const std = @import("std");

pub const TTQConfig = struct {
    init_threshold: f32 = 0.05,
    lr_threshold: f32 = 1e-4,
    min_threshold: f32 = 1e-6,
    max_threshold: f32 = 1.0,
};

pub const TTQLayer = struct {
    threshold: f32,
    grad_accumulator: f32,
    allocator: std.mem.Allocator,
    config: TTQConfig,

    pub fn init(allocator: std.mem.Allocator, config: TTQConfig) TTQLayer {
        return .{
            .threshold = config.init_threshold,
            .grad_accumulator = 0.0,
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn quantize(self: *const TTQLayer, weights: []const f32, output: [] Trit) void {
        std.debug.assert(weights.len == output.len);
        const t = self.threshold;
        for (weights, output) |w, *o| {
            o.* = if (w > t)
                .P
            else if (w < -t)
                .N
            else
                .Z;
        }
    }

    pub fn quantizeScaled(self: *const TTQLayer, weights: []const f32, output: [] Trit, scale: f32) void {
        std.debug.assert(weights.len == output.len);
        const t = self.threshold * scale;
        for (weights, output) |w, *o| {
            o.* = if (w > t)
                .P
            else if (w < -t)
                .N
            else
                .Z;
        }
    }

    pub fn computeGradient(self: *TTQLayer, weights: []const f32, upstream_grad: []const f32) f32 {
        var grad: f32 = 0.0;
        const t = self.threshold;
        const eps: f32 = 1e-6;

        for (weights, upstream_grad) |w, g| {
            const dist = @abs(w) - t;
            const soft_grad = 1.0 / (1.0 + std.math.exp(dist * 100.0));
            if (@abs(w) > eps) {
                grad += g * std.math.copysign(soft_grad, w);
            }
        }
        self.grad_accumulator += grad;
        return grad;
    }

    pub fn updateThreshold(self: *TTQLayer) void {
        self.threshold += self.config.lr_threshold * self.grad_accumulator;
        self.threshold = std.math.clamp(self.threshold, self.config.min_threshold, self.config.max_threshold);
        self.grad_accumulator = 0.0;
    }

    pub fn sparsity(self: *const TTQLayer, weights: []const f32) f32 {
        const t = self.threshold;
        var zeros: usize = 0;
        for (weights) |w| {
            if (@abs(w) <= t) zeros += 1;
        }
        return @as(f32, @floatFromInt(zeros)) / @as(f32, @floatFromInt(weights.len));
    }

    pub fn effectiveBits(self: *const TTQLayer, weights: []const f32) f32 {
        const s = self.sparsity(weights);
        const p_nonzero = 1.0 - s;
        if (p_nonzero == 0) return 0;
        const entropy = -p_nonzero * std.math.log2(p_nonzero) - s * std.math.log2(@max(s, 1e-10));
        return entropy;
    }
};

pub const Trit = enum(i8) { P = 1, Z = 0, N = -1 };

pub const TTQNetwork = struct {
    allocator: std.mem.Allocator,
    layers: std.ArrayList(TTQLayer),
    config: TTQConfig,

    pub fn init(allocator: std.mem.Allocator, config: TTQConfig) TTQNetwork {
        return .{
            .allocator = allocator,
            .layers = std.ArrayList(TTQLayer).init(allocator),
            .config = config,
        };
    }

    pub fn deinit(self: *TTQNetwork) void {
        self.layers.deinit();
    }

    pub fn addLayer(self: *TTQNetwork) !usize {
        const idx = self.layers.items.len;
        try self.layers.append(TTQLayer.init(self.allocator, self.config));
        return idx;
    }

    pub fn updateAllThresholds(self: *TTQNetwork) void {
        for (self.layers.items) |*layer| {
            layer.updateThreshold();
        }
    }

    pub fn averageSparsity(self: *const TTQNetwork, all_weights: []const []const f32) f32 {
        var total: f32 = 0;
        for (self.layers.items, all_weights) |layer, weights| {
            total += layer.sparsity(weights);
        }
        return total / @as(f32, @floatFromInt(self.layers.items.len));
    }
};

test "TTQ quantize basic" {
    const config = TTQConfig{ .init_threshold = 0.3 };
    var layer = TTQLayer.init(std.testing.allocator, config);

    const weights = [_]f32{ 0.5, -0.5, 0.1, -0.1, 0.0 };
    var output: [5]Trit = undefined;
    layer.quantize(&weights, &output);

    try std.testing.expectEqual(Trit.P, output[0]);
    try std.testing.expectEqual(Trit.N, output[1]);
    try std.testing.expectEqual(Trit.Z, output[2]);
    try std.testing.expectEqual(Trit.Z, output[3]);
    try std.testing.expectEqual(Trit.Z, output[4]);
}

test "TTQ threshold update" {
    var layer = TTQLayer.init(std.testing.allocator, .{ .init_threshold = 0.1, .lr_threshold = 0.01 });

    const weights = [_]f32{ 0.5, -0.5, 0.3 };
    const grads = [_]f32{ 1.0, 1.0, 1.0 };

    _ = layer.computeGradient(&weights, &grads);
    const before = layer.threshold;
    layer.updateThreshold();
    try std.testing.expect(layer.threshold != before);
}

test "TTQ sparsity calculation" {
    var layer = TTQLayer.init(std.testing.allocator, .{ .init_threshold = 0.3 });

    const weights = [_]f32{ 0.5, -0.5, 0.1, -0.1, 0.0 };
    const s = layer.sparsity(&weights);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), s, 1e-6);
}

test "TTQ scaled quantize" {
    var layer = TTQLayer.init(std.testing.allocator, .{ .init_threshold = 0.1 });

    const weights = [_]f32{ 0.15, -0.15, 0.05, -0.05 };
    var output: [4]Trit = undefined;
    layer.quantizeScaled(&weights, &output, 2.0);

    try std.testing.expectEqual(Trit.Z, output[0]);
    try std.testing.expectEqual(Trit.Z, output[1]);
    try std.testing.expectEqual(Trit.Z, output[2]);
    try std.testing.expectEqual(Trit.Z, output[3]);
}

test "TTQ network multi-layer" {
    var net = TTQNetwork.init(std.testing.allocator, .{});
    defer net.deinit();

    const idx1 = try net.addLayer();
    const idx2 = try net.addLayer();
    try std.testing.expectEqual(@as(usize, 0), idx1);
    try std.testing.expectEqual(@as(usize, 1), idx2);
    try std.testing.expectEqual(@as(usize, 2), net.layers.items.len);
}

test "TTQ effective bits" {
    var layer = TTQLayer.init(std.testing.allocator, .{ .init_threshold = 0.3 });
    const weights = [_]f32{ 0.5, -0.5, 0.1, -0.1, 0.0 };
    const bits = layer.effectiveBits(&weights);
    try std.testing.expect(bits > 0);
    try std.testing.expect(bits < 2.0);
}
