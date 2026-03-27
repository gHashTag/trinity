//! tri/neuron — Single neuron unit
//! TTT Dogfood v0.2 Stage 281

const std = @import("std");

pub const Neuron = struct {
    weights: []f64,
    bias: f64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, inputs: usize) !Neuron {
        const weights = try allocator.alloc(f64, inputs);
        @memset(weights, 0);
        return .{
            .weights = weights,
            .bias = 0,
            .allocator = allocator,
        };
    }

    pub fn forward(neuron: *const Neuron, inputs: []const f64) f64 {
        var sum: f64 = neuron.bias;
        for (inputs, 0..) |inp, i| {
            if (i < neuron.weights.len) {
                sum += inp * neuron.weights[i];
            }
        }
        return sum;
    }

    pub fn deinit(neuron: *Neuron) void {
        neuron.allocator.free(neuron.weights);
    }
};

test "neuron" {
    var n = try Neuron.init(std.testing.allocator, 3);
    defer n.deinit();
    n.bias = 0.5;
    const result = n.forward(&[_]f64{1, 1, 1});
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), result, 0.001);
}
