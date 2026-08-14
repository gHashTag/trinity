const std = @import("std");

pub const MatmulBackend = enum {
    scalar,
   Accelerate,
    amx,
    auto,
};

pub fn detectBackend() MatmulBackend {
    const arch = std.Target.current.cpu.arch;
    if (arch == .aarch64) {
        return .Accelerate;
    }
    if (arch == .x86_64) {
        return .scalar;
    }
    return .scalar;
}

pub fn ternaryMatmul(
    weights: []const i8,
    input: []const f32,
    output: []f32,
    rows: usize,
    cols: usize,
) void {
    for (0..rows) |r| {
        var sum: f32 = 0.0;
        for (0..cols) |c| {
            const w = weights[r * cols + c];
            switch (w) {
                1 => sum += input[c],
                -1 => sum -= input[c],
                else => {},
            }
        }
        output[r] = sum;
    }
}

pub fn ternaryMatmulAccelerate(
    weights: []const i8,
    input: []const f32,
    rows: usize,
    cols: usize,
    positive_sums: []f32,
    negative_sums: []f32,
) void {
    @memset(positive_sums[0..rows], 0);
    @memset(negative_sums[0..rows], 0);

    for (0..rows) |r| {
        for (0..cols) |c| {
            const w = weights[r * cols + c];
            if (w == 1) {
                positive_sums[r] += input[c];
            } else if (w == -1) {
                negative_sums[r] += input[c];
            }
        }
    }
}

pub fn ternaryMatmulBlocked(
    weights: []const i8,
    input: []const f32,
    output: []f32,
    rows: usize,
    cols: usize,
    block_size: usize,
) void {
    @memset(output[0..rows], 0);

    var col_start: usize = 0;
    while (col_start < cols) : (col_start += block_size) {
        const col_end = @min(col_start + block_size, cols);
        const block_len = col_end - col_start;

        for (0..rows) |r| {
            var partial: f32 = 0.0;
            for (0..block_len) |b| {
                const c = col_start + b;
                const w = weights[r * cols + c];
                switch (w) {
                    1 => partial += input[c],
                    -1 => partial -= input[c],
                    else => {},
                }
            }
            output[r] += partial;
        }
    }
}

pub fn floatMatmulBlocked(
    a: []const f32,
    b: []const f32,
    output: []f32,
    m: usize,
    n: usize,
    k: usize,
    block_size: usize,
) void {
    @memset(output[0 .. m * n], 0);

    var kk: usize = 0;
    while (kk < k) : (kk += block_size) {
        const kk_end = @min(kk + block_size, k);
        var jj: usize = 0;
        while (jj < n) : (jj += block_size) {
            const jj_end = @min(jj + block_size, n);

            for (0..m) |i| {
                for (jj..jj_end) |j| {
                    var sum: f32 = 0;
                    for (kk..kk_end) |k_i| {
                        sum += a[i * k + k_i] * b[k_i * n + j];
                    }
                    output[i * n + j] += sum;
                }
            }
        }
    }
}

pub const AMXConfig = struct {
    rows: usize = 16,
    cols: usize = 64,
    enabled: bool = true,
};

pub const AMXMatmul = struct {
    config: AMXConfig,

    pub fn init(config: AMXConfig) AMXMatmul {
        return .{ .config = config };
    }

    pub fn isAvailable() bool {
        const arch = std.Target.current.cpu.arch;
        return arch == .aarch64;
    }

    pub fn matmul(self: *const AMXMatmul, a: []const f32, b: []const f32, output: []f32, m: usize, n: usize, k: usize) void {
        if (!self.config.enabled) {
            floatMatmulBlocked(a, b, output, m, n, k, 32);
            return;
        }

        floatMatmulBlocked(a, b, output, m, n, k, self.config.cols);
    }
};

test "ternary matmul scalar" {
    const weights = [_]i8{ 1, 0, -1, -1, 1, 0 };
    const input = [_]f32{ 2.0, 3.0, 4.0 };
    var output: [2]f32 = undefined;

    ternaryMatmul(&weights, &input, &output, 2, 3);
    try std.testing.expectApproxEqAbs(@as(f32, -2.0), output[0], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), output[1], 1e-6);
}

test "ternary matmul blocked matches scalar" {
    const weights = [_]i8{ 1, 1, -1, -1, 0, 1, 0, -1, 1 };
    const input = [_]f32{ 1.0, 2.0, 3.0 };

    var scalar_out: [3]f32 = undefined;
    var blocked_out: [3]f32 = undefined;

    ternaryMatmul(&weights, &input, &scalar_out, 3, 3);
    ternaryMatmulBlocked(&weights, &input, &blocked_out, 3, 3, 2);

    for (scalar_out, blocked_out) |s, b| {
        try std.testing.expectApproxEqAbs(s, b, 1e-6);
    }
}

test "ternary matmul accelerate positive/negative split" {
    const weights = [_]i8{ 1, -1, 0, -1, 1, 1 };
    const input = [_]f32{ 2.0, 3.0, 4.0 };

    var pos: [2]f32 = undefined;
    var neg: [2]f32 = undefined;
    ternaryMatmulAccelerate(&weights, &input, 2, 3, &pos, &neg);

    const row0 = pos[0] + neg[0];
    const row1 = pos[1] + neg[1];
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), row0, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), row1, 1e-6);
}

test "float matmul blocked" {
    const a = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const b = [_]f32{ 5.0, 6.0, 7.0, 8.0 };
    var output: [4]f32 = undefined;

    floatMatmulBlocked(&a, &b, &output, 2, 2, 2, 1);

    try std.testing.expectApproxEqAbs(@as(f32, 19.0), output[0], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 22.0), output[1], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 43.0), output[2], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), output[3], 1e-5);
}

test "AMX matmul wrapper" {
    const amx = AMXMatmul.init(.{ .enabled = true });
    const a = [_]f32{ 1.0, 0.0, 0.0, 1.0 };
    const b = [_]f32{ 2.0, 3.0, 4.0, 5.0 };
    var output: [4]f32 = undefined;

    amx.matmul(&a, &b, &output, 2, 2, 2);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), output[0], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), output[3], 1e-5);
}

test "detect backend returns valid" {
    const backend = detectBackend();
    try std.testing.expect(backend == .scalar or backend == .Accelerate or backend == .amx);
}
