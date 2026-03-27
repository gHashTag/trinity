//! tri/async — Future and promise primitives
//! Auto-generated from specs/tri/tri_async.tri
//! TTT Dogfood v0.2 Stage 73

const std = @import("std");

/// Async computation result
pub fn Future(comptime T: type) type {
    return struct {
        completed: bool,
        value: T,

        const Self = @This();

        /// Create unfulfilled future
        pub fn init() Self {
            return .{ .completed = false, .value = undefined };
        }

        /// Create completed future
        pub fn ready(val: T) Self {
            return .{ .completed = true, .value = val };
        }

        /// Check if completed
        pub fn isCompleted(self: Self) bool {
            return self.completed;
        }

        /// Get value if completed
        pub fn getValue(self: Self) ?T {
            if (self.completed) return self.value;
            return null;
        }

        /// Poll for completion (non-blocking)
        pub fn poll(self: Self) ?T {
            return self.getValue();
        }

        /// Transform future result
        pub fn map(self: Self, comptime U: type, mapper: *const fn (T) U) Future(U) {
            if (self.completed) {
                return Future(U).ready(mapper(self.value));
            }
            return Future(U).init();
        }

        /// Chain future-returning function
        pub fn andThen(self: Self, comptime U: type, binder: *const fn (T) Future(U)) Future(U) {
            if (self.completed) {
                return binder(self.value);
            }
            return Future(U).init();
        }
    };
}

/// Writable async value
pub fn Promise(comptime T: type) type {
    return struct {
        fulfilled: bool,
        future: Future(T),

        const Self = @This();

        /// Create unfulfilled promise
        pub fn init() Self {
            return .{ .fulfilled = false, .future = Future(T).init() };
        }

        /// Create already fulfilled promise
        pub fn ready(val: T) Self {
            return .{ .fulfilled = true, .future = Future(T).ready(val) };
        }

        /// Check if fulfilled
        pub fn isFulfilled(self: Self) bool {
            return self.fulfilled;
        }

        /// Get associated future
        pub fn getFuture(self: Self) Future(T) {
            return self.future;
        }

        /// Fulfill promise with value (idempotent)
        pub fn fulfill(self: *Self, val: T) bool {
            if (self.fulfilled) return false; // Already fulfilled

            self.fulfilled = true;
            self.future = Future(T).ready(val);
            return true;
        }

        /// Try to fulfill, returns true if successful
        pub fn tryFulfill(self: *Self, val: T) bool {
            return self.fulfill(val);
        }
    };
}

/// Wait for future completion (simplified - in real async would use event loop)
pub fn await(comptime T: type, future: *const Future(T)) T {
    // In a real async runtime, this would park the task
    // For now, just return the value (assuming completed)
    std.debug.assert(future.completed);
    return future.value;
}

test "Promise.fulfill" {
    var promise = Promise(i32).init();
    try std.testing.expect(!promise.isFulfilled());

    const result = promise.fulfill(42);
    try std.testing.expect(result);
    try std.testing.expect(promise.isFulfilled());

    const second = promise.fulfill(99);
    try std.testing.expect(!second); // Idempotent
}

test "Promise.getFuture" {
    var promise = Promise(i32).init();
    _ = promise.fulfill(42);

    const future = promise.getFuture();
    try std.testing.expect(future.isCompleted());
    try std.testing.expectEqual(@as(i32, 42), future.getValue().?);
}

test "Future.ready" {
    const future = Future(i32).ready(42);
    try std.testing.expect(future.isCompleted());
    try std.testing.expectEqual(@as(i32, 42), future.poll().?);
}

test "Future.map" {
    const future = Future(i32).ready(5);

    const mapped = future.map(i32, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);

    try std.testing.expect(mapped.isCompleted());
    try std.testing.expectEqual(@as(i32, 10), mapped.getValue().?);
}

test "Future.andThen" {
    const future = Future(i32).ready(4);

    const chained = future.andThen(i32, struct {
        fn safeDiv(x: i32) Future(i32) {
            if (x == 0) return Future(i32).init();
            return Future(i32).ready(@divTrunc(100, x));
        }
    }.safeDiv);

    try std.testing.expect(chained.isCompleted());
    try std.testing.expectEqual(@as(i32, 25), chained.getValue().?);
}

test "Future.andThen uncompleted" {
    const future = Future(i32).init();

    const chained = future.andThen(i32, struct {
        fn safeDiv(x: i32) Future(i32) {
            return Future(i32).ready(@divTrunc(100, x));
        }
    }.safeDiv);

    try std.testing.expect(!chained.isCompleted());
}

test "Promise.ready" {
    const promise = Promise(i32).ready(42);
    try std.testing.expect(promise.isFulfilled());

    const future = promise.getFuture();
    try std.testing.expectEqual(@as(i32, 42), await(i32, &future));
}
