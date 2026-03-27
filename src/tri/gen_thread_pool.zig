//! tri/thread_pool — Thread pool for parallel work
//! TTT Dogfood v0.2 Stage 221

const std = @import("std");

pub const ThreadPool = struct {
    num_threads: usize,
    shutdown: bool,

    pub fn init(allocator: std.mem.Allocator, num_threads: usize) !ThreadPool {
        _ = allocator;
        return .{
            .num_threads = num_threads,
            .shutdown = false,
        };
    }

    pub fn deinit(pool: *ThreadPool) void {
        _ = pool;
    }
};

test "thread pool init" {
    const pool = try ThreadPool.init(std.testing.allocator, 4);
    try std.testing.expectEqual(@as(usize, 4), pool.num_threads);
}
