//! tri/skiplist — Probabilistic skip list
//! TTT Dogfood v0.2 Stage 194

const std = @import("std");

pub const SkipNode = struct {
    value: i64,
    forward: []?*SkipNode,
    level: usize,
};

pub const SkipList = struct {
    head: *SkipNode,
    max_level: usize,
    p: f64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !SkipList {
        const head = try allocator.create(SkipNode);
        head.* = .{
            .value = 0,
            .forward = try allocator.alloc(?*SkipNode, 16),
            .level = 15,
        };
        @memset(head.forward, null);
        return .{
            .head = head,
            .max_level = 16,
            .p = 0.5,
            .allocator = allocator,
        };
    }

    fn randomLevel(list: *const SkipList) usize {
        _ = list;
        var level: usize = 0;
        var rng = std.rand.DefaultPrng.init(0);
        while (level < 15 and rng.random().float(f64) < 0.5) {
            level += 1;
        }
        return level;
    }

    pub fn insert(list: *SkipList, value: i64) !void {
        const update = try list.allocator.alloc(?*SkipNode, list.max_level);
        defer list.allocator.free(update);

        var curr = list.head;
        var i: isize = @intCast(list.head.level);
        while (i >= 0) : (i -= 1) {
            const idx = @as(usize, @intCast(i));
            while (curr.forward[idx]) |n| {
                if (n.value >= value) break;
                curr = n;
            }
            update[idx] = curr;
        }

        const level = list.randomLevel();
        const node = try list.allocator.create(SkipNode);
        node.* = .{
            .value = value,
            .forward = try list.allocator.alloc(?*SkipNode, level + 1),
            .level = level,
        };
        @memset(node.forward, null);

        for (0..level + 1) |j| {
            node.forward[j] = update[j].?.forward[j];
            update[j].?.forward[j] = node;
        }
    }

    pub fn contains(list: *const SkipList, value: i64) bool {
        var curr = list.head;
        var i: isize = @intCast(list.head.level);
        while (i >= 0) : (i -= 1) {
            const idx = @as(usize, @intCast(i));
            while (curr.forward[idx]) |n| {
                if (n.value >= value) break;
                curr = n;
            }
            if (curr.forward[idx]) |n| {
                if (n.value == value) return true;
            }
        }
        return false;
    }

    pub fn deinit(list: *SkipList) void {
        var curr = list.head;
        while (curr != null) {
            const next = if (curr.forward.len > 0) curr.forward[0] else null;
            list.allocator.free(curr.forward);
            list.allocator.destroy(curr);
            curr = next;
        }
    }
};

test "skiplist init" {
    var list = try SkipList.init(std.testing.allocator);
    defer list.deinit();
    try std.testing.expect(list.head.forward.len > 0);
}

test "skiplist insert search" {
    var list = try SkipList.init(std.testing.allocator);
    defer list.deinit();

    try list.insert(5);
    try list.insert(10);
    try list.insert(3);

    try std.testing.expect(list.contains(5));
    try std.testing.expect(!list.contains(99));
}
