//! tri/work_stealing — Work-stealing deque for thread pools
//! TTT Dogfood v0.2 Stage 222

const std = @import("std");

pub const WorkStealingDeque = struct {
    tasks: std.ArrayList(i64),
    bottom: usize,
    top: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) !WorkStealingDeque {
        const tasks = try std.ArrayList(i64).initCapacity(allocator, capacity);
        return .{
            .tasks = tasks,
            .bottom = 0,
            .top = 0,
            .allocator = allocator,
        };
    }

    pub fn push(deque: *WorkStealingDeque, task: i64) !void {
        try deque.tasks.append(deque.allocator, task);
        deque.bottom += 1;
    }

    pub fn pop(deque: *WorkStealingDeque) ?i64 {
        if (deque.bottom <= deque.top) return null;
        deque.bottom -= 1;
        return deque.tasks.pop();
    }

    pub fn deinit(deque: *WorkStealingDeque) void {
        deque.tasks.deinit(deque.allocator);
    }
};

test "work stealing push pop" {
    var deque = try WorkStealingDeque.init(std.testing.allocator, 16);
    defer deque.deinit();

    try deque.push(42);
    const popped = deque.pop();
    try std.testing.expect(popped != null);
}
