//! tri/maybe — Lazy computation with deferred execution
//! Auto-generated from specs/tri/tri_maybe.tri
//! TTT Dogfood v0.2 Stage 71

const std = @import("std");

/// Lazy optional value with deferred computation
pub fn Maybe(comptime T: type) type {
    return struct {
        computed: bool,
        value: T,

        const Self = @This();

        /// Lift value into Maybe context
        pub fn pure(val: T) Self {
            return .{ .computed = true, .value = val };
        }

        /// Create empty Maybe
        pub fn nothing() Self {
            return .{ .computed = false, .value = undefined };
        }

        /// Check if has value
        pub fn isJust(self: Self) bool {
            return self.computed;
        }

        /// Check if is empty
        pub fn isNothing(self: Self) bool {
            return !self.computed;
        }

        /// Chain Maybe computations (monadic bind)
        pub fn bind(self: Self, comptime U: type, fn_bind: *const fn (T) Maybe(U)) Maybe(U) {
            if (self.computed) {
                return fn_bind(self.value);
            }
            return Maybe(U).nothing();
        }

        /// Transform value if present
        pub fn map(self: Self, comptime U: type, fn_map: *const fn (T) U) Maybe(U) {
            if (self.computed) {
                return Maybe(U).pure(fn_map(self.value));
            }
            return Maybe(U).nothing();
        }

        /// Get value or return default
        pub fn unwrapOr(self: Self, default: T) T {
            if (self.computed) {
                return self.value;
            }
            return default;
        }

        /// Flatten nested Maybe
        pub fn flatten(comptime Inner: type, nested: Maybe(Maybe(Inner))) Maybe(Inner) {
            if (nested.computed) {
                return nested.value;
            }
            return Maybe(Inner).nothing();
        }

        /// Apply function inside Maybe
        pub fn ap(self: Self, comptime U: type, fn_maybe: Maybe(*const fn (T) U)) Maybe(U) {
            if (self.computed and fn_maybe.computed) {
                return Maybe(U).pure(fn_maybe.value(self.value));
            }
            return Maybe(U).nothing();
        }
    };
}

test "Maybe.pure" {
    const maybe = Maybe(i32).pure(42);
    try std.testing.expect(maybe.isJust());
    try std.testing.expectEqual(@as(i32, 42), maybe.unwrapOr(0));
}

test "Maybe.nothing" {
    const maybe = Maybe(i32).nothing();
    try std.testing.expect(maybe.isNothing());
    try std.testing.expectEqual(@as(i32, 99), maybe.unwrapOr(99));
}

test "Maybe.map" {
    const just = Maybe(i32).pure(5);
    const nothing = Maybe(i32).nothing();

    const mappedJust = just.map(i32, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);

    const mappedNothing = nothing.map(i32, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);

    try std.testing.expectEqual(@as(i32, 10), mappedJust.unwrapOr(0));
    try std.testing.expect(mappedNothing.isNothing());
}

test "Maybe.bind" {
    const just = Maybe(i32).pure(4);

    const bound = just.bind(i32, struct {
        fn safeDiv(x: i32) Maybe(i32) {
            if (x == 0) return Maybe(i32).nothing();
            return Maybe(i32).pure(@divTrunc(100, x));
        }
    }.safeDiv);

    try std.testing.expectEqual(@as(i32, 25), bound.unwrapOr(0));
}

test "Maybe.bind nothing" {
    const nothing = Maybe(i32).nothing();

    const bound = nothing.bind(i32, struct {
        fn safeDiv(x: i32) Maybe(i32) {
            return Maybe(i32).pure(@divTrunc(100, x));
        }
    }.safeDiv);

    try std.testing.expect(bound.isNothing());
}

test "Maybe.flatten" {
    const nested = Maybe(Maybe(i32)).pure(Maybe(i32).pure(42));
    const inner = Maybe(i32).flatten(i32, nested);

    try std.testing.expectEqual(@as(i32, 42), inner.unwrapOr(0));
}

test "Maybe.ap" {
    const justFn = Maybe(*const fn (i32) i32).pure(struct {
        fn addOne(x: i32) i32 {
            return x + 1;
        }
    }.addOne);

    const justVal = Maybe(i32).pure(5);
    const nothingVal = Maybe(i32).nothing();

    const applied = justVal.ap(i32, justFn);
    const notApplied = nothingVal.ap(i32, justFn);

    try std.testing.expectEqual(@as(i32, 6), applied.unwrapOr(0));
    try std.testing.expect(notApplied.isNothing());
}
