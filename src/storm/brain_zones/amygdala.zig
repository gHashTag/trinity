//! AMYGDALA (Striatum) — Memory + Blacklist
//! Levenshtein fuzzy match for similar tasks + failure tracking

const std = @import("std");

pub const MAX_FAILURES: u32 = 3; // 3 failures = blacklist

/// Error types for failure tracking
pub const ErrorType = enum(u8) {
    Duplicate = 1,
    Persistent = 2,
    Timeout = 3,
    Unknown = 0,

    pub fn toString(self: ErrorType) []const u8 {
        return switch (self) {
            .Duplicate => "DUPLICATE",
            .Persistent => "PERSISTENT",
            .Timeout => "TIMEOUT",
            .Unknown => "UNKNOWN",
        };
    }
};

/// Failure record - tracks count and type
pub const FailureRecord = struct {
    count: u32,
    error_type: ErrorType,
    message: []const u8,
};

/// Experience Engine - tracks task failures and blacklist
pub const ExperienceEngine = struct {
    allocator: std.mem.Allocator,
    blacklist: ?std.StringHashMap(FailureRecord) = null,

    /// Create new experience engine
    pub fn init(allocator: std.mem.Allocator) ExperienceEngine {
        return .{
            .allocator = allocator,
            .blacklist = null,
        };
    }

    /// Deinitialize experience engine
    pub fn deinit(self: *ExperienceEngine) void {
        if (self.blacklist) |*bl| {
            // Free all allocated messages
            var iter = bl.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.value_ptr.message);
            }
            bl.deinit();
        }
    }
};

/// Simple Levenshtein distance calculation
fn levenshtein(a: []const u8, b: []const u8) usize {
    // For simplicity, return 0 for identical strings, 1 for different
    if (std.mem.eql(u8, a, b)) return 0;
    if (a.len == 0 or b.len == 0) return @max(a.len, b.len);

    // Count character differences
    var diff: usize = 0;
    const min_len = @min(a.len, b.len);
    diff += @abs(a.len - b.len);

    for (0..min_len) |i| {
        if (a[i] != b[i]) diff += 1;
    }
    return diff;
}

/// Record a failure for blacklist
/// Uses error_code to track different failure types (Duplicate, Persistent, Timeout)
pub fn recordFailure(self: *ExperienceEngine, task: []const u8, error_code: ErrorType) !void {
    if (self.blacklist == null) {
        self.blacklist = std.StringHashMap(FailureRecord).init(self.allocator);
    }

    // Check if already tracked
    const entry = self.blacklist.?.get(task) orelse {
        // First failure - record it with provided error type
        const msg = try std.fmt.allocPrint(self.allocator, "{s} (1/{d})", .{ error_code.toString(), MAX_FAILURES });
        _ = try self.blacklist.?.put(task, .{
            .count = 1,
            .error_type = error_code,
            .message = msg,
        });
        return;
    };

    // Increment failure count
    if (entry.value_ptr.count >= MAX_FAILURES) {
        // Already at max - ensure blacklisted status
        if (entry.value_ptr.count > MAX_FAILURES) {
            entry.value_ptr.count = MAX_FAILURES;
        }
        const msg = try std.fmt.allocPrint(self.allocator, "{s} - Blacklisted ({d}/{d})", .{ entry.value_ptr.error_type.toString(), entry.value_ptr.count, MAX_FAILURES });
        self.allocator.free(entry.value_ptr.message);
        entry.value_ptr.message = msg;
    } else {
        entry.value_ptr.count += 1;
        const msg = try std.fmt.allocPrint(self.allocator, "{s} ({d}/{d})", .{ entry.value_ptr.error_type.toString(), entry.value_ptr.count, MAX_FAILURES });
        self.allocator.free(entry.value_ptr.message);
        entry.value_ptr.message = msg;
    }
}

/// Check if task is blacklisted
pub fn checkBlacklist(self: *ExperienceEngine, task: []const u8) bool {
    const bl = self.blacklist orelse return false;
    const entry = bl.get(task) orelse return false;
    return entry.count >= MAX_FAILURES;
}

/// Get failure info for a task
pub fn getFailureInfo(self: *ExperienceEngine, task: []const u8) ?FailureRecord {
    const bl = self.blacklist orelse return null;
    return bl.get(task);
}

/// CLI command for AMYGDALA
/// Usage: tri amygdala check <task_name>
pub fn cmdCheckFear(allocator: std.mem.Allocator, args: []const u8) ![]const u8 {
    var engine = ExperienceEngine.init(allocator);
    defer engine.deinit();

    // Parse task name from args
    const task_name = std.mem.trim(u8, args, " \n\t");
    if (task_name.len == 0) {
        return try std.fmt.allocPrint(allocator, "Usage: tri amygdala check <task_name>\n", .{});
    }

    const info = getFailureInfo(&engine, task_name);
    const is_blocked = checkBlacklist(&engine, task_name);

    if (info) |record| {
        return try std.fmt.allocPrint(allocator, "Task: {s}\nStatus: {s}\nFailures: {d}/{d}\nType: {s}\nMessage: {s}\n", .{
            task_name,
            if (is_blocked) "BLOCKED ❌" else "TRACKED ⚠️",
            record.count,
            MAX_FAILURES,
            record.error_type.toString(),
            record.message,
        });
    } else {
        return try std.fmt.allocPrint(allocator, "Task: {s}\nStatus: NO ✅\nNot tracked in experience engine\n", .{task_name});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════

test "levenshtein identical strings" {
    try std.testing.expectEqual(@as(usize, 0), levenshtein("hello", "hello"));
}

test "levenshtein different strings" {
    const result = levenshtein("hello", "world");
    try std.testing.expect(result > 0);
}

test "levenshtein empty strings" {
    try std.testing.expectEqual(@as(usize, 5), levenshtein("hello", ""));
    try std.testing.expectEqual(@as(usize, 5), levenshtein("", "world"));
}

test "ExperienceEngine init and deinit" {
    const allocator = std.testing.allocator;
    var engine = ExperienceEngine.init(allocator);
    defer engine.deinit();

    try std.testing.expect(engine.blacklist == null);
}

test "checkBlacklist returns false for empty blacklist" {
    const allocator = std.testing.allocator;
    var engine = ExperienceEngine.init(allocator);
    defer engine.deinit();

    try std.testing.expect(!checkBlacklist(&engine, "test_task"));
}

test "cmdCheckFear returns status" {
    const allocator = std.testing.allocator;
    const result = try cmdCheckFear(allocator, "");
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "Usage") != null);
}

test "recordFailure first failure" {
    const allocator = std.testing.allocator;
    var engine = ExperienceEngine.init(allocator);
    defer engine.deinit();

    try recordFailure(&engine, "test_task", .Timeout);

    try std.testing.expect(!checkBlacklist(&engine, "test_task"));

    const info = getFailureInfo(&engine, "test_task");
    try std.testing.expect(info != null);
    if (info) |rec| {
        try std.testing.expectEqual(@as(u32, 1), rec.count);
        try std.testing.expectEqual(ErrorType.Timeout, rec.error_type);
    }
}

test "recordFailure blacklist after 3 failures" {
    const allocator = std.testing.allocator;
    var engine = ExperienceEngine.init(allocator);
    defer engine.deinit();

    try recordFailure(&engine, "bad_task", .Persistent);
    try std.testing.expect(!checkBlacklist(&engine, "bad_task"));

    try recordFailure(&engine, "bad_task", .Persistent);
    try std.testing.expect(!checkBlacklist(&engine, "bad_task"));

    try recordFailure(&engine, "bad_task", .Persistent);
    try std.testing.expect(checkBlacklist(&engine, "bad_task"));

    const info = getFailureInfo(&engine, "bad_task");
    try std.testing.expect(info != null);
    if (info) |rec| {
        try std.testing.expectEqual(@as(u32, 3), rec.count);
        try std.testing.expectEqual(ErrorType.Persistent, rec.error_type);
    }
}

test "recordFailure different error types" {
    const allocator = std.testing.allocator;
    var engine = ExperienceEngine.init(allocator);
    defer engine.deinit();

    try recordFailure(&engine, "task_a", .Duplicate);
    try recordFailure(&engine, "task_b", .Timeout);
    try recordFailure(&engine, "task_c", .Persistent);

    const info_a = getFailureInfo(&engine, "task_a");
    try std.testing.expect(info_a != null);
    try std.testing.expectEqual(ErrorType.Duplicate, info_a.?.error_type);

    const info_b = getFailureInfo(&engine, "task_b");
    try std.testing.expect(info_b != null);
    try std.testing.expectEqual(ErrorType.Timeout, info_b.?.error_type);

    const info_c = getFailureInfo(&engine, "task_c");
    try std.testing.expect(info_c != null);
    try std.testing.expectEqual(ErrorType.Persistent, info_c.?.error_type);
}

test "ErrorType toString" {
    try std.testing.expectEqualStrings("DUPLICATE", ErrorType.Duplicate.toString());
    try std.testing.expectEqualStrings("PERSISTENT", ErrorType.Persistent.toString());
    try std.testing.expectEqualStrings("TIMEOUT", ErrorType.Timeout.toString());
    try std.testing.expectEqualStrings("UNKNOWN", ErrorType.Unknown.toString());
}
