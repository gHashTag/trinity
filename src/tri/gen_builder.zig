//! tri/builder — Efficient sequential construction
//! Auto-generated from specs/tri/tri_builder.tri
//! TTT Dogfood v0.2 Stage 100

const std = @import("std");

/// Grow-only buffer for construction
pub fn Builder(comptime T: type) type {
    return struct {
        items: []T = &[_]T{},
        capacity: usize = 0,
        len: usize = 0,
        allocator: std.mem.Allocator,

        const Self = @This();

        /// Create with pre-allocated capacity
        pub fn init(capacity: usize, allocator: std.mem.Allocator) !Self {
            const items = try allocator.alloc(T, capacity);
            return .{
                .items = items,
                .capacity = capacity,
                .len = 0,
                .allocator = allocator,
            };
        }

        /// Create empty builder
        pub fn empty(allocator: std.mem.Allocator) Self {
            return .{
                .items = &[_]T{},
                .capacity = 0,
                .len = 0,
                .allocator = allocator,
            };
        }

        /// Free resources
        pub fn deinit(self: Self) void {
            if (self.capacity > 0) {
                self.allocator.free(self.items);
            }
        }

        /// Add single item
        pub fn append(self: *Self, item: T) !void {
            if (self.len >= self.capacity) {
                const new_cap = if (self.capacity == 0) 4 else self.capacity * 2;
                const new_items = try self.allocator.realloc(self.items, new_cap);
                self.items = new_items;
                self.capacity = new_cap;
            }
            self.items[self.len] = item;
            self.len += 1;
        }

        /// Add multiple items
        pub fn appendSlice(self: *Self, slice: []const T) !void {
            const needed = self.len + slice.len;
            if (needed > self.capacity) {
                var new_cap = self.capacity;
                while (new_cap < needed) {
                    new_cap = if (new_cap == 0) 4 else new_cap * 2;
                }
                const new_items = try self.allocator.realloc(self.items, new_cap);
                self.items = new_items;
                self.capacity = new_cap;
            }
            @memcpy(self.items[self.len..][0..slice.len], slice);
            self.len += slice.len;
        }

        /// Current item count
        pub fn len(self: Self) usize {
            return self.len;
        }

        /// Allocated space
        pub fn capacity(self: Self) usize {
            return self.capacity;
        }

        /// Convert to owned slice, consume builder
        pub fn finish(self: Self) ![]T {
            if (self.len == 0) {
                if (self.capacity > 0) {
                    self.allocator.free(self.items);
                }
                return &[_]T{};
            }
            if (self.len == self.capacity) {
                return self.items;
            }
            // Shrink to fit
            const exact = try self.allocator.realloc(self.items, self.len);
            return exact;
        }

        /// Clear without freeing
        pub fn reset(self: *Self) void {
            self.len = 0;
        }
    };
}

test "Builder.empty" {
    var b = Builder(i32).empty(std.testing.allocator);
    defer b.deinit();
    try std.testing.expectEqual(@as(usize, 0), b.len());
}

test "Builder.append" {
    var b = try Builder(i32).init(4, std.testing.allocator);
    defer b.deinit();
    try b.append(1);
    try b.append(2);
    try b.append(3);
    try std.testing.expectEqual(@as(usize, 3), b.len());
    try std.testing.expectEqual(@as(i32, 2), b.items[1]);
}

test "Builder.appendSlice" {
    var b = Builder(i32).empty(std.testing.allocator);
    defer b.deinit();
    try b.appendSlice(&[_]i32{ 1, 2, 3 });
    try std.testing.expectEqual(@as(usize, 3), b.len());
}

test "Builder.finish" {
    var b = try Builder(i32).init(4, std.testing.allocator);
    try b.appendSlice(&[_]i32{ 1, 2, 3 });
    const result = try b.finish();
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 3 }, result);
}

test "Builder.grow" {
    var b = Builder(i32).empty(std.testing.allocator);
    defer b.deinit();
    // Append more than initial capacity
    for (0..10) |i| {
        try b.append(@intCast(i));
    }
    try std.testing.expectEqual(@as(usize, 10), b.len());
}

test "Builder.reset" {
    var b = try Builder(i32).init(4, std.testing.allocator);
    defer b.deinit();
    try b.append(1);
    try b.append(2);
    b.reset();
    try std.testing.expectEqual(@as(usize, 0), b.len());
    try std.testing.expect(@as(usize, 4) >= b.capacity());
}
