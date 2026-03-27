//! tri/result — Error handling without exceptions
//! Auto-generated from specs/tri/tri_result.tri
//! TTT Dogfood v0.2 Stage 68

const std = @import("std");

/// Result that is either Ok(value) or Err(error)
pub fn Result(comptime T: type, comptime E: type) type {
    return struct {
        is_ok: bool,
        value: T,
        err_val: E,

        const Self = @This();

        /// Create success result
        pub fn ok(val: T) Self {
            return .{ .is_ok = true, .value = val, .err_val = undefined };
        }

        /// Create error result
        pub fn err(err_val: E) Self {
            return .{ .is_ok = false, .value = undefined, .err_val = err_val };
        }

        /// Get value or return default
        pub fn unwrapOr(self: Self, default: T) T {
            if (self.is_ok) {
                return self.value;
            }
            return default;
        }

        /// Check if is error
        pub fn isError(self: Self) bool {
            return !self.is_ok;
        }

        /// Check if is ok
        pub fn isOk(self: Self) bool {
            return self.is_ok;
        }

        /// Map over ok value
        pub fn map(self: Self, comptime U: type, mapper: *const fn (T) U) Result(U, E) {
            if (self.is_ok) {
                return Result(U, E).ok(mapper(self.value));
            }
            return Result(U, E).err(self.err_val);
        }

        /// Map over error value
        pub fn mapErr(self: Self, comptime F: type, mapper: *const fn (E) F) Result(T, F) {
            if (self.is_ok) {
                return Result(T, F).ok(self.value);
            }
            return Result(T, F).err(mapper(self.err_val));
        }

        /// Chain with another result-returning function
        pub fn andThen(self: Self, comptime U: type, binder: *const fn (T) Result(U, E)) Result(U, E) {
            if (self.is_ok) {
                return binder(self.value);
            }
            return Result(U, E).err(self.err_val);
        }

        /// Recover from error with default
        pub fn orElse(self: Self, fallback: *const fn (E) Result(T, E)) Result(T, E) {
            if (self.is_ok) {
                return self;
            }
            return fallback(self.err_val);
        }
    };
}

test "Result.ok creates success" {
    const res = Result(i32, []const u8).ok(42);
    try std.testing.expect(res.isOk());
    try std.testing.expect(!res.isError());
    try std.testing.expectEqual(@as(i32, 42), res.unwrapOr(0));
}

test "Result.err creates error" {
    const res = Result(i32, []const u8).err("something failed");
    try std.testing.expect(res.isError());
    try std.testing.expect(!res.isOk());
    try std.testing.expectEqual(@as(i32, 99), res.unwrapOr(99));
}

test "Result.isError" {
    const ok = Result(i32, []const u8).ok(10);
    const err = Result(i32, []const u8).err("failed");
    try std.testing.expect(!ok.isError());
    try std.testing.expect(err.isError());
}

test "Result.unwrapOr" {
    const ok = Result(i32, []const u8).ok(5);
    const err = Result(i32, []const u8).err("error");
    try std.testing.expectEqual(@as(i32, 5), ok.unwrapOr(0));
    try std.testing.expectEqual(@as(i32, 100), err.unwrapOr(100));
}

test "Result.map" {
    const ok = Result(i32, []const u8).ok(4);
    const err = Result(i32, []const u8).err("failed");

    const mappedOk = ok.map(u32, struct {
        fn double(x: i32) u32 {
            return @as(u32, @intCast(@abs(x) * 2));
        }
    }.double);

    const mappedErr = err.map(u32, struct {
        fn double(x: i32) u32 {
            return @as(u32, @intCast(@abs(x) * 2));
        }
    }.double);

    try std.testing.expect(mappedOk.isOk());
    try std.testing.expectEqual(@as(u32, 8), mappedOk.unwrapOr(0));
    try std.testing.expect(mappedErr.isError());
}

test "Result.mapErr" {
    const ok = Result(i32, []const u8).ok(4);
    const err = Result(i32, u16).err(404);

    const mappedOk = ok.mapErr(u16, struct {
        fn toCode(e: []const u8) u16 {
            _ = e;
            return 500;
        }
    }.toCode);

    const mappedErr = err.mapErr(u16, struct {
        fn toCode(e: u16) u16 {
            return e * 10;
        }
    }.toCode);

    try std.testing.expect(mappedOk.isOk());
    try std.testing.expectEqual(@as(i32, 4), mappedOk.unwrapOr(0));
    try std.testing.expect(mappedErr.isError());
    try std.testing.expectEqual(@as(u16, 4040), mappedErr.err_val);
}

test "Result.andThen" {
    const ok1 = Result(i32, []const u8).ok(4);
    const err1 = Result(i32, []const u8).err("failed");

    const chained = ok1.andThen(i32, struct {
        fn addOne(x: i32) Result(i32, []const u8) {
            return Result(i32, []const u8).ok(x + 1);
        }
    }.addOne);

    const chainedErr = err1.andThen(i32, struct {
        fn addOne(x: i32) Result(i32, []const u8) {
            return Result(i32, []const u8).ok(x + 1);
        }
    }.addOne);

    try std.testing.expect(chained.isOk());
    try std.testing.expectEqual(@as(i32, 5), chained.unwrapOr(0));
    try std.testing.expect(chainedErr.isError());
}

test "Result.orElse" {
    const ok = Result(i32, []const u8).ok(5);
    const err = Result(i32, []const u8).err("error");

    const recovered = ok.orElse(struct {
        fn withDefault(e: []const u8) Result(i32, []const u8) {
            _ = e;
            return Result(i32, []const u8).ok(0);
        }
    }.withDefault);

    const recoveredErr = err.orElse(struct {
        fn withDefault(e: []const u8) Result(i32, []const u8) {
            _ = e;
            return Result(i32, []const u8).ok(0);
        }
    }.withDefault);

    try std.testing.expect(recovered.isOk());
    try std.testing.expectEqual(@as(i32, 5), recovered.unwrapOr(0));
    try std.testing.expect(recoveredErr.isOk());
    try std.testing.expectEqual(@as(i32, 0), recoveredErr.unwrapOr(0));
}
