const std = @import("std");

pub const LambConfig = struct {
    lr: f32 = 3e-4,
    beta1: f32 = 0.9,
    beta2: f32 = 0.999,
    eps: f32 = 1e-8,
    weight_decay: f32 = 0.01,
    clamp: f32 = 10.0,
    stable_ratio: f32 = 0.02,
};

pub const LambState = struct {
    m: []f32,
    v: []f32,
    step_count: u32,

    pub fn init(allocator: std.mem.Allocator, num_params: usize) !LambState {
        const m = try allocator.alloc(f32, num_params);
        const v = try allocator.alloc(f32, num_params);
        @memset(m, 0);
        @memset(v, 0);
        return .{ .m = m, .v = v, .step_count = 0 };
    }

    pub fn deinit(self: *LambState, allocator: std.mem.Allocator) void {
        allocator.free(self.m);
        allocator.free(self.v);
    }
};

pub const LambOptimizer = struct {
    config: LambConfig,
    allocator: std.mem.Allocator,
    states: std.ArrayList(LambState),

    pub fn init(allocator: std.mem.Allocator, config: LambConfig) LambOptimizer {
        return .{
            .config = config,
            .allocator = allocator,
            .states = std.ArrayList(LambState).init(allocator),
        };
    }

    pub fn deinit(self: *LambOptimizer) void {
        for (self.states.items) |*s| s.deinit(self.allocator);
        self.states.deinit();
    }

    pub fn register(self: *LambOptimizer, num_params: usize) !usize {
        const state = try LambState.init(self.allocator, num_params);
        const idx = self.states.items.len;
        try self.states.append(state);
        return idx;
    }

    pub fn step(self: *LambOptimizer, tensor_idx: usize, params: []f32, grads: []const f32) void {
        std.debug.assert(tensor_idx < self.states.items.len);
        const state = &self.states.items[tensor_idx];
        state.step_count += 1;

        const t = @as(f32, @floatFromInt(state.step_count));
        const bias_corr1 = 1.0 - std.math.pow(f32, self.config.beta1, t);
        const bias_corr2 = 1.0 - std.math.pow(f32, self.config.beta2, t);

        var weight_norm: f32 = 0;
        for (params) |p| weight_norm += p * p;
        weight_norm = std.math.sqrt(weight_norm);

        for (params, grads, 0..) |*p, g, i| {
            state.m[i] = self.config.beta1 * state.m[i] + (1.0 - self.config.beta1) * g;
            state.v[i] = self.config.beta2 * state.v[i] + (1.0 - self.config.beta2) * g * g;

            const m_hat = state.m[i] / bias_corr1;
            const v_hat = state.v[i] / bias_corr2;

            var update = m_hat / (std.math.sqrt(v_hat) + self.config.eps);
            update += self.config.weight_decay * p.*;

            var update_norm: f32 = 0;
            update_norm += update * update;
            update_norm = std.math.sqrt(update_norm);

            const ratio = if (update_norm > 0 and weight_norm > 0)
                std.math.clamp(weight_norm / update_norm, 1.0 / self.config.clamp, self.config.clamp)
            else
                1.0;

            p.* -= self.config.lr * ratio * update;
        }
    }
};

pub fn labelSmoothing(logits: []f32, target: usize, smoothing: f32, vocab_size: usize) void {
    std.debug.assert(logits.len >= vocab_size);
    const confidence = 1.0 - smoothing;
    const uniform = smoothing / @as(f32, @floatFromInt(vocab_size - 1));

    for (logits[0..vocab_size], 0..) |*l, i| {
        l.* = if (i == target) confidence + uniform else uniform;
    }
}

pub fn smoothCrossEntropy(logits: []const f32, target: usize, smoothing: f32, vocab_size: usize) f32 {
    const log_sum = logSumExp(logits[0..vocab_size]);
    var loss: f32 = 0;

    const confidence = 1.0 - smoothing;
    const uniform = smoothing / @as(f32, @floatFromInt(vocab_size - 1));

    for (logits[0..vocab_size], 0..) |l, i| {
        const target_prob = if (i == target) confidence + uniform else uniform;
        if (target_prob > 0) {
            loss -= target_prob * (l - log_sum);
        }
    }

    return loss;
}

fn logSumExp(values: []const f32) f32 {
    var max_val: f32 = -std.math.inf(f32);
    for (values) |v| max_val = @max(max_val, v);

    var sum: f32 = 0;
    for (values) |v| sum += std.math.exp(v - max_val);
    return max_val + std.math.log(@max(sum, 1e-10));
}

pub fn avx2TernaryMatmul(weights: []const i8, input: []const f32, output: []f32, rows: usize, cols: usize) void {
    const vec_len = 8;

    for (0..rows) |r| {
        var sum: f32 = 0.0;
        const row_offset = r * cols;

        var c: usize = 0;
        while (c + vec_len <= cols) : (c += vec_len) {
            var vsum: f32 = 0.0;
            for (0..vec_len) |v| {
                const w = weights[row_offset + c + v];
                switch (w) {
                    1 => vsum += input[c + v],
                    -1 => vsum -= input[c + v],
                    else => {},
                }
            }
            sum += vsum;
        }

        while (c < cols) : (c += 1) {
            const w = weights[row_offset + c];
            switch (w) {
                1 => sum += input[c],
                -1 => sum -= input[c],
                else => {},
            }
        }

        output[r] = sum;
    }
}

test "LAMB optimizer converges" {
    const allocator = std.testing.allocator;
    var opt = LambOptimizer.init(allocator, .{ .lr = 0.01, .weight_decay = 0.01 });
    defer opt.deinit();

    var params = [_]f32{ 5.0, -3.0, 2.0 };
    const grads = [_]f32{ 1.0, 1.0, 1.0 };

    const idx = try opt.register(params.len);
    for (0..20) |_| {
        opt.step(idx, &params, &grads);
    }

    try std.testing.expect(@abs(params[0]) < 5.0);
    try std.testing.expect(@abs(params[1]) < 3.0);
}

test "LAMB clamp works" {
    const allocator = std.testing.allocator;
    var opt = LambOptimizer.init(allocator, .{ .lr = 0.01, .clamp = 1.0 });
    defer opt.deinit();

    var params = [_]f32{ 0.001 };
    const grads = [_]f32{ 100.0 };

    const idx = try opt.register(params.len);
    opt.step(idx, &params, &grads);

    try std.testing.expect(std.math.isFinite(params[0]));
}

test "label smoothing produces valid distribution" {
    var logits = [_]f32{ 0, 0, 0, 0, 0 };
    labelSmoothing(&logits, 2, 0.1, 5);

    var sum: f32 = 0;
    for (logits) |l| sum += l;
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), sum, 1e-6);
    try std.testing.expect(logits[2] > logits[0]);
}

test "smooth cross entropy loss" {
    const logits = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const loss = smoothCrossEntropy(&logits, 4, 0.1, 5);
    try std.testing.expect(loss > 0);
    try std.testing.expect(std.math.isFinite(loss));
}

test "smooth cross entropy lower for correct prediction" {
    const good = [_]f32{ 0.0, 0.0, 0.0, 0.0, 10.0 };
    const bad = [_]f32{ 10.0, 0.0, 0.0, 0.0, 0.0 };

    const loss_good = smoothCrossEntropy(&good, 4, 0.1, 5);
    const loss_bad = smoothCrossEntropy(&bad, 4, 0.1, 5);
    try std.testing.expect(loss_good < loss_bad);
}

test "AVX2-style ternary matmul matches scalar" {
    const weights = [_]i8{ 1, -1, 0, 1, 0, -1, -1, 1, 1 };
    const input = [_]f32{ 2.0, 3.0, 4.0 };

    var scalar_out: [3]f32 = undefined;
    var simd_out: [3]f32 = undefined;

    for (0..3) |r| {
        var sum: f32 = 0;
        for (0..3) |c| {
            switch (weights[r * 3 + c]) {
                1 => sum += input[c],
                -1 => sum -= input[c],
                else => {},
            }
        }
        scalar_out[r] = sum;
    }

    avx2TernaryMatmul(&weights, &input, &simd_out, 3, 3);

    for (scalar_out, simd_out) |s, v| {
        try std.testing.expectApproxEqAbs(s, v, 1e-6);
    }
}
