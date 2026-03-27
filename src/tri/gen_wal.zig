//! tri/wal — Write-ahead log
//! TTT Dogfood v0.2 Stage 298

const std = @import("std");

pub const WAL = struct {
    entries: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) WAL {
        return .{
            .entries = std.ArrayList([]const u8).initCapacity(allocator, 16) catch unreachable,
            .allocator = allocator,
        };
    }

    pub fn append(wal: *WAL, entry: []const u8) !void {
        const copy = try wal.allocator.dupe(u8, entry);
        try wal.entries.append(wal.allocator, copy);
    }

    pub fn checkpoint(wal: *WAL) void {
        wal.entries.clearRetainingCapacity();
    }

    pub fn deinit(wal: *WAL) void {
        for (wal.entries.items) |entry| {
            wal.allocator.free(entry);
        }
        wal.entries.deinit(wal.allocator);
    }
};

test "wal" {
    var wal = WAL.init(std.testing.allocator);
    defer wal.deinit();
    try wal.append("entry1");
    try std.testing.expectEqual(@as(usize, 1), wal.entries.items.len);
}
