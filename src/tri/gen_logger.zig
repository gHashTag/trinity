//! tri/logger — Structured logging
//! Auto-generated from specs/tri/tri_logger.tri
//! TTT Dogfood v0.2 Stage 106

const std = @import("std");

/// Log severity
pub const Level = enum(u3) {
    Trace = 0,
    Debug = 1,
    Info = 2,
    Warn = 3,
    Error = 4,
    Fatal = 5,
};

/// Log record
pub const LogEntry = struct {
    timestamp: Instant,
    level: Level,
    message: []const u8,
};

/// Logger instance
pub const Logger = struct {
    name: []const u8 = "",
    min_level: Level = .Info,

    /// Create named logger
    pub fn new(name: []const u8, min_level: Level) Logger {
        return .{ .name = name, .min_level = min_level };
    }

    /// Write log entry
    pub fn log(logger: *Logger, level: Level, message: []const u8) void {
        if (@intFromEnum(level) < @intFromEnum(logger.min_level)) return;
        // Simple stdout logging
        std.debug.print("[{s}] {s}\n", .{ @tagName(level), message });
    }
};

const Instant = struct {
    epoch_seconds: i64,
    nanos: u32,
};

test "Logger.new" {
    const logger = Logger.new("test", .Info);
    try std.testing.expectEqual(.Info, logger.min_level);
}

test "Logger.log" {
    var logger = Logger.new("test", .Debug);
    logger.log(.Info, "test message");
    // Just verify it doesn't crash
}
