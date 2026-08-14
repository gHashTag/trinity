const std = @import("std");

pub const DatasetType = enum {
    code_completion,
    medical_notes,
    scientific_papers,
    synthetic,
};

pub const DatasetSpec = struct {
    name: []const u8,
    dataset_type: DatasetType,
    num_samples: usize,
    avg_tokens_per_sample: usize,
    vocab_coverage: f32,
};

pub const BenchmarkMetrics = struct {
    ppl: f32,
    accuracy: f32,
    training_epochs_per_hour: f32,
    inference_tok_per_sec: f32,
    model_size_mb: f32,
};

pub const FormatComparison = struct {
    format_name: []const u8,
    bits_per_weight: f32,
    metrics: BenchmarkMetrics,
    gap_vs_fp32_ppl: f32,
};

pub const DomainBenchmark = struct {
    allocator: std.mem.Allocator,
    dataset: DatasetSpec,
    comparisons: std.ArrayList(FormatComparison),
    fp32_baseline: ?BenchmarkMetrics,

    pub fn init(allocator: std.mem.Allocator, dataset: DatasetSpec) DomainBenchmark {
        return .{
            .allocator = allocator,
            .dataset = dataset,
            .comparisons = std.ArrayList(FormatComparison).init(allocator),
            .fp32_baseline = null,
        };
    }

    pub fn deinit(self: *DomainBenchmark) void {
        self.comparisons.deinit();
    }

    pub fn setBaseline(self: *DomainBenchmark, metrics: BenchmarkMetrics) void {
        self.fp32_baseline = metrics;
    }

    pub fn addComparison(self: *DomainBenchmark, comp: FormatComparison) !void {
        if (self.fp32_baseline) |baseline| {
            var mut_comp = comp;
            mut_comp.gap_vs_fp32_ppl = (comp.metrics.ppl - baseline.ppl) / baseline.ppl * 100.0;
            try self.comparisons.append(mut_comp);
        } else {
            try self.comparisons.append(comp);
        }
    }

    pub fn passesThreshold(self: *const DomainBenchmark, max_ppl_gap_pct: f32) bool {
        for (self.comparisons.items) |comp| {
            if (comp.gap_vs_fp32_ppl > max_ppl_gap_pct) return false;
        }
        return true;
    }

    pub fn printReport(self: *const DomainBenchmark, writer: anytype) !void {
        try writer.print("\n  Domain Benchmark: {s} ({s})\n", .{ self.dataset.name, @tagName(self.dataset.dataset_type) });
        try writer.print("  {s}\n", .{"-" * 72});
        try writer.print("  Samples: {d} | Avg tokens: {d} | Vocab coverage: {d:.0}%\n\n", .{
            self.dataset.num_samples,
            self.dataset.avg_tokens_per_sample,
            self.dataset.vocab_coverage * 100,
        });

        if (self.fp32_baseline) |bl| {
            try writer.print("  FP32 Baseline: PPL={d:.2}, tok/s={d:.0}, size={d:.1}MB\n\n", .{
                bl.ppl,
                bl.inference_tok_per_sec,
                bl.model_size_mb,
            });
        }

        try writer.print("  {s:<12} {s:>6} {s:>8} {s:>8} {s:>12} {s:>8}\n", .{
            "Format", "Bits", "PPL", "Acc%", "Tok/s", "PPL Gap" });
        try writer.print("  {s}\n", .{"-" * 72});

        for (self.comparisons.items) |comp| {
            try writer.print("  {s:<12} {d:>5.1} {d:>8.2} {d:>7.1}% {d:>11.0} {d:>7.1}%\n", .{
                comp.format_name,
                comp.bits_per_weight,
                comp.metrics.ppl,
                comp.metrics.accuracy * 100,
                comp.metrics.inference_tok_per_sec,
                comp.gap_vs_fp32_ppl,
            });
        }
        try writer.print("  {s}\n\n", .{"-" * 72});
    }
};

pub const BenchmarkSuite = struct {
    allocator: std.mem.Allocator,
    benchmarks: std.ArrayList(DomainBenchmark),

    pub fn init(allocator: std.mem.Allocator) BenchmarkSuite {
        return .{
            .allocator = allocator,
            .benchmarks = std.ArrayList(DomainBenchmark).init(allocator),
        };
    }

    pub fn deinit(self: *BenchmarkSuite) void {
        for (self.benchmarks.items) |*b| b.deinit();
        self.benchmarks.deinit();
    }

    pub fn addDataset(self: *BenchmarkSuite, spec: DatasetSpec) !*DomainBenchmark {
        try self.benchmarks.append(DomainBenchmark.init(self.allocator, spec));
        return &self.benchmarks.items[self.benchmarks.items.len - 1];
    }

    pub fn allPassThreshold(self: *const BenchmarkSuite, max_ppl_gap_pct: f32) bool {
        for (self.benchmarks.items) |b| {
            if (!b.passesThreshold(max_ppl_gap_pct)) return false;
        }
        return true;
    }

    pub fn overallSummary(self: *const BenchmarkSuite) struct { avg_ppl_gap: f32, datasets: usize, passing: usize } {
        var total_gap: f32 = 0;
        var count: usize = 0;
        var passing: usize = 0;
        for (self.benchmarks.items) |b| {
            for (b.comparisons.items) |c| {
                total_gap += c.gap_vs_fp32_ppl;
                count += 1;
                if (c.gap_vs_fp32_ppl <= 10.0) passing += 1;
            }
        }
        return .{
            .avg_ppl_gap = if (count > 0) total_gap / @as(f32, @floatFromInt(count)) else 0,
            .datasets = self.benchmarks.items.len,
            .passing = passing,
        };
    }
};

test "domain benchmark with baseline" {
    const allocator = std.testing.allocator;
    var bench = DomainBenchmark.init(allocator, .{
        .name = "ArXiv Abstracts",
        .dataset_type = .scientific_papers,
        .num_samples = 50000,
        .avg_tokens_per_sample = 150,
        .vocab_coverage = 0.85,
    });
    defer bench.deinit();

    bench.setBaseline(.{
        .ppl = 45.0,
        .accuracy = 0.0,
        .training_epochs_per_hour = 12.0,
        .inference_tok_per_sec = 15000,
        .model_size_mb = 10.8,
    });

    try bench.addComparison(.{
        .format_name = "Ternary",
        .bits_per_weight = 2,
        .metrics = .{
            .ppl = 49.5,
            .accuracy = 0.0,
            .training_epochs_per_hour = 18.0,
            .inference_tok_per_sec = 45000,
            .model_size_mb = 2.7,
        },
        .gap_vs_fp32_ppl = 0,
    });

    try std.testing.expect(bench.comparisons.items.len == 1);
    try std.testing.expect(bench.comparisons.items[0].gap_vs_fp32_ppl > 0);
}

test "benchmark suite multi-dataset" {
    const allocator = std.testing.allocator;
    var suite = BenchmarkSuite.init(allocator);
    defer suite.deinit();

    const b1 = try suite.addDataset(.{
        .name = "GitHub Code",
        .dataset_type = .code_completion,
        .num_samples = 100000,
        .avg_tokens_per_sample = 200,
        .vocab_coverage = 0.92,
    });

    const b2 = try suite.addDataset(.{
        .name = "ArXiv",
        .dataset_type = .scientific_papers,
        .num_samples = 50000,
        .avg_tokens_per_sample = 150,
        .vocab_coverage = 0.85,
    });

    b1.setBaseline(.{ .ppl = 30, .accuracy = 0.0, .training_epochs_per_hour = 12, .inference_tok_per_sec = 15000, .model_size_mb = 10.8 });
    b2.setBaseline(.{ .ppl = 45, .accuracy = 0.0, .training_epochs_per_hour = 10, .inference_tok_per_sec = 14000, .model_size_mb = 10.8 });

    try b1.addComparison(.{ .format_name = "GF16", .bits_per_weight = 16, .metrics = .{ .ppl = 30.5, .accuracy = 0.0, .training_epochs_per_hour = 14, .inference_tok_per_sec = 20000, .model_size_mb = 5.4 }, .gap_vs_fp32_ppl = 0 });
    try b2.addComparison(.{ .format_name = "GF16", .bits_per_weight = 16, .metrics = .{ .ppl = 46.0, .accuracy = 0.0, .training_epochs_per_hour = 12, .inference_tok_per_sec = 19000, .model_size_mb = 5.4 }, .gap_vs_fp32_ppl = 0 });

    const summary = suite.overallSummary();
    try std.testing.expectEqual(@as(usize, 2), summary.datasets);
    try std.testing.expect(summary.avg_ppl_gap < 10.0);
}

test "pass threshold check" {
    const allocator = std.testing.allocator;
    var bench = DomainBenchmark.init(allocator, .{
        .name = "test",
        .dataset_type = .synthetic,
        .num_samples = 100,
        .avg_tokens_per_sample = 50,
        .vocab_coverage = 0.5,
    });
    defer bench.deinit();

    bench.setBaseline(.{ .ppl = 100, .accuracy = 0.0, .training_epochs_per_hour = 1, .inference_tok_per_sec = 1, .model_size_mb = 1 });
    try bench.addComparison(.{ .format_name = "Ternary", .bits_per_weight = 2, .metrics = .{ .ppl = 108, .accuracy = 0.0, .training_epochs_per_hour = 2, .inference_tok_per_sec = 3, .model_size_mb = 0.25 }, .gap_vs_fp32_ppl = 0 });

    try std.testing.expect(bench.passesThreshold(10.0));
    try std.testing.expect(!bench.passesThreshold(5.0));
}
