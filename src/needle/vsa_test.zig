// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE Tier 3 — VSA Embeddings Tests
// ═══════════════════════════════════════════════════════════════════════════════
//
// Tests for VSA-based semantic search and embeddings
// φ² + 1/φ² = 3 | TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const vsa = @import("vsa.zig");
const zig_parser = @import("zig_parser.zig");

const Allocator = std.mem.Allocator;
const expectEqual = std.testing.expectEqual;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 1: VSA Basic Operations (10 cases)
// ═══════════════════════════════════════════════════════════════════════════════

test "vsa.1: Codebook init and cleanup" {
    const allocator = std.testing.allocator;
    var codebook = try vsa.Codebook.init(allocator, 100);
    defer codebook.deinit();

    try expectEqual(@as(usize, 0), codebook.count());
}

test "vsa.2: Bind and unbind roundtrip" {
    const allocator = std.testing.allocator;
    var codebook = try vsa.Codebook.init(allocator, 100);
    defer codebook.deinit();

    const symbol_a = "function_a";
    const symbol_b = "parameter_x";

    const hv_a = try codebook.getOrBind(symbol_a);
    const hv_b = try codebook.getOrBind(symbol_b);

    // Bind: A ⊗ B
    var bound = try vsa.bind(allocator, hv_a, hv_b);
    defer bound.deinit(allocator);

    // Unbind: (A ⊗ B) ⊗ A ≈ B
    var recovered = try vsa.unbind(allocator, bound, hv_a);
    defer recovered.deinit(allocator);

    // Similarity should be high between recovered and original B
    const similarity = vsa.cosineSimilarity(recovered.data(), hv_b.data());
    try expectApproxEqAbs(@as(f32, 1.0), similarity, 0.1);
}

test "vsa.3: Bundle two vectors" {
    const allocator = std.testing.allocator;
    var codebook = try vsa.Codebook.init(allocator, 100);
    defer codebook.deinit();

    const hv_a = try codebook.getOrBind("a");
    const hv_b = try codebook.getOrBind("b");

    const vectors = &[_]vsa.Hypervector{ hv_a, hv_b };
    var bundled = try vsa.bundle(allocator, vectors);
    defer bundled.deinit(allocator);

    // Bundled vector should be non-zero
    const bundled_data = bundled.data();
    var sum: f32 = 0;
    for (bundled_data) |v| sum += @abs(v);
    try std.testing.expect(sum > 0);
}

test "vsa.4: Cosine similarity of identical vectors" {
    const allocator = std.testing.allocator;
    var codebook = try vsa.Codebook.init(allocator, 100);
    defer codebook.deinit();

    const hv = try codebook.getOrBind("test");
    const similarity = vsa.cosineSimilarity(hv.data(), hv.data());
    try expectApproxEqAbs(@as(f32, 1.0), similarity, 0.001);
}

test "vsa.5: Cosine similarity of different vectors" {
    const allocator = std.testing.allocator;
    var codebook = try vsa.Codebook.init(allocator, 100);
    defer codebook.deinit();

    const hv_a = try codebook.getOrBind("alpha");
    const hv_b = try codebook.getOrBind("beta");

    const similarity = vsa.cosineSimilarity(hv_a.data(), hv_b.data());
    // Different symbols should have low similarity
    try std.testing.expect(similarity < 0.5);
}

test "vsa.6: Hash-based embedding generation" {
    const allocator = std.testing.allocator;
    const dim: usize = 128;

    const embedding = try vsa.generateHashEmbedding(
        allocator,
        "myFunction",
        "fn_def:myFunction",
        "src/file.zig",
        dim,
    );
    defer allocator.free(embedding);

    try expectEqual(dim, embedding.len);

    // Verify L2 normalization (norm should be ~1.0)
    const norm = vsa.l2Norm(embedding);
    try expectApproxEqAbs(@as(f32, 1.0), norm, 0.01);
}

test "vsa.7: Same symbol produces same embedding" {
    const allocator = std.testing.allocator;

    const emb1 = try vsa.generateHashEmbedding(allocator, "test", "sig", "ctx", 64);
    defer allocator.free(emb1);

    const emb2 = try vsa.generateHashEmbedding(allocator, "test", "sig", "ctx", 64);
    defer allocator.free(emb2);

    // Identical inputs should produce identical embeddings
    const similarity = vsa.cosineSimilarity(emb1, emb2);
    try expectApproxEqAbs(@as(f32, 1.0), similarity, 0.001);
}

test "vsa.8: Different symbols produce different embeddings" {
    const allocator = std.testing.allocator;

    const emb1 = try vsa.generateHashEmbedding(allocator, "alpha", "sig", "ctx", 64);
    defer allocator.free(emb1);

    const emb2 = try vsa.generateHashEmbedding(allocator, "beta", "sig", "ctx", 64);
    defer allocator.free(emb2);

    const similarity = vsa.cosineSimilarity(emb1, emb2);
    try std.testing.expect(similarity < 0.9);
}

test "vsa.9: L2 norm calculation" {
    const vec = [_]f32{ 3.0, 4.0 }; // Should have norm 5.0
    const norm = vsa.l2Norm(&vec);
    try expectApproxEqAbs(@as(f32, 5.0), norm, 0.01);
}

test "vsa.10: Euclidean distance" {
    const vec1 = [_]f32{ 0.0, 0.0 };
    const vec2 = [_]f32{ 3.0, 4.0 };
    const dist = vsa.euclideanDistance(&vec1, &vec2);
    try expectApproxEqAbs(@as(f32, 5.0), dist, 0.01);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 2: Embedding Roundtrip (5 cases)
// ═══════════════════════════════════════════════════════════════════════════════

test "embeddings.1: SemanticVector init and deinit" {
    const allocator = std.testing.allocator;
    var vec = try vsa.SemanticVector.init(allocator, "testSymbol", 128);
    defer vec.deinit();

    try expectEqual(@as(usize, 128), vec.embedding.len);
    try std.testing.expectEqualStrings("testSymbol", vec.symbol_id);
}

test "embeddings.2: SemanticVector clone" {
    const allocator = std.testing.allocator;
    var original = try vsa.SemanticVector.init(allocator, "original", 64);
    defer original.deinit();

    // Set some values
    original.line = 42;

    const cloned = try original.clone();
    defer cloned.deinit();

    try std.testing.expectEqualStrings(original.symbol_id, cloned.symbol_id);
    try expectEqual(original.line, cloned.line);
}

test "embeddings.3: VSARule init" {
    const allocator = std.testing.allocator;
    var rule = try vsa.VSARule.init(allocator, "test_rule");
    defer rule.deinit();

    try std.testing.expectEqualStrings("test_rule", rule.pattern_id);
    try expectEqual(vsa.DEFAULT_SIMILARITY_THRESHOLD, rule.similarity_threshold);
}

test "embeddings.4: VSAMatch confidence computation" {
    const allocator = std.testing.allocator;
    var match = vsa.VSAMatch.init(allocator);
    defer match.deinit();

    match.similarity = 0.8;
    match.context_match = 0.6;
    match.computeConfidence();

    // Confidence = 0.7 * similarity + 0.3 * context_match
    // = 0.7 * 0.8 + 0.3 * 0.6 = 0.56 + 0.18 = 0.74
    try expectApproxEqAbs(@as(f32, 0.74), match.confidence, 0.01);
}

test "embeddings.5: VSA embedding generation" {
    const allocator = std.testing.allocator;
    var codebook = try vsa.Codebook.init(allocator, 100);
    defer codebook.deinit();

    const hv = try vsa.generateVSAEmbedding(
        allocator,
        &codebook,
        "test_symbol",
        "test_context",
    );
    defer hv.deinit(allocator);

    // Should produce a valid hypervector
    const data = hv.data();
    try std.testing.expect(data.len > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 3: Semantic Similarity (8 cases)
// ═══════════════════════════════════════════════════════════════════════════════

test "similarity.1: SemanticIndex init" {
    const allocator = std.testing.allocator;
    var index = try vsa.SemanticIndex.init(allocator, 256);
    defer index.deinit();

    try expectEqual(@as(usize, 256), index.embedding_dim);
}

test "similarity.2: Add vector to index" {
    const allocator = std.testing.allocator;
    var index = try vsa.SemanticIndex.init(allocator, 128);
    defer index.deinit();

    var vec = try vsa.SemanticVector.init(allocator, "add_test", 128);
    defer vec.deinit();

    try index.addVector(vec);

    try expectEqual(@as(usize, 1), index.vectors.count());
}

test "similarity.3: Search with no results" {
    const allocator = std.testing.allocator;
    var index = try vsa.SemanticIndex.init(allocator, 128);
    defer index.deinit();

    const query_embedding = try allocator.alloc(f32, 128);
    defer allocator.free(query_embedding);
    @memset(query_embedding, 0.0);

    const results = try index.search(query_embedding, 10, 0.5);
    defer {
        for (results.items) |*r| r.deinit();
        results.deinit(allocator);
    }

    try expectEqual(@as(usize, 0), results.items.len);
}

test "similarity.4: Search with exact match" {
    const allocator = std.testing.allocator;
    var index = try vsa.SemanticIndex.init(allocator, 128);
    defer index.deinit();

    var vec = try vsa.SemanticVector.init(allocator, "exact_match", 128);
    defer vec.deinit();
    @memcpy(vec.embedding, &[_]f32{0.1} ** 128);

    try index.addVector(vec);

    const query = &[_]f32{0.1} ** 128;
    const results = try index.search(query, 10, 0.9);
    defer {
        for (results.items) |*r| r.deinit();
        results.deinit(allocator);
    }

    try std.testing.expect(results.items.len >= 1);
    if (results.items.len > 0) {
        try std.testing.expect(results.items[0].similarity > 0.9);
    }
}

test "similarity.5: Search respects top_k limit" {
    const allocator = std.testing.allocator;
    var index = try vsa.SemanticIndex.init(allocator, 64);
    defer index.deinit();

    // Add multiple vectors
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        var vec = try vsa.SemanticVector.init(allocator, "test", 64);
        defer vec.deinit();
        try index.addVector(vec);
    }

    const query = try allocator.alloc(f32, 64);
    defer allocator.free(query);
    @memset(query, 0.0);

    const results = try index.search(query, 5, 0.0);
    defer {
        for (results.items) |*r| r.deinit();
        results.deinit(allocator);
    }

    try std.testing.expect(results.items.len <= 5);
}

test "similarity.6: Search respects similarity threshold" {
    const allocator = std.testing.allocator;
    var index = try vsa.SemanticIndex.init(allocator, 64);
    defer index.deinit();

    var vec = try vsa.SemanticVector.init(allocator, "threshold_test", 64);
    defer vec.deinit();
    @memset(vec.embedding, 0.0);
    try index.addVector(vec);

    // Query with orthogonal vector
    var query = try allocator.alloc(f32, 64);
    defer allocator.free(query);
    for (0..64) |j| {
        query[j] = @as(f32, @floatFromInt(j)) / 64.0;
    }

    const results = try index.search(query, 10, 0.95);
    defer {
        for (results.items) |*r| r.deinit();
        results.deinit(allocator);
    }

    // Should not match due to high threshold
    try expectEqual(@as(usize, 0), results.items.len);
}

test "similarity.7: Results sorted by confidence" {
    const allocator = std.testing.allocator;
    var index = try vsa.SemanticIndex.init(allocator, 64);
    defer index.deinit();

    // Add vectors with varying similarities
    var vec1 = try vsa.SemanticVector.init(allocator, "low", 64);
    defer vec1.deinit();
    @memset(vec1.embedding, 0.0);
    try index.addVector(vec1);

    var vec2 = try vsa.SemanticVector.init(allocator, "high", 64);
    defer vec2.deinit();
    @memset(vec2.embedding, 1.0);
    // Normalize
    const norm2 = vsa.l2Norm(vec2.embedding);
    if (norm2 > 0) {
        for (vec2.embedding) |*v| v.* /= norm2;
    }
    try index.addVector(vec2);

    const query = &[_]f32{1.0} ** 64;
    const results = try index.search(query, 10, 0.0);
    defer {
        for (results.items) |*r| r.deinit();
        results.deinit(allocator);
    }

    if (results.items.len >= 2) {
        // Results should be sorted by confidence (descending)
        try std.testing.expect(results.items[0].confidence >= results.items[1].confidence);
    }
}

test "similarity.8: SemanticSearch function" {
    const allocator = std.testing.allocator;
    var index = try vsa.SemanticIndex.init(allocator, 128);
    defer index.deinit();

    var vec = try vsa.SemanticVector.init(allocator, "search_test", 128);
    defer vec.deinit();
    try index.addVector(vec);

    const results = try vsa.semanticSearch(&index, "search_test", 10, 0.0, allocator);
    defer {
        for (results.items) |*r| r.deinit();
        results.deinit(allocator);
    }

    // Should find at least one result
    try std.testing.expect(results.items.len >= 1);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 4: End-to-End Semantic Rename (5 cases)
// ═══════════════════════════════════════════════════════════════════════════════

test "e2e.1: Build semantic index from Zig code" {
    const allocator = std.testing.allocator;

    const zig_code = \\
        \\const std = @import("std");
        \\
        \\pub fn add(a: i32, b: i32) i32 {
        \\    return a + b;
        \\}
        \\
        \\pub fn multiply(x: i32, y: i32) i32 {
        \\    return x * y;
        \\}
    ;

    var graph = try zig_parser.ASTGraph.init(allocator);
    defer graph.deinit();

    try graph.addFileFromCode("test.zig", zig_code);

    var index = try vsa.buildSemanticIndex(allocator, &graph, 256);
    defer index.deinit();

    // Should have found at least the functions
    try std.testing.expect(index.vectors.count() >= 2);
}

test "e2e.2: Find similar function patterns" {
    const allocator = std.testing.allocator;

    const zig_code = \\
        \\pub fn processData(data: []u8) void {
        \\    // Process data
        \\}
        \\
        \\pub fn handleRequest(req: []u8) void {
        \\    // Handle request
        \\}
    ;

    var graph = try zig_parser.ASTGraph.init(allocator);
    defer graph.deinit();

    try graph.addFileFromCode("test.zig", zig_code);

    var index = try vsa.buildSemanticIndex(allocator, &graph, 128);
    defer index.deinit();

    // Search for similar patterns
    const results = try vsa.semanticSearch(&index, "processData", 5, 0.0, allocator);
    defer {
        for (results.items) |*r| r.deinit();
        results.deinit(allocator);
    }

    try std.testing.expect(results.items.len >= 1);
}

test "e2e.3: Semantic search for struct definitions" {
    const allocator = std.testing.allocator;

    const zig_code = \\
        \\pub const Config = struct {
        \\    enabled: bool,
        \\    timeout: u32,
        \\};
        \\
        \\pub const Settings = struct {
        \\    debug: bool,
        \\    verbose: bool,
        \\};
    ;

    var graph = try zig_parser.ASTGraph.init(allocator);
    defer graph.deinit();

    try graph.addFileFromCode("test.zig", zig_code);

    var index = try vsa.buildSemanticIndex(allocator, &graph, 128);
    defer index.deinit();

    // Find Config
    const results = try vsa.semanticSearch(&index, "Config", 5, 0.0, allocator);
    defer {
        for (results.items) |*r| r.deinit();
        results.deinit(allocator);
    }

    // Should find Config
    const found_config = for (results.items) |r| {
        if (std.mem.eql(u8, r.symbol_id, "Config")) break true;
    } else false;

    try std.testing.expect(found_config);
}

test "e2e.4: Multi-file semantic index" {
    const allocator = std.testing.allocator;

    const code1 = "pub fn helper() void {}";
    const code2 = "pub fn utility() void {}";

    var graph = try zig_parser.ASTGraph.init(allocator);
    defer graph.deinit();

    try graph.addFileFromCode("file1.zig", code1);
    try graph.addFileFromCode("file2.zig", code2);

    var index = try vsa.buildSemanticIndex(allocator, &graph, 128);
    defer index.deinit();

    // Should have symbols from both files
    try std.testing.expect(index.vectors.count() >= 2);
}

test "e2e.5: Semantic find with context" {
    const allocator = std.testing.allocator;

    const zig_code = \\
        \\pub fn calculateSum(a: i32, b: i32) i32 {
        \\    return a + b;
        \\}
        \\
        \\pub fn calculateProduct(a: i32, b: i32) i32 {
        \\    return a * b;
        \\}
    ;

    var graph = try zig_parser.ASTGraph.init(allocator);
    defer graph.deinit();

    try graph.addFileFromCode("math.zig", zig_code);

    var index = try vsa.buildSemanticIndex(allocator, &graph, 128);
    defer index.deinit();

    // Search for "calculate" - should find both functions
    const results = try vsa.semanticSearch(&index, "calculate", 10, 0.0, allocator);
    defer {
        for (results.items) |*r| r.deinit();
        results.deinit(allocator);
    }

    // Both functions have "calculate" in their names
    try std.testing.expect(results.items.len >= 2);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Summary: 23 tests total
// - 10 VSA basic operations
// - 5 embedding roundtrip
// - 8 semantic similarity
// - 5 end-to-end
// ═══════════════════════════════════════════════════════════════════════════════
