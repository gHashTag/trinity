//! tri/fs — Filesystem operations
//! Auto-generated from specs/tri/tri_fs.tri
//! TTT Dogfood v0.2 Stage 107

const std = @import("std");

/// Filesystem path
pub const Path = struct {
    parts: std.ArrayList([]const u8),
    absolute: bool = false,

    /// Create empty path
    pub fn init(allocator: std.mem.Allocator) !Path {
        return .{
            .parts = try std.ArrayList([]const u8).initCapacity(allocator, 0),
            .absolute = false,
        };
    }

    /// Free resources
    pub fn deinit(self: *Path, allocator: std.mem.Allocator) void {
        self.parts.deinit(allocator);
    }

    /// Get filename without directory
    pub fn basename(self: Path) []const u8 {
        if (self.parts.items.len == 0) return ".";
        return self.parts.items[self.parts.items.len - 1];
    }

    /// Get directory path
    pub fn dirname(self: Path) []const u8 {
        if (self.parts.items.len <= 1) return if (self.absolute) "/" else ".";
        return self.parts.items[self.parts.items.len - 2];
    }

    /// Get file extension or null
    pub fn extension(self: Path) ?[]const u8 {
        if (self.parts.items.len == 0) return null;
        const filename = self.parts.items[self.parts.items.len - 1];
        if (std.mem.lastIndexOfScalar(u8, filename, '.')) |dot| {
            if (dot == 0 or dot == filename.len - 1) return null;
            return filename[dot..];
        }
        return null;
    }
};

/// Concatenate paths
pub fn join(base: Path, suffix: Path, allocator: std.mem.Allocator) !Path {
    var result = try Path.init(allocator);
    result.absolute = base.absolute;
    for (base.parts.items) |part| {
        try result.parts.append(allocator, part);
    }
    for (suffix.parts.items) |part| {
        try result.parts.append(allocator, part);
    }
    return result;
}

test "Path.basename" {
    var path = try Path.init(std.testing.allocator);
    defer path.deinit(std.testing.allocator);
    try path.parts.append(std.testing.allocator, "home");
    try path.parts.append(std.testing.allocator, "user");
    try path.parts.append(std.testing.allocator, "file.txt");
    try std.testing.expectEqualStrings("file.txt", path.basename());
}

test "Path.extension" {
    var path = try Path.init(std.testing.allocator);
    defer path.deinit(std.testing.allocator);
    try path.parts.append(std.testing.allocator, "file.txt");
    try std.testing.expect(path.extension() != null);
}
