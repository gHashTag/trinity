//! tri/cell — Mutable shared memory
//! Auto-generated from specs/tri/tri_cell.tri
//! TTT Dogfood v0.2 Stage 75

const std = @import("std");

/// Mutable memory cell
pub fn Cell(comptime T: type) type {
    return struct {
        value: T,
        mutex: std.Thread.Mutex,

        const Self = @This();

        /// Create cell with initial value
        pub fn init(initial: T) Self {
            return .{ .value = initial, .mutex = std.Thread.Mutex{} };
        }

        /// Read current value
        pub fn get(self: *const Self) T {
            // Cast away const for mutex lock (mutex lock doesn't modify logical state)
            const mutable = @constCast(self);
            mutable.mutex.lock();
            defer mutable.mutex.unlock();
            return mutable.value;
        }

        /// Update cell value
        pub fn set(self: *Self, new_val: T) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.value = new_val;
        }

        /// Transform cell value
        pub fn update(self: *Self, transformer: *const fn (T) T) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.value = transformer(self.value);
        }

        /// Get and set atomically
        pub fn getAndSet(self: *Self, new_val: T) T {
            self.mutex.lock();
            defer self.mutex.unlock();
            const old = self.value;
            self.value = new_val;
            return old;
        }

        /// Modify value and return new value
        pub fn modify(self: *Self, modifier: *const fn (T) T) T {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.value = modifier(self.value);
            return self.value;
        }

        /// Compare and swap (returns true if successful)
        pub fn compareAndSet(self: *Self, expected: T, new_val: T) bool {
            self.mutex.lock();
            defer self.mutex.unlock();
            if (std.meta.eql(self.value, expected)) {
                self.value = new_val;
                return true;
            }
            return false;
        }

        /// Swap values with another cell
        pub fn swap(self: *Self, other: *Self) void {
            self.mutex.lock();
            other.mutex.lock();
            defer self.mutex.unlock();
            defer other.mutex.unlock();

            const temp = self.value;
            self.value = other.value;
            other.value = temp;
        }
    };
}

test "Cell.get/set" {
    var cell = Cell(i32).init(0);

    try std.testing.expectEqual(@as(i32, 0), cell.get());
    cell.set(42);
    try std.testing.expectEqual(@as(i32, 42), cell.get());
}

test "Cell.update" {
    var cell = Cell(i32).init(5);

    cell.update(struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);

    try std.testing.expectEqual(@as(i32, 10), cell.get());
}

test "Cell.getAndSet" {
    var cell = Cell(i32).init(10);

    const old = cell.getAndSet(20);
    try std.testing.expectEqual(@as(i32, 10), old);
    try std.testing.expectEqual(@as(i32, 20), cell.get());
}

test "Cell.modify" {
    var cell = Cell(i32).init(5);

    const new_val = cell.modify(struct {
        fn square(x: i32) i32 {
            return x * x;
        }
    }.square);

    try std.testing.expectEqual(@as(i32, 25), new_val);
    try std.testing.expectEqual(@as(i32, 25), cell.get());
}

test "Cell.compareAndSet success" {
    var cell = Cell(i32).init(10);

    const result = cell.compareAndSet(10, 20);
    try std.testing.expect(result);
    try std.testing.expectEqual(@as(i32, 20), cell.get());
}

test "Cell.compareAndSet failure" {
    var cell = Cell(i32).init(10);

    const result = cell.compareAndSet(99, 20);
    try std.testing.expect(!result);
    try std.testing.expectEqual(@as(i32, 10), cell.get());
}

test "Cell.swap" {
    var cell1 = Cell(i32).init(10);
    var cell2 = Cell(i32).init(20);

    cell1.swap(&cell2);

    try std.testing.expectEqual(@as(i32, 20), cell1.get());
    try std.testing.expectEqual(@as(i32, 10), cell2.get());
}

test "Cell with struct" {
    const Point = struct { x: i32, y: i32 };

    var cell = Cell(Point).init(.{ .x = 0, .y = 0 });

    cell.update(struct {
        fn moveRight(p: Point) Point {
            return .{ .x = p.x + 1, .y = p.y };
        }
    }.moveRight);

    const val = cell.get();
    try std.testing.expectEqual(@as(i32, 1), val.x);
    try std.testing.expectEqual(@as(i32, 0), val.y);
}
