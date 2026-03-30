// @origin(spec:managed_list.tri) @regen(manual-impl)
//
// Zig 0.15 ArrayList API Compatibility Wrapper
//
// In Zig 0.15, ArrayList no longer stores the allocator internally.
// All methods (append, deinit, toOwnedSlice, etc.) now require the allocator
// to be passed as the first argument. This wrapper restores the Zig 0.14 behavior
// where the allocator is stored with the list.
//
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

/// ManagedList provides Zig 0.14-compatible ArrayList API for Zig 0.15
/// The allocator is stored with the list and automatically used in all methods.
pub fn ManagedList(comptime T: type) type {
    return struct {
        inner: std.ArrayList(T),
        gpa: Allocator,

        const Self = @This();

        /// Initialize empty managed list
        pub fn init(allocator: Allocator) Self {
            return .{
                .inner = std.ArrayList(T).empty,
                .gpa = allocator,
            };
        }

        /// Initialize with capacity
        pub fn initCapacity(allocator: Allocator, capacity: usize) !Self {
            return .{
                .inner = try std.ArrayList(T).initCapacity(allocator, capacity),
                .gpa = allocator,
            };
        }

        /// Append item to list (allocator automatically provided)
        pub fn append(self: *Self, item: T) !void {
            try self.inner.append(self.gpa, item);
        }

        /// Append slice of items to list
        pub fn appendSlice(self: *Self, slice: []const T) !void {
            try self.inner.appendSlice(self.gpa, slice);
        }

        /// Get number of items in list
        pub fn len(self: *const Self) usize {
            return self.inner.items.len;
        }

        /// Check if list is empty
        pub fn isEmpty(self: *const Self) bool {
            return self.inner.items.len == 0;
        }

        /// Get slice of all items
        pub fn items(self: *const Self) []const T {
            return self.inner.items;
        }

        /// Get mutable slice of all items
        pub fn mutableItems(self: *Self) []T {
            return self.inner.items;
        }

        /// Clear list but keep capacity
        pub fn clearRetainingCapacity(self: *Self) void {
            self.inner.clearRetainingCapacity();
        }

        /// Deinitialize list (allocator automatically provided)
        pub fn deinit(self: *Self) void {
            self.inner.deinit(self.gpa);
        }

        /// Get owned slice (allocator automatically provided)
        pub fn toOwnedSlice(self: *Self) ![]T {
            return try self.inner.toOwnedSlice(self.gpa);
        }

        /// Get item at index
        pub fn get(self: *const Self, index: usize) T {
            return self.inner.items[index];
        }

        /// Set item at index
        pub fn set(self: *Self, index: usize, item: T) void {
            self.inner.items[index] = item;
        }

        /// Pop last item
        pub fn pop(self: *Self) ?T {
            return self.inner.pop();
        }

        /// Remove last item and return it
        pub fn popOrNull(self: *Self) ?T {
            return self.inner.pop();
        }

        /// Iterator
        pub fn iterator(self: *const Self) Iterator {
            return .{
                .list = self,
                .index = 0,
            };
        }

        pub const Iterator = struct {
            list: *const Self,
            index: usize,

            pub fn next(self: *Iterator) ?T {
                if (self.index >= self.list.len()) return null;
                const item = self.list.get(self.index);
                self.index += 1;
                return item;
            }
        };
    };
}

// ============================================================================
// TESTS
// ============================================================================

test "managed_list: init and append" {
    const allocator = std.testing.allocator;
    var list = ManagedList(i32).init(allocator);
    defer list.deinit();

    try list.append(42);
    try list.append(100);

    try std.testing.expectEqual(@as(usize, 2), list.len());
    try std.testing.expectEqual(42, list.get(0));
    try std.testing.expectEqual(100, list.get(1));
}

test "managed_list: initCapacity and toOwnedSlice" {
    const allocator = std.testing.allocator;
    var list = try ManagedList(i32).initCapacity(allocator, 3);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);

    const slice = try list.toOwnedSlice();
    defer allocator.free(slice);

    try std.testing.expectEqual(@as(usize, 3), slice.len);
    try std.testing.expectEqual(1, slice[0]);
    try std.testing.expectEqual(2, slice[1]);
    try std.testing.expectEqual(3, slice[2]);
}

test "managed_list: appendSlice" {
    const allocator = std.testing.allocator;
    var list = ManagedList(i32).init(allocator);
    defer list.deinit();

    const items = [_]i32{ 1, 2, 3 };
    try list.appendSlice(&items);

    try std.testing.expectEqual(@as(usize, 3), list.len());
}

test "managed_list: isEmpty and clear" {
    const allocator = std.testing.allocator;
    var list = ManagedList(i32).init(allocator);
    defer list.deinit();

    try std.testing.expect(list.isEmpty());

    try list.append(42);
    try std.testing.expect(!list.isEmpty());

    list.clearRetainingCapacity();
    try std.testing.expect(list.isEmpty());
}

test "managed_list: iterator" {
    const allocator = std.testing.allocator;
    var list = ManagedList(i32).init(allocator);
    defer list.deinit();

    try list.append(10);
    try list.append(20);
    try list.append(30);

    var sum: i32 = 0;
    var iter = list.iterator();
    while (iter.next()) |item| {
        sum += item;
    }

    try std.testing.expectEqual(@as(i32, 60), sum);
}
