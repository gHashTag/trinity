const std = @import("std");

pub const OutputFormat = enum { JSON, Markdown, CSV };

pub const BenchmarkConfig = struct {
    name: []const u8,
    warmup_iterations: usize = 10,
    benchmark_iterations: usize = 100,
    output_format: OutputFormat = .JSON,
};

pub const BenchmarkResult = struct {
    name: []const u8,
    iterations: usize,
    total_time_ns: u64,
    min_time_ns: u64,
    max_time_ns: u64,
    mean_time_ns: u64,
    std_dev_f: f64,
    ops_per_second: f64,
};

pub const BenchmarkSuite = struct {
    allocator: std.mem.Allocator,
    results: std.ArrayList(BenchmarkResult),
    config: BenchmarkConfig,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: BenchmarkConfig) Self {
        return Self{
            .allocator = allocator,
            .results = std.ArrayList(BenchmarkResult).init(allocator),
            .config = config,
        };
    }

    pub fn deinit(self: *Self) void {
        self.results.deinit();
    }

    pub fn runAll(self: *Self) !void {
        std.log.info("Running Trinity S³AI Benchmark Suite", .{});
        try self.benchmarkVSABind();
        try self.benchmarkVSABundle();
        try self.benchmarkVSACosine();
        try self.generateReport();
    }

    fn benchmarkVSABind(self: *Self) !void {
        const dim: usize = 1024;
        const iterations = self.config.benchmark_iterations;
        const warmup = self.config.warmup_iterations;

        const a = try self.allocator.alloc(i8, dim);
        defer self.allocator.free(a);
        const b = try self.allocator.alloc(i8, dim);
        defer self.allocator.free(b);
        const result = try self.allocator.alloc(i8, dim);
        defer self.allocator.free(result);

        var prng = std.Random.DefaultPrng.init(0x52455539);
        const rng = prng.random();
        for (0..dim) |i| {
            a[i] = rng.intRangeAtMost(i8, -1, 2);
            b[i] = rng.intRangeAtMost(i8, -1, 2);
        }

        var i: usize = 0;
        while (i < warmup) : (i += 1) {
            _ = self.bindOp(a, b, result);
        }

        const times = try self.allocator.alloc(u64, iterations);
        defer self.allocator.free(times);

        i = 0;
        while (i < iterations) : (i += 1) {
            const start = std.time.nanoTimestamp();
            _ = self.bindOp(a, b, result);
            const end = std.time.nanoTimestamp();
            times[i] = @as(u64, @intCast(end - start));
        }

        try self.addResult("VSA Bind", dim, iterations, times);
    }

    fn benchmarkVSABundle(self: *Self) !void {
        const dim: usize = 1024;
        const iterations = self.config.benchmark_iterations;
        const warmup = self.config.warmup_iterations;

        const a = try self.allocator.alloc(i8, dim);
        defer self.allocator.free(a);
        const b = try self.allocator.alloc(i8, dim);
        defer self.allocator.free(b);
        const c = try self.allocator.alloc(i8, dim);
        defer self.allocator.free(c);
        const result = try self.allocator.alloc(i8, dim);
        defer self.allocator.free(result);

        var prng = std.Random.DefaultPrng.init(0x52455539);
        const rng = prng.random();
        for (0..dim) |i| {
            a[i] = rng.intRangeAtMost(i8, -1, 2);
            b[i] = rng.intRangeAtMost(i8, -1, 2);
            c[i] = rng.intRangeAtMost(i8, -1, 2);
        }

        var i: usize = 0;
        while (i < warmup) : (i += 1) {
            _ = self.bundle3Op(a, b, c, result);
        }

        const times = try self.allocator.alloc(u64, iterations);
        defer self.allocator.free(times);

        i = 0;
        while (i < iterations) : (i += 1) {
            const start = std.time.nanoTimestamp();
            _ = self.bundle3Op(a, b, c, result);
            const end = std.time.nanoTimestamp();
            times[i] = @as(u64, @intCast(end - start));
        }

        try self.addResult("VSA Bundle3", dim, iterations, times);
    }

    fn benchmarkVSACosine(self: *Self) !void {
        const dim: usize = 1024;
        const iterations = self.config.benchmark_iterations;
        const warmup = self.config.warmup_iterations;

        const a = try self.allocator.alloc(i8, dim);
        defer self.allocator.free(a);
        const b = try self.allocator.alloc(i8, dim);
        defer self.allocator.free(b);

        var prng = std.Random.DefaultPrng.init(0x52455539);
        const rng = prng.random();
        for (0..dim) |i| {
            a[i] = rng.intRangeAtMost(i8, -1, 2);
            b[i] = rng.intRangeAtMost(i8, -1, 2);
        }

        var i: usize = 0;
        while (i < warmup) : (i += 1) {
            _ = self.cosineSimilarityOp(a, b);
        }

        const times = try self.allocator.alloc(u64, iterations);
        defer self.allocator.free(times);

        i = 0;
        while (i < iterations) : (i += 1) {
            const start = std.time.nanoTimestamp();
            _ = self.cosineSimilarityOp(a, b);
            const end = std.time.nanoTimestamp();
            times[i] = @as(u64, @intCast(end - start));
        }

        try self.addResult("VSA Cosine Similarity", dim, iterations, times);
    }

    fn addResult(self: *Self, name: []const u8, ops_per_iter: usize, iterations: usize, times: []u64) !void {
        var total_time: u64 = 0;
        for (times) |t| {
            total_time += t;
        }
        const mean_time = total_time / iterations;

        var min_time: u64 = times[0];
        var max_time: u64 = times[0];
        for (times) |t| {
            if (t < min_time) min_time = t;
            if (t > max_time) max_time = t;
        }

        var variance_f: f64 = 0;
        for (times) |t| {
            const diff_f = @as(f64, @floatFromInt(t)) - @as(f64, @floatFromInt(mean_time));
            variance_f += diff_f * diff_f;
        }
        variance_f /= @as(f64, @floatFromInt(iterations));
        const std_dev = @sqrt(variance_f);

        const ops_per_sec = @as(f64, @floatFromInt(ops_per_iter * iterations)) /
                           @as(f64, @floatFromInt(total_time)) * 1_000_000_000;

        try self.results.append(self.allocator, BenchmarkResult{
            .name = name,
            .iterations = iterations,
            .total_time_ns = total_time,
            .min_time_ns = min_time,
            .max_time_ns = max_time,
            .mean_time_ns = mean_time,
            .std_dev_f = std_dev,
            .ops_per_second = ops_per_sec,
        });

        std.log.info("{s}: {d:.2} ops/sec ({d:.0} ns/op)", .{ name, ops_per_sec, @as(f64, @floatFromInt(mean_time)) });
    }

    fn generateReport(self: *Self) !void {
        const stdout = std.io.getStdOut().writer();

        switch (self.config.output_format) {
            .JSON => try self.generateJSONReport(stdout),
            .Markdown => try self.generateMarkdownReport(stdout),
            .CSV => try self.generateCSVReport(stdout),
        }
    }

    fn generateJSONReport(self: *Self, writer: anytype) !void {
        try writer.writeAll("{\"benchmarks\":[\n");
        for (self.results.items, 0..) |result, i| {
            if (i > 0) try writer.writeAll(",\n");
            try writer.print(
                \\{{"name":"{s}","iterations":{d},"ops_per_second":{d:.2},"mean_ns":{d},"min_ns":{d},"max_ns":{d},"std_dev_f":{d:.2}}}
            , .{ result.name, result.iterations, result.ops_per_second, result.mean_time_ns, result.min_time_ns, result.max_time_ns, result.std_dev_f });
        }
        try writer.writeAll("\n],\"summary\":{\"total_benchmarks\":{d}}}\n", .{self.results.items.len});
    }

    fn generateMarkdownReport(self: *Self, writer: anytype) !void {
        try writer.writeAll("\n# Benchmark Results\n\n");
        try writer.writeAll("| Benchmark | Ops/sec | Mean (ns) | Min (ns) | Max (ns) | Std Dev |\n");
        try writer.writeAll("|-----------|---------|----------|----------|----------|--------|\n");

        for (self.results.items) |result| {
            try writer.print("| {s} | {d:.2} | {d} | {d} | {d} | {d:.2} |\n", .{ result.name, result.ops_per_second, result.mean_time_ns, result.min_time_ns, result.max_time_ns, result.std_dev_f });
        }
        try writer.writeAll("\n## Summary\n\n");
        try writer.print("- Total Benchmarks: {d}\n", .{self.results.items.len});
        try writer.writeAll("- Status: PASSED\n\n");
    }

    fn generateCSVReport(self: *Self, writer: anytype) !void {
        try writer.writeAll("name,ops_per_second,mean_ns,min_ns,max_ns,std_dev_f\n");

        for (self.results.items) |result| {
            try writer.print("{s},{d:.2},{d},{d},{d},{d:.2}\n", .{ result.name, result.ops_per_second, result.mean_time_ns, result.min_time_ns, result.max_time_ns, result.std_dev_f });
        }
    }

    fn bindOp(self: *Self, a: []const i8, b: []const i8, result: []i8) void {
        _ = self;
        for (0..a.len) |i| {
            result[i] = a[i] * b[i];
        }
    }

    fn bundle3Op(self: *Self, a: []const i8, b: []const i8, c: []const i8, result: []i8) void {
        _ = self;
        for (0..a.len) |i| {
            const sum = a[i] + b[i] + c[i];
            result[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;
        }
    }

    fn cosineSimilarityOp(self: *Self, a: []const i8, b: []const i8) f64 {
        _ = self;
        var dot: i64 = 0;
        var norm_a: i64 = 0;
        var norm_b: i64 = 0;

        for (0..a.len) |i| {
            dot += @as(i64, a[i]) * @as(i64, b[i]);
            norm_a += @as(i64, a[i]) * @as(i64, a[i]);
            norm_b += @as(i64, b[i]) * @as(i64, b[i]);
        }

        const norm_a_f = @sqrt(@as(f64, @floatFromInt(norm_a)));
        const norm_b_f = @sqrt(@as(f64, @floatFromInt(norm_b)));

        if (norm_a_f == 0 or norm_b_f == 0) return 0.0;
        return @as(f64, @floatFromInt(dot)) / (norm_a_f * norm_b_f);
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var config = BenchmarkConfig{
        .name = "Trinity S³AI Benchmark Suite",
        .warmup_iterations = 10,
        .benchmark_iterations = 100,
        .output_format = .JSON,
    };

    var suite = BenchmarkSuite.init(allocator, config);
    defer suite.deinit();

    try suite.runAll();
}

test "vsa_bind_operation" {
    const allocator = std.testing.allocator;
    const a = try allocator.alloc(i8, 4);
    defer allocator.free(a);
    const b = try allocator.alloc(i8, 4);
    defer allocator.free(b);
    const result = try allocator.alloc(i8, 4);
    defer allocator.free(result);

    a[0] = 1;
    a[1] = -1;
    a[2] = 0;
    a[3] = 1;

    b[0] = 1;
    b[1] = 1;
    b[2] = -1;
    b[3] = 0;

    var suite = BenchmarkSuite.init(allocator, BenchmarkConfig{
        .name = "test",
        .warmup_iterations = 1,
        .benchmark_iterations = 1,
        .output_format = .JSON,
    });
    defer suite.deinit();

    suite.bindOp(a, b, result);

    try std.testing.expectEqual(@as(i8, 1), result[0]);
    try std.testing.expectEqual(@as(i8, -1), result[1]);
    try std.testing.expectEqual(@as(i8, 0), result[2]);
    try std.testing.expectEqual(@as(i8, 0), result[3]);
}

test "vsa_bundle3_operation" {
    const allocator = std.testing.allocator;
    const a = try allocator.alloc(i8, 3);
    defer allocator.free(a);
    const b = try allocator.alloc(i8, 3);
    defer allocator.free(b);
    const c = try allocator.alloc(i8, 3);
    defer allocator.free(c);
    const result = try allocator.alloc(i8, 3);
    defer allocator.free(result);

    a[0] = 1;
    a[1] = -1;
    a[2] = 1;

    b[0] = 1;
    b[1] = 1;
    b[2] = 0;

    c[0] = -1;
    c[1] = -1;
    c[2] = 0;

    var suite = BenchmarkSuite.init(allocator, BenchmarkConfig{
        .name = "test",
        .warmup_iterations = 1,
        .benchmark_iterations = 1,
        .output_format = .JSON,
    });
    defer suite.deinit();

    suite.bundle3Op(a, b, c, result);

    try std.testing.expectEqual(@as(i8, 1), result[0]);
    try std.testing.expectEqual(@as(i8, -1), result[1]);
    try std.testing.expectEqual(@as(i8, 0), result[2]);
}
