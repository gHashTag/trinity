// ═══════════════════════════════════════════════════════════════════════════════
// IVF Tier 4.1 Benchmark — 10000 Symbols
// ═══════════════════════════════════════════════════════════════════════════════
// Target: <50ms for cached search with 10000+ symbols
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const vsa = @import("src/needle/vsa.zig");

const stdout_file = std.fs.File.stderr();
var write_buf: [4096]u8 = undefined;
var writer = stdout_file.writer(&write_buf);
const stdout = &writer.interface;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const embedding_dim: usize = 128;
    const n_symbols: usize = 10000;

    try std.Io.Writer.print(stdout, "╔════════════════════════════════════════════════════════════╗\n", .{});
    try std.Io.Writer.print(stdout, "║  IVF Tier 4.1 Benchmark — {d} Symbols                ║\n", .{n_symbols});
    try std.Io.Writer.print(stdout, "╚════════════════════════════════════════════════════════════╝\n\n", .{});

    // Build SemanticIndex with IVF
    try std.Io.Writer.print(stdout, "📊 Building SemanticIndex with {d} symbols...\n", .{n_symbols});
    var timer = try std.time.Timer.start();

    var index = try vsa.SemanticIndex.init(allocator, embedding_dim);
    defer index.deinit();

    const build_start = timer.lap();

    // Add 10000 symbols
    var i: usize = 0;
    while (i < n_symbols) : (i += 1) {
        const name = try std.fmt.allocPrint(allocator, "symbol_{d}", .{i});
        defer allocator.free(name);

        var sem_vec = try vsa.SemanticVector.init(allocator, name, embedding_dim);
        defer sem_vec.deinit();

        // Pattern-based embedding (different for each symbol)
        for (0..embedding_dim) |j| {
            sem_vec.embedding[j] = @as(f32, @floatFromInt((i + j) % 3)) / 3.0;
        }

        try index.addVector(sem_vec);

        // Progress indicator
        if (i > 0 and (i % 1000) == 0) {
            try std.Io.Writer.print(stdout, "   Added {d} symbols...\n", .{i});
        }
    }

    const add_time_ns = timer.lap();
    const add_time_ms: f64 = @as(f64, @floatFromInt(add_time_ns - build_start)) / 1_000_000.0;
    try std.Io.Writer.print(stdout, "   Add time: {d:.2} ms\n\n", .{add_time_ms});

    // Build IVF index
    try std.Io.Writer.print(stdout, "🔨 Building IVF index...\n", .{});
    const ivf_build_start = timer.lap();
    try index.buildIVFFromVectors();
    const ivf_build_time_ns = timer.lap();
    const ivf_build_time_ms: f64 = @as(f64, @floatFromInt(ivf_build_time_ns - ivf_build_start)) / 1_000_000.0;
    try std.Io.Writer.print(stdout, "   IVF build time: {d:.2} ms\n", .{ivf_build_time_ms});

    if (index.ivf_index) |idx| {
        const stats = idx.getStats();
        try std.Io.Writer.print(stdout, "   IVF clusters: {d}\n", .{idx.config.n_clusters});
        try std.Io.Writer.print(stdout, "   Total entries: {d}\n", .{stats.total_entries});
        try std.Io.Writer.print(stdout, "   Max cluster size: {d}\n", .{stats.max_cluster_size});
        try std.Io.Writer.print(stdout, "   Min cluster size: {d}\n\n", .{stats.min_cluster_size});
    } else {
        try std.Io.Writer.print(stdout, "   ❌ IVF index not built!\n\n", .{});
    }

    // Benchmark search performance
    try std.Io.Writer.print(stdout, "🔍 IVF Search Performance (cached):\n", .{});
    const n_searches: usize = 100;
    var total_search_ns: u64 = 0;

    var search_idx: usize = 0;
    while (search_idx < n_searches) : (search_idx += 1) {
        // Generate random query
        var query_arr: [embedding_dim]f32 = undefined;
        for (0..embedding_dim) |j| {
            query_arr[j] = @as(f32, @floatFromInt(search_idx + j)) / 100.0;
        }

        const search_start = timer.read();
        var results = try index.search(&query_arr, 10, 0.0);
        const search_end = timer.read();
        total_search_ns += search_end - search_start;

        // Clean up results
        for (results.items) |*r| {
            r.deinit();
        }
        results.deinit(allocator);
    }

    const avg_search_ns = total_search_ns / n_searches;
    const avg_search_ms: f64 = @as(f32, @floatFromInt(avg_search_ns)) / 1_000_000.0;

    try std.Io.Writer.print(stdout, "   Searches: {d}\n", .{n_searches});
    try std.Io.Writer.print(stdout, "   Avg time: {d:.2} ms\n", .{avg_search_ms});
    try std.Io.Writer.print(stdout, "   Total time: {d:.2} ms\n\n", .{@as(f64, @floatFromInt(total_search_ns)) / 1_000_000.0});

    // Verdict
    try std.Io.Writer.print(stdout, "╔════════════════════════════════════════════════════════════╗\n", .{});
    if (avg_search_ms < 50.0) {
        try std.Io.Writer.print(stdout, "║  ✅ TARGET MET: {d:.2} ms < 50 ms                      ║\n", .{avg_search_ms});
    } else {
        try std.Io.Writer.print(stdout, "║  ⚠️  TARGET MISSED: {d:.2} ms > 50 ms                    ║\n", .{avg_search_ms});
    }
    try std.Io.Writer.print(stdout, "╚════════════════════════════════════════════════════════════╝\n", .{});
    try std.Io.Writer.flush(stdout);
}
