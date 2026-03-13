// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// Faculty Board Types — Shared types for Trinity A2A Dashboard
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const Agent = enum {
    ralph,
    scholar,
    mu,
    oracle,
    swarm,
    linter,

    pub fn name(self: Agent) []const u8 {
        return switch (self) {
            .ralph => "Ralph",
            .scholar => "Scholar",
            .mu => "Agent TRI",
            .oracle => "Oracle",
            .swarm => "Swarm",
            .linter => "Linter",
        };
    }

    pub fn emoji(self: Agent) []const u8 {
        return switch (self) {
            .ralph => "🔧",
            .scholar => "📚",
            .mu => "🧠",
            .oracle => "🔮",
            .swarm => "🐝",
            .linter => "🔍",
        };
    }
};

pub const AgentStatus = enum {
    up,
    down,
    stub,
    tbd,

    pub fn label(self: AgentStatus) []const u8 {
        return switch (self) {
            .up => "UP",
            .down => "DOWN",
            .stub => "STUB",
            .tbd => "TBD",
        };
    }

    pub fn color(self: AgentStatus) []const u8 {
        return switch (self) {
            .up => "\x1b[38;2;0;229;153m", // green
            .down => "\x1b[38;2;239;68;68m", // red
            .stub => "\x1b[38;2;255;215;0m", // golden
            .tbd => "\x1b[38;2;156;156;160m", // gray
        };
    }
};

pub const CycleType = enum {
    quiet,
    working,
    emergency,

    pub fn label(self: CycleType) []const u8 {
        return switch (self) {
            .quiet => "QUIET",
            .working => "WORKING",
            .emergency => "EMERGENCY",
        };
    }
};

pub const VZone = enum {
    gold,
    stable,
    drift,

    pub fn label(self: VZone) []const u8 {
        return switch (self) {
            .gold => "GOLD",
            .stable => "STABLE",
            .drift => "DRIFT",
        };
    }

    pub fn color(self: VZone) []const u8 {
        return switch (self) {
            .gold => "\x1b[38;2;255;215;0m",
            .stable => "\x1b[38;2;0;229;153m",
            .drift => "\x1b[38;2;239;68;68m",
        };
    }
};

pub const AgentState = struct {
    agent: Agent,
    status: AgentStatus,
    last_action: []const u8,
};

pub const FacultySnapshot = struct {
    agents: [6]AgentState,
    build_ok: bool,
    binaries: u8,
    compile_pass: u16,
    compile_total: u16,
    compile_rate: u8, // 0-100
    v_number: f64, // φ·(rate/100)²
    v_zone: VZone,
    git_branch: []const u8,
    dirty_files: u16,
    open_issues: u16,
    mu_patterns: u16,
    cycle: CycleType,

    pub fn activeFaculty(self: FacultySnapshot) u8 {
        var count: u8 = 0;
        for (self.agents) |a| {
            if (a.status == .up) count += 1;
        }
        return count;
    }
};

pub const FacultyDelta = struct {
    has_prev: bool = false,
    seconds_ago: i64 = 0,
    compile_rate_delta: i16 = 0,
    active_delta: i8 = 0,
    dirty_delta: i32 = 0,
    compile_frozen: bool = false,
    prev_compile_rate: u8 = 0,
    prev_active: u8 = 0,
    prev_dirty: u16 = 0,
    prev_compile_pass: u16 = 0,
    prev_compile_total: u16 = 0,
    prev_issues: u16 = 0,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Agent name and emoji" {
    try std.testing.expectEqualStrings("Ralph", Agent.ralph.name());
    try std.testing.expectEqualStrings("🔧", Agent.ralph.emoji());
    try std.testing.expectEqualStrings("Agent TRI", Agent.mu.name());
    try std.testing.expectEqualStrings("🧠", Agent.mu.emoji());
}

test "AgentStatus label and color" {
    try std.testing.expectEqualStrings("UP", AgentStatus.up.label());
    try std.testing.expect(AgentStatus.up.color().len > 0);
    try std.testing.expectEqualStrings("TBD", AgentStatus.tbd.label());
}

test "VZone from v_number" {
    // gold > 1.5, stable 1.0-1.5, drift < 1.0
    try std.testing.expectEqualStrings("GOLD", VZone.gold.label());
    try std.testing.expectEqualStrings("DRIFT", VZone.drift.label());
}

test "FacultySnapshot activeFaculty" {
    const snap = FacultySnapshot{
        .agents = .{
            .{ .agent = .ralph, .status = .up, .last_action = "build" },
            .{ .agent = .scholar, .status = .tbd, .last_action = "" },
            .{ .agent = .mu, .status = .stub, .last_action = "" },
            .{ .agent = .oracle, .status = .up, .last_action = "watch" },
            .{ .agent = .swarm, .status = .tbd, .last_action = "" },
            .{ .agent = .linter, .status = .up, .last_action = "scan" },
        },
        .build_ok = true,
        .binaries = 5,
        .compile_pass = 40,
        .compile_total = 47,
        .compile_rate = 85,
        .v_number = 1.17,
        .v_zone = .stable,
        .git_branch = "main",
        .dirty_files = 5,
        .open_issues = 10,
        .mu_patterns = 12,
        .cycle = .working,
    };
    try std.testing.expectEqual(@as(u8, 3), snap.activeFaculty());
}
