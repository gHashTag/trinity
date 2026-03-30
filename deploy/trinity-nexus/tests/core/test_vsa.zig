// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY NEXUS - Core VSA Unit Tests
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// TRIT TYPE & CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

const Trit = i8; // -1, 0, +1

const PHI: f64 = 1.618033988749895;
const PHI_SQ: f64 = 2.618033988749895;
const TRINITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// TRIT OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

fn tritMul(a: Trit, b: Trit) Trit {
    return @as(Trit, @intCast(@as(i16, a) * @as(i16, b)));
}

fn tritAdd(a: Trit, b: Trit) Trit {
    const sum = @as(i16, a) + @as(i16, b);
    if (sum > 1) return 1;
    if (sum < -1) return -1;
    return @intCast(sum);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS: Trit Arithmetic
// ═══════════════════════════════════════════════════════════════════════════════

test "trit multiplication identity" {
    // 1 * x = x for all trits
    const trits = [_]Trit{ -1, 0, 1 };
    for (trits) |t| {
        try std.testing.expectEqual(t, tritMul(1, t));
    }
}

test "trit multiplication by zero" {
    const trits = [_]Trit{ -1, 0, 1 };
    for (trits) |t| {
        try std.testing.expectEqual(@as(Trit, 0), tritMul(0, t));
    }
}

test "trit multiplication commutativity" {
    const trits = [_]Trit{ -1, 0, 1 };
    for (trits) |a| {
        for (trits) |b| {
            try std.testing.expectEqual(tritMul(a, b), tritMul(b, a));
        }
    }
}

test "trit negation via multiply by -1" {
    try std.testing.expectEqual(@as(Trit, -1), tritMul(-1, 1));
    try std.testing.expectEqual(@as(Trit, 1), tritMul(-1, -1));
    try std.testing.expectEqual(@as(Trit, 0), tritMul(-1, 0));
}

test "trit addition saturation" {
    // 1 + 1 should saturate to 1
    try std.testing.expectEqual(@as(Trit, 1), tritAdd(1, 1));
    // -1 + -1 should saturate to -1
    try std.testing.expectEqual(@as(Trit, -1), tritAdd(-1, -1));
    // 1 + -1 = 0
    try std.testing.expectEqual(@as(Trit, 0), tritAdd(1, -1));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS: Sacred Constants
// ═══════════════════════════════════════════════════════════════════════════════

test "golden ratio identity: phi^2 + 1/phi^2 = 3" {
    const result = PHI_SQ + (1.0 / PHI_SQ);
    try std.testing.expectApproxEqAbs(TRINITY, result, 1e-10);
}

test "golden ratio: phi^2 = phi + 1" {
    try std.testing.expectApproxEqAbs(PHI + 1.0, PHI * PHI, 1e-10);
}

test "golden ratio: 1/phi = phi - 1" {
    try std.testing.expectApproxEqAbs(PHI - 1.0, 1.0 / PHI, 1e-10);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS: Vector Operations (VSA bind/bundle/permute stubs)
// ═══════════════════════════════════════════════════════════════════════════════

const VEC_DIM = 64;

fn randomTritVector(seed: u64) [VEC_DIM]Trit {
    var vec: [VEC_DIM]Trit = undefined;
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();
    for (&vec) |*v| {
        const r = random.intRangeAtMost(i8, -1, 1);
        v.* = r;
    }
    return vec;
}

fn bind(a: [VEC_DIM]Trit, b: [VEC_DIM]Trit) [VEC_DIM]Trit {
    var result: [VEC_DIM]Trit = undefined;
    for (0..VEC_DIM) |i| {
        result[i] = tritMul(a[i], b[i]);
    }
    return result;
}

fn dotProduct(a: [VEC_DIM]Trit, b: [VEC_DIM]Trit) i64 {
    var sum: i64 = 0;
    for (0..VEC_DIM) |i| {
        sum += @as(i64, a[i]) * @as(i64, b[i]);
    }
    return sum;
}

test "bind is its own inverse" {
    const a = randomTritVector(111);
    const b = randomTritVector(222);
    const bound = bind(a, b);
    const recovered = bind(bound, b);
    // For non-zero b elements, a should be recovered
    for (0..VEC_DIM) |i| {
        if (b[i] != 0) {
            try std.testing.expectEqual(a[i], recovered[i]);
        }
    }
}

test "self-bind produces identity-like vector" {
    const a = randomTritVector(333);
    const self_bound = bind(a, a);
    // a * a: for trits, (-1)*(-1)=1, 0*0=0, 1*1=1
    for (0..VEC_DIM) |i| {
        if (a[i] != 0) {
            try std.testing.expectEqual(@as(Trit, 1), self_bound[i]);
        } else {
            try std.testing.expectEqual(@as(Trit, 0), self_bound[i]);
        }
    }
}

test "dot product of orthogonal-ish vectors near zero" {
    const a = randomTritVector(444);
    const b = randomTritVector(555);
    const dot = dotProduct(a, b);
    // Random trit vectors should have low dot product relative to dimension
    const abs_dot = if (dot < 0) -dot else dot;
    try std.testing.expect(abs_dot < VEC_DIM);
}

test "dot product self is non-negative" {
    const a = randomTritVector(666);
    const dot = dotProduct(a, a);
    try std.testing.expect(dot >= 0);
}
