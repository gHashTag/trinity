//! tri/rope — Immutable string for efficient edits
//! Auto-generated from specs/tri/tri_rope.tri
//! TTT Dogfood v0.2 Stage 91

const std = @import("std");

/// Binary tree string representation
pub const Rope = struct {
    is_leaf: bool,
    text: []const u8 = "",
    left: ?*const Rope = null,
    right: ?*const Rope = null,
    length: usize = 0,

    /// Create empty rope
    pub fn empty() Rope {
        return .{ .is_leaf = true, .length = 0 };
    }

    /// Create rope from string
    pub fn fromString(str: []const u8, allocator: std.mem.Allocator) !Rope {
        if (str.len == 0) return empty();
        const node = try allocator.create(Rope);
        node.* = .{
            .is_leaf = true,
            .text = try allocator.dupe(u8, str),
            .length = str.len,
        };
        return .{ .is_leaf = false, .left = node, .length = str.len };
    }

    /// Concatenate two ropes
    pub fn concat(a: Rope, b: Rope, allocator: std.mem.Allocator) !Rope {
        if (a.length == 0) return b;
        if (b.length == 0) return a;

        const left_copy = try allocator.create(Rope);
        const right_copy = try allocator.create(Rope);
        left_copy.* = a;
        right_copy.* = b;

        return .{
            .is_leaf = false,
            .left = left_copy,
            .right = right_copy,
            .length = a.length + b.length,
        };
    }

    /// Extract substring
    pub fn slice(rope: Rope, start: usize, end: usize, allocator: std.mem.Allocator) !Rope {
        if (start >= end or end > rope.length) return error.InvalidRange;
        if (rope.is_leaf) {
            return fromString(rope.text[start..end], allocator);
        }

        const left = rope.left orelse return empty();
        const left_len = left.length;

        if (end <= left_len) {
            return left.slice(start, end, allocator);
        } else if (start >= left_len) {
            const right = rope.right orelse return empty();
            return right.slice(start - left_len, end - left_len, allocator);
        } else {
            const left_part = try left.slice(start, left_len, allocator);
            const right_part = try (rope.right orelse return empty()).slice(0, end - left_len, allocator);
            return left_part.concat(right_part, allocator);
        }
    }

    /// Convert to flat string
    pub fn flatten(rope: Rope, allocator: std.mem.Allocator) ![]const u8 {
        var list = try std.ArrayList(u8).initCapacity(allocator, rope.length);
        try rope.appendToList(&list);
        return list.toOwnedSlice(allocator);
    }

    fn appendToList(rope: Rope, list: *std.ArrayList(u8)) !void {
        if (rope.is_leaf) {
            try list.appendSlice(rope.text);
        } else {
            if (rope.left) |l| try l.appendToList(list);
            if (rope.right) |r| try r.appendToList(list);
        }
    }
};

test "Rope.empty" {
    const rope = Rope.empty();
    try std.testing.expectEqual(@as(usize, 0), rope.length);
}

test "Rope.fromString" {
    const rope = try Rope.fromString("hello", std.testing.allocator);
    _ = rope;
    // Allocator cleanup skipped for test
}

test "Rope.concat" {
    const a = try Rope.fromString("hello", std.testing.allocator);
    const b = try Rope.fromString(" world", std.testing.allocator);
    const combined = try a.concat(b, std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 11), combined.length);
}
