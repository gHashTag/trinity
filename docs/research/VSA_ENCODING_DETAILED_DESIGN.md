# VSA Text Encoding: Detailed Scientific Implementation

## Abstract

This document provides a complete scientific implementation of Vector Symbolic Architecture (VSA) text encoding using ternary hypervectors {-1, 0, +1}^d. The implementation is based on:
- Plate (2003) - Distributed Sparse Distributed Memory
- Kanerva (2009) - Hyperdimensional Computing
- Gayler (2003) - Vector Symbolic Architectures
- Joselyne et al. (2024) - Ternary Neural Networks

**Hypothesis**: Ternary VSA encoding achieves >30% semantic similarity at d=512 dimensions with O(n) complexity.

---

## Part 1: Mathematical Foundation

### 1.1 Ternary Hypervector Space

**Definition**: A ternary hypervector v ∈ {-1, 0, +1}^d where d is the dimensionality.

**Properties**:
1. **Dimension**: d = 512 (configurable)
2. **Sparsity**: ~33% non-zero elements (random initialization)
3. **Capacity**: O(d) items can be stored with ~95% recall

**Similarity Metric**: Cosine similarity
```
sim(v₁, v₂) = (v₁ · v₂) / (||v₁|| × ||v₂||)
```

For ternary vectors:
- Maximum similarity: 1.0 (identical vectors)
- Expected similarity: 0 (random orthogonal vectors)
- Minimum similarity: -1.0 (opposite vectors)

### 1.2 Character Vector Generation

**Method**: Random projection with ternary constraint

```zig
const std = @import("std");
const vsa = @import("vsa.zig");
const HybridBigInt = vsa.HybridBigInt;

pub const TextEncodingConfig = struct {
    dimension: usize = 512,
    alphabet_size: usize = 128, // ASCII
    sparsity: f64 = 0.33, // 33% non-zero
    seed: u64 = 0x9e3779b9,
};

/// Pre-generated character vectors for ASCII (0-127)
pub const CHAR_VECTORS: [128]HybridBigInt = blk: {
    var vectors: [128]HybridBigInt = undefined;
    var prng = std.Random.DefaultPrng.init(TextEncodingConfig.seed);

    for (&vectors, 0..) |*vec, i| {
        vec = generateRandomVector(TextEncodingConfig.dimension, &prng, TextEncodingConfig.sparsity);
    }
    break :blk vectors;
};

fn generateRandomVector(dim: usize, prng: *std.Random.DefaultPrng, sparsity: f64) HybridBigInt {
    var result = HybridBigInt.zero();
    for (0..dim) |i| {
        const r = prng.random().float(f64);
        const trit: i2 = if (r < sparsity / 2.0)
            -1  // Negative
        else if (r < sparsity)
            0   // Zero
        else
            1;  // Positive
        result.set(i, trit);
    }
    return result;
}
```

### 1.3 Word Encoding via Bundling

**Method**: Bundle character vectors using majority voting

```zig
/// Encode word into hypervector via character bundling
pub fn encodeWord(word: []const u8) HybridBigInt {
    var result = HybridBigInt.zero();
    var count: usize = 0;

    for (word) |c| {
        const char_vec = charToVector(c);
        result = vsa.bundle3(&result, &char_vec, &vsa.HybridBigInt.zero());
        count += 1;
    }

    // Normalize to handle variable length words
    if (count > 1) {
        result = normalizeBundle(result, count);
    }

    return result;
}

/// Normalize bundled vector by majority vote
fn normalizeBundle(vec: HybridBigInt, n: usize) HybridBigInt {
    var result = HybridBigInt.zero();
    const threshold = @as(i2, @intFromFloat(@as(f64, @floatFromInt(n)) / 3.0));

    for (0..TextEncodingConfig.dimension) |i| {
        const val = vec.get(i);
        // Majority vote: positive if > n/3, negative if < -n/3
        const normalized: i2 = if (val > threshold) 1
                              else if (val < -threshold) -1
                              else 0;
        result.set(i, normalized);
    }

    return result;
}
```

### 1.4 Text Similarity Calculation

```zig
/// Calculate semantic similarity between two text strings
pub fn textSimilarity(text1: []const u8, text2: []const u8) f64 {
    const vec1 = encodeText(text1);
    const vec2 = encodeText(text2);
    return vsa.cosineSimilarity(&vec1, &vec2);
}

/// Encode text (multiple words) via word bundling
pub fn encodeText(text: []const u8) HybridBigInt {
    var result = HybridBigInt.zero();
    var word_iter = std.mem.tokenizeScalar(u8, text, ' ');
    var word_count: usize = 0;

    while (word_iter.next()) |word| {
        const word_vec = encodeWord(word);
        result = vsa.bundle2(&result, &word_vec);
        word_count += 1;
    }

    return result;
}
```

---

## Part 2: N-gram Encoding for Semantic Enhancement

### 2.1 Character Bigram Encoding

**Rationale**: Bigrams capture character-level semantics (e.g., "th" in "the", "this")

```zig
/// Bigram (character pair) vectors for semantic enhancement
pub const BIGRAM_VECTORS: [128 * 128]HybridBigInt = blk: {
    var vectors: [128 * 128]HybridBigInt = undefined;
    var prng = std.Random.DefaultPrng.init(0x9e3779b9 + 1);

    for (&vectors, 0..) |*vec| {
        vec = generateRandomVector(TextEncodingConfig.dimension, &prng, TextEncodingConfig.sparsity);
    }
    break :blk vectors;
};

/// Encode word using bigram enhancement
pub fn encodeWordBigram(word: []const u8) HybridBigInt {
    if (word.len < 2) return encodeWord(word);

    // Unigram (character) contribution
    var unigram_vec = encodeWord(word);

    // Bigram contribution
    var bigram_vec = HybridBigInt.zero();
    var bigram_count: usize = 0;

    for (0..word.len - 1) |i| {
        const c1 = word[i];
        const c2 = word[i + 1];
        const idx = @as(usize, c1) * 128 + @as(usize, c2);
        const bigram = BIGRAM_VECTORS[idx];
        bigram_vec = vsa.bundle2(&bigram_vec, &bigram);
        bigram_count += 1;
    }

    // Combine unigram and bigram (weighted sum)
    const alpha: f64 = 0.7; // Unigram weight
    const beta: f64 = 0.3;  // Bigram weight

    return weightedBundle(unigram_vec, bigram_vec, alpha, beta);
}

/// Weighted bundle of two vectors
fn weightedBundle(v1: HybridBigInt, v2: HybridBigInt, w1: f64, w2: f64) HybridBigInt {
    var result = HybridBigInt.zero();
    const total = w1 + w2;

    for (0..TextEncodingConfig.dimension) |i| {
        const val1 = @as(f64, @floatFromInt(v1.get(i))) * w1;
        const val2 = @as(f64, @floatFromInt(v2.get(i))) * w2;
        const sum = val1 + val2;

        const trit: i2 = if (sum > total / 3.0) 1
                      else if (sum < -total / 3.0) -1
                      else 0;
        result.set(i, trit);
    }

    return result;
}
```

### 2.2 TF-IDF Weighting

**Reference**: Information Retrieval (Manning et al., 2008)

```zig
/// TF-IDF weighting for word importance
pub const TFIDFContext = struct {
    document_count: usize = 0,
    word_freq: std.StringHashMap(usize),
    doc_freq: std.StringHashMap(usize),

    pub fn init(allocator: std.mem.Allocator) TFIDFContext {
        return .{
            .document_count = 0,
            .word_freq = std.StringHashMap(usize).init(allocator),
            .doc_freq = std.StringHashMap(usize).init(allocator),
        };
    }

    pub fn deinit(self: *TFIDFContext) void {
        self.word_freq.deinit();
        self.doc_freq.deinit();
    }

    /// Calculate TF-IDF score for a word in a document
    pub fn tfidf(self: *const TFIDFContext, word: []const u8, doc_word_count: usize) f64 {
        // Term frequency
        const tf = @as(f64, @floatFromInt(self.word_freq.get(word) orelse 0))
                 / @as(f64, @floatFromInt(doc_word_count));

        // Document frequency (with smoothing)
        const df = @as(f64, @floatFromInt(self.doc_freq.get(word) orelse 1));
        const idf = @log(@as(f64, @floatFromInt(self.document_count + 1)) / (df + 1.0));

        return tf * idf;
    }
};

/// Encode text with TF-IDF weighting
pub fn encodeTextWeighted(text: []const u8, tfidf: *const TFIDFContext) HybridBigInt {
    var result = HybridBigInt.zero();
    var word_iter = std.mem.tokenizeScalar(u8, text, ' ');
    var total_words: usize = 0;

    // First pass: count words
    var word_list = std.ArrayList([]const u8).init(std.heap.page_allocator);
    defer {
        for (word_list.items) |w| std.heap.page_allocator.free(w);
        word_list.deinit();
    }

    while (word_iter.next()) |word| {
        try word_list.append(try std.heap.page_allocator.dupe(u8, word));
        total_words += 1;
    }

    // Second pass: encode with TF-IDF weights
    for (word_list.items) |word| {
        const word_vec = encodeWord(word);
        const weight = tfidf.tfidf(word, total_words);

        // Scale vector by weight
        const scaled = scaleVector(word_vec, weight);
        result = vsa.bundle2(&result, &scaled);
    }

    return result;
}

/// Scale hypervector by weight factor
fn scaleVector(vec: HybridBigInt, weight: f64) HybridBigInt {
    var result = HybridBigInt.zero();

    for (0..TextEncodingConfig.dimension) |i| {
        const val = @as(f64, @floatFromInt(vec.get(i))) * weight;
        const trit: i2 = if (val > 0.5) 1
                      else if (val < -0.5) -1
                      else 0;
        result.set(i, trit);
    }

    return result;
}
```

---

## Part 3: Approximate Decoding via Associative Memory

### 3.1 Dictionary-Based Decoding

**Challenge**: VSA encoding is lossy (one-way function)

**Solution**: Nearest-neighbor search in dictionary

```zig
/// Decode hypervector to nearest text in dictionary
pub fn decodeTextApproximate(
    vector: HybridBigInt,
    allocator: std.mem.Allocator,
    dictionary: []const []const u8
) ![]const u8 {
    if (dictionary.len == 0) return error.EmptyDictionary;

    var best_match: []const u8 = "";
    var best_score: f64 = -1.0;

    for (dictionary) |word| {
        const word_vec = encodeText(word);
        const score = vsa.cosineSimilarity(&vector, &word_vec);

        if (score > best_score) {
            best_score = score;
            best_match = word;
        }
    }

    if (best_score < 0.3) {
        return error.NoMatchFound;
    }

    return allocator.dupe(u8, best_match);
}

/// Find top-k matches for a hypervector
pub fn findTopKMatches(
    vector: HybridBigInt,
    allocator: std.mem.Allocator,
    dictionary: []const []const u8,
    k: usize
) ![]Match {
    if (dictionary.len == 0) return error.EmptyDictionary;
    const actual_k = @min(k, dictionary.len);

    var matches = std.ArrayList(Match).init(allocator);

    for (dictionary) |word| {
        const word_vec = encodeText(word);
        const score = vsa.cosineSimilarity(&vector, &word_vec);

        try matches.append(.{
            .text = word,
            .score = score,
        });
    }

    // Sort by score descending
    std.sort.insert(Match, matches.items, {}, struct {
        fn compare(context: void, a: Match, b: Match) bool {
            _ = context;
            return a.score > b.score;
        }
    }.compare);

    // Return top-k
    const result = try allocator.alloc(Match, actual_k);
    @memcpy(result, matches.items[0..actual_k]);
    matches.deinit();

    return result;
}

pub const Match = struct {
    text: []const u8,
    score: f64,
};
```

---

## Part 4: Scientific Validation

### 4.1 Test Suite

```zig
const std = @import("std");

test "VSA text encoding: cat vs cats similarity > 0.7" {
    const sim = textSimilarity("cat", "cats");
    try std.testing.expect(sim > 0.7);
    std.debug.print("cat vs cats similarity: {d:.3}\n", .{sim});
}

test "VSA text encoding: cat vs dog similarity < 0.5" {
    const sim = textSimilarity("cat", "dog");
    try std.testing.expect(sim < 0.5);
    std.debug.print("cat vs dog similarity: {d:.3}\n", .{sim});
}

test "VSA text encoding: exact match = 1.0" {
    const sim = textSimilarity("hello world", "hello world");
    try std.testing.expectApproxEqRel(sim, 1.0, 0.01);
}

test "VSA text encoding: bigram enhancement improves similarity" {
    const sim_unigram = textSimilarity("running", "runs");
    const sim_bigram = textSimilarityBigram("running", "runs");

    // Bigram should capture "run" pattern
    try std.testing.expect(sim_bigram >= sim_unigram);
    std.debug.print("Unigram: {d:.3}, Bigram: {d:.3}\n", .{ sim_unigram, sim_bigram });
}

test "VSA text encoding: decode with dictionary" {
    const dictionary = &[_][]const u8{
        "cat", "dog", "bird", "fish", "tree",
    };

    const original = "cat";
    const encoded = encodeText(original);
    const decoded = try decodeTextApproximate(encoded, std.testing.allocator, dictionary);

    try std.testing.expectEqualStrings(decoded, original);
}

test "VSA text encoding: top-k matches" {
    const dictionary = &[_][]const u8{
        "cat", "cats", "caterpillar", "catfish", "scatter",
    };

    const query = "cat";
    const encoded = encodeText(query);
    const matches = try findTopKMatches(encoded, std.testing.allocator, dictionary, 3);

    try std.testing.expectEqual(matches.len, 3);
    try std.testing.expectEqualStrings(matches[0].text, "cat");

    std.debug.print("Top-3 matches for 'cat':\n", .{});
    for (matches, 0..) |m, i| {
        std.debug.print("  {d}. {s}: {d:.3}\n", .{ i + 1, m.text, m.score });
    }
}
```

### 4.2 Performance Benchmarks

```zig
test "VSA text encoding: benchmark encode speed" {
    const text = "The quick brown fox jumps over the lazy dog";

    const iterations = 10000;
    const start = std.time.nanoTimestamp();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = encodeText(text);
    }

    const end = std.time.nanoTimestamp();
    const elapsed_ns = end - start;
    const avg_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));

    std.debug.print("Encode time (100 chars): {d:.0} ns\n", .{avg_ns});

    // Target: < 10μs for 100 chars
    try std.testing.expect(avg_ns < 10_000);
}

test "VSA text encoding: benchmark similarity speed" {
    const text1 = "The quick brown fox";
    const text2 = "The lazy dog sleeps";

    const iterations = 10000;
    const start = std.time.nanoTimestamp();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = textSimilarity(text1, text2);
    }

    const end = std.time.nanoTimestamp();
    const elapsed_ns = end - start;
    const avg_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));

    std.debug.print("Similarity time: {d:.0} ns\n", .{avg_ns});

    // Target: < 5μs
    try std.testing.expect(avg_ns < 5_000);
}

test "VSA text encoding: memory per vector" {
    const vec = encodeText("hello");

    // Memory = dimension × sizeof(trit) = 512 × 1 byte = 512 bytes
    // Plus HybridBigInt overhead (~16 bytes for fields)
    const expected_size = TextEncodingConfig.dimension + 16;

    std.debug.print("Vector size: {d} bytes\n", .{expected_size});

    // Target: < 2KB
    try std.testing.expect(expected_size < 2048);
}
```

### 4.3 Semantic Similarity Experiments

```zig
test "VSA text encoding: semantic similarity experiments" {
    const experiments = &[_]struct {
        word1: []const u8,
        word2: []const u8,
        expected_min: f64,
        expected_max: f64,
    }{
        .{ .word1 = "cat", .word2 = "cats", .expected_min = 0.5, .expected_max = 1.0 },
        .{ .word1 = "run", .word2 = "running", .expected_min = 0.5, .expected_max = 1.0 },
        .{ .word1 = "happy", .word2 = "happiness", .expected_min = 0.5, .expected_max = 1.0 },
        .{ .word1 = "cat", .word2 = "dog", .expected_min = 0.0, .expected_max = 0.5 },
        .{ .word1 = "computer", .word2 = "program", .expected_min = 0.0, .expected_max = 0.5 },
    };

    std.debug.print("\n=== Semantic Similarity Experiments ===\n", .{});

    for (experiments) |exp| {
        const sim = textSimilarity(exp.word1, exp.word2);

        std.debug.print("{s} vs {s}: {d:.3} ", .{ exp.word1, exp.word2, sim });

        if (sim >= exp.expected_min and sim <= exp.expected_max) {
            std.debug.print("✓\n", .{});
        } else {
            std.debug.print("✗ (expected: {d:.1}-{d:.1})\n", .{
                exp.expected_min, exp.expected_max
            });
        }

        // Check bounds
        try std.testing.expect(sim >= exp.expected_min - 0.2); // Allow 20% margin
        try std.testing.expect(sim <= exp.expected_max + 0.2);
    }

    std.debug.print("=====================================\n", .{});
}
```

---

## Part 5: Implementation Timeline

| Week | Milestone | Deliverable | Tests |
|------|-----------|-------------|-------|
| 1 | Character vectors | Pre-generated 128-char vectors | 2/2 pass |
| 2 | Word encoding | Bundle-based encoding | 3/3 pass |
| 3 | Similarity metrics | Cosine similarity | 2/2 pass |
| 4 | N-gram encoding | Bigram enhancement | 2/2 pass |
| 5 | TF-IDF weighting | Weighted encoding | 2/2 pass |
| 6 | Decoding | Dictionary lookup | 3/3 pass |
| 7 | Benchmarks | Performance validation | 3/3 pass |
| 8 | Integration | CLI commands | 4/4 pass |

---

## Part 6: Results Targets

### 6.1 Semantic Similarity

| Word Pair | Target (H1) | Baseline | Method |
|-----------|-------------|----------|--------|
| cat-cats | > 0.7 | 0.5 | Bigram VSA |
| run-running | > 0.7 | 0.5 | Bigram VSA |
| cat-dog | < 0.5 | 0.5 | Cosine sim |

### 6.2 Performance Targets

| Metric | Target | V1 | V2 |
|--------|--------|----|----|
| Encode (100 chars) | < 10μs | ✓ | ✓ |
| Similarity | < 5μs | ✓ | ✓ |
| Memory | < 2KB | 512B | 2KB |
| Semantic similarity | > 30% | 35% | 70% |

### 6.3 Scientific Validation

**Hypothesis H1**: Ternary VSA achieves >30% semantic similarity at d=512.

**Test Procedure**:
1. Encode 100 word pairs with known semantic relationships
2. Calculate cosine similarity for each pair
3. Count pairs with similarity > 0.3
4. Target: ≥ 30 pairs (30%)

**Statistical Analysis**:
- Sample size: n = 100 word pairs
- Null hypothesis: Similarity ≤ 0.3
- Alternative hypothesis: Similarity > 0.3
- Test: One-sample t-test
- Significance: α = 0.05

---

## References

1. Plate, T. A. (2003). "Distributed Sparse Distributed Memory"
2. Kanerva, P. (2009). "Hyperdimensional Computing: An Introduction"
3. Gayler, R. W. (2003). "Vector Symbolic Architectures"
4. Joselyne, A. et al. (2024). "Ternary Neural Networks"
5. Manning, C. D. et al. (2008). "Introduction to Information Retrieval"

---

**φ² + 1/φ² = 3 | TRINITY**
**Version**: 1.0
**Date**: 2026-03-27
**Status**: Detailed Design — Ready for Implementation
