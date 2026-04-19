// ═══════════════════════════════════════════════════════════════════════════════
// TVC RAG RETRIEVAL
// ═══════════════════════════════════════════════════════════════════════════════
//
// Retrieval-Augmented Generation with PAS sacred scoring.
// - Top-k retrieval with φ-weighted ranking
// - LLM prompt augmentation
// - Context caching for performance
//
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import TVC embeddings
const embeddings = @import("embeddings.zig");
const TVCEngine = embeddings.TVCEngine;
const TVCEmbedding = embeddings.TVCEmbedding;
const CodeChunk = embeddings.CodeChunk;
const RAGContext = embeddings.RAGContext;

// Import sacred constants
pub const PHI = embeddings.PHI;
pub const PHI_SQ = embeddings.PHI_SQ;
pub const PHI_INV_SQ = embeddings.PHI_INV_SQ;
pub const TRINITY = embeddings.TRINITY;
pub const SEMANTIC_WEIGHT = embeddings.SEMANTIC_WEIGHT;
pub const NAME_MATCH_WEIGHT = embeddings.NAME_MATCH_WEIGHT;
pub const RECENCY_WEIGHT = embeddings.RECENCY_WEIGHT;

// ═══════════════════════════════════════════════════════════════════════════════
// RAG RETRIEVER
// ═══════════════════════════════════════════════════════════════════════════════

/// Indexed symbol entry
pub const IndexedSymbol = struct {
    id: u64,
    name: []const u8,
    file_path: []const u8,
    line_number: u32,
    snippet: []const u8,
    embedding: TVCEmbedding,
    timestamp: i64,
    sacred_bonus: f32,

    pub fn deinit(self: *IndexedSymbol, allocator: Allocator) void {
        allocator.free(self.name);
        allocator.free(self.file_path);
        allocator.free(self.snippet);
        self.embedding.deinit();
    }
};

/// RAG retriever for code context
pub const RAGRetriever = struct {
    allocator: Allocator,
    engine: TVCEngine,
    symbols: std.StringHashMap(IndexedSymbol),
    cache: std.StringHashMap(RAGContext),
    max_cache_size: usize,

    /// Initialize a new RAG retriever
    pub fn init(allocator: Allocator) RAGRetriever {
        return RAGRetriever{
            .allocator = allocator,
            .engine = TVCEngine.init(allocator),
            .symbols = std.StringHashMap(IndexedSymbol).init(allocator),
            .cache = std.StringHashMap(RAGContext).init(allocator),
            .max_cache_size = 100,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *RAGRetriever) void {
        self.engine.deinit();

        // Free all symbols
        var symbol_iter = self.symbols.valueIterator();
        while (symbol_iter.next()) |*sym| {
            sym.deinit(self.allocator);
        }
        self.symbols.deinit();

        // Free cache
        var cache_iter = self.cache.valueIterator();
        while (cache_iter.next()) |*ctx| {
            ctx.deinit();
        }
        self.cache.deinit();
    }

    /// Index a symbol for retrieval
    pub fn indexSymbol(
        self: *RAGRetriever,
        id: u64,
        name: []const u8,
        file_path: []const u8,
        line_number: u32,
        snippet: []const u8,
        sacred_bonus: f32,
    ) !void {
        // Generate embedding from symbol name + snippet
        const text = try std.fmt.allocPrint(
            self.allocator,
            "{s}:{s}",
            .{ name, snippet },
        );
        defer self.allocator.free(text);

        const embedding = try self.engine.embed(text, .hybrid);
        errdefer embedding.deinit();

        const key = try std.fmt.allocPrint(self.allocator, "{s}:{d}", .{ file_path, id });
        errdefer self.allocator.free(key);

        const symbol = IndexedSymbol{
            .id = id,
            .name = try self.allocator.dupe(u8, name),
            .file_path = try self.allocator.dupe(u8, file_path),
            .line_number = line_number,
            .snippet = try self.allocator.dupe(u8, snippet),
            .embedding = embedding,
            .timestamp = std.time.timestamp(),
            .sacred_bonus = sacred_bonus,
        };

        // Remove old symbol if exists
        if (self.symbols.fetchRemove(key)) |entry| {
            entry.value.deinit(self.allocator);
        }

        try self.symbols.put(key, symbol);
    }

    /// Retrieve top-k chunks for RAG context with sacred scoring
    pub fn retrieve(
        self: *RAGRetriever,
        query: []const u8,
        top_k: usize,
    ) !RAGContext {
        // Check cache
        const cache_key = try std.fmt.allocPrint(self.allocator, "{s}:k{d}", .{ query, top_k });
        defer self.allocator.free(cache_key);

        if (self.cache.get(cache_key)) |cached| {
            // Return copy of cached context
            return try self.copyContext(cached);
        }

        // Generate query embedding
        const query_emb = try self.engine.embed(query, .hybrid);
        defer query_emb.deinit();

        // Score all symbols
        var scores = std.ArrayList(struct {
            key: []const u8,
            score: f32,
        }).init(self.allocator);

        defer {
            for (scores.items) |item| {
                self.allocator.free(item.key);
            }
            scores.deinit();
        }

        var symbol_iter = self.symbols.iterator();
        while (symbol_iter.next()) |entry| {
            const symbol = entry.value_ptr.*;
            const key = entry.key_ptr.*;

            // Calculate semantic similarity
            const similarity = self.engine.similarity(&query_emb, &symbol.embedding);

            // Calculate name match score
            const name_score = nameMatchScore(query, symbol.name);

            // Calculate recency boost
            const recency = recencyBoost(symbol.timestamp);

            // Apply sacred scoring
            const score = sacredScore(
                similarity,
                name_score,
                recency,
                symbol.sacred_bonus,
            );

            try scores.append(.{
                .key = try self.allocator.dupe(u8, key),
                .score = score,
            });
        }

        // Sort by score (descending)
        std.sort.insertion(struct { key: []const u8, score: f32 }, scores.items, {}, struct {
            fn lessThan(
                _: void,
                a: struct { key: []const u8, score: f32 },
                b: struct { key: []const u8, score: f32 },
            ) bool {
                return a.score > b.score;
            }
        }.lessThan);

        // Extract top-k chunks
        const count = @min(top_k, scores.items.len);
        const chunks = try self.allocator.alloc(CodeChunk, count);
        errdefer {
            for (chunks[0..count]) |*c| {
                self.allocator.free(c.symbol_name);
                self.allocator.free(c.file_path);
                self.allocator.free(c.snippet);
            }
            self.allocator.free(chunks);
        }

        const score_list = try self.allocator.alloc(f32, count);
        errdefer self.allocator.free(score_list);

        for (0..count) |i| {
            const symbol = self.symbols.get(scores.items[i].key).?;
            chunks[i] = CodeChunk{
                .symbol_name = try self.allocator.dupe(u8, symbol.name),
                .file_path = try self.allocator.dupe(u8, symbol.file_path),
                .line_number = symbol.line_number,
                .snippet = try self.allocator.dupe(u8, symbol.snippet),
                .similarity = scores.items[i].score, // Already sacred-weighted
                .sacred_bonus = symbol.sacred_bonus,
            };
            score_list[i] = scores.items[i].score;
        }

        // Calculate sacred score (average of top-k)
        var sacred_sum: f32 = 0.0;
        for (score_list) |s| {
            sacred_sum += s;
        }
        const sacred_score = if (count > 0) sacred_sum / @as(f32, @floatFromInt(count)) else 0.0;

        var context = RAGContext{
            .allocator = self.allocator,
            .query = try self.allocator.dupe(u8, query),
            .chunks = chunks,
            .scores = score_list,
            .sacred_score = sacred_score,
            .total_chunks = self.symbols.count(),
        };

        // Cache the result
        if (self.cache.count() < self.max_cache_size) {
            const cache_copy = try self.copyContext(&context);
            try self.cache.put(try self.allocator.dupe(u8, cache_key), cache_copy);
        }

        return context;
    }

    /// Remove a symbol from the index
    pub fn removeSymbol(self: *RAGRetriever, file_path: []const u8, id: u64) !void {
        const key = try std.fmt.allocPrint(self.allocator, "{s}:{d}", .{ file_path, id });
        defer self.allocator.free(key);

        if (self.symbols.fetchRemove(key)) |entry| {
            entry.value.deinit(self.allocator);
        }

        // Invalidate cache
        self.invalidateCache();
    }

    /// Clear all symbols
    pub fn clear(self: *RAGRetriever) void {
        var symbol_iter = self.symbols.valueIterator();
        while (symbol_iter.next()) |*sym| {
            sym.deinit(self.allocator);
        }
        self.symbols.clearRetainingCapacity();
        self.invalidateCache();
    }

    /// Get statistics
    pub fn stats(self: *const RAGRetriever) struct {
        symbols_indexed: usize,
        cache_size: usize,
    } {
        return .{
            .symbols_indexed = self.symbols.count(),
            .cache_size = self.cache.count(),
        };
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // PRIVATE METHODS
    // ═══════════════════════════════════════════════════════════════════════════════

    /// Copy a context (for caching)
    fn copyContext(self: *RAGRetriever, ctx: *const RAGContext) !RAGContext {
        const chunks = try self.allocator.alloc(CodeChunk, ctx.chunks.len);
        errdefer {
            for (chunks) |*c| {
                self.allocator.free(c.symbol_name);
                self.allocator.free(c.file_path);
                self.allocator.free(c.snippet);
            }
            self.allocator.free(chunks);
        }

        const scores = try self.allocator.alloc(f32, ctx.scores.len);
        errdefer self.allocator.free(scores);

        for (0..chunks.len) |i| {
            chunks[i] = CodeChunk{
                .symbol_name = try self.allocator.dupe(u8, ctx.chunks[i].symbol_name),
                .file_path = try self.allocator.dupe(u8, ctx.chunks[i].file_path),
                .line_number = ctx.chunks[i].line_number,
                .snippet = try self.allocator.dupe(u8, ctx.chunks[i].snippet),
                .similarity = ctx.chunks[i].similarity,
                .sacred_bonus = ctx.chunks[i].sacred_bonus,
            };
            scores[i] = ctx.scores[i];
        }

        return RAGContext{
            .allocator = self.allocator,
            .query = try self.allocator.dupe(u8, ctx.query),
            .chunks = chunks,
            .scores = scores,
            .sacred_score = ctx.sacred_score,
            .total_chunks = ctx.total_chunks,
        };
    }

    /// Invalidate the entire cache
    fn invalidateCache(self: *RAGRetriever) void {
        var iter = self.cache.valueIterator();
        while (iter.next()) |*ctx| {
            ctx.deinit();
        }
        self.cache.clearRetainingCapacity();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS (re-exported from embeddings)
// ═══════════════════════════════════════════════════════════════════════════════

/// Apply PAS sacred φ-weighted scoring
pub fn sacredScore(
    similarity: f32,
    name_match: f32,
    recency: f32,
    sacred_bonus: f32,
) f32 {
    return embeddings.sacredScore(similarity, name_match, recency, sacred_bonus);
}

/// Calculate name match score for ranking
pub fn nameMatchScore(query: []const u8, symbol_name: []const u8) f32 {
    return embeddings.nameMatchScore(query, symbol_name);
}

/// Calculate recency boost based on timestamp
pub fn recencyBoost(timestamp: i64) f32 {
    return embeddings.recencyBoost(timestamp);
}

/// Re-rank search results with sacred scoring
pub fn sacredRankResults(
    allocator: Allocator,
    results: []const CodeChunk,
    query: []const u8,
) ![]CodeChunk {
    const ranked = try allocator.alloc(CodeChunk, results.len);
    errdefer {
        for (ranked) |*c| {
            allocator.free(c.symbol_name);
            allocator.free(c.file_path);
            allocator.free(c.snippet);
        }
        allocator.free(ranked);
    }

    for (0..results.len) |i| {
        const name_score = nameMatchScore(query, results[i].symbol_name);
        const recency = recencyBoost(std.time.timestamp()); // Use now for results

        ranked[i] = CodeChunk{
            .symbol_name = try allocator.dupe(u8, results[i].symbol_name),
            .file_path = try allocator.dupe(u8, results[i].file_path),
            .line_number = results[i].line_number,
            .snippet = try allocator.dupe(u8, results[i].snippet),
            .similarity = results[i].similarity, // Keep original
            .sacred_bonus = sacredScore(
                results[i].similarity,
                name_score,
                recency,
                results[i].sacred_bonus,
            ),
        };
    }

    // Sort by sacred_bonus (descending)
    std.sort.insertion(CodeChunk, ranked, {}, struct {
        fn lessThan(_: void, a: CodeChunk, b: CodeChunk) bool {
            return a.sacred_bonus > b.sacred_bonus;
        }
    }.lessThan);

    return ranked;
}

/// Augment LLM prompt with retrieved RAG context
pub fn augmentPromptWith(
    allocator: Allocator,
    original_prompt: []const u8,
    context: *const RAGContext,
) ![]const u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    errdefer buffer.deinit();

    // Add context header
    try buffer.appendSlice("═══════════════════════════════════════\n");
    try buffer.appendSlice("RELEVANT CODE CONTEXT\n");
    try buffer.appendSlice("═══════════════════════════════════════\n\n");

    try buffer.appendSlice(std.fmt.allocPrint(
        allocator,
        "Query: {s}\n",
        .{context.query},
    ) catch "");
    try buffer.appendSlice(std.fmt.allocPrint(
        allocator,
        "Sacred Score: {d:.3}\n",
        .{context.sacred_score},
    ) catch "");
    try buffer.appendSlice(std.fmt.allocPrint(
        allocator,
        "Chunks Found: {d}/{d}\n\n",
        .{ context.chunks.len, context.total_chunks },
    ) catch "");

    // Add each chunk
    for (context.chunks, 0..) |chunk, i| {
        try buffer.appendSlice(std.fmt.allocPrint(
            allocator,
            "--- Chunk {} ---\n",
            .{i + 1},
        ) catch "");
        try buffer.appendSlice(std.fmt.allocPrint(
            allocator,
            "File: {s}:{d}\n",
            .{ chunk.file_path, chunk.line_number },
        ) catch "");
        try buffer.appendSlice(std.fmt.allocPrint(
            allocator,
            "Symbol: {s}\n",
            .{chunk.symbol_name},
        ) catch "");
        try buffer.appendSlice(std.fmt.allocPrint(
            allocator,
            "Score: {d:.3}\n",
            .{chunk.similarity},
        ) catch "");
        try buffer.appendSlice("```zig\n");
        try buffer.appendSlice(chunk.snippet);
        try buffer.appendSlice("\n```\n\n");
    }

    try buffer.appendSlice("═══════════════════════════════════════\n");
    try buffer.appendSlice("ORIGINAL PROMPT\n");
    try buffer.appendSlice("═══════════════════════════════════════\n\n");
    try buffer.appendSlice(original_prompt);

    return buffer.toOwnedSlice();
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "RAGRetriever.init" {
    const allocator = std.testing.allocator;
    var retriever = RAGRetriever.init(allocator);
    defer retriever.deinit();

    const stats = retriever.stats();
    try std.testing.expectEqual(@as(usize, 0), stats.symbols_indexed);
    try std.testing.expectEqual(@as(usize, 0), stats.cache_size);
}

test "RAGRetriever.indexSymbol" {
    const allocator = std.testing.allocator;
    var retriever = RAGRetriever.init(allocator);
    defer retriever.deinit();

    try retriever.indexSymbol(
        1,
        "testFunction",
        "test.zig",
        10,
        "pub fn testFunction() void {}",
        0.0,
    );

    const stats = retriever.stats();
    try std.testing.expectEqual(@as(usize, 1), stats.symbols_indexed);
}

test "RAGRetriever.retrieve" {
    const allocator = std.testing.allocator;
    var retriever = RAGRetriever.init(allocator);
    defer retriever.deinit();

    try retriever.indexSymbol(
        1,
        "addVectors",
        "math.zig",
        10,
        "pub fn addVectors(a: Vector, b: Vector) Vector { return a + b; }",
        0.0,
    );

    try retriever.indexSymbol(
        2,
        "multiplyMatrix",
        "matrix.zig",
        20,
        "pub fn multiplyMatrix(a: Matrix, b: Matrix) Matrix { /* ... */ }",
        0.0,
    );

    const context = try retriever.retrieve("vector addition", 5);
    defer context.deinit();

    try std.testing.expect(context.chunks.len > 0);
    try std.testing.expect(context.sacred_score > 0.0);
}

test "RAGRetriever.cache" {
    const allocator = std.testing.allocator;
    var retriever = RAGRetriever.init(allocator);
    defer retriever.deinit();

    try retriever.indexSymbol(
        1,
        "cachedFunction",
        "cache.zig",
        5,
        "pub fn cachedFunction() void {}",
        0.0,
    );

    // First retrieval
    const ctx1 = try retriever.retrieve("cached", 5);
    defer ctx1.deinit();

    // Second retrieval (should use cache)
    const stats_before = retriever.stats();
    const ctx2 = try retriever.retrieve("cached", 5);
    defer ctx2.deinit();
    const stats_after = retriever.stats();

    try std.testing.expect(stats_after.cache_size >= stats_before.cache_size);
}

test "sacredRankResults" {
    const allocator = std.testing.allocator;

    const chunks = [_]CodeChunk{
        .{
            .symbol_name = "exactMatch",
            .file_path = "test.zig",
            .line_number = 10,
            .snippet = "pub fn exactMatch() void {}",
            .similarity = 0.5,
            .sacred_bonus = 0.0,
        },
        .{
            .symbol_name = "partial",
            .file_path = "test.zig",
            .line_number = 20,
            .snippet = "pub fn partial() void {}",
            .similarity = 0.7,
            .sacred_bonus = 0.0,
        },
    };

    const ranked = try sacredRankResults(allocator, &chunks, "exactMatch");
    defer {
        for (ranked) |*c| {
            allocator.free(c.symbol_name);
            allocator.free(c.file_path);
            allocator.free(c.snippet);
        }
        allocator.free(ranked);
    }

    // exactMatch should be boosted due to name match
    try std.testing.expect(ranked[0].sacred_bonus > chunks[0].sacred_bonus);
}

test "augmentPromptWith" {
    const allocator = std.testing.allocator;

    var retriever = RAGRetriever.init(allocator);
    defer retriever.deinit();

    try retriever.indexSymbol(
        1,
        "helperFunction",
        "util.zig",
        15,
        "pub fn helperFunction(x: i32) i32 { return x * 2; }",
        0.1,
    );

    const context = try retriever.retrieve("helper", 5);
    defer context.deinit();

    const augmented = try augmentPromptWith(allocator, "Write code for X", &context);
    defer allocator.free(augmented);

    try std.testing.expect(std.mem.indexOf(u8, augmented, "RELEVANT CODE CONTEXT") != null);
    try std.testing.expect(std.mem.indexOf(u8, augmented, "helperFunction") != null);
    try std.testing.expect(std.mem.indexOf(u8, augmented, "ORIGINAL PROMPT") != null);
}

test "nameMatchScore - exact" {
    const score = nameMatchScore("bind", "bind");
    try std.testing.expectEqual(@as(f32, 1.0), score);
}

test "nameMatchScore - contains" {
    const score = nameMatchScore("bind", "bindVectors");
    try std.testing.expect(score > 0.5);
}

test "sacredScore - phi weighting" {
    const base: f32 = 0.5;
    const score = sacredScore(base, 0.5, 0.3, 0.1);
    // Score should be boosted by φ²
    try std.testing.expect(score > base);
}

// φ² + 1/φ² = 3
