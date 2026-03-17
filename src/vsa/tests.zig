const std = @import("std");
const vsa = @import("../vsa.zig");
const vsa10k = @import("10k_vsa.zig");
const HybridBigInt = vsa.HybridBigInt;
const Trit = vsa.Trit;
const TextCorpus = vsa.TextCorpus;

// Helper functions for tests
fn dummyJobFn(_: *anyopaque) void {
    // No-op for testing
}

fn incrementCounter(ctx: *anyopaque) void {
    const counter: *usize = @ptrCast(@alignCast(ctx));
    counter.* += 1;
}

test "permute/inverse_permute roundtrip" {
    var v = vsa.randomVector(100, 99999);
    var permuted = vsa.permute(&v, 7);
    const recovered = vsa.inversePermute(&permuted, 7);
    for (0..v.trit_len) |i| {
        try std.testing.expectEqual(v.unpacked_cache[i], recovered.unpacked_cache[i]);
    }
}

test "permute shift correctness" {
    var v = vsa.HybridBigInt.zero();
    v.mode = .unpacked_mode;
    v.trit_len = 5;
    v.unpacked_cache[0] = 1;
    v.unpacked_cache[1] = -1;
    v.unpacked_cache[2] = 0;
    v.unpacked_cache[3] = 1;
    v.unpacked_cache[4] = -1;
    const p = vsa.permute(&v, 2);
    try std.testing.expectEqual(@as(Trit, 1), p.unpacked_cache[0]);
    try std.testing.expectEqual(@as(Trit, -1), p.unpacked_cache[1]);
    try std.testing.expectEqual(@as(Trit, 1), p.unpacked_cache[2]);
    try std.testing.expectEqual(@as(Trit, -1), p.unpacked_cache[3]);
    try std.testing.expectEqual(@as(Trit, 0), p.unpacked_cache[4]);
}

test "sequence encoding" {
    const a = vsa.randomVector(100, 11111);
    const b = vsa.randomVector(100, 22222);
    var items = [_]HybridBigInt{ a, b };
    const seq = vsa.encodeSequence(&items);
    try std.testing.expectEqual(a.trit_len, seq.trit_len);
}

test "bind self-inverse" {
    var a = vsa.randomVector(100, 12345);
    const bound = vsa.bind(&a, &a);
    for (0..a.trit_len) |i| {
        if (a.unpacked_cache[i] != 0) {
            try std.testing.expectEqual(@as(Trit, 1), bound.unpacked_cache[i]);
        } else {
            try std.testing.expectEqual(@as(Trit, 0), bound.unpacked_cache[i]);
        }
    }
}

test "bundle2 similarity" {
    var a = vsa.randomVector(100, 33333);
    var b = vsa.randomVector(100, 44444);
    var bundled = vsa.bundle2(&a, &b);
    const sim_a = vsa.cosineSimilarity(&bundled, &a);
    const sim_b = vsa.cosineSimilarity(&bundled, &b);
    try std.testing.expect(sim_a > 0.3);
    try std.testing.expect(sim_b > 0.3);
}

test "textSimilarity identical texts" {
    const sim = vsa.textSimilarity("hello", "hello");
    try std.testing.expect(sim > 0.9);
}

test "TextCorpus add and find" {
    var corpus = vsa.TextCorpus.init();
    _ = corpus.add("hello world", "greeting");
    _ = corpus.add("goodbye world", "farewell");
    try std.testing.expectEqual(@as(usize, 2), corpus.count);
    const idx = corpus.findMostSimilarIndex("hello world") orelse unreachable;
    try std.testing.expectEqualStrings("greeting", corpus.getLabel(idx));
}

test "DependencyGraph execution" {
    var graph = vsa.DependencyGraph.init();
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
    var agent = vsa.UnifiedAgent.init();
    const result = agent.autoProcess("write a pub fn main function");
    try std.testing.expect(result.success);
    try std.testing.expectEqual(vsa.Modality.code, result.modality);
}

test "AutonomousAgent full run cycle" {
    var agent = vsa.AutonomousAgent.init();
    const result = agent.run("implement code and create documentation");
    try std.testing.expect(result.success);
    try std.testing.expect(result.tool_calls > 0);
}

test "UnifiedAutonomousSystem process text request" {
    var sys = vsa.UnifiedAutonomousSystem.init();
    var req = vsa.UnifiedRequest.init("calculate sum and search data");
    const resp = sys.process(&req);
    try std.testing.expect(resp.success);
    try std.testing.expect(resp.getOutput().len > 0);
}

test "SIMD bundle3 correctness" {
    var a = vsa.randomVector(100, 55555);
    var b = vsa.randomVector(100, 66666);
    var c = vsa.randomVector(100, 77777);
    var bundled = vsa.bundle3(&a, &b, &c);
    // bundle3 result should be similar to all 3 inputs
    const sim_a = vsa.cosineSimilarity(&bundled, &a);
    const sim_b = vsa.cosineSimilarity(&bundled, &b);
    const sim_c = vsa.cosineSimilarity(&bundled, &c);
    try std.testing.expect(sim_a > 0.2);
    try std.testing.expect(sim_b > 0.2);
    try std.testing.expect(sim_c > 0.2);
}

test "SIMD vectorNorm correctness" {
    var v = vsa.randomVector(100, 88888);
    const norm = vsa.vectorNorm(&v);
    // Norm of random ternary vector ~= sqrt(non_zero_count)
    try std.testing.expect(norm > 0);
    try std.testing.expect(norm <= 10.1); // sqrt(100) = 10
}

test "SIMD countNonZero correctness" {
    var v = vsa.randomVector(100, 99999);
    const count = vsa.countNonZero(&v);
    // Random ternary: ~2/3 should be non-zero
    try std.testing.expect(count > 40);
    try std.testing.expect(count <= 100);
}

test "SIMD bundleN 5 vectors" {
    var a = vsa.randomVector(100, 10001);
    var b = vsa.randomVector(100, 10002);
    var c = vsa.randomVector(100, 10003);
    var d = vsa.randomVector(100, 10004);
    var e = vsa.randomVector(100, 10005);
    var vecs = [_]*HybridBigInt{ &a, &b, &c, &d, &e };
    var bundled = vsa.bundleN(&vecs);
    // bundleN result should be similar to each input
    const sim_a = vsa.cosineSimilarity(&bundled, &a);
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
    try std.testing.expectEqual(@as(usize, 0), vsa.hammingDistanceSlice(&a, &a));
}

test "hamming distance all different" {
    const a = [_]i8{ 1, 1, 1 };
    const b = [_]i8{ -1, -1, -1 };
    try std.testing.expectEqual(@as(usize, 3), vsa.hammingDistanceSlice(&a, &b));
}

test "hamming distance partial" {
    const a = [_]i8{ 1, -1, 0, 1, -1 };
    const b = [_]i8{ 1, -1, 1, 1, -1 };
    try std.testing.expectEqual(@as(usize, 1), vsa.hammingDistanceSlice(&a, &b));
}

test "hamming distance different lengths" {
    const a = [_]i8{ 1, -1, 0 };
    const b = [_]i8{ 1, -1, 0, 1, -1 };
    try std.testing.expectEqual(@as(usize, 2), vsa.hammingDistanceSlice(&a, &b));
}

test "hamming distance empty" {
    const a = [_]i8{};
    try std.testing.expectEqual(@as(usize, 0), vsa.hammingDistanceSlice(&a, &a));
}

//==========================================================================
// TQNN TESTS (Week 2 Day 5)
//==========================================================================

test "Qutrit from_float mapping" {
    const qutrit_mod = @import("../quantum/qutrit.zig");

    const q_neg = qutrit_mod.Qutrit.from_float(-1.0);
    try std.testing.expectEqual(qutrit_mod.TRIT_NEG, q_neg.value);

    const q_zero = qutrit_mod.Qutrit.from_float(0.0);
    try std.testing.expectEqual(qutrit_mod.TRIT_ZERO, q_zero.value);

    const q_pos = qutrit_mod.Qutrit.from_float(1.0);
    try std.testing.expectEqual(qutrit_mod.TRIT_POS, q_pos.value);
}

test "Qutrit Hadamard gate" {
    const qutrit_mod = @import("../quantum/qutrit.zig");

    var q = qutrit_mod.Qutrit.from_trit(qutrit_mod.TRIT_NEG);
    q.hadamard();
    try std.testing.expectEqual(qutrit_mod.TRIT_POS, q.value);

    q = qutrit_mod.Qutrit.from_trit(qutrit_mod.TRIT_ZERO);
    q.hadamard();
    try std.testing.expectEqual(qutrit_mod.TRIT_NEG, q.value);

    q = qutrit_mod.Qutrit.from_trit(qutrit_mod.TRIT_POS);
    q.hadamard();
    try std.testing.expectEqual(qutrit_mod.TRIT_ZERO, q.value);
}

test "Qutrit Sacred Phase" {
    const qutrit_mod = @import("../quantum/qutrit.zig");

    var q = qutrit_mod.Qutrit.from_trit(qutrit_mod.TRIT_POS);
    const old_phase = q.phase;
    q.sacred_phase();
    try std.testing.expect(q.phase != old_phase);
}

test "QutritArray coherence detection" {
    const qutrit_mod = @import("../quantum/qutrit.zig");

    // Balanced distribution should be coherent
    var pos_trits: [16]qutrit_mod.Trit = undefined;
    for (0..8) |i| pos_trits[i] = qutrit_mod.TRIT_POS;
    for (8..16) |i| pos_trits[i] = qutrit_mod.TRIT_NEG;
    var qa_balanced = qutrit_mod.QutritArray(16).from_trits(pos_trits);
    try std.testing.expect(qa_balanced.coherence());

    // Unbalanced should not be coherent
    const zero_trits = [_]qutrit_mod.Trit{qutrit_mod.TRIT_ZERO} ** 16;
    var qa_unbalanced = qutrit_mod.QutritArray(16).from_trits(zero_trits);
    try std.testing.expect(!qa_unbalanced.coherence());
}

// TQNN tests moved to src/models/tqnn/tqnn_inference.zig (break vsa↔models cycle)
