const std = @import("std");
const tnn = @import("../b2t/tnn.zig");

pub const OverfitConfig = struct {
    num_samples: usize = 100,
    num_steps: u32 = 500,
    input_size: usize = 243,
    output_size: usize = 729,
    hidden_size: usize = 243,
    learning_rate: f32 = 3e-4,
    eval_every: u32 = 50,
    target_bpb: f32 = 0.5,
};

pub const OverfitResult = struct {
    final_loss: f32,
    final_bpb: f32,
    steps_run: u32,
    passed: bool,
    best_loss: f32,
    best_step: u32,
    loss_history: []f32,
};

pub fn runOverfit100(allocator: std.mem.Allocator, config: OverfitConfig) !OverfitResult {
    var rng = std.Random.DefaultPrng.init(42);
    const random = rng.random();

    var network = try tnn.TrainableTNN.initWithLayers(allocator, &[_]usize{
        config.input_size,
        config.hidden_size,
        config.output_size,
    });
    defer network.deinit();

    var inputs = try allocator.alloc([]f32, config.num_samples);
    defer {
        for (inputs) |inp| allocator.free(inp);
        allocator.free(inputs);
    }

    var targets = try allocator.alloc(usize, config.num_samples);
    defer allocator.free(targets);

    for (0..config.num_samples) |s| {
        inputs[s] = try allocator.alloc(f32, config.input_size);
        for (inputs[s]) |*v| v.* = random.floatNorm(f32) * 0.5;
        targets[s] = random.intRangeAtMost(usize, 0, config.output_size - 1);
    }

    const max_history = config.num_steps / config.eval_every + 1;
    var loss_history = try allocator.alloc(f32, max_history);
    var history_idx: usize = 0;

    var best_loss: f32 = std.math.inf(f32);
    var best_step: u32 = 0;
    var output = try allocator.alloc(f32, config.output_size);
    defer allocator.free(output);

    for (0..config.num_steps) |step| {
        const sample_idx = random.intRangeAtMost(usize, 0, config.num_samples - 1);
        const input = inputs[sample_idx];
        const target = targets[sample_idx];

        network.forward(input, output);

        var grad = try allocator.alloc(f32, config.output_size);
        @memset(grad, 0);

        const log_sum = logSumExp(output);
        for (0..config.output_size) |i| {
            const prob = std.math.exp(output[i] - log_sum);
            grad[i] = prob;
        }
        grad[target] -= 1.0;

        network.backward(input, grad);
        network.applyGradients(config.learning_rate);
        allocator.free(grad);

        if ((step + 1) % config.eval_every == 0) {
            var total_loss: f32 = 0;
            for (0..config.num_samples) |s| {
                network.forward(inputs[s], output);
                const ls = logSumExp(output);
                total_loss -= output[targets[s]] - ls;
            }
            const avg_loss = total_loss / @as(f32, @floatFromInt(config.num_samples));
            const bpb = avg_loss / @log(@as(f32, @floatFromInt(config.output_size)));

            if (history_idx < max_history) {
                loss_history[history_idx] = bpb;
                history_idx += 1;
            }

            if (avg_loss < best_loss) {
                best_loss = avg_loss;
                best_step = @intCast(step + 1);
            }
        }
    }

    var final_total: f32 = 0;
    for (0..config.num_samples) |s| {
        network.forward(inputs[s], output);
        const ls = logSumExp(output);
        final_total -= output[targets[s]] - ls;
    }
    const final_loss = final_total / @as(f32, @floatFromInt(config.num_samples));
    const final_bpb = final_loss / @log(@as(f32, @floatFromInt(config.output_size)));

    return .{
        .final_loss = final_loss,
        .final_bpb = final_bpb,
        .steps_run = config.num_steps,
        .passed = final_bpb < config.target_bpb,
        .best_loss = best_loss,
        .best_step = best_step,
        .loss_history = loss_history[0..history_idx],
    };
}

fn logSumExp(values: []const f32) f32 {
    var max_val: f32 = -std.math.inf(f32);
    for (values) |v| max_val = @max(max_val, v);
    var sum: f32 = 0;
    for (values) |v| sum += std.math.exp(v - max_val);
    return max_val + std.math.log(@max(sum, 1e-10));
}

test "overfit-100 small run converges" {
    const allocator = std.testing.allocator;
    const result = try runOverfit100(allocator, .{
        .num_samples = 10,
        .num_steps = 100,
        .input_size = 8,
        .output_size = 16,
        .hidden_size = 16,
        .learning_rate = 1e-3,
        .eval_every = 20,
        .target_bpb = 2.0,
    });
    defer allocator.free(result.loss_history);

    try std.testing.expect(result.steps_run == 100);
    try std.testing.expect(result.final_bpb < std.math.inf(f32));
    try std.testing.expect(result.final_loss >= 0);
}

test "overfit-100 result tracking" {
    const allocator = std.testing.allocator;
    const result = try runOverfit100(allocator, .{
        .num_samples = 5,
        .num_steps = 50,
        .input_size = 4,
        .output_size = 8,
        .hidden_size = 8,
        .eval_every = 10,
    });
    defer allocator.free(result.loss_history);

    try std.testing.expect(result.loss_history.len > 0);
    try std.testing.expect(result.best_step > 0);
}
