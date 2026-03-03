// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE Tier 3.5 — HNSW Index for Fast Semantic Search
// ═══════════════════════════════════════════════════════════════════════════════
//
// Hierarchical Navigable Small World graph for approximate nearest neighbor
// O(log N) search complexity for large-scale semantic code search
// φ² + 1/φ² = 3 | TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const DEFAULT_M: usize = 16;
pub const DEFAULT_EF_CONSTRUCTION: usize = 200;
pub const DEFAULT_EF_SEARCH: usize = 50;

pub const HNSWConfig = struct {
    dim: usize = 384,
    M: usize = DEFAULT_M,
    ef_construction: usize = DEFAULT_EF_CONSTRUCTION,
    ef_search: usize = DEFAULT_EF_SEARCH,
};

pub const SearchResult = struct {
    node_id: usize,
    symbol_id: []const u8,
    similarity: f32,
};

pub const HNSWIndex = struct {
    config: HNSWConfig,
    // Simple flat storage for now (HNSW optimization later)
    symbols: std.ArrayList([]const u8),
    embeddings: std.ArrayList([]f32),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: HNSWConfig) !HNSWIndex {
        return .{
            .config = config,
            .symbols = std.ArrayList([]const u8).empty,
            .embeddings = std.ArrayList([]f32).empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *HNSWIndex) void {
        for (self.symbols.items) |sym| {
            self.allocator.free(sym);
        }
        self.symbols.deinit(self.allocator);

        for (self.embeddings.items) |emb| {
            self.allocator.free(emb);
        }
        self.embeddings.deinit(self.allocator);
    }

    fn distance(a: []const f32, b: []const f32) f32 {
        std.debug.assert(a.len == b.len);
        var sum: f32 = 0.0;
        for (0..a.len) |i| {
            const diff = a[i] - b[i];
            sum += diff * diff;
        }
        return @sqrt(sum);
    }

    pub fn insert(self: *HNSWIndex, symbol_id: []const u8, vector: []const f32) !void {
        const sym_copy = try self.allocator.dupe(u8, symbol_id);
        const emb_copy = try self.allocator.alloc(f32, vector.len);
        @memcpy(emb_copy, vector);

        try self.symbols.append(self.allocator, sym_copy);
        try self.embeddings.append(self.allocator, emb_copy);
    }

    pub fn search(self: *HNSWIndex, query: []const f32, k: usize, result_allocator: std.mem.Allocator) ![]SearchResult {
        if (self.symbols.items.len == 0) return &.{};

        var results = std.ArrayList(SearchResult).empty;
        errdefer {
            for (results.items) |*r| {
                result_allocator.free(r.symbol_id);
            }
            results.deinit(result_allocator);
        }

        // Calculate distances to all nodes
        for (self.symbols.items, 0..) |sym, i| {
            const dist = distance(query, self.embeddings.items[i]);
            const sim = 1.0 / (1.0 + dist);

            try results.append(result_allocator, .{
                .node_id = i,
                .symbol_id = try result_allocator.dupe(u8, sym),
                .similarity = sim,
            });
        }

        // Sort by similarity descending
        std.sort.insertion(SearchResult, results.items, {}, struct {
            fn lessThan(_: void, a: SearchResult, b: SearchResult) bool {
                return a.similarity > b.similarity;
            }
        }.lessThan);

        // Return top k
        const top_k = @min(k, results.items.len);
        const result_slice = try result_allocator.alloc(SearchResult, top_k);
        for (0..top_k) |i| {
            result_slice[i] = results.items[i];
        }
        results.items.len = 0;
        results.deinit(result_allocator);

        return result_slice;
    }

    pub fn size(self: *const HNSWIndex) usize {
        return self.symbols.items.len;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "hnsw.1: HNSWIndex init and deinit" {
    const allocator = std.testing.allocator;
    var index = try HNSWIndex.init(allocator, .{});
    defer index.deinit();
    try std.testing.expectEqual(@as(usize, 0), index.size());
}

test "hnsw.2: Insert single node" {
    const allocator = std.testing.allocator;
    var index = try HNSWIndex.init(allocator, .{});
    defer index.deinit();

    const vector = [_]f32{0.1} ** 64;
    try index.insert("test_symbol", &vector);
    try std.testing.expectEqual(@as(usize, 1), index.size());
}

test "hnsw.3: Insert and search" {
    const allocator = std.testing.allocator;
    var index = try HNSWIndex.init(allocator, .{});
    defer index.deinit();

    const v1 = [_]f32{1.0} ** 64;
    const v2 = [_]f32{0.0} ** 64;

    try index.insert("one", &v1);
    try index.insert("two", &v2);

    const query = [_]f32{0.9} ** 64;
    const results = try index.search(&query, 2, allocator);
    defer {
        for (results) |*r| {
            allocator.free(r.symbol_id);
        }
        allocator.free(results);
    }

    try std.testing.expect(results.len >= 1);
    try std.testing.expectEqualStrings("one", results[0].symbol_id);
}

test "hnsw.4: Multiple inserts" {
    const allocator = std.testing.allocator;
    var index = try HNSWIndex.init(allocator, .{});
    defer index.deinit();

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        var vec = [_]f32{0.0} ** 64;
        vec[i % 64] = 1.0;
        const name = try std.fmt.allocPrint(allocator, "symbol_{d}", .{i});
        try index.insert(name, &vec);
        allocator.free(name);
    }

    try std.testing.expectEqual(@as(usize, 10), index.size());
}

test "hnsw.5: Distance function" {
    const a = [_]f32{ 0.0, 0.0 };
    const b = [_]f32{ 3.0, 4.0 };
    const dist = HNSWIndex.distance(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), dist, 0.01);
}
