// Arena Elo Codegen — Generate Zig from .tri spec
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

const ARENA_ELO_TEMPLATE =
    \\//! Arena Elo — Generated from specs/arena/elo.tri
    \\//! φ² + 1/φ² = 3 | TRINITY
    \\//!
    \\//! DO NOT EDIT: This file is generated from elo.tri spec
    \\//! Modify spec and regenerate: tri vibee-gen arena_elo
    \\
    \\const std = @import("std");
    \\
    \\/// ════════════════════════════════════════════════════════════════════════════════════════════
    \\/// ARENA ELO RATING SYSTEM
    \\/// ════════════════════════════════════════════════════════════════════════
    \\/// LMSYS standard v1.0 for Trinity Arena LLM battles
    \\/// ════════════════════════════════════════════════════════════════════
    \\
    \\/// Match verdict: 1=A wins, 0=tie, -1=B wins
    \\pub const Verdict = enum(i8) {
    \\    a_wins = 1,  // Model A wins
    \\    b_wins = 2,  // Model B wins
    \\    tie = 0,    // Draw
    \\};
    \\
    \\/// Match result with ELO updates
    \\pub const Match = struct {
    \\    verdict: Verdict = .tie,
    \\    confidence: f64 = 1.0,
    \\};
    \\
    \\/// ════════════════════════════════════════════════════════════════
    \\/// CONSTANTS
    \\/// ══════════════════════════════════════════════════════════════
    \\
    \\/// K-factor for ELO updates (LMSYS standard)
    \\pub const K_FACTOR: f64 = 32.0;
    \\
    \\/// Starting rating for new models
    \\pub const INITIAL_RATING: f64 = 1500.0;
    \\
    \\/// Minimum allowed rating
    \\pub const MIN_RATING: f64 = 100.0;
    \\
    \\/// Maximum allowed rating
    \\pub const MAX_RATING: f64 = 3000.0;
    \\
    \\/// Small epsilon for numerical stability
    \\pub const EPSILON: f64 = 1e-6;
    \\
    \\/// ════════════════════════════════════════════════════════════
    \\/// ELO CALCULATION
    \\/// ════════════════════════════════════════════════════════════
    \\
    \\/// Calculate expected score using logistic function
    \\/// Formula: E = 1/(1+10^((Rb-Ra)/400))
    \\pub fn expectedScore(rating_a: f64, rating_b: f64) !f64 {
    \\    const rating_diff = rating_b - rating_a;
    \\    const exponent = rating_diff / 400.0;
    \\    const power_of_10 = std.math.pow(f64, 10.0, exponent);
    \\    const denominator = 1.0 + power_of_10;
    \\    return 1.0 / denominator;
    \\}
    \\
    \\/// Update ELO ratings based on match result
    \\/// Returns: new rating_a, new rating_b
    \\/// Uses standard ELO: A wins=1.0, B wins=0.0, tie=0.5
    \\pub fn updateRatings(
    \\    match: Match,
    \\    rating_a: *f64,
    \\    rating_b: *f64,
    \\) !void {
    \\    const k = K_FACTOR;
    \\    const actual: f64 = switch (match.verdict) {
    \\        .a_wins => 1.0,
    \\        .b_wins => 0.0,
    \\        .tie => 0.5,
    \\    };
    \\    const expected = expectedScore(rating_a.*, rating_b.*);
    \\    const change = k * (actual - expected);
    \\
    \\    rating_a.* += change;
    \\    rating_b.* -= change;
    \\}
    \\
    \\/// Format ELO rating to string with 4 significant digits
    \\/// Returns: stack-allocated string
    \\pub fn formatElo(rating: f64, allocator: Allocator) ![]const u8 {
    \\    // Clamp to reasonable range
    \\    const clamped = @max(MIN_RATING, @min(MAX_RATING, rating));
    \\
    \\    // Format with 1 decimal place for readability
    \\    return std.fmt.allocPrint(allocator, "{d:.1}", .{clamped});
    \\}
    \\
    \\// ════════════════════════════════════════════════════════════
    \\// TESTS
    \\// ══════════════════════════════════════════════════════════
    \\
    \\test "Verdict: values correct" {
    \\    try std.testing.expectEqual(@as(i8, 1), @intFromEnum(Verdict.a_wins));
    \\    try std.testing.expectEqual(@as(i8, 0), @intFromEnum(Verdict.tie));
    \\    try std.testing.expectEqual(@as(i8, 2), @intFromEnum(Verdict.b_wins));
    \\}
    \\
    \\test "Constants: K_FACTOR" {
    \\    try std.testing.expectEqual(@as(f64, 32.0), K_FACTOR);
    \\}
    \\
    \\test "Constants: INITIAL_RATING" {
    \\    try std.testing.expectEqual(@as(f64, 1500.0), INITIAL_RATING);
    \\}
    \\
    \\test "Constants: rating bounds" {
    \\    try std.testing.expectEqual(@as(f64, 100.0), MIN_RATING);
    \\    try std.testing.expectEqual(@as(f64, 3000.0), MAX_RATING);
    \\}
    \\
    \\test "expectedScore: equal ratings" {
    \\    const result = expectedScore(1500.0, 1500.0);
    \\    try std.testing.expectApproxEqAbs(@as(f64, 0.5), result, 0.01);
    \\}
    \\
    \\test "expectedScore: A wins B" {
    \\    const result = expectedScore(1500.0, 1300.0);
    \\    try std.testing.expect(result > 0.75 and result < 0.76);
    \\}
    \\
    \\test "updateRatings: A wins B" {
    \\    var rating_a: f64 = 1500.0;
    \\    var rating_b: f64 = 1400.0;
    \\
    \\    try updateRatings(.{ .verdict = .a_wins }, &rating_a, &rating_b);
    \\    try std.testing.expect(rating_a > 1500.0);
    \\    try std.testing.expect(rating_b < 1400.0);
    \\}
    \\
    \\test "updateRatings: B wins A" {
    \\    var rating_a: f64 = 1500.0;
    \\    var rating_b: f64 = 1400.0;
    \\
    \\    try updateRatings(.{ .verdict = .b_wins }, &rating_a, &rating_b);
    \\    try std.testing.expect(rating_a < 1500.0);
    \\    try std.testing.expect(rating_b > 1400.0);
    \\}
    \\
    \\test "updateRatings: tie (no change for equal ratings)" {
    \\    var rating_a: f64 = 1400.0;
    \\    var rating_b: f64 = 1400.0;
    \\    try updateRatings(.{ .verdict = .tie }, &rating_a, &rating_b);
    \\    // With standard ELO, tie between equals = actual=0.5, expected=0.5, change=0
    \\    try std.testing.expectApproxEqAbs(@as(f64, 1400.0), rating_a, 0.1);
    \\    try std.testing.expectApproxEqAbs(@as(f64, 1400.0), rating_b, 0.1);
    \\}
    \\
    \\test "formatElo: 1500" {
    \\    const formatted = try formatElo(1500.0, std.testing.allocator);
    \\    defer std.testing.allocator.free(formatted);
    \\    try std.testing.expectEqualSlices(u8, "1500.0", formatted);
    \\}
    \\
    \\test "formatElo: 999999 (max)" {
    \\    const formatted = try formatElo(999999.0, std.testing.allocator);
    \\    defer std.testing.allocator.free(formatted);
    \\    try std.testing.expectEqualSlices(u8, "3000.0", formatted);
    \\}
    \\
    \\test "formatElo: 50 (min)" {
    \\    const formatted = try formatElo(50.0, std.testing.allocator);
    \\    defer std.testing.allocator.free(formatted);
    \\    try std.testing.expectEqualSlices(u8, "100.0", formatted);
    \\}
;

pub fn generateArenaElo(allocator: Allocator) ![]const u8 {
    return allocator.dupe(u8, ARENA_ELO_TEMPLATE);
}

pub fn writeArenaElo(allocator: Allocator, path: []const u8) !void {
    const content = try generateArenaElo(allocator);
    defer allocator.free(content);

    const file = try std.fs.createFileAbsolute(path, .{});
    defer file.close();

    try file.writeAll(content);
}

test "arena_elo codegen" {
    const content = try generateArenaElo(std.testing.allocator);
    defer std.testing.allocator.free(content);

    try std.testing.expect(content.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, content, "pub const Verdict") != null);
}
