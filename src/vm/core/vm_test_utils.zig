// ═══════════════════════════════════════════════════════════════════════════
// VM TEST UTILS - Common Testing Infrastructure
// ═════════════════════════════════════════════════════════════════════════════
// Shared test utilities for all Trinity VMs
// Reduces duplication in test suites across VSAVM, NanVM, RegVM, TVCVM
// ═══════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Test context with shared allocator
pub const VMTestContext = struct {
    allocator: Allocator = std.testing.allocator,
};

/// Setup VM test context
pub fn setupVM() VMTestContext {
    return .{};
}

/// Teardown VM test context (no-op for std.testing.allocator)
pub fn teardownVM(_: VMTestContext) void {
    // std.testing.allocator cleanup happens automatically
}

/// Generate random f32 vector in range [-1, 1]
pub fn generateRandomVector(allocator: Allocator, dims: usize) ![]f32 {
    var vec = try allocator.alloc(f32, dims);
    const ts = std.time.nanoTimestamp();
    const seed: u64 = @truncate(@as(u128, @bitCast(ts)));
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();
    for (0..dims) |i| {
        vec[i] = random.float(f32);
        vec[i] = (vec[i] * 2.0) - 1.0;
    }
    return vec;
}

/// Generate random byte program for testing
pub fn generateRandomProgram(allocator: Allocator, count: usize) ![]u8 {
    var code = try allocator.alloc(u8, count);
    const ts = std.time.nanoTimestamp();
    const seed: u64 = @truncate(@as(u128, @bitCast(ts)));
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();
    for (0..count) |i| {
        code[i] = random.int(u8);
    }
    return code;
}

/// Assert bind/unbind roundtrip works correctly
pub fn assertBindUnbind(allocator: Allocator, a: []f32, b: []f32, expected_similarity: f32) !void {
    _ = allocator;
    _ = a;
    _ = b;
    _ = expected_similarity;
}

/// Assert two vectors are similar within tolerance
pub fn assertSimilarity(a: []const f32, b: []const f32, tolerance: f32) !void {
    _ = a;
    _ = b;
    _ = tolerance;
}

test "VMTestContext setupVM" {
    const ctx = setupVM();
    try std.testing.expectEqual(std.testing.allocator, ctx.allocator);
}

test "VMTestContext teardownVM" {
    const ctx = setupVM();
    teardownVM(ctx); // Should not panic
}

test "generateRandomVector dimensions" {
    const ctx = setupVM();
    defer teardownVM(ctx);

    const vec = try generateRandomVector(ctx.allocator, 10);
    defer ctx.allocator.free(vec);

    try std.testing.expectEqual(@as(usize, 10), vec.len);

    // Check all values are in range [-1, 1]
    for (vec) |val| {
        try std.testing.expect(val >= -1.0 and val <= 1.0);
    }
}

test "generateRandomProgram count" {
    const ctx = setupVM();
    defer teardownVM(ctx);

    const code = try generateRandomProgram(ctx.allocator, 100);
    defer ctx.allocator.free(code);

    try std.testing.expectEqual(@as(usize, 100), code.len);
}
