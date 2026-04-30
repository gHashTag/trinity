const std = @import("std");

pub const STEConfig = struct {
    init_temperature: f32 = 5.0,
    final_temperature: f32 = 0.1,
    anneal_steps: u32 = 10000,
};

pub const StraightThroughEstimator = struct {
    temperature: f32,
    config: STEConfig,
    step_count: u32,

    pub fn init(config: STEConfig) StraightThroughEstimator {
        return .{
            .temperature = config.init_temperature,
            .config = config,
            .step_count = 0,
        };
    }

    pub fn step(self: *StraightThroughEstimator) f32 {
        self.step_count += 1;
        const progress = @min(
            @as(f32, @floatFromInt(self.step_count)) /
                @as(f32, @floatFromInt(self.config.anneal_steps)),
            1.0,
        );
        const cosine = 0.5 * (1.0 + std.math.cos(std.math.pi * progress));
        self.temperature = self.config.final_temperature +
            (self.config.init_temperature - self.config.final_temperature) * cosine;
        return self.temperature;
    }

    pub fn softTernarize(self: *const StraightThroughEstimator, x: f32) f32 {
        const t = self.temperature;
        const p = sigmoid(x / t);
        const n = sigmoid(-x / t);
        return p - n;
    }

    pub fn forward(self: *const StraightThroughEstimator, weights: []const f32, output: []f32) void {
        for (weights, output) |w, *o| {
            o.* = self.softTernarize(w);
        }
    }

    pub fn hardTernarize(self: *const StraightThroughEstimator, weights: []const f32, output: []i8) void {
        const threshold = @max(self.temperature * 0.1, 0.01);
        for (weights, output) |w, *o| {
            o.* = if (w > threshold) 1 else if (w < -threshold) -1 else 0;
        }
    }

    pub fn gradient(self: *const StraightThroughEstimator, x: f32) f32 {
        const t = self.temperature;
        const abs_x_t = @abs(x) / t;
        if (abs_x_t > 5.0) return 0.0;
        const g = sigmoid(x / t);
        return g * (1.0 - g) / t;
    }
};

fn sigmoid(x: f32) f32 {
    if (x > 20.0) return 1.0;
    if (x < -20.0) return 0.0;
    return 1.0 / (1.0 + std.math.exp(-x));
}

pub const EMAConfig = struct {
    decay: f32 = 0.999,
    warmup_steps: u32 = 100,
};

pub const EMAShadow = struct {
    shadow: []f32,
    config: EMAConfig,
    step_count: u32,

    pub fn init(allocator: std.mem.Allocator, num_params: usize, config: EMAConfig) !EMAShadow {
        const shadow = try allocator.alloc(f32, num_params);
        @memset(shadow, 0);
        return .{
            .shadow = shadow,
            .config = config,
            .step_count = 0,
        };
    }

    pub fn deinit(self: *EMAShadow, allocator: std.mem.Allocator) void {
        allocator.free(self.shadow);
    }

    pub fn update(self: *EMAShadow, params: []const f32) void {
        self.step_count += 1;
        const effective_decay = if (self.step_count < self.config.warmup_steps)
            std.math.clamp(
                self.config.decay * (1.0 - std.math.pow(f32, 1.0 - self.config.decay, @floatFromInt(self.step_count))),
                0.0,
                self.config.decay,
            )
        else
            self.config.decay;

        for (self.shadow, params) |*s, p| {
            s.* = effective_decay * s.* + (1.0 - effective_decay) * p;
        }
    }

    pub fn copyTo(self: *const EMAShadow, output: []f32) void {
        @memcpy(output[0..self.shadow.len], self.shadow);
    }
};

pub const BFloat16 = packed struct {
    mantissa: u7 = 0,
    exponent: u8 = 0,
    sign: u1 = 0,

    pub fn fromF32(val: f32) BFloat16 {
        const bits: u32 = @bitCast(val);
        const sign: u1 = @truncate(bits >> 31);
        const exponent: u8 = @truncate(bits >> 23);
        const mantissa: u7 = @truncate(bits >> 16);
        return .{ .sign = sign, .exponent = exponent, .mantissa = mantissa };
    }

    pub fn toF32(self: BFloat16) f32 {
        const bits: u32 = (@as(u32, self.sign) << 31) |
            (@as(u32, self.exponent) << 23) |
            (@as(u32, self.mantissa) << 16);
        return @bitCast(bits);
    }
};

pub const BFloat16Accumulator = struct {
    shadow_bf16: []BFloat16,
    shadow_f32: []f32,
    num_params: usize,

    pub fn init(allocator: std.mem.Allocator, num_params: usize) !BFloat16Accumulator {
        const bf16 = try allocator.alloc(BFloat16, num_params);
        const f32_buf = try allocator.alloc(f32, num_params);
        @memset(bf16, .{});
        @memset(f32_buf, 0);
        return .{
            .shadow_bf16 = bf16,
            .shadow_f32 = f32_buf,
            .num_params = num_params,
        };
    }

    pub fn deinit(self: *BFloat16Accumulator, allocator: std.mem.Allocator) void {
        allocator.free(self.shadow_bf16);
        allocator.free(self.shadow_f32);
    }

    pub fn accumulateGradients(self: *BFloat16Accumulator, grads: []const f32) void {
        for (self.shadow_f32, grads) |*s, g| {
            s.* += g;
        }
    }

    pub fn quantizeShadow(self: *BFloat16Accumulator) void {
        for (self.shadow_bf16, self.shadow_f32) |*bf, *f| {
            bf.* = BFloat16.fromF32(f.*);
            f.* = bf.toF32();
        }
    }

    pub fn getShadow(self: *const BFloat16Accumulator) []const f32 {
        return self.shadow_f32;
    }
};

pub const RMSNorm = struct {
    dim: usize,
    eps: f32 = 1e-8,

    pub fn init(dim: usize) RMSNorm {
        return .{ .dim = dim };
    }

    pub fn forward(self: *const RMSNorm, input: []const f32, output: []f32) void {
        var sum_sq: f32 = 0;
        for (input[0..self.dim]) |x| sum_sq += x * x;
        const rms = std.math.sqrt(sum_sq / @as(f32, @floatFromInt(self.dim)) + self.eps);
        const inv_rms = 1.0 / rms;
        for (input[0..self.dim], output[0..self.dim]) |x, *o| {
            o.* = x * inv_rms;
        }
    }
};

test "STE temperature anneals correctly" {
    var ste = StraightThroughEstimator.init(.{
        .init_temperature = 5.0,
        .final_temperature = 0.1,
        .anneal_steps = 100,
    });

    const t0 = ste.temperature;
    for (0..100) |_| {
        _ = ste.step();
    }
    try std.testing.expect(ste.temperature < t0);
    try std.testing.expect(ste.temperature >= 0.09);
}

test "STE soft ternarize" {
    var ste = StraightThroughEstimator.init(.{ .init_temperature = 1.0 });

    const p = ste.softTernarize(5.0);
    const n = ste.softTernarize(-5.0);
    const z = ste.softTernarize(0.0);

    try std.testing.expect(p > 0.9);
    try std.testing.expect(n < -0.9);
    try std.testing.expect(@abs(z) < 0.01);
}

test "STE gradient nonzero in transition region" {
    var ste = StraightThroughEstimator.init(.{ .init_temperature = 1.0 });

    const g = ste.gradient(0.5);
    try std.testing.expect(g > 0);
    try std.testing.expect(g < 1.0);
}

test "EMA shadow tracks weights" {
    const allocator = std.testing.allocator;
    var ema = try EMAShadow.init(allocator, 3, .{ .decay = 0.99 });
    defer ema.deinit(allocator);

    const params = [_]f32{ 1.0, 2.0, 3.0 };
    for (0..100) |_| {
        ema.update(&params);
    }

    try std.testing.expect(ema.shadow[0] > 0.9);
    try std.testing.expect(ema.shadow[1] > 1.9);
    try std.testing.expect(ema.shadow[2] > 2.9);
}

test "BFloat16 roundtrip" {
    const bf = BFloat16.fromF32(1.5);
    const back = bf.toF32();
    try std.testing.expect(@abs(back - 1.5) < 0.01);
}

test "BFloat16 accumulator" {
    const allocator = std.testing.allocator;
    var acc = try BFloat16Accumulator.init(allocator, 4);
    defer acc.deinit(allocator);

    acc.accumulateGradients(&[_]f32{ 0.1, 0.2, 0.3, 0.4 });
    acc.accumulateGradients(&[_]f32{ 0.1, 0.2, 0.3, 0.4 });
    acc.quantizeShadow();

    const shadow = acc.getShadow();
    for (shadow) |s| {
        try std.testing.expect(std.math.isFinite(s));
    }
}

test "RMSNorm output has unit norm" {
    const norm = RMSNorm.init(4);
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var output: [4]f32 = undefined;
    norm.forward(&input, &output);

    var rms: f32 = 0;
    for (output) |o| rms += o * o;
    rms = std.math.sqrt(rms / 4.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), rms, 0.05);
}
