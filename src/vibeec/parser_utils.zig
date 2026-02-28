// ═══════════════════════════════════════════════════════════════════════════════
// PARSER UTILS — Stateless String Scanning Utilities
// ═══════════════════════════════════════════════════════════════════════════════
//
// Cycle 84: IGLA Phase 4 — Parser migration
// Source of truth: specs/tri/holy_core_parser_phase1.tri
//
// Pure functions extracted from vibee_parser.zig.
// All functions take (source, pos, line) and return updated state.
// No allocator, no side effects — just string scanning.
//
// IGLA ([CYR:Игла]) — уtoол, убandin[CYR:ающ]andй [CYR:ручной] code
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Parser scanning state — position and line number
pub const ScanState = struct {
    pos: usize,
    line: usize,
};

/// Result of reading a key or value — slice + updated position
pub const ReadResult = struct {
    key: []const u8,
    new_pos: usize,
};

/// Result of reading a value — slice + updated position
pub const ValueResult = struct {
    value: []const u8,
    new_pos: usize,
};

/// Result of reading a value with line tracking
pub const ValueLineResult = struct {
    value: []const u8,
    new_pos: usize,
    new_line: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// WHITESPACE SKIPPING
// ═══════════════════════════════════════════════════════════════════════════════

/// Skip spaces and tabs on the current line only (no newlines).
pub fn skipInlineWhitespace(source: []const u8, pos: usize) usize {
    var p = pos;
    while (p < source.len) {
        const c = source[p];
        if (c == ' ' or c == '\t') {
            p += 1;
        } else {
            break;
        }
    }
    return p;
}

/// Skip all whitespace, newlines and comment lines.
pub fn skipWhitespaceAndComments(source: []const u8, pos: usize, line: usize) ScanState {
    var p = pos;
    var l = line;
    while (p < source.len) {
        const c = source[p];
        if (c == ' ' or c == '\t' or c == '\r') {
            p += 1;
        } else if (c == '\n') {
            p += 1;
            l += 1;
        } else if (c == '#') {
            while (p < source.len and source[p] != '\n') {
                p += 1;
            }
        } else {
            break;
        }
    }
    return .{ .pos = p, .line = l };
}

/// Advance to the start of the next line.
pub fn skipToNextLine(source: []const u8, pos: usize, line: usize) ScanState {
    var p = pos;
    var l = line;
    while (p < source.len and source[p] != '\n') {
        p += 1;
    }
    if (p < source.len) {
        p += 1;
        l += 1;
    }
    return .{ .pos = p, .line = l };
}

/// Skip current line (alias for skipToNextLine).
pub fn skipLine(source: []const u8, pos: usize, line: usize) ScanState {
    return skipToNextLine(source, pos, line);
}

/// Skip blank lines and comment-only lines.
pub fn skipEmptyLinesAndComments(source: []const u8, pos: usize, line: usize) ScanState {
    var p = pos;
    var l = line;
    while (p < source.len) {
        if (source[p] == '\n') {
            p += 1;
            l += 1;
            continue;
        }
        const line_start = p;
        while (p < source.len and source[p] == ' ') {
            p += 1;
        }
        if (p < source.len and source[p] == '#') {
            const s = skipToNextLine(source, p, l);
            p = s.pos;
            l = s.line;
            continue;
        }
        if (p < source.len and source[p] == '\n') {
            p += 1;
            l += 1;
            continue;
        }
        p = line_start;
        break;
    }
    return .{ .pos = p, .line = l };
}

// ═══════════════════════════════════════════════════════════════════════════════
// READING
// ═══════════════════════════════════════════════════════════════════════════════

/// Read a YAML-like key (identifier before colon).
pub fn readKey(source: []const u8, pos: usize) ReadResult {
    const start = pos;
    var p = pos;
    while (p < source.len) {
        const c = source[p];
        if (c == ':' or c == ' ' or c == '\n' or c == '\r') break;
        p += 1;
    }
    return .{ .key = source[start..p], .new_pos = p };
}

/// Skip optional colon separator with surrounding whitespace.
pub fn skipColon(source: []const u8, pos: usize) usize {
    var p = skipInlineWhitespace(source, pos);
    if (p < source.len and source[p] == ':') {
        p += 1;
    }
    p = skipInlineWhitespace(source, p);
    return p;
}

/// Read a value until end of line or comment, trimming trailing whitespace.
pub fn readValue(source: []const u8, pos: usize) ValueResult {
    var p = skipInlineWhitespace(source, pos);
    const start = p;
    while (p < source.len) {
        const c = source[p];
        if (c == '\n' or c == '\r') break;
        if (c == '#') break;
        p += 1;
    }
    return .{ .value = std.mem.trim(u8, source[start..p], " \t"), .new_pos = p };
}

/// Read a quoted string value, or fall back to readValue.
pub fn readQuotedValue(source: []const u8, pos: usize) ValueResult {
    var p = skipInlineWhitespace(source, pos);
    if (p < source.len and source[p] == '"') {
        p += 1;
        const start = p;
        while (p < source.len and source[p] != '"') {
            p += 1;
        }
        const value = source[start..p];
        if (p < source.len) p += 1;
        return .{ .value = value, .new_pos = p };
    }
    return readValue(source, p);
}

/// Read either a quoted string or a plain value (skips whitespace/comments first).
pub fn readQuotedOrValue(source: []const u8, pos: usize, line: usize) ValueLineResult {
    const s = skipWhitespaceAndComments(source, pos, line);
    if (s.pos < source.len and source[s.pos] == '"') {
        const r = readQuotedValue(source, s.pos);
        return .{ .value = r.value, .new_pos = r.new_pos, .new_line = s.line };
    }
    const r = readValue(source, s.pos);
    return .{ .value = r.value, .new_pos = r.new_pos, .new_line = s.line };
}

// ═══════════════════════════════════════════════════════════════════════════════
// INDENTATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Count leading spaces at current position (read-only peek, does NOT advance).
pub fn countIndent(source: []const u8, pos: usize) usize {
    var count: usize = 0;
    var p = pos;
    while (p < source.len and source[p] == ' ') {
        count += 1;
        p += 1;
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BLOCK SKIPPING
// ═══════════════════════════════════════════════════════════════════════════════

/// Skip an indented block (all lines with deeper indent than current).
pub fn skipBlock(source: []const u8, pos: usize, line: usize) ScanState {
    const base_indent = countIndent(source, pos);
    var s = skipLine(source, pos, line);
    while (s.pos < source.len) {
        const indent = countIndent(source, s.pos);
        if (indent <= base_indent) break;
        s = skipLine(source, s.pos, s.line);
    }
    return s;
}

/// Skip nested content with indent greater than minimum.
pub fn skipNestedBlock(source: []const u8, pos: usize, line: usize, min_indent: usize) ScanState {
    var s = ScanState{ .pos = pos, .line = line };
    while (s.pos < source.len) {
        const indent = countIndent(source, s.pos);
        if (indent <= min_indent) break;
        s = skipToNextLine(source, s.pos, s.line);
    }
    return s;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BRACE PARSING
// ═══════════════════════════════════════════════════════════════════════════════

/// Read a brace-delimited value with depth tracking, or fall back to readValue.
pub fn readBraceValue(source: []const u8, pos: usize, line: usize) ValueLineResult {
    const s = skipWhitespaceAndComments(source, pos, line);
    if (s.pos < source.len and source[s.pos] == '{') {
        const start = s.pos;
        var depth: usize = 0;
        var p = s.pos;
        while (p < source.len) {
            const c = source[p];
            if (c == '{') depth += 1;
            if (c == '}') {
                depth -= 1;
                if (depth == 0) {
                    p += 1;
                    return .{ .value = source[start..p], .new_pos = p, .new_line = s.line };
                }
            }
            p += 1;
        }
        return .{ .value = source[start..p], .new_pos = p, .new_line = s.line };
    }
    const r = readValue(source, s.pos);
    return .{ .value = r.value, .new_pos = r.new_pos, .new_line = s.line };
}

// ═══════════════════════════════════════════════════════════════════════════════
// MULTILINE BLOCK
// ═══════════════════════════════════════════════════════════════════════════════

/// Read a YAML multiline block (pipe indicator or indented).
pub fn readMultilineBlock(source: []const u8, pos: usize, line: usize) ValueLineResult {
    var s = skipWhitespaceAndComments(source, pos, line);
    if (s.pos < source.len and source[s.pos] == '|') {
        s.pos += 1;
        s = skipToNextLine(source, s.pos, s.line);
    }
    const start = s.pos;
    const base_indent = countIndent(source, s.pos);

    while (s.pos < source.len) {
        const line_start = s.pos;

        var is_empty = false;
        var p = s.pos;
        while (p < source.len and source[p] == ' ') : (p += 1) {}
        if (p < source.len and source[p] == '\n') is_empty = true;

        if (is_empty) {
            s = skipToNextLine(source, s.pos, s.line);
            continue;
        }

        const indent = countIndent(source, s.pos);
        if (indent < base_indent and s.pos > start) {
            return .{ .value = source[start..line_start], .new_pos = line_start, .new_line = s.line };
        }
        s = skipToNextLine(source, s.pos, s.line);
    }
    return .{ .value = source[start..s.pos], .new_pos = s.pos, .new_line = s.line };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "skipInlineWhitespace skips spaces and tabs" {
    const source = "   \thello";
    const result = skipInlineWhitespace(source, 0);
    try std.testing.expectEqual(@as(usize, 4), result);
    try std.testing.expectEqual(@as(u8, 'h'), source[result]);
}

test "skipInlineWhitespace stops at newline" {
    const source = "  \nworld";
    const result = skipInlineWhitespace(source, 0);
    try std.testing.expectEqual(@as(usize, 2), result);
    try std.testing.expectEqual(@as(u8, '\n'), source[result]);
}

test "skipWhitespaceAndComments skips comments" {
    const source = "  # comment\nhello";
    const s = skipWhitespaceAndComments(source, 0, 1);
    try std.testing.expectEqual(@as(usize, 12), s.pos);
    try std.testing.expectEqual(@as(usize, 2), s.line);
    try std.testing.expectEqual(@as(u8, 'h'), source[s.pos]);
}

test "skipToNextLine advances past newline" {
    const source = "hello\nworld";
    const s = skipToNextLine(source, 0, 1);
    try std.testing.expectEqual(@as(usize, 6), s.pos);
    try std.testing.expectEqual(@as(usize, 2), s.line);
}

test "skipEmptyLinesAndComments skips blanks and comments" {
    const source = "\n\n  # comment\nhello";
    const s = skipEmptyLinesAndComments(source, 0, 1);
    try std.testing.expectEqual(@as(u8, 'h'), source[s.pos]);
    try std.testing.expectEqual(@as(usize, 4), s.line);
}

test "readKey reads until colon" {
    const source = "name: value";
    const r = readKey(source, 0);
    try std.testing.expectEqualStrings("name", r.key);
    try std.testing.expectEqual(@as(usize, 4), r.new_pos);
}

test "skipColon skips colon with whitespace" {
    const source = " : value";
    const p = skipColon(source, 0);
    try std.testing.expectEqual(@as(u8, 'v'), source[p]);
}

test "readValue reads until newline trimmed" {
    const source = " hello world  \n";
    const r = readValue(source, 0);
    try std.testing.expectEqualStrings("hello world", r.value);
}

test "readValue stops at comment" {
    const source = "value # comment\n";
    const r = readValue(source, 0);
    try std.testing.expectEqualStrings("value", r.value);
}

test "readQuotedValue reads quoted string" {
    const source = "\"hello world\"";
    const r = readQuotedValue(source, 0);
    try std.testing.expectEqualStrings("hello world", r.value);
}

test "readQuotedValue falls back to readValue" {
    const source = "plain value\n";
    const r = readQuotedValue(source, 0);
    try std.testing.expectEqualStrings("plain value", r.value);
}

test "countIndent counts spaces" {
    const source = "    hello";
    const count = countIndent(source, 0);
    try std.testing.expectEqual(@as(usize, 4), count);
}

test "skipBlock skips indented block" {
    const source = "parent:\n  child1\n  child2\nsibling";
    const s = skipBlock(source, 0, 1);
    try std.testing.expectEqual(@as(u8, 's'), source[s.pos]);
}

test "skipNestedBlock skips deeper indent" {
    const source = "      deep\n      deep2\n    less\n";
    const s = skipNestedBlock(source, 0, 1, 4);
    try std.testing.expectEqualStrings("    less\n", source[s.pos..]);
}

test "readBraceValue reads braces" {
    const source = "{a: 1, b: 2}";
    const r = readBraceValue(source, 0, 1);
    try std.testing.expectEqualStrings("{a: 1, b: 2}", r.value);
}

test "readMultilineBlock reads pipe block" {
    const source = "|\n      line1\n      line2\n  end";
    const r = readMultilineBlock(source, 0, 1);
    try std.testing.expectEqualStrings("      line1\n      line2\n", r.value);
}
