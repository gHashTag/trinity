const std = @import("std");
const time = std.time;

const BenchmarkResult = struct {
    name: []const u8,
    iterations: u64,
    total_ns: u64,
    avg_ns: u64,
    min_ns: u64,
    max_ns: u64,
    ops_per_sec: f64,
};

const BenchmarkSuite = struct {
    results: std.ArrayList(BenchmarkResult),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) BenchmarkSuite {
        return .{
            .results = std.ArrayList(BenchmarkResult).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BenchmarkSuite) void {
        self.results.deinit();
    }

    pub fn run(self: *BenchmarkSuite, comptime name: []const u8, comptime func: fn (allocator: std.mem.Allocator) void, iterations: u64) !void {
        const allocator = self.allocator;

        var min_ns: u64 = std.math.maxInt(u64);
        var max_ns: u64 = 0;
        var total_ns: u64 = 0;

        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            const start = time.nanoTimestamp();
            func(allocator);
            const elapsed = @as(u64, @intCast(time.nanoTimestamp() - start));

            if (elapsed < min_ns) min_ns = elapsed;
            if (elapsed > max_ns) max_ns = elapsed;
            total_ns += elapsed;
        }

        const avg_ns = total_ns / iterations;
        const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(total_ns)) / 1e9);

        const result = BenchmarkResult{
            .name = name,
            .iterations = iterations,
            .total_ns = total_ns,
            .avg_ns = avg_ns,
            .min_ns = min_ns,
            .max_ns = max_ns,
            .ops_per_sec = ops_per_sec,
        };

        try self.results.append(result);
    }

    pub fn printReport(self: *BenchmarkSuite) void {
        const stdout = std.io.getStdOut().writer();

        stdout.print("\n{s}\n", .{"=" ** 72}) catch {};
        stdout.print("  TRINITY Benchmark Suite — Results\n", .{});
        stdout.print("{s}\n\n", .{"=" * 72}) catch {};

        stdout.print("  {s:<30} {s:>10} {s:>10} {s:>10} {s:>12}\n", .{ "Benchmark", "Avg (ns)", "Min (ns)", "Max (ns)", "ops/sec" });
        stdout.print("  {s}\n", .{"-" * 72}) catch {};

        for (self.results.items) |r| {
            stdout.print("  {s:<30} {d:>10} {d:>10} {d:>10} {d:>12.1}\n", .{
                r.name,
                r.avg_ns,
                r.min_ns,
                r.max_ns,
                r.ops_per_sec,
            }) catch {};
        }

        stdout.print("\n{s}\n", .{"=" * 72}) catch {};
    }

    pub fn exportJson(self: *BenchmarkSuite) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        try buf.appendSlice("{\"benchmarks\":[\n");

        for (self.results.items, 0..) |r, i| {
            if (i > 0) try buf.appendSlice(",\n");
            try std.fmt.format(buf.writer(),
                \\  {{"name":"{s}","iterations":{d},"total_ns":{d},"avg_ns":{d},"min_ns":{d},"max_ns":{d},"ops_per_sec":{d:.1}}}
            , .{ r.name, r.iterations, r.total_ns, r.avg_ns, r.min_ns, r.max_ns, r.ops_per_sec });
        }

        try buf.appendSlice("\n]}\n");
        return buf.toOwnedSlice();
    }
};

fn benchTernaryEncode(allocator: std.mem.Allocator) void {
    var values = [_]f64{ 0.0, 1.0, -1.0, 0.5, -0.5, 1.618, -1.618, 3.14159 };
    var encoded = [_]u8{0} ** 8;
    for (&values, 0..) |v, i| {
        encoded[i] = if (v > 0.33) @as(u8, 1) else if (v < -0.33) @as(u8, 255) else @as(u8, 0);
    }
    _ = allocator;
    _ = encoded;
}

fn benchTernaryMatmul(allocator: std.mem.Allocator) void {
    const N: usize = 64;
    var a: [N]f64 = undefined;
    var b: [N]f64 = undefined;
    var c: [N]f64 = undefined;

    for (&a, 0..) |*v, i| v.* = @floatFromInt(i % 3 - 1);
    for (&b, 0..) |*v, i| v.* = @floatFromInt((i + 1) % 3 - 1);

    for (&c, 0..) |*v, i| {
        var sum: f64 = 0;
        var j: usize = 0;
        while (j < N) : (j += 1) {
            sum += a[j] * b[(i + j) % N];
        }
        v.* = sum;
    }
    _ = allocator;
}

fn benchVsaBind(allocator: std.mem.Allocator) void {
    const dim = 1024;
    var a: [dim]f64 = undefined;
    var b: [dim]f64 = undefined;
    var result: [dim]f64 = undefined;

    for (&a, 0..) |*v, i| v.* = if (i % 2 == 0) 1.0 else -1.0;
    for (&b, 0..) |*v, i| v.* = if (i % 3 == 0) 1.0 else -1.0;

    for (&result, 0..) |*v, i| v.* = a[i] * b[i];
    _ = allocator;
}

fn benchVsaBundle(allocator: std.mem.Allocator) void {
    const dim = 1024;
    const n_vecs = 10;
    var vecs: [n_vecs][dim]f64 = undefined;
    var result: [dim]f64 = undefined;

    for (&vecs, 0..) |*vec, vi| {
        for (vec, 0..) |*v, i| {
            v.* = if ((vi + i) % 2 == 0) 1.0 else -1.0;
        }
    }

    for (&result, 0..) |*v, i| {
        var sum: f64 = 0;
        for (&vecs, 0..) |*vec, _| {
            sum += vec[i];
        }
        v.* = sum / @as(f64, @floatFromInt(n_vecs));
    }
    _ = allocator;
}

fn benchVsaCosine(allocator: std.mem.Allocator) void {
    const dim = 1024;
    var a: [dim]f64 = undefined;
    var b: [dim]f64 = undefined;

    for (&a, 0..) |*v, i| v.* = if (i % 2 == 0) 1.0 else -1.0;
    for (&b, 0..) |*v, i| v.* = if (i % 3 == 0) 1.0 else -1.0;

    var dot: f64 = 0;
    var norm_a: f64 = 0;
    var norm_b: f64 = 0;
    for (&a, 0..) |_, i| {
        dot += a[i] * b[i];
        norm_a += a[i] * a[i];
        norm_b += b[i] * b[i];
    }
    const cos_sim = dot / (@sqrt(norm_a) * @sqrt(norm_b));
    _ = cos_sim;
    _ = allocator;
}

fn benchGf16Encode(allocator: std.mem.Allocator) void {
    const n = 1024;
    var values: [n]f64 = undefined;
    var encoded: [n]u16 = undefined;

    for (&values, 0..) |*v, i| v.* = @as(f64, @floatFromInt(i)) * 0.1;

    for (&encoded, 0..) |*v, i| {
        const fval = values[i];
        const sign: u16 = if (fval < 0) 1 << 15 else 0;
        const abs_val = @abs(fval);
        const exp_val: u16 = if (abs_val > 0) @intFromFloat(@log2(abs_val)) + 31 else 0;
        const mantissa: u16 = @intFromFloat(@rem(abs_val, 1.0) * 512.0);
        v.* = sign | (exp_val << 9) | (mantissa & 0x1FF);
    }
    _ = allocator;
}

fn benchGf16Decode(allocator: std.mem.Allocator) void {
    const n = 1024;
    var encoded: [n]u16 = undefined;
    var decoded: [n]f64 = undefined;

    for (&encoded, 0..) |*v, i| v.* = @intCast(i % 65536);

    for (&decoded, 0..) |*v, i| {
        const raw = encoded[i];
        const sign: f64 = if ((raw >> 15) & 1 == 1) -1.0 else 1.0;
        const exp: u16 = (raw >> 9) & 0x3F;
        const mant: u16 = raw & 0x1FF;
        v.* = sign * @as(f64, @floatFromInt(@as(u32, 1) << @intCast(exp))) * (1.0 + @as(f64, @floatFromInt(mant)) / 512.0);
    }
    _ = allocator;
}

fn benchPhiComputation(allocator: std.mem.Allocator) void {
    const phi = (1.0 + @sqrt(5.0)) / 2.0;
    var result: f64 = 0;
    var i: u64 = 0;
    while (i < 1000) : (i += 1) {
        result += phi * phi + 1.0 / (phi * phi);
    }
    result /= 1000.0;
    _ = result;
    _ = allocator;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var suite = BenchmarkSuite.init(allocator);
    defer suite.deinit();

    const stdout = std.io.getStdOut().writer();
    stdout.print("\n{s}\n", .{"=" * 72}) catch {};
    stdout.print("  TRINITY S3AI — Reproducible Benchmark Suite\n", .{});
    stdout.print("  phi^2 + 1/phi^2 = 3 | TRINITY\n", .{});
    stdout.print("{s}\n\n", .{"=" * 72}) catch {};

    stdout.print("  Running benchmarks...\n\n", .{});

    try suite.run("ternary_encode", benchTernaryEncode, 10000);
    try suite.run("ternary_matmul_64", benchTernaryMatmul, 10000);
    try suite.run("vsa_bind_1024", benchVsaBind, 10000);
    try suite.run("vsa_bundle_10x1024", benchVsaBundle, 10000);
    try suite.run("vsa_cosine_1024", benchVsaCosine, 10000);
    try suite.run("gf16_encode", benchGf16Encode, 10000);
    try suite.run("gf16_decode", benchGf16Decode, 10000);
    try suite.run("phi_computation", benchPhiComputation, 10000);

    suite.printReport();

    const json = try suite.exportJson();
    defer allocator.free(json);

    const json_file = try std.fs.cwd().createFile("benchmarks/results.json", .{});
    defer json_file.close();
    try json_file.writeAll(json);

    stdout.print("  Results exported to benchmarks/results.json\n", .{});
}

test "benchmark suite runs" {
    var suite = BenchmarkSuite.init(std.testing.allocator);
    defer suite.deinit();

    try suite.run("test_bench", benchPhiComputation, 100);
    try std.testing.expect(suite.results.items.len == 1);
    try std.testing.expect(suite.results.items[0].iterations == 100);
    try std.testing.expect(suite.results.items[0].avg_ns > 0);
}
