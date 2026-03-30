//! Centralized log aggregation from all 27 agents
//!
//! Queen (Omega) collects logs from all agents in the grid.
//! Logs are stored in JSONL format and can be queried by agent, time, or level.
//!
//! φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

// ============================================================================
// DATA STRUCTURES
// ============================================================================

pub const LogLevel = enum {
    debug,
    info,
    warn,
    err,

    pub fn jsonStringify(value: LogLevel, options: anytype, writer: anytype) !void {
        _ = options;
        try writer.writeAll(switch (value) {
            .debug => "\"debug\"",
            .info => "\"info\"",
            .warn => "\"warn\"",
            .err => "\"error\"",
        });
    }
};

pub const LogEntry = struct {
    agent_domain: []const u8,
    timestamp: i64,
    level: LogLevel,
    message: []const u8,
    metadata: ?std.json.Value = null,

    pub fn format(entry: LogEntry, comptime fmt: []const u8, options: anytype, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("[{s}] {s}: {s}", .{
            entry.agent_domain,
            @tagName(entry.level),
            entry.message,
        });
    }
};

pub const LogQuery = struct {
    agent: ?[]const u8 = null,
    level: ?LogLevel = null,
    since: ?i64 = null,
    limit: usize = 100,
};

pub const LogAggregator = struct {
    allocator: std.mem.Allocator,
    logs: std.ArrayList(LogEntry),
    log_dir: []const u8,
    mutex: std.Thread.Mutex,

    /// Initialize aggregator with log directory
    pub fn init(allocator: std.mem.Allocator, log_dir: []const u8) !LogAggregator {
        // Create log directory if it doesn't exist
        _ = try std.fs.cwd().makeOpenPath(log_dir, .{});

        return LogAggregator{
            .allocator = allocator,
            .logs = std.ArrayList(LogEntry).initCapacity(allocator, 0) catch return error.OutOfMemory,
            .log_dir = log_dir,
            .mutex = std.Thread.Mutex{},
        };
    }

    /// Deinitialize aggregator
    pub fn deinit(self: *LogAggregator) void {
        for (self.logs.items) |log| {
            self.allocator.free(log.agent_domain);
            self.allocator.free(log.message);
            if (log.metadata) |meta| {
                // JSON values are allocated with arena in practice
                _ = meta;
            }
        }
        self.logs.deinit(self.allocator);
    }

    /// Ingest a log entry
    pub fn ingest(self: *LogAggregator, entry: LogEntry) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Add to memory buffer
        const duped = LogEntry{
            .agent_domain = try self.allocator.dupe(u8, entry.agent_domain),
            .timestamp = entry.timestamp,
            .level = entry.level,
            .message = try self.allocator.dupe(u8, entry.message),
            .metadata = entry.metadata,
        };
        try self.logs.append(self.allocator, duped);

        // Persist to .trinity/logs/agent-<domain>.jsonl
        const log_file = try std.fmt.allocPrint(
            self.allocator,
            "{s}/agent-{s}.jsonl",
            .{ self.log_dir, entry.agent_domain }
        );
        defer self.allocator.free(log_file);

        const file = try std.fs.cwd().createFile(log_file, .{ .read = true });
        defer file.close();

        // Write JSON line manually to avoid API issues
        const json_line = try std.fmt.allocPrint(
            self.allocator,
            "{{\"agent_domain\":\"{s}\",\"timestamp\":{d},\"level\":\"{s}\",\"message\":\"{s}\"}}\n",
            .{
                entry.agent_domain,
                entry.timestamp,
                @tagName(entry.level),
                entry.message, // Note: message should not contain quotes or special chars
            }
        );
        defer self.allocator.free(json_line);

        try file.writeAll(json_line);
    }

    /// Query logs by agent
    pub fn queryByAgent(self: *LogAggregator, domain: []const u8, limit: usize) ![]LogEntry {
        self.mutex.lock();
        defer self.mutex.unlock();

        var filtered = std.ArrayList(LogEntry).initCapacity(self.allocator, 0) catch return error.OutOfMemory;
        var count: usize = 0;

        // Iterate backwards (newest first)
        var i: usize = self.logs.items.len;
        while (i > 0) : (i -= 1) {
            const entry = self.logs.items[i - 1];
            if (std.mem.eql(u8, entry.agent_domain, domain)) {
                try filtered.append(self.allocator, entry);
                count += 1;
                if (count >= limit) break;
            }
        }

        return filtered.toOwnedSlice(self.allocator);
    }

    /// Query logs by time
    pub fn queryByTime(self: *LogAggregator, since: i64, limit: usize) ![]LogEntry {
        self.mutex.lock();
        defer self.mutex.unlock();

        var filtered = std.ArrayList(LogEntry).initCapacity(self.allocator, 0) catch return error.OutOfMemory;
        var count: usize = 0;

        var i: usize = self.logs.items.len;
        while (i > 0) : (i -= 1) {
            const entry = self.logs.items[i - 1];
            if (entry.timestamp >= since) {
                try filtered.append(self.allocator, entry);
                count += 1;
                if (count >= limit) break;
            }
        }

        return filtered.toOwnedSlice(self.allocator);
    }

    /// Query logs by level
    pub fn queryByLevel(self: *LogAggregator, level: LogLevel, limit: usize) ![]LogEntry {
        self.mutex.lock();
        defer self.mutex.unlock();

        var filtered = std.ArrayList(LogEntry).initCapacity(self.allocator, 0) catch return error.OutOfMemory;
        var count: usize = 0;

        var i: usize = self.logs.items.len;
        while (i > 0) : (i -= 1) {
            const entry = self.logs.items[i - 1];
            if (entry.level == level) {
                try filtered.append(self.allocator, entry);
                count += 1;
                if (count >= limit) break;
            }
        }

        return filtered.toOwnedSlice(self.allocator);
    }

    /// Complex query with multiple filters
    pub fn query(self: *LogAggregator, q: LogQuery) ![]LogEntry {
        self.mutex.lock();
        defer self.mutex.unlock();

        var filtered = std.ArrayList(LogEntry).initCapacity(self.allocator, 0) catch return error.OutOfMemory;

        var i: usize = self.logs.items.len;
        while (i > 0) : (i -= 1) {
            const entry = self.logs.items[i - 1];

            // Apply filters
            if (q.agent) |agent| {
                if (!std.mem.eql(u8, entry.agent_domain, agent)) continue;
            }

            if (q.level) |level| {
                if (entry.level != level) continue;
            }

            if (q.since) |since| {
                if (entry.timestamp < since) continue;
            }

            try filtered.append(self.allocator, entry);
            if (filtered.items.len >= q.limit) break;
        }

        return filtered.toOwnedSlice(self.allocator);
    }

    /// Get recent logs from all agents
    pub fn getRecent(self: *LogAggregator, limit: usize) ![]LogEntry {
        self.mutex.lock();
        defer self.mutex.unlock();

        const start = if (self.logs.items.len > limit)
            self.logs.items.len - limit
        else
            0;

        const slice_size = self.logs.items.len - start;
        const result = try self.allocator.alloc(LogEntry, slice_size);
        std.mem.copyForwards(LogEntry, result, self.logs.items[start..]);

        return result;
    }

    /// Get error logs only
    pub fn getErrors(self: *LogAggregator, limit: usize) ![]LogEntry {
        return self.queryByLevel(.err, limit);
    }

    /// Get logs count per agent
    pub fn getCountPerAgent(self: *LogAggregator) !std.StringHashMap(usize) {
        self.mutex.lock();
        defer self.mutex.unlock();

        var counts = std.StringHashMap(usize).init(self.allocator);

        for (self.logs.items) |entry| {
            const gop = try counts.getOrPut(entry.agent_domain, 0);
            gop.value_ptr.* += 1;
        }

        return counts;
    }

    /// Clear logs older than specified seconds
    pub fn pruneOldLogs(self: *LogAggregator, older_than_seconds: i64) !usize {
        self.mutex.lock();
        defer self.mutex.unlock();

        const cutoff = std.time.timestamp() - older_than_seconds;
        var removed_count: usize = 0;

        // Remove old entries from memory
        var i: usize = 0;
        while (i < self.logs.items.len) {
            if (self.logs.items[i].timestamp < cutoff) {
                _ = self.logs.orderedRemove(i);
                removed_count += 1;
            } else {
                i += 1;
            }
        }

        return removed_count;
    }

    /// Export logs as JSON
    pub fn toJson(self: *LogAggregator, q: LogQuery) ![]const u8 {
        const entries = try self.query(q);
        defer self.allocator.free(entries);

        var json_buffer = std.ArrayList(u8).initCapacity(self.allocator, 0) catch return error.OutOfMemory;
        const writer = json_buffer.writer();

        try writer.writeAll("{\"logs\":[");

        for (entries, 0..) |entry, i| {
            if (i > 0) try writer.writeAll(",");

            try writer.print(
                "{{\"agent\":\"{s}\",\"timestamp\":{d},\"level\":\"{s}\",\"message\":\"{s}\"}}",
                .{
                    entry.agent_domain,
                    entry.timestamp,
                    @tagName(entry.level),
                    std.zig.fmtEscapes(entry.message),
                });
        }

        try writer.writeAll("]}");
        return json_buffer.toOwnedSlice(self.allocator);
    }

    /// Get aggregate statistics
    pub const LogStats = struct {
        total_logs: usize,
        debug_logs: usize,
        info_logs: usize,
        warn_logs: usize,
        error_logs: usize,
        agents_count: usize,
    };

    pub fn getStats(self: *LogAggregator) !LogStats {
        self.mutex.lock();
        defer self.mutex.unlock();

        var stats = LogStats{
            .total_logs = self.logs.items.len,
            .debug_logs = 0,
            .info_logs = 0,
            .warn_logs = 0,
            .error_logs = 0,
            .agents_count = 0,
        };

        var agents = std.StringHashMap(void).init(self.allocator);
        defer agents.deinit();

        for (self.logs.items) |entry| {
            switch (entry.level) {
                .debug => stats.debug_logs += 1,
                .info => stats.info_logs += 1,
                .warn => stats.warn_logs += 1,
                .err => stats.error_logs += 1,
            }

            if (!agents.contains(entry.agent_domain)) {
                try agents.put(entry.agent_domain, {});
            }
        }

        stats.agents_count = agents.count();
        return stats;
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "Log Aggregator — ingest and query" {
    const allocator = std.testing.allocator;
    var aggregator = try LogAggregator.init(allocator, ".trinity/logs");
    defer aggregator.deinit();

    // Ingest log entry
    const entry = LogEntry{
        .agent_domain = "alpha",
        .timestamp = std.time.timestamp(),
        .level = .info,
        .message = "Agent started",
    };

    try aggregator.ingest(entry);

    // Query by agent
    const results = try aggregator.queryByAgent("alpha", 10);
    defer allocator.free(results);

    try std.testing.expectEqual(@as(usize, 1), results.len);
    try std.testing.expectEqualStrings("Agent started", results[0].message);
}

test "Log Aggregator — query by level" {
    const allocator = std.testing.allocator;
    var aggregator = try LogAggregator.init(allocator, ".trinity/logs");
    defer aggregator.deinit();

    // Ingest entries
    try aggregator.ingest(.{
        .agent_domain = "alpha",
        .timestamp = std.time.timestamp(),
        .level = .info,
        .message = "Info message",
    });

    try aggregator.ingest(.{
        .agent_domain = "alpha",
        .timestamp = std.time.timestamp(),
        .level = .err,
        .message = "Error message",
    });

    // Query errors
    const errors = try aggregator.queryByLevel(.err, 10);
    defer allocator.free(errors);

    try std.testing.expectEqual(@as(usize, 1), errors.len);
    try std.testing.expectEqualStrings("Error message", errors[0].message);
}

test "Log Aggregator — statistics" {
    const allocator = std.testing.allocator;
    var aggregator = try LogAggregator.init(allocator, ".trinity/logs");
    defer aggregator.deinit();

    // Ingest entries
    try aggregator.ingest(.{
        .agent_domain = "alpha",
        .timestamp = std.time.timestamp(),
        .level = .info,
        .message = "Info",
    });

    try aggregator.ingest(.{
        .agent_domain = "beta",
        .timestamp = std.time.timestamp(),
        .level = .warn,
        .message = "Warning",
    });

    const stats = try aggregator.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats.total_logs);
    try std.testing.expectEqual(@as(usize, 1), stats.info_logs);
    try std.testing.expectEqual(@as(usize, 1), stats.warn_logs);
    try std.testing.expectEqual(@as(usize, 2), stats.agents_count);
}
