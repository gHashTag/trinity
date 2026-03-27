//! tri/skiplist_impl — Skip list implementation
//! Auto-generated from specs/tri_skiplist_impl.tri
//! TTT Dogfood v0.2 Stage 194

const std = @import("std");

/// Skip list node
pub const SkipNode = struct {
    value: i64,
    forward: [][]?SkipNode,
    level: usize,

    pub fn deinit(node: *SkipNode, allocator: std.mem.Allocator) void {
        for (node.forward) |level| {
            allocator.free(level);
        }
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
        const forward = try allocator.alloc([]?SkipNode, max_level);
        for (0..max_level) |i| {
            forward[i] = &[_]?SkipNode{};
        }

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

        while (level < max and std.crypto.random.int(u8, std.testing.random) < @as(u8, 128)) {
            level += 1;
        }

        return level;
    }

    /// Insert value
    pub fn insert(sl: *SkipList, value: i64) !void {
        const level = sl.randomLevel();
        const update = try sl.allocator.alloc([]?SkipNode, level + 1);
        defer sl.allocator.free(update);

        var current = sl.head;

        // Find insertion points
        var i: isize = @intCast(sl.max_level);
        while (i >= 0) : (i -= 1) {
            const idx = @as(usize, @intCast(i));

            while (current.forward[idx].?.value < value) {
                current = current.forward[idx].?;
            }

            if (idx <= level) {
                update[idx] = current;
            }
        }

        // Create new node
        const forward = try sl.allocator.alloc([]?SkipNode, level + 1);
        @memset(forward, null);

        const node = try sl.allocator.create(SkipNode);
        node.* = .{
            .value = value,
            .forward = forward,
            .level = level,
        };

        // Link node
        for (0..level + 1) |i| {
            node.forward[i] = update[i].forward[i];
            update[i].forward[i] = node;
        }
    }

    /// Check if value exists
    pub fn search(sl: *const SkipList, value: i64) bool {
        var current = sl.head;

        var i: isize = @intCast(sl.max_level);
        while (i >= 0) : (i -= 1) {
            const idx = @as(usize, @intCast(i));

            while (current.forward[idx].?.value < value) {
                current = current.forward[idx].?;
            }

            current = current.forward[idx] orelse return false;
            if (current.value == value) return true;
        }

        return false;
    }

    /// Remove value
    pub fn delete(sl: *SkipList, value: i64) !bool {
        var update = try sl.allocator.alloc([]?SkipNode, sl.max_level);
        defer sl.allocator.free(update);

        var current = sl.head;
        var found = false;

        var i: isize = @intCast(sl.max_level);
        while (i >= 0) : (i -= 1) {
            const idx = @as(usize, @intCast(i));

            while (current.forward[idx].?.value < value) {
                current = current.forward[idx].?;
            }

            if (current.forward[idx].?value == value) {
                found = true;
                update[idx] = current;
                current.forward[idx] = current.forward[idx].?.forward[idx];
            } else {
                update[idx] = current;
            }
        }

        return found;
    }

    /// Free list
    pub fn deinit(sl: *SkipList) void {
        var current = sl.head;

        // Free all nodes (simplified - just head)
        sl.head.deinit(sl.allocator);
    }
};

test "skiplist init" {
    var sl = try SkipList.init(std.testing.allocator, 4);
    defer sl.deinit();

    try std.testing.expect(sl.head != null);
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
