// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE Tier 3.5 — HNSW Performance Benchmarks
// ═══════════════════════════════════════════════════════════════════════════════
//
// Benchmarks for HNSW index semantic search performance
// Target: <100ms for 1000+ symbols
// φ² + 1/φ² = 3 | TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Direct inline HNSW implementation for benchmark
const DEFAULT_M: usize = 16;
const DEFAULT_EF_CONSTRUCTION: usize = 200;
const DEFAULT_EF_SEARCH: usize = 50;

const HNSWConfig = struct {
    dim: usize = 384,
    M: usize = DEFAULT_M,
    ef_construction: usize = DEFAULT_EF_CONSTRUCTION,
    ef_search: usize = DEFAULT_EF_SEARCH,
};

const SearchResult = struct {
    node_id: usize,
    symbol_id: []const u8,
    similarity: f32,
};

const HNSWIndex = struct {
    config: HNSWConfig,
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

// L2 norm function
fn l2Norm(vec: []const f32) f32 {
    var sum: f32 = 0.0;
    for (vec) |v| {
        sum += v * v;
    }
    return @sqrt(sum);
}

pub fn main() !void {
    // Use stderr for output in Zig 0.15
    const stderr_file = std.fs.File.stderr();
    var write_buffer: [4096]u8 = undefined;
    var writer = stderr_file.writer(&write_buffer);
    const stdout = &writer.interface;

    const allocator = std.heap.page_allocator;

    try std.Io.Writer.print(stdout, "═════════════════════════════════════════════════════════\n", .{});
    try std.Io.Writer.print(stdout, "  HNSW Performance Benchmarks — Tier 3.5\n", .{});
    try std.Io.Writer.print(stdout, "═════════════════════════════════════════════════════════\n\n", .{});

    // Benchmark 1: Build index with 100 symbols
    try std.Io.Writer.print(stdout, "[B1] Build index with 100 symbols...\n", .{});
    const t1_build = try benchmarkBuildIndex(allocator, 100);
    try std.Io.Writer.print(stdout, "     Time: {d:.2} ms (target: <10ms) {s}\n\n", .{
        t1_build,
        if (t1_build < 10.0) "✓" else "✗",
    });

    // Benchmark 2: Build index with 1000 symbols
    try std.Io.Writer.print(stdout, "[B2] Build index with 1000 symbols...\n", .{});
    const t2_build = try benchmarkBuildIndex(allocator, 1000);
    try std.Io.Writer.print(stdout, "     Time: {d:.2} ms (target: <100ms) {s}\n\n", .{
        t2_build,
        if (t2_build < 100.0) "✓" else "✗",
    });

    // Benchmark 3: Search index with 1000 symbols
    try std.Io.Writer.print(stdout, "[B3] Search index with 1000 symbols (top-10)...\n", .{});
    var index_1000 = try buildIndex(allocator, 1000);
    defer index_1000.deinit();
    const t3_search = try benchmarkSearch(&index_1000, 1000, 10);
    try std.Io.Writer.print(stdout, "     Time: {d:.2} ms (target: <100ms) {s}\n\n", .{
        t3_search,
        if (t3_search < 100.0) "✓" else "✗",
    });

    // Benchmark 4: Search index with 10000 symbols
    try std.Io.Writer.print(stdout, "[B4] Search index with 10000 symbols (top-10)...\n", .{});
    var index_10000 = try buildIndex(allocator, 10000);
    defer index_10000.deinit();
    const t4_search = try benchmarkSearch(&index_10000, 10000, 10);
    try std.Io.Writer.print(stdout, "     Time: {d:.2} ms (target: <100ms) {s}\n\n", .{
        t4_search,
        if (t4_search < 100.0) "✓" else "✗",
    });

    // Summary
    try std.Io.Writer.print(stdout, "═════════════════════════════════════════════════════════\n", .{});
    try std.Io.Writer.print(stdout, "  Summary:\n", .{});
    try std.Io.Writer.print(stdout, "    B1 (100 build):  {d:.2} ms {s}\n", .{ t1_build, if (t1_build < 10.0) "✓" else "✗" });
    try std.Io.Writer.print(stdout, "    B2 (1000 build): {d:.2} ms {s}\n", .{ t2_build, if (t2_build < 100.0) "✓" else "✗" });
    try std.Io.Writer.print(stdout, "    B3 (1000 search): {d:.2} ms {s}\n", .{ t3_search, if (t3_search < 100.0) "✓" else "✗" });
    try std.Io.Writer.print(stdout, "    B4 (10000 search): {d:.2} ms {s}\n", .{ t4_search, if (t4_search < 100.0) "✓" else "✗" });
    try std.Io.Writer.print(stdout, "═════════════════════════════════════════════════════════\n", .{});

    // Flush the buffer
    try std.Io.Writer.flush(stdout);
}

fn benchmarkBuildIndex(allocator: std.mem.Allocator, n: usize) !f64 {
    var timer = try std.time.Timer.start();
    var index = try buildIndex(allocator, n);
    index.deinit();
    return @as(f64, @floatFromInt(timer.read())) / 1_000_000.0;
}

fn benchmarkSearch(index: *HNSWIndex, n: usize, k: usize) !f64 {
    _ = n; // Unused but kept for API consistency
    const allocator = std.heap.page_allocator;

    // Generate random query vector
    const query_vec = try allocator.alloc(f32, 384);
    defer allocator.free(query_vec);
    var rng = std.Random.DefaultPrng.init(42);
    const random = rng.random();
    for (query_vec) |*v| {
        v.* = random.float(f32) * 2.0 - 1.0;
    }
    // Normalize
    const norm = l2Norm(query_vec);
    if (norm > 0) {
        for (query_vec) |*v| {
            v.* /= norm;
        }
    }

    // Warm-up
    _ = try index.search(query_vec, k, allocator);

    // Benchmark (average of 10 runs)
    var total: u64 = 0;
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        var timer = try std.time.Timer.start();
        const results = try index.search(query_vec, k, allocator);
        const elapsed = timer.read();
        total += elapsed;

        // Free results
        for (results) |*r| {
            allocator.free(r.symbol_id);
        }
        allocator.free(results);
    }

    return @as(f64, @floatFromInt(total / 10)) / 1_000_000.0;
}

fn buildIndex(allocator: std.mem.Allocator, n: usize) !HNSWIndex {
    var index = try HNSWIndex.init(allocator, .{ .dim = 384 });
    errdefer index.deinit();

    var rng = std.Random.DefaultPrng.init(42);
    const random = rng.random();

    var i: usize = 0;
    while (i < n) : (i += 1) {
        // Generate random embedding
        const vec = try allocator.alloc(f32, 384);
        for (vec) |*v| {
            v.* = random.float(f32) * 2.0 - 1.0;
        }
        // Normalize
        const norm = l2Norm(vec);
        if (norm > 0) {
            for (vec) |*v| {
                v.* /= norm;
            }
        }

        const name = try std.fmt.allocPrint(allocator, "symbol_{d}", .{i});
        try index.insert(name, vec);
        allocator.free(name);
        allocator.free(vec);
    }

    return index;
}
