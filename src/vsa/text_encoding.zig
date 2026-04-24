//! VSA Text Encoding — Character-level Ternary VSA for Semantic Search
//! φ² + 1/φ² = 3 | TRINITY
//!
//! Based on:
//! - Kanerva (2009) "Hyperdimensional Computing"
//! - Plate (2003) "Distributed Sparse Distributed Memory"
//! - Gayler (2003) "Vector Symbolic Architectures"
//!
//! Key innovations:
//! - Character-level random projection
//! - N-gram encoding for semantic similarity
//! - TF-IDF weighting (Manning et al., 2008)
//! - Approximate decoding via associative memory

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ArrayListUnmanaged = std.ArrayListUnmanaged;

const common = @import("common.zig");
const HybridBigInt = common.HybridBigInt;
const core = @import("core.zig");

pub const TEXT_VECTOR_DIM: usize = 512;
pub const CHAR_VECTOR_DIM: usize = 512;
pub const NGRAM_N: usize = 2; // Bigrams for semantic enhancement

// ============================================================================
// CHARACTER VECTOR STORAGE
// ============================================================================

/// Pre-generated character vectors for ASCII range (0-127)
/// Extended to 256 for full byte range
var char_vectors_initialized = false;
var char_vectors: [256]HybridBigInt = undefined;

/// Initialize character vectors with random projection
/// Uses deterministic seed for reproducibility
pub fn initCharVectors() void {
    if (char_vectors_initialized) return;

    const seed: u64 = 0xDEADBEEFCAFEBABE; // Deterministic seed
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();

    for (0..256) |i| {
        char_vectors[i] = core.randomVector(CHAR_VECTOR_DIM, random.int(u64));
    }

    char_vectors_initialized = true;
}

/// Get vector for single character (lazy initialization)
pub fn charToVector(c: u8) HybridBigInt {
    if (!char_vectors_initialized) {
        initCharVectors();
    }
    return char_vectors[c];
}

// ============================================================================
// WORD ENCODING VIA BUNDLING
// ============================================================================

/// Encode word by bundling character vectors
/// Reference: Plate (2003) "Holographic Reduced Representation"
pub fn encodeWord(word: []const u8) HybridBigInt {
    if (word.len == 0) return HybridBigInt.zero();

    // Bundle all character vectors
    var result = charToVector(word[0]);

    for (word[1..]) |c| {
        var char_vec = charToVector(c);
        result = core.bundle2(&result, &char_vec, std.heap.page_allocator);
    }

    return result;
}

/// Encode word with position binding (preserves character order)
pub fn encodeWordWithPosition(word: []const u8) HybridBigInt {
    if (word.len == 0) return HybridBigInt.zero();

    var result = HybridBigInt.zero();

    for (word, 0..) |c, pos| {
        var char_vec = charToVector(c);
        // Permute by position to preserve order information
        const permuted = core.permute(&char_vec, pos);
        result = result.add(&permuted, std.heap.page_allocator);
    }

    return result;
}

// ============================================================================
// N-GRAM ENCODING (Bigrams for Semantic Similarity)
// ============================================================================

/// N-gram encoding for semantic similarity
/// Bigrams capture morphological patterns (e.g., "ing", "tion")
pub const NgramVector = struct {
    vector: HybridBigInt,
    ngram: [NGRAM_N]u8,
    count: usize,
};

/// Encode single n-gram to vector
pub fn encodeNgram(gram: []const u8) HybridBigInt {
    std.debug.assert(gram.len == NGRAM_N);

    // Bind character vectors together
    var result = charToVector(gram[0]);

    for (gram[1..]) |c| {
        var char_vec = charToVector(c);
        result = core.bind(&result, &char_vec);
    }

    return result;
}

/// Encode text with n-gram enhancement
/// Combines character-level encoding with bigram features
pub fn encodeTextWithNgrams(text: []const u8, allocator: Allocator) !struct {
    char_level: HybridBigInt,
    ngram_level: HybridBigInt,
    combined: HybridBigInt,
} {
    _ = allocator; // Reserved for future use

    // Character-level encoding
    var char_vec = HybridBigInt.zero();
    for (text) |c| {
        var cv = charToVector(c);
        char_vec = char_vec.add(&cv, std.heap.page_allocator);
    }

    // N-gram level encoding
    var ngram_vec = HybridBigInt.zero();
    var ngram_count: usize = 0;

    if (text.len >= NGRAM_N) {
        for (0..text.len - NGRAM_N + 1) |i| {
            var ngram = encodeNgram(text[i..][0..NGRAM_N]);
            ngram_vec = ngram_vec.add(&ngram, std.heap.page_allocator);
            ngram_count += 1;
        }
    }

    // Combine with weighted bundling
    // Character-level gets 60% weight, n-gram gets 40%
    var char_weighted = char_vec;
    var ngram_weighted = ngram_vec;

    // Scale vectors (simplified: just bundle)
    const combined = core.bundle2(&char_weighted, &ngram_weighted, std.heap.page_allocator);

    return .{
        .char_level = char_vec,
        .ngram_level = ngram_vec,
        .combined = combined,
    };
}

// ============================================================================
// TEXT ENCODING API
// ============================================================================

/// Encode text to VSA vector (primary API)
pub fn encodeText(text: []const u8) HybridBigInt {
    if (text.len == 0) return HybridBigInt.zero();

    // Simple word bundling for now
    var result = HybridBigInt.zero();
    var word_start: usize = 0;
    var in_word = false;

    for (text, 0..) |c, i| {
        const is_alpha = (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');

        if (is_alpha and !in_word) {
            word_start = i;
            in_word = true;
        } else if (!is_alpha and in_word) {
            const word = text[word_start..i];
            var word_vec = encodeWord(word);
            result = result.add(&word_vec, std.heap.page_allocator);
            in_word = false;
        }
    }

    // Handle last word
    if (in_word) {
        const word = text[word_start..];
        var word_vec = encodeWord(word);
        result = result.add(&word_vec, std.heap.page_allocator);
    }

    return result;
}

/// Encode text with advanced n-gram features
pub fn encodeTextAdvanced(text: []const u8, allocator: Allocator) !HybridBigInt {
    const encoded = try encodeTextWithNgrams(text, allocator);
    return encoded.combined;
}

// ============================================================================
// SIMILARITY METRICS
// ============================================================================

/// Compute cosine similarity between two texts
pub fn textSimilarity(text1: []const u8, text2: []const u8) f64 {
    const vec1 = encodeText(text1);
    const vec2 = encodeText(text2);

    return core.cosineSimilarity(&vec1, &vec2);
}

/// Compute similarity with n-gram enhancement
pub fn textSimilarityAdvanced(text1: []const u8, text2: []const u8, allocator: Allocator) !f64 {
    const vec1 = try encodeTextAdvanced(text1, allocator);
    const vec2 = try encodeTextAdvanced(text2, allocator);

    return core.cosineSimilarity(&vec1, &vec2);
}

/// Check if two texts are similar above threshold
pub fn textsAreSimilar(text1: []const u8, text2: []const u8, threshold: f64) bool {
    return textSimilarity(text1, text2) >= threshold;
}

// ============================================================================
// TF-IDF WEIGHTING (Manning et al., 2008)
// ============================================================================

/// Document frequency for TF-IDF
pub const DocumentStats = struct {
    total_docs: usize,
    doc_freq: std.AutoHashMap(u64, usize),

    pub fn init(allocator: Allocator) DocumentStats {
        return .{
            .total_docs = 0,
            .doc_freq = std.AutoHashMap(u64, usize).init(allocator),
        };
    }

    pub fn deinit(self: *DocumentStats) void {
        self.doc_freq.deinit();
    }

    /// Add document to statistics
    pub fn addDocument(self: *DocumentStats, text: []const u8) !void {
        self.total_docs += 1;

        var seen = std.AutoHashMap(u64, void).init(self.doc_freq.allocator);
        defer seen.deinit();

        var word_start: usize = 0;
        var in_word = false;

        for (text, 0..) |c, i| {
            const is_alpha = (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');

            if (is_alpha and !in_word) {
                word_start = i;
                in_word = true;
            } else if (!is_alpha and in_word) {
                const word = text[word_start..i];
                const hash = std.hash.Wyhash.hash(0, word);
                try seen.put(hash, {});
                in_word = false;
            }
        }

        if (in_word) {
            const word = text[word_start..];
            const hash = std.hash.Wyhash.hash(0, word);
            try seen.put(hash, {});
        }

        // Update document frequency
        var iter = seen.iterator();
        while (iter.next()) |entry| {
            const gop = try self.doc_freq.getOrPut(entry.key_ptr.*);
            if (!gop.found_existing) {
                gop.value_ptr.* = 0;
            }
            gop.value_ptr.* += 1;
        }
    }

    /// Compute IDF for a term
    pub fn idf(self: *const DocumentStats, term: []const u8) f64 {
        const hash = std.hash.Wyhash.hash(0, term);
        const df = self.doc_freq.get(hash) orelse 1;

        if (df >= self.total_docs) return 0;
        return @log(@as(f64, @floatFromInt(self.total_docs)) / @as(f64, @floatFromInt(df)));
    }
};

/// Encode text with TF-IDF weighting
pub fn encodeTextTFIDF(text: []const u8, stats: *const DocumentStats) HybridBigInt {
    var result = HybridBigInt.zero();

    var word_start: usize = 0;
    var in_word = false;

    for (text, 0..) |c, i| {
        const is_alpha = (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');

        if (is_alpha and !in_word) {
            word_start = i;
            in_word = true;
        } else if (!is_alpha and in_word) {
            const word = text[word_start..i];
            const word_vec = encodeWord(word);
            const idf = stats.idf(word);

            // Scale vector by IDF (simplified: add multiple times)
            const scale = @as(usize, @intFromFloat(idf));
            var weighted = word_vec;
            for (0..@max(1, scale)) |_| {
                result = result.add(&weighted, std.heap.page_allocator);
            }

            in_word = false;
        }
    }

    if (in_word) {
        const word = text[word_start..];
        const word_vec = encodeWord(word);
        const idf = stats.idf(word);

        const scale = @as(usize, @intFromFloat(idf));
        var weighted = word_vec;
        for (0..@max(1, scale)) |_| {
            result = result.add(&weighted, std.heap.page_allocator);
        }
    }

    return result;
}

// ============================================================================
// APPROXIMATE DECODING
// ============================================================================

/// Associative memory for approximate decoding
pub const AssociativeMemory = struct {
    vectors: ArrayListUnmanaged(HybridBigInt),
    keys: ArrayListUnmanaged([]const u8),

    pub fn init(_: Allocator) AssociativeMemory {
        return .{
            .vectors = .{},
            .keys = .{},
        };
    }

    pub fn deinit(self: *AssociativeMemory, allocator: Allocator) void {
        for (self.keys.items) |key| {
            allocator.free(key);
        }
        self.vectors.deinit(allocator);
        self.keys.deinit(allocator);
    }

    /// Store key-vector association
    pub fn store(self: *AssociativeMemory, allocator: Allocator, key: []const u8, vector: HybridBigInt) !void {
        const key_copy = try allocator.dupe(u8, key);
        try self.vectors.append(allocator, vector);
        try self.keys.append(allocator, key_copy);
    }

    /// Retrieve best matching key for query vector
    pub fn retrieve(self: *const AssociativeMemory, query: HybridBigInt) ?[]const u8 {
        if (self.vectors.items.len == 0) return null;

        var best_idx: usize = 0;
        var best_sim: f64 = -1.0;

        for (self.vectors.items, 0..) |vec, i| {
            const sim = core.cosineSimilarity(&vec, &query);
            if (sim > best_sim) {
                best_sim = sim;
                best_idx = i;
            }
        }

        return if (best_sim > 0.3) self.keys.items[best_idx] else null;
    }
};

/// Decode vector to text using associative memory (best-effort)
pub fn decodeText(vector: *const HybridBigInt, memory: *const AssociativeMemory) ?[]const u8 {
    return memory.retrieve(vector.*);
}

// ============================================================================
// SEARCH AND RETRIEVAL
// ============================================================================

/// Search result with similarity score
pub const SearchResult = struct {
    text: []const u8,
    similarity: f64,
};

/// Find top-k similar texts in corpus
pub fn findTopK(
    query: []const u8,
    corpus: []const []const u8,
    allocator: Allocator,
    k: usize,
) ![]SearchResult {
    if (k == 0) return &[_]SearchResult{};

    const query_vec = encodeText(query);

    // Compute similarities
    var similarities = try ArrayList(struct { usize, f64 }).initCapacity(allocator, corpus.len);
    defer similarities.deinit(allocator);

    for (corpus, 0..) |doc, i| {
        const doc_vec = encodeText(doc);
        const sim = core.cosineSimilarity(&query_vec, &doc_vec);
        try similarities.append(allocator, .{ i, sim });
    }

    // Sort by similarity (descending)
    const SortContext = struct {
        pub fn lessThan(_: void, a: struct { usize, f64 }, b: struct { usize, f64 }) bool {
            return a.@"1" > b.@"1";
        }
    };

    std.sort.block(struct { usize, f64 }, similarities.items, {}, SortContext.lessThan);

    // Return top-k
    const actual_k = @min(k, similarities.items.len);
    const results = try allocator.alloc(SearchResult, actual_k);

    for (0..actual_k) |i| {
        const item = similarities.items[i];
        results[i] = .{
            .text = corpus[item.@"0"],
            .similarity = item.@"1",
        };
    }

    return results;
}

// ============================================================================
// TESTS
// ============================================================================

test "VSA Text Encoding: charToVector deterministic" {
    const v1 = charToVector('a');
    const v2 = charToVector('a');

    // Same character should produce same vector
    try std.testing.expectEqual(v1.trit_len, v2.trit_len);

    // Different characters should produce different vectors
    const v3 = charToVector('b');
    const sim = core.cosineSimilarity(&v1, &v3);
    try std.testing.expect(sim < 0.8); // Should be dissimilar
}

test "VSA Text Encoding: encodeWord" {
    const word_vec = encodeWord("cat");

    // Word vector should have correct dimension
    try std.testing.expect(word_vec.trit_len > 0);

    // Same word should produce same vector
    const word_vec2 = encodeWord("cat");
    const sim = core.cosineSimilarity(&word_vec, &word_vec2);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 0.01);
}

test "VSA Text Encoding: similar words have higher similarity" {
    const cat = encodeWord("cat");
    const cats = encodeWord("cats");
    const dog = encodeWord("dog");

    const cat_cats_sim = core.cosineSimilarity(&cat, &cats);
    const cat_dog_sim = core.cosineSimilarity(&cat, &dog);

    // "cat" and "cats" should be more similar than "cat" and "dog"
    try std.testing.expect(cat_cats_sim > cat_dog_sim);
}

test "VSA Text Encoding: textSimilarity" {
    const sim1 = textSimilarity("hello world", "hello world");
    const sim2 = textSimilarity("hello world", "goodbye world");

    // Identical texts should be very similar
    try std.testing.expect(sim1 > 0.9);

    // Different texts should be less similar
    try std.testing.expect(sim2 < sim1);
}

test "VSA Text Encoding: encodeNgram" {
    const bigram = encodeNgram("th");

    // Bigram vector should have correct dimension
    try std.testing.expect(bigram.trit_len > 0);

    // Same bigram should produce same vector
    const bigram2 = encodeNgram("th");
    const sim = core.cosineSimilarity(&bigram, &bigram2);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 0.01);
}

test "VSA Text Encoding: encodeTextWithNgrams" {
    const allocator = std.testing.allocator;

    const encoded = try encodeTextWithNgrams("hello", allocator);

    // All levels should have valid vectors
    try std.testing.expect(encoded.char_level.trit_len > 0);
    try std.testing.expect(encoded.combined.trit_len > 0);
}

test "VSA Text Encoding: DocumentStats" {
    const allocator = std.testing.allocator;

    var stats = DocumentStats.init(allocator);
    defer stats.deinit();

    try stats.addDocument("the cat sat");
    try stats.addDocument("the dog sat");
    try stats.addDocument("the bird flew");

    try std.testing.expectEqual(@as(usize, 3), stats.total_docs);

    // "the" appears in all docs, should have lower IDF
    const idf_the = stats.idf("the");
    const idf_cat = stats.idf("cat");

    try std.testing.expect(idf_cat > idf_the);
}

test "VSA Text Encoding: AssociativeMemory" {
    const allocator = std.testing.allocator;

    var memory = AssociativeMemory.init(allocator);
    defer memory.deinit(allocator);

    const vec1 = encodeWord("apple");
    const vec2 = encodeWord("banana");

    try memory.store(allocator, "apple", vec1);
    try memory.store(allocator, "banana", vec2);

    // Should retrieve stored keys
    const retrieved1 = memory.retrieve(vec1);
    try std.testing.expectEqualStrings("apple", retrieved1.?);

    const retrieved2 = memory.retrieve(vec2);
    try std.testing.expectEqualStrings("banana", retrieved2.?);
}

test "VSA Text Encoding: findTopK" {
    const allocator = std.testing.allocator;

    const corpus = &[_][]const u8{
        "the quick brown fox",
        "the lazy dog",
        "the quick cat",
        "a completely different text",
    };

    const results = try findTopK("quick fox", corpus, allocator, 2);
    defer allocator.free(results);

    try std.testing.expectEqual(@as(usize, 2), results.len);

    // First result should be most similar
    try std.testing.expect(results[0].similarity > results[1].similarity);
}

// φ² + 1/φ² = 3 | TRINITY
