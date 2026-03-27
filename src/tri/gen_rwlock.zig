//! tri/rwlock — Read-write lock for concurrent access
//! TTT Dogfood v0.2 Stage 223

const std = @import("std");

pub const RwLock = struct {
    readers: usize,
    writer: bool,

    pub fn init() RwLock {
        return .{
            .readers = 0,
            .writer = false,
        };
    }

    pub fn readLock(lock: *RwLock) void {
        while (lock.writer) {}
        lock.readers += 1;
    }

    pub fn readUnlock(lock: *RwLock) void {
        lock.readers -= 1;
    }

    pub fn writeLock(lock: *RwLock) void {
        while (lock.writer or lock.readers > 0) {}
        lock.writer = true;
    }

    pub fn writeUnlock(lock: *RwLock) void {
        lock.writer = false;
    }
};

test "rwlock basic" {
    var lock = RwLock.init();
    lock.writeLock();
    lock.writeUnlock();
    lock.readLock();
    lock.readUnlock();
}
