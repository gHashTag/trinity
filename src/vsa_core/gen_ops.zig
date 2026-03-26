// ═══════════════════════════════════════════════════════════════════════════════
// VSA Core — Operations (GENERATED from .tri spec)
// Stage 0.5: Template-based codegen
// DO NOT EDIT — Generated from specs/vsa/ops.tri
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const common = @import("common.zig");
const Allocator = std.mem.Allocator;
const Trit = common.Trit;
const Vec32i8 = common.Vec32i8;
const Vec32i16 = common.Vec32i16;
const SIMD_WIDTH = common.SIMD_WIDTH;

pub fn bind(allocator: std.mem.Allocator, a: []const Trit, b: []const Trit) ![]Trit {
    const result = try allocator.alloc(Trit, a.len);
    for (a, 0..) |_, i| {
        result[i] = if (b[i] == 0) a[i] else @as(i8, @truncate(b[i] * a[i]));
    }
    return result;
}

// TODO: No implementation for unbind
// TODO: No implementation for bundle2
// TODO: No implementation for bundle3
// TODO: No implementation for bundleN
// TODO: No implementation for permute
// TODO: No implementation for inversePermute
// TODO: No implementation for cosineSimilarity
// TODO: No implementation for hammingDistance
// TODO: No implementation for hammingSimilarity
// TODO: No implementation for dotSimilarity
// TODO: No implementation for vectorNorm
// TODO: No implementation for countNonZero
// TODO: No implementation for randomVector
// TODO: No implementation for encodeSequence
// TODO: No implementation for probeSequence
pub fn dotProduct(a: []const Trit, b: []const Trit) i64 {
    var sum: i64 = 0;
    const len = @min(a.len, b.len);
    for (0..len) |i| {
        sum += a[i] * b[i];
    }
    return sum;
}
