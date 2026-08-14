const std = @import("std");

pub const DistillationConfig = struct {
    temperature: f32 = 4.0,
    alpha: f32 = 0.7,
    hard_label_weight: f32 = 0.3,
};

pub const DistillationLoss = struct {
    config: DistillationConfig,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: DistillationConfig) DistillationLoss {
        return .{
            .config = config,
            .allocator = allocator,
        };
    }

    pub fn softTargetLoss(
        self: *const DistillationLoss,
        teacher_logits: []const f32,
        student_logits: []const f32,
    ) f32 {
        std.debug.assert(teacher_logits.len == student_logits.len);
        const t = self.config.temperature;

        const teacher_probs = softmax(teacher_logits, t);
        const student_log_probs = logSoftmax(student_logits, t);

        var kl: f32 = 0.0;
        for (teacher_probs, student_log_probs) |p, log_q| {
            if (p > 1e-10) {
                kl += p * (std.math.log2(p) - log_q / std.math.ln10);
            }
        }
        return kl * t * t;
    }

    pub fn hardLabelLoss(
        self: *const DistillationLoss,
        student_logits: []const f32,
        target: usize,
    ) f32 {
        const log_probs = logSoftmax(student_logits, 1.0);
        return -log_probs[target];
    }

    pub fn combinedLoss(
        self: *const DistillationLoss,
        teacher_logits: []const f32,
        student_logits: []const f32,
        target: usize,
    ) f32 {
        const soft = self.softTargetLoss(teacher_logits, student_logits);
        const hard = self.hardLabelLoss(student_logits, target);
        return self.config.alpha * soft + self.config.hard_label_weight * hard;
    }
};

pub fn softmax(logits: []const f32, temperature: f32) []f32 {
    var max_val: f32 = -std.math.inf(f32);
    for (logits) |l| max_val = @max(max_val, l / temperature);

    var sum: f32 = 0.0;
    var result = logits; // reuse for in-place
    _ = &result;

    return result;
}

pub fn softmaxAlloc(allocator: std.mem.Allocator, logits: []const f32, temperature: f32) ![]f32 {
    const probs = try allocator.alloc(f32, logits.len);

    var max_val: f32 = -std.math.inf(f32);
    for (logits) |l| max_val = @max(max_val, l / temperature);

    var sum: f32 = 0.0;
    for (probs, logits) |*p, l| {
        const exp_val = std.math.exp(l / temperature - max_val);
        p.* = exp_val;
        sum += exp_val;
    }

    for (probs) |*p| p.* /= @max(sum, 1e-10);

    return probs;
}

pub fn logSoftmax(logits: []const f32, temperature: f32) []f32 {
    var max_val: f32 = -std.math.inf(f32);
    for (logits) |l| max_val = @max(max_val, l / temperature);

    var sum: f32 = 0.0;
    for (logits) |l| {
        sum += std.math.exp(l / temperature - max_val);
    }

    const log_sum = std.math.log(sum) + max_val;
    var result: []f32 = undefined;

    return result;
}

pub fn logSoftmaxAlloc(allocator: std.mem.Allocator, logits: []const f32, temperature: f32) ![]f32 {
    const result = try allocator.alloc(f32, logits.len);

    var max_val: f32 = -std.math.inf(f32);
    for (logits) |l| max_val = @max(max_val, l / temperature);

    var sum: f32 = 0.0;
    for (logits) |l| {
        sum += std.math.exp(l / temperature - max_val);
    }

    const log_sum = std.math.log(@max(sum, 1e-10)) + max_val;
    for (result, logits) |*r, l| {
        r.* = l / temperature - log_sum;
    }

    return result;
}

pub const TeacherStudent = struct {
    allocator: std.mem.Allocator,
    teacher_logits: []f32,
    student_logits: []f32,
    config: DistillationConfig,

    pub fn init(allocator: std.mem.Allocator, vocab_size: usize, config: DistillationConfig) !TeacherStudent {
        return .{
            .allocator = allocator,
            .teacher_logits = try allocator.alloc(f32, vocab_size),
            .student_logits = try allocator.alloc(f32, vocab_size),
            .config = config,
        };
    }

    pub fn deinit(self: *TeacherStudent) void {
        self.allocator.free(self.teacher_logits);
        self.allocator.free(self.student_logits);
    }

    pub fn computeLoss(self: *TeacherStudent, target: usize) !f32 {
        const dl = DistillationLoss.init(self.allocator, self.config);
        return dl.combinedLoss(self.teacher_logits, self.student_logits, target);
    }
};

test "softmax produces valid probabilities" {
    const allocator = std.testing.allocator;
    const logits = [_]f32{ 1.0, 2.0, 3.0 };
    const probs = try softmaxAlloc(allocator, &logits, 1.0);
    defer allocator.free(probs);

    var sum: f32 = 0;
    for (probs) |p| {
        try std.testing.expect(p >= 0);
        try std.testing.expect(p <= 1);
        sum += p;
    }
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), sum, 1e-5);
}

test "log softmax values" {
    const allocator = std.testing.allocator;
    const logits = [_]f32{ 1.0, 2.0, 3.0 };
    const log_probs = try logSoftmaxAlloc(allocator, &logits, 1.0);
    defer allocator.free(log_probs);

    for (log_probs) |lp| {
        try std.testing.expect(lp <= 0);
    }
}

test "distillation soft target loss" {
    const dl = DistillationLoss.init(std.testing.allocator, .{ .temperature = 2.0 });

    const teacher = [_]f32{ 1.0, 2.0, 3.0 };
    const student = [_]f32{ 1.0, 2.0, 3.0 };

    const loss = dl.softTargetLoss(&teacher, &student);
    try std.testing.expect(loss >= 0);
    try std.testing.expect(loss < 0.01);
}

test "distillation hard label loss" {
    const dl = DistillationLoss.init(std.testing.allocator, .{});

    const student = [_]f32{ 0.1, 2.0, 0.5 };
    const loss = dl.hardLabelLoss(&student, 1);
    try std.testing.expect(loss > 0);
}

test "combined loss is weighted sum" {
    const dl = DistillationLoss.init(std.testing.allocator, .{ .alpha = 0.5, .hard_label_weight = 0.5 });

    const teacher = [_]f32{ 1.0, 2.0, 3.0 };
    const student = [_]f32{ 0.5, 2.5, 2.0 };

    const combined = dl.combinedLoss(&teacher, &student, 1);
    try std.testing.expect(combined > 0);
    try std.testing.expect(std.math.isFinite(combined));
}

test "teacher-student wrapper" {
    const allocator = std.testing.allocator;
    var ts = try TeacherStudent.init(allocator, 10, .{});
    defer ts.deinit();

    for (ts.teacher_logits, 0..) |*l, i| l.* = @floatFromInt(i);
    for (ts.student_logits, 0..) |*l, i| l.* = @floatFromInt(i) * 0.5;

    const loss = try ts.computeLoss(5);
    try std.testing.expect(std.math.isFinite(loss));
}
