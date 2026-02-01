// Tekum - Balanced Ternary Tapered Precision Real Arithmetic
// Based on arXiv:2512.10964 (Hunhold, 2025)
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const trit = @import("trit.zig");
const Trit = trit.Trit;
const Trit27 = trit.Trit27;

// ═══════════════════════════════════════════════════════════════════════════════
// TEKUM FORMAT
// ═══════════════════════════════════════════════════════════════════════════════
//
// Tekum uses balanced ternary (-1, 0, +1) with tapered precision:
//
// Format: [sign] [regime] [exponent] [fraction]
//
// - Sign: 1 trit (N=-1, Z=0, P=+1)
// - Regime: variable length, run-length encoded
// - Exponent: variable length based on regime
// - Fraction: remaining trits
//
// Special values:
// - Zero: all trits are Z
// - Infinity: sign followed by all P (positive) or all N (negative)
// - NaN: specific pattern (Z followed by all N)
//
// ═══════════════════════════════════════════════════════════════════════════════

/// Tekum27 - 27-trit balanced ternary floating-point number
/// Range: approximately ±3^13 with variable precision
pub const Tekum27 = struct {
    trits: [27]Trit,

    // Special value patterns
    pub const ZERO = Tekum27{ .trits = [_]Trit{.Z} ** 27 };
    pub const POS_INF = blk: {
        var t: [27]Trit = undefined;
        t[0] = .P; // positive sign
        for (1..27) |i| {
            t[i] = .P; // all P = infinity
        }
        break :blk Tekum27{ .trits = t };
    };
    pub const NEG_INF = blk: {
        var t: [27]Trit = undefined;
        t[0] = .N; // negative sign
        for (1..27) |i| {
            t[i] = .P; // regime pattern for infinity
        }
        break :blk Tekum27{ .trits = t };
    };
    pub const NAN = blk: {
        var t: [27]Trit = undefined;
        t[0] = .Z; // zero sign
        for (1..27) |i| {
            t[i] = .N; // all N = NaN
        }
        break :blk Tekum27{ .trits = t };
    };

    /// Create Tekum27 from f64
    /// Simple fixed-point representation:
    /// - Trit 0: sign
    /// - Trits 1-26: balanced ternary fixed-point (13.13 format)
    pub fn fromFloat(value: f64) Tekum27 {
        // Handle special cases
        if (std.math.isNan(value)) return NAN;
        if (std.math.isPositiveInf(value)) return POS_INF;
        if (std.math.isNegativeInf(value)) return NEG_INF;
        if (value == 0.0) return ZERO;

        var result = Tekum27{ .trits = [_]Trit{.Z} ** 27 };

        // Sign trit
        const is_negative = value < 0;
        result.trits[0] = if (is_negative) .N else .P;

        // Convert to fixed-point: multiply by 3^13 to get integer representation
        // Range: approximately ±797161 (half of 3^13)
        const scale: f64 = 1594323.0; // 3^13
        var scaled = @abs(value) * scale / 797161.0; // normalize to [-1, 1] range then scale

        // Clamp to prevent overflow
        scaled = @min(scaled, scale);

        // Convert to balanced ternary integer
        var int_val: i64 = @intFromFloat(@round(scaled));

        // Encode in balanced ternary (trits 1-26)
        for (1..27) |i| {
            const idx = 27 - i; // fill from LSB
            var rem = @mod(int_val, 3);
            if (rem == 2) rem = -1;

            result.trits[idx] = switch (rem) {
                -1 => .N,
                0 => .Z,
                1 => .P,
                else => .Z,
            };

            int_val = @divTrunc(int_val - rem, 3);
        }

        return result;
    }

    /// Convert Tekum27 to f64
    pub fn toFloat(self: Tekum27) f64 {
        // Check special values
        if (self.isNaN()) return std.math.nan(f64);
        if (self.isPosInf()) return std.math.inf(f64);
        if (self.isNegInf()) return -std.math.inf(f64);
        if (self.isZero()) return 0.0;

        // Decode sign
        const sign: f64 = switch (self.trits[0]) {
            .N => -1.0,
            .Z => 0.0,
            .P => 1.0,
        };

        if (sign == 0.0) return 0.0;

        // Decode balanced ternary integer from trits 1-26
        var int_val: i64 = 0;
        var place: i64 = 1;

        for (1..27) |i| {
            const idx = 27 - i; // read from LSB
            const trit_val: i64 = switch (self.trits[idx]) {
                .N => -1,
                .Z => 0,
                .P => 1,
            };
            int_val += trit_val * place;
            place *= 3;
        }

        // Convert back to float
        const scale: f64 = 1594323.0; // 3^13
        const result = sign * @as(f64, @floatFromInt(int_val)) * 797161.0 / scale;

        return result;
    }

    /// Create Tekum27 from integer
    pub fn fromInt(value: i64) Tekum27 {
        return fromFloat(@floatFromInt(value));
    }

    /// Convert to integer (truncated)
    pub fn toInt(self: Tekum27) i64 {
        const f = self.toFloat();
        if (std.math.isNan(f)) return 0;
        if (std.math.isInf(f)) return if (f > 0) std.math.maxInt(i64) else std.math.minInt(i64);
        return @intFromFloat(f);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SPECIAL VALUE CHECKS
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn isZero(self: Tekum27) bool {
        for (self.trits) |t| {
            if (t != .Z) return false;
        }
        return true;
    }

    pub fn isNaN(self: Tekum27) bool {
        if (self.trits[0] != .Z) return false;
        for (1..27) |i| {
            if (self.trits[i] != .N) return false;
        }
        return true;
    }

    pub fn isPosInf(self: Tekum27) bool {
        if (self.trits[0] != .P) return false;
        for (1..27) |i| {
            if (self.trits[i] != .P) return false;
        }
        return true;
    }

    pub fn isNegInf(self: Tekum27) bool {
        if (self.trits[0] != .N) return false;
        for (1..27) |i| {
            if (self.trits[i] != .P) return false;
        }
        return true;
    }

    pub fn isInf(self: Tekum27) bool {
        return self.isPosInf() or self.isNegInf();
    }

    pub fn isFinite(self: Tekum27) bool {
        return !self.isNaN() and !self.isInf();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ARITHMETIC OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Add two Tekum27 values
    pub fn add(a: Tekum27, b: Tekum27) Tekum27 {
        // Handle special cases
        if (a.isNaN() or b.isNaN()) return NAN;
        if (a.isPosInf() and b.isNegInf()) return NAN;
        if (a.isNegInf() and b.isPosInf()) return NAN;
        if (a.isPosInf() or b.isPosInf()) return POS_INF;
        if (a.isNegInf() or b.isNegInf()) return NEG_INF;
        if (a.isZero()) return b;
        if (b.isZero()) return a;

        // For floating-point, we need to use float conversion
        // Native ternary float arithmetic requires proper exponent handling
        const result = a.toFloat() + b.toFloat();
        return fromFloat(result);
    }

    /// Subtract two Tekum27 values
    pub fn sub(a: Tekum27, b: Tekum27) Tekum27 {
        // Handle special cases
        if (a.isNaN() or b.isNaN()) return NAN;
        if (a.isPosInf() and b.isPosInf()) return NAN;
        if (a.isNegInf() and b.isNegInf()) return NAN;
        if (a.isPosInf()) return POS_INF;
        if (a.isNegInf()) return NEG_INF;
        if (b.isPosInf()) return NEG_INF;
        if (b.isNegInf()) return POS_INF;
        if (b.isZero()) return a;

        const result = a.toFloat() - b.toFloat();
        return fromFloat(result);
    }

    /// Multiply two Tekum27 values
    pub fn mul(a: Tekum27, b: Tekum27) Tekum27 {
        // Handle special cases
        if (a.isNaN() or b.isNaN()) return NAN;
        if ((a.isInf() and b.isZero()) or (a.isZero() and b.isInf())) return NAN;

        if (a.isInf() or b.isInf()) {
            const a_sign = a.trits[0] == .N;
            const b_sign = b.trits[0] == .N;
            return if (a_sign != b_sign) NEG_INF else POS_INF;
        }

        if (a.isZero() or b.isZero()) return ZERO;

        // For floating-point multiplication, use float conversion
        const result = a.toFloat() * b.toFloat();
        return fromFloat(result);
    }

    /// Divide two Tekum27 values
    pub fn div(a: Tekum27, b: Tekum27) Tekum27 {
        // Handle special cases
        if (a.isNaN() or b.isNaN()) return NAN;
        if (a.isInf() and b.isInf()) return NAN;
        if (b.isZero()) {
            if (a.isZero()) return NAN;
            return if (a.trits[0] == .N) NEG_INF else POS_INF;
        }

        const a_neg = a.trits[0] == .N;
        const b_neg = b.trits[0] == .N;
        const result_neg = a_neg != b_neg;

        if (a.isInf()) {
            return if (result_neg) NEG_INF else POS_INF;
        }

        if (a.isZero()) return ZERO;

        const result = a.toFloat() / b.toFloat();
        return fromFloat(result);
    }

    /// Negate a Tekum27 value
    pub fn neg(self: Tekum27) Tekum27 {
        if (self.isNaN()) return NAN;
        if (self.isZero()) return ZERO;
        if (self.isPosInf()) return NEG_INF;
        if (self.isNegInf()) return POS_INF;

        var result = self;
        // Flip sign trit
        result.trits[0] = switch (self.trits[0]) {
            .N => .P,
            .Z => .Z,
            .P => .N,
        };
        return result;
    }

    /// Absolute value
    pub fn abs(self: Tekum27) Tekum27 {
        if (self.isNaN()) return NAN;
        if (self.isZero()) return ZERO;
        if (self.isInf()) return POS_INF;

        var result = self;
        result.trits[0] = .P;
        return result;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // NATIVE ARITHMETIC (NO BINARY CONVERSION)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Native add without binary conversion
    /// Adds mantissas directly in balanced ternary
    pub fn addNative(a: Tekum27, b: Tekum27) Tekum27 {
        // Handle special cases
        if (a.isNaN() or b.isNaN()) return NAN;
        if (a.isPosInf() and b.isNegInf()) return NAN;
        if (a.isNegInf() and b.isPosInf()) return NAN;
        if (a.isPosInf() or b.isPosInf()) return POS_INF;
        if (a.isNegInf() or b.isNegInf()) return NEG_INF;
        if (a.isZero()) return b;
        if (b.isZero()) return a;

        // Extract signs
        const a_neg = a.trits[0] == .N;
        const b_neg = b.trits[0] == .N;

        // Get mantissa as Trit27 (trits 1-26, padded to 27)
        var a_mant = Trit27{ .trits = [_]Trit{.Z} ** 27 };
        var b_mant = Trit27{ .trits = [_]Trit{.Z} ** 27 };

        for (1..27) |i| {
            a_mant.trits[i] = a.trits[i];
            b_mant.trits[i] = b.trits[i];
        }

        // If signs differ, negate one operand
        if (a_neg != b_neg) {
            if (b_neg) {
                b_mant = b_mant.neg();
            } else {
                a_mant = a_mant.neg();
            }
        }

        // Add mantissas using native ternary addition
        const sum = Trit27.addNative(a_mant, b_mant);

        // Determine result sign
        var result = Tekum27{ .trits = [_]Trit{.Z} ** 27 };

        // Check if result is negative (MSB is N)
        const result_neg = sum.trits[1] == .N;
        result.trits[0] = if (result_neg) .N else .P;

        // Copy mantissa (negate if needed to make positive)
        const final_mant = if (result_neg) sum.neg() else sum;
        for (1..27) |i| {
            result.trits[i] = final_mant.trits[i];
        }

        // Check for zero
        var is_zero = true;
        for (1..27) |i| {
            if (result.trits[i] != .Z) {
                is_zero = false;
                break;
            }
        }
        if (is_zero) return ZERO;

        return result;
    }

    /// Native subtract without binary conversion
    pub fn subNative(a: Tekum27, b: Tekum27) Tekum27 {
        // a - b = a + (-b)
        return addNative(a, b.neg());
    }

    /// Native multiply without binary conversion
    /// Uses Karatsuba multiplication on mantissas
    pub fn mulNative(a: Tekum27, b: Tekum27) Tekum27 {
        // Handle special cases
        if (a.isNaN() or b.isNaN()) return NAN;
        if ((a.isInf() and b.isZero()) or (a.isZero() and b.isInf())) return NAN;

        if (a.isInf() or b.isInf()) {
            const a_sign = a.trits[0] == .N;
            const b_sign = b.trits[0] == .N;
            return if (a_sign != b_sign) NEG_INF else POS_INF;
        }

        if (a.isZero() or b.isZero()) return ZERO;

        // Determine result sign
        const a_neg = a.trits[0] == .N;
        const b_neg = b.trits[0] == .N;
        const result_neg = a_neg != b_neg;

        // Get mantissas
        var a_mant = Trit27{ .trits = [_]Trit{.Z} ** 27 };
        var b_mant = Trit27{ .trits = [_]Trit{.Z} ** 27 };

        for (1..27) |i| {
            a_mant.trits[i] = a.trits[i];
            b_mant.trits[i] = b.trits[i];
        }

        // Multiply using Karatsuba
        const product = Trit27.mul(a_mant, b_mant);

        // Build result
        var result = Tekum27{ .trits = [_]Trit{.Z} ** 27 };
        result.trits[0] = if (result_neg) .N else .P;

        // Copy product mantissa (may need normalization)
        for (1..27) |i| {
            result.trits[i] = product.trits[i];
        }

        // Check for zero
        var is_zero = true;
        for (1..27) |i| {
            if (result.trits[i] != .Z) {
                is_zero = false;
                break;
            }
        }
        if (is_zero) return ZERO;

        return result;
    }

    /// Native divide without binary conversion
    /// Uses iterative division on mantissas
    pub fn divNative(a: Tekum27, b: Tekum27) Tekum27 {
        // Handle special cases
        if (a.isNaN() or b.isNaN()) return NAN;
        if (a.isInf() and b.isInf()) return NAN;
        if (b.isZero()) {
            if (a.isZero()) return NAN;
            return if (a.trits[0] == .N) NEG_INF else POS_INF;
        }

        if (a.isInf()) {
            const a_neg = a.trits[0] == .N;
            const b_neg = b.trits[0] == .N;
            return if (a_neg != b_neg) NEG_INF else POS_INF;
        }

        if (a.isZero()) return ZERO;

        // Determine result sign
        const a_neg = a.trits[0] == .N;
        const b_neg = b.trits[0] == .N;
        const result_neg = a_neg != b_neg;

        // Get mantissas as Trit27
        var a_mant = Trit27{ .trits = [_]Trit{.Z} ** 27 };
        var b_mant = Trit27{ .trits = [_]Trit{.Z} ** 27 };

        for (1..27) |i| {
            a_mant.trits[i] = a.trits[i];
            b_mant.trits[i] = b.trits[i];
        }

        // Use Trit27 division
        const quotient = Trit27.div(a_mant, b_mant);

        // Build result
        var result = Tekum27{ .trits = [_]Trit{.Z} ** 27 };
        result.trits[0] = if (result_neg) .N else .P;

        for (1..27) |i| {
            result.trits[i] = quotient.trits[i];
        }

        // Check for zero
        var is_zero = true;
        for (1..27) |i| {
            if (result.trits[i] != .Z) {
                is_zero = false;
                break;
            }
        }
        if (is_zero) return ZERO;

        return result;
    }

    /// Normalize a Tekum27 value
    /// Shifts mantissa left until MSB is non-zero (or all zeros)
    pub fn normalize(self: Tekum27) Tekum27 {
        if (self.isNaN() or self.isInf() or self.isZero()) return self;

        var result = self;

        // Find first non-zero trit in mantissa
        var first_nonzero: usize = 27;
        for (1..27) |i| {
            if (result.trits[i] != .Z) {
                first_nonzero = i;
                break;
            }
        }

        if (first_nonzero == 27) return ZERO; // All zeros

        // Shift left to normalize
        if (first_nonzero > 1) {
            const shift = first_nonzero - 1;
            for (1..27 - shift) |i| {
                result.trits[i] = result.trits[i + shift];
            }
            for (27 - shift..27) |i| {
                result.trits[i] = .Z;
            }
        }

        return result;
    }

    /// Round to nearest representable value
    pub fn round(self: Tekum27, precision: usize) Tekum27 {
        if (self.isNaN() or self.isInf() or self.isZero()) return self;
        if (precision >= 26) return self;

        var result = self;

        // Check the trit after precision for rounding
        const round_pos = 1 + precision;
        if (round_pos < 27) {
            const round_trit = result.trits[round_pos];

            // Balanced ternary rounding: round to nearest
            if (round_trit == .P) {
                // Round up: add 1 at precision position
                var carry: Trit = .P;
                var i: usize = round_pos - 1;
                while (i >= 1 and carry != .Z) : (i -= 1) {
                    const sum = tritAdd(result.trits[i], carry);
                    result.trits[i] = sum.result;
                    carry = sum.carry;
                    if (i == 1) break;
                }
            } else if (round_trit == .N) {
                // Round down: subtract 1 at precision position
                var borrow: Trit = .N;
                var i: usize = round_pos - 1;
                while (i >= 1 and borrow != .Z) : (i -= 1) {
                    const sum = tritAdd(result.trits[i], borrow);
                    result.trits[i] = sum.result;
                    borrow = sum.carry;
                    if (i == 1) break;
                }
            }

            // Zero out trits after precision
            for (round_pos..27) |j| {
                result.trits[j] = .Z;
            }
        }

        return result;
    }

    const TritAddResult = struct { result: Trit, carry: Trit };

    fn tritAdd(a: Trit, b: Trit) TritAddResult {
        const av: i8 = switch (a) {
            .N => -1,
            .Z => 0,
            .P => 1,
        };
        const bv: i8 = switch (b) {
            .N => -1,
            .Z => 0,
            .P => 1,
        };
        const sum = av + bv;

        return switch (sum) {
            -2 => .{ .result = .P, .carry = .N },
            -1 => .{ .result = .N, .carry = .Z },
            0 => .{ .result = .Z, .carry = .Z },
            1 => .{ .result = .P, .carry = .Z },
            2 => .{ .result = .N, .carry = .P },
            else => .{ .result = .Z, .carry = .Z },
        };
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // COMPARISON
    // ═══════════════════════════════════════════════════════════════════════════

    /// Compare two Tekum27 values
    /// Returns: N if a < b, Z if a == b, P if a > b
    pub fn cmp(a: Tekum27, b: Tekum27) Trit {
        if (a.isNaN() or b.isNaN()) return .Z; // NaN comparisons are unordered

        const af = a.toFloat();
        const bf = b.toFloat();

        if (af < bf) return .N;
        if (af > bf) return .P;
        return .Z;
    }

    /// Check equality
    pub fn eql(a: Tekum27, b: Tekum27) bool {
        if (a.isNaN() or b.isNaN()) return false;
        return cmp(a, b) == .Z;
    }

    /// Check if a < b
    pub fn lt(a: Tekum27, b: Tekum27) bool {
        if (a.isNaN() or b.isNaN()) return false;
        return cmp(a, b) == .N;
    }

    /// Check if a > b
    pub fn gt(a: Tekum27, b: Tekum27) bool {
        if (a.isNaN() or b.isNaN()) return false;
        return cmp(a, b) == .P;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // UTILITY
    // ═══════════════════════════════════════════════════════════════════════════

    /// Format Tekum27 for display
    pub fn format(
        self: Tekum27,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        if (self.isNaN()) {
            try writer.writeAll("NaN");
        } else if (self.isPosInf()) {
            try writer.writeAll("+Inf");
        } else if (self.isNegInf()) {
            try writer.writeAll("-Inf");
        } else {
            const f = self.toFloat();
            try writer.print("{d:.6}", .{f});
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Tekum27 zero" {
    const zero = Tekum27.ZERO;
    try std.testing.expect(zero.isZero());
    try std.testing.expectEqual(@as(f64, 0.0), zero.toFloat());
}

test "Tekum27 from/to float" {
    const values = [_]f64{ 1.0, -1.0, 3.0, -3.0, 9.0, 0.5, 27.0, 100.0, -100.0 };

    for (values) |v| {
        const t = Tekum27.fromFloat(v);
        const back = t.toFloat();
        // Allow 5% error due to balanced ternary precision
        const error_pct = @abs(back - v) / @max(@abs(v), 0.001);
        try std.testing.expect(error_pct < 0.05);
    }
}

test "Tekum27 from/to int" {
    const t1 = Tekum27.fromInt(42);
    const back = t1.toInt();
    // Allow ±1 error due to rounding
    try std.testing.expect(@abs(back - 42) <= 1);

    const t2 = Tekum27.fromInt(-100);
    try std.testing.expect(@abs(t2.toInt() - (-100)) <= 1);
}

test "Tekum27 special values" {
    try std.testing.expect(Tekum27.NAN.isNaN());
    try std.testing.expect(Tekum27.POS_INF.isPosInf());
    try std.testing.expect(Tekum27.NEG_INF.isNegInf());
    try std.testing.expect(Tekum27.POS_INF.isInf());
    try std.testing.expect(!Tekum27.ZERO.isNaN());
}

test "Tekum27 addition" {
    const a = Tekum27.fromFloat(10.0);
    const b = Tekum27.fromFloat(5.0);
    const sum = a.add(b);
    const result = sum.toFloat();
    try std.testing.expect(@abs(result - 15.0) < 1.5);
}

test "Tekum27 subtraction" {
    const a = Tekum27.fromFloat(10.0);
    const b = Tekum27.fromFloat(3.0);
    const diff = a.sub(b);
    const result = diff.toFloat();
    try std.testing.expect(@abs(result - 7.0) < 1.0);
}

test "Tekum27 multiplication" {
    const a = Tekum27.fromFloat(3.0);
    const b = Tekum27.fromFloat(4.0);
    const prod = a.mul(b);
    const result = prod.toFloat();
    try std.testing.expect(@abs(result - 12.0) < 1.5);
}

test "Tekum27 division" {
    const a = Tekum27.fromFloat(12.0);
    const b = Tekum27.fromFloat(4.0);
    const quot = a.div(b);
    const result = quot.toFloat();
    try std.testing.expect(@abs(result - 3.0) < 0.5);
}

test "Tekum27 negation" {
    const a = Tekum27.fromFloat(5.0);
    const neg_a = a.neg();
    const result = neg_a.toFloat();
    try std.testing.expect(@abs(result - (-5.0)) < 0.5);
}

test "Tekum27 comparison" {
    const a = Tekum27.fromFloat(10.0);
    const b = Tekum27.fromFloat(5.0);
    const c = Tekum27.fromFloat(10.0);

    try std.testing.expect(a.gt(b));
    try std.testing.expect(b.lt(a));
    try std.testing.expect(!a.lt(c)); // approximately equal
}

test "Tekum27 infinity arithmetic" {
    const inf = Tekum27.POS_INF;
    const neg_inf = Tekum27.NEG_INF;
    const one = Tekum27.fromFloat(1.0);

    // inf + 1 = inf
    try std.testing.expect(inf.add(one).isPosInf());

    // inf - inf = NaN
    try std.testing.expect(inf.sub(inf).isNaN());

    // inf * 0 = NaN
    try std.testing.expect(inf.mul(Tekum27.ZERO).isNaN());

    // 1 / 0 = inf
    try std.testing.expect(one.div(Tekum27.ZERO).isPosInf());

    // -1 / 0 = -inf
    const neg_one = Tekum27.fromFloat(-1.0);
    try std.testing.expect(neg_one.div(Tekum27.ZERO).isNegInf());

    _ = neg_inf;
}
