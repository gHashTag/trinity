// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE Tier 3.5 — HNSW Index for Fast Semantic Search
// ═══════════════════════════════════════════════════════════════════════════════
//
// Hierarchical Navigable Small World graph for approximate nearest neighbor
// O(log N) search complexity for large-scale semantic code search
// φ² + 1/φ² = 3 | TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const DEFAULT_M: usize = 16;
pub const DEFAULT_EF_CONSTRUCTION: usize = 200;
pub const DEFAULT_EF_SEARCH: usize = 50;

pub const HNSWConfig = struct {
    dim: usize = 384,
    M: usize = DEFAULT_M,
    ef_construction: usize = DEFAULT_EF_CONSTRUCTION,
    ef_search: usize = DEFAULT_EF_SEARCH,
    ml: f64 = 1.0 / @log(@as(f64, @floatFromInt(DEFAULT_M))),
};

pub const SearchResult = struct {
    node_id: usize,
    symbol_id: []const u8,
    similarity: f32,
};

/// HNSW Node with connections at different layers
const HNSWNode = struct {
    id: usize,
    symbol_id: []const u8,
    vector: []f32,
    // Each layer has a list of neighbor node IDs
    layers: std.ArrayList(std.ArrayList(usize)),
    level: usize,

    fn deinit(self: *HNSWNode, allocator: std.mem.Allocator) void {
        for (self.layers.items) |*layer| {
            layer.deinit(allocator);
        }
        self.layers.deinit(allocator);
    }
};

/// Candidate for priority queue during search
const Candidate = struct {
    node_id: usize,
    distance: f32,

    fn lessThan(_: void, a: Candidate, b: Candidate) bool {
        return a.distance < b.distance; // Min-heap by distance
    }
};

pub const HNSWIndex = struct {
    config: HNSWConfig,
    // All nodes indexed by ID
    nodes: std.ArrayList(*HNSWNode),
    // Entry point for search (top level node)
    entry_point: ?*HNSWNode,
    // Max level in the graph
    max_level: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: HNSWConfig) !HNSWIndex {
        return .{
            .config = config,
            .nodes = std.ArrayList(*HNSWNode).empty,
            .entry_point = null,
            .max_level = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *HNSWIndex) void {
        for (self.nodes.items) |node| {
            self.allocator.free(node.vector);
            self.allocator.free(node.symbol_id);
            node.deinit(self.allocator);
            self.allocator.destroy(node);
        }
        self.nodes.deinit(self.allocator);
    }

    fn distance(a: []const f32, b: []const f32) f32 {
        std.debug.assert(a.len == b.len);
        var sum: f32 = 0.0;
        for (0..a.len) |i| {
            const diff = a[i] - b[i];
            sum += diff * diff;
        }
        return @sqrt(sum);
    }

    fn getRandomLevel(self: *const HNSWIndex) usize {
        const level = @as(usize, @intFromFloat(@floor(-@log(std.crypto.random.float(f64)) * self.config.ml)));
        return level;
    }

    /// Insert a vector into the HNSW index
    pub fn insert(self: *HNSWIndex, symbol_id: []const u8, vector: []const f32) !void {
        // Create new node
        const node_id = self.nodes.items.len;
        const level = self.getRandomLevel();
        const new_node = try self.allocator.create(HNSWNode);
        new_node.* = .{
            .id = node_id,
            .symbol_id = try self.allocator.dupe(u8, symbol_id),
            .vector = try self.allocator.alloc(f32, vector.len),
            .layers = std.ArrayList(std.ArrayList(usize)).empty,
            .level = level,
        };
        @memcpy(new_node.vector, vector);

        // Initialize layer lists
        try new_node.layers.ensureTotalCapacity(self.allocator, level + 1);
        for (0..level + 1) |_| {
            try new_node.layers.append(self.allocator, std.ArrayList(usize).empty);
        }

        try self.nodes.append(self.allocator, new_node);

        // Find entry point - first node becomes entry immediately
        var curr = self.entry_point orelse {
            // First node - set as entry point and done
            self.entry_point = new_node;
            self.max_level = level;
            return;
        };

        // Set as entry point if highest level
        if (level > self.max_level) {
            self.entry_point = new_node;
            self.max_level = level;
        }

        // Top layer: greedy search
        var top_level = self.max_level;
        while (top_level > level) : (top_level -= 1) {
            curr = self.searchLayerOne(curr, new_node.vector, 1, top_level);
        }

        // Insert at each level
        var layer_data = std.ArrayList(usize).empty;
        defer {
            layer_data.deinit(self.allocator);
        }

        var lc: usize = level + 1;
        while (lc > 0) : (lc -= 1) {
            const l = lc - 1;

            // Find neighbors at this level
            var candidates = try self.searchLayer(curr, new_node.vector, self.config.ef_construction, l);
            defer {
                candidates.deinit(self.allocator);
            }

            // Select M neighbors
            var neighbors = try self.selectNeighbors(candidates, self.config.M);
            defer {
                for (neighbors.items) |n_id| {
                    self.allocator.free(n_id);
                }
                neighbors.deinit(self.allocator);
            }

            // Add connections
            for (neighbors.items) |neighbor_id| {
                if (neighbor_id.len > 0) {
                    const nid = std.fmt.parseInt(usize, neighbor_id, 10) catch 0;
                    try new_node.layers.items[l].append(self.allocator, nid);

                    // Add backward connection (bidirectional)
                    const neighbor_node = self.nodes.items[nid];
                    if (neighbor_node.layers.items.len > l) {
                        try neighbor_node.layers.items[l].append(self.allocator, node_id);
                    }
                }
            }

            // Update curr for next level
            if (candidates.items.len > 0) {
                curr = self.nodes.items[candidates.items[0].node_id];
            }
        }
    }

    fn searchLayerOne(self: *HNSWIndex, entry: *HNSWNode, query: []const f32, _: usize, level: usize) *HNSWNode {
        var curr = entry;
        var min_dist = distance(query, curr.vector);

        var visited = std.AutoHashMap(usize, void).init(self.allocator);
        defer visited.deinit();
        visited.put(curr.id, {}) catch |err| {
            std.log.warn("hnsw: visited set insert failed: {}", .{err});
        };

        var changed = true;
        while (changed) {
            changed = false;

            // Check neighbors
            if (level < curr.layers.items.len) {
                for (curr.layers.items[level].items) |neighbor_id| {
                    if (visited.contains(neighbor_id)) continue;
                    visited.put(neighbor_id, {}) catch |err| {
                        std.log.warn("hnsw: visited set insert failed: {}", .{err});
                    };

                    const neighbor = self.nodes.items[neighbor_id];
                    const dist = distance(query, neighbor.vector);

                    if (dist < min_dist) {
                        min_dist = dist;
                        curr = neighbor;
                        changed = true;
                    }
                }
            }
        }

        return curr;
    }

    fn searchLayer(self: *HNSWIndex, entry: *HNSWNode, query: []const f32, ef: usize, level: usize) !std.ArrayList(Candidate) {
        var candidates = std.ArrayList(Candidate).empty;
        var visited = std.AutoHashMap(usize, void).init(self.allocator);
        defer visited.deinit();

        const entry_dist = distance(query, entry.vector);
        try candidates.append(self.allocator, .{
            .node_id = entry.id,
            .distance = entry_dist,
        });
        visited.put(entry.id, {}) catch |err| {
            std.log.warn("hnsw: visited set insert failed: {}", .{err});
        };

        var w = std.ArrayList(Candidate).empty;
        try w.append(self.allocator, .{
            .node_id = entry.id,
            .distance = entry_dist,
        });

        while (candidates.items.len > 0) {
            // Extract closest
            std.sort.insertion(Candidate, candidates.items, {}, Candidate.lessThan);
            const curr = candidates.orderedRemove(0);

            // Check if we can stop
            if (w.items.len >= ef and curr.distance > w.items[w.items.len - 1].distance) {
                break;
            }

            // Explore neighbors
            if (curr.node_id < self.nodes.items.len) {
                const curr_node = self.nodes.items[curr.node_id];
                if (level < curr_node.layers.items.len) {
                    for (curr_node.layers.items[level].items) |neighbor_id| {
                        if (visited.contains(neighbor_id)) continue;
                        visited.put(neighbor_id, {}) catch |err| {
                            std.log.warn("hnsw: visited set insert failed: {}", .{err});
                        };

                        const neighbor = self.nodes.items[neighbor_id];
                        const dist = distance(query, neighbor.vector);

                        if (w.items.len < ef or dist < w.items[w.items.len - 1].distance) {
                            try candidates.append(self.allocator, .{
                                .node_id = neighbor_id,
                                .distance = dist,
                            });

                            try w.append(self.allocator, .{
                                .node_id = neighbor_id,
                                .distance = dist,
                            });

                            if (w.items.len > ef) {
                                std.sort.insertion(Candidate, w.items, {}, Candidate.lessThan);
                                _ = w.orderedRemove(w.items.len - 1);
                            }
                        }
                    }
                }
            }
        }

        candidates.deinit(self.allocator);
        return w;
    }

    fn selectNeighbors(self: *HNSWIndex, candidates: std.ArrayList(Candidate), m: usize) !std.ArrayList([]const u8) {
        var result = std.ArrayList([]const u8).empty;

        const k = @min(m, candidates.items.len);
        for (0..k) |i| {
            const node_id = candidates.items[i].node_id;
            const id_str = try std.fmt.allocPrint(self.allocator, "{d}", .{node_id});
            try result.append(self.allocator, id_str);
        }

        return result;
    }

    pub fn search(self: *HNSWIndex, query: []const f32, k: usize, result_allocator: std.mem.Allocator) ![]SearchResult {
        if (self.nodes.items.len == 0) return &.{};

        const entry = self.entry_point orelse return &.{};

        // Search from top down
        var curr = entry;
        var level = self.max_level;

        // Greedy descent
        while (level > 0) : (level -= 1) {
            curr = self.searchLayerOne(curr, query, 1, level);
        }

        // Search at bottom level
        var candidates = try self.searchLayer(curr, query, @max(k, self.config.ef_search), 0);

        // Convert to results
        const result_count = @min(k, candidates.items.len);
        const results = try result_allocator.alloc(SearchResult, result_count);

        for (0..result_count) |i| {
            const c = candidates.items[i];
            const node = self.nodes.items[c.node_id];
            const dist = c.distance;

            // Convert distance to similarity (1/(1+d))
            results[i] = .{
                .node_id = c.node_id,
                .symbol_id = try result_allocator.dupe(u8, node.symbol_id),
                .similarity = 1.0 / (1.0 + dist),
            };
        }

        // Cleanup candidates
        candidates.deinit(self.allocator);

        return results;
    }

    pub fn size(self: *const HNSWIndex) usize {
        return self.nodes.items.len;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "hnsw.1: HNSWIndex init and deinit" {
    const allocator = std.testing.allocator;
    var index = try HNSWIndex.init(allocator, .{});
    defer index.deinit();
    try std.testing.expectEqual(@as(usize, 0), index.size());
}

test "hnsw.2: Insert single node" {
    const allocator = std.testing.allocator;
    var index = try HNSWIndex.init(allocator, .{});
    defer index.deinit();

    const vector = [_]f32{0.1} ** 64;
    try index.insert("test_symbol", &vector);
    try std.testing.expectEqual(@as(usize, 1), index.size());
}

test "hnsw.3: Insert and search" {
    const allocator = std.testing.allocator;
    var index = try HNSWIndex.init(allocator, .{});
    defer index.deinit();

    const v1 = [_]f32{1.0} ** 64;
    const v2 = [_]f32{0.0} ** 64;

    try index.insert("one", &v1);
    try index.insert("two", &v2);

    const query = [_]f32{0.9} ** 64;
    const results = try index.search(&query, 2, allocator);
    defer {
        for (results) |*r| {
            allocator.free(r.symbol_id);
        }
        allocator.free(results);
    }

    try std.testing.expect(results.len >= 1);
    try std.testing.expectEqualStrings("one", results[0].symbol_id);
}

test "hnsw.4: Multiple inserts" {
    const allocator = std.testing.allocator;
    var index = try HNSWIndex.init(allocator, .{});
    defer index.deinit();

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        var vec = [_]f32{0.0} ** 64;
        vec[i % 64] = 1.0;
        const name = try std.fmt.allocPrint(allocator, "symbol_{d}", .{i});
        try index.insert(name, &vec);
        allocator.free(name);
    }

    try std.testing.expectEqual(@as(usize, 10), index.size());
}

test "hnsw.5: Distance function" {
    const a = [_]f32{ 0.0, 0.0 };
    const b = [_]f32{ 3.0, 4.0 };
    const dist = HNSWIndex.distance(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), dist, 0.01);
}
