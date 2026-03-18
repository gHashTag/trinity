//! Comptime Optimizer v8.21
//!
//! Compile-time pattern optimization using Zig's comptime
//! Features:
//! - Auto-unroll loops based on φ-patterns
//! - Generate lookup tables at compile-time
//! - Specialize functions for common pattern sizes
//! - Zero-cost abstraction through comptime

const std = @import("std");
const sacred = @import("sacred_constants.zig");

/// Optimization level
pub const OptLevel = enum {
    None,
    Basic,
    Aggressive,
    Maximal,
};

/// Optimization transform
pub const Transform = enum {
    LoopUnroll,
    Vectorize,
    Inline,
    LookupTable,
    Specialize,
    ConstFold,
    DeadCodeElim,
};

/// Compile-time optimizer configuration
pub const OptConfig = struct {
    level: OptLevel = .Aggressive,
    max_unroll: u32 = 8,
    enable_vectorization: bool = true,
    enable_lookup_tables: bool = true,
    min_speedup_threshold: f32 = 1.2,
};

/// Comptime pattern optimizer
pub const ComptimeOptimizer = struct {
    const Self = @This();

    config: OptConfig,

    /// Initialize optimizer
    pub fn init(config: OptConfig) Self {
        return .{ .config = config };
    }

    /// Calculate optimal loop unroll factor using φ
    pub fn optimalUnrollFactor(comptime loop_count: usize) u32 {
        const phi_factors = [_]u32{ 2, 3, 5, 8, 13 };
        inline for (phi_factors) |factor| {
            if (loop_count % factor == 0 and loop_count / factor >= 2) {
                return factor;
            }
        }
        comptime var factor: u32 = 2;
        inline while (factor <= loop_count / 2) : (factor *= 2) {
            if (loop_count % factor == 0) return factor;
        }
        return 1;
    }

    /// Compile-time Fibonacci (φ-series)
    pub fn fibonacci(comptime n: usize) usize {
        if (n == 0) return 0;
        if (n == 1) return 1;
        comptime var a: usize = 0;
        comptime var b: usize = 1;
        comptime var i: usize = 2;
        inline while (i <= n) : (i += 1) {
            const temp = a + b;
            a = b;
            b = temp;
        }
        return b;
    }

    /// Optimal vector width for given element size
    pub fn optimalVectorWidth(comptime element_size: usize) u32 {
        const simd_bits = 128;
        return @intCast(simd_bits / (element_size * 8));
    }

    /// Optimal memory padding using φ-spacing
    pub fn optimalPadding(comptime base_size: usize, comptime align_to: usize) usize {
        const phi_padding = comptime @as(usize, @intFromFloat(@as(f64, @floatFromInt(align_to)) * sacred.PHI));
        const padded = base_size + phi_padding;
        return ((padded + align_to - 1) / align_to) * align_to;
    }

    /// Const-fold arithmetic expression at comptime
    pub fn constFold(comptime a: comptime_int, comptime b: comptime_int, comptime op: []const u8) comptime_int {
        if (std.mem.eql(u8, op, "+")) return a + b;
        if (std.mem.eql(u8, op, "-")) return a - b;
        if (std.mem.eql(u8, op, "*")) return a * b;
        if (std.mem.eql(u8, op, "/")) return @divTrunc(a, b);
        if (std.mem.eql(u8, op, "%")) return @rem(a, b);
        @compileError("Unknown operation");
    }

    /// Generate power-of-two sequence at compile-time
    pub fn powerOfTwoSequence(comptime n: usize) [n]usize {
        var seq: [n]usize = undefined;
        seq[0] = 1;
        comptime var i: usize = 1;
        inline while (i < n) : (i += 1) {
            seq[i] = 2 << @intCast(i - 1);
        }
        return seq;
    }

    /// Generate multiplication table at compile-time
    pub fn multiplicationTable(comptime size: usize) [size][size]usize {
        var table: [size][size]usize = undefined;
        comptime var i: usize = 0;
        inline while (i < size) : (i += 1) {
            comptime var j: usize = 0;
            inline while (j < size) : (j += 1) {
                table[i][j] = (i + 1) * (j + 1);
            }
        }
        return table;
    }

    /// Generate Trinity-aligned constants at compile-time
    pub fn trinityConstants() [3]f64 {
        return [_]f64{
            sacred.PHI_SQUARED,
            sacred.INVERSE_PHI_SQUARED,
            sacred.TRINITY_SUM,
        };
    }

    /// Optimal hash table size (φ-based prime)
    pub fn optimalHashSize(comptime min_size: usize) usize {
        const primes = [_]usize{ 13, 23, 37, 61, 97, 157, 251, 401, 647, 1049 };
        inline for (primes) |p| {
            if (p >= min_size) return p;
        }
        return comptime @as(usize, @intFromFloat(@as(f64, @floatFromInt(min_size)) * sacred.PHI));
    }

    /// Calculate bit-length needed for value
    pub fn bitLength(value: usize) usize {
        if (value == 0) return 1;
        var len: usize = 0;
        var v = value;
        while (v > 0) : (v >>= 1) {
            len += 1;
        }
        return len;
    }

    /// φ-based priority score for optimization candidates
    pub fn phiPriority(comptime benefit: usize, comptime cost: usize) f32 {
        const ratio = @as(f32, @floatFromInt(benefit)) / @as(f32, @floatFromInt(cost));
        return @floatCast(ratio * @as(f32, @floatCast(sacred.PHI)));
    }

    /// Generate φ-spaced indices for loop unrolling
    pub fn phiSpacedIndices(comptime count: usize, comptime max: usize) [count]usize {
        var result: [count]usize = undefined;
        const step = max / count;
        comptime var i: usize = 0;
        inline while (i < count) : (i += 1) {
            result[i] = @intFromFloat(@as(f64, @floatFromInt(i * step)) / sacred.PHI);
        }
        return result;
    }

    /// Calculate optimal cache line alignment
    pub fn optimalCacheAlign(comptime size: usize) usize {
        const cache_line = 64; // Standard cache line size
        const padded = size + cache_line - 1;
        return padded - (padded % cache_line);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "Comptime Optimizer: Initialize" {
    const opt = ComptimeOptimizer.init(.{});
    _ = opt;
}

test "Comptime Optimizer: Optimal unroll factor" {
    const factor = ComptimeOptimizer.optimalUnrollFactor(100);
    try std.testing.expect(factor >= 2 and factor <= 13);
}

test "Comptime Optimizer: Fibonacci" {
    const fib10 = ComptimeOptimizer.fibonacci(10);
    try std.testing.expectEqual(@as(usize, 55), fib10);

    const fib15 = ComptimeOptimizer.fibonacci(15);
    try std.testing.expectEqual(@as(usize, 610), fib15);
}

test "Comptime Optimizer: Optimal vector width" {
    const width32 = ComptimeOptimizer.optimalVectorWidth(4); // f32
    try std.testing.expectEqual(@as(u32, 4), width32);

    const width64 = ComptimeOptimizer.optimalVectorWidth(8); // f64
    try std.testing.expectEqual(@as(u32, 2), width64);
}

test "Comptime Optimizer: Optimal padding" {
    const padded = ComptimeOptimizer.optimalPadding(100, 16);
    try std.testing.expect(padded >= 100);
    try std.testing.expect(padded % 16 == 0);
}

test "Comptime Optimizer: Const folding" {
    const result = ComptimeOptimizer.constFold(5, 3, "+");
    try std.testing.expectEqual(@as(comptime_int, 8), result);

    const result2 = ComptimeOptimizer.constFold(10, 4, "*");
    try std.testing.expectEqual(@as(comptime_int, 40), result2);
}

test "Comptime Optimizer: Power of two sequence" {
    const seq = ComptimeOptimizer.powerOfTwoSequence(5);
    try std.testing.expectEqual(@as(usize, 1), seq[0]);
    try std.testing.expectEqual(@as(usize, 2), seq[1]);
    try std.testing.expectEqual(@as(usize, 16), seq[4]);
}

test "Comptime Optimizer: Multiplication table" {
    const table = ComptimeOptimizer.multiplicationTable(5);
    try std.testing.expectEqual(@as(usize, 1), table[0][0]);
    try std.testing.expectEqual(@as(usize, 25), table[4][4]);
    try std.testing.expectEqual(@as(usize, 12), table[2][3]);
}

test "Comptime Optimizer: Trinity constants" {
    const consts = ComptimeOptimizer.trinityConstants();
    try std.testing.expectApproxEqAbs(2.618, consts[0], 0.01); // φ²
    try std.testing.expectApproxEqAbs(0.382, consts[1], 0.01); // 1/φ²
    try std.testing.expectApproxEqAbs(3.0, consts[2], 0.01); // Sum
}

test "Comptime Optimizer: Optimal hash size" {
    const size = ComptimeOptimizer.optimalHashSize(50);
    try std.testing.expect(size >= 50);
    try std.testing.expect(size >= 61); // Should round up to prime 61
}

test "Comptime Optimizer: Bit length" {
    const len8 = ComptimeOptimizer.bitLength(255);
    try std.testing.expectEqual(@as(usize, 8), len8);

    const len16 = ComptimeOptimizer.bitLength(256);
    try std.testing.expectEqual(@as(usize, 9), len16);
}

test "Comptime Optimizer: Phi priority" {
    const priority = ComptimeOptimizer.phiPriority(100, 10);
    try std.testing.expect(priority > 15.0 and priority < 17.0);
}

test "Comptime Optimizer: Optimal cache align" {
    const aligned = ComptimeOptimizer.optimalCacheAlign(100);
    try std.testing.expect(aligned >= 100);
    try std.testing.expect(aligned % 64 == 0);
}
