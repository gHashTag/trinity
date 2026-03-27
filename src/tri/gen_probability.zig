//! tri/probability — Probability distributions and sampling
//! Auto-generated from specs/tri/tri_probability.tri
//! TTT Dogfood v0.2 Stage 185

const std = @import("std");

const pi = 3.14159265358979323846;

/// Simple PRNG state
pub const PRNG = struct {
    state: u64,

    pub fn init(seed: u64) PRNG {
        return .{ .state = seed };
    }

    pub fn float(self: *PRNG) f64 {
        self.state = self.state *% 6364136223846793005 +% 1442695040888963407;
        const max_u64: u64 = 1 << 53; // 53 bits of precision
        return @as(f64, @floatFromInt(self.state & (max_u64 - 1))) / @as(f64, @floatFromInt(max_u64));
    }
};

/// Bernoulli trial with probability p
pub fn bernoulli(p: f64, rng: *PRNG) bool {
    const u = rng.float();
    return u < p;
}

/// Binomial distribution B(n,p)
pub fn binomial(n: usize, p: f64, rng: *PRNG) usize {
    var count: usize = 0;
    for (0..n) |_| {
        if (bernoulli(p, rng)) count += 1;
    }
    return count;
}

/// Poisson distribution
pub fn poisson(lambda: f64, rng: *PRNG) usize {
    if (lambda <= 0) return 0;

    const L = std.math.exp(-lambda);
    var k: usize = 0;
    var prod: f64 = 1.0;

    while (prod > L) {
        k += 1;
        prod *= rng.float();
    }

    return k - 1;
}

/// Normal distribution (Box-Muller)
pub fn normal(mean: f64, std_dev: f64, rng: *PRNG) f64 {
    // Box-Muller transform
    const u_a = rng.float();
    const u_b = rng.float();

    const ln_u_a = std.math.log(f64, std.math.e, u_a);
    const z0 = std.math.sqrt(-2.0 * ln_u_a) * std.math.cos(2.0 * pi * u_b);

    return mean + std_dev * z0;
}

/// Exponential distribution
pub fn exponential(lambda: f64, rng: *PRNG) f64 {
    if (lambda <= 0) return 0;
    const u = rng.float();
    const ln_val = std.math.log(f64, std.math.e, 1.0 - u);
    return -ln_val / lambda;
}

test "bernoulli" {
    var rng = PRNG.init(12345);
    var count: usize = 0;
    for (0..1000) |_| {
        if (bernoulli(0.5, &rng)) count += 1;
    }
    // Should be around 500
    try std.testing.expect(count > 400 and count < 600);
}

test "binomial" {
    var rng = PRNG.init(12345);
    const result = binomial(100, 0.5, &rng);
    // Should be around 50
    try std.testing.expect(result > 25 and result < 75);
}

test "poisson" {
    var rng = PRNG.init(12345);
    const result = poisson(10.0, &rng);
    // Should be around 10
    try std.testing.expect(result > 0 and result < 30);
}

test "normal" {
    var rng = PRNG.init(12345);
    const result = normal(0.0, 1.0, &rng);
    // Should be within reasonable range
    try std.testing.expect(result > -10 and result < 10);
}

test "exponential" {
    var rng = PRNG.init(12345);
    const result = exponential(1.0, &rng);
    // Should be positive
    try std.testing.expect(result >= 0);
}
