//! TRI Logging — Generated from specs/tri/tri_logging.tri
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// ============================================================================
// TYPES
// ============================================================================

/// Logging severity levels
pub const LogLevel = enum(u8) {
    debug = 0,
    info = 1,
    warn = 2,
    err = 3,

    pub fn intValue(self: LogLevel) u8 {
        return @intFromEnum(self);
    }
};

/// Single log entry
pub const LogEntry = struct {
    level: LogLevel,
    message: []const u8,
    timestamp: u64,
    tag: ?[]const u8,
};

// ============================================================================
// LOG LEVEL FUNCTIONS
// ============================================================================

/// Convert log level to string
pub fn levelToString(level: LogLevel) []const u8 {
    return switch (level) {
        LogLevel.debug => "DEBUG",
        LogLevel.info => "INFO",
        LogLevel.warn => "WARN",
        LogLevel.err => "ERROR",
    };
}

/// Parse log level from string
pub fn levelFromString(s: []const u8) ?LogLevel {
    if (std.mem.eql(u8, s, "DEBUG") or std.mem.eql(u8, s, "debug")) return LogLevel.debug;
    if (std.mem.eql(u8, s, "INFO") or std.mem.eql(u8, s, "info")) return LogLevel.info;
    if (std.mem.eql(u8, s, "WARN") or std.mem.eql(u8, s, "warn")) return LogLevel.warn;
    if (std.mem.eql(u8, s, "ERROR") or std.mem.eql(u8, s, "error")) return LogLevel.err;
    return null;
}

/// Get ANSI color code for level
pub fn levelColor(level: LogLevel) []const u8 {
    return switch (level) {
        LogLevel.debug => "\x1b[36m", // Cyan
        LogLevel.info => "\x1b[32m", // Green
        LogLevel.warn => "\x1b[33m", // Yellow
        LogLevel.err => "\x1b[31m", // Red
    };
}

/// Get ANSI reset code
pub fn colorReset() []const u8 {
    return "\x1b[0m";
}

/// Check if message should be logged
pub fn shouldLog(msg_level: LogLevel, min_level: LogLevel) bool {
    return msg_level.intValue() >= min_level.intValue();
}

/// Format log entry for output
pub fn formatEntry(allocator: std.mem.Allocator, entry: LogEntry) ![]u8 {
    const level_str = levelToString(entry.level);
    const color = levelColor(entry.level);
    const reset = colorReset();

    var buffer: [512]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);
    const writer = stream.writer();

    // Format: [LEVEL] [TAG] message
    try writer.print("{s}[{s}]{s}", .{ color, level_str, reset });

    if (entry.tag) |tag| {
        try writer.print(" [{s}]", .{tag});
    }

    try writer.print(" {s}", .{entry.message});

    const result_len = stream.pos;
    const result = try allocator.alloc(u8, result_len);
    @memcpy(result, buffer[0..result_len]);
    return result;
}

/// Format log entry with timestamp
pub fn formatEntryWithTime(allocator: std.mem.Allocator, entry: LogEntry) ![]u8 {
    const level_str = levelToString(entry.level);
    const color = levelColor(entry.level);
    const reset = colorReset();

    // Convert milliseconds timestamp to seconds:millis
    const secs = entry.timestamp / 1000;
    const millis = entry.timestamp % 1000;

    var buffer: [512]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);
    const writer = stream.writer();

    // Format: [HH:MM:SS.mmm] [LEVEL] [TAG] message
    const hours = @as(u32, @intCast((secs / 3600) % 24));
    const minutes = @as(u32, @intCast((secs / 60) % 60));
    const seconds = @as(u32, @intCast(secs % 60));

    try writer.print("{s}[{d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}]{s} ", .{
        color, hours, minutes, seconds, millis, reset,
    });
    try writer.print("[{s}] ", .{level_str});

    if (entry.tag) |tag| {
        try writer.print("[{s}] ", .{tag});
    }

    try writer.print("{s}", .{entry.message});

    const result_len = stream.pos;
    const result = try allocator.alloc(u8, result_len);
    @memcpy(result, buffer[0..result_len]);
    return result;
}

// ============================================================================
// TESTS
// ============================================================================

test "Logging: levelToString" {
    try std.testing.expectEqualStrings("DEBUG", levelToString(LogLevel.debug));
    try std.testing.expectEqualStrings("INFO", levelToString(LogLevel.info));
    try std.testing.expectEqualStrings("WARN", levelToString(LogLevel.warn));
    try std.testing.expectEqualStrings("ERROR", levelToString(LogLevel.err));
}

test "Logging: levelFromString" {
    try std.testing.expectEqual(LogLevel.debug, levelFromString("debug").?);
    try std.testing.expectEqual(LogLevel.info, levelFromString("INFO").?);
    try std.testing.expectEqual(LogLevel.warn, levelFromString("warn").?);
    try std.testing.expectEqual(LogLevel.err, levelFromString("ERROR").?);
    try std.testing.expect(levelFromString("invalid") == null);
}

test "Logging: levelColor" {
    const debug_color = levelColor(LogLevel.debug);
    const info_color = levelColor(LogLevel.info);
    const warn_color = levelColor(LogLevel.warn);
    const error_color = levelColor(LogLevel.err);

    try std.testing.expectEqualStrings("\x1b[36m", debug_color);
    try std.testing.expectEqualStrings("\x1b[32m", info_color);
    try std.testing.expectEqualStrings("\x1b[33m", warn_color);
    try std.testing.expectEqualStrings("\x1b[31m", error_color);
}

test "Logging: shouldLog" {
    try std.testing.expect(shouldLog(LogLevel.err, LogLevel.info));
    try std.testing.expect(shouldLog(LogLevel.warn, LogLevel.warn));
    try std.testing.expect(!shouldLog(LogLevel.debug, LogLevel.info));
    try std.testing.expect(shouldLog(LogLevel.info, LogLevel.debug));
}

test "Logging: formatEntry" {
    const allocator = std.testing.allocator;

    {
        const entry = LogEntry{
            .level = LogLevel.info,
            .message = "test message",
            .timestamp = 0,
            .tag = null,
        };
        const result = try formatEntry(allocator, entry);
        defer allocator.free(result);
        try std.testing.expect(result.len > 0);
        // Should contain INFO and the message
        try std.testing.expect(std.mem.indexOf(u8, result, "INFO") != null);
        try std.testing.expect(std.mem.indexOf(u8, result, "test message") != null);
    }

    {
        const entry = LogEntry{
            .level = LogLevel.warn,
            .message = "warning",
            .timestamp = 0,
            .tag = "TEST",
        };
        const result = try formatEntry(allocator, entry);
        defer allocator.free(result);
        try std.testing.expect(std.mem.indexOf(u8, result, "WARN") != null);
        try std.testing.expect(std.mem.indexOf(u8, result, "[TEST]") != null);
    }
}

test "Logging: formatEntryWithTime" {
    const allocator = std.testing.allocator;

    const entry = LogEntry{
        .level = LogLevel.debug,
        .message = "test",
        .timestamp = 3661001, // 01:01:01.001
        .tag = "TAG",
    };
    const result = try formatEntryWithTime(allocator, entry);
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "01:01:01") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "DEBUG") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "[TAG]") != null);
}

test "Logging: level hierarchy" {
    try std.testing.expectEqual(@as(u8, 0), LogLevel.debug.intValue());
    try std.testing.expectEqual(@as(u8, 1), LogLevel.info.intValue());
    try std.testing.expectEqual(@as(u8, 2), LogLevel.warn.intValue());
    try std.testing.expectEqual(@as(u8, 3), LogLevel.err.intValue());
}
