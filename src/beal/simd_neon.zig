// ═══════════════════════════════════════════════════════════════════════════════
// BEAL SIMD - ARM NEON Optimized Vector Operations
// ═══════════════════════════════════════════════════════════════════════════════
// 128-bit ARM NEON SIMD for Beal Conjecture modular filtering
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// ARM NEON VECTOR TYPES
// ═══════════════════════════════════════════════════════════════════════════════
// ARM NEON uses 128-bit registers. We use these for parallel modular checks.

pub const Vec16i8 = @Vector(16, i8); // 16 × 8-bit integers
pub const Vec8i16 = @Vector(8, i16); // 8 × 16-bit integers
pub const Vec4i32 = @Vector(4, i32); // 4 × 32-bit integers
pub const Vec2i64 = @Vector(2, i64); // 2 × 64-bit integers
pub const Vec4u64 = @Vector(4, u64); // 4 × 64-bit unsigned (for modular arithmetic)
pub const Vec2u64 = @Vector(2, u64); // 2 × 64-bit unsigned

pub const SIMD_WIDTH: usize = 16;

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD MODULAR OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Check modular congruence for 2 primes simultaneously using SIMD
/// Returns true if BOTH (A^x + B^y) mod p[i] == C^z mod p[i]
pub inline fn check2PrimesSIMD(
    ax_mod: u64,
    by_mod: u64,
    cz_mod: u64,
    ax_mod1: u64,
    by_mod1: u64,
    cz_mod1: u64,
) bool {
    const left = Vec2i64{ @as(i64, @bitCast(ax_mod + by_mod)), @as(i64, @bitCast(ax_mod1 + by_mod1)) };
    const right = Vec2i64{ @as(i64, @bitCast(cz_mod)), @as(i64, @bitCast(cz_mod1)) };
    const matches = left == right;
    return @reduce(.And, matches);
}

/// Check modular congruence for 4 primes simultaneously using SIMD
/// Returns true if ALL 4 primes satisfy the congruence
pub inline fn check4PrimesSIMD(
    ax_mod: [4]u64,
    by_mod: [4]u64,
    cz_mod: [4]u64,
) bool {
    const left = Vec4u64{
        ax_mod[0] + by_mod[0],
        ax_mod[1] + by_mod[1],
        ax_mod[2] + by_mod[2],
        ax_mod[3] + by_mod[3],
    };
    const right = Vec4u64{
        cz_mod[0],
        cz_mod[1],
        cz_mod[2],
        cz_mod[3],
    };
    const matches = left == right;
    return @reduce(.And, matches);
}

/// SIMD-parallel modular addition with overflow handling
/// Computes (a + b) mod m for 2 pairs simultaneously
pub inline fn addMod2SIMD(a: [2]u64, b: [2]u64, m: [2]u64) [2]u64 {
    // Use conditional subtraction for modulo
    const sums = Vec2u64{ a[0] + b[0], a[1] + b[1] };
    const mods = Vec2u64{ m[0], m[1] };

    // Branchless modulo: if sum >= mod, subtract mod
    const cmp = sums >= mods;
    const sub = Vec2u64{ m[0], m[1] };

    var result = sums;
    const masked = @select(u64, cmp, sub, Vec2u64{ 0, 0 });
    result -= masked;

    return .{ result[0], result[1] };
}

/// SIMD min operation for 4 values
pub inline fn min4SIMD(values: [4]u64) u64 {
    const v = Vec4u64{ values[0], values[1], values[2], values[3] };

    // Pairwise min
    var m = v;
    m = @select(u64, m < @shuffle(u64, v, undefined, [4]i32{ 1, 0, 3, 2 }), m, @shuffle(u64, v, undefined, [4]i32{ 1, 0, 3, 2 }));
    m = @select(u64, m < @shuffle(u64, m, undefined, [4]i32{ 2, 3, 0, 1 }), m, @shuffle(u64, m, undefined, [4]i32{ 2, 3, 0, 1 }));

    return m[0];
}

/// SIMD max operation for 4 values
pub inline fn max4SIMD(values: [4]u64) u64 {
    const v = Vec4u64{ values[0], values[1], values[2], values[3] };

    // Pairwise max
    var m = v;
    m = @select(u64, m > @shuffle(u64, v, undefined, [4]i32{ 1, 0, 3, 2 }), m, @shuffle(u64, v, undefined, [4]i32{ 1, 0, 3, 2 }));
    m = @select(u64, m > @shuffle(u64, m, undefined, [4]i32{ 2, 3, 0, 1 }), m, @shuffle(u64, m, undefined, [4]i32{ 2, 3, 0, 1 }));

    return m[0];
}

/// SIMD sum of 4 values
pub inline fn sum4SIMD(values: [4]u64) u64 {
    const v = Vec4u64{ values[0], values[1], values[2], values[3] };
    return @reduce(.Add, v);
}

/// SIMD count of non-zero values in array of 16
pub inline fn countNonZero16SIMD(values: [16]u8) usize {
    const v = Vec16i8{
        @intCast(values[0]),  @intCast(values[1]),  @intCast(values[2]),  @intCast(values[3]),
        @intCast(values[4]),  @intCast(values[5]),  @intCast(values[6]),  @intCast(values[7]),
        @intCast(values[8]),  @intCast(values[9]),  @intCast(values[10]), @intCast(values[11]),
        @intCast(values[12]), @intCast(values[13]), @intCast(values[14]), @intCast(values[15]),
    };
    const zero: Vec16i8 = @splat(0);
    const ne = v != zero;
    return @popCount(@as(u16, @bitCast(ne)));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TARGET DETECTION
// ═══════════════════════════════════════════════════════════════════════════════

pub const SimdTarget = enum {
    neon, // ARM NEON (128-bit)
    neon_sve, // ARM SVE (scalable)
    avx2, // x86 AVX2 (256-bit)
    avx512, // x86 AVX-512 (512-bit)
    scalar, // No SIMD
};

/// Detect SIMD capabilities at runtime (comptime)
pub fn detectSimdTarget() SimdTarget {
    const builtin = @import("builtin");
    const arch = builtin.cpu.arch;

    // ARM/Apple Silicon
    if (arch == .aarch64) {
        return .neon;
    }

    // x86/x86_64
    if (arch == .x86_64 or arch == .x86) {
        // Check for AVX2/AVX512 via builtin
        if (builtin.cpu.features.has_avx512f and builtin.cpu.features.has_avx512dq) {
            return .avx512;
        }
        if (builtin.cpu.features.has_avx2) {
            return .avx2;
        }
    }

    return .scalar;
}

/// Get optimal SIMD width for detected target
pub fn getSimdWidth() usize {
    return switch (detectSimdTarget()) {
        .neon => 16,
        .neon_sve => 256, // SVE is scalable, use reasonable default
        .avx2 => 32,
        .avx512 => 64,
        .scalar => 1,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "check2PrimesSIMD - both match" {
    const ax1: u64 = 9;
    const by1: u64 = 16;
    const cz1: u64 = 25;
    const ax2: u64 = 5;
    const by2: u64 = 12;
    const cz2: u64 = 17;

    const result = check2PrimesSIMD(
        ax1,
        by1,
        cz1,
        ax2,
        by2,
        cz2,
    );

    // 9 + 16 = 25 ✓, 5 + 12 = 17 ✓
    try std.testing.expect(result);
}

test "check2PrimesSIMD - one mismatch" {
    const ax1: u64 = 9;
    const by1: u64 = 16;
    const cz1: u64 = 25;
    const ax2: u64 = 5;
    const by2: u64 = 12;
    const cz2: u64 = 18; // Wrong!

    const result = check2PrimesSIMD(
        ax1,
        by1,
        cz1,
        ax2,
        by2,
        cz2,
    );

    // 9 + 16 = 25 ✓, 5 + 12 ≠ 18 ✗
    try std.testing.expect(!result);
}

test "check4PrimesSIMD - all match" {
    const ax = [4]u64{ 9, 8, 27, 64 };
    const by = [4]u64{ 16, 18, 64, 125 };
    const cz = [4]u64{ 25, 26, 91, 189 };

    const result = check4PrimesSIMD(ax, by, cz);
    try std.testing.expect(result);
}

test "check4PrimesSIMD - one mismatch" {
    const ax = [4]u64{ 9, 8, 27, 64 };
    const by = [4]u64{ 16, 18, 64, 125 };
    const cz = [4]u64{ 25, 26, 91, 190 }; // Last one wrong

    const result = check4PrimesSIMD(ax, by, cz);
    try std.testing.expect(!result);
}

test "addMod2SIMD" {
    const a = [2]u64{ 100, 200 };
    const b = [2]u64{ 50, 150 };
    const m = [2]u64{ 127, 256 };

    const result = addMod2SIMD(a, b, m);
    try std.testing.expectEqual(@as(u64, 23), result[0]); // (100 + 50) % 127
    try std.testing.expectEqual(@as(u64, 94), result[1]); // (200 + 150) % 256
}

test "min4SIMD" {
    const values = [4]u64{ 42, 17, 99, 3 };
    const result = min4SIMD(values);
    try std.testing.expectEqual(@as(u64, 3), result);
}

test "max4SIMD" {
    const values = [4]u64{ 42, 17, 99, 3 };
    const result = max4SIMD(values);
    try std.testing.expectEqual(@as(u64, 99), result);
}

test "sum4SIMD" {
    const values = [4]u64{ 1, 2, 3, 4 };
    const result = sum4SIMD(values);
    try std.testing.expectEqual(@as(u64, 10), result);
}

test "countNonZero16SIMD" {
    const values = [16]u8{ 1, 0, 2, 0, 0, 0, 5, 0, 0, 7, 0, 0, 3, 0, 0, 9 };
    const result = countNonZero16SIMD(values);
    try std.testing.expectEqual(@as(usize, 6), result);
}

test "detect target" {
    const target = detectSimdTarget();
    std.debug.print("Detected SIMD target: {}\n", .{target});

    const width = getSimdWidth();
    try std.testing.expect(width >= 1);
}
