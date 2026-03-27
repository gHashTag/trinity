//! tri/disjoint_set — Union-Find data structure
//! Auto-generated from specs/tri/tri_disjoint_set.tri
//! TTT Dogfood v0.2 Stage 146

const std = @import("std");

/// Disjoint Set Union (Union-Find)
pub const DisjointSet = struct {
    parent: []usize,
    rank: []usize,
    count: usize,
    allocator: std.mem.Allocator,

    /// Create N disjoint singletons
    pub fn init(size: usize, allocator: std.mem.Allocator) !DisjointSet {
        const parent = try allocator.alloc(usize, size);
        const rank = try allocator.alloc(usize, size);

        for (0..size) |i| {
            parent[i] = i;
            rank[i] = 0;
        }

        return .{
            .parent = parent,
            .rank = rank,
            .count = size,
            .allocator = allocator,
        };
    }

    /// Free resources
    pub fn deinit(self: *DisjointSet) void {
        self.allocator.free(self.parent);
        self.allocator.free(self.rank);
    }

    /// Find root with path compression
    pub fn find(self: *DisjointSet, x: usize) usize {
        if (x >= self.parent.len) return x;

        if (self.parent[x] != x) {
            self.parent[x] = self.find(self.parent[x]);
        }

        return self.parent[x];
    }

    /// Internal find with explicit self parameter
    fn findInner(self: *DisjointSet, x: usize) usize {
        if (x >= self.parent.len) return x;

        if (self.parent[x] != x) {
            self.parent[x] = self.findInner(self.parent[x]);
        }

        return self.parent[x];
    }

    /// Merge sets containing x and y (unionSets to avoid reserved keyword)
    pub fn unionSets(self: *DisjointSet, x: usize, y: usize) void {
        const root_x = self.find(x);
        const root_y = self.find(y);

        if (root_x == root_y) return;

        // Union by rank
        if (self.rank[root_x] < self.rank[root_y]) {
            self.parent[root_x] = root_y;
        } else if (self.rank[root_x] > self.rank[root_y]) {
            self.parent[root_y] = root_x;
        } else {
            self.parent[root_y] = root_x;
            self.rank[root_x] += 1;
        }

        self.count -= 1;
    }

    /// Check if x and y in same set
    pub fn connected(self: *const DisjointSet, x: usize, y: usize) bool {
        if (x >= self.parent.len or y >= self.parent.len) return false;

        // Use const version of find
        var root_x = x;
        while (root_x != self.parent[root_x]) {
            root_x = self.parent[root_x];
        }

        var root_y = y;
        while (root_y != self.parent[root_y]) {
            root_y = self.parent[root_y];
        }

        return root_x == root_y;
    }

    /// Get number of disjoint sets
    pub fn getCount(self: *const DisjointSet) usize {
        return self.count;
    }
};

test "disjoint set init" {
    var ds = try DisjointSet.init(5, std.testing.allocator);
    defer ds.deinit();

    try std.testing.expectEqual(@as(usize, 5), ds.count);
}

test "disjoint set union find" {
    var ds = try DisjointSet.init(5, std.testing.allocator);
    defer ds.deinit();

    ds.unionSets(0, 1);
    ds.unionSets(2, 3);

    try std.testing.expect(ds.connected(0, 1));
    try std.testing.expect(ds.connected(2, 3));
    try std.testing.expect(!ds.connected(0, 2));
}

test "disjoint set path compression" {
    var ds = try DisjointSet.init(10, std.testing.allocator);
    defer ds.deinit();

    ds.unionSets(0, 1);
    ds.unionSets(1, 2);
    ds.unionSets(2, 3);

    // After path compression, find(3) should point directly to root
    const root3 = ds.find(3);
    const root0 = ds.find(0);
    try std.testing.expect(root3 == root0);
}

test "disjoint set union by rank" {
    var ds = try DisjointSet.init(10, std.testing.allocator);
    defer ds.deinit();

    // Build two trees of different heights
    ds.unionSets(0, 1);
    ds.unionSets(0, 2);

    ds.unionSets(3, 4);
    ds.unionSets(3, 5);
    ds.unionSets(3, 6);

    // Union should attach shorter tree under taller
    ds.unionSets(0, 3);

    try std.testing.expect(ds.connected(0, 6));
    // 10 elements, 6 unions = 4 remaining sets
    try std.testing.expectEqual(@as(usize, 4), ds.getCount());
}
