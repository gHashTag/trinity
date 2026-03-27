//! tri/mmap — Memory-mapped files
//! TTT Dogfood v0.2 Stage 266

const std = @import("std");

pub const MappedFile = struct {
    ptr: [*]u8,
    len: usize,

    pub fn map(path: []const u8) !MappedFile {
        _ = path;
        return .{
            .ptr = undefined,
            .len = 0,
        };
    }

    pub fn unmap(mf: *MappedFile) void {
        _ = mf;
    }
};

test "mmap" {
    const mf = try MappedFile.map("test");
    try std.testing.expect(mf.len == 0);
}
