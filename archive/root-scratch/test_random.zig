const std = @import("std");

test "Random init test" {
    const seed: u64 = 42;
    var prng = std.Random.DefaultPrng.init(seed);
    const rng = prng.random();
    const val = rng.float(f32);
    _ = val;
}
