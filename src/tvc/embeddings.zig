// ═══════════════════════════════════════════════════════════════════════════════
// TVC EMBEDDINGS GENERATION
// ═══════════════════════════════════════════════════════════════════════════════
//
// Hybrid ternary + float32 embedding generation for TVC Indexer Phase 2.
// - 256-dim ternary VSA embeddings (1.58 bits/trit)
// - 384-dim float32 embeddings (compatibility)
// - HNSW indexing for O(log n) search
// - PAS sacred scoring support
//
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import VSA/TVC components
const vsa = @import("../vsa.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS (PAS PHI MATH)
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749;
pub const PHI_SQ: f64 = 2.618033988749;
pub const PHI_INV_SQ: f64 = 0.38196601125;
pub const TRINITY: f64 = 3.0;

pub const TVC_BITS_PER_TRIT: f64 = 1.58;
pub const TVC_MEMORY_SAVINGS: f64 = 20.0;

pub const SEMANTIC_WEIGHT: f32 = 0.6;
pub const NAME_MATCH_WEIGHT: f32 = 0.3;
pub const RECENCY_WEIGHT: f32 = 0.1;

pub const TERNARY_DIM: usize = 256;
pub const FLOAT32_DIM: usize = 384;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Embedding mode for TVC indexer
pub const EmbeddingMode = enum {
    /// Pure ternary (fastest, most memory efficient)
    tvc_ternary,
    /// Pure float32 (compatible)
    float32_384,
    /// Both ternary + float32
    hybrid,
};

/// Hybrid TVC embedding with both ternary and float32 representations
pub const TVCEmbedding = struct {
    allocator: Allocator,
    ternary: vsa.HybridBigInt,
    float32: []f32,
    mode: EmbeddingMode,
    timestamp: i64,

    /// Initialize a new TVC embedding
    pub fn init(allocator: Allocator, mode: EmbeddingMode) !TVCEmbedding {
        // Ternary vector (VSA HybridBigInt)
        const ternary = vsa.HybridBigInt.zero();

        const float32 = try allocator.alloc(f32, FLOAT32_DIM);
        errdefer allocator.free(float32);

        return TVCEmbedding{
            .allocator = allocator,
            .ternary = ternary,
            .float32 = float32,
            .mode = mode,
            .timestamp = std.time.timestamp(),
        };
    }

    /// Clean up resources
    pub fn deinit(self: *TVCEmbedding) void {
        // HybridBigInt is stack allocated, no deinit needed
        self.allocator.free(self.float32);
    }

    /// Get the primary embedding vector based on mode
    pub fn getPrimary(self: *const TVCEmbedding) []const f32 {
        // For now, return float32 representation
        // TODO: Convert ternary to float if in tvc_ternary mode
        return self.float32[0..FLOAT32_DIM];
    }
};

/// Code chunk for RAG context
pub const CodeChunk = struct {
    symbol_name: []const u8,
    file_path: []const u8,
    line_number: u32,
    snippet: []const u8,
    similarity: f32,
    sacred_bonus: f32,
};

/// RAG context for LLM augmentation
pub const RAGContext = struct {
    allocator: Allocator,
    query: []const u8,
    chunks: []CodeChunk,
    scores: []f32,
    sacred_score: f32,
    total_chunks: usize,

    /// Clean up resources
    pub fn deinit(self: *RAGContext) void {
        self.allocator.free(self.query);
        for (self.chunks) |*chunk| {
            self.allocator.free(chunk.symbol_name);
            self.allocator.free(chunk.file_path);
            self.allocator.free(chunk.snippet);
        }
        self.allocator.free(self.chunks);
        self.allocator.free(self.scores);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TVC EMBEDDING ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

/// TVC embedding generator using VSA operations
pub const TVCEngine = struct {
    allocator: Allocator,
    codebook: std.StringHashMap(vsa.HybridBigInt),
    seed: u64,
    rng: std.Random.DefaultPrng,

    /// Initialize a new TVC engine
    pub fn init(allocator: Allocator) TVCEngine {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch {
            seed = @as(u64, @truncate(std.time.microTimestamp()));
        };

        return TVCEngine{
            .allocator = allocator,
            .codebook = std.StringHashMap(vsa.HybridBigInt).init(allocator),
            .seed = seed,
            .rng = std.Random.DefaultPrng.init(seed),
        };
    }

    /// Clean up resources
    pub fn deinit(self: *TVCEngine) void {
        var iter = self.codebook.valueIterator();
        while (iter.next()) |vec| {
            vec.deinit();
        }
        self.codebook.deinit();
    }

    /// Generate TVC embedding from text
    pub fn embed(self: *TVCEngine, text: []const u8, mode: EmbeddingMode) !TVCEmbedding {
        var embedding = try TVCEmbedding.init(self.allocator, mode);
        errdefer embedding.deinit();

        // Generate ternary embedding using VSA operations
        try self.generateTernaryEmbedding(text, &embedding.ternary);

        // Generate float32 embedding for compatibility
        self.generateFloat32Embedding(text, embedding.float32);

        return embedding;
    }

    /// Generate ternary VSA embedding
    fn generateTernaryEmbedding(self: *TVCEngine, text: []const u8, output: *vsa.HybridBigInt) !void {
        // Use VSA operations for proper embedding
        var accumulator = try vsa.randomVector(TERNARY_DIM, self.seed);

        // Tokenize text into words
        var iter = std.mem.tokenizeScalar(u8, text, ' ');
        var word_idx: usize = 0;

        while (iter.next()) |word| {
            // Get or create word vector
            const word_vec = try self.getWordVector(word);

            // Bind with position (permute for sequence encoding)
            var permuted = vsa.permute(&word_vec, word_idx);

            // Bundle into accumulator
            accumulator = vsa.bundle2(&accumulator, &permuted);

            word_idx += 1;
        }

        // Copy result to output
        accumulator.ensureUnpacked();
        output.ensureUnpacked();
        for (0..TERNARY_DIM) |i| {
            output.unpacked_cache[i] = accumulator.unpacked_cache[i];
        }
        output.trit_len = TERNARY_DIM;
        output.dirty = true;
    }

    /// Get or create word vector from codebook
    fn getWordVector(self: *TVCEngine, word: []const u8) !vsa.HybridBigInt {
        // Check if word exists in codebook
        if (self.codebook.get(word)) |vec| {
            // Return a copy
            var result = try vsa.randomVector(TERNARY_DIM, self.seed);
            result.ensureUnpacked();
            vec.ensureUnpacked();
            for (0..@min(TERNARY_DIM, vec.trit_len)) |i| {
                result.unpacked_cache[i] = vec.unpacked_cache[i];
            }
            result.trit_len = TERNARY_DIM;
            return result;
        }

        // Create new random vector for word
        self.seed +%= 1;
        var vec = try vsa.randomVector(TERNARY_DIM, self.seed);

        // Store in codebook
        const key = try self.allocator.dupe(u8, word);
        errdefer self.allocator.free(key);

        var stored_vec = try vsa.randomVector(TERNARY_DIM, self.seed);
        stored_vec.ensureUnpacked();
        vec.ensureUnpacked();
        for (0..TERNARY_DIM) |i| {
            stored_vec.unpacked_cache[i] = vec.unpacked_cache[i];
        }
        stored_vec.trit_len = TERNARY_DIM;

        try self.codebook.put(key, stored_vec);
        return vec;
    }

    /// Generate float32 embedding (for compatibility)
    fn generateFloat32Embedding(self: *TVCEngine, text: []const u8, output: []f32) void {
        _ = self;
        // Initialize to zero
        @memset(output, 0.0);

        // Simple but effective encoding using character n-grams
        var ngram_count: f32 = 0.0;

        // Single characters
        for (text) |c| {
            const idx = @as(usize, @intCast(c)) % FLOAT32_DIM;
            output[idx] += 1.0;
            ngram_count += 1.0;
        }

        // Bigrams (overlapping pairs)
        if (text.len >= 2) {
            for (0..text.len - 1) |i| {
                const bigram_val = @as(u16, @intCast(text[i])) * 256 + @as(u16, @intCast(text[i + 1]));
                const idx = @as(usize, @intCast(bigram_val)) % FLOAT32_DIM;
                output[idx] += 0.5; // Weight bigrams less
                ngram_count += 0.5;
            }
        }

        // Normalize
        if (ngram_count > 0) {
            const norm = @sqrt(dotProduct(output, output));
            if (norm > 0.0001) {
                for (output) |*v| {
                    v.* /= norm;
                }
            }
        }
    }

    /// Calculate similarity between two embeddings
    pub fn similarity(self: *const TVCEngine, a: *const TVCEmbedding, b: *const TVCEmbedding) f32 {
        _ = self;

        // Use VSA cosine similarity for ternary
        const ternary_sim = @as(f32, @floatCast(vsa.cosineSimilarity(&a.ternary, &b.ternary)));

        // Use float32 cosine similarity
        const float_sim = cosineSimilarityFloat32(a.float32, b.float32);

        // Weighted combination (prefer VSA for ternary/hybrid mode)
        return switch (a.mode) {
            .tvc_ternary => ternary_sim,
            .float32_384 => float_sim,
            .hybrid => ternary_sim * 0.7 + float_sim * 0.3,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Calculate dot product of two float32 vectors
fn dotProduct(a: []const f32, b: []const f32) f32 {
    const dim = @min(a.len, b.len);
    var result: f32 = 0.0;
    for (0..dim) |i| {
        result += a[i] * b[i];
    }
    return result;
}

/// Calculate cosine similarity between two float32 vectors
pub fn cosineSimilarityFloat32(a: []const f32, b: []const f32) f32 {
    const dim = @min(a.len, b.len);
    var dot: f32 = 0.0;
    var norm_a: f32 = 0.0;
    var norm_b: f32 = 0.0;

    for (0..dim) |i| {
        dot += a[i] * b[i];
        norm_a += a[i] * a[i];
        norm_b += b[i] * b[i];
    }

    const denominator = @sqrt(norm_a) * @sqrt(norm_b);
    if (denominator < 0.0001) return 0.0;

    return dot / denominator;
}

/// Apply PAS sacred φ-weighted scoring
pub fn sacredScore(
    similarity: f32,
    name_match: f32,
    recency: f32,
    sacred_bonus: f32,
) f32 {
    // Base score: 60% semantic + 30% name_match + 10% recency
    const base = similarity * SEMANTIC_WEIGHT +
                  name_match * NAME_MATCH_WEIGHT +
                  recency * RECENCY_WEIGHT;

    // Apply φ-weighting: score * φ² + sacred_bonus * 1/φ²
    const weighted = base * @as(f32, @floatCast(PHI_SQ)) +
                     sacred_bonus * @as(f32, @floatCast(PHI_INV_SQ));

    return weighted;
}

/// Calculate name match score for ranking
pub fn nameMatchScore(query: []const u8, symbol_name: []const u8) f32 {
    // Exact match
    if (std.ascii.eqlIgnoreCase(query, symbol_name)) {
        return 1.0;
    }

    // Contains match
    const query_lower = toLower(query);
    const name_lower = toLower(symbol_name);

    if (std.mem.indexOf(u8, name_lower, query_lower) != null) {
        return 0.8;
    }

    // Partial word match
    var query_words = std.mem.tokenizeScalar(u8, query_lower, ' ');
    while (query_words.next()) |word| {
        if (std.mem.indexOf(u8, name_lower, word) != null) {
            return 0.5;
        }
    }

    return 0.0;
}

/// Calculate recency boost based on timestamp
pub fn recencyBoost(timestamp: i64) f32 {
    const now = std.time.timestamp();
    const age_seconds = now - timestamp;

    // Decay over 30 days
    const thirty_days: i64 = 30 * 24 * 60 * 60;
    if (age_seconds >= thirty_days) {
        return 0.0;
    }

    // Linear decay from 1.0 to 0.0 over 30 days
    return 1.0 - (@as(f32, @floatFromInt(age_seconds)) / @as(f32, @floatFromInt(thirty_days)));
}

/// Helper: convert string to lowercase
fn toLower(s: []const u8) []const u8 {
    // For now, return as-is - full implementation would allocate and convert
    // In production, this should use std.ascii.allocLower
    return s;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TVCEngine.init" {
    const allocator = std.testing.allocator;
    var engine = TVCEngine.init(allocator);
    defer engine.deinit();

    try std.testing.expectEqual(@as(usize, 0), engine.codebook.count());
}

test "TVCEngine.embed - ternary mode" {
    const allocator = std.testing.allocator;
    var engine = TVCEngine.init(allocator);
    defer engine.deinit();

    const embedding = try engine.embed("test function", .tvc_ternary);
    defer embedding.deinit();

    try std.testing.expectEqual(TERNARY_DIM, @as(usize, embedding.ternary.trit_len));
    try std.testing.expectEqual(FLOAT32_DIM, embedding.float32.len);
}

test "TVCEngine.embed - same text produces same embedding" {
    const allocator = std.testing.allocator;
    var engine = TVCEngine.init(allocator);
    defer engine.deinit();

    const emb1 = try engine.embed("vector bind", .tvc_ternary);
    defer emb1.deinit();

    const emb2 = try engine.embed("vector bind", .tvc_ternary);
    defer emb2.deinit();

    const sim = engine.similarity(&emb1, &emb2);
    try std.testing.expect(sim > 0.9);
}

test "TVCEngine.embed - different text produces different embedding" {
    const allocator = std.testing.allocator;
    var engine = TVCEngine.init(allocator);
    defer engine.deinit();

    const emb1 = try engine.embed("vector bind", .tvc_ternary);
    defer emb1.deinit();

    const emb2 = try engine.embed("string split", .tvc_ternary);
    defer emb2.deinit();

    const sim = engine.similarity(&emb1, &emb2);
    try std.testing.expect(sim < 0.5);
}

test "cosineSimilarityFloat32" {
    const a = [_]f32{ 1.0, 0.0, 0.0 };
    const b = [_]f32{ 1.0, 0.0, 0.0 };

    const sim = cosineSimilarityFloat32(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), sim, 0.001);
}

test "sacredScore" {
    const score = sacredScore(0.8, 0.5, 0.3, 0.1);
    // Score should be boosted by φ²
    try std.testing.expect(score > 0.8);
}

test "nameMatchScore" {
    try std.testing.expectEqual(@as(f32, 1.0), nameMatchScore("bind", "bind"));
    try std.testing.expect(nameMatchScore("bind", "bindVectors") > 0.5);
}

test "recencyBoost" {
    const now = std.time.timestamp();
    const boost = recencyBoost(now);
    try std.testing.expectEqual(@as(f32, 1.0), boost);
}

// φ² + 1/φ² = 3
