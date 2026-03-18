// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// CACHE — persistent cell discovery cache management
// ═══════════════════════════════════════════════════════════════════════════════

/// Cache command handler
fn runCacheCommand(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        // Show stats by default
        try runCacheStats(allocator);
        return;
    }

    const sub = args[0];

    if (std.mem.eql(u8, sub, "--stats")) {
        try runCacheStats(allocator);
    } else if (std.mem.eql(u8, sub, "--clear")) {
        try runCacheClear(allocator);
    } else if (std.mem.eql(u8, sub, "--refresh")) {
        try runCacheRefresh(allocator);
    } else {
        std.debug.print("{s}Usage:{s} tri cell cache [--stats] [--clear] [--refresh]\n", .{ YELLOW, RESET });
        std.debug.print("  {s}--stats{s}    Show cache statistics\n", .{ CYAN, RESET });
        std.debug.print("  {s}--clear{s}    Delete cache file\n", .{ CYAN, RESET });
        std.debug.print("  {s}--refresh{s}  Force refresh all cells\n", .{ CYAN, RESET });
    }
}

/// Show cache statistics
fn runCacheStats(allocator: Allocator) !void {
    std.debug.print("\n{s}═══ CELL CACHE STATUS ═══{s}\n\n", .{ GOLDEN, RESET });

    const stats = try cell_parser.getCacheStats(allocator);

    if (!stats.file_exists) {
        std.debug.print("  {s}Cache file:{s}    {s}Not found{s} (cold cache on next run)\n", .{ CYAN, RESET, YELLOW, RESET });
        std.debug.print("  {s}Location:{s}     {s}\n\n", .{ CYAN, RESET, ".trinity/cache/cells.json" });
        std.debug.print("  Run {s}tri cell status{s} to populate cache.\n\n", .{ CYAN, RESET });
        return;
    }

    std.debug.print("  {s}Cache file:{s}    {s}Exists{s}\n", .{ CYAN, RESET, GREEN, RESET });
    std.debug.print("  {s}File size:{s}     {s}{d} KB{s}\n", .{ CYAN, RESET, YELLOW, RESET, stats.file_size / 1024 });
    std.debug.print("  {s}Total entries:{s} {d}\n", .{ CYAN, RESET, stats.total_entries });
    std.debug.print("  {s}Valid entries:{s} {s}{d}{s}\n", .{ CYAN, RESET, GREEN, RESET, stats.valid_entries });
    std.debug.print("  {s}Stale entries:{s} {s}{d}{s}\n", .{ CYAN, RESET, YELLOW, RESET, stats.stale_entries });

    const hit_rate: f64 = if (stats.total_entries > 0)
        @as(f64, @floatFromInt(stats.valid_entries)) / @as(f64, @floatFromInt(stats.total_entries)) * 100.0
    else
        0.0;

    const rate_color = if (hit_rate >= 90) GREEN else if (hit_rate >= 70) YELLOW else RED;
    std.debug.print("  {s}Hit rate:{s}      {s}{d:.1}%{s}\n\n", .{ CYAN, RESET, rate_color, RESET, hit_rate });

    if (stats.stale_entries > 0) {
        std.debug.print("  {s}Tip:{s} Run {s}tri cell cache --refresh{s} to update stale entries.\n\n", .{ YELLOW, RESET, CYAN, RESET });
    } else if (hit_rate < 90) {
        std.debug.print("  {s}Tip:{s} Cache is warming up. Hit rate will improve on subsequent runs.\n\n", .{ YELLOW, RESET });
    }

    // Benchmark with warm cache
    std.debug.print("Benchmarking warm cache...\n", .{ YELLOW, RESET });
    const result = try cell_parser.discoverCached(allocator, .{
        .use_cache = true,
        .benchmark = false,
    });
    defer {
        for (result.cells) |c| {
            allocator.free(c.content);
            allocator.free(c.dir_path);
        }
        allocator.free(result.cells);
    }

    const ms = @as(f64, @floatFromInt(result.total_time_ns)) / 1_000_000.0;
    const verdict = if (ms < 50) "FAST" else if (ms < 100) "OK" else "SLOW";
    const vcolor = if (ms < 50) GREEN else if (ms < 100) YELLOW else RED;

    std.debug.print("\n  {s}Discovery time:{s} {s}{d:.2} ms{s}\n", .{ CYAN, RESET, vcolor, RESET, ms });
    std.debug.print("  {s}Verdict:{s}        {s}{s}{s}\n\n", .{ CYAN, RESET, vcolor, verdict, RESET });
}

/// Clear cache file
fn runCacheClear(allocator: Allocator) !void {
    const stats = try cell_parser.getCacheStats(allocator);

    if (!stats.file_exists) {
        std.debug.print("{s}Cache file does not exist.{s}\n", .{ YELLOW, RESET });
        return;
    }

    std.debug.print("Clearing cache file ({d} KB)...\n", .{stats.file_size / 1024});

    try cell_parser.clearCache();

    std.debug.print("{s}Cache cleared.{s}\n\n", .{ GREEN, RESET });
    std.debug.print("Run {s}tri cell status{s} to rebuild cache.\n", .{ CYAN, RESET });
}

/// Force refresh all cached cells
fn runCacheRefresh(allocator: Allocator) !void {
    const stats = try cell_parser.getCacheStats(allocator);

    if (!stats.file_exists) {
        std.debug.print("{s}Cache file does not exist. Run {s}tri cell status{s} first.{s}\n", .{ YELLOW, RESET, CYAN, RESET });
        return;
    }

    std.debug.print("Force refreshing all cached cells...\n", .{ YELLOW, RESET });

    const result = try cell_parser.discoverCached(allocator, .{
        .use_cache = true,
        .force_refresh = true,
    });
    defer {
        for (result.cells) |c| {
            allocator.free(c.content);
            allocator.free(c.dir_path);
        }
        allocator.free(result.cells);
    }

    const ms = @as(f64, @floatFromInt(result.total_time_ns)) / 1_000_000.0;
    std.debug.print("\n{s}Refreshed {d} cells in {d:.2} ms{s}\n\n", .{ GREEN, RESET, result.cells.len, ms, RESET });
}
