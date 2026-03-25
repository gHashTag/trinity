// VSA Core — Operations Verification Tests (TTT Dogfood v0.1)
// Tests to verify generated code matches manual implementation
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const common = @import("common.zig");
const Trit = common.Trit;
const build_options = @import("build_options");

// Import all ops for testing
const ops = @import("ops.zig");

test "vsa ops: build succeeds" {
    // Test that both manual and self-hosted modes compile
    _ = ops.cosineSimilarity;
    _ = ops.hammingDistance;
    _ = ops.hammingSimilarity;
    _ = ops.dotSimilarity;
    _ = ops.vectorNorm;
    _ = ops.countNonZero;
}

test "vsa ops: cosineSimilarity pure" {
    const a = [_]Trit{ 1, 1, 1, 1 };
    const b = [_]Trit{ 1, 1, 1, 1 };

    const result = ops.cosineSimilarity(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), result, 0.001);
}

test "vsa ops: hammingDistance pure" {
    const a = [_]Trit{ 1, -1, 0, 1, 0 };
    const b = [_]Trit{ 1, 1, -1, 1, 1 };

    const result = ops.hammingDistance(&a, &b);
    try std.testing.expectEqual(@as(usize, 3), result);
}

test "vsa ops: hammingSimilarity pure" {
    const a = [_]Trit{ 1, 1, 1, 1 };
    const b = [_]Trit{ 1, 1, 1, 1 };

    const result = ops.hammingSimilarity(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), result, 0.001);
}

test "vsa ops: dotSimilarity pure" {
    const a = [_]Trit{ 1, 1, 1, 1 };
    const b = [_]Trit{ 1, 1, 1, 1 };

    const result = ops.dotSimilarity(&a, &b);
    try std.testing.expectEqual(@as(i64, 4), result);
}

test "vsa ops: vectorNorm pure" {
    const v = [_]Trit{ 1, 1, 1, 1 };

    const result = ops.vectorNorm(&v);
    try std.testing.expectApproxEqAbs(@as(f64, 2.0), result, 0.001);
}

test "vsa ops: countNonZero pure" {
    const v = [_]Trit{ 1, 0, -1, 0, 1, 0, 0, -1 };
    const result = ops.countNonZero(&v);
    try std.testing.expectEqual(@as(usize, 4), result);
}

test "vsa ops: bind allocates correctly" {
    const a = [_]Trit{ 1, -1, 0, 1 };
    const b = [_]Trit{ 1, 1, -1, 0 };

    const result = try ops.bind(std.testing.allocator, &a, &b);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqual(@as(usize, 4), result.len);
    try std.testing.expectEqual(@as(Trit, 1), result[0]);
    try std.testing.expectEqual(@as(Trit, -1), result[1]);
    try std.testing.expectEqual(@as(Trit, 0), result[2]);
    try std.testing.expectEqual(@as(Trit, 0), result[3]);
}

test "vsa ops: bundle2 majority vote" {
    const a = [_]Trit{ 1, 1, -1, -1 };
    const b = [_]Trit{ 1, -1, 1, -1 };

    const result = try ops.bundle2(std.testing.allocator, &a, &b);
    defer std.testing.allocator.free(result);

    // [2, 0, 0, -2] → [1, 0, 0, -1]
    try std.testing.expectEqualSlices(Trit, &[_]Trit{ 1, 0, 0, -1 }, result);
}

test "vsa ops: bundle3 majority vote" {
    const a = [_]Trit{ 1, 1, -1, -1 };
    const b = [_]Trit{ 1, -1, 1, -1 };
    const c = [_]Trit{ -1, -1, -1, 1 };

    const result = try ops.bundle3(std.testing.allocator, &a, &b, &c);
    defer std.testing.allocator.free(result);

    // [1, -1, -1, -1] → [1, -1, -1, -1]
    try std.testing.expectEqualSlices(Trit, &[_]Trit{ 1, -1, -1, -1 }, result);
}

test "vsa ops: bundleN handles 4 vectors" {
    const vectors = &[_][]const Trit{
        &[_]Trit{ 1, 1 },
        &[_]Trit{ 1, -1 },
        &[_]Trit{ -1, 1 },
        &[_]Trit{ -1, -1 },
    };

    const result = try ops.bundleN(std.testing.allocator, vectors);
    defer std.testing.allocator.free(result);

    // [0, 0] → tie, defaults to 0
    try std.testing.expectEqualSlices(Trit, &[_]Trit{ 0, 0 }, result);
}

test "vsa ops: permute rotate left" {
    const v = [_]Trit{ 1, 2, 3, 4, 5 };

    const result = try ops.permute(std.testing.allocator, &v, 2);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualSlices(Trit, &[_]Trit{ 3, 4, 5, 1, 2 }, result);
}

test "vsa ops: permute zero rotation" {
    const v = [_]Trit{ 1, 2, 3, 4, 5 };

    const result = try ops.permute(std.testing.allocator, &v, 0);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualSlices(Trit, &[_]Trit{ 1, 2, 3, 4, 5 }, result);
}

test "vsa ops: inversePermute is inverse of permute" {
    const v = [_]Trit{ 1, 2, 3, 4, 5 };

    const permuted = try ops.permute(std.testing.allocator, &v, 2);
    defer std.testing.allocator.free(permuted);

    const result = try ops.inversePermute(std.testing.allocator, permuted, 2);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualSlices(Trit, &v, result);
}

test "vsa ops: randomVector deterministic" {
    const seed: u64 = 12345;

    const v1 = try ops.randomVector(std.testing.allocator, 100, seed);
    defer std.testing.allocator.free(v1);

    const v2 = try ops.randomVector(std.testing.allocator, 100, seed);
    defer std.testing.allocator.free(v2);

    try std.testing.expectEqualSlices(Trit, v1, v2);
}

test "vsa ops: encodeSequence encodes correctly" {
    const vectors = &[_][]const Trit{
        &[_]Trit{ 1, 0, -1 },
        &[_]Trit{ 0, 1, 1 },
        &[_]Trit{ -1, -1, 0 },
    };

    const result = try ops.encodeSequence(std.testing.allocator, vectors);
    defer std.testing.allocator.free(result);

    // Just verify it runs without error and produces output
    try std.testing.expectEqual(@as(usize, 3), result.len);
}

test "vsa ops: encodeSequence errors on empty" {
    const vectors = &[_][]const Trit{};

    const result = ops.encodeSequence(std.testing.allocator, vectors);
    try std.testing.expectError(error.EmptySequence, result);
}

test "vsa ops: probeSequence finds best match" {
    const encoded = &[_]Trit{ 1, 0, -1 };

    // Each query is a sequence (list of vectors) - using single-element sequences
    const query_sequences = &[_][]const []const Trit{
        &[_][]const Trit{&[_]Trit{ 1, 1, 1 }}, // Different
        &[_][]const Trit{&[_]Trit{ 1, 0, -1 }}, // Match!
        &[_][]const Trit{&[_]Trit{ -1, 0, 1 }}, // Different
    };

    const best_idx = try ops.probeSequence(std.testing.allocator, encoded, query_sequences);

    // Should return index 1 (the matching vector)
    try std.testing.expectEqual(@as(usize, 1), best_idx);
}

test "vsa ops: unbind is inverse of bind" {
    // Key must not contain 0 for true inverse (0 * anything = 0 loses information)
    const key = &[_]Trit{ 1, -1, 1 };
    const value = &[_]Trit{ 1, 1, -1 };

    const bound = try ops.bind(std.testing.allocator, key, value);
    defer std.testing.allocator.free(bound);

    const unbound = try ops.unbind(std.testing.allocator, bound, key);
    defer std.testing.allocator.free(unbound);

    try std.testing.expectEqualSlices(Trit, value, unbound);
}

test "vsa ops: empty vector handling" {
    const empty = [_]Trit{};

    // permute empty vector
    const result = try ops.permute(std.testing.allocator, &empty, 5);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "vsa ops: unequal length vectors" {
    const a = [_]Trit{ 1, 1, 1 };
    const b = [_]Trit{ 1, -1, 0, 1, 0 };

    // bind should work with unequal lengths
    const result = try ops.bind(std.testing.allocator, &a, &b);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqual(@as(usize, 5), result.len);
}

test "vsa ops: similarity metrics are consistent" {
    const a = [_]Trit{ 1, 1, 1, 1 };
    const b = [_]Trit{ 1, 1, 1, 1 };

    const cos_sim = ops.cosineSimilarity(&a, &b);
    const ham_sim = ops.hammingSimilarity(&a, &b);
    const dot_sim = ops.dotSimilarity(&a, &b);

    // For identical vectors, all similarities should be max
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), cos_sim, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), ham_sim, 0.001);
    try std.testing.expect(dot_sim > 0);
}

// Self-hosted mode verification tests (only run in self-hosted mode)
test "vsa ops: self-hosted mode works" {
    // TODO: Enable after codegen is implemented
    // In self-hosted mode, just verify that operations work
    // The codegen produces the same implementation as manual
    return error.SkipZigTest;
}
