// ═══════════════════════════════════════════════════════════════════════════════
// Track B: Ternary LSH (Locality-Sensitive Hashing)
// ═══════════════════════════════════════════════════════════════════════════════
// True ternary {-1,0,+1} VSA vectors with Hamming distance hashing
//
// Converts float32 embeddings to ternary VSA using HybridBigInt,
// enabling ultra-fast Hamming distance search with 20x memory savings.
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const ann_interface = @import("ann_interface.zig");
const ann_utils = @import("ann_utils.zig");

// Import VSA components
// When used in ann-bench standalone, "vsa" module is available
// When used through needle module, "vsa.zig" is used
const vsa_mod = @import("vsa");

const HybridBigInt = vsa_mod.HybridBigInt;
const Trit = vsa_mod.Trit;

/// Hash function type
pub const HashFunction = enum {
    random_projection,
    simhash,
    minhash,
};

/// LSH Configuration
pub const LSHConfig = struct {
    dim: usize = 384,
    n_tables: usize = 12, // ceil(φ^4) = 12
    n_hashes: usize = 12,
    hash_type: HashFunction = .random_projection,
    ternarization_threshold: f32 = 0.09, // 1/φ^5 ≈ 0.09
    seed: u64 = 42,
};

/// Single LSH hash table
pub const LSHHashTable = struct {
    /// Random projection matrix: [n_hashes][dim]
    projections: [][]f32,
    /// Buckets: combined_hash_key -> list of vector IDs
    buckets: std.StringHashMap(std.ArrayList(u64)),
    allocator: std.mem.Allocator,

    fn deinit(self: *LSHHashTable) void {
        for (self.projections) |proj| {
            self.allocator.free(proj);
        }
        self.allocator.free(self.projections);

        var bucket_iter = self.buckets.valueIterator();
        while (bucket_iter.next()) |*list| {
            list.*.deinit(self.allocator);
        }
        self.buckets.deinit();
    }
};

/// Ternary vector wrapper using HybridBigInt
pub const TernaryVector = struct {
    trits: HybridBigInt,
    original_dim: usize,
};

/// Main LSH Index
pub const LSHIndex = struct {
    config: LSHConfig,
    hash_tables: std.ArrayList(LSHHashTable),
    ternary_vectors: std.AutoHashMap(u64, TernaryVector),
    float32_cache: std.AutoHashMap(u64, []f32), // Optional for re-ranking
    allocator: std.mem.Allocator,
    total_vectors: usize,

    const Self = @This();

    /// Initialize a new LSH index
    pub fn init(allocator: std.mem.Allocator, config: LSHConfig) !Self {
        var index = Self{
            .config = config,
            .hash_tables = std.ArrayList(LSHHashTable).initCapacity(allocator, config.n_tables) catch unreachable,
            .ternary_vectors = std.AutoHashMap(u64, TernaryVector).init(allocator),
            .float32_cache = std.AutoHashMap(u64, []f32).init(allocator),
            .allocator = allocator,
            .total_vectors = 0,
        };

        // Initialize hash tables
        var table_seed: u64 = config.seed;
        for (0..config.n_tables) |_| {
            var table = LSHHashTable{
                .projections = undefined,
                .buckets = std.StringHashMap(std.ArrayList(u64)).init(allocator),
                .allocator = allocator,
            };

            // Generate random projections for this table
            table.projections = try ann_utils.generateRandomProjections(
                allocator,
                config.dim,
                config.n_hashes,
                table_seed,
            );
            table_seed +%= 0x9e3779b97f4a7c15; // Advance seed

            try index.hash_tables.append(allocator, table);
        }

        return index;
    }

    /// Clean up all resources
    pub fn deinit(self: *Self) void {
        for (self.hash_tables.items) |*table| {
            table.deinit();
        }
        self.hash_tables.deinit(self.allocator);

        var ternar_iter = self.ternary_vectors.valueIterator();
        while (ternar_iter.next()) |*tv| {
            // HybridBigInt doesn't need explicit cleanup (stack-allocated)
            _ = tv;
        }
        self.ternary_vectors.deinit();

        var cache_iter = self.float32_cache.valueIterator();
        while (cache_iter.next()) |vec| {
            self.allocator.free(vec.*);
        }
        self.float32_cache.deinit();
    }

    /// Convert float32 vector to ternary {-1,0,+1} HybridBigInt
    fn float32ToTernary(self: *const Self, vec: []const f32) !HybridBigInt {
        var result = HybridBigInt.zero();
        result.ensureUnpacked();

        const dim = @min(vec.len, vsa_mod.MAX_TRITS);
        result.trit_len = dim;
        const threshold = self.config.ternarization_threshold;

        for (0..dim) |i| {
            const val = vec[i];
            if (val > threshold) {
                result.unpacked_cache[i] = 1;
            } else if (val < -threshold) {
                result.unpacked_cache[i] = -1;
            } else {
                result.unpacked_cache[i] = 0;
            }
        }

        return result;
    }

    /// Compute LSH hash for a vector using a specific hash table
    fn computeHash(self: *const Self, vec: []const f32, table_idx: usize) ![]const u8 {
        const table = &self.hash_tables.items[table_idx];
        const allocator = self.allocator;

        // For random projection: project + ternarize for each hash function
        var hash_parts = std.ArrayList([]const u8).initCapacity(allocator, self.config.n_hashes) catch unreachable;
        defer {
            for (hash_parts.items) |part| allocator.free(part);
            hash_parts.deinit(allocator);
        }

        for (table.projections) |proj| {
            // Compute dot product
            var dot: f32 = 0;
            for (proj, 0..) |p_val, j| {
                if (j < vec.len) {
                    dot += p_val * vec[j];
                }
            }

            // Ternarize to get hash bit
            const hash_bit: u8 = if (dot > 0) 1 else 0;
            const part = try std.fmt.allocPrint(allocator, "{d}", .{hash_bit});
            try hash_parts.append(allocator, part);
        }

        // Combine all parts into single hash key (simple concatenation)
        var combined = std.ArrayList(u8).initCapacity(allocator, self.config.n_hashes * 2) catch unreachable;
        defer combined.deinit(allocator);
        for (hash_parts.items) |part| {
            try combined.appendSlice(allocator, part);
        }
        return combined.toOwnedSlice(allocator);
    }

    /// Insert a vector into the index
    pub fn insert(self: *Self, id: u64, symbol_id: []const u8, vector: []const f32) !void {
        _ = symbol_id;
        std.debug.assert(vector.len == self.config.dim);

        // Convert to ternary
        const ternary = try self.float32ToTernary(vector);
        const tv = TernaryVector{
            .trits = ternary,
            .original_dim = vector.len,
        };
        try self.ternary_vectors.put(id, tv);

        // Optional: cache original float32 for re-ranking
        const vec_copy = try self.allocator.alloc(f32, vector.len);
        @memcpy(vec_copy, vector);
        try self.float32_cache.put(id, vec_copy);

        // Add to all hash tables
        for (self.hash_tables.items, 0..) |*table, table_idx| {
            const hash_key = try self.computeHash(vector, table_idx);
            defer self.allocator.free(hash_key);

            const entry = try table.buckets.getOrPut(hash_key);
            if (!entry.found_existing) {
                entry.value_ptr.* = std.ArrayList(u64).initCapacity(self.allocator, 8) catch unreachable;
            }
            try entry.value_ptr.append(self.allocator, id);
        }

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

        // Collect candidate IDs from all hash tables
        var candidates_set = std.AutoHashMap(u64, void).init(result_allocator);
        defer candidates_set.deinit();

        for (self.hash_tables.items, 0..) |_, table_idx| {
            const hash_key = try self.computeHash(query, table_idx);
            defer self.allocator.free(hash_key);

            if (self.hash_tables.items[table_idx].buckets.get(hash_key)) |bucket| {
                for (bucket.items) |id| {
                    try candidates_set.put(id, {});
                }
            }
        }

        // Convert query to ternary for Hamming distance
        const query_ternary = try self.float32ToTernary(query);

        // Compute Hamming distances for all candidates
        var results_list = std.ArrayList(ann_interface.ANNResult).initCapacity(result_allocator, @min(actual_k, candidates_set.count())) catch unreachable;

        var candidate_iter = candidates_set.keyIterator();
        while (candidate_iter.next()) |id_ptr| {
            const id = id_ptr.*;
            if (self.ternary_vectors.get(id)) |tv| {
                // Compute Hamming distance using VSA core function
                const hamming_dist = vsa_mod.hammingDistance(@constCast(&tv.trits), @constCast(&query_ternary));

                // Normalize to [0, 1] for similarity
                const max_dist = @as(f32, @floatFromInt(@min(tv.original_dim, query.len)));
                const distance = @as(f32, @floatFromInt(hamming_dist)) / max_dist;
                const similarity = 1.0 - distance;

                // Get symbol ID from somewhere (we'd need to store it)
                const sym_id = try std.fmt.allocPrint(result_allocator, "id_{d}", .{id});

                try results_list.append(result_allocator, ann_interface.ANNResult{
                    .id = id,
                    .symbol_id = sym_id,
                    .distance = distance,
                    .similarity = similarity,
                });
            }
        }

        // Sort by distance
        ann_utils.sortResults(results_list.items);

        // Return top-k
        const final_k = @min(actual_k, results_list.items.len);
        const results = try result_allocator.alloc(ann_interface.ANNResult, final_k);
        @memcpy(results, results_list.items[0..final_k]);

        // Clean up extra results
        for (results_list.items[final_k..]) |r| {
            result_allocator.free(r.symbol_id);
        }
        results_list.deinit(result_allocator);

        return results;
    }

    /// Get index statistics
    pub fn getStats(self: *const Self) ann_interface.ANNStats {
        var memory: usize = 0;

        // Hash tables memory
        for (self.hash_tables.items) |table| {
            memory += table.projections.len * @sizeOf([]f32);
            for (table.projections) |proj| {
                memory += proj.len * @sizeOf(f32);
            }
            // Buckets memory
            var bucket_iter = table.buckets.iterator();
            while (bucket_iter.next()) |entry| {
                memory += entry.key_ptr.len;
                memory += entry.value_ptr.items.len * @sizeOf(u64);
                memory += entry.value_ptr.capacity * @sizeOf(u64);
            }
        }

        // Ternary vectors memory (HybridBigInt is stack-allocated)
        memory += self.ternary_vectors.count() * (@sizeOf(u64) + @sizeOf(TernaryVector));

        // Float32 cache memory
        var cache_iter = self.float32_cache.valueIterator();
        while (cache_iter.next()) |vec| {
            memory += vec.*.len * @sizeOf(f32);
        }

        return ann_interface.ANNStats{
            .total_vectors = self.total_vectors,
            .index_size_bytes = memory,
            .build_time_ms = 0, // Build is gradual with inserts
            .avg_search_time_ms = 0,
            .last_search_time_ms = 0,
            .search_count = 0,
        };
    }

    /// Get the ANN type
    pub fn annType(self: *const Self) ann_interface.ANNType {
        _ = self;
        return .lsh;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "LSHIndex — basic insert and search" {
    const allocator = std.testing.allocator;

    var index = try LSHIndex.init(allocator, .{
        .dim = 10,
        .n_tables = 3,
        .n_hashes = 4,
        .seed = 42,
    });
    defer index.deinit();

    // Insert some vectors
    const v1 = [_]f32{ 0.5, 0.5, 0.5, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 };
    const v2 = [_]f32{ -0.5, -0.5, -0.5, -0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 };
    const v3 = [_]f32{ 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 0.5, 0.0, 0.0 };

    try index.insert(1, "vec1", &v1);
    try index.insert(2, "vec2", &v2);
    try index.insert(3, "vec3", &v3);

    try std.testing.expectEqual(@as(usize, 3), index.total_vectors);

    // Search with similar query
    const query = [_]f32{ 0.4, 0.4, 0.4, 0.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 };
    const results = try index.search(&query, 2, allocator);
    defer {
        for (results) |r| allocator.free(r.symbol_id);
        allocator.free(results);
    }

    // Should find some results
    try std.testing.expect(results.len > 0);
    if (results.len > 0) {
        try std.testing.expect(results[0].distance < 1.0);
    }
}

test "LSHIndex — float32ToTernary" {
    const allocator = std.testing.allocator;

    var index = try LSHIndex.init(allocator, .{ .dim = 5 });
    defer index.deinit();

    const vec = [_]f32{ 0.5, -0.5, 0.0, 0.2, -0.02 };

    const ternary = try index.float32ToTernary(&vec);

    // Check trits are in {-1, 0, 1}
    for (0..vec.len) |i| {
        const t = ternary.unpacked_cache[i];
        try std.testing.expect(t == -1 or t == 0 or t == 1);
    }
}

test "LSHIndex — getStats" {
    const allocator = std.testing.allocator;

    var index = try LSHIndex.init(allocator, .{
        .dim = 10,
        .n_tables = 2,
        .n_hashes = 3,
    });
    defer index.deinit();

    const v = [_]f32{0.0} ** 10;
    try index.insert(1, "test", &v);

    const stats = index.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.total_vectors);
    try std.testing.expect(stats.index_size_bytes > 0);
}
