//! tri/cursor — Database cursor
//! TTT Dogfood v0.2 Stage 299

const std = @import("std");

pub const Cursor = struct {
    position: usize,
    data: std.ArrayList(i32),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Cursor {
        return .{
            .position = 0,
            .data = std.ArrayList(i32).initCapacity(allocator, 16) catch unreachable,
            .allocator = allocator,
        };
    }

    pub fn next(cursor: *Cursor) ?i32 {
        if (cursor.position >= cursor.data.items.len) return null;
        const value = cursor.data.items[cursor.position];
        cursor.position += 1;
        return value;
    }

    pub fn reset(cursor: *Cursor) void {
        cursor.position = 0;
    }

    pub fn deinit(cursor: *Cursor) void {
        cursor.data.deinit(cursor.allocator);
    }
};

test "cursor" {
    var cursor = Cursor.init(std.testing.allocator);
    try cursor.data.append(cursor.allocator, 42);
    defer cursor.deinit();
    try std.testing.expectEqual(@as(i32, 42), cursor.next().?);
}
