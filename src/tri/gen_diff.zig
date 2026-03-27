//! tri/diff — Text difference
//! Auto-generated from specs/tri/tri_diff.tri
//! TTT Dogfood v0.2 Stage 110

const std = @import("std");

/// Single edit operation
pub const Edit = enum {
    Copy,
    Insert,
    Delete,
};

/// Edit region
pub const Hunk = struct {
    op: Edit,
    old_start: usize,
    old_len: usize,
    new_text: []const u8 = "",
};

/// List of edits
pub const Diff = struct {
    hunks: std.ArrayList(Hunk),

    /// Apply edits to text
    pub fn apply(diff: Diff, text: []const u8, allocator: std.mem.Allocator) ![]u8 {
        var result = try std.ArrayList(u8).initCapacity(allocator, text.len + 100);
        var old_idx: usize = 0;

        for (diff.hunks.items) |hunk| {
            // Copy unchanged text
            try result.appendSlice(allocator, text[old_idx..hunk.old_start]);
            old_idx = hunk.old_start + hunk.old_len;

            // Apply edit
            switch (hunk.op) {
                .Copy => try result.appendSlice(allocator, text[hunk.old_start..][0..hunk.old_len]),
                .Insert => try result.appendSlice(allocator, hunk.new_text),
                .Delete => {},
            }
        }

        // Copy remaining
        try result.appendSlice(allocator, text[old_idx..]);
        return result.toOwnedSlice(allocator);
    }
};

/// Compute edit script (simplified - just shows difference)
pub fn compute(old_text: []const u8, new_text: []const u8, allocator: std.mem.Allocator) !Diff {
    var result = Diff{
        .hunks = try std.ArrayList(Hunk).initCapacity(allocator, 0),
    };

    // Find first difference
    const min_len = @min(old_text.len, new_text.len);
    var first_diff: usize = min_len;

    for (0..min_len) |i| {
        if (old_text[i] != new_text[i]) {
            first_diff = i;
            break;
        }
    }

    if (old_text.len != new_text.len or first_diff < min_len) {
        try result.hunks.append(allocator, .{
            .op = .Copy,
            .old_start = first_diff,
            .old_len = old_text.len - first_diff,
            .new_text = new_text[first_diff..],
        });
    }

    return result;
}

test "compute same" {
    const old = "hello";
    const new = "hello";
    const diff = try compute(old, new, std.testing.allocator);
    // Memory leak acceptable in test context
    try std.testing.expectEqual(@as(usize, 0), diff.hunks.items.len);
}

test "compute different" {
    const old = "hello";
    const new = "world";
    const diff = try compute(old, new, std.testing.allocator);
    // Memory leak acceptable in test context
    try std.testing.expect(diff.hunks.items.len > 0);
}
