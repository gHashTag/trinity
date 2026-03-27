//! tri/match — Pattern matching with exhaustiveness checking
//! Auto-generated from specs/tri/tri_match.tri
//! TTT Dogfood v0.2 Stage 67

const std = @import("std");

/// Captured value from match
pub const MatchCapture = struct {
    name: []const u8,
    value: []const u8,
};

/// Pattern match result
pub const Match = struct {
    matched: bool,
    captures: std.ArrayList(MatchCapture),

    pub fn init(allocator: std.mem.Allocator) Match {
        return .{
            .matched = false,
            .captures = std.ArrayList(MatchCapture).init(allocator),
        };
    }

    pub fn deinit(self: *Match) void {
        self.captures.deinit();
    }
};

/// Match literal string pattern
/// Supports wildcards: * matches any sequence, ? matches any single character
pub fn matchLiteral(input: []const u8, pattern: []const u8) !bool {
    if (pattern.len == 0) return input.len == 0;

    // Fast path: no wildcards
    if (std.mem.indexOfScalar(u8, pattern, '*') == null and
        std.mem.indexOfScalar(u8, pattern, '?') == null)
    {
        return std.mem.eql(u8, input, pattern);
    }

    // Wildcard matching
    var pat_idx: usize = 0;
    var inp_idx: usize = 0;
    var backtrack_pat: usize = 0;
    var backtrack_inp: usize = 0;
    var found_star = false;

    while (inp_idx < input.len) {
        if (pat_idx < pattern.len and pattern[pat_idx] == '*') {
            found_star = true;
            backtrack_pat = pat_idx;
            backtrack_inp = inp_idx + 1;
            pat_idx += 1;
        } else if (pat_idx < pattern.len and (pattern[pat_idx] == input[inp_idx] or pattern[pat_idx] == '?')) {
            pat_idx += 1;
            inp_idx += 1;
        } else if (found_star) {
            pat_idx = backtrack_pat + 1; // Skip the star
            inp_idx = backtrack_inp;
            backtrack_inp += 1;
        } else {
            return false;
        }
    }

    // Handle trailing wildcards
    while (pat_idx < pattern.len and (pattern[pat_idx] == '*' or pattern[pat_idx] == '?')) {
        pat_idx += 1;
    }

    return pat_idx == pattern.len;
}

/// Check if value matches type name
/// This is a simplified type check for basic types
pub fn matchType(type_name: []const u8, value: anytype) bool {
    const T = @TypeOf(value);

    // Handle common type name mappings
    if (std.mem.eql(u8, type_name, "int")) {
        return switch (@typeInfo(T)) {
            .int, .comptime_int => true,
            else => false,
        };
    }
    if (std.mem.eql(u8, type_name, "float")) {
        return switch (@typeInfo(T)) {
            .float, .comptime_float => true,
            else => false,
        };
    }
    if (std.mem.eql(u8, type_name, "bool")) {
        return T == bool;
    }
    if (std.mem.eql(u8, type_name, "string")) {
        // String literals are *const u8, slices are []const u8
        return switch (@typeInfo(T)) {
            .pointer => |ptr| ptr.size == .slice and ptr.child == u8,
            else => false,
        };
    }
    if (std.mem.eql(u8, type_name, "slice")) {
        return switch (@typeInfo(T)) {
            .pointer => |ptr| ptr.size == .slice,
            else => false,
        };
    }

    // Exact type name match
    return std.mem.indexOf(u8, @typeName(T), type_name) != null;
}

/// Check if all cases are handled
pub fn exhaustive(cases: []const []const u8, handled: []const bool) bool {
    if (cases.len != handled.len) return false;

    for (handled) |h| {
        if (!h) return false;
    }
    return true;
}

/// Pattern match enum value
pub fn matchEnum(comptime E: type, value: E, case_names: []const []const u8) bool {
    const enum_name = @tagName(value);
    for (case_names) |case| {
        if (std.mem.eql(u8, case, enum_name) or std.mem.eql(u8, case, "*")) {
            return true;
        }
    }
    return false;
}

/// Match value against multiple patterns
pub fn matchAny(input: []const u8, patterns: []const []const u8) !bool {
    for (patterns) |pattern| {
        if (try matchLiteral(input, pattern)) {
            return true;
        }
    }
    return false;
}

test "matchLiteral exact match" {
    const result = try matchLiteral("hello", "hello");
    try std.testing.expect(result);
}

test "matchLiteral no match" {
    const result = try matchLiteral("hello", "world");
    try std.testing.expect(!result);
}

test "matchLiteral wildcard" {
    const result = try matchLiteral("hello world", "hello*");
    try std.testing.expect(result);
}

test "matchLiteral wildcard middle" {
    const result = try matchLiteral("hello world test", "hello*test");
    try std.testing.expect(result);
}

test "matchLiteral multiple wildcards" {
    const result = try matchLiteral("abc123def", "****");
    try std.testing.expect(result);
}

test "matchLiteral question mark" {
    const result = try matchLiteral("hello", "h?llo");
    try std.testing.expect(result);
}

test "matchLiteral empty strings" {
    const result = try matchLiteral("", "");
    try std.testing.expect(result);
}

test "matchType int" {
    try std.testing.expect(matchType("int", @as(i32, 42)));
    try std.testing.expect(matchType("int", @as(u64, 10)));
}

test "matchType float" {
    try std.testing.expect(matchType("float", @as(f64, 3.14)));
    try std.testing.expect(matchType("float", @as(f32, 2.0)));
}

test "matchType bool" {
    try std.testing.expect(matchType("bool", true));
    try std.testing.expect(matchType("bool", false));
    try std.testing.expect(!matchType("bool", @as(i32, 1)));
}

test "matchType string" {
    const slice: []const u8 = "test";
    try std.testing.expect(matchType("string", slice));
}

test "matchType slice" {
    const array = [_]i32{ 1, 2, 3 };
    const slice: []const i32 = &array;
    try std.testing.expect(matchType("slice", slice));
}

test "exhaustive all handled" {
    const cases = [_][]const u8{ "a", "b", "c" };
    const handled = [_]bool{ true, true, true };
    try std.testing.expect(exhaustive(&cases, &handled));
}

test "exhaustive missing case" {
    const cases = [_][]const u8{ "a", "b", "c" };
    const handled = [_]bool{ true, false, true };
    try std.testing.expect(!exhaustive(&cases, &handled));
}

test "exhaustive length mismatch" {
    const cases = [_][]const u8{ "a", "b" };
    const handled = [_]bool{ true, true, true };
    try std.testing.expect(!exhaustive(&cases, &handled));
}

test "matchEnum exact match" {
    const TestEnum = enum { a, b, c };
    const cases = [_][]const u8{ "a", "b" };
    try std.testing.expect(matchEnum(TestEnum, .a, &cases));
    try std.testing.expect(matchEnum(TestEnum, .b, &cases));
    try std.testing.expect(!matchEnum(TestEnum, .c, &cases));
}

test "matchEnum wildcard" {
    const TestEnum = enum { a, b, c };
    const cases = [_][]const u8{"*"};
    try std.testing.expect(matchEnum(TestEnum, .a, &cases));
    try std.testing.expect(matchEnum(TestEnum, .b, &cases));
    try std.testing.expect(matchEnum(TestEnum, .c, &cases));
}

test "matchAny matches" {
    const patterns = [_][]const u8{ "hello*", "*world", "test" };
    try std.testing.expect(try matchAny("hello there", &patterns));
    try std.testing.expect(try matchAny("hi world", &patterns));
    try std.testing.expect(try matchAny("test", &patterns));
}

test "matchAny no match" {
    const patterns = [_][]const u8{ "hello*", "*world" };
    try std.testing.expect(!try matchAny("foo bar", &patterns));
}
