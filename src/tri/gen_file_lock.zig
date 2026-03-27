//! tri/file_lock — File locking
//! TTT Dogfood v0.2 Stage 264

const std = @import("std");

pub const FileLock = struct {
    locked: bool,

    pub fn init() FileLock {
        return .{ .locked = false };
    }

    pub fn acquire(lock: *FileLock) !void {
        lock.locked = true;
    }

    pub fn release(lock: *FileLock) void {
        lock.locked = false;
    }
};

test "file lock" {
    var lock = FileLock.init();
    try lock.acquire();
    lock.release();
}
