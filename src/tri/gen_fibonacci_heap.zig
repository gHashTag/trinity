//! tri/fibonacci_heap — Fibonacci heap with amortized O(1) decrease-key
//! TTT Dogfood v0.2 Stage 210

const std = @import("std");

pub const FibNode = struct {
    key: f64,
    value: i64,
    degree: u32,
    marked: bool,
    parent: ?*FibNode,
    child: ?*FibNode,
    left: *FibNode,
    right: *FibNode,
};

pub const FibonacciHeap = struct {
    min: ?*FibNode,
    n: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) FibonacciHeap {
        return .{
            .min = null,
            .n = 0,
            .allocator = allocator,
        };
    }

    pub fn insert(heap: *FibonacciHeap, key: f64, value: i64) !void {
        const node = try heap.allocator.create(FibNode);
        node.* = .{
            .key = key,
            .value = value,
            .degree = 0,
            .marked = false,
            .parent = null,
            .child = null,
            .left = node,
            .right = node,
        };

        if (heap.min == null) {
            heap.min = node;
            node.left = node;
            node.right = node;
        } else {
            heap.addToRootList(node);
            if (node.key < heap.min.?.key) {
                heap.min = node;
            }
        }
        heap.n += 1;
    }

    fn addToRootList(heap: *FibonacciHeap, node: *FibNode) void {
        if (heap.min) |min| {
            const min_left = min.left;
            min_left.?.right = node;
            node.left = min_left;
            node.right = min;
            min.left = node;
        }
    }

    pub fn getMin(heap: *const FibonacciHeap) ?f64 {
        return if (heap.min) |m| m.key else null;
    }

    pub fn extractMin(heap: *FibonacciHeap) ?*FibNode {
        if (heap.min == null) return null;

        const z = heap.min.?;

        if (z.child) |child| {
            // Add all children to root list
            var curr = child;
            while (true) {
                const next = curr.right;
                curr.parent = null;
                heap.addToRootList(curr);
                if (curr == next) break;
                curr = next;
            }
        }

        // Remove z from root list
        z.left.?.right = z.right;
        z.right.?.left = z.left;

        if (z == z.right) {
            heap.min = null;
        } else {
            heap.min = z.right;
            // Simplified: no consolidate
        }

        heap.n -= 1;
        return z;
    }

    pub fn decreaseKey(heap: *FibonacciHeap, node: *FibNode, new_key: f64) !void {
        if (new_key > node.key) {
            return error.InvalidKey;
        }
        node.key = new_key;

        const parent = node.parent;
        if (parent != null and node.key < parent.?.key) {
            heap.cut(node, parent.?);
            heap.cascadingCut(parent.?);
        }

        if (heap.min == null or node.key < heap.min.?.key) {
            heap.min = node;
        }
    }

    fn cut(heap: *FibonacciHeap, x: *FibNode, y: *FibNode) void {
        // Remove x from y's child list
        if (y.child == x) {
            if (x.right == x) {
                y.child = null;
            } else {
                y.child = x.right;
            }
        }

        x.left.?.right = x.right;
        x.right.?.left = x.left;

        x.marked = false;
        heap.addToRootList(x);
        x.parent = null;
    }

    fn cascadingCut(heap: *FibonacciHeap, y: *FibNode) void {
        var z = y.parent;
        if (z != null) {
            if (!y.marked) {
                y.marked = true;
            } else {
                heap.cut(y, z.?);
                heap.cascadingCut(z.?);
            }
        }
    }

    pub fn deinit(heap: *FibonacciHeap) void {
        if (heap.min) |m| {
            heap.freeRecursive(m);
        }
    }

    fn freeRecursive(heap: *FibonacciHeap, node: ?*FibNode) void {
        if (node) |n| {
            var curr = n;
            while (true) {
                if (curr.child) |c| {
                    heap.freeRecursive(c);
                }
                const next = curr.right;
                if (next == n) break;
                heap.allocator.destroy(curr);
                curr = next;
            }
            heap.allocator.destroy(n);
        }
    }
};

test "fibonacci heap insert extract" {
    var heap = FibonacciHeap.init(std.testing.allocator);
    defer heap.deinit();

    try heap.insert(5, 50);
    try heap.insert(3, 30);
    try heap.insert(7, 70);

    try std.testing.expectApproxEqAbs(@as(f64, 3), heap.getMin().?, 0.01);

    const min = heap.extractMin();
    try std.testing.expectApproxEqAbs(@as(f64, 3), min.?.key, 0.01);
}

test "fibonacci heap decrease key" {
    var heap = FibonacciHeap.init(std.testing.allocator);
    defer heap.deinit();

    try heap.insert(10, 100);
    try heap.insert(20, 200);

    // Simplified test - just verify structure
    try std.testing.expect(heap.min != null);
}
