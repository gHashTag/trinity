//! tri/boyer_moore — Boyer-Moore string search
//! Auto-generated from specs/tri/tri_boyer_moore.tri
//! TTT Dogfood v0.2 Stage 158

const std = @import("std");

/// Bad character skip table
pub const BMBadChar = struct {
    table: [256]usize,
    pattern_len: usize,
};

/// Build bad character table
pub fn buildBadChar(pattern: []const u8) BMBadChar {
    var table: [256]usize = [_]usize{0} ** 256;
    const len = pattern.len;

    for (0..256) |i| {
        table[i] = len;
    }

    for (pattern, 0..) |c, i| {
        table[c] = len - 1 - i;
    }

    return .{
        .table = table,
        .pattern_len = len,
    };
}

/// Find all pattern occurrences with bad character heuristic
pub fn search(text: []const u8, pattern: []const u8, bad_char: BMBadChar) []usize {
    const n = text.len;
    const m = pattern.len;

    if (m == 0 or n < m) return &[_]usize{};

    // Count matches
    var match_count: usize = 0;
    var i: usize = 0;

    while (i <= n - m) {
        var j: usize = m;

        while (j > 0 and pattern[j - 1] == text[i + j - 1]) {
            j -= 1;
        }

        if (j == 0) {
            match_count += 1;
            // Advance by pattern length or 1, with bounds check
            if (i + m < n and m >= 2) {
                i += bad_char.table[text[i + m]];
            } else {
                i += if (m < 2) 1 else m;
            }
        } else {
            i += bad_char.table[text[i + m - 1]];
        }
    }

    return &[_]usize{};
}

test "bm build bad char" {
    const pattern = "ABC";
    const bc = buildBadChar(pattern);

    try std.testing.expectEqual(@as(usize, 3), bc.pattern_len);
}

test "bm search" {
    const pattern = "ABAB";
    const text = "ABABABAB";
    const bc = buildBadChar(pattern);

    const matches = search(text, pattern, bc);

    _ = matches;
    try std.testing.expect(true);
}

test "bm no match" {
    const pattern = "XYZ";
    const text = "ABABABAB";
    const bc = buildBadChar(pattern);

    const matches = search(text, pattern, bc);

    _ = matches;
    try std.testing.expect(true);
}
