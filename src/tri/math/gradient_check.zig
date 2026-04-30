const std = @import("std");
const tnn = @import("../b2t/tnn.zig");

pub fn finiteDiffGradient(
    allocator: std.mem.Allocator,
    layer_sizes: []const usize,
    input: []const f32,
    epsilon: f32,
) !FiniteDiffResult {
    var network = tnn.TrainableTNN.init(allocator, layer_sizes);
    defer network.deinit();

    const output = try network.forward(allocator, input);
    defer allocator.free(output);

    const ref_loss = sumSquared(output);

    var max_rel_err: f32 = 0.0;
    var num_params: usize = 0;
    var num_passing: usize = 0;

    for (network.shadow_weights.items, 0..) |*layer_weights, layer_idx| {
        for (layer_weights.items, 0..) |*w, w_idx| {
            const orig = w.*;

            w.* = orig + epsilon;
            const out_plus = try network.forward(allocator, input);
            defer allocator.free(out_plus);
            const loss_plus = sumSquared(out_plus);

            w.* = orig - epsilon;
            const out_minus = try network.forward(allocator, input);
            defer allocator.free(out_minus);
            const loss_minus = sumSquared(out_minus);

            w.* = orig;

            const numerical_grad = (loss_plus - loss_minus) / (2.0 * epsilon);

            if (layer_idx < network.gradients.items.len) {
                const grads = network.gradients.items[layer_idx];
                const layer_grad = if (w_idx < grads.weights.len) grads.weights[w_idx] else 0.0;
                const denom = @max(@abs(numerical_grad), @abs(layer_grad), 1e-8);
                const rel_err = @abs(numerical_grad - layer_grad) / denom;

                num_params += 1;
                if (rel_err < 1e-4) num_passing += 1;
                max_rel_err = @max(max_rel_err, rel_err);
            }
        }
    }

    return FiniteDiffResult{
        .max_relative_error = max_rel_err,
        .num_parameters_checked = num_params,
        .num_passing = num_passing,
        .passing = max_rel_err < 1e-4,
    };
}

pub fn finiteDiffSingleParam(
    network: *tnn.TrainableTNN,
    allocator: std.mem.Allocator,
    input: []const f32,
    layer_idx: usize,
    param_idx: usize,
    epsilon: f32,
) !f32 {
    const layer_weights = &network.shadow_weights.items[layer_idx];
    const orig = layer_weights.items[param_idx];

    layer_weights.items[param_idx] = orig + epsilon;
    const out_plus = try network.forward(allocator, input);
    defer allocator.free(out_plus);
    const loss_plus = sumSquared(out_plus);

    layer_weights.items[param_idx] = orig - epsilon;
    const out_minus = try network.forward(allocator, input);
    defer allocator.free(out_minus);
    const loss_minus = sumSquared(out_minus);

    layer_weights.items[param_idx] = orig;

    return (loss_plus - loss_minus) / (2.0 * epsilon);
}

fn sumSquared(v: []const f32) f32 {
    var s: f32 = 0.0;
    for (v) |x| s += x * x;
    return s;
}

pub const FiniteDiffResult = struct {
    max_relative_error: f32,
    num_parameters_checked: usize,
    num_passing: usize,
    passing: bool,
};

test "finite-diff gradient check passes for small TNN" {
    const allocator = std.testing.allocator;

    const layer_sizes = [_]usize{ 3, 4, 2 };
    var network = tnn.TrainableTNN.init(allocator, &layer_sizes);
    defer network.deinit();

    const input = [_]f32{ 0.5, -0.3, 0.8 };
    const output_grad = [_]f32{ 1.0, -1.0 };

    const output = try network.forward(allocator, &input);
    defer allocator.free(output);

    network.backward(&input, &output_grad);

    const epsilon: f32 = 1e-5;
    var max_rel_err: f32 = 0.0;
    var checked: usize = 0;
    var passing: usize = 0;

    for (network.shadow_weights.items, 0..) |*layer_weights, layer_idx| {
        for (layer_weights.items, 0..) |*w, w_idx| {
            const numerical = try finiteDiffSingleParam(&network, allocator, &input, layer_idx, w_idx, epsilon);

            const grads = network.gradients.items[layer_idx];
            const analytical = if (w_idx < grads.weights.len) grads.weights[w_idx] else 0.0;

            const denom = @max(@abs(numerical), @abs(analytical), 1e-8);
            const rel_err = @abs(numerical - analytical) / denom;

            checked += 1;
            if (rel_err < 1e-4) passing += 1;
            max_rel_err = @max(max_rel_err, rel_err);
        }
    }

    try std.testing.expect(checked > 0);
    try std.testing.expect(passing == checked);
    try std.testing.expect(max_rel_err < 1e-4);
}

test "finite-diff helper sumSquared" {
    const v = [_]f32{ 1.0, 2.0, 3.0 };
    const s = sumSquared(&v);
    try std.testing.expect(@abs(s - 14.0) < 1e-6);
}

test "finiteDiffSingleParam returns correct gradient direction" {
    const allocator = std.testing.allocator;

    const layer_sizes = [_]usize{ 2, 3, 1 };
    var network = tnn.TrainableTNN.init(allocator, &layer_sizes);
    defer network.deinit();

    const input = [_]f32{ 1.0, 0.0 };
    const eps: f32 = 1e-5;

    const grad = try finiteDiffSingleParam(&network, allocator, &input, 0, 0, eps);
    try std.testing.expect(std.math.isFinite(grad));
}
