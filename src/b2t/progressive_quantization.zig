const std = @import("std");

pub const QuantizationStage = enum {
    fp32_warmup,
    fp16_transition,
    ternary_anneal,
    full_ternary,
};

pub const ScheduleConfig = struct {
    warmup_steps: u32 = 1000,
    transition_steps: u32 = 2000,
    anneal_steps: u32 = 3000,
    init_threshold: f32 = 1.0,
    final_threshold: f32 = 0.05,
};

pub const ProgressiveQuantizer = struct {
    allocator: std.mem.Allocator,
    config: ScheduleConfig,
    current_step: u32,
    stage: QuantizationStage,
    threshold: f32,

    pub fn init(allocator: std.mem.Allocator, config: ScheduleConfig) ProgressiveQuantizer {
        return .{
            .allocator = allocator,
            .config = config,
            .current_step = 0,
            .stage = .fp32_warmup,
            .threshold = config.init_threshold,
        };
    }

    pub fn step(self: *ProgressiveQuantizer) QuantizationStage {
        self.current_step += 1;
        const s = self.current_step;

        if (s <= self.config.warmup_steps) {
            self.stage = .fp32_warmup;
        } else if (s <= self.config.warmup_steps + self.config.transition_steps) {
            self.stage = .fp16_transition;
            const progress = @as(f32, @floatFromInt(s - self.config.warmup_steps)) /
                @as(f32, @floatFromInt(self.config.transition_steps));
            self.threshold = self.config.init_threshold - progress * (self.config.init_threshold - self.config.final_threshold) * 0.5;
        } else if (s <= self.config.warmup_steps + self.config.transition_steps + self.config.anneal_steps) {
            self.stage = .ternary_anneal;
            const progress = @as(f32, @floatFromInt(s - self.config.warmup_steps - self.config.transition_steps)) /
                @as(f32, @floatFromInt(self.config.anneal_steps));
            self.threshold = (self.config.init_threshold + self.config.final_threshold) * 0.5 -
                progress * (self.config.init_threshold * 0.5 - self.config.final_threshold);
            self.threshold = @max(self.threshold, self.config.final_threshold);
        } else {
            self.stage = .full_ternary;
            self.threshold = self.config.final_threshold;
        }

        return self.stage;
    }

    pub fn quantizeWeights(self: *const ProgressiveQuantizer, weights: []f32, temp: f32) void {
        switch (self.stage) {
            .fp32_warmup => {},
            .fp16_transition => {
                const scale = @as(f32, @floatFromInt(1 << 10));
                for (weights) |*w| {
                    w.* = @round(w.* * scale) / scale;
                }
            },
            .ternary_anneal => {
                const mix = self.ternaryMixRatio();
                for (weights) |*w| {
                    if (mix > 0) {
                        const ternary_val: f32 = if (w.* > self.threshold) 1.0 else if (w.* < -self.threshold) -1.0 else 0.0;
                        if (@abs(w.*) > self.threshold * (1.0 + temp)) {
                            w.* = ternary_val;
                        }
                    }
                }
            },
            .full_ternary => {
                for (weights) |*w| {
                    w.* = if (w.* > self.threshold) 1.0 else if (w.* < -self.threshold) -1.0 else 0.0;
                }
            },
        }
    }

    pub fn ternaryMixRatio(self: *const ProgressiveQuantizer) f32 {
        return switch (self.stage) {
            .fp32_warmup => 0.0,
            .fp16_transition => 0.1,
            .ternary_anneal => 0.5,
            .full_ternary => 1.0,
        };
    }

    pub fn quantizationLossWeight(self: *const ProgressiveQuantizer) f32 {
        return switch (self.stage) {
            .fp32_warmup => 0.0,
            .fp16_transition => 0.01,
            .ternary_anneal => 0.1,
            .full_ternary => 1.0,
        };
    }

    pub fn progress(self: *const ProgressiveQuantizer) f32 {
        const total = self.config.warmup_steps + self.config.transition_steps + self.config.anneal_steps;
        return @min(@as(f32, @floatFromInt(self.current_step)) / @as(f32, @floatFromInt(total)), 1.0);
    }
};

test "progressive stages advance correctly" {
    var pq = ProgressiveQuantizer.init(std.testing.allocator, .{
        .warmup_steps = 10,
        .transition_steps = 10,
        .anneal_steps = 10,
    });

    for (0..10) |_| {
        try std.testing.expectEqual(QuantizationStage.fp32_warmup, pq.step());
    }
    for (0..10) |_| {
        try std.testing.expectEqual(QuantizationStage.fp16_transition, pq.step());
    }
    for (0..10) |_| {
        try std.testing.expectEqual(QuantizationStage.ternary_anneal, pq.step());
    }
    try std.testing.expectEqual(QuantizationStage.full_ternary, pq.step());
}

test "fp32 warmup does not modify weights" {
    var pq = ProgressiveQuantizer.init(std.testing.allocator, .{ .warmup_steps = 5 });
    _ = pq.step();

    var weights = [_]f32{ 0.123456789, -0.987654321 };
    pq.quantizeWeights(&weights, 0.0);
    try std.testing.expect(weights[0] != @as(f32, @round(weights[0])));
}

test "full ternary quantizes to {-1, 0, 1}" {
    var pq = ProgressiveQuantizer.init(std.testing.allocator, .{
        .warmup_steps = 0,
        .transition_steps = 0,
        .anneal_steps = 0,
    });
    _ = pq.step();

    var weights = [_]f32{ 0.5, -0.5, 0.01, -0.01, 0.0 };
    pq.quantizeWeights(&weights, 0.0);

    try std.testing.expectEqual(@as(f32, 1.0), weights[0]);
    try std.testing.expectEqual(@as(f32, -1.0), weights[1]);
    try std.testing.expectEqual(@as(f32, 0.0), weights[2]);
    try std.testing.expectEqual(@as(f32, 0.0), weights[3]);
}

test "progress tracking" {
    var pq = ProgressiveQuantizer.init(std.testing.allocator, .{
        .warmup_steps = 10,
        .transition_steps = 10,
        .anneal_steps = 10,
    });

    for (0..15) |_| {
        _ = pq.step();
    }
    const p = pq.progress();
    try std.testing.expect(p > 0.0);
    try std.testing.expect(p < 1.0);
}

test "quantization loss weight increases" {
    var pq = ProgressiveQuantizer.init(std.testing.allocator, .{
        .warmup_steps = 5,
        .transition_steps = 5,
        .anneal_steps = 5,
    });

    const w0 = pq.quantizationLossWeight();
    for (0..6) |_| _ = pq.step();
    const w1 = pq.quantizationLossWeight();
    for (0..6) |_| _ = pq.step();
    const w2 = pq.quantizationLossWeight();
    for (0..6) |_| _ = pq.step();
    const w3 = pq.quantizationLossWeight();

    try std.testing.expect(w0 < w1);
    try std.testing.expect(w1 < w2);
    try std.testing.expect(w2 < w3);
}
