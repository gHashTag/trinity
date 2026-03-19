//! BRAIN PERSISTENCE — Event Log for S³AI Brain
//!
//! Persists brain events to JSONL for replay and analysis.

const std = @import("std");
const fs = std.fs;
const mem = std.mem;

pub const BrainEventLog = struct {
    file: fs.File,
    writer: fs.File.Writer,
    mutex: std.Thread.Mutex,

    const Self = @This();

    /// Open or create brain event log
    pub fn open(path: []const u8) !Self {
        const dir = std.fs.path.dirname(path) orelse ".";
        try fs.cwd().makePath(dir);

        const file = try fs.cwd().createFile(path, .{ .read = true });
        errdefer file.close();

        try file.seekFromEnd(0);

        return Self{
            .file = file,
            .writer = file.writer(),
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn close(self: *Self) void {
        self.file.close();
    }

    /// Log a brain event
    pub fn log(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const timestamp = std.time.nanoTimestamp();
        try self.writer.print("{\"ts\":{d},\"event\":\"", .{timestamp});
        try self.writer.print(fmt, args);
        try self.writer.writeAll("\"\n");
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "BrainEventLog open and write" {
    const tmp = try std.testing.allocator.dupeZ(u8, "/tmp/brain_test.jsonl");
    defer std.testing.allocator.free(tmp);

    {
        var log = try BrainEventLog.open(tmp);
        defer log.close();

        try log.log("task_claimed", .{});
        try log.log("task_completed", .{});
    }

    // Verify file exists and has content
    const content = try fs.cwd().readFileAlloc(std.testing.allocator, tmp, 1024);
    defer std.testing.allocator.free(content);

    try std.testing.expect(content.len > 0);
}
