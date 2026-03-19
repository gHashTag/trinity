// ═══════════════════════════════════════════════════════════════════════════════
// PERSISTENT FILE CACHE — cross-run cell discovery caching
// ═══════════════════════════════════════════════════════════════════════════════

/// Cache entry for a single cell
const CachedCell = struct {
    /// Path to cell.tri file (relative to repo root)
    path: []const u8,
    /// Last modification time of cell.tri
    mtime: i128,
    /// Directory path for the cell
    dir_path: []const u8,
    /// Raw cell.tri content
    content: []const u8,
};

/// Persistent cache structure (JSON-serializable)
const CellCache = struct {
    version: u32 = CACHE_VERSION,
    /// Cache entries
    cells: []CachedCell = &.{},

    /// Serialize cache to JSON
    fn toJson(allocator: Allocator, self: *const CellCache) ![]const u8 {
        var root = std.json.ObjectMap.init(allocator);
        defer root.deinit();

        try root.put("version", std.json.Value{ .integer = self.version });

        var cells_array = std.json.Array.init(allocator);
        defer cells_array.deinit();

        for (self.cells) |cell| {
            var cell_obj = std.json.ObjectMap.init(allocator);
            defer cell_obj.deinit();

            try cell_obj.put("path", std.json.Value{ .string = cell.path });
            try cell_obj.put("mtime", std.json.Value{ .integer = cell.mtime });
            try cell_obj.put("dir_path", std.json.Value{ .string = cell.dir_path });
            try cell_obj.put("content", std.json.Value{ .string = cell.content });

            try cells_array.append(std.json.Value{ .object = cell_obj });
        }

        try root.put("cells", std.json.Value{ .array = cells_array });

        const root_value = std.json.Value{ .object = root };
        return std.json.stringifyAlloc(allocator, root_value, .{ .whitespace = .indent_2 });
    }

    /// Deserialize cache from JSON
    fn fromJson(allocator: Allocator, json_str: []const u8) !CellCache {
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
        defer parsed.deinit();

        const root = parsed.value.object;
        const version = root.get("version") orelse return error.InvalidCacheVersion;
        if (version.integer != CACHE_VERSION) return error.InvalidCacheVersion;

        const cells_value = root.get("cells") orelse return error.InvalidCacheFormat;
        if (cells_value != .array) return error.InvalidCacheFormat;

        var cells = std.ArrayList(CachedCell).initCapacity(allocator, cells_value.array.items.len) catch unreachable;
        errdefer {
            for (cells.items) |c| {
                allocator.free(c.path);
                allocator.free(c.dir_path);
                allocator.free(c.content);
            }
            cells.deinit();
        }

        for (cells_value.array.items) |cell_val| {
            if (cell_val != .object) continue;
            const obj = cell_val.object;

            const path = (obj.get("path") orelse continue).string;
            const mtime = (obj.get("mtime") orelse continue).integer;
            const dir_path = (obj.get("dir_path") orelse continue).string;
            const content = (obj.get("content") orelse continue).string;

            try cells.append(.{
                .path = try allocator.dupe(u8, path),
                .mtime = mtime,
                .dir_path = try allocator.dupe(u8, dir_path),
                .content = try allocator.dupe(u8, content),
            });
        }

        return .{
            .version = @intCast(version.integer),
            .cells = try cells.toOwnedSlice(),
        };
    }

    /// Free all cache allocations
    fn deinit(self: *CellCache, allocator: Allocator) void {
        for (self.cells) |cell| {
            allocator.free(cell.path);
            allocator.free(cell.dir_path);
            allocator.free(cell.content);
        }
        allocator.free(self.cells);
        self.* = undefined;
    }
};

/// Load cache from file, returns null if file doesn't exist or is invalid
fn loadCache(allocator: Allocator) ?CellCache {
    const cwd = std.fs.cwd();

    const file = cwd.openFile(CACHE_FILE, .{}) catch return null;
    defer file.close();

    const content = file.readToEndAlloc(allocator, 10 * 1024 * 1024) catch return null;
    defer allocator.free(content);

    return CellCache.fromJson(allocator, content) catch null;
}

/// Save cache to file, creates directory if needed
fn saveCache(allocator: Allocator, cache: *const CellCache) !void {
    const cwd = std.fs.cwd();

    // Create cache directory if it doesn't exist
    cwd.makePath(CACHE_DIR) catch |err| {
        std.debug.print("Warning: failed to create cache directory: {}\n", .{err});
        return err;
    };

    const json_str = try cache.toJson(allocator);
    defer allocator.free(json_str);

    const file = try cwd.createFile(CACHE_FILE, .{ .truncate = true });
    defer file.close();

    try file.writeAll(json_str);
}

/// Clear the cache file
pub fn clearCache() !void {
    const cwd = std.fs.cwd();
    cwd.deleteFile(CACHE_FILE) catch |err| {
        // Ignore error if file doesn't exist
        if (err != error.FileNotFound) return err;
    };
    _ = cwd.deleteDir(CACHE_DIR) catch {};
}

/// Get cache statistics
pub const CacheStats = struct {
    enabled: bool = false,
    file_exists: bool = false,
    total_entries: usize = 0,
    valid_entries: usize = 0,
    stale_entries: usize = 0,
    file_size: usize = 0,
};

/// Get current cache statistics
pub fn getCacheStats(allocator: Allocator) !CacheStats {
    var stats = CacheStats{ .enabled = true };

    const cwd = std.fs.cwd();

    const file = cwd.openFile(CACHE_FILE, .{}) catch {
        return stats;
    };
    defer file.close();

    stats.file_exists = true;
    const stat = try file.stat();
    stats.file_size = @intCast(stat.size);

    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);

    const cache = CellCache.fromJson(allocator, content) catch return stats;
    defer cache.deinit(allocator);

    stats.total_entries = cache.cells.len;

    // Check which entries are still valid
    for (cache.cells) |cell| {
        if (cwd.statFile(cell.path)) |file_stat| {
            if (file_stat.mtime <= cell.mtime) {
                stats.valid_entries += 1;
            } else {
                stats.stale_entries += 1;
            }
        } else |_| {
            stats.stale_entries += 1;
        }
    }

    return stats;
}

/// Discovery options for persistent cache integration
pub const DiscoveryOptionsEx = struct {
    use_cache: bool = true,
    benchmark: bool = false,
    force_refresh: bool = false,
};

/// Enhanced discovery result with persistent cache integration
pub const DiscoveryResultEx = struct {
    cells: []DiscoveredCell,
    cache_hits: usize = 0,
    cache_misses: usize = 0,
    scan_time_ns: u64 = 0,
    parse_time_ns: u64 = 0,
    total_time_ns: u64 = 0,
    cache_stats: CacheStats = .{},
};

/// Discover and parse all cell.tri manifests with persistent file cache.
pub fn discoverCached(allocator: Allocator, options: DiscoveryOptionsEx) !DiscoveryResultEx {
    const total_start = std.time.nanoTimestamp();

    var result = DiscoveryResultEx{};
    var cache_hits: usize = 0;
    var cache_misses: usize = 0;
    var parse_time_ns: u64 = 0;

    var scan_results = std.array_list.Managed(DiscoveredCell).init(allocator);
    defer {
        for (scan_results.items) |c| {
            allocator.free(c.content);
            allocator.free(c.dir_path);
        }
        scan_results.deinit();
    }

    var new_cache = CellCache{};

    if (options.use_cache and !options.force_refresh) {
        result.cache_stats = try getCacheStats(allocator);
    }

    // Load cache from disk
    var loaded_cache: ?CellCache = null;
    if (options.use_cache and !options.force_refresh and result.cache_stats.file_exists) {
        loaded_cache = loadCache(allocator);
    }
    defer if (loaded_cache) |*c| c.deinit(allocator);

    // Build map of cached cells by path for fast lookup
    var cached_map = std.StringHashMap(CachedCell).init(allocator);
    defer cached_map.deinit();

    if (loaded_cache) |cache| {
        for (cache.cells) |cell| {
            cached_map.put(cell.path, cell) catch {};
        }
    }

    const cwd = std.fs.cwd();

    // Scan filesystem for all cell.tri files
    const parse_start = std.time.nanoTimestamp();
    var cell_files = std.array_list.Managed(struct { path: []const u8, mtime: i128 }).initCapacity(allocator, 128) catch unreachable;
    defer {
        for (cell_files.items) |cf| allocator.free(cf.path);
        cell_files.deinit();
    }

    for (CELL_SCAN_DIRS) |scan_dir| {
        var dir = cwd.openDir(scan_dir, .{ .iterate = true }) catch continue;
        defer dir.close();

        var walker = dir.walk(allocator) catch continue;
        defer walker.deinit();

        while (walker.next() catch null) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.eql(u8, entry.basename, "cell.tri")) continue;

            const sub_dir = std.fs.path.dirname(entry.path) orelse "";
            const cell_dir = if (sub_dir.len > 0)
                try std.fmt.allocPrint(allocator, "{s}/{s}", .{ scan_dir, sub_dir })
            else
                try allocator.dupe(u8, scan_dir);

            const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ scan_dir, entry.path });
            const stat = cwd.statFile(full_path) catch {
                allocator.free(cell_dir);
                allocator.free(full_path);
                continue;
            };

            try cell_files.append(.{ .path = full_path, .mtime = stat.mtime });
        }
    }

    const parse_end = std.time.nanoTimestamp();
    parse_time_ns = @as(u64, @intCast(parse_end - parse_start));

    var new_cache_cells = std.array_list.Managed(CachedCell).initCapacity(allocator, cell_files.items.len) catch unreachable;

    // Process each cell file
    for (cell_files.items) |cf| {
        const cell_dir_with_file = std.fs.path.dirname(cf.path) orelse "";
        const cell_dir = try allocator.dupe(u8, cell_dir_with_file);

        // Check if we have a valid cached entry
        const hit = if (cached_map.get(cf.path)) |cached| blk: {
            if (cf.mtime <= cached.mtime) {
                // Cache entry is valid
                const manifest = parse(cached.content);
                if (manifest.id.len > 0) {
                    try scan_results.append(.{
                        .content = try allocator.dupe(u8, cached.content),
                        .manifest = manifest,
                        .dir_path = cell_dir,
                    });
                    cache_hits += 1;
                    break :blk true;
                }
            }
            break :blk false;
        } else false;

        if (!hit) {
            // Cache miss or stale, parse from file
            const content = cwd.readFileAlloc(allocator, cf.path, 65536) catch {
                allocator.free(cell_dir);
                continue;
            };
            const manifest = parse(content);

            if (manifest.id.len > 0) {
                try scan_results.append(.{
                    .content = content,
                    .manifest = manifest,
                    .dir_path = cell_dir,
                });

                // Add to new cache
                try new_cache_cells.append(.{
                    .path = try allocator.dupe(u8, cf.path),
                    .mtime = cf.mtime,
                    .dir_path = try allocator.dupe(u8, cell_dir),
                    .content = content,
                });

                cache_misses += 1;
            } else {
                allocator.free(content);
                allocator.free(cell_dir);
            }
        }
    }

    const total_end = std.time.nanoTimestamp();

    // Save new cache
    if (options.use_cache) {
        new_cache.cells = try new_cache_cells.toOwnedSlice();

        // Copy remaining valid entries from old cache
        for (loaded_cache) |old_cache| {
            for (old_cache.cells) |old_cell| {
                const already_added = blk: {
                    for (new_cache.cells) |new_cell| {
                        if (std.mem.eql(u8, new_cell.path, old_cell.path)) break :blk true;
                    }
                    break :blk false;
                };

                if (!already_added) {
                    // Check if this entry is still valid
                    if (cwd.statFile(old_cell.path)) |file_stat| {
                        if (file_stat.mtime <= old_cell.mtime) {
                            // Cache hit, add to new cache
                            const path_copy = try allocator.dupe(u8, old_cell.path);
                            const dir_copy = try allocator.dupe(u8, old_cell.dir_path);
                            const content_copy = try allocator.dupe(u8, old_cell.content);
                            try new_cache.cells.append(.{
                                .path = path_copy,
                                .mtime = old_cell.mtime,
                                .dir_path = dir_copy,
                                .content = content_copy,
                            });
                        }
                    } else |_| {}
                }
            }
        }

        try saveCache(allocator, &new_cache);

        // Free new cache allocations
        for (new_cache.cells) |c| {
            allocator.free(c.path);
            allocator.free(c.dir_path);
            allocator.free(c.content);
        }
        allocator.free(new_cache.cells);
    } else {
        // Free new cache cells since we're not saving
        for (new_cache_cells.items) |c| {
            allocator.free(c.path);
            allocator.free(c.dir_path);
            allocator.free(c.content);
        }
        new_cache_cells.deinit();
    }

    result.cells = try scan_results.toOwnedSlice();
    result.cache_hits = cache_hits;
    result.cache_misses = cache_misses;
    result.scan_time_ns = parse_time_ns;
    result.parse_time_ns = 0; // Parse is included in scan now
    result.total_time_ns = @as(u64, @intCast(total_end - total_start));

    return result;
}
