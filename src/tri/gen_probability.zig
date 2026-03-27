//! tri/probability — Probability distributions and sampling
//! Auto-generated from specs/tri/tri_probability.tri
//! TTT Dogfood v0.2 Stage 185

const std = @import("std");
const Random = std.Random.Default;

/// Bernoulli trial with probability p
pub fn bernoulli(p: f64, rng: *Random) bool {
    const u = rng.float(f64);
    return u < p;
}

/// Binomial distribution B(n,p)
pub fn binomial(n: usize, p: f64, rng: *Random) usize {
    var count: usize = 0;
    for (0..n) |_| {
        if (bernoulli(p, rng)) count += 1;
    }
    return count;
}

/// Poisson distribution
pub fn poisson(lambda: f64, rng: *Random) usize {
    if (lambda <= 0) return 0;

    const L = std.math.exp(-lambda);
    var k: usize = 0;
    var prod: f64 = 1.0;

    while (prod > L) {
        k += 1;
        prod *= rng.float(f64);
    }

    return k - 1;
}

/// Normal distribution (Box-Muller)
pub fn normal(mean: f64, std_dev: f64, rng: *Random) f64 {
    // Box-Muller transform
    const u1 = rng.float(f64);
    const u2 = rng.float(f64);

    const z0 = std.math.sqrt(-2.0 * std.math.log(u1)) * std.math.cos(2.0 * std.pi * u2);
    // const z1 = std.math.sqrt(-2.0 * std.math.log(u1)) * std.math.sin(2.0 * std.pi * u2);

    return mean + std_dev * z0;
}

/// Exponential distribution
pub fn exponential(lambda: f64, rng: *Random) f64 {
    if (lambda <= 0) return 0;
    const u = rng.float(f64);
    return -std.math.log(1.0 - u) / lambda;
}

test "bernoulli" {
    var rng = Random.init(@intCast(std.testing.timestamp));
    var count: usize = 0;
    for (0..1000) |_| {
        if (bernoulli(0.5, &rng)) count += 1;
    }
    // Should be around 500
    try std.testing.expect(count > 400 and count < 600);
}

test "binomial" {
    var rng = Random.init(@intCast(std.testing.timestamp));
    const result = binomial(100, 0.5, &rng);
    // Should be around 50
    try std.testing.expect(result > 25 and result < 75);
}

test "poisson" {
    var rng = Random.init(@intCast(std.testing.timestamp));
    const result = poisson(10.0, &rng);
    // Should be around 10
    try std.testing.expect(result > 0 and result < 30);
}

test "normal" {
    var rng = Random.init(@intCast(std.testing.timestamp));
    const result = normal(0.0, 1.0, &rng);
    // Should be within reasonable range
    try std.testing.expect(result > -10 and result < 10);
}

test "exponential" {
    var rng = Random.init(@intCast(std.testing.timestamp));
    const result = exponential(1.0, &rng);
    // Should be positive
    try std.testing.expect(result >= 0);
}
