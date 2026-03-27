//! tri/option — Optional values without null
//! Auto-generated from specs/tri/tri_option.tri
//! TTT Dogfood v0.2 Stage 69

const std = @import("std");

/// Optional value that may or may not be present
pub fn Option(comptime T: type) type {
    return struct {
        is_some: bool,
        value: T,

        const Self = @This();

        /// Create optional with value
        pub fn some(val: T) Self {
            return .{ .is_some = true, .value = val };
        }

        /// Create empty optional
        pub fn none() Self {
            return .{ .is_some = false, .value = undefined };
        }

        /// Get value or return default
        pub fn unwrapOr(self: Self, default: T) T {
            if (self.is_some) {
                return self.value;
            }
            return default;
        }

        /// Get value or return error
        pub fn unwrapOrElse(self: Self, defaultFn: anytype) T {
            if (self.is_some) {
                return self.value;
            }
            return @call(.auto, defaultFn, .{});
        }

        /// Check if has value
        pub fn isSome(self: Self) bool {
            return self.is_some;
        }

        /// Check if is none
        pub fn isNone(self: Self) bool {
            return !self.is_some;
        }

        /// Map over value
        pub fn map(self: Self, comptime U: type, mapper: *const fn (T) U) Option(U) {
            if (self.is_some) {
                return Option(U).some(mapper(self.value));
            }
            return Option(U).none();
        }

        /// Filter with predicate
        pub fn filter(self: Self, predicate: *const fn (T) bool) Self {
            if (self.is_some and predicate(self.value)) {
                return self;
            }
            return Self.none();
        }
    };
}

test "Option.some creates value" {
    const opt = Option(i32).some(42);
    try std.testing.expect(opt.isSome());
    try std.testing.expectEqual(@as(i32, 42), opt.unwrapOr(0));
}

test "Option.none creates empty" {
    const opt = Option(i32).none();
    try std.testing.expect(opt.isNone());
    try std.testing.expectEqual(@as(i32, 99), opt.unwrapOr(99));
}

test "Option.isSome" {
    const some = Option(i32).some(10);
    const none = Option(i32).none();
    try std.testing.expect(some.isSome());
    try std.testing.expect(!none.isSome());
}

test "Option.unwrapOr" {
    const some = Option(i32).some(5);
    const none = Option(i32).none();
    try std.testing.expectEqual(@as(i32, 5), some.unwrapOr(0));
    try std.testing.expectEqual(@as(i32, 100), none.unwrapOr(100));
}

test "Option.map" {
    const some = Option(i32).some(4);
    const none = Option(i32).none();
    const mappedSome = some.map(u32, struct {
        fn double(x: i32) u32 {
            return @as(u32, @intCast(@abs(x) * 2));
        }
    }.double);
    const mappedNone = none.map(u32, struct {
        fn double(x: i32) u32 {
            return @as(u32, @intCast(@abs(x) * 2));
        }
    }.double);
    try std.testing.expectEqual(@as(u32, 8), mappedSome.unwrapOr(0));
    try std.testing.expect(mappedNone.isNone());
}

test "Option.filter" {
    const opt1 = Option(i32).some(10);
    const opt2 = Option(i32).some(3);
    const opt3 = Option(i32).none();

    const filtered1 = opt1.filter(struct {
        fn isEven(x: i32) bool {
            return @rem(x, 2) == 0;
        }
    }.isEven);
    const filtered2 = opt2.filter(struct {
        fn isEven(x: i32) bool {
            return @rem(x, 2) == 0;
        }
    }.isEven);
    const filtered3 = opt3.filter(struct {
        fn isEven(x: i32) bool {
            return @rem(x, 2) == 0;
        }
    }.isEven);

    try std.testing.expectEqual(@as(i32, 10), filtered1.unwrapOr(0));
    try std.testing.expect(filtered2.isNone());
    try std.testing.expect(filtered3.isNone());
}
