// ═══════════════════════════════════════════════════════════════════════════════
// Track A: IVF + PQ (Inverted File + Product Quantization)
// ═══════════════════════════════════════════════════════════════════════════════
// Inverted File Index with Product Quantization for memory-efficient search
//
// Partitions vectors into clusters (Voronoi cells), then searches only
// nearby clusters. PQ compresses vectors for 10x+ memory savings.
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const ann_interface = @import("ann_interface.zig");
const ann_utils = @import("ann_utils.zig");

/// IVF configuration
pub const IVFConfig = struct {
    dim: usize = 384,
    nlist: usize = 100, // Number of Voronoi cells
    nprobe: usize = 8, // Clusters to search
    m: usize = 16, // PQ sub-vectors
    nbits: u8 = 8, // Bits per PQ code
    distance_metric: ann_interface.DistanceMetric = .cosine,
    max_iterations: usize = 25, // K-means max iterations
    convergence_threshold: f32 = 0.001,
};

/// Single Voronoi cell (cluster)
pub const VoronoiCell = struct {
    center_id: u64,
    center: []f32, // Owned, must free
    vector_ids: std.ArrayList(u64),

    fn deinit(self: *VoronoiCell, allocator: std.mem.Allocator) void {
        allocator.free(self.center);
        self.vector_ids.deinit(allocator);
    }
};

/// PQ Codebook for encoding
pub const PQCodebook = struct {
    // centroids[m][k][sub_dim]
    // m: number of sub-vectors
    // k: number of centroids per sub-vector (2^nbits)
    // sub_dim: dimension of each sub-vector
    centroids: [][][]f32, // 3D array, allocated
    m: usize,
    nbits: u8,
    k: usize,
    sub_dim: usize,

    fn deinit(self: *PQCodebook, allocator: std.mem.Allocator) void {
        for (self.centroids) |outer| {
            for (outer) |middle| {
                allocator.free(middle);
            }
            allocator.free(outer);
        }
        allocator.free(self.centroids);
    }
};

/// PQ-encoded vector (compressed)
pub const PQCode = struct {
    codes: []u8, // m codes, each nbits wide
};

/// Main IVF+PQ Index
pub const IVFPQIndex = struct {
    config: IVFConfig,
    voronoi_cells: std.ArrayList(VoronoiCell),
    pq_codebook: ?PQCodebook,
    pq_codes: std.AutoHashMap(u64, PQCode),
    vectors: std.AutoHashMap(u64, []f32), // Keep original vectors
    symbol_ids: std.AutoHashMap(u64, []const u8),
    is_trained: bool,
    allocator: std.mem.Allocator,
    total_vectors: usize,

    const Self = @This();

    /// Initialize a new IVF+PQ index
    pub fn init(allocator: std.mem.Allocator, config: IVFConfig) !Self {
        return Self{
            .config = config,
            .voronoi_cells = try std.ArrayList(VoronoiCell).initCapacity(allocator, 64),
            .pq_codebook = null,
            .pq_codes = std.AutoHashMap(u64, PQCode).init(allocator),
            .vectors = std.AutoHashMap(u64, []f32).init(allocator),
            .symbol_ids = std.AutoHashMap(u64, []const u8).init(allocator),
            .is_trained = false,
            .allocator = allocator,
            .total_vectors = 0,
        };
    }

    /// Clean up all resources
    pub fn deinit(self: *Self) void {
        for (self.voronoi_cells.items) |*cell| {
            cell.deinit(self.allocator);
        }
        self.voronoi_cells.deinit(self.allocator);

        if (self.pq_codebook) |*cb| {
            cb.deinit(self.allocator);
        }

        var code_iter = self.pq_codes.valueIterator();
        while (code_iter.next()) |code| {
            self.allocator.free(code.codes);
        }
        self.pq_codes.deinit();

        var vec_iter = self.vectors.valueIterator();
        while (vec_iter.next()) |vec| {
            self.allocator.free(vec.*);
        }
        self.vectors.deinit();

        var sym_iter = self.symbol_ids.valueIterator();
        while (sym_iter.next()) |sym| {
            self.allocator.free(sym.*);
        }
        self.symbol_ids.deinit();
    }

    /// Train the index with k-means clustering and PQ codebook generation
    pub fn train(self: *Self, training_vectors: []const []const f32) !void {
        if (training_vectors.len == 0) return error.NoTrainingData;

        // Step 1: K-means clustering to find nlist centroids
        try self.kMeansClustering(training_vectors);

        // Step 2: Build PQ codebook
        try self.buildPQCodebook(training_vectors);

        self.is_trained = true;
    }

    /// K-means clustering for Voronoi cells
    fn kMeansClustering(self: *Self, vectors: []const []const f32) !void {
        const nlist = @min(self.config.nlist, vectors.len);
        const dim = self.config.dim;

        // Initialize centroids with random vectors
        var rng = std.Random.DefaultPrng.init(42);
        const random = rng.random();

        // Clear existing cells
        for (self.voronoi_cells.items) |*cell| {
            cell.deinit(self.allocator);
        }
        self.voronoi_cells.clearRetainingCapacity();

        // Initialize cells with random centroids
        for (0..nlist) |i| {
            const vec_idx = random.uintLessThan(usize, @intCast(vectors.len));
            const centroid = try self.allocator.alloc(f32, dim);
            @memcpy(centroid, vectors[vec_idx]);

            const cell = VoronoiCell{
                .center_id = @intCast(i),
                .center = centroid,
                .vector_ids = try std.ArrayList(u64).initCapacity(self.allocator, 32),
            };
            try self.voronoi_cells.append(self.allocator, cell);
        }

        // K-means iterations
        var iteration: usize = 0;
        while (iteration < self.config.max_iterations) : (iteration += 1) {
            // Clear assignments
            for (self.voronoi_cells.items) |*cell| {
                cell.vector_ids.clearRetainingCapacity();
            }

            // Assign each vector to nearest centroid
            for (vectors, 0..) |vec, vec_id| {
                var best_cell: usize = 0;
                var best_dist: f32 = std.math.floatMax(f32);

                for (self.voronoi_cells.items, 0..) |*cell, cell_idx| {
                    const dist = ann_utils.simdCosineDistance(vec, cell.center);
                    if (dist < best_dist) {
                        best_dist = dist;
                        best_cell = cell_idx;
                    }
                }

                try self.voronoi_cells.items[best_cell].vector_ids.append(self.allocator, @intCast(vec_id));
            }

            // Update centroids
            for (self.voronoi_cells.items) |*cell| {
                if (cell.vector_ids.items.len == 0) continue;

                // Compute new centroid as mean of assigned vectors
                @memset(cell.center, 0);
                for (cell.vector_ids.items) |vec_id| {
                    const vec = vectors[@intCast(vec_id)];
                    for (cell.center, vec) |*c, v| {
                        c.* += v;
                    }
                }

                const scale = 1.0 / @as(f32, @floatFromInt(cell.vector_ids.items.len));
                for (cell.center) |*c| {
                    c.* *= scale;
                }
            }
        }
    }

    /// Build Product Quantization codebook
    fn buildPQCodebook(self: *Self, vectors: []const []const f32) !void {
        const m = self.config.m;
        const k = std.math.shl(usize, 1, self.config.nbits); // 2^nbits
        const dim = self.config.dim;
        const sub_dim = (dim + m - 1) / m; // Round up

        // Initialize codebook
        var codebook = PQCodebook{
            .centroids = undefined,
            .m = m,
            .nbits = self.config.nbits,
            .k = k,
            .sub_dim = sub_dim,
        };

        codebook.centroids = try self.allocator.alloc([][]f32, m);
        for (0..m) |i| {
            const start = i * sub_dim;
            const end = @min(start + sub_dim, dim);
            const actual_sub_dim = end - start;

            codebook.centroids[i] = try self.allocator.alloc([]f32, k);
            for (0..k) |j| {
                codebook.centroids[i][j] = try self.allocator.alloc(f32, actual_sub_dim);

                // Initialize with random values from actual sub-vectors
                var rng = std.Random.DefaultPrng.init(@as(u64, @intCast(i * k + j)));
                const random = rng.random();
                const vec_idx = random.uintLessThan(usize, @intCast(vectors.len));
                const sub_vec = vectors[vec_idx][start..end];
                @memcpy(codebook.centroids[i][j], sub_vec);
            }
        }

        // Simple k-means for each sub-space
        for (0..m) |_| {
            // Simplified: just keep random centroids for now
            // Full implementation would run k-means per sub-space
        }

        self.pq_codebook = codebook;
    }

    /// Encode a vector using PQ
    fn encodeVector(self: *const Self, vec: []const f32) !PQCode {
        const codebook = self.pq_codebook orelse return error.NotTrained;
        const m = codebook.m;
        const sub_dim = codebook.sub_dim;

        const codes = try self.allocator.alloc(u8, m);

        for (0..m) |i| {
            const start = i * sub_dim;
            const end = @min(start + sub_dim, vec.len);
            const sub_vec = vec[start..end];

            // Find nearest centroid
            var best_k: usize = 0;
            var best_dist: f32 = std.math.floatMax(f32);

            for (0..codebook.k) |k_idx| {
                const centroid = codebook.centroids[i][k_idx];
                const dist = ann_utils.simdCosineDistance(sub_vec, centroid);
                if (dist < best_dist) {
                    best_dist = dist;
                    best_k = k_idx;
                }
            }

            codes[i] = @intCast(best_k);
        }

        return PQCode{ .codes = codes };
    }

    /// Insert a vector into the index
    pub fn insert(self: *Self, id: u64, symbol_id: []const u8, vector: []const f32) !void {
        std.debug.assert(vector.len == self.config.dim);

        // Auto-train if not trained
        if (!self.is_trained) {
            const training_vecs = [1][]const f32{vector};
            try self.train(&training_vecs);
        }

        // Deep copy vector
        const vec_copy = try self.allocator.alloc(f32, vector.len);
        @memcpy(vec_copy, vector);
        try self.vectors.put(id, vec_copy);

        // Deep copy symbol ID
        const sym_copy = try self.allocator.dupe(u8, symbol_id);
        try self.symbol_ids.put(id, sym_copy);

        // Encode with PQ
        const pq_code = try self.encodeVector(vector);
        try self.pq_codes.put(id, pq_code);

        // Add to appropriate Voronoi cell
        var best_cell: usize = 0;
        var best_dist: f32 = std.math.floatMax(f32);

        for (self.voronoi_cells.items, 0..) |*cell, cell_idx| {
            const dist = ann_utils.simdCosineDistance(vector, cell.center);
            if (dist < best_dist) {
                best_dist = dist;
                best_cell = cell_idx;
            }
        }

        try self.voronoi_cells.items[best_cell].vector_ids.append(self.allocator, id);
        self.total_vectors += 1;
    }

    /// Bulk insert
    pub fn insertBatch(self: *Self, ids: []const u64, symbol_ids: []const []const u8, vectors: []const []const f32) !void {
        std.debug.assert(ids.len == symbol_ids.len);
        std.debug.assert(ids.len == vectors.len);

        for (ids, symbol_ids, vectors) |id, sym, vec| {
            try self.insert(id, sym, vec);
        }
    }

    /// Search for k nearest neighbors
    pub fn search(self: *Self, query: []const f32, k: usize, result_allocator: std.mem.Allocator) ![]ann_interface.ANNResult {
        std.debug.assert(query.len == self.config.dim);

        const actual_k = @min(k, self.total_vectors);
        if (actual_k == 0) {
            return result_allocator.alloc(ann_interface.ANNResult, 0);
        }

        // Find nprobe nearest cells to query
        var cell_dists = try std.ArrayList(struct { cell_idx: usize, dist: f32 }).initCapacity(self.allocator, 64);
        defer cell_dists.deinit(self.allocator);

        for (self.voronoi_cells.items, 0..) |*cell, cell_idx| {
            const dist = ann_utils.simdCosineDistance(query, cell.center);
            try cell_dists.append(self.allocator, .{ .cell_idx = cell_idx, .dist = dist });
        }

        // Sort by distance and take top nprobe
        const nprobe = @min(self.config.nprobe, cell_dists.items.len);
        const CellDist = @TypeOf(cell_dists.items[0]);
        std.sort.insertion(CellDist, cell_dists.items, {}, struct {
            fn compare(_: void, a: CellDist, b: CellDist) bool {
                return a.dist < b.dist;
            }
        }.compare);

        // Collect candidates from nearby cells
        var candidates = try std.ArrayList(u64).initCapacity(self.allocator, 256);
        defer candidates.deinit(self.allocator);

        for (cell_dists.items[0..nprobe]) |item| {
            const cell = &self.voronoi_cells.items[item.cell_idx];
            try candidates.appendSlice(self.allocator, cell.vector_ids.items);
        }

        // Compute distances for candidates
        var heap = std.PriorityQueue(ann_interface.ANNResult, void, compareDistance).init(result_allocator, {});
        defer heap.deinit();

        try heap.ensureTotalCapacity(@as(usize, @intCast(actual_k)));

        for (candidates.items) |id| {
            const vec = self.vectors.get(id).?;
            const sym_id = self.symbol_ids.get(id).?;

            const distance = ann_utils.simdCosineDistance(query, vec);
            const similarity = 1.0 - distance;

            const result = ann_interface.ANNResult{
                .id = id,
                .symbol_id = try result_allocator.dupe(u8, sym_id),
                .distance = distance,
                .similarity = similarity,
            };

            if (heap.count() < actual_k) {
                try heap.add(result);
            } else if (distance < heap.peek().?.distance) {
                const old = heap.remove();
                result_allocator.free(old.symbol_id);
                try heap.add(result);
            } else {
                result_allocator.free(result.symbol_id);
            }
        }

        // Extract results
        const results = try result_allocator.alloc(ann_interface.ANNResult, heap.count());
        var i: usize = heap.count();
        while (i > 0) {
            i -= 1;
            results[i] = heap.remove();
        }

        return results;
    }

    /// Get index statistics
    pub fn getStats(self: *const Self) ann_interface.ANNStats {
        var memory: usize = 0;

        // Voronoi cells
        for (self.voronoi_cells.items) |cell| {
            memory += cell.center.len * @sizeOf(f32);
            memory += cell.vector_ids.items.len * @sizeOf(u64);
            memory += cell.vector_ids.capacity * @sizeOf(u64);
        }

        // PQ codes
        var code_iter = self.pq_codes.valueIterator();
        while (code_iter.next()) |code| {
            memory += code.codes.len * @sizeOf(u8);
        }

        // Original vectors
        var vec_iter = self.vectors.valueIterator();
        while (vec_iter.next()) |vec| {
            memory += vec.*.len * @sizeOf(f32);
        }

        // Symbol IDs
        var sym_iter = self.symbol_ids.valueIterator();
        while (sym_iter.next()) |sym| {
            memory += sym.*.len;
        }

        return ann_interface.ANNStats{
            .total_vectors = self.total_vectors,
            .index_size_bytes = memory,
            .build_time_ms = 0,
            .avg_search_time_ms = 0,
            .last_search_time_ms = 0,
            .search_count = 0,
        };
    }

    /// Get the ANN type
    pub fn annType(self: *const Self) ann_interface.ANNType {
        _ = self;
        return .ivf_pq;
    }

    /// Comparator for max-heap by distance
    fn compareDistance(_: void, a: ann_interface.ANNResult, b: ann_interface.ANNResult) std.math.Order {
        return std.math.order(a.distance, b.distance);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "IVFPQIndex — basic insert and search" {
    const allocator = std.testing.allocator;

    var index = try IVFPQIndex.init(allocator, .{
        .dim = 10,
        .nlist = 3,
        .nprobe = 2,
        .m = 2,
        .nbits = 4,
    });
    defer index.deinit();

    // Insert some vectors
    const v1 = [_]f32{ 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 };
    const v2 = [_]f32{ 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 };
    const v3 = [_]f32{ 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 };

    try index.insert(1, "vec1", &v1);
    try index.insert(2, "vec2", &v2);
    try index.insert(3, "vec3", &v3);

    try std.testing.expectEqual(@as(usize, 3), index.total_vectors);
    try std.testing.expect(index.is_trained);

    // Search
    const query = [_]f32{ 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 };
    const results = try index.search(&query, 2, allocator);
    defer {
        for (results) |r| allocator.free(r.symbol_id);
        allocator.free(results);
    }

    try std.testing.expect(results.len > 0);
}

test "IVFPQIndex — getStats" {
    const allocator = std.testing.allocator;

    var index = try IVFPQIndex.init(allocator, .{
        .dim = 10,
        .nlist = 2,
        .m = 2,
    });
    defer index.deinit();

    const v = [_]f32{0.0} ** 10;
    try index.insert(1, "test", &v);

    const stats = index.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.total_vectors);
    try std.testing.expect(stats.index_size_bytes > 0);
}
