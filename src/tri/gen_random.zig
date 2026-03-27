//! tri/random — Random number generation
//! TTT Dogfood v0.2 Stage 249

const std = @import("std");

pub const Random = struct {
    prng: std.Random.DefaultPrng,

    pub fn init(seed: u64) Random {
        return .{ .prng = std.Random.DefaultPrng.init(seed) };
    }

    pub fn next(rnd: *Random) u64 {
        return rnd.prng.random().u64();
    }

    pub fn range(rnd: *Random, max: u64) u64 {
        return rnd.prng.random().uintRangeLessThan(u64, max);
    }
};

test "random" {
    var rnd = Random.init(42);
    const val = rnd.next();
    try std.testing.expect(val >= 0);
}
