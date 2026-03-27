// ELO Rating — Generated from specs/arena/elo.tri
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

/// Battle outcome verdict
pub const Verdict = enum {
    a_wins,
    b_wins,
    tie,
};

/// K-factor: controls how much a single game affects the rating
pub const K_FACTOR: f64 = 32.0;

/// Expected score of player A against player B
pub fn expectedScore(rating_a: f64, rating_b: f64) f64 {
    return 1.0 / (1.0 + std.math.pow(f64, 10.0, (rating_b - rating_a) / 400.0));
}

/// Update ratings after a battle
/// Returns: { new_rating_a, new_rating_b }
pub fn updateRatings(rating_a: f64, rating_b: f64, verdict: Verdict) struct { f64, f64 } {
    const ea = expectedScore(rating_a, rating_b);
    const eb = 1.0 - ea;

    const sa: f64 = switch (verdict) {
        .a_wins => 1.0,
        .b_wins => 0.0,
        .tie => 0.5,
    };
    const sb: f64 = 1.0 - sa;

    const new_a = rating_a + K_FACTOR * (sa - ea);
    const new_b = rating_b + K_FACTOR * (sb - eb);

    return .{ new_a, new_b };
}

/// Format ELO as integer string into buffer
pub fn formatElo(elo: f64, buf: []u8) []const u8 {
    const elo_int: i32 = @intFromFloat(@round(elo));
    return std.fmt.bufPrint(buf, "{d}", .{elo_int}) catch "???";
}

// ============================================================================
// TESTS
// ============================================================================

test "expected score equal ratings" {
    const e = expectedScore(1000.0, 1000.0);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), e, 0.001);
}

test "expected score higher rated player" {
    const e = expectedScore(1200.0, 1000.0);
    try std.testing.expect(e > 0.7);
    try std.testing.expect(e < 0.8);
}

test "update ratings a_wins" {
    const result = updateRatings(1000.0, 1000.0, .a_wins);
    try std.testing.expectApproxEqAbs(@as(f64, 1016.0), result[0], 0.1);
    try std.testing.expectApproxEqAbs(@as(f64, 984.0), result[1], 0.1);
}

test "update ratings tie" {
    const result = updateRatings(1000.0, 1000.0, .tie);
    try std.testing.expectApproxEqAbs(@as(f64, 1000.0), result[0], 0.1);
    try std.testing.expectApproxEqAbs(@as(f64, 1000.0), result[1], 0.1);
}

test "update ratings conserves total" {
    const result = updateRatings(1200.0, 800.0, .b_wins);
    const total_before = 1200.0 + 800.0;
    const total_after = result[0] + result[1];
    try std.testing.expectApproxEqAbs(total_before, total_after, 0.001);
}

test "format elo" {
    var buf: [16]u8 = undefined;
    const s = formatElo(1042.7, &buf);
    try std.testing.expectEqualStrings("1043", s);
}
