// Ternary Logic Codegen — Generate Zig from .tri spec
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

const TERNARY_LOGIC_TEMPLATE =
    \\//! Ternary Logic — Generated from specs/ternary/logic.tri
    \\//! φ² + 1/φ² = 3 | TRINITY
    \\//!
    \\//! DO NOT EDIT: This file is generated from logic.tri spec
    \\//! Modify spec and regenerate: tri vibee-gen ternary_logic
    \\
    \\const std = @import("std");
    \\
    \\/// ═════════════════════════════════════════════════════════════════════════
    \\/// TERNARY VALUES
    \\/// ═════════════════════════════════════════════════════════════════════════
    \\
    \\/// Balanced ternary digit: {-1, 0, +1}
    \\pub const Trit = enum(i8) {
    \\    /// False / Negative
    \\    neg = -1,
    \\    /// Unknown / Zero
    \\    zero = 0,
    \\    /// True / Positive
    \\    pos = 1,
    \\
    \\    /// Get integer value
    \\    pub fn value(self: Trit) i8 {
    \\        return @intFromEnum(self);
    \\    }
    \\
    \\    /// Create from i8 (clamped to -1, 0, 1)
    \\    pub fn fromInt(v: i8) Trit {
    \\        return if (v < 0) .neg else if (v > 0) .pos else .zero;
    \\    }
    \\
    \\    /// String representation
    \\    pub fn toString(self: Trit) []const u8 {
    \\        return switch (self) {
    \\            .neg => "-",
    \\            .zero => "0",
    \\            .pos => "+",
    \\        };
    \\    }
    \\};
    \\
    \\/// ═════════════════════════════════════════════════════════════════════════
    \\/// TERNARY LOGIC GATES
    \\/// ═════════════════════════════════════════════════════════════════════════
    \\
    \\/// Logical NOT: flips {-1 → +1, 0 → 0, +1 → -1}
    \\pub fn tritNot(x: Trit) Trit {
    \\    return Trit.fromInt(-x.value());
    \\}
    \\
    \\/// Logical AND: min of two values
    \\/// Invariant: tritAnd(-1, x) == -1 (negative absorbs)
    \\pub fn tritAnd(a: Trit, b: Trit) Trit {
    \\    const av = a.value();
    \\    const bv = b.value();
    \\    return Trit.fromInt(@min(av, bv));
    \\}
    \\
    \\/// Logical OR: max of two values
    \\/// Invariant: tritOr(+1, x) == +1 (positive absorbs)
    \\pub fn tritOr(a: Trit, b: Trit) Trit {
    \\    const av = a.value();
    \\    const bv = b.value();
    \\    return Trit.fromInt(@max(av, bv));
    \\}
    \\
    \\/// Majority vote of three trits
    \\/// Invariant: commutative (order doesn't matter)
    \\pub fn tritMajority(a: Trit, b: Trit, c: Trit) Trit {
    \\    const sum = a.value() + b.value() + c.value();
    \\    if (sum > 0) return .pos;
    \\    if (sum < 0) return .neg;
    \\    return .zero;
    \\}
    \\
    \\/// ═════════════════════════════════════════════════════════════════════════
    \\/// TEKUM: Balanced Ternary Integer
    \\/// ═════════════════════════════════════════════════════════════════════════
    \\
    \\/// Tekum value: array of trits (balanced ternary integer)
    \\pub const Tekum = struct {
    \\    /// Trit array (least significant at index 0)
    \\    trits: []Trit,
    \\    /// Number of trits
    \\    len: usize,
    \\
    \\    /// Create empty Tekum
    \\    pub fn init() Tekum {
    \\        return .{ .trits = &.{}, .len = 0 };
    \\    }
    \\
    \\    /// Create from slice
    \\    pub fn fromSlice(trits: []const Trit) Tekum {
    \\        return .{ .trits = trits, .len = trits.len };
    \\    }
    \\
    \\    /// Convert to i64 (balanced ternary)
    \\    pub fn toInt(self: Tekum) i64 {
    \\        var result: i64 = 0;
    \\        var power: i64 = 1;
    \\        for (self.trits[0..self.len]) |t| {
    \\            result += @as(i64, t.value()) * power;
    \\            power *= 3;
    \\        }
    \\        return result;
    \\    }
    \\
    \\    /// Add two Tekums
    \\    pub fn add(self: Tekum, other: Tekum, allocator: Allocator) !Tekum {
    \\        const max_len = @max(self.len, other.len) + 1;
    \\        var result = try allocator.alloc(Trit, max_len);
    \\        defer allocator.free(result);
    \\
    \\        var carry: i8 = 0;
    \\        for (0..max_len) |i| {
    \\            const a_val = if (i < self.len) self.trits[i].value() else 0;
    \\            const b_val = if (i < other.len) other.trits[i].value() else 0;
    \\            var sum = a_val + b_val + carry;
    \\
    \\            // Normalize to [-1, 0, 1]
    \\            if (sum > 1) {
    \\                sum -= 3;
    \\                carry = 1;
    \\            } else if (sum < -1) {
    \\                sum += 3;
    \\                carry = -1;
    \\            } else {
    \\                carry = 0;
    \\            }
    \\            result[i] = Trit.fromInt(sum);
    \\        }
    \\
    \\        // Trim leading zeros
    \\        var actual_len = max_len;
    \\        while (actual_len > 1 and result[actual_len - 1] == .zero) {
    \\            actual_len -= 1;
    \\        }
    \\
    \\        const trimmed = try allocator.alloc(Trit, actual_len);
    \\        @memcpy(trimmed, result[0..actual_len]);
    \\        return Tekum{ .trits = trimmed, .len = actual_len };
    \\    }
    \\};
    \\
    \\// ═════════════════════════════════════════════════════════════════════════
    \\// TESTS
    \\// ═════════════════════════════════════════════════════════════════════════
    \\
    \\test "Trit: values correct" {
    \\    try std.testing.expectEqual(@as(i8, -1), Trit.neg.value());
    \\    try std.testing.expectEqual(@as(i8, 0), Trit.zero.value());
    \\    try std.testing.expectEqual(@as(i8, 1), Trit.pos.value());
    \\}
    \\
    \\test "Trit: fromInt clamping" {
    \\    try std.testing.expectEqual(Trit.neg, Trit.fromInt(-5));
    \\    try std.testing.expectEqual(Trit.neg, Trit.fromInt(-1));
    \\    try std.testing.expectEqual(Trit.zero, Trit.fromInt(0));
    \\    try std.testing.expectEqual(Trit.pos, Trit.fromInt(1));
    \\    try std.testing.expectEqual(Trit.pos, Trit.fromInt(10));
    \\}
    \\
    \\test "Trit: toString" {
    \\    try std.testing.expectEqualSlices(u8, "-", Trit.neg.toString());
    \\    try std.testing.expectEqualSlices(u8, "0", Trit.zero.toString());
    \\    try std.testing.expectEqualSlices(u8, "+", Trit.pos.toString());
    \\}
    \\
    \\test "tritNot: double negation" {
    \\    try std.testing.expectEqual(Trit.neg, tritNot(tritNot(Trit.pos)));
    \\    try std.testing.expectEqual(Trit.pos, tritNot(tritNot(Trit.neg)));
    \\    try std.testing.expectEqual(Trit.zero, tritNot(tritNot(Trit.zero)));
    \\}
    \\
    \\test "tritAnd: negative absorbs" {
    \\    try std.testing.expectEqual(Trit.neg, tritAnd(.neg, .neg));
    \\    try std.testing.expectEqual(Trit.neg, tritAnd(.neg, .zero));
    \\    try std.testing.expectEqual(Trit.neg, tritAnd(.neg, .pos));
    \\}
    \\
    \\test "tritOr: positive absorbs" {
    \\    try std.testing.expectEqual(Trit.pos, tritOr(.pos, .pos));
    \\    try std.testing.expectEqual(Trit.pos, tritOr(.pos, .zero));
    \\    try std.testing.expectEqual(Trit.pos, tritOr(.pos, .neg));
    \\}
    \\
    \\test "tritMajority: commutative" {
    \\    try std.testing.expectEqual(tritMajority(.neg, .zero, .pos), tritMajority(.pos, .zero, .neg));
    \\    try std.testing.expectEqual(tritMajority(.neg, .neg, .neg), tritMajority(.neg, .neg, .neg));
    \\}
    \\
    \\test "Tekum: toInt single trit" {
    \\    const trits = [_]Trit{.pos};
    \\    const tekum = Tekum.fromSlice(&trits);
    \\    try std.testing.expectEqual(@as(i64, 1), tekum.toInt());
    \\}
    \\
    \\test "Tekum: toInt multiple" {
    \\    const trits = [_]Trit{ .pos, .neg, .zero };  // 1*9 + 0*3 + (-1)*1 = 8
    \\    const tekum = Tekum.fromSlice(&trits);
    \\    try std.testing.expectEqual(@as(i64, 8), tekum.toInt());
    \\}
    \\
    \\test "Tekum: add simple" {
    \\    const a_trits = [_]Trit{.pos, .zero};  // 3
    \\    const b_trits = [_]Trit{.pos, .zero};  // 3
    \\    const a = Tekum.fromSlice(&a_trits);
    \\    const b = Tekum.fromSlice(&b_trits);
    \\
    \\    const result = try a.add(b, std.testing.allocator);
    \\    defer std.testing.allocator.free(result.trits);
    \\    try std.testing.expectEqual(@as(i64, 6), result.toInt());
    \\}
    \\
;

pub fn generateTernaryLogic(allocator: Allocator) ![]const u8 {
    return allocator.dupe(u8, TERNARY_LOGIC_TEMPLATE);
}

pub fn writeTernaryLogic(allocator: Allocator, path: []const u8) !void {
    const content = try generateTernaryLogic(allocator);
    defer allocator.free(content);

    const file = try std.fs.createFileAbsolute(path, .{});
    defer file.close();

    try file.writeAll(content);
}

test "ternary_logic codegen" {
    const content = try generateTernaryLogic(std.testing.allocator);
    defer std.testing.allocator.free(content);

    try std.testing.expect(content.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, content, "pub const Trit") != null);
}
