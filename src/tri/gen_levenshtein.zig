//! tri/levenshtein — Edit distance
//! Auto-generated from specs/tri/tri_levenshtein.tri
//! TTT Dogfood v0.2 Stage 159

const std = @import("std");

/// Edit operation type
pub const EditOp = enum {
    INSERT,
    DELETE,
    SUBSTITUTE,
    MATCH,
};

/// Edit path with operations
pub const EditPath = struct {
    ops: []EditOp,
    distance: usize,
    allocator: std.mem.Allocator,

    /// Free resources
    pub fn deinit(self: *EditPath) void {
        self.allocator.free(self.ops);
    }
};

/// Compute minimum edit distance
pub fn distance(a: []const u8, b: []const u8, allocator: std.mem.Allocator) !usize {
    const m = a.len;
    const n = b.len;

    if (m == 0) return n;
    if (n == 0) return m;

    // Use smaller dimension for space optimization
    const prev = try allocator.alloc(usize, n + 1);
    defer allocator.free(prev);
    const curr = try allocator.alloc(usize, n + 1);
    defer allocator.free(curr);

    for (0..n + 1) |j| {
        prev[j] = j;
    }

    for (1..m + 1) |i| {
        curr[0] = i;

        for (1..n + 1) |j| {
            const cost = if (a[i - 1] == b[j - 1]) @as(usize, 0) else 1;

            curr[j] = @min(
                @min(curr[j - 1] + 1, prev[j] + 1),
                prev[j - 1] + cost,
            );
        }

        // Swap
        const tmp = prev;
        _ = @memcpy(curr[0..], prev[0..]);
        _ = @memcpy(tmp[0..], curr[0..]);
    }

    return prev[n];
}

/// Compute edit path with operations
pub fn computeAlign(a: []const u8, b: []const u8, allocator: std.mem.Allocator) !EditPath {
    const dist = try distance(a, b, allocator);

    // Simplified: return placeholder
    const ops = try allocator.alloc(EditOp, 1);
    ops[0] = .MATCH;

    return .{
        .ops = ops,
        .distance = dist,
        .allocator = allocator,
    };
}

test "levenshtein empty" {
    const d = try distance("", "", std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), d);
}

test "levenshtein identical" {
    const d = try distance("abc", "abc", std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), d);
}

test "levenshtein insert" {
    const d = try distance("abc", "abcd", std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), d);
}

test "levenshtein delete" {
    const d = try distance("abcd", "abc", std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), d);
}

test "levenshtein substitute" {
    const d = try distance("abc", "axc", std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), d);
}

test "levenshtein complex" {
    const d = try distance("kitten", "sitting", std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 3), d);
}
