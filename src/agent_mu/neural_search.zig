//! Neural Similarity Search with Pattern Clustering
//!
//! Advanced semantic search using neural embeddings.
//! Clusters similar patterns for better organization.

const std = @import("std");
const ArrayListManaged = std.array_list.Managed;
const diagnostic = @import("diagnostic.zig");
const embeddings = @import("embeddings.zig");

/// Search result with similarity score
pub const SearchResult = struct {
    pattern_id: []const u8,
    similarity: f32,
    fix_type: diagnostic.FixType,
    confidence: f32,
    embedding: *const [embeddings.EMBEDDING_DIM]f32,
};

/// Neural search engine
pub const NeuralSearchEngine = struct {
    index: *embeddings.HNSWIndex,
    allocator: std.mem.Allocator,

    /// Initialize neural search engine
    pub fn init(allocator: std.mem.Allocator, ef_construction: usize) !NeuralSearchEngine {
        const idx = try allocator.create(embeddings.HNSWIndex);
        idx.* = try embeddings.HNSWIndex.init(allocator, ef_construction);
        return NeuralSearchEngine{
            .index = idx,
            .allocator = allocator,
        };
    }

    /// Deinitialize search engine
    pub fn deinit(self: *NeuralSearchEngine) void {
        self.index.deinit();
        self.allocator.destroy(self.index);
    }

    /// Search for top-k similar patterns
    pub fn search(self: *NeuralSearchEngine, error_message: []const u8, k: usize, threshold: f32) ![]SearchResult {
        // Generate query embedding
        const query_emb = try embeddings.EmbeddingGenerator.generate(self.allocator, error_message);

        // Search HNSW index
        const nodes = try self.index.search(&query_emb, @min(k, self.index.nodes.items.len));

        // Build results
        var results = ArrayListManaged(SearchResult).init(self.allocator);
        for (nodes) |node| {
            const sim = embeddings.cosineSimilarity(&query_emb, node.embedding);
            if (sim >= threshold) {
                // TODO: Get pattern_id and fix_type from node
                try results.append(SearchResult{
                    .pattern_id = "unknown",
                    .similarity = sim,
                    .fix_type = .UNKNOWN,
                    .confidence = sim,
                    .embedding = node.embedding,
                });
            }
        }

        return results.toOwnedSlice();
    }

    /// Add pattern to search index
    pub fn addPattern(self: *NeuralSearchEngine, pattern: *const embeddings.ErrorEmbedding) !void {
        try self.index.insert(self.allocator, pattern);
    }

    /// Batch index patterns from SUCCESS_HISTORY
    pub fn indexFromHistory(self: *NeuralSearchEngine) !void {
        _ = self;
        // TODO: Parse SUCCESS_HISTORY.md and extract patterns
    }
};

/// Pattern cluster for organizing similar fixes
pub const PatternCluster = struct {
    cluster_id: []const u8,
    centroid: [embeddings.EMBEDDING_DIM]f32,
    patterns: ArrayListManaged(*embeddings.ErrorEmbedding),
    fix_type: diagnostic.FixType,
    avg_success_rate: f32,

    pub fn init(allocator: std.mem.Allocator, cluster_id: []const u8, fix_type: diagnostic.FixType) !PatternCluster {
        return PatternCluster{
            .cluster_id = try allocator.dupe(u8, cluster_id),
            .centroid = [_]f32{0.0} ** embeddings.EMBEDDING_DIM,
            .patterns = ArrayListManaged(*embeddings.ErrorEmbedding).init(allocator),
            .fix_type = fix_type,
            .avg_success_rate = 0.0,
        };
    }

    pub fn deinit(self: *PatternCluster) void {
        self.patterns.allocator.free(self.cluster_id);
        self.patterns.deinit();
    }

    /// Add pattern to cluster
    pub fn addPattern(self: *PatternCluster, pattern: *embeddings.ErrorEmbedding) !void {
        try self.patterns.append(pattern);
        try self.updateCentroid();
    }

    /// Update cluster centroid
    pub fn updateCentroid(self: *PatternCluster) !void {
        if (self.patterns.items.len == 0) return;

        // Average all embeddings
        var sum = [_]f32{0.0} ** embeddings.EMBEDDING_DIM;
        for (self.patterns.items) |p| {
            for (0..embeddings.EMBEDDING_DIM) |i| {
                sum[i] += p.vector[i];
            }
        }

        const n: f32 = @floatFromInt(self.patterns.items.len);
        for (0..embeddings.EMBEDDING_DIM) |i| {
            self.centroid[i] = sum[i] / n;
        }
    }

    /// Calculate cluster cohesion
    pub fn cohesion(self: *const PatternCluster) f32 {
        if (self.patterns.items.len < 2) return 1.0;

        var total_sim: f32 = 0.0;
        var count: usize = 0;

        for (self.patterns.items, 0..) |p1, i| {
            for (self.patterns.items[i + 1 ..]) |p2| {
                total_sim += embeddings.cosineSimilarity(&p1.vector, &p2.vector);
                count += 1;
            }
        }

        if (count == 0) return 1.0;
        return total_sim / @as(f32, @floatFromInt(count));
    }
};

/// K-means clustering for patterns
pub const PatternClustering = struct {
    clusters: ArrayListManaged(PatternCluster),
    k: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, k: usize) !PatternClustering {
        return PatternClustering{
            .clusters = ArrayListManaged(PatternCluster).init(allocator),
            .k = k,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PatternClustering) void {
        for (self.clusters.items) |*c| {
            c.deinit();
        }
        self.clusters.deinit();
    }

    /// Cluster patterns using k-means
    pub fn cluster(self: *PatternClustering, patterns: []const embeddings.ErrorEmbedding) !void {
        if (patterns.len == 0) return;
        if (self.k == 0) return;

        // Initialize clusters with first k patterns as centroids
        const actual_k = @min(self.k, patterns.len);
        for (0..actual_k) |i| {
            const cluster = try PatternCluster.init(self.allocator, "cluster_001", .TYPE_FIX);
            try self.clusters.append(cluster);
        }

        // Assign patterns to nearest cluster
        for (patterns) |pattern| {
            var best_cluster: usize = 0;
            var best_sim: f32 = -1.0;

            for (self.clusters.items, 0..) |cluster, i| {
                const sim = embeddings.cosineSimilarity(&pattern.vector, &cluster.centroid);
                if (sim > best_sim) {
                    best_sim = sim;
                    best_cluster = i;
                }
            }

            try self.clusters.items[best_cluster].addPattern(pattern);
        }

        // Update centroids
        for (self.clusters.items) |*cluster| {
            try cluster.updateCentroid();
        }
    }

    /// Get cluster for a pattern
    pub fn getCluster(self: *const PatternClustering, embedding: *const [embeddings.EMBEDDING_DIM]f32) ?*const PatternCluster {
        var best_cluster: ?*const PatternCluster = null;
        var best_sim: f32 = -1.0;

        for (self.clusters.items) |*cluster| {
            const sim = embeddings.cosineSimilarity(embedding, &cluster.centroid);
            if (sim > best_sim) {
                best_sim = sim;
                best_cluster = cluster;
            }
        }

        return best_cluster;
    }
};

test "NeuralSearchEngine: basic search" {
    const allocator = std.testing.allocator;
    var engine = try NeuralSearchEngine.init(allocator, 16);
    defer engine.deinit();

    const embedding = try embeddings.EmbeddingGenerator.generate(allocator, "test error message");
    const pattern = embeddings.ErrorEmbedding{
        .pattern_id = "test_001",
        .vector = embedding,
        .confidence = 0.9,
        .fix_type = .TYPE_FIX,
        .timestamp = std.time.timestamp(),
    };

    try engine.addPattern(&pattern);

    const results = try engine.search("test error message", 1, 0.5);
    try std.testing.expect(results.len >= 1);
}

test "PatternCluster: add and cohesion" {
    const allocator = std.testing.allocator;
    var cluster = try PatternCluster.init(allocator, "cluster_001", .TYPE_FIX);
    defer cluster.deinit();

    const emb1 = try embeddings.EmbeddingGenerator.generate(allocator, "error type mismatch");
    const emb2 = try embeddings.EmbeddingGenerator.generate(allocator, "error type mismatch");

    const pattern1 = embeddings.ErrorEmbedding{
        .pattern_id = "p1",
        .vector = emb1,
        .confidence = 1.0,
        .fix_type = .TYPE_FIX,
        .timestamp = 0,
    };
    const pattern2 = embeddings.ErrorEmbedding{
        .pattern_id = "p2",
        .vector = emb2,
        .confidence = 1.0,
        .fix_type = .TYPE_FIX,
        .timestamp = 0,
    };

    try cluster.addPattern(&pattern1);
    try cluster.addPattern(&pattern2);

    // Cohesion should be high (similar patterns)
    const cohesion = cluster.cohesion();
    try std.testing.expect(cohesion > 0.5);
}

test "PatternClustering: k-means" {
    const allocator = std.testing.allocator;
    var clustering = try PatternClustering.init(allocator, 2);
    defer clustering.deinit();

    var patterns = ArrayListManaged(embeddings.ErrorEmbedding).init(allocator);

    // Add 4 patterns (2 similar pairs)
    const emb1 = try embeddings.EmbeddingGenerator.generate(allocator, "error type mismatch");
    const emb2 = try embeddings.EmbeddingGenerator.generate(allocator, "error type mismatch");
    const emb3 = try embeddings.EmbeddingGenerator.generate(allocator, "memory leak detected");
    const emb4 = try embeddings.EmbeddingGenerator.generate(allocator, "memory leak detected");

    try patterns.append(embeddings.ErrorEmbedding{
        .pattern_id = "p1",
        .vector = emb1,
        .confidence = 1.0,
        .fix_type = .TYPE_FIX,
        .timestamp = 0,
    });
    try patterns.append(embeddings.ErrorEmbedding{
        .pattern_id = "p2",
        .vector = emb2,
        .confidence = 1.0,
        .fix_type = .TYPE_FIX,
        .timestamp = 0,
    });
    try patterns.append(embeddings.ErrorEmbedding{
        .pattern_id = "p3",
        .vector = emb3,
        .confidence = 1.0,
        .fix_type = .MEM_FIX,
        .timestamp = 0,
    });
    try patterns.append(embeddings.ErrorEmbedding{
        .pattern_id = "p4",
        .vector = emb4,
        .confidence = 1.0,
        .fix_type = .MEM_FIX,
        .timestamp = 0,
    });

    try clustering.cluster(patterns.items);

    // Should have 2 clusters
    try std.testing.expectEqual(@as(usize, 2), clustering.clusters.items.len);
}
