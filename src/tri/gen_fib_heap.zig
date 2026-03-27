//! tri/fib_heap — Fibonacci heap
//! Auto-generated from specs/tri/tri_fib_heap.tri
//! TTT Dogfood v0.2 Stage 147

const std = @import("std");

/// Fibonacci heap node
pub fn FibNode(comptime T: type) type {
    return struct {
        value: T,
        degree: usize = 0,
        parent: ?*FibNode(T),
        children: std.ArrayList(*FibNode(T)),
        marked: bool = false,
    };
}

/// Fibonacci heap
pub fn FibHeap(comptime T: type) type {
    return struct {
        min: ?*FibNode(T),
        roots: std.ArrayList(*FibNode(T)),
        size: usize,
        allocator: std.mem.Allocator,

        const Self = @This();

        /// Create empty Fibonacci heap
        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .min = null,
                .roots = std.ArrayList(*FibNode(T)).initCapacity(allocator, 0) catch unreachable,
                .size = 0,
                .allocator = allocator,
            };
        }

        /// Free resources
        pub fn deinit(self: *Self) void {
            for (self.roots.items) |root| {
                self.destroyNode(root);
            }
            self.roots.deinit(self.allocator);
        }

        /// Recursively destroy node and children
        fn destroyNode(self: *Self, node: *FibNode(T)) void {
            for (node.children.items) |child| {
                self.destroyNode(child);
            }
            node.children.deinit(self.allocator);
            self.allocator.destroy(node);
        }

        /// Insert value (O(1) amortized)
        pub fn insert(self: *Self, value: T) !void {
            const node = try self.allocator.create(FibNode(T));
            node.* = .{
                .value = value,
                .degree = 0,
                .parent = null,
                .children = std.ArrayList(*FibNode(T)).initCapacity(self.allocator, 0) catch unreachable,
                .marked = false,
            };

            try self.roots.append(self.allocator, node);

            if (self.min == null or value < self.min.?.value) {
                self.min = node;
            }

            self.size += 1;
        }

        /// Get minimum value
        pub fn peek(self: *const Self) ?T {
            if (self.min) |m| {
                return m.value;
            }
            return null;
        }

        /// Remove and return minimum (O(log n) amortized)
        pub fn extractMin(self: *Self) !?T {
            const min_node = self.min orelse return null;
            const min_value = min_node.value;

            // Move min's children to roots
            for (min_node.children.items) |child| {
                child.parent = null;
                self.roots.append(self.allocator, child) catch {};
            }

            // Remove min from roots
            for (self.roots.items, 0..) |root, i| {
                if (root == min_node) {
                    _ = self.roots.orderedRemove(i);
                    break;
                }
            }

            min_node.children.deinit(self.allocator);
            self.allocator.destroy(min_node);
            self.size -= 1;

            if (self.roots.items.len > 0) {
                self.consolidate();
            } else {
                self.min = null;
            }

            return min_value;
        }

        /// Consolidate trees of same degree
        fn consolidate(self: *Self) void {
            if (self.roots.items.len == 0) return;

            var degree_table = std.AutoHashMap(usize, *FibNode(T)).init(self.allocator);
            defer degree_table.deinit();

            var i: usize = 0;
            while (i < self.roots.items.len) {
                var x = self.roots.items[i];
                var d = x.degree;

                while (degree_table.get(d)) |y_ptr| {
                    var y = y_ptr;

                    if (x.value > y.value) {
                        const tmp = x;
                        x = y;
                        y = tmp;
                    }

                    // Link y as child of x
                    self.link(y, x);
                    _ = degree_table.remove(d);
                    d += 1;
                }

                degree_table.put(d, x) catch unreachable;
                i += 1;
            }

            // Find new min
            self.min = null;
            for (self.roots.items) |root| {
                if (self.min == null or root.value < self.min.?.value) {
                    self.min = root;
                }
            }
        }

        /// Link y as child of x
        fn link(self: *Self, y: *FibNode(T), x: *FibNode(T)) void {
            // Remove y from roots
            for (self.roots.items, 0..) |root, i| {
                if (root == y) {
                    _ = self.roots.orderedRemove(i);
                    break;
                }
            }

            y.parent = x;
            x.children.append(self.allocator, y) catch unreachable;
            x.degree += 1;
            y.marked = false;
        }
    };
}

test "fib heap init" {
    var fh = FibHeap(i32).init(std.testing.allocator);
    defer fh.deinit();

    try std.testing.expectEqual(@as(usize, 0), fh.size);
}

test "fib heap insert peek" {
    var fh = FibHeap(i32).init(std.testing.allocator);
    defer fh.deinit();

    try fh.insert(5);
    try fh.insert(3);
    try fh.insert(7);

    try std.testing.expectEqual(@as(i32, 3), fh.peek().?);
}

test "fib heap extract_min" {
    var fh = FibHeap(i32).init(std.testing.allocator);
    defer fh.deinit();

    try fh.insert(5);
    try fh.insert(3);
    try fh.insert(7);

    try std.testing.expectEqual(@as(i32, 3), (try fh.extractMin()).?);
    try std.testing.expectEqual(@as(i32, 5), (try fh.extractMin()).?);
    try std.testing.expectEqual(@as(i32, 7), (try fh.extractMin()).?);
}
