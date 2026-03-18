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
    priority_relays: []const PriorityRelay = &.{},
    alert_count: u8 = 0,
    mood: qt.AlertKind = .build_broken, // Reuse as "primary concern"
    summary: [256]u8 = undefined,
    summary_len: usize = 0,

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
                    };
                    relay_idx += 1;
                }
            }

            if (relay_idx < config.max_relay_count) {
                const health = thalamus.getCellHealth(allocator);
                relays[relay_idx] = .{
                    .name = "cell_health",
                    .value = try fmtCellHealth(allocator, health.total, health.healthy),
                    .score = 0.6,
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
    const result = try filterRelays(std.testing.allocator, .{ .focus = .all });
    defer std.testing.allocator.free(result.priority_relays);

    try std.testing.expect(result.priority_relays.len > 0);
    try std.testing.expect(result.summaryStr().len > 0);
}

test "vlpfc — filterRelays farm focus" {
    const result = try filterRelays(std.testing.allocator, .{ .focus = .farm });
    defer {
        for (result.priority_relays) |r| {
            std.testing.allocator.free(r.value);
        }
        std.testing.allocator.free(result.priority_relays);
    }

    try std.testing.expect(result.priority_relays.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, result.priority_relays[0].name, "farm") != null);
}

test "vlpfc — health returns healthy" {
    const h = health();
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
}
