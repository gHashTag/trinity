// ═══════════════════════════════════════════════════════════════════════════
// DORSOLATERAL PREFRONTAL CORTEX (DLPFC) — Decision Engine
// ═════════════════════════════════════════════════════════════════════════
// Neuro: Working memory, planning, abstract reasoning, cognitive control
// Trinity: Decision engine + priority queue + main Queen cycle
//   READ → THINK → ACT → SPEAK cycle
//   Phase 1: READ ONLY — decisions logged, NOT executed
//
// φ² + 1/φ² = 3 = TRINITY
// ═════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const qt = @import("queen_types.zig");
const thalamus = @import("thalamus.zig");
const hippocampus = @import("hippocampus.zig");

// ═══════════════════════════════════════════════════════════════════════════════════
// PHASE 1 — READ ONLY (no actions executed)
// ═════════════════════════════════════════════════════════════════════════════════════

pub const PHASE: u8 = 1; // READ_ONLY

// ═════════════════════════════════════════════════════════════════════════════════════════
// DECISION — What to do, priority, reasoning
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

pub const Decision = struct {
    id: u32 = 0,
    kind: DecisionKind,
    priority: Priority,
    action: []const u8 = "",
    action_len: usize = 0,
    reason: [512]u8 = undefined,
    reason_len: usize = 0,
    timestamp: i64 = 0,
    executed: bool = false, // Was this decision executed?
    result: [1024]u8 = undefined,
    result_len: usize = 0,

    pub fn reasonStr(self: *const Decision) []const u8 {
        return self.reason[0..self.reason_len];
    }

    pub fn setReason(self: *Decision, text: []const u8) void {
        const len = @min(text.len, self.reason.len);
        @memcpy(self.reason[0..len], text[0..len]);
        self.reason_len = len;
    }

    pub fn setResult(self: *Decision, text: []const u8) void {
        const len = @min(text.len, self.result.len);
        @memcpy(self.result[0..len], text[0..len]);
        self.result_len = len;
    }

    pub fn setExecuted(self: *Decision) void {
        self.executed = true;
        self.timestamp = std.time.timestamp();
    }
};

pub const DecisionKind = enum {
    scan_system, // Run doctor scan
    check_health, // Verify cell health
    recycle_worker, // Recycle stale/crashed farm worker
    inject_config, // Inject new training config
    farm_evolve_step, // Run evolution step
    git_commit, // Commit git state
    git_push, // Push to remote
    heal_doctor, // Run doctor heal

    pub fn label(self: DecisionKind) []const u8 {
        return switch (self) {
            .scan_system => "scan system",
            .check_health => "check cell health",
            .recycle_worker => "recycle worker",
            .inject_config => "inject config",
            .farm_evolve_step => "evolve step",
            .git_commit => "git commit",
            .git_push => "git push",
            .heal_doctor => "heal doctor",
        };
    }
};

pub const Priority = enum(u8) {
    critical = 0, // crashed worker, dead token
    high = 1, // stalled >1h, PPL regression
    medium = 2, // recycle, status checks
    low = 3, // informational

    pub fn label(self: Priority) []const u8 {
        return switch (self) {
            .critical => "CRITICAL",
            .high => "HIGH",
            .medium => "MEDIUM",
            .low => "LOW",
        };
    }

    pub fn emoji(self: Priority) []const u8 {
        return switch (self) {
            .critical => qt.E_SIREN,
            .high => qt.E_WRENCH,
            .medium => qt.E_WRENCH,
            .low => qt.E_CHECK,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// PRIORITY QUEUE — Decisions waiting execution
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════

pub const PriorityQueue = struct {
    decisions: []Decision = &.{},
    count: usize = 0,

    pub fn init(allocator: Allocator) !PriorityQueue {
        const queue = try allocator.alloc(Decision, 16);
        return .{ .decisions = queue };
    }

    pub fn push(self: *PriorityQueue, decision: Decision) !void {
        if (self.count >= self.decisions.len) {
            return error.QueueFull;
        }

        // Insert sorted by priority (critical first)
        var insert_at = self.count;
        for (0..self.count) |i| {
            if (decision.priority > self.decisions[i].priority) {
                insert_at = i;
                break;
            }
        }

        // Shift to make room
        const move_from = if (insert_at < self.count)
            insert_at
        else
            self.count;

        for (insert_at .. self.count) |i| {
            const target = if (i >= move_from and i > insert_at)
                i - 1
            else
                i;

            self.decisions[target] = self.decisions[i];
        }

        self.decisions[insert_at] = decision;
        self.count += 1;
    }

    pub fn pop(self: *PriorityQueue) ?Decision {
        if (self.count == 0) return null;

        self.count -= 1;
        return &self.decisions[0];
    }

    pub fn peek(self: *const PriorityQueue) ?Decision {
        if (self.count == 0) return null;
        return &self.decisions[self.count - 1];
    }

    pub fn isEmpty(self: *const PriorityQueue) bool {
        return self.count == 0;
    }

    pub fn len(self: *const PriorityQueue) usize {
        return self.count;
    }
};

// ═════════════════════════════════════════════════════════════════════════════════════════════════
// UNIFIED LOOP — READ → THINK → ACT → SPEAK
// ═════════════════════════════════════════════════════════════════════════════════════════════

pub const LoopState = struct {
    cycle: u32 = 0,
    queue: PriorityQueue = .{},
    last_think: i64 = 0,

    pub fn init(allocator: Allocator) !LoopState {
        const q = try PriorityQueue.init(allocator);
        return .{ .queue = q };
    }
};

/// READ phase — gather Thalamus data
pub fn readPhase(allocator: Allocator, state: *LoopState) !void {
    state.cycle += 1;

    // Collect all Thalamus relays
    const farm_status = try thalamus.getFarmStatus(allocator);
    const github_issues = try thalamus.getGitHubIssues(allocator);

    _ = try thalamus.getCellHealth(allocator); // Not used yet
    const metabolism = try thalamus.getMetabolismSnapshot(allocator);
    const sleep_info = try thalamus.getLastSleepInfo(allocator);

    // Build observation string
    var buf: [2048]u8 = undefined;
    var offset: usize = 0;

    offset += try std.fmt.bufPrint(
        buf[offset..],
        "\\n{s} READ PHASE — Cycle {d}{s}\\n",
        .{ qt.E_EYE, state.cycle },
    );
    offset += try std.fmt.bufPrint(
        buf[offset..],
        "{s} Farm: {d}/{d} active PPL={d:.1}\\n",
        .{ farm_status.active, farm_status.total_services, farm_status.best_ppl },
    );
    offset += try std.fmt.bufPrint(
        buf[offset..],
        "{s} GitHub: {d} open issues\\n",
        .{ github_issues.open },
    );
    offset += try std.fmt.bufPrint(
        buf[offset..],
        "{s} Metabolism: PPL={d:.1} tok/s={d}\\n",
        .{ if (metabolism) |m| m.ppl else 0.0, if (metabolism) |m| m.tok_per_sec else 0 },
    );
    offset += try std.fmt.bufPrint(
        buf[offset..],
        "{s} Sleep: {d}h ago\\n",
        .{ if (sleep_info) |s| s.hours_since else 999 },
    );

    // Log to hippocampus
    const data = try std.fmt.allocPrint(
        allocator,
        "{{\"cycle\":{d},\"farm_active\":{d},\"farm_total\":{d},\"github_open\":{d},\"metabolism_ppl\":{d:.1},\"sleep_hours_ago\":{d:.1}}}",
        .{ state.cycle, farm_status.active, farm_status.total_services, github_issues.open, if (metabolism) |m| m.ppl else 0.0, if (sleep_info) |s| s.hours_since else 999.0 },
    );
    defer allocator.free(data);

    _ = try hippocampus.write(allocator, .{
        .agent = "queen_dlpfc",
        .kind = .observation,
        .summary = "unified read phase",
        .data = data,
    });
}

/// THINK phase — analyze and prioritize
pub fn thinkPhase(allocator: Allocator, state: *LoopState) !void {
    state.last_think = std.time.timestamp();

    // Decision queue for this cycle
    var decisions = std.ArrayList(Decision).initCapacity(0, allocator);
    defer decisions.deinit(allocator);

    // Check for critical issues
    const farm_status = try thalamus.getFarmStatus(allocator);

    if (farm_status.crashed > 0) {
        try decisions.append(Decision{
            .id = 1,
            .kind = .recycle_worker,
            .priority = .critical,
            .action = "recycle crashed worker",
            .reason = "Worker crash detected, immediate recycle needed",
        });
    }

    if (farm_status.stale_count > 5) {
        try decisions.append(Decision{
            .id = 2,
            .kind = .recycle_worker,
            .priority = .high,
            .action = "mass recycle stale workers",
            .reason = "Multiple stale workers detected",
        });
    }

    // Push all decisions to priority queue
    for (decisions.items) |dec| {
        try state.queue.push(dec);
    }

    // Log think summary
    const summary = try std.fmt.allocPrint(
        allocator,
        "{{\\\"decisions\\\":{d},\\\"cycle\\\":{d}}}",
        .{ decisions.items.len, state.cycle },
    );
    defer allocator.free(summary);

    _ = try hippocampus.write(allocator, .{
        .agent = "queen_dlpfc",
        .kind = .observation,
        .summary = "think phase completed",
        .data = summary,
    });
}

/// SPEAK phase — format decisions for output (Phase 1: log only)
pub fn speakPhase(allocator: Allocator, state: *LoopState) ![]const u8 {
    _ = allocator; // Not used in Phase 1
    if (state.queue.isEmpty()) {
        return "No decisions in queue";
    }

    var buf: [2048]u8 = undefined;
    var offset: usize = 0;

    // Header
    offset += try std.fmt.bufPrint(
        buf[offset..],
        "{s} Unified Queen Loop — {s}\\n",
        .{ qt.E_CROWN },
    );
    offset += try std.fmt.bufPrint(
        buf[offset..],
        "{s} Phase {d} (READ ONLY) | Cycle {d}\\n",
        .{ PHASE, state.cycle },
    );

    // List all decisions
    var idx: usize = 0;
    while (idx < state.queue.count) {
        const dec = state.queue.peek() orelse break;
        if (dec == null) break;

        const icon = dec.priority.emoji();
        offset += try std.fmt.bufPrint(
            buf[offset..],
            "  {s} {s}{s} — {s}\\n",
            .{ icon, dec.priority.label(), dec.kind.label() },
        );
        offset += try std.fmt.bufPrint(
            buf[offset..],
            "    Reason: {s}\\n",
            .{ dec.reasonStr() },
        );

        _ = state.queue.pop();
        idx += 1;
    }

    // Footer
    offset += try std.fmt.bufPrint(
        buf[offset..],
        "\\n{s} {d} decisions total\\n",
        .{ qt.E_CHECK, state.queue.count },
    );

    return buf[0..offset];
}

/// Main unified loop entry point
pub fn runUnifiedLoop(allocator: Allocator, interval_sec: u32) !void {
    var state = try LoopState.init(allocator);

    while (true) {
        std.Thread.sleep(interval_sec * std.time.ns_per_s);

        try readPhase(allocator, &state);
        try thinkPhase(allocator, &state);

        // Phase 1: SPEAK = log only, no execution
        const report = try speakPhase(allocator, &state);

        // TODO: Send to Telegram in Phase 2
        std.debug.print("{s}\n", .{ report });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════

test "dlpfc — DecisionKind labels" {
    try std.testing.expectEqualStrings("scan system", DecisionKind.scan_system.label());
    try std.testing.expectEqualStrings("git commit", DecisionKind.git_commit.label());
}

test "dlpfc — Priority labels" {
    try std.testing.expectEqualStrings("CRITICAL", Priority.critical.label());
    try std.testing.expectEqualStrings("LOW", Priority.low.label());
}

test "dlpfc — PriorityQueue push pop" {
    var pq = try PriorityQueue.init(std.testing.allocator);
    defer {
        for (pq.decisions[0..pq.count]) |*d| {
            std.testing.allocator.free(d.reasonStr());
        }
        std.testing.allocator.free(pq.decisions);
    }

    var d = Decision{
        .id = 1,
        .kind = .scan_system,
        .priority = .medium,
        .action = "test action",
    };
    d.setReason("test");
    try pq.push(d);

    try std.testing.expectEqual(@as(usize, 1), pq.count);

    if (pq.pop()) |popped| {
        try std.testing.expect(popped.id == 1);
        try std.testing.expect(popped.kind == .scan_system);
        std.testing.allocator.free(popped.reasonStr());
    }
}

test "dlpfc — PHASE = 1 (READ ONLY)" {
    try std.testing.expectEqual(@as(u8, 1), PHASE);
}

test "dlpfc — health returns healthy" {
    const h = health();
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
}

pub const CellHealth = struct {
    status: Status = .healthy,
    cycle: u32 = 0,
    last_check: i64 = 0,

    pub const Status = enum {
        healthy,
        weak,
        broken,
    };
};

pub fn health() CellHealth {
    return CellHealth{};
}
