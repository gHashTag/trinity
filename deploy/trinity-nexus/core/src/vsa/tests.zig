const std = @import("std");
const vsa = @import("../vsa.zig");
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
