// @origin(spec:simd_config.tri) @regen(manual-impl)
// Adaptive SIMD Width — Comptime CPU Feature Detection
// Selects optimal vector width based on available SIMD extensions
//
// Architecture support:
// - x86_64: AVX2 (256-bit) → SSE2 (128-bit) → fallback (64-bit)
// - aarch64: NEON (128-bit)
// - Default: 8-wide (safe baseline)
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const builtin = @import("builtin");

// ═══════════════════════════════════════════════════════════════════════════════
// CPU FEATURE DETECTION
// ═══════════════════════════════════════════════════════════════════════════════

/// Detected SIMD capabilities at comptime
pub const SimdCapabilities = struct {
    /// Has AVX2 (256-bit vectors on x86_64)
    has_avx2: bool = false,

    /// Has SSE2 (128-bit vectors on x86_64)
    has_sse2: bool = false,

    /// Has NEON (128-bit vectors on ARM)
    has_neon: bool = false,

    /// Has ARM SVE (scalable vectors)
    has_sve: bool = false,

    /// Optimal f16 vector width
    optimal_f16_width: usize,

    /// Optimal f32 vector width
    optimal_f32_width: usize,

    /// Optimal i8 vector width
    optimal_i8_width: usize,

    /// CPU architecture name
    arch_name: []const u8,
};

/// Get SIMD capabilities for current target
pub fn detectSimdCapabilities() SimdCapabilities {
    const arch = builtin.cpu.arch;
    const features = builtin.cpu.features;

    return switch (arch) {
        .x86_64 => blk: {
            const has_avx2 = std.Target.x86.featureSetHas(features, .avx2);
            const has_sse2 = std.Target.x86.featureSetHas(features, .sse2);

            const f16_width: usize = if (has_avx2) 16 else if (has_sse2) 8 else 4;
            const f32_width: usize = if (has_avx2) 8 else if (has_sse2) 4 else 2;
            const i8_width: usize = if (has_avx2) 32 else if (has_sse2) 16 else 8;

            break :blk .{
                .has_avx2 = has_avx2,
                .has_sse2 = has_sse2,
                .optimal_f16_width = f16_width,
                .optimal_f32_width = f32_width,
                .optimal_i8_width = i8_width,
                .arch_name = "x86_64",
            };
        },
        .aarch64, .aarch64_be => blk: {
            // ARM NEON is always available on aarch64
            const f16_width: usize = 8; // 128-bit / 16-bit = 8
            const f32_width: usize = 4; // 128-bit / 32-bit = 4
            const i8_width: usize = 16; // 128-bit / 8-bit = 16

            break :blk .{
                .has_neon = true,
                .optimal_f16_width = f16_width,
                .optimal_f32_width = f32_width,
                .optimal_i8_width = i8_width,
                .arch_name = "aarch64",
            };
        },
        .wasm32, .wasm64 => blk: {
            // WASM SIMD128 provides 128-bit vectors
            const f16_width: usize = 8;
            const f32_width: usize = 4;
            const i8_width: usize = 16;

            break :blk .{
                .optimal_f16_width = f16_width,
                .optimal_f32_width = f32_width,
                .optimal_i8_width = i8_width,
                .arch_name = "wasm",
            };
        },
        else => blk: {
            // Safe fallback for unknown architectures
            break :blk .{
                .optimal_f16_width = 4,
                .optimal_f32_width = 2,
                .optimal_i8_width = 8,
                .arch_name = "generic",
            };
        },
    };
}

/// Comptime-detected SIMD capabilities
pub const capabilities = detectSimdCapabilities();

// ═══════════════════════════════════════════════════════════════════════════════
// ADAPTIVE VECTOR TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Optimal f16 vector type for current CPU
pub const VecF16 = @Vector(capabilities.optimal_f16_width, f16);

/// Optimal f32 vector type for current CPU
pub const VecF32 = @Vector(capabilities.optimal_f32_width, f32);

/// Optimal i8 vector type for current CPU
pub const VecI8 = @Vector(capabilities.optimal_i8_width, i8);

/// Get zero vector for f16
pub inline fn zeroVecF16() VecF16 {
    return @splat(@as(f16, 0.0));
}

/// Get zero vector for f32
pub inline fn zeroVecF32() VecF32 {
    return @splat(@as(f32, 0.0));
}

/// Get zero vector for i8
pub inline fn zeroVecI8() VecI8 {
    return @splat(@as(i8, 0));
}

// ═══════════════════════════════════════════════════════════════════════════════
// RUNTIME INFO
// ═══════════════════════════════════════════════════════════════════════════════

/// Get human-readable SIMD info string
pub fn simdInfoString() []const u8 {
    if (capabilities.has_avx2) {
        return "AVX2 (256-bit)";
    } else if (capabilities.has_sse2) {
        return "SSE2 (128-bit)";
    } else if (capabilities.has_neon) {
        return "NEON (128-bit)";
    } else {
        return "Scalar (fallback)";
    }
}

/// Print SIMD configuration at runtime
/// Note: Only works in executables, not in test mode
pub fn printSimdConfig() void {
    const stdout = std.io.getStdOut().writer();

    stdout.print("SIMD Configuration:\n", .{}) catch return;
    stdout.print("  Architecture: {s}\n", .{capabilities.arch_name}) catch return;
    stdout.print("  f16 width: {d}\n", .{capabilities.optimal_f16_width}) catch return;
    stdout.print("  f32 width: {d}\n", .{capabilities.optimal_f32_width}) catch return;
    stdout.print("  i8 width: {d}\n", .{capabilities.optimal_i8_width}) catch return;
    stdout.print("  Detection: {s}\n", .{simdInfoString()}) catch return;

    if (capabilities.has_avx2) {
        stdout.print("  Extensions: AVX2, SSE2\n", .{}) catch return;
    } else if (capabilities.has_sse2) {
        stdout.print("  Extensions: SSE2\n", .{}) catch return;
    } else if (capabilities.has_neon) {
        stdout.print("  Extensions: NEON\n", .{}) catch return;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMPATIBILITY HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Check if current CPU supports a given minimum width
pub fn supportsMinWidth(min_width: usize) bool {
    return capabilities.optimal_f32_width >= min_width;
}

/// Get expected speedup vs baseline (8-wide)
pub fn expectedSpeedupVsBaseline() f64 {
    const baseline_width: f64 = 8;
    const current_width: f64 = @floatFromInt(capabilities.optimal_f32_width);
    // Theoretical speedup (actual may vary due to memory bandwidth)
    return current_width / baseline_width;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "detect simd capabilities" {
    const caps = detectSimdCapabilities();

    // Should have detected some architecture
    try std.testing.expect(caps.arch_name.len > 0);

    // Widths should be power of 2 and reasonable
    try std.testing.expect(caps.optimal_f16_width >= 4 and caps.optimal_f16_width <= 32);
    try std.testing.expect(caps.optimal_f32_width >= 2 and caps.optimal_f32_width <= 8);
    try std.testing.expect(caps.optimal_i8_width >= 8 and caps.optimal_i8_width <= 32);

    // f16 width should be 2× f32 width (same total bits)
    try std.testing.expectEqual(caps.optimal_f16_width, caps.optimal_f32_width * 2);

    // i8 width should be 4× f32 width (same total bits)
    try std.testing.expectEqual(caps.optimal_i8_width, caps.optimal_f32_width * 4);
}

test "vector types are correctly sized" {
    // Verify the types compile and have expected widths
    // The actual width is comptime-known from capabilities

    try std.testing.expect(capabilities.optimal_f16_width >= 4);
    try std.testing.expect(capabilities.optimal_f32_width >= 2);
    try std.testing.expect(capabilities.optimal_i8_width >= 8);

    // Verify the relationship between widths
    try std.testing.expectEqual(capabilities.optimal_f16_width, capabilities.optimal_f32_width * 2);
    try std.testing.expectEqual(capabilities.optimal_i8_width, capabilities.optimal_f32_width * 4);
}

test "zero vectors" {
    // Verify zero vectors are actually all zeros
    {
        const zv = zeroVecF16();
        var sum: f64 = 0;
        inline for (0..capabilities.optimal_f16_width) |i| {
            sum += @as(f64, @floatCast(zv[i]));
        }
        try std.testing.expectEqual(sum, 0);
    }

    {
        const zv = zeroVecF32();
        var sum: f64 = 0;
        inline for (0..capabilities.optimal_f32_width) |i| {
            sum += @as(f64, zv[i]);
        }
        try std.testing.expectEqual(sum, 0);
    }

    {
        const zv = zeroVecI8();
        var sum: i64 = 0;
        inline for (0..capabilities.optimal_i8_width) |i| {
            sum += zv[i];
        }
        try std.testing.expectEqual(sum, 0);
    }
}

test "simd info string is valid" {
    const info = simdInfoString();
    try std.testing.expect(info.len > 0);
}

test "supports min width" {
    // Should always support at least 4-wide
    try std.testing.expect(supportsMinWidth(4));

    // Should support 8-wide on most platforms
    try std.testing.expect(supportsMinWidth(8) or capabilities.optimal_f32_width < 8);
}

test "expected speedup is reasonable" {
    const speedup = expectedSpeedupVsBaseline();

    // Speedup should be between 0.25× and 4×
    try std.testing.expect(speedup >= 0.25 and speedup <= 4.0);
}

test "x86_64 avx2 detection" {
    if (builtin.cpu.arch == .x86_64) {
        // On x86_64, should have at least SSE2
        try std.testing.expect(capabilities.has_sse2 or capabilities.optimal_f32_width >= 4);
    }
}

test "aarch64 neon detection" {
    if (builtin.cpu.arch == .aarch64) {
        // On ARM64, should have NEON
        try std.testing.expect(capabilities.has_neon);
        try std.testing.expectEqual(@as(usize, 8), capabilities.optimal_f16_width);
    }
}

test "vector types support common operations" {
    // Test that our adaptive vector types work with common SIMD ops

    const f16_width = capabilities.optimal_f16_width;
    const f32_width = capabilities.optimal_f32_width;
    const i8_width = capabilities.optimal_i8_width;

    // f16 vector operations
    const v_f16_a: VecF16 = @splat(1.5);
    const v_f16_b: VecF16 = @splat(2.5);
    const v_f16_sum = v_f16_a + v_f16_b;

    var f16_check: f64 = 0;
    inline for (0..f16_width) |i| {
        f16_check += @as(f64, @floatCast(v_f16_sum[i]));
    }
    const expected_f16 = @as(f64, 4.0) * @as(f64, @floatFromInt(f16_width));
    try std.testing.expectApproxEqAbs(expected_f16, f16_check, 0.1);

    // f32 vector operations
    const v_f32_a: VecF32 = @splat(1.5);
    const v_f32_b: VecF32 = @splat(2.5);
    const v_f32_sum = v_f32_a + v_f32_b;

    var f32_check: f64 = 0;
    inline for (0..f32_width) |i| {
        f32_check += @as(f64, v_f32_sum[i]);
    }
    const expected_f32 = @as(f64, 4.0) * @as(f64, @floatFromInt(f32_width));
    try std.testing.expectApproxEqAbs(expected_f32, f32_check, 0.1);

    // i8 vector operations
    const v_i8_a: VecI8 = @splat(@as(i8, 1));
    const v_i8_b: VecI8 = @splat(@as(i8, 2));
    const v_i8_sum = v_i8_a + v_i8_b;

    var i8_check: i64 = 0;
    inline for (0..i8_width) |i| {
        i8_check += v_i8_sum[i];
    }
    const expected_i8 = @as(i64, 3) * @as(i64, @intCast(i8_width));
    try std.testing.expectEqual(expected_i8, i8_check);
}

// φ² + 1/φ² = 3 | TRINITY
