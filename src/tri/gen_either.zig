//! tri/either — One of two possible values
//! Auto-generated from specs/tri/tri_either.tri
//! TTT Dogfood v0.2 Stage 70

const std = @import("std");

/// One of Left or Right value
pub fn Either(comptime L: type, comptime R: type) type {
    return struct {
        is_left: bool,
        left_val: L,
        right_val: R,

        const Self = @This();

        /// Create Left variant
        pub fn left(val: L) Self {
            return .{ .is_left = true, .left_val = val, .right_val = undefined };
        }

        /// Create Right variant
        pub fn right(val: R) Self {
            return .{ .is_left = false, .left_val = undefined, .right_val = val };
        }

        /// Check if is Left
        pub fn isLeft(self: Self) bool {
            return self.is_left;
        }

        /// Check if is Right
        pub fn isRight(self: Self) bool {
            return !self.is_left;
        }

        /// Get left value or return default
        pub fn unwrapLeft(self: Self, default: L) L {
            if (self.is_left) {
                return self.left_val;
            }
            return default;
        }

        /// Get right value or return default
        pub fn unwrapRight(self: Self, default: R) R {
            if (!self.is_left) {
                return self.right_val;
            }
            return default;
        }

        /// Get value (merged type approximation)
        /// Note: Zig doesn't have union types, so this returns a struct
        pub fn unwrap(self: Self, default_left: L, default_right: R) struct { left: L, right: R } {
            if (self.is_left) {
                return .{ .left = self.left_val, .right = default_right };
            }
            return .{ .left = default_left, .right = self.right_val };
        }

        /// Map over left value
        pub fn mapLeft(self: Self, comptime L2: type, mapper: *const fn (L) L2) Either(L2, R) {
            if (self.is_left) {
                return Either(L2, R).left(mapper(self.left_val));
            }
            return Either(L2, R).right(self.right_val);
        }

        /// Map over right value
        pub fn mapRight(self: Self, comptime R2: type, mapper: *const fn (R) R2) Either(L, R2) {
            if (self.is_left) {
                return Either(L, R2).left(self.left_val);
            }
            return Either(L, R2).right(mapper(self.right_val));
        }

        /// Flip Left <-> Right
        pub fn flip(self: Self) Either(R, L) {
            if (self.is_left) {
                return Either(R, L).right(self.left_val);
            }
            return Either(R, L).left(self.right_val);
        }

        /// Apply left or right function
        pub fn fold(self: Self, comptime U: type, onLeft: *const fn (L) U, onRight: *const fn (R) U) U {
            if (self.is_left) {
                return onLeft(self.left_val);
            }
            return onRight(self.right_val);
        }
    };
}

test "Either.left creates left variant" {
    const either = Either(i32, []const u8).left(42);
    try std.testing.expect(either.isLeft());
    try std.testing.expect(!either.isRight());
    try std.testing.expectEqual(@as(i32, 42), either.unwrapLeft(0));
}

test "Either.right creates right variant" {
    const either = Either(i32, []const u8).right("hello");
    try std.testing.expect(either.isRight());
    try std.testing.expect(!either.isLeft());
    try std.testing.expectEqualStrings("hello", either.unwrapRight(""));
}

test "Either.isLeft" {
    const left = Either(i32, []const u8).left(10);
    const right = Either(i32, []const u8).right("test");
    try std.testing.expect(left.isLeft());
    try std.testing.expect(!right.isLeft());
}

test "Either.isRight" {
    const left = Either(i32, []const u8).left(10);
    const right = Either(i32, []const u8).right("test");
    try std.testing.expect(!left.isRight());
    try std.testing.expect(right.isRight());
}

test "Either.unwrapLeft" {
    const left = Either(i32, []const u8).left(5);
    const right = Either(i32, []const u8).right("test");
    try std.testing.expectEqual(@as(i32, 5), left.unwrapLeft(0));
    try std.testing.expectEqual(@as(i32, 99), right.unwrapLeft(99));
}

test "Either.unwrapRight" {
    const left = Either(i32, []const u8).left(5);
    const right = Either(i32, []const u8).right("hello");
    try std.testing.expectEqualStrings("", left.unwrapRight(""));
    try std.testing.expectEqualStrings("hello", right.unwrapRight(""));
}

test "Either.mapLeft" {
    const left = Either(i32, []const u8).left(4);
    const right = Either(i32, []const u8).right("test");

    const mappedLeft = left.mapLeft(u32, struct {
        fn double(x: i32) u32 {
            return @as(u32, @intCast(@abs(x) * 2));
        }
    }.double);

    const mappedRight = right.mapLeft(u32, struct {
        fn double(x: i32) u32 {
            return @as(u32, @intCast(@abs(x) * 2));
        }
    }.double);

    try std.testing.expect(mappedLeft.isLeft());
    try std.testing.expectEqual(@as(u32, 8), mappedLeft.unwrapLeft(0));
    try std.testing.expect(mappedRight.isRight());
    try std.testing.expectEqualStrings("test", mappedRight.unwrapRight(""));
}

test "Either.mapRight" {
    const left = Either(i32, []const u8).left(4);
    const right = Either(i32, []const u8).right("hi");

    const mappedLeft = left.mapRight(usize, struct {
        fn len(s: []const u8) usize {
            return s.len;
        }
    }.len);

    const mappedRight = right.mapRight(usize, struct {
        fn len(s: []const u8) usize {
            return s.len;
        }
    }.len);

    try std.testing.expect(mappedLeft.isLeft());
    try std.testing.expectEqual(@as(i32, 4), mappedLeft.unwrapLeft(0));
    try std.testing.expect(mappedRight.isRight());
    try std.testing.expectEqual(@as(usize, 2), mappedRight.unwrapRight(0));
}

test "Either.flip" {
    const left = Either(i32, []const u8).left(42);
    const right = Either(i32, []const u8).right("hello");

    const flippedLeft = left.flip();
    const flippedRight = right.flip();

    try std.testing.expect(flippedLeft.isRight());
    try std.testing.expectEqual(@as(i32, 42), flippedLeft.unwrapRight(0));
    try std.testing.expect(flippedRight.isLeft());
    try std.testing.expectEqualStrings("hello", flippedRight.unwrapLeft(""));
}

test "Either.fold" {
    const left = Either(i32, []const u8).left(10);
    const right = Either(i32, []const u8).right("hello");

    const foldedLeft = left.fold(usize, struct {
        fn countDigits(n: i32) usize {
            return @as(usize, @intCast(@abs(n)));
        }
    }.countDigits, struct {
        fn length(s: []const u8) usize {
            return s.len;
        }
    }.length);

    const foldedRight = right.fold(usize, struct {
        fn countDigits(n: i32) usize {
            return @as(usize, @intCast(@abs(n)));
        }
    }.countDigits, struct {
        fn length(s: []const u8) usize {
            return s.len;
        }
    }.length);

    try std.testing.expectEqual(@as(usize, 10), foldedLeft);
    try std.testing.expectEqual(@as(usize, 5), foldedRight);
}
