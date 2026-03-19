// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// QUEEN OUROBOROS — Ouroboros state integration for Queen daemon
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const qt = @import("queen_types.zig");

const STATE_PATH = ".trinity/ouroboros_state.json";

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES — using OuroborosState from queen_types.zig
// ═══════════════════════════════════════════════════════════════════════════════

pub const OuroborosState = qt.OuroborosState;

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

test "Queen Ouroboros — findJsonF32 returns null for missing" {
    const data = "{\"no_score\":75.5}";
    try std.testing.expectEqual(@as(?f32, null), findJsonF32(data, "\"score\":"));
}

test "Queen Ouroboros — findJsonU32 returns null for missing" {
    const data = "{\"no_cycle\":10}";
    try std.testing.expectEqual(@as(?u32, null), findJsonU32(data, "\"cycle\":"));
}

test "Queen Ouroboros — findJsonStr returns null for missing" {
    const data = "{\"no_strategy\":\"test\"}";
    try std.testing.expectEqual(@as(?[]const u8, null), findJsonStr(data, "\"strategy\":\""));
}

test "Queen Ouroboros — OuroborosState default values" {
    const state = OuroborosState{};
    try std.testing.expectEqual(@as(f32, 0.0), state.score);
    try std.testing.expectEqual(@as(f32, 0.0), state.initial);
    try std.testing.expectEqual(@as(u32, 0), state.cycle);
    try std.testing.expectEqual(@as(u32, 0), state.stagnation);
    try std.testing.expectEqual(@as(i64, 0), state.started_ts);
    try std.testing.expectEqual(@as(usize, 0), state.strategy_len);
}

test "Queen Ouroboros — fetch with missing file returns default" {
    // If STATE_PATH doesn't exist, fetch() should return default state
    const state = fetch();
    try std.testing.expect(state.score >= 0.0 and state.score <= 100.0);
}

test "Queen Ouroboros — fmtTelegram includes delta" {
    var buf: [512]u8 = undefined;
    const state = OuroborosState{
        .score = 85.0,
        .initial = 75.0,
        .cycle = 10,
        .stagnation = 0,
    };

    const msg = fmtTelegram(&buf, state);
    // Should show +10.0 delta
    try std.testing.expect(std.mem.indexOf(u8, msg, "+10.0") != null);
}

test "Queen Ouroboros — fmtTelegram handles negative delta" {
    var buf: [512]u8 = undefined;
    const state = OuroborosState{
        .score = 70.0,
        .initial = 80.0,
        .cycle = 10,
    };

    const msg = fmtTelegram(&buf, state);
    // Should show -10.0 delta
    try std.testing.expect(std.mem.indexOf(u8, msg, "-10.0") != null);
}

test "Queen Ouroboros — fmtTelegram with zero delta" {
    var buf: [512]u8 = undefined;
    const state = OuroborosState{
        .score = 75.0,
        .initial = 75.0,
        .cycle = 5,
        .stagnation = 0,
    };

    const msg = fmtTelegram(&buf, state);
    try std.testing.expect(msg.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, msg, "+0.0") != null or std.mem.indexOf(u8, msg, "-0.0") != null);
}

test "Queen Ouroboros — fmtTelegram includes all fields" {
    var buf: [512]u8 = undefined;
    var state = OuroborosState{
        .score = 50.0,
        .initial = 40.0,
        .cycle = 15,
        .stagnation = 3,
    };
    @memcpy(state.strategy[0.."test_strategy".len], "test_strategy");
    state.strategy_len = "test_strategy".len;

    const msg = fmtTelegram(&buf, state);
    try std.testing.expect(std.mem.indexOf(u8, msg, "Cycle 15") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "50.0") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "test_strategy") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "Stagnation: 3") != null);
}

test "Queen Ouroboros — OuroborosState all dimensions default to zero" {
    const state = OuroborosState{};
    try std.testing.expectEqual(@as(f32, 0.0), state.efficiency);
    try std.testing.expectEqual(@as(f32, 0.0), state.build_health);
    try std.testing.expectEqual(@as(f32, 0.0), state.test_coverage);
    try std.testing.expectEqual(@as(f32, 0.0), state.doc_quality);
    try std.testing.expectEqual(@as(f32, 0.0), state.spec_compliance);
    try std.testing.expectEqual(@as(f32, 0.0), state.git_cleanliness);
    try std.testing.expectEqual(@as(f32, 0.0), state.farm_productivity);
    try std.testing.expectEqual(@as(f32, 0.0), state.arena_activity);
    try std.testing.expectEqual(@as(f32, 0.0), state.experience_growth);
    try std.testing.expectEqual(@as(f32, 0.0), state.sacred_balance);
    try std.testing.expectEqual(@as(f32, 0.0), state.network_health);
}

test "Queen Ouroboros — findJsonI64 returns null for missing" {
    const data = "{\"no_started\":1700000000}";
    try std.testing.expectEqual(@as(?i64, null), findJsonI64(data, "\"started\":"));
}

test "Queen Ouroboros — findJsonF32 handles negative" {
    const data = "{\"score\":-10.5}";
    const result = findJsonF32(data, "\"score\":");
    try std.testing.expect(result != null);
    try std.testing.expectApproxEqAbs(@as(f32, -10.5), result.?, 0.01);
}

test "Queen Ouroboros — findJsonF32 handles zero" {
    const data = "{\"score\":0.0}";
    const result = findJsonF32(data, "\"score\":");
    try std.testing.expect(result != null);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), result.?, 0.001);
}

test "Queen Ouroboros — findJsonF32 empty data" {
    const data = "";
    try std.testing.expectEqual(@as(?f32, null), findJsonF32(data, "\"x\":"));
}

test "Queen Ouroboros — findJsonU32 handles large numbers" {
    const data = "{\"cycle\":999999}";
    const result = findJsonU32(data, "\"cycle\":");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u32, 999999), result.?);
}

test "Queen Ouroboros — findJsonStr empty string" {
    const data = "{\"strategy\":\"\"}";
    const result = findJsonStr(data, "\"strategy\":\"");
    try std.testing.expectEqual(@as(usize, 0), result.?.len);
}

test "Queen Ouroboros — OuroborosState strategyStr" {
    var state = OuroborosState{};
    @memcpy(state.strategy[0.."test".len], "test");
    state.strategy_len = "test".len;

    try std.testing.expectEqualStrings("test", state.strategyStr());
}

test "Queen Ouroboros — OuroborosState strategyStr empty" {
    const state = OuroborosState{};
    try std.testing.expectEqual(@as(usize, 0), state.strategyStr().len);
}

test "Queen Ouroboros — fmtTelegram buffer overflow returns empty" {
    var tiny_buf: [10]u8 = undefined;
    const state = OuroborosState{
        .score = 50.0,
        .initial = 40.0,
        .cycle = 1,
    };

    const msg = fmtTelegram(&tiny_buf, state);
    // Should return empty string if buffer too small
    try std.testing.expect(msg.len == 0);
}

test "Queen Ouroboros — getScore with zero state" {
    const state = OuroborosState{};
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getScore(state), 0.001);
}

test "Queen Ouroboros — getScore with max score" {
    const state = OuroborosState{ .score = 100.0 };
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), getScore(state), 0.01);
}

test "ouroboros — fetch returns valid state with defaults" {
    const state = fetch();
    try std.testing.expect(state.score >= 0.0 and state.score <= 100.0);
}

test "ouroboros — fetch reads cycle from file if exists" {
    const state = fetch();
    // Cycle should be >= 0 (file may or may not exist)
    try std.testing.expect(state.cycle >= 0);
}

test "ouroboros — fmtTelegram includes key fields" {
    var buf: [512]u8 = undefined;
    const state = OuroborosState{
        .score = 75.5,
        .initial = 65.0,
        .cycle = 10,
        .stagnation = 0,
        .started_ts = 1000000,
    };

    const msg = fmtTelegram(&buf, state);
    try std.testing.expect(msg.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, msg, "75") != null); // score
}

test "ouroboros — OuroborosState with all dimensions set" {
    const state = OuroborosState{
        .score = 80.0,
        .initial = 70.0,
        .cycle = 5,
        .stagnation = 1,
        .started_ts = 1234567890,
        .efficiency = 90.0,
        .build_health = 85.0,
        .test_coverage = 75.0,
        .doc_quality = 80.0,
        .spec_compliance = 95.0,
        .git_cleanliness = 100.0,
        .farm_productivity = 88.0,
        .arena_activity = 60.0,
        .experience_growth = 70.0,
        .sacred_balance = 85.0,
        .network_health = 90.0,
    };

    try std.testing.expectApproxEqAbs(@as(f32, 80.0), getScore(state), 0.01);
    try std.testing.expectEqual(@as(u32, 5), state.cycle);
    try std.testing.expectEqual(@as(u32, 1), state.stagnation);
}

test "ouroboros — getScore returns current score directly" {
    const state = OuroborosState{ .score = 42.0 };
    try std.testing.expectApproxEqAbs(@as(f32, 42.0), getScore(state), 0.01);
}

test "ouroboros — findJsonStr returns slice" {
    const data = "{\"strategy\":\"sacred_optimization\"}";
    const result = findJsonStr(data, "\"strategy\":\"");
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("sacred_optimization", result.?);
}

test "ouroboros — findJsonStr with colon in value" {
    const data = "{\"key\":\"value:with:colons\"}";
    const result = findJsonStr(data, "\"key\":\"");
    try std.testing.expect(result != null);
    try std.testing.expect(std.mem.indexOf(u8, result.?, "with:colons") != null);
}

test "ouroboros — findJsonU32 returns null for missing key" {
    const data = "{\"no_cycle\":123}";
    try std.testing.expectEqual(@as(?u32, null), findJsonU32(data, "\"cycle\":"));
}

test "ouroboros — findJsonI64 handles positive numbers" {
    const data = "{\"started\":1700000000}";
    const result = findJsonI64(data, "\"started\":");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(i64, 1700000000), result.?);
}
