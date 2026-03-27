//! tri/async_io — Asynchronous I/O placeholder
//! TTT Dogfood v0.2 Stage 267

const std = @import("std");

pub const AsyncIO = struct {
    pending: usize,

    pub fn init() AsyncIO {
        return .{ .pending = 0 };
    }

    pub fn read(aio: *AsyncIO, fd: i32, buf: []u8) !void {
        _ = fd;
        _ = buf;
        aio.pending += 1;
    }

    pub fn write(aio: *AsyncIO, fd: i32, buf: []const u8) !void {
        _ = fd;
        _ = buf;
        aio.pending += 1;
    }
};

test "async io" {
    var aio = AsyncIO.init();
    var buf: [1]u8 = .{0};
    try aio.read(0, &buf);
    try std.testing.expectEqual(@as(usize, 1), aio.pending);
}
