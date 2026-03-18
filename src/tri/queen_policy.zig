// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// QUEEN POLICY — Safety levels, guardrails, audit trail, incident memory
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
//
// Three-tier action safety:
//   Level 0 (read-only): always allowed — status, leaderboard, dry-run doctor
//   Level 1 (soft write): git commit state, ouroboros --cycles 1, doctor quick
//   Level 2 (dangerous): service restart, config changes, mass git ops
//
// Per-action rate limits, audit trail, incident escalation.
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const qt = @import("queen_types.zig");

const print = std.debug.print;

// ═══════════════════════════════════════════════════════════════════════════════
// SAFETY LEVELS
// ═══════════════════════════════════════════════════════════════════════════════

pub const SafetyLevel = enum(u8) {
    read_only = 0, // Level 0: always safe
    soft_write = 1, // Level 1: mild mutations, auto-allowed with flag
    dangerous = 2, // Level 2: needs human approval

    pub fn label(self: SafetyLevel) []const u8 {
        return switch (self) {
            .read_only => "L0 read-only",
            .soft_write => "L1 soft-write",
            .dangerous => "L2 dangerous",
        };
    }

    pub fn emoji(self: SafetyLevel) []const u8 {
        return switch (self) {
            .read_only => qt.E_CHECK,
            .soft_write => qt.E_WRENCH,
            .dangerous => qt.E_SIREN,
        };
    }
};

/// Map each action to its safety level
pub fn actionLevel(kind: qt.ActionKind) SafetyLevel {
    return switch (kind) {
        // L0 — Read-Only
        .farm_status, .arena_status, .doctor_scan, .train_status, .train_diagnose, .experiment_chart, .patent_status, .research_sacred, .ouroboros_status, .experience_recall, .farm_evolve_status, .swarm_status => .read_only,
        // L1 — Soft Write
        .doctor_quick, .doctor_heal, .ouroboros_cycle, .git_commit_state, .git_push, .issue_comment, .notify, .arena_battle, .experience_save, .fmt => .soft_write,
        // L2 — Dangerous
        .farm_recycle, .farm_evolve_step, .cloud_spawn, .cloud_kill, .cloud_cleanup, .issue_create, .swarm_decompose => .dangerous,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// PER-ACTION RATE LIMITS
// ═══════════════════════════════════════════════════════════════════════════════

pub const ActionRateLimit = struct {
    max_per_hour: u8,
    cooldown_sec: u32, // minimum seconds between same action
};

pub fn actionRateLimit(kind: qt.ActionKind) ActionRateLimit {
    return switch (kind) {
        // L0 — generous limits
        .farm_status, .arena_status, .train_status, .ouroboros_status, .farm_evolve_status, .swarm_status => .{ .max_per_hour = 12, .cooldown_sec = 300 },
        .doctor_scan, .train_diagnose, .experiment_chart, .patent_status, .research_sacred, .experience_recall => .{ .max_per_hour = 6, .cooldown_sec = 600 },
        // L1 — moderate limits
        .doctor_quick, .fmt => .{ .max_per_hour = 3, .cooldown_sec = 600 },
        .doctor_heal => .{ .max_per_hour = 1, .cooldown_sec = 3600 },
        .ouroboros_cycle => .{ .max_per_hour = 2, .cooldown_sec = 1800 },
        .git_commit_state, .git_push => .{ .max_per_hour = 1, .cooldown_sec = 3600 },
        .issue_comment, .notify, .experience_save => .{ .max_per_hour = 6, .cooldown_sec = 300 },
        .arena_battle => .{ .max_per_hour = 3, .cooldown_sec = 600 },
        // L2 — strict limits
        .farm_recycle, .cloud_cleanup => .{ .max_per_hour = 1, .cooldown_sec = 3600 },
        .farm_evolve_step => .{ .max_per_hour = 1, .cooldown_sec = 7200 },
        .cloud_spawn, .cloud_kill, .issue_create => .{ .max_per_hour = 2, .cooldown_sec = 1800 },
        .swarm_decompose => .{ .max_per_hour = 1, .cooldown_sec = 3600 },
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// POLICY CHECK — "Can Queen do this right now?"
// ═══════════════════════════════════════════════════════════════════════════════

pub const PolicyVerdict = enum {
    allowed,
    denied_level, // action level exceeds config max_auto_level
    denied_rate, // per-action rate limit exceeded
    denied_cooldown, // cooldown not elapsed
    denied_escalated, // incident escalation → human required
    needs_approval, // Level 2, require_human_approval = true

    pub fn isAllowed(self: PolicyVerdict) bool {
        return self == .allowed;
    }

    pub fn reason(self: PolicyVerdict) []const u8 {
        return switch (self) {
            .allowed => "OK",
            .denied_level => "level exceeds max_auto_level",
            .denied_rate => "per-action rate limit",
            .denied_cooldown => "cooldown not elapsed",
            .denied_escalated => "incident escalated, human required",
            .needs_approval => "Level 2: needs /queen approve",
        };
    }
};

pub fn checkPolicy(
    kind: qt.ActionKind,
    config: qt.QueenConfig,
    counters: *const ActionCounters,
    incidents: *const IncidentMemory,
) PolicyVerdict {
    const level = actionLevel(kind);

    // Level gate
    if (@intFromEnum(level) > config.max_auto_level) {
        if (level == .dangerous and config.require_human_approval) {
            return .needs_approval;
        }
        return .denied_level;
    }

    // Incident escalation: if same type failed 3+ times in last hour, block auto
    if (incidents.recentFailCount(kind) >= 3) {
        return .denied_escalated;
    }

    // Per-action rate limit
    const limits = actionRateLimit(kind);
    const count = counters.getCount(kind);
    if (count >= limits.max_per_hour) {
        return .denied_rate;
    }

    // Per-action cooldown
    const last_ts = counters.getLastTs(kind);
    if (last_ts > 0) {
        const now = std.time.timestamp();
        if (now - last_ts < limits.cooldown_sec) {
            return .denied_cooldown;
        }
    }

    return .allowed;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PER-ACTION COUNTERS (hourly window)
// ═══════════════════════════════════════════════════════════════════════════════

const NUM_ACTIONS = qt.ActionKind.COUNT;

pub const ActionCounters = struct {
    counts: [NUM_ACTIONS]u8 = .{0} ** NUM_ACTIONS,
    last_ts: [NUM_ACTIONS]i64 = .{0} ** NUM_ACTIONS,
    window_start: i64 = 0,

    pub fn getCount(self: *const ActionCounters, kind: qt.ActionKind) u8 {
        return self.counts[@intFromEnum(kind)];
    }

    pub fn getLastTs(self: *const ActionCounters, kind: qt.ActionKind) i64 {
        return self.last_ts[@intFromEnum(kind)];
    }

    pub fn record(self: *ActionCounters, kind: qt.ActionKind) void {
        const now = std.time.timestamp();
        // Reset window if hour elapsed
        if (now - self.window_start > 3600) {
            self.counts = .{0} ** NUM_ACTIONS;
            self.window_start = now;
        }
        const idx = @intFromEnum(kind);
        self.counts[idx] +|= 1; // saturating add
        self.last_ts[idx] = now;
    }

    pub fn resetAll(self: *ActionCounters) void {
        self.counts = .{0} ** NUM_ACTIONS;
        self.last_ts = .{0} ** NUM_ACTIONS;
        self.window_start = 0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// INCIDENT MEMORY — Rolling window of events
// ═══════════════════════════════════════════════════════════════════════════════

pub const MAX_INCIDENTS = 32;

pub const IncidentKind = enum(u8) {
    alert, // alert triggered
    auto_action, // auto-action executed
    auto_action_fail, // auto-action failed
    human_command, // /queen command from Telegram
    approval, // /queen approve
    denial, // /queen deny
    escalation, // repeated failure → escalated to human
};

pub const Incident = struct {
    ts: i64 = 0,
    kind: IncidentKind = .alert,
    action: qt.ActionKind = .doctor_quick,
    success: bool = true,
    detail: [128]u8 = undefined,
    detail_len: usize = 0,

    pub fn detailStr(self: *const Incident) []const u8 {
        return self.detail[0..self.detail_len];
    }

    fn setDetail(self: *Incident, text: []const u8) void {
        const len = @min(text.len, self.detail.len);
        @memcpy(self.detail[0..len], text[0..len]);
        self.detail_len = len;
    }
};

pub const IncidentMemory = struct {
    ring: [MAX_INCIDENTS]Incident = undefined,
    count: u32 = 0,
    total_alerts_24h: u32 = 0,
    total_auto_actions_24h: u32 = 0,
    total_auto_fails_24h: u32 = 0,
    build_breaks_24h: u8 = 0,
    heal_cycles_24h: u8 = 0,
    day_start_ts: i64 = 0,

    pub fn init() IncidentMemory {
        var m = IncidentMemory{};
        m.day_start_ts = std.time.timestamp();
        return m;
    }

    /// Add an incident to the ring buffer
    pub fn record(self: *IncidentMemory, kind: IncidentKind, action: qt.ActionKind, success: bool, detail: []const u8) void {
        self.maybeResetDaily();

        const idx = self.count % MAX_INCIDENTS;
        self.ring[idx] = Incident{
            .ts = std.time.timestamp(),
            .kind = kind,
            .action = action,
            .success = success,
        };
        self.ring[idx].setDetail(detail);
        self.count += 1;

        // Aggregate counters
        switch (kind) {
            .alert => self.total_alerts_24h += 1,
            .auto_action => self.total_auto_actions_24h += 1,
            .auto_action_fail => self.total_auto_fails_24h += 1,
            else => {},
        }
    }

    /// Count recent failures of a specific action kind (last hour)
    pub fn recentFailCount(self: *const IncidentMemory, action: qt.ActionKind) u8 {
        const now = std.time.timestamp();
        const one_hour_ago = now - 3600;
        var fails: u8 = 0;

        const total = @min(self.count, MAX_INCIDENTS);
        for (0..total) |i| {
            const idx = if (self.count > MAX_INCIDENTS)
                (self.count - MAX_INCIDENTS + @as(u32, @intCast(i))) % MAX_INCIDENTS
            else
                @as(u32, @intCast(i));
            const inc = &self.ring[idx];
            if (inc.ts > one_hour_ago and
                inc.action == action and
                !inc.success and
                (inc.kind == .auto_action_fail or inc.kind == .auto_action))
            {
                fails +|= 1;
            }
        }
        return fails;
    }

    /// Get the last N incidents (most recent first)
    pub fn lastN(self: *const IncidentMemory, buf: *[MAX_INCIDENTS]Incident) u32 {
        const total = @min(self.count, MAX_INCIDENTS);
        for (0..total) |i| {
            // Read from newest to oldest
            const ring_idx = if (self.count > 0)
                (self.count - 1 - @as(u32, @intCast(i))) % MAX_INCIDENTS
            else
                0;
            buf[i] = self.ring[ring_idx];
        }
        return total;
    }

    fn maybeResetDaily(self: *IncidentMemory) void {
        const now = std.time.timestamp();
        if (now - self.day_start_ts > 86400) {
            self.total_alerts_24h = 0;
            self.total_auto_actions_24h = 0;
            self.total_auto_fails_24h = 0;
            self.build_breaks_24h = 0;
            self.heal_cycles_24h = 0;
            self.day_start_ts = now;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PENDING APPROVALS (Level 2 actions awaiting human /queen approve)
// ═══════════════════════════════════════════════════════════════════════════════

pub const MAX_PENDING = 4;

pub const PendingAction = struct {
    id: u16 = 0,
    action: qt.ActionKind = .doctor_quick,
    requested_at: i64 = 0,
    reason: [64]u8 = undefined,
    reason_len: usize = 0,
    active: bool = false,

    pub fn reasonStr(self: *const PendingAction) []const u8 {
        return self.reason[0..self.reason_len];
    }
};

pub const PendingQueue = struct {
    items: [MAX_PENDING]PendingAction = undefined,
    next_id: u16 = 1,

    pub fn init() PendingQueue {
        var q = PendingQueue{};
        for (&q.items) |*item| item.active = false;
        return q;
    }

    pub fn add(self: *PendingQueue, action: qt.ActionKind, reason_text: []const u8) ?u16 {
        for (&self.items) |*item| {
            if (!item.active) {
                const id = self.next_id;
                self.next_id +%= 1;
                if (self.next_id == 0) self.next_id = 1;
                item.* = PendingAction{
                    .id = id,
                    .action = action,
                    .requested_at = std.time.timestamp(),
                    .active = true,
                };
                const len = @min(reason_text.len, item.reason.len);
                @memcpy(item.reason[0..len], reason_text[0..len]);
                item.reason_len = len;
                return id;
            }
        }
        return null; // queue full
    }

    pub fn approve(self: *PendingQueue, id: u16) ?qt.ActionKind {
        for (&self.items) |*item| {
            if (item.active and item.id == id) {
                item.active = false;
                return item.action;
            }
        }
        return null;
    }

    pub fn deny(self: *PendingQueue, id: u16) bool {
        for (&self.items) |*item| {
            if (item.active and item.id == id) {
                item.active = false;
                return true;
            }
        }
        return false;
    }

    pub fn pendingCount(self: *const PendingQueue) u8 {
        var c: u8 = 0;
        for (self.items) |item| {
            if (item.active) c += 1;
        }
        return c;
    }

    /// Expire items older than 30 minutes
    pub fn expireOld(self: *PendingQueue) void {
        const now = std.time.timestamp();
        for (&self.items) |*item| {
            if (item.active and now - item.requested_at > 1800) {
                item.active = false;
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// AUDIT LOG — Append-only JSONL file
// ═══════════════════════════════════════════════════════════════════════════════

pub const AUDIT_PATH = ".trinity/queen/audit.jsonl";

pub fn writeAuditEntry(
    kind: []const u8,
    action: qt.ActionKind,
    verdict: PolicyVerdict,
    success: bool,
    detail: []const u8,
) void {
    // Ensure directory exists
    std.fs.cwd().makePath(".trinity/queen") catch {};

    const file = std.fs.cwd().openFile(AUDIT_PATH, .{ .mode = .read_write }) catch {
        // Create if not exists
        const new_file = std.fs.cwd().createFile(AUDIT_PATH, .{}) catch return;
        writeAuditLine(new_file, kind, action, verdict, success, detail);
        new_file.close();
        return;
    };
    defer file.close();
    file.seekFromEnd(0) catch return;
    writeAuditLine(file, kind, action, verdict, success, detail);
}

fn writeAuditLine(
    file: std.fs.File,
    kind: []const u8,
    action: qt.ActionKind,
    verdict: PolicyVerdict,
    success: bool,
    detail: []const u8,
) void {
    var buf: [512]u8 = undefined;

    // Truncate detail for JSON safety
    const d_len = @min(detail.len, 100);
    const d = detail[0..d_len];

    const line = std.fmt.bufPrint(&buf,
        \\{{"ts":{d},"kind":"{s}","action":"{s}","verdict":"{s}","success":{s},"detail":"{s}"}}
        \\
    , .{
        std.time.timestamp(),
        kind,
        action.label(),
        verdict.reason(),
        if (success) "true" else "false",
        d,
    }) catch return;
    _ = file.write(line) catch {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// TTY — Print policy map
// ═══════════════════════════════════════════════════════════════════════════════

pub fn printPolicyMap(config: qt.QueenConfig, counters: *const ActionCounters) void {
    const colors = @import("tri_colors.zig");
    print("\n{s}" ++ qt.E_GEAR ++ " Queen v4 Policy Map ({d} actions){s}\n\n", .{ colors.GOLDEN, @as(u8, NUM_ACTIONS), colors.RESET });
    print("  max_auto_level: L{d} | require_human_approval: {s}\n\n", .{
        config.max_auto_level,
        if (config.require_human_approval) "YES" else "NO",
    });
    print("  {s}#   Action              Level      Rate  Cool   Used  Status{s}\n", .{ colors.GRAY, colors.RESET });
    print("  {s}─── ─────────────────── ────────── ───── ────── ──── ──────{s}\n", .{ colors.GRAY, colors.RESET });

    for (0..NUM_ACTIONS) |i| {
        const kind: qt.ActionKind = @enumFromInt(i);
        const level = actionLevel(kind);
        const limits = actionRateLimit(kind);
        const used = counters.getCount(kind);
        const allowed = @intFromEnum(level) <= config.max_auto_level;
        print("  {d:<3} {s} {s:<19} {s:<10} {d:<5} {d:<6} {d:<4} {s}{s}\n", .{
            i,
            level.emoji(),
            kind.label(),
            level.label(),
            limits.max_per_hour,
            limits.cooldown_sec,
            used,
            if (allowed) "OPEN" else "BLOCKED",
            colors.RESET,
        });
    }
    print("\n", .{});
}

/// Format policy for Telegram
pub fn fmtPolicyTelegram(buf: []u8, config: qt.QueenConfig, counters: *const ActionCounters) []const u8 {
    var offset: usize = 0;

    // Header
    const hdr = std.fmt.bufPrint(buf[offset..], qt.E_GEAR ++ " Queen v4 Policy ({d} actions)\n\nMax: L{d} | Approval: {s}\n\n", .{
        @as(u8, NUM_ACTIONS),
        config.max_auto_level,
        if (config.require_human_approval) "ON" else "OFF",
    }) catch return buf[0..0];
    offset += hdr.len;

    // L0 section
    const l0_hdr = std.fmt.bufPrint(buf[offset..], "--- L0 Read-Only ---\n", .{}) catch return buf[0..offset];
    offset += l0_hdr.len;
    for (0..NUM_ACTIONS) |i| {
        const kind: qt.ActionKind = @enumFromInt(i);
        if (actionLevel(kind) != .read_only) continue;
        const line = std.fmt.bufPrint(buf[offset..], "{s} {s} {d}/{d}\n", .{
            qt.E_CHECK, kind.label(), counters.getCount(kind), actionRateLimit(kind).max_per_hour,
        }) catch break;
        offset += line.len;
    }

    // L1 section
    const l1_hdr = std.fmt.bufPrint(buf[offset..], "\n--- L1 Soft-Write ---\n", .{}) catch return buf[0..offset];
    offset += l1_hdr.len;
    for (0..NUM_ACTIONS) |i| {
        const kind: qt.ActionKind = @enumFromInt(i);
        if (actionLevel(kind) != .soft_write) continue;
        const line = std.fmt.bufPrint(buf[offset..], "{s} {s} {d}/{d}\n", .{
            qt.E_WRENCH, kind.label(), counters.getCount(kind), actionRateLimit(kind).max_per_hour,
        }) catch break;
        offset += line.len;
    }

    // L2 section
    const l2_hdr = std.fmt.bufPrint(buf[offset..], "\n--- L2 Dangerous ---\n", .{}) catch return buf[0..offset];
    offset += l2_hdr.len;
    for (0..NUM_ACTIONS) |i| {
        const kind: qt.ActionKind = @enumFromInt(i);
        if (actionLevel(kind) != .dangerous) continue;
        const allowed = @intFromEnum(actionLevel(kind)) <= config.max_auto_level;
        const line = std.fmt.bufPrint(buf[offset..], "{s} {s} {d}/{d} {s}\n", .{
            qt.E_SIREN,                        kind.label(), counters.getCount(kind), actionRateLimit(kind).max_per_hour,
            if (allowed) "OPEN" else "LOCKED",
        }) catch break;
        offset += line.len;
    }

    return buf[0..offset];
}

/// Format incident history for Telegram
pub fn fmtHistoryTelegram(buf: []u8, memory: *const IncidentMemory) []const u8 {
    var incidents: [MAX_INCIDENTS]Incident = undefined;
    const n = memory.lastN(&incidents);
    const show = @min(n, 10); // Show last 10

    var offset: usize = 0;

    // Header
    const hdr = qt.E_CLIP ++ " Queen History\n\n" ++
        qt.E_FIRE ++ " 24h: {d} alerts, {d} auto, {d} fails\n\n";
    const hdr_written = std.fmt.bufPrint(buf[offset..], hdr, .{
        memory.total_alerts_24h,
        memory.total_auto_actions_24h,
        memory.total_auto_fails_24h,
    }) catch return buf[0..0];
    offset += hdr_written.len;

    if (show == 0) {
        const empty = "(no incidents yet)";
        if (offset + empty.len <= buf.len) {
            @memcpy(buf[offset..][0..empty.len], empty);
            offset += empty.len;
        }
        return buf[0..offset];
    }

    for (0..show) |i| {
        const inc = &incidents[i];
        const icon = switch (inc.kind) {
            .alert => qt.E_FIRE,
            .auto_action => qt.E_BOLT,
            .auto_action_fail => qt.E_CROSS,
            .human_command => qt.E_HAND,
            .approval => qt.E_CHECK,
            .denial => qt.E_STOP,
            .escalation => qt.E_SIREN,
        };
        // Format: [icon] action (Xs ago)
        const ago = std.time.timestamp() - inc.ts;
        const ago_min = @divTrunc(ago, 60);
        const line = std.fmt.bufPrint(buf[offset..], "{s} {s} ({d}m ago)\n", .{
            icon,
            inc.action.label(),
            ago_min,
        }) catch break;
        offset += line.len;
    }

    return buf[0..offset];
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Policy — action levels" {
    try std.testing.expectEqual(SafetyLevel.read_only, actionLevel(.farm_status));
    try std.testing.expectEqual(SafetyLevel.read_only, actionLevel(.arena_status));
    try std.testing.expectEqual(SafetyLevel.read_only, actionLevel(.train_status));
    try std.testing.expectEqual(SafetyLevel.read_only, actionLevel(.ouroboros_status));
    try std.testing.expectEqual(SafetyLevel.read_only, actionLevel(.farm_evolve_status));
    try std.testing.expectEqual(SafetyLevel.read_only, actionLevel(.swarm_status));
    try std.testing.expectEqual(SafetyLevel.soft_write, actionLevel(.doctor_quick));
    try std.testing.expectEqual(SafetyLevel.soft_write, actionLevel(.doctor_heal));
    try std.testing.expectEqual(SafetyLevel.soft_write, actionLevel(.git_commit_state));
    try std.testing.expectEqual(SafetyLevel.soft_write, actionLevel(.git_push));
    try std.testing.expectEqual(SafetyLevel.soft_write, actionLevel(.issue_comment));
    try std.testing.expectEqual(SafetyLevel.soft_write, actionLevel(.arena_battle));
    try std.testing.expectEqual(SafetyLevel.dangerous, actionLevel(.farm_recycle));
    try std.testing.expectEqual(SafetyLevel.dangerous, actionLevel(.farm_evolve_step));
    try std.testing.expectEqual(SafetyLevel.dangerous, actionLevel(.cloud_spawn));
    try std.testing.expectEqual(SafetyLevel.dangerous, actionLevel(.issue_create));
}

test "Policy — check allowed L0" {
    const config = qt.QueenConfig{ .max_auto_level = 0 };
    var counters = ActionCounters{};
    const memory = IncidentMemory.init();
    const v = checkPolicy(.farm_status, config, &counters, &memory);
    try std.testing.expectEqual(PolicyVerdict.allowed, v);
}

test "Policy — check denied level" {
    const config = qt.QueenConfig{ .max_auto_level = 0 };
    var counters = ActionCounters{};
    const memory = IncidentMemory.init();
    const v = checkPolicy(.doctor_quick, config, &counters, &memory);
    try std.testing.expectEqual(PolicyVerdict.denied_level, v);
}

test "Policy — check allowed L1" {
    const config = qt.QueenConfig{ .max_auto_level = 1 };
    var counters = ActionCounters{};
    const memory = IncidentMemory.init();
    const v = checkPolicy(.doctor_quick, config, &counters, &memory);
    try std.testing.expectEqual(PolicyVerdict.allowed, v);
}

test "Policy — rate limit exceeded" {
    const config = qt.QueenConfig{ .max_auto_level = 1 };
    var counters = ActionCounters{};
    counters.window_start = std.time.timestamp();
    // git_commit_state: max 1/hour
    counters.counts[@intFromEnum(qt.ActionKind.git_commit_state)] = 1;
    const memory = IncidentMemory.init();
    const v = checkPolicy(.git_commit_state, config, &counters, &memory);
    try std.testing.expectEqual(PolicyVerdict.denied_rate, v);
}

test "Policy — incident escalation" {
    const config = qt.QueenConfig{ .max_auto_level = 1 };
    var counters = ActionCounters{};
    var memory = IncidentMemory.init();
    // Record 3 failures for doctor_quick
    memory.record(.auto_action_fail, .doctor_quick, false, "fail 1");
    memory.record(.auto_action_fail, .doctor_quick, false, "fail 2");
    memory.record(.auto_action_fail, .doctor_quick, false, "fail 3");
    const v = checkPolicy(.doctor_quick, config, &counters, &memory);
    try std.testing.expectEqual(PolicyVerdict.denied_escalated, v);
}

test "Policy — ActionCounters record and window reset" {
    var c = ActionCounters{};
    c.record(.doctor_quick);
    try std.testing.expectEqual(@as(u8, 1), c.getCount(.doctor_quick));
    try std.testing.expect(c.getLastTs(.doctor_quick) > 0);
    try std.testing.expectEqual(@as(u8, 0), c.getCount(.farm_status));
}

test "Policy — IncidentMemory ring buffer" {
    var m = IncidentMemory.init();
    m.record(.alert, .doctor_quick, true, "build broken");
    m.record(.auto_action, .doctor_quick, true, "healed");
    try std.testing.expectEqual(@as(u32, 2), m.count);
    try std.testing.expectEqual(@as(u32, 1), m.total_alerts_24h);
    try std.testing.expectEqual(@as(u32, 1), m.total_auto_actions_24h);
}

test "Policy — IncidentMemory lastN" {
    var m = IncidentMemory.init();
    m.record(.alert, .doctor_quick, true, "first");
    m.record(.auto_action, .farm_status, true, "second");
    var buf: [MAX_INCIDENTS]Incident = undefined;
    const n = m.lastN(&buf);
    try std.testing.expectEqual(@as(u32, 2), n);
    // Most recent first
    try std.testing.expectEqual(IncidentKind.auto_action, buf[0].kind);
    try std.testing.expectEqual(IncidentKind.alert, buf[1].kind);
}

test "Policy — PendingQueue add/approve/deny" {
    var q = PendingQueue.init();
    const id1 = q.add(.doctor_quick, "build broken").?;
    const id2 = q.add(.ouroboros_cycle, "low score").?;
    try std.testing.expectEqual(@as(u8, 2), q.pendingCount());

    const approved = q.approve(id1).?;
    try std.testing.expectEqual(qt.ActionKind.doctor_quick, approved);
    try std.testing.expectEqual(@as(u8, 1), q.pendingCount());

    try std.testing.expect(q.deny(id2));
    try std.testing.expectEqual(@as(u8, 0), q.pendingCount());
}

test "Policy — fmtPolicyTelegram" {
    const config = qt.QueenConfig{ .max_auto_level = 1 };
    var counters = ActionCounters{};
    var buf: [1024]u8 = undefined;
    const msg = fmtPolicyTelegram(&buf, config, &counters);
    try std.testing.expect(msg.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, msg, "Policy") != null);
}

test "Policy — fmtHistoryTelegram empty" {
    const m = IncidentMemory.init();
    var buf: [1024]u8 = undefined;
    const msg = fmtHistoryTelegram(&buf, &m);
    try std.testing.expect(msg.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, msg, "no incidents") != null);
}
