// B2T RAG - Retrieval-Augmented Generation для декомпиляции
// Использует троичные эмбеддинги (VSA) для поиска похожего кода
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const DEFAULT_DIMENSION: usize = 10000;
pub const DEFAULT_SPARSITY: f32 = 0.33; // 1/3 нулей (троичная гармония)
pub const MIN_SIMILARITY_THRESHOLD: f32 = 0.7;
pub const MAX_RETRIEVAL_RESULTS: usize = 10;

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY EMBEDDING (VSA-based)
// ═══════════════════════════════════════════════════════════════════════════════

pub const TernaryEmbedding = struct {
    allocator: std.mem.Allocator,
    dimension: usize,
    trits: []i8, // Значения {-1, 0, +1}
    source_hash: [32]u8,

    pub fn init(allocator: std.mem.Allocator, dim: usize) !TernaryEmbedding {
        const trits = try allocator.alloc(i8, dim);
        @memset(trits, 0);

        return TernaryEmbedding{
            .allocator = allocator,
            .dimension = dim,
            .trits = trits,
            .source_hash = [_]u8{0} ** 32,
        };
    }

    pub fn deinit(self: *TernaryEmbedding) void {
        self.allocator.free(self.trits);
    }

    /// Генерация случайного троичного вектора
    pub fn randomize(self: *TernaryEmbedding, seed: u64) void {
        var rng = std.rand.DefaultPrng.init(seed);
        const random = rng.random();

        for (self.trits) |*trit| {
            const r = random.float(f32);
            if (r < 0.33) {
                trit.* = -1;
            } else if (r < 0.66) {
                trit.* = 0;
            } else {
                trit.* = 1;
            }
        }
    }

    /// Вычисление косинусного сходства
    pub fn cosineSimilarity(self: *const TernaryEmbedding, other: *const TernaryEmbedding) f32 {
        if (self.dimension != other.dimension) return 0.0;

        var dot_product: i64 = 0;
        var norm_a: i64 = 0;
        var norm_b: i64 = 0;

        for (self.trits, other.trits) |a, b| {
            dot_product += @as(i64, a) * @as(i64, b);
            norm_a += @as(i64, a) * @as(i64, a);
            norm_b += @as(i64, b) * @as(i64, b);
        }

        if (norm_a == 0 or norm_b == 0) return 0.0;

        const norm = @sqrt(@as(f64, @floatFromInt(norm_a))) * @sqrt(@as(f64, @floatFromInt(norm_b)));
        return @floatCast(@as(f64, @floatFromInt(dot_product)) / norm);
    }

    /// Расстояние Хэмминга
    pub fn hammingDistance(self: *const TernaryEmbedding, other: *const TernaryEmbedding) usize {
        if (self.dimension != other.dimension) return self.dimension;

        var distance: usize = 0;
        for (self.trits, other.trits) |a, b| {
            if (a != b) distance += 1;
        }
        return distance;
    }

    /// Bundling (мажоритарное голосование)
    pub fn bundle(allocator: std.mem.Allocator, embeddings: []const *const TernaryEmbedding) !TernaryEmbedding {
        if (embeddings.len == 0) return error.EmptyInput;

        const dim = embeddings[0].dimension;
        var result = try TernaryEmbedding.init(allocator, dim);

        for (0..dim) |i| {
            var sum: i32 = 0;
            for (embeddings) |emb| {
                sum += emb.trits[i];
            }

            // Мажоритарное голосование
            if (sum > 0) {
                result.trits[i] = 1;
            } else if (sum < 0) {
                result.trits[i] = -1;
            } else {
                result.trits[i] = 0;
            }
        }

        return result;
    }

    /// Binding (троичный XOR)
    pub fn bind(self: *const TernaryEmbedding, other: *const TernaryEmbedding, allocator: std.mem.Allocator) !TernaryEmbedding {
        if (self.dimension != other.dimension) return error.DimensionMismatch;

        var result = try TernaryEmbedding.init(allocator, self.dimension);

        for (self.trits, other.trits, 0..) |a, b, i| {
            // Троичный XOR: (a * b) mod 3
            const product = @as(i32, a) * @as(i32, b);
            result.trits[i] = @intCast(@mod(product + 3, 3) - 1);
        }

        return result;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CODE CHUNK
// ═══════════════════════════════════════════════════════════════════════════════

pub const ChunkType = enum {
    function_body,
    loop_construct,
    conditional,
    variable_declaration,
    function_call,
    memory_access,
    arithmetic_expression,
};

pub const CodeChunk = struct {
    allocator: std.mem.Allocator,
    code: []const u8,
    chunk_type: ChunkType,
    start_line: u32,
    end_line: u32,
    embedding: ?TernaryEmbedding,
    metadata: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator, code: []const u8, chunk_type: ChunkType) CodeChunk {
        return CodeChunk{
            .allocator = allocator,
            .code = code,
            .chunk_type = chunk_type,
            .start_line = 0,
            .end_line = 0,
            .embedding = null,
            .metadata = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *CodeChunk) void {
        if (self.embedding) |*emb| {
            emb.deinit();
        }
        self.metadata.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIMILARITY RESULT
// ═══════════════════════════════════════════════════════════════════════════════

pub const SimilarityResult = struct {
    chunk: *const CodeChunk,
    similarity: f32,
    source: []const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// KNOWLEDGE BASE
// ═══════════════════════════════════════════════════════════════════════════════

pub const KnowledgeSource = enum {
    decompiled_verified, // Проверенный декомпилированный код
    original_source, // Оригинальный исходный код
    documentation, // Документация API
    pattern_library, // Библиотека паттернов
    user_corrections, // Исправления пользователей
};

pub const KnowledgeEntry = struct {
    id: u64,
    source: KnowledgeSource,
    code: []const u8,
    description: []const u8,
    quality_score: f32, // 0.0 - 1.0
    usage_count: u32,
    embedding: ?TernaryEmbedding,
};

pub const KnowledgeBase = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(KnowledgeEntry),
    next_id: u64,

    pub fn init(allocator: std.mem.Allocator) KnowledgeBase {
        return KnowledgeBase{
            .allocator = allocator,
            .entries = std.ArrayList(KnowledgeEntry).init(allocator),
            .next_id = 1,
        };
    }

    pub fn deinit(self: *KnowledgeBase) void {
        for (self.entries.items) |*entry| {
            if (entry.embedding) |*emb| {
                emb.deinit();
            }
        }
        self.entries.deinit();
    }

    /// Добавление записи в базу знаний
    pub fn addEntry(self: *KnowledgeBase, source: KnowledgeSource, code: []const u8, description: []const u8) !u64 {
        const id = self.next_id;
        self.next_id += 1;

        try self.entries.append(KnowledgeEntry{
            .id = id,
            .source = source,
            .code = code,
            .description = description,
            .quality_score = 0.5,
            .usage_count = 0,
            .embedding = null,
        });

        return id;
    }

    /// Поиск похожих записей
    pub fn searchSimilar(self: *KnowledgeBase, query_embedding: *const TernaryEmbedding, max_results: usize) !std.ArrayList(SimilarityResult) {
        var results = std.ArrayList(SimilarityResult).init(self.allocator);

        for (self.entries.items) |*entry| {
            if (entry.embedding) |*emb| {
                const similarity = query_embedding.cosineSimilarity(emb);
                if (similarity >= MIN_SIMILARITY_THRESHOLD) {
                    // Простая вставка (можно оптимизировать с heap)
                    try results.append(SimilarityResult{
                        .chunk = undefined, // TODO: связать с chunk
                        .similarity = similarity,
                        .source = entry.code,
                    });
                }
            }
        }

        // Сортировка по убыванию similarity
        std.mem.sort(SimilarityResult, results.items, {}, struct {
            fn lessThan(_: void, a: SimilarityResult, b: SimilarityResult) bool {
                return a.similarity > b.similarity;
            }
        }.lessThan);

        // Ограничение результатов
        if (results.items.len > max_results) {
            results.shrinkRetainingCapacity(max_results);
        }

        return results;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// RAG ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

pub const RAGEngine = struct {
    allocator: std.mem.Allocator,
    knowledge_base: KnowledgeBase,
    dimension: usize,

    pub fn init(allocator: std.mem.Allocator) RAGEngine {
        return RAGEngine{
            .allocator = allocator,
            .knowledge_base = KnowledgeBase.init(allocator),
            .dimension = DEFAULT_DIMENSION,
        };
    }

    pub fn deinit(self: *RAGEngine) void {
        self.knowledge_base.deinit();
    }

    /// Генерация эмбеддинга из кода
    pub fn embedCode(self: *RAGEngine, code: []const u8) !TernaryEmbedding {
        var embedding = try TernaryEmbedding.init(self.allocator, self.dimension);

        // Простой хеш-based эмбеддинг
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(code);
        const hash = hasher.final();

        embedding.randomize(hash);

        // Вычисление хеша исходного кода
        var sha = std.crypto.hash.sha2.Sha256.init(.{});
        sha.update(code);
        sha.final(&embedding.source_hash);

        return embedding;
    }

    /// Поиск похожего кода для ICL
    pub fn retrieveExamples(self: *RAGEngine, code: []const u8, max_examples: usize) !std.ArrayList(SimilarityResult) {
        var query_embedding = try self.embedCode(code);
        defer query_embedding.deinit();

        return self.knowledge_base.searchSimilar(&query_embedding, max_examples);
    }

    /// Добавление примера в базу знаний
    pub fn addExample(self: *RAGEngine, source: KnowledgeSource, code: []const u8, description: []const u8) !u64 {
        const id = try self.knowledge_base.addEntry(source, code, description);

        // Генерация эмбеддинга для новой записи
        const idx = self.knowledge_base.entries.items.len - 1;
        self.knowledge_base.entries.items[idx].embedding = try self.embedCode(code);

        return id;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ternary embedding init and deinit" {
    var emb = try TernaryEmbedding.init(std.testing.allocator, 100);
    defer emb.deinit();

    try std.testing.expectEqual(@as(usize, 100), emb.dimension);
}

test "ternary embedding cosine similarity" {
    var emb1 = try TernaryEmbedding.init(std.testing.allocator, 100);
    defer emb1.deinit();
    var emb2 = try TernaryEmbedding.init(std.testing.allocator, 100);
    defer emb2.deinit();

    emb1.randomize(12345);
    emb2.randomize(12345); // Одинаковый seed = одинаковые векторы

    const similarity = emb1.cosineSimilarity(&emb2);
    try std.testing.expect(similarity > 0.99); // Должны быть почти идентичны
}

test "ternary embedding hamming distance" {
    var emb1 = try TernaryEmbedding.init(std.testing.allocator, 100);
    defer emb1.deinit();
    var emb2 = try TernaryEmbedding.init(std.testing.allocator, 100);
    defer emb2.deinit();

    emb1.randomize(12345);
    emb2.randomize(12345);

    const distance = emb1.hammingDistance(&emb2);
    try std.testing.expectEqual(@as(usize, 0), distance); // Одинаковые векторы
}

test "knowledge base add and search" {
    var kb = KnowledgeBase.init(std.testing.allocator);
    defer kb.deinit();

    const id = try kb.addEntry(.pattern_library, "int add(int a, int b) { return a + b; }", "Simple addition");
    try std.testing.expect(id > 0);
    try std.testing.expectEqual(@as(usize, 1), kb.entries.items.len);
}

test "rag engine embed code" {
    var engine = RAGEngine.init(std.testing.allocator);
    defer engine.deinit();

    var emb = try engine.embedCode("int x = 5;");
    defer emb.deinit();

    try std.testing.expectEqual(DEFAULT_DIMENSION, emb.dimension);
}
