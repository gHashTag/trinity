//! Ternary Logic — Generated from specs/ternary/logic.tri
//! φ² + 1/φ² = 3 | TRINITY
//!
//! DO NOT EDIT: This file is generated from logic.tri spec
//! Modify spec and regenerate: tri vibee-gen ternary_logic

const std = @import("std");

/// ═══════════════════════════════════════════════════════════════
/// TERNARY VALUES
/// ══════════════════════════════════════════════════════════════
/// Balanced ternary digit: {-1, 0, +1}
pub const Trit = enum(i8) {
    /// False / Negative
    neg = -1,
    /// Unknown / Zero
    zero = 0,
    /// True / Positive
    pos = 1,

    /// Get integer value
    pub fn value(self: Trit) i8 {
        return @intFromEnum(self);
    }

    /// Create from i8 (clamped to -1, 0, 1)
    pub fn fromInt(v: i8) Trit {
        return if (v < 0) .neg else if (v > 0) .pos else .zero;
    }

    /// String representation
    pub fn toString(self: Trit) []const u8 {
        return switch (self) {
            .neg => "-",
            .zero => "0",
            .pos => "+",
        };
    }
};

/// ═════════════════════════════════════════════════════════════════════
/// TERNARY LOGIC GATES
/// ══════════════════════════════════════════════════════════════
/// Logical NOT: flips {-1 → +1, 0 → 0}
/// Invariant: tritNot(tritNot(x)) == x
pub fn tritNot(x: Trit) Trit {
    return Trit.fromInt(-@as(i8, x.value()));
}

/// Logical AND: min of two values
/// Invariant: tritAnd(a, b) == min(a, b)
pub fn tritAnd(a: Trit, b: Trit) Trit {
    const av = a.value();
    const bv = b.value();
    return Trit.fromInt(@min(av, bv));
}

/// Logical OR: max of two values (positive absorbs)
/// Invariant: tritOr(a, b) == max(a, b)
pub fn tritOr(a: Trit, b: Trit) Trit {
    const av = a.value();
    const bv = b.value();
    return Trit.fromInt(@max(av, bv));
}

/// Majority vote of three trits (commutative, order doesn't matter)
pub fn tritMajority(a: Trit, b: Trit, c: Trit) Trit {
    const sum = a.value() + b.value() + c.value();
    // Sum can be -3, -2, -1, 0, 1, 2, 3
    // Use sign to determine majority
    return if (sum > 0) .pos else if (sum < 0) .neg else .zero;
}

/// ═════════════════════════════════════════════════════════════════
/// TEKUM: Balanced Ternary Integer
/// ═════════════════════════════════════════════════════════════
/// Ternary array (least significant trit at index 0)
pub const Tekum = struct {
    /// Trit array (least significant at index 0)
    trits: []const Trit,
    /// Number of trits
    len: usize,

    /// Create empty Tekum
    pub fn init() Tekum {
        return .{ .trits = &.{}, .len = 0 };
    }

    /// Create from slice
    pub fn fromSlice(trits: []const Trit) Tekum {
        return .{ .trits = trits, .len = trits.len };
    }

    /// Convert to i64 (balanced ternary integer)
    /// Formula: Σ(t[i] × 3^i)
    pub fn toInt(self: Tekum) i64 {
        var result: i64 = 0;
        var power: i64 = 1;

        for (self.trits) |t| {
            result += @as(i64, t.value()) * power;
            power *= 3;
        }

        return result;
    }

    /// Add two Tekums
    pub fn add(self: Tekum, other: Tekum, allocator: std.mem.Allocator) !Tekum {
        const max_len = @max(self.len, other.len) + 1;
        var result = try allocator.alloc(Trit, max_len);
        defer allocator.free(result);

        var carry: i8 = 0;
        for (0..max_len) |i| {
            const a_val = if (i < self.len) self.trits[i].value() else 0;
            const b_val = if (i < other.len) other.trits[i].value() else 0;
            var sum = a_val + b_val + carry;

            // Normalize to [-1, 0, 1]
            if (sum > 1) {
                sum -= 3;
                carry = 1;
            } else if (sum < -1) {
                sum += 3;
                carry = -1;
            } else {
                carry = 0;
            }

            result[i] = Trit.fromInt(sum);
        }

        // Trim leading zeros
        var actual_len = max_len;
        while (actual_len > 0 and result[actual_len - 1] == .zero) {
            actual_len -= 1;
        }

        const trimmed = try allocator.alloc(Trit, actual_len);
        @memcpy(trimmed, result[0..actual_len]);
        return .{ .trits = trimmed, .len = actual_len };
    }
};

// ══════════════════════════════════════════════════════════════
// TESTS
// ══════════════════════════════════════════════════════════════

test "Trit: values correct" {
    try std.testing.expectEqual(@as(i8, -1), Trit.neg.value());
    try std.testing.expectEqual(@as(i8, 0), Trit.zero.value());
    try std.testing.expectEqual(@as(i8, 1), Trit.pos.value());
}

test "Trit: fromInt clamping" {
    try std.testing.expectEqual(Trit.neg, Trit.fromInt(-5));
    try std.testing.expectEqual(Trit.neg, Trit.fromInt(-1));
    try std.testing.expectEqual(Trit.zero, Trit.fromInt(0));
    try std.testing.expectEqual(Trit.pos, Trit.fromInt(1));
    try std.testing.expectEqual(Trit.pos, Trit.fromInt(10));
}

test "Trit: toString" {
    try std.testing.expectEqualSlices(u8, "-", Trit.neg.toString());
    try std.testing.expectEqualSlices(u8, "0", Trit.zero.toString());
    try std.testing.expectEqualSlices(u8, "+", Trit.pos.toString());
}

test "tritNot: flips values" {
    try std.testing.expectEqual(Trit.pos, tritNot(Trit.neg));
    try std.testing.expectEqual(Trit.zero, tritNot(Trit.zero));
    try std.testing.expectEqual(Trit.neg, tritNot(Trit.pos));
}

test "tritNot: double negation" {
    try std.testing.expectEqual(Trit.neg, tritNot(tritNot(Trit.neg)));
    try std.testing.expectEqual(Trit.pos, tritNot(tritNot(Trit.pos)));
    try std.testing.expectEqual(Trit.zero, tritNot(tritNot(Trit.zero)));
}

test "tritAnd: negative absorbs" {
    try std.testing.expectEqual(Trit.neg, tritAnd(.neg, .neg));
    try std.testing.expectEqual(Trit.neg, tritAnd(.neg, .zero));
    try std.testing.expectEqual(Trit.neg, tritAnd(.neg, .pos));
    try std.testing.expectEqual(Trit.zero, tritAnd(.zero, .zero));
}

test "tritOr: positive absorbs" {
    try std.testing.expectEqual(Trit.pos, tritOr(.pos, .pos));
    try std.testing.expectEqual(Trit.pos, tritOr(.pos, .zero));
    try std.testing.expectEqual(Trit.pos, tritOr(.pos, .neg));
    try std.testing.expectEqual(Trit.zero, tritOr(.zero, .neg));
}

test "tritMajority: commutative" {
    try std.testing.expectEqual(Trit.zero, tritMajority(.pos, .zero, .neg));
    try std.testing.expectEqual(Trit.pos, tritMajority(.pos, .pos, .pos));
    try std.testing.expectEqual(Trit.neg, tritMajority(.neg, .neg, .neg));
}

test "Tekum: toInt single trit" {
    const trits = [_]Trit{.pos};
    const tekum = Tekum.fromSlice(&trits);
    try std.testing.expectEqual(@as(i64, 1), tekum.toInt());
}

test "Tekum: toInt multiple" {
    // LSB at index 0: [zero, neg, pos] = 0*1 + (-1)*3 + 1*9 = 6
    const trits = [_]Trit{ .zero, .neg, .pos };
    const tekum = Tekum.fromSlice(&trits);
    try std.testing.expectEqual(@as(i64, 6), tekum.toInt());
}

test "Tekum: add simple" {
    // a = [pos] = 1
    // b = [pos] = 1
    // a + b = 2 = [-1, 1] = -1 + 3 = 2
    const a_trits = [_]Trit{.pos};
    const b_trits = [_]Trit{.pos};
    const a = Tekum.fromSlice(&a_trits);
    const b = Tekum.fromSlice(&b_trits);

    const result = try a.add(b, std.testing.allocator);
    defer std.testing.allocator.free(result.trits);
    try std.testing.expectEqual(@as(i64, 2), result.toInt());
}

test "Tekum: add larger" {
    // a = [zero, pos] = 0 + 1*3 = 3
    // b = [zero, pos] = 0 + 1*3 = 3
    // a + b = 6 = [zero, zero, pos] = 0 + 0*3 + 1*9 = 9 (but with carry = 6?)
    // Actually: 3 + 3 = 6 = [0, -1, 1] = 0 - 3 + 9 = 6
    const a_trits = [_]Trit{ .zero, .pos };
    const b_trits = [_]Trit{ .zero, .pos };
    const a = Tekum.fromSlice(&a_trits);
    const b = Tekum.fromSlice(&b_trits);

    const result = try a.add(b, std.testing.allocator);
    defer std.testing.allocator.free(result.trits);
    try std.testing.expectEqual(@as(i64, 6), result.toInt());
}
