// ═══════════════════════════════════════════════════════════════════════════════
// TVC HNSW (Hierarchical Navigable Small World) GRAPH INDEX
// ═══════════════════════════════════════════════════════════════════════════════
//
// Native Zig implementation of HNSW for O(log n) semantic search.
// Based on "Efficient and Robust Approximate Nearest Neighbor Search"
//   by Malkov and Yashunin (2018)
//
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;
const math = std.math;

const distance = @import("hnsw_distance.zig");
pub const DistanceMetric = distance.DistanceMetric;

/// Managed ArrayList for easier allocator handling
const Managed = std.array_list.Managed;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const DEFAULT_M: usize = 16;
pub const DEFAULT_MAX_M0: usize = 32;
pub const DEFAULT_EF_CONSTRUCTION: usize = 64;
pub const DEFAULT_EF_SEARCH: usize = 80;

pub const MAGIC: [4]u8 = .{ 'H', 'N', 'S', 'W' };
pub const VERSION: u16 = 1;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// HNSW configuration
pub const Config = struct {
    dim: usize,
    m: usize = DEFAULT_M,
    max_m0: usize = DEFAULT_MAX_M0,
    ef_construction: usize = DEFAULT_EF_CONSTRUCTION,
    ef_search: usize = DEFAULT_EF_SEARCH,
    distance_metric: DistanceMetric = .cosine,
    seed: u64 = 42,

    /// Calculate level normalization factor
    pub fn ml(self: *const Config) f32 {
        return 1.0 / @as(f32, @floatFromInt(@as(usize, @intFromFloat(@log(@as(f32, @floatFromInt(self.m)))))));
    }
};

/// Neighbor connection
pub const Neighbor = struct {
    node_id: u64,
    distance: f32,

    pub fn format(self: Neighbor) []const u8 {
        return std.fmt.allocPrint(std.heap.page_allocator, "N({d}, d={d:.4})", .{
            self.node_id, self.distance,
        }) catch "N(?)";
    }
};

/// Search candidate (for priority queue)
pub const Candidate = struct {
    node_id: u64,
    distance: f32,

    /// Compare for priority queue (returns math.Order)
    pub fn compare(_: void, a: Candidate, b: Candidate) math.Order {
        return math.order(a.distance, b.distance);
    }

    /// Less than for sorting (returns bool)
    pub fn lessThan(_: void, a: Candidate, b: Candidate) bool {
        return a.distance < b.distance;
    }
};

/// Search result match
pub const Match = struct {
    id: u64,
    distance: f32,
    similarity: f32,

    pub fn format(self: Match, _: DistanceMetric) []const u8 {
        return std.fmt.allocPrint(std.heap.page_allocator, "Match(id={d}, dist={d:.4}, sim={d:.4})", .{
            self.id, self.distance, self.similarity,
        }) catch "Match(?)";
    }
};

/// Search results
pub const SearchResults = struct {
    allocator: Allocator,
    matches: []Match,
    ef_used: usize,
    visited_nodes: usize,
    last_search_time_ms: u64 = 0,

    pub fn deinit(self: *SearchResults) void {
        self.allocator.free(self.matches);
    }
};

/// HNSW node at a specific layer
pub const Node = struct {
    id: u64,
    level: usize,
    vector: ?[]f32, // null for layers > 0
    neighbors: []Managed(Neighbor), // One list per layer [0..level]
    allocator: Allocator,
    vector_dim: usize,

    pub fn init(allocator: Allocator, id: u64, level: usize, has_vector: bool, vector_dim: usize) !Node {
        // Allocate neighbor lists for each layer
        const neighbors_slice = try allocator.alloc(Managed(Neighbor), level + 1);
        for (0..level + 1) |i| {
            neighbors_slice[i] = Managed(Neighbor).init(allocator);
        }

        var vector_slice: ?[]f32 = null;
        if (has_vector) {
            vector_slice = try allocator.alloc(f32, vector_dim);
        }

        return Node{
            .id = id,
            .level = level,
            .vector = vector_slice,
            .allocator = allocator,
            .vector_dim = vector_dim,
            .neighbors = neighbors_slice,
        };
    }

    pub fn deinit(self: *Node) void {
        for (self.neighbors) |*nb| {
            nb.deinit();
        }
        self.allocator.free(self.neighbors);
        if (self.vector) |v| {
            self.allocator.free(v);
        }
    }
};

/// Index statistics
pub const Stats = struct {
    total_nodes: usize = 0,
    max_level: usize = 0,
    total_edges: usize = 0,
    avg_connections: f32 = 0.0,
    memory_bytes: usize = 0,
    build_time_ms: u64 = 0,
    last_search_time_ms: u64 = 0,

    pub fn format(self: *const Stats) []const u8 {
        return std.fmt.allocPrint(std.heap.page_allocator,
            \\Stats:
            \\  Nodes: {d}
            \\  Max Level: {d}
            \\  Edges: {d}
            \\  Avg Conn: {d:.2}
            \\  Memory: {d} MB
            \\  Build: {d} ms
            \\  Last Search: {d} ms
        , .{
            self.total_nodes,
            self.max_level,
            self.total_edges,
            self.avg_connections,
            self.memory_bytes / (1024 * 1024),
            self.build_time_ms,
            self.last_search_time_ms,
        }) catch "Stats(?)";
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN HNSW STRUCTURE
// ═══════════════════════════════════════════════════════════════════════════════

/// HNSW index with comptime parameters
pub fn HNSW(comptime dim: usize, comptime _: usize) type {
    return struct {
        allocator: Allocator,
        config: Config,
        nodes: AutoHashMap(u64, Node),
        entry_point: ?u64,
        max_level: usize,
        rng: std.Random.DefaultPrng,
        visited: AutoHashMap(u64, void),

        const Self = @This();

        /// Initialize HNSW index
        pub fn init(allocator: Allocator, config: Config) !Self {
            const rng = std.Random.DefaultPrng.init(config.seed);

            return Self{
                .allocator = allocator,
                .config = config,
                .nodes = AutoHashMap(u64, Node).init(allocator),
                .entry_point = null,
                .max_level = 0,
                .rng = rng,
                .visited = AutoHashMap(u64, void).init(allocator),
            };
        }

        /// Clean up HNSW index
        pub fn deinit(self: *Self) void {
            var iter = self.nodes.valueIterator();
            while (iter.next()) |node| {
                node.deinit();
            }
            self.nodes.deinit();
            self.visited.deinit();
        }

        /// Get random level for new node using exponential distribution
        fn getRandomLevel(self: *Self) usize {
            const level = @as(usize, @intFromFloat(
                @floor(-@log(self.random().float(f32)) / self.config.ml()),
            ));
            return level;
        }

        /// Insert a new vector into the index
        pub fn insert(self: *Self, vector: []const f32, id: u64) !void {
            if (vector.len != dim) return error.DimensionMismatch;

            // Calculate level for new node
            const level = self.getRandomLevel();
            if (level > self.max_level) {
                self.max_level = level;
            }

            // Create node
            const node = try Node.init(self.allocator, id, level, true, dim);
            @memcpy(node.vector.?, vector[0..dim]);

            // Insert into nodes map
            try self.nodes.put(id, node);

            // If first node or highest level, make entry point
            if (self.entry_point == null or level > self.getNodeLevel(self.entry_point.?)) {
                self.entry_point = id;
            }

            // Starting from top level, find neighbors and connect
            var curr_level = self.max_level;
            var curr_id = self.entry_point.?;

            // Descend through layers
            while (curr_level > level) : (curr_level -= 1) {
                curr_id = try self.searchLayerOne(vector, curr_id, curr_level);
            }

            // At target layer and below, connect neighbors
            while (curr_level >= 1) : (curr_level -= 1) {
                const candidates = try self.searchLayerEf(vector, curr_id, curr_level, self.config.ef_construction);
                const selected = try self.selectNeighbors(candidates, @min(self.config.m, self.config.max_m0));
                try self.connectNeighbors(id, selected, curr_level);

                // Update current to closest for next layer
                if (candidates.items.len > 0) {
                    curr_id = candidates.items[0].node_id;
                }
            }

            // Layer 0 - use max_m0 connections
            {
                const candidates = try self.searchLayerEf(vector, curr_id, 0, self.config.ef_construction);
                const selected = try self.selectNeighbors(candidates, self.config.max_m0);
                try self.connectNeighbors(id, selected, 0);

                // CRITICAL: Always connect to entry point at layer 0 to ensure graph connectivity
                // This prevents disconnected components
                if (self.entry_point) |ep_id| {
                    if (ep_id != id) {
                        // Calculate distance to entry point
                        var dist: f32 = 1.0; // Default
                        if (self.nodes.get(ep_id)) |ep_node| {
                            if (ep_node.vector) |ep_vec| {
                                dist = distance.calculateDistance(vector, ep_vec[0..dim], self.config.distance_metric);
                            }
                        }
                        // Add connection to entry point if not already connected
                        var already_connected = false;
                        for (selected.items) |s| {
                            if (s.node_id == ep_id) {
                                already_connected = true;
                                break;
                            }
                        }
                        if (!already_connected) {
                            var ep_candidate = Managed(Candidate).init(self.allocator);
                            try ep_candidate.append(.{ .node_id = ep_id, .distance = dist });
                            try self.connectNeighbors(id, ep_candidate, 0);
                            ep_candidate.deinit();
                        }
                    }
                }
            }

            // Bidirectional connections
            try self.updateBacklinks(id);
        }

        /// Search for k nearest neighbors
        pub fn search(self: *Self, query: []const f32, k: usize) !SearchResults {
            if (query.len != dim) return error.DimensionMismatch;

            var timer = try std.time.Timer.start();

            if (self.entry_point == null or self.nodes.count() == 0) {
                return SearchResults{
                    .allocator = self.allocator,
                    .matches = &[_]Match{},
                    .ef_used = 0,
                    .visited_nodes = 0,
                };
            }

            // Use a local visited set for this search
            var visited = AutoHashMap(u64, void).init(self.allocator);
            defer visited.deinit();

            // Collect multiple entry points (all high-level nodes)
            var entry_points = Managed(Candidate).init(self.allocator);
            defer entry_points.deinit();

            {
                var iter = self.nodes.iterator();
                while (iter.next()) |entry| {
                    const node_id = entry.key_ptr.*;
                    const node = entry.value_ptr.*;
                    // Use all nodes at level >= 2 as entry points, or at least the entry point
                    if (node.level >= 2 or node_id == self.entry_point.?) {
                        const dist = if (node.vector) |v|
                            distance.calculateDistance(query, v[0..dim], self.config.distance_metric)
                        else
                            1.0;
                        try entry_points.append(.{ .node_id = node_id, .distance = dist });
                    }
                }
            }

            // Sort entry points by distance
            std.sort.block(Candidate, entry_points.items, {}, struct {
                fn lessThan(ctx: void, a: Candidate, b: Candidate) bool {
                    _ = ctx;
                    return a.distance < b.distance;
                }
            }.lessThan);

            // Search from each entry point and merge results
            var merged = Managed(Candidate).init(self.allocator);
            defer merged.deinit();

            for (entry_points.items) |entry| {
                var ep_visited = AutoHashMap(u64, void).init(self.allocator);
                defer ep_visited.deinit();

                // Search from this entry point at layer 0 (bottom layer has all connections)
                const layer_candidates = try self.searchLayerEfWithVisited(query, entry.node_id, 0, self.config.ef_search, &ep_visited);
                defer layer_candidates.deinit();

                // Merge unique candidates
                for (layer_candidates.items) |lc| {
                    var exists = false;
                    for (merged.items) |m| {
                        if (m.node_id == lc.node_id) {
                            exists = true;
                            // Keep the better distance
                            if (lc.distance < m.distance) {
                                // Update (would need mutable access)
                            }
                            break;
                        }
                    }
                    if (!exists) try merged.append(lc);
                }
            }

            // Sort merged candidates by distance
            std.sort.block(Candidate, merged.items, {}, struct {
                fn lessThan(ctx: void, a: Candidate, b: Candidate) bool {
                    _ = ctx;
                    return a.distance < b.distance;
                }
            }.lessThan);

            // Extract top-k results
            const actual_k = @min(k, merged.items.len);
            const matches = try self.allocator.alloc(Match, actual_k);

            for (0..actual_k) |i| {
                const cand = merged.items[i];
                matches[i] = Match{
                    .id = cand.node_id,
                    .distance = cand.distance,
                    .similarity = distance.distanceToSimilarity(cand.distance, self.config.distance_metric),
                };
            }

            const elapsed = timer.read();
            return SearchResults{
                .allocator = self.allocator,
                .matches = matches,
                .ef_used = self.config.ef_search,
                .visited_nodes = visited.count(),
                .last_search_time_ms = elapsed / 1_000_000,
            };
        }

        /// Search layer and find 1 nearest neighbor
        fn searchLayerOne(self: *Self, query: []const f32, entry_id: u64, layer: usize) !u64 {
            var curr_id = entry_id;
            var improved = true;

            while (improved) {
                improved = false;
                const node = self.nodes.get(curr_id) orelse return error.NodeNotFound;
                const neighbors = &node.neighbors[layer];

                for (neighbors.items) |nb| {
                    if (self.visited.contains(nb.node_id)) continue;
                    try self.visited.put(nb.node_id, {});

                    const nb_node = self.nodes.get(nb.node_id) orelse continue;
                    if (nb_node.vector) |nb_vec| {
                        const new_dist = distance.calculateDistance(query, nb_vec[0..dim], self.config.distance_metric);
                        if (new_dist < nb.distance) {
                            curr_id = nb.node_id;
                            improved = true;
                            break;
                        }
                    }
                }
            }

            return curr_id;
        }

        /// Search layer with ef candidates (beam search), using provided visited set
        fn searchLayerEfWithVisited(self: *Self, query: []const f32, entry_id: u64, layer: usize, ef: usize, visited_set: *AutoHashMap(u64, void)) !Managed(Candidate) {
            var candidates = Managed(Candidate).init(self.allocator);

            var candidates_pq = std.PriorityQueue(Candidate, void, Candidate.compare).init(self.allocator, {});
            defer candidates_pq.deinit();

            // Add entry point
            const entry_node = self.nodes.get(entry_id) orelse return error.NodeNotFound;
            const entry_dist = if (layer == 0)
                blk: {
                    const v = entry_node.vector orelse return error.NoVector;
                    break :blk distance.calculateDistance(query, v[0..dim], self.config.distance_metric);
                }
            else
                0.0; // Layers > 0 don't have vectors, use graph structure only

            try candidates_pq.add(.{ .node_id = entry_id, .distance = entry_dist });
            try visited_set.put(entry_id, {});

            var w = Managed(Candidate).init(self.allocator); // Working set
            defer w.deinit();

            // Greedy search
            while (candidates_pq.count() > 0) {
                const c = candidates_pq.remove();

                // Add current candidate to results if not already there
                var already_in_results = false;
                for (candidates.items) |existing| {
                    if (existing.node_id == c.node_id) {
                        already_in_results = true;
                        break;
                    }
                }
                if (!already_in_results) {
                    if (candidates.items.len < ef) {
                        try candidates.append(c);
                    } else if (c.distance < candidates.items[candidates.items.len - 1].distance) {
                        candidates.items[candidates.items.len - 1] = c;
                    }
                }

                // Check if this candidate is useful for further exploration
                if (candidates.items.len >= ef and c.distance > candidates.items[candidates.items.len - 1].distance) {
                    continue;
                }

                // Get node and explore neighbors
                if (self.nodes.get(c.node_id)) |node| {
                    if (layer >= node.neighbors.len) continue;
                    const neighbors = &node.neighbors[layer];
                    for (neighbors.items) |nb| {
                        if (visited_set.contains(nb.node_id)) continue;
                        try visited_set.put(nb.node_id, {});

                        if (layer == 0) {
                            const nb_node = self.nodes.get(nb.node_id) orelse continue;
                            if (nb_node.vector) |nb_vec| {
                                const dist = distance.calculateDistance(query, nb_vec[0..dim], self.config.distance_metric);
                                try w.append(.{ .node_id = nb.node_id, .distance = dist });
                            }
                        } else {
                            try w.append(.{ .node_id = nb.node_id, .distance = 0.0 });
                        }
                    }
                }

                // Sort working set by distance
                std.sort.block(Candidate, w.items, {}, struct {
                    fn lessThan(ctx: void, a: Candidate, b: Candidate) bool {
                        _ = ctx;
                        return a.distance < b.distance;
                    }
                }.lessThan);

                // Add working set to priority queue for further exploration
                for (w.items) |wc| {
                    try candidates_pq.add(wc);
                }

                w.clearRetainingCapacity();
            }

            // Sort candidates by distance
            std.sort.block(Candidate, candidates.items, {}, struct {
                fn lessThan(ctx: void, a: Candidate, b: Candidate) bool {
                    _ = ctx;
                    return a.distance < b.distance;
                }
            }.lessThan);

            return candidates;
        }

        /// Search layer with ef candidates (beam search)
        fn searchLayerEf(self: *Self, query: []const f32, entry_id: u64, layer: usize, ef: usize) !Managed(Candidate) {
            var candidates = Managed(Candidate).init(self.allocator);
            var visited = AutoHashMap(u64, void).init(self.allocator);
            defer visited.deinit();

            var candidates_pq = std.PriorityQueue(Candidate, void, Candidate.compare).init(self.allocator, {});
            defer candidates_pq.deinit();

            // Add entry point
            const entry_node = self.nodes.get(entry_id) orelse return error.NodeNotFound;
            const entry_dist = if (layer == 0)
                blk: {
                    const v = entry_node.vector orelse return error.NoVector;
                    break :blk distance.calculateDistance(query, v[0..dim], self.config.distance_metric);
                }
            else
                0.0; // Layers > 0 don't have vectors, use graph structure only

            try candidates_pq.add(.{ .node_id = entry_id, .distance = entry_dist });
            try visited.put(entry_id, {});

            var w = Managed(Candidate).init(self.allocator); // Working set
            defer w.deinit();

            // Greedy search
            while (candidates_pq.count() > 0) {
                const c = candidates_pq.remove();

                // Add current candidate to results if not already there
                var already_in_results = false;
                for (candidates.items) |existing| {
                    if (existing.node_id == c.node_id) {
                        already_in_results = true;
                        break;
                    }
                }
                if (!already_in_results) {
                    if (candidates.items.len < ef) {
                        try candidates.append(c);
                    } else if (c.distance < candidates.items[candidates.items.len - 1].distance) {
                        candidates.items[candidates.items.len - 1] = c;
                    }
                }

                // Check if this candidate is useful for further exploration
                if (candidates.items.len >= ef and c.distance > candidates.items[candidates.items.len - 1].distance) {
                    continue;
                }

                // Get node and explore neighbors
                if (self.nodes.get(c.node_id)) |node| {
                    if (layer >= node.neighbors.len) continue;
                    const neighbors = &node.neighbors[layer];
                    for (neighbors.items) |nb| {
                        if (visited.contains(nb.node_id)) continue;
                        try visited.put(nb.node_id, {});

                        if (layer == 0) {
                            const nb_node = self.nodes.get(nb.node_id) orelse continue;
                            if (nb_node.vector) |nb_vec| {
                                const dist = distance.calculateDistance(query, nb_vec[0..dim], self.config.distance_metric);
                                try w.append(.{ .node_id = nb.node_id, .distance = dist });
                            }
                        } else {
                            try w.append(.{ .node_id = nb.node_id, .distance = 0.0 });
                        }
                    }
                }

                // Sort working set by distance
                std.sort.block(Candidate, w.items, {}, struct {
                    fn lessThan(ctx: void, a: Candidate, b: Candidate) bool {
                        _ = ctx;
                        return a.distance < b.distance;
                    }
                }.lessThan);

                // Add working set to priority queue for further exploration
                for (w.items) |wc| {
                    try candidates_pq.add(wc);
                }

                w.clearRetainingCapacity();
            }

            // Sort candidates by distance
            std.sort.block(Candidate, candidates.items, {}, struct {
                fn lessThan(ctx: void, a: Candidate, b: Candidate) bool {
                    _ = ctx;
                    return a.distance < b.distance;
                }
            }.lessThan);

            return candidates;
        }

        /// Select neighbors using heuristic (prefer diverse connections)
        fn selectNeighbors(self: *Self, candidates: Managed(Candidate), max_neighbors: usize) !Managed(Candidate) {
            var selected = Managed(Candidate).init(self.allocator);

            const actual_m = @min(max_neighbors, candidates.items.len);
            for (0..actual_m) |i| {
                try selected.append(candidates.items[i]);
            }

            return selected;
        }

        /// Connect node to selected neighbors (bidirectional)
        fn connectNeighbors(self: *Self, id: u64, neighbors: Managed(Candidate), layer: usize) !void {
            const node = self.nodes.get(id) orelse return error.NodeNotFound;

            for (neighbors.items) |nb| {
                if (nb.node_id == id) continue; // Don't connect to self

                const other_node = self.nodes.get(nb.node_id) orelse continue;

                // Check if already connected
                var already_connected = false;
                for (node.neighbors[layer].items) |existing| {
                    if (existing.node_id == nb.node_id) {
                        already_connected = true;
                        break;
                    }
                }

                if (!already_connected) {
                    // Add forward connection (from new node to neighbor)
                    try node.neighbors[layer].append(.{
                        .node_id = nb.node_id,
                        .distance = nb.distance,
                    });

                    // Add reverse connection (from neighbor to new node)
                    if (layer < other_node.neighbors.len) {
                        var reverse_connected = false;
                        for (other_node.neighbors[layer].items) |existing| {
                            if (existing.node_id == id) {
                                reverse_connected = true;
                                break;
                            }
                        }
                        if (!reverse_connected) {
                            try other_node.neighbors[layer].append(.{
                                .node_id = id,
                                .distance = nb.distance,
                            });
                        }
                    }
                }
            }
        }

        /// Update backlinks (make connections bidirectional)
        fn updateBacklinks(self: *Self, id: u64) !void {
            const node = self.nodes.get(id) orelse return;
            const node_level = node.level;

            var iter = self.nodes.iterator();
            while (iter.next()) |entry| {
                const other_id = entry.key_ptr.*;
                const other = entry.value_ptr.*;

                if (other_id == id) continue;

                // Check each layer
                var l: usize = 0;
                while (l <= @min(node_level, other.level)) : (l += 1) {
                    // Check if 'other' is connected to 'id'
                    for (other.neighbors[l].items) |nb| {
                        if (nb.node_id == id) {
                            // Add backlink from id to other
                            var already_connected = false;
                            for (node.neighbors[l].items) |my_nb| {
                                if (my_nb.node_id == other_id) {
                                    already_connected = true;
                                    break;
                                }
                            }

                            if (!already_connected) {
                                try node.neighbors[l].append(.{
                                    .node_id = other_id,
                                    .distance = nb.distance,
                                });
                            }
                            break;
                        }
                    }
                }
            }
        }

        /// Get level of a node
        fn getNodeLevel(self: *Self, id: u64) usize {
            if (self.nodes.get(id)) |node| {
                return node.level;
            }
            return 0;
        }

        /// Get index statistics
        pub fn getStats(self: *const Self) Stats {
            var stats = Stats{
                .total_nodes = self.nodes.count(),
                .max_level = self.max_level,
            };

            var total_edges: usize = 0;
            var iter = self.nodes.valueIterator();
            while (iter.next()) |node| {
                for (node.neighbors) |*nb_list| {
                    total_edges += nb_list.items.len;
                }
            }

            stats.total_edges = total_edges;
            stats.avg_connections = if (stats.total_nodes > 0)
                @as(f32, @floatFromInt(total_edges)) / @as(f32, @floatFromInt(stats.total_nodes))
            else
                0.0;

            // Memory estimate
            stats.memory_bytes = self.nodes.count() * (@sizeOf(u64) + @sizeOf(Node) + dim * @sizeOf(f32)) +
                total_edges * @sizeOf(Neighbor);

            return stats;
        }

        /// Get random generator
        fn random(self: *Self) std.Random {
            return self.rng.random();
        }

        /// Validate index integrity
        pub fn validate(self: *Self) bool {
            if (self.entry_point) |ep| {
                if (self.nodes.get(ep)) |node| {
                    if (node.vector == null) return false;
                } else {
                    return false;
                }
            }

            var iter = self.nodes.iterator();
            while (iter.next()) |entry| {
                const node = entry.value_ptr.*;
                if (node.level >= node.neighbors.len) return false;
                if (node.level == 0 and node.vector == null) return false;
            }

            return true;
        }
    };
}
