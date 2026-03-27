//! tri/perceptron — Binary classifier
//! TTT Dogfood v0.2 Stage 282

const std = @import("std");

pub const Perceptron = struct {
    weights: []f64,
    learning_rate: f64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, inputs: usize, lr: f64) !Perceptron {
        const weights = try allocator.alloc(f64, inputs);
        @memset(weights, 0);
        return .{
            .weights = weights,
            .learning_rate = lr,
            .allocator = allocator,
        };
    }

    pub fn predict(perceptron: *const Perceptron, inputs: []const f64) i32 {
        var sum: f64 = 0;
        for (inputs, 0..) |inp, i| {
            if (i < perceptron.weights.len) {
                sum += inp * perceptron.weights[i];
            }
        }
        return if (sum >= 0) 1 else 0;
    }

    pub fn train(perceptron: *Perceptron, inputs: []const f64, target: i32) !void {
        const guess = perceptron.predict(inputs);
        const diff = @as(f64, @floatFromInt(target - guess));
        for (inputs, 0..) |inp, i| {
            if (i < perceptron.weights.len) {
                perceptron.weights[i] += perceptron.learning_rate * diff * inp;
            }
        }
    }

    pub fn deinit(perceptron: *Perceptron) void {
        perceptron.allocator.free(perceptron.weights);
    }
};

test "perceptron" {
    var p = try Perceptron.init(std.testing.allocator, 2, 0.1);
    defer p.deinit();
    try p.train(&[_]f64{ 1, 1 }, 1);
    try std.testing.expect(p.predict(&[_]f64{ 1, 1 }) == 1);
}
