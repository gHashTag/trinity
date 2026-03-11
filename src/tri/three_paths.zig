// ═══════════════════════════════════════════════════════════════════════════════
// Three Paths — Path generator for Faculty Board
// ═══════════════════════════════════════════════════════════════════════════════
// Generates 3 prioritized action paths: SAFE, BALANCED, BOLD.
// No allocations — uses static string slices.
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("faculty_types.zig");
const FacultySnapshot = types.FacultySnapshot;

pub const Path = struct {
    tier: Tier,
    label: []const u8,
    action: []const u8,

    pub const Tier = enum {
        safe,
        balanced,
        bold,

        pub fn emoji(self: Tier) []const u8 {
            return switch (self) {
                .safe => "🅰️",
                .balanced => "🅱️",
                .bold => "🅲",
            };
        }

        pub fn name(self: Tier) []const u8 {
            return switch (self) {
                .safe => "SAFE",
                .balanced => "BALANCED",
                .bold => "BOLD",
            };
        }
    };
};

/// Generate 3 prioritized action paths based on current system state.
pub fn generatePaths(snapshot: FacultySnapshot, paths: *[3]Path) void {
    const active = snapshot.activeFaculty();

    // === PATH A: SAFE (low risk, immediate value) ===
    if (!snapshot.build_ok) {
        paths[0] = .{ .tier = .safe, .label = "Починить сборку", .action = "zig build 2>&1 | head -20 → fix errors" };
    } else if (snapshot.compile_rate < 80) {
        paths[0] = .{ .tier = .safe, .label = "Починить генератор", .action = "tri verify → fix failing specs" };
    } else if (snapshot.dirty_files > 15) {
        paths[0] = .{ .tier = .safe, .label = "Зафиксировать прогресс", .action = "git add -A && git commit" };
    } else {
        paths[0] = .{ .tier = .safe, .label = "Прогнать тесты", .action = "zig build test" };
    }

    // === PATH B: BALANCED (moderate effort, good ROI) ===
    if (active < 6) {
        // Find first non-active agent to wake
        const next_agent = findNextAgent(snapshot);
        paths[1] = .{ .tier = .balanced, .label = next_agent.label, .action = next_agent.action };
    } else if (snapshot.compile_rate < 95) {
        paths[1] = .{ .tier = .balanced, .label = "Довести compile до 95%+", .action = "tri verify → fix remaining specs" };
    } else {
        paths[1] = .{ .tier = .balanced, .label = "Почистить dirty файлы", .action = "git status → stage & commit" };
    }

    // === PATH C: BOLD (transformative, high effort) ===
    if (active <= 3) {
        paths[2] = .{ .tier = .bold, .label = "Запустить Swarm оркестрацию", .action = "Implement #75 → multi-agent routing" };
    } else if (snapshot.open_issues > 20) {
        paths[2] = .{ .tier = .bold, .label = "Автоматизировать issue-triage", .action = "Scholar + MU → auto-label & prioritize" };
    } else {
        paths[2] = .{ .tier = .bold, .label = "A2A Federation", .action = "Connect Trinity swarm to external A2A agents" };
    }
}

const NextAgent = struct { label: []const u8, action: []const u8 };

fn findNextAgent(snapshot: FacultySnapshot) NextAgent {
    // Priority: MU (#72) → Scholar (#79) → Swarm (#75)
    for (snapshot.agents) |a| {
        if (a.agent == .mu and a.status != .up) {
            return .{ .label = "Разбудить MU", .action = "Implement #72 → auto error healing" };
        }
    }
    for (snapshot.agents) |a| {
        if (a.agent == .scholar and a.status != .up) {
            return .{ .label = "Нанять Scholar", .action = "Implement #79 → research agent" };
        }
    }
    for (snapshot.agents) |a| {
        if (a.agent == .swarm and a.status != .up) {
            return .{ .label = "Запустить Swarm", .action = "Implement #75 → task routing" };
        }
    }
    // Fallback
    return .{ .label = "Активировать агента", .action = "Выбрать следующий agent из backlog" };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

fn testSnap(build_ok: bool, compile_rate: u8, active: u8, dirty: u16) FacultySnapshot {
    var agents: [6]types.AgentState = undefined;
    const agent_list = [_]types.Agent{ .ralph, .scholar, .mu, .oracle, .swarm, .linter };
    for (agent_list, 0..) |a, i| {
        agents[i] = .{
            .agent = a,
            .status = if (i < active) .up else .tbd,
            .last_action = "",
        };
    }
    const pass: u16 = @intCast((@as(u16, compile_rate) * 47) / 100);
    return .{
        .agents = agents,
        .build_ok = build_ok,
        .binaries = 5,
        .compile_pass = pass,
        .compile_total = 47,
        .compile_rate = compile_rate,
        .v_number = 1.0,
        .v_zone = .stable,
        .git_branch = "main",
        .dirty_files = dirty,
        .open_issues = 10,
        .mu_patterns = 12,
        .cycle = .working,
    };
}

test "paths — build broken → fix build first" {
    var paths: [3]Path = undefined;
    const snap = testSnap(false, 85, 3, 5);
    generatePaths(snap, &paths);
    try std.testing.expect(std.mem.indexOf(u8, paths[0].label, "сборку") != null);
}

test "paths — dirty files → commit" {
    var paths: [3]Path = undefined;
    const snap = testSnap(true, 95, 6, 20);
    generatePaths(snap, &paths);
    try std.testing.expect(std.mem.indexOf(u8, paths[0].label, "Зафиксировать") != null);
}

test "paths — low compile → fix generator" {
    var paths: [3]Path = undefined;
    const snap = testSnap(true, 60, 3, 5);
    generatePaths(snap, &paths);
    try std.testing.expect(std.mem.indexOf(u8, paths[0].label, "генератор") != null);
}

test "paths — faculty < 6 → wake agent" {
    var paths: [3]Path = undefined;
    const snap = testSnap(true, 90, 3, 5);
    generatePaths(snap, &paths);
    // Path B should suggest waking an agent
    try std.testing.expect(paths[1].tier == .balanced);
    try std.testing.expect(paths[1].label.len > 0);
}

test "paths — all three tiers present" {
    var paths: [3]Path = undefined;
    const snap = testSnap(true, 90, 3, 5);
    generatePaths(snap, &paths);
    try std.testing.expectEqual(Path.Tier.safe, paths[0].tier);
    try std.testing.expectEqual(Path.Tier.balanced, paths[1].tier);
    try std.testing.expectEqual(Path.Tier.bold, paths[2].tier);
}
