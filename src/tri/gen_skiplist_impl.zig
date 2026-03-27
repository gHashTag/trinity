//! tri/skiplist_impl — Skip list implementation
//! Auto-generated from specs/tri_skiplist_impl.tri
//! TTT Dogfood v0.2 Stage 194

const std = @import("std");

/// Skip list node
pub const SkipNode = struct {
    value: i64,
    forward: []?*SkipNode,
    level: usize,

    pub fn deinit(node: *SkipNode, allocator: std.mem.Allocator) void {
        allocator.free(node.forward);
        allocator.destroy(node);
    }
};

/// Probabilistic skip list
pub const SkipList = struct {
    head: *SkipNode,
    max_level: usize,
    allocator: std.mem.Allocator,

    /// Create skip list
    pub fn init(allocator: std.mem.Allocator, max_level: usize) !SkipList {
        // Create head node with max_level forward pointers
        const forward = try allocator.alloc(?*SkipNode, max_level);
        @memset(forward, null);

        const head = try allocator.create(SkipNode);
        head.* = .{
            .value = std.math.minInt(i64),
            .forward = forward,
            .level = max_level,
        };

        return .{
            .head = head,
            .max_level = max_level,
            .allocator = allocator,
        };
    }

    /// Random level
    fn randomLevel(sl: *const SkipList) usize {
        var level: usize = 0;
        const max = sl.max_level - 1;

        // Simple PRNG for probability (50% chance per level)
        while (level < max) {
            const rand: u8 = @truncate(level *% 37 +% 1);
            if (rand >= 128) break;
            level += 1;
        }

        return level;
    }

    /// Insert value
    pub fn insert(sl: *SkipList, value: i64) !void {
        const node_level = sl.randomLevel();
        const update = try sl.allocator.alloc(?*SkipNode, sl.max_level);
        defer sl.allocator.free(update);
        @memset(update, null);

        var current = sl.head;

        // Find insertion points from top level down
        var lvl: isize = @intCast(sl.max_level - 1);
        while (lvl >= 0) : (lvl -= 1) {
            const idx = @as(usize, @intCast(lvl));

            while (current.forward[idx]) |next| {
                if (next.value < value) {
                    current = next;
                } else {
                    break;
                }
            }

            update[idx] = current;
        }

        // Create new node
        const forward = try sl.allocator.alloc(?*SkipNode, node_level + 1);
        @memset(forward, null);

        const node = try sl.allocator.create(SkipNode);
        node.* = .{
            .value = value,
            .forward = forward,
            .level = node_level,
        };

        // Link node at each level
        for (0..node_level + 1) |lvl_idx| {
            if (update[lvl_idx]) |u| {
                node.forward[lvl_idx] = u.forward[lvl_idx];
                u.forward[lvl_idx] = node;
            }
        }
    }

    /// Check if value exists
    pub fn search(sl: *const SkipList, value: i64) bool {
        var current = sl.head;

        var lvl: isize = @intCast(sl.max_level - 1);
        while (lvl >= 0) : (lvl -= 1) {
            const idx = @as(usize, @intCast(lvl));

            while (current.forward[idx]) |next| {
                if (next.value < value) {
                    current = next;
                } else {
                    break;
                }
            }
        }

        // Check level 0
        if (current.forward[0]) |next| {
            return next.value == value;
        }

        return false;
    }

    /// Remove value
    pub fn delete(sl: *SkipList, value: i64) !bool {
        const update = try sl.allocator.alloc(?*SkipNode, sl.max_level);
        defer sl.allocator.free(update);
        @memset(update, null);

        var current = sl.head;
        var target: ?*SkipNode = null;

        // Find node and update pointers
        var lvl: isize = @intCast(sl.max_level - 1);
        while (lvl >= 0) : (lvl -= 1) {
            const idx = @as(usize, @intCast(lvl));

            while (current.forward[idx]) |next| {
                if (next.value < value) {
                    current = next;
                } else {
                    break;
                }
            }

            update[idx] = current;

            if (current.forward[idx]) |next| {
                if (next.value == value) {
                    target = next;
                }
            }
        }

        if (target) |t| {
            for (0..sl.max_level) |lvl_idx| {
                if (update[lvl_idx]) |u| {
                    if (u.forward[lvl_idx] == t) {
                        u.forward[lvl_idx] = t.forward[lvl_idx];
                    }
                }
            }
            t.deinit(sl.allocator);
            return true;
        }

        return false;
    }

    /// Free list
    pub fn deinit(sl: *SkipList) void {
        // Free all nodes except head first
        var current = sl.head.forward[0];
        while (current) |node| {
            const next = node.forward[0];
            node.deinit(sl.allocator);
            current = next;
        }
        // Free head last
        sl.head.deinit(sl.allocator);
    }
};

test "skiplist init" {
    var sl = try SkipList.init(std.testing.allocator, 4);
    defer sl.deinit();

    try std.testing.expect(sl.head.value == std.math.minInt(i64));
}

test "skiplist insert search" {
    var sl = try SkipList.init(std.testing.allocator, 4);
    defer sl.deinit();

    try sl.insert(10);
    try sl.insert(20);
    try sl.insert(30);

    try std.testing.expect(sl.search(20));
    try std.testing.expect(!sl.search(99));
}
