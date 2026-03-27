//! TRI Text — Generated from specs/tri/tri_text.tri
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

pub const TextMetrics = struct {
    width: usize,
    height: usize,
    lines: usize,
};

pub fn wordWrap(allocator: std.mem.Allocator, text: []const u8, width: usize) ![]u8 {
    var result = std.ArrayList(u8).initCapacity(allocator, 256);
    defer result.deinit();

    var line_len: usize = 0;
    var word_start: usize = 0;
    var in_word = false;

    for (text, 0..) |c, i| {
        if (c == ' ' or c == '\n' or c == '\t') {
            if (in_word) {
                const word = text[word_start..i];
                if (line_len > 0 and line_len + word.len > width) {
                    try result.append('\n');
                    line_len = 0;
                } else if (line_len > 0) {
                    try result.append(' ');
                    line_len += 1;
                }
                try result.appendSlice(word);
                line_len += word.len;
                in_word = false;
            }
            if (c == '\n') {
                try result.append('\n');
                line_len = 0;
            }
        } else {
            if (!in_word) {
                word_start = i;
                in_word = true;
            }
        }
    }

    // Last word
    if (in_word) {
        const word = text[word_start..];
        if (line_len > 0 and line_len + word.len > width) {
            try result.append('\n');
        } else if (line_len > 0) {
            try result.append(' ');
        }
        try result.appendSlice(word);
    }

    return try result.toOwnedSlice();
}

pub fn countWords(text: []const u8) usize {
    var count: usize = 0;
    var in_word = false;

    for (text) |c| {
        if (c == ' ' or c == '\n' or c == '\t' or c == '\r') {
            if (in_word) {
                count += 1;
                in_word = false;
            }
        } else {
            in_word = true;
        }
    }
    if (in_word) count += 1;

    return count;
}

pub fn countLines(text: []const u8) usize {
    var count: usize = 0;
    for (text) |c| {
        if (c == '\n') count += 1;
    }
    if (text.len > 0) count += 1;
    return count;
}

pub fn indent(allocator: std.mem.Allocator, text: []const u8, spaces: usize) ![]u8 {
    var result = std.ArrayList(u8).initCapacity(allocator, 256);
    defer result.deinit();

    const indent_str = [_]u8{' '} ** spaces;

    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (line.len > 0) {
            try result.appendSlice(&indent_str);
        }
        try result.appendSlice(line);
        try result.append('\n');
    }

    return try result.toOwnedSlice();
}

test "Text: countWords" {
    try std.testing.expectEqual(@as(usize, 3), countWords("hello world test"));
    try std.testing.expectEqual(@as(usize, 0), countWords(""));
}

test "Text: countLines" {
    try std.testing.expectEqual(@as(usize, 1), countLines("single"));
    try std.testing.expectEqual(@as(usize, 2), countLines("line1\nline2"));
}

test "Text: wordWrap" {
    const allocator = std.testing.allocator;
    const result = try wordWrap(allocator, "hello world", 5);
    defer allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "\n") != null);
}
