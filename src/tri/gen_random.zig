//! TRI Random — Generated from specs/tri/tri_random.tri
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

pub const Rng = struct {
    state: u64,
};

pub fn init(seed: u64) Rng {
    var rng = Rng{ .state = seed };
    if (seed == 0) rng.state = 1;
    return rng;
}

pub fn next(rng: *Rng) u64 {
    rng.state ^= rng.state >> 12;
    rng.state ^= rng.state << 25;
    rng.state ^= rng.state >> 27;
    return rng.state *% 2685821657736338717;
}

pub fn range(rng: *Rng, max: u64) u64 {
    return @mod(next(rng), max + 1);
}

pub fn rangeInclusive(rng: *Rng, min: i64, max: i64) i64 {
    const span = @as(u64, @intCast(max - min + 1));
    return min + @as(i64, @intCast(@mod(next(rng), span)));
}

test "Random: next produces different values" {
    var rng = init(42);
    const a = next(&rng);
    const b = next(&rng);
    try std.testing.expect(a != b);
}

test "Random: range" {
    var rng = init(123);
    const val = range(&rng, 100);
    try std.testing.expect(val <= 100);
}
