// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// Three Paths — Path generator for Faculty Board
// ═══════════════════════════════════════════════════════════════════════════════
// Generates 3 prioritized action paths: SAFE, BALANCED, BOLD.
// v2: parses `gh issue list` JSON for real issue numbers.
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
                .safe => "1️⃣",
                .balanced => "2️⃣",
                .bold => "3️⃣",
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

// ═══════════════════════════════════════════════════════════════════════════════
// ISSUE PARSING
// ═══════════════════════════════════════════════════════════════════════════════

pub const GhIssue = struct {
    number: u16,
    title: []const u8,
    is_fix: bool, // title contains fix/broken/fail/error
    is_codegen: bool, // title contains codegen/vibee/spec/gen
    is_agent: bool, // title contains agent/scholar/swarm/mu
    is_epic: bool, // title contains epic/federation/a2a/swarm
};

const MAX_ISSUES = 16;

pub const IssueSet = struct {
    items: [MAX_ISSUES]GhIssue,
    count: u8,

    pub fn fixIssues(self: *const IssueSet) ?GhIssue {
        for (self.items[0..self.count]) |i| {
            if (i.is_fix or i.is_codegen) return i;
        }
        return null;
    }

    pub fn agentIssue(self: *const IssueSet) ?GhIssue {
        for (self.items[0..self.count]) |i| {
            if (i.is_agent) return i;
        }
        return null;
    }

    pub fn epicIssue(self: *const IssueSet) ?GhIssue {
        for (self.items[0..self.count]) |i| {
            if (i.is_epic) return i;
        }
        return null;
    }
};

/// Parse `gh issue list --json number,title` JSON output into IssueSet.
/// Expects JSON array of objects: [{"number":114,"title":"..."},...]
/// Minimal parser — finds "number": and "title":" patterns.
pub fn parseGhIssues(json: []const u8) IssueSet {
    var set = IssueSet{ .items = undefined, .count = 0 };
    var pos: usize = 0;

    while (pos < json.len and set.count < MAX_ISSUES) {
        // Find next "number":
        const num_key = std.mem.indexOf(u8, json[pos..], "\"number\":");
        if (num_key == null) break;
        pos += num_key.? + 9; // skip "number":
        // Skip whitespace
        while (pos < json.len and (json[pos] == ' ' or json[pos] == '\t')) pos += 1;
        // Parse number
        const num_start = pos;
        while (pos < json.len and json[pos] >= '0' and json[pos] <= '9') pos += 1;
        const number = std.fmt.parseInt(u16, json[num_start..pos], 10) catch continue;

        // Find "title":"
        const title_key = std.mem.indexOf(u8, json[pos..], "\"title\":\"");
        if (title_key == null) continue;
        pos += title_key.? + 9; // skip "title":"
        const title_start = pos;
        // Find closing quote (handle escaped quotes)
        while (pos < json.len) {
            if (json[pos] == '\\') {
                pos += 2;
                continue;
            }
            if (json[pos] == '"') break;
            pos += 1;
        }
        const title = json[title_start..pos];
        if (pos < json.len) pos += 1; // skip closing quote

        const title_lower = title; // case-sensitive is fine for our keywords
        set.items[set.count] = .{
            .number = number,
            .title = title,
            .is_fix = containsAny(title_lower, &.{ "fix", "broken", "fail", "error", "bug" }),
            .is_codegen = containsAny(title_lower, &.{ "codegen", "vibee", "spec", "VIBEE", "Codegen" }),
            .is_agent = containsAny(title_lower, &.{ "agent", "Scholar", "scholar", "Swarm", "swarm", "Agent TRI", "tri agent" }),
            .is_epic = containsAny(title_lower, &.{ "epic", "federation", "a2a", "A2A", "Swarm Pipeline" }),
        };
        set.count += 1;
    }
    return set;
}

fn containsAny(haystack: []const u8, needles: []const []const u8) bool {
    for (needles) |needle| {
        if (std.mem.indexOf(u8, haystack, needle) != null) return true;
    }
    return false;
}

/// Fetch issues from `gh issue list` and parse them.
/// Returns empty IssueSet if gh command fails.
pub fn fetchIssues(allocator: std.mem.Allocator) IssueSet {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "gh", "issue", "list", "--json", "number,title", "--limit", "20" },
        .max_output_bytes = 32 * 1024,
    }) catch return .{ .items = undefined, .count = 0 };
    defer allocator.free(result.stderr);
    defer allocator.free(result.stdout);

    return parseGhIssues(result.stdout);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PATH GENERATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Generate paths with real issue numbers when available.
/// Uses action_bufs for formatted strings with issue numbers.
pub fn generatePathsWithIssues(
    snapshot: FacultySnapshot,
    issues: *const IssueSet,
    paths: *[3]Path,
    action_bufs: *[3][128]u8,
) void {
    const active = snapshot.activeFaculty();

    // === PATH A: SAFE ===
    if (!snapshot.build_ok) {
        paths[0] = .{ .tier = .safe, .label = "Починить сборку", .action = "zig build 2>&1 | head -20 → fix errors" };
    } else if (snapshot.compile_rate < 80) {
        paths[0] = .{ .tier = .safe, .label = "Починить генератор", .action = "tri verify → fix failing specs" };
    } else if (snapshot.dirty_files > 15) {
        paths[0] = .{ .tier = .safe, .label = "Зафиксировать прогресс", .action = "git add -A && git commit" };
    } else if (snapshot.compile_pass < snapshot.compile_total and snapshot.compile_total > 0) {
        // Try to find a real fix issue
        if (issues.fixIssues()) |issue| {
            const action = std.fmt.bufPrint(&action_bufs[0], "Fix #{d} → compile {d}%→95%+", .{
                issue.number, snapshot.compile_rate,
            }) catch "/tri audit → fix specs";
            paths[0] = .{ .tier = .safe, .label = "Починить broken спеки", .action = action };
        } else {
            paths[0] = .{ .tier = .safe, .label = "Починить broken спеки", .action = "/tri audit → fix specs → vibee gen" };
        }
    } else {
        paths[0] = .{ .tier = .safe, .label = "Прогнать тесты", .action = "zig build test" };
    }

    // === PATH B: BALANCED ===
    if (active < 6) {
        const next = nextAgentToWake(snapshot, issues, &action_bufs[1]);
        paths[1] = .{ .tier = .balanced, .label = next.label, .action = next.action };
    } else if (snapshot.compile_rate < 95) {
        paths[1] = .{ .tier = .balanced, .label = "Довести compile до 95%+", .action = "tri verify → fix remaining specs" };
    } else {
        paths[1] = .{ .tier = .balanced, .label = "Почистить dirty файлы", .action = "git status → stage & commit" };
    }

    // === PATH C: BOLD ===
    if (issues.epicIssue()) |epic| {
        const action = std.fmt.bufPrint(&action_bufs[2], "#{d} {s}", .{
            epic.number, epic.title[0..@min(epic.title.len, 60)],
        }) catch "Swarm + A2A federation";
        paths[2] = .{ .tier = .bold, .label = "Трансформация", .action = action };
    } else if (active <= 3) {
        paths[2] = .{ .tier = .bold, .label = "Запустить Swarm оркестрацию", .action = "Implement #75 → multi-agent routing" };
    } else if (snapshot.open_issues > 20) {
        paths[2] = .{ .tier = .bold, .label = "Автоматизировать issue-triage", .action = "Scholar + Agent TRI → auto-label & prioritize" };
    } else {
        paths[2] = .{ .tier = .bold, .label = "A2A Federation", .action = "Connect Trinity swarm to external A2A agents" };
    }
}

const NextAgent = struct { label: []const u8, action: []const u8 };

fn nextAgentToWake(snapshot: FacultySnapshot, issues: *const IssueSet, buf: *[128]u8) NextAgent {
    // Agent TRI → Scholar → Swarm dependency chain
    for (snapshot.agents) |a| {
        if (a.agent == .mu and a.status != .up) {
            return .{ .label = "Разбудить Agent TRI", .action = "tri mu start → auto error healing" };
        }
    }
    for (snapshot.agents) |a| {
        if (a.agent == .scholar and a.status != .up) {
            // Try to find scholar issue
            if (issues.agentIssue()) |issue| {
                const action = std.fmt.bufPrint(buf, "#{d} → Faculty 5/6", .{issue.number}) catch "Implement #79 → research agent";
                return .{ .label = "Нанять Scholar", .action = action };
            }
            return .{ .label = "Нанять Scholar", .action = "Implement #79 → research agent" };
        }
    }
    for (snapshot.agents) |a| {
        if (a.agent == .swarm and a.status != .up) {
            return .{ .label = "Запустить Swarm", .action = "Implement #75 → task routing" };
        }
    }
    return .{ .label = "Активировать агента", .action = "Выбрать следующий agent из backlog" };
}

/// Legacy: generate paths without issue data (static strings only).
pub fn generatePaths(snapshot: FacultySnapshot, paths: *[3]Path) void {
    var empty_issues = IssueSet{ .items = undefined, .count = 0 };
    var action_bufs: [3][128]u8 = undefined;
    generatePathsWithIssues(snapshot, &empty_issues, paths, &action_bufs);
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

test "parseGhIssues — basic JSON" {
    const json =
        \\[{"number":114,"title":"VIBEE undefined Field type"},
        \\{"number":79,"title":"Scholar research agent"},
        \\{"number":38,"title":"Ralph Agent Swarm Pipeline"}]
    ;
    const issues = parseGhIssues(json);
    try std.testing.expectEqual(@as(u8, 3), issues.count);
    try std.testing.expectEqual(@as(u16, 114), issues.items[0].number);
    try std.testing.expect(issues.items[0].is_codegen); // VIBEE
    try std.testing.expect(issues.items[1].is_agent); // Scholar
    try std.testing.expect(issues.items[2].is_epic); // Swarm Pipeline
}

test "parseGhIssues — empty" {
    const issues = parseGhIssues("[]");
    try std.testing.expectEqual(@as(u8, 0), issues.count);
}

test "paths with issues — fix issue in safe path" {
    const json =
        \\[{"number":114,"title":"fix broken VIBEE codegen"},
        \\{"number":38,"title":"Ralph Agent Swarm Pipeline"}]
    ;
    const issues = parseGhIssues(json);
    var paths: [3]Path = undefined;
    var bufs: [3][128]u8 = undefined;
    const snap = testSnap(true, 90, 4, 5);
    generatePathsWithIssues(snap, &issues, &paths, &bufs);
    // Safe path should reference #114
    try std.testing.expect(std.mem.indexOf(u8, paths[0].action, "#114") != null);
}
