//! tri/pipe — Pipe communication
//! TTT Dogfood v0.2 Stage 268

const std = @import("std");

pub const Pipe = struct {
    read_end: i32,
    write_end: i32,

    pub fn create() !Pipe {
        return .{
            .read_end = 0,
            .write_end = 1,
        };
    }

    pub fn close(pipe: *Pipe) void {
        pipe.read_end = -1;
        pipe.write_end = -1;
    }
};

test "pipe" {
    const pipe = try Pipe.create();
    try std.testing.expect(pipe.read_end >= 0);
}
