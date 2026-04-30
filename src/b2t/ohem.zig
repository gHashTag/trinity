const std = @import("std");

pub const OhemConfig = struct {
    hard_ratio: f32 = 0.7,
    min_keep: usize = 1,
    loss_threshold: f32 = std.math.inf(f32),
};

pub const OhemResult = struct {
    selected_indices: []usize,
    selected_losses: []f32,
    avg_loss: f32,
    hard_count: usize,
    total_count: usize,
};

pub const OhemMiner = struct {
    allocator: std.mem.Allocator,
    config: OhemConfig,

    pub fn init(allocator: std.mem.Allocator, config: OhemConfig) OhemMiner {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn mine(self: *OhemMiner, losses: []const f32) !OhemResult {
        const n = losses.len;
        if (n == 0) {
            return .{
                .selected_indices = &[_]usize{},
                .selected_losses = &[_]f32{},
                .avg_loss = 0.0,
                .hard_count = 0,
                .total_count = 0,
            };
        }

        const indices = try self.allocator.alloc(usize, n);
        errdefer self.allocator.free(indices);
        for (indices, 0..) |*idx, i| idx.* = i;

        const sorted = try self.allocator.dupe(usize, indices);
        errdefer self.allocator.free(sorted);

        const SortCtx = struct {
            losses: []const f32,
            pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
                return ctx.losses[a] > ctx.losses[b];
            }
        };
        std.mem.sort(usize, sorted, SortCtx{ .losses = losses }, SortCtx.lessThan);

        const keep_count = @max(
            @as(usize, @intFromFloat(@as(f32, @floatFromInt(n)) * self.config.hard_ratio)),
            self.config.min_keep,
        );
        const final_keep = @min(keep_count, n);

        const selected = try self.allocator.alloc(usize, final_keep);
        const sel_losses = try self.allocator.alloc(f32, final_keep);

        var sum: f32 = 0.0;
        for (0..final_keep) |i| {
            selected[i] = sorted[i];
            sel_losses[i] = losses[sorted[i]];
            sum += sel_losses[i];
        }

        self.allocator.free(indices);
        self.allocator.free(sorted);

        return .{
            .selected_indices = selected,
            .selected_losses = sel_losses,
            .avg_loss = if (final_keep > 0) sum / @as(f32, @floatFromInt(final_keep)) else 0.0,
            .hard_count = final_keep,
            .total_count = n,
        };
    }

    pub fn deinitResult(self: *OhemMiner, result: *OhemResult) void {
        self.allocator.free(result.selected_indices);
        self.allocator.free(result.selected_losses);
    }

    pub fn hardRatio(self: *const OhemMiner, result: *const OhemResult) f32 {
        if (result.total_count == 0) return 0.0;
        return @as(f32, @floatFromInt(result.hard_count)) / @as(f32, @floatFromInt(result.total_count));
    }
};

pub const LossStats = struct {
    mean: f32,
    max: f32,
    min: f32,
    variance: f32,
    above_mean_count: usize,
    total: usize,

    pub fn compute(losses: []const f32) LossStats {
        if (losses.len == 0) return .{ .mean = 0, .max = 0, .min = 0, .variance = 0, .above_mean_count = 0, .total = 0 };

        var sum: f32 = 0;
        var mx: f32 = -std.math.inf(f32);
        var mn: f32 = std.math.inf(f32);
        for (losses) |l| {
            sum += l;
            mx = @max(mx, l);
            mn = @min(mn, l);
        }
        const mean = sum / @as(f32, @floatFromInt(losses.len));

        var var_sum: f32 = 0;
        var above: usize = 0;
        for (losses) |l| {
            const d = l - mean;
            var_sum += d * d;
            if (l > mean) above += 1;
        }

        return .{
            .mean = mean,
            .max = mx,
            .min = mn,
            .variance = var_sum / @as(f32, @floatFromInt(losses.len)),
            .above_mean_count = above,
            .total = losses.len,
        };
    }
};

test "ohem selects hardest examples" {
    const allocator = std.testing.allocator;
    var miner = OhemMiner.init(allocator, .{ .hard_ratio = 0.5, .min_keep = 1 });

    const losses = [_]f32{ 0.1, 0.9, 0.2, 0.8, 0.3 };
    var result = try miner.mine(&losses);
    defer miner.deinitResult(&result);

    try std.testing.expectEqual(@as(usize, 2), result.hard_count);
    try std.testing.expect(result.selected_losses[0] >= result.selected_losses[1]);
    try std.testing.expect(result.avg_loss > 0.5);
}

test "ohem respects min_keep" {
    const allocator = std.testing.allocator;
    var miner = OhemMiner.init(allocator, .{ .hard_ratio = 0.01, .min_keep = 3 });

    const losses = [_]f32{ 0.1, 0.2, 0.3, 0.4, 0.5 };
    var result = try miner.mine(&losses);
    defer miner.deinitResult(&result);

    try std.testing.expectEqual(@as(usize, 3), result.hard_count);
}

test "ohem handles empty losses" {
    const allocator = std.testing.allocator;
    var miner = OhemMiner.init(allocator, .{});
    var result = try miner.mine(&[_]f32{});
    try std.testing.expectEqual(@as(usize, 0), result.hard_count);
}

test "ohem all examples equally hard" {
    const allocator = std.testing.allocator;
    var miner = OhemMiner.init(allocator, .{ .hard_ratio = 0.5 });

    const losses = [_]f32{ 0.5, 0.5, 0.5, 0.5 };
    var result = try miner.mine(&losses);
    defer miner.deinitResult(&result);

    try std.testing.expectEqual(@as(usize, 2), result.hard_count);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), result.avg_loss, 1e-6);
}

test "loss stats compute" {
    const losses = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const stats = LossStats.compute(&losses);

    try std.testing.expectApproxEqAbs(@as(f32, 3.0), stats.mean, 1e-6);
    try std.testing.expectEqual(@as(f32, 5.0), stats.max);
    try std.testing.expectEqual(@as(f32, 1.0), stats.min);
    try std.testing.expect(stats.variance > 0);
    try std.testing.expectEqual(@as(usize, 2), stats.above_mean_count);
}
