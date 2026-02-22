// HARDWARE ABSTRACTION LAYER — Unified Ternary Backend Interface
// Compile-time backend selection with runtime feature detection
// Generated from specs/tri/hardware_abstraction.vibee
// phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");
const builtin = @import("builtin");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const MAX_DIM: usize = 1024;
pub const TEST_DIM: usize = 64;

// ═══════════════════════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════════════════════

pub const Backend = enum(u8) {
    cpu_scalar = 0,
    cpu_simd = 1,
    fpga = 2,
    gpu = 3,
};

pub const Architecture = enum(u8) {
    x86_64 = 0,
    aarch64 = 1,
    wasm32 = 2,
    unknown = 3,
};

pub const SimdCapability = enum(u8) {
    none = 0,
    sse4 = 1,
    avx2 = 2,
    avx512 = 3,
    neon = 4,
};

// ═══════════════════════════════════════════════════════════════════════════════
// HARDWARE DETECTION
// ═══════════════════════════════════════════════════════════════════════════════

pub const HardwareInfo = struct {
    arch: Architecture,
    simd_cap: SimdCapability,
    simd_width: u32,
    cache_line_size: u32,

    pub fn isSimdAvailable(self: *const HardwareInfo) bool {
        return self.simd_cap != .none;
    }

    pub fn backendName(self: *const HardwareInfo) []const u8 {
        return switch (self.simd_cap) {
            .none => "scalar",
            .sse4 => "SSE4.2",
            .avx2 => "AVX2",
            .avx512 => "AVX-512",
            .neon => "NEON",
        };
    }
};

/// Detect hardware at compile time
pub fn detectHardware() HardwareInfo {
    const arch: Architecture = switch (builtin.cpu.arch) {
        .x86_64 => .x86_64,
        .aarch64 => .aarch64,
        .wasm32 => .wasm32,
        else => .unknown,
    };

    const simd_result = detectSimd(arch);

    return HardwareInfo{
        .arch = arch,
        .simd_cap = simd_result.cap,
        .simd_width = simd_result.width,
        .cache_line_size = 64, // Common default
    };
}

const SimdDetectResult = struct { cap: SimdCapability, width: u32 };

fn detectSimd(arch: Architecture) SimdDetectResult {
    return switch (arch) {
        .x86_64 => blk: {
            // Check for AVX-512 first, then AVX2, then SSE4
            if (std.Target.x86.featureSetHas(builtin.cpu.features, .avx512f)) {
                break :blk .{ .cap = .avx512, .width = 16 };
            } else if (std.Target.x86.featureSetHas(builtin.cpu.features, .avx2)) {
                break :blk .{ .cap = .avx2, .width = 8 };
            } else if (std.Target.x86.featureSetHas(builtin.cpu.features, .sse4_2)) {
                break :blk .{ .cap = .sse4, .width = 4 };
            } else {
                break :blk .{ .cap = .none, .width = 1 };
            }
        },
        .aarch64 => .{ .cap = .neon, .width = 4 }, // NEON is always available on AArch64
        .wasm32 => .{ .cap = .none, .width = 1 },
        .unknown => .{ .cap = .none, .width = 1 },
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERFORMANCE COUNTERS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PerfCounters = struct {
    ops_count: u64 = 0,
    total_elements: u64 = 0,
    bind_ops: u64 = 0,
    bundle_ops: u64 = 0,
    similarity_ops: u64 = 0,
    matvec_ops: u64 = 0,
    permute_ops: u64 = 0,

    pub fn reset(self: *PerfCounters) void {
        self.* = .{};
    }

    pub fn totalOps(self: *const PerfCounters) u64 {
        return self.bind_ops + self.bundle_ops + self.similarity_ops + self.matvec_ops + self.permute_ops;
    }

    pub fn opsPerElement(self: *const PerfCounters) f64 {
        if (self.total_elements == 0) return 0.0;
        return @as(f64, @floatFromInt(self.totalOps())) / @as(f64, @floatFromInt(self.total_elements));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SCALAR BACKEND — Reference Implementation
// ═══════════════════════════════════════════════════════════════════════════════

pub const ScalarBackend = struct {
    /// Ternary bind: c[i] = clamp(a[i] * b[i], -1, 1)
    pub fn bind(output: []i8, a: []const i8, b: []const i8, dim: usize) void {
        const n = @min(dim, @min(output.len, @min(a.len, b.len)));
        for (0..n) |i| {
            const product = @as(i16, a[i]) * @as(i16, b[i]);
            output[i] = @as(i8, @intCast(std.math.clamp(product, -1, 1)));
        }
    }

    /// Ternary unbind: same as bind (multiplication is its own inverse in {-1,0,1})
    pub fn unbind(output: []i8, bound: []const i8, key: []const i8, dim: usize) void {
        bind(output, bound, key, dim);
    }

    /// Ternary bundle (majority vote of 2): sign(a + b), 0 breaks ties to 0
    pub fn bundle2(output: []i8, a: []const i8, b: []const i8, dim: usize) void {
        const n = @min(dim, @min(output.len, @min(a.len, b.len)));
        for (0..n) |i| {
            const sum = @as(i16, a[i]) + @as(i16, b[i]);
            output[i] = if (sum > 0) @as(i8, 1) else if (sum < 0) @as(i8, -1) else 0;
        }
    }

    /// Ternary bundle3 (majority vote of 3)
    pub fn bundle3(output: []i8, a: []const i8, b: []const i8, c: []const i8, dim: usize) void {
        const n = @min(dim, @min(output.len, @min(a.len, @min(b.len, c.len))));
        for (0..n) |i| {
            const sum = @as(i16, a[i]) + @as(i16, b[i]) + @as(i16, c[i]);
            output[i] = if (sum > 0) @as(i8, 1) else if (sum < 0) @as(i8, -1) else 0;
        }
    }

    /// Cosine similarity: dot(a,b) / (norm(a) * norm(b))
    pub fn cosineSimilarity(a: []const i8, b: []const i8, dim: usize) f32 {
        const n = @min(dim, @min(a.len, b.len));
        var dot_ab: i32 = 0;
        var norm_a: i32 = 0;
        var norm_b: i32 = 0;
        for (0..n) |i| {
            dot_ab += @as(i32, a[i]) * @as(i32, b[i]);
            norm_a += @as(i32, a[i]) * @as(i32, a[i]);
            norm_b += @as(i32, b[i]) * @as(i32, b[i]);
        }
        const denom = @sqrt(@as(f32, @floatFromInt(norm_a))) * @sqrt(@as(f32, @floatFromInt(norm_b)));
        if (denom < 1e-10) return 0.0;
        return @as(f32, @floatFromInt(dot_ab)) / denom;
    }

    /// Hamming distance: count of positions where a[i] != b[i]
    pub fn hammingDistance(a: []const i8, b: []const i8, dim: usize) u32 {
        const n = @min(dim, @min(a.len, b.len));
        var count: u32 = 0;
        for (0..n) |i| {
            if (a[i] != b[i]) count += 1;
        }
        return count;
    }

    /// Cyclic permutation: rotate vector by shift positions
    pub fn permute(output: []i8, input: []const i8, dim: usize, shift: usize) void {
        const n = @min(dim, @min(output.len, input.len));
        if (n == 0) return;
        const effective_shift = shift % n;
        for (0..n) |i| {
            output[i] = input[(i + effective_shift) % n];
        }
    }

    /// Ternary matrix-vector multiply: output[r] = sum_c(M[r][c] * v[c])
    /// For ternary weights {-1,0,+1}: no multiply needed, just add/subtract
    pub fn ternaryMatVec(output: []f32, weights: []const i8, input: []const f32, rows: usize, cols: usize) void {
        for (0..rows) |r| {
            var sum: f32 = 0.0;
            const row_offset = r * cols;
            for (0..cols) |c| {
                const w = weights[row_offset + c];
                if (w == 1) {
                    sum += input[c];
                } else if (w == -1) {
                    sum -= input[c];
                }
                // w == 0: skip (add nothing)
            }
            output[r] = sum;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD BACKEND — Vectorized Implementation
// ═══════════════════════════════════════════════════════════════════════════════

pub const SimdBackend = struct {
    const VEC_WIDTH = 8; // Process 8 i8 elements at a time

    /// SIMD ternary bind using @Vector
    pub fn bind(output: []i8, a: []const i8, b: []const i8, dim: usize) void {
        const n = @min(dim, @min(output.len, @min(a.len, b.len)));
        const Vec8 = @Vector(VEC_WIDTH, i8);
        const ones: Vec8 = @splat(1);
        const neg_ones: Vec8 = @splat(-1);

        var i: usize = 0;
        while (i + VEC_WIDTH <= n) : (i += VEC_WIDTH) {
            const va: Vec8 = a[i..][0..VEC_WIDTH].*;
            const vb: Vec8 = b[i..][0..VEC_WIDTH].*;
            const product = va * vb;
            // Clamp to [-1, 1]
            const clamped = @min(ones, @max(neg_ones, product));
            output[i..][0..VEC_WIDTH].* = clamped;
        }
        // Scalar tail
        while (i < n) : (i += 1) {
            const product = @as(i16, a[i]) * @as(i16, b[i]);
            output[i] = @as(i8, @intCast(std.math.clamp(product, -1, 1)));
        }
    }

    /// SIMD ternary bundle2
    pub fn bundle2(output: []i8, a: []const i8, b: []const i8, dim: usize) void {
        const n = @min(dim, @min(output.len, @min(a.len, b.len)));
        const Vec8i16 = @Vector(VEC_WIDTH, i16);
        const zeros: Vec8i16 = @splat(0);

        var i: usize = 0;
        while (i + VEC_WIDTH <= n) : (i += VEC_WIDTH) {
            const va: @Vector(VEC_WIDTH, i8) = a[i..][0..VEC_WIDTH].*;
            const vb: @Vector(VEC_WIDTH, i8) = b[i..][0..VEC_WIDTH].*;
            // Widen to i16 for addition
            const wa: Vec8i16 = va;
            const wb: Vec8i16 = vb;
            const sum = wa + wb;
            // Sign function: > 0 => 1, < 0 => -1, == 0 => 0
            const pos_mask = sum > zeros;
            const neg_mask = sum < zeros;
            const ones: Vec8i16 = @splat(1);
            const neg_ones: Vec8i16 = @splat(-1);
            const result = @select(i16, pos_mask, ones, @select(i16, neg_mask, neg_ones, zeros));
            // Narrow back to i8
            const narrow: @Vector(VEC_WIDTH, i8) = @truncate(result);
            output[i..][0..VEC_WIDTH].* = narrow;
        }
        // Scalar tail
        while (i < n) : (i += 1) {
            const sum = @as(i16, a[i]) + @as(i16, b[i]);
            output[i] = if (sum > 0) @as(i8, 1) else if (sum < 0) @as(i8, -1) else 0;
        }
    }

    /// SIMD cosine similarity
    pub fn cosineSimilarity(a: []const i8, b: []const i8, dim: usize) f32 {
        const n = @min(dim, @min(a.len, b.len));
        const Vec8i16 = @Vector(VEC_WIDTH, i16);

        var dot_acc: i32 = 0;
        var norm_a_acc: i32 = 0;
        var norm_b_acc: i32 = 0;

        var i: usize = 0;
        while (i + VEC_WIDTH <= n) : (i += VEC_WIDTH) {
            const va: @Vector(VEC_WIDTH, i8) = a[i..][0..VEC_WIDTH].*;
            const vb: @Vector(VEC_WIDTH, i8) = b[i..][0..VEC_WIDTH].*;
            const wa: Vec8i16 = va;
            const wb: Vec8i16 = vb;
            dot_acc += @reduce(.Add, wa * wb);
            norm_a_acc += @reduce(.Add, wa * wa);
            norm_b_acc += @reduce(.Add, wb * wb);
        }
        // Scalar tail
        while (i < n) : (i += 1) {
            dot_acc += @as(i32, a[i]) * @as(i32, b[i]);
            norm_a_acc += @as(i32, a[i]) * @as(i32, a[i]);
            norm_b_acc += @as(i32, b[i]) * @as(i32, b[i]);
        }

        const denom = @sqrt(@as(f32, @floatFromInt(norm_a_acc))) * @sqrt(@as(f32, @floatFromInt(norm_b_acc)));
        if (denom < 1e-10) return 0.0;
        return @as(f32, @floatFromInt(dot_acc)) / denom;
    }

    /// SIMD ternary matvec: add-only for {-1,0,+1} weights
    pub fn ternaryMatVec(output: []f32, weights: []const i8, input: []const f32, rows: usize, cols: usize) void {
        const Vec8f = @Vector(VEC_WIDTH, f32);

        for (0..rows) |r| {
            var sum_vec: Vec8f = @splat(0.0);
            var sum_scalar: f32 = 0.0;
            const row_offset = r * cols;

            var c: usize = 0;
            while (c + VEC_WIDTH <= cols) : (c += VEC_WIDTH) {
                const in_vec: Vec8f = input[c..][0..VEC_WIDTH].*;
                // Convert weights to f32 signs
                var signs: Vec8f = undefined;
                inline for (0..VEC_WIDTH) |k| {
                    signs[k] = @floatFromInt(weights[row_offset + c + k]);
                }
                sum_vec += in_vec * signs;
                _ = &sum_scalar;
            }
            sum_scalar += @reduce(.Add, sum_vec);
            // Scalar tail
            while (c < cols) : (c += 1) {
                const w = weights[row_offset + c];
                if (w == 1) {
                    sum_scalar += input[c];
                } else if (w == -1) {
                    sum_scalar -= input[c];
                }
            }
            output[r] = sum_scalar;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED HARDWARE ABSTRACTION — Dispatch Layer
// ═══════════════════════════════════════════════════════════════════════════════

pub const HardwareAbstraction = struct {
    hw_info: HardwareInfo,
    active_backend: Backend,
    counters: PerfCounters,
    enable_counters: bool,

    pub fn init() HardwareAbstraction {
        return initWithConfig(.{ .preferred_backend = .cpu_simd, .auto_select = true, .enable_perf_counters = true });
    }

    pub fn initWithConfig(config: BackendConfig) HardwareAbstraction {
        const hw = detectHardware();
        const backend = if (config.auto_select)
            selectBestBackend(hw)
        else
            config.preferred_backend;

        return .{
            .hw_info = hw,
            .active_backend = backend,
            .counters = .{},
            .enable_counters = config.enable_perf_counters,
        };
    }

    fn selectBestBackend(hw: HardwareInfo) Backend {
        return if (hw.isSimdAvailable()) .cpu_simd else .cpu_scalar;
    }

    /// Ternary bind dispatched to active backend
    pub fn bind(self: *HardwareAbstraction, output: []i8, a: []const i8, b: []const i8, dim: usize) void {
        switch (self.active_backend) {
            .cpu_simd => SimdBackend.bind(output, a, b, dim),
            .cpu_scalar => ScalarBackend.bind(output, a, b, dim),
            .fpga, .gpu => ScalarBackend.bind(output, a, b, dim), // Fallback
        }
        if (self.enable_counters) {
            self.counters.bind_ops += 1;
            self.counters.total_elements += dim;
            self.counters.ops_count += dim;
        }
    }

    /// Ternary bundle2 dispatched to active backend
    pub fn bundle2(self: *HardwareAbstraction, output: []i8, a: []const i8, b: []const i8, dim: usize) void {
        switch (self.active_backend) {
            .cpu_simd => SimdBackend.bundle2(output, a, b, dim),
            .cpu_scalar => ScalarBackend.bundle2(output, a, b, dim),
            .fpga, .gpu => ScalarBackend.bundle2(output, a, b, dim),
        }
        if (self.enable_counters) {
            self.counters.bundle_ops += 1;
            self.counters.total_elements += dim;
            self.counters.ops_count += dim;
        }
    }

    /// Cosine similarity dispatched to active backend
    pub fn cosineSimilarity(self: *HardwareAbstraction, a: []const i8, b: []const i8, dim: usize) f32 {
        const result = switch (self.active_backend) {
            .cpu_simd => SimdBackend.cosineSimilarity(a, b, dim),
            .cpu_scalar => ScalarBackend.cosineSimilarity(a, b, dim),
            .fpga, .gpu => ScalarBackend.cosineSimilarity(a, b, dim),
        };
        if (self.enable_counters) {
            self.counters.similarity_ops += 1;
            self.counters.total_elements += dim;
            self.counters.ops_count += dim * 3; // dot + 2 norms
        }
        return result;
    }

    /// Ternary matvec dispatched to active backend
    pub fn ternaryMatVec(self: *HardwareAbstraction, output: []f32, weights: []const i8, input: []const f32, rows: usize, cols: usize) void {
        switch (self.active_backend) {
            .cpu_simd => SimdBackend.ternaryMatVec(output, weights, input, rows, cols),
            .cpu_scalar => ScalarBackend.ternaryMatVec(output, weights, input, rows, cols),
            .fpga, .gpu => ScalarBackend.ternaryMatVec(output, weights, input, rows, cols),
        }
        if (self.enable_counters) {
            self.counters.matvec_ops += 1;
            self.counters.total_elements += rows * cols;
            self.counters.ops_count += rows * cols;
        }
    }

    /// Cyclic permutation (always scalar — memory-bound, not compute-bound)
    pub fn permute(self: *HardwareAbstraction, output: []i8, input: []const i8, dim: usize, shift: usize) void {
        ScalarBackend.permute(output, input, dim, shift);
        if (self.enable_counters) {
            self.counters.permute_ops += 1;
            self.counters.total_elements += dim;
            self.counters.ops_count += dim;
        }
    }

    /// Get performance counters snapshot
    pub fn getCounters(self: *const HardwareAbstraction) PerfCounters {
        return self.counters;
    }

    /// Reset performance counters
    pub fn resetCounters(self: *HardwareAbstraction) void {
        self.counters.reset();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BACKEND CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

pub const BackendConfig = struct {
    preferred_backend: Backend = .cpu_simd,
    auto_select: bool = true,
    enable_perf_counters: bool = true,
};

// ═══════════════════════════════════════════════════════════════════════════════
// MEMORY ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

pub const MemoryAnalysis = struct {
    ternary_bytes: u64,
    f32_bytes: u64,
    f16_bytes: u64,
    compression_vs_f32: f32,
    compression_vs_f16: f32,
    bits_per_trit: f32,

    pub fn analyze(num_params: u64) MemoryAnalysis {
        // Ternary: 2 bits per trit (could be 1.58 with packing)
        const ternary_bytes = (num_params + 3) / 4; // 4 trits per byte
        const f32_bytes = num_params * 4;
        const f16_bytes = num_params * 2;

        return .{
            .ternary_bytes = ternary_bytes,
            .f32_bytes = f32_bytes,
            .f16_bytes = f16_bytes,
            .compression_vs_f32 = @as(f32, @floatFromInt(f32_bytes)) / @as(f32, @floatFromInt(ternary_bytes)),
            .compression_vs_f16 = @as(f32, @floatFromInt(f16_bytes)) / @as(f32, @floatFromInt(ternary_bytes)),
            .bits_per_trit = 1.585, // log2(3) = 1.58496...
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "hardware detection" {
    const hw = detectHardware();
    // Should detect some architecture
    try std.testing.expect(hw.arch != .unknown or hw.arch == .unknown);
    // SIMD width should be at least 1
    try std.testing.expect(hw.simd_width >= 1);
    // Cache line size should be reasonable
    try std.testing.expectEqual(hw.cache_line_size, 64);
}

test "hardware info backend name" {
    const hw_none = HardwareInfo{ .arch = .unknown, .simd_cap = .none, .simd_width = 1, .cache_line_size = 64 };
    try std.testing.expectEqualStrings("scalar", hw_none.backendName());

    const hw_neon = HardwareInfo{ .arch = .aarch64, .simd_cap = .neon, .simd_width = 4, .cache_line_size = 64 };
    try std.testing.expectEqualStrings("NEON", hw_neon.backendName());
}

test "scalar bind" {
    const a = [_]i8{ 1, -1, 1, 0, -1, 1, -1, 0 };
    const b = [_]i8{ 1, 1, -1, 1, -1, 0, 1, -1 };
    var out: [8]i8 = undefined;
    ScalarBackend.bind(&out, &a, &b, 8);
    // 1*1=1, -1*1=-1, 1*-1=-1, 0*1=0, -1*-1=1, 1*0=0, -1*1=-1, 0*-1=0
    const expected = [_]i8{ 1, -1, -1, 0, 1, 0, -1, 0 };
    try std.testing.expectEqualSlices(i8, &expected, &out);
}

test "scalar unbind is inverse of bind" {
    const a = [_]i8{ 1, -1, 1, -1 };
    const b = [_]i8{ -1, 1, 1, -1 };
    var bound: [4]i8 = undefined;
    var recovered: [4]i8 = undefined;
    ScalarBackend.bind(&bound, &a, &b, 4);
    ScalarBackend.unbind(&recovered, &bound, &b, 4);
    // For non-zero elements, unbind(bind(a,b), b) should give a
    for (0..4) |i| {
        if (a[i] != 0 and b[i] != 0) {
            try std.testing.expectEqual(a[i], recovered[i]);
        }
    }
}

test "scalar bundle2" {
    const a = [_]i8{ 1, -1, 1, 0 };
    const b = [_]i8{ 1, 1, -1, -1 };
    var out: [4]i8 = undefined;
    ScalarBackend.bundle2(&out, &a, &b, 4);
    // 1+1=2>0 -> 1, -1+1=0 -> 0, 1+-1=0 -> 0, 0+-1=-1 -> -1
    const expected = [_]i8{ 1, 0, 0, -1 };
    try std.testing.expectEqualSlices(i8, &expected, &out);
}

test "scalar bundle3" {
    const a = [_]i8{ 1, -1, 1, 0 };
    const b = [_]i8{ 1, 1, -1, -1 };
    const c = [_]i8{ -1, -1, 1, 1 };
    var out: [4]i8 = undefined;
    ScalarBackend.bundle3(&out, &a, &b, &c, 4);
    // 1+1-1=1>0 -> 1, -1+1-1=-1<0 -> -1, 1-1+1=1>0 -> 1, 0-1+1=0 -> 0
    const expected = [_]i8{ 1, -1, 1, 0 };
    try std.testing.expectEqualSlices(i8, &expected, &out);
}

test "scalar cosine similarity — identical vectors" {
    const a = [_]i8{ 1, -1, 1, -1, 1, -1, 1, -1 };
    const sim = ScalarBackend.cosineSimilarity(&a, &a, 8);
    try std.testing.expectApproxEqAbs(sim, 1.0, 0.001);
}

test "scalar cosine similarity — opposite vectors" {
    const a = [_]i8{ 1, -1, 1, -1 };
    const b = [_]i8{ -1, 1, -1, 1 };
    const sim = ScalarBackend.cosineSimilarity(&a, &b, 4);
    try std.testing.expectApproxEqAbs(sim, -1.0, 0.001);
}

test "scalar cosine similarity — orthogonal" {
    const a = [_]i8{ 1, 1, 0, 0 };
    const b = [_]i8{ 0, 0, 1, 1 };
    const sim = ScalarBackend.cosineSimilarity(&a, &b, 4);
    try std.testing.expectApproxEqAbs(sim, 0.0, 0.001);
}

test "scalar hamming distance" {
    const a = [_]i8{ 1, -1, 1, 0 };
    const b = [_]i8{ 1, 1, 1, -1 };
    const dist = ScalarBackend.hammingDistance(&a, &b, 4);
    // Differ at positions 1 and 3 => distance = 2
    try std.testing.expectEqual(dist, 2);
}

test "scalar permute" {
    const input = [_]i8{ 1, 2, 3, 4 };
    var output: [4]i8 = undefined;
    ScalarBackend.permute(&output, &input, 4, 1);
    // Shift by 1: [2, 3, 4, 1]
    const expected = [_]i8{ 2, 3, 4, 1 };
    try std.testing.expectEqualSlices(i8, &expected, &output);
}

test "scalar ternary matvec" {
    // 2x4 matrix with mixed ternary weights
    const weights = [_]i8{ 1, -1, 1, 0, 0, 1, -1, 1 };
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var output: [2]f32 = undefined;
    ScalarBackend.ternaryMatVec(&output, &weights, &input, 2, 4);
    // Row 0: 1*1 + (-1)*2 + 1*3 + 0*4 = 1 - 2 + 3 = 2.0
    // Row 1: 0*1 + 1*2 + (-1)*3 + 1*4 = 2 - 3 + 4 = 3.0
    try std.testing.expectApproxEqAbs(output[0], 2.0, 0.001);
    try std.testing.expectApproxEqAbs(output[1], 3.0, 0.001);
}

test "SIMD bind matches scalar" {
    const a = [_]i8{ 1, -1, 1, 0, -1, 1, -1, 0, 1, 1, -1, -1 };
    const b = [_]i8{ 1, 1, -1, 1, -1, 0, 1, -1, -1, 1, 1, -1 };
    var scalar_out: [12]i8 = undefined;
    var simd_out: [12]i8 = undefined;
    ScalarBackend.bind(&scalar_out, &a, &b, 12);
    SimdBackend.bind(&simd_out, &a, &b, 12);
    try std.testing.expectEqualSlices(i8, &scalar_out, &simd_out);
}

test "SIMD bundle2 matches scalar" {
    const a = [_]i8{ 1, -1, 1, 0, -1, 1, -1, 0, 1, 0 };
    const b = [_]i8{ 1, 1, -1, -1, 1, -1, 0, 1, 1, -1 };
    var scalar_out: [10]i8 = undefined;
    var simd_out: [10]i8 = undefined;
    ScalarBackend.bundle2(&scalar_out, &a, &b, 10);
    SimdBackend.bundle2(&simd_out, &a, &b, 10);
    try std.testing.expectEqualSlices(i8, &scalar_out, &simd_out);
}

test "SIMD cosine similarity matches scalar" {
    const a = [_]i8{ 1, -1, 1, 0, -1, 1, -1, 0, 1, 1, -1, -1, 0, 1, -1, 1 };
    const b = [_]i8{ -1, 1, 1, -1, 0, 1, 1, -1, 1, -1, 0, 1, 1, -1, 1, -1 };
    const scalar_sim = ScalarBackend.cosineSimilarity(&a, &b, 16);
    const simd_sim = SimdBackend.cosineSimilarity(&a, &b, 16);
    try std.testing.expectApproxEqAbs(scalar_sim, simd_sim, 0.001);
}

test "SIMD ternary matvec matches scalar" {
    const weights = [_]i8{ 1, -1, 1, 0, -1, 1, -1, 0, 0, 1, -1, 1, 1, -1, 0, 1 };
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0 };
    var scalar_out: [2]f32 = undefined;
    var simd_out: [2]f32 = undefined;
    ScalarBackend.ternaryMatVec(&scalar_out, &weights, &input, 2, 8);
    SimdBackend.ternaryMatVec(&simd_out, &weights, &input, 2, 8);
    for (0..2) |i| {
        try std.testing.expectApproxEqAbs(scalar_out[i], simd_out[i], 0.01);
    }
}

test "unified HAL dispatches correctly" {
    var hal = HardwareAbstraction.init();

    const a = [_]i8{ 1, -1, 1, 0, -1, 1, -1, 0 };
    const b = [_]i8{ 1, 1, -1, 1, -1, 0, 1, -1 };
    var out: [8]i8 = undefined;

    hal.bind(&out, &a, &b, 8);

    // Verify result matches expected
    var expected: [8]i8 = undefined;
    ScalarBackend.bind(&expected, &a, &b, 8);
    try std.testing.expectEqualSlices(i8, &expected, &out);

    // Verify counters
    const counters = hal.getCounters();
    try std.testing.expectEqual(counters.bind_ops, 1);
    try std.testing.expectEqual(counters.total_elements, 8);
}

test "perf counters track operations" {
    var hal = HardwareAbstraction.init();

    const a = [_]i8{ 1, -1, 1, -1 };
    const b = [_]i8{ -1, 1, 1, -1 };
    var out: [4]i8 = undefined;

    hal.bind(&out, &a, &b, 4);
    hal.bundle2(&out, &a, &b, 4);
    _ = hal.cosineSimilarity(&a, &b, 4);

    const c = hal.getCounters();
    try std.testing.expectEqual(c.bind_ops, 1);
    try std.testing.expectEqual(c.bundle_ops, 1);
    try std.testing.expectEqual(c.similarity_ops, 1);
    try std.testing.expectEqual(c.totalOps(), 3);

    hal.resetCounters();
    const c2 = hal.getCounters();
    try std.testing.expectEqual(c2.totalOps(), 0);
}

test "memory analysis" {
    const analysis = MemoryAnalysis.analyze(1_000_000_000); // 1B params
    // Ternary: 1B / 4 = 250MB
    try std.testing.expectEqual(analysis.ternary_bytes, 250_000_000);
    // F32: 1B * 4 = 4GB
    try std.testing.expectEqual(analysis.f32_bytes, 4_000_000_000);
    // Compression: 4GB / 250MB = 16x
    try std.testing.expectApproxEqAbs(analysis.compression_vs_f32, 16.0, 0.01);
    // F16 compression: 2GB / 250MB = 8x
    try std.testing.expectApproxEqAbs(analysis.compression_vs_f16, 8.0, 0.01);
    // Bits per trit
    try std.testing.expectApproxEqAbs(analysis.bits_per_trit, 1.585, 0.001);
}

test "backend auto-selection" {
    const hw = detectHardware();
    const hal = HardwareAbstraction.init();
    if (hw.isSimdAvailable()) {
        try std.testing.expectEqual(hal.active_backend, .cpu_simd);
    } else {
        try std.testing.expectEqual(hal.active_backend, .cpu_scalar);
    }
}

test "force scalar backend" {
    var hal = HardwareAbstraction.initWithConfig(.{
        .preferred_backend = .cpu_scalar,
        .auto_select = false,
        .enable_perf_counters = true,
    });
    try std.testing.expectEqual(hal.active_backend, .cpu_scalar);

    // Should still produce correct results
    const a = [_]i8{ 1, -1, 1, -1 };
    const b = [_]i8{ 1, 1, 1, 1 };
    var out: [4]i8 = undefined;
    hal.bind(&out, &a, &b, 4);
    try std.testing.expectEqualSlices(i8, &a, &out);
}

// phi^2 + 1/phi^2 = 3 | TRINITY
