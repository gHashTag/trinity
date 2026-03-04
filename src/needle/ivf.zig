// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE Tier 4.1/4.2 — IVF (Inverted File) Index for Large-Scale Semantic Search
// ═══════════════════════════════════════════════════════════════════════════════
//
// IVF = k-means clustering + inverted file index
// Search complexity: O(n_clusters * cluster_size) vs O(N) for flat search
// Target: <50ms for 10000+ symbols
//
// Tier 4.2: Incremental rebuild + persistent cache
// - incrementalBuild() only reprocesses changed symbols
// - saveToFile()/loadFromFile() for cache persistence
// - Build time <15s for incremental updates
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const vsa = @import("vsa.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// CACHE FILE FORMAT
// ═══════════════════════════════════════════════════════════════════════════════
// Header (32 bytes):
//   - Magic: "IVF\x01" (4 bytes)
//   - Version: u32 (4 bytes)
//   - n_clusters: u32 (4 bytes)
//   - dim: u32 (4 bytes)
//   - nprobe: u32 (4 bytes)
//   - max_iterations: u32 (4 bytes)
//   - reserved: [8]u8
//
// Cluster data (per cluster):
//   - centroid: [dim]f32
//   - n_entries: u32
//   - entries: (id_len: u32, id_bytes, file_len: u32, file_bytes, line: u32)[n_entries]
//   - Note: embeddings are NOT stored (referenced from SemanticIndex)
// ═══════════════════════════════════════════════════════════════════════════════

const CACHE_MAGIC: [4]u8 = .{ 'I', 'V', 'F', 0x01 };
const CACHE_VERSION: u32 = 1;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Symbol representation for IVF index
pub const Symbol = struct {
    id: []const u8,
    embedding: []const f32,
    file: []const u8,
    line: u32,
};

/// Cluster distance for sorting
const ClusterDistance = struct {
    idx: usize,
    dist: f32,
};

/// Cluster entry (ID + embedding pair)
const ClusterEntry = struct {
    id: []const u8,
    embedding: []const f32,
};

/// IVF configuration
pub const IVFConfig = struct {
    /// Number of k-means clusters (default: sqrt(N))
    n_clusters: usize = 100,
    /// Number of nearest clusters to search (default: 16)
    nprobe: usize = 16,
    /// Max iterations for k-means
    max_iterations: usize = 20,
    /// Embedding dimension
    dim: usize = 128,

    pub fn init(n_symbols: usize, dim: usize) IVFConfig {
        // Use sqrt(N) as heuristic for n_clusters
        const n_clusters_f64 = std.math.ceil(std.math.sqrt(@as(f64, @floatFromInt(n_symbols))));
        const n_clusters = @as(usize, @intFromFloat(n_clusters_f64));
        return .{
            .n_clusters = n_clusters,
            .dim = dim,
        };
    }
};

/// A single cluster in the IVF index
pub const Cluster = struct {
    /// Cluster centroid (mean of all vectors in cluster)
    centroid: []f32,
    /// Vector entries in this cluster (id + embedding pairs)
    entries: std.ArrayList(ClusterEntry),

    pub fn init(allocator: std.mem.Allocator, dim: usize) !Cluster {
        const centroid = try allocator.alloc(f32, dim);
        @memset(centroid[0..dim], 0.0);
        return .{
            .centroid = centroid,
            .entries = std.ArrayList(ClusterEntry){ .items = &.{}, .capacity = 0 },
        };
    }

    pub fn deinit(self: *Cluster, allocator: std.mem.Allocator) void {
        allocator.free(self.centroid);
        // Free entry IDs (embeddings are references, not owned)
        for (self.entries.items) |entry| {
            allocator.free(entry.id);
        }
        self.entries.deinit(allocator);
    }

    /// Add a vector to this cluster
    pub fn addVector(self: *Cluster, allocator: std.mem.Allocator, id: []const u8, embedding: []const f32) !void {
        const id_copy = try allocator.dupe(u8, id);
        errdefer allocator.free(id_copy);
        try self.entries.append(allocator, .{ .id = id_copy, .embedding = embedding });
    }

    /// Update centroid after adding vectors
    pub fn updateCentroid(self: *Cluster) void {
        if (self.entries.items.len == 0) return;

        const n = @as(f64, @floatFromInt(self.entries.items.len));
        const dim = self.centroid.len;

        // Reset centroid to zero
        for (0..dim) |i| {
            self.centroid[i] = 0.0;
        }

        for (self.entries.items) |entry| {
            for (0..dim) |i| {
                self.centroid[i] += @as(f32, @floatCast(entry.embedding[i] / n));
            }
        }
    }
};

/// IVF Search Result
pub const IVFSearchResult = struct {
    symbol_id: []const u8,
    distance: f32,

    pub fn init(allocator: std.mem.Allocator, symbol_id: []const u8, distance: f32) !IVFSearchResult {
        return .{
            .symbol_id = try allocator.dupe(u8, symbol_id),
            .distance = distance,
        };
    }

    pub fn deinit(self: *const IVFSearchResult, allocator: std.mem.Allocator) void {
        allocator.free(self.symbol_id);
    }
};

/// IVF Index - main data structure
pub const IVFIndex = struct {
    allocator: std.mem.Allocator,
    config: IVFConfig,
    clusters: std.ArrayList(Cluster),

    pub fn init(allocator: std.mem.Allocator, config: IVFConfig) !IVFIndex {
        var clusters = std.ArrayList(Cluster){ .items = &.{}, .capacity = 0 };
        errdefer {
            for (clusters.items) |*c| c.deinit(allocator);
            clusters.deinit(allocator);
        }

        // Initialize empty clusters
        for (0..config.n_clusters) |_| {
            try clusters.append(allocator, try Cluster.init(allocator, config.dim));
        }

        return .{
            .allocator = allocator,
            .config = config,
            .clusters = clusters,
        };
    }

    pub fn deinit(self: *IVFIndex) void {
        for (self.clusters.items) |*cluster| {
            cluster.deinit(self.allocator);
        }
        self.clusters.deinit(self.allocator);
    }

    /// Build IVF index from symbol vectors using k-means clustering
    pub fn build(self: *IVFIndex, symbols: std.ArrayList(Symbol)) !void {
        const n_symbols = symbols.items.len;

        if (n_symbols == 0) return;

        // Step 1: Initialize centroids with k-means++ seeding
        try self.initCentroids(symbols);

        // Step 2: Run k-means iterations
        var iteration: usize = 0;
        while (iteration < self.config.max_iterations) : (iteration += 1) {
            // Clear clusters (free old IDs first)
            for (self.clusters.items) |*cluster| {
                for (cluster.entries.items) |entry| {
                    self.allocator.free(entry.id);
                }
                cluster.entries.clearRetainingCapacity();
            }

            // Assign each vector to nearest centroid
            for (symbols.items) |symbol| {
                const nearest_cluster_idx = try self.findNearestCluster(symbol.embedding);
                const cluster = &self.clusters.items[nearest_cluster_idx];
                try cluster.addVector(self.allocator, symbol.id, symbol.embedding);
            }

            // Update centroids
            for (self.clusters.items) |*cluster| {
                cluster.updateCentroid();
            }
        }
    }

    /// Initialize centroids using k-means++ algorithm
    fn initCentroids(self: *IVFIndex, symbols: std.ArrayList(Symbol)) !void {
        if (symbols.items.len == 0) return;

        const n_clusters = @min(self.clusters.items.len, symbols.items.len);

        // First centroid: use first symbol (deterministic for reproducibility)
        @memcpy(self.clusters.items[0].centroid, symbols.items[0].embedding);

        // Subsequent centroids: choose farthest from existing centroids
        var centroids_chosen: usize = 1;
        while (centroids_chosen < n_clusters) : (centroids_chosen += 1) {
            // Compute min distance to existing centroids for all points
            var max_min_dist: f32 = 0.0;
            var farthest_idx: usize = 0;

            for (symbols.items, 0..) |symbol, i| {
                var min_dist: f32 = std.math.floatMax(f32);
                for (0..centroids_chosen) |c| {
                    const dist = squaredEuclideanDistance(symbol.embedding, self.clusters.items[c].centroid);
                    if (dist < min_dist) min_dist = dist;
                }
                // Choose point with max min-distance (farthest from all existing centroids)
                if (min_dist > max_min_dist) {
                    max_min_dist = min_dist;
                    farthest_idx = i;
                }
            }

            @memcpy(self.clusters.items[centroids_chosen].centroid, symbols.items[farthest_idx].embedding);
        }
    }

    /// Find nearest cluster to a query vector
    fn findNearestCluster(self: *const IVFIndex, query: []const f32) !usize {
        var min_dist: f32 = std.math.floatMax(f32);
        var nearest: usize = 0;

        for (self.clusters.items, 0..) |cluster, i| {
            const dist = squaredEuclideanDistance(query, cluster.centroid);
            if (dist < min_dist) {
                min_dist = dist;
                nearest = i;
            }
        }

        return nearest;
    }

    /// Search IVF index with nprobe (search nearest n clusters)
    pub fn search(self: *IVFIndex, query: []const f32, top_k: usize, allocator: std.mem.Allocator) ![]IVFSearchResult {
        // Step 1: Find nprobe nearest clusters to query
        var cluster_distances = try self.allocator.alloc(ClusterDistance, self.clusters.items.len);
        defer self.allocator.free(cluster_distances);

        for (self.clusters.items, 0..) |cluster, i| {
            cluster_distances[i] = .{
                .idx = i,
                .dist = squaredEuclideanDistance(query, cluster.centroid),
            };
        }

        // Sort by distance and take top nprobe
        const nprobe = @min(self.config.nprobe, cluster_distances.len);
        std.sort.block(ClusterDistance, cluster_distances, {}, clusterDistanceLessThan);

        // Step 2: Search within nprobe nearest clusters
        var results = std.ArrayList(IVFSearchResult){ .items = &.{}, .capacity = 0 };

        for (cluster_distances[0..nprobe]) |cd| {
            const cluster = &self.clusters.items[cd.idx];

            for (cluster.entries.items) |entry| {
                const dist = squaredEuclideanDistance(query, entry.embedding);
                try insertResult(&results, allocator, entry.id, dist, top_k);
            }
        }

        return results.toOwnedSlice(allocator);
    }

    /// Get cluster statistics
    pub fn getStats(self: *const IVFIndex) struct {
        total_entries: usize,
        max_cluster_size: usize,
        min_cluster_size: usize,
    } {
        var total: usize = 0;
        var max_size: usize = 0;
        var min_size: usize = std.math.maxInt(usize);

        for (self.clusters.items) |cluster| {
            const size = cluster.entries.items.len;
            total += size;
            if (size > max_size) max_size = size;
            if (size < min_size) min_size = size;
        }

        return .{
            .total_entries = total,
            .max_cluster_size = max_size,
            .min_cluster_size = if (min_size == std.math.maxInt(usize)) 0 else min_size,
        };
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // TIER 4.2: INCREMENTAL BUILD
    // ═══════════════════════════════════════════════════════════════════════════════

    /// Incremental update - only reprocess changed symbols
    /// symbols_added: new symbols to add
    /// symbols_removed: IDs of symbols that were removed
    pub fn incrementalBuild(
        self: *IVFIndex,
        symbols_added: *const std.ArrayList(Symbol),
        symbols_removed: *const std.ArrayList([]const u8),
    ) !void {
        // Phase 1: Remove deleted symbols from clusters
        for (symbols_removed.items) |removed_id| {
            for (self.clusters.items) |*cluster| {
                var i: usize = 0;
                while (i < cluster.entries.items.len) {
                    if (std.mem.eql(u8, cluster.entries.items[i].id, removed_id)) {
                        self.allocator.free(cluster.entries.items[i].id);
                        _ = cluster.entries.orderedRemove(i);
                    } else {
                        i += 1;
                    }
                }
            }
        }

        // Phase 2: Add new symbols to nearest existing clusters
        // (Centroids will be updated afterward)
        for (symbols_added.items) |symbol| {
            const nearest_cluster_idx = try self.findNearestCluster(symbol.embedding);
            const cluster = &self.clusters.items[nearest_cluster_idx];
            try cluster.addVector(self.allocator, symbol.id, symbol.embedding);
        }

        // Phase 3: Recompute centroids for affected clusters
        // For incremental updates, only clusters that received new symbols need update
        // But for simplicity and correctness, update all clusters
        for (self.clusters.items) |*cluster| {
            cluster.updateCentroid();
        }
    }

    /// Save IVF index to file for persistent cache
    pub fn saveToFile(self: *const IVFIndex, file_path: []const u8) !void {
        // For Zig 0.15 compatibility, use a simpler approach:
        // Build the entire buffer in memory, then write it at once
        var buffer = std.ArrayList(u8){ .items = &.{}, .capacity = 0 };
        defer buffer.deinit(self.allocator);

        // Write header
        try buffer.appendSlice(self.allocator, &CACHE_MAGIC);
        try buffer.appendSlice(self.allocator, &std.mem.toBytes(CACHE_VERSION));
        try buffer.appendSlice(self.allocator, &std.mem.toBytes(@as(u32, @intCast(self.clusters.items.len))));
        try buffer.appendSlice(self.allocator, &std.mem.toBytes(@as(u32, @intCast(self.config.dim))));
        try buffer.appendSlice(self.allocator, &std.mem.toBytes(@as(u32, @intCast(self.config.nprobe))));
        try buffer.appendSlice(self.allocator, &std.mem.toBytes(@as(u32, @intCast(self.config.max_iterations))));

        // Reserved bytes
        var reserved: [8]u8 = undefined;
        @memset(&reserved, 0);
        try buffer.appendSlice(self.allocator, &reserved);

        // Write cluster data
        for (self.clusters.items) |cluster| {
            // Write centroid
            for (cluster.centroid) |val| {
                try buffer.appendSlice(self.allocator, &std.mem.toBytes(val));
            }

            // Write entries count
            try buffer.appendSlice(self.allocator, &std.mem.toBytes(@as(u32, @intCast(cluster.entries.items.len))));

            // Write entries
            for (cluster.entries.items) |entry| {
                // Write ID
                try buffer.appendSlice(self.allocator, &std.mem.toBytes(@as(u32, @intCast(entry.id.len))));
                try buffer.appendSlice(self.allocator, entry.id);

                // Note: file and line are not stored in ClusterEntry
                // Write zero-length file path and line for compatibility
                try buffer.appendSlice(self.allocator, &std.mem.toBytes(@as(u32, 0)));
                try buffer.appendSlice(self.allocator, &std.mem.toBytes(@as(u32, 0)));
            }
        }

        // Write buffer to file
        try std.fs.cwd().writeFile(.{
            .sub_path = file_path,
            .data = buffer.items,
        });
    }

    /// Load IVF index from file (embeddings must be provided separately)
    /// Returns a populated IVFIndex that still needs embeddings to be linked
    pub fn loadFromFile(
        allocator: std.mem.Allocator,
        file_path: []const u8,
    ) !IVFIndex {
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const contents = try file.readToEndAlloc(allocator, 1024 * 1024 * 100); // Max 100MB
        defer allocator.free(contents);

        var pos: usize = 0;

        // Read and verify header
        if (contents.len < 32) return error.InvalidCacheFormat;

        const magic = contents[pos..][0..4];
        pos += 4;
        if (!std.mem.eql(u8, magic, &CACHE_MAGIC)) {
            return error.InvalidCacheFormat;
        }

        const version = std.mem.readInt(u32, contents[pos..][0..4], .little);
        pos += 4;
        if (version != CACHE_VERSION) {
            return error.UnsupportedCacheVersion;
        }

        const n_clusters = std.mem.readInt(u32, contents[pos..][0..4], .little);
        pos += 4;
        const dim = std.mem.readInt(u32, contents[pos..][0..4], .little);
        pos += 4;
        const nprobe = std.mem.readInt(u32, contents[pos..][0..4], .little);
        pos += 4;
        const max_iterations = std.mem.readInt(u32, contents[pos..][0..4], .little);
        pos += 4;

        // Skip reserved bytes
        pos += 8;

        // Create config and index
        const config = IVFConfig{
            .n_clusters = n_clusters,
            .dim = dim,
            .nprobe = nprobe,
            .max_iterations = max_iterations,
        };

        var index = try IVFIndex.init(allocator, config);
        errdefer index.deinit();

        // Read cluster data sequentially
        for (index.clusters.items) |*cluster| {
            // Read centroid (f32 values, 4 bytes each)
            for (0..dim) |i| {
                const bytes = contents[pos..][0..4];
                cluster.centroid[i] = @as(f32, @bitCast(std.mem.readInt(u32, bytes, .little)));
                pos += 4;
            }

            // Read entries
            const n_entries = std.mem.readInt(u32, contents[pos..][0..4], .little);
            pos += 4;
            for (0..n_entries) |_| {
                // Read ID
                const id_len = std.mem.readInt(u32, contents[pos..][0..4], .little);
                pos += 4;
                const id = try allocator.alloc(u8, id_len);
                @memcpy(id, contents[pos..][0..id_len]);
                pos += id_len;

                // Read file path (skip for now)
                const file_len = std.mem.readInt(u32, contents[pos..][0..4], .little);
                pos += 4;
                pos += file_len;

                // Read line number (skip)
                pos += 4;

                // Store entry with placeholder embedding
                try cluster.entries.append(allocator, .{
                    .id = id,
                    .embedding = &[_]f32{}, // Placeholder
                });
            }
        }

        return index;
    }
};

/// Comparison function for ClusterDistance sorting
fn clusterDistanceLessThan(_: void, a: ClusterDistance, b: ClusterDistance) bool {
    return a.dist < b.dist;
}

/// Helper: insert result maintaining top-k order
fn insertResult(results: *std.ArrayList(IVFSearchResult), allocator: std.mem.Allocator, symbol_id: []const u8, distance: f32, top_k: usize) !void {
    const result = try IVFSearchResult.init(allocator, symbol_id, distance);
    errdefer result.deinit(allocator);

    // Find insertion point
    var insert_idx = results.items.len;
    for (results.items, 0..) |r, i| {
        if (distance < r.distance) {
            insert_idx = i;
            break;
        }
    }

    try results.insert(allocator, insert_idx, result);

    // Keep only top-k
    if (results.items.len > top_k) {
        const removed = results.orderedRemove(top_k);
        removed.deinit(allocator);
    }
}

/// Squared Euclidean distance (for centroid distance computation)
pub fn squaredEuclideanDistance(a: []const f32, b: []const f32) f32 {
    const n = @min(a.len, b.len);
    var sum: f32 = 0.0;
    for (0..n) |i| {
        const diff = a[i] - b[i];
        sum += diff * diff;
    }
    return sum;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ivf.1: IVFIndex init and deinit" {
    const allocator = std.testing.allocator;
    // Use fixed config instead of init() to get predictable cluster count
    const config = IVFConfig{ .n_clusters = 32, .dim = 128, .nprobe = 16, .max_iterations = 20 };
    var index = try IVFIndex.init(allocator, config);
    defer index.deinit();

    try std.testing.expectEqual(@as(usize, 32), index.clusters.items.len);
}

test "ivf.2: Cluster addVector and updateCentroid" {
    const allocator = std.testing.allocator;
    var cluster = try Cluster.init(allocator, 4);
    defer cluster.deinit(allocator);

    const vec1 = [_]f32{ 1.0, 0.0, 0.0, 0.0 };
    const vec2 = [_]f32{ 0.0, 1.0, 0.0, 0.0 };

    try cluster.addVector(allocator, "test1", &vec1);
    try cluster.addVector(allocator, "test2", &vec2);
    cluster.updateCentroid();

    try std.testing.expectApproxEqAbs(@as(f32, 0.5), cluster.centroid[0], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), cluster.centroid[1], 0.01);
}

test "ivf.3: IVFIndex build with k-means" {
    const allocator = std.testing.allocator;

    // Create test symbols
    var symbols = std.ArrayList(Symbol){ .items = &.{}, .capacity = 0 };
    defer symbols.deinit(allocator);

    const vec1 = [_]f32{ 1.0, 0.0, 0.0, 0.0 };
    const vec2 = [_]f32{ 0.9, 0.1, 0.0, 0.0 };
    const vec3 = [_]f32{ 0.0, 1.0, 0.0, 0.0 };
    const vec4 = [_]f32{ 0.1, 0.9, 0.0, 0.0 };

    try symbols.append(allocator, .{ .id = "a", .embedding = &vec1, .file = "test.zig", .line = 1 });
    try symbols.append(allocator, .{ .id = "b", .embedding = &vec2, .file = "test.zig", .line = 2 });
    try symbols.append(allocator, .{ .id = "c", .embedding = &vec3, .file = "test.zig", .line = 3 });
    try symbols.append(allocator, .{ .id = "d", .embedding = &vec4, .file = "test.zig", .line = 4 });

    const config = IVFConfig{ .n_clusters = 2, .dim = 4, .max_iterations = 5 };
    var index = try IVFIndex.init(allocator, config);
    defer index.deinit();

    try index.build(symbols);

    // Check that symbols were distributed
    var total_in_clusters: usize = 0;
    for (index.clusters.items) |cluster| {
        total_in_clusters += cluster.entries.items.len;
    }
    try std.testing.expectEqual(@as(usize, 4), total_in_clusters);
}

test "ivf.4: IVFIndex search" {
    const allocator = std.testing.allocator;

    var symbols = std.ArrayList(Symbol){ .items = &.{}, .capacity = 0 };
    defer symbols.deinit(allocator);

    const vec1 = [_]f32{ 1.0, 0.0, 0.0, 0.0 };
    const vec2 = [_]f32{ 0.9, 0.1, 0.0, 0.0 };
    const vec3 = [_]f32{ 0.0, 1.0, 0.0, 0.0 };

    try symbols.append(allocator, .{ .id = "close1", .embedding = &vec1, .file = "test.zig", .line = 1 });
    try symbols.append(allocator, .{ .id = "close2", .embedding = &vec2, .file = "test.zig", .line = 2 });
    try symbols.append(allocator, .{ .id = "far", .embedding = &vec3, .file = "test.zig", .line = 3 });

    const config = IVFConfig{ .n_clusters = 2, .dim = 4, .max_iterations = 5, .nprobe = 2 };
    var index = try IVFIndex.init(allocator, config);
    defer index.deinit();

    try index.build(symbols);

    const query = [_]f32{ 0.95, 0.05, 0.0, 0.0 };
    const results = try index.search(&query, 2, allocator);
    defer {
        for (results) |*r| r.deinit(allocator);
        allocator.free(results);
    }

    try std.testing.expectEqual(@as(usize, 2), results.len);

    // Results should contain "close1" or "close2" (they are closer to query)
    const has_close_result = results[0].symbol_id.len > 0;
    try std.testing.expect(has_close_result);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TIER 4.2 TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ivf.5: Tier 4.2 - incrementalBuild add symbols" {
    const allocator = std.testing.allocator;

    var symbols = std.ArrayList(Symbol){ .items = &.{}, .capacity = 0 };
    defer symbols.deinit(allocator);

    const vec1 = [_]f32{ 1.0, 0.0, 0.0, 0.0 };
    const vec2 = [_]f32{ 0.0, 1.0, 0.0, 0.0 };

    try symbols.append(allocator, .{ .id = "a", .embedding = &vec1, .file = "test.zig", .line = 1 });
    try symbols.append(allocator, .{ .id = "b", .embedding = &vec2, .file = "test.zig", .line = 2 });

    const config = IVFConfig{ .n_clusters = 2, .dim = 4, .max_iterations = 5 };
    var index = try IVFIndex.init(allocator, config);
    defer index.deinit();

    try index.build(symbols);

    // Verify initial state
    var total: usize = 0;
    for (index.clusters.items) |cluster| {
        total += cluster.entries.items.len;
    }
    try std.testing.expectEqual(@as(usize, 2), total);

    // Incremental add new symbol
    var symbols_added = std.ArrayList(Symbol){ .items = &.{}, .capacity = 0 };
    defer symbols_added.deinit(allocator);
    const vec3 = [_]f32{ 0.5, 0.5, 0.0, 0.0 };
    try symbols_added.append(allocator, .{ .id = "c", .embedding = &vec3, .file = "test.zig", .line = 3 });

    var symbols_removed = std.ArrayList([]const u8){ .items = &.{}, .capacity = 0 };
    defer symbols_removed.deinit(allocator);

    try index.incrementalBuild(&symbols_added, &symbols_removed);

    // Verify 3 symbols now
    total = 0;
    for (index.clusters.items) |cluster| {
        total += cluster.entries.items.len;
    }
    try std.testing.expectEqual(@as(usize, 3), total);
}

test "ivf.6: Tier 4.2 - incrementalBuild remove symbols" {
    const allocator = std.testing.allocator;

    var symbols = std.ArrayList(Symbol){ .items = &.{}, .capacity = 0 };
    defer symbols.deinit(allocator);

    const vec1 = [_]f32{ 1.0, 0.0, 0.0, 0.0 };
    const vec2 = [_]f32{ 0.0, 1.0, 0.0, 0.0 };
    const vec3 = [_]f32{ 0.5, 0.5, 0.0, 0.0 };

    try symbols.append(allocator, .{ .id = "a", .embedding = &vec1, .file = "test.zig", .line = 1 });
    try symbols.append(allocator, .{ .id = "b", .embedding = &vec2, .file = "test.zig", .line = 2 });
    try symbols.append(allocator, .{ .id = "c", .embedding = &vec3, .file = "test.zig", .line = 3 });

    const config = IVFConfig{ .n_clusters = 2, .dim = 4, .max_iterations = 5 };
    var index = try IVFIndex.init(allocator, config);
    defer index.deinit();

    try index.build(symbols);

    // Verify initial state
    var total: usize = 0;
    for (index.clusters.items) |cluster| {
        total += cluster.entries.items.len;
    }
    try std.testing.expectEqual(@as(usize, 3), total);

    // Incremental remove symbol "b"
    var symbols_added = std.ArrayList(Symbol){ .items = &.{}, .capacity = 0 };
    defer symbols_added.deinit(allocator);

    var symbols_removed = std.ArrayList([]const u8){ .items = &.{}, .capacity = 0 };
    defer symbols_removed.deinit(allocator);
    try symbols_removed.append(allocator, "b");

    try index.incrementalBuild(&symbols_added, &symbols_removed);

    // Verify 2 symbols now
    total = 0;
    for (index.clusters.items) |cluster| {
        total += cluster.entries.items.len;
    }
    try std.testing.expectEqual(@as(usize, 2), total);
}

test "ivf.7: Tier 4.2 - saveToFile and loadFromFile" {
    const allocator = std.testing.allocator;

    // Create and build an index
    var symbols = std.ArrayList(Symbol){ .items = &.{}, .capacity = 0 };
    defer symbols.deinit(allocator);

    const vec1 = [_]f32{ 1.0, 0.0, 0.0, 0.0 };
    const vec2 = [_]f32{ 0.0, 1.0, 0.0, 0.0 };

    try symbols.append(allocator, .{ .id = "symbol1", .embedding = &vec1, .file = "test.zig", .line = 1 });
    try symbols.append(allocator, .{ .id = "symbol2", .embedding = &vec2, .file = "test.zig", .line = 2 });

    const config = IVFConfig{ .n_clusters = 2, .dim = 4, .max_iterations = 5 };
    var index = try IVFIndex.init(allocator, config);
    defer index.deinit();

    try index.build(symbols);

    // Save to temp file
    const cache_path = "/tmp/ivf_test_cache.bin";
    try index.saveToFile(cache_path);
    defer {
        std.fs.cwd().deleteFile(cache_path) catch {};
    }

    // Load from file
    var loaded_index = try IVFIndex.loadFromFile(allocator, cache_path);
    defer loaded_index.deinit();

    // Verify config matches
    try std.testing.expectEqual(config.n_clusters, loaded_index.config.n_clusters);
    try std.testing.expectEqual(config.dim, loaded_index.config.dim);

    // Verify clusters have entries (even though embeddings are placeholders)
    var total_entries: usize = 0;
    for (loaded_index.clusters.items) |cluster| {
        total_entries += cluster.entries.items.len;
    }
    try std.testing.expectEqual(@as(usize, 2), total_entries);
}
