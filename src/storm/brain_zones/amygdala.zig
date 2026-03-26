//! AMYGDALA (Striatum) — Memory + Blacklist
//! Levenshtein fuzzy match for similar tasks + failure tracking

const std = @import("std");
const storm = @import("../golden_chain.zig");

pub const MAX_FAILURES: u32 = 3; // 3 failures = blacklist

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
    if (self.blacklist == null) {
        self.blacklist = std.StringHashMap(Error).init(self.allocator);
    }

    const err_entry = try self.blacklist.getOrPut(self.allocator, task, .{
        .code = error_code,
        .message = "",
    });
    defer self.allocator.free(err_entry.value_ptr.message);

    // Check if already at MAX_FAILURES
    const count = self.blacklist.get(task) orelse 0;
    if (count + 1 >= MAX_FAILURES) {
        // Add to blacklist with PERSISTENT error
        _ = try self.blacklist.put(self.allocator, task, .{
            .code = ERR_PERSISTENT,
            .message = "Persistently failing (3x)",
        });
    }
}

/// Check if task is blacklisted
pub fn checkBlacklist(self: *ExperienceEngine, task: []const u8) bool {
    if (self.blacklist == null) return false;
    const entry = self.blacklist.get(task) orelse return false;
    const is_persistent = std.mem.eql(u8, entry.value_ptr.code, ERR_PERSISTENT);
    return is_persistent or entry.count > 1;
}

/// CLI command for AMYGDALA
pub fn cmdCheckFear(allocator: std.mem.Allocator, args: []const u8) !u8 {
    _ = allocator;
    _ = args;

    std.debug.print("🧠 AMYGDALA check-fear: P1 stub\n");

    // TODO: Integrate with experience engine
    const is_blocked = false; // Mock for now

    return try std.fmt.allocPrint(allocator,
        \\Blocked: {s}
    , .{if (is_blocked) "YES ❌" else "NO ✅"});
}
