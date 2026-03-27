// ═══════════════════════════════════════════════════════════════════════════════
// VSA Core — Text Encoding (GENERATED from specs/vsa/encoding.tri)
// Island 2: Text encoding operations
// DO NOT EDIT — Regenerate from .tri spec
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const common = @import("common.zig");
const Trit = common.Trit;
const Allocator = std.mem.Allocator;

pub const TEXT_VECTOR_DIM: usize = 1000;

const ops = @import("ops.zig");

/// Character codebook (deterministic vector per character)
pub const Codebook = struct {
    vectors: [256][]const Trit,
    allocator: std.mem.Allocator,
    dim: usize,

    /// Initialize codebook with deterministic vectors
    pub fn initCodebook(allocator: std.mem.Allocator, dim: usize) !Codebook {
        var vectors: [256][]const Trit = undefined;

        for (0..256) |i| {
            const char64: u64 = @as(u64, i);
            const seed: u64 = char64 *% 0x9E3779B97F4A7C15 +% 0xC6BC279692B5C323;
            vectors[i] = try ops.randomVector(allocator, dim, seed);
        }

        return .{
            .vectors = vectors,
            .allocator = allocator,
            .dim = dim,
        };
    }

    /// Get vector for character
    pub fn getVector(self: Codebook, char: u8) []const Trit {
        return self.vectors[char];
    }

    /// Deallocate all vectors
    pub fn deinitCodebook(self: Codebook) void {
        for (self.vectors) |v| {
            self.allocator.free(v);
        }
    }
};

/// Encode text string to hypervector
pub fn encodeText(allocator: std.mem.Allocator, codebook: Codebook, text: []const u8) ![]Trit {
    if (text.len == 0) {
        return allocator.alloc(Trit, codebook.dim);
    }

    var result = try allocator.alloc(Trit, codebook.dim);
    @memcpy(result, codebook.getVector(text[0]));

    for (1..text.len) |i| {
        const char_vec = codebook.getVector(text[i]);
        const permuted = try ops.permute(allocator, char_vec, i);
        defer allocator.free(permuted);

        const bundled = try ops.bundle2(allocator, result, permuted);
        allocator.free(result);
        result = bundled;
    }

    return result;
}

/// Encode text with word-level tokenization
pub fn encodeTextWords(allocator: std.mem.Allocator, codebook: Codebook, text: []const u8) ![]Trit {
    if (text.len == 0) {
        return allocator.alloc(Trit, codebook.dim);
    }

    var word_iter = std.mem.splitScalar(u8, text, ' ');
    var result: []Trit = &[_]Trit{};
    var first = true;

    while (word_iter.next()) |word| {
        if (word.len == 0) continue;

        const word_vec = try encodeText(allocator, codebook, word);
        defer if (!first) allocator.free(result);

        if (first) {
            result = word_vec;
            first = false;
        } else {
            const bundled = try ops.bundle2(allocator, result, word_vec);
            allocator.free(result);
            result = bundled;
            allocator.free(word_vec);
        }
    }

    if (first) {
        return allocator.alloc(Trit, codebook.dim);
    }

    return result;
}

/// Decode hypervector (probe against character codebook)
pub fn decodeText(allocator: std.mem.Allocator, codebook: Codebook, encoded: []const Trit, max_len: usize) ![]u8 {
    var result = try allocator.alloc(u8, max_len);
    var result_len: usize = 0;

    for (0..max_len) |pos| {
        var best_char: u8 = ' ';
        var best_sim: f64 = -1.0;

        for (0..256) |c| {
            const char_vec = codebook.getVector(@as(u8, @intCast(c)));
            const permuted = try ops.permute(allocator, char_vec, pos);
            defer allocator.free(permuted);

            const sim = ops.cosineSimilarity(encoded, permuted);
            if (sim > best_sim) {
                best_sim = sim;
                best_char = @as(u8, @intCast(c));
            }
        }

        if (best_sim > 0.3) {
            result[result_len] = best_char;
            result_len += 1;
        }
    }

    return result[0..result_len];
}

/// Compute similarity between two text vectors
pub fn textSimilarity(a: []const Trit, b: []const Trit) f64 {
    return ops.cosineSimilarity(a, b);
}

/// Check if two texts are similar (above threshold)
pub fn textsAreSimilar(a: []const Trit, b: []const Trit, threshold: f64) bool {
    return textSimilarity(a, b) >= threshold;
}

/// Search result struct
pub const SearchResult = struct {
    index: usize,
    similarity: f64,
};

/// Find best match in corpus
pub fn findBestMatch(allocator: std.mem.Allocator, codebook: Codebook, query: []const u8, corpus: []const []const u8) !SearchResult {
    const query_vec = try encodeText(allocator, codebook, query);
    defer allocator.free(query_vec);

    var best_idx: usize = 0;
    var best_sim: f64 = -1.0;

    for (corpus, 0..) |doc, idx| {
        const doc_vec = try encodeText(allocator, codebook, doc);
        defer allocator.free(doc_vec);

        const sim = textSimilarity(query_vec, doc_vec);
        if (sim > best_sim) {
            best_sim = sim;
            best_idx = idx;
        }
    }

    return .{
        .index = best_idx,
        .similarity = best_sim,
    };
}
test "Codebook initialization" {
    var codebook = try Codebook.initCodebook(std.testing.allocator, 100);
    defer codebook.deinitCodebook();

    const v1 = codebook.getVector('A');
    const v2 = codebook.getVector('A');

    try std.testing.expectEqualSlices(Trit, v1, v2);
}

test "encode text length" {
    var codebook = try Codebook.initCodebook(std.testing.allocator, 100);
    defer codebook.deinitCodebook();

    const text = "HELLO";

    const encoded = try encodeText(std.testing.allocator, codebook, text);
    defer std.testing.allocator.free(encoded);

    try std.testing.expectEqual(@as(usize, 100), encoded.len);
}

test "textSimilarity identical" {
    var codebook = try Codebook.initCodebook(std.testing.allocator, 100);
    defer codebook.deinitCodebook();

    const text = "TEST";

    const vec1 = try encodeText(std.testing.allocator, codebook, text);
    defer std.testing.allocator.free(vec1);

    const vec2 = try encodeText(std.testing.allocator, codebook, text);
    defer std.testing.allocator.free(vec2);

    const sim = textSimilarity(vec1, vec2);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 0.001);
}

test "findBestMatch" {
    var codebook = try Codebook.initCodebook(std.testing.allocator, 100);
    defer codebook.deinitCodebook();

    const corpus = &[_][]const u8{ "apple", "banana", "cherry" };
    const result = try findBestMatch(std.testing.allocator, codebook, "apple", corpus);

    try std.testing.expectEqual(@as(usize, 0), result.index);
    try std.testing.expect(result.similarity > 0.9);
}
