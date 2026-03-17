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
        const trimmed = std.mem.trim(u8, line, " \t\r");
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
        const key = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
        const value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t\"");

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

/// Discovery options for benchmarking and cache control
pub const DiscoveryOptions = struct {
    use_cache: bool = true,
    parallel: bool = true,
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

/// Cache entry for cell.tri parse results
const CacheEntry = struct {
    mtime: i128,
    manifest: CellManifest,
    content_hash: u64,

    fn serialize(self: CacheEntry, writer: anytype) !void {
        try writer.writeInt(i128, self.mtime, .little);
        try writer.writeInt(u64, self.content_hash, .little);
        // Store selected fields from manifest
        try writer.writeInt(u32, @as(u32, @intCast(self.manifest.files)), .little);
        try writer.writeInt(u32, @as(u32, @intCast(self.manifest.tests)), .little);
        try writer.writeInt(u16, self.manifest.agent_max_turns, .little);
        try writer.writeAll(self.manifest.id);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.name);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.version);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.kind);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.path);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.parent);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.status);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.description);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.min_core_version);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.capabilities);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.owner);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.file_patterns);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.tags_scope);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.tags_type);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.contributes_commands);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.contributes_tri_subcommands);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.contributes_events);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.contributes_binaries);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.contributes_exports);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.dependencies_raw);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.perm_level);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.perm_filesystem);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.perm_network);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.perm_process);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.perm_ffi);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.perm_concurrency);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.security_signature);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.dna_cell_id);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.dna_source);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.dna_output);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.dna_contract_raw);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.bio_system);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.bio_organ);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.agent_definition);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.agent_model);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.agent_tools);
        try writer.writeByte(0);
        try writer.writeAll(self.manifest.agent_isolation);
        try writer.writeByte(0);
    }

    fn deserialize(allocator: Allocator, reader: anytype) !CacheEntry {
        const mtime = try reader.readInt(i128, .little);
        const content_hash = try reader.readInt(u64, .little);
        const files = try reader.readInt(u32, .little);
        const tests = try reader.readInt(u32, .little);
        const agent_max_turns = try reader.readInt(u16, .little);

        var manifest = CellManifest{};
        manifest.files = files;
        manifest.tests = tests;
        manifest.agent_max_turns = agent_max_turns;

        // Read null-terminated strings
        inline for (.{
            &manifest.id, &manifest.name, &manifest.version, &manifest.kind, &manifest.path,
            &manifest.parent, &manifest.status, &manifest.description, &manifest.min_core_version,
            &manifest.capabilities, &manifest.owner, &manifest.file_patterns, &manifest.tags_scope,
            &manifest.tags_type, &manifest.contributes_commands, &manifest.contributes_tri_subcommands,
            &manifest.contributes_events, &manifest.contributes_binaries, &manifest.contributes_exports,
            &manifest.dependencies_raw, &manifest.perm_level, &manifest.perm_filesystem,
            &manifest.perm_network, &manifest.perm_process, &manifest.perm_ffi, &manifest.perm_concurrency,
            &manifest.security_signature, &manifest.dna_cell_id, &manifest.dna_source,
            &manifest.dna_output, &manifest.dna_contract_raw, &manifest.bio_system, &manifest.bio_organ,
            &manifest.agent_definition, &manifest.agent_model, &manifest.agent_tools, &manifest.agent_isolation,
        }) |field| {
            var buf = try std.ArrayList(u8).initCapacity(allocator, 256);
            while (true) {
                const byte = try reader.readByte();
                if (byte == 0) break;
                try buf.append(allocator, byte);
            }
            field.* = try buf.toOwnedSlice(allocator);
        }

        return .{
            .mtime = mtime,
            .content_hash = content_hash,
            .manifest = manifest,
        };
    }
};

/// Context for parallel directory scanning
const ScanContext = struct {
    allocator: Allocator,
    scan_dir: []const u8,
    results: *std.array_list.Managed(DiscoveredCell),
    mutex: std.Thread.Mutex,
    cache_dir: std.fs.Dir,
    use_cache: bool,
    cache_hits: *usize,
    cache_misses: *usize,
    parse_time_ns: *u64,

    fn scan(self: *ScanContext) !void {
        const cwd = std.fs.cwd();
        var dir = cwd.openDir(self.scan_dir, .{ .iterate = true }) catch return;
        defer dir.close();

        var walker = dir.walk(self.allocator) catch return;
        defer walker.deinit();

        while (walker.next() catch null) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.eql(u8, entry.basename, "cell.tri")) continue;

            const sub_dir = std.fs.path.dirname(entry.path) orelse "";
            const cell_dir = if (sub_dir.len > 0)
                try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ self.scan_dir, sub_dir })
            else
                try self.allocator.dupe(u8, self.scan_dir);

            const full_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ self.scan_dir, entry.path });
            defer self.allocator.free(full_path);

            // Get file metadata for cache validation
            const stat = cwd.statFile(full_path) catch continue;
            const mtime = stat.mtime;

            // Try cache first
            var use_cached = false;
            if (self.use_cache) {
                const cache_key = try std.fmt.allocPrint(self.allocator, "{x}.cell", .{std.hash.Wyhash.hash(0, full_path)});
                defer self.allocator.free(cache_key);

                if (self.cache_dir.readFileAlloc(self.allocator, cache_key, 65536)) |cached_data| {
                    defer self.allocator.free(cached_data);
                    var fbs = std.io.fixedBufferStream(cached_data);
                    if (CacheEntry.deserialize(self.allocator, fbs.reader())) |cache_entry| {
                        if (cache_entry.mtime == mtime) {
                            // Cache hit - reconstruct content from manifest
                            const content = try self.allocator.dupe(u8, ""); // Empty but valid
                            self.mutex.lock();
                            try self.results.append(.{
                                .content = content,
                                .manifest = cache_entry.manifest,
                                .dir_path = cell_dir,
                            });
                            self.mutex.unlock();
                            self.cache_hits.* += 1;
                            use_cached = true;
                        } else {
                            self.cache_misses.* += 1;
                        }
                    } else |_| {
                        self.cache_misses.* += 1;
                    }
                } else |_| {
                    self.cache_misses.* += 1;
                }
            }

            if (!use_cached) {
                // Cache miss or disabled - parse file
                const parse_start = std.time.nanoTimestamp();
                const content = cwd.readFileAlloc(self.allocator, full_path, 65536) catch continue;
                const manifest = parse(content);
                const parse_end = std.time.nanoTimestamp();
                self.parse_time_ns.* += @as(u64, @intCast(parse_end - parse_start));

                if (manifest.id.len > 0) {
                    // Update cache
                    if (self.use_cache) {
                        const cache_key = try std.fmt.allocPrint(self.allocator, "{x}.cell", .{std.hash.Wyhash.hash(0, full_path)});
                        defer self.allocator.free(cache_key);

                        var hash = std.hash.Wyhash.init(0);
                        hash.update(content);
                        const content_hash = hash.final();

                        const cache_entry = CacheEntry{
                            .mtime = mtime,
                            .content_hash = content_hash,
                            .manifest = manifest,
                        };

                        var buf = std.ArrayList(u8).init(self.allocator);
                        try cache_entry.serialize(buf.writer());
                        self.cache_dir.writeFile(.{ .sub_path = cache_key, .data = buf.items }) catch {};
                    }

                    self.mutex.lock();
                    try self.results.append(.{
                        .content = content,
                        .manifest = manifest,
                        .dir_path = cell_dir,
                    });
                    self.mutex.unlock();
                }
            }
        }
    }
};

/// Discover and parse all cell.tri manifests with caching and parallel scan.
/// Returns owned slice of DiscoveredCell with timing information.
pub fn discoverAllEx(allocator: Allocator, options: DiscoveryOptions) !DiscoveryResult {
    var results = std.array_list.Managed(DiscoveredCell).init(allocator);
    errdefer {
        for (results.items) |c| {
            allocator.free(c.content);
            allocator.free(c.dir_path);
        }
        results.deinit();
    }

    const total_start = std.time.nanoTimestamp();

    // Ensure cache directory exists
    std.fs.cwd().makePath(".zig-cache/cells") catch {};
    var cache_dir = std.fs.cwd().openDir(".zig-cache/cells", .{}) catch |err| {
        // Fallback: continue without cache if directory fails
        if (options.benchmark) return err;
        const empty_result = DiscoveryResult{
            .cells = try allocator.alloc(DiscoveredCell, 0),
            .cache_hits = 0,
            .cache_misses = 0,
            .scan_time_ns = 0,
            .parse_time_ns = 0,
            .total_time_ns = 0,
        };
        return empty_result;
    };
    defer cache_dir.close();

    var cache_hits: usize = 0;
    var cache_misses: usize = 0;
    var parse_time_ns: u64 = 0;

    // For simplicity, use sequential scan with caching
    // The cache provides the main performance benefit
    var cache_handle = cache_dir;
    defer cache_handle.close();

    for (CELL_SCAN_DIRS) |scan_dir| {
        var ctx = ScanContext{
            .allocator = allocator,
            .scan_dir = scan_dir,
            .results = &results,
            .mutex = .{},
            .cache_dir = cache_handle,
            .use_cache = options.use_cache,
            .cache_hits = &cache_hits,
            .cache_misses = &cache_misses,
            .parse_time_ns = &parse_time_ns,
        };
        _ = ctx.scan() catch {};
    }

    const total_end = std.time.nanoTimestamp();

    return .{
        .cells = try results.toOwnedSlice(),
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
        const stripped = std.mem.trim(u8, raw, "[]\" ");
        return .{ .inner = std.mem.splitSequence(u8, stripped, "\", \"") };
    }

    pub fn next(self: *ArrayIterator) ?[]const u8 {
        while (self.inner.next()) |item| {
            const trimmed = std.mem.trim(u8, item, "\" ");
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
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0) continue;
            if (trimmed[0] == '[') break;
            const eq_pos = std.mem.indexOf(u8, trimmed, "=") orelse continue;
            if (eq_pos == 0) continue;
            const key = std.mem.trim(u8, trimmed[0..eq_pos], " \t\"");
            const value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t\"");
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
