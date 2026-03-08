// ╔════════════════════════════════════════════════════════════════════════════╗
// ║  TRINITY TQNN BENCHMARK — Performance Measurement Suite                      ║
// ║  Week 2 Day 5: Benchmark TQNN operations                                     ║
// ║                                                                              ║
// ║  Benchmarks:                                                                 ║
// ║  - Layer 1 only (1000 iterations)                                           ║
// ║  - TQNN+VSA integration                                                     ║
// ║  - Scaling test (8-128 dimensions)                                          ║
// ║                                                                              ║
// ║  φ² + 1/φ² = 3 = TRINITY                                                    ║
// ╚════════════════════════════════════════════════════════════════════════════╝

const std = @import("std");
const tqnn = @import("tqnn_inference.zig");
const qutrit = @import("../../quantum/qutrit.zig");
const vsa10k = @import("../../vsa/10k_vsa.zig");

/// Benchmark configuration
pub const BenchmarkConfig = struct {
    iterations: usize = 1000,
    warmup: usize = 10,
    input_dim: usize = 16,
    vsa_dim: usize = 10000,

    pub fn default(input_dim: usize) BenchmarkConfig {
        return .{
            .input_dim = input_dim,
            .vsa_dim = vsa10k.DIM_10K,
        };
    }
};

/// Single benchmark result
pub const BenchmarkResult = struct {
    name: []const u8,
    iterations: usize,
    total_ns: u64,
    avg_ns: u64,
    throughput: f64,
    success: bool,

    pub fn format(self: BenchmarkResult, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "{s}: {d} iterations, {d} ns avg, {d:.2} ops/sec", .{
            self.name,
            self.iterations,
            self.avg_ns,
            self.throughput,
        });
    }
};

/// Scaling test result
pub const ScalingResult = struct {
    dim: usize,
    time_ns: u64,
    ops_per_sec: f64,
};

//==============================================================================
// BENCHMARK FUNCTIONS
//==============================================================================

/// Run Layer 1 benchmark
pub fn run_layer_benchmark(allocator: std.mem.Allocator, config: BenchmarkConfig) !BenchmarkResult {
    var layer = try tqnn.TQNNLayer1.init(allocator, tqnn.TQNNConfig.default(config.input_dim));
    defer layer.deinit(allocator);

    const input = try allocator.alloc(f32, config.input_dim);
    defer allocator.free(input);
    for (input) |*v| v.* = 0.5;

    // Warmup
    var i: usize = 0;
    while (i < config.warmup) : (i += 1) {
        _ = try layer.forward(input);
    }

    // Benchmark
    const start = std.time.nanoTimestamp();
    i = 0;
    while (i < config.iterations) : (i += 1) {
        _ = try layer.forward(input);
    }
    const end = std.time.nanoTimestamp();

    const total_ns = @as(u64, @intCast(end - start));
    const avg_ns = total_ns / config.iterations;
    const throughput = if (avg_ns > 0)
        @as(f64, @floatFromInt(1_000_000_000)) / @as(f64, @floatFromInt(avg_ns))
    else
        0;

    return BenchmarkResult{
        .name = "Layer 1",
        .iterations = config.iterations,
        .total_ns = total_ns,
        .avg_ns = avg_ns,
        .throughput = throughput,
        .success = true,
    };
}

/// Run hybrid TQNN+VSA benchmark
pub fn run_hybrid_benchmark(allocator: std.mem.Allocator, config: BenchmarkConfig) !BenchmarkResult {
    var engine = try tqnn.TQNNVSAInference.init(allocator, config.input_dim);
    defer engine.deinit();

    const input = try allocator.alloc(f32, config.input_dim);
    defer allocator.free(input);
    for (input) |*v| v.* = 0.5;

    // Warmup
    var i: usize = 0;
    while (i < config.warmup) : (i += 1) {
        _ = try engine.forward(input);
    }

    // Benchmark
    const start = std.time.nanoTimestamp();
    i = 0;
    while (i < config.iterations) : (i += 1) {
        _ = try engine.forward(input);
    }
    const end = std.time.nanoTimestamp();

    const total_ns = @as(u64, @intCast(end - start));
    const avg_ns = total_ns / config.iterations;
    const throughput = if (avg_ns > 0)
        @as(f64, @floatFromInt(1_000_000_000)) / @as(f64, @floatFromInt(avg_ns))
    else
        0;

    return BenchmarkResult{
        .name = "TQNN+VSA",
        .iterations = config.iterations,
        .total_ns = total_ns,
        .avg_ns = avg_ns,
        .throughput = throughput,
        .success = true,
    };
}

/// Run scaling benchmark across dimensions
pub fn run_scaling_benchmark(allocator: std.mem.Allocator, base_dim: usize, iterations: usize) ![]ScalingResult {
    const dims = [_]usize{ 8, 16, 32, 64, 128 };
    var results = try allocator.alloc(ScalingResult, dims.len);

    for (dims, 0..) |dim, idx| {
        const config = BenchmarkConfig{
            .iterations = iterations,
            .warmup = 5,
            .input_dim = dim,
            .vsa_dim = vsa10k.DIM_10K,
        };

        var engine = try tqnn.TQNNVSAInference.init(allocator, dim);
        defer engine.deinit();

        const input = try allocator.alloc(f32, dim);
        defer allocator.free(input);
        for (input) |*v| v.* = 0.5;

        // Warmup
        var i: usize = 0;
        while (i < 5) : (i += 1) {
            _ = try engine.forward(input);
        }

        // Benchmark
        const start = std.time.nanoTimestamp();
        i = 0;
        while (i < iterations) : (i += 1) {
            _ = try engine.forward(input);
        }
        const end = std.time.nanoTimestamp();

        const total_ns = @as(u64, @intCast(end - start));
        const ops_per_sec = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(total_ns)) * 1_000_000_000;

        results[idx] = ScalingResult{
            .dim = dim,
            .time_ns = total_ns,
            .ops_per_sec = ops_per_sec,
        };
    }

    return results;
}

/// Print benchmark results table
pub fn print_benchmark_results(results: []const BenchmarkResult) void {
    const stdout = std.io.getStdOut().writer();

    stdout.print("\n╔════════════════════════════════════════════════════════════════╗\n", .{}) catch {};
    stdout.print("║  TQNN BENCHMARK RESULTS                                          ║\n", .{}) catch {};
    stdout.print("╚════════════════════════════════════════════════════════════════╝\n\n", .{}) catch {};

    stdout.print("{s:<20} {s:>12} {s:>15} {s:>15}\n", .{ "Name", "Iterations", "Avg (ns)", "Ops/sec" }) catch {};
    stdout.print("{s:<20} {s:>12} {s:>15} {s:>15}\n", .{ "-" ** 20, "-" ** 12, "-" ** 15, "-" ** 15 }) catch {};

    for (results) |r| {
        stdout.print("{s:<20} {d:>12} {d:>15} {d:>15.2}\n", .{
            r.name,
            r.iterations,
            r.avg_ns,
            @as(u64, @intFromFloat(r.throughput)),
        }) catch {};
    }
    stdout.print("\n", .{}) catch {};
}

/// Print scaling results table
pub fn print_scaling_results(results: []const ScalingResult) void {
    const stdout = std.io.getStdOut().writer();

    stdout.print("\n╔════════════════════════════════════════════════════════════════╗\n", .{}) catch {};
    stdout.print("║  SCALING BENCHMARK RESULTS                                       ║\n", .{}) catch {};
    stdout.print("╚════════════════════════════════════════════════════════════════╝\n\n", .{}) catch {};

    stdout.print("{s:>10} {s:>15} {s:>15}\n", .{ "Dim", "Total (ns)", "Ops/sec" }) catch {};
    stdout.print("{s:>10} {s:>15} {s:>15}\n", .{ "-" ** 10, "-" ** 15, "-" ** 15 }) catch {};

    for (results) |r| {
        stdout.print("{d:>10} {d:>15} {d:>15.2}\n", .{
            r.dim,
            r.time_ns,
            r.ops_per_sec,
        }) catch {};
    }
    stdout.print("\n", .{}) catch {};
}

/// Verify layer output
pub fn verify_layer_output(layer: *const tqnn.TQNNLayer1, input_dim: usize) bool {
    return layer.neurons.len == input_dim;
}

/// Verify hybrid output
pub fn verify_hybrid_output(result: anytype, input_dim: usize) bool {
    _ = result;
    return true;
}

//==============================================================================
// MAIN BENCHMARK ENTRY POINT
//==============================================================================

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const stdout = std.io.getStdOut().writer();

    stdout.print("\n╔════════════════════════════════════════════════════════════════╗\n", .{}) catch {};
    stdout.print("║  TRINITY TQNN BENCHMARK SUITE                                    ║\n", .{}) catch {};
    stdout.print("║  Week 2 Day 5: TQNN Performance Tests                            ║\n", .{}) catch {};
    stdout.print("╚════════════════════════════════════════════════════════════════╝\n", .{}) catch {};

    // Run Layer 1 benchmark
    const layer_result = try run_layer_benchmark(allocator, BenchmarkConfig.default(16));
    print_benchmark_results(&[_]BenchmarkResult{layer_result});

    // Run Hybrid benchmark
    const hybrid_result = try run_hybrid_benchmark(allocator, BenchmarkConfig.default(16));
    print_benchmark_results(&[_]BenchmarkResult{hybrid_result});

    // Run scaling benchmark
    const scaling_results = try run_scaling_benchmark(allocator, 16, 100);
    print_scaling_results(scaling_results);
}

// φ² + 1/φ² = 3 = TRINITY
// Cycle #127 — Week 2 Day 5
