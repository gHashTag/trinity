// VSA Core — Root Module
// TTT Dogfood v0.1: Self-hosted VSA module
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// Common types
pub const Trit = @import("common.zig").Trit;
pub const SearchResult = @import("common.zig").SearchResult;
pub const Vec32i8 = @import("common.zig").Vec32i8;
pub const Vec32i16 = @import("common.zig").Vec32i16;
pub const SIMD_WIDTH = @import("common.zig").SIMD_WIDTH;

// Core operations
pub const bind = @import("ops.zig").bind;
pub const unbind = @import("ops.zig").unbind;
pub const bundle2 = @import("ops.zig").bundle2;
pub const bundle3 = @import("ops.zig").bundle3;
pub const bundleN = @import("ops.zig").bundleN;
pub const permute = @import("ops.zig").permute;
pub const inversePermute = @import("ops.zig").inversePermute;
pub const randomVector = @import("ops.zig").randomVector;
pub const encodeSequence = @import("ops.zig").encodeSequence;
pub const probeSequence = @import("ops.zig").probeSequence;
pub const cosineSimilarity = @import("ops.zig").cosineSimilarity;
pub const hammingDistance = @import("ops.zig").hammingDistance;
pub const hammingSimilarity = @import("ops.zig").hammingSimilarity;
pub const dotSimilarity = @import("ops.zig").dotSimilarity;
pub const vectorNorm = @import("ops.zig").vectorNorm;
pub const countNonZero = @import("ops.zig").countNonZero;
pub const dotProduct = @import("ops.zig").dotProduct;

// Sparse operations
pub const SparseVector = @import("sparse.zig").SparseVector;

// Text encoding
pub const TEXT_VECTOR_DIM = @import("encoding.zig").TEXT_VECTOR_DIM;
pub const Codebook = @import("encoding.zig").Codebook;
pub const initCodebook = @import("encoding.zig").initCodebook;
pub const encodeText = @import("encoding.zig").encodeText;
pub const encodeTextWords = @import("encoding.zig").encodeTextWords;
pub const decodeText = @import("encoding.zig").decodeText;
pub const textSimilarity = @import("encoding.zig").textSimilarity;
pub const textsAreSimilar = @import("encoding.zig").textsAreSimilar;
pub const findBestMatch = @import("encoding.zig").findBestMatch;

test "vsa_core: all modules importable" {
    _ = @import("common.zig");
    _ = @import("ops.zig");
    _ = @import("sparse.zig");
    _ = @import("encoding.zig");
}

test "vsa_core: core operations work" {
    const a = [_]Trit{ 1, -1, 0, 1 };
    const b = [_]Trit{ 1, 1, 0, -1 };

    const dot = dotProduct(&a, &b);
    try std.testing.expectEqual(@as(i64, -1), dot);

    const sim = cosineSimilarity(&a, &b);
    try std.testing.expect(sim < 1.0 and sim > -1.0);
}

test "vsa_core: sparse operations work" {
    const dense = [_]Trit{ 0, 1, 0, -1 };
    var sparse = try SparseVector.fromDense(std.testing.allocator, &dense);
    defer sparse.deinitSparse(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), sparse.indices.len);
}

test "vsa_core: encoding operations work" {
    try std.testing.expectEqual(@as(usize, 1000), TEXT_VECTOR_DIM);
}
