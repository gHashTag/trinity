//! tri/hash_table — Open addressing hash table
//! TTT Dogfood v0.2 Stage 293

const std = @import("std");

pub const Entry = struct {
    key: i32,
    value: i32,
    used: bool,
};

pub const HashTable = struct {
    entries: []Entry,
    capacity: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) !HashTable {
        const entries = try allocator.alloc(Entry, capacity);
        @memset(entries, .{ .key = 0, .value = 0, .used = false });
        return .{
            .entries = entries,
            .capacity = capacity,
            .allocator = allocator,
        };
    }

    pub fn insert(table: *HashTable, key: i32, value: i32) !void {
        const abs_key: u32 = @intCast(@abs(key));
        const idx = @as(usize, @intCast(abs_key % @as(u32, @intCast(table.capacity))));
        table.entries[idx] = .{ .key = key, .value = value, .used = true };
    }

    pub fn get(table: *const HashTable, key: i32) ?i32 {
        const abs_key: u32 = @intCast(@abs(key));
        const idx = @as(usize, @intCast(abs_key % @as(u32, @intCast(table.capacity))));
        const entry = table.entries[idx];
        return if (entry.used and entry.key == key) entry.value else null;
    }

    pub fn deinit(table: *HashTable) void {
        table.allocator.free(table.entries);
    }
};

test "hash table" {
    var table = try HashTable.init(std.testing.allocator, 16);
    defer table.deinit();
    try table.insert(5, 42);
    try std.testing.expectEqual(@as(i32, 42), table.get(5).?);
}
