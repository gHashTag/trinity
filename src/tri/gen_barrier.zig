//! tri/barrier — Synchronization barrier
//! TTT Dogfood v0.2 Stage 225

const std = @import("std");

pub const Barrier = struct {
    count: usize,
    remaining: usize,

    pub fn init(num_threads: usize) Barrier {
        return .{
            .count = num_threads,
            .remaining = num_threads,
        };
    }

    pub fn wait(barrier: *Barrier) void {
        barrier.remaining -= 1;
        if (barrier.remaining == 0) {
            barrier.remaining = barrier.count;
        }
    }
};

test "barrier wait" {
    var barrier = Barrier.init(2);
    barrier.remaining = 2;
    barrier.wait();
}
