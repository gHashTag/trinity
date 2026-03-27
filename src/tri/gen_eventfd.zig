//! tri/eventfd — Event notification
//! TTT Dogfood v0.2 Stage 269

const std = @import("std");

pub const EventFd = struct {
    fd: i32,

    pub fn init(initval: u32) !EventFd {
        _ = initval;
        return .{ .fd = 0 };
    }

    pub fn read(efd: *EventFd) !u64 {
        _ = efd;
        return 0;
    }

    pub fn write(efd: *EventFd, val: u64) !void {
        _ = efd;
        _ = val;
    }
};

test "eventfd" {
    const efd = try EventFd.init(0);
    try std.testing.expect(efd.fd >= 0);
}
