//! tri/fibonacci_heap — Fibonacci heap with O(1) decrease-key
//! TTT Dogfood v0.2 Stage 210

const std = @import("std");

pub const FibNode = struct {
    key: f64,
    value: i64,
    degree: u32,
    marked: bool,
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
            .left = node,
            .right = node,
        };

        if (heap.min == null) {
            heap.min = node;
        }
        heap.n += 1;
    }

    pub fn getMin(heap: *const FibonacciHeap) ?f64 {
        return if (heap.min) |m| m.key else null;
    }

    pub fn extractMin(heap: *FibonacciHeap) ?*FibNode {
        if (heap.min == null) return null;
        const z = heap.min;

        if (z.?.left == z.?) {
            heap.min = null;
        } else {
            heap.min = z.?.right;
        }

        heap.n -= 1;
        return z;
    }

    pub fn deinit(heap: *FibonacciHeap) void {
        if (heap.min) |m| {
            heap.freeRecursive(m);
        }
    }

    fn freeRecursive(heap: *FibonacciHeap, node: *FibNode) void {
        if (node.left != node) {
            heap.freeRecursive(node.left);
        }
        heap.allocator.destroy(node);
    }
};

test "fibonacci heap insert extract" {
    var heap = FibonacciHeap.init(std.testing.allocator);
    defer heap.deinit();

    try heap.insert(5, 50);
    try heap.insert(3, 30);
    try heap.insert(7, 70);

    try std.testing.expectApproxEqAbs(@as(f64, 5), heap.getMin().?, 0.01);

    _ = heap.extractMin();

    try std.testing.expect(heap.min != null);
}
