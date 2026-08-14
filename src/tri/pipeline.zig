const std = @import("std");

pub const PipelineStep = enum {
    scan,
    pick,
    research,
    spec_create,
    gen,
    test,
    verdict,
    experience_save,
    git_commit,
    loop_decide,
};

pub const StepStatus = enum {
    pending,
    in_progress,
    passed,
    failed,
    skipped,
};

pub const StepResult = struct {
    step: PipelineStep,
    status: StepStatus,
    message: []const u8,
    timestamp: u64,
    duration_ns: u64,
};

pub const PipelineConfig = struct {
    max_iterations: u32 = 10,
    fail_threshold: u32 = 3,
    toxic_check: bool = true,
    auto_commit: bool = true,
};

pub const PipelineRun = struct {
    allocator: std.mem.Allocator,
    config: PipelineConfig,
    steps: std.ArrayList(StepResult),
    current_iteration: u32,
    issue_number: ?u32,
    started_at: u64,

    pub fn init(allocator: std.mem.Allocator, config: PipelineConfig) PipelineRun {
        return .{
            .allocator = allocator,
            .config = config,
            .steps = std.ArrayList(StepResult).init(allocator),
            .current_iteration = 0,
            .issue_number = null,
            .started_at = @intCast(std.time.milliTimestamp()),
        };
    }

    pub fn deinit(self: *PipelineRun) void {
        for (self.steps.items) |s| {
            self.allocator.free(s.message);
        }
        self.steps.deinit();
    }

    pub fn setIssue(self: *PipelineRun, issue_number: u32) void {
        self.issue_number = issue_number;
    }

    pub fn recordStep(self: *PipelineRun, step: PipelineStep, status: StepStatus, message: []const u8) !void {
        const msg_copy = try self.allocator.dupe(u8, message);
        try self.steps.append(.{
            .step = step,
            .status = status,
            .message = msg_copy,
            .timestamp = @intCast(std.time.milliTimestamp()),
            .duration_ns = 0,
        });
    }

    pub fn currentStep(self: *const PipelineRun) ?PipelineStep {
        const step_order = [_]PipelineStep{
            .scan, .pick, .research, .spec_create,
            .gen, .test, .verdict, .experience_save,
            .git_commit, .loop_decide,
        };
        for (step_order) |s| {
            var found = false;
            for (self.steps.items) |sr| {
                if (sr.step == s and sr.status != .skipped) {
                    found = true;
                    break;
                }
            }
            if (!found) return s;
        }
        return null;
    }

    pub fn completedSteps(self: *const PipelineRun) usize {
        var count: usize = 0;
        for (self.steps.items) |s| {
            if (s.status == .passed) count += 1;
        }
        return count;
    }

    pub fn failedSteps(self: *const PipelineRun) usize {
        var count: usize = 0;
        for (self.steps.items) |s| {
            if (s.status == .failed) count += 1;
        }
        return count;
    }

    pub fn progress(self: *const PipelineRun) f32 {
        return @as(f32, @floatFromInt(self.completedSteps())) / 10.0;
    }

    pub fn shouldContinue(self: *const PipelineRun) bool {
        if (self.failedSteps() >= self.config.fail_threshold) return false;
        if (self.current_iteration >= self.config.max_iterations) return false;
        return self.currentStep() != null;
    }
};

pub const ExperienceEntry = struct {
    issue_number: u32,
    pattern: []const u8,
    approach: []const u8,
    mistakes: std.ArrayList([]const u8),
    learnings: std.ArrayList([]const u8),
    success: bool,
    timestamp: u64,

    pub fn deinit(self: *ExperienceEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.pattern);
        allocator.free(self.approach);
        for (self.mistakes.items) |m| allocator.free(m);
        self.mistakes.deinit();
        for (self.learnings.items) |l| allocator.free(l);
        self.learnings.deinit();
    }
};

pub const ExperienceStore = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(ExperienceEntry),

    pub fn init(allocator: std.mem.Allocator) ExperienceStore {
        return .{
            .allocator = allocator,
            .entries = std.ArrayList(ExperienceEntry).init(allocator),
        };
    }

    pub fn deinit(self: *ExperienceStore) void {
        for (self.entries.items) |*e| e.deinit(self.allocator);
        self.entries.deinit();
    }

    pub fn save(self: *ExperienceStore, entry: ExperienceEntry) !void {
        try self.entries.append(entry);
    }

    pub fn findSimilar(self: *const ExperienceStore, pattern: []const u8) ?*const ExperienceEntry {
        for (self.entries.items) |*entry| {
            if (std.mem.indexOf(u8, entry.pattern, pattern) != null) {
                return entry;
            }
        }
        return null;
    }

    pub fn successRate(self: *const ExperienceStore) f32 {
        if (self.entries.items.len == 0) return 0;
        var successes: usize = 0;
        for (self.entries.items) |e| {
            if (e.success) successes += 1;
        }
        return @as(f32, @floatFromInt(successes)) /
            @as(f32, @floatFromInt(self.entries.items.len));
    }
};

pub const Verdict = struct {
    category: []const u8,
    before_score: f32,
    after_score: f32,
    delta: f32,
    passed: bool,

    pub fn init(category: []const u8, before: f32, after: f32, threshold: f32) Verdict {
        const d = after - before;
        return .{
            .category = category,
            .before_score = before,
            .after_score = after,
            .delta = d,
            .passed = d >= threshold,
        };
    }
};

pub const ToxicVerdict = struct {
    verdicts: std.ArrayList(Verdict),
    overall_passed: bool,

    pub fn init(allocator: std.mem.Allocator) ToxicVerdict {
        return .{
            .verdicts = std.ArrayList(Verdict).init(allocator),
            .overall_passed = true,
        };
    }

    pub fn deinit(self: *ToxicVerdict) void {
        self.verdicts.deinit();
    }

    pub fn addVerdict(self: *ToxicVerdict, v: Verdict) void {
        if (!v.passed) self.overall_passed = false;
        self.verdicts.append(v) catch {};
    }

    pub fn format(self: *const ToxicVerdict, writer: anytype) !void {
        try writer.print("Toxic Verdict: ", .{});
        if (self.overall_passed) {
            try writer.print("PASS", .{});
        } else {
            try writer.print("FAIL", .{});
        }
        try writer.print(" ({d}/{d} passed)\n", .{
            self.passCount(),
            self.verdicts.items.len,
        });
        for (self.verdicts.items) |v| {
            const status = if (v.passed) "OK" else "FAIL";
            try writer.print("  {s}: {d:.1} → {d:.1} (Δ={d:+.1}) [{s}]\n", .{
                v.category,
                v.before_score,
                v.after_score,
                v.delta,
                status,
            });
        }
    }

    fn passCount(self: *const ToxicVerdict) usize {
        var c: usize = 0;
        for (self.verdicts.items) |v| {
            if (v.passed) c += 1;
        }
        return c;
    }
};

test "pipeline run records steps" {
    const allocator = std.testing.allocator;
    var run = PipelineRun.init(allocator, .{});
    defer run.deinit();

    try run.recordStep(.scan, .passed, "Found 5 similar issues");
    try run.recordStep(.pick, .passed, "Selected issue #42");
    try std.testing.expectEqual(@as(usize, 2), run.steps.items.len);
    try std.testing.expectEqual(@as(usize, 2), run.completedSteps());
}

test "pipeline tracks progress" {
    const allocator = std.testing.allocator;
    var run = PipelineRun.init(allocator, .{});
    defer run.deinit();

    try run.recordStep(.scan, .passed, "ok");
    try run.recordStep(.pick, .passed, "ok");

    try std.testing.expect(run.progress() > 0);
    try std.testing.expect(run.shouldContinue());
}

test "pipeline stops after too many failures" {
    const allocator = std.testing.allocator;
    var run = PipelineRun.init(allocator, .{ .fail_threshold = 2 });
    defer run.deinit();

    try run.recordStep(.test, .failed, "test failed");
    try run.recordStep(.test, .failed, "test failed again");
    try std.testing.expect(!run.shouldContinue());
}

test "experience store saves and queries" {
    const allocator = std.testing.allocator;
    var store = ExperienceStore.init(allocator);
    defer store.deinit();

    const entry = ExperienceEntry{
        .issue_number = 42,
        .pattern = try allocator.dupe(u8, "ternary-matmul"),
        .approach = try allocator.dupe(u8, "sparse-iteration"),
        .mistakes = std.ArrayList([]const u8).init(allocator),
        .learnings = std.ArrayList([]const u8).init(allocator),
        .success = true,
        .timestamp = 1000,
    };
    try store.save(entry);
    try std.testing.expect(store.findSimilar("ternary") != null);
    try std.testing.expectEqual(@as(f32, 1.0), store.successRate());
}

test "toxic verdict tracks pass/fail" {
    const allocator = std.testing.allocator;
    var verdict = ToxicVerdict.init(allocator);
    defer verdict.deinit();

    verdict.addVerdict(Verdict.init("tests", 3, 7, 3));
    verdict.addVerdict(Verdict.init("lint", 5, 7, 3));
    try std.testing.expect(verdict.overall_passed);
}

test "toxic verdict detects failure" {
    const allocator = std.testing.allocator;
    var verdict = ToxicVerdict.init(allocator);
    defer verdict.deinit();

    verdict.addVerdict(Verdict.init("tests", 3, 7, 3));
    verdict.addVerdict(Verdict.init("lint", 5, 4, 3));
    try std.testing.expect(!verdict.overall_passed);
}
