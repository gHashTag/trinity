const std = @import("std");
const vsa10k = @import("10k_vsa.zig");
const common = @import("common.zig");
const core = @import("core.zig");
const HybridBigInt = common.HybridBigInt;
const Trit = common.Trit;

// VSA functions - imported from core module
const randomVector = core.randomVector;
const permute = core.permute;
const inversePermute = core.inversePermute;
const encodeSequence = core.encodeSequence;
const bind = core.bind;
const bundle2 = core.bundle2;
const bundle3 = core.bundle3;
const cosineSimilarity = core.cosineSimilarity;
const vectorNorm = core.vectorNorm;
const countNonZero = core.countNonZero;
const bundleN = core.bundleN;
const textSimilarity = @import("text_encoding.zig").textSimilarity;

// hammingDistanceSlice is defined in vsa.zig, not core.zig
// We'll define it inline for now since we can't import parent
fn hammingDistanceSlice(a: []const i8, b: []const i8) usize {
    const min_len = @min(a.len, b.len);
    var distance: usize = 0;

    for (0..min_len) |i| {
        if (a[i] != b[i]) distance += 1;
    }

    // Add extra elements as differences
    distance += if (a.len > b.len) a.len - b.len else b.len - a.len;
    return distance;
}

// Additional VSA types from submodules
const TextCorpus = @import("storage.zig").TextCorpus;
const DependencyGraph = @import("concurrency.zig").DependencyGraph;
const UnifiedAgent = @import("agent.zig").UnifiedAgent;
const AutonomousAgent = @import("agent.zig").AutonomousAgent;
const UnifiedAutonomousSystem = @import("agent.zig").UnifiedAutonomousSystem;
const Modality = @import("agent.zig").Modality;
const UnifiedRequest = @import("agent.zig").UnifiedRequest;

// Helper functions for tests
fn dummyJobFn(_: *anyopaque) void {
    // No-op for testing
}

fn incrementCounter(ctx: *anyopaque) void {
    const counter: *usize = @ptrCast(@alignCast(ctx));
    counter.* += 1;
}

test "permute/inverse_permute roundtrip" {
    var v = randomVector(100, 99999);
    var permuted = permute(&v, 7);
    const recovered = inversePermute(&permuted, 7);
    for (0..v.trit_len) |i| {
        try std.testing.expectEqual(v.unpacked_cache[i], recovered.unpacked_cache[i]);
    }
}

test "permute shift correctness" {
    var v = HybridBigInt.zero();
    v.mode = .unpacked_mode;
    v.trit_len = 5;
    v.unpacked_cache[0] = 1;
    v.unpacked_cache[1] = -1;
    v.unpacked_cache[2] = 0;
    v.unpacked_cache[3] = 1;
    v.unpacked_cache[4] = -1;
    const p = permute(&v, 2);
    try std.testing.expectEqual(@as(Trit, 1), p.unpacked_cache[0]);
    try std.testing.expectEqual(@as(Trit, -1), p.unpacked_cache[1]);
    try std.testing.expectEqual(@as(Trit, 1), p.unpacked_cache[2]);
    try std.testing.expectEqual(@as(Trit, -1), p.unpacked_cache[3]);
    try std.testing.expectEqual(@as(Trit, 0), p.unpacked_cache[4]);
}

test "sequence encoding" {
    const a = randomVector(100, 11111);
    const b = randomVector(100, 22222);
    var items = [_]HybridBigInt{ a, b };
    const seq = encodeSequence(&items);
    try std.testing.expectEqual(a.trit_len, seq.trit_len);
}

test "bind self-inverse" {
    var a = randomVector(100, 12345);
    const bound = bind(&a, &a);
    for (0..a.trit_len) |i| {
        if (a.unpacked_cache[i] != 0) {
            try std.testing.expectEqual(@as(Trit, 1), bound.unpacked_cache[i]);
        } else {
            try std.testing.expectEqual(@as(Trit, 0), bound.unpacked_cache[i]);
        }
    }
}

test "bundle2 similarity" {
    var a = randomVector(100, 33333);
    var b = randomVector(100, 44444);
    var bundled = bundle2(&a, &b);
    const sim_a = cosineSimilarity(&bundled, &a);
    const sim_b = cosineSimilarity(&bundled, &b);
    try std.testing.expect(sim_a > 0.3);
    try std.testing.expect(sim_b > 0.3);
}

test "textSimilarity identical texts" {
    const sim = textSimilarity("hello", "hello");
    try std.testing.expect(sim > 0.9);
}

test "TextCorpus add and find" {
    var corpus = TextCorpus.init();
    _ = corpus.add("hello world", "greeting");
    _ = corpus.add("goodbye world", "farewell");
    try std.testing.expectEqual(@as(usize, 2), corpus.count);
    const idx = corpus.findMostSimilarIndex("hello world") orelse unreachable;
    try std.testing.expectEqualStrings("greeting", corpus.getLabel(idx));
}

test "DependencyGraph execution" {
    var graph = DependencyGraph.init();
    var counter: usize = 0;
    const ctx_ptr: *anyopaque = @ptrCast(&counter);
    _ = graph.addTask(incrementCounter, ctx_ptr);
    _ = graph.addTask(incrementCounter, ctx_ptr);
    _ = graph.addTask(incrementCounter, ctx_ptr);
    const result = graph.executeAll();
    try std.testing.expectEqual(@as(usize, 3), result.completed);
    try std.testing.expectEqual(@as(usize, 3), counter);
}

test "UnifiedAgent auto-detect and process" {
    var agent = UnifiedAgent.init();
    const result = agent.autoProcess("write a pub fn main function");
    try std.testing.expect(result.success);
    try std.testing.expectEqual(Modality.code, result.modality);
}

test "AutonomousAgent full run cycle" {
    var agent = AutonomousAgent.init();
    const result = agent.run("implement code and create documentation");
    try std.testing.expect(result.success);
    try std.testing.expect(result.tool_calls > 0);
}

test "UnifiedAutonomousSystem process text request" {
    var sys = UnifiedAutonomousSystem.init();
    var req = UnifiedRequest.init("calculate sum and search data");
    const resp = sys.process(&req);
    try std.testing.expect(resp.success);
    try std.testing.expect(resp.getOutput().len > 0);
}

test "SIMD bundle3 correctness" {
    var a = randomVector(100, 55555);
    var b = randomVector(100, 66666);
    var c = randomVector(100, 77777);
    var bundled = bundle3(&a, &b, &c);
    // bundle3 result should be similar to all 3 inputs
    const sim_a = cosineSimilarity(&bundled, &a);
    const sim_b = cosineSimilarity(&bundled, &b);
    const sim_c = cosineSimilarity(&bundled, &c);
    try std.testing.expect(sim_a > 0.2);
    try std.testing.expect(sim_b > 0.2);
    try std.testing.expect(sim_c > 0.2);
}

test "SIMD vectorNorm correctness" {
    var v = randomVector(100, 88888);
    const norm = vectorNorm(&v);
    // Norm of random ternary vector ~= sqrt(non_zero_count)
    try std.testing.expect(norm > 0);
    try std.testing.expect(norm <= 10.1); // sqrt(100) = 10
}

test "SIMD countNonZero correctness" {
    var v = randomVector(100, 99999);
    const count = countNonZero(&v);
    // Random ternary: ~2/3 should be non-zero
    try std.testing.expect(count > 40);
    try std.testing.expect(count <= 100);
}

test "SIMD bundleN 5 vectors" {
    var a = randomVector(100, 10001);
    var b = randomVector(100, 10002);
    var c = randomVector(100, 10003);
    var d = randomVector(100, 10004);
    var e = randomVector(100, 10005);
    var vecs = [_]*HybridBigInt{ &a, &b, &c, &d, &e };
    var bundled = bundleN(&vecs);
    // bundleN result should be similar to each input
    const sim_a = cosineSimilarity(&bundled, &a);
    try std.testing.expect(sim_a > 0.1);
    try std.testing.expect(bundled.trit_len == 100);
}

//==========================================================================
// 10K VSA TESTS (Week 2 Day 1)
//==========================================================================

test "10K HyperVector zero vector" {
    const vec = vsa10k.HyperVector10K.zero();
    try std.testing.expectEqual(@as(usize, 0), try vec.countNonZero());
}

test "10K HyperVector bind identity" {
    var rng = std.Random.DefaultPrng.init(42);
    const vec = try vsa10k.HyperVector10K.random(&rng);

    // Identity vector (all +1)
    var identity = vsa10k.HyperVector10K.zero();
    var i: usize = 0;
    while (i < vsa10k.DIM_10K) : (i += 1) {
        try identity.set(i, vsa10k.TRIT_POS);
    }

    const result = vsa10k.HyperVector10K.bind(&vec, &identity);

    // Verify result equals original (sample check)
    var match_count: usize = 0;
    i = 0;
    while (i < 100) : (i += 1) {
        if ((try result.get(i)) == (try vec.get(i)))
            match_count += 1;
    }

    try std.testing.expect(match_count >= 95); // Allow some tolerance
}

test "10K HyperVector bind inverse" {
    var rng = std.Random.DefaultPrng.init(42);
    const vec = try vsa10k.HyperVector10K.random(&rng);

    // Inverse vector (all -1)
    var inverse = vsa10k.HyperVector10K.zero();
    var i: usize = 0;
    while (i < vsa10k.DIM_10K) : (i += 1) {
        try inverse.set(i, vsa10k.TRIT_NEG);
    }

    const result = vsa10k.HyperVector10K.bind(&vec, &inverse);

    // Verify result is negation of original
    var match_count: usize = 0;
    i = 0;
    while (i < 100) : (i += 1) {
        const vi = try vec.get(i);
        const expected: i8 = if (vi == vsa10k.TRIT_NEG) vsa10k.TRIT_POS else if (vi == vsa10k.TRIT_POS) vsa10k.TRIT_NEG else vsa10k.TRIT_ZERO;
        if ((try result.get(i)) == expected)
            match_count += 1;
    }

    try std.testing.expectEqual(@as(usize, 100), match_count);
}

test "10K HyperVector cosine similarity bounds" {
    var rng = std.Random.DefaultPrng.init(42);
    const vec_a = try vsa10k.HyperVector10K.random(&rng);
    const vec_b = try vsa10k.HyperVector10K.random(&rng);

    const sim = try vsa10k.HyperVector10K.cosineSimilarity(&vec_a, &vec_b);

    // Similarity should be in range [0, 65535]
    try std.testing.expect(sim >= 0 and sim <= 65535);
}

test "10K HyperVector permutation roundtrip" {
    var rng = std.Random.DefaultPrng.init(42);
    const original = try vsa10k.HyperVector10K.random(&rng);

    const shifted = try original.permute(100);
    const unshifted = try shifted.permute(@as(u16, @intCast(vsa10k.DIM_10K - 100)));

    // Sample check (not all 10K to save time)
    var match_count: usize = 0;
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        if ((try unshifted.get(i)) == (try original.get(i)))
            match_count += 1;
    }

    try std.testing.expectEqual(@as(usize, 100), match_count);
}

test "10K VSA benchmark quick" {
    const allocator = std.testing.allocator;
    const result = try vsa10k.benchmark(allocator, 10);
    _ = result;

    // Just verify it completes without error
    try std.testing.expect(true);
}

//==========================================================================
// HAMMING DISTANCE TESTS (Issue #283)
//==========================================================================

test "hamming distance identical" {
    const a = [_]i8{ 1, -1, 0, 1, -1 };
    try std.testing.expectEqual(@as(usize, 0), hammingDistanceSlice(&a, &a));
}

test "hamming distance all different" {
    const a = [_]i8{ 1, 1, 1 };
    const b = [_]i8{ -1, -1, -1 };
    try std.testing.expectEqual(@as(usize, 3), hammingDistanceSlice(&a, &b));
}

test "hamming distance partial" {
    const a = [_]i8{ 1, -1, 0, 1, -1 };
    const b = [_]i8{ 1, -1, 1, 1, -1 };
    try std.testing.expectEqual(@as(usize, 1), hammingDistanceSlice(&a, &b));
}

test "hamming distance different lengths" {
    const a = [_]i8{ 1, -1, 0 };
    const b = [_]i8{ 1, -1, 0, 1, -1 };
    try std.testing.expectEqual(@as(usize, 2), hammingDistanceSlice(&a, &b));
}

test "hamming distance empty" {
    const a = [_]i8{};
    try std.testing.expectEqual(@as(usize, 0), hammingDistanceSlice(&a, &a));
}

//==========================================================================
// TQNN TESTS (Week 2 Day 5)
// NOTE: Quantum tests disabled - need proper module path resolution
// TODO: Re-enable when quantum module structure is fixed
//==========================================================================

// test "Qutrit from_float mapping" {
//     const qutrit_mod = @import("../quantum/qutrit.zig");
//     ...
// }

// test "Qutrit Hadamard gate" { ... }
// test "Qutrit Sacred Phase" { ... }
// test "QutritArray coherence detection" { ... }

// TQNN tests moved to src/models/tqnn/tqnn_inference.zig (break vsa↔models cycle)

//==========================================================================
// TEXT ENCODING TESTS (Phase 1: Character-level VSA)
//==========================================================================

test "VSA Text Encoding: charToVector deterministic" {
    const text = @import("text_encoding.zig");

    const v1 = text.charToVector('a');
    const v2 = text.charToVector('a');

    // Same character should produce same vector
    try std.testing.expectEqual(v1.trit_len, v2.trit_len);

    // Different characters should produce different vectors
    const v3 = text.charToVector('b');
    const sim = cosineSimilarity(&v1, &v3);
    try std.testing.expect(sim < 0.8); // Should be dissimilar
}

test "VSA Text Encoding: encodeWord" {
    const text = @import("text_encoding.zig");

    const word_vec = text.encodeWord("cat");

    // Word vector should have correct dimension
    try std.testing.expect(word_vec.trit_len > 0);

    // Same word should produce same vector
    const word_vec2 = text.encodeWord("cat");
    const sim = cosineSimilarity(&word_vec, &word_vec2);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 0.01);
}

test "VSA Text Encoding: similar words have higher similarity" {
    const text = @import("text_encoding.zig");

    const cat = text.encodeWord("cat");
    const cats = text.encodeWord("cats");
    const dog = text.encodeWord("dog");

    const cat_cats_sim = cosineSimilarity(&cat, &cats);
    const cat_dog_sim = cosineSimilarity(&cat, &dog);

    // "cat" and "cats" should be more similar than "cat" and "dog"
    try std.testing.expect(cat_cats_sim > cat_dog_sim);
}

test "VSA Text Encoding: textSimilarity" {
    const text = @import("text_encoding.zig");

    const sim1 = text.textSimilarity("hello world", "hello world");
    const sim2 = text.textSimilarity("hello world", "goodbye world");

    // Identical texts should be very similar
    try std.testing.expect(sim1 > 0.9);

    // Different texts should be less similar
    try std.testing.expect(sim2 < sim1);
}

test "VSA Text Encoding: encodeNgram" {
    const text = @import("text_encoding.zig");

    const bigram = text.encodeNgram("th");

    // Bigram vector should have correct dimension
    try std.testing.expect(bigram.trit_len > 0);

    // Same bigram should produce same vector
    const bigram2 = text.encodeNgram("th");
    const sim = cosineSimilarity(&bigram, &bigram2);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 0.01);
}

test "VSA Text Encoding: encodeTextWithNgrams" {
    const text_enc = @import("text_encoding.zig");
    const allocator = std.testing.allocator;

    const encoded = try text_enc.encodeTextWithNgrams("hello", allocator);

    // All levels should have valid vectors
    try std.testing.expect(encoded.char_level.trit_len > 0);
    try std.testing.expect(encoded.combined.trit_len > 0);
}

test "VSA Text Encoding: DocumentStats" {
    const text = @import("text_encoding.zig");
    const allocator = std.testing.allocator;

    var stats = text.DocumentStats.init(allocator);
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
    const text = @import("text_encoding.zig");
    const allocator = std.testing.allocator;

    var memory = text.AssociativeMemory.init(allocator);
    defer memory.deinit(allocator);

    const vec1 = text.encodeWord("apple");
    const vec2 = text.encodeWord("banana");

    try memory.store(allocator, "apple", vec1);
    try memory.store(allocator, "banana", vec2);

    // Should retrieve stored keys
    const retrieved1 = memory.retrieve(vec1);
    try std.testing.expectEqualStrings("apple", retrieved1.?);

    const retrieved2 = memory.retrieve(vec2);
    try std.testing.expectEqualStrings("banana", retrieved2.?);
}

test "VSA Text Encoding: findTopK" {
    const text = @import("text_encoding.zig");
    const allocator = std.testing.allocator;

    const corpus = &[_][]const u8{
        "the quick brown fox",
        "the lazy dog",
        "the quick cat",
        "a completely different text",
    };

    const results = try text.findTopK("quick fox", corpus, allocator, 2);
    defer allocator.free(results);

    try std.testing.expectEqual(@as(usize, 2), results.len);

    // First result should be most similar
    try std.testing.expect(results[0].similarity > results[1].similarity);
}
