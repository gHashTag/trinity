//! tri/lockfree_stack — Treiber stack (lock-free)
//! TTT Dogfood v0.2 Stage 193

const std = @import("std");

pub const Node = struct {
    value: i64,
    next: ?*Node,
};

pub const LockFreeStack = struct {
    head: ?*Node = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) LockFreeStack {
        return .{ .allocator = allocator };
    }

    pub fn push(stack: *LockFreeStack, value: i64) !void {
        const node = try stack.allocator.create(Node);
        node.* = .{ .value = value, .next = stack.head };

        while (true) {
            const old_head = stack.head;
            node.next = old_head;

            if (@cmpxchgStrong(?*Node, &stack.head, old_head, node, .acquire, .monotonic) == null) {
                return;
            }
        }
    }

    pub fn pop(stack: *LockFreeStack) ?i64 {
        while (true) {
            const old_head = stack.head orelse return null;
            const new_head = old_head.next;

            if (@cmpxchgStrong(?*Node, &stack.head, old_head, new_head, .acquire, .monotonic) == null) {
                const value = old_head.value;
                stack.allocator.destroy(old_head);
                return value;
            }
        }
    }

    pub fn isEmpty(stack: *const LockFreeStack) bool {
        return stack.head == null;
    }
};

test "lockfree stack push pop" {
    var stack = LockFreeStack.init(std.testing.allocator);
    defer {
        while (stack.pop()) |_| {}
    };

    try stack.push(1);
    try stack.push(2);

    try std.testing.expectEqual(@as(i64, 2), stack.pop().?);
    try std.testing.expectEqual(@as(i64, 1), stack.pop().?);
}

test "lockfree stack empty" {
    var stack = LockFreeStack.init(std.testing.allocator);
    defer {
        while (stack.pop()) |_| {}
    };

    try std.testing.expect(stack.isEmpty());
    try std.testing.expect(stack.pop() == null);
}
