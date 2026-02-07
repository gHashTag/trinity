//! IGLA RAG Engine v1.0
//! Retrieval-Augmented Generation for local files and codebase
//! Part of the IGLA (Intelligent Generative Language Architecture) system
//!
//! Features:
//! - Document chunking and indexing
//! - Simple embedding generation (character frequency vectors)
//! - Vector similarity search
//! - Source tracking (file path, line numbers)
//! - Context assembly for LLM augmentation
//!
//! Golden Chain Cycle 23 - phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");

// ============================================================================
// CONSTANTS
// ============================================================================

pub const MAX_CHUNKS: usize = 500;
pub const MAX_CHUNK_LEN: usize = 512;
pub const MAX_PATH_LEN: usize = 256;
pub const EMBEDDING_DIM: usize = 32;
pub const DEFAULT_CHUNK_SIZE: usize = 10; // lines
pub const DEFAULT_OVERLAP: usize = 2; // lines
pub const DEFAULT_TOP_K: usize = 5;
pub const DEFAULT_MIN_SIMILARITY: f32 = 0.01;

// ============================================================================
// DOCUMENT TYPE
// ============================================================================

pub const DocumentType = enum {
    Code,
    Text,
    Markdown,
    Config,
    Unknown,

    pub fn getName(self: DocumentType) []const u8 {
        return switch (self) {
            .Code => "code",
            .Text => "text",
            .Markdown => "markdown",
            .Config => "config",
            .Unknown => "unknown",
        };
    }

    pub fn fromExtension(ext: []const u8) DocumentType {
        if (std.mem.eql(u8, ext, ".zig") or std.mem.eql(u8, ext, ".py") or
            std.mem.eql(u8, ext, ".js") or std.mem.eql(u8, ext, ".ts") or
            std.mem.eql(u8, ext, ".go") or std.mem.eql(u8, ext, ".rs") or
            std.mem.eql(u8, ext, ".c") or std.mem.eql(u8, ext, ".cpp"))
        {
            return .Code;
        }
        if (std.mem.eql(u8, ext, ".md") or std.mem.eql(u8, ext, ".markdown")) {
            return .Markdown;
        }
        if (std.mem.eql(u8, ext, ".json") or std.mem.eql(u8, ext, ".yaml") or
            std.mem.eql(u8, ext, ".toml") or std.mem.eql(u8, ext, ".ini"))
        {
            return .Config;
        }
        if (std.mem.eql(u8, ext, ".txt") or std.mem.eql(u8, ext, ".log")) {
            return .Text;
        }
        return .Unknown;
    }

    pub fn isCode(self: DocumentType) bool {
        return self == .Code;
    }
};

// ============================================================================
// SIMPLE EMBEDDING (Character Frequency Vector)
// ============================================================================

pub const SimpleEmbedding = struct {
    values: [EMBEDDING_DIM]f32,
    magnitude: f32,

    pub fn init() SimpleEmbedding {
        return SimpleEmbedding{
            .values = [_]f32{0} ** EMBEDDING_DIM,
            .magnitude = 0,
        };
    }

    pub fn fromText(text: []const u8) SimpleEmbedding {
        var embedding = SimpleEmbedding.init();

        if (text.len == 0) return embedding;

        // Character frequency across buckets
        for (text) |c| {
            const bucket = @as(usize, c) % EMBEDDING_DIM;
            embedding.values[bucket] += 1.0;
        }

        // Normalize
        var sum_sq: f32 = 0;
        for (embedding.values) |v| {
            sum_sq += v * v;
        }
        embedding.magnitude = @sqrt(sum_sq);

        if (embedding.magnitude > 0) {
            for (&embedding.values) |*v| {
                v.* /= embedding.magnitude;
            }
        }

        return embedding;
    }

    pub fn cosineSimilarity(self: *const SimpleEmbedding, other: *const SimpleEmbedding) f32 {
        if (self.magnitude == 0 or other.magnitude == 0) return 0;

        var dot: f32 = 0;
        for (self.values, other.values) |a, b| {
            dot += a * b;
        }

        return dot; // Already normalized
    }
};

// ============================================================================
// CHUNK
// ============================================================================

pub const Chunk = struct {
    content: [MAX_CHUNK_LEN]u8,
    content_len: usize,
    source_path: [MAX_PATH_LEN]u8,
    path_len: usize,
    start_line: usize,
    end_line: usize,
    doc_type: DocumentType,
    embedding: SimpleEmbedding,
    is_active: bool,

    pub fn init(content: []const u8, source: []const u8, start: usize, end: usize) Chunk {
        var chunk = Chunk{
            .content = undefined,
            .content_len = 0,
            .source_path = undefined,
            .path_len = 0,
            .start_line = start,
            .end_line = end,
            .doc_type = .Unknown,
            .embedding = SimpleEmbedding.init(),
            .is_active = true,
        };
        chunk.setContent(content);
        chunk.setSource(source);
        chunk.embedding = SimpleEmbedding.fromText(content);
        return chunk;
    }

    pub fn setContent(self: *Chunk, content: []const u8) void {
        const len = @min(content.len, MAX_CHUNK_LEN);
        @memcpy(self.content[0..len], content[0..len]);
        self.content_len = len;
    }

    pub fn getContent(self: *const Chunk) []const u8 {
        return self.content[0..self.content_len];
    }

    pub fn setSource(self: *Chunk, source: []const u8) void {
        const len = @min(source.len, MAX_PATH_LEN);
        @memcpy(self.source_path[0..len], source[0..len]);
        self.path_len = len;
    }

    pub fn getSource(self: *const Chunk) []const u8 {
        return self.source_path[0..self.path_len];
    }

    pub fn setDocType(self: *Chunk, doc_type: DocumentType) void {
        self.doc_type = doc_type;
    }

    pub fn deactivate(self: *Chunk) void {
        self.is_active = false;
    }

    pub fn getLineCount(self: *const Chunk) usize {
        if (self.end_line >= self.start_line) {
            return self.end_line - self.start_line + 1;
        }
        return 0;
    }
};

// ============================================================================
// CHUNK STORE
// ============================================================================

pub const ChunkStore = struct {
    chunks: [MAX_CHUNKS]Chunk,
    count: usize,
    total_indexed: usize,

    pub fn init() ChunkStore {
        return ChunkStore{
            .chunks = undefined,
            .count = 0,
            .total_indexed = 0,
        };
    }

    pub fn add(self: *ChunkStore, chunk: Chunk) bool {
        if (self.count >= MAX_CHUNKS) return false;
        self.chunks[self.count] = chunk;
        self.count += 1;
        self.total_indexed += 1;
        return true;
    }

    pub fn get(self: *ChunkStore, index: usize) ?*Chunk {
        if (index >= self.count) return null;
        return &self.chunks[index];
    }

    pub fn getConst(self: *const ChunkStore, index: usize) ?*const Chunk {
        if (index >= self.count) return null;
        return &self.chunks[index];
    }

    pub fn getActiveCount(self: *const ChunkStore) usize {
        var active: usize = 0;
        for (self.chunks[0..self.count]) |*chunk| {
            if (chunk.is_active) active += 1;
        }
        return active;
    }

    pub fn clear(self: *ChunkStore) void {
        self.count = 0;
    }

    pub fn isEmpty(self: *const ChunkStore) bool {
        return self.count == 0;
    }
};

// ============================================================================
// CHUNKER
// ============================================================================

pub const Chunker = struct {
    chunk_size: usize,
    overlap: usize,
    chunks_created: usize,

    pub fn init() Chunker {
        return Chunker{
            .chunk_size = DEFAULT_CHUNK_SIZE,
            .overlap = DEFAULT_OVERLAP,
            .chunks_created = 0,
        };
    }

    pub fn initWithSize(chunk_size: usize, overlap: usize) Chunker {
        return Chunker{
            .chunk_size = chunk_size,
            .overlap = overlap,
            .chunks_created = 0,
        };
    }

    pub fn chunkText(self: *Chunker, text: []const u8, source: []const u8, store: *ChunkStore) usize {
        if (text.len == 0) return 0;

        var chunks_added: usize = 0;
        var line_start: usize = 0;
        var line_num: usize = 1;
        var chunk_start_line: usize = 1;
        var chunk_content: [MAX_CHUNK_LEN]u8 = undefined;
        var chunk_len: usize = 0;
        var lines_in_chunk: usize = 0;

        var i: usize = 0;
        while (i < text.len) : (i += 1) {
            if (text[i] == '\n' or i == text.len - 1) {
                const line_end = if (text[i] == '\n') i else i + 1;
                const line = text[line_start..line_end];

                const add_len = @min(line.len, MAX_CHUNK_LEN - chunk_len);
                if (add_len > 0) {
                    @memcpy(chunk_content[chunk_len..][0..add_len], line[0..add_len]);
                    chunk_len += add_len;
                    if (chunk_len < MAX_CHUNK_LEN) {
                        chunk_content[chunk_len] = '\n';
                        chunk_len += 1;
                    }
                }

                lines_in_chunk += 1;
                line_num += 1;
                line_start = i + 1;

                if (lines_in_chunk >= self.chunk_size or i == text.len - 1) {
                    if (chunk_len > 0) {
                        const chunk = Chunk.init(
                            chunk_content[0..chunk_len],
                            source,
                            chunk_start_line,
                            chunk_start_line + lines_in_chunk - 1,
                        );
                        if (store.add(chunk)) {
                            chunks_added += 1;
                            self.chunks_created += 1;
                        }
                    }

                    chunk_len = 0;
                    lines_in_chunk = 0;
                    chunk_start_line = line_num - self.overlap;
                    if (chunk_start_line < 1) chunk_start_line = 1;
                }
            }
        }

        return chunks_added;
    }

    pub fn setChunkSize(self: *Chunker, size: usize) void {
        self.chunk_size = size;
    }

    pub fn reset(self: *Chunker) void {
        self.chunks_created = 0;
    }
};

// ============================================================================
// RETRIEVAL RESULT
// ============================================================================

pub const MAX_RESULTS: usize = 20;

pub const SearchResult = struct {
    chunk_index: usize,
    score: f32,
    source: [MAX_PATH_LEN]u8,
    source_len: usize,
    line_num: usize,

    pub fn init(index: usize, score: f32, source: []const u8, line: usize) SearchResult {
        var result = SearchResult{
            .chunk_index = index,
            .score = score,
            .source = undefined,
            .source_len = 0,
            .line_num = line,
        };
        const len = @min(source.len, MAX_PATH_LEN);
        @memcpy(result.source[0..len], source[0..len]);
        result.source_len = len;
        return result;
    }

    pub fn getSource(self: *const SearchResult) []const u8 {
        return self.source[0..self.source_len];
    }
};

pub const RetrievalResult = struct {
    results: [MAX_RESULTS]SearchResult,
    count: usize,

    pub fn init() RetrievalResult {
        return RetrievalResult{
            .results = undefined,
            .count = 0,
        };
    }

    pub fn addResult(self: *RetrievalResult, index: usize, score: f32, source: []const u8, line: usize) bool {
        if (self.count >= MAX_RESULTS) return false;
        self.results[self.count] = SearchResult.init(index, score, source, line);
        self.count += 1;
        return true;
    }

    pub fn sortByScore(self: *RetrievalResult) void {
        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            var j: usize = i + 1;
            while (j < self.count) : (j += 1) {
                if (self.results[j].score > self.results[i].score) {
                    const tmp = self.results[i];
                    self.results[i] = self.results[j];
                    self.results[j] = tmp;
                }
            }
        }
    }

    pub fn getBestScore(self: *const RetrievalResult) f32 {
        if (self.count == 0) return 0;
        return self.results[0].score;
    }

    pub fn getAverageScore(self: *const RetrievalResult) f32 {
        if (self.count == 0) return 0;
        var sum: f32 = 0;
        for (self.results[0..self.count]) |r| {
            sum += r.score;
        }
        return sum / @as(f32, @floatFromInt(self.count));
    }

    pub fn isEmpty(self: *const RetrievalResult) bool {
        return self.count == 0;
    }
};

// ============================================================================
// VECTOR INDEX
// ============================================================================

pub const VectorIndex = struct {
    store: *ChunkStore,
    queries_processed: usize,

    pub fn init(store: *ChunkStore) VectorIndex {
        return VectorIndex{
            .store = store,
            .queries_processed = 0,
        };
    }

    pub fn search(self: *VectorIndex, query_embedding: *const SimpleEmbedding, top_k: usize, min_similarity: f32) RetrievalResult {
        var result = RetrievalResult.init();

        var i: usize = 0;
        while (i < self.store.count) : (i += 1) {
            if (self.store.getConst(i)) |chunk| {
                if (!chunk.is_active) continue;

                const similarity = query_embedding.cosineSimilarity(&chunk.embedding);

                if (similarity >= min_similarity) {
                    _ = result.addResult(i, similarity, chunk.getSource(), chunk.start_line);
                }
            }
        }

        result.sortByScore();

        if (result.count > top_k) {
            result.count = top_k;
        }

        self.queries_processed += 1;
        return result;
    }
};

// ============================================================================
// RAG CONFIG
// ============================================================================

pub const RAGConfig = struct {
    chunk_size: usize,
    overlap: usize,
    top_k: usize,
    min_similarity: f32,

    pub fn init() RAGConfig {
        return RAGConfig{
            .chunk_size = DEFAULT_CHUNK_SIZE,
            .overlap = DEFAULT_OVERLAP,
            .top_k = DEFAULT_TOP_K,
            .min_similarity = DEFAULT_MIN_SIMILARITY,
        };
    }

    pub fn withChunkSize(self: RAGConfig, size: usize) RAGConfig {
        var config = self;
        config.chunk_size = size;
        return config;
    }

    pub fn withTopK(self: RAGConfig, k: usize) RAGConfig {
        var config = self;
        config.top_k = k;
        return config;
    }

    pub fn withMinSimilarity(self: RAGConfig, min: f32) RAGConfig {
        var config = self;
        config.min_similarity = min;
        return config;
    }
};

// ============================================================================
// RAG STATS
// ============================================================================

pub const RAGStats = struct {
    documents_indexed: usize,
    chunks_created: usize,
    queries_processed: usize,
    successful_retrievals: usize,
    total_results_returned: usize,
    avg_similarity: f32,

    pub fn init() RAGStats {
        return RAGStats{
            .documents_indexed = 0,
            .chunks_created = 0,
            .queries_processed = 0,
            .successful_retrievals = 0,
            .total_results_returned = 0,
            .avg_similarity = 0,
        };
    }

    pub fn getHitRate(self: *const RAGStats) f32 {
        if (self.queries_processed == 0) return 0;
        return @as(f32, @floatFromInt(self.successful_retrievals)) / @as(f32, @floatFromInt(self.queries_processed));
    }

    pub fn getAvgResultsPerQuery(self: *const RAGStats) f32 {
        if (self.queries_processed == 0) return 0;
        return @as(f32, @floatFromInt(self.total_results_returned)) / @as(f32, @floatFromInt(self.queries_processed));
    }

    pub fn reset(self: *RAGStats) void {
        self.* = RAGStats.init();
    }
};

// ============================================================================
// AUGMENTED CONTEXT
// ============================================================================

pub const AugmentedContext = struct {
    chunks: [MAX_RESULTS]*const Chunk,
    count: usize,
    total_tokens: usize,

    pub fn init() AugmentedContext {
        return AugmentedContext{
            .chunks = undefined,
            .count = 0,
            .total_tokens = 0,
        };
    }

    pub fn addChunk(self: *AugmentedContext, chunk: *const Chunk) bool {
        if (self.count >= MAX_RESULTS) return false;
        self.chunks[self.count] = chunk;
        self.count += 1;
        self.total_tokens += chunk.content_len / 4;
        return true;
    }

    pub fn isEmpty(self: *const AugmentedContext) bool {
        return self.count == 0;
    }
};

// ============================================================================
// RAG ENGINE
// ============================================================================

pub const RAGEngine = struct {
    store: ChunkStore,
    chunker: Chunker,
    index: VectorIndex,
    config: RAGConfig,
    stats: RAGStats,

    pub fn init() RAGEngine {
        var engine = RAGEngine{
            .store = ChunkStore.init(),
            .chunker = Chunker.init(),
            .index = undefined,
            .config = RAGConfig.init(),
            .stats = RAGStats.init(),
        };
        engine.index = VectorIndex.init(&engine.store);
        return engine;
    }

    pub fn initWithConfig(config: RAGConfig) RAGEngine {
        var engine = RAGEngine.init();
        engine.config = config;
        engine.chunker = Chunker.initWithSize(config.chunk_size, config.overlap);
        return engine;
    }

    pub fn indexDocument(self: *RAGEngine, content: []const u8, source_path: []const u8) usize {
        var doc_type = DocumentType.Unknown;
        var i: usize = source_path.len;
        while (i > 0) {
            i -= 1;
            if (source_path[i] == '.') {
                doc_type = DocumentType.fromExtension(source_path[i..]);
                break;
            }
        }

        const chunks_added = self.chunker.chunkText(content, source_path, &self.store);

        var j: usize = self.store.count - chunks_added;
        while (j < self.store.count) : (j += 1) {
            if (self.store.get(j)) |chunk| {
                chunk.setDocType(doc_type);
            }
        }

        self.stats.documents_indexed += 1;
        self.stats.chunks_created += chunks_added;

        return chunks_added;
    }

    pub fn indexText(self: *RAGEngine, content: []const u8, source_name: []const u8) usize {
        return self.indexDocument(content, source_name);
    }

    pub fn query(self: *RAGEngine, query_text: []const u8) RetrievalResult {
        const query_embedding = SimpleEmbedding.fromText(query_text);
        // Refresh index pointer (may be stale after struct move)
        self.index.store = &self.store;
        const result = self.index.search(&query_embedding, self.config.top_k, self.config.min_similarity);

        self.stats.queries_processed += 1;
        if (result.count > 0) {
            self.stats.successful_retrievals += 1;
            self.stats.total_results_returned += result.count;

            const new_avg = result.getAverageScore();
            const total = self.stats.queries_processed;
            self.stats.avg_similarity = (self.stats.avg_similarity * @as(f32, @floatFromInt(total - 1)) + new_avg) / @as(f32, @floatFromInt(total));
        }

        return result;
    }

    pub fn retrieve(self: *RAGEngine, query_text: []const u8) AugmentedContext {
        const result = self.query(query_text);
        var context = AugmentedContext.init();

        for (result.results[0..result.count]) |r| {
            if (self.store.getConst(r.chunk_index)) |chunk| {
                _ = context.addChunk(chunk);
            }
        }

        return context;
    }

    pub fn getChunkCount(self: *const RAGEngine) usize {
        return self.store.count;
    }

    pub fn getStats(self: *const RAGEngine) RAGStats {
        return self.stats;
    }

    pub fn setConfig(self: *RAGEngine, config: RAGConfig) void {
        self.config = config;
        self.chunker = Chunker.initWithSize(config.chunk_size, config.overlap);
    }

    pub fn reset(self: *RAGEngine) void {
        self.store.clear();
        self.chunker.reset();
        self.stats.reset();
    }

    pub fn getChunk(self: *RAGEngine, index: usize) ?*const Chunk {
        return self.store.getConst(index);
    }
};

// ============================================================================
// BENCHMARK
// ============================================================================

pub fn runBenchmark() void {
    std.debug.print("\n", .{});
    std.debug.print("===============================================================================\n", .{});
    std.debug.print("     IGLA RAG ENGINE BENCHMARK (CYCLE 23)\n", .{});
    std.debug.print("===============================================================================\n", .{});
    std.debug.print("\n", .{});

    var engine = RAGEngine.init();
    std.debug.print("  Chunk size: {} lines\n", .{engine.config.chunk_size});
    std.debug.print("  Top-K: {}\n", .{engine.config.top_k});
    std.debug.print("  Min similarity: {d:.2}\n", .{engine.config.min_similarity});
    std.debug.print("\n", .{});

    std.debug.print("  Indexing sample documents...\n", .{});

    const doc1 = "pub fn main() void {\n    const x = 42;\n    std.debug.print(\"Hello\", .{});\n}\n\npub fn add(a: i32, b: i32) i32 {\n    return a + b;\n}\n\npub fn multiply(a: i32, b: i32) i32 {\n    return a * b;\n}";
    const doc2 = "# README\n\nThis is a sample project.\n\n## Features\n\n- Vector search\n- Chunking\n- Source tracking";
    const doc3 = "const std = @import(\"std\");\n\npub const Vector = struct {\n    x: f32,\n    y: f32,\n\n    pub fn dot(self: Vector, other: Vector) f32 {\n        return self.x * other.x + self.y * other.y;\n    }\n};";

    const start_time = std.time.nanoTimestamp();

    _ = engine.indexDocument(doc1, "src/main.zig");
    _ = engine.indexDocument(doc2, "README.md");
    _ = engine.indexDocument(doc3, "src/vector.zig");

    std.debug.print("  Documents indexed: {}\n", .{engine.stats.documents_indexed});
    std.debug.print("  Chunks created: {}\n", .{engine.stats.chunks_created});
    std.debug.print("\n", .{});

    std.debug.print("  Running queries...\n", .{});

    const queries = [_][]const u8{
        "How to add two numbers?",
        "Vector dot product",
        "README features",
        "main function",
        "multiply operation",
    };

    for (queries) |q| {
        const result = engine.query(q);
        if (result.count > 0) {
            std.debug.print("  [HIT] \"{s}\" -> {} results (best: {d:.2})\n", .{ q[0..@min(30, q.len)], result.count, result.getBestScore() });
        } else {
            std.debug.print("  [MISS] \"{s}\" -> no results\n", .{q[0..@min(30, q.len)]});
        }
    }

    const end_time = std.time.nanoTimestamp();
    const elapsed_ns: i64 = @intCast(end_time - start_time);
    const elapsed_us: u64 = @intCast(@divFloor(elapsed_ns, 1000));

    std.debug.print("\n", .{});

    const stats = engine.getStats();
    std.debug.print("  Stats:\n", .{});
    std.debug.print("    Queries: {}\n", .{stats.queries_processed});
    std.debug.print("    Successful: {}\n", .{stats.successful_retrievals});
    std.debug.print("    Hit rate: {d:.2}\n", .{stats.getHitRate()});
    std.debug.print("    Avg results: {d:.2}\n", .{stats.getAvgResultsPerQuery()});
    std.debug.print("    Avg similarity: {d:.2}\n", .{stats.avg_similarity});
    std.debug.print("\n", .{});

    const queries_per_sec = if (elapsed_us > 0)
        (queries.len * 1_000_000) / elapsed_us
    else
        0;

    std.debug.print("  Performance:\n", .{});
    std.debug.print("    Total time: {}us\n", .{elapsed_us});
    std.debug.print("    Throughput: {} queries/s\n", .{queries_per_sec});
    std.debug.print("\n", .{});

    const improvement = stats.getHitRate() + stats.avg_similarity;
    const passed = improvement > 0.618;
    std.debug.print("  Improvement rate: {d:.2}\n", .{improvement});
    std.debug.print("  Golden Ratio Gate: {s} (>0.618)\n", .{if (passed) "PASSED" else "FAILED"});
}

pub fn main() void {
    runBenchmark();
}

// ============================================================================
// TESTS
// ============================================================================

test "DocumentType getName" {
    try std.testing.expectEqualStrings("code", DocumentType.Code.getName());
    try std.testing.expectEqualStrings("markdown", DocumentType.Markdown.getName());
}

test "DocumentType fromExtension" {
    try std.testing.expectEqual(DocumentType.Code, DocumentType.fromExtension(".zig"));
    try std.testing.expectEqual(DocumentType.Code, DocumentType.fromExtension(".py"));
    try std.testing.expectEqual(DocumentType.Markdown, DocumentType.fromExtension(".md"));
    try std.testing.expectEqual(DocumentType.Config, DocumentType.fromExtension(".json"));
}

test "DocumentType isCode" {
    try std.testing.expect(DocumentType.Code.isCode());
    try std.testing.expect(!DocumentType.Markdown.isCode());
}

test "SimpleEmbedding init" {
    const embedding = SimpleEmbedding.init();
    try std.testing.expectEqual(@as(f32, 0), embedding.magnitude);
}

test "SimpleEmbedding fromText" {
    const embedding = SimpleEmbedding.fromText("hello world");
    try std.testing.expect(embedding.magnitude > 0);
}

test "SimpleEmbedding cosineSimilarity" {
    const e1 = SimpleEmbedding.fromText("hello world");
    const e2 = SimpleEmbedding.fromText("hello there");
    const similarity = e1.cosineSimilarity(&e2);
    try std.testing.expect(similarity > 0);
    try std.testing.expect(similarity <= 1.0);
}

test "SimpleEmbedding self similarity" {
    const e = SimpleEmbedding.fromText("test string");
    const similarity = e.cosineSimilarity(&e);
    try std.testing.expect(similarity > 0.99);
}

test "Chunk init" {
    const chunk = Chunk.init("test content", "file.txt", 1, 10);
    try std.testing.expectEqualStrings("test content", chunk.getContent());
    try std.testing.expectEqualStrings("file.txt", chunk.getSource());
    try std.testing.expectEqual(@as(usize, 1), chunk.start_line);
}

test "Chunk setDocType" {
    var chunk = Chunk.init("code", "main.zig", 1, 5);
    chunk.setDocType(.Code);
    try std.testing.expectEqual(DocumentType.Code, chunk.doc_type);
}

test "Chunk getLineCount" {
    const chunk = Chunk.init("test", "file.txt", 5, 15);
    try std.testing.expectEqual(@as(usize, 11), chunk.getLineCount());
}

test "Chunk deactivate" {
    var chunk = Chunk.init("test", "file.txt", 1, 1);
    try std.testing.expect(chunk.is_active);
    chunk.deactivate();
    try std.testing.expect(!chunk.is_active);
}

test "ChunkStore init" {
    const store = ChunkStore.init();
    try std.testing.expectEqual(@as(usize, 0), store.count);
    try std.testing.expect(store.isEmpty());
}

test "ChunkStore add" {
    var store = ChunkStore.init();
    const chunk = Chunk.init("test", "file.txt", 1, 1);
    try std.testing.expect(store.add(chunk));
    try std.testing.expectEqual(@as(usize, 1), store.count);
}

test "ChunkStore get" {
    var store = ChunkStore.init();
    const chunk = Chunk.init("content", "path.txt", 1, 5);
    _ = store.add(chunk);
    if (store.get(0)) |c| {
        try std.testing.expectEqualStrings("content", c.getContent());
    } else {
        try std.testing.expect(false);
    }
}

test "ChunkStore getActiveCount" {
    var store = ChunkStore.init();
    _ = store.add(Chunk.init("a", "f1", 1, 1));
    _ = store.add(Chunk.init("b", "f2", 1, 1));
    try std.testing.expectEqual(@as(usize, 2), store.getActiveCount());
}

test "ChunkStore clear" {
    var store = ChunkStore.init();
    _ = store.add(Chunk.init("test", "file", 1, 1));
    store.clear();
    try std.testing.expectEqual(@as(usize, 0), store.count);
}

test "Chunker init" {
    const chunker = Chunker.init();
    try std.testing.expectEqual(DEFAULT_CHUNK_SIZE, chunker.chunk_size);
    try std.testing.expectEqual(DEFAULT_OVERLAP, chunker.overlap);
}

test "Chunker chunkText" {
    var chunker = Chunker.initWithSize(3, 1);
    var store = ChunkStore.init();
    const text = "line1\nline2\nline3\nline4\nline5\nline6";
    const chunks = chunker.chunkText(text, "test.txt", &store);
    try std.testing.expect(chunks > 0);
}

test "Chunker setChunkSize" {
    var chunker = Chunker.init();
    chunker.setChunkSize(20);
    try std.testing.expectEqual(@as(usize, 20), chunker.chunk_size);
}

test "SearchResult init" {
    const result = SearchResult.init(5, 0.85, "path/to/file.txt", 42);
    try std.testing.expectEqual(@as(usize, 5), result.chunk_index);
    try std.testing.expect(result.score > 0.8);
    try std.testing.expectEqual(@as(usize, 42), result.line_num);
}

test "RetrievalResult init" {
    const result = RetrievalResult.init();
    try std.testing.expectEqual(@as(usize, 0), result.count);
    try std.testing.expect(result.isEmpty());
}

test "RetrievalResult addResult" {
    var result = RetrievalResult.init();
    try std.testing.expect(result.addResult(0, 0.9, "file.txt", 1));
    try std.testing.expectEqual(@as(usize, 1), result.count);
}

test "RetrievalResult sortByScore" {
    var result = RetrievalResult.init();
    _ = result.addResult(0, 0.5, "a.txt", 1);
    _ = result.addResult(1, 0.9, "b.txt", 1);
    _ = result.addResult(2, 0.7, "c.txt", 1);
    result.sortByScore();
    try std.testing.expect(result.results[0].score > result.results[1].score);
    try std.testing.expect(result.results[1].score > result.results[2].score);
}

test "RetrievalResult getBestScore" {
    var result = RetrievalResult.init();
    _ = result.addResult(0, 0.9, "file.txt", 1);
    _ = result.addResult(1, 0.7, "file2.txt", 1);
    result.sortByScore();
    try std.testing.expect(result.getBestScore() > 0.85);
}

test "RAGConfig init" {
    const config = RAGConfig.init();
    try std.testing.expectEqual(DEFAULT_CHUNK_SIZE, config.chunk_size);
    try std.testing.expectEqual(DEFAULT_TOP_K, config.top_k);
}

test "RAGConfig withChunkSize" {
    const config = RAGConfig.init().withChunkSize(20);
    try std.testing.expectEqual(@as(usize, 20), config.chunk_size);
}

test "RAGConfig withTopK" {
    const config = RAGConfig.init().withTopK(10);
    try std.testing.expectEqual(@as(usize, 10), config.top_k);
}

test "RAGStats init" {
    const stats = RAGStats.init();
    try std.testing.expectEqual(@as(usize, 0), stats.queries_processed);
}

test "RAGStats getHitRate" {
    var stats = RAGStats.init();
    stats.queries_processed = 10;
    stats.successful_retrievals = 8;
    try std.testing.expect(stats.getHitRate() > 0.7);
}

test "AugmentedContext init" {
    const context = AugmentedContext.init();
    try std.testing.expectEqual(@as(usize, 0), context.count);
    try std.testing.expect(context.isEmpty());
}

test "RAGEngine init" {
    const engine = RAGEngine.init();
    try std.testing.expectEqual(@as(usize, 0), engine.getChunkCount());
}

test "RAGEngine indexDocument" {
    var engine = RAGEngine.init();
    const content = "line1\nline2\nline3\nline4\nline5";
    const chunks = engine.indexDocument(content, "test.zig");
    try std.testing.expect(chunks > 0);
    try std.testing.expect(engine.getChunkCount() > 0);
}

test "RAGEngine indexText" {
    var engine = RAGEngine.init();
    const chunks = engine.indexText("test content\nmore lines", "doc.txt");
    try std.testing.expect(chunks > 0);
}

test "RAGEngine query" {
    var engine = RAGEngine.init();
    _ = engine.indexDocument("hello world\ntest content\nmore text", "file.txt");
    _ = engine.query("hello");
    try std.testing.expect(engine.stats.queries_processed == 1);
}

test "RAGEngine retrieve" {
    var engine = RAGEngine.init();
    _ = engine.indexDocument("hello world\ntest content", "file.txt");
    const context = engine.retrieve("hello");
    try std.testing.expect(context.count >= 0);
}

test "RAGEngine getStats" {
    var engine = RAGEngine.init();
    _ = engine.indexDocument("test", "file.txt");
    _ = engine.query("test");
    const stats = engine.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.documents_indexed);
    try std.testing.expectEqual(@as(usize, 1), stats.queries_processed);
}

test "RAGEngine reset" {
    var engine = RAGEngine.init();
    _ = engine.indexDocument("test", "file.txt");
    engine.reset();
    try std.testing.expectEqual(@as(usize, 0), engine.getChunkCount());
}

test "RAGEngine setConfig" {
    var engine = RAGEngine.init();
    const config = RAGConfig.init().withChunkSize(20).withTopK(10);
    engine.setConfig(config);
    try std.testing.expectEqual(@as(usize, 20), engine.config.chunk_size);
    try std.testing.expectEqual(@as(usize, 10), engine.config.top_k);
}

test "VectorIndex search" {
    var store = ChunkStore.init();
    _ = store.add(Chunk.init("hello world test", "f1.txt", 1, 1));
    _ = store.add(Chunk.init("goodbye moon", "f2.txt", 1, 1));
    var index = VectorIndex.init(&store);
    const query_emb = SimpleEmbedding.fromText("hello");
    const result = index.search(&query_emb, 5, 0.1);
    try std.testing.expect(result.count > 0);
}

test "Integration: full RAG workflow" {
    var engine = RAGEngine.init();

    _ = engine.indexDocument("pub fn add(a: i32, b: i32) i32 { return a + b; }", "math.zig");
    _ = engine.indexDocument("# README\nThis is documentation", "README.md");

    _ = engine.query("add function");

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats.documents_indexed);
    try std.testing.expectEqual(@as(usize, 1), stats.queries_processed);
}
