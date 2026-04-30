const std = @import("std");

pub const RunStatus = enum {
    queued,
    building,
    training,
    completed,
    crashed,
    cancelled,
};

pub const RunConfig = struct {
    id: []const u8,
    optimizer: []const u8,
    lr: f64,
    schedule: []const u8,
    batch_size: usize,
    gradient_accum: usize,
    special: []const u8,
    account: []const u8,
};

pub const RunMetrics = struct {
    step: u32,
    avg_loss: f32,
    ppl: f32,
    lr: f32,
    tok_per_sec: f32,
    timestamp: u64,
};

pub const TrainingRun = struct {
    config: RunConfig,
    status: RunStatus,
    metrics_history: std.ArrayList(RunMetrics),
    best_loss: f32,
    best_ppl: f32,
    best_step: u32,
    started_at: u64,
    updated_at: u64,

    pub fn init(allocator: std.mem.Allocator, config: RunConfig) TrainingRun {
        return .{
            .config = config,
            .status = .queued,
            .metrics_history = std.ArrayList(RunMetrics).init(allocator),
            .best_loss = std.math.inf(f32),
            .best_ppl = std.math.inf(f32),
            .best_step = 0,
            .started_at = 0,
            .updated_at = 0,
        };
    }

    pub fn deinit(self: *TrainingRun) void {
        self.metrics_history.deinit();
    }

    pub fn updateMetrics(self: *TrainingRun, metrics: RunMetrics) void {
        if (metrics.avg_loss < self.best_loss) {
            self.best_loss = metrics.avg_loss;
            self.best_ppl = std.math.exp(metrics.avg_loss);
            self.best_step = metrics.step;
        }
        self.metrics_history.append(metrics) catch {};
        self.updated_at = metrics.timestamp;
    }

    pub fn currentMetrics(self: *const TrainingRun) ?RunMetrics {
        if (self.metrics_history.items.len == 0) return null;
        return self.metrics_history.items[self.metrics_history.items.len - 1];
    }
};

pub const FarmAccount = struct {
    name: []const u8,
    max_slots: usize,
    runs: std.ArrayList(*TrainingRun),

    pub fn init(allocator: std.mem.Allocator, name: []const u8, max_slots: usize) FarmAccount {
        return .{
            .name = name,
            .max_slots = max_slots,
            .runs = std.ArrayList(*TrainingRun).init(allocator),
        };
    }

    pub fn deinit(self: *FarmAccount) void {
        self.runs.deinit();
    }

    pub fn activeCount(self: *const FarmAccount) usize {
        var count: usize = 0;
        for (self.runs.items) |run| {
            switch (run.status) {
                .training, .building, .queued => count += 1,
                else => {},
            }
        }
        return count;
    }

    pub fn utilization(self: *const FarmAccount) f32 {
        return @as(f32, @floatFromInt(self.activeCount())) /
            @as(f32, @floatFromInt(self.max_slots));
    }
};

pub const EvolutionTracker = struct {
    allocator: std.mem.Allocator,
    accounts: std.ArrayList(FarmAccount),
    all_runs: std.ArrayList(TrainingRun),
    best_result: ?*TrainingRun,

    pub fn init(allocator: std.mem.Allocator) EvolutionTracker {
        return .{
            .allocator = allocator,
            .accounts = std.ArrayList(FarmAccount).init(allocator),
            .all_runs = std.ArrayList(TrainingRun).init(allocator),
            .best_result = null,
        };
    }

    pub fn deinit(self: *EvolutionTracker) void {
        for (self.accounts.items) |*a| a.deinit();
        self.accounts.deinit();
        for (self.all_runs.items) |*r| r.deinit();
        self.all_runs.deinit();
    }

    pub fn addAccount(self: *EvolutionTracker, name: []const u8, max_slots: usize) !void {
        try self.accounts.append(FarmAccount.init(self.allocator, name, max_slots));
    }

    pub fn addRun(self: *EvolutionTracker, config: RunConfig) !*TrainingRun {
        try self.all_runs.append(TrainingRun.init(self.allocator, config));
        return &self.all_runs.items[self.all_runs.items.len - 1];
    }

    pub fn assignRun(self: *EvolutionTracker, account_idx: usize, run: *TrainingRun) !void {
        try self.accounts.items[account_idx].runs.append(run);
        run.status = .queued;
    }

    pub fn totalActive(self: *const EvolutionTracker) usize {
        var count: usize = 0;
        for (self.accounts.items) |a| count += a.activeCount();
        return count;
    }

    pub fn totalSlots(self: *const EvolutionTracker) usize {
        var total: usize = 0;
        for (self.accounts.items) |a| total += a.max_slots;
        return total;
    }

    pub fn farmUtilization(self: *const EvolutionTracker) f32 {
        const slots = self.totalSlots();
        if (slots == 0) return 0;
        return @as(f32, @floatFromInt(self.totalActive())) /
            @as(f32, @floatFromInt(slots));
    }

    pub fn updateBest(self: *EvolutionTracker) void {
        for (self.all_runs.items) |*run| {
            if (run.best_ppl < std.math.inf(f32)) {
                if (self.best_result == null or run.best_ppl < self.best_result.?.best_ppl) {
                    self.best_result = run;
                }
            }
        }
    }

    pub fn printStatus(self: *const EvolutionTracker, writer: anytype) !void {
        try writer.print("\n  Training Farm Status\n", .{});
        try writer.print("  {s}\n", .{"-" * 60});
        try writer.print("  Total slots: {d}/{d} ({d:.0}% utilized)\n\n", .{
            self.totalActive(),
            self.totalSlots(),
            self.farmUtilization() * 100,
        });

        for (self.accounts.items) |account| {
            try writer.print("  {s}: {d}/{d} active\n", .{
                account.name,
                account.activeCount(),
                account.max_slots,
            });
        }

        if (self.best_result) |best| {
            try writer.print("\n  Best: {s} PPL={d:.1} (step {d})\n", .{
                best.config.id,
                best.best_ppl,
                best.best_step,
            });
        }
        try writer.print("\n", .{});
    }
};

test "training run tracks metrics" {
    const allocator = std.testing.allocator;
    var run = TrainingRun.init(allocator, .{
        .id = "R20",
        .optimizer = "adam",
        .lr = 3e-4,
        .schedule = "cosine",
        .batch_size = 66,
        .gradient_accum = 1,
        .special = "full-ternary",
        .account = "farm-3",
    });
    defer run.deinit();

    run.updateMetrics(.{ .step = 1000, .avg_loss = 6.5, .ppl = 665, .lr = 2.8e-4, .tok_per_sec = 12000, .timestamp = 1000 });
    run.updateMetrics(.{ .step = 5000, .avg_loss = 5.2, .ppl = 181, .lr = 2.0e-4, .tok_per_sec = 12500, .timestamp = 5000 });
    run.updateMetrics(.{ .step = 10000, .avg_loss = 4.8, .ppl = 122, .lr = 1.5e-4, .tok_per_sec = 12800, .timestamp = 10000 });

    try std.testing.expectEqual(@as(usize, 3), run.metrics_history.items.len);
    try std.testing.expect(run.best_loss < 5.0);
    try std.testing.expectEqual(@as(u32, 10000), run.best_step);
}

test "farm account utilization" {
    const allocator = std.testing.allocator;
    var account = FarmAccount.init(allocator, "primary", 25);
    defer account.deinit();

    try std.testing.expectEqual(@as(f32, 0.0), account.utilization());
}

test "evolution tracker farm status" {
    const allocator = std.testing.allocator;
    var tracker = EvolutionTracker.init(allocator);
    defer tracker.deinit();

    try tracker.addAccount("primary", 25);
    try tracker.addAccount("farm-2", 25);
    try tracker.addAccount("farm-3", 25);

    try std.testing.expectEqual(@as(usize, 75), tracker.totalSlots());
    try std.testing.expectEqual(@as(f32, 0.0), tracker.farmUtilization());
}

test "evolution tracker assigns and tracks runs" {
    const allocator = std.testing.allocator;
    var tracker = EvolutionTracker.init(allocator);
    defer tracker.deinit();

    try tracker.addAccount("primary", 25);

    const run = try tracker.addRun(.{
        .id = "R20",
        .optimizer = "adam",
        .lr = 3e-4,
        .schedule = "cosine",
        .batch_size = 66,
        .gradient_accum = 1,
        .special = "full-ternary",
        .account = "primary",
    });
    run.status = .training;

    try tracker.assignRun(0, run);
    try std.testing.expectEqual(@as(usize, 1), tracker.totalActive());
}

test "evolution tracker best result" {
    const allocator = std.testing.allocator;
    var tracker = EvolutionTracker.init(allocator);
    defer tracker.deinit();

    try tracker.addAccount("primary", 25);

    const r1 = try tracker.addRun(.{
        .id = "R10",
        .optimizer = "lamb",
        .lr = 3e-4,
        .schedule = "cosine",
        .batch_size = 66,
        .gradient_accum = 2,
        .special = "",
        .account = "primary",
    });
    r1.updateMetrics(.{ .step = 10000, .avg_loss = 5.0, .ppl = 148, .lr = 1e-4, .tok_per_sec = 11000, .timestamp = 10000 });

    const r2 = try tracker.addRun(.{
        .id = "R20",
        .optimizer = "adam",
        .lr = 3e-4,
        .schedule = "cosine",
        .batch_size = 66,
        .gradient_accum = 1,
        .special = "full-ternary",
        .account = "primary",
    });
    r2.updateMetrics(.{ .step = 10000, .avg_loss = 4.83, .ppl = 125, .lr = 1e-4, .tok_per_sec = 12800, .timestamp = 10000 });

    tracker.updateBest();
    try std.testing.expect(tracker.best_result != null);
    try std.testing.expectEqualStrings("R20", tracker.best_result.?.config.id);
}
