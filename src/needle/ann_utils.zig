// ═══════════════════════════════════════════════════════════════════════════════
// ANN UTILITIES — Shared helper functions
// ═══════════════════════════════════════════════════════════════════════════════
// Common utilities for all ANN implementations:
// - SIMD distance computation
// - Random projection generation
// - Vector normalization
// - Result sorting
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const ann_interface = @import("ann_interface.zig");

/// SIMD batch size for float operations (round(φ³) = 8)
pub const SIMD_BATCH_SIZE: usize = 8;

/// SIMD-accelerated cosine distance computation
pub fn simdCosineDistance(a: []const f32, b: []const f32) f32 {
    std.debug.assert(a.len == b.len);

    const Vec8 = @Vector(8, f32);
    var dot_prod: f32 = 0;
    var norm_a: f32 = 0;
    var norm_b: f32 = 0;

    const batch_size = SIMD_BATCH_SIZE;
    const num_batches = a.len / batch_size;

    var i: usize = 0;

    // SIMD batches
    while (i < num_batches * batch_size) : (i += batch_size) {
        const a_vec: Vec8 = a[i..][0..batch_size].*;
        const b_vec: Vec8 = b[i..][0..batch_size].*;

        dot_prod += @reduce(.Add, a_vec * b_vec);
        norm_a += @reduce(.Add, a_vec * a_vec);
        norm_b += @reduce(.Add, b_vec * b_vec);
    }

    // Remainder
    while (i < a.len) : (i += 1) {
        dot_prod += a[i] * b[i];
        norm_a += a[i] * a[i];
        norm_b += b[i] * b[i];
    }

    const norm_a_sqrt = @sqrt(norm_a);
    const norm_b_sqrt = @sqrt(norm_b);

    if (norm_a_sqrt < 1e-6 or norm_b_sqrt < 1e-6) {
        return 0.0;
    }

    const cosine_sim = dot_prod / (norm_a_sqrt * norm_b_sqrt);
    return 1.0 - cosine_sim;
}

/// SIMD-accelerated Euclidean distance computation
pub fn simdEuclideanDistance(a: []const f32, b: []const f32) f32 {
    std.debug.assert(a.len == b.len);

    const Vec8 = @Vector(8, f32);
    var sum_sq: f32 = 0;

    const batch_size = SIMD_BATCH_SIZE;
    const num_batches = a.len / batch_size;

    var i: usize = 0;

    // SIMD batches
    while (i < num_batches * batch_size) : (i += batch_size) {
        const a_vec: Vec8 = a[i..][0..batch_size].*;
        const b_vec: Vec8 = b[i..][0..batch_size].*;
        const diff = a_vec - b_vec;
        sum_sq += @reduce(.Add, diff * diff);
    }

    // Remainder
    while (i < a.len) : (i += 1) {
        const diff = a[i] - b[i];
        sum_sq += diff * diff;
    }

    return @sqrt(sum_sq);
}

/// L2 normalize a vector in-place
pub fn l2Normalize(vec: []f32) void {
    var norm: f32 = 0;
    for (vec) |v| {
        norm += v * v;
    }
    norm = @sqrt(norm);

    if (norm > 1e-6) {
        const scale = 1.0 / norm;
        for (vec) |*v| {
            v.* *= scale;
        }
    }
}

/// Generate random projection matrix for LSH
pub fn generateRandomProjections(
    allocator: std.mem.Allocator,
    dim: usize,
    n_hashes: usize,
    seed: u64,
) ![][]f32 {
    const projections = try allocator.alloc([]f32, n_hashes);
    errdefer {
        for (projections) |proj| {
            allocator.free(proj);
        }
        allocator.free(projections);
    }

    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();

    for (projections) |*proj| {
        proj.* = try allocator.alloc(f32, dim);
        for (proj.*) |*v| {
            // Gaussian approximation using Box-Muller transform
            const u1_val = random.float(f32);
            const u2_val = random.float(f32);
            const r = @sqrt(-2.0 * @log(u1_val + 1e-10));
            const theta = 2.0 * std.math.pi * u2_val;
            v.* = r * @cos(theta);
        }
    }

    return projections;
}

/// Sort ANN results by distance (ascending)
pub fn sortResults(results: []ann_interface.ANNResult) void {
    std.sort.insertion(ann_interface.ANNResult, results, {}, struct {
        fn compare(_: void, a: ann_interface.ANNResult, b: ann_interface.ANNResult) bool {
            return a.distance < b.distance;
        }
    }.compare);
}

/// Compute recall@k (how many of true top-k are in results)
pub fn computeRecall(
    results: []ann_interface.ANNResult,
    ground_truth: []const u64,
    k: usize,
) f32 {
    const check_k = @min(k, results.len, ground_truth.len);
    if (check_k == 0) return 0.0;

    var found: usize = 0;

    // Create set of ground truth IDs
    var truth_set = std.AutoHashMap(u64, void).init(std.heap.page_allocator);
    defer truth_set.deinit();

    for (ground_truth[0..check_k]) |id| {
        truth_set.put(id, {}) catch |err| {
            std.log.warn("ann_utils: truth set insert failed: {}", .{err});
        };
    }

    // Check how many of our results are in ground truth
    for (results[0..check_k]) |r| {
        if (truth_set.contains(r.id)) {
            found += 1;
        }
    }

    return @as(f32, @floatFromInt(found)) / @as(f32, @floatFromInt(check_k));
}

/// Generate random test vectors
pub fn generateRandomVectors(
    allocator: std.mem.Allocator,
    count: usize,
    dim: usize,
    seed: u64,
) ![][]f32 {
    const vectors = try allocator.alloc([]f32, count);
    errdefer {
        for (vectors) |v| {
            allocator.free(v);
        }
        allocator.free(vectors);
    }

    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();

    for (vectors) |*vec| {
        vec.* = try allocator.alloc(f32, dim);
        for (vec.*) |*v| {
            // Random values in [-1, 1]
            v.* = 2.0 * random.float(f32) - 1.0;
        }
        l2Normalize(vec.*);
    }

    return vectors;
}

/// Generate symbol IDs for test vectors
pub fn generateSymbolIds(
    allocator: std.mem.Allocator,
    count: usize,
) ![][]const u8 {
    const ids = try allocator.alloc([]const u8, count);
    errdefer allocator.free(ids);

    for (0..count) |i| {
        ids[i] = try std.fmt.allocPrint(allocator, "symbol_{d}", .{i});
    }

    return ids;
}

/// Timer for benchmarking
pub const Timer = struct {
    start_time: std.time.Instant,
    end_time: std.time.Instant,

    pub fn start() !Timer {
        return Timer{
            .start_time = try std.time.Instant.now(),
            .end_time = undefined,
        };
    }

    pub fn stop(self: *Timer) void {
        self.end_time = std.time.Instant.now() catch unreachable;
    }

    pub fn elapsedMs(self: *const Timer) u64 {
        const elapsed = self.end_time.since(self.start_time);
        return @intCast(elapsed / std.time.ns_per_ms);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "l2Normalize" {
    var vec = [_]f32{ 3.0, 4.0 };
    l2Normalize(&vec);
    const norm = @sqrt(vec[0] * vec[0] + vec[1] * vec[1]);
    try std.testing.expectApproxEqAbs(1.0, norm, 1e-6);
}

test "simdCosineDistance matches scalar" {
    const a = [_]f32{ 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 };
    const b = [_]f32{ 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 };

    const dist = simdCosineDistance(&a, &b);
    try std.testing.expectApproxEqAbs(1.0, dist, 1e-6);
}

test "simdEuclideanDistance matches scalar" {
    const a = [_]f32{ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 };
    const b = [_]f32{ 3.0, 4.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 };

    const dist = simdEuclideanDistance(&a, &b);
    try std.testing.expectApproxEqAbs(5.0, dist, 1e-6);
}

test "generateRandomVectors" {
    const allocator = std.testing.allocator;
    const vectors = try generateRandomVectors(allocator, 10, 384, 42);
    defer {
        for (vectors) |v| allocator.free(v);
        allocator.free(vectors);
    }

    try std.testing.expectEqual(@as(usize, 10), vectors.len);
    try std.testing.expectEqual(@as(usize, 384), vectors[0].len);
}
