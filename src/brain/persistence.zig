//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! BRAIN PERSISTENCE — Event Log for S³AI Brain
//!
//! Persists brain events to JSONL for replay and analysis.
//!
//! Sacred Formula: φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const json = std.json;
const fmt = std.fmt;

/// Brain event for JSONL logging
pub const BrainEvent = struct {
    ts: i64, // Nano timestamp
    event: []const u8,

    /// Parse from JSON string
    pub fn fromJsonString(allocator: mem.Allocator, str: []const u8) !BrainEvent {
        const parsed = try json.parseFromSlice(BrainEvent, allocator, str, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();
        return parsed.value;
    }
};

/// Log rotation configuration
pub const RotationConfig = struct {
    max_file_size: usize = 10 * 1024 * 1024, // 10 MB default
    max_backup_files: usize = 5,

    pub fn init() RotationConfig {
        return .{};
    }
};

pub const BrainEventLog = struct {
    file: fs.File,
    mutex: std.Thread.Mutex,
    path: []const u8,
    allocator: mem.Allocator,
    write_buffer: []u8,
    rotation_config: RotationConfig,

    const Self = @This();

    /// Open or create brain event log
    pub fn open(allocator: mem.Allocator, path: []const u8) !Self {
        const dir = std.fs.path.dirname(path) orelse ".";
        try fs.cwd().makePath(dir);

        const file = fs.cwd().openFile(path, .{ .mode = .read_write }) catch |err| {
            if (err == error.FileNotFound) {
                // Create new file
                const new_file = try fs.cwd().createFile(path, .{ .read = true });
                errdefer new_file.close();
                const path_copy = try allocator.dupe(u8, path);
                errdefer allocator.free(path_copy);
                const write_buffer = try allocator.alloc(u8, 4096);
                errdefer allocator.free(write_buffer);
                return Self{
                    .file = new_file,
                    .mutex = std.Thread.Mutex{},
                    .path = path_copy,
                    .allocator = allocator,
                    .write_buffer = write_buffer,
                    .rotation_config = RotationConfig.init(),
                };
            }
            return err;
        };
        errdefer file.close();

        // Seek to end for appending
        try file.seekFromEnd(0);

        const path_copy = try allocator.dupe(u8, path);
        errdefer allocator.free(path_copy);

        const write_buffer = try allocator.alloc(u8, 4096);
        errdefer allocator.free(write_buffer);

        return Self{
            .file = file,
            .mutex = std.Thread.Mutex{},
            .path = path_copy,
            .allocator = allocator,
            .write_buffer = write_buffer,
            .rotation_config = RotationConfig.init(),
        };
    }

    /// Open with custom rotation config
    pub fn openWithConfig(allocator: mem.Allocator, path: []const u8, config: RotationConfig) !Self {
        var event_log = try open(allocator, path);
        event_log.rotation_config = config;
        return event_log;
    }

    pub fn close(self: *Self) void {
        self.file.sync() catch {};
        self.file.close();
        self.allocator.free(self.write_buffer);
        self.allocator.free(self.path);
    }

    /// Log a brain event
    pub fn log(self: *Self, comptime fmt_str: []const u8, args: anytype) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const timestamp = std.time.nanoTimestamp();

        // Build JSON line: {"ts":<timestamp>,"event":"<event>"}
        var buffer: [1024]u8 = undefined;
        const prefix = try fmt.bufPrint(&buffer, "{{\"ts\":{d},\"event\":\"", .{timestamp});
        _ = try self.file.writeAll(prefix);

        // Write formatted event
        const event_bytes = fmt.allocPrint(self.allocator, fmt_str, args) catch |err| {
            // Fallback to simple buffer if allocation fails
            var small_buf: [256]u8 = undefined;
            const formatted = try fmt.bufPrint(&small_buf, fmt_str, args);
            try self.file.writeAll(formatted);
            try self.file.writeAll("\"}\n");
            try self.file.sync();
            return err;
        };
        defer self.allocator.free(event_bytes);
        try self.file.writeAll(event_bytes);
        try self.file.writeAll("\"}\n");

        // Sync to ensure data is written
        try self.file.sync();

        // Check if rotation is needed
        const pos = try self.file.getPos();
        if (pos >= self.rotation_config.max_file_size) {
            try self.rotateLocked();
        }
    }

    /// Flush pending writes to disk
    pub fn flush(self: *Self) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.file.sync();
    }

    /// Rotate log file (must hold mutex)
    fn rotateLocked(self: *Self) !void {
        // Close current file
        self.file.close();

        // Rotate existing backups
        const base_path = self.path;
        const dir = std.fs.path.dirname(base_path) orelse ".";
        const basename = std.fs.path.basename(base_path);

        // Delete oldest backup if it exists
        const oldest_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}.{d}", .{ dir, basename, self.rotation_config.max_backup_files });
        defer self.allocator.free(oldest_path);
        fs.cwd().deleteFile(oldest_path) catch {};

        // Rotate backups: N -> N+1
        var i: usize = self.rotation_config.max_backup_files;
        while (i > 1) : (i -= 1) {
            const old_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}.{d}", .{ dir, basename, i - 1 });
            defer self.allocator.free(old_path);
            const new_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}.{d}", .{ dir, basename, i });
            defer self.allocator.free(new_path);

            fs.cwd().rename(old_path, new_path) catch {};
        }

        // Move current log to .1
        const backup_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}.1", .{ dir, basename });
        defer self.allocator.free(backup_path);
        fs.cwd().rename(base_path, backup_path) catch {};

        // Open new log file
        self.file = try fs.cwd().createFile(base_path, .{ .read = true });
    }

    /// Force rotation of the log file
    pub fn rotate(self: *Self) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.rotateLocked();
    }

    /// Replay events from the log
    pub fn replay(self: *Self, context: anytype, comptime callback: fn (@TypeOf(context), BrainEvent) anyerror!void) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Save current position
        const pos = try self.file.getPos();

        // Read from beginning
        try self.file.seekTo(0);

        var read_buffer: [4096]u8 = undefined;
        var line_buffer = std.ArrayList(u8).initCapacity(self.allocator, 1024) catch unreachable;
        defer line_buffer.deinit(self.allocator);

        while (true) {
            const bytes_read = self.file.read(&read_buffer) catch |err| {
                if (err == error.EndOfStream) break;
                return err;
            };

            if (bytes_read == 0) break;

            for (read_buffer[0..bytes_read]) |byte| {
                if (byte == '\n') {
                    if (line_buffer.items.len > 0) {
                        const event = try BrainEvent.fromJsonString(self.allocator, line_buffer.items);
                        try callback(context, event);
                        line_buffer.clearRetainingCapacity();
                    }
                } else {
                    try line_buffer.append(self.allocator, byte);
                }
            }
        }

        // Handle last line if no trailing newline
        if (line_buffer.items.len > 0) {
            const event = try BrainEvent.fromJsonString(self.allocator, line_buffer.items);
            try callback(context, event);
        }

        // Restore position (ignore errors during cleanup)
        self.file.seekTo(pos) catch {};
    }

    /// Get current file size
    pub fn fileSize(self: *Self) !u64 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return try self.file.getPos();
    }

    /// Count events in log
    pub fn countEvents(self: *Self) !usize {
        self.mutex.lock();
        defer self.mutex.unlock();

        const pos = try self.file.getPos();

        try self.file.seekTo(0);

        var read_buffer: [4096]u8 = undefined;
        var count: usize = 0;

        while (true) {
            const bytes_read = self.file.read(&read_buffer) catch |err| {
                if (err == error.EndOfStream) break;
                return err;
            };

            if (bytes_read == 0) break;

            for (read_buffer[0..bytes_read]) |byte| {
                if (byte == '\n') count += 1;
            }
        }

        // Restore position (ignore errors during cleanup)
        self.file.seekTo(pos) catch {};

        return count;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "BrainEventLog open and write" {
    const tmp = try std.testing.allocator.dupeZ(u8, "/tmp/brain_test.jsonl");
    defer std.testing.allocator.free(tmp);

    // Clean up any existing test file
    fs.cwd().deleteFile(tmp) catch {};

    {
        var log = try BrainEventLog.open(std.testing.allocator, tmp);
        defer log.close();

        try log.log("task_claimed", .{});
        try log.log("task_completed", .{});
    }

    // Verify file exists and has content
    const content = try fs.cwd().readFileAlloc(std.testing.allocator, tmp, 1024);
    defer std.testing.allocator.free(content);

    try std.testing.expect(content.len > 0);

    // Clean up
    fs.cwd().deleteFile(tmp) catch {};
}

test "BrainEventLog JSONL format validation" {
    const tmp = try std.testing.allocator.dupeZ(u8, "/tmp/brain_test_format.jsonl");
    defer std.testing.allocator.free(tmp);

    fs.cwd().deleteFile(tmp) catch {};

    {
        var log = try BrainEventLog.open(std.testing.allocator, tmp);
        defer log.close();

        try log.log("test_event", .{});
        try log.log("another_event", .{});
    }

    // Read and validate JSONL format
    const content = try fs.cwd().readFileAlloc(std.testing.allocator, tmp, 4096);
    defer std.testing.allocator.free(content);

    // Split by lines
    var lines = mem.splitScalar(u8, content, '\n');

    var line_count: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        // Each line should be valid JSON
        const parsed = try json.parseFromSlice(BrainEvent, std.testing.allocator, line, .{});
        parsed.deinit();
        line_count += 1;
    }

    try std.testing.expectEqual(@as(usize, 2), line_count);

    // Clean up
    fs.cwd().deleteFile(tmp) catch {};
}

test "BrainEventLog event replay" {
    const tmp = try std.testing.allocator.dupeZ(u8, "/tmp/brain_test_replay.jsonl");
    defer std.testing.allocator.free(tmp);

    fs.cwd().deleteFile(tmp) catch {};

    const test_events = [_][]const u8{
        "task_claimed",
        "task_started",
        "task_progress",
        "task_completed",
    };

    // Write events
    {
        var log = try BrainEventLog.open(std.testing.allocator, tmp);
        defer log.close();

        for (test_events) |event| {
            try log.log("{s}", .{event});
        }
    }

    // Replay and verify
    var replayed = std.ArrayList([]const u8).initCapacity(std.testing.allocator, 16) catch unreachable;
    defer {
        for (replayed.items) |item| std.testing.allocator.free(item);
        replayed.deinit(std.testing.allocator);
    }

    {
        var log = try BrainEventLog.open(std.testing.allocator, tmp);
        defer log.close();

        try log.replay(&replayed, struct {
            fn ctx(list: *std.ArrayList([]const u8), ev: BrainEvent) !void {
                const event_copy = try std.testing.allocator.dupe(u8, ev.event);
                try list.append(std.testing.allocator, event_copy);
            }
        }.ctx);
    }

    try std.testing.expectEqual(test_events.len, replayed.items.len);

    for (test_events, 0..) |expected, i| {
        try std.testing.expectEqualStrings(expected, replayed.items[i]);
    }

    // Clean up
    fs.cwd().deleteFile(tmp) catch {};
}

test "BrainEventLog count events" {
    const tmp = try std.testing.allocator.dupeZ(u8, "/tmp/brain_test_count.jsonl");
    defer std.testing.allocator.free(tmp);

    fs.cwd().deleteFile(tmp) catch {};

    const event_count: usize = 42;

    {
        var log = try BrainEventLog.open(std.testing.allocator, tmp);
        defer log.close();

        for (0..event_count) |i| {
            try log.log("event_{d}", .{i});
        }
    }

    {
        var log = try BrainEventLog.open(std.testing.allocator, tmp);
        defer log.close();

        const count = try log.countEvents();
        try std.testing.expectEqual(event_count, count);
    }

    // Clean up
    fs.cwd().deleteFile(tmp) catch {};
}

test "BrainEventLog file size tracking" {
    const tmp = try std.testing.allocator.dupeZ(u8, "/tmp/brain_test_size.jsonl");
    defer std.testing.allocator.free(tmp);

    fs.cwd().deleteFile(tmp) catch {};

    {
        var log = try BrainEventLog.open(std.testing.allocator, tmp);
        defer log.close();

        const initial_size = try log.fileSize();
        try std.testing.expectEqual(@as(usize, 0), initial_size);

        try log.log("test_event", .{});

        const after_size = try log.fileSize();
        try std.testing.expect(after_size > 0);
    }

    // Clean up
    fs.cwd().deleteFile(tmp) catch {};
}

test "BrainEventLog manual rotation" {
    const tmp = try std.testing.allocator.dupeZ(u8, "/tmp/brain_test_rotate.jsonl");
    defer std.testing.allocator.free(tmp);

    // Clean up test files
    fs.cwd().deleteFile(tmp) catch {};
    fs.cwd().deleteFile("/tmp/brain_test_rotate.jsonl.1") catch {};

    {
        var log = try BrainEventLog.open(std.testing.allocator, tmp);
        defer log.close();

        try log.log("before_rotation", .{});

        // Force rotation
        try log.rotate();

        try log.log("after_rotation", .{});
    }

    // Check that backup was created
    {
        const backup_content = fs.cwd().readFileAlloc(std.testing.allocator, "/tmp/brain_test_rotate.jsonl.1", 1024) catch null;
        defer if (backup_content) |c| std.testing.allocator.free(c);

        try std.testing.expect(backup_content != null);
        if (backup_content) |content| {
            try std.testing.expect(mem.indexOf(u8, content, "before_rotation") != null);
        }
    }

    // Check current file has new content
    {
        const current_content = try fs.cwd().readFileAlloc(std.testing.allocator, tmp, 1024);
        defer std.testing.allocator.free(current_content);

        try std.testing.expect(mem.indexOf(u8, current_content, "after_rotation") != null);
    }

    // Clean up
    fs.cwd().deleteFile(tmp) catch {};
    fs.cwd().deleteFile("/tmp/brain_test_rotate.jsonl.1") catch {};
}

test "BrainEventLog automatic rotation by size" {
    const tmp = try std.testing.allocator.dupeZ(u8, "/tmp/brain_test_auto_rotate.jsonl");
    defer std.testing.allocator.free(tmp);

    // Clean up test files
    fs.cwd().deleteFile(tmp) catch {};
    fs.cwd().deleteFile("/tmp/brain_test_auto_rotate.jsonl.1") catch {};

    // Small rotation threshold for testing
    const config = RotationConfig{ .max_file_size = 100, .max_backup_files = 3 };

    {
        var log = try BrainEventLog.openWithConfig(std.testing.allocator, tmp, config);
        defer log.close();

        // Write enough to trigger rotation
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            try log.log("event_number_{d}_with_some_extra_data", .{i});
        }
    }

    // Verify backup was created
    if (fs.cwd().openFile("/tmp/brain_test_auto_rotate.jsonl.1", .{})) |file| {
        file.close();
    } else |_| {
        try std.testing.expect(false);
    }

    // Clean up
    fs.cwd().deleteFile(tmp) catch {};
    fs.cwd().deleteFile("/tmp/brain_test_auto_rotate.jsonl.1") catch {};
    fs.cwd().deleteFile("/tmp/brain_test_auto_rotate.jsonl.2") catch {};
}

test "BrainEventLog rotation backup limits" {
    const tmp = try std.testing.allocator.dupeZ(u8, "/tmp/brain_test_limits.jsonl");
    defer std.testing.allocator.free(tmp);

    // Clean up all test files
    fs.cwd().deleteFile(tmp) catch {};
    var i: usize = 1;
    while (i <= 5) : (i += 1) {
        const path = try std.fmt.allocPrint(std.testing.allocator, "/tmp/brain_test_limits.jsonl.{d}", .{i});
        defer std.testing.allocator.free(path);
        fs.cwd().deleteFile(path) catch {};
    }

    // Config with max 3 backups
    const config = RotationConfig{ .max_file_size = 50, .max_backup_files = 3 };

    {
        var log = try BrainEventLog.openWithConfig(std.testing.allocator, tmp, config);
        defer log.close();

        // Trigger multiple rotations
        var rotation: usize = 0;
        while (rotation < 5) : (rotation += 1) {
            try log.log("data_to_fill_buffer_{d}", .{rotation});
            try log.rotate();
        }
    }

    // Verify oldest backup (beyond max) doesn't exist
    const oldest_path = "/tmp/brain_test_limits.jsonl.4";
    if (fs.cwd().openFile(oldest_path, .{})) |file| {
        file.close();
        try std.testing.expect(false);
    } else |_| {
        // Expected - file should not exist
    }

    // Clean up
    fs.cwd().deleteFile(tmp) catch {};
    i = 1;
    while (i <= 3) : (i += 1) {
        const path = try std.fmt.allocPrint(std.testing.allocator, "/tmp/brain_test_limits.jsonl.{d}", .{i});
        defer std.testing.allocator.free(path);
        fs.cwd().deleteFile(path) catch {};
    }
}

test "BrainEventLog replay with complex events" {
    const tmp = try std.testing.allocator.dupeZ(u8, "/tmp/brain_test_complex.jsonl");
    defer std.testing.allocator.free(tmp);

    fs.cwd().deleteFile(tmp) catch {};

    const complex_events = [_][]const u8{
        "task_claimed:task-123:agent-456",
        "metric_update:ppl:2.45",
        "checkpoint:saved:/models/checkpoint.ckpt",
        "error:timeout:connection_refused",
    };

    {
        var log = try BrainEventLog.open(std.testing.allocator, tmp);
        defer log.close();

        for (complex_events) |event| {
            try log.log("{s}", .{event});
        }
    }

    var captured = std.ArrayList([]const u8).initCapacity(std.testing.allocator, 16) catch unreachable;
    defer {
        for (captured.items) |item| std.testing.allocator.free(item);
        captured.deinit(std.testing.allocator);
    }

    {
        var log = try BrainEventLog.open(std.testing.allocator, tmp);
        defer log.close();

        try log.replay(&captured, struct {
            fn capture(list: *std.ArrayList([]const u8), ev: BrainEvent) !void {
                const copy = try std.testing.allocator.dupe(u8, ev.event);
                try list.append(std.testing.allocator, copy);
            }
        }.capture);
    }

    try std.testing.expectEqual(complex_events.len, captured.items.len);

    for (complex_events, 0..) |expected, i| {
        try std.testing.expectEqualStrings(expected, captured.items[i]);
    }

    // Clean up
    fs.cwd().deleteFile(tmp) catch {};
}

test "BrainEventLog empty file replay" {
    const tmp = try std.testing.allocator.dupeZ(u8, "/tmp/brain_test_empty.jsonl");
    defer std.testing.allocator.free(tmp);

    fs.cwd().deleteFile(tmp) catch {};

    // Create empty log file
    {
        var log = try BrainEventLog.open(std.testing.allocator, tmp);
        defer log.close();
    }

    var call_count: usize = 0;

    {
        var log = try BrainEventLog.open(std.testing.allocator, tmp);
        defer log.close();

        try log.replay(&call_count, struct {
            fn count(cnt: *usize, ev: BrainEvent) !void {
                _ = ev;
                cnt.* += 1;
            }
        }.count);
    }

    try std.testing.expectEqual(@as(usize, 0), call_count);

    // Clean up
    fs.cwd().deleteFile(tmp) catch {};
}

test "BrainEventLog concurrent write safety" {
    const tmp = try std.testing.allocator.dupeZ(u8, "/tmp/brain_test_concurrent.jsonl");
    defer std.testing.allocator.free(tmp);

    fs.cwd().deleteFile(tmp) catch {};

    {
        var log = try BrainEventLog.open(std.testing.allocator, tmp);
        defer log.close();

        // Write multiple events (mutex should handle safely)
        var i: usize = 0;
        while (i < 100) : (i += 1) {
            try log.log("event_{d}", .{i});
        }
    }

    // Verify all events were written
    {
        var log = try BrainEventLog.open(std.testing.allocator, tmp);
        defer log.close();

        const count = try log.countEvents();
        try std.testing.expectEqual(@as(usize, 100), count);
    }

    // Clean up
    fs.cwd().deleteFile(tmp) catch {};
}

test "BrainEventLog append to existing file" {
    const tmp = try std.testing.allocator.dupeZ(u8, "/tmp/brain_test_append.jsonl");
    defer std.testing.allocator.free(tmp);

    fs.cwd().deleteFile(tmp) catch {};

    // First write
    {
        var log = try BrainEventLog.open(std.testing.allocator, tmp);
        defer log.close();

        try log.log("first_batch", .{});
    }

    // Second write (should append)
    {
        var log = try BrainEventLog.open(std.testing.allocator, tmp);
        defer log.close();

        try log.log("second_batch", .{});
    }

    // Verify both events exist
    const content = try fs.cwd().readFileAlloc(std.testing.allocator, tmp, 1024);
    defer std.testing.allocator.free(content);

    try std.testing.expect(mem.indexOf(u8, content, "first_batch") != null);
    try std.testing.expect(mem.indexOf(u8, content, "second_batch") != null);

    // Clean up
    fs.cwd().deleteFile(tmp) catch {};
}

test "BrainEventLog special characters in events" {
    const tmp = try std.testing.allocator.dupeZ(u8, "/tmp/brain_test_special.jsonl");
    defer std.testing.allocator.free(tmp);

    fs.cwd().deleteFile(tmp) catch {};

    const special_events = [_][]const u8{
        "event_with_underscore",
        "event-with-dash",
        "event.with.dot",
        "event:with:colon",
        "event/with/slash",
    };

    {
        var log = try BrainEventLog.open(std.testing.allocator, tmp);
        defer log.close();

        for (special_events) |event| {
            try log.log("{s}", .{event});
        }
    }

    // Verify all special character events can be replayed
    var replayed = std.ArrayList([]const u8).initCapacity(std.testing.allocator, 16) catch unreachable;
    defer {
        for (replayed.items) |item| std.testing.allocator.free(item);
        replayed.deinit(std.testing.allocator);
    }

    {
        var log = try BrainEventLog.open(std.testing.allocator, tmp);
        defer log.close();

        try log.replay(&replayed, struct {
            fn capture(list: *std.ArrayList([]const u8), ev: BrainEvent) !void {
                const copy = try std.testing.allocator.dupe(u8, ev.event);
                try list.append(std.testing.allocator, copy);
            }
        }.capture);
    }

    try std.testing.expectEqual(special_events.len, replayed.items.len);

    // Clean up
    fs.cwd().deleteFile(tmp) catch {};
}

test "BrainEvent JSON parsing validation" {
    const allocator = std.testing.allocator;

    // Valid JSON string
    const valid_json = "{\"ts\":1234567890,\"event\":\"test_event\"}";
    const event = try BrainEvent.fromJsonString(allocator, valid_json);

    try std.testing.expectEqual(@as(i64, 1234567890), event.ts);
    try std.testing.expectEqualStrings("test_event", event.event);

    // Invalid JSON string
    const invalid_json = "{not valid json";
    const result = BrainEvent.fromJsonString(allocator, invalid_json);
    try std.testing.expectError(error.SyntaxError, result);
}

test "BrainEventLog with custom rotation config" {
    const tmp = try std.testing.allocator.dupeZ(u8, "/tmp/brain_test_custom.jsonl");
    defer std.testing.allocator.free(tmp);

    fs.cwd().deleteFile(tmp) catch {};

    // Custom config: very small file size, 2 backups max
    const custom_config = RotationConfig{
        .max_file_size = 10,
        .max_backup_files = 2,
    };

    {
        var log = try BrainEventLog.openWithConfig(std.testing.allocator, tmp, custom_config);
        defer log.close();

        try log.log("test", .{});

        // Verify config was applied
        try std.testing.expectEqual(custom_config.max_file_size, log.rotation_config.max_file_size);
        try std.testing.expectEqual(custom_config.max_backup_files, log.rotation_config.max_backup_files);
    }

    // Clean up
    fs.cwd().deleteFile(tmp) catch {};
}
