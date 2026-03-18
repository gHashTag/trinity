// @origin(manual) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// ARENA TYPES — Shared data structures for LLM Battle Arena
// ═══════════════════════════════════════════════════════════════════════════════
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ─────────────────────────────────────────────────────────────────────────────
// Task
// ─────────────────────────────────────────────────────────────────────────────

pub const TaskCategory = enum {
    math,
    coding,
    reasoning,
    wild,

    pub fn toString(self: TaskCategory) []const u8 {
        return switch (self) {
            .math => "math",
            .coding => "coding",
            .reasoning => "reasoning",
            .wild => "wild",
        };
    }

    pub fn fromString(s: []const u8) ?TaskCategory {
        if (std.mem.eql(u8, s, "math")) return .math;
        if (std.mem.eql(u8, s, "coding")) return .coding;
        if (std.mem.eql(u8, s, "reasoning")) return .reasoning;
        if (std.mem.eql(u8, s, "wild")) return .wild;
        return null;
    }
};

pub const Difficulty = enum {
    easy,
    medium,
    hard,

    pub fn toString(self: Difficulty) []const u8 {
        return switch (self) {
            .easy => "easy",
            .medium => "medium",
            .hard => "hard",
        };
    }

    pub fn fromString(s: []const u8) ?Difficulty {
        if (std.mem.eql(u8, s, "easy")) return .easy;
        if (std.mem.eql(u8, s, "medium")) return .medium;
        if (std.mem.eql(u8, s, "hard")) return .hard;
        return null;
    }
};

pub const Task = struct {
    id: []const u8, // "gsm8k-042", "humaneval-012", "custom"
    category: TaskCategory,
    prompt: []const u8,
    reference_answer: ?[]const u8 = null, // ground truth if available
    difficulty: Difficulty,
};

// ─────────────────────────────────────────────────────────────────────────────
// Fighter
// ─────────────────────────────────────────────────────────────────────────────

pub const FighterKind = enum {
    trinity,
    openai,
    anthropic,
    local,
    echo, // debug: echoes the prompt back
    custom,

    pub fn toString(self: FighterKind) []const u8 {
        return switch (self) {
            .trinity => "trinity",
            .openai => "openai",
            .anthropic => "anthropic",
            .local => "local",
            .echo => "echo",
            .custom => "custom",
        };
    }

    pub fn fromString(s: []const u8) ?FighterKind {
        if (std.mem.eql(u8, s, "trinity")) return .trinity;
        if (std.mem.eql(u8, s, "openai")) return .openai;
        if (std.mem.eql(u8, s, "anthropic")) return .anthropic;
        if (std.mem.eql(u8, s, "local")) return .local;
        if (std.mem.eql(u8, s, "echo")) return .echo;
        if (std.mem.eql(u8, s, "custom")) return .custom;
        return null;
    }
};

pub const Fighter = struct {
    name: []const u8, // "trinity-hslm", "gpt-4o", "claude-sonnet"
    kind: FighterKind,
    model: ?[]const u8 = null, // model ID for API calls
    endpoint: ?[]const u8 = null, // custom endpoint URL
    elo: f64 = 1000.0, // current ELO rating
    wins: u32 = 0,
    losses: u32 = 0,
    ties: u32 = 0,
};

// ─────────────────────────────────────────────────────────────────────────────
// Battle
// ─────────────────────────────────────────────────────────────────────────────

pub const BattleStatus = enum {
    pending,
    running,
    complete,
    judged,

    pub fn toString(self: BattleStatus) []const u8 {
        return switch (self) {
            .pending => "pending",
            .running => "running",
            .complete => "complete",
            .judged => "judged",
        };
    }
};

pub const Verdict = enum {
    a_wins,
    b_wins,
    tie,

    pub fn toString(self: Verdict) []const u8 {
        return switch (self) {
            .a_wins => "a_wins",
            .b_wins => "b_wins",
            .tie => "tie",
        };
    }

    pub fn fromString(s: []const u8) ?Verdict {
        if (std.mem.eql(u8, s, "a_wins")) return .a_wins;
        if (std.mem.eql(u8, s, "b_wins")) return .b_wins;
        if (std.mem.eql(u8, s, "tie")) return .tie;
        return null;
    }
};

pub const Battle = struct {
    id: u64, // monotonic ID
    task: Task,
    fighter_a: []const u8, // fighter name
    fighter_b: []const u8,
    response_a: ?[]const u8 = null,
    response_b: ?[]const u8 = null,
    status: BattleStatus = .pending,
    judge_verdict: ?Verdict = null,
    judge_reasoning: ?[]const u8 = null,
    latency_a_ms: u64 = 0,
    latency_b_ms: u64 = 0,
    created_at: i64 = 0, // unix timestamp
    completed_at: ?i64 = null,
};

// ─────────────────────────────────────────────────────────────────────────────
// Vote
// ─────────────────────────────────────────────────────────────────────────────

pub const Vote = struct {
    battle_id: u64,
    verdict: Verdict,
    voter: []const u8, // "human", "llm-judge", etc.
    timestamp: i64,
};

// ─────────────────────────────────────────────────────────────────────────────
// Leaderboard
// ─────────────────────────────────────────────────────────────────────────────

pub const LeaderboardEntry = struct {
    name: []const u8,
    elo: f64,
    wins: u32,
    losses: u32,
    ties: u32,

    pub fn totalBattles(self: LeaderboardEntry) u32 {
        return self.wins + self.losses + self.ties;
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// Fixed-size buffers for arena storage (no allocations in hot path)
// ─────────────────────────────────────────────────────────────────────────────

pub const MAX_FIGHTERS = 32;
pub const MAX_BATTLES = 1024;
pub const MAX_TASKS = 128;
pub const MAX_RESPONSE_LEN = 8192;
pub const MAX_NAME_LEN = 64;

pub const StoredFighter = struct {
    name_buf: [MAX_NAME_LEN]u8 = undefined,
    name_len: usize = 0,
    kind: FighterKind = .echo,
    model_buf: [MAX_NAME_LEN]u8 = undefined,
    model_len: usize = 0,
    endpoint_buf: [256]u8 = undefined,
    endpoint_len: usize = 0,
    elo: f64 = 1000.0,
    wins: u32 = 0,
    losses: u32 = 0,
    ties: u32 = 0,
    active: bool = false,

    pub fn getName(self: *const StoredFighter) []const u8 {
        return self.name_buf[0..self.name_len];
    }

    pub fn getModel(self: *const StoredFighter) ?[]const u8 {
        if (self.model_len == 0) return null;
        return self.model_buf[0..self.model_len];
    }

    pub fn getEndpoint(self: *const StoredFighter) ?[]const u8 {
        if (self.endpoint_len == 0) return null;
        return self.endpoint_buf[0..self.endpoint_len];
    }

    pub fn setName(self: *StoredFighter, name: []const u8) void {
        const len = @min(name.len, MAX_NAME_LEN);
        @memcpy(self.name_buf[0..len], name[0..len]);
        self.name_len = len;
    }

    pub fn setModel(self: *StoredFighter, model: []const u8) void {
        const len = @min(model.len, MAX_NAME_LEN);
        @memcpy(self.model_buf[0..len], model[0..len]);
        self.model_len = len;
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

test "TaskCategory roundtrip" {
    const cat = TaskCategory.math;
    const s = cat.toString();
    try std.testing.expectEqual(TaskCategory.math, TaskCategory.fromString(s).?);
}

test "Verdict roundtrip" {
    const v = Verdict.a_wins;
    try std.testing.expectEqual(Verdict.a_wins, Verdict.fromString(v.toString()).?);
}

test "StoredFighter name" {
    var f = StoredFighter{};
    f.setName("trinity-hslm");
    f.active = true;
    try std.testing.expectEqualStrings("trinity-hslm", f.getName());
}

test "LeaderboardEntry totalBattles" {
    const e = LeaderboardEntry{
        .name = "test",
        .elo = 1000,
        .wins = 5,
        .losses = 3,
        .ties = 2,
    };
    try std.testing.expectEqual(@as(u32, 10), e.totalBattles());
}
