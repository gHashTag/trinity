// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED ANN INTERFACE
// ═══════════════════════════════════════════════════════════════════════════════
// Common interface for all Approximate Nearest Neighbor implementations:
// - HNSW (baseline)
// - IVF + PQ (Track A)
// - Ternary LSH (Track B)
// - Brute + SIMD (Track C)
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Import from canonical source (ANTI-PATTERN: no inline constants!)
const sacred_constants = @import("sacred_constants");

/// Distance metrics supported across all ANN implementations
pub const DistanceMetric = enum {
    /// Cosine similarity [-1, 1] -> distance [0, 2]
    cosine,
    /// Euclidean L2 distance
    euclidean,
    /// Hamming distance (for ternary/binary vectors)
    hamming,
    /// Dot product (for normalized vectors)
    dot_product,
};

/// ANN algorithm type identifier
pub const ANNType = enum {
    /// Hierarchical Navigable Small World (baseline)
    hnsw,
    /// Inverted File + Product Quantization (Track A)
    ivf_pq,
    /// Locality-Sensitive Hashing (Track B)
    lsh,
    /// Brute-force + SIMD (Track C) - WINNER for <7k symbols
    brute,
    // Note: brute_simd was an alias for brute, removed due to Zig 0.15 enum rules
};

/// Configuration for any ANN index
pub const ANNConfig = struct {
    /// Vector dimension (default: 384 for embeddings)
    dim: usize = 384,
    /// Distance metric to use
    distance_metric: DistanceMetric = .cosine,
    /// Default number of results for search
    default_k: usize = 10,
    /// Allocator for all operations
    allocator: std.mem.Allocator,
};

/// Single search result
pub const ANNResult = struct {
    /// Unique identifier for the result
    id: u64,
    /// Symbol name/ID (owned, must free)
    symbol_id: []const u8,
    /// Distance from query (lower is better)
    distance: f32,
    /// Similarity score (higher is better)
    similarity: f32,

    /// Clean up resources
    pub fn deinit(self: *const ANNResult, allocator: std.mem.Allocator) void {
        allocator.free(self.symbol_id);
    }
};

/// Statistics for ANN operations
pub const ANNStats = struct {
    /// Total number of vectors indexed
    total_vectors: usize = 0,
    /// Index size in bytes
    index_size_bytes: usize = 0,
    /// Time to build index (milliseconds)
    build_time_ms: u64 = 0,
    /// Average search time (milliseconds)
    avg_search_time_ms: f64 = 0.0,
    /// Last search time (milliseconds)
    last_search_time_ms: u64 = 0,
    /// Number of searches performed
    search_count: u64 = 0,

    /// Format stats as string
    pub fn format(self: *const ANNStats, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\ANNStats:
            \\  vectors: {d}
            \\  memory: {d} KB
            \\  build: {d} ms
            \\  avg_search: {d:.2} ms
            \\  searches: {d}
        , .{
            self.total_vectors,
            @as(f64, @floatFromInt(self.index_size_bytes)) / 1024.0,
            self.build_time_ms,
            self.avg_search_time_ms,
            self.search_count,
        });
    }
};

/// Unified ANN interface — all implementations must conform
pub fn ANNInterface(comptime Self: type) type {
    return struct {
        /// Initialize the index with config
        pub fn init(allocator: std.mem.Allocator, config: ANNConfig) !Self {
            _ = allocator;
            _ = config;
            @compileError("ANNInterface.init must be implemented by concrete type");
        }

        /// Clean up resources
        pub fn deinit(self: *Self) void {
            _ = self;
            @compileError("ANNInterface.deinit must be implemented by concrete type");
        }

        /// Insert a vector into the index
        pub fn insert(self: *Self, id: u64, symbol_id: []const u8, vector: []const f32) !void {
            _ = self;
            _ = id;
            _ = symbol_id;
            _ = vector;
            @compileError("ANNInterface.insert must be implemented by concrete type");
        }

        /// Bulk insert for faster indexing
        pub fn insertBatch(self: *Self, ids: []const u64, symbol_ids: []const []const u8, vectors: []const []const f32) !void {
            _ = self;
            _ = ids;
            _ = symbol_ids;
            _ = vectors;
            @compileError("ANNInterface.insertBatch must be implemented by concrete type");
        }

        /// Search for k nearest neighbors
        pub fn search(self: *Self, query: []const f32, k: usize, result_allocator: std.mem.Allocator) ![]ANNResult {
            _ = self;
            _ = query;
            _ = k;
            _ = result_allocator;
            @compileError("ANNInterface.search must be implemented by concrete type");
        }

        /// Get index statistics
        pub fn getStats(self: *const Self) ANNStats {
            _ = self;
            @compileError("ANNInterface.getStats must be implemented by concrete type");
        }

        /// Get the ANN type
        pub fn annType(self: *const Self) ANNType {
            _ = self;
            @compileError("ANNInterface.annType must be implemented by concrete type");
        }
    };
}

/// Helper: compute distance between two float32 vectors
pub fn computeDistance(a: []const f32, b: []const f32, metric: DistanceMetric) f32 {
    std.debug.assert(a.len == b.len);

    switch (metric) {
        .cosine => {
            var dot: f32 = 0;
            var norm_a: f32 = 0;
            var norm_b: f32 = 0;
            for (a, b) |va, vb| {
                dot += va * vb;
                norm_a += va * va;
                norm_b += vb * vb;
            }
            const norm_a_sqrt = @sqrt(norm_a);
            const norm_b_sqrt = @sqrt(norm_b);
            if (norm_a_sqrt < 1e-6 or norm_b_sqrt < 1e-6) return 0.0;
            const cosine_sim = dot / (norm_a_sqrt * norm_b_sqrt);
            return 1.0 - cosine_sim; // Convert similarity to distance
        },
        .euclidean => {
            var sum: f32 = 0;
            for (a, b) |va, vb| {
                const diff = va - vb;
                sum += diff * diff;
            }
            return @sqrt(sum);
        },
        .dot_product => {
            var dot: f32 = 0;
            for (a, b) |va, vb| {
                dot += va * vb;
            }
            return -dot; // Negative because higher dot product = closer
        },
        .hamming => {
            @panic("Hamming distance not supported for float32 vectors");
        },
    }
}

/// Helper: convert distance to similarity (for display)
pub fn distanceToSimilarity(distance: f32, metric: DistanceMetric) f32 {
    return switch (metric) {
        .cosine => 1.0 - distance,
        .euclidean => 1.0 / (1.0 + distance),
        .dot_product => -distance,
        .hamming => 1.0 - (distance / @as(f32, @floatFromInt(384))), // Normalize
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Golden ratio φ = (1 + √5) / 2
pub const PHI = sacred_constants.PHI;

/// φ⁻¹ = φ - 1 = 0.618...
pub const PHI_INVERSE = sacred_constants.PHI_INVERSE;

/// φ⁴ ≈ 6.854 → ceil = 7 (but we use 12 for LSH tables)
pub const PHI_POW_4: f64 = 6.854101966249685;

/// Default embedding dimension
pub const DEFAULT_DIM: usize = 384;

test "computeDistance — cosine" {
    const a = [_]f32{ 1.0, 0.0, 0.0 };
    const c = [_]f32{ 0.0, 1.0, 0.0 };

    const dist_same = computeDistance(&a, &a, .cosine);
    const dist_orthogonal = computeDistance(&a, &c, .cosine);

    try std.testing.expectApproxEqAbs(0.0, dist_same, 1e-6);
    try std.testing.expectApproxEqAbs(1.0, dist_orthogonal, 1e-6);
}

test "computeDistance — euclidean" {
    const a = [_]f32{ 0.0, 0.0 };
    const b = [_]f32{ 3.0, 4.0 };

    const dist = computeDistance(&a, &b, .euclidean);
    try std.testing.expectApproxEqAbs(5.0, dist, 1e-6);
}
