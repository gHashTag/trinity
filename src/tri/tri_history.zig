// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI — Command History
// ═══════════════════════════════════════════════════════════════════════════════
//
// Command history management for TRI CLI REPL
// Supports persistent history with search and navigation
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

const MAX_HISTORY_SIZE: usize = 1000;
const ArrayListManaged = std.array_list.Managed;

pub const History = struct {
    allocator: std.mem.Allocator,
    entries: ArrayListManaged([]const u8),
    index: usize = 0,
    file_path: []const u8,

    /// Initialize history with optional file path
    pub fn init(allocator: std.mem.Allocator, file_path: []const u8) History {
        return History{
            .allocator = allocator,
            .entries = ArrayListManaged([]const u8).init(allocator),
            .index = 0,
            .file_path = file_path,
        };
    }

    /// Deallocate history resources
    pub fn deinit(self: *History) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry);
        }
        self.entries.deinit();
    }

    /// Add a command to history
    pub fn add(self: *History, command: []const u8) !void {
        // Skip empty commands and duplicates of the last command
        if (command.len == 0) return;

        if (self.entries.items.len > 0) {
            const last = self.entries.items[self.entries.items.len - 1];
            if (std.mem.eql(u8, command, last)) return;
        }

        // Make a copy of the command
        const copy = try self.allocator.dupe(u8, command);
        errdefer self.allocator.free(copy);

        try self.entries.append(copy);
        self.index = self.entries.items.len;

        // Trim history if too large
        while (self.entries.items.len > MAX_HISTORY_SIZE) {
            const old = self.entries.orderedRemove(0);
            self.allocator.free(old);
        }

        // Save to file
        self.save() catch |err| {
            std.log.debug("history save: {s}", .{@errorName(err)});
        };
    }

    /// Navigate to previous command
    pub fn previous(self: *History) ?[]const u8 {
        if (self.entries.items.len == 0) return null;
        if (self.index > 0) self.index -= 1;
        return self.entries.items[self.index];
    }

    /// Navigate to next command
    pub fn next(self: *History) ?[]const u8 {
        if (self.index < self.entries.items.len - 1) {
            self.index += 1;
            return self.entries.items[self.index];
        }
        return null;
    }

    /// Reset navigation index to end
    pub fn resetIndex(self: *History) void {
        self.index = self.entries.items.len;
    }

    /// Search history by prefix
    pub fn search(self: *History, prefix: []const u8) ?[]const u8 {
        if (prefix.len == 0) return null;

        // Search backwards from current position
        var i: isize = if (self.index > 0) @as(isize, @intCast(self.index)) - 1 else -1;
        while (i >= 0) : (i -= 1) {
            const entry = self.entries.items[@as(usize, @intCast(i))];
            if (std.mem.startsWith(u8, entry, prefix)) {
                self.index = @as(usize, @intCast(i));
                return entry;
            }
        }

        return null;
    }

    /// Get all entries matching a pattern
    pub fn grep(self: *History, pattern: []const u8, allocator: std.mem.Allocator) ![][]const u8 {
        var results = ArrayListManaged([]const u8).init(allocator);

        for (self.entries.items) |entry| {
            if (std.mem.indexOf(u8, entry, pattern) != null) {
                try results.append(entry);
            }
        }

        return results.toOwnedSlice();
    }

    /// Get recent N commands
    pub fn recent(self: *History, n: usize, allocator: std.mem.Allocator) ![][]const u8 {
        const start = if (n >= self.entries.items.len)
            0
        else
            self.entries.items.len - n;

        const slice = self.entries.items[start..];
        const results = try allocator.alloc([]const u8, slice.len);

        @memcpy(results, slice);
        return results;
    }

    /// Clear all history
    pub fn clear(self: *History) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry);
        }
        self.entries.clearRetainingCapacity();
        self.index = 0;
    }

    /// Save history to file
    pub fn save(self: *const History) !void {
        const file = try std.fs.cwd().createFile(self.file_path, .{});
        defer file.close();

        for (self.entries.items) |entry| {
            try file.writeAll(entry);
            try file.writeAll("\n");
        }
    }

    /// Load history from file
    pub fn load(self: *History) !void {
        const file = try std.fs.cwd().openFile(self.file_path, .{});
        defer file.close();

        var read_buffer: [4096]u8 = undefined;
        const reader = file.reader(&read_buffer);

        var line_buf = ArrayListManaged(u8).init(self.allocator);
        defer line_buf.deinit();

        while (true) {
            line_buf.clearRetainingCapacity();

            reader.streamUntilDelimiterArrayList(u8, &line_buf, '\n', &read_buffer) catch |err| {
                if (err == error.EndOfStream) break;
                return err;
            };

            const line = line_buf.items;
            if (line.len > 0) {
                // Trim carriage return if present
                const trimmed = std.mem.trimRight(u8, line, "\r");
                if (trimmed.len > 0) {
                    const copy = try self.allocator.dupe(u8, trimmed);
                    try self.entries.append(copy);
                }
            }
        }

        self.index = self.entries.items.len;

        // Trim if too large
        while (self.entries.items.len > MAX_HISTORY_SIZE) {
            const old = self.entries.orderedRemove(0);
            self.allocator.free(old);
        }
    }

    /// Get history size
    pub fn size(self: *const History) usize {
        return self.entries.items.len;
    }

    /// Check if history is empty
    pub fn isEmpty(self: *const History) bool {
        return self.entries.items.len == 0;
    }

    /// Print history summary
    pub fn printSummary(self: *const History) void {
        const CYAN = "\x1b[38;2;0;229;153m";
        const GRAY = "\x1b[38;2;156;156;160m";
        const RESET = "\x1b[0m";

        std.debug.print("{s}History: {d} commands{s}\n", .{ CYAN, self.entries.items.len, RESET });

        if (self.entries.items.len > 0) {
            std.debug.print("{s}File: {s}{s}\n", .{ GRAY, self.file_path, RESET });
        }
    }

    /// Print last N commands
    pub fn printLast(self: *const History, n: usize) void {
        const CYAN = "\x1b[38;2;0;229;153m";
        const WHITE = "\x1b[38;2;255;255;255m";
        const RESET = "\x1b[0m";

        const count = @min(n, self.entries.items.len);
        const start = self.entries.items.len - count;

        std.debug.print("{s}\nLast {d} commands:{s}\n\n", .{ CYAN, count, RESET });

        for (self.entries.items[start..], start..) |entry, i| {
            std.debug.print("{s}  {d:4}) {s}{s}\n", .{ WHITE, i + 1, entry, RESET });
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// REPL HISTORY ENHANCEMENT
// ═══════════════════════════════════════════════════════════════════════════════

pub const ReplHistory = struct {
    history: History,
    current_input: ArrayListManaged(u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, file_path: []const u8) ReplHistory {
        return ReplHistory{
            .history = History.init(allocator, file_path),
            .current_input = ArrayListManaged(u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ReplHistory) void {
        self.history.deinit();
        self.current_input.deinit();
    }

    /// Load history from file
    pub fn load(self: *ReplHistory) !void {
        self.history.load() catch |err| {
            std.log.debug("history load: {s}", .{@errorName(err)});
        };
    }

    /// Save current input and clear
    pub fn saveAndClear(self: *ReplHistory, input: []const u8) !void {
        try self.history.add(input);
        self.current_input.clearRetainingCapacity();
    }

    /// Get current input as string
    pub fn getCurrentInput(self: *ReplHistory) []const u8 {
        return self.current_input.items;
    }

    /// Set current input
    pub fn setCurrentInput(self: *ReplHistory, input: []const u8) !void {
        self.current_input.clearRetainingCapacity();
        try self.current_input.appendSlice(input);
    }

    /// Append to current input
    pub fn appendInput(self: *ReplHistory, byte: u8) !void {
        try self.current_input.append(byte);
    }

    /// Navigate back in history
    pub fn navigateBack(self: *ReplHistory) ?[]const u8 {
        if (self.history.previous()) |cmd| {
            self.current_input.clearRetainingCapacity();
            self.current_input.appendSliceAssumeCapacity(cmd);
            return cmd;
        }
        return null;
    }

    /// Navigate forward in history
    pub fn navigateForward(self: *ReplHistory) ?[]const u8 {
        if (self.history.next()) |cmd| {
            self.current_input.clearRetainingCapacity();
            self.current_input.appendSliceAssumeCapacity(cmd);
            return cmd;
        } else {
            // Clear if at end
            self.current_input.clearRetainingCapacity();
            return "";
        }
    }

    /// Search history with prefix
    pub fn search(self: *ReplHistory, prefix: []const u8) ?[]const u8 {
        if (self.history.search(prefix)) |cmd| {
            self.current_input.clearRetainingCapacity();
            self.current_input.appendSliceAssumeCapacity(cmd);
            return cmd;
        }
        return null;
    }

    /// Save history before exit
    pub fn saveBeforeExit(self: *ReplHistory) void {
        self.history.save() catch |err| {
            std.log.debug("history save: {s}", .{@errorName(err)});
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "History: add and retrieve" {
    const allocator = std.testing.allocator;
    var history = History.init(allocator, "test_history.txt");
    defer history.deinit();

    try history.add("command1");
    try history.add("command2");
    try history.add("command3");

    try std.testing.expectEqual(@as(usize, 3), history.size());

    try std.testing.expectEqual(@as(usize, 3), history.index);
    const prev = history.previous() orelse return error.NoPrevious;
    try std.testing.expectEqualStrings("command3", prev);
}

test "History: navigation" {
    const allocator = std.testing.allocator;
    var history = History.init(allocator, "test_history.txt");
    defer history.deinit();

    try history.add("cmd1");
    try history.add("cmd2");
    try history.add("cmd3");

    // Navigate back
    try std.testing.expectEqualStrings("cmd3", history.previous().?);
    try std.testing.expectEqualStrings("cmd2", history.previous().?);
    try std.testing.expectEqualStrings("cmd1", history.previous().?);

    // Navigate forward
    try std.testing.expectEqualStrings("cmd2", history.next().?);
    try std.testing.expectEqualStrings("cmd3", history.next().?);
    _ = history.next(); // Should be null (at end)
}

test "History: duplicate prevention" {
    const allocator = std.testing.allocator;
    var history = History.init(allocator, "test_history.txt");
    defer history.deinit();

    try history.add("same");
    try history.add("same");
    try history.add("different");

    try std.testing.expectEqual(@as(usize, 2), history.size());
}

test "History: search" {
    const allocator = std.testing.allocator;
    var history = History.init(allocator, "test_history.txt");
    defer history.deinit();

    try history.add("phi 10");
    try history.add("fib 20");
    try history.add("phi 5");

    const result = history.search("phi") orelse return error.NotFound;
    try std.testing.expectEqualStrings("phi 5", result);
}

test "ReplHistory: full cycle" {
    const allocator = std.testing.allocator;
    var repl = ReplHistory.init(allocator, "test_history.txt");
    defer repl.deinit();

    try repl.setCurrentInput("test input");
    try std.testing.expectEqualStrings("test input", repl.getCurrentInput());

    try repl.appendInput('!');
    try std.testing.expectEqualStrings("test input!", repl.getCurrentInput());

    try repl.saveAndClear("test input!");
    try std.testing.expectEqual(@as(usize, 0), repl.getCurrentInput().len);
    try std.testing.expectEqual(@as(usize, 1), repl.history.size());
}
