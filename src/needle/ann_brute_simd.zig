// ═══════════════════════════════════════════════════════════════════════════════
// Track C: Brute + SIMD (Optimized Baseline)
// ═══════════════════════════════════════════════════════════════════════════════
// Brute-force search with SIMD vectorized distance computation
//
// Provides exact nearest neighbor search with SIMD acceleration.
// Competitive performance up to 10k vectors, serves as accuracy baseline.
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const ann_interface = @import("ann_interface.zig");
const ann_utils = @import("ann_utils.zig");

/// Brute force configuration
pub const BruteConfig = struct {
    dim: usize = 384,
    distance_metric: ann_interface.DistanceMetric = .cosine,
    use_simd: bool = true,
    batch_size: usize = ann_utils.SIMD_BATCH_SIZE, // round(φ³) = 8
};

/// Main Brute Force Index
pub const BruteIndex = struct {
    config: BruteConfig,
    vectors: std.AutoHashMap(u64, []f32),
    symbol_ids: std.AutoHashMap(u64, []const u8),
    vector_list: std.ArrayList(u64),
    allocator: std.mem.Allocator,
    total_vectors: usize,

    const Self = @This();

    /// Initialize a new brute force index
    pub fn init(allocator: std.mem.Allocator, config: BruteConfig) !Self {
        return Self{
            .config = config,
            .vectors = std.AutoHashMap(u64, []f32).init(allocator),
            .symbol_ids = std.AutoHashMap(u64, []const u8).init(allocator),
            .vector_list = try std.ArrayList(u64).initCapacity(allocator, 64),
            .allocator = allocator,
            .total_vectors = 0,
        };
    }

    /// Clean up all resources
    pub fn deinit(self: *Self) void {
        var vector_iter = self.vectors.valueIterator();
        while (vector_iter.next()) |vec| {
            self.allocator.free(vec.*);
        }
        self.vectors.deinit();

        var symbol_iter = self.symbol_ids.valueIterator();
        while (symbol_iter.next()) |sym| {
            self.allocator.free(sym.*);
        }
        self.symbol_ids.deinit();

        self.vector_list.deinit(self.allocator);
    }

    /// Insert a vector into the index
    pub fn insert(self: *Self, id: u64, symbol_id: []const u8, vector: []const f32) !void {
        std.debug.assert(vector.len == self.config.dim);

        // Deep copy the vector
        const vec_copy = try self.allocator.alloc(f32, vector.len);
        @memcpy(vec_copy, vector);

        // Deep copy the symbol ID
        const sym_copy = try self.allocator.dupe(u8, symbol_id);

        try self.vectors.put(id, vec_copy);
        try self.symbol_ids.put(id, sym_copy);
        try self.vector_list.append(self.allocator, id);
        self.total_vectors += 1;
    }

    /// Bulk insert for faster indexing
    pub fn insertBatch(self: *Self, ids: []const u64, symbol_ids: []const []const u8, vectors: []const []const f32) !void {
        std.debug.assert(ids.len == symbol_ids.len);
        std.debug.assert(ids.len == vectors.len);

        for (ids, symbol_ids, vectors) |id, sym, vec| {
            try self.insert(id, sym, vec);
        }
    }

    /// Search for k nearest neighbors (exact, O(N))
    pub fn search(self: *Self, query: []const f32, k: usize, result_allocator: std.mem.Allocator) ![]ann_interface.ANNResult {
        std.debug.assert(query.len == self.config.dim);

        const actual_k = @min(k, self.total_vectors);
        if (actual_k == 0) {
            return result_allocator.alloc(ann_interface.ANNResult, 0);
        }

        // Min-heap to track top-k results
        var heap = std.PriorityQueue(ann_interface.ANNResult, void, compareDistance).init(result_allocator, {});
        defer heap.deinit();

        try heap.ensureTotalCapacity(@as(usize, @intCast(actual_k)));

        // Scan all vectors
        for (self.vector_list.items) |id| {
            const vec = self.vectors.get(id).?;
            const sym_id = self.symbol_ids.get(id).?;

            const distance = if (self.config.use_simd)
                self.computeDistanceSIMD(query, vec)
            else
                self.computeDistanceScalar(query, vec);

            const similarity = ann_interface.distanceToSimilarity(distance, self.config.distance_metric);

            const result = ann_interface.ANNResult{
                .id = id,
                .symbol_id = try result_allocator.dupe(u8, sym_id),
                .distance = distance,
                .similarity = similarity,
            };

            if (heap.count() < actual_k) {
                try heap.add(result);
            } else if (distance < heap.peek().?.distance) {
                // Remove farthest and add closer
                const old = heap.remove();
                result_allocator.free(old.symbol_id);
                try heap.add(result);
            } else {
                result_allocator.free(result.symbol_id);
            }
        }

        // Extract results in order (closest first)
        // The PriorityQueue with our comparator gives smallest distance first
        const n = heap.count();
        const results = try result_allocator.alloc(ann_interface.ANNResult, n);
        for (0..n) |i| {
            results[i] = heap.remove();
        }

        return results;
    }

    /// Compute distance using SIMD (when supported)
    fn computeDistanceSIMD(self: *const Self, a: []const f32, b: []const f32) f32 {
        return switch (self.config.distance_metric) {
            .cosine => ann_utils.simdCosineDistance(a, b),
            .euclidean => ann_utils.simdEuclideanDistance(a, b),
            .dot_product => {
                const Vec8 = @Vector(8, f32);
                var dot: f32 = 0;
                const batch_size = self.config.batch_size;
                const num_batches = a.len / batch_size;

                var i: usize = 0;
                while (i < num_batches * batch_size) : (i += batch_size) {
                    const a_vec: Vec8 = @as(*const [8]f32, @ptrCast(&a[i])).*;
                    const b_vec: Vec8 = @as(*const [8]f32, @ptrCast(&b[i])).*;
                    dot += @reduce(.Add, a_vec * b_vec);
                }
                while (i < a.len) : (i += 1) {
                    dot += a[i] * b[i];
                }
                return -dot; // Negative because higher = closer
            },
            .hamming => @panic("Hamming distance not supported for float32"),
        };
    }

    /// Compute distance using scalar operations
    fn computeDistanceScalar(self: *const Self, a: []const f32, b: []const f32) f32 {
        return ann_interface.computeDistance(a, b, self.config.distance_metric);
    }

    /// Get index statistics
    pub fn getStats(self: *const Self) ann_interface.ANNStats {
        var memory: usize = self.vectors.count() * @sizeOf([]f32);
        memory += self.symbol_ids.count() * @sizeOf([]const u8);
        memory += self.vector_list.capacity * @sizeOf(u64);

        var vector_iter = self.vectors.valueIterator();
        while (vector_iter.next()) |vec| {
            memory += vec.*.len * @sizeOf(f32);
        }

        var symbol_iter = self.symbol_ids.valueIterator();
        while (symbol_iter.next()) |sym| {
            memory += sym.*.len;
        }

        return ann_interface.ANNStats{
            .total_vectors = self.total_vectors,
            .index_size_bytes = memory,
            .build_time_ms = 0, // N/A for brute force (build is insert)
            .avg_search_time_ms = 0,
            .last_search_time_ms = 0,
            .search_count = 0,
        };
    }

    /// Get the ANN type
    pub fn annType(self: *const Self) ann_interface.ANNType {
        _ = self;
        return .brute;
    }

    /// Comparator for max-heap by distance (we want smallest distance)
    fn compareDistance(_: void, a: ann_interface.ANNResult, b: ann_interface.ANNResult) std.math.Order {
        return std.math.order(a.distance, b.distance);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "BruteIndex — basic insert and search" {
    const allocator = std.testing.allocator;

    var index = try BruteIndex.init(allocator, .{ .dim = 3 });
    defer index.deinit();

    // Insert some vectors
    const v1 = [_]f32{ 1.0, 0.0, 0.0 };
    const v2 = [_]f32{ 0.0, 1.0, 0.0 };
    const v3 = [_]f32{ 0.0, 0.0, 1.0 };

    try index.insert(1, "vec1", &v1);
    try index.insert(2, "vec2", &v2);
    try index.insert(3, "vec3", &v3);

    // Search
    const query = [_]f32{ 1.0, 0.0, 0.0 };
    const results = try index.search(&query, 2, allocator);
    defer {
        for (results) |r| allocator.free(r.symbol_id);
        allocator.free(results);
    }

    // Debug: print results
    for (results, 0..) |r, i| {
        std.debug.print("result[{d}]: id={d}, dist={d:.6}\n", .{ i, r.id, r.distance });
    }

    try std.testing.expectEqual(@as(usize, 2), results.len);
    // Closest should be id=1 with distance=0 (same vector)
    try std.testing.expectEqual(@as(u64, 1), results[0].id);
    try std.testing.expectApproxEqAbs(0.0, results[0].distance, 1e-3);
}

test "BruteIndex — getStats" {
    const allocator = std.testing.allocator;

    var index = try BruteIndex.init(allocator, .{ .dim = 10 });
    defer index.deinit();

    const v = [_]f32{0.0} ** 10;
    try index.insert(1, "test", &v);

    const stats = index.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.total_vectors);
    try std.testing.expect(stats.index_size_bytes > 0);
}

test "BruteIndex — bulk insert" {
    const allocator = std.testing.allocator;

    var index = try BruteIndex.init(allocator, .{ .dim = 3 });
    defer index.deinit();

    const vectors = [_][]const f32{
        &[_]f32{ 1.0, 0.0, 0.0 },
        &[_]f32{ 0.0, 1.0, 0.0 },
        &[_]f32{ 0.0, 0.0, 1.0 },
    };
    const ids = [_]u64{ 1, 2, 3 };
    const symbols = [_][]const u8{ "a", "b", "c" };

    try index.insertBatch(&ids, &symbols, &vectors);

    try std.testing.expectEqual(@as(usize, 3), index.total_vectors);
}
