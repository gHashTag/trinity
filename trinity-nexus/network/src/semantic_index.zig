// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY NODE v2.0 - Semantic Index
// Hypervector-based content index for similarity search
// Find shards by content similarity (cosine), not just SHA256 hash
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const ArrayList = std.array_list.Managed;
const vsa_encoder = @import("vsa_shard_encoder.zig");
const Hypervector = vsa_encoder.Hypervector;
const VsaShardEncoder = vsa_encoder.VsaShardEncoder;

// ═══════════════════════════════════════════════════════════════════════════════
// SEARCH RESULT
// ═══════════════════════════════════════════════════════════════════════════════

pub const SearchResult = struct {
    shard_hash: [32]u8,
    similarity: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// INDEX STATS
// ═══════════════════════════════════════════════════════════════════════════════

pub const IndexStats = struct {
    shards_indexed: u64,
    shards_removed: u64,
    queries_executed: u64,
    current_size: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// SEMANTIC INDEX
// ═══════════════════════════════════════════════════════════════════════════════

pub const SemanticIndex = struct {
    allocator: std.mem.Allocator,
    encoder: *VsaShardEncoder,
    // HashMap: shard_hash[32] → Hypervector fingerprint
    index: std.AutoArrayHashMap([32]u8, Hypervector),
    shards_indexed: u64,
    shards_removed: u64,
    queries_executed: u64,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator, encoder: *VsaShardEncoder) SemanticIndex {
        return .{
            .allocator = allocator,
            .encoder = encoder,
            .index = std.AutoArrayHashMap([32]u8, Hypervector).init(allocator),
            .shards_indexed = 0,
            .shards_removed = 0,
            .queries_executed = 0,
            .mutex = .{},
        };
    }

    pub fn deinit(self: *SemanticIndex) void {
        self.index.deinit();
    }

    /// Index a shard: compute fingerprint from data, store in index
    pub fn indexShard(self: *SemanticIndex, shard_hash: [32]u8, data: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const fingerprint = self.encoder.encode(data);
        try self.index.put(shard_hash, fingerprint);
        self.shards_indexed += 1;
    }

    /// Index a shard with a pre-computed fingerprint
    pub fn indexShardWithFingerprint(self: *SemanticIndex, shard_hash: [32]u8, fingerprint: Hypervector) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        try self.index.put(shard_hash, fingerprint);
        self.shards_indexed += 1;
    }

    /// Remove shard from index
    pub fn removeShard(self: *SemanticIndex, shard_hash: [32]u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        _ = self.index.orderedRemove(shard_hash);
        self.shards_removed += 1;
    }

    /// Search by content data: encode query, scan index for similar fingerprints
    pub fn searchByContent(
        self: *SemanticIndex,
        query_data: []const u8,
        threshold: f64,
        max_results: usize,
    ) ![]SearchResult {
        const query_fp = self.encoder.encode(query_data);
        return self.searchByVector(&query_fp, threshold, max_results);
    }

    /// Search by raw hypervector: scan index for similar fingerprints
    pub fn searchByVector(
        self: *SemanticIndex,
        query: *const Hypervector,
        threshold: f64,
        max_results: usize,
    ) ![]SearchResult {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.queries_executed += 1;

        // Collect all matches above threshold
        var results = ArrayList(SearchResult).init(self.allocator);
        defer results.deinit();

        var iter = self.index.iterator();
        while (iter.next()) |entry| {
            const sim = Hypervector.cosineSimilarity(query, entry.value_ptr);
            if (sim >= threshold) {
                try results.append(.{
                    .shard_hash = entry.key_ptr.*,
                    .similarity = sim,
                });
            }
        }

        // Sort by similarity descending
        std.mem.sort(SearchResult, results.items, {}, struct {
            fn lessThan(_: void, a: SearchResult, b: SearchResult) bool {
                return b.similarity < a.similarity;
            }
        }.lessThan);

        // Return top-k results (caller owns the memory)
        const count = @min(results.items.len, max_results);
        const out = try self.allocator.alloc(SearchResult, count);
        @memcpy(out, results.items[0..count]);
        return out;
    }

    /// Get fingerprint for a known shard hash
    pub fn getFingerprint(self: *SemanticIndex, shard_hash: [32]u8) ?Hypervector {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.index.get(shard_hash);
    }

    /// Get index statistics
    pub fn getStats(self: *SemanticIndex) IndexStats {
        self.mutex.lock();
        defer self.mutex.unlock();

        return .{
            .shards_indexed = self.shards_indexed,
            .shards_removed = self.shards_removed,
            .queries_executed = self.queries_executed,
            .current_size = self.index.count(),
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

fn makeHash(comptime val: u8) [32]u8 {
    return [_]u8{val} ** 32;
}

test "index and retrieve fingerprint" {
    var encoder = VsaShardEncoder.init(std.testing.allocator);
    defer encoder.deinit();

    var idx = SemanticIndex.init(std.testing.allocator, &encoder);
    defer idx.deinit();

    const hash = makeHash(0xAA);
    const data = "Hello, Trinity!";
    try idx.indexShard(hash, data);

    const fp = idx.getFingerprint(hash);
    try std.testing.expect(fp != null);
    try std.testing.expect(fp.?.countNonZero() > 0);
}

test "search by content finds matching shard" {
    var encoder = VsaShardEncoder.init(std.testing.allocator);
    defer encoder.deinit();

    var idx = SemanticIndex.init(std.testing.allocator, &encoder);
    defer idx.deinit();

    const hash = makeHash(0x01);
    const data = "The quick brown fox";
    try idx.indexShard(hash, data);

    // Search with the same data — should find it with similarity ~1.0
    const results = try idx.searchByContent(data, 0.5, 10);
    defer std.testing.allocator.free(results);

    try std.testing.expect(results.len == 1);
    try std.testing.expect(results[0].similarity > 0.999);
    try std.testing.expectEqual(hash, results[0].shard_hash);
}

test "search with threshold filters low similarity" {
    var encoder = VsaShardEncoder.init(std.testing.allocator);
    defer encoder.deinit();

    var idx = SemanticIndex.init(std.testing.allocator, &encoder);
    defer idx.deinit();

    try idx.indexShard(makeHash(0x01), "AAAAAAAAAAAAAAAA");
    try idx.indexShard(makeHash(0x02), "BBBBBBBBBBBBBBBB");

    // Search for something completely different with high threshold
    const results = try idx.searchByContent("ZZZZZZZZZZZZZZZZ", 0.99, 10);
    defer std.testing.allocator.free(results);

    // High threshold should filter out non-matching shards
    try std.testing.expect(results.len == 0);
}

test "search returns sorted by similarity" {
    var encoder = VsaShardEncoder.init(std.testing.allocator);
    defer encoder.deinit();

    var idx = SemanticIndex.init(std.testing.allocator, &encoder);
    defer idx.deinit();

    // Index three shards with varying similarity to query
    try idx.indexShard(makeHash(0x01), "The quick brown fox jumps over the lazy dog");
    try idx.indexShard(makeHash(0x02), "The quick brown fox jumps over the lazy cat");
    try idx.indexShard(makeHash(0x03), "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");

    const results = try idx.searchByContent("The quick brown fox jumps over the lazy dog", 0.0, 10);
    defer std.testing.allocator.free(results);

    try std.testing.expect(results.len >= 2);

    // Results should be sorted descending by similarity
    for (0..results.len - 1) |i| {
        try std.testing.expect(results[i].similarity >= results[i + 1].similarity);
    }

    // First result should be the exact match
    try std.testing.expectEqual(makeHash(0x01), results[0].shard_hash);
}

test "remove shard from index" {
    var encoder = VsaShardEncoder.init(std.testing.allocator);
    defer encoder.deinit();

    var idx = SemanticIndex.init(std.testing.allocator, &encoder);
    defer idx.deinit();

    const hash = makeHash(0xBB);
    try idx.indexShard(hash, "some data");

    try std.testing.expect(idx.getFingerprint(hash) != null);

    idx.removeShard(hash);

    try std.testing.expect(idx.getFingerprint(hash) == null);
}

test "empty index returns no results" {
    var encoder = VsaShardEncoder.init(std.testing.allocator);
    defer encoder.deinit();

    var idx = SemanticIndex.init(std.testing.allocator, &encoder);
    defer idx.deinit();

    const results = try idx.searchByContent("anything", 0.0, 10);
    defer std.testing.allocator.free(results);

    try std.testing.expectEqual(@as(usize, 0), results.len);
}

test "multiple shards indexed and searched" {
    var encoder = VsaShardEncoder.init(std.testing.allocator);
    defer encoder.deinit();

    var idx = SemanticIndex.init(std.testing.allocator, &encoder);
    defer idx.deinit();

    // Index 10 shards
    for (0..10) |i| {
        var hash: [32]u8 = [_]u8{0} ** 32;
        hash[0] = @intCast(i);
        var buf: [32]u8 = undefined;
        const data = std.fmt.bufPrint(&buf, "shard data number {d}", .{i}) catch "fallback";
        try idx.indexShard(hash, data);
    }

    const stats = idx.getStats();
    try std.testing.expectEqual(@as(u64, 10), stats.shards_indexed);
    try std.testing.expectEqual(@as(usize, 10), stats.current_size);

    // Search should return results capped at max_results
    const results = try idx.searchByContent("shard data number 5", 0.0, 3);
    defer std.testing.allocator.free(results);

    try std.testing.expect(results.len <= 3);
}

test "stats tracking" {
    var encoder = VsaShardEncoder.init(std.testing.allocator);
    defer encoder.deinit();

    var idx = SemanticIndex.init(std.testing.allocator, &encoder);
    defer idx.deinit();

    try idx.indexShard(makeHash(0x01), "data1");
    try idx.indexShard(makeHash(0x02), "data2");
    try idx.indexShard(makeHash(0x03), "data3");

    idx.removeShard(makeHash(0x02));

    const r1 = try idx.searchByContent("query1", 0.0, 5);
    defer std.testing.allocator.free(r1);
    const r2 = try idx.searchByContent("query2", 0.0, 5);
    defer std.testing.allocator.free(r2);

    const stats = idx.getStats();
    try std.testing.expectEqual(@as(u64, 3), stats.shards_indexed);
    try std.testing.expectEqual(@as(u64, 1), stats.shards_removed);
    try std.testing.expectEqual(@as(u64, 2), stats.queries_executed);
    try std.testing.expectEqual(@as(usize, 2), stats.current_size);
}
