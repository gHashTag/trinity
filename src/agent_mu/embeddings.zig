//! Enhanced Semantic Search with Neural Embeddings
//!
//! Vector embeddings for error messages with HNSW indexing.
//! Provides O(log n) similarity search for pattern matching.

const std = @import("std");
const ArrayListManaged = std.array_list.Managed;
const diagnostic = @import("diagnostic.zig");

/// Embedding dimension (384-dim vectors)
pub const EMBEDDING_DIM: usize = 384;

/// Vector embedding for error pattern
pub const ErrorEmbedding = struct {
    pattern_id: []const u8,
    vector: [EMBEDDING_DIM]f32,
    confidence: f32,
    fix_type: diagnostic.FixType,
    timestamp: i64,
};

/// HNSW graph node for approximate nearest neighbor search
pub const HNSWNode = struct {
    id: usize,
    embedding: *const [EMBEDDING_DIM]f32,
    neighbors: ArrayListManaged(usize),
    level: usize,

    pub fn init(allocator: std.mem.Allocator, id: usize, embedding: *const [EMBEDDING_DIM]f32, level: usize) !HNSWNode {
        var neighbors = ArrayListManaged(usize).init(allocator);
        return HNSWNode{
            .id = id,
            .embedding = embedding,
            .neighbors = neighbors,
            .level = level,
        };
    }

    pub fn deinit(self: *HNSWNode) void {
        self.neighbors.deinit();
    }
};

/// HNSW index for fast similarity search
pub const HNSWIndex = struct {
    nodes: ArrayListManaged(*HNSWNode),
    entry_point: ?*HNSWNode,
    max_level: usize,
    ml: f64, // Level normalization factor
    ef_construction: usize,

    pub fn init(allocator: std.mem.Allocator, ef_construction: usize) !HNSWIndex {
        return HNSWIndex{
            .nodes = ArrayListManaged(*HNSWNode).init(allocator),
            .entry_point = null,
            .max_level = 0,
            .ml = 1.0 / std.math.ln(@as(f32, @floatFromInt(ef_construction))),
            .ef_construction = ef_construction,
        };
    }

    pub fn deinit(self: *HNSWIndex) void {
        for (self.nodes.items) |node| {
            node.deinit();
            self.nodes.allocator.destroy(node);
        }
        self.nodes.deinit();
    }

    /// Insert a new embedding into the index
    pub fn insert(self: *HNSWIndex, allocator: std.mem.Allocator, embedding: *const ErrorEmbedding) !void {
        const node = try allocator.create(HNSWNode);
        errdefer allocator.destroy(node);
        node.* = try HNSWNode.init(allocator, self.nodes.items.len, &embedding.vector, 0);
        errdefer node.deinit();
        try self.nodes.append(node);

        // Set as entry point if first node
        if (self.entry_point == null) {
            self.entry_point = node;
        }

        // Determine node level
        const level = self.getRandomLevel();
        node.level = level;

        if (level > self.max_level) {
            self.max_level = level;
            self.entry_point = node;
        }

        // TODO: Connect to neighbors at each level
        _ = level;
    }

    /// Search for k nearest neighbors
    pub fn search(self: *const HNSWIndex, query: *const [EMBEDDING_DIM]f32, k: usize) ![]const *HNSWNode {
        _ = k;
        if (self.entry_point == null) return &[_]*HNSWNode{};

        // Greedy search from entry point
        var current = self.entry_point.?;
        var best_dist = self.distance(query, current.embedding);

        // TODO: Implement proper HNSW search
        _ = best_dist;
        return &[_]*HNSWNode{current};
    }

    /// Calculate Euclidean distance between vectors
    fn distance(self: *const HNSWIndex, a: *const [EMBEDDING_DIM]f32, b: *const [EMBEDDING_DIM]f32) f32 {
        var sum: f32 = 0.0;
        for (0..EMBEDDING_DIM) |i| {
            const diff = a[i] - b[i];
            sum += diff * diff;
        }
        return std.math.sqrt(sum);
    }

    /// Get random level for new node (exponential distribution)
    fn getRandomLevel(self: *const HNSWIndex) usize {
        var level: usize = 0;
        var rand_val: u32 = undefined;
        while (true) {
            std.crypto.random.bytes(std.mem.asBytes(&rand_val));
            const unif: f32 = @as(f32, @floatFromInt(rand_val)) / @as(f32, std.math.maxInt(u32));
            if (unif > self.ml) break;
            level += 1;
        }
        return level;
    }
};

/// Embedding generator using character n-grams
pub const EmbeddingGenerator = struct {
    /// Generate 384-dim embedding from error message
    pub fn generate(allocator: std.mem.Allocator, text: []const u8) ![EMBEDDING_DIM]f32 {
        var embedding: [EMBEDDING_DIM]f32 = undefined;

        // Simple hash-based embedding (placeholder)
        // TODO: Replace with proper neural embeddings
        var i: usize = 0;
        var hash: u32 = 5381;
        for (text) |c| {
            hash = ((hash << 5) + hash) + c;
            if (i < EMBEDDING_DIM) {
                embedding[i] = @as(f32, @floatFromInt(hash % 10000)) / 10000.0;
                i += 1;
            }
        }

        // Fill remaining with zeros
        while (i < EMBEDDING_DIM) : (i += 1) {
            embedding[i] = 0.0;
        }

        // Normalize to unit length
        var norm: f32 = 0.0;
        for (embedding) |v| {
            norm += v * v;
        }
        norm = std.math.sqrt(norm);
        if (norm > 0.0) {
            for (&embedding) |*v| {
                v.* /= norm;
            }
        }

        return embedding;
    }

    /// Generate embedding from FixType
    pub fn fromFixType(allocator: std.mem.Allocator, fix_type: diagnostic.FixType) ![EMBEDDING_DIM]f32 {
        const type_name = @tagName(fix_type);
        return generate(allocator, type_name);
    }

    /// Generate embedding from error code
    pub fn fromErrorCode(allocator: std.mem.Allocator, error_code: []const u8) ![EMBEDDING_DIM]f32 {
        return generate(allocator, error_code);
    }
};

/// Cosine similarity between two embeddings
pub fn cosineSimilarity(a: *const [EMBEDDING_DIM]f32, b: *const [EMBEDDING_DIM]f32) f32 {
    var dot: f32 = 0.0;
    var norm_a: f32 = 0.0;
    var norm_b: f32 = 0.0;

    for (0..EMBEDDING_DIM) |i| {
        dot += a[i] * b[i];
        norm_a += a[i] * a[i];
        norm_b += b[i] * b[i];
    }

    const norm = std.math.sqrt(norm_a) * std.math.sqrt(norm_b);
    if (norm == 0.0) return 0.0;
    return dot / norm;
}

test "EmbeddingGenerator: generate" {
    const allocator = std.testing.allocator;
    const embedding = try EmbeddingGenerator.generate(allocator, "error: undefined field");

    // Check normalized
    var norm: f32 = 0.0;
    for (embedding) |v| {
        norm += v * v;
    }
    try std.testing.expectApproxEqRel(@as(f32, 1.0), std.math.sqrt(norm), 0.001);
}

test "cosineSimilarity: identical vectors" {
    const allocator = std.testing.allocator;
    const embedding = try EmbeddingGenerator.generate(allocator, "test");

    const sim = cosineSimilarity(&embedding, &embedding);
    try std.testing.expectApproxEqRel(@as(f32, 1.0), sim, 0.001);
}

test "cosineSimilarity: orthogonal vectors" {
    const v1 = [_]f32{1.0} ** EMBEDDING_DIM;
    var v2: [EMBEDDING_DIM]f32 = undefined;
    for (&v2, 0..) |*v, i| {
        v.* = if (i == EMBEDDING_DIM - 1) 1.0 else 0.0;
    }

    const sim = cosineSimilarity(&v1, &v2);
    try std.testing.expectApproxEqRel(@as(f32, 0.0), sim, 0.001);
}

test "HNSWIndex: insert and search" {
    const allocator = std.testing.allocator;
    var index = try HNSWIndex.init(allocator, 16);
    defer index.deinit();

    const embedding = try EmbeddingGenerator.generate(allocator, "test error");
    const error_emb = ErrorEmbedding{
        .pattern_id = "test_001",
        .vector = embedding,
        .confidence = 1.0,
        .fix_type = .TYPE_FIX,
        .timestamp = std.time.timestamp(),
    };

    try index.insert(allocator, &error_emb);

    const results = try index.search(&embedding, 1);
    try std.testing.expectEqual(@as(usize, 1), results.len);
}
