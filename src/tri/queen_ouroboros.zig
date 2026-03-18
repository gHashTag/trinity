// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// QUEEN OUROBOROS — Ouroboros state integration for Queen daemon
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

const STATE_PATH = ".trinity/ouroboros_state.json";

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Ouroboros state with 12 dimensions
pub const OuroborosState = struct {
    // Primary metrics
    score: f32 = 0.0, // current aggregate score (0-100)
    initial: f32 = 0.0, // initial score at cycle start
    cycle: u32 = 0, // current cycle number

    // Dimensions (12 total for health calculation)
    efficiency: f32 = 0.0, // code efficiency
    build_health: f32 = 0.0, // build passes
    test_coverage: f32 = 0.0, // test pass rate
    doc_quality: f32 = 0.0, // documentation completeness
    spec_compliance: f32 = 0.0, // specs vs generated ratio
    git_cleanliness: f32 = 0.0, // few dirty files
    farm_productivity: f32 = 0.0, // PPL improvement
    arena_activity: f32 = 0.0, // battle frequency
    experience_growth: f32 = 0.0, // episodes logged
    sacred_balance: f32 = 0.0, // predictions vs reality
    network_health: f32 = 0.0, // external connectivity

    // Meta
    stagnation: u8 = 0, // cycles without improvement
    strategy: [32]u8 = undefined, // current strategy name
    strategy_len: usize = 0,
    started_ts: i64 = 0, // timestamp of cycle start

    pub fn strategyStr(self: *const OuroborosState) []const u8 {
        return self.strategy[0..self.strategy_len];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FETCH — Load state from JSON file
// ═══════════════════════════════════════════════════════════════════════════════

pub fn fetch() OuroborosState {
    var state = OuroborosState{};

    const file = std.fs.cwd().openFile(STATE_PATH, .{}) catch return state;
    defer file.close();

    var buf: [8192]u8 = undefined;
    const n = file.readAll(&buf) catch return state;
    const data = buf[0..n];

    // Parse JSON using simple key search
    if (findJsonF32(data, "\"current\":")) |v| state.score = v;
    if (findJsonF32(data, "\"initial\":")) |v| state.initial = v;
    if (findJsonU32(data, "\"cycle\":")) |v| state.cycle = v;
    if (findJsonU32(data, "\"stagnation\":")) |v| state.stagnation = @intCast(v);
    if (findJsonI64(data, "\"started\":")) |v| state.started_ts = v;

    if (findJsonStr(data, "\"strategy\":\"")) |s| {
        const len = @min(s.len, state.strategy.len);
        @memcpy(state.strategy[0..len], s[0..len]);
        state.strategy_len = len;
    }

    // Load metrics if present in ouroboros_metrics.json
    loadMetrics(&state);

    return state;
}

fn loadMetrics(state: *OuroborosState) void {
    const metrics_path = ".trinity/ouroboros_metrics.json";
    const file = std.fs.cwd().openFile(metrics_path, .{}) catch return;
    defer file.close();

    var buf: [4096]u8 = undefined;
    const n = file.readAll(&buf) catch return;
    const data = buf[0..n];

    if (findJsonF32(data, "\"efficiency\":")) |v| state.efficiency = v;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GET SCORE — Extract aggregate score
// ═══════════════════════════════════════════════════════════════════════════════

pub fn getScore(state: OuroborosState) f32 {
    return state.score;
}

// ═══════════════════════════════════════════════════════════════════════════════
// FORMAT TELEGRAM — Create report for Telegram
// ═══════════════════════════════════════════════════════════════════════════════

pub fn fmtTelegram(buf: []u8, state: OuroborosState) []const u8 {
    const emoji_cycle = "\xf0\x9f\x94\x84"; // 🔄
    const emoji_star = "\xe2\xad\x90"; // ⭐
    const emoji_chart = "\xf0\x9f\x93\x88"; // 📈
    const emoji_brain = "\xf0\x9f\xa7\xa0"; // 🧠

    const delta = state.score - state.initial;
    const sign = if (delta >= 0) "+" else "";

    return std.fmt.bufPrint(buf,
        \\{s} Ouroboros Cycle {d}
        \\{s} Score: {d:.1} ({s}{d:.1})
        \\{s} Strategy: {s}
        \\{s} Stagnation: {d}
        \\
    , .{
        emoji_cycle,
        state.cycle,
        emoji_star,
        state.score,
        sign,
        delta,
        emoji_brain,
        state.strategyStr(),
        emoji_chart,
        state.stagnation,
    }) catch buf[0..0];
}

// ═══════════════════════════════════════════════════════════════════════════════
// JSON HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn findJsonF32(data: []const u8, key: []const u8) ?f32 {
    const idx = std.mem.indexOf(u8, data, key) orelse return null;
    const start = idx + key.len;
    if (start >= data.len) return null;
    var end = start;
    while (end < data.len and (data[end] == '-' or data[end] == '.' or (data[end] >= '0' and data[end] <= '9'))) : (end += 1) {}
    if (end == start) return null;
    return std.fmt.parseFloat(f32, data[start..end]) catch null;
}

fn findJsonU32(data: []const u8, key: []const u8) ?u32 {
    const idx = std.mem.indexOf(u8, data, key) orelse return null;
    const start = idx + key.len;
    if (start >= data.len) return null;
    var end = start;
    while (end < data.len and data[end] >= '0' and data[end] <= '9') : (end += 1) {}
    if (end == start) return null;
    return std.fmt.parseInt(u32, data[start..end], 10) catch null;
}

fn findJsonI64(data: []const u8, key: []const u8) ?i64 {
    const idx = std.mem.indexOf(u8, data, key) orelse return null;
    const start = idx + key.len;
    if (start >= data.len) return null;
    var end = start;
    while (end < data.len and (data[end] == '-' or (data[end] >= '0' and data[end] <= '9'))) : (end += 1) {}
    if (end == start) return null;
    return std.fmt.parseInt(i64, data[start..end], 10) catch null;
}

fn findJsonStr(data: []const u8, key: []const u8) ?[]const u8 {
    const idx = std.mem.indexOf(u8, data, key) orelse return null;
    const start = idx + key.len;
    if (start >= data.len) return null;
    const end = std.mem.indexOfScalarPos(u8, data, start, '"') orelse return null;
    return data[start..end];
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Queen Ouroboros — fetch returns valid state" {
    const state = fetch();
    try std.testing.expect(state.score >= 0.0);
    try std.testing.expect(state.score <= 100.0);
}

test "Queen Ouroboros — getScore extracts score" {
    const state = OuroborosState{ .score = 75.5 };
    try std.testing.expectApproxEqAbs(@as(f32, 75.5), getScore(state), 0.01);
}

test "Queen Ouroboros — fmtTelegram formats" {
    var buf: [512]u8 = undefined;
    var state = OuroborosState{
        .score = 91.1,
        .initial = 79.4,
        .cycle = 20,
        .stagnation = 2,
        .started_ts = 1773496151,
    };
    @memcpy(state.strategy[0..14], "priority_first");
    state.strategy_len = 14;

    const msg = fmtTelegram(&buf, state);
    try std.testing.expect(msg.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, msg, "91.1") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "+11.7") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "Cycle 20") != null);
}

test "Queen Ouroboros — JSON helpers" {
    const data = "{\"score\":75.5,\"cycle\":10,\"stagnation\":2,\"started\":1700000000,\"strategy\":\"test\"}";

    try std.testing.expectApproxEqAbs(@as(f32, 75.5), findJsonF32(data, "\"score\":").?, 0.01);
    try std.testing.expectEqual(@as(u32, 10), findJsonU32(data, "\"cycle\":").?);
    try std.testing.expectEqual(@as(i64, 1700000000), findJsonI64(data, "\"started\":").?);
    try std.testing.expectEqualStrings("test", findJsonStr(data, "\"strategy\":\"").?);
}
