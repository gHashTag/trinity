// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE Tier 3 — Simple VSA Compilation Test
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const vsa = @import("vsa.zig");

test "vsa.compile: VSA module compiles and types are available" {
    const allocator = std.testing.allocator;

    // Test that core types are available
    _ = vsa.DEFAULT_EMBEDDING_DIM;
    _ = vsa.DEFAULT_SIMILARITY_THRESHOLD;
    _ = vsa.DEFAULT_TOP_K;

    // Test that SemanticVector can be created
    var vec = try vsa.SemanticVector.init(allocator, "test", 64);
    defer vec.deinit();

    try std.testing.expectEqual(@as(usize, 64), vec.embedding.len);
    try std.testing.expectEqualStrings("test", vec.symbol_id);
}

test "vsa.compile: SemanticIndex can be created" {
    const allocator = std.testing.allocator;
    var index = try vsa.SemanticIndex.init(allocator, 128);
    defer index.deinit();

    try std.testing.expectEqual(@as(usize, 128), index.embedding_dim);
}

test "vsa.compile: Hash embedding generation works" {
    const allocator = std.testing.allocator;
    const embedding = try vsa.generateHashEmbedding(allocator, "test", "sig", "ctx", 64);
    defer allocator.free(embedding);

    try std.testing.expectEqual(@as(usize, 64), embedding.len);

    // Verify L2 normalization
    const norm = vsa.l2Norm(embedding);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), norm, 0.01);
}

test "vsa.compile: Similarity metrics work" {
    const vec1 = [_]f32{ 1.0, 0.0, 0.0 };
    const vec2 = [_]f32{ 1.0, 0.0, 0.0 };

    const sim = vsa.cosineSimilarity(&vec1, &vec2);
    try std.testing.expect(sim > 0.99);
}

test "vsa.compile: L2 norm calculation" {
    const vec = [_]f32{ 3.0, 4.0 };
    const norm = vsa.l2Norm(&vec);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), norm, 0.01);
}

// Summary: 5 basic compilation tests
