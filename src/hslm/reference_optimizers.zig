// @origin(manual) @regen(pending)
// HSLM Reference — Optimizer Implementations
// Migrated from archive/implementations/zig/src/optimizers.zig
// AdamW, Lion (memory-efficient), SGD with momentum

const std = @import("std");

/// Optimizer state for a single parameter group
pub fn OptimizerState(comptime T: type) type {
    return struct {
        exp_avg: []T,
        exp_avg_sq: []T,
        step: usize,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, size: usize) !Self {
            const exp_avg = try allocator.alloc(T, size);
            @memset(exp_avg, 0);
            const exp_avg_sq = try allocator.alloc(T, size);
            @memset(exp_avg_sq, 0);
            return Self{
                .exp_avg = exp_avg,
                .exp_avg_sq = exp_avg_sq,
                .step = 0,
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.exp_avg);
            allocator.free(self.exp_avg_sq);
        }
    };
}

pub const AdamWConfig = struct {
    lr: f32 = 1e-4,
    beta1: f32 = 0.9,
    beta2: f32 = 0.999,
    eps: f32 = 1e-8,
    weight_decay: f32 = 0.01,
};

pub fn adamwStep(
    params: []f32,
    grads: []const f32,
    state: *OptimizerState(f32),
    config: AdamWConfig,
) void {
    state.step += 1;
    const t = @as(f32, @floatFromInt(state.step));
    const bias_correction1 = 1.0 - std.math.pow(f32, config.beta1, t);
    const bias_correction2 = 1.0 - std.math.pow(f32, config.beta2, t);

    for (params, grads, state.exp_avg, state.exp_avg_sq) |*p, g, *m, *v| {
        m.* = config.beta1 * m.* + (1.0 - config.beta1) * g;
        v.* = config.beta2 * v.* + (1.0 - config.beta2) * g * g;
        const m_hat = m.* / bias_correction1;
        const v_hat = v.* / bias_correction2;
        p.* -= config.lr * config.weight_decay * p.*;
        p.* -= config.lr * m_hat / (@sqrt(v_hat) + config.eps);
    }
}

pub const LionConfig = struct {
    lr: f32 = 1e-4,
    beta1: f32 = 0.9,
    beta2: f32 = 0.99,
    weight_decay: f32 = 0.1,
};

pub fn lionStep(
    params: []f32,
    grads: []const f32,
    momentum: []f32,
    config: LionConfig,
) void {
    for (params, grads, momentum) |*p, g, *m| {
        p.* *= (1.0 - config.lr * config.weight_decay);
        const update = config.beta1 * m.* + (1.0 - config.beta1) * g;
        p.* -= config.lr * std.math.sign(update);
        m.* = config.beta2 * m.* + (1.0 - config.beta2) * g;
    }
}

pub const SGDConfig = struct {
    lr: f32 = 0.01,
    momentum: f32 = 0.9,
    weight_decay: f32 = 0.0,
    nesterov: bool = false,
};

pub fn sgdStep(
    params: []f32,
    grads: []const f32,
    velocity: []f32,
    config: SGDConfig,
) void {
    for (params, grads, velocity) |*p, g, *v| {
        const grad_with_wd = g + config.weight_decay * p.*;
        v.* = config.momentum * v.* + grad_with_wd;
        if (config.nesterov) {
            p.* -= config.lr * (grad_with_wd + config.momentum * v.*);
        } else {
            p.* -= config.lr * v.*;
        }
    }
}

test "adamw step" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var params = [_]f32{ 1.0, 2.0, 3.0 };
    const grads = [_]f32{ 0.1, 0.2, 0.3 };
    var state = try OptimizerState(f32).init(allocator, 3);
    defer state.deinit(allocator);

    adamwStep(&params, &grads, &state, AdamWConfig{});
    try std.testing.expect(params[0] != 1.0);
    try std.testing.expectEqual(@as(usize, 1), state.step);
}

test "lion step" {
    var params = [_]f32{ 1.0, 2.0, 3.0 };
    const grads = [_]f32{ 0.1, 0.2, 0.3 };
    var momentum = [_]f32{ 0.0, 0.0, 0.0 };
    lionStep(&params, &grads, &momentum, LionConfig{});
    try std.testing.expect(params[0] != 1.0);
    try std.testing.expect(momentum[0] != 0.0);
}
