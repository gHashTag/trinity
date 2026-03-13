//! MCP Server Diagnostic Logger
//! Logs to file + stderr for debugging MCP connection issues
// @origin(manual) @regen(pending)

const std = @import("std");
const posix = std.posix;

pub const LogLevel = enum(u8) {
    debug,
    info,
    warn,
    err,
};

fn logLevelToColor(level: LogLevel) []const u8 {
    return switch (level) {
        .debug => "\x1b[36m", // Cyan
        .info => "\x1b[32m", // Green
        .warn => "\x1b[33m", // Yellow
        .err => "\x1b[31m", // Red
    };
}

pub const Logger = struct {
    file: std.fs.File,
    level: LogLevel,
    enabled: bool,

    pub fn init(path: []const u8, level: LogLevel) !Logger {
        const file = try std.fs.createFileAbsolute(path, .{});
        // Seek to end for append
        const end_pos = try file.getEndPos();
        try file.seekTo(end_pos);
        return .{
            .file = file,
            .level = level,
            .enabled = true,
        };
    }

    pub fn deinit(self: *Logger) void {
        self.file.close();
    }

    pub fn disable(self: *Logger) void {
        self.enabled = false;
    }

    pub fn log(self: *Logger, level: LogLevel, comptime fmt: []const u8, args: anytype) void {
        if (!self.enabled) return;
        if (@intFromEnum(level) < @intFromEnum(self.level)) return;

        const timestamp = std.time.timestamp();
        const color = logLevelToColor(level);
        const reset = "\x1b[0m";

        var buffer: [4096]u8 = undefined;
        const msg = std.fmt.bufPrint(&buffer, "[{d}] {s}{s}{s} " ++ fmt ++ "\n", .{
            timestamp, color, @tagName(level), reset,
        } ++ args) catch return;

        self.file.writeAll(msg) catch |err| {
            std.log.debug("logger: file.writeAll failed: {}", .{err});
        };
        // Also to stderr for immediate visibility
        _ = posix.write(2, msg) catch |err| {
            std.log.debug("logger: posix.write stderr failed: {}", .{err});
        };
    }

    pub fn hexDump(self: *Logger, data: []const u8, max_len: usize) void {
        if (!self.enabled) return;

        const show_len = @min(data.len, max_len);
        var buffer: [8192]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        const writer = fbs.writer();

        writer.writeAll("HEX: ") catch |err| {
            std.log.debug("logger: writeAll HEX prefix failed: {}", .{err});
        };
        var i: usize = 0;
        while (i < show_len) : (i += 1) {
            writer.print("{x:0>2} ", .{data[i]}) catch |err| {
                std.log.debug("logger: hex byte print failed: {}", .{err});
            };
            if (i % 16 == 15 and i < show_len - 1) {
                writer.writeAll("\n     ") catch |err| {
                    std.log.debug("logger: writeAll newline indent failed: {}", .{err});
                };
            }
        }
        if (data.len > max_len) {
            writer.writeAll("...") catch |err| {
                std.log.debug("logger: writeAll truncation marker failed: {}", .{err});
            };
        }

        const msg = fbs.getWritten();
        self.file.writeAll(msg) catch |err| {
            std.log.debug("logger: hexDump file.writeAll failed: {}", .{err});
        };
        _ = posix.write(2, msg) catch return;
    }
};
