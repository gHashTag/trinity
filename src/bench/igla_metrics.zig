// IGLA METRICS v1.0 — CSV Export and Heatmap Generation
//
// Purpose: Export benchmark results to CSV format and generate heatmap visualizations
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL

const std = @import("std");
const igla_bench = @import("igla_bench.zig");
const Allocator = std.mem.Allocator;

/// Export results to CSV format
/// CSV format: format,ctx,needles,depth,accuracy,latency_ms,tok_per_sec
pub fn exportCSV(results: []const igla_bench.ConfigResult, path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    // Write header
    try file.writeAll("format,ctx,needles,depth,accuracy,latency_ms,tok_per_sec\n");

    // Write each result
    var buffer: [256]u8 = undefined;
    for (results) |result| {
        const line = try std.fmt.bufPrint(&buffer, "{s},{d},{d},{d:.2},{d:.3},{d:.1},{d:.1}\n", .{
            result.format.displayName(),
            result.context_length,
            result.num_needles,
            result.depth_percent,
            result.accuracy,
            result.latency_ms,
            result.tok_per_sec,
        });
        try file.writeAll(line);
    }

    std.debug.print("Exported {d} results to {s}\n", .{ results.len, path });
}

/// Generate ASCII heatmap for accuracy across depths
pub fn generateHeatmap(allocator: Allocator, results: []const igla_bench.ConfigResult) !void {
    std.debug.print("\n{s}IGLA ACCURACY HEATMAP{s}\n", .{ "\x1b[33m", "\x1b[0m" });
    std.debug.print("{s}═════════════════════════════════════════{s}\n\n", .{ "\x1b[33m", "\x1b[0m" });

    // Group results by format
    var format_groups = std.AutoHashMap(igla_bench.WeightFormat, std.ArrayList(igla_bench.ConfigResult)).init(allocator);
    for (results) |result| {
        const entry = try format_groups.getOrPut(result.format, try std.ArrayList(igla_bench.ConfigResult).initCapacity(allocator, 10));
        try entry.value_ptr.append(allocator, result);
    }

    var iter = format_groups.iterator();
    while (iter.next()) |entry| {
        std.debug.print("{s}Format: {s}{s}\n", .{ "\x1b[36m", entry.key_ptr.*.displayName(), "\x1b[0m" });

        // Group by context length for heatmap
        var ctx_map = std.AutoHashMap(usize, []f32).init(allocator);
        for (entry.value_ptr.items) |result| {
            const depths = try ctx_map.getOrPut(result.context_length, try allocator.alloc(f32, 7));
            const depth_idx = @min(6, @as(usize, @intFromFloat(result.depth_percent * 6)));
            depths[depth_idx] = result.accuracy;
        }

        // Print heatmap row
        const ctx_keys = &[_]usize{ 27, 81, 243, 729, 2187 };
        for (ctx_keys) |ctx| {
            const depths = ctx_map.get(ctx) orelse &[7]f32{0} ** 7;

            const ctx_str = if (ctx >= 1000) try std.fmt.allocPrint(allocator, "{d}", .{ctx}) else try std.fmt.allocPrint(allocator, " {d}", .{ctx});

            std.debug.print("{s}{s}", .{ ctx_str, "\x1b[0m" });

            // Heatmap cells with color coding
            for (depths) |acc| {
                const marker = switch (@as(u32, @intFromFloat(acc * 100))) {
                    0...50 => "  ", // >90%
                    51...75 => "\x1b[42m▓\x1b[0m", // 75-90%
                    76...85 => "\x1b[43m▓\x1b[0m", // 60-75%
                    86...90 => "\x1b[44m▓\x1b[0m", // 50-60%
                    91...100 => "\x1b[41m▓\x1b[0m", // <50%
                    else => "  ",
                };
                std.debug.print("{s}", .{marker});
            }
            std.debug.print("\n", .{});
        }
        std.debug.print("\n", .{});
    }

    std.debug.print("{s}Legend{s}\n", .{ "\x1b[33m", "\x1b[0m" });
    std.debug.print("  \x1b[42m▓\x1b[0m >90%\n", .{});
    std.debug.print("  \x1b[43m▓\x1b[0m 75-90%\n", .{});
    std.debug.print("  \x1b[44m▓\x1b[0m 60-75%\n", .{});
    std.debug.print("  \x1b[41m▓\x1b[0m <50%\n", .{});
    std.debug.print("    >90%  = Excellent retrieval\n", .{});
    std.debug.print("    75-90% = Good retrieval\n", .{});
    std.debug.print("    60-75% = Fair retrieval\n", .{});
    std.debug.print("    <50%   = Poor retrieval\n", .{});
    std.debug.print("\n", .{});
}

/// Calculate aggregate statistics
pub fn calculateStats(allocator: Allocator, results: []const igla_bench.ConfigResult) !struct {
    total_tests: usize,
    avg_accuracy: f32,
    best_accuracy: f32,
    best_config: igla_bench.ConfigResult,
    worst_accuracy: f32,
    by_format: [4]f32, // STD, BF16, GF16, TF3
} {
    _ = allocator;
    if (results.len == 0) {
        return .{
            .total_tests = 0,
            .avg_accuracy = 0,
            .best_accuracy = 0,
            .best_config = undefined,
            .worst_accuracy = 0,
            .by_format = [_]f32{0} ** 4,
        };
    }

    var total_acc: f32 = 0;
    var best_acc: f32 = 0;
    var worst_acc: f32 = 1.0;
    var best_result: igla_bench.ConfigResult = undefined;

    var format_counts = [_]usize{ 0, 0, 0, 0 };
    var format_sums = [_]f32{ 0, 0, 0, 0 };

    for (results) |result| {
        total_acc += result.accuracy;
        if (result.accuracy > best_acc) {
            best_acc = result.accuracy;
            best_result = result;
        }
        if (result.accuracy < worst_acc) {
            worst_acc = result.accuracy;
        }

        const fmt_idx = @intFromEnum(result.format);
        if (fmt_idx >= 0 and fmt_idx < 4) {
            format_counts[fmt_idx] += 1;
            format_sums[fmt_idx] += result.accuracy;
        }
    }

    var format_avgs: [4]f32 = undefined;
    for (0..4) |i| {
        format_avgs[i] = if (format_counts[i] > 0)
            format_sums[i] / @as(f32, @floatFromInt(format_counts[i]))
        else
            0;
    }

    return .{
        .total_tests = results.len,
        .avg_accuracy = total_acc / @as(f32, @floatFromInt(results.len)),
        .best_accuracy = best_acc,
        .best_config = best_result,
        .worst_accuracy = worst_acc,
        .by_format = format_avgs,
    };
}

/// Print statistics summary
pub fn printStats(stats: anytype) void {
    std.debug.print("\n{s}═══════════════════════════════════════════════════{s}\n", .{ "\x1b[33m", "\x1b[0m" });
    std.debug.print("{s}IGLA BENCHMARK STATISTICS{s}\n", .{ "\x1b[36m", "\x1b[0m" });
    std.debug.print("{s}═══════════════════════════════════════════════════{s}\n\n", .{ "\x1b[33m", "\x1b[0m" });

    std.debug.print("Total tests: {d}\n", .{stats.total_tests});
    std.debug.print("Average accuracy: {d:.2}%\n", .{stats.avg_accuracy * 100});
    std.debug.print("Best accuracy: {d:.2}%\n", .{stats.best_accuracy * 100});
    std.debug.print("Worst accuracy: {d:.2}%\n\n", .{stats.worst_accuracy * 100});

    std.debug.print("Accuracy by format:\n", .{});
    inline for (.{ .STD, .BF16, .GF16, .TF3 }, 0..) |fmt, i| {
        std.debug.print("  {s}: {d:.2}%\n", .{ fmt.displayName(), stats.by_format[i] * 100 });
    }

    std.debug.print("\nBest configuration:\n", .{});
    std.debug.print("  Format: {s}\n", .{stats.best_config.format.displayName()});
    std.debug.print("  Context: {d}\n", .{stats.best_config.context_length});
    std.debug.print("  Needles: {d}\n", .{stats.best_config.num_needles});
    std.debug.print("  Depth: {d:.0}%\n", .{stats.best_config.depth_percent * 100});
    std.debug.print("  Accuracy: {d:.2}%\n", .{stats.best_config.accuracy * 100});
    std.debug.print("  Latency: {d:.1}ms\n", .{stats.best_config.latency_ms});
    std.debug.print("  Throughput: {d:.0} tok/s\n\n", .{stats.best_config.tok_per_sec});

    std.debug.print("{s}═══════════════════════════════════════════════════{s}\n\n", .{ "\x1b[33m", "\x1b[0m" });
}

test "igla_metrics_exportCSV" {
    const allocator = std.testing.allocator;

    const results = [_]igla_bench.ConfigResult{
        .{ .format = .STD, .context_length = 243, .num_needles = 1, .depth_percent = 0.5, .accuracy = 0.95, .latency_ms = 100, .tok_per_sec = 2.43 },
        .{ .format = .GF16, .context_length = 729, .num_needles = 3, .depth_percent = 0.25, .accuracy = 0.82, .latency_ms = 350, .tok_per_sec = 2.08 },
    };

    _ = try std.fs.cwd().makeOpenPath("tmp_test", .{});
    defer std.fs.cwd().deleteTree("tmp_test") catch {};

    const csv_path = try std.fmt.allocPrint(allocator, "tmp_test/test.csv", .{});
    try exportCSV(&results, csv_path);

    // Verify file was created
    const file = std.fs.cwd().openFile(csv_path, .{}) catch return error.FileNotFound;
    file.close();
}

test "igla_metrics_calculateStats" {
    const allocator = std.testing.allocator;

    const results = [_]igla_bench.ConfigResult{
        .{ .format = .STD, .context_length = 243, .num_needles = 1, .depth_percent = 0.5, .accuracy = 0.95, .latency_ms = 100, .tok_per_sec = 2.43 },
        .{ .format = .GF16, .context_length = 729, .num_needles = 3, .depth_percent = 0.25, .accuracy = 0.82, .latency_ms = 350, .tok_per_sec = 2.08 },
        .{ .format = .TF3, .context_length = 81, .num_needles = 1, .depth_percent = 0.75, .accuracy = 0.88, .latency_ms = 80, .tok_per_sec = 1.01 },
    };

    const stats = try calculateStats(allocator, &results);
    try std.testing.expectEqual(stats.total_tests, 3);
    try std.testing.expect(stats.avg_accuracy > 0.88 and stats.avg_accuracy < 0.89); // (0.95 + 0.82 + 0.88) / 3
    try std.testing.expectEqual(stats.best_accuracy, 0.95);
    try std.testing.expectEqual(stats.worst_accuracy, 0.82);
}
