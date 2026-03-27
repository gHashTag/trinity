//! tri/index — Inverted index
//! TTT Dogfood v0.2 Stage 296

const std = @import("std");

pub const InvertedIndex = struct {
    index: std.StringHashMap(std.ArrayList(usize)),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) InvertedIndex {
        return .{
            .index = std.StringHashMap(std.ArrayList(usize)).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn add(idx: *InvertedIndex, term: []const u8, doc_id: usize) !void {
        const gop = try idx.index.getOrPut(term);
        if (!gop.found_existing) {
            gop.value_ptr.* = std.ArrayList(usize).initCapacity(idx.allocator, 4);
        }
        try gop.value_ptr.append(idx.allocator, doc_id);
    }

    pub fn search(idx: *const InvertedIndex, term: []const u8) ?[]const usize {
        if (idx.index.get(term)) |list| {
            return list.items;
        }
        return null;
    }

    pub fn deinit(idx: *InvertedIndex) void {
        var iter = idx.index.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*.deinit(idx.allocator);
        }
        idx.index.deinit();
    }
};

test "inverted index" {
    var idx = InvertedIndex.init(std.testing.allocator);
    defer idx.deinit();
    try idx.add("hello", 1);
    try std.testing.expectEqual(@as(usize, 1), idx.search("hello").?[0]);
}
