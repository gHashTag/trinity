// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI CELL PARSER — Single Source of Truth for cell.tri manifests
// ═══════════════════════════════════════════════════════════════════════════════
//
// One parser, one struct. All cell consumers import from here.
// Eliminates 4 duplicate parsers across tri_cell, tri_cell_dispatch,
// tri_events, tri_plugin.
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// Re-export from global constants for backward compatibility
pub const CELL_SCAN_DIRS = @import("const.zig").CELL_SCAN_DIRS;

// Cache configuration
const CACHE_DIR = ".trinity/cache";
const CACHE_FILE = CACHE_DIR ++ "/cells.json";
const CACHE_VERSION: u32 = 1;

/// Complete cell manifest — parsed from cell.tri
/// All string fields are slices into the original content buffer.
/// Caller must keep content alive while using this struct.
pub const CellManifest = struct {
    // [cell] section
    id: []const u8 = "",
    name: []const u8 = "",
    version: []const u8 = "",
    kind: []const u8 = "",
    path: []const u8 = "",
    parent: []const u8 = "", // Sub-cell: parent cell ID (e.g. "trinity.tri")
    status: []const u8 = "",
    description: []const u8 = "",
    min_core_version: []const u8 = "",
    capabilities: []const u8 = "",
    files: u32 = 0,
    tests: u32 = 0,
    owner: []const u8 = "",

    // [source] section — virtual sub-cells use file_patterns instead of directory
    file_patterns: []const u8 = "", // glob patterns for files (e.g. ["tri_farm*.zig", "railway_*.zig"])

    // [tags] section
    tags_scope: []const u8 = "",
    tags_type: []const u8 = "",

    // [contributes] section
    contributes_commands: []const u8 = "",
    contributes_tri_subcommands: []const u8 = "",
    contributes_events: []const u8 = "",
    contributes_binaries: []const u8 = "",
    contributes_exports: []const u8 = "", // pub fn names this cell guarantees

    // [dependencies] section — raw text for lazy parsing
    dependencies_raw: []const u8 = "",

    // [permissions] section
    perm_level: []const u8 = "",
    perm_filesystem: []const u8 = "",
    perm_network: []const u8 = "",
    perm_process: []const u8 = "",
    perm_ffi: []const u8 = "",
    perm_concurrency: []const u8 = "",

    // [security] section
    security_signed: bool = false,
    security_signature: []const u8 = "",
    security_score: ?u8 = null,

    // [dna] section — regeneration contract for Phoenix system
    dna_cell_id: []const u8 = "",
    dna_source: []const u8 = "",
    dna_output: []const u8 = "",
    dna_regenerable: bool = false,

    // [contract] section — stored as raw text for Phoenix validation
    dna_contract_raw: []const u8 = "",

    // [biology] section — biological system classification
    bio_system: []const u8 = "", // "dna" | "brain" | "immune" | "regen" | "body"
    bio_organ: []const u8 = "", // e.g. "ribosome", "hypothalamus", "leukocyte", "heartbeat"

    // [agent] section — links cell to .claude/agents/<name>.md definition
    agent_definition: []const u8 = "", // ".claude/agents/queen-swift.md"
    agent_model: []const u8 = "", // "opus" | "sonnet" | "haiku"
    agent_max_turns: u16 = 0,
    agent_tools: []const u8 = "", // "Read,Edit,Write,Bash,Grep,Glob"
    agent_isolation: []const u8 = "", // "worktree" | ""

    /// True if this cell has DNA (regeneration contract)
    pub fn hasDNA(self: CellManifest) bool {
        return self.dna_source.len > 0 and self.dna_output.len > 0;
    }

    /// True if this cell is an agent with a .md definition
    pub fn isAgent(self: CellManifest) bool {
        return self.agent_definition.len > 0;
    }

    // Convenience: check if cell has any tri subcommands
    pub fn hasSubcommands(self: CellManifest) bool {
        return self.contributes_tri_subcommands.len > 2;
    }

    // Convenience: check if cell has any events
    pub fn hasEvents(self: CellManifest) bool {
        return self.contributes_events.len > 2;
    }

    // Convenience: check if cell has any commands
    pub fn hasCommands(self: CellManifest) bool {
        return self.contributes_commands.len > 2;
    }

    // Convenience: check if cell declares exports
    pub fn hasExports(self: CellManifest) bool {
        return self.contributes_exports.len > 2;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PARSER — section-aware cell.tri TOML-like format
// ═══════════════════════════════════════════════════════════════════════════════

const Section = enum { cell, tags, contributes, dependencies, permissions, security, source, agent, dna, contract, biology };

/// Parse cell.tri content into CellManifest.
/// All string fields are slices into `content` — caller must keep it alive.
pub fn parse(content: []const u8) CellManifest {
    var m = CellManifest{};
    var current_section: Section = .cell;

    var dep_section_start: ?usize = null;
    var dep_section_end: usize = 0;
    var contract_section_start: ?usize = null;
    var contract_section_end: usize = 0;

    var offset: usize = 0;
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        offset += line.len + 1;
        if (offset > content.len) offset = content.len;
        const trimmed = std.mem.trim(u8, line, &[_]u8{ ' ', '\t', '\r' });
        if (trimmed.len == 0) continue;

        // Section headers
        if (trimmed.len >= 2 and trimmed[0] == '[') {
            if (std.mem.eql(u8, trimmed, "[cell]")) {
                current_section = .cell;
            } else if (std.mem.eql(u8, trimmed, "[tags]")) {
                current_section = .tags;
            } else if (std.mem.eql(u8, trimmed, "[contributes]")) {
                current_section = .contributes;
            } else if (std.mem.eql(u8, trimmed, "[dependencies]")) {
                current_section = .dependencies;
                dep_section_start = offset;
            } else if (std.mem.eql(u8, trimmed, "[permissions]")) {
                current_section = .permissions;
            } else if (std.mem.eql(u8, trimmed, "[security]")) {
                current_section = .security;
            } else if (std.mem.eql(u8, trimmed, "[source]")) {
                current_section = .source;
            } else if (std.mem.eql(u8, trimmed, "[agent]")) {
                current_section = .agent;
            } else if (std.mem.eql(u8, trimmed, "[dna]")) {
                current_section = .dna;
            } else if (std.mem.eql(u8, trimmed, "[contract]")) {
                current_section = .contract;
                contract_section_start = offset;
            } else if (std.mem.eql(u8, trimmed, "[biology]")) {
                current_section = .biology;
            }
            continue;
        }

        // Parse key = value
        const eq_pos = std.mem.indexOf(u8, trimmed, "=") orelse continue;
        if (eq_pos == 0) continue;
        const key = std.mem.trim(u8, trimmed[0..eq_pos], &[_]u8{ ' ', '\t' });
        const value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], &[_]u8{ ' ', '\t', '"' });

        switch (current_section) {
            .cell => {
                if (std.mem.eql(u8, key, "id")) m.id = value else if (std.mem.eql(u8, key, "name")) m.name = value else if (std.mem.eql(u8, key, "version")) m.version = value else if (std.mem.eql(u8, key, "kind")) m.kind = value else if (std.mem.eql(u8, key, "path")) m.path = value else if (std.mem.eql(u8, key, "parent")) m.parent = value else if (std.mem.eql(u8, key, "status")) m.status = value else if (std.mem.eql(u8, key, "description")) m.description = value else if (std.mem.eql(u8, key, "min_core_version")) m.min_core_version = value else if (std.mem.eql(u8, key, "capabilities")) m.capabilities = value else if (std.mem.eql(u8, key, "owner")) m.owner = value else if (std.mem.eql(u8, key, "files")) m.files = std.fmt.parseInt(u32, value, 10) catch 0 else if (std.mem.eql(u8, key, "tests")) m.tests = std.fmt.parseInt(u32, value, 10) catch 0;
            },
            .tags => {
                if (std.mem.eql(u8, key, "scope")) m.tags_scope = value else if (std.mem.eql(u8, key, "type")) m.tags_type = value;
            },
            .contributes => {
                if (std.mem.eql(u8, key, "commands")) m.contributes_commands = value else if (std.mem.eql(u8, key, "tri_subcommands")) m.contributes_tri_subcommands = value else if (std.mem.eql(u8, key, "events")) m.contributes_events = value else if (std.mem.eql(u8, key, "binaries")) m.contributes_binaries = value else if (std.mem.eql(u8, key, "exports")) m.contributes_exports = value;
            },
            .dependencies => {
                if (key.len > 0) dep_section_end = offset;
            },
            .permissions => {
                if (std.mem.eql(u8, key, "level")) m.perm_level = value else if (std.mem.eql(u8, key, "filesystem")) m.perm_filesystem = value else if (std.mem.eql(u8, key, "network")) m.perm_network = value else if (std.mem.eql(u8, key, "process")) m.perm_process = value else if (std.mem.eql(u8, key, "ffi")) m.perm_ffi = value else if (std.mem.eql(u8, key, "concurrency")) m.perm_concurrency = value;
            },
            .security => {
                if (std.mem.eql(u8, key, "signed")) m.security_signed = std.mem.eql(u8, value, "true") else if (std.mem.eql(u8, key, "signature")) m.security_signature = value;
            },
            .source => {
                if (std.mem.eql(u8, key, "file_patterns")) m.file_patterns = value;
            },
            .dna => {
                if (std.mem.eql(u8, key, "cell_id")) m.dna_cell_id = value else if (std.mem.eql(u8, key, "source")) m.dna_source = value else if (std.mem.eql(u8, key, "output")) m.dna_output = value else if (std.mem.eql(u8, key, "regenerable")) m.dna_regenerable = std.mem.eql(u8, value, "true");
            },
            .contract => {
                if (key.len > 0) contract_section_end = offset;
            },
            .agent => {
                if (std.mem.eql(u8, key, "definition")) m.agent_definition = value else if (std.mem.eql(u8, key, "model")) m.agent_model = value else if (std.mem.eql(u8, key, "max_turns")) m.agent_max_turns = std.fmt.parseInt(u16, value, 10) catch 0 else if (std.mem.eql(u8, key, "tools")) m.agent_tools = value else if (std.mem.eql(u8, key, "isolation")) m.agent_isolation = value;
            },
            .biology => {
                if (std.mem.eql(u8, key, "system")) m.bio_system = value else if (std.mem.eql(u8, key, "organ")) m.bio_organ = value;
            },
        }
    }

    if (dep_section_start) |start| {
        if (dep_section_end > start) {
            m.dependencies_raw = content[start..dep_section_end];
        }
    }

    if (contract_section_start) |start| {
        if (contract_section_end > start) {
            m.dna_contract_raw = content[start..contract_section_end];
        }
    }

    return m;
}

// ═══════════════════════════════════════════════════════════════════════════════
// DISCOVERY — walk filesystem for cell.tri files
// ═══════════════════════════════════════════════════════════════════════════════

/// Discovery result: content buffer + parsed manifest
pub const DiscoveredCell = struct {
    /// Raw file content — must be kept alive while manifest is used.
    /// NOT freed by the caller when using page_allocator (main.zig).
    content: []const u8,
    manifest: CellManifest,
    /// Relative path to the cell directory (e.g. "src/arena")
    dir_path: []const u8,
};

/// Simple in-memory cache for cell discovery
var cache_state: struct {
    initialized: bool = false,
    mtime: i128 = 0,
    cell_paths: []const []const u8 = &.{},
    manifests: []const CellManifest = &.{},
} = .{};

var cache_mutex = std.Thread.Mutex{};

/// Discovery options for benchmarking and cache control
pub const DiscoveryOptions = struct {
    use_cache: bool = false,
    benchmark: bool = false,
};

/// Discovery result with timing information for benchmarking
pub const DiscoveryResult = struct {
    cells: []DiscoveredCell,
    cache_hits: usize = 0,
    cache_misses: usize = 0,
    scan_time_ns: u64 = 0,
    parse_time_ns: u64 = 0,
    total_time_ns: u64 = 0,
};

/// Discover and parse all cell.tri manifests with timing information.
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
    fn toJson(self: *const CellCache, allocator: Allocator) ![]const u8 {
        var root = std.json.ObjectMap.init(allocator);
        defer root.deinit();

        try root.put("version", std.json.Value{ .integer = self.version });

        var cells_array = std.json.Array.init(allocator);
        defer cells_array.deinit();

        for (self.cells) |cell| {
            var cell_obj = std.json.ObjectMap.init(allocator);
            defer cell_obj.deinit();

            try cell_obj.put("path", std.json.Value{ .string = cell.path });
            try cell_obj.put("mtime", std.json.Value{ .integer = @as(i64, @intCast(cell.mtime)) });
            try cell_obj.put("dir_path", std.json.Value{ .string = cell.dir_path });
            try cell_obj.put("content", std.json.Value{ .string = cell.content });

            try cells_array.append(std.json.Value{ .object = cell_obj });
        }

        try root.put("cells", std.json.Value{ .array = cells_array });

        const root_value = std.json.Value{ .object = root };
        return std.json.Stringify.valueAlloc(allocator, root_value, .{ .whitespace = .indent_2 });
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
            cells.deinit(allocator);
        }

        for (cells_value.array.items) |cell_val| {
            if (cell_val != .object) continue;
            const obj = cell_val.object;

            const path = (obj.get("path") orelse continue).string;
            const mtime = (obj.get("mtime") orelse continue).integer;
            const dir_path = (obj.get("dir_path") orelse continue).string;
            const content = (obj.get("content") orelse continue).string;

            try cells.append(allocator, .{
                .path = try allocator.dupe(u8, path),
                .mtime = mtime,
                .dir_path = try allocator.dupe(u8, dir_path),
                .content = try allocator.dupe(u8, content),
            });
        }

        return .{
            .version = @intCast(version.integer),
            .cells = try cells.toOwnedSlice(allocator),
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

    var cache = CellCache.fromJson(allocator, content) catch return stats;
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

    var result = DiscoveryResultEx{ .cells = &.{} };
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
        // Convert ArrayList to slice after all additions
        // Copy remaining valid entries from old cache
        if (loaded_cache) |old_cache| {
            for (old_cache.cells) |old_cell| {
                const already_added = blk: {
                    for (new_cache_cells.items) |new_cell| {
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
                            try new_cache_cells.append(.{
                                .path = path_copy,
                                .mtime = old_cell.mtime,
                                .dir_path = dir_copy,
                                .content = content_copy,
                            });
                        }
                    } else |_| {}
                }
            }
        } // end if (loaded_cache)

        new_cache.cells = try new_cache_cells.toOwnedSlice();
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
pub fn discoverAllEx(allocator: Allocator, options: DiscoveryOptions) !DiscoveryResult {
    const total_start = std.time.nanoTimestamp();

    // Check if we can use the cache
    var cache_hits: usize = 0;
    var cache_misses: usize = 0;

    const needs_refresh = blk: {
        if (!options.use_cache) break :blk true;
        if (!cache_state.initialized) break :blk true;

        // Check if any scan directory was modified
        const cwd = std.fs.cwd();
        for (CELL_SCAN_DIRS) |scan_dir| {
            if (cwd.statFile(scan_dir)) |stat| {
                if (stat.mtime > cache_state.mtime) break :blk true;
            } else |_| {
                break :blk true;
            }
        }
        break :blk false;
    };

    var scan_results = try std.array_list.Managed(DiscoveredCell).initCapacity(allocator, 64);
    defer {
        if (!needs_refresh) {
            // Don't free on cache hit
        } else {
            for (scan_results.items) |c| {
                allocator.free(c.content);
                allocator.free(c.dir_path);
            }
        }
    }

    var parse_time_ns: u64 = 0;

    if (!needs_refresh and options.use_cache) {
        // Use cached manifests
        const parse_start = std.time.nanoTimestamp();
        for (cache_state.cell_paths, cache_state.manifests) |path, manifest| {
            const content = try allocator.dupe(u8, "");
            const dir_path = try allocator.dupe(u8, path);
            try scan_results.append(.{
                .content = content,
                .manifest = manifest,
                .dir_path = dir_path,
            });
            cache_hits += 1;
        }
        const parse_end = std.time.nanoTimestamp();
        parse_time_ns = @as(u64, @intCast(parse_end - parse_start));
    } else {
        // Full scan
        const parse_start = std.time.nanoTimestamp();

        const cwd = std.fs.cwd();

        // Collect all cell.tri files first
        var cell_files = try std.array_list.Managed(struct { path: []const u8, mtime: i128 }).initCapacity(allocator, 64);
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
                cache_misses += 1;
            }
        }

        // Parse all cells
        for (cell_files.items) |cf| {
            const content = cwd.readFileAlloc(allocator, cf.path, 65536) catch continue;
            const manifest = parse(content);

            if (manifest.id.len > 0) {
                // cf.path is like "src/research/cell.tri"
                // We need to extract "src/research" as the cell directory
                const cell_dir_with_file = std.fs.path.dirname(cf.path) orelse "";
                // cell_dir_with_file is now "src/research"
                // Just use it directly (no need to prepend scan_dir again)
                const cell_dir = try allocator.dupe(u8, cell_dir_with_file);

                try scan_results.append(.{
                    .content = content,
                    .manifest = manifest,
                    .dir_path = cell_dir,
                });
            }
        }

        const parse_end = std.time.nanoTimestamp();
        parse_time_ns = @as(u64, @intCast(parse_end - parse_start));

        // Update cache
        if (options.use_cache) {
            cache_mutex.lock();
            defer cache_mutex.unlock();

            // Free old cache
            if (cache_state.initialized) {
                const old_cache = cache_state;
                allocator.free(old_cache.cell_paths);
                // manifests are slices into content, don't free them
            }

            // Build new cache
            var paths = std.array_list.Managed([]const u8).init(allocator);
            var manifests = std.array_list.Managed(CellManifest).init(allocator);

            for (scan_results.items) |cell| {
                try paths.append(try allocator.dupe(u8, cell.dir_path));
                try manifests.append(cell.manifest);
            }

            cache_state.cell_paths = try paths.toOwnedSlice();
            cache_state.manifests = try manifests.toOwnedSlice();
            cache_state.mtime = std.time.nanoTimestamp();
            cache_state.initialized = true;
        }
    }

    const total_end = std.time.nanoTimestamp();

    return .{
        .cells = try scan_results.toOwnedSlice(),
        .cache_hits = cache_hits,
        .cache_misses = cache_misses,
        .scan_time_ns = @as(u64, @intCast(total_end - total_start)) - parse_time_ns,
        .parse_time_ns = parse_time_ns,
        .total_time_ns = @as(u64, @intCast(total_end - total_start)),
    };
}

/// Discover and parse all cell.tri manifests (legacy API).
/// Returns owned slice of DiscoveredCell. Content buffers are NOT freed
/// (slices in manifest reference them). Safe with page_allocator.
pub fn discoverAll(allocator: Allocator) ![]DiscoveredCell {
    const result = try discoverAllEx(allocator, .{});
    return result.cells;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ARRAY HELPERS — parse ["a", "b"] style arrays from cell.tri values
// ═══════════════════════════════════════════════════════════════════════════════

/// Iterator over items in a cell.tri array value like ["a", "b", "c"]
pub const ArrayIterator = struct {
    inner: std.mem.SplitIterator(u8, .sequence),

    pub fn init(raw: []const u8) ArrayIterator {
        const stripped = std.mem.trim(u8, raw, &[_]u8{ '[', ']', '"', ' ' });
        return .{ .inner = std.mem.splitSequence(u8, stripped, "\", \"") };
    }

    pub fn next(self: *ArrayIterator) ?[]const u8 {
        while (self.inner.next()) |item| {
            const trimmed = std.mem.trim(u8, item, &[_]u8{ '"', ' ' });
            if (trimmed.len > 0) return trimmed;
        }
        return null;
    }
};

/// Iterator over dependency entries from raw [dependencies] section text
pub const DepIterator = struct {
    lines: std.mem.SplitIterator(u8, .scalar),

    pub fn init(raw: []const u8) DepIterator {
        return .{ .lines = std.mem.splitScalar(u8, raw, '\n') };
    }

    pub fn next(self: *DepIterator) ?struct { id: []const u8, constraint: []const u8 } {
        while (self.lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, &[_]u8{ ' ', '\t', '\r' });
            if (trimmed.len == 0) continue;
            if (trimmed[0] == '[') break;
            const eq_pos = std.mem.indexOf(u8, trimmed, "=") orelse continue;
            if (eq_pos == 0) continue;
            const key = std.mem.trim(u8, trimmed[0..eq_pos], &[_]u8{ ' ', '\t', '"' });
            const value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], &[_]u8{ ' ', '\t', '"' });
            if (key.len > 0 and value.len > 0) {
                return .{ .id = key, .constraint = value };
            }
        }
        return null;
    }

    pub fn count(raw: []const u8) usize {
        var it = DepIterator.init(raw);
        var n: usize = 0;
        while (it.next()) |_| n += 1;
        return n;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "parse full cell.tri — arena" {
    const content =
        \\[cell]
        \\id = "trinity.arena"
        \\name = "Arena 2.0"
        \\version = "1.0.0"
        \\kind = "tool"
        \\path = "src/arena"
        \\min_core_version = "1.0.0"
        \\status = "stable"
        \\description = "LLM battle platform with ELO ratings"
        \\capabilities = ["arena", "elo", "battle"]
        \\files = 7
        \\tests = 30
        \\owner = "agent:ralph"
        \\
        \\[tags]
        \\scope = "hslm"
        \\type = "tool"
        \\
        \\[contributes]
        \\commands = ["battle", "leaderboard", "judge"]
        \\tri_subcommands = ["arena battle", "arena leaderboard"]
        \\events = ["on_battle_complete", "on_elo_update"]
        \\binaries = ["arena"]
        \\
        \\[dependencies]
        \\trinity.hslm = "^1.0.0"
        \\
        \\[permissions]
        \\level = "L2"
        \\filesystem = "write"
        \\network = "external"
        \\process = "spawn"
        \\ffi = "none"
        \\concurrency = "none"
        \\
        \\[security]
        \\signed = true
        \\signature = "sha256:abc123"
    ;

    const m = parse(content);
    try std.testing.expectEqualStrings("trinity.arena", m.id);
    try std.testing.expectEqualStrings("Arena 2.0", m.name);
    try std.testing.expectEqualStrings("1.0.0", m.version);
    try std.testing.expectEqualStrings("tool", m.kind);
    try std.testing.expectEqualStrings("src/arena", m.path);
    try std.testing.expectEqualStrings("stable", m.status);
    try std.testing.expectEqual(@as(u32, 7), m.files);
    try std.testing.expectEqual(@as(u32, 30), m.tests);
    try std.testing.expectEqualStrings("agent:ralph", m.owner);
    try std.testing.expectEqualStrings("hslm", m.tags_scope);
    try std.testing.expectEqualStrings("tool", m.tags_type);
    try std.testing.expect(m.hasSubcommands());
    try std.testing.expect(m.hasEvents());
    try std.testing.expect(m.hasCommands());
    try std.testing.expectEqualStrings("L2", m.perm_level);
    try std.testing.expectEqualStrings("write", m.perm_filesystem);
    try std.testing.expect(m.security_signed);
    try std.testing.expectEqualStrings("sha256:abc123", m.security_signature);
}

test "parse minimal cell.tri" {
    const content =
        \\[cell]
        \\id = "trinity.core"
        \\name = "Core"
        \\path = "src/core"
    ;
    const m = parse(content);
    try std.testing.expectEqualStrings("trinity.core", m.id);
    try std.testing.expect(!m.hasSubcommands());
    try std.testing.expect(!m.hasEvents());
    try std.testing.expect(!m.hasCommands());
    try std.testing.expectEqualStrings("", m.contributes_commands);
}

test "array iterator" {
    var iter = ArrayIterator.init("[\"arena battle\", \"arena leaderboard\"]");
    const first = iter.next().?;
    try std.testing.expectEqualStrings("arena battle", first);
    const second = iter.next().?;
    try std.testing.expectEqualStrings("arena leaderboard", second);
    try std.testing.expect(iter.next() == null);
}

test "array iterator — empty" {
    var iter = ArrayIterator.init("[]");
    try std.testing.expect(iter.next() == null);
}

test "dep iterator" {
    const deps = "trinity.hslm = \"^1.0.0\"\ntrinity.vsa = \">=0.5.0\"\n";
    var iter = DepIterator.init(deps);
    const first = iter.next().?;
    try std.testing.expectEqualStrings("trinity.hslm", first.id);
    try std.testing.expectEqualStrings("^1.0.0", first.constraint);
    const second = iter.next().?;
    try std.testing.expectEqualStrings("trinity.vsa", second.id);
    try std.testing.expect(iter.next() == null);
}

test "dep count" {
    try std.testing.expectEqual(@as(usize, 2), DepIterator.count("a = \"1\"\nb = \"2\"\n"));
    try std.testing.expectEqual(@as(usize, 0), DepIterator.count(""));
}

test "parse agent cell.tri" {
    const content =
        \\[cell]
        \\id = "trinity.agent.queen-swift"
        \\name = "Queen Swift Agent"
        \\version = "1.0.0"
        \\kind = "agent"
        \\path = "tools/agents/queen-swift"
        \\status = "stable"
        \\description = "SwiftUI developer for Queen UI"
        \\capabilities = ["swiftui", "macos", "queen-ui"]
        \\owner = "agent:ralph"
        \\
        \\[tags]
        \\scope = "agent"
        \\type = "agent"
        \\
        \\[agent]
        \\definition = ".claude/agents/queen-swift.md"
        \\model = "opus"
        \\max_turns = 30
        \\tools = "Read,Edit,Write,Bash,Grep,Glob"
        \\isolation = "worktree"
        \\
        \\[permissions]
        \\level = "L2"
        \\filesystem = "write"
        \\network = "none"
        \\process = "spawn"
    ;

    const m = parse(content);
    try std.testing.expectEqualStrings("trinity.agent.queen-swift", m.id);
    try std.testing.expectEqualStrings("agent", m.kind);
    try std.testing.expect(m.isAgent());
    try std.testing.expectEqualStrings(".claude/agents/queen-swift.md", m.agent_definition);
    try std.testing.expectEqualStrings("opus", m.agent_model);
    try std.testing.expectEqual(@as(u16, 30), m.agent_max_turns);
    try std.testing.expectEqualStrings("Read,Edit,Write,Bash,Grep,Glob", m.agent_tools);
    try std.testing.expectEqualStrings("worktree", m.agent_isolation);
    try std.testing.expectEqualStrings("L2", m.perm_level);
    try std.testing.expectEqualStrings("write", m.perm_filesystem);
    try std.testing.expectEqualStrings("spawn", m.perm_process);
}

test "non-agent cell has isAgent false" {
    const content =
        \\[cell]
        \\id = "trinity.core"
        \\name = "Core"
        \\path = "src/core"
    ;
    const m = parse(content);
    try std.testing.expect(!m.isAgent());
    try std.testing.expectEqualStrings("", m.agent_definition);
}

test "parse cell.tri with DNA section" {
    const content =
        \\[cell]
        \\id = "trinity.b2t"
        \\name = "B2T"
        \\path = "src/b2t"
        \\
        \\[dna]
        \\cell_id = "trinity.b2t"
        \\source = "specs/b2t/core.tri"
        \\output = "gen/protein.zig"
        \\regenerable = true
        \\
        \\[contract]
        \\inputs = ["binary_data: []u8"]
        \\outputs = ["ternary_data: []Trit"]
    ;

    const m = parse(content);
    try std.testing.expectEqualStrings("trinity.b2t", m.id);
    try std.testing.expectEqualStrings("trinity.b2t", m.dna_cell_id);
    try std.testing.expectEqualStrings("specs/b2t/core.tri", m.dna_source);
    try std.testing.expectEqualStrings("gen/protein.zig", m.dna_output);
    try std.testing.expect(m.dna_regenerable);
    try std.testing.expect(m.hasDNA());
    try std.testing.expect(m.dna_contract_raw.len > 0);
}

test "cell without DNA has hasDNA false" {
    const content =
        \\[cell]
        \\id = "trinity.core"
        \\name = "Core"
        \\path = "src/core"
    ;

    const m = parse(content);
    try std.testing.expect(!m.hasDNA());
}
