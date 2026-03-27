//! tri/semaphore — Counting semaphore
//! TTT Dogfood v0.2 Stage 224

const std = @import("std");

pub const Semaphore = struct {
    count: usize,

    pub fn init(initial: usize) Semaphore {
        return .{ .count = initial };
    }

    pub fn wait(sem: *Semaphore) void {
        while (sem.count == 0) {}
        sem.count -= 1;
    }

    pub fn signal(sem: *Semaphore) void {
        sem.count += 1;
    }

    pub fn tryWait(sem: *Semaphore) bool {
        if (sem.count == 0) return false;
        sem.count -= 1;
        return true;
    }
};

test "semaphore wait signal" {
    var sem = Semaphore.init(0);
    try std.testing.expect(!sem.tryWait());
    sem.signal();
    try std.testing.expect(sem.tryWait());
}
