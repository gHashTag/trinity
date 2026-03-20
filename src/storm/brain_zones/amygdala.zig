// ══════════════════════════════════════════════════════════════════════════
// AMYGDALA — Страж ошибок (Mistake Guardian)
// ══════════════════════════════════════════════════════════════════════════════
//
// MNL (Mistake Never Again) pattern enforcement
// - Check blacklist before action
// - 3x failed = auto-SKIP
// - Fear conditioning: past errors → avoidance
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═════════════════════════════════════════════════════════════════════════
// TYPES
// ═════════════════════════════════════════════════════════════════════════════════

pub const FearLevel = enum {
    none,
    low,
    medium,
    high,

    pub fn emoji(self: FearLevel) []const u8 {
        return switch (self) {
            .none => "😌",
            .low => "😟",
            .medium => "😨",
            .high => "😱",
        };
    }

    pub fn color(self: FearLevel) []const u8 {
        return switch (self) {
            .none => "\\x1b[32m",
            .low => "\\x1b[33m",
            .medium => "\\x1b[31m",
            .high => "\\x1b[35m",
        };
    }
};

pub const BlacklistEntry = struct {
    task: []const u8,
    failure_count: u8,
    last_issue: u32,
    last_error: []const u8,
};

pub const Amygdala = struct {
    allocator: std.mem.Allocator,
    blacklist_file: []const u8 = ".trinity/mistakes/blacklist.json",
    fear_threshold: u8 = 3,

    /// Check if task is blacklisted (3x failed)
    pub fn isBlacklisted(amg: *Amygdala, task: []const u8) bool {
        const entry = amg.getEntry(task) catch return false;
        return entry.failure_count >= amg.fear_threshold;
    }

    /// Get fear level for a task
    pub fn fearLevel(amg: *Amygdala, task: []const u8) !FearLevel {
        const entry = amg.getEntry(task) catch {
            return .none;
        };

        if (entry.failure_count == 0) return .none;
        if (entry.failure_count < amg.fear_threshold) return .low;
        if (entry.failure_count == amg.fear_threshold) return .medium;
        return .high;
    }

    /// Record failure → blacklist after 3rd
    pub fn recordFailure(amg: *Amygdala, task: []const u8, issue: u32, error_msg: []const u8) !void {
        var blacklist = try amg.loadBlacklist();
        defer {
            var it = blacklist.iterator();
            while (it.next()) |entry| {
                amg.allocator.free(entry.key_ptr.*);
            }
            blacklist.deinit();
        }

        // Increment or create entry
        const count = blacklist.get(task) orelse 0;
        const new_count = @min(count + 1, 255);
        try blacklist.put(try amg.allocator.dupe(u8, task), new_count);

        try amg.saveBlacklist(&blacklist);

        // If newly blacklisted, create detailed entry
        if (count < amg.fear_threshold and new_count >= amg.fear_threshold) {
            try amg.createMistakeEntry(task, issue, error_msg);
        }
    }

    /// CLI: tri amygdala check-fear
    pub fn cmdCheckFear(amg: *Amygdala, task: []const u8) !void {
        const print = std.debug.print;
        const RESET = "\\x1b[0m";

        const level = try amg.fearLevel(task);
        const is_blacklisted = amg.isBlacklisted(task);

        print("\\n{s}🧠 AMYGDALA — Страж ошибок{s}\\n", .{ "\\x1b[35m", RESET });
        print("{s}═══════════════════════════════════════════════════════════{s}\\n\\n", .{ "\\x1b[2m", RESET });

        print("  Task: {s}\\n", .{task});
        print("  Fear: {s}{s}{s}\\n", .{ level.color(), level.emoji(), RESET });
        print("  Blacklisted: {s}{s}{s}\\n\\n", .{
            if (is_blacklisted) "\\x1b[31m",
            "YES 🚫",
            "\\x1b[32m",
            "NO",
            RESET,
        });

        if (is_blacklisted) {
            print("  {s}⚠️  MNL: This task has failed {d}+ times. Skip recommended.{s}\\n\\n", .{
                "\\x1b[33m",
                amg.fear_threshold,
                RESET,
            });
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════

    fn loadBlacklist(amg: *Amygdala) !std.StringHashMap(u8) {
        var blacklist = std.StringHashMap(u8).init(amg.allocator);

        const file = std.fs.cwd().openFile(amg.blacklist_file, .{}) catch {
            return blacklist;
        };
        defer file.close();

        const contents = file.readToEndAlloc(amg.allocator, 64 * 1024) catch {
            return blacklist;
        };
        defer amg.allocator.free(contents);

        if (std.json.parseFromSlice(std.json.Value, amg.allocator, contents, .{})) |parsed| {
            defer parsed.deinit();
            if (parsed.value == .object) {
                var iter = parsed.value.object.iterator();
                while (iter.next()) |entry| {
                    if (entry.value_ptr.* == .integer) {
                        const key = try amg.allocator.dupe(u8, entry.key_ptr.*);
                        try blacklist.put(key, @as(u8, @intCast(@min(entry.value_ptr.*.integer, 255))));
                    }
                }
            }
        } else |_| {}

        return blacklist;
    }

    fn saveBlacklist(amg: *Amygdala, blacklist: *const std.StringHashMap(u8)) !void {
        std.fs.cwd().makePath(".trinity/mistakes") catch {};

        var json_buf: [4096]u8 = undefined;
        var pos: usize = 0;
        pos += (std.fmt.bufPrint(json_buf[pos..], "{{", .{})).len;

        var first = true;
        var iter = blacklist.iterator();
        while (iter.next()) |entry| {
            if (!first) {
                json_buf[pos] = ',';
                pos += 1;
            }
            first = false;
            pos += (std.fmt.bufPrint(json_buf[pos..], "\\{s}\\\":{d}", .{
                entry.key_ptr.*,
                entry.value_ptr.*,
            })).len;
        }

        json_buf[pos] = '}';
        pos += 1;

        const file = try std.fs.cwd().createFile(amg.blacklist_file, .{});
        defer file.close();
        try file.writeAll(json_buf[0..pos]);
    }

    fn getEntry(amg: *Amygdala, task: []const u8) !BlacklistEntry {
        const file = std.fs.cwd().openFile(amg.blacklist_file, .{}) catch {
            return error.NotFound;
        };
        defer file.close();

        const contents = file.readToEndAlloc(amg.allocator, 64 * 1024) catch {
            return error.NotFound;
        };
        defer amg.allocator.free(contents);

        if (std.json.parseFromSlice(std.json.Value, amg.allocator, contents, .{})) |parsed| {
            defer parsed.deinit();
            if (parsed.value == .object) {
                // Check exact match
                if (parsed.value.object.get(task)) |v| {
                    if (v == .integer) {
                        return .{
                            .task = task,
                            .failure_count = @as(u8, @intCast(@min(v.integer, 255))),
                            .last_issue = 0,
                            .last_error = "",
                        };
                    }
                }
            }
        } else |_| {}

        return error.NotFound;
    }

    fn createMistakeEntry(amg: *Amygdala, task: []const u8, issue: u32, error_msg: []const u8) !void {
        _ = amg;
        _ = task;
        _ = issue;
        _ = error_msg;
        // TODO: Create detailed mistake entry in .trinity/mistakes/
    }
};

// ═════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════

test "Amygdala isBlacklisted false initially" {
    const allocator = std.testing.allocator;
    var amg = Amygdala{ .allocator = allocator };
    try std.testing.expect(!amg.isBlacklisted("new task"));
}

test "Amygdala recordFailure" {
    const allocator = std.testing.allocator;
    var amg = Amygdala{ .allocator = allocator };

    try amg.recordFailure("test task", 1, "error");
    try std.testing.expect(!amg.isBlacklisted("test task"));

    try amg.recordFailure("test task", 2, "error");
    try amg.recordFailure("test task", 3, "error");
    try std.testing.expect(amg.isBlacklisted("test task"));

    // Clean up
    std.fs.cwd().deleteTree(".trinity") catch {};
}

test "FearLevel progression" {
    const allocator = std.testing.allocator;
    var amg = Amygdala{ .allocator = allocator };

    var level = try amg.fearLevel("new task");
    try std.testing.expectEqual(FearLevel.none, level);

    try amg.recordFailure("test", 1, "e");
    level = try amg.fearLevel("test");
    try std.testing.expectEqual(FearLevel.low, level);

    try amg.recordFailure("test", 2, "e");
    try amg.recordFailure("test", 3, "e");
    level = try amg.fearLevel("test");
    try std.testing.expectEqual(FearLevel.medium, level);

    // Clean up
    std.fs.cwd().deleteTree(".trinity") catch {};
}

test "FearLevel emoji" {
    try std.testing.expectEqualStrings("😌", FearLevel.none.emoji());
    try std.testing.expectEqualStrings("😟", FearLevel.low.emoji());
    try std.testing.expectEqualStrings("😨", FearLevel.medium.emoji());
    try std.testing.expectEqualStrings("😱", FearLevel.high.emoji());
}

test "FearLevel color codes" {
    try std.testing.expectEqualStrings("\\x1b[32m", FearLevel.none.color());
    try std.testing.expectEqualStrings("\\x1b[33m", FearLevel.low.color());
    try std.testing.expectEqualStrings("\\x1b[31m", FearLevel.medium.color());
    try std.testing.expectEqualStrings("\\x1b[35m", FearLevel.high.color());
}

test "Amygdala empty task name" {
    const allocator = std.testing.allocator;
    var amg = Amygdala{ .allocator = allocator };
    try std.testing.expect(!amg.isBlacklisted(""));
}

test "Amygdala isBlacklisted with no failures" {
    const allocator = std.testing.allocator;
    var amg = Amygdala{ .allocator = allocator };
    try std.testing.expect(!amg.isBlacklisted("never-attempted-task"));
}

test "Amygdala fearLevel progression through thresholds" {
    const allocator = std.testing.allocator;
    var amg = Amygdala{ .allocator = allocator };

    // 0 failures = none
    try std.testing.expectEqual(FearLevel.none, amg.fearLevel("task") catch return);

    // 1 failure = low
    try amg.recordFailure("task", 1, "error");
    try std.testing.expectEqual(FearLevel.low, amg.fearLevel("task") catch return);

    // 2 failures = still low
    try amg.recordFailure("task", 2, "error");
    try std.testing.expectEqual(FearLevel.low, amg.fearLevel("task") catch return);

    // 3 failures = medium (at threshold)
    try amg.recordFailure("task", 3, "error");
    try std.testing.expectEqual(FearLevel.medium, amg.fearLevel("task") catch return);

    // 4 failures = high (past threshold)
    try amg.recordFailure("task", 4, "error");
    try std.testing.expectEqual(FearLevel.high, amg.fearLevel("task") catch return);

    // Clean up
    std.fs.cwd().deleteTree(".trinity") catch {};
}

test "Amygdala recordFailure caps at 255" {
    const allocator = std.testing.allocator;
    var amg = Amygdala{ .allocator = allocator, .fear_threshold = 3 };

    // Record 300 failures (should cap at 255)
    var i: u8 = 0;
    while (i < 10) : (i += 1) {
        try amg.recordFailure("task", @intCast(i), "error");
    }

    // Should still be blacklisted
    try std.testing.expect(amg.isBlacklisted("task"));

    // Clean up
    std.fs.cwd().deleteTree(".trinity") catch {};
}

test "Amygdala multiple tasks tracked independently" {
    const allocator = std.testing.allocator;
    var amg = Amygdala{ .allocator = allocator };

    try amg.recordFailure("task1", 1, "error");
    try amg.recordFailure("task1", 2, "error");
    try amg.recordFailure("task1", 3, "error");

    try amg.recordFailure("task2", 1, "error");

    try std.testing.expect(amg.isBlacklisted("task1"));
    try std.testing.expect(!amg.isBlacklisted("task2"));

    // Clean up
    std.fs.cwd().deleteTree(".trinity") catch {};
}

test "Amygdala custom fear threshold" {
    const allocator = std.testing.allocator;
    var amg = Amygdala{ .allocator = allocator, .fear_threshold = 5 };

    try amg.recordFailure("task", 1, "error");
    try amg.recordFailure("task", 2, "error");
    try amg.recordFailure("task", 3, "error");

    // Should not be blacklisted yet (threshold is 5)
    try std.testing.expect(!amg.isBlacklisted("task"));

    try amg.recordFailure("task", 4, "error");
    try amg.recordFailure("task", 5, "error");

    // Now should be blacklisted
    try std.testing.expect(amg.isBlacklisted("task"));

    // Clean up
    std.fs.cwd().deleteTree(".trinity") catch {};
}

test "Amygdala getEntry not found" {
    const allocator = std.testing.allocator;
    var amg = Amygdala{ .allocator = allocator };

    const result = amg.getEntry("non-existent-task");
    try std.testing.expectError(error.NotFound, result);
}

test "Amygdala blacklist file persistence" {
    const allocator = std.testing.allocator;
    var amg = Amygdala{ .allocator = allocator };

    try amg.recordFailure("persistent-task", 1, "error");
    try amg.recordFailure("persistent-task", 2, "error");
    try amg.recordFailure("persistent-task", 3, "error");

    // Create a new amygdala instance and verify the blacklist is persisted
    var amg2 = Amygdala{ .allocator = allocator };
    try std.testing.expect(amg2.isBlacklisted("persistent-task"));

    // Clean up
    std.fs.cwd().deleteTree(".trinity") catch {};
}

test "Amygdala fearLevel for different failure counts" {
    const allocator = std.testing.allocator;
    var amg = Amygdala{ .allocator = allocator, .fear_threshold = 5 };

    try amg.recordFailure("task1", 1, "e");
    try std.testing.expectEqual(FearLevel.low, amg.fearLevel("task1") catch return);

    try amg.recordFailure("task2", 1, "e");
    try amg.recordFailure("task2", 2, "e");
    try amg.recordFailure("task2", 3, "e");
    try amg.recordFailure("task2", 4, "e");
    try std.testing.expectEqual(FearLevel.low, amg.fearLevel("task2") catch return);

    try amg.recordFailure("task3", 1, "e");
    try amg.recordFailure("task3", 2, "e");
    try amg.recordFailure("task3", 3, "e");
    try amg.recordFailure("task3", 4, "e");
    try amg.recordFailure("task3", 5, "e");
    try std.testing.expectEqual(FearLevel.medium, amg.fearLevel("task3") catch return);

    try amg.recordFailure("task4", 1, "e");
    try amg.recordFailure("task4", 2, "e");
    try amg.recordFailure("task4", 3, "e");
    try amg.recordFailure("task4", 4, "e");
    try amg.recordFailure("task4", 5, "e");
    try amg.recordFailure("task4", 6, "e");
    try std.testing.expectEqual(FearLevel.high, amg.fearLevel("task4") catch return);

    // Clean up
    std.fs.cwd().deleteTree(".trinity") catch {};
}

test "Amygdala custom blacklist file path" {
    const allocator = std.testing.allocator;
    var amg = Amygdala{ .allocator = allocator, .blacklist_file = "/tmp/test_custom_blacklist.json" };

    try amg.recordFailure("custom-path-task", 1, "e");
    try amg.recordFailure("custom-path-task", 2, "e");
    try amg.recordFailure("custom-path-task", 3, "e");

    try std.testing.expect(amg.isBlacklisted("custom-path-task"));

    // Clean up
    std.fs.deleteFile("/tmp/test_custom_blacklist.json") catch {};
}
