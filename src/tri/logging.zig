// Trinity Logging Module — Centralized logging for all Trinity components
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

/// Log levels matching common severity
pub const LogLevel = enum {
    Debug,
    Info,
    Warn,
    Error,

    pub fn getName(self: LogLevel) []const u8 {
        return switch (self) {
            .Debug => "DEBUG",
            .Info => "INFO",
            .Warn => "WARN",
            .Error => "ERROR",
        };
    }
};

/// Log entry structure
pub const LogEntry = struct {
    timestamp: i64,
    level: LogLevel,
    component: []const u8,
    message: []const u8,
    details: ?[]const u8,

    /// Format timestamp as [YYYY-MM-DD HH:MM:SS.mmm]
    pub fn timestampFmt(ts: i64) []const u8 {
        // Convert nanoseconds to seconds and milliseconds
        const seconds = @divFloor(ts, 1_000_000_000);
        const millis = @rem(@divFloor(ts, 1_000_000), 1000);

        // Epoch to datetime (simplified - for real use use proper calendar math)
        const epoch_year = 1970;
        const days_since_epoch: u64 = @intCast(@divFloor(seconds, 86400));
        const year = epoch_year + @divFloor(days_since_epoch, 365);
        const day_of_year = @rem(days_since_epoch, 365);

        const month: u32 = @as(u32, @intCast(@divFloor(day_of_year, 30))) + 1;
        const day: u32 = @as(u32, @intCast(@rem(day_of_year, 30))) + 1;

        const seconds_in_day: u64 = @intCast(@rem(seconds, 86400));
        const hour: u32 = @as(u32, @intCast(@divFloor(seconds_in_day, 3600)));
        const minute: u32 = @as(u32, @intCast(@divFloor(@rem(seconds_in_day, 3600), 60)));
        const second: u32 = @as(u32, @intCast(@rem(@rem(seconds_in_day, 3600), 60)));

        // Static buffer for formatting
        var buf: [32]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}", .{
            year, month, day, hour, minute, second, millis,
        }) catch "";
        return &buf;
    }
};

/// Log file wrapper
const LogFile = struct {
    path: []const u8,
    file_handle: ?std.fs.File,
};

/// Centralized logging state
const LoggingState = struct {
    allocator: std.mem.Allocator,
    log_file: ?LogFile,
    current_level: LogLevel,
    initialized: bool,
    entries_count: usize,
};

var global_state: LoggingState = .{
    .allocator = undefined,
    .log_file = null,
    .current_level = .Info,
    .initialized = false,
    .entries_count = 0,
};

/// Initialize logging system
pub fn init(allocator: std.mem.Allocator, level: LogLevel) !void {
    if (global_state.initialized) {
        return;
    }

    global_state.allocator = allocator;
    global_state.current_level = level;

    // Create .trinity/logs directory if needed
    const log_dir = ".trinity/logs";
    try std.fs.cwd().makePath(log_dir);

    // Create or open log file
    const log_path = ".trinity/logs/trinity.log";
    const log_file = try std.fs.cwd().createFile(log_path, .{ .read = true });

    global_state.log_file = LogFile{
        .path = log_path,
        .file_handle = log_file,
    };
    global_state.initialized = true;

    std.debug.print("[✓] Logging initialized: {s}\n", .{log_path});
}

/// Write formatted log entry to file
pub fn log(level: LogLevel, comptime fmt: []const u8, args: anytype, details: ?[]const u8) !void {
    if (!global_state.initialized) {
        return;
    }

    if (@intFromEnum(level) < @intFromEnum(global_state.current_level)) {
        return; // Skip messages below current level
    }

    const timestamp = std.time.nanoTimestamp();
    const ts_formatted = LogEntry.timestampFmt(timestamp);
    const level_name = level.getName();
    const component = "core"; // Default component

    // Format: [LEVEL] [TIME] [COMPONENT] MESSAGE
    const formatted = try std.fmt.allocPrint(
        global_state.allocator,
        "[{s}] [{s}] [{s}] " ++ fmt ++ "\n",
        .{ level_name, ts_formatted, component } ++ args,
    );
    defer global_state.allocator.free(formatted);

    if (global_state.log_file) |*file| {
        if (file.file_handle) |fh| {
            try fh.writeAll(formatted);

            // Add details if present
            if (details) |det| {
                try fh.writeAll("  Details: ");
                try fh.writeAll(det);
                try fh.writeAll("\n");
            }

            // Sync on error level
            if (level == .Error) {
                try fh.sync();
            }
        }
    }

    global_state.entries_count += 1;
}

/// Write log entry with component
pub fn logWithComponent(level: LogLevel, component: []const u8, comptime fmt: []const u8, args: anytype, details: ?[]const u8) !void {
    if (!global_state.initialized) {
        return;
    }

    if (@intFromEnum(level) < @intFromEnum(global_state.current_level)) {
        return;
    }

    const timestamp = std.time.nanoTimestamp();
    const ts_formatted = LogEntry.timestampFmt(timestamp);
    const level_name = level.getName();

    const formatted = try std.fmt.allocPrint(
        global_state.allocator,
        "[{s}] [{s}] [{s}] " ++ fmt ++ "\n",
        .{ level_name, ts_formatted, component } ++ args,
    );
    defer global_state.allocator.free(formatted);

    if (global_state.log_file) |*file| {
        if (file.file_handle) |fh| {
            try fh.writeAll(formatted);

            if (details) |det| {
                try fh.writeAll("  Details: ");
                try fh.writeAll(det);
                try fh.writeAll("\n");
            }

            if (level == .Error) {
                try fh.sync();
            }
        }
    }

    global_state.entries_count += 1;
}

/// Flush all log entries to file
pub fn flush() !usize {
    if (global_state.log_file) |*file| {
        if (file.file_handle) |fh| {
            try fh.sync();
        }
    }
    return global_state.entries_count;
}

/// Set log level at runtime
pub fn setLevel(level: LogLevel) void {
    std.debug.print("[*] Log level set to {s}\n", .{level.getName()});
    global_state.current_level = level;
}

/// Get current log level
pub fn getLevel() LogLevel {
    return global_state.current_level;
}

/// Get number of entries logged
pub fn getEntryCount() usize {
    return global_state.entries_count;
}

/// Close log file and cleanup
pub fn close() void {
    if (global_state.log_file) |*file| {
        if (file.file_handle) |fh| {
            fh.close();
            std.debug.print("[✓] Closed log file: {s}\n", .{file.path});
        }
        global_state.log_file = null;
    }
    global_state.initialized = false;
}

/// Debug shorthand
pub fn debug(comptime fmt: []const u8, args: anytype) void {
    log(.Debug, fmt, args, null) catch {};
}

/// Info shorthand
pub fn info(comptime fmt: []const u8, args: anytype) void {
    log(.Info, fmt, args, null) catch {};
}

/// Warn shorthand
pub fn warn(comptime fmt: []const u8, args: anytype) void {
    log(.Warn, fmt, args, null) catch {};
}

/// Error shorthand
pub fn err(comptime fmt: []const u8, args: anytype) void {
    log(.Error, fmt, args, null) catch {};
}

test "logging module - basic functionality" {
    const allocator = std.testing.allocator;

    // Test initialization
    try init(allocator, .Debug);
    defer close();

    // Test basic logging
    try log(.Info, "Test message", .{}, null);

    // Test all log levels
    const levels = [_]LogLevel{ .Debug, .Info, .Warn, .Error };
    for (levels) |lvl| {
        try log(lvl, "Level test message: {s}", .{lvl.getName()}, null);
    }

    // Verify level is set
    try std.testing.expectEqual(getLevel(), .Debug);

    // Test entry count
    const count = getEntryCount();
    try std.testing.expect(count > 0);

    // Test flush
    _ = try flush();
}
