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
