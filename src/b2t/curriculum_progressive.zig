const std = @import("std");

pub const CurriculumConfig = struct {
    warmup_fraction: f32 = 0.2,
    initial_vocab_fraction: f32 = 0.5,
    total_tokens: usize = 100000,
};

pub const CurriculumScheduler = struct {
    config: CurriculumConfig,
    current_step: usize,
    vocab_size: usize,

    pub fn init(config: CurriculumConfig, vocab_size: usize) CurriculumScheduler {
        return .{
            .config = config,
            .current_step = 0,
            .vocab_size = vocab_size,
        };
    }

    pub fn step(self: *CurriculumScheduler) usize {
        self.current_step += 1;
        return self.activeVocabSize();
    }

    pub fn activeVocabSize(self: *const CurriculumScheduler) usize {
        const warmup_steps = @as(usize, @intFromFloat(
            @as(f32, @floatFromInt(self.config.total_tokens)) * self.config.warmup_fraction,
        ));

        if (self.current_step >= warmup_steps) {
            return self.vocab_size;
        }

        const progress = @as(f32, @floatFromInt(self.current_step)) /
            @as(f32, @floatFromInt(warmup_steps));

        const fraction = self.config.initial_vocab_fraction +
            (1.0 - self.config.initial_vocab_fraction) * progress;

        const active = @as(usize, @intFromFloat(
            @as(f32, @floatFromInt(self.vocab_size)) * fraction,
        ));
        return @max(active, 10);
    }

    pub fn isActive(self: *const CurriculumScheduler, token_id: usize) bool {
        return token_id < self.activeVocabSize();
    }

    pub fn filterBatch(self: *const CurriculumScheduler, tokens: []const usize, output: []usize) usize {
        var count: usize = 0;
        for (tokens) |t| {
            if (self.isActive(t)) {
                if (count < output.len) {
                    output[count] = t;
                    count += 1;
                }
            }
        }
        return count;
    }
};

pub const ProgressiveConfig = struct {
    init_hidden: usize = 81,
    final_hidden: usize = 729,
    grow_stages: usize = 3,
    steps_per_stage: usize = 10000,
};

pub const ProgressiveGrower = struct {
    config: ProgressiveConfig,
    current_stage: usize,
    current_step: usize,

    pub fn init(config: ProgressiveConfig) ProgressiveGrower {
        return .{
            .config = config,
            .current_stage = 0,
            .current_step = 0,
        };
    }

    pub fn step(self: *ProgressiveGrower) usize {
        self.current_step += 1;
        const stage_length = self.config.steps_per_stage;
        const new_stage = self.current_step / stage_length;

        if (new_stage > self.current_stage and new_stage <= self.config.grow_stages) {
            self.current_stage = new_stage;
        }

        return self.currentHiddenSize();
    }

    pub fn currentHiddenSize(self: *const ProgressiveGrower) usize {
        const progress = @min(
            @as(f32, @floatFromInt(self.current_stage)) /
                @as(f32, @floatFromInt(self.config.grow_stages)),
            1.0,
        );
        const size = @as(f32, @floatFromInt(self.config.init_hidden)) +
            (@as(f32, @floatFromInt(self.config.final_hidden)) -
                @as(f32, @floatFromInt(self.config.init_hidden))) * progress;
        return @as(usize, @intFromFloat(size));
    }

    pub fn shouldGrow(self: *const ProgressiveGrower) bool {
        const prev_stage = (self.current_step - 1) / self.config.steps_per_stage;
        return self.current_step > 0 and
            self.current_step % self.config.steps_per_stage == 0 and
            prev_stage < self.config.grow_stages;
    }

    pub fn stageSchedule(self: *const ProgressiveGrower, allocator: std.mem.Allocator) ![]usize {
        var sizes = std.ArrayList(usize).init(allocator);
        for (0..self.config.grow_stages + 1) |s| {
            self.current_stage = s;
            try sizes.append(self.currentHiddenSize());
        }
        self.current_stage = 0;
        return sizes.toOwnedSlice();
    }
};

pub const InferenceConfig = struct {
    target_tokens_per_sec: f32 = 15000,
    target_power_watts: f32 = 25,
    model_size_mb: f32 = 14.0,
};

pub const InferenceBenchmark = struct {
    config: InferenceConfig,
    actual_tok_per_sec: f32,
    actual_power_watts: f32,

    pub fn init(config: InferenceConfig) InferenceBenchmark {
        return .{
            .config = config,
            .actual_tok_per_sec = 0,
            .actual_power_watts = 0,
        };
    }

    pub fn update(self: *InferenceBenchmark, tokens: usize, elapsed_ns: u64) void {
        const secs = @as(f32, @floatFromInt(elapsed_ns)) / 1e9;
        self.actual_tok_per_sec = @as(f32, @floatFromInt(tokens)) / @max(secs, 1e-9);
    }

    pub fn passesThroughput(self: *const InferenceBenchmark) bool {
        return self.actual_tok_per_sec >= self.config.target_tokens_per_sec;
    }

    pub fn passesPower(self: *const InferenceBenchmark) bool {
        return self.actual_power_watts <= self.config.target_power_watts;
    }
};

test "curriculum scheduler expands vocabulary" {
    var sched = CurriculumScheduler.init(.{
        .warmup_fraction = 0.5,
        .initial_vocab_fraction = 0.5,
        .total_tokens = 100,
    }, 729);

    const v0 = sched.activeVocabSize();
    for (0..50) |_| {
        _ = sched.step();
    }
    const v1 = sched.activeVocabSize();
    for (0..50) |_| {
        _ = sched.step();
    }
    const v2 = sched.activeVocabSize();

    try std.testing.expect(v0 < v1);
    try std.testing.expectEqual(@as(usize, 729), v2);
}

test "curriculum filter batch" {
    var sched = CurriculumScheduler.init(.{
        .warmup_fraction = 0.5,
        .initial_vocab_fraction = 0.1,
        .total_tokens = 100,
    }, 100);

    const tokens = [_]usize{ 5, 10, 50, 80, 99 };
    var output: [5]usize = undefined;
    const count = sched.filterBatch(&tokens, &output);
    try std.testing.expect(count < 5);
    for (output[0..count]) |t| {
        try std.testing.expect(t < sched.activeVocabSize());
    }
}

test "progressive grower increases hidden size" {
    var grower = ProgressiveGrower.init(.{
        .init_hidden = 81,
        .final_hidden = 729,
        .grow_stages = 3,
        .steps_per_stage = 100,
    });

    const h0 = grower.currentHiddenSize();
    for (0..100) |_| {
        _ = grower.step();
    }
    const h1 = grower.currentHiddenSize();
    for (0..200) |_| {
        _ = grower.step();
    }
    const h2 = grower.currentHiddenSize();
    for (0..100) |_| {
        _ = grower.step();
    }
    const h3 = grower.currentHiddenSize();

    try std.testing.expect(h0 <= h1);
    try std.testing.expect(h1 <= h2);
    try std.testing.expect(h2 <= h3);
}

test "progressive grower shouldGrow detection" {
    var grower = ProgressiveGrower.init(.{
        .init_hidden = 81,
        .final_hidden = 729,
        .grow_stages = 3,
        .steps_per_stage = 100,
    });

    for (0..99) |_| {
        _ = grower.step();
        try std.testing.expect(!grower.shouldGrow());
    }
    _ = grower.step();
    try std.testing.expect(grower.shouldGrow());
}

test "progressive stage schedule" {
    const allocator = std.testing.allocator;
    var grower = ProgressiveGrower.init(.{
        .init_hidden = 81,
        .final_hidden = 729,
        .grow_stages = 3,
        .steps_per_stage = 1000,
    });

    const schedule = try grower.stageSchedule(allocator);
    defer allocator.free(schedule);

    try std.testing.expectEqual(@as(usize, 4), schedule.len);
    try std.testing.expect(schedule[0] < schedule[3]);
}

test "inference benchmark update" {
    var bench = InferenceBenchmark.init(.{ .target_tokens_per_sec = 1000 });
    bench.update(5000, 1_000_000_000);

    try std.testing.expectApproxEqAbs(@as(f32, 5000.0), bench.actual_tok_per_sec, 1.0);
    try std.testing.expect(bench.passesThroughput());
}
