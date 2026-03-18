// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE Tier 3 — Cached semanticFind Performance Benchmark
// ═══════════════════════════════════════════════════════════════════════════════
//
// Benchmark semanticFindCached with index caching
// Target: <100ms for 1000+ symbols (with cache)
// φ² + 1/φ² = 3 | TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

const needle = @import("mod.zig");
const zig_parser = needle.zig_parser;
const vsa = needle.vsa;

const stdout_file = std.fs.File.stderr();
var write_buf: [4096]u8 = undefined;
var writer = stdout_file.writer(&write_buf);
const stdout = &writer.interface;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    try std.Io.Writer.print(stdout, "╔════════════════════════════════════════════════════════════╗\n", .{});
    try std.Io.Writer.print(stdout, "║  NEEDLE Tier 3 — semanticFindCached Benchmarks (Cached)    ║\n", .{});
    try std.Io.Writer.print(stdout, "╚════════════════════════════════════════════════════════════╝\n\n", .{});

    // Benchmark 1: First call (builds cache)
    try benchmarkCachedSearch(allocator, 1000, true);
    try std.Io.Writer.flush(stdout);

    // Benchmark 2: Subsequent calls (uses cache)
    try benchmarkCachedSearch(allocator, 1000, false);
    try std.Io.Writer.flush(stdout);

    // Benchmark 3: Multiple cached calls
    try benchmarkMultipleCachedCalls(allocator, 1000, 100);
    try std.Io.Writer.flush(stdout);

    // Benchmark 4: Large dataset with cache
    try benchmarkCachedSearch(allocator, 10000, false);
    try std.Io.Writer.flush(stdout);

    try std.Io.Writer.print(stdout, "\n✅ All benchmarks complete!\n", .{});
}

fn benchmarkCachedSearch(allocator: std.mem.Allocator, n_symbols: usize, first_call: bool) !void {
    const call_type = if (first_call) "First call (builds cache)" else "Cached call";
    try std.Io.Writer.print(stdout, "\n🎯 semanticFindCached ({d} symbols, {s})\n", .{ n_symbols, call_type });

    var graph = zig_parser.ASTGraph.init(allocator);
    defer graph.deinit();

    // Create symbols
    for (0..n_symbols) |i| {
        const file_name = try std.fmt.allocPrint(allocator, "file_{d}.zig", .{i});
        var node = zig_parser.ZigNode.init(allocator, .fn_def, "test");
        const names = [_][]const u8{ "parse", "validate", "render", "compute" };
        const name = names[i % names.len];
        node.name = try std.fmt.allocPrint(allocator, "{s}_{d}", .{ name, i });
        node.start_line = @intCast(i % 1000 + 1);
        try graph.files.put(file_name, node);
    }

    // Clear cache before first call
    if (first_call) {
        vsa.clearSemanticCache();
    }

    const iterations: usize = if (first_call) 1 else 50;
    const start_time = std.time.nanoTimestamp();

    for (0..iterations) |_| {
        const matches = try vsa.semanticFindCached(&graph, "parse function", 10, allocator);
        defer allocator.free(matches);
    }

    const total_time = std.time.nanoTimestamp() - start_time;
    const avg_time = @divTrunc(total_time, iterations);

    const ms = @as(f64, @floatFromInt(avg_time)) / 1_000_000.0;
    const status = if (ms < 100.0) "✅" else "⚠️";
    try std.Io.Writer.print(stdout, "   Avg Time: {d:.2}ms {s}\n", .{ ms, status });
    try std.Io.Writer.print(stdout, "   Target: <100ms for 1000+ symbols\n", .{});
}

fn benchmarkMultipleCachedCalls(allocator: std.mem.Allocator, n_symbols: usize, n_calls: usize) !void {
    try std.Io.Writer.print(stdout, "\n🔄 Multiple Cached Calls ({d} symbols, {d} calls)\n", .{ n_symbols, n_calls });

    var graph = zig_parser.ASTGraph.init(allocator);
    defer graph.deinit();

    // Create symbols
    for (0..n_symbols) |i| {
        const file_name = try std.fmt.allocPrint(allocator, "file_{d}.zig", .{i});
        var node = zig_parser.ZigNode.init(allocator, .fn_def, "test");
        const names = [_][]const u8{ "parse", "validate", "render", "compute" };
        const name = names[i % names.len];
        node.name = try std.fmt.allocPrint(allocator, "{s}_{d}", .{ name, i });
        node.start_line = @intCast(i % 1000 + 1);
        try graph.files.put(file_name, node);
    }

    // Build cache
    vsa.clearSemanticCache();
    _ = try vsa.semanticFindCached(&graph, "parse", 5, allocator);

    // Benchmark cached calls
    const start_time = std.time.nanoTimestamp();
    for (0..n_calls) |_| {
        const matches = try vsa.semanticFindCached(&graph, "parse function", 10, allocator);
        defer allocator.free(matches);
    }
    const total_time = std.time.nanoTimestamp() - start_time;

    const avg_time = @divTrunc(total_time, n_calls);
    const ms = @as(f64, @floatFromInt(avg_time)) / 1_000_000.0;
    const status = if (ms < 100.0) "✅" else "⚠️";

    try std.Io.Writer.print(stdout, "   Avg Time: {d:.2}ms {s}\n", .{ ms, status });
    try std.Io.Writer.print(stdout, "   Total Time: {d:.2}ms for {d} calls\n", .{ @as(f64, @floatFromInt(total_time)) / 1_000_000.0, n_calls });

    // Clear cache
    vsa.clearSemanticCache();
}
