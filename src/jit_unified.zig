// Trinity Unified JIT Compiler
// Architecture-agnostic interface with compile-time backend selection
//
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3

const std = @import("std");
const builtin = @import("builtin");

// Import architecture-specific backends
const arm64 = @import("jit_arm64.zig");
const x86_64 = @import("jit_x86_64.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// ARCHITECTURE DETECTION
// ═══════════════════════════════════════════════════════════════════════════════

pub const Architecture = enum {
    arm64,
    x86_64,
    unsupported,
};

pub const current_arch: Architecture = switch (builtin.cpu.arch) {
    .aarch64 => .arm64,
    .x86_64 => .x86_64,
    else => .unsupported,
};

pub const is_arm64 = current_arch == .arm64;
pub const is_x86_64 = current_arch == .x86_64;
pub const is_jit_supported = current_arch != .unsupported;

// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED JIT FUNCTION TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// JIT-compiled dot product function
/// Takes two i8 array pointers and returns i64 dot product
pub const JitDotFn = *const fn (*anyopaque, *anyopaque) callconv(.c) i64;

/// JIT-compiled bind function
/// Takes two i8 array pointers, stores result in first
pub const JitBindFn = *const fn (*anyopaque, *anyopaque) callconv(.c) void;

// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED JIT COMPILER
// ═══════════════════════════════════════════════════════════════════════════════

pub const UnifiedJitCompiler = struct {
    allocator: std.mem.Allocator,

    // Architecture-specific backend
    backend: Backend,

    const Backend = union(Architecture) {
        arm64: arm64.Arm64JitCompiler,
        x86_64: x86_64.X86_64JitCompiler,
        unsupported: void,
    };

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .backend = switch (current_arch) {
                .arm64 => .{ .arm64 = arm64.Arm64JitCompiler.init(allocator) },
                .x86_64 => .{ .x86_64 = x86_64.X86_64JitCompiler.init(allocator) },
                .unsupported => .{ .unsupported = {} },
            },
        };
    }

    pub fn deinit(self: *Self) void {
        switch (self.backend) {
            .arm64 => |*b| b.deinit(),
            .x86_64 => |*b| b.deinit(),
            .unsupported => {},
        }
    }

    /// Get current architecture name
    pub fn archName() []const u8 {
        return switch (current_arch) {
            .arm64 => "ARM64 (AArch64)",
            .x86_64 => "x86-64",
            .unsupported => "Unsupported",
        };
    }

    /// Check if SIMD is available
    pub fn hasSIMD() bool {
        return switch (current_arch) {
            .arm64 => true, // NEON is always available on AArch64
            .x86_64 => false, // TODO: Add AVX/SSE detection
            .unsupported => false,
        };
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DOT PRODUCT COMPILATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Compile dot product - automatically selects best implementation
    /// For ARM64: uses hybrid SIMD+scalar for any dimension
    /// For x86_64: uses scalar loop
    pub fn compileDotProduct(self: *Self, dimension: usize) !void {
        switch (self.backend) {
            .arm64 => |*b| {
                // Use hybrid for best performance on any dimension
                try b.compileDotProductHybrid(dimension);
            },
            .x86_64 => |*b| {
                // x86_64 scalar implementation
                try b.compileDotProduct(dimension);
            },
            .unsupported => return error.UnsupportedArchitecture,
        }
    }

    /// Compile pure SIMD dot product (requires dimension % 16 == 0 on ARM64)
    pub fn compileDotProductSIMD(self: *Self, dimension: usize) !void {
        switch (self.backend) {
            .arm64 => |*b| try b.compileDotProductSIMD(dimension),
            .x86_64 => |*b| {
                // x86_64 falls back to scalar (TODO: add AVX2 SIMD)
                try b.compileDotProduct(dimension);
            },
            .unsupported => return error.UnsupportedArchitecture,
        }
    }

    /// Compile pure scalar dot product
    pub fn compileDotProductScalar(self: *Self, dimension: usize) !void {
        switch (self.backend) {
            .arm64 => |*b| try b.compileDotProduct(dimension),
            .x86_64 => |*b| try b.compileDotProduct(dimension),
            .unsupported => return error.UnsupportedArchitecture,
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // BIND COMPILATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Compile bind operation - uses SIMD on ARM64
    pub fn compileBind(self: *Self, dimension: usize) !void {
        switch (self.backend) {
            .arm64 => |*b| try b.compileBindSIMD(dimension),
            .x86_64 => |*b| try b.compileBindDirect(dimension),
            .unsupported => return error.UnsupportedArchitecture,
        }
    }

    /// Compile bind operation (scalar version)
    pub fn compileBindScalar(self: *Self, dimension: usize) !void {
        switch (self.backend) {
            .arm64 => |*b| try b.compileBindDirect(dimension),
            .x86_64 => |*b| try b.compileBindDirect(dimension),
            .unsupported => return error.UnsupportedArchitecture,
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HAMMING DISTANCE COMPILATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Compile hamming distance - uses SIMD on ARM64
    pub fn compileHamming(self: *Self, dimension: usize) !void {
        switch (self.backend) {
            .arm64 => |*b| try b.compileHammingSIMD(dimension),
            .x86_64 => return error.UnsupportedOperation,
            .unsupported => return error.UnsupportedArchitecture,
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FUSED COSINE COMPILATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Compile fused cosine similarity - computes dot(a,b), dot(a,a), dot(b,b) in single pass
    /// Returns f64 bit pattern (2.5x faster than 3 separate dot products)
    pub fn compileFusedCosine(self: *Self, dimension: usize) !void {
        switch (self.backend) {
            .arm64 => |*b| try b.compileFusedCosine(dimension),
            .x86_64 => return error.UnsupportedOperation,
            .unsupported => return error.UnsupportedArchitecture,
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // BUNDLE COMPILATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Compile bundle operation - threshold(a + b) to {-1, 0, 1}
    pub fn compileBundleSIMD(self: *Self, dimension: usize) !void {
        switch (self.backend) {
            .arm64 => |*b| try b.compileBundleSIMD(dimension),
            .x86_64 => return error.UnsupportedOperation,
            .unsupported => return error.UnsupportedArchitecture,
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FINALIZATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Make compiled code executable and return function pointer
    pub fn finalize(self: *Self) !JitDotFn {
        switch (self.backend) {
            .arm64 => |*b| return try b.finalize(),
            .x86_64 => |*b| return try b.finalize(),
            .unsupported => return error.UnsupportedArchitecture,
        }
    }

    /// Get generated code size
    pub fn codeSize(self: *Self) usize {
        return switch (self.backend) {
            .arm64 => |*b| b.codeSize(),
            .x86_64 => |*b| b.codeSize(),
            .unsupported => 0,
        };
    }

    /// Reset compiler for new compilation
    pub fn reset(self: *Self) void {
        switch (self.backend) {
            .arm64 => |*b| b.reset(),
            .x86_64 => |*b| b.reset(),
            .unsupported => {},
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONVENIENCE FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Quick compile and run dot product
pub fn jitDotProduct(allocator: std.mem.Allocator, a: []const i8, b: []const i8) !i64 {
    if (a.len != b.len) return error.DimensionMismatch;

    var compiler = UnifiedJitCompiler.init(allocator);
    defer compiler.deinit();

    try compiler.compileDotProduct(a.len);
    const func = try compiler.finalize();

    // Need mutable copies for the function call
    const a_copy = try allocator.alloc(i8, a.len);
    defer allocator.free(a_copy);
    @memcpy(a_copy, a);

    const b_copy = try allocator.alloc(i8, b.len);
    defer allocator.free(b_copy);
    @memcpy(b_copy, b);

    return func(@ptrCast(a_copy.ptr), @ptrCast(b_copy.ptr));
}

/// Print JIT capabilities info
pub fn printCapabilities() void {
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("              TRINITY UNIFIED JIT CAPABILITIES\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Architecture: {s}\n", .{UnifiedJitCompiler.archName()});
    std.debug.print("  JIT Supported: {}\n", .{is_jit_supported});
    std.debug.print("  SIMD Available: {}\n", .{UnifiedJitCompiler.hasSIMD()});
    std.debug.print("───────────────────────────────────────────────────────────────\n", .{});

    if (is_arm64) {
        std.debug.print("  ARM64 Features:\n", .{});
        std.debug.print("    • NEON SIMD (128-bit vectors)\n", .{});
        std.debug.print("    • SDOT instruction (16 i8 elements/cycle)\n", .{});
        std.debug.print("    • Hybrid SIMD+Scalar for any dimension\n", .{});
        std.debug.print("    • Expected speedup: 15-70x over scalar\n", .{});
    } else if (is_x86_64) {
        std.debug.print("  x86-64 Features:\n", .{});
        std.debug.print("    • Scalar JIT implementation\n", .{});
        std.debug.print("    • System V ABI compatible\n", .{});
        std.debug.print("    • TODO: AVX2/AVX-512 SIMD support\n", .{});
    }

    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Unified JIT architecture detection" {
    const arch = current_arch;

    // Should be one of the known architectures
    try std.testing.expect(arch == .arm64 or arch == .x86_64 or arch == .unsupported);

    // Consistency checks
    if (is_arm64) {
        try std.testing.expectEqual(Architecture.arm64, arch);
    }
    if (is_x86_64) {
        try std.testing.expectEqual(Architecture.x86_64, arch);
    }
}

test "Unified JIT compiler init/deinit" {
    var compiler = UnifiedJitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    // Should initialize without error
    try std.testing.expect(true);
}

test "Unified JIT dot product on ARM64" {
    if (!is_arm64) return;

    var compiler = UnifiedJitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const dim = 100; // Non-aligned dimension
    try compiler.compileDotProduct(dim);

    const func = try compiler.finalize();

    var a: [dim]i8 = undefined;
    var b: [dim]i8 = undefined;
    var expected: i64 = 0;

    for (0..dim) |i| {
        a[i] = 1;
        b[i] = 1;
        expected += 1;
    }

    const result = func(@ptrCast(&a), @ptrCast(&b));
    try std.testing.expectEqual(expected, result);
}

test "Unified JIT dot product various dimensions" {
    if (!is_arm64) return;

    const test_dims = [_]usize{ 1, 7, 16, 17, 32, 100, 256, 1000 };

    for (test_dims) |dim| {
        var compiler = UnifiedJitCompiler.init(std.testing.allocator);
        defer compiler.deinit();

        try compiler.compileDotProduct(dim);
        const func = try compiler.finalize();

        // Allocate dynamic arrays
        var a = try std.testing.allocator.alloc(i8, dim);
        defer std.testing.allocator.free(a);
        var b = try std.testing.allocator.alloc(i8, dim);
        defer std.testing.allocator.free(b);

        var expected: i64 = 0;
        for (0..dim) |i| {
            const val: i8 = @intCast(@as(i32, @intCast(i % 3)) - 1);
            a[i] = val;
            b[i] = 1;
            expected += val;
        }

        const result = func(@ptrCast(a.ptr), @ptrCast(b.ptr));
        try std.testing.expectEqual(expected, result);
    }
}

test "Unified JIT convenience function" {
    if (!is_arm64) return;

    const a = [_]i8{ 1, 1, 1, -1, -1, 0, 0, 1 };
    const b = [_]i8{ 1, 1, 1, 1, 1, 1, 1, 1 };

    // Expected: 1 + 1 + 1 - 1 - 1 + 0 + 0 + 1 = 2
    const expected: i64 = 2;

    const result = try jitDotProduct(std.testing.allocator, &a, &b);
    try std.testing.expectEqual(expected, result);
}

test "Unified JIT print capabilities" {
    // Just verify it doesn't crash
    printCapabilities();
}

test "Unified JIT benchmark" {
    if (!is_arm64) return;

    const dim = 1024;
    const iterations = 10000;

    var compiler = UnifiedJitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    try compiler.compileDotProduct(dim);
    const func = try compiler.finalize();

    var a: [dim]i8 = undefined;
    var b: [dim]i8 = undefined;
    for (0..dim) |i| {
        a[i] = @intCast(@as(i32, @intCast(i % 3)) - 1);
        b[i] = @intCast(@as(i32, @intCast((i + 1) % 3)) - 1);
    }

    var timer = std.time.Timer.start() catch unreachable;
    var result: i64 = 0;
    for (0..iterations) |_| {
        result = func(@ptrCast(&a), @ptrCast(&b));
    }
    const ns = timer.read();

    const ms = @as(f64, @floatFromInt(ns)) / 1_000_000.0;
    const ns_per_iter = @as(f64, @floatFromInt(ns)) / @as(f64, iterations);

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("           UNIFIED JIT BENCHMARK ({s})\n", .{UnifiedJitCompiler.archName()});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Dimension: {d}, Iterations: {d}\n", .{ dim, iterations });
    std.debug.print("  Total time: {d:.3} ms\n", .{ms});
    std.debug.print("  Per iteration: {d:.0} ns\n", .{ns_per_iter});
    std.debug.print("  Throughput: {d:.2} M dot products/sec\n", .{@as(f64, iterations) / ms * 1000.0 / 1_000_000.0});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});

    // Sanity check - result should be deterministic
    try std.testing.expect(result != 0 or dim == 0);
}
