// @origin(spec:dev_pick.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// dev_pick v1.0.0 — Smart issue selection with experience-weighted ranking
// ═══════════════════════════════════════════════════════════════════════════════
//
// tri dev pick [--smart|--fifo|--priority|--random]
//
// Experience-weighted ranking:
//   base_score (from priority) ± experience boost/penalty ± MNL ± doctor bonus
//
// MNL anti-pattern: fail_count >= 3 → score × 0.3
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("tri_colors.zig");
const dev_scan = @import("dev_scan.zig");
const tri_experience = @import("tri_experience.zig");

const Allocator = std.mem.Allocator;
const print = std.debug.print;

const GREEN = colors.GREEN;
const GOLDEN = colors.GOLDEN;
const RED = colors.RED;
const CYAN = colors.CYAN;
const GRAY = colors.GRAY;
const RESET = colors.RESET;
const YELLOW = "\x1b[38;2;255;255;0m";
const DIM = "\x1b[38;2;156;156;160m";

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const PickStrategy = enum {
    fifo,
    priority,
    smart,
    random,

    pub fn label(self: PickStrategy) []const u8 {
        return switch (self) {
            .fifo => "FIFO",
            .priority => "PRIORITY",
            .smart => "SMART",
            .random => "RANDOM",
        };
    }
};

pub const PickReason = struct {
    factor: [32]u8 = undefined,
    factor_len: usize = 0,
    weight: f32 = 0,
    detail: [64]u8 = undefined,
    detail_len: usize = 0,

    pub fn factorStr(self: *const PickReason) []const u8 {
        return self.factor[0..self.factor_len];
    }

    pub fn detailStr(self: *const PickReason) []const u8 {
        return self.detail[0..self.detail_len];
    }

    fn setFactor(self: *PickReason, text: []const u8) void {
        const len = @min(text.len, self.factor.len);
        @memcpy(self.factor[0..len], text[0..len]);
        self.factor_len = len;
    }

    fn setDetail(self: *PickReason, text: []const u8) void {
        const len = @min(text.len, self.detail.len);
        @memcpy(self.detail[0..len], text[0..len]);
        self.detail_len = len;
    }
};

const MAX_REASONS = 8;

pub const PickResult = struct {
    chosen_idx: usize = 0,
    strategy: PickStrategy = .smart,
    final_score: f32 = 0,
    reasons: [MAX_REASONS]PickReason = undefined,
    reason_count: usize = 0,
    alternatives: [3]usize = .{ 0, 0, 0 },
    alt_count: usize = 0,
    skipped_mnl: u32 = 0,

    pub fn addReason(self: *PickResult, factor: []const u8, weight: f32, detail: []const u8) void {
        if (self.reason_count < MAX_REASONS) {
            var r = PickReason{};
            r.setFactor(factor);
            r.weight = weight;
            r.setDetail(detail);
            self.reasons[self.reason_count] = r;
            self.reason_count += 1;
        }
    }
};

// Scored item for ranking
const ScoredItem = struct {
    idx: usize,
    score: f32,
};

// ═══════════════════════════════════════════════════════════════════════════════
// BEHAVIORS
// ═══════════════════════════════════════════════════════════════════════════════

/// Load scan results from .trinity/scan_results.json
/// If file missing or empty, returns null (caller should trigger scan)
fn loadScanResults() ?dev_scan.ScanResult {
    const file = std.fs.cwd().openFile(".trinity/scan_results.json", .{}) catch return null;
    defer file.close();

    const stat = file.stat() catch return null;
    if (stat.size < 10) return null;

    // Check staleness: >1h old = stale
    const now = std.time.timestamp();
    const mtime: i64 = @intCast(@divTrunc(stat.mtime, std.time.ns_per_s));
    if (now - mtime > 3600) return null;

    // Parse the JSON scan results
    var result = dev_scan.ScanResult{};

    var buf: [65536]u8 = undefined;
    const n = file.readAll(&buf) catch return null;
    const content = buf[0..n];

    // Simple JSON array parser: find each {"source":..., "id":..., "title":..., "priority":...}
    var pos: usize = 0;
    while (pos < content.len and result.count < 64) {
        // Find next object
        const obj_start = std.mem.indexOfPos(u8, content, pos, "{") orelse break;
        const obj_end = std.mem.indexOfPos(u8, content, obj_start, "}") orelse break;
        const obj = content[obj_start .. obj_end + 1];

        var item = dev_scan.ScanItem{};

        // Extract id
        if (extractJsonString(obj, "\"id\":\"")) |id| {
            item.setId(id);
        }

        // Extract title
        if (extractJsonString(obj, "\"title\":\"")) |title| {
            item.setTitle(title);
        }

        // Extract priority
        if (extractJsonString(obj, "\"priority\":\"")) |pri| {
            item.priority = parsePriority(pri);
        }

        // Extract source
        if (extractJsonString(obj, "\"source\":\"")) |src| {
            item.source = parseSource(src);
        }

        if (item.id_len > 0) {
            result.addItem(item);
        }

        pos = obj_end + 1;
    }

    return result;
}

fn extractJsonString(json: []const u8, needle: []const u8) ?[]const u8 {
    const start = std.mem.indexOf(u8, json, needle) orelse return null;
    const val_start = start + needle.len;
    const val_end = std.mem.indexOfPos(u8, json, val_start, "\"") orelse return null;
    return json[val_start..val_end];
}

fn parsePriority(s: []const u8) dev_scan.Priority {
    if (std.mem.eql(u8, s, "critical")) return .critical;
    if (std.mem.eql(u8, s, "high")) return .high;
    if (std.mem.eql(u8, s, "medium")) return .medium;
    if (std.mem.eql(u8, s, "low")) return .low;
    return .backlog;
}

fn parseSource(s: []const u8) dev_scan.ScanSource {
    if (std.mem.eql(u8, s, "github_issues")) return .github_issues;
    if (std.mem.eql(u8, s, "dirty_files")) return .dirty_files;
    if (std.mem.eql(u8, s, "doctor_violations")) return .doctor_violations;
    if (std.mem.eql(u8, s, "pipeline_failures")) return .pipeline_failures;
    return .github_issues;
}

/// Base score from priority
fn baseScore(pri: dev_scan.Priority) f32 {
    return switch (pri) {
        .critical => 100.0,
        .high => 80.0,
        .medium => 60.0,
        .low => 40.0,
        .backlog => 20.0,
    };
}

/// FIFO: sort by creation date (oldest first)
pub fn pickFifo(result: *const dev_scan.ScanResult) PickResult {
    var pick = PickResult{ .strategy = .fifo };
    if (result.count == 0) return pick;

    // Just take first item (already sorted by priority from scan)
    pick.chosen_idx = 0;
    pick.final_score = baseScore(result.items[0].priority);
    pick.addReason("fifo", pick.final_score, "First in queue");
    return pick;
}

/// Priority: highest priority, lowest fail_count
pub fn pickPriority(result: *const dev_scan.ScanResult) PickResult {
    var pick = PickResult{ .strategy = .priority };
    if (result.count == 0) return pick;

    // Items already sorted by priority from scan
    pick.chosen_idx = 0;
    pick.final_score = baseScore(result.items[0].priority);
    pick.addReason("priority", pick.final_score, result.items[0].priority.tag());

    // Add alternatives
    var alt_i: usize = 0;
    for (1..@min(result.count, 4)) |i| {
        pick.alternatives[alt_i] = i;
        alt_i += 1;
    }
    pick.alt_count = alt_i;
    return pick;
}

/// Smart: experience-weighted ranking with MNL anti-pattern
pub fn pickSmart(result: *const dev_scan.ScanResult) PickResult {
    var pick = PickResult{ .strategy = .smart };
    if (result.count == 0) return pick;

    var scored: [64]ScoredItem = undefined;
    var scored_count: usize = 0;

    for (0..result.count) |i| {
        const item = &result.items[i];
        var score = baseScore(item.priority);
        var reasons_buf: [4]PickReason = undefined;
        var reason_count: usize = 0;

        // (1) Base score
        {
            var r = PickReason{};
            r.setFactor("base_priority");
            r.weight = score;
            r.setDetail(item.priority.tag());
            reasons_buf[reason_count] = r;
            reason_count += 1;
        }

        // (2) MNL pattern: fail_count >= 3 → heavy penalty
        if (item.fail_count >= 3) {
            const penalty = score * 0.7; // reduce to 30% of original
            score -= penalty;
            pick.skipped_mnl += 1;
            var r = PickReason{};
            r.setFactor("mnl_penalty");
            r.weight = -penalty;
            r.setDetail("3+ failures, deprioritized");
            reasons_buf[reason_count] = r;
            reason_count += 1;
        } else if (item.fail_count > 0) {
            const penalty: f32 = @as(f32, @floatFromInt(item.fail_count)) * 10.0;
            score -= penalty;
        }

        // (3) Doctor bonus: fixing doctor violations gets +15
        if (item.source == .doctor_violations) {
            score += 15.0;
            var r = PickReason{};
            r.setFactor("doctor_bonus");
            r.weight = 15.0;
            r.setDetail("Fixes codebase health");
            reasons_buf[reason_count] = r;
            reason_count += 1;
        }

        // (4) Dirty file urgency: dirty files with high count = urgent
        if (item.source == .dirty_files) {
            score += 10.0;
        }

        scored[scored_count] = ScoredItem{ .idx = i, .score = score };
        scored_count += 1;
    }

    // Sort by score descending
    std.mem.sort(ScoredItem, scored[0..scored_count], {}, struct {
        fn lessThan(_: void, a: ScoredItem, b: ScoredItem) bool {
            return a.score > b.score;
        }
    }.lessThan);

    // Best pick
    pick.chosen_idx = scored[0].idx;
    pick.final_score = scored[0].score;

    // Add top reasons for chosen item
    const chosen = &result.items[pick.chosen_idx];
    pick.addReason("base_priority", baseScore(chosen.priority), chosen.priority.tag());
    if (chosen.fail_count >= 3) {
        pick.addReason("mnl_penalty", -baseScore(chosen.priority) * 0.7, "3+ past failures");
    }
    if (chosen.source == .doctor_violations) {
        pick.addReason("doctor_bonus", 15.0, "Fixes codebase health");
    }

    // Alternatives (next 3)
    var alt_i: usize = 0;
    for (1..@min(scored_count, 4)) |i| {
        pick.alternatives[alt_i] = scored[i].idx;
        alt_i += 1;
    }
    pick.alt_count = alt_i;

    return pick;
}

/// Random: pick from medium priority or lower
pub fn pickRandom(result: *const dev_scan.ScanResult) PickResult {
    var pick = PickResult{ .strategy = .random };
    if (result.count == 0) return pick;

    // Filter to medium+ items
    var candidates: [64]usize = undefined;
    var cand_count: usize = 0;
    for (0..result.count) |i| {
        if (@intFromEnum(result.items[i].priority) <= @intFromEnum(dev_scan.Priority.medium)) {
            candidates[cand_count] = i;
            cand_count += 1;
        }
    }

    if (cand_count == 0) {
        // Fallback: pick first
        pick.chosen_idx = 0;
        pick.final_score = baseScore(result.items[0].priority);
        pick.addReason("random_fallback", pick.final_score, "No medium+ items");
        return pick;
    }

    // Simple "random" based on timestamp
    const ts: u64 = @intCast(std.time.timestamp());
    const idx = ts % cand_count;
    pick.chosen_idx = candidates[idx];
    pick.final_score = baseScore(result.items[pick.chosen_idx].priority);
    pick.addReason("random", pick.final_score, "Exploration pick");
    return pick;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RENDER
// ═══════════════════════════════════════════════════════════════════════════════

fn renderPick(result: *const dev_scan.ScanResult, pick: *const PickResult) void {
    if (result.count == 0) {
        print("\n{s}No items to pick from. Run tri dev scan first.{s}\n\n", .{ RED, RESET });
        return;
    }

    const chosen = &result.items[pick.chosen_idx];
    const score_int: u32 = @intFromFloat(pick.final_score);

    print("\n{s}DEV PICK{s} [{s}{s}{s}]\n", .{ GOLDEN, RESET, CYAN, pick.strategy.label(), RESET });
    print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    // Chosen item
    print("  {s}PICKED:{s} {s}{s}{s} {s}{s}{s} (score: {d})\n\n", .{
        GREEN,
        RESET,
        GOLDEN,
        chosen.idStr(),
        RESET,
        GREEN,
        chosen.titleStr(),
        RESET,
        score_int,
    });

    // Reasons table
    if (pick.reason_count > 0) {
        print("  {s}Factor              Weight   Detail{s}\n", .{ DIM, RESET });
        print("  {s}──────────────────  ───────  ──────────────────{s}\n", .{ DIM, RESET });
        for (0..pick.reason_count) |i| {
            const r = &pick.reasons[i];
            const w_int: i32 = @intFromFloat(r.weight);
            const sign: []const u8 = if (r.weight >= 0) "+" else "";
            print("  {s}{s: <18}{s}  {s}{s}{d: >5}{s}  {s}\n", .{
                CYAN,
                r.factorStr(),
                RESET,
                if (r.weight >= 0) GREEN else RED,
                sign,
                w_int,
                RESET,
                r.detailStr(),
            });
        }
        print("\n", .{});
    }

    // Alternatives
    if (pick.alt_count > 0) {
        print("  {s}Alternatives:{s}\n", .{ DIM, RESET });
        for (0..pick.alt_count) |i| {
            const alt = &result.items[pick.alternatives[i]];
            const alt_score = baseScore(alt.priority);
            const alt_score_int: u32 = @intFromFloat(alt_score);
            print("    {s}#{d}{s} {s} ({d})\n", .{
                GRAY,
                i + 2,
                RESET,
                alt.titleStr(),
                alt_score_int,
            });
        }
        print("\n", .{});
    }

    // MNL skips
    if (pick.skipped_mnl > 0) {
        print("  {s}MNL:{s} {d} items deprioritized (3+ past failures)\n\n", .{ YELLOW, RESET, pick.skipped_mnl });
    }

    print("{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI ENTRYPOINT
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runPickCommand(allocator: Allocator, args: []const []const u8) void {
    // Parse strategy from args
    var strategy = PickStrategy.smart; // default
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--fifo")) {
            strategy = .fifo;
        } else if (std.mem.eql(u8, arg, "--priority")) {
            strategy = .priority;
        } else if (std.mem.eql(u8, arg, "--smart")) {
            strategy = .smart;
        } else if (std.mem.eql(u8, arg, "--random")) {
            strategy = .random;
        }
    }

    // Collect scan results directly (no file I/O)
    print("{s}Scanning...{s}\n", .{ DIM, RESET });
    var result = dev_scan.collectScanResults(allocator);

    if (result.count == 0) {
        print("\n{s}Nothing to pick — scan returned 0 items{s}\n\n", .{ GREEN, RESET });
        return;
    }

    // Apply strategy
    const pick = switch (strategy) {
        .fifo => pickFifo(&result),
        .priority => pickPriority(&result),
        .smart => pickSmart(&result),
        .random => pickRandom(&result),
    };

    renderPick(&result, &pick);

    // Save pick result for dev loop RESEARCH phase
    savePickResult(&result, &pick);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SAVE PICK RESULT
// ═══════════════════════════════════════════════════════════════════════════════

/// Save pick result to .trinity/pick_result.json
/// Used by dev_loop RESEARCH phase to load context
fn savePickResult(result: *const dev_scan.ScanResult, pick: *const PickResult) void {
    if (result.count == 0 or pick.chosen_idx >= result.count) return;

    std.fs.cwd().makePath(".trinity") catch return;

    const file = std.fs.cwd().createFile(".trinity/pick_result.json", .{}) catch return;
    defer file.close();

    const chosen = &result.items[pick.chosen_idx];
    const score_int: u32 = @intFromFloat(pick.final_score);
    const timestamp = std.time.timestamp();

    // Manual JSON string escaping (Zig 0.15 doesn't have jsonEscape)
    var id_escaped: [128]u8 = undefined;
    var id_len: usize = 0;
    for (chosen.idStr()) |c| {
        if (c == '"') {
            id_escaped[id_len] = '\\';
            id_escaped[id_len + 1] = '"';
            id_len += 2;
        } else if (c == '\\') {
            id_escaped[id_len] = '\\';
            id_escaped[id_len + 1] = '\\';
            id_len += 2;
        } else {
            id_escaped[id_len] = c;
            id_len += 1;
        }
    }

    var title_escaped: [512]u8 = undefined;
    var title_len: usize = 0;
    for (chosen.titleStr()) |c| {
        if (c == '"') {
            title_escaped[title_len] = '\\';
            title_escaped[title_len + 1] = '"';
            title_len += 2;
        } else if (c == '\\') {
            title_escaped[title_len] = '\\';
            title_escaped[title_len + 1] = '\\';
            title_len += 2;
        } else if (c == '\n') {
            title_escaped[title_len] = '\\';
            title_escaped[title_len + 1] = 'n';
            title_len += 2;
        } else if (c == '\r') {
            title_escaped[title_len] = '\\';
            title_escaped[title_len + 1] = 'r';
            title_len += 2;
        } else if (c == '\t') {
            title_escaped[title_len] = '\\';
            title_escaped[title_len + 1] = 't';
            title_len += 2;
        } else {
            title_escaped[title_len] = c;
            title_len += 1;
        }
    }

    var buf: [2048]u8 = undefined;
    const content = std.fmt.bufPrint(&buf,
        \\{{
        \\  "chosen_idx":{d},
        \\  "strategy":"{s}",
        \\  "final_score":{d},
        \\  "skipped_mnl":{d},
        \\  "picked":{{
        \\    "id":"{s}",
        \\    "title":"{s}",
        \\    "priority":"{s}",
        \\    "source":"{s}",
        \\    "fail_count":{d}
        \\  }},
        \\  "timestamp":{d}
        \\}}
    , .{
        pick.chosen_idx,
        pick.strategy.label(),
        score_int,
        pick.skipped_mnl,
        id_escaped[0..id_len],
        title_escaped[0..title_len],
        chosen.priority.tag(),
        chosen.source.label(),
        chosen.fail_count,
        timestamp,
    }) catch return;

    file.writeAll(content) catch return;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "smart_mnl_penalty" {
    var result = dev_scan.ScanResult{};

    // High priority but 3 failures
    var item1 = dev_scan.ScanItem{ .priority = .high, .fail_count = 3 };
    item1.setId("#100");
    item1.setTitle("Failed task");

    // Medium priority, 0 failures
    var item2 = dev_scan.ScanItem{ .priority = .medium, .fail_count = 0 };
    item2.setId("#101");
    item2.setTitle("Fresh task");

    result.addItem(item1);
    result.addItem(item2);

    const pick = pickSmart(&result);
    // Medium with 0 failures should beat high with 3 failures (MNL penalty)
    try std.testing.expectEqual(@as(usize, 1), pick.chosen_idx);
    try std.testing.expect(pick.skipped_mnl > 0);
}

test "priority_pick" {
    var result = dev_scan.ScanResult{};

    var low = dev_scan.ScanItem{ .priority = .low };
    low.setId("#1");
    low.setTitle("Low task");

    var crit = dev_scan.ScanItem{ .priority = .critical };
    crit.setId("#2");
    crit.setTitle("Critical task");

    result.addItem(low);
    result.addItem(crit);
    result.sort();

    const pick = pickPriority(&result);
    try std.testing.expectEqual(dev_scan.Priority.critical, result.items[pick.chosen_idx].priority);
}

test "empty_scan" {
    const result = dev_scan.ScanResult{};
    const pick = pickSmart(&result);
    try std.testing.expectEqual(@as(f32, 0), pick.final_score);
}

test "doctor_bonus" {
    var result = dev_scan.ScanResult{};

    var issue = dev_scan.ScanItem{ .priority = .medium, .source = .github_issues };
    issue.setId("#10");
    issue.setTitle("Normal issue");

    var doctor = dev_scan.ScanItem{ .priority = .medium, .source = .doctor_violations };
    doctor.setId("DR1");
    doctor.setTitle("Doctor fix");

    result.addItem(issue);
    result.addItem(doctor);

    const pick = pickSmart(&result);
    // Doctor item should score higher due to +15 bonus
    try std.testing.expectEqual(@as(usize, 1), pick.chosen_idx);
}
