const std = @import("std");

pub const EntropyGate = struct {
    id: []const u8,
    description: []const u8,
    threshold: f32,
    passed: bool,
    value: f32,
};

pub const SweepResult = struct {
    gate_id: []const u8,
    entropy: f32,
    rank: usize,
    passed: bool,
};

pub const SweepConfig = struct {
    num_samples: usize = 10000,
    vocab_size: usize = 729,
    grid_size: usize = 9,
    num_states: usize = 9,
    top_k: usize = 3,
};

pub fn computeShannonEntropy(distribution: []const f32) f32 {
    var entropy: f32 = 0;
    for (distribution) |p| {
        if (p > 1e-10) {
            entropy -= p * std.math.log2(p);
        }
    }
    return entropy;
}

pub fn computeEntropyFromCounts(counts: []const u32) f32 {
    var total: f32 = 0;
    for (counts) |c| total += @as(f32, @floatFromInt(c));
    if (total < 1e-10) return 0;

    var entropy: f32 = 0;
    for (counts) |c| {
        const p = @as(f32, @floatFromInt(c)) / total;
        if (p > 1e-10) {
            entropy -= p * std.math.log2(p);
        }
    }
    return entropy;
}

pub const EntropySweeper = struct {
    allocator: std.mem.Allocator,
    config: SweepConfig,
    rng: std.Random.DefaultPrng,

    pub fn init(allocator: std.mem.Allocator, config: SweepConfig) EntropySweeper {
        return .{
            .allocator = allocator,
            .config = config,
            .rng = std.Random.DefaultPrng.init(42),
        };
    }

    pub fn sweepGate(self: *EntropySweeper, gate_id: []const u8, threshold: f32) !SweepResult {
        const counts = try self.allocator.alloc(u32, self.config.vocab_size);
        defer self.allocator.free(counts);
        @memset(counts, 0);

        const random = self.rng.random();
        for (0..self.config.num_samples) |_| {
            const idx = random.intRangeLessThan(usize, 0, self.config.vocab_size);
            counts[idx] += 1;
        }

        const entropy = computeEntropyFromCounts(counts);
        const passed = entropy >= threshold;

        return .{
            .gate_id = gate_id,
            .entropy = entropy,
            .rank = 0,
            .passed = passed,
        };
    }

    pub fn sweepAll(self: *EntropySweeper, gates: []const EntropyGate) ![]SweepResult {
        var results = try self.allocator.alloc(SweepResult, gates.len);

        for (gates, results) |gate, *result| {
            result.* = try self.sweepGate(gate.id, gate.threshold);
        }

        for (results, 0..) |r, i| {
            var rank: usize = 1;
            for (results) |other| {
                if (other.entropy > r.entropy) rank += 1;
            }
            results[i].rank = rank;
        }

        return results;
    }

    pub fn topK(self: *EntropySweeper, results: []SweepResult, k: usize) []SweepResult {
        var sorted = self.allocator.dupe(SweepResult, results) catch return results[0..@min(k, results.len)];
        std.mem.sort(SweepResult, sorted, {}, struct {
            pub fn lessThan(_: void, a: SweepResult, b: SweepResult) bool {
                return a.entropy > b.entropy;
            }
        }.lessThan);
        return sorted[0..@min(k, sorted.len)];
    }
};

pub fn printSweepReport(results: []const SweepResult, top_results: []const SweepResult, writer: anytype) !void {
    try writer.print("\n  G1-G8 Entropy Sweep Results\n", .{});
    try writer.print("  {s}\n", .{"-" * 60});
    try writer.print("  {s:<8} {s:>12} {s:>6} {s:>8}\n", .{ "Gate", "Entropy", "Rank", "Passed" });
    try writer.print("  {s}\n", .{"-" * 60});
    for (results) |r| {
        const status = if (r.passed) "PASS" else "FAIL";
        try writer.print("  {s:<8} {d:>12.4} {d:>6} {s:>8}\n", .{ r.gate_id, r.entropy, r.rank, status });
    }
    try writer.print("  {s}\n", .{"-" * 60});
    try writer.print("  Top-{d}:\n", .{top_results.len});
    for (top_results) |r| {
        try writer.print("    {s}: {d:.4}\n", .{ r.gate_id, r.entropy });
    }
    try writer.print("\n", .{});
}

test "Shannon entropy uniform distribution" {
    const dist = [_]f32{ 0.25, 0.25, 0.25, 0.25 };
    const h = computeShannonEntropy(&dist);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), h, 0.01);
}

test "Shannon entropy single value" {
    const dist = [_]f32{ 1.0, 0.0, 0.0 };
    const h = computeShannonEntropy(&dist);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), h, 0.01);
}

test "entropy from counts" {
    const counts = [_]u32{ 250, 250, 250, 250 };
    const h = computeEntropyFromCounts(&counts);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), h, 0.01);
}

test "sweep gate produces valid result" {
    const allocator = std.testing.allocator;
    var sweeper = EntropySweeper.init(allocator, .{ .num_samples = 1000, .vocab_size = 27 });

    const result = try sweeper.sweepGate("G1", 2.0);
    try std.testing.expect(result.entropy > 0);
    try std.testing.expect(result.entropy < 10.0);
}

test "sweep all gates" {
    const allocator = std.testing.allocator;
    var sweeper = EntropySweeper.init(allocator, .{ .num_samples = 500, .vocab_size = 27 });

    const gates = [_]EntropyGate{
        .{ .id = "G1", .description = "token", .threshold = 3.0, .passed = false, .value = 0 },
        .{ .id = "G2", .description = "attention", .threshold = 2.0, .passed = false, .value = 0 },
        .{ .id = "G3", .description = "weight", .threshold = 1.0, .passed = false, .value = 0 },
    };

    const results = try sweeper.sweepAll(&gates);
    defer allocator.free(results);

    try std.testing.expectEqual(@as(usize, 3), results.len);
    for (results) |r| {
        try std.testing.expect(r.rank >= 1);
    }
}
