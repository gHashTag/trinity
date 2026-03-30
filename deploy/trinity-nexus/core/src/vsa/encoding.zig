// 🤖 TRINITY v0.11.0: Suborbital Order
// Text encoding/decoding operations for VSA

const std = @import("std");
const common = @import("common.zig");
const core = @import("core.zig");
const HybridBigInt = common.HybridBigInt;
const Trit = common.Trit;

/// Default vector dimension for text encoding
pub const TEXT_VECTOR_DIM: usize = 1000;

/// Generate deterministic vector for a character
/// Uses character code as seed for reproducibility
pub fn charToVector(char: u8) HybridBigInt {
    const char64: u64 = @as(u64, char);
    const seed: u64 = char64 *% 0x9E3779B97F4A7C15 +% 0xC6BC279692B5C323;
    return core.randomVector(TEXT_VECTOR_DIM, seed);
}

/// Encode text string to hypervector
/// Uses position-based binding: text_vec = sum(permute(char_vec[i], i))
pub fn encodeText(text: []const u8) HybridBigInt {
    if (text.len == 0) return HybridBigInt.zero();

    // Start with first character
    var result = charToVector(text[0]);

    // Add permuted character vectors for remaining positions
    for (1..text.len) |i| {
        var char_vec = charToVector(text[i]);
        var permuted = core.permute(&char_vec, i);
        result = result.add(&permuted);
    }

    return result;
}

/// Decode hypervector back to text
/// Probes each position against character codebook
/// Returns decoded text up to max_len characters
pub fn decodeText(encoded: *HybridBigInt, max_len: usize, buffer: []u8) []u8 {
    var decoded_len: usize = 0;

    for (0..max_len) |pos| {
        if (pos >= buffer.len) break;

        var best_char: u8 = ' ';
        var best_sim: f64 = -2.0;

        // Check printable ASCII characters (32-126)
        var c: u8 = 32;
        while (c <= 126) : (c += 1) {
            var char_vec = charToVector(c);
            const sim = core.probeSequence(encoded, &char_vec, pos);

            if (sim > best_sim) {
                best_sim = sim;
                best_char = c;
            }
        }

        // Stop if similarity drops too low (end of encoded text)
        if (best_sim < 0.1 and pos > 0) break;

        buffer[pos] = best_char;
        decoded_len = pos + 1;
    }

    return buffer[0..decoded_len];
}

/// Simple encode-decode roundtrip check
pub fn textRoundtrip(text: []const u8, buffer: []u8) []u8 {
    var encoded = encodeText(text);
    return decodeText(&encoded, text.len, buffer);
}

/// Encode a single word to a hypervector using hash-based seed
/// The entire word maps to one deterministic random vector (no positional encoding)
pub fn encodeWord(word: []const u8) HybridBigInt {
    if (word.len == 0) return HybridBigInt.zero();

    // Hash the word bytes to produce a single seed
    var hash: u64 = 0x517cc1b727220a95; // FNV offset basis
    for (word) |c| {
        // Lowercase for case-insensitive matching
        const lower: u64 = if (c >= 'A' and c <= 'Z') c + 32 else c;
        hash ^= lower;
        hash *%= 0x100000001b3; // FNV prime
    }
    return core.randomVector(TEXT_VECTOR_DIM, hash);
}

/// Encode text to hypervector using word-level bag-of-words
/// Splits on whitespace/punctuation, encodes each word independently, bundles all.
/// Uses element-wise majority vote (proper VSA bundling), not arithmetic addition.
pub fn encodeTextWords(text: []const u8) HybridBigInt {
    if (text.len == 0) return HybridBigInt.zero();

    var sums: [common.MAX_TRITS]i16 = @splat(0);
    var word_count: usize = 0;
    var word_start: usize = 0;
    var in_word: bool = false;
    var max_dim: usize = 0;

    for (text, 0..) |c, i| {
        const is_alpha = (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9');
        if (is_alpha) {
            if (!in_word) {
                word_start = i;
                in_word = true;
            }
        } else {
            if (in_word) {
                const word = text[word_start..i];
                if (word.len >= 2) {
                    var wv = encodeWord(word);
                    wv.ensureUnpacked();
                    max_dim = @max(max_dim, wv.trit_len);
                    for (0..wv.trit_len) |j| {
                        sums[j] += wv.unpacked_cache[j];
                    }
                    word_count += 1;
                }
                in_word = false;
            }
        }
    }
    if (in_word) {
        const word = text[word_start..text.len];
        if (word.len >= 2) {
            var wv = encodeWord(word);
            wv.ensureUnpacked();
            max_dim = @max(max_dim, wv.trit_len);
            for (0..wv.trit_len) |j| {
                sums[j] += wv.unpacked_cache[j];
            }
            word_count += 1;
        }
    }

    if (word_count == 0) return encodeText(text);

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;
    result.trit_len = max_dim;

    for (0..max_dim) |j| {
        if (sums[j] > 0) {
            result.unpacked_cache[j] = 1;
        } else if (sums[j] < 0) {
            result.unpacked_cache[j] = -1;
        } else {
            result.unpacked_cache[j] = 0;
        }
    }

    return result;
}

/// Compare semantic similarity between two texts
/// Returns cosine similarity in range [-1, 1]
pub fn textSimilarity(text1: []const u8, text2: []const u8) f64 {
    var vec1 = encodeText(text1);
    var vec2 = encodeText(text2);
    return core.cosineSimilarity(&vec1, &vec2);
}

/// Check if two texts are semantically similar (above threshold)
pub fn textsAreSimilar(text1: []const u8, text2: []const u8, threshold: f64) bool {
    return textSimilarity(text1, text2) >= threshold;
}

// φ² + 1/φ² = 3 | TRINITY
