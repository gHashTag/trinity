// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN REGISTRY - HNSW-Indexed Pattern Storage for VIBEE
// ═══════════════════════════════════════════════════════════════════════════════
// High-performance pattern storage with semantic search via HNSW indexing
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;

const pattern_engine = @import("pattern_engine.zig");
pub const Pattern = pattern_engine.Pattern;

// ═══════════════════════════════════════════════════════════════════════════════
// HNSW INDEX (Simplified Implementation)
// ═══════════════════════════════════════════════════════════════════════════════
//
// NOTE: This is a simplified HNSW-like index. For production, integrate with
// the actual HNSW implementation in the embeddings subsystem.
//

/// Vector embedding for semantic search
pub const Embedding = struct {
    data: []f32,
    dimension: usize,

    pub fn init(allocator: Allocator, dimension: usize) !Embedding {
        const data = try allocator.alloc(f32, dimension);
        return Embedding{
            .data = data,
            .dimension = dimension,
        };
    }

    pub fn deinit(self: *Embedding, allocator: Allocator) void {
        allocator.free(self.data);
    }

    /// Compute cosine similarity with another embedding
    pub fn cosineSimilarity(self: *const Embedding, other: *const Embedding) !f32 {
        if (self.dimension != other.dimension) return error.DimensionMismatch;

        var dot_product: f32 = 0.0;
        var norm_a: f32 = 0.0;
        var norm_b: f32 = 0.0;

        for (0..self.dimension) |i| {
            dot_product += self.data[i] * other.data[i];
            norm_a += self.data[i] * self.data[i];
            norm_b += other.data[i] * other.data[i];
        }

        const denominator = @sqrt(norm_a) * @sqrt(norm_b);
        if (denominator < 1e-6) return 0.0;

        return dot_product / denominator;
    }
};

/// Simple hash-based text embedding (TF-IDF like)
pub fn textToEmbedding(allocator: Allocator, text: []const u8, vocab_size: usize) !Embedding {
    var embedding = try Embedding.init(allocator, vocab_size);
    errdefer embedding.deinit(allocator);

    // Initialize to zero
    for (0..vocab_size) |i| {
        embedding.data[i] = 0.0;
    }

    // Simple word hashing
    var word_count: f32 = 0.0;
    var iter = std.mem.tokenizeScalar(u8, text, ' ');
    while (iter.next()) |word| {
        // Hash word to index
        const hash = std.hash.Wyhash.hash(0, word);
        const idx = @as(usize, @intCast(hash % @as(u64, @intCast(vocab_size))));

        // Increment count (TF)
        embedding.data[idx] += 1.0;
        word_count += 1.0;
    }

    // Normalize (TF-like)
    if (word_count > 0) {
        for (0..vocab_size) |i| {
            embedding.data[i] /= word_count;
        }
    }

    return embedding;
}

/// Node in the HNSW graph
const HnswNode = struct {
    pattern_id: usize,
    embedding: Embedding,
    connections: ArrayList(usize), // Connected node indices
    layer: usize,

    pub fn init(_: Allocator, pattern_id: usize, embedding: Embedding, layer: usize) !HnswNode {
        return HnswNode{
            .pattern_id = pattern_id,
            .embedding = embedding,
            .connections = .{},
            .layer = layer,
        };
    }

    pub fn deinit(self: *HnswNode, allocator: Allocator) void {
        self.embedding.deinit(allocator);
        self.connections.deinit(allocator);
    }
};

/// HNSW Index for approximate nearest neighbor search
pub const HnswIndex = struct {
    allocator: Allocator,
    layers: ArrayList(ArrayList(HnswNode)),
    entry_point: ?usize,
    vocab_size: usize,
    max_layers: usize = 16,
    max_connections: usize = 16,

    const Self = @This();

    pub fn init(allocator: Allocator, vocab_size: usize) HnswIndex {
        return HnswIndex{
            .allocator = allocator,
            .layers = .{},
            .entry_point = null,
            .vocab_size = vocab_size,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.layers.items) |*layer| {
            for (layer.items) |*node| {
                var n = node.*;
                n.deinit(self.allocator);
            }
            layer.deinit(self.allocator);
        }
        self.layers.deinit(self.allocator);
    }

    /// Insert a pattern into the index
    pub fn insert(self: *Self, pattern_id: usize, description: []const u8) !void {
        // Create embedding
        var embedding = try textToEmbedding(self.allocator, description, self.vocab_size);
        errdefer embedding.deinit(self.allocator);

        // Determine layer (random with exponential decay)
        const layer = self.randomLayer();
        const node = try HnswNode.init(self.allocator, pattern_id, embedding, layer);

        // Ensure we have enough layers
        while (self.layers.items.len <= layer) {
            try self.layers.append(self.allocator, .{});
        }

        // Insert node
        try self.layers.items[layer].append(self.allocator, node);
        const node_idx = self.layers.items[layer].items.len - 1;

        // Set as entry point if first node
        if (self.entry_point == null) {
            self.entry_point = node_idx;
        }

        // Connect to nearest neighbors
        try self.connectToNeighbors(layer, node_idx);
    }

    /// Find nearest patterns to a query
    pub fn findNearest(self: *const Self, query: []const u8, k: usize) ![]const SearchResult {
        if (self.layers.items.len == 0) return &.{};

        // Create query embedding
        var query_emb = try textToEmbedding(self.allocator, query, self.vocab_size);
        defer query_emb.deinit(self.allocator);

        // Search from top layer down
        var candidates: ArrayList(SearchResult) = .{};

        // Search each layer
        for (self.layers.items) |layer| {
            for (layer.items) |node| {
                const similarity = try query_emb.cosineSimilarity(&node.embedding);
                try candidates.append(self.allocator, SearchResult{
                    .pattern_id = node.pattern_id,
                    .similarity = @as(f64, @floatCast(similarity)),
                });
            }
        }

        // Sort by similarity
        sortSearchResults(candidates.items);

        // Return top k
        const result_len = @min(k, candidates.items.len);
        const results = try self.allocator.alloc(SearchResult, result_len);
        for (0..result_len) |i| {
            results[i] = candidates.items[i];
        }

        candidates.deinit(self.allocator);
        return results;
    }

    fn randomLayer(self: *const Self) usize {
        // Exponential distribution: P(layer = L) ~ 1/mL^L
        // Use a simple deterministic hash-based approach for reproducibility
        const ml = self.max_layers *| 2;
        // Simple layer assignment: most nodes go to layer 0
        const seed: u64 = @intCast(self.layers.items.len +% 1);
        var layer: usize = 0;
        var h = seed *% 0x517cc1b727220a95;
        while (layer < self.max_layers) {
            h = h *% 0x517cc1b727220a95 +% 0x6c62272e07bb0142;
            const f: f32 = @as(f32, @floatFromInt(h & 0xFFFF)) / 65536.0;
            if (f >= 1.0 / @as(f32, @floatFromInt(ml))) break;
            layer += 1;
        }
        return layer;
    }

    const SimEntry = struct { idx: usize, sim: f32 };

    fn connectToNeighbors(self: *Self, layer: usize, node_idx: usize) !void {
        const layer_nodes = &self.layers.items[layer];
        if (layer_nodes.items.len <= 1) return;

        const node = &layer_nodes.items[node_idx];
        const max_conn = @min(self.max_connections, layer_nodes.items.len - 1);

        // Find nearest neighbors
        var similarities = try self.allocator.alloc(SimEntry, layer_nodes.items.len);
        defer self.allocator.free(similarities);

        for (layer_nodes.items, 0..) |other, i| {
            if (i == node_idx) {
                similarities[i] = .{ .idx = i, .sim = -1.0 };
                continue;
            }
            const sim = node.embedding.cosineSimilarity(&other.embedding) catch 0.0;
            similarities[i] = .{ .idx = i, .sim = sim };
        }

        // Sort by similarity (descending)
        std.sort.block(SimEntry, similarities, {}, struct {
            fn lessThan(_: void, a: SimEntry, b: SimEntry) bool {
                return a.sim > b.sim;
            }
        }.lessThan);

        // Connect to top-k
        for (0..max_conn) |i| {
            const neighbor_idx = similarities[i].idx;
            if (neighbor_idx != node_idx) {
                try node.connections.append(self.allocator, neighbor_idx);
            }
        }
    }
};

pub const SearchResult = struct {
    pattern_id: usize,
    similarity: f64,
};

fn sortSearchResults(items: []SearchResult) void {
    std.sort.block(SearchResult, items, {}, struct {
        fn lessThan(_: void, a: SearchResult, b: SearchResult) bool {
            return a.similarity > b.similarity;
        }
    }.lessThan);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN REGISTRY WITH HNSW
// ═══════════════════════════════════════════════════════════════════════════════

pub const PatternRegistry = struct {
    allocator: Allocator,
    patterns: ArrayList(Pattern),
    hnsw: HnswIndex,
    next_id: usize,

    const Self = @This();

    pub fn init(allocator: Allocator) PatternRegistry {
        return PatternRegistry{
            .allocator = allocator,
            .patterns = .{},
            .hnsw = HnswIndex.init(allocator, 256), // 256-dim embeddings
            .next_id = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.patterns.items) |*p| {
            p.deinit(self.allocator);
        }
        self.patterns.deinit(self.allocator);
        self.hnsw.deinit();
    }

    /// Register a pattern with HNSW indexing
    pub fn registerPattern(self: *Self, pattern: Pattern) !void {
        const id = self.next_id;
        self.next_id += 1;

        // Store pattern
        try self.patterns.append(self.allocator, pattern);

        // Index in HNSW
        try self.hnsw.insert(id, pattern.description);
    }

    /// Find pattern by semantic query
    pub fn findPattern(self: *const Self, query: []const u8, threshold: f64) !?Pattern {
        const results = try self.hnsw.findNearest(query, 5);
        defer self.allocator.free(results);

        if (results.len == 0) return null;

        const best = results[0];
        if (best.similarity < threshold) return null;

        if (best.pattern_id < self.patterns.items.len) {
            // Return copy of pattern
            return self.patterns.items[best.pattern_id];
        }

        return null;
    }

    /// Get pattern by ID
    pub fn getPattern(self: *const Self, id: usize) ?Pattern {
        if (id < self.patterns.items.len) {
            return self.patterns.items[id];
        }
        return null;
    }

    /// Get all patterns in a category
    pub fn getByCategory(self: *const Self, category: []const u8) ![]const Pattern {
        // Count patterns in category
        var count: usize = 0;
        for (self.patterns.items) |p| {
            if (std.mem.eql(u8, p.category, category)) {
                count += 1;
            }
        }

        if (count == 0) return &.{};

        // Allocate result array
        const result = try self.allocator.alloc(Pattern, count);
        var idx: usize = 0;
        for (self.patterns.items) |p| {
            if (std.mem.eql(u8, p.category, category)) {
                result[idx] = p;
                idx += 1;
            }
        }

        return result;
    }

    /// List all pattern names
    pub fn listNames(self: *const Self) ![][]const u8 {
        const names = try self.allocator.alloc([]const u8, self.patterns.items.len);
        for (self.patterns.items, 0..) |p, i| {
            names[i] = p.name;
        }
        return names;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "textToEmbedding - basic functionality" {
    var emb1 = try textToEmbedding(std.testing.allocator, "hello world", 64);
    defer emb1.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 64), emb1.dimension);
}

test "Embedding - cosine similarity" {
    var emb1 = try textToEmbedding(std.testing.allocator, "hello world", 64);
    defer emb1.deinit(std.testing.allocator);

    var emb2 = try textToEmbedding(std.testing.allocator, "hello world", 64);
    defer emb2.deinit(std.testing.allocator);

    const sim = try emb1.cosineSimilarity(&emb2);
    try std.testing.expect(sim > 0.9); // Should be very similar
}

test "HnswIndex - insert and search" {
    var index = HnswIndex.init(std.testing.allocator, 64);
    defer index.deinit();

    try index.insert(0, "vector binding operation");
    try index.insert(1, "simple math calculation");
    try index.insert(2, "string manipulation");

    const results = try index.findNearest("bind vectors", 3);
    defer std.testing.allocator.free(results);

    try std.testing.expect(results.len > 0);
    // First result should be pattern 0 (vector binding)
    try std.testing.expectEqual(@as(usize, 0), results[0].pattern_id);
}

test "PatternRegistry - register and find" {
    var registry = PatternRegistry.init(std.testing.allocator);
    defer registry.deinit();

    var pattern1 = Pattern.init(std.testing.allocator, "vector_bind", "vsa");
    pattern1.description = "bind two hypervectors together";
    pattern1.template = "pub fn bind(a: Hypervector, b: Hypervector) Hypervector {{}}";

    try registry.registerPattern(pattern1);

    // Find by semantic query
    const found = try registry.findPattern("I need to bind vectors", 0.2);
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("vector_bind", found.?.name);
}

test "PatternRegistry - category filtering" {
    var registry = PatternRegistry.init(std.testing.allocator);
    defer registry.deinit();

    var p1 = Pattern.init(std.testing.allocator, "vsa_pattern", "vsa");
    p1.description = "VSA operation";
    try registry.registerPattern(p1);

    var p2 = Pattern.init(std.testing.allocator, "math_pattern", "math");
    p2.description = "Math operation";
    try registry.registerPattern(p2);

    // Get VSA patterns
    const vsa_patterns = try registry.getByCategory("vsa");
    defer std.testing.allocator.free(vsa_patterns);

    try std.testing.expectEqual(@as(usize, 1), vsa_patterns.len);
    try std.testing.expectEqualStrings("vsa_pattern", vsa_patterns[0].name);
}
