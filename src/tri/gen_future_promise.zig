//! tri/future_promise — Future/Promise for async values
//! TTT Dogfood v0.2 Stage 226

const std = @import("std");

pub const Promise = struct {
    value: ?i64,
    fulfilled: bool,

    pub fn init() Promise {
        return .{
            .value = null,
            .fulfilled = false,
        };
    }

    pub fn set(promise: *Promise, val: i64) void {
        promise.value = val;
        promise.fulfilled = true;
    }

    pub fn get(promise: *Promise) i64 {
        return promise.value.?;
    }
};

pub const Future = struct {
    promise: *Promise,

    pub fn get(future: *const Future) i64 {
        return future.promise.get();
    }
};

pub fn makePair(allocator: std.mem.Allocator) !struct { promise: *Promise, future: Future } {
    const promise = try allocator.create(Promise);
    promise.* = Promise.init();
    return .{
        .promise = promise,
        .future = .{ .promise = promise },
    };
}

test "future promise get set" {
    const pair = try makePair(std.testing.allocator);
    defer std.testing.allocator.destroy(pair.promise);
    pair.promise.set(42);
    const value = pair.future.get();
    try std.testing.expectEqual(@as(i64, 42), value);
}
