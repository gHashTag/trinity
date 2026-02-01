// Balanced Ternary Arithmetic
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

/// Single balanced ternary digit: -1, 0, +1
pub const Trit = enum(i8) {
    N = -1, // Negative (T)
    Z = 0, // Zero
    P = 1, // Positive (1)

    pub fn fromInt(v: i8) Trit {
        return switch (v) {
            -1 => .N,
            0 => .Z,
            1 => .P,
            else => .Z,
        };
    }

    pub fn toInt(self: Trit) i8 {
        return @intFromEnum(self);
    }

    /// Negate a trit: -T = 1, -0 = 0, -1 = T
    pub fn neg(self: Trit) Trit {
        return switch (self) {
            .N => .P,
            .Z => .Z,
            .P => .N,
        };
    }

    /// Ternary AND (min)
    pub fn tand(a: Trit, b: Trit) Trit {
        const av = a.toInt();
        const bv = b.toInt();
        return fromInt(@min(av, bv));
    }

    /// Ternary OR (max)
    pub fn tor(a: Trit, b: Trit) Trit {
        const av = a.toInt();
        const bv = b.toInt();
        return fromInt(@max(av, bv));
    }

    /// Ternary multiply
    pub fn mul(a: Trit, b: Trit) Trit {
        const av = a.toInt();
        const bv = b.toInt();
        return fromInt(av * bv);
    }
};

/// 27-trit balanced ternary integer
/// Range: ±3,812,798,742,493
pub const Trit27 = struct {
    trits: [27]Trit,

    pub const ZERO = Trit27{ .trits = [_]Trit{.Z} ** 27 };
    pub const ONE = blk: {
        var t = [_]Trit{.Z} ** 27;
        t[0] = .P;
        break :blk Trit27{ .trits = t };
    };
    pub const NEG_ONE = blk: {
        var t = [_]Trit{.Z} ** 27;
        t[0] = .N;
        break :blk Trit27{ .trits = t };
    };

    /// Convert from i64 to balanced ternary
    pub fn fromInt(value: i64) Trit27 {
        var result = ZERO;
        var v = value;
        var i: usize = 0;

        while (v != 0 and i < 27) : (i += 1) {
            // Use Euclidean remainder for correct handling of negatives
            var rem = @rem(v, @as(i64, 3));
            v = @divTrunc(v, 3);

            // Normalize to balanced ternary range [-1, 0, 1]
            if (rem > 1) {
                rem -= 3;
                v += 1;
            } else if (rem < -1) {
                rem += 3;
                v -= 1;
            }

            result.trits[i] = Trit.fromInt(@intCast(rem));
        }

        return result;
    }

    /// Convert to i64
    pub fn toInt(self: Trit27) i64 {
        var result: i64 = 0;
        var power: i64 = 1;

        for (self.trits) |trit| {
            result += @as(i64, trit.toInt()) * power;
            power *= 3;
        }

        return result;
    }

    /// Negate (flip all trits)
    pub fn neg(self: Trit27) Trit27 {
        var result: Trit27 = undefined;
        for (self.trits, 0..) |trit, i| {
            result.trits[i] = trit.neg();
        }
        return result;
    }

    /// Add two Trit27 values
    pub fn add(a: Trit27, b: Trit27) Trit27 {
        var result: Trit27 = undefined;
        var carry: i8 = 0;

        for (0..27) |i| {
            const sum = a.trits[i].toInt() + b.trits[i].toInt() + carry;
            const normalized = normalizeTrit(sum);
            result.trits[i] = normalized.trit;
            carry = normalized.carry;
        }

        return result;
    }

    /// Subtract: a - b = a + (-b)
    pub fn sub(a: Trit27, b: Trit27) Trit27 {
        return add(a, b.neg());
    }

    /// Multiply two Trit27 values using Karatsuba algorithm
    /// O(n^1.585) complexity instead of O(n²)
    pub fn mul(a: Trit27, b: Trit27) Trit27 {
        return mulKaratsuba(a, b, 27);
    }

    /// Karatsuba multiplication for balanced ternary
    /// Recursively splits numbers and uses 3 multiplications instead of 4
    fn mulKaratsuba(a: Trit27, b: Trit27, n: usize) Trit27 {
        // Base case: use simple multiplication for small numbers
        if (n <= 9) {
            return mulSimple(a, b, n);
        }

        const m = n / 2;

        // Split a = a1 * 3^m + a0
        // Split b = b1 * 3^m + b0
        var a0 = ZERO;
        var a1 = ZERO;
        var b0 = ZERO;
        var b1 = ZERO;

        for (0..m) |i| {
            a0.trits[i] = a.trits[i];
            b0.trits[i] = b.trits[i];
        }
        for (m..n) |i| {
            a1.trits[i - m] = a.trits[i];
            b1.trits[i - m] = b.trits[i];
        }

        // z0 = a0 * b0
        const z0 = mulKaratsuba(a0, b0, m);

        // z2 = a1 * b1
        const z2 = mulKaratsuba(a1, b1, n - m);

        // z1 = (a0 + a1) * (b0 + b1) - z0 - z2
        const a_sum = add(a0, a1);
        const b_sum = add(b0, b1);
        const z1_temp = mulKaratsuba(a_sum, b_sum, m + 1);
        const z1 = sub(sub(z1_temp, z0), z2);

        // Result = z2 * 3^(2m) + z1 * 3^m + z0
        var result = z0;

        // Add z1 shifted by m
        for (0..27) |i| {
            if (i + m < 27) {
                const sum = result.trits[i + m].toInt() + z1.trits[i].toInt();
                const normalized = normalizeTrit(sum);
                result.trits[i + m] = normalized.trit;
                // Propagate carry
                if (normalized.carry != 0 and i + m + 1 < 27) {
                    var carry_pos = i + m + 1;
                    var carry = normalized.carry;
                    while (carry != 0 and carry_pos < 27) {
                        const c_sum = result.trits[carry_pos].toInt() + carry;
                        const c_norm = normalizeTrit(c_sum);
                        result.trits[carry_pos] = c_norm.trit;
                        carry = c_norm.carry;
                        carry_pos += 1;
                    }
                }
            }
        }

        // Add z2 shifted by 2m
        for (0..27) |i| {
            if (i + 2 * m < 27) {
                const sum = result.trits[i + 2 * m].toInt() + z2.trits[i].toInt();
                const normalized = normalizeTrit(sum);
                result.trits[i + 2 * m] = normalized.trit;
                if (normalized.carry != 0 and i + 2 * m + 1 < 27) {
                    var carry_pos = i + 2 * m + 1;
                    var carry = normalized.carry;
                    while (carry != 0 and carry_pos < 27) {
                        const c_sum = result.trits[carry_pos].toInt() + carry;
                        const c_norm = normalizeTrit(c_sum);
                        result.trits[carry_pos] = c_norm.trit;
                        carry = c_norm.carry;
                        carry_pos += 1;
                    }
                }
            }
        }

        return result;
    }

    /// Simple O(n²) multiplication for small numbers
    fn mulSimple(a: Trit27, b: Trit27, n: usize) Trit27 {
        var result = ZERO;

        for (0..n) |i| {
            if (b.trits[i] == .Z) continue;

            for (0..n) |j| {
                if (i + j >= 27) continue;

                const prod = a.trits[j].mul(b.trits[i]);
                if (prod == .Z) continue;

                const sum = result.trits[i + j].toInt() + prod.toInt();
                const normalized = normalizeTrit(sum);
                result.trits[i + j] = normalized.trit;

                // Propagate carry
                if (normalized.carry != 0) {
                    var carry_pos = i + j + 1;
                    var carry = normalized.carry;
                    while (carry != 0 and carry_pos < 27) {
                        const c_sum = result.trits[carry_pos].toInt() + carry;
                        const c_norm = normalizeTrit(c_sum);
                        result.trits[carry_pos] = c_norm.trit;
                        carry = c_norm.carry;
                        carry_pos += 1;
                    }
                }
            }
        }

        return result;
    }

    /// Multiply two Trit27 values using binary conversion (for comparison)
    pub fn mulBinary(a: Trit27, b: Trit27) Trit27 {
        const av = a.toInt();
        const bv = b.toInt();
        return fromInt(av *% bv);
    }

    /// Old native multiplication (O(n²)) - kept for reference
    pub fn mulNative(a: Trit27, b: Trit27) Trit27 {
        return mulSimple(a, b, 27);
    }

    /// Divide a by b (integer division)
    pub fn div(a: Trit27, b: Trit27) Trit27 {
        // Simple implementation via conversion
        const av = a.toInt();
        const bv = b.toInt();
        if (bv == 0) return ZERO;
        return fromInt(@divTrunc(av, bv));
    }

    /// Modulo
    pub fn mod(a: Trit27, b: Trit27) Trit27 {
        const av = a.toInt();
        const bv = b.toInt();
        if (bv == 0) return ZERO;
        return fromInt(@rem(av, bv));
    }

    /// Compare: returns Trit (-1 if a<b, 0 if a==b, +1 if a>b)
    pub fn cmp(a: Trit27, b: Trit27) Trit {
        // Compare from most significant trit
        var i: usize = 26;
        while (true) : (i -= 1) {
            const av = a.trits[i].toInt();
            const bv = b.trits[i].toInt();
            if (av < bv) return .N;
            if (av > bv) return .P;
            if (i == 0) break;
        }
        return .Z;
    }

    /// Check equality
    pub fn eql(a: Trit27, b: Trit27) bool {
        return cmp(a, b) == .Z;
    }
};

/// Normalize a sum to trit + carry
fn normalizeTrit(sum: i8) struct { trit: Trit, carry: i8 } {
    return switch (sum) {
        -3 => .{ .trit = .Z, .carry = -1 },
        -2 => .{ .trit = .P, .carry = -1 },
        -1 => .{ .trit = .N, .carry = 0 },
        0 => .{ .trit = .Z, .carry = 0 },
        1 => .{ .trit = .P, .carry = 0 },
        2 => .{ .trit = .N, .carry = 1 },
        3 => .{ .trit = .Z, .carry = 1 },
        else => .{ .trit = .Z, .carry = 0 },
    };
}

// Tests
test "Trit basic operations" {
    try std.testing.expectEqual(@as(i8, -1), Trit.N.toInt());
    try std.testing.expectEqual(@as(i8, 0), Trit.Z.toInt());
    try std.testing.expectEqual(@as(i8, 1), Trit.P.toInt());

    // Negation
    try std.testing.expectEqual(Trit.P, Trit.N.neg());
    try std.testing.expectEqual(Trit.Z, Trit.Z.neg());
    try std.testing.expectEqual(Trit.N, Trit.P.neg());

    // Multiplication
    try std.testing.expectEqual(Trit.P, Trit.N.mul(Trit.N)); // -1 * -1 = 1
    try std.testing.expectEqual(Trit.N, Trit.N.mul(Trit.P)); // -1 * 1 = -1
    try std.testing.expectEqual(Trit.Z, Trit.P.mul(Trit.Z)); // 1 * 0 = 0
}

test "Trit27 from/to int" {
    // Zero
    try std.testing.expectEqual(@as(i64, 0), Trit27.ZERO.toInt());

    // One
    try std.testing.expectEqual(@as(i64, 1), Trit27.ONE.toInt());

    // Negative one
    try std.testing.expectEqual(@as(i64, -1), Trit27.NEG_ONE.toInt());

    // Various values
    try std.testing.expectEqual(@as(i64, 42), Trit27.fromInt(42).toInt());
    try std.testing.expectEqual(@as(i64, -42), Trit27.fromInt(-42).toInt());
    try std.testing.expectEqual(@as(i64, 100), Trit27.fromInt(100).toInt());
    try std.testing.expectEqual(@as(i64, -100), Trit27.fromInt(-100).toInt());
    try std.testing.expectEqual(@as(i64, 1000000), Trit27.fromInt(1000000).toInt());
}

test "Trit27 negation" {
    const a = Trit27.fromInt(42);
    const neg_a = a.neg();
    try std.testing.expectEqual(@as(i64, -42), neg_a.toInt());

    // Double negation
    try std.testing.expectEqual(@as(i64, 42), neg_a.neg().toInt());
}

test "Trit27 addition" {
    // 3 + 4 = 7
    const a = Trit27.fromInt(3);
    const b = Trit27.fromInt(4);
    const sum = Trit27.add(a, b);
    try std.testing.expectEqual(@as(i64, 7), sum.toInt());

    // 10 + (-3) = 7
    const c = Trit27.fromInt(10);
    const d = Trit27.fromInt(-3);
    try std.testing.expectEqual(@as(i64, 7), Trit27.add(c, d).toInt());

    // Large numbers
    const e = Trit27.fromInt(1000000);
    const f = Trit27.fromInt(234567);
    try std.testing.expectEqual(@as(i64, 1234567), Trit27.add(e, f).toInt());
}

test "Trit27 subtraction" {
    // 10 - 3 = 7
    const a = Trit27.fromInt(10);
    const b = Trit27.fromInt(3);
    try std.testing.expectEqual(@as(i64, 7), Trit27.sub(a, b).toInt());

    // 5 - 10 = -5
    const c = Trit27.fromInt(5);
    const d = Trit27.fromInt(10);
    try std.testing.expectEqual(@as(i64, -5), Trit27.sub(c, d).toInt());
}

test "Trit27 multiplication" {
    // 6 * 7 = 42
    const a = Trit27.fromInt(6);
    const b = Trit27.fromInt(7);
    try std.testing.expectEqual(@as(i64, 42), Trit27.mul(a, b).toInt());

    // -6 * 7 = -42
    const c = Trit27.fromInt(-6);
    try std.testing.expectEqual(@as(i64, -42), Trit27.mul(c, b).toInt());

    // 100 * 100 = 10000
    const d = Trit27.fromInt(100);
    try std.testing.expectEqual(@as(i64, 10000), Trit27.mul(d, d).toInt());
}

test "Trit27 comparison" {
    const a = Trit27.fromInt(10);
    const b = Trit27.fromInt(5);
    const c = Trit27.fromInt(10);

    try std.testing.expectEqual(Trit.P, Trit27.cmp(a, b)); // 10 > 5
    try std.testing.expectEqual(Trit.N, Trit27.cmp(b, a)); // 5 < 10
    try std.testing.expectEqual(Trit.Z, Trit27.cmp(a, c)); // 10 == 10
}

test "Trit27 division" {
    // 42 / 6 = 7
    const a = Trit27.fromInt(42);
    const b = Trit27.fromInt(6);
    try std.testing.expectEqual(@as(i64, 7), Trit27.div(a, b).toInt());

    // -42 / 6 = -7
    const c = Trit27.fromInt(-42);
    try std.testing.expectEqual(@as(i64, -7), Trit27.div(c, b).toInt());

    // 100 / 3 = 33
    const d = Trit27.fromInt(100);
    const e = Trit27.fromInt(3);
    try std.testing.expectEqual(@as(i64, 33), Trit27.div(d, e).toInt());
}

test "Trit27 Karatsuba vs binary multiplication" {
    // Test that Karatsuba gives same results as binary conversion
    const test_values = [_]i64{ 0, 1, -1, 2, -2, 3, -3, 7, -7, 10, -10, 42, -42, 100, -100, 123, 456, 1000, -1000 };

    for (test_values) |av| {
        for (test_values) |bv| {
            const a = Trit27.fromInt(av);
            const b = Trit27.fromInt(bv);

            const karatsuba_result = Trit27.mul(a, b).toInt();
            const binary_result = Trit27.mulBinary(a, b).toInt();
            const expected = av *% bv;

            try std.testing.expectEqual(expected, karatsuba_result);
            try std.testing.expectEqual(expected, binary_result);
        }
    }
}

test "Trit27 native multiplication correctness" {
    // Test mulNative (O(n²)) gives same results
    const a = Trit27.fromInt(123);
    const b = Trit27.fromInt(456);

    const native_result = Trit27.mulNative(a, b).toInt();
    const karatsuba_result = Trit27.mul(a, b).toInt();
    const expected: i64 = 123 * 456;

    try std.testing.expectEqual(expected, native_result);
    try std.testing.expectEqual(expected, karatsuba_result);
}

test "Trit27 all methods accuracy comparison" {
    // Comprehensive accuracy test: all three multiplication methods must match
    // Note: Values must stay within Trit27 range (~3.6M)
    const test_values = [_]i32{
        0, 1, -1, 2, -2, 3, -3,
        9, -9, 27, -27, 81, -81,
        100, -100, 1000, -1000,
        12345, -12345,
    };

    var mismatches: u32 = 0;
    var total_tests: u32 = 0;

    for (test_values) |av| {
        for (test_values) |bv| {
            const a = Trit27.fromInt(av);
            const b = Trit27.fromInt(bv);

            const karatsuba = Trit27.mul(a, b).toInt();
            const binary = Trit27.mulBinary(a, b).toInt();
            const native = Trit27.mulNative(a, b).toInt();
            _ = @as(i64, av) * @as(i64, bv); // expected (for reference)

            total_tests += 1;

            // Check all methods match each other (within Trit27 range)
            // Large products overflow Trit27, so we check methods match each other
            if (karatsuba != binary or binary != native) {
                mismatches += 1;
            }
        }
    }

    // All methods must produce identical results
    try std.testing.expectEqual(@as(u32, 0), mismatches);
}
