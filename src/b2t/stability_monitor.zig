const std = @import("std");

pub const StabilityConfig = struct {
    total_episodes: u32 = 10000,
    log_every: u32 = 100,
    checkpoint_every: u32 = 1000,
    max_memory_mb: f32 = 4096,
    divergence_threshold: f32 = 2.0,
};

pub const EpisodeMetrics = struct {
    episode: u32,
    loss: f32,
    reward: f32,
    success: bool,
    memory_mb: f32,
    cpu_pct: f32,
    elapsed_ms: u64,
};

pub const StabilityReport = struct {
    total_episodes: u32,
    final_loss: f32,
    initial_loss: f32,
    loss_drift: f32,
    min_loss: f32,
    max_loss: f32,
    mean_loss: f32,
    loss_variance: f32,
    success_rate: f32,
    mean_reward: f32,
    max_memory_mb: f32,
    divergence_episodes: u32,
    converged: bool,

    pub fn print(self: *const StabilityReport, writer: anytype) !void {
        try writer.print("\n  Stability Report ({d} episodes)\n", .{self.total_episodes});
        try writer.print("  {s}\n", .{"-" * 50});
        try writer.print("  Loss: {d:.4} → {d:.4} (drift: {d:+.4})\n", .{ self.initial_loss, self.final_loss, self.loss_drift });
        try writer.print("  Range: [{d:.4}, {d:.4}]\n", .{ self.min_loss, self.max_loss });
        try writer.print("  Mean: {d:.4} ± {d:.4}\n", .{ self.mean_loss, std.math.sqrt(self.loss_variance) });
        try writer.print("  Success: {d:.1}%\n", .{self.success_rate * 100});
        try writer.print("  Reward: {d:.4}\n", .{self.mean_reward});
        try writer.print("  Max Memory: {d:.1}MB\n", .{self.max_memory_mb});
        try writer.print("  Divergences: {d}\n", .{self.divergence_episodes});
        try writer.print("  Converged: {s}\n", .{if (self.converged) "YES" else "NO"});
        try writer.print("  {s}\n\n", .{"-" * 50});
    }
};

pub const StabilityMonitor = struct {
    allocator: std.mem.Allocator,
    config: StabilityConfig,
    history: std.ArrayList(EpisodeMetrics),
    min_loss: f32,
    max_loss: f32,
    max_memory_mb: f32,
    divergence_count: u32,

    pub fn init(allocator: std.mem.Allocator, config: StabilityConfig) StabilityMonitor {
        return .{
            .allocator = allocator,
            .config = config,
            .history = std.ArrayList(EpisodeMetrics).init(allocator),
            .min_loss = std.math.inf(f32),
            .max_loss = -std.math.inf(f32),
            .max_memory_mb = 0,
            .divergence_count = 0,
        };
    }

    pub fn deinit(self: *StabilityMonitor) void {
        self.history.deinit();
    }

    pub fn record(self: *StabilityMonitor, metrics: EpisodeMetrics) bool {
        if (metrics.loss < self.min_loss) self.min_loss = metrics.loss;
        if (metrics.loss > self.max_loss) self.max_loss = metrics.loss;
        if (metrics.memory_mb > self.max_memory_mb) self.max_memory_mb = metrics.memory_mb;

        if (self.history.items.len > 0) {
            const prev_loss = self.history.items[self.history.items.len - 1].loss;
            if (@abs(metrics.loss - prev_loss) > self.config.divergence_threshold * prev_loss) {
                self.divergence_count += 1;
            }
        }

        if (metrics.loss > self.config.divergence_threshold * self.min_loss and self.min_loss > 0) {
            self.divergence_count += 1;
        }

        self.history.append(metrics) catch {};
        return metrics.memory_mb <= self.config.max_memory_mb;
    }

    pub fn shouldLog(self: *const StabilityMonitor) bool {
        return self.history.items.len % self.config.log_every == 0;
    }

    pub fn shouldCheckpoint(self: *const StabilityMonitor) bool {
        return self.history.items.len > 0 and
            self.history.items.len % self.config.checkpoint_every == 0;
    }

    pub fn generateReport(self: *const StabilityMonitor) StabilityReport {
        if (self.history.items.len == 0) {
            return .{
                .total_episodes = 0, .final_loss = 0, .initial_loss = 0,
                .loss_drift = 0, .min_loss = 0, .max_loss = 0,
                .mean_loss = 0, .loss_variance = 0, .success_rate = 0,
                .mean_reward = 0, .max_memory_mb = 0,
                .divergence_episodes = 0, .converged = false,
            };
        }

        const first = self.history.items[0];
        const last = self.history.items[self.history.items.len - 1];

        var loss_sum: f32 = 0;
        var reward_sum: f32 = 0;
        var success_count: usize = 0;
        for (self.history.items) |m| {
            loss_sum += m.loss;
            reward_sum += m.reward;
            if (m.success) success_count += 1;
        }
        const n = @as(f32, @floatFromInt(self.history.items.len));
        const mean_loss = loss_sum / n;

        var var_sum: f32 = 0;
        for (self.history.items) |m| {
            const d = m.loss - mean_loss;
            var_sum += d * d;
        }

        const converged = self.history.items.len >= 1000 and
            last.loss < first.loss * 0.5 and
            self.divergence_count < self.history.items.len / 100;

        return .{
            .total_episodes = @intCast(self.history.items.len),
            .final_loss = last.loss,
            .initial_loss = first.loss,
            .loss_drift = last.loss - first.loss,
            .min_loss = self.min_loss,
            .max_loss = self.max_loss,
            .mean_loss = mean_loss,
            .loss_variance = var_sum / n,
            .success_rate = @as(f32, @floatFromInt(success_count)) / n,
            .mean_reward = reward_sum / n,
            .max_memory_mb = self.max_memory_mb,
            .divergence_episodes = self.divergence_count,
            .converged = converged,
        };
    }
};

test "stability monitor records episodes" {
    const allocator = std.testing.allocator;
    var monitor = StabilityMonitor.init(allocator, .{ .total_episodes = 1000 });
    defer monitor.deinit();

    for (0..100) |i| {
        _ = monitor.record(.{
            .episode = @intCast(i),
            .loss = 10.0 - @as(f32, @floatFromInt(i)) * 0.05,
            .reward = @as(f32, @floatFromInt(i)) * 0.01,
            .success = i > 50,
            .memory_mb = 100.0,
            .cpu_pct = 45.0,
            .elapsed_ms = 100,
        });
    }

    try std.testing.expectEqual(@as(usize, 100), monitor.history.items.len);
    const report = monitor.generateReport();
    try std.testing.expect(report.loss_drift < 0);
    try std.testing.expect(report.success_rate > 0);
}

test "stability monitor detects divergence" {
    const allocator = std.testing.allocator;
    var monitor = StabilityMonitor.init(allocator, .{ .divergence_threshold = 0.5 });
    defer monitor.deinit();

    _ = monitor.record(.{ .episode = 0, .loss = 1.0, .reward = 0, .success = true, .memory_mb = 100, .cpu_pct = 50, .elapsed_ms = 100 });
    _ = monitor.record(.{ .episode = 1, .loss = 10.0, .reward = 0, .success = false, .memory_mb = 100, .cpu_pct = 50, .elapsed_ms = 100 });

    try std.testing.expect(monitor.divergence_count > 0);
}

test "stability monitor memory budget" {
    const allocator = std.testing.allocator;
    var monitor = StabilityMonitor.init(allocator, .{ .max_memory_mb = 100 });
    defer monitor.deinit();

    const ok = monitor.record(.{ .episode = 0, .loss = 1.0, .reward = 0, .success = true, .memory_mb = 50, .cpu_pct = 50, .elapsed_ms = 100 });
    try std.testing.expect(ok);

    const over = monitor.record(.{ .episode = 1, .loss = 1.0, .reward = 0, .success = true, .memory_mb = 200, .cpu_pct = 50, .elapsed_ms = 100 });
    try std.testing.expect(!over);
}

test "stability report convergence check" {
    const allocator = std.testing.allocator;
    var monitor = StabilityMonitor.init(allocator, .{});
    defer monitor.deinit();

    for (0..2000) |i| {
        _ = monitor.record(.{
            .episode = @intCast(i),
            .loss = 5.0 - @as(f32, @floatFromInt(i)) * 0.002,
            .reward = 0.5,
            .success = true,
            .memory_mb = 50,
            .cpu_pct = 40,
            .elapsed_ms = 50,
        });
    }

    const report = monitor.generateReport();
    try std.testing.expect(report.converged);
}
