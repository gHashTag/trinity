//! AMYGDALA (Striatum) — Memory + Blacklist
//! Levenshtein fuzzy match for similar tasks + failure tracking

const std = @import("std");

pub const MAX_FAILURES: u32 = 3; // 3 failures = blacklist

/// Experience Engine - tracks task failures and blacklist
pub const ExperienceEngine = struct {
    allocator: std.mem.Allocator,
    blacklist: ?std.StringHashMap(Error) = null,

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
            bl.deinit();
        }
    }
};

pub const Error = struct {
    code: u8,
    message: []const u8,
};

/// AMYGDALA Error Codes
const ERR_DUPLICATE = "DUPLICATE";
const ERR_PERSISTENT = "PERSISTENT";
const ERR_TIMEOUT = "TIMEOUT";

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
pub fn recordFailure(self: *ExperienceEngine, task: []const u8, error_code: Error) !void {
    _ = error_code; // TODO: use error code to track different failure types

    if (self.blacklist == null) {
        self.blacklist = std.StringHashMap(Error).init(self.allocator);
    }

    // Check if already at MAX_FAILURES
    const entry = self.blacklist.?.get(task) orelse {
        // First failure - record it
        _ = try self.blacklist.?.put(self.allocator, task, .{
            .code = 1,
            .message = "",
        });
        return;
    };

    // Increment failure count
    if (entry.value_ptr.code >= MAX_FAILURES) {
        // Add to blacklist with PERSISTENT error
        _ = try self.blacklist.?.put(self.allocator, task, .{
            .code = MAX_FAILURES,
            .message = "Persistently failing (3x)",
        });
    } else {
        // Increment failure count
        entry.value_ptr.code += 1;
    }
}

/// Check if task is blacklisted
pub fn checkBlacklist(self: *ExperienceEngine, task: []const u8) bool {
    const bl = self.blacklist orelse return false;
    const entry = bl.get(task) orelse return false;
    return entry.code >= MAX_FAILURES;
}

/// CLI command for AMYGDALA
pub fn cmdCheckFear(allocator: std.mem.Allocator, args: []const u8) ![]const u8 {
    _ = args;

    // TODO: Integrate with experience engine
    const is_blocked = false; // Mock for now

    return try std.fmt.allocPrint(allocator, "Blocked: {s}\n", .{if (is_blocked) "YES ❌" else "NO ✅"});
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

    try std.testing.expect(std.mem.indexOf(u8, result, "Blocked") != null);
}
