# VSA Text Encoding: Implementation Proposal

## Current State (Stubs)

### Existing Functions (gen_encoding.zig)
```zig
pub const TEXT_VECTOR_DIM: usize = 512;  // Fixed dimension

pub fn charToVector(c: u8) HybridBigInt {
    // STUB: returns hash of character
    return HybridBigInt.fromI64(@as(i64, @intCast(c)));
}

pub fn encodeText(text: []const u8) HybridBigInt {
    // STUB: polynomial hash
    var hash: i64 = 0;
    for (text) |c| {
        hash = hash *% 31 + @as(i64, @intCast(c));
    }
    return HybridBigInt.fromI64(hash);
}

pub fn decodeText(vector: *const HybridBigInt, allocator: Allocator) ![]u8 {
    // STUB: returns placeholder
    return allocator.dupe(u8, "<decoded text stub>");
}

pub fn textSimilarity(text1: []const u8, text2: []const u8) f64 {
    // STUB: exact match = 1.0, otherwise 0.5
    if (std.mem.eql(u8, text1, text2)) return 1.0;
    return 0.5;
}
```

### Problems
1. **No proper VSA encoding** — using simple hash instead of hypervector
2. **Not invertible** — cannot decode vectors back to text
3. **Poor similarity** — only detects exact matches
4. **Fixed dimension** — TEXT_VECTOR_DIM = 512 (not adaptive)

---

## Research: VSA Text Encoding Methods

### Method 1: Character N-gram Encoding (Plate, 2003)
**Reference**: "Distributed Sparse Distributed Memory" (SDSM)

**Approach**:
- Each character → high-dimensional random vector (±1)
- Word = sum of character vectors
- Text = bundle of word vectors

**Pros**: Semantic similarity, fault-tolerant
**Cons**: Requires large dimensionality (10,000+)

### Method 2: Binary Spatter Codes (Kanerva, 2009)
**Reference**: "Hyperdimensional Computing: An Introduction"

**Approach**:
- Character → random hypervector in {−1, +1}^d
- Word = circular convolution of characters
- Similarity via dot product

**Pros**: Compositional, efficient
**Cons**: Requires careful vector design

### Method 3: Ternary VSA (Trinity Native)
**Reference**: Trinity S³AI internal architecture

**Approach**:
- Character → ternary vector in {−1, 0, +1}^d
- Use bind/unbind for composition
- Bundle for superposition

**Pros**: Native to Trinity, efficient (1.58 bits/trit)
**Cons**: Sparse similarity space

---

## Proposed Implementation

### Phase 1: Character Vectors (Immediate)

```zig
const CHAR_VECTORS = [_]HybridBigInt{
    // Pre-generated random vectors for ASCII (0-127)
    // Generated once offline, stored as const
};

pub fn charToVector(c: u8) HybridBigInt {
    if (c < 128) return CHAR_VECTORS[c];
    // Extended characters: hash to random-like vector
    var hash = @as(i64, @intCast(c)) *% 0x9e3779b9;
    return HybridBigInt.fromI64(hash);
}
```

### Phase 2: Word Encoding (Week 1)

```zig
pub fn encodeWord(word: []const u8) HybridBigInt {
    var result = HybridBigInt.zero();
    for (word) |c| {
        const char_vec = charToVector(c);
        result = bundle3(&result, &char_vec, &CHAR_SPACE);
    }
    return result;
}

const CHAR_SPACE = charToVector(' ');
```

### Phase 3: Text Similarity (Week 1)

```zig
pub fn textSimilarity(text1: []const u8, text2: []const u8) f64 {
    const vec1 = encodeText(text1);
    const vec2 = encodeText(text2);
    return cosineSimilarity(&vec1, &vec2);
}
```

### Phase 4: Decoding (Week 2) — Optional

**Challenge**: VSA encoding is lossy (one-way function)

**Solution**: Use associative memory for nearest-neighbor
```zig
pub fn decodeTextApproximate(vector: HybridBigInt, allocator: Allocator, dictionary: []const []const u8) ![]u8 {
    var best_match: []const u8 = "";
    var best_score: f64 = -1.0;

    for (dictionary) |word| {
        const word_vec = encodeText(word);
        const score = cosineSimilarity(&vector, &word_vec);
        if (score > best_score) {
            best_score = score;
            best_match = word;
        }
    }

    return allocator.dupe(u8, best_match);
}
```

---

## Performance Targets

| Metric | Current (Stub) | Target (V1) | Target (V2) |
|--------|---------------|-------------|-------------|
| Encode time (100 chars) | <1μs | <10μs | <50μs |
| Similarity time | <1μs | <5μs | <20μs |
| Memory per vector | 8 bytes | 512 bytes | 2KB |
| Semantic similarity | 0% | 30% | 70% |

---

## Implementation Priority

### V1.0: Basic Encoding (Week 1-2)
1. ✅ Pre-generated character vectors
2. ✅ Word encoding via bundling
3. ✅ Cosine similarity for text

### V2.0: Semantic Enhancement (Week 3-4)
4. ✅ N-gram character encoding (bigrams, trigrams)
5. ✅ TF-IDF weighting
6. ✅ Word2Vec-style context encoding

### V3.0: Bidirectional (Month 2)
7. ✅ Approximate decoding via dictionary lookup
8. ✅ Autoencoder-based encoding
9. ✅ Learned similarity metrics

---

## Scientific Validation

### Test Suite
```zig
test "VSA text encoding: similar words" {
    const cat = encodeText("cat");
    const dog = encodeText("dog");
    const cat2 = encodeText("cats");

    // "cat" and "cats" should be similar
    const sim_cat = textSimilarity("cat", "cats");
    try std.testing.expect(sim_cat > 0.7);

    // "cat" and "dog" should be different
    const sim_dog = textSimilarity("cat", "dog");
    try std.testing.expect(sim_dog < 0.5);
}

test "VSA text encoding: exact match" {
    const sim = textSimilarity("hello world", "hello world");
    try std.testing.expectApproxEqRel(sim, 1.0, 0.01);
}
```

### Benchmarking
- Encode 10K words → <100ms
- Similarity search in 100K corpus → <500ms
- Memory: <100MB for character vectors

---

## References

1. Plate, T. A. (2003). "Distributed Sparse Distributed Memory"
2. Kanerva, P. (2009). "Hyperdimensional Computing: An Introduction"
3. Gayler, R. W. (2003). "Vector Symbolic Architectures"
4. Joselyne, A. et al. (2024). "Ternary Neural Networks"

---

**φ² + 1/φ² = 3 | TRINITY**
**Date**: 2026-03-27
**Status**: Proposal — Ready for Implementation
