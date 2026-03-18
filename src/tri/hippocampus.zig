// ═══════════════════════════════════════════════════════════════════════════════
// TRI MEMORY — Unified Agent Memory Store (JSONL)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Commands:
//   tri memory list   [--agent mu] [--kind heartbeat] [--limit 20]
//   tri memory read   <id>
//   tri memory write  --agent mu --kind observation --summary "text" [--data '{}'] [--tag build] [--ttl 3600]
//   tri memory search <query> [--limit 20]
//   tri memory gc     [--agent mu] [--dry-run]
//   tri memory stats
//
// Storage: .trinity/memory/{agent}/current.jsonl (append-only JSONL)
// Archive: .trinity/memory/{agent}/archive/{YYYY-MM}.jsonl (after 1MB rotation)
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const agent_roles = @import("agent_roles.zig");

const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const DIM = "\x1b[2m";
const MAGENTA = "\x1b[35m";
const WHITE = "\x1b[37m";

const MEMORY_ROOT = ".trinity/memory";
const MAX_FILE_SIZE: usize = 1024 * 1024; // 1MB rotation threshold
const AUTO_GC_INTERVAL: usize = 1000; // GC every N writes

// ═══════════════════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

pub const MemoryKind = enum {
    heartbeat,
    learning,
    episode,
    rule,
    @"error",
    observation,
    cellhealth, // C1: Cell health events for organism learning

    pub fn toString(self: MemoryKind) []const u8 {
        return switch (self) {
            .heartbeat => "heartbeat",
            .learning => "learning",
            .episode => "episode",
            .rule => "rule",
            .@"error" => "error",
            .observation => "observation",
            .cellhealth => "cellhealth",
        };
    }

    pub fn fromString(s: []const u8) ?MemoryKind {
        if (std.mem.eql(u8, s, "heartbeat")) return .heartbeat;
        if (std.mem.eql(u8, s, "learning")) return .learning;
        if (std.mem.eql(u8, s, "episode")) return .episode;
        if (std.mem.eql(u8, s, "rule")) return .rule;
        if (std.mem.eql(u8, s, "error")) return .@"error";
        if (std.mem.eql(u8, s, "observation")) return .observation;
        if (std.mem.eql(u8, s, "cellhealth")) return .cellhealth;
        return null;
    }

    pub fn defaultTtl(self: MemoryKind) u64 {
        return switch (self) {
            .heartbeat => 7 * 24 * 3600, // 7 days
            .episode => 30 * 24 * 3600, // 30 days
            .learning, .rule => 0, // permanent
            .@"error" => 14 * 24 * 3600, // 14 days
            .observation => 30 * 24 * 3600, // 30 days
            .cellhealth => 90 * 24 * 3600, // 90 days - longer retention for health trends
        };
    }
};

/// Fixed-buffer memory record — used for write path (~2.5KB on stack)
pub const MemoryRecord = struct {
    id_buf: [64]u8 = undefined,
    id_len: u8 = 0,
    agent_buf: [32]u8 = undefined,
    agent_len: u8 = 0,
    kind: MemoryKind = .observation,
    ts: u64 = 0,
    tags: [8][32]u8 = undefined,
    tag_lens: [8]u8 = .{ 0, 0, 0, 0, 0, 0, 0, 0 },
    tag_count: u8 = 0,
    ttl: u64 = 0,
    data_buf: [2048]u8 = undefined,
    data_len: u16 = 0,
    summary_buf: [256]u8 = undefined,
    summary_len: u16 = 0,

    pub fn agent(self: *const MemoryRecord) []const u8 {
        return self.agent_buf[0..self.agent_len];
    }

    pub fn summary(self: *const MemoryRecord) []const u8 {
        return self.summary_buf[0..self.summary_len];
    }

    pub fn data(self: *const MemoryRecord) []const u8 {
        return self.data_buf[0..self.data_len];
    }

    pub fn id(self: *const MemoryRecord) []const u8 {
        return self.id_buf[0..self.id_len];
    }

    pub fn getTag(self: *const MemoryRecord, idx: usize) []const u8 {
        if (idx >= self.tag_count) return "";
        return self.tags[idx][0..self.tag_lens[idx]];
    }

    pub fn isExpired(self: *const MemoryRecord, now_ts: u64) bool {
        if (self.ttl == 0) return false; // permanent
        return now_ts > self.ts + self.ttl;
    }
};

pub fn copyToFixed(comptime N: usize, dest: *[N]u8, len_ptr: anytype, src: []const u8) void {
    const copy_len = @min(src.len, N);
    @memcpy(dest[0..copy_len], src[0..copy_len]);
    len_ptr.* = @intCast(copy_len);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CORE API
// ═══════════════════════════════════════════════════════════════════════════════

/// In-memory write counter for auto-GC (resets on process restart — acceptable)
var gc_write_counter: u32 = 0;

/// Write a memory record to the agent's current.jsonl
pub fn write(allocator: Allocator, record: *const MemoryRecord) !void {
    const agent_name = record.agent();
    if (agent_name.len == 0) return error.EmptyAgent;

    // Ensure directory exists
    const dir_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ MEMORY_ROOT, agent_name });
    defer allocator.free(dir_path);
    std.fs.cwd().makePath(dir_path) catch {};

    const file_path = try std.fmt.allocPrint(allocator, "{s}/{s}/current.jsonl", .{ MEMORY_ROOT, agent_name });
    defer allocator.free(file_path);

    // Serialize record to JSON line
    var buf: [4096]u8 = undefined;
    const json_line = try serializeRecord(&buf, record);

    // Append to file
    const file = try std.fs.cwd().createFile(file_path, .{ .truncate = false });
    defer file.close();
    try file.seekFromEnd(0);
    try file.writeAll(json_line);
    try file.writeAll("\n");

    // Check file size for rotation
    const stat = try file.stat();
    if (stat.size > MAX_FILE_SIZE) {
        rotateFile(allocator, agent_name) catch {};
    }

    // Auto-GC: run gc every AUTO_GC_INTERVAL writes
    gc_write_counter += 1;
    if (gc_write_counter % AUTO_GC_INTERVAL == 0) {
        _ = gc(allocator, null) catch {};
    }
}

pub const ReadOptions = struct {
    agent: ?[]const u8 = null, // null = scan all agents
    kind: ?MemoryKind = null,
    tag_filter: ?[]const u8 = null,
    since_ts: u64 = 0,
    limit: u32 = 100,
};

/// Read memory records matching the given options
pub fn read(allocator: Allocator, opts: ReadOptions) !std.ArrayList(MemoryRecord) {
    var results: std.ArrayList(MemoryRecord) = .{};

    if (opts.agent) |agent_name| {
        // Read from specific agent
        try readAgentRecords(allocator, agent_name, opts, &results);
    } else {
        // Scan all agent directories
        var dir = std.fs.cwd().openDir(MEMORY_ROOT, .{ .iterate = true }) catch return results;
        defer dir.close();

        var dir_iter = dir.iterate();
        while (try dir_iter.next()) |entry| {
            if (entry.kind != .directory) continue;
            try readAgentRecords(allocator, entry.name, opts, &results);
        }
    }

    // Sort by timestamp descending (newest first)
    std.mem.sort(MemoryRecord, results.items, {}, struct {
        fn lessThan(_: void, a: MemoryRecord, b: MemoryRecord) bool {
            return a.ts > b.ts;
        }
    }.lessThan);

    // Apply limit
    if (results.items.len > opts.limit) {
        results.shrinkRetainingCapacity(opts.limit);
    }

    return results;
}

/// Search memory records by keyword matching in summary and data
pub fn search(allocator: Allocator, query: []const u8, limit: u32) !std.ArrayList(MemoryRecord) {
    // Split query into words
    var words_buf: [16][]const u8 = undefined;
    var word_count: usize = 0;
    var iter = std.mem.splitScalar(u8, query, ' ');
    while (iter.next()) |w| {
        if (w.len > 0 and word_count < 16) {
            words_buf[word_count] = w;
            word_count += 1;
        }
    }
    const words = words_buf[0..word_count];
    if (word_count == 0) {
        const empty: std.ArrayList(MemoryRecord) = .{};
        return empty;
    }

    // Read all records
    var all = try read(allocator, .{ .limit = 10000 });
    defer all.deinit(allocator);

    var results: std.ArrayList(MemoryRecord) = .{};

    for (all.items) |rec| {
        var score: u32 = 0;
        for (words) |word| {
            if (containsIgnoreCase(rec.summary(), word)) score += 2;
            if (containsIgnoreCase(rec.data(), word)) score += 1;
            // Check tags
            var ti: u8 = 0;
            while (ti < rec.tag_count) : (ti += 1) {
                if (containsIgnoreCase(rec.getTag(ti), word)) score += 3;
            }
        }
        if (score > 0) {
            try results.append(allocator, rec);
        }
    }

    // Apply limit
    if (results.items.len > limit) {
        results.shrinkRetainingCapacity(limit);
    }

    return results;
}

pub const GcResult = struct {
    scanned: u32 = 0,
    removed: u32 = 0,
    kept: u32 = 0,
};

/// Garbage collect expired records
pub fn gc(allocator: Allocator, agent_filter: ?[]const u8) !GcResult {
    var result = GcResult{};
    const now_ts: u64 = @intCast(std.time.timestamp());

    if (agent_filter) |agent_name| {
        try gcAgent(allocator, agent_name, now_ts, &result);
    } else {
        var dir = std.fs.cwd().openDir(MEMORY_ROOT, .{ .iterate = true }) catch return result;
        defer dir.close();

        var dir_iter = dir.iterate();
        while (try dir_iter.next()) |entry| {
            if (entry.kind != .directory) continue;
            try gcAgent(allocator, entry.name, now_ts, &result);
        }
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONVENIENCE FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn writeHeartbeat(allocator: Allocator, agent_name: []const u8, data_json: []const u8) !void {
    var record = MemoryRecord{};
    const ts: u64 = @intCast(std.time.timestamp());
    generateId(&record.id_buf, &record.id_len, ts, agent_name);
    copyToFixed(32, &record.agent_buf, &record.agent_len, agent_name);
    record.kind = .heartbeat;
    record.ts = ts;
    record.ttl = MemoryKind.heartbeat.defaultTtl();
    copyToFixed(2048, &record.data_buf, &record.data_len, data_json);

    const summary_text = try std.fmt.allocPrint(allocator, "{s} heartbeat", .{agent_name});
    defer allocator.free(summary_text);
    copyToFixed(256, &record.summary_buf, &record.summary_len, summary_text);

    try write(allocator, &record);
}

pub fn writeLearning(allocator: Allocator, agent_name: []const u8, summary_text: []const u8, data_json: []const u8) !void {
    var record = MemoryRecord{};
    const ts: u64 = @intCast(std.time.timestamp());
    generateId(&record.id_buf, &record.id_len, ts, agent_name);
    copyToFixed(32, &record.agent_buf, &record.agent_len, agent_name);
    record.kind = .learning;
    record.ts = ts;
    record.ttl = 0; // permanent
    copyToFixed(2048, &record.data_buf, &record.data_len, data_json);
    copyToFixed(256, &record.summary_buf, &record.summary_len, summary_text);

    try write(allocator, &record);
}

pub fn writeEpisode(allocator: Allocator, agent_name: []const u8, summary_text: []const u8, data_json: []const u8) !void {
    var record = MemoryRecord{};
    const ts: u64 = @intCast(std.time.timestamp());
    generateId(&record.id_buf, &record.id_len, ts, agent_name);
    copyToFixed(32, &record.agent_buf, &record.agent_len, agent_name);
    record.kind = .episode;
    record.ts = ts;
    record.ttl = MemoryKind.episode.defaultTtl();
    copyToFixed(2048, &record.data_buf, &record.data_len, data_json);
    copyToFixed(256, &record.summary_buf, &record.summary_len, summary_text);

    try write(allocator, &record);
}

pub fn writeError(allocator: Allocator, agent_name: []const u8, summary_text: []const u8, data_json: []const u8) !void {
    var record = MemoryRecord{};
    const ts: u64 = @intCast(std.time.timestamp());
    generateId(&record.id_buf, &record.id_len, ts, agent_name);
    copyToFixed(32, &record.agent_buf, &record.agent_len, agent_name);
    record.kind = .@"error";
    record.ts = ts;
    record.ttl = MemoryKind.@"error".defaultTtl();
    copyToFixed(2048, &record.data_buf, &record.data_len, data_json);
    copyToFixed(256, &record.summary_buf, &record.summary_len, summary_text);

    try write(allocator, &record);
}

pub fn writeObservation(allocator: Allocator, agent_name: []const u8, summary_text: []const u8, data_json: []const u8) !void {
    var record = MemoryRecord{};
    const ts: u64 = @intCast(std.time.timestamp());
    generateId(&record.id_buf, &record.id_len, ts, agent_name);
    copyToFixed(32, &record.agent_buf, &record.agent_len, agent_name);
    record.kind = .observation;
    record.ts = ts;
    record.ttl = MemoryKind.observation.defaultTtl();
    copyToFixed(2048, &record.data_buf, &record.data_len, data_json);
    copyToFixed(256, &record.summary_buf, &record.summary_len, summary_text);

    try write(allocator, &record);
}

// ═══════════════════════════════════════════════════════════════════════════════
// C1: CELL HEALTH EVENTS — Wave 3 Dual-Write (Cytoplasm → Hippocampus)
// ═══════════════════════════════════════════════════════════════════════════════

/// Cell health event data — stored in hippocampus for learning patterns
pub const CellHealthData = struct {
    cell_id: []const u8,
    cell_name: []const u8,
    health_score: u8, // 0-100
    health_delta: i8, // change from previous scan
    bio_system: []const u8, // dna, brain, immune, regen, body
    trigger: []const u8, // "scan", "fix", "regenerate", "manual"
    files_total: u32,
    files_generated: u32,
    files_manual: u32,
    tests_passing: bool,
};

/// Write cell health event to hippocampus (called by cytoplasm.runHealth)
/// Agent name: "cytoplasm" — all cell health events come from cell scanner
pub fn writeCellHealth(allocator: Allocator, cell_data: CellHealthData) !void {
    // Build JSON data payload
    var data_buffer: [1024]u8 = undefined;
    const data_json = try std.fmt.bufPrint(&data_buffer,
        \\{{"cell_id":"{s}","cell_name":"{s}","health":{d},"delta":{d},"bio_system":"{s}","trigger":"{s}","files":{{"total":{d},"generated":{d},"manual":{d}}},"tests_passing":{s}}}
    , .{
        cell_data.cell_id,
        cell_data.cell_name,
        cell_data.health_score,
        cell_data.health_delta,
        cell_data.bio_system,
        cell_data.trigger,
        cell_data.files_total,
        cell_data.files_generated,
        cell_data.files_manual,
        if (cell_data.tests_passing) "true" else "false",
    });

    // Build summary text
    var summary_buffer: [128]u8 = undefined;
    const summary = try std.fmt.bufPrint(&summary_buffer, "{s} health: {d} ({s}) {d} files", .{ cell_data.cell_name, cell_data.health_score, cell_data.bio_system, cell_data.files_total });

    // Create and write record
    var record = MemoryRecord{};
    const ts: u64 = @intCast(std.time.timestamp());
    generateId(&record.id_buf, &record.id_len, ts, "cytoplasm");
    copyToFixed(32, &record.agent_buf, &record.agent_len, "cytoplasm");
    record.kind = .cellhealth;
    record.ts = ts;
    record.ttl = MemoryKind.cellhealth.defaultTtl(); // 90 days

    // Add tag for bio_system filtering
    const tag = try std.fmt.allocPrint(allocator, "bio:{s}", .{cell_data.bio_system});
    defer allocator.free(tag);
    copyToFixed(32, &record.tags[0], &record.tag_lens[0], tag);
    record.tag_count = 1;

    copyToFixed(2048, &record.data_buf, &record.data_len, data_json);
    copyToFixed(256, &record.summary_buf, &record.summary_len, summary);

    try write(allocator, &record);
}

/// Query cell health history for a specific cell
pub fn getCellHistory(allocator: Allocator, cell_id: []const u8, days: u32) !std.ArrayList(MemoryRecord) {
    const now = std.time.timestamp();
    const since_ts: u64 = @intCast(now - (@as(u64, days) * 24 * 3600));

    var records = try read(allocator, .{
        .kind = .cellhealth,
        .since_ts = since_ts,
        .agent = "cytoplasm",
    });

    // Filter by cell_id (done in-memory since data_json contains cell_id)
    var filtered = std.ArrayList(MemoryRecord).init(allocator);
    for (records.items) |rec| {
        const data_slice = rec.data_buf[0..rec.data_len];
        if (std.mem.indexOf(u8, data_slice, cell_id) != null) {
            try filtered.append(rec);
        }
    }
    records.deinit();

    return filtered;
}

/// Parsed cell health data from a memory record
pub const ParsedCellHealth = struct {
    cell_id: []const u8,
    cell_name: []const u8,
    health_score: u8,
    health_delta: i8,
    bio_system: []const u8,
    trigger: []const u8,
    files_total: u32,
    files_generated: u32,
    files_manual: u32,
    tests_passing: bool,
    ts: u64,

    /// Parse cell health from JSON data in memory record
    pub fn fromRecord(rec: *const MemoryRecord) !ParsedCellHealth {
        // Parse the JSON data string
        // Format: {"cell_id":"...","cell_name":"...","health":...,"delta":...,"bio_system":"...","trigger":"...","files":{"total":...,"generated":...,"manual":...},"tests_passing":...}
        const data = rec.data_buf[0..rec.data_len];

        var self: ParsedCellHealth = undefined;

        // Simple parsing - extract values using string search (no full JSON parser needed)
        // cell_id
        if (std.mem.indexOf(u8, data, "\"cell_id\":\"")) |start| {
            const val_start = start + 11;
            const val_end = std.mem.indexOf(u8, data[val_start..], "\"") orelse return error.ParseError;
            self.cell_id = data[val_start .. val_start + val_end];
        } else return error.ParseError;

        // cell_name
        if (std.mem.indexOf(u8, data, "\"cell_name\":\"")) |start| {
            const val_start = start + 13;
            const val_end = std.mem.indexOf(u8, data[val_start..], "\"") orelse return error.ParseError;
            self.cell_name = data[val_start .. val_start + val_end];
        } else return error.ParseError;

        // health
        if (std.mem.indexOf(u8, data, "\"health\":")) |start| {
            const val_start = start + 9;
            const val_end = if (std.mem.indexOf(u8, data[val_start..], ",")) |idx| idx else if (std.mem.indexOf(u8, data[val_start..], "}")) |idx| idx else return error.ParseError;
            self.health_score = try std.fmt.parseInt(u8, data[val_start .. val_start + val_end], 10);
        } else return error.ParseError;

        // delta
        if (std.mem.indexOf(u8, data, "\"delta\":")) |start| {
            const val_start = start + 8;
            const val_end = if (std.mem.indexOf(u8, data[val_start..], ",")) |idx| idx else if (std.mem.indexOf(u8, data[val_start..], "}")) |idx| idx else return error.ParseError;
            self.health_delta = try std.fmt.parseInt(i8, data[val_start .. val_start + val_end], 10);
        } else return error.ParseError;

        // bio_system
        if (std.mem.indexOf(u8, data, "\"bio_system\":\"")) |start| {
            const val_start = start + 14;
            const val_end = std.mem.indexOf(u8, data[val_start..], "\"") orelse return error.ParseError;
            self.bio_system = data[val_start .. val_start + val_end];
        } else return error.ParseError;

        // trigger
        if (std.mem.indexOf(u8, data, "\"trigger\":\"")) |start| {
            const val_start = start + 11;
            const val_end = std.mem.indexOf(u8, data[val_start..], "\"") orelse return error.ParseError;
            self.trigger = data[val_start .. val_start + val_end];
        } else return error.ParseError;

        // files.total
        if (std.mem.indexOf(u8, data, "\"files\":{\"total\":")) |start| {
            const val_start = start + 18;
            const val_end = std.mem.indexOf(u8, data[val_start..], ",") orelse return error.ParseError;
            self.files_total = try std.fmt.parseInt(u32, data[val_start .. val_start + val_end], 10);
        } else return error.ParseError;

        // tests_passing
        if (std.mem.indexOf(u8, data, "\"tests_passing\":")) |start| {
            const val_start = start + 16;
            self.tests_passing = std.mem.eql(u8, data[val_start .. val_start + 4], "true");
        } else return error.ParseError;

        self.ts = rec.ts;

        return self;
    }
};

/// Get all cell health records within the given time period
/// Returns records sorted by timestamp (newest first)
pub fn getAllCellHealth(allocator: Allocator, days: u32) !std.ArrayList(MemoryRecord) {
    const now: i64 = std.time.timestamp();
    const seconds_back: i64 = @as(i64, days) * 24 * 3600;
    const since_ts: u64 = @intCast(@max(0, now - seconds_back));

    return read(allocator, .{
        .kind = .cellhealth,
        .since_ts = since_ts,
        .agent = "cytoplasm",
        .limit = 100000, // Large limit to get all records
    });
}

pub fn writeRule(allocator: Allocator, agent_name: []const u8, summary_text: []const u8, data_json: []const u8) !void {
    var record = MemoryRecord{};
    const ts: u64 = @intCast(std.time.timestamp());
    generateId(&record.id_buf, &record.id_len, ts, agent_name);
    copyToFixed(32, &record.agent_buf, &record.agent_len, agent_name);
    record.kind = .rule;
    record.ts = ts;
    record.ttl = 0; // permanent
    copyToFixed(2048, &record.data_buf, &record.data_len, data_json);
    copyToFixed(256, &record.summary_buf, &record.summary_len, summary_text);

    try write(allocator, &record);
}

pub fn latestHeartbeat(allocator: Allocator, agent_name: []const u8) !?MemoryRecord {
    var results = try read(allocator, .{
        .agent = agent_name,
        .kind = .heartbeat,
        .limit = 1,
    });
    defer results.deinit(allocator);

    if (results.items.len > 0) {
        return results.items[0];
    }
    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTERNAL HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn generateId(id_buf: *[64]u8, id_len: *u8, ts: u64, agent_name: []const u8) void {
    // Simple hash from agent name
    var hash: u32 = 0;
    for (agent_name) |c| {
        hash = hash *% 31 +% c;
    }
    hash ^= @truncate(ts);

    const result = std.fmt.bufPrint(id_buf, "mem_{d}_{s}_{x:0>8}", .{ ts, agent_name, hash }) catch {
        id_len.* = 0;
        return;
    };
    id_len.* = @intCast(result.len);
}

fn serializeRecord(buf: *[4096]u8, rec: *const MemoryRecord) ![]const u8 {
    var stream = std.io.fixedBufferStream(buf);
    const w = stream.writer();

    try w.writeAll("{\"id\":\"");
    try w.writeAll(rec.id());
    try w.writeAll("\",\"agent\":\"");
    try w.writeAll(rec.agent());
    try w.writeAll("\",\"kind\":\"");
    try w.writeAll(rec.kind.toString());
    try w.print("\",\"ts\":{d},\"tags\":[", .{rec.ts});

    var ti: u8 = 0;
    while (ti < rec.tag_count) : (ti += 1) {
        if (ti > 0) try w.writeAll(",");
        try w.writeAll("\"");
        try w.writeAll(rec.getTag(ti));
        try w.writeAll("\"");
    }

    try w.print("],\"ttl\":{d},\"data\":", .{rec.ttl});

    // data is raw JSON or empty object
    const data_slice = rec.data();
    if (data_slice.len > 0) {
        try w.writeAll(data_slice);
    } else {
        try w.writeAll("{}");
    }

    try w.writeAll(",\"summary\":\"");
    // Escape summary for JSON
    for (rec.summary()) |c| {
        switch (c) {
            '"' => try w.writeAll("\\\""),
            '\\' => try w.writeAll("\\\\"),
            '\n' => try w.writeAll("\\n"),
            '\r' => try w.writeAll("\\r"),
            '\t' => try w.writeAll("\\t"),
            else => try w.writeByte(c),
        }
    }
    try w.writeAll("\"}");

    return stream.getWritten();
}

fn deserializeRecord(line: []const u8, rec: *MemoryRecord) bool {
    // Minimal JSON parsing — extract fields by scanning
    rec.* = MemoryRecord{};

    // Extract id
    if (extractJsonString(line, "\"id\":\"")) |val| {
        copyToFixed(64, &rec.id_buf, &rec.id_len, val);
    }

    // Extract agent
    if (extractJsonString(line, "\"agent\":\"")) |val| {
        copyToFixed(32, &rec.agent_buf, &rec.agent_len, val);
    } else return false;

    // Extract kind
    if (extractJsonString(line, "\"kind\":\"")) |val| {
        rec.kind = MemoryKind.fromString(val) orelse .observation;
    }

    // Extract ts
    if (extractJsonNumber(line, "\"ts\":")) |val| {
        rec.ts = val;
    }

    // Extract ttl
    if (extractJsonNumber(line, "\"ttl\":")) |val| {
        rec.ttl = val;
    }

    // Extract summary
    if (extractJsonString(line, "\"summary\":\"")) |val| {
        copyToFixed(256, &rec.summary_buf, &rec.summary_len, val);
    }

    // Extract tags (simple: scan for tags array)
    if (std.mem.indexOf(u8, line, "\"tags\":[")) |tags_start| {
        const rest = line[tags_start + 8 ..];
        if (std.mem.indexOf(u8, rest, "]")) |tags_end| {
            const tags_content = rest[0..tags_end];
            var tag_iter = std.mem.splitSequence(u8, tags_content, "\",\"");
            while (tag_iter.next()) |tag_raw| {
                if (rec.tag_count >= 8) break;
                // Strip surrounding quotes
                var tag = tag_raw;
                if (tag.len > 0 and tag[0] == '"') tag = tag[1..];
                if (tag.len > 0 and tag[tag.len - 1] == '"') tag = tag[0 .. tag.len - 1];
                if (tag.len > 0) {
                    copyToFixed(32, &rec.tags[rec.tag_count], &rec.tag_lens[rec.tag_count], tag);
                    rec.tag_count += 1;
                }
            }
        }
    }

    // Extract data (raw JSON between "data": and ,"summary")
    if (std.mem.indexOf(u8, line, "\"data\":")) |data_start| {
        const data_rest = line[data_start + 7 ..];
        if (std.mem.indexOf(u8, data_rest, ",\"summary\"")) |data_end| {
            copyToFixed(2048, &rec.data_buf, &rec.data_len, data_rest[0..data_end]);
        }
    }

    return rec.agent_len > 0;
}

fn extractJsonString(json: []const u8, key: []const u8) ?[]const u8 {
    const start = (std.mem.indexOf(u8, json, key) orelse return null) + key.len;
    const rest = json[start..];
    // Find unescaped closing quote
    var i: usize = 0;
    while (i < rest.len) : (i += 1) {
        if (rest[i] == '\\') {
            i += 1; // skip escaped char
            continue;
        }
        if (rest[i] == '"') return rest[0..i];
    }
    return null;
}

fn extractJsonNumber(json: []const u8, key: []const u8) ?u64 {
    const start = (std.mem.indexOf(u8, json, key) orelse return null) + key.len;
    const rest = json[start..];
    var end: usize = 0;
    while (end < rest.len and rest[end] >= '0' and rest[end] <= '9') : (end += 1) {}
    if (end == 0) return null;
    return std.fmt.parseInt(u64, rest[0..end], 10) catch null;
}

fn readAgentRecords(allocator: Allocator, agent_name: []const u8, opts: ReadOptions, results: *std.ArrayList(MemoryRecord)) !void {
    const file_path = try std.fmt.allocPrint(allocator, "{s}/{s}/current.jsonl", .{ MEMORY_ROOT, agent_name });
    defer allocator.free(file_path);

    const contents = std.fs.cwd().readFileAlloc(allocator, file_path, 8 * 1024 * 1024) catch return;
    defer allocator.free(contents);

    var line_iter = std.mem.splitScalar(u8, contents, '\n');
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;

        var rec = MemoryRecord{};
        if (!deserializeRecord(line, &rec)) continue;

        // Apply filters
        if (opts.kind) |k| {
            if (rec.kind != k) continue;
        }
        if (opts.since_ts > 0 and rec.ts < opts.since_ts) continue;
        if (opts.tag_filter) |tag| {
            var found = false;
            var ti: u8 = 0;
            while (ti < rec.tag_count) : (ti += 1) {
                if (std.mem.eql(u8, rec.getTag(ti), tag)) {
                    found = true;
                    break;
                }
            }
            if (!found) continue;
        }

        try results.append(allocator, rec);
    }
}

fn gcAgent(allocator: Allocator, agent_name: []const u8, now_ts: u64, result: *GcResult) !void {
    const file_path = try std.fmt.allocPrint(allocator, "{s}/{s}/current.jsonl", .{ MEMORY_ROOT, agent_name });
    defer allocator.free(file_path);

    const contents = std.fs.cwd().readFileAlloc(allocator, file_path, 8 * 1024 * 1024) catch return;
    defer allocator.free(contents);

    var kept_lines: std.ArrayList(u8) = .{};
    defer kept_lines.deinit(allocator);

    var line_iter = std.mem.splitScalar(u8, contents, '\n');
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;
        result.scanned += 1;

        var rec = MemoryRecord{};
        if (!deserializeRecord(line, &rec)) {
            result.removed += 1;
            continue;
        }

        if (rec.isExpired(now_ts)) {
            result.removed += 1;
        } else {
            result.kept += 1;
            try kept_lines.appendSlice(allocator, line);
            try kept_lines.append(allocator, '\n');
        }
    }

    // Rewrite file with only kept records
    if (result.removed > 0) {
        const file = try std.fs.cwd().createFile(file_path, .{});
        defer file.close();
        try file.writeAll(kept_lines.items);
    }
}

fn rotateFile(allocator: Allocator, agent_name: []const u8) !void {
    // Move current.jsonl to archive/YYYY-MM.jsonl
    const archive_dir = try std.fmt.allocPrint(allocator, "{s}/{s}/archive", .{ MEMORY_ROOT, agent_name });
    defer allocator.free(archive_dir);
    std.fs.cwd().makePath(archive_dir) catch {};

    const ts: u64 = @intCast(std.time.timestamp());
    // Simple date: use ts / seconds_per_month approximation
    const days = ts / 86400;
    const approx_year = 1970 + days / 365;
    const approx_month = (days % 365) / 30 + 1;

    const archive_path = try std.fmt.allocPrint(allocator, "{s}/{d}-{d:0>2}.jsonl", .{ archive_dir, approx_year, approx_month });
    defer allocator.free(archive_path);

    const current_path = try std.fmt.allocPrint(allocator, "{s}/{s}/current.jsonl", .{ MEMORY_ROOT, agent_name });
    defer allocator.free(current_path);

    // Append current to archive, then truncate current
    const current_contents = std.fs.cwd().readFileAlloc(allocator, current_path, 8 * 1024 * 1024) catch return;
    defer allocator.free(current_contents);

    const archive_file = try std.fs.cwd().createFile(archive_path, .{ .truncate = false });
    defer archive_file.close();
    try archive_file.seekFromEnd(0);
    try archive_file.writeAll(current_contents);

    // Truncate current
    const trunc_file = try std.fs.cwd().createFile(current_path, .{});
    trunc_file.close();
}

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0 or haystack.len < needle.len) return false;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        var match = true;
        for (0..needle.len) |j| {
            if (toLower(haystack[i + j]) != toLower(needle[j])) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

fn toLower(c: u8) u8 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runMemoryCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "help";

    if (std.mem.eql(u8, subcmd, "list")) {
        return runMemoryList(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "read")) {
        return runMemoryRead(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "write")) {
        return runMemoryWrite(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "search")) {
        return runMemorySearch(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "gc")) {
        return runMemoryGc(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "stats")) {
        return runMemoryStats(allocator);
    } else if (std.mem.eql(u8, subcmd, "dashboard")) {
        return runMemoryDashboard(allocator);
    } else if (std.mem.eql(u8, subcmd, "consolidate")) {
        return runMemoryConsolidate(allocator);
    } else if (std.mem.eql(u8, subcmd, "import")) {
        return runMemoryImport(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help")) {
        printHelp();
    } else {
        print("{s}Unknown memory subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printHelp();
    }
}

fn runMemoryList(allocator: Allocator, args: []const []const u8) !void {
    var opts = ReadOptions{};

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--agent") and i + 1 < args.len) {
            i += 1;
            opts.agent = args[i];
        } else if (std.mem.eql(u8, arg, "--kind") and i + 1 < args.len) {
            i += 1;
            opts.kind = MemoryKind.fromString(args[i]);
        } else if (std.mem.eql(u8, arg, "--limit") and i + 1 < args.len) {
            i += 1;
            opts.limit = std.fmt.parseInt(u32, args[i], 10) catch 100;
        } else if (std.mem.eql(u8, arg, "--tag") and i + 1 < args.len) {
            i += 1;
            opts.tag_filter = args[i];
        }
    }

    var results = try read(allocator, opts);
    defer results.deinit(allocator);

    if (results.items.len == 0) {
        print("{s}No memory records found.{s}\n", .{ YELLOW, RESET });
        return;
    }

    print("\n{s}📝 MEMORY RECORDS{s} ({d} found)\n", .{ BOLD, RESET, results.items.len });
    print("{s}─────────────────────────────────────────────────────{s}\n", .{ DIM, RESET });

    for (results.items) |rec| {
        const kind_color = kindColor(rec.kind);
        print("{s}{s:<12}{s} {s}{s}{s}  {s}{s}{s}\n", .{
            kind_color, rec.kind.toString(), RESET,
            CYAN,       rec.agent(),         RESET,
            WHITE,      rec.summary(),       RESET,
        });
    }
    print("\n", .{});
}

fn runMemoryRead(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        print("{s}Usage: tri memory read <id>{s}\n", .{ RED, RESET });
        return;
    }
    const target_id = args[0];

    var results = try read(allocator, .{ .limit = 10000 });
    defer results.deinit(allocator);

    for (results.items) |rec| {
        if (std.mem.eql(u8, rec.id(), target_id)) {
            print("\n{s}📋 MEMORY RECORD{s}\n", .{ BOLD, RESET });
            print("  {s}ID:{s}      {s}\n", .{ DIM, RESET, rec.id() });
            print("  {s}Agent:{s}   {s}{s}{s}\n", .{ DIM, RESET, CYAN, rec.agent(), RESET });
            print("  {s}Kind:{s}    {s}{s}{s}\n", .{ DIM, RESET, kindColor(rec.kind), rec.kind.toString(), RESET });
            print("  {s}TS:{s}      {d}\n", .{ DIM, RESET, rec.ts });
            print("  {s}TTL:{s}     {d}s\n", .{ DIM, RESET, rec.ttl });
            print("  {s}Summary:{s} {s}\n", .{ DIM, RESET, rec.summary() });
            print("  {s}Data:{s}    {s}\n", .{ DIM, RESET, rec.data() });
            // Tags
            if (rec.tag_count > 0) {
                print("  {s}Tags:{s}    ", .{ DIM, RESET });
                var ti: u8 = 0;
                while (ti < rec.tag_count) : (ti += 1) {
                    if (ti > 0) print(", ", .{});
                    print("{s}{s}{s}", .{ MAGENTA, rec.getTag(ti), RESET });
                }
                print("\n", .{});
            }
            print("\n", .{});
            return;
        }
    }

    print("{s}Record not found: {s}{s}\n", .{ RED, target_id, RESET });
}

fn runMemoryWrite(allocator: Allocator, args: []const []const u8) !void {
    var record = MemoryRecord{};
    const ts: u64 = @intCast(std.time.timestamp());
    record.ts = ts;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--agent") and i + 1 < args.len) {
            i += 1;
            copyToFixed(32, &record.agent_buf, &record.agent_len, args[i]);
        } else if (std.mem.eql(u8, arg, "--kind") and i + 1 < args.len) {
            i += 1;
            record.kind = MemoryKind.fromString(args[i]) orelse .observation;
        } else if (std.mem.eql(u8, arg, "--summary") and i + 1 < args.len) {
            i += 1;
            copyToFixed(256, &record.summary_buf, &record.summary_len, args[i]);
        } else if (std.mem.eql(u8, arg, "--data") and i + 1 < args.len) {
            i += 1;
            copyToFixed(2048, &record.data_buf, &record.data_len, args[i]);
        } else if (std.mem.eql(u8, arg, "--tag") and i + 1 < args.len) {
            i += 1;
            if (record.tag_count < 8) {
                copyToFixed(32, &record.tags[record.tag_count], &record.tag_lens[record.tag_count], args[i]);
                record.tag_count += 1;
            }
        } else if (std.mem.eql(u8, arg, "--ttl") and i + 1 < args.len) {
            i += 1;
            record.ttl = std.fmt.parseInt(u64, args[i], 10) catch 0;
        }
    }

    if (record.agent_len == 0) {
        print("{s}Error: --agent is required{s}\n", .{ RED, RESET });
        return;
    }
    if (record.summary_len == 0) {
        print("{s}Error: --summary is required{s}\n", .{ RED, RESET });
        return;
    }

    // Apply default TTL if not specified
    if (record.ttl == 0) {
        record.ttl = record.kind.defaultTtl();
    }

    // Generate ID
    generateId(&record.id_buf, &record.id_len, ts, record.agent());

    try write(allocator, &record);

    print("{s}✅ Memory written{s}\n", .{ GREEN, RESET });
    print("  {s}ID:{s}    {s}\n", .{ DIM, RESET, record.id() });
    print("  {s}Agent:{s} {s}\n", .{ DIM, RESET, record.agent() });
    print("  {s}Kind:{s}  {s}\n", .{ DIM, RESET, record.kind.toString() });
    print("\n", .{});
}

fn runMemorySearch(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        print("{s}Usage: tri memory search <query> [--limit 20]{s}\n", .{ RED, RESET });
        return;
    }

    const query = args[0];
    var limit: u32 = 20;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--limit") and i + 1 < args.len) {
            i += 1;
            limit = std.fmt.parseInt(u32, args[i], 10) catch 20;
        }
    }

    var results = try search(allocator, query, limit);
    defer results.deinit(allocator);

    if (results.items.len == 0) {
        print("{s}No matches found for: \"{s}\"{s}\n", .{ YELLOW, args[0], RESET });
        return;
    }

    print("\n{s}🔍 SEARCH RESULTS{s} ({d} matches for \"{s}\")\n", .{ BOLD, RESET, results.items.len, args[0] });
    print("{s}─────────────────────────────────────────────────────{s}\n", .{ DIM, RESET });

    for (results.items) |rec| {
        const kind_color = kindColor(rec.kind);
        print("{s}{s:<12}{s} {s}{s}{s}  {s}{s}{s}\n", .{
            kind_color, rec.kind.toString(), RESET,
            CYAN,       rec.agent(),         RESET,
            WHITE,      rec.summary(),       RESET,
        });
    }
    print("\n", .{});
}

fn runMemoryGc(allocator: Allocator, args: []const []const u8) !void {
    var agent_filter: ?[]const u8 = null;
    var dry_run = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--agent") and i + 1 < args.len) {
            i += 1;
            agent_filter = args[i];
        } else if (std.mem.eql(u8, args[i], "--dry-run")) {
            dry_run = true;
        }
    }

    if (dry_run) {
        // Just count expired records
        const now_ts: u64 = @intCast(std.time.timestamp());
        var result = GcResult{};

        var all = try read(allocator, .{ .agent = agent_filter, .limit = 100000 });
        defer all.deinit(allocator);

        for (all.items) |rec| {
            result.scanned += 1;
            if (rec.isExpired(now_ts)) {
                result.removed += 1;
            } else {
                result.kept += 1;
            }
        }

        print("\n{s}🗑️  GC DRY RUN{s}\n", .{ BOLD, RESET });
        print("  Scanned: {d}\n", .{result.scanned});
        print("  {s}Would remove: {d}{s}\n", .{ YELLOW, result.removed, RESET });
        print("  Would keep:   {d}\n", .{result.kept});
        print("\n", .{});
    } else {
        const result = try gc(allocator, agent_filter);

        print("\n{s}🗑️  GC COMPLETE{s}\n", .{ BOLD, RESET });
        print("  Scanned: {d}\n", .{result.scanned});
        print("  {s}Removed: {d}{s}\n", .{ RED, result.removed, RESET });
        print("  {s}Kept:    {d}{s}\n", .{ GREEN, result.kept, RESET });
        print("\n", .{});
    }
}

fn runMemoryStats(allocator: Allocator) !void {
    var dir = std.fs.cwd().openDir(MEMORY_ROOT, .{ .iterate = true }) catch {
        print("{s}No memory store found at {s}{s}\n", .{ YELLOW, MEMORY_ROOT, RESET });
        return;
    };
    defer dir.close();

    print("\n{s}📊 MEMORY STATS{s}\n", .{ BOLD, RESET });
    print("{s}─────────────────────────────────────────────────────{s}\n", .{ DIM, RESET });

    var total_records: u32 = 0;
    var total_size: u64 = 0;

    var dir_iter = dir.iterate();
    while (try dir_iter.next()) |entry| {
        if (entry.kind != .directory) continue;

        const file_path = try std.fmt.allocPrint(allocator, "{s}/current.jsonl", .{entry.name});
        defer allocator.free(file_path);

        const stat = dir.statFile(file_path) catch continue;
        const size = stat.size;

        // Count lines
        const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}/current.jsonl", .{ MEMORY_ROOT, entry.name });
        defer allocator.free(full_path);
        const contents = std.fs.cwd().readFileAlloc(allocator, full_path, 8 * 1024 * 1024) catch continue;
        defer allocator.free(contents);

        var lines: u32 = 0;
        var line_iter = std.mem.splitScalar(u8, contents, '\n');
        while (line_iter.next()) |line| {
            if (line.len > 0) lines += 1;
        }

        total_records += lines;
        total_size += size;

        print("  {s}{s:<20}{s}  {d:>5} records  {d:>8} bytes\n", .{
            CYAN, entry.name, RESET, lines, size,
        });
    }

    print("{s}─────────────────────────────────────────────────────{s}\n", .{ DIM, RESET });
    print("  {s}TOTAL:{s}               {d:>5} records  {d:>8} bytes\n", .{ BOLD, RESET, total_records, total_size });
    print("\n", .{});
}

fn runMemoryDashboard(allocator: Allocator) !void {
    print("\n{s}🧠 HIPPOCAMPUS DASHBOARD{s}\n", .{ BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });

    // Collect per-agent stats
    var dir = std.fs.cwd().openDir(MEMORY_ROOT, .{ .iterate = true }) catch {
        print("{s}No memory store found at {s}{s}\n", .{ YELLOW, MEMORY_ROOT, RESET });
        return;
    };
    defer dir.close();

    const now_ts: u64 = @intCast(std.time.timestamp());

    print("\n{s}  Agent         ROLE     Records   Last Active{s}\n", .{ BOLD, RESET });
    print("{s}  ─────────────────────────────────────────────{s}\n", .{ DIM, RESET });

    var total_records: u32 = 0;
    var dir_iter = dir.iterate();
    while (try dir_iter.next()) |entry| {
        if (entry.kind != .directory) continue;

        var agent_results = try read(allocator, .{ .agent = entry.name, .limit = 10000 });
        defer agent_results.deinit(allocator);

        const count: u32 = @intCast(agent_results.items.len);
        total_records += count;

        // Find most recent timestamp
        var last_ts: u64 = 0;
        for (agent_results.items) |rec| {
            if (rec.ts > last_ts) last_ts = rec.ts;
        }

        var age_buf: [16]u8 = undefined;
        const age_str = if (last_ts > 0) blk: {
            const age_s = if (now_ts > last_ts) now_ts - last_ts else 0;
            if (age_s < 60) break :blk std.fmt.bufPrint(&age_buf, "{d}s ago", .{age_s}) catch "?";
            if (age_s < 3600) break :blk std.fmt.bufPrint(&age_buf, "{d}m ago", .{age_s / 60}) catch "?";
            if (age_s < 86400) break :blk std.fmt.bufPrint(&age_buf, "{d}h ago", .{age_s / 3600}) catch "?";
            break :blk std.fmt.bufPrint(&age_buf, "{d}d ago", .{age_s / 86400}) catch "?";
        } else "never";

        const role = agent_roles.agentToRole(entry.name);
        const role_sym = agent_roles.roleSymbol(role);
        print("  {s}{s:<20}{s} {s} {d:>5}     {s}\n", .{
            CYAN,     entry.name, RESET,
            role_sym, count,      age_str,
        });
    }

    print("{s}  ─────────────────────────────────────────────{s}\n", .{ DIM, RESET });
    print("  {s}TOTAL:{s}               {d:>5}\n", .{ BOLD, RESET, total_records });

    // Recent learnings
    var learnings = try read(allocator, .{ .kind = .learning, .limit = 3 });
    defer learnings.deinit(allocator);
    if (learnings.items.len > 0) {
        print("\n{s}  Recent Learnings:{s}\n", .{ BOLD, RESET });
        for (learnings.items) |rec| {
            print("    {s}•{s} {s} {s}({s}){s}\n", .{ GREEN, RESET, rec.summary(), DIM, rec.agent(), RESET });
        }
    }

    // Recent errors
    var errors = try read(allocator, .{ .kind = .@"error", .limit = 3 });
    defer errors.deinit(allocator);
    if (errors.items.len > 0) {
        print("\n{s}  Recent Errors:{s}\n", .{ BOLD, RESET });
        for (errors.items) |rec| {
            print("    {s}•{s} {s} {s}({s}){s}\n", .{ RED, RESET, rec.summary(), DIM, rec.agent(), RESET });
        }
    }

    print("\n", .{});
}

fn runMemoryConsolidate(allocator: Allocator) !void {
    print("\n{s}🧠 HIPPOCAMPUS CONSOLIDATION{s}\n", .{ BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    const now_ts: u64 = @intCast(std.time.timestamp());
    const week_ago = now_ts -| (7 * 24 * 3600);

    // Read all episodes older than 7 days
    var all_episodes = try read(allocator, .{ .kind = .episode, .limit = 10000 });
    defer all_episodes.deinit(allocator);

    // Group old episodes by agent
    const AgentStats = struct {
        name: [32]u8 = undefined,
        name_len: u8 = 0,
        count: u32 = 0,
    };
    var agent_stats: [32]AgentStats = undefined;
    var agent_count: usize = 0;

    var old_count: u32 = 0;
    for (all_episodes.items) |rec| {
        if (rec.ts >= week_ago) continue; // skip recent
        old_count += 1;

        // Find or create agent entry
        var found = false;
        for (agent_stats[0..agent_count]) |*stat| {
            if (std.mem.eql(u8, stat.name[0..stat.name_len], rec.agent())) {
                stat.count += 1;
                found = true;
                break;
            }
        }
        if (!found and agent_count < 32) {
            agent_stats[agent_count] = .{};
            copyToFixed(32, &agent_stats[agent_count].name, &agent_stats[agent_count].name_len, rec.agent());
            agent_stats[agent_count].count = 1;
            agent_count += 1;
        }
    }

    if (old_count == 0) {
        print("  {s}No episodes older than 7 days to consolidate.{s}\n\n", .{ YELLOW, RESET });
        return;
    }

    // Generate summary rules for each agent
    var rules_created: u32 = 0;
    for (agent_stats[0..agent_count]) |stat| {
        var summary_buf: [256]u8 = undefined;
        const agent_name = stat.name[0..stat.name_len];
        const rule_summary = std.fmt.bufPrint(&summary_buf, "Weekly consolidation: {s} had {d} episodes", .{
            agent_name, stat.count,
        }) catch continue;

        var data_buf2: [512]u8 = undefined;
        const rule_data = std.fmt.bufPrint(&data_buf2, "{{\"agent\":\"{s}\",\"episode_count\":{d},\"period\":\"week\",\"consolidated_at\":{d}}}", .{
            agent_name, stat.count, now_ts,
        }) catch continue;

        writeRule(allocator, "consolidation", rule_summary, rule_data) catch continue;
        rules_created += 1;
        print("  {s}✅{s} {s}: {d} episodes → rule\n", .{ GREEN, RESET, agent_name, stat.count });
    }

    print("\n  {s}Consolidated:{s} {d} old episodes → {d} rules\n", .{ BOLD, RESET, old_count, rules_created });
    print("  {s}Note: Old episodes will be cleaned up by GC when TTL expires.{s}\n\n", .{ DIM, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// MEMORY IMPORT — Corpus Callosum: external memory → hippocampus (Wave 4)
// ═══════════════════════════════════════════════════════════════════════════════

fn runMemoryImport(allocator: Allocator, args: []const []const u8) !void {
    var source: []const u8 = "arena";

    // Parse --source flag
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--source") and i + 1 < args.len) {
            source = args[i + 1];
            i += 1;
        }
    }

    if (std.mem.eql(u8, source, "arena")) {
        return importArenaBattles(allocator);
    }

    print("{s}Unknown source: {s}{s}\n", .{ RED, source, RESET });
    print("Available sources: arena\n", .{});
}

/// Import arena battle results as hippocampus episodes (Corpus Callosum bridge)
fn importArenaBattles(allocator: Allocator) !void {
    print("\n{s}🌉 CORPUS CALLOSUM: Arena → Hippocampus{s}\n", .{ BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    // Read arena history from .trinity/arena/history.jsonl
    const history_file = std.fs.cwd().openFile(".trinity/arena/history.jsonl", .{}) catch {
        print("  {s}⚠️  No arena history found.{s}\n", .{ YELLOW, RESET });
        print("  {s}Hint:{s} Run arena battles first to create history.{s}\n\n", .{ DIM, RESET, RESET });
        return;
    };
    defer history_file.close();

    var buf: [1024 * 64]u8 = undefined;
    const content_len = try history_file.readAll(&buf);

    var imported: u32 = 0;
    var skipped: u32 = 0;
    var lines = std.mem.splitScalar(u8, buf[0..content_len], '\n');

    // Track imported records by hash for deduplication
    var imported_hashes = std.StringHashMap(void).init(allocator);
    defer imported_hashes.deinit();

    // Read existing arena episodes to check for duplicates
    var existing = read(allocator, .{
        .agent = "arena",
        .kind = .episode,
        .limit = 1000,
    }) catch |err| {
        if (err != error.FileNotFound) return err;
        return;
    };
    defer existing.deinit(allocator);

    for (existing.items) |rec| {
        const hash = try recordHash(allocator, &rec);
        try imported_hashes.put(hash, {});
    }

    while (lines.next()) |line| {
        if (line.len < 10) continue;

        // Parse JSON line
        const parsed = std.json.parseFromSlice(std.json.Value, allocator, line, .{}) catch continue;
        defer parsed.deinit();

        if (parsed.value != .object) continue;
        const obj = parsed.value.object;

        const winner = getJsonStrObj(obj, "winner");
        const loser = getJsonStrObj(obj, "loser");
        const task_id = getJsonStrObj(obj, "task_id");
        const result = getJsonStrObj(obj, "result"); // "win", "loss", "draw"

        // Create temp record for hash check
        var temp_rec: MemoryRecord = undefined;
        const ts: u64 = @intCast(std.time.timestamp());
        temp_rec.ts = ts;
        copyToFixed(32, &temp_rec.agent_buf, &temp_rec.agent_len, "arena");
        copyToFixed(256, &temp_rec.summary_buf, &temp_rec.summary_len, try std.fmt.allocPrint(allocator, "arena: {s} vs {s} → {s}", .{ winner, loser, result }));

        const hash = try recordHash(allocator, &temp_rec);
        if (imported_hashes.contains(hash)) {
            skipped += 1;
            continue;
        }

        // Write episode to hippocampus
        var summary_buf: [256]u8 = undefined;
        const summary = std.fmt.bufPrint(&summary_buf, "arena battle: {s} vs {s} on {s} → {s}", .{ winner, loser, task_id, result }) catch "arena battle";

        var data_buf: [512]u8 = undefined;
        const data_json = std.fmt.bufPrint(&data_buf, "{{\"winner\":\"{s}\",\"loser\":\"{s}\",\"task_id\":\"{s}\",\"result\":\"{s}\"}}", .{ winner, loser, task_id, result }) catch "{}";

        try writeEpisode(allocator, "arena", summary, data_json);
        try imported_hashes.put(hash, {});
        imported += 1;
    }

    print("  {s}✅{s} Imported {d} arena battles → hippocampus (agent: arena)\n", .{ GREEN, RESET, imported });
    if (skipped > 0) {
        print("  {s}⊙{s} Skipped {d} duplicates\n", .{ DIM, RESET, skipped });
    }
    print("\n", .{});
}

fn getJsonStrObj(obj: std.json.ObjectMap, key: []const u8) []const u8 {
    if (obj.get(key)) |val| {
        if (val == .string) return val.string;
    }
    return "";
}

fn recordHash(allocator: Allocator, rec: *const MemoryRecord) ![]const u8 {
    var hash_buf: [128]u8 = undefined;
    const hash_str = try std.fmt.bufPrint(&hash_buf, "{s}_{d}_{s}", .{ rec.agent(), rec.ts, rec.summary() });
    return allocator.dupe(u8, hash_str);
}

fn kindColor(kind: MemoryKind) []const u8 {
    return switch (kind) {
        .heartbeat => GREEN,
        .learning => CYAN,
        .episode => MAGENTA,
        .rule => YELLOW,
        .@"error" => RED,
        .observation => WHITE,
        .cellhealth => CYAN, // Health events - same as learning
    };
}

fn printHelp() void {
    print(
        \\
        \\{s}TRI MEMORY{s} — Unified Agent Memory Store
        \\
        \\{s}Usage:{s}
        \\  tri memory list        [--agent <name>] [--kind <kind>] [--tag <tag>] [--limit N]
        \\  tri memory read        <id>
        \\  tri memory write       --agent <name> --kind <kind> --summary "text" [--data '{{}}'] [--tag <tag>] [--ttl <sec>]
        \\  tri memory search      <query> [--limit N]
        \\  tri memory gc          [--agent <name>] [--dry-run]
        \\  tri memory stats
        \\  tri memory dashboard   Visual summary of all agents and recent activity
        \\  tri memory consolidate Summarize old episodes into permanent rules
        \\  tri memory import      --source <src>  Import external memory (arena)
        \\
        \\{s}Kinds:{s} heartbeat, learning, episode, rule, error, observation
        \\{s}Agents:{s} mu, scholar, phoenix, queen, oracle, arena, cerebellum, hypothalamus
        \\
        \\{s}Default TTLs:{s}
        \\  heartbeat=7d  episode=30d  error=14d  observation=30d  learning/rule=permanent
        \\
    , .{ BOLD, RESET, BOLD, RESET, BOLD, RESET, BOLD, RESET, BOLD, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "MemoryKind toString roundtrip" {
    const kinds = [_]MemoryKind{ .heartbeat, .learning, .episode, .rule, .@"error", .observation };
    for (kinds) |k| {
        const s = k.toString();
        const parsed = MemoryKind.fromString(s);
        try std.testing.expectEqual(k, parsed.?);
    }
}

test "MemoryKind default TTLs" {
    try std.testing.expect(MemoryKind.heartbeat.defaultTtl() > 0);
    try std.testing.expectEqual(@as(u64, 0), MemoryKind.learning.defaultTtl());
    try std.testing.expectEqual(@as(u64, 0), MemoryKind.rule.defaultTtl());
}

test "generateId produces valid id" {
    var id_buf: [64]u8 = undefined;
    var id_len: u8 = 0;
    generateId(&id_buf, &id_len, 1773750360, "mu");
    const id_str = id_buf[0..id_len];
    try std.testing.expect(std.mem.startsWith(u8, id_str, "mem_"));
    try std.testing.expect(id_len > 10);
}

test "serialize and deserialize roundtrip" {
    var record = MemoryRecord{};
    copyToFixed(32, &record.agent_buf, &record.agent_len, "mu");
    copyToFixed(256, &record.summary_buf, &record.summary_len, "test summary");
    copyToFixed(2048, &record.data_buf, &record.data_len, "{\"key\":\"val\"}");
    record.kind = .learning;
    record.ts = 1773750360;
    record.ttl = 0;
    generateId(&record.id_buf, &record.id_len, record.ts, record.agent());

    // Add a tag
    copyToFixed(32, &record.tags[0], &record.tag_lens[0], "build");
    record.tag_count = 1;

    var buf: [4096]u8 = undefined;
    const json = try serializeRecord(&buf, &record);

    var parsed = MemoryRecord{};
    try std.testing.expect(deserializeRecord(json, &parsed));

    try std.testing.expectEqualStrings("mu", parsed.agent());
    try std.testing.expectEqualStrings("test summary", parsed.summary());
    try std.testing.expectEqual(MemoryKind.learning, parsed.kind);
    try std.testing.expectEqual(@as(u64, 1773750360), parsed.ts);
    try std.testing.expectEqual(@as(u8, 1), parsed.tag_count);
    try std.testing.expectEqualStrings("build", parsed.getTag(0));
}

test "containsIgnoreCase" {
    try std.testing.expect(containsIgnoreCase("Hello World", "hello"));
    try std.testing.expect(containsIgnoreCase("Hello World", "WORLD"));
    try std.testing.expect(!containsIgnoreCase("Hello World", "xyz"));
    try std.testing.expect(!containsIgnoreCase("Hi", "Hello"));
}

test "MemoryRecord isExpired" {
    var rec = MemoryRecord{};
    rec.ts = 1000;
    rec.ttl = 100;

    try std.testing.expect(!rec.isExpired(1050)); // within TTL
    try std.testing.expect(rec.isExpired(1200)); // past TTL

    rec.ttl = 0; // permanent
    try std.testing.expect(!rec.isExpired(999999)); // never expires
}

test "extractJsonString basic" {
    const json = "{\"id\":\"mem_123_mu_abc\",\"agent\":\"mu\"}";
    const id_val = extractJsonString(json, "\"id\":\"");
    try std.testing.expect(id_val != null);
    try std.testing.expectEqualStrings("mem_123_mu_abc", id_val.?);

    const agent_val = extractJsonString(json, "\"agent\":\"");
    try std.testing.expect(agent_val != null);
    try std.testing.expectEqualStrings("mu", agent_val.?);
}

test "extractJsonNumber basic" {
    const json = "{\"ts\":1773750360,\"ttl\":604800}";
    const ts = extractJsonNumber(json, "\"ts\":");
    try std.testing.expect(ts != null);
    try std.testing.expectEqual(@as(u64, 1773750360), ts.?);
}

test "MemoryKind fromString invalid returns null" {
    try std.testing.expectEqual(@as(?MemoryKind, null), MemoryKind.fromString("invalid"));
    try std.testing.expectEqual(@as(?MemoryKind, null), MemoryKind.fromString(""));
}

test "serialize escapes special chars in summary" {
    var record = MemoryRecord{};
    copyToFixed(32, &record.agent_buf, &record.agent_len, "test");
    copyToFixed(256, &record.summary_buf, &record.summary_len, "line1\nline2\"quoted\"");
    record.kind = .observation;
    record.ts = 100;
    generateId(&record.id_buf, &record.id_len, record.ts, record.agent());

    var buf: [4096]u8 = undefined;
    const json = try serializeRecord(&buf, &record);

    // Should contain escaped newline and quote
    try std.testing.expect(std.mem.indexOf(u8, json, "\\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\\\"") != null);
}

test "copyToFixed truncates long input" {
    var buf: [8]u8 = undefined;
    var len: u8 = 0;
    copyToFixed(8, &buf, &len, "this is a very long string that should be truncated");
    try std.testing.expectEqual(@as(u8, 8), len);
    try std.testing.expectEqualStrings("this is ", buf[0..len]);
}

test "empty agent returns error on write" {
    var record = MemoryRecord{};
    record.agent_len = 0;
    const result = write(std.testing.allocator, &record);
    try std.testing.expectError(error.EmptyAgent, result);
}
