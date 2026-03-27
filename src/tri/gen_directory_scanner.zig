//! tri/directory_scanner — Directory traversal
//! TTT Dogfood v0.2 Stage 263

const std = @import("std");

pub const DirScanner = struct {
    path: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, path: []const u8) DirScanner {
        return .{
            .path = path,
            .allocator = allocator,
        };
    }

    pub fn list(scanner: *DirScanner) ![][]const u8 {
        const empty = try scanner.allocator.alloc([]const u8, 0);
        return empty;
    }
};

test "dir scanner" {
    var scanner = DirScanner.init(std.testing.allocator, ".");
    _ = try scanner.list();
}
