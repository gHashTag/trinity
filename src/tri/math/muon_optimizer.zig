const std = @import("std");

pub const MuonConfig = struct {
    lr: f32 = 0.02,
    momentum: f32 = 0.95,
    ns_iterations: u32 = 5,
    weight_decay: f32 = 0.0,
    nesterov: bool = true,
};

pub const MuonState = struct {
    velocity: []f32,
    momentum_buffer: []f32,
    step_count: u32,

    pub fn init(allocator: std.mem.Allocator, num_params: usize) !MuonState {
        const velocity = try allocator.alloc(f32, num_params);
        const momentum_buffer = try allocator.alloc(f32, num_params);
        @memset(velocity, 0);
        @memset(momentum_buffer, 0);
        return .{
            .velocity = velocity,
            .momentum_buffer = momentum_buffer,
            .step_count = 0,
        };
    }

    pub fn deinit(self: *MuonState, allocator: std.mem.Allocator) void {
        allocator.free(self.velocity);
        allocator.free(self.momentum_buffer);
    }
};

pub const MuonOptimizer = struct {
    config: MuonConfig,
    allocator: std.mem.Allocator,
    states: std.ArrayList(MuonState),

    pub fn init(allocator: std.mem.Allocator, config: MuonConfig) MuonOptimizer {
        return .{
            .config = config,
            .allocator = allocator,
            .states = std.ArrayList(MuonState).init(allocator),
        };
    }

    pub fn deinit(self: *MuonOptimizer) void {
        for (self.states.items) |*s| s.deinit(self.allocator);
        self.states.deinit();
    }

    pub fn registerTensor(self: *MuonOptimizer, num_params: usize) !usize {
        const state = try MuonState.init(self.allocator, num_params);
        const idx = self.states.items.len;
        try self.states.append(state);
        return idx;
    }

    pub fn step(
        self: *MuonOptimizer,
        tensor_idx: usize,
        weights_2d: []f32,
        grads_2d: []const f32,
        rows: usize,
        cols: usize,
    ) void {
        std.debug.assert(tensor_idx < self.states.items.len);
        std.debug.assert(weights_2d.len >= rows * cols);
        std.debug.assert(grads_2d.len >= rows * cols);

        const state = &self.states.items[tensor_idx];
        const lr = self.config.lr;
        const mu = self.config.momentum;
        const wd = self.config.weight_decay;

        for (0..rows) |r| {
            const row_offset = r * cols;
            const grad_row = grads_2d[row_offset .. row_offset + cols];
            const weight_row = weights_2d[row_offset .. row_offset + cols];
            const vel_row = state.velocity[row_offset .. row_offset + cols];

            for (vel_row, 0..) |*v, i| {
                const g = grad_row[i];
                v.* = mu * v.* + g;
                if (wd > 0) {
                    v.* -= wd * weight_row[i];
                }
            }

            var orthogonal = tryOrthonormalize(vel_row);

            const update_base = if (self.config.nesterov)
                mu * vel_row
            else
                vel_row;

            for (weight_row, 0..) |*w, i| {
                const ns_scale = @max(std.math.sqrt(@as(f32, @floatFromInt(cols))), 1.0);
                w.* -= lr * (update_base[i] + orthogonal[i]) / ns_scale;
            }
        }

        state.step_count += 1;
    }
};

fn tryOrthonormalize(vec: []f32) []f32 {
    newtonSchulzIteration5(vec);
    return vec;
}

pub fn newtonSchulzIteration5(vec: []f32) void {
    var x: f32 = 0;
    for (vec) |v| x += v * v;
    if (x < 1e-12) return;

    var a = x;
    for (0..5) |_| {
        const b = a * a;
        const c = (a * (2.874_279_6 - b * 0.159_983_7)) / (2.939_741_5 + b * 0.281_969_3);
        a = c;
    }

    const scale = 1.0 / @max(@sqrt(a), 1e-8);
    for (vec) |*v| v.* *= scale;
}

pub fn newtonSchulz3x3(matrix: []f32, n: usize) void {
    for (0..5) |_| {
        var xt: [9]f32 = undefined;
        for (0..n) |i| {
            for (0..n) |j| {
                xt[i * n + j] = matrix[j * n + i];
            }
        }
        var aa: [9]f32 = undefined;
        matMul3x3(matrix, &xt, &aa, n);

        var i2: [9]f32 = undefined;
        for (0..n * n) |idx| {
            i2[idx] = if (idx % (n + 1) == 0) 2.0 else 0.0;
        }
        var half_i: [9]f32 = undefined;
        for (0..n * n) |idx| {
            half_i[idx] = if (idx % (n + 1) == 0) 0.5 else 0.0;
        }

        var correction: [9]f32 = undefined;
        matMul3x3(&i2, &aa, &correction, n);
        for (&correction) |*c| c.* *= 0.5;

        var result: [9]f32 = undefined;
        matMul3x3(&half_i, &correction, &result, n);
        for (0..n * n) |idx| {
            matrix[idx] = result[idx];
        }
    }
}

fn matMul3x3(a: []const f32, b: []const f32, out: []f32, n: usize) void {
    for (0..n) |i| {
        for (0..n) |j| {
            var s: f32 = 0;
            for (0..n) |k| {
                s += a[i * n + k] * b[k * n + j];
            }
            out[i * n + j] = s;
        }
    }
}

pub const AdamWState = struct {
    m: []f32,
    v: []f32,
    step_count: u32,

    pub fn init(allocator: std.mem.Allocator, num_params: usize) !AdamWState {
        const m = try allocator.alloc(f32, num_params);
        const v = try allocator.alloc(f32, num_params);
        @memset(m, 0);
        @memset(v, 0);
        return .{ .m = m, .v = v, .step_count = 0 };
    }

    pub fn deinit(self: *AdamWState, allocator: std.mem.Allocator) void {
        allocator.free(self.m);
        allocator.free(self.v);
    }
};

pub const HybridMuonAdamW = struct {
    muon: MuonOptimizer,
    adamw_lr: f32 = 3e-4,
    adamw_beta1: f32 = 0.9,
    adamw_beta2: f32 = 0.999,
    adamw_eps: f32 = 1e-8,
    adamw_wd: f32 = 0.1,
    adamw_states: std.ArrayList(AdamWState),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, muon_config: MuonConfig) HybridMuonAdamW {
        return .{
            .muon = MuonOptimizer.init(allocator, muon_config),
            .adamw_states = std.ArrayList(AdamWState).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *HybridMuonAdamW) void {
        self.muon.deinit();
        for (self.adamw_states.items) |*s| s.deinit(self.allocator);
        self.adamw_states.deinit();
    }

    pub fn register2D(self: *HybridMuonAdamW, num_params: usize) !usize {
        return self.muon.registerTensor(num_params);
    }

    pub fn register1D(self: *HybridMuonAdamW, num_params: usize) !usize {
        const state = try AdamWState.init(self.allocator, num_params);
        const idx = self.adamw_states.items.len;
        try self.adamw_states.append(state);
        return idx;
    }

    pub fn stepAdamW(
        self: *HybridMuonAdamW,
        tensor_idx: usize,
        params: []f32,
        grads: []const f32,
    ) void {
        std.debug.assert(tensor_idx < self.adamw_states.items.len);
        const state = &self.adamw_states.items[tensor_idx];
        state.step_count += 1;
        const t = @as(f32, @floatFromInt(state.step_count));
        const bias_corr1 = 1.0 - std.math.pow(f32, self.adamw_beta1, t);
        const bias_corr2 = 1.0 - std.math.pow(f32, self.adamw_beta2, t);

        for (params, grads, 0..) |*p, g, i| {
            state.m[i] = self.adamw_beta1 * state.m[i] + (1.0 - self.adamw_beta1) * g;
            state.v[i] = self.adamw_beta2 * state.v[i] + (1.0 - self.adamw_beta2) * g * g;
            const m_hat = state.m[i] / bias_corr1;
            const v_hat = state.v[i] / bias_corr2;
            p.* -= self.adamw_lr * (m_hat / (std.math.sqrt(v_hat) + self.adamw_eps) + self.adamw_wd * p.*);
        }
    }
};

test "Newton-Schulz 5-iteration normalizes vector" {
    var vec = [_]f32{ 3.0, 4.0 };
    newtonSchulzIteration5(&vec);

    var norm: f32 = 0;
    for (vec) |v| norm += v * v;
    norm = std.math.sqrt(norm);
    try std.testing.expect(@abs(norm - 1.0) < 0.01);
}

test "Newton-Schulz handles zero vector" {
    var vec = [_]f32{ 0.0, 0.0, 0.0 };
    newtonSchulzIteration5(&vec);
    for (vec) |v| try std.testing.expect(v == 0.0);
}

test "Newton-Schulz preserves direction" {
    const original = [_]f32{ 1.0, 2.0, 3.0 };
    var vec = original;
    newtonSchulzIteration5(&vec);

    const cross = original[0] * vec[1] - original[1] * vec[0];
    try std.testing.expect(@abs(cross) < 0.1);
}

test "MuonOptimizer updates 2D weights" {
    const allocator = std.testing.allocator;
    var opt = MuonOptimizer.init(allocator, .{ .lr = 0.01, .ns_iterations = 5 });
    defer opt.deinit();

    const rows: usize = 2;
    const cols: usize = 3;
    var weights = [_]f32{ 1.0, 0.5, -0.3, 0.8, -0.1, 0.2 };
    const grads = [_]f32{ 0.1, -0.2, 0.3, -0.1, 0.2, -0.3 };

    const idx = try opt.registerTensor(rows * cols);
    opt.step(idx, &weights, &grads, rows, cols);

    for (weights) |w| {
        try std.testing.expect(std.math.isFinite(w));
    }
}

test "AdamW step reduces parameter magnitude with weight decay" {
    const allocator = std.testing.allocator;
    var hybrid = HybridMuonAdamW.init(allocator, .{ .lr = 0.01 });
    defer hybrid.deinit();

    var params = [_]f32{ 1.0, 2.0, 3.0 };
    const grads = [_]f32{ 0.1, 0.1, 0.1 };

    const idx = try hybrid.register1D(params.len);
    for (0..10) |_| {
        hybrid.stepAdamW(idx, &params, &grads);
    }

    try std.testing.expect(params[0] < 1.0);
    try std.testing.expect(params[1] < 2.0);
}

test "Hybrid optimizer handles both 1D and 2D tensors" {
    const allocator = std.testing.allocator;
    var hybrid = HybridMuonAdamW.init(allocator, .{ .lr = 0.01 });
    defer hybrid.deinit();

    const idx_2d = try hybrid.register2D(6);
    const idx_1d = try hybrid.register1D(3);

    var weights_2d = [_]f32{ 1.0, 0.5, -0.3, 0.8, -0.1, 0.2 };
    const grads_2d = [_]f32{ 0.1, -0.2, 0.3, -0.1, 0.2, -0.3 };
    var params_1d = [_]f32{ 1.0, 0.0, -1.0 };
    const grads_1d = [_]f32{ 0.5, 0.5, 0.5 };

    hybrid.muon.step(idx_2d, &weights_2d, &grads_2d, 2, 3);
    hybrid.stepAdamW(idx_1d, &params_1d, &grads_1d);

    for (weights_2d) |w| try std.testing.expect(std.math.isFinite(w));
    for (params_1d) |p| try std.testing.expect(std.math.isFinite(p));
}
