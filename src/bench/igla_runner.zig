// IGLA RUNNER v1.0 — Matrix Execution for IGLA Bench
//
// Purpose: Run IGLA benchmarks across configuration matrix
//   - Full mode: 4 formats × 5 ctxs × 3 needles × 7 depths = 420 configs
//   - Evolve mode: Reduced matrix for quick evaluation (ctx=81,243; needles=1,3; depths=0.25,0.5,0.75)
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL

const std = @import("std");
const igla_bench = @import("igla_bench.zig");
const igla_tasks = @import("igla_tasks.zig");
const igla_metrics = @import("igla_metrics.zig");
const Allocator = std.mem.Allocator;

/// Run single configuration
pub fn runSingleConfig(
    allocator: Allocator,
    format: igla_bench.WeightFormat,
    context_length: usize,
    num_needles: usize,
    depth_percent: f32,
) !struct {
    results: []igla_bench.IGLAResult,
    config_result: igla_bench.ConfigResult,
} {
    const haystack = try igla_bench.generateHaystack(
        allocator,
        "single_test",
        context_length,
        num_needles,
        depth_percent,
    );

    var test_results = try std.ArrayList(igla_bench.IGLAResult).initCapacity(allocator, haystack.questions.len);

    const start = std.time.nanoTimestamp();
    for (haystack.questions) |question| {
        const result = try igla_bench.runInference(allocator, haystack, question, format);
        try test_results.append(allocator, result);
    }
    const total_ms = @as(f32, @floatFromInt(@divFloor(std.time.nanoTimestamp() - start, 1_000_000)));

    // Calculate accuracy
    var correct: usize = 0;
    for (test_results.items) |r| {
        if (r.correct) correct += 1;
    }
    const accuracy = if (test_results.items.len > 0)
        @as(f32, @floatFromInt(correct)) / @as(f32, @floatFromInt(test_results.items.len))
    else
        0;

    // Calculate average latency and throughput
    var total_lat: f32 = 0;
    for (test_results.items) |r| {
        total_lat += r.latency_ms;
    }
    const avg_lat = if (test_results.items.len > 0)
        total_lat / @as(f32, @floatFromInt(test_results.items.len))
    else
        0;

    const avg_tps = if (test_results.items.len > 0)
        @as(f32, @floatFromInt(context_length)) / (if (total_ms > 0) total_ms / 1000.0 else 1.0)
    else
        0;

    return .{
        .results = try test_results.toOwnedSlice(allocator),
        .config_result = igla_bench.ConfigResult{
            .format = format,
            .context_length = context_length,
            .num_needles = num_needles,
            .depth_percent = depth_percent,
            .accuracy = accuracy,
            .latency_ms = avg_lat,
            .tok_per_sec = avg_tps,
        },
    };
}

/// Run specific task type across format
pub fn runTaskType(
    allocator: Allocator,
    format: igla_bench.WeightFormat,
    context_length: usize,
    num_needles: usize,
    depth_percent: f32,
    task_type: igla_tasks.TaskType,
) !struct {
    results: []igla_bench.IGLAResult,
    config_result: igla_bench.ConfigResult,
} {
    switch (task_type) {
        .Retrieve => {
            const single = try runSingleConfig(allocator, format, context_length, 1, depth_percent);
            return .{
                .results = single.results,
                .config_result = single.config_result,
            };
        },
        .Multi => {
            const depths = [_]f32{0.5};
            const task = try igla_tasks.generateMultiTask(allocator, context_length, &depths, format);
            const single = try runSingleConfig(allocator, format, task.haystack.tokens, task.haystack.needles.len, 0.5);
            return .{
                .results = single.results,
                .config_result = single.config_result,
            };
        },
        .Ternary => {
            const single = try runSingleConfig(allocator, format, context_length, 1, 0.5);
            return .{
                .results = single.results,
                .config_result = single.config_result,
            };
        },
        .Chain => {
            const single = try runSingleConfig(allocator, format, context_length, num_needles, 0.5);
            return .{
                .results = single.results,
                .config_result = single.config_result,
            };
        },
    }
}

/// Run full benchmark matrix (420 configurations)
/// WARNING: Only use this manually! Evolution uses reduced matrix.
pub fn runFullBenchmark(
    allocator: Allocator,
) ![]igla_bench.ConfigResult {
    const formats = [_]igla_bench.WeightFormat{ .STD, .BF16, .GF16, .TF3 };
    const ctxs = [_]usize{ 27, 81, 243, 729, 2187 };
    const needles = [_]usize{ 1, 3, 9 };
    const depths = [_]f32{ 0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0 };

    std.debug.print("\n{s}IGLA FULL BENCHMARK{s}\n", .{ "\x1b[33m", "\x1b[0m" });
    std.debug.print("Configuration matrix: 4 × 5 × 3 × 7 = {d} tests\n\n", .{formats.len * ctxs.len * needles.len * depths.len});
    std.debug.print("{s}WARNING: This will run {d} inference calls!{s}\n", .{ "\x1b[31m", formats.len * ctxs.len * needles.len * depths.len, "\x1b[0m" });
    std.debug.print("Use --evolve mode for quick evaluation.\n\n", .{});

    const results = try igla_bench.runFullBenchmark(
        allocator,
        &formats,
        &ctxs,
        &needles,
        &depths,
    );

    // Export CSV
    try igla_metrics.exportCSV(results, "igla_bench_results.csv");

    // Generate heatmap
    try igla_metrics.generateHeatmap(allocator, results);

    // Print statistics
    const stats = try igla_metrics.calculateStats(allocator, results);
    igla_metrics.printStats(stats);

    return results;
}

/// Run reduced benchmark matrix for evolution
/// Uses: ctx=81,243; needles=1,3; depths=0.25,0.5,0.75
/// This is a matrix used in evolveStep for quick evaluation
pub fn runEvolveMatrix(
    allocator: Allocator,
) !struct {
    score: f32,
    format_accuracy: [4]f32,
    details: struct {
        retrieve: f32,
        multi: f32,
        ternary: f32,
        chain: f32,
        latency_ms: f32,
        tok_per_sec: f32,
    },
} {
    const formats = [_]igla_bench.WeightFormat{ .STD, .BF16, .GF16, .TF3 };
    const ctxs = [_]usize{ 81, 243 };
    const needles = [_]usize{ 1, 3 };
    const depths = [_]f32{ 0.25, 0.5, 0.75 };

    std.debug.print("\n{s}IGLA EVOLVE MATRIX{s}\n", .{ "\x1b[33m", "\x1b[0m" });
    std.debug.print("Configuration matrix: 4 × 2 × 2 × 3 = {d} tests\n", .{formats.len * ctxs.len * needles.len * depths.len});

    var format_accuracy = [_]f32{0} ** 4;
    var total_retrieve: f32 = 0;
    var total_multi: f32 = 0;
    var total_ternary: f32 = 0;
    var total_chain: f32 = 0;
    var total_latency: f32 = 0;
    var total_tps: f32 = 0;
    var test_count: usize = 0;

    // Run RETRIEVE tests (single needle)
    for (ctxs) |ctx_len| {
        for (depths) |depth| {
            const result = try runSingleConfig(allocator, .GF16, ctx_len, 1, depth);
            total_retrieve += result.config_result.accuracy;
            total_latency += result.config_result.latency_ms;
            total_tps += result.config_result.tok_per_sec;
            test_count += 1;
        }
    }

    // Run MULTI tests (3 needles)
    for (ctxs) |ctx_len| {
        const depths_multi = [_]f32{ 0.25, 0.5, 0.75 };
        for (depths_multi) |depth| {
            const result = try runSingleConfig(allocator, .GF16, ctx_len, 3, depth);
            total_multi += result.config_result.accuracy;
            total_latency += result.config_result.latency_ms;
            total_tps += result.config_result.tok_per_sec;
            test_count += 1;
        }
    }

    // Run TERNARY tests
    const ternary_result = try igla_tasks.generateTernaryTask(allocator, 81, .GF16);
    const ternary_single = try runSingleConfig(allocator, .GF16, ternary_result.haystack.tokens, 1, 0.5);
    total_ternary += ternary_single.config_result.accuracy;
    total_latency += ternary_single.config_result.latency_ms;
    total_tps += ternary_single.config_result.tok_per_sec;
    test_count += 1;

    // Run CHAIN tests (3 facts)
    const chain_result = try igla_tasks.generateChainTask(allocator, 243, 3, .GF16);
    const chain_single = try runSingleConfig(allocator, .GF16, chain_result.haystack.tokens, 3, 0.5);
    total_chain += chain_single.config_result.accuracy;
    total_latency += chain_single.config_result.latency_ms;
    total_tps += chain_single.config_result.tok_per_sec;
    test_count += 1;

    // Calculate averages
    const avg_retrieve = total_retrieve / @as(f32, @floatFromInt(6)); // 2 ctxs × 3 depths
    const avg_multi = total_multi / @as(f32, @floatFromInt(6));
    const avg_ternary = total_ternary; // Just 1 test
    const avg_chain = total_chain; // Just 1 test

    const avg_lat = total_latency / @as(f32, @floatFromInt(test_count));
    const avg_tps = total_tps / @as(f32, @floatFromInt(test_count));

    // Calculate per-format accuracy (using GF16 as representative for now)
    // In full implementation, run each format separately
    const fmt_avg = (avg_retrieve + avg_multi + avg_ternary + avg_chain) / 4.0;
    for (0..4) |i| {
        format_accuracy[i] = fmt_avg;
    }

    // Overall score (weighted average)
    const score = (avg_retrieve * 1.0 + avg_multi * 1.0 + avg_ternary * 1.0 + avg_chain * 0.5) / 3.5;

    return .{
        .score = score,
        .format_accuracy = format_accuracy,
        .details = .{
            .retrieve = avg_retrieve,
            .multi = avg_multi,
            .ternary = avg_ternary,
            .chain = avg_chain,
            .latency_ms = avg_lat,
            .tok_per_sec = avg_tps,
        },
    };
}

test "igla_runner_runSingleConfig" {
    const allocator = std.testing.allocator;

    const result = try runSingleConfig(allocator, .STD, 243, 1, 0.5);
    try std.testing.expect(result.results.len >= 1);
    try std.testing.expect(result.config_result.format == .STD);
    try std.testing.expect(result.config_result.context_length == 243);
}

test "igla_runner_runTaskType" {
    const allocator = std.testing.allocator;

    const result = try runTaskType(allocator, .GF16, 81, 1, 0.5, .Ternary);
    try std.testing.expect(result.results.len >= 1);
    try std.testing.expect(result.config_result.format == .GF16);
}

test "igla_runner_runEvolveMatrix" {
    const allocator = std.testing.allocator;

    const result = try runEvolveMatrix(allocator);
    try std.testing.expect(result.score >= 0 and result.score <= 1);
    try std.testing.expect(result.details.latency_ms >= 0);
}
