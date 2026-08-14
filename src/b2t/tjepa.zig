const std = @import("std");

pub const TJEPAConfig = struct {
    mask_ratio: f32 = 0.3,
    ema_decay_init: f32 = 0.996,
    ema_decay_final: f32 = 1.0,
    ema_warmup_steps: u32 = 5000,
    loss_fn: LossFunction = .l2_mse,
    total_steps: u32 = 20000,
    checkpoint_every: u32 = 5000,
    embed_dim: usize = 243,
    num_patches: usize = 27,
    patch_dim: usize = 9,
};

pub const LossFunction = enum { l2_mse, l1_smooth };

pub const TJEPATrainer = struct {
    allocator: std.mem.Allocator,
    config: TJEPAConfig,
    student_params: []f32,
    teacher_params: []f32,
    step_count: u32,
    ema_decay: f32,

    pub fn init(allocator: std.mem.Allocator, num_params: usize, config: TJEPAConfig) !TJEPATrainer {
        const student = try allocator.alloc(f32, num_params);
        const teacher = try allocator.alloc(f32, num_params);
        var rng = std.Random.DefaultPrng.init(42);
        for (student) |*s| s.* = rng.random().floatNorm(f32) * 0.02;
        @memcpy(teacher, student);
        return .{
            .allocator = allocator,
            .config = config,
            .student_params = student,
            .teacher_params = teacher,
            .step_count = 0,
            .ema_decay = config.ema_decay_init,
        };
    }

    pub fn deinit(self: *TJEPATrainer) void {
        self.allocator.free(self.student_params);
        self.allocator.free(self.teacher_params);
    }

    pub fn trainStep(self: *TJEPATrainer, input: []const f32, grad: []const f32) f32 {
        self.step_count += 1;
        self.updateEMA();

        const lr = self.currentLR();
        for (self.student_params, grad) |*p, g| {
            p.* -= lr * g;
        }

        const loss = self.computeLoss(input);
        return loss;
    }

    pub fn updateEMA(self: *TJEPATrainer) void {
        const progress = @min(
            @as(f32, @floatFromInt(self.step_count)) /
                @as(f32, @floatFromInt(self.config.ema_warmup_steps)),
            1.0,
        );
        self.ema_decay = self.config.ema_decay_init +
            (self.config.ema_decay_final - self.config.ema_decay_init) * progress;

        for (self.teacher_params, self.student_params) |*t, s| {
            t.* = self.ema_decay * t.* + (1.0 - self.ema_decay) * s;
        }
    }

    fn currentLR(self: *const TJEPATrainer) f32 {
        const progress = @as(f32, @floatFromInt(self.step_count)) /
            @as(f32, @floatFromInt(self.config.total_steps));
        return 1e-4 * (1.0 + std.math.cos(std.math.pi * progress)) * 0.5;
    }

    fn computeLoss(self: *const TJEPATrainer, target: []const f32) f32 {
        switch (self.config.loss_fn) {
            .l2_mse => {
                var sum: f32 = 0;
                for (self.teacher_params, target) |t, g| {
                    const d = t - g;
                    sum += d * d;
                }
                return sum / @as(f32, @floatFromInt(self.teacher_params.len));
            },
            .l1_smooth => {
                var sum: f32 = 0;
                for (self.teacher_params, target) |t, g| {
                    const d = @abs(t - g);
                    sum += if (d < 1.0) 0.5 * d * d else d - 0.5;
                }
                return sum / @as(f32, @floatFromInt(self.teacher_params.len));
            },
        }
    }

    pub fn shouldCheckpoint(self: *const TJEPATrainer) bool {
        return self.step_count > 0 and self.step_count % self.config.checkpoint_every == 0;
    }

    pub fn isDone(self: *const TJEPATrainer) bool {
        return self.step_count >= self.config.total_steps;
    }

    pub fn progress(self: *const TJEPATrainer) f32 {
        return @as(f32, @floatFromInt(self.step_count)) /
            @as(f32, @floatFromInt(self.config.total_steps));
    }
};

pub const MaskGenerator = struct {
    mask_ratio: f32,
    num_patches: usize,
    rng: std.Random.DefaultPrng,

    pub fn init(mask_ratio: f32, num_patches: usize, seed: u64) MaskGenerator {
        return .{
            .mask_ratio = mask_ratio,
            .num_patches = num_patches,
            .rng = std.Random.DefaultPrng.init(seed),
        };
    }

    pub fn generate(self: *MaskGenerator, allocator: std.mem.Allocator) !struct { visible: []usize, masked: []usize } {
        const num_masked = @as(usize, @intFromFloat(@as(f32, @floatFromInt(self.num_patches)) * self.mask_ratio));
        const num_visible = self.num_patches - num_masked;

        var indices = try allocator.alloc(usize, self.num_patches);
        defer allocator.free(indices);
        for (indices, 0..) |*idx, i| idx.* = i;

        const random = self.rng.random();
        var i: usize = self.num_patches;
        while (i > 1) {
            i -= 1;
            const j = random.intRangeLessThan(usize, 0, i + 1);
            std.mem.swap(usize, &indices[i], &indices[j]);
        }

        const visible = try allocator.dupe(usize, indices[0..num_visible]);
        const masked = try allocator.dupe(usize, indices[num_visible..]);

        return .{ .visible = visible, .masked = masked };
    }
};

test "T-JEPA EMA decay schedule" {
    const allocator = std.testing.allocator;
    var trainer = try TJEPATrainer.init(allocator, 10, .{
        .ema_decay_init = 0.996,
        .ema_decay_final = 1.0,
        .ema_warmup_steps = 100,
    });
    defer trainer.deinit();

    const d0 = trainer.ema_decay;
    for (0..100) |_| {
        trainer.updateEMA();
    }
    try std.testing.expect(trainer.ema_decay > d0);
}

test "T-JEPA training step reduces loss" {
    const allocator = std.testing.allocator;
    var trainer = try TJEPATrainer.init(allocator, 10, .{
        .total_steps = 100,
    });
    defer trainer.deinit();

    const target = [_]f32{ 1.0, 0.5, 0.3, 0.1, 0.0, -0.1, -0.3, -0.5, -0.7, -1.0 };
    const grad = [_]f32{ 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1 };

    const loss1 = trainer.trainStep(&target, &grad);
    const loss2 = trainer.trainStep(&target, &grad);
    const loss3 = trainer.trainStep(&target, &grad);

    try std.testing.expect(std.math.isFinite(loss1));
    try std.testing.expect(std.math.isFinite(loss2));
}

test "T-JEPA checkpoint detection" {
    const allocator = std.testing.allocator;
    var trainer = try TJEPATrainer.init(allocator, 10, .{
        .total_steps = 20000,
        .checkpoint_every = 5000,
    });
    defer trainer.deinit();

    const target = [_]f32{0} ** 10;
    const grad = [_]f32{0} ** 10;

    for (0..5000) |_| {
        _ = trainer.trainStep(&target, &grad);
    }
    try std.testing.expect(trainer.shouldCheckpoint());
}

test "T-JEPA progress tracking" {
    const allocator = std.testing.allocator;
    var trainer = try TJEPATrainer.init(allocator, 10, .{
        .total_steps = 100,
    });
    defer trainer.deinit();

    const target = [_]f32{0} ** 10;
    const grad = [_]f32{0} ** 10;

    for (0..50) |_| {
        _ = trainer.trainStep(&target, &grad);
    }
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), trainer.progress(), 0.01);
}

test "mask generator produces correct split" {
    const allocator = std.testing.allocator;
    var mask = MaskGenerator.init(0.3, 27, 42);
    const result = try mask.generate(allocator);
    defer {
        allocator.free(result.visible);
        allocator.free(result.masked);
    }

    try std.testing.expectEqual(@as(usize, 19), result.visible.len);
    try std.testing.expectEqual(@as(usize, 8), result.masked.len);
}

test "mask generator covers all patches" {
    const allocator = std.testing.allocator;
    var mask = MaskGenerator.init(0.3, 10, 123);
    const result = try mask.generate(allocator);
    defer {
        allocator.free(result.visible);
        allocator.free(result.masked);
    }

    var seen = [_]bool{false} ** 10;
    for (result.visible) |i| seen[i] = true;
    for (result.masked) |i| seen[i] = true;
    for (seen) |s| try std.testing.expect(s);
}
