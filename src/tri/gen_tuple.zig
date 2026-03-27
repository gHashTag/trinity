//! tri/tuple — Fixed-size product type
//! Auto-generated from specs/tri/tri_tuple.tri
//! TTT Dogfood v0.2 Stage 89

const std = @import("std");

/// Pair of values
pub fn Tuple2(comptime A: type, comptime B: type) type {
    return struct {
        first: A,
        second: B,

        const Self = @This();

        /// Create pair
        pub fn pair(a: A, b: B) Self {
            return .{ .first = a, .second = b };
        }

        /// Get first element
        pub fn fst(self: Self) A {
            return self.first;
        }

        /// Get second element
        pub fn snd(self: Self) B {
            return self.second;
        }
    };
}

/// Triple of values
pub fn Tuple3(comptime A: type, comptime B: type, comptime C: type) type {
    return struct {
        first: A,
        second: B,
        third: C,

        const Self = @This();

        /// Create triple
        pub fn triple(a: A, b: B, c: C) Self {
            return .{ .first = a, .second = b, .third = c };
        }
    };
}

test "Tuple2.pair" {
    const pair = Tuple2(i32, i32).pair(1, 2);
    try std.testing.expectEqual(@as(i32, 1), pair.first);
    try std.testing.expectEqual(@as(i32, 2), pair.second);
}

test "Tuple2.fst" {
    const pair = Tuple2(i32, []const u8).pair(42, "hello");
    try std.testing.expectEqual(@as(i32, 42), pair.fst());
}

test "Tuple2.snd" {
    const pair = Tuple2(i32, []const u8).pair(42, "hello");
    try std.testing.expectEqualStrings("hello", pair.snd());
}

test "Tuple3.triple" {
    const triple = Tuple3(i32, i32, i32).triple(1, 2, 3);
    try std.testing.expectEqual(@as(i32, 1), triple.first);
    try std.testing.expectEqual(@as(i32, 2), triple.second);
    try std.testing.expectEqual(@as(i32, 3), triple.third);
}
