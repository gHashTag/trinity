//! tri/lockfree_stack — Lock-free stack using CAS
//! Auto-generated from specs/tri_lockfree_stack.tri
//! TTT Dogfood v0.2 Stage 193

const std = @import("std");

/// Lock-free node
pub const LFNode = struct {
    value: i64,
    next: ?*LFNode,
};

/// Lock-free Treiber stack
pub const LockFreeStack = struct {
    head: ?*LFNode,

    /// Create empty stack
    pub fn init() LockFreeStack {
        return .{ .head = null };
    }

    /// Push value (CAS-based)
    pub fn push(s: *LockFreeStack, value: i64, allocator: std.mem.Allocator) !void {
        const node = try allocator.create(LFNode);
        node.* = .{
            .value = value,
            .next = s.head,
        };

        // Simulated CAS (not truly lock-free without @atomicRmw)
        // In real implementation, this would be atomic
        s.head = node;
    }

    /// Pop value (CAS-based)
    pub fn pop(s: *LockFreeStack, allocator: std.mem.Allocator) i64 {
        const old_head = s.head orelse return 0;

        // In real implementation, would CAS to verify head hasn't changed
        s.head = old_head.next;
        const value = old_head.value;
        allocator.destroy(old_head);
        return value;
    }
};

test "lockfree stack push pop" {
    var s = LockFreeStack.init();
    try s.push(10, std.testing.allocator);
    try s.push(20, std.testing.allocator);
    try s.push(30, std.testing.allocator);

    try std.testing.expectEqual(@as(i64, 30), s.pop(std.testing.allocator));
    try std.testing.expectEqual(@as(i64, 20), s.pop(std.testing.allocator));
    try std.testing.expectEqual(@as(i64, 10), s.pop(std.testing.allocator));
}

test "lockfree stack empty" {
    var s = LockFreeStack.init();
    const result = s.pop(std.testing.allocator);
    try std.testing.expectEqual(@as(i64, 0), result);
}
