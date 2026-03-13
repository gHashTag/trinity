//! P2.10: Structured Logging
//!
//! Machine-parseable JSON logging for observability.
//! All logs written to .trinity/logs/ with rotation.
//!
//! φ² + 1/φ² = 3 = TRINITY
// @origin(generated) @regen(done)

const std = @import("std");
const observability = @import("observability.zig");

/// Log level severity
pub const Level = enum(u3) {
    debug = 0,
    info = 1,
    warn = 2,
    err = 3, // Renamed from 'error' (reserved keyword)
    critical = 4,

    pub fn toString(self: Level) []const u8 {
        return switch (self) {
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
            .critical => "CRITICAL",
        };
    }

    pub fn fromString(str: []const u8) ?Level {
        if (std.mem.eql(u8, str, "DEBUG")) return .debug;
        if (std.mem.eql(u8, str, "INFO")) return .info;
        if (std.mem.eql(u8, str, "WARN")) return .warn;
        if (std.mem.eql(u8, str, "ERROR")) return .err;
        if (std.mem.eql(u8, str, "CRITICAL")) return .critical;
        return null;
    }
};

/// Structured log entry
pub const LogEntry = struct {
    timestamp: i64,
    level: Level,
    request_id: ?[24]u8,
    message: []const u8,
    context: std.StringHashMap([]const u8),
    error_code: ?[]const u8,
    stack_trace: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator, level: Level, message: []const u8) LogEntry {
        return LogEntry{
            .timestamp = std.time.timestamp(),
            .level = level,
            .request_id = null,
            .message = message,
            .context = std.StringHashMap([]const u8).init(allocator),
            .error_code = null,
            .stack_trace = null,
        };
    }

    pub fn deinit(self: *LogEntry) void {
        var iter = self.context.iterator();
        while (iter.next()) |entry| {
            self.context.allocator.free(entry.key_ptr.*);
            self.context.allocator.free(entry.value_ptr.*);
        }
        self.context.deinit();
    }

    pub fn setContext(self: *LogEntry, key: []const u8, value: []const u8) !void {
        const key_copy = try self.context.allocator.dupe(u8, key);
        errdefer self.context.allocator.free(key_copy);
        const value_copy = try self.context.allocator.dupe(u8, value);
        errdefer self.context.allocator.free(value_copy);
        try self.context.put(key_copy, value_copy);
    }

    pub fn toJson(self: *const LogEntry, allocator: std.mem.Allocator) ![]const u8 {
        var buffer = try std.ArrayListAligned(u8, null).initCapacity(allocator, 256);
        defer buffer.deinit(allocator);

        try buffer.append(allocator, '{');

        // Timestamp
        try buffer.appendSlice(allocator, "\"timestamp\":");
        try buffer.print(allocator, "{d}", .{self.timestamp});

        // Level
        try buffer.appendSlice(allocator, ",\"level\":\"");
        try buffer.appendSlice(allocator, self.level.toString());
        try buffer.append(allocator, '"');

        // Request ID (optional)
        if (self.request_id) |id| {
            try buffer.appendSlice(allocator, ",\"request_id\":\"");
            // Slice to actual content length (stop at first null byte)
            const id_slice: []const u8 = &id;
            const id_len = std.mem.indexOfScalar(u8, id_slice, 0) orelse id_slice.len;
            try buffer.appendSlice(allocator, id_slice[0..id_len]);
            try buffer.append(allocator, '"');
        }

        // Message
        try buffer.appendSlice(allocator, ",\"message\":");
        try writeJsonString(allocator, buffer.writer(allocator), self.message);

        // Context
        if (self.context.count() > 0) {
            try buffer.appendSlice(allocator, ",\"context\":{");
            var first = true;
            var iter = self.context.iterator();
            while (iter.next()) |entry| {
                if (!first) try buffer.append(allocator, ',');
                first = false;
                try writeJsonString(allocator, buffer.writer(allocator), entry.key_ptr.*);
                try buffer.appendSlice(allocator, ":");
                try writeJsonString(allocator, buffer.writer(allocator), entry.value_ptr.*);
            }
            try buffer.append(allocator, '}');
        }

        // Error code (optional)
        if (self.error_code) |code| {
            try buffer.appendSlice(allocator, ",\"error_code\":");
            try writeJsonString(allocator, buffer.writer(allocator), code);
        }

        // Stack trace (optional)
        if (self.stack_trace) |trace| {
            try buffer.appendSlice(allocator, ",\"stack_trace\":");
            try writeJsonString(allocator, buffer.writer(allocator), trace);
        }

        try buffer.append(allocator, '}');

        return buffer.toOwnedSlice(allocator);
    }
};

/// Logger with file rotation
pub const Logger = struct {
    allocator: std.mem.Allocator,
    base_dir: std.fs.Dir,
    current_file: ?std.fs.File,
    current_date: i64,
    min_level: Level,
    stdout_enabled: bool,

    const LOG_DIR = ".trinity/logs";
    const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB per file

    pub fn init(allocator: std.mem.Allocator, min_level: Level) !Logger {
        // Create logs directory
        const logs_dir = try std.fs.cwd().makeOpenPath(LOG_DIR, .{});

        return Logger{
            .allocator = allocator,
            .base_dir = logs_dir,
            .current_file = null,
            .current_date = 0,
            .min_level = min_level,
            .stdout_enabled = true,
        };
    }

    pub fn deinit(self: *Logger) void {
        if (self.current_file) |f| {
            f.close();
        }
        self.base_dir.close();
    }

    pub fn setStdoutEnabled(self: *Logger, enabled: bool) void {
        self.stdout_enabled = enabled;
    }

    pub fn setMinLevel(self: *Logger, level: Level) void {
        self.min_level = level;
    }

    pub fn log(self: *Logger, entry: LogEntry) !void {
        if (@intFromEnum(entry.level) < @intFromEnum(self.min_level)) {
            return;
        }

        // Get or create log file for current date
        try self.rotateLogFileIfNeeded();

        // Write to file
        if (self.current_file) |file| {
            const json = try entry.toJson(self.allocator);
            defer self.allocator.free(json);

            try file.writeAll(json);
            try file.writeAll("\n");
        }

        // Also print to stdout if enabled (for human readability)
        if (self.stdout_enabled) {
            try self.printToStdout(&entry);
        }
    }

    pub fn debug(self: *Logger, message: []const u8) !void {
        var entry = LogEntry.init(self.allocator, .debug, message);
        defer entry.deinit();
        try self.log(entry);
    }

    pub fn info(self: *Logger, message: []const u8) !void {
        var entry = LogEntry.init(self.allocator, .info, message);
        defer entry.deinit();
        try self.log(entry);
    }

    pub fn warn(self: *Logger, message: []const u8) !void {
        var entry = LogEntry.init(self.allocator, .warn, message);
        defer entry.deinit();
        try self.log(entry);
    }

    pub fn logError(self: *Logger, message: []const u8) !void {
        var entry = LogEntry.init(self.allocator, .err, message);
        defer entry.deinit();
        try self.log(entry);
    }

    pub fn critical(self: *Logger, message: []const u8) !void {
        var entry = LogEntry.init(self.allocator, .critical, message);
        defer entry.deinit();
        try self.log(entry);
    }

    pub fn withContext(
        self: *Logger,
        level: Level,
        message: []const u8,
        context: anytype,
    ) !void {
        var entry = LogEntry.init(self.allocator, level, message);
        defer entry.deinit();

        // Add context from anytype
        inline for (@typeInfo(@TypeOf(context)).Struct.fields) |field| {
            const value = @field(context, field.name);
            const value_str = try self.formatValue(value);
            defer self.allocator.free(value_str);
            try entry.setContext(field.name, value_str);
        }

        try self.log(entry);
    }

    fn formatValue(self: *Logger, value: anytype) ![]const u8 {
        const T = @TypeOf(value);
        return switch (@typeInfo(T)) {
            .Int, .Float, .ComptimeInt, .ComptimeFloat => std.fmt.allocPrint(self.allocator, "{d}", .{value}),
            .Optional => if (value) |v| self.formatValue(v) else self.allocator.dupe(u8, "null"),
            .Pointer => |ptr| switch (ptr.size) {
                .Slice => std.fmt.allocPrint(
                    self.allocator,
                    "{s}",
                    .{if (ptr.child == u8) value else "([...])"},
                ),
                .One => switch (@typeInfo(ptr.child)) {
                    .Array => std.fmt.allocPrint(self.allocator, "{s}", .{value}),
                    else => std.fmt.allocPrint(self.allocator, "{*}", .{value}),
                },
                else => std.fmt.allocPrint(self.allocator, "{*}", .{value}),
            },
            .Bool => self.allocator.dupe(u8, if (value) "true" else "false"),
            .Void => self.allocator.dupe(u8, "void"),
            .Enum => std.fmt.allocPrint(self.allocator, "{s}", .{@tagName(value)}),
            else => std.fmt.allocPrint(self.allocator, "{any}", .{value}),
        };
    }

    fn rotateLogFileIfNeeded(self: *Logger) !void {
        const now = std.time.timestamp();
        const current_date = now / (24 * 60 * 60); // Days since epoch

        if (self.current_date == current_date and self.current_file != null) {
            // Check file size
            if (self.current_file) |file| {
                const stat = file.stat() catch return;
                if (stat.size < MAX_FILE_SIZE) {
                    return; // File is still good
                }
                // File too large, close and rotate
                file.close();
                self.current_file = null;
            }
        }

        self.current_date = current_date;

        // Open new log file: tri-YYYY-MM-DD.jsonl
        var buffer: [32]u8 = undefined;
        const date_str = std.fmt.formatIntBuf(buffer[0..], current_date, 10, .lower, .{});

        const filename = try std.fmt.allocPrint(self.allocator, "tri-{s}.jsonl", .{date_str});
        defer self.allocator.free(filename);

        const file = try self.base_dir.createFile(filename, .{ .read = true });
        self.current_file = file;
    }

    fn printToStdout(self: *Logger, entry: *const LogEntry) !void {
        _ = self;
        const colors = struct {
            const RESET = "\x1b[0m";
            const DEBUG = "\x1b[38;2;156;156;156m"; // Gray
            const INFO = "\x1b[38;2;0;229;153m"; // Cyan
            const WARN = "\x1b[38;2;255;215;0m"; // Yellow
            const ERROR = "\x1b[38;2;255;100;100m"; // Red
            const CRITICAL = "\x1b[38;2;255;0;100m"; // Magenta
            const DIM = "\x1b[38;2;156;156;160m";
        };

        const color = switch (entry.level) {
            .debug => colors.DEBUG,
            .info => colors.INFO,
            .warn => colors.WARN,
            .err => colors.ERROR,
            .critical => colors.CRITICAL,
        };

        // Print: [LEVEL] [timestamp] message
        std.debug.print("{s}[{s}]{s} ", .{ color, entry.level.toString(), colors.RESET });

        if (entry.request_id) |id| {
            std.debug.print("{s}[{s}]{s} ", .{ colors.DIM, id[0..8], colors.RESET });
        }

        std.debug.print("{s}\n", .{entry.message});
    }
};

/// Global logger instance (initialized on first use)
var global_logger: ?Logger = null;
var global_logger_mutex = std.Thread.Mutex{};

pub fn initGlobalLogger(allocator: std.mem.Allocator, min_level: Level) !void {
    global_logger_mutex.lock();
    defer global_logger_mutex.unlock();

    if (global_logger == null) {
        global_logger = try Logger.init(allocator, min_level);
    }
}

pub fn deinitGlobalLogger() void {
    global_logger_mutex.lock();
    defer global_logger_mutex.unlock();

    if (global_logger) |*logger| {
        logger.deinit();
        global_logger = null;
    }
}

pub fn getGlobalLogger() ?*Logger {
    return if (global_logger) |*l| &l else null;
}

/// Convenience functions using global logger
pub fn log(level: Level, message: []const u8) void {
    if (getGlobalLogger()) |logger| {
        var entry = LogEntry.init(logger.allocator, level, message);
        defer entry.deinit();
        logger.log(entry) catch |err| {
            std.log.debug("structured_log: failed to write log entry: {}", .{err});
        };
    }
}

pub fn debugFmt(comptime fmt: []const u8, args: anytype) void {
    const msg = std.fmt.allocPrint(std.heap.page_allocator, fmt, args) catch {
        log(.debug, "unformattable");
        return;
    };
    defer std.heap.page_allocator.free(msg);
    log(.debug, msg);
}

pub fn infoFmt(comptime fmt: []const u8, args: anytype) void {
    const msg = std.fmt.allocPrint(std.heap.page_allocator, fmt, args) catch {
        log(.info, "unformattable");
        return;
    };
    defer std.heap.page_allocator.free(msg);
    log(.info, msg);
}

pub fn warnFmt(comptime fmt: []const u8, args: anytype) void {
    const msg = std.fmt.allocPrint(std.heap.page_allocator, fmt, args) catch {
        log(.warn, "unformattable");
        return;
    };
    defer std.heap.page_allocator.free(msg);
    log(.warn, msg);
}

pub fn errorFmt(comptime fmt: []const u8, args: anytype) void {
    const msg = std.fmt.allocPrint(std.heap.page_allocator, fmt, args) catch {
        log(.err, "unformattable");
        return;
    };
    defer std.heap.page_allocator.free(msg);
    log(.err, msg);
}

pub fn criticalFmt(comptime fmt: []const u8, args: anytype) void {
    const msg = std.fmt.allocPrint(std.heap.page_allocator, fmt, args) catch {
        log(.critical, "unformattable");
        return;
    };
    defer std.heap.page_allocator.free(msg);
    log(.critical, msg);
}

/// Write JSON string with proper escaping
fn writeJsonString(allocator: std.mem.Allocator, writer: anytype, str: []const u8) !void {
    _ = allocator;
    try writer.writeByte('"');
    for (str) |c| {
        switch (c) {
            '\\' => try writer.writeAll("\\\\"),
            '"' => try writer.writeAll("\\\""),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => {
                if (c < 32) {
                    const hex_chars = "0123456789ABCDEF";
                    try writer.writeAll("\\u00");
                    try writer.writeByte(hex_chars[c >> 4]);
                    try writer.writeByte(hex_chars[c & 0xf]);
                } else {
                    try writer.writeByte(c);
                }
            },
        }
    }
    try writer.writeByte('"');
}

// Tests
test "Logger creates log directory" {
    var logger = try Logger.init(std.testing.allocator, .info);
    defer logger.deinit();

    // Verify directory exists
    var dir = try std.fs.cwd().openDir(".trinity/logs", .{});
    defer dir.close();
}

test "LogEntry JSON serialization" {
    var entry = LogEntry.init(std.testing.allocator, .info, "Test message");
    defer entry.deinit();

    try entry.setContext("key", "value");
    try entry.setContext("number", "42");

    const json = try entry.toJson(std.testing.allocator);
    defer std.testing.allocator.free(json);

    try std.testing.expect(json.len > 0);
    try std.testing.expect(std.mem.startsWith(u8, json, "{"));
}

test "Level string conversion" {
    try std.testing.expectEqualStrings("INFO", Level.info.toString());
    try std.testing.expectEqual(.err, Level.fromString("ERROR").?);
}

test "writeJsonString escapes special characters" {
    var buffer = try std.ArrayListAligned(u8, null).initCapacity(std.testing.allocator, 100);
    defer buffer.deinit(std.testing.allocator);

    try writeJsonString(std.testing.allocator, buffer.writer(std.testing.allocator), "Hello\nWorld\"");
    const result = try buffer.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("\"Hello\\nWorld\\\"\"", result);
}
