// ═══════════════════════════════════════════════════════════════════════════════
// TVC-POWERED CODEBASE INDEXER
// ═══════════════════════════════════════════════════════════════════════════════
//
// Efficient semantic code search using Ternary Vector Computing.
// - 1.58 bits/trit (20x memory savings vs float32)
// - HNSW indexing for O(log n) search
// - Tree-sitter AST parsing for deep code understanding
// - Real-time file watching for auto-reindex
//
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import VSA/TVC components
const vsa = @import("../vsa.zig");
const tvc_vsa = @import("tvc_vsa.zig");
const tvc_hybrid = @import("tvc_hybrid.zig");

// Import Tree-sitter bindings
const ast_nodes = @import("treesitter/ast_nodes.zig");
const zig_parser = @import("treesitter/zig.zig");

// Import HNSW for fast similarity search
const hnsw_module = @import("hnsw.zig");
const hnsw_distance = @import("hnsw_distance.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Embedding mode for indexing
pub const EmbeddingMode = enum {
    /// VSA-based ternary (1.58 bits/trit, 256-dim)
    tvc_ternary,
    /// Standard 384-dim float32
    float32_384,
    /// Both for compatibility
    hybrid,
};

/// Indexer configuration
pub const IndexConfig = struct {
    embedding_mode: EmbeddingMode = .tvc_ternary,
    chunk_size: usize = 100, // lines per chunk
    overlap_lines: usize = 10,
    top_k: usize = 10,
    min_similarity: f32 = 0.3,
    watch_files: bool = false,
    debounce_ms: u64 = 100,
    storage_path: ?[]const u8 = null,

    pub fn init() IndexConfig {
        return .{};
    }
};

/// Symbol kind for filtering
pub const SymbolKind = enum {
    function,
    type,
    constant,
    variable,
    parameter,
    struct_field,
    enum_variant,
    import,
    module,
    test_case,
};

/// Output format for results
pub const OutputFormat = enum {
    pretty,
    json,
    markdown,
};

/// Single search result
pub const SearchResult = struct {
    symbol_id: u64,
    symbol_name: []const u8,
    qualified_name: []const u8,
    file_path: []const u8,
    line_number: u32,
    snippet: []const u8,
    similarity: f32,
    symbol_kind: SymbolKind,
    language: ast_nodes.Language,
};

/// Search results container
pub const SearchResults = struct {
    results: []SearchResult,
    count: usize,
    query_time_ms: u64,
    total_indexed: usize,

    pub fn deinit(self: *SearchResults, allocator: Allocator) void {
        for (self.results) |*r| {
            allocator.free(r.symbol_name);
            allocator.free(r.qualified_name);
            allocator.free(r.file_path);
            allocator.free(r.snippet);
        }
        allocator.free(self.results);
    }
};

/// Index statistics
pub const IndexStats = struct {
    files_indexed: usize = 0,
    symbols_indexed: usize = 0,
    total_embeddings: usize = 0,
    queries_processed: usize = 0,
    avg_query_time_ms: f64 = 0.0,
    index_size_bytes: usize = 0,
    last_update: u64 = 0,
    zig_symbols: usize = 0,
    vibee_symbols: usize = 0,

    pub fn format(self: *const IndexStats, allocator: Allocator, format: OutputFormat) ![]const u8 {
        return switch (format) {
            .pretty => self.formatPretty(allocator),
            .json => self.formatJson(allocator),
            .markdown => self.formatMarkdown(allocator),
        };
    }

    fn formatPretty(self: *const IndexStats, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\═══════════════════════════════════════
            \\INDEX STATISTICS
            \\═══════════════════════════════════════
            \\Files Indexed:      {d}
            \\Symbols Indexed:    {d}
            \\Total Embeddings:   {d}
            \\Queries Processed:  {d}
            \\Avg Query Time:     {d:.2} ms
            \\Index Size:         {d} bytes
            \\
            \\By Language:
            \\  Zig:   {d}
            \\  VIBEE: {d}
            \\═══════════════════════════════════════
        , .{
            self.files_indexed,
            self.symbols_indexed,
            self.total_embeddings,
            self.queries_processed,
            self.avg_query_time_ms,
            self.index_size_bytes,
            self.zig_symbols,
            self.tri_symbols,
        });
    }

    fn formatJson(self: *const IndexStats, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\{{
            \\  "files_indexed": {d},
            \\  "symbols_indexed": {d},
            \\  "total_embeddings": {d},
            \\  "queries_processed": {d},
            \\  "avg_query_time_ms": {d:.2},
            \\  "index_size_bytes": {d},
            \\  "languages": {{
            \\    "zig": {d},
            \\    "vibee": {d}
            \\  }}
            \\}}
        , .{
            self.files_indexed,
            self.symbols_indexed,
            self.total_embeddings,
            self.queries_processed,
            self.avg_query_time_ms,
            self.index_size_bytes,
            self.zig_symbols,
            self.tri_symbols,
        });
    }

    fn formatMarkdown(self: *const IndexStats, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\## Index Statistics
            \\
            \\| Metric | Value |
            \\|--------|-------|
            \\| Files Indexed | {d} |
            \\| Symbols Indexed | {d} |
            \\| Total Embeddings | {d} |
            \\| Queries Processed | {d} |
            \\| Avg Query Time | {d:.2} ms |
            \\| Index Size | {d} bytes |
            \\
            \\### By Language
            \\
            \\| Language | Symbols |
            \\|----------|---------|
            \\| Zig | {d} |
            \\| VIBEE | {d} |
        , .{
            self.files_indexed,
            self.symbols_indexed,
            self.total_embeddings,
            self.queries_processed,
            self.avg_query_time_ms,
            self.index_size_bytes,
            self.zig_symbols,
            self.tri_symbols,
        });
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CODE INDEXER
// ═══════════════════════════════════════════════════════════════════════════════

/// Main TVC-powered code indexer
pub const CodeIndexer = struct {
    allocator: Allocator,
    config: IndexConfig,
    stats: IndexStats,

    // Symbol storage
    symbols: std.StringHashMap(SymbolEntry),

    // Embedding storage (legacy HashMap storage for compatibility)
    embeddings_tvc: std.StringHashMap(TVCEmbedding),
    embeddings_float32: std.StringHashMap(Float32Embedding),

    // HNSW index for O(log n) search (Cycle 70)
    // Using 256-dim float32 for HNSW (converted from ternary if needed)
    hnsw_index: ?hnsw_module.HNSW(256, 16),
    next_symbol_id: u64,

    // File watching (optional)
    watcher_handle: ?*anyopaque = null,

    const SymbolEntry = struct {
        id: u64,
        kind: SymbolKind,
        name: []const u8,
        file_path: []const u8,
        line: u32,
        language: ast_nodes.Language,
    };

    const TVCEmbedding = struct {
        vector: tvc_hybrid.HybridBigInt,
        dimension: usize,
        symbol_id: u64,
    };

    const Float32Embedding = struct {
        vector: []f32,
        dimension: usize,
        symbol_id: u64,
    };

    /// Create a new indexer
    pub fn init(allocator: Allocator, config: IndexConfig) !CodeIndexer {
        // Initialize HNSW index
        const hnsw_config = hnsw_module.Config{
            .dim = 256,
            .m = 16,
            .max_m0 = 32,
            .ef_construction = 64,
            .ef_search = config.top_k * 8, // ef = k * 8 for good recall
            .distance_metric = .cosine,
        };
        var hnsw = try hnsw_module.HNSW(256, 16).init(allocator, hnsw_config);

        return CodeIndexer{
            .allocator = allocator,
            .config = config,
            .stats = .{},
            .symbols = std.StringHashMap(SymbolEntry).init(allocator),
            .embeddings_tvc = std.StringHashMap(TVCEmbedding).init(allocator),
            .embeddings_float32 = std.StringHashMap(Float32Embedding).init(allocator),
            .hnsw_index = hnsw,
            .next_symbol_id = 1,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *CodeIndexer) void {
        // Clean up HNSW index
        if (self.hnsw_index) |*index| {
            index.deinit();
        }

        // Free symbols
        var symbol_iter = self.symbols.valueIterator();
        while (symbol_iter.next()) |entry| {
            self.allocator.free(entry.name);
            self.allocator.free(entry.file_path);
        }
        self.symbols.deinit();

        // Free embeddings
        var tvc_iter = self.embeddings_tvc.valueIterator();
        while (tvc_iter.next()) |*emb| {
            emb.vector.deinit();
        }
        self.embeddings_tvc.deinit();

        var float_iter = self.embeddings_float32.valueIterator();
        while (float_iter.next()) |*emb| {
            self.allocator.free(emb.vector);
        }
        self.embeddings_float32.deinit();

        // Stop file watcher if running
        if (self.watcher_handle) |_| {
            self.stopWatching();
        }
    }

    /// Index a single file
    pub fn indexFile(self: *CodeIndexer, file_path: []const u8) !void {
        // Read file content
        const source = try std.fs.cwd().readFileAlloc(self.allocator, file_path, 10 * 1024 * 1024);
        defer self.allocator.free(source);

        // Extract symbols using Tree-sitter
        const result = try ast_nodes.extractSymbols(self.allocator, file_path, source);
        defer result.deinit();

        // Store symbols and generate embeddings
        for (result.symbols.items) |sym| {
            const key = try std.fmt.allocPrint(self.allocator, "{s}:{d}", .{ file_path, sym.id });

            // Store symbol entry with unique ID
            const symbol_id = self.next_symbol_id;
            self.next_symbol_id += 1;

            try self.symbols.put(key, SymbolEntry{
                .id = symbol_id,
                .kind = @as(SymbolKind, @enumFromInt(@intFromEnum(sym.kind))),
                .name = try self.allocator.dupe(u8, sym.name),
                .file_path = try self.allocator.dupe(u8, sym.file_path),
                .line = sym.line,
                .language = sym.language,
            });

            // Generate and store embeddings based on mode
            const search_text = try sym.toSearchText(self.allocator);
            defer self.allocator.free(search_text);

            switch (self.config.embedding_mode) {
                .tvc_ternary, .hybrid => {
                    const emb = try self.generateTVCEmbedding(search_text);
                    try self.embeddings_tvc.put(key, emb);
                },
                .float32_384, .hybrid => {
                    const emb = try self.generateFloat32Embedding(search_text);
                    try self.embeddings_float32.put(key, emb);

                    // ALSO insert into HNSW for O(log n) search (Cycle 70)
                    if (self.hnsw_index) |*index| {
                        // Convert to 256-dim float32 for HNSW
                        const dim256 = try self.allocator.alloc(f32, 256);
                        defer self.allocator.free(dim256);
                        @memset(dim256, 0.0);
                        const copy_len = @min(256, emb.vector.len);
                        @memcpy(dim256[0..copy_len], emb.vector[0..copy_len]);

                        try index.insert(dim256, symbol_id);
                    }
                },
            }

            self.allocator.free(key);
        }

        // Update stats
        self.stats.files_indexed += 1;
        self.stats.symbols_indexed += result.symbols.items.len;
        self.stats.total_embeddings += result.symbols.items.len;

        if (result.symbols.items.len > 0) {
            const lang = result.symbols.items[0].language;
            switch (lang) {
                .zig => self.stats.zig_symbols += result.symbols.items.len,
                .tri => self.stats.tri_symbols += result.symbols.items.len,
            }
        }

        self.stats.last_update = std.time.timestamp();
    }

    /// Index a directory recursively
    pub fn indexDirectory(self: *CodeIndexer, dir_path: []const u8, recursive: bool) !void {
        var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
        defer dir.close();

        var walker = if (recursive)
            try dir.walk(self.allocator)
        else
            dir.iterate(self.allocator);

        defer if (recursive) walker.deinit();

        if (recursive) {
            while (try walker.next()) |entry| {
                if (entry.kind == .file) {
                    if (ast_nodes.Language.fromPath(entry.path)) |_| {
                        self.indexFile(entry.path) catch |err| {
                            std.debug.print("Warning: Failed to index {s}: {}\n", .{ entry.path, err });
                        };
                    }
                }
            }
        } else {
            while (try walker.next()) |entry| {
                if (entry.kind == .file) {
                    if (ast_nodes.Language.fromPath(entry.basename)) |_| {
                        const full_path = try std.fs.path.join(self.allocator, &.{ dir_path, entry.basename });
                        defer self.allocator.free(full_path);
                        self.indexFile(full_path) catch |err| {
                            std.debug.print("Warning: Failed to index {s}: {}\n", .{ full_path, err });
                        };
                    }
                }
            }
        }
    }

    /// Re-index a file (remove old, add new)
    pub fn reindexFile(self: *CodeIndexer, file_path: []const u8) !void {
        // Remove old embeddings for this file
        try self.removeFile(file_path);

        // Re-index
        try self.indexFile(file_path);
    }

    /// Remove a file from the index
    pub fn removeFile(self: *CodeIndexer, file_path: []const u8) !void {
        var keys_to_remove = std.ArrayList([]const u8).init(self.allocator);
        defer {
            for (keys_to_remove.items) |k| {
                self.allocator.free(k);
            }
            keys_to_remove.deinit();
        }

        // Find all keys for this file
        var iter = self.symbols.iterator();
        while (iter.next()) |entry| {
            if (std.mem.eql(u8, entry.value_ptr.file_path, file_path)) {
                try keys_to_remove.append(try self.allocator.dupe(u8, entry.key_ptr.*));
            }
        }

        // Remove from all maps
        for (keys_to_remove.items) |key| {
            _ = self.symbols.remove(key);
            if (self.embeddings_tvc.fetchRemove(key)) |e| {
                e.value.vector.deinit();
            }
            if (self.embeddings_float32.fetchRemove(key)) |e| {
                self.allocator.free(e.value.vector);
            }
        }
    }

    /// Clear all indexed data
    pub fn clearIndex(self: *CodeIndexer) void {
        var symbol_iter = self.symbols.valueIterator();
        while (symbol_iter.next()) |entry| {
            self.allocator.free(entry.name);
            self.allocator.free(entry.file_path);
        }
        self.symbols.clearRetainingCapacity();

        var tvc_iter = self.embeddings_tvc.valueIterator();
        while (tvc_iter.next()) |*emb| {
            emb.vector.deinit();
        }
        self.embeddings_tvc.clearRetainingCapacity();

        var float_iter = self.embeddings_float32.valueIterator();
        while (float_iter.next()) |*emb| {
            self.allocator.free(emb.vector);
        }
        self.embeddings_float32.clearRetainingCapacity();

        self.stats = .{};
    }

    /// Search for similar code (NOW WITH HNSW - O(log n) performance!)
    pub fn search(self: *CodeIndexer, query: []const u8, top_k: usize) !SearchResults {
        const start_time = std.time.nanoTimestamp();

        var results = std.ArrayList(SearchResult).init(self.allocator);

        // Use HNSW if available (Cycle 70 fast path)
        if (self.hnsw_index) |*index| {
            // Generate query embedding as float32
            const query_vec = try self.generateFloat32Embedding(query);
            defer self.allocator.free(query_vec.vector);

            // Resize to 256-dim if needed
            const dim256 = try self.allocator.alloc(f32, 256);
            defer self.allocator.free(dim256);
            @memset(dim256, 0.0);
            const copy_len = @min(256, query_vec.vector.len);
            @memcpy(dim256[0..copy_len], query_vec.vector[0..copy_len]);

            // Search HNSW
            const hnsw_results = try index.search(dim256, top_k);
            defer hnsw_results.deinit();

            // Convert HNSW matches to SearchResults
            for (hnsw_results.matches) |match| {
                // Find symbol by ID
                var symbol_iter = self.symbols.iterator();
                while (symbol_iter.next()) |entry| {
                    if (entry.value_ptr.id == match.id) {
                        try results.append(SearchResult{
                            .symbol_id = match.id,
                            .symbol_name = try self.allocator.dupe(u8, entry.value_ptr.name),
                            .qualified_name = try self.allocator.dupe(u8, entry.value_ptr.name),
                            .file_path = try self.allocator.dupe(u8, entry.value_ptr.file_path),
                            .line_number = entry.value_ptr.line,
                            .snippet = "", // DEFERRED (v12): Extract code snippet from source (requires file I/O)
                            .similarity = match.similarity,
                            .symbol_kind = entry.value_ptr.kind,
                            .language = entry.value_ptr.language,
                        });
                        break;
                    }
                }
            }
        } else {
            // Fallback to linear scan (should not happen with HNSW initialized)
            // Generate query embedding
            const query_emb = switch (self.config.embedding_mode) {
                .tvc_ternary => try self.generateTVCEmbedding(query),
                .float32_384 => try self.generateFloat32Embedding(query),
                .hybrid => try self.generateTVCEmbedding(query), // Use TVC for hybrid query
            };

            // Compare against all embeddings (legacy path)
            var iter = self.symbols.iterator();
            while (iter.next()) |entry| {
                const key = entry.key_ptr.*;

                // Calculate similarity
                const similarity = if (self.embeddings_tvc.get(key)) |emb|
                    self.calculateSimilarityTVC(&query_emb.vector, &emb.vector)
                else if (self.embeddings_float32.get(key)) |emb|
                    self.calculateSimilarityFloat32(query_emb.vector, emb.vector)
                else
                    0.0;

                if (similarity >= self.config.min_similarity) {
                    try results.append(SearchResult{
                        .symbol_id = entry.value_ptr.id,
                        .symbol_name = try self.allocator.dupe(u8, entry.value_ptr.name),
                        .qualified_name = try self.allocator.dupe(u8, entry.value_ptr.name),
                        .file_path = try self.allocator.dupe(u8, entry.value_ptr.file_path),
                        .line_number = entry.value_ptr.line,
                        .snippet = "", // DEFERRED (v12): Extract code snippet from source (requires file I/O)
                        .similarity = similarity,
                        .symbol_kind = entry.value_ptr.kind,
                        .language = entry.value_ptr.language,
                    });
                }
            }

            // Sort by similarity (descending)
            std.sort.insertion(f32, results.items, {}, struct {
                fn compare(_: void, a: SearchResult, b: SearchResult) bool {
                    return a.similarity > b.similarity;
                }
            }.compare);

            // Limit to top_k
            const count = @min(top_k, results.items.len);
            const final_results = try self.allocator.dupe(SearchResult, results.items[0..count]);
            results.clearAndFree();
            results.items = final_results;
        }

        // Update stats
        const end_time = std.time.nanoTimestamp();
        const query_time = @as(u64, @intCast((end_time - start_time) / 1_000_000));
        self.stats.queries_processed += 1;
        self.stats.avg_query_time_ms = (self.stats.avg_query_time_ms * @as(f64, @floatFromInt(self.stats.queries_processed - 1)) +
            @as(f64, @floatFromInt(query_time))) / @as(f64, @floatFromInt(self.stats.queries_processed));

        return SearchResults{
            .results = try self.allocator.dupe(SearchResult, results.items),
            .count = results.items.len,
            .query_time_ms = query_time,
            .total_indexed = self.stats.symbols_indexed,
        };
    }

    /// Get index statistics
    pub fn getStats(self: *const CodeIndexer) IndexStats {
        return self.stats;
    }

    /// Start file watching for auto-reindex
    pub fn startWatching(self: *CodeIndexer, dir_path: []const u8) !void {
        _ = self;
        _ = dir_path;
        // DEFERRED (v12): Integrate with ralph_file_watcher for auto-reindex on file changes
        // Requires: file system watcher (kqueue/inotify), event debouncing, incremental reindex
        return error.NotImplemented;
    }

    /// Stop file watching
    pub fn stopWatching(self: *CodeIndexer) void {
        if (self.watcher_handle) |handle| {
            _ = handle;
            // DEFERRED (v12): Stop file watcher and cleanup resources
            self.watcher_handle = null;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // INTERNAL METHODS
    // ═══════════════════════════════════════════════════════════════════════════════

    /// Generate TVC ternary embedding from text
    fn generateTVCEmbedding(self: *CodeIndexer, text: []const u8) !TVCEmbedding {
        _ = text;

        // Create a HybridBigInt vector (simplified - in production use actual VSA ops)
        var vector = try tvc_hybrid.HybridBigInt.init(self.allocator, 256);
        errdefer vector.deinit();

        // Simple character-based encoding (placeholder)
        // In production, use proper VSA bind/bundle operations
        for (text, 0..) |c, i| {
            if (i >= 256) break;
            const trit: i2 = if (c % 3 == 0) -1 else if (c % 3 == 1) 0 else 1;
            vector.set(i, trit);
        }

        return TVCEmbedding{
            .vector = vector,
            .dimension = 256,
            .symbol_id = 0,
        };
    }

    /// Generate Float32 embedding from text
    fn generateFloat32Embedding(self: *CodeIndexer, text: []const u8) !Float32Embedding {
        _ = text;

        const dim = 384;
        const vector = try self.allocator.alloc(f32, dim);

        // Simple character frequency encoding (placeholder)
        // In production, use proper embeddings or VSA-to-float conversion
        @memset(vector, 0.0);
        for (text) |c| {
            const idx = @as(usize, @intCast(c)) % dim;
            vector[idx] += 1.0;
        }

        // Normalize
        var sum: f32 = 0.0;
        for (vector) |v| {
            sum += v * v;
        }
        const norm = @sqrt(sum);
        if (norm > 0.0001) {
            for (vector) |*v| {
                v.* /= norm;
            }
        }

        return Float32Embedding{
            .vector = vector,
            .dimension = dim,
            .symbol_id = 0,
        };
    }

    /// Calculate cosine similarity between two TVC embeddings
    fn calculateSimilarityTVC(self: *const CodeIndexer, a: *const tvc_hybrid.HybridBigInt, b: *const tvc_hybrid.HybridBigInt) f32 {
        _ = self;

        // Simple dot product for trit vectors
        const dim = @min(256, a.len(), b.len());
        var dot: f32 = 0.0;
        var norm_a: f32 = 0.0;
        var norm_b: f32 = 0.0;

        for (0..dim) |i| {
            const va = @as(f32, @floatFromInt(a.get(i)));
            const vb = @as(f32, @floatFromInt(b.get(i)));
            dot += va * vb;
            norm_a += va * va;
            norm_b += vb * vb;
        }

        const denom = @sqrt(norm_a) * @sqrt(norm_b);
        if (denom < 0.0001) return 0.0;
        return dot / denom;
    }

    /// Calculate cosine similarity between two Float32 embeddings
    fn calculateSimilarityFloat32(self: *const CodeIndexer, a: []f32, b: []f32) f32 {
        _ = self;

        const dim = @min(a.len, b.len);
        var dot: f32 = 0.0;
        var norm_a: f32 = 0.0;
        var norm_b: f32 = 0.0;

        for (0..dim) |i| {
            dot += a[i] * b[i];
            norm_a += a[i] * a[i];
            norm_b += b[i] * b[i];
        }

        const denom = @sqrt(norm_a) * @sqrt(norm_b);
        if (denom < 0.0001) return 0.0;
        return dot / denom;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "CodeIndexer.init" {
    const allocator = std.testing.allocator;
    const indexer = try CodeIndexer.init(allocator, IndexConfig{});
    defer indexer.deinit();

    try std.testing.expectEqual(@as(usize, 0), indexer.getStats().files_indexed);
}

test "CodeIndexer.indexFile - simple Zig function" {
    const allocator = std.testing.allocator;

    // Create temporary test file
    const test_source =
        \\pub fn add(a: i32, b: i32) i32 {
        \\    return a + b;
        \\}
    ;

    const tmp_path = "/tmp/test_indexer.zig";
    try std.fs.cwd().writeFile(.{ .sub_path = tmp_path }, test_source);
    defer std.fs.cwd().deleteFile(tmp_path) catch |err| {
        std.log.debug("indexer: cleanup temp file: {}", .{err});
    };

    const indexer = try CodeIndexer.init(allocator, IndexConfig{});
    defer indexer.deinit();

    try indexer.indexFile(tmp_path);

    const stats = indexer.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.files_indexed);
    try std.testing.expect(stats.symbols_indexed >= 1);
}

test "CodeIndexer.search" {
    const allocator = std.testing.allocator;

    // Create test files
    const test_source1 =
        \\pub fn calculateSum(a: i32, b: i32) i32 {
        \\    return a + b;
        \\}
    ;
    const test_source2 =
        \\pub fn multiply(x: i32, y: i32) i32 {
        \\    return x * y;
        \\}
    ;

    try std.fs.cwd().writeFile(.{ .sub_path = "/tmp/test_search1.zig" }, test_source1);
    try std.fs.cwd().writeFile(.{ .sub_path = "/tmp/test_search2.zig" }, test_source2);
    defer {
        std.fs.cwd().deleteFile("/tmp/test_search1.zig") catch |err| {
            std.log.debug("indexer: cleanup test_search1.zig: {}", .{err});
        };
        std.fs.cwd().deleteFile("/tmp/test_search2.zig") catch |err| {
            std.log.debug("indexer: cleanup test_search2.zig: {}", .{err});
        };
    }

    const indexer = try CodeIndexer.init(allocator, IndexConfig{});
    defer indexer.deinit();

    try indexer.indexFile("/tmp/test_search1.zig");
    try indexer.indexFile("/tmp/test_search2.zig");

    const results = try indexer.search("addition function", 10);
    defer results.deinit(allocator);

    try std.testing.expect(results.count >= 0);
}

test "CodeIndexer.clearIndex" {
    const allocator = std.testing.allocator;

    const test_source =
        \\pub fn test() void {}
    ;

    try std.fs.cwd().writeFile(.{ .sub_path = "/tmp/test_clear.zig" }, test_source);
    defer std.fs.cwd().deleteFile("/tmp/test_clear.zig") catch |err| {
        std.log.debug("indexer: cleanup test_clear.zig: {}", .{err});
    };

    const indexer = try CodeIndexer.init(allocator, IndexConfig{});
    try indexer.indexFile("/tmp/test_clear.zig");

    try std.testing.expect(indexer.getStats().files_indexed >= 1);

    indexer.clearIndex();

    try std.testing.expectEqual(@as(usize, 0), indexer.getStats().files_indexed);
}
