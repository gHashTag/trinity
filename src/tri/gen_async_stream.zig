//! tri/async_stream — Lazy sequences
//! Auto-generated from specs/tri/tri_async_stream.tri
//! TTT Dogfood v0.2 Stage 135

const std = @import("std");

/// Stream state
pub const StreamState = enum {
    Ready,
    Pending,
    Done,
};

/// Iterator state for array-backed streams
pub const ArrayIterator = struct {
    items_ptr: *const []const i32,
    index: usize,
};

/// Lazy stream
pub fn Stream(comptime T: type) type {
    return struct {
        state: StreamState,
        cached_value: ?T,
        // Store iterator data directly instead of function pointer
        items: []const T,
        index: *usize,
        allocator: std.mem.Allocator,

        const Self = @This();

        /// Create stream from array
        pub fn from(items: []const T, allocator: std.mem.Allocator) !Self {
            const index = try allocator.create(usize);
            index.* = 0;

            return .{
                .state = .Ready,
                .cached_value = null,
                .items = items,
                .index = index,
                .allocator = allocator,
            };
        }

        /// Free resources
        pub fn deinit(self: *Self) void {
            self.allocator.destroy(self.index);
        }

        /// Transform each element (simplified - returns empty stream)
        pub fn map(self: Self, comptime U: type, map_fn: fn (T) U) Stream(U) {
            _ = map_fn;
            // Simplified - return empty stream
            return Stream(U).from(&[_]U{}, self.allocator) catch unreachable;
        }

        /// Filter elements (simplified - returns empty stream)
        pub fn filter(self: Self, predicate: fn (T) bool) Stream(T) {
            _ = predicate;
            // Simplified - return empty stream
            return Stream(T).from(&[_]T{}, self.allocator) catch unreachable;
        }

        /// Get next element
        pub fn next(self: *Self) ?T {
            if (self.state == .Done) return null;

            if (self.cached_value) |val| {
                self.cached_value = null;
                return val;
            }

            if (self.index.* >= self.items.len) {
                self.state = .Done;
                return null;
            }

            const val = self.items[self.index.*];
            self.index.* += 1;
            return val;
        }

        /// Collect all elements
        pub fn collect(self: *Self, allocator: std.mem.Allocator) ![]T {
            var list = std.ArrayList(T).initCapacity(allocator, 0) catch unreachable;
            errdefer list.deinit(allocator);

            while (self.next()) |item| {
                try list.append(allocator, item);
            }

            return list.toOwnedSlice(allocator);
        }
    };
}

test "stream from array" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };
    var stream = try Stream(i32).from(&items, std.testing.allocator);
    defer stream.deinit();

    try std.testing.expectEqual(@as(i32, 1), stream.next().?);
    try std.testing.expectEqual(@as(i32, 2), stream.next().?);
    try std.testing.expectEqual(@as(i32, 3), stream.next().?);
}

test "stream collect" {
    const items = [_]i32{ 1, 2, 3 };
    var stream = try Stream(i32).from(&items, std.testing.allocator);
    defer stream.deinit();

    const collected = try stream.collect(std.testing.allocator);
    defer std.testing.allocator.free(collected);

    try std.testing.expectEqual(@as(usize, 3), collected.len);
}
