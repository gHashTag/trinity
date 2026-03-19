// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// VENTROLATERAL PREFRONTAL CORTEX (VLPFC) — Attention Filter
// ═══════════════════════════════════════════════════════════════════════════════
// Neuro: Bridge perception↔action, suppress irrelevant stimuli
// Trinity: Filter — which Thalamus data matters NOW
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const qt = @import("queen_types.zig");
const thalamus = @import("thalamus.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// ATTENTION FILTER — What matters RIGHT NOW?
// ═══════════════════════════════════════════════════════════════════════════════

pub const FilterConfig = struct {
    focus: FocusArea = .all,
    suppress: []const []const u8 = &.{},
    max_relay_count: u8 = 3, // Top-N most relevant relays
};

pub const FocusArea = enum {
    all, // Show everything
    farm, // Focus on farm, suppress metabolism noise
    training, // Focus on PPL curves, suppress farm alerts
    github, // Focus on issues only
    self_check, // Focus on Queen health diagnostics
};

/// Filtered state — only relevant data
pub const FilteredState = struct {
    priority_relays: []PriorityRelay = &.{},
    priority_relays_allocated: []PriorityRelay = &.{}, // Store original allocation for freeing
    alert_count: u8 = 0,
    mood: qt.AlertKind = .build_broken, // Reuse as "primary concern"
    summary: [256]u8 = undefined,
    summary_len: usize = 0,

    pub fn deinit(self: *FilteredState, allocator: Allocator) void {
        for (self.priority_relays) |relay| {
            if (relay.value_is_owned) {
                allocator.free(relay.value);
            }
        }
        if (self.priority_relays_allocated.len > 0) {
            allocator.free(self.priority_relays_allocated);
        }
        self.priority_relays = &.{};
        self.priority_relays_allocated = &.{};
    }

    pub fn summaryStr(self: *const FilteredState) []const u8 {
        return self.summary[0..self.summary_len];
    }

    fn setSummary(self: *FilteredState, text: []const u8) void {
        const len = @min(text.len, self.summary.len);
        @memcpy(self.summary[0..len], text[0..len]);
        self.summary_len = len;
    }
};

pub const PriorityRelay = struct {
    name: []const u8,
    value: []const u8,
    score: f32, // 0-1 relevance
    value_is_owned: bool = false, // true if value was allocated and needs freeing
};

/// Filter Thalamus state by focus area
pub fn filterRelays(
    allocator: Allocator,
    config: FilterConfig,
) !FilteredState {
    var result = FilteredState{};

    // Allocate relay buffer
    var relays = try allocator.alloc(PriorityRelay, config.max_relay_count);
    errdefer allocator.free(relays);
    var relay_idx: usize = 0;

    // Query based on focus
    switch (config.focus) {
        .all => {
            // Sample top 3 from different domains
            if (relay_idx < config.max_relay_count) {
                const mu_hb = thalamus.getMuHeartbeat(allocator);
                relays[relay_idx] = .{
                    .name = "mu_heartbeat",
                    .value = try fmtHeartbeat(allocator, mu_hb.wake, mu_hb.age_s),
                    .score = 0.7,
                    .value_is_owned = true,
                };
                relay_idx += 1;
            }

            if (relay_idx < config.max_relay_count) {
                const snapshot = thalamus.getMetabolismSnapshot(allocator);
                if (snapshot) |snap| {
                    relays[relay_idx] = .{
                        .name = "metabolism",
                        .value = try fmtMetabolism(allocator, snap.ppl, snap.tok_per_sec),
                        .score = 0.8,
                        .value_is_owned = true,
                    };
                    relay_idx += 1;
                }
            }

            if (relay_idx < config.max_relay_count) {
                const cell_health = thalamus.getCellHealth(allocator);
                relays[relay_idx] = .{
                    .name = "cell_health",
                    .value = try fmtCellHealth(allocator, cell_health.total, cell_health.healthy),
                    .score = 0.6,
                    .value_is_owned = true,
                };
                relay_idx += 1;
            }
        },
        .farm => {
            // Focus on farm only
            const farm = try thalamus.getFarmStatus(allocator);
            relays[relay_idx] = .{
                .name = "farm_status",
                .value = try fmtFarmStatus(allocator, farm.total_services, farm.active, farm.best_ppl),
                .score = 1.0,
                .value_is_owned = true,
            };
            relay_idx += 1;
        },
        .training => {
            // Focus on PPL curves
            const snapshot = thalamus.getMetabolismSnapshot(allocator);
            if (snapshot) |snap| {
                relays[relay_idx] = .{
                    .name = "ppl_metrics",
                    .value = try fmtMetabolism(allocator, snap.ppl, snap.tok_per_sec),
                    .score = 1.0,
                    .value_is_owned = true,
                };
                relay_idx += 1;
            }
        },
        .github => {
            // Focus on issues
            const issues = try thalamus.getGitHubIssues(allocator);
            relays[relay_idx] = .{
                .name = "github_issues",
                .value = try fmtIssues(allocator, issues.open, issues.agent_spawn),
                .score = 1.0,
                .value_is_owned = true,
            };
            relay_idx += 1;
        },
        .self_check => {
            // Focus on Queen health
            relays[relay_idx] = .{
                .name = "queen_heartbeat",
                .value = "OK",
                .score = 1.0,
            };
            relay_idx += 1;
        },
    }

    result.priority_relays = relays[0..relay_idx];
    result.priority_relays_allocated = relays; // Store full allocation for cleanup
    result.setSummary("Filtered by focus area");
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// FORMAT HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn fmtHeartbeat(allocator: Allocator, wake: u32, age_s: i64) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "wake={d} age={d}s",
        .{ wake, age_s },
    );
}

fn fmtMetabolism(allocator: Allocator, ppl: f32, tok_per_sec: u32) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "ppl={d:.1} tok/s={d}",
        .{ ppl, tok_per_sec },
    );
}

fn fmtCellHealth(allocator: Allocator, total: u32, healthy: u32) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{d}/{d} healthy",
        .{ healthy, total },
    );
}

fn fmtFarmStatus(allocator: Allocator, total: usize, active: usize, best_ppl: f32) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{d}/{d} active best={d:.1}",
        .{ active, total, best_ppl },
    );
}

fn fmtIssues(allocator: Allocator, open: usize, spawn: usize) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{d} open {d} spawn",
        .{ open, spawn },
    );
}

// ═══════════════════════════════════════════════════════════════════════════════
// CELL HEALTH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn health() CellHealth {
    return CellHealth{
        .status = .healthy,
        .cycle = 0,
        .last_check = std.time.timestamp(),
    };
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

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "vlpfc — filterRelays all focus" {
    var result = try filterRelays(std.testing.allocator, .{ .focus = .all });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.priority_relays.len > 0);
    try std.testing.expect(result.summaryStr().len > 0);
}

test "vlpfc — filterRelays farm focus" {
    var result = try filterRelays(std.testing.allocator, .{ .focus = .farm });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.priority_relays.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, result.priority_relays[0].name, "farm") != null);
}

test "vlpfc — health returns healthy" {
    const h = health();
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
}

test "vlpfc — FilteredState setSummary truncates" {
    var state = FilteredState{};
    const long_text = "This is a very long summary that should be truncated to fit in the 256 byte array provided for the summary field";
    state.setSummary(long_text);

    try std.testing.expect(state.summary_len <= 256);
    try std.testing.expect(state.summaryStr().len > 0);
}

test "vlpfc — filterRelays training focus" {
    var result = try filterRelays(std.testing.allocator, .{ .focus = .training });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.priority_relays.len > 0);
    if (result.priority_relays.len > 0) {
        try std.testing.expect(std.mem.indexOf(u8, result.priority_relays[0].name, "ppl") != null);
    }
}

test "vlpfc — filterRelays github focus" {
    var result = try filterRelays(std.testing.allocator, .{ .focus = .github });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.priority_relays.len > 0);
    if (result.priority_relays.len > 0) {
        try std.testing.expect(std.mem.indexOf(u8, result.priority_relays[0].name, "github") != null);
    }
}

test "vlpfc — filterRelays self_check focus" {
    var result = try filterRelays(std.testing.allocator, .{ .focus = .self_check });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.priority_relays.len > 0);
    try std.testing.expectEqualStrings("queen_heartbeat", result.priority_relays[0].name);
}

test "vlpfc — FocusArea enum coverage" {
    const focus_areas = [_]FocusArea{ .all, .farm, .training, .github, .self_check };
    for (focus_areas) |fa| {
        _ = fa; // Just verify all enum values exist
    }
}

test "vlpfc — FilterConfig default values" {
    const config = FilterConfig{};
    try std.testing.expectEqual(FocusArea.all, config.focus);
    try std.testing.expectEqual(@as(usize, 0), config.suppress.len);
    try std.testing.expectEqual(@as(u8, 3), config.max_relay_count);
}

test "vlpfc — PriorityRelay struct fields" {
    const relay = PriorityRelay{
        .name = "test",
        .value = "value",
        .score = 0.5,
        .value_is_owned = false,
    };

    try std.testing.expectEqualStrings("test", relay.name);
    try std.testing.expectEqualStrings("value", relay.value);
    try std.testing.expectEqual(@as(f32, 0.5), relay.score);
    try std.testing.expect(!relay.value_is_owned);
}

test "vlpfc — FilteredState default initialization" {
    const state = FilteredState{};
    try std.testing.expectEqual(@as(usize, 0), state.priority_relays.len);
    try std.testing.expectEqual(@as(u8, 0), state.alert_count);
    try std.testing.expectEqual(qt.AlertKind.build_broken, state.mood);
    try std.testing.expectEqual(@as(usize, 0), state.summary_len);
}

test "vlpfc — FilteredState summaryStr returns slice" {
    var state = FilteredState{};
    state.setSummary("test");

    const summary = state.summaryStr();
    try std.testing.expectEqualStrings("test", summary);
    try std.testing.expect(summary.len > 0);
}

test "vlpfc — FilteredState setSummary empty" {
    var state = FilteredState{};
    state.setSummary("");

    try std.testing.expectEqual(@as(usize, 0), state.summary_len);
    try std.testing.expectEqual(@as(usize, 0), state.summaryStr().len);
}

test "vlpfc — CellHealth struct defaults" {
    const cell_health = CellHealth{};
    try std.testing.expectEqual(CellHealth.Status.healthy, cell_health.status);
    try std.testing.expectEqual(@as(u32, 0), cell_health.cycle);
    try std.testing.expectEqual(@as(i64, 0), cell_health.last_check);
}

test "vlpfc — CellHealth Status enum values" {
    const statuses = [_]CellHealth.Status{ .healthy, .weak, .broken };
    for (statuses) |s| {
        _ = s; // Verify all enum values exist
    }
}

test "vlpfc — filterRelays with max_relay_count=1" {
    const config = FilterConfig{
        .focus = .all,
        .max_relay_count = 1,
    };
    var result = try filterRelays(std.testing.allocator, config);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.priority_relays.len <= 1);
}

test "vlpfc — filterRelays with max_relay_count=10" {
    const config = FilterConfig{
        .focus = .all,
        .max_relay_count = 10,
    };
    var result = try filterRelays(std.testing.allocator, config);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.priority_relays.len <= 10);
}

test "vlpfc — PriorityRelay score range" {
    var result = try filterRelays(std.testing.allocator, .{ .focus = .all });
    defer result.deinit(std.testing.allocator);

    for (result.priority_relays) |relay| {
        try std.testing.expect(relay.score >= 0.0 and relay.score <= 1.0);
    }
}

test "vlpfc — FilteredState mood field" {
    var state = FilteredState{};
    state.mood = qt.AlertKind.new_ppl_record;
    try std.testing.expectEqual(qt.AlertKind.new_ppl_record, state.mood);
}

test "vlpfc — CellHealth from health() function" {
    const h = health();
    try std.testing.expect(h.last_check != 0); // Should have timestamp
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
}

test "vlpfc — FilterConfig suppress list mutability" {
    const suppress_list = &[_][]const u8{ "unused", "noise" };

    var config = FilterConfig{};
    config.suppress = suppress_list;
    config.max_relay_count = 5;

    try std.testing.expectEqual(@as(usize, 2), config.suppress.len);
    try std.testing.expectEqual(@as(u8, 5), config.max_relay_count);
}

test "vlpfc — FocusArea all values" {
    const areas = [_]FocusArea{ .all, .farm, .training, .github, .self_check };
    for (areas) |a| {
        _ = a; // Verify all focus areas exist
    }
}

test "vlpfc — PriorityRelay with owned value" {
    const relay = PriorityRelay{
        .name = "test_relay",
        .value = "test_value",
        .score = 0.75,
        .value_is_owned = true,
    };

    try std.testing.expectEqual(@as(f32, 0.75), relay.score);
    try std.testing.expect(relay.value_is_owned);
}

test "vlpfc — PriorityRelay with borrowed value" {
    const relay = PriorityRelay{
        .name = "borrowed",
        .value = "borrowed_value",
        .score = 0.5,
        .value_is_owned = false,
    };

    try std.testing.expect(!relay.value_is_owned);
    try std.testing.expectEqual(@as(f32, 0.5), relay.score);
}

test "vlpfc — FilteredState deinit handles empty" {
    var state = FilteredState{};
    state.deinit(std.testing.allocator);

    // Should not crash
}

test "vlpfc — FilteredState deinit with owned values" {
    var state = FilteredState{};
    state.priority_relays_allocated = try std.testing.allocator.alloc(PriorityRelay, 1);
    state.priority_relays = state.priority_relays_allocated;

    state.priority_relays[0] = PriorityRelay{
        .name = "owned",
        .value = try std.testing.allocator.dupe(u8, "allocated_value"),
        .score = 0.8,
        .value_is_owned = true,
    };

    state.deinit(std.testing.allocator);

    // Should free the allocated value
}

test "vlpfc — FilteredState alert count max" {
    var state = FilteredState{};
    state.alert_count = 255;

    try std.testing.expectEqual(@as(u8, 255), state.alert_count);
}

test "vlpfc — FilteredState mood all AlertKind values" {
    var state = FilteredState{};

    const moods = [_]qt.AlertKind{
        .build_broken,
        .new_ppl_record,
        .senior_killed,
        .arena_upset,
        .blocked_issue,
        .dirty_overload,
        .key_expired,
    };

    for (moods) |m| {
        state.mood = m;
        try std.testing.expectEqual(m, state.mood);
    }
}

test "vlpfc — FilteredState setSummary with exact fit" {
    var state = FilteredState{};
    const text = "exact fit";

    state.setSummary(text);

    try std.testing.expectEqual(@as(usize, text.len), state.summary_len);
    try std.testing.expectEqualStrings("exact fit", state.summaryStr());
}

test "vlpfc — FilteredState setSummary with truncation" {
    var state = FilteredState{};
    // Create text longer than summary array
    const long_text = "x" ** 300;

    state.setSummary(long_text);

    // Should be truncated to summary array size
    try std.testing.expectEqual(@as(usize, 256), state.summary_len);
}

test "vlpfc — CellHealth weak status" {
    const h = CellHealth{ .status = .weak };

    try std.testing.expectEqual(CellHealth.Status.weak, h.status);
    try std.testing.expectEqual(@as(i64, 0), h.last_check);
}

test "vlpfc — CellHealth broken status" {
    const h = CellHealth{ .status = .broken };

    try std.testing.expectEqual(CellHealth.Status.broken, h.status);
}

test "vlpfc — filterRelays with zero max_relay_count" {
    const config = FilterConfig{
        .focus = .all,
        .max_relay_count = 0,
    };

    var result = try filterRelays(std.testing.allocator, config);
    defer result.deinit(std.testing.allocator);

    // Should succeed (returns empty set)
    try std.testing.expectEqual(@as(usize, 0), result.priority_relays.len);
}

// ═══════════════════════════════════════════════════════════════════════════════
// FORMAT HELPER TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "vlpfc — fmtHeartbeat formats correctly" {
    const result = try fmtHeartbeat(std.testing.allocator, 42, 3600);
    defer std.testing.allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "wake=42") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "age=3600s") != null);
}

test "vlpfc — fmtHeartbeat with zero values" {
    const result = try fmtHeartbeat(std.testing.allocator, 0, 0);
    defer std.testing.allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "wake=0") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "age=0s") != null);
}

test "vlpfc — fmtHeartbeat with negative age" {
    const result = try fmtHeartbeat(std.testing.allocator, 10, -60);
    defer std.testing.allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "wake=10") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "age=-60s") != null);
}

test "vlpfc — fmtMetabolism formats correctly" {
    const result = try fmtMetabolism(std.testing.allocator, 3.14, 1000);
    defer std.testing.allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "ppl=") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "tok/s=1000") != null);
}

test "vlpfc — fmtMetabolism with zero PPL" {
    const result = try fmtMetabolism(std.testing.allocator, 0.0, 500);
    defer std.testing.allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "ppl=0.0") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "tok/s=500") != null);
}

test "vlpfc — fmtMetabolism with large values" {
    const result = try fmtMetabolism(std.testing.allocator, 999.99, 99999);
    defer std.testing.allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "ppl=") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "tok/s=99999") != null);
}

test "vlpfc — fmtCellHealth formats correctly" {
    const result = try fmtCellHealth(std.testing.allocator, 10, 8);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("8/10 healthy", result);
}

test "vlpfc — fmtCellHealth with zero healthy" {
    const result = try fmtCellHealth(std.testing.allocator, 5, 0);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("0/5 healthy", result);
}

test "vlpfc — fmtCellHealth with all healthy" {
    const result = try fmtCellHealth(std.testing.allocator, 7, 7);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("7/7 healthy", result);
}

test "vlpfc — fmtFarmStatus formats correctly" {
    const result = try fmtFarmStatus(std.testing.allocator, 100, 85, 3.5);
    defer std.testing.allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "85/100") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "best=3.5") != null);
}

test "vlpfc — fmtFarmStatus with zero active" {
    const result = try fmtFarmStatus(std.testing.allocator, 50, 0, 0.0);
    defer std.testing.allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "0/50") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "best=0.0") != null);
}

test "vlpfc — fmtFarmStatus with all active" {
    const result = try fmtFarmStatus(std.testing.allocator, 10, 10, 2.5);
    defer std.testing.allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "10/10") != null);
}

test "vlpfc — fmtIssues formats correctly" {
    const result = try fmtIssues(std.testing.allocator, 15, 3);
    defer std.testing.allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "15 open") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "3 spawn") != null);
}

test "vlpfc — fmtIssues with zero issues" {
    const result = try fmtIssues(std.testing.allocator, 0, 0);
    defer std.testing.allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "0 open") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "0 spawn") != null);
}

test "vlpfc — fmtIssues with spawn count only" {
    const result = try fmtIssues(std.testing.allocator, 5, 5);
    defer std.testing.allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "5 open") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "5 spawn") != null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CELL HEALTH EXTENDED TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "vlpfc — CellHealth with custom timestamp" {
    const timestamp: i64 = 1710800000;
    const h = CellHealth{
        .status = .healthy,
        .cycle = 5,
        .last_check = timestamp,
    };

    try std.testing.expectEqual(timestamp, h.last_check);
    try std.testing.expectEqual(@as(u32, 5), h.cycle);
}

test "vlpfc — CellHealth with max cycle value" {
    const h = CellHealth{
        .status = .weak,
        .cycle = std.math.maxInt(u32),
    };

    try std.testing.expectEqual(std.math.maxInt(u32), h.cycle);
}

test "vlpfc — CellHealth Status healthy" {
    const h = CellHealth{ .status = .healthy };
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
}

test "vlpfc — CellHealth Status weak" {
    const h = CellHealth{ .status = .weak };
    try std.testing.expectEqual(CellHealth.Status.weak, h.status);
}

test "vlpfc — CellHealth Status broken" {
    const h = CellHealth{ .status = .broken };
    try std.testing.expectEqual(CellHealth.Status.broken, h.status);
}

test "vlpfc — CellHealth all fields zero" {
    const h = CellHealth{};
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status); // default
    try std.testing.expectEqual(@as(u32, 0), h.cycle);
    try std.testing.expectEqual(@as(i64, 0), h.last_check);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRIORITY RELAY EDGE CASES
// ═══════════════════════════════════════════════════════════════════════════════

test "vlpfc — PriorityRelay with minimum score" {
    const relay = PriorityRelay{
        .name = "min_score",
        .value = "value",
        .score = 0.0,
    };

    try std.testing.expectEqual(@as(f32, 0.0), relay.score);
}

test "vlpfc — PriorityRelay with maximum score" {
    const relay = PriorityRelay{
        .name = "max_score",
        .value = "value",
        .score = 1.0,
    };

    try std.testing.expectEqual(@as(f32, 1.0), relay.score);
}

test "vlpfc — PriorityRelay with empty name" {
    const relay = PriorityRelay{
        .name = "",
        .value = "value",
        .score = 0.5,
    };

    try std.testing.expectEqual(@as(usize, 0), relay.name.len);
}

test "vlpfc — PriorityRelay with empty value" {
    const relay = PriorityRelay{
        .name = "test",
        .value = "",
        .score = 0.5,
    };

    try std.testing.expectEqual(@as(usize, 0), relay.value.len);
}

test "vlpfc — PriorityRelay default value_is_owned" {
    const relay = PriorityRelay{
        .name = "test",
        .value = "value",
        .score = 0.5,
    };

    try std.testing.expect(!relay.value_is_owned); // default is false
}

// ═══════════════════════════════════════════════════════════════════════════════
// FILTERED STATE DEINIT WITH MIXED VALUES
// ═══════════════════════════════════════════════════════════════════════════════

test "vlpfc — FilteredState deinit with mixed owned/borrowed" {
    var state = FilteredState{};
    state.priority_relays_allocated = try std.testing.allocator.alloc(PriorityRelay, 3);
    state.priority_relays = state.priority_relays_allocated;

    // Mix of owned and borrowed values
    state.priority_relays[0] = PriorityRelay{
        .name = "owned1",
        .value = try std.testing.allocator.dupe(u8, "allocated1"),
        .score = 0.8,
        .value_is_owned = true,
    };
    state.priority_relays[1] = PriorityRelay{
        .name = "borrowed",
        .value = "static_string",
        .score = 0.5,
        .value_is_owned = false,
    };
    state.priority_relays[2] = PriorityRelay{
        .name = "owned2",
        .value = try std.testing.allocator.dupe(u8, "allocated2"),
        .score = 0.9,
        .value_is_owned = true,
    };

    state.deinit(std.testing.allocator);
    // Should free only owned values
}

test "vlpfc — FilteredState deinit with all borrowed" {
    var state = FilteredState{};
    state.priority_relays_allocated = try std.testing.allocator.alloc(PriorityRelay, 2);
    state.priority_relays = state.priority_relays_allocated;

    state.priority_relays[0] = PriorityRelay{
        .name = "borrowed1",
        .value = "static1",
        .score = 0.5,
        .value_is_owned = false,
    };
    state.priority_relays[1] = PriorityRelay{
        .name = "borrowed2",
        .value = "static2",
        .score = 0.6,
        .value_is_owned = false,
    };

    state.deinit(std.testing.allocator);
    // Should not crash - no owned values to free
}

test "vlpfc — FilteredState deinit multiple times" {
    var state = FilteredState{};
    state.priority_relays_allocated = try std.testing.allocator.alloc(PriorityRelay, 1);
    state.priority_relays = state.priority_relays_allocated;
    state.priority_relays[0] = PriorityRelay{
        .name = "test",
        .value = try std.testing.allocator.dupe(u8, "owned"),
        .score = 0.7,
        .value_is_owned = true,
    };

    state.deinit(std.testing.allocator);
    state.deinit(std.testing.allocator);
    // Second deinit should be safe (slices are now empty)
}

// ═══════════════════════════════════════════════════════════════════════════════
// FOCUS AREA RELAY NAME VERIFICATION
// ═══════════════════════════════════════════════════════════════════════════════

test "vlpfc — filterRelays farm returns farm_status relay" {
    var result = try filterRelays(std.testing.allocator, .{ .focus = .farm });
    defer result.deinit(std.testing.allocator);

    if (result.priority_relays.len > 0) {
        try std.testing.expectEqualStrings("farm_status", result.priority_relays[0].name);
    }
}

test "vlpfc — filterRelays training returns ppl_metrics relay" {
    var result = try filterRelays(std.testing.allocator, .{ .focus = .training });
    defer result.deinit(std.testing.allocator);

    if (result.priority_relays.len > 0) {
        try std.testing.expectEqualStrings("ppl_metrics", result.priority_relays[0].name);
    }
}

test "vlpfc — filterRelays github returns github_issues relay" {
    var result = try filterRelays(std.testing.allocator, .{ .focus = .github });
    defer result.deinit(std.testing.allocator);

    if (result.priority_relays.len > 0) {
        try std.testing.expectEqualStrings("github_issues", result.priority_relays[0].name);
    }
}

test "vlpfc — filterRelays self_check returns queen_heartbeat" {
    var result = try filterRelays(std.testing.allocator, .{ .focus = .self_check });
    defer result.deinit(std.testing.allocator);

    if (result.priority_relays.len > 0) {
        try std.testing.expectEqualStrings("queen_heartbeat", result.priority_relays[0].name);
    }
}

test "vlpfc — filterRelays all includes multiple relay types" {
    var result = try filterRelays(std.testing.allocator, .{ .focus = .all });
    defer result.deinit(std.testing.allocator);

    // Should have relays from different domains
    var found_heartbeat = false;
    var found_metabolism = false;
    var found_cell_health = false;

    for (result.priority_relays) |relay| {
        if (std.mem.indexOf(u8, relay.name, "heartbeat") != null) found_heartbeat = true;
        if (std.mem.indexOf(u8, relay.name, "metabolism") != null) found_metabolism = true;
        if (std.mem.indexOf(u8, relay.name, "health") != null) found_cell_health = true;
    }

    // At least one should be found
    try std.testing.expect(found_heartbeat or found_metabolism or found_cell_health);
}

// ═══════════════════════════════════════════════════════════════════════════════
// FILTER CONFIG VARIATIONS
// ═══════════════════════════════════════════════════════════════════════════════

test "vlpfc — FilterConfig with custom focus" {
    var config = FilterConfig{};
    config.focus = .training;

    try std.testing.expectEqual(FocusArea.training, config.focus);
}

test "vlpfc — FilterConfig with suppress list" {
    const suppress_items = &[_][]const u8{ "noise1", "noise2", "noise3" };
    const config = FilterConfig{
        .focus = .all,
        .suppress = suppress_items,
        .max_relay_count = 5,
    };

    try std.testing.expectEqual(@as(usize, 3), config.suppress.len);
    try std.testing.expectEqual(@as(u8, 5), config.max_relay_count);
}

test "vlpfc — FilterConfig with max_relay_count variations" {
    const counts = [_]u8{ 0, 1, 5, 10, 100, 255 };

    for (counts) |count| {
        const config = FilterConfig{
            .focus = .all,
            .max_relay_count = count,
        };
        try std.testing.expectEqual(count, config.max_relay_count);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ALERT KIND COVERAGE
// ═══════════════════════════════════════════════════════════════════════════════

test "vlpfc — FilteredState mood build_broken" {
    var state = FilteredState{};
    state.mood = qt.AlertKind.build_broken;
    try std.testing.expectEqual(qt.AlertKind.build_broken, state.mood);
}

test "vlpfc — FilteredState mood new_ppl_record" {
    var state = FilteredState{};
    state.mood = qt.AlertKind.new_ppl_record;
    try std.testing.expectEqual(qt.AlertKind.new_ppl_record, state.mood);
}

test "vlpfc — FilteredState mood senior_killed" {
    var state = FilteredState{};
    state.mood = qt.AlertKind.senior_killed;
    try std.testing.expectEqual(qt.AlertKind.senior_killed, state.mood);
}

test "vlpfc — FilteredState mood arena_upset" {
    var state = FilteredState{};
    state.mood = qt.AlertKind.arena_upset;
    try std.testing.expectEqual(qt.AlertKind.arena_upset, state.mood);
}

test "vlpfc — FilteredState mood blocked_issue" {
    var state = FilteredState{};
    state.mood = qt.AlertKind.blocked_issue;
    try std.testing.expectEqual(qt.AlertKind.blocked_issue, state.mood);
}

test "vlpfc — FilteredState mood dirty_overload" {
    var state = FilteredState{};
    state.mood = qt.AlertKind.dirty_overload;
    try std.testing.expectEqual(qt.AlertKind.dirty_overload, state.mood);
}

test "vlpfc — FilteredState mood key_expired" {
    var state = FilteredState{};
    state.mood = qt.AlertKind.key_expired;
    try std.testing.expectEqual(qt.AlertKind.key_expired, state.mood);
}
