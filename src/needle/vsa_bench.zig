// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE Tier 3 — VSA Semantic Search Benchmarks
// ═══════════════════════════════════════════════════════════════════════════════
//
// Benchmark semanticFind performance with HNSW-backed index
// Target: <100ms for 1000+ symbols
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
    try std.Io.Writer.print(stdout, "║  NEEDLE Tier 3 — semanticFind Performance Benchmarks        ║\n", .{});
    try std.Io.Writer.print(stdout, "╚════════════════════════════════════════════════════════════╝\n\n", .{});

    // Benchmark 1: Build semantic index (100 symbols)
    try benchmarkIndexBuild(allocator, 100);
    try std.Io.Writer.flush(stdout);

    // Benchmark 2: Build semantic index (1000 symbols)
    try benchmarkIndexBuild(allocator, 1000);
    try std.Io.Writer.flush(stdout);

    // Benchmark 3: Build semantic index (10000 symbols)
    try benchmarkIndexBuild(allocator, 10000);
    try std.Io.Writer.flush(stdout);

    // Benchmark 4: Semantic search (small index)
    try benchmarkSemanticSearch(allocator, 100);
    try std.Io.Writer.flush(stdout);

    // Benchmark 5: Semantic search (medium index)
    try benchmarkSemanticSearch(allocator, 1000);
    try std.Io.Writer.flush(stdout);

    // Benchmark 6: Semantic search (large index)
    try benchmarkSemanticSearch(allocator, 10000);
    try std.Io.Writer.flush(stdout);

    // Benchmark 7: Full semanticFind pipeline
    try benchmarkSemanticFind(allocator, 100);
    try std.Io.Writer.flush(stdout);

    try benchmarkSemanticFind(allocator, 1000);
    try std.Io.Writer.flush(stdout);

    try benchmarkSemanticFind(allocator, 10000);
    try std.Io.Writer.flush(stdout);

    try std.Io.Writer.print(stdout, "\n✅ All benchmarks complete!\n", .{});
}

fn benchmarkIndexBuild(allocator: std.mem.Allocator, n_symbols: usize) !void {
    try std.Io.Writer.print(stdout, "\n📊 Build Semantic Index ({d} symbols)\n", .{n_symbols});

    var graph = zig_parser.ASTGraph.init(allocator);
    defer graph.deinit();

    // Create synthetic symbols
    const start_time = std.time.nanoTimestamp();
    for (0..n_symbols) |i| {
        const file_name = try std.fmt.allocPrint(allocator, "file_{d}.zig", .{i});
        var node = zig_parser.ZigNode.init(allocator, .fn_def, "test");
        node.name = try std.fmt.allocPrint(allocator, "symbol_{d}", .{i});
        node.start_line = @intCast(i % 1000 + 1);
        try graph.files.put(file_name, node);
    }

    var index = try vsa.buildSemanticIndex(allocator, &graph, vsa.DEFAULT_EMBEDDING_DIM);
    const build_time = std.time.nanoTimestamp() - start_time;
    defer index.deinit();

    const ms = @as(f64, @floatFromInt(build_time)) / 1_000_000.0;
    const status = if (ms < 100.0) "✅" else "⚠️";
    try std.Io.Writer.print(stdout, "   Time: {d:.2}ms {s}\n", .{ ms, status });
    try std.Io.Writer.print(stdout, "   Vectors: {d}\n", .{index.vectors.count()});
}

fn benchmarkSemanticSearch(allocator: std.mem.Allocator, n_symbols: usize) !void {
    try std.Io.Writer.print(stdout, "\n🔍 Semantic Search ({d} symbols, top_k=10)\n", .{n_symbols});

    var graph = zig_parser.ASTGraph.init(allocator);
    defer graph.deinit();

    // Create indexed symbols
    for (0..n_symbols) |i| {
        const file_name = try std.fmt.allocPrint(allocator, "file_{d}.zig", .{i});
        var node = zig_parser.ZigNode.init(allocator, .fn_def, "test");
        node.name = try std.fmt.allocPrint(allocator, "symbol_{d}", .{i});
        node.start_line = @intCast(i % 1000 + 1);
        try graph.files.put(file_name, node);
    }

    var index = try vsa.buildSemanticIndex(allocator, &graph, vsa.DEFAULT_EMBEDDING_DIM);
    defer index.deinit();

    // Warmup
    _ = try index.search(&[_]f32{0.1} ** 384, 5, 0.5);

    // Benchmark search
    const iterations = 100;
    const start_time = std.time.nanoTimestamp();
    for (0..iterations) |_| {
        var results = try index.search(&[_]f32{0.1} ** 384, 10, 0.5);
        defer {
            for (results.items) |*r| {
                r.deinit();
            }
            results.deinit(allocator);
        }
    }
    const total_time = std.time.nanoTimestamp() - start_time;
    const avg_time = @divTrunc(total_time, iterations);

    const ms = @as(f64, @floatFromInt(avg_time)) / 1_000_000.0;
    const status = if (ms < 100.0) "✅" else "⚠️";
    try std.Io.Writer.print(stdout, "   Avg Time: {d:.2}ms {s}\n", .{ ms, status });
}

fn benchmarkSemanticFind(allocator: std.mem.Allocator, n_symbols: usize) !void {
    try std.Io.Writer.print(stdout, "\n🎯 Full semanticFind Pipeline ({d} symbols)\n", .{n_symbols});

    var graph = zig_parser.ASTGraph.init(allocator);
    defer graph.deinit();

    // Create symbols with meaningful names for semantic search
    for (0..n_symbols) |i| {
        const file_name = try std.fmt.allocPrint(allocator, "file_{d}.zig", .{i});
        var node = zig_parser.ZigNode.init(allocator, .fn_def, "test");
        
        // Mix of different symbol types
        const names = [_][]const u8{ "parse", "validate", "render", "compute", "fetch" };
        const name = names[i % names.len];
        node.name = try std.fmt.allocPrint(allocator, "{s}_{d}", .{ name, i });
        node.start_line = @intCast(i % 1000 + 1);
        try graph.files.put(file_name, node);
    }

    // Warmup
    _ = try vsa.semanticFind(&graph, "parse function", 5, allocator);

    // Benchmark semanticFind
    const iterations = 10;
    var total_time: i128 = 0;
    var found_total: usize = 0;

    for (0..iterations) |_| {
        const start = std.time.nanoTimestamp();
        const matches = try vsa.semanticFind(&graph, "parse function", 10, allocator);
        const elapsed = std.time.nanoTimestamp() - start;
        total_time += elapsed;
        found_total += matches.len;
        allocator.free(matches);
    }

    const avg_time = @divTrunc(total_time, iterations);
    const avg_found = found_total / iterations;

    const ms = @as(f64, @floatFromInt(avg_time)) / 1_000_000.0;
    const status = if (ms < 100.0) "✅" else "⚠️";
    try std.Io.Writer.print(stdout, "   Avg Time: {d:.2}ms {s}\n", .{ ms, status });
    try std.Io.Writer.print(stdout, "   Avg Found: {d} matches\n", .{avg_found });
    try std.Io.Writer.print(stdout, "   Target: <100ms for 1000+ symbols\n", .{});
}
