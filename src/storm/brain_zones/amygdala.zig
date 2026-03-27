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

/// Simple Levenshtein distance calculation (no full DP, just basic)
fn levenshtein(a: []const u8, b: []const u8) usize {
    const max_len = @max(a.len, b.len);
    var matrix = [_][u8]usize;
    var i: usize = 0;
    while (i < max_len + 1) : (i + 1) {
        matrix[0][i] = 0;
    }

    var j: usize = 0;
    while (j <= b.len) : (j + 1) {
        const insert_cost = if (a[i] == b[j]) @as(u8, 1) else @as(u8, 0);
        matrix[j + 1][i] = insert_cost + matrix[j][i];
        j += 1;
    }

    // Fill diagonal
    i = 0;
    while (i <= max_len) : (i + 1) {
        const delete_cost = if (a[i - 1] == b[j]) @as(u8, 1) else @as(u8, 0);
        matrix[j + 1][i] = delete_cost + matrix[j][i];
        i += 1;
    }

    // Find minimum path (bottom-right to top-left)
    var last_row = max_len;
    var last_col = b.len + 1;
    var result = matrix[last_row][b.len];

    while (last_row > 0) {
        // Move up
        for (0..b.len) |col| {
            const cost = matrix[last_row - 1][col];
            const new_cost = cost + if (a[last_row - 1] == b[col]) @as(u8, 0) else @as(u8, 1);
            if (new_cost < matrix[last_row][col]) {
                matrix[last_row - 1][col] = new_cost;
                result = new_cost;
                last_row = last_row - 1;
                last_col = col;
            }
        }
        // Move left
        const move_left = if (a[last_row] == b[last_row - 1]) @as(u8, 1) else @as(u8, 0);
        if (move_left != 0) {
            matrix[last_row - 1][last_row - 1] = move_left;
            last_col -= 1;
        }
        last_row -= 1;
    }

    return result;
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
