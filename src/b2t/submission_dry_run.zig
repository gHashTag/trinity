const std = @import("std");
const submit = @import("trios_submit.zig");

pub const DryRunConfig = struct {
    seeds: []const u32,
    target_bpb: f32 = 1.15,
    max_size_mb: f32 = 16.0,
    output_dir: []const u8 = "artifacts/submission",
};

pub const DryRunResult = struct {
    passed: bool,
    median_bpb: f32,
    median_mad: f32,
    candidate_seed: u32,
    candidate_bpb: f32,
    candidate_size_mb: f32,
    within_budget: bool,
    bpb_pass: bool,
    manifest_valid: bool,
};

pub const DryRunExecutor = struct {
    allocator: std.mem.Allocator,
    config: DryRunConfig,

    pub fn init(allocator: std.mem.Allocator, config: DryRunConfig) DryRunExecutor {
        return .{ .allocator = allocator, .config = config };
    }

    pub fn execute(self: *DryRunExecutor) !DryRunResult {
        var pipeline = submit.TriosSubmitPipeline.init(self.allocator, .{
            .seeds = self.config.seeds,
            .dry_run = true,
            .max_size_mb = self.config.max_size_mb,
        });
        defer pipeline.deinit();

        try pipeline.runAllSeeds();
        const manifest = try pipeline.generateManifest();
        defer {
            self.allocator.free(manifest.median.seeds);
            self.allocator.free(manifest.median.bpbs);
        }

        const bpb_pass = manifest.median.median_bpb < self.config.target_bpb;
        const valid = bpb_pass and manifest.size.within_budget;

        return .{
            .passed = valid,
            .median_bpb = manifest.median.median_bpb,
            .median_mad = manifest.median.mad,
            .candidate_seed = manifest.median.candidate_seed,
            .candidate_bpb = manifest.median.candidate_bpb,
            .candidate_size_mb = manifest.size.size_mb,
            .within_budget = manifest.size.within_budget,
            .bpb_pass = bpb_pass,
            .manifest_valid = manifest.valid,
        };
    }

    pub fn printReport(self: *const DryRunExecutor, result: *const DryRunResult, writer: anytype) !void {
        try writer.print("\n  Submission Dry-Run Report\n", .{});
        try writer.print("  {s}\n", .{"=" * 50});
        try writer.print("  Status:  {s}\n", .{if (result.passed) "PASS" else "FAIL"});
        try writer.print("  Median BPB:  {d:.4} (target: {d:.2})\n", .{ result.median_bpb, self.config.target_bpb });
        try writer.print("  MAD:         {d:.4}\n", .{result.median_mad});
        try writer.print("  Candidate:   seed={d} BPB={d:.4}\n", .{ result.candidate_seed, result.candidate_bpb });
        try writer.print("  Size:        {d:.2}MB / {d:.0}MB budget\n", .{ result.candidate_size_mb, self.config.max_size_mb });
        try writer.print("  BPB gate:    {s}\n", .{if (result.bpb_pass) "PASS" else "FAIL"});
        try writer.print("  Size gate:   {s}\n", .{if (result.within_budget) "PASS" else "FAIL"});
        try writer.print("  {s}\n\n", .{"=" * 50});
    }
};

pub const CandidateSelector = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CandidateSelector {
        return .{ .allocator = allocator };
    }

    pub fn selectBest(seeds: []const u32, bpbs: []const f32) struct { seed: u32, bpb: f32 } {
        std.debug.assert(seeds.len == bpbs.len);
        var best_idx: usize = 0;
        for (bpbs, 0..) |b, i| {
            if (b < bpbs[best_idx]) best_idx = i;
        }
        return .{ .seed = seeds[best_idx], .bpb = bpbs[best_idx] };
    }

    pub fn computeMedian(bpbs: []const f32) f32 {
        if (bpbs.len == 0) return 0;
        var sorted = bpbs[0..].*;
        std.mem.sort(f32, &sorted, {}, std.sort.asc(f32));
        return sorted[sorted.len / 2];
    }

    pub fn computeMAD(bpbs: []const f32, median: f32) f32 {
        var sum: f32 = 0;
        for (bpbs) |b| sum += @abs(b - median);
        return sum / @as(f32, @floatFromInt(bpbs.len));
    }
};

pub const ManifestWriter = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ManifestWriter {
        return .{ .allocator = allocator };
    }

    pub fn writeMedianReport(self: *ManifestWriter, seeds: []const u32, bpbs: []const f32, writer: anytype) !void {
        const median = CandidateSelector.computeMedian(bpbs);
        const mad = CandidateSelector.computeMAD(bpbs, median);
        const best = CandidateSelector.selectBest(seeds, bpbs);

        try writer.print("{{\n", .{});
        try writer.print("  \"seeds\": [{s}],\n", .{formatU32Array(seeds)});
        try writer.print("  \"bpbs\": [{s}],\n", .{formatF32Array(bpbs)});
        try writer.print("  \"median\": {d:.4},\n", .{median});
        try writer.print("  \"mad\": {d:.4},\n", .{mad});
        try writer.print("  \"candidate_seed\": {d},\n", .{best.seed});
        try writer.print("  \"candidate_bpb\": {d:.4}\n", .{best.bpb});
        try writer.print("}}\n", .{});
    }

    fn formatU32Array(values: []const u32) std.ArrayList(u8) {
        var buf = std.ArrayList(u8).init(self.allocator);
        for (values, 0..) |v, i| {
            if (i > 0) buf.writer().print(", ", .{}) catch {};
            buf.writer().print("{d}", .{v}) catch {};
        }
        return buf;
    }

    fn formatF32Array(values: []const f32) std.ArrayList(u8) {
        var buf = std.ArrayList(u8).init(self.allocator);
        for (values, 0..) |v, i| {
            if (i > 0) buf.writer().print(", ", .{}) catch {};
            buf.writer().print("{d:.4}", .{v}) catch {};
        }
        return buf;
    }
};

test "dry run passes with good BPB" {
    const allocator = std.testing.allocator;
    var executor = DryRunExecutor.init(allocator, .{
        .seeds = &[_]u32{ 42, 43, 44 },
        .target_bpb = 2.0,
    });

    const result = try executor.execute();
    try std.testing.expect(result.bpb_pass);
    try std.testing.expect(result.median_bpb > 0);
}

test "dry run result structure" {
    const allocator = std.testing.allocator;
    var executor = DryRunExecutor.init(allocator, .{
        .seeds = &[_]u32{42},
    });

    const result = try executor.execute();
    try std.testing.expect(result.candidate_seed == 42);
    try std.testing.expect(result.candidate_size_mb > 0);
}

test "candidate selector picks best" {
    const seeds = [_]u32{ 42, 43, 44, 45, 46 };
    const bpbs = [_]f32{ 1.12, 1.08, 1.14, 1.09, 1.11 };

    const best = CandidateSelector.selectBest(&seeds, &bpbs);
    try std.testing.expectEqual(@as(u32, 43), best.seed);
    try std.testing.expectApproxEqAbs(@as(f32, 1.08), best.bpb, 1e-6);
}

test "median computation" {
    const bpbs = [_]f32{ 1.12, 1.08, 1.14, 1.09, 1.11 };
    const median = CandidateSelector.computeMedian(&bpbs);
    try std.testing.expectApproxEqAbs(@as(f32, 1.11), median, 0.01);
}

test "MAD computation" {
    const bpbs = [_]f32{ 1.0, 1.0, 1.0, 1.0, 1.0 };
    const mad = CandidateSelector.computeMAD(&bpbs, 1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), mad, 1e-6);
}
