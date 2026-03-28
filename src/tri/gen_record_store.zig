//! tri/record_store — Column-oriented storage
//! TTT Dogfood v0.2 Stage 295

const std = @import("std");

pub const RecordStore = struct {
    columns: std.ArrayList(std.ArrayList(i32)),
    row_count: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, column_count: usize) !RecordStore {
        var columns = try std.ArrayList(std.ArrayList(i32)).initCapacity(allocator, column_count);
        for (0..column_count) |_| {
            try columns.append(allocator, std.ArrayList(i32).initCapacity(allocator, 16) catch unreachable);
        }
        return .{
            .columns = columns,
            .row_count = 0,
            .allocator = allocator,
        };
    }

    pub fn insert(store: *RecordStore, values: []const i32) !void {
        for (values, 0..) |v, i| {
            if (i < store.columns.items.len) {
                try store.columns.items[i].append(store.allocator, v);
            }
        }
        store.row_count += 1;
    }

    pub fn get(store: *const RecordStore, row: usize, col: usize) ?i32 {
        if (col >= store.columns.items.len) return null;
        const column = store.columns.items[col];
        if (row >= column.items.len) return null;
        return column.items[row];
    }

    pub fn deinit(store: *RecordStore) void {
        for (store.columns.items, 0..) |_, i| {
            store.columns.items[i].deinit(store.allocator);
        }
        store.columns.deinit(store.allocator);
    }
};

test "record store" {
    var store = try RecordStore.init(std.testing.allocator, 2);
    defer store.deinit();
    try store.insert(&[_]i32{ 1, 2 });
    try std.testing.expectEqual(@as(i32, 1), store.get(0, 0).?);
}
