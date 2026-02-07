// ═══════════════════════════════════════════════════════════════════════════════
// CODEGEN UTILS - Utility functions for code generation
// ═══════════════════════════════════════════════════════════════════════════════
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// Strip surrounding quotes from value
pub fn stripQuotes(value: []const u8) []const u8 {
    if (value.len >= 2 and value[0] == '"' and value[value.len - 1] == '"') {
        return value[1 .. value.len - 1];
    }
    return value;
}

/// Parse u64 from string
pub fn parseU64(value: []const u8) ?u64 {
    const trimmed = std.mem.trim(u8, value, " \t");
    return std.fmt.parseInt(u64, trimmed, 10) catch null;
}

/// Parse f64 from string
pub fn parseF64(value: []const u8) ?f64 {
    const trimmed = std.mem.trim(u8, value, " \t");
    return std.fmt.parseFloat(f64, trimmed) catch null;
}

/// Extract only number from string (handles comments like "65.47 # comment")
pub fn extractNumber(value: []const u8) []const u8 {
    var end: usize = 0;
    var start: usize = 0;
    while (start < value.len and (value[start] == ' ' or value[start] == '\t')) {
        start += 1;
    }
    end = start;
    if (end < value.len and value[end] == '-') {
        end += 1;
    }
    while (end < value.len and ((value[end] >= '0' and value[end] <= '9') or value[end] == '.')) {
        end += 1;
    }
    if (end > start) {
        return value[start..end];
    }
    return value;
}

/// Extract integer parameter from input like "{ n: 0 }"
pub fn extractIntParam(input: []const u8, param: []const u8) ?i32 {
    var search_buf: [64]u8 = undefined;
    const search = std.fmt.bufPrint(&search_buf, "{s}:", .{param}) catch return null;

    if (std.mem.indexOf(u8, input, search)) |idx| {
        var start = idx + search.len;
        while (start < input.len and (input[start] == ' ' or input[start] == '\t')) {
            start += 1;
        }
        var end = start;
        if (end < input.len and input[end] == '-') {
            end += 1;
        }
        while (end < input.len and input[end] >= '0' and input[end] <= '9') {
            end += 1;
        }
        if (end > start) {
            return std.fmt.parseInt(i32, input[start..end], 10) catch null;
        }
    }
    return null;
}

/// Extract float parameter from input
pub fn extractFloatParam(input: []const u8, param: []const u8) ?f64 {
    var search_buf: [64]u8 = undefined;
    const search = std.fmt.bufPrint(&search_buf, "{s}:", .{param}) catch return null;

    if (std.mem.indexOf(u8, input, search)) |idx| {
        var start = idx + search.len;
        while (start < input.len and (input[start] == ' ' or input[start] == '\t')) {
            start += 1;
        }
        var end = start;
        if (end < input.len and input[end] == '-') {
            end += 1;
        }
        while (end < input.len and ((input[end] >= '0' and input[end] <= '9') or input[end] == '.')) {
            end += 1;
        }
        if (end > start) {
            return std.fmt.parseFloat(f64, input[start..end]) catch null;
        }
    }
    return null;
}

/// Escape Zig reserved words (error, type, etc.)
pub fn escapeReservedWord(name: []const u8) []const u8 {
    if (std.mem.eql(u8, name, "error")) return "@\"error\"";
    if (std.mem.eql(u8, name, "type")) return "@\"type\"";
    if (std.mem.eql(u8, name, "return")) return "@\"return\"";
    if (std.mem.eql(u8, name, "break")) return "@\"break\"";
    if (std.mem.eql(u8, name, "continue")) return "@\"continue\"";
    if (std.mem.eql(u8, name, "if")) return "@\"if\"";
    if (std.mem.eql(u8, name, "else")) return "@\"else\"";
    if (std.mem.eql(u8, name, "while")) return "@\"while\"";
    if (std.mem.eql(u8, name, "for")) return "@\"for\"";
    if (std.mem.eql(u8, name, "fn")) return "@\"fn\"";
    if (std.mem.eql(u8, name, "const")) return "@\"const\"";
    if (std.mem.eql(u8, name, "var")) return "@\"var\"";
    if (std.mem.eql(u8, name, "pub")) return "@\"pub\"";
    if (std.mem.eql(u8, name, "try")) return "@\"try\"";
    if (std.mem.eql(u8, name, "catch")) return "@\"catch\"";
    return name;
}

/// Clean type name (remove comments, default values, union types)
pub fn cleanTypeName(type_name: []const u8) []const u8 {
    var result = type_name;

    // Remove comments (# ...)
    if (std.mem.indexOf(u8, result, "#")) |pos| {
        result = result[0..pos];
    }

    // Remove default values (= "...")
    if (std.mem.indexOf(u8, result, "=")) |pos| {
        result = result[0..pos];
    }

    // Handle union types (A | B) -> use first type
    if (std.mem.indexOf(u8, result, "|")) |pos| {
        result = result[0..pos];
    }

    return std.mem.trim(u8, result, " \t");
}

/// Map VIBEE type to Zig type
pub fn mapType(type_name: []const u8) []const u8 {
    // Primitive types
    if (std.mem.eql(u8, type_name, "f64")) return "f64";
    if (std.mem.eql(u8, type_name, "f32")) return "f32";
    if (std.mem.eql(u8, type_name, "i32")) return "i32";
    if (std.mem.eql(u8, type_name, "i64")) return "i64";
    if (std.mem.eql(u8, type_name, "u32")) return "u32";
    if (std.mem.eql(u8, type_name, "u64")) return "u64";
    if (std.mem.eql(u8, type_name, "bool")) return "bool";

    // VIBEE types -> Zig types
    if (std.mem.eql(u8, type_name, "String")) return "[]const u8";
    if (std.mem.eql(u8, type_name, "Int")) return "i64";
    if (std.mem.eql(u8, type_name, "Float")) return "f64";
    if (std.mem.eql(u8, type_name, "Bool")) return "bool";
    if (std.mem.eql(u8, type_name, "Bytes")) return "[]const u8";
    if (std.mem.eql(u8, type_name, "Timestamp")) return "i64";
    if (std.mem.eql(u8, type_name, "Duration")) return "i64";
    if (std.mem.eql(u8, type_name, "Any")) return "[]const u8";
    if (std.mem.eql(u8, type_name, "Void")) return "void";
    if (std.mem.eql(u8, type_name, "Error")) return "anyerror";

    // Generic types Option<T> -> ?T
    if (std.mem.startsWith(u8, type_name, "Option<")) {
        return "?[]const u8";
    }

    // Generic types List<T> -> []T
    if (std.mem.startsWith(u8, type_name, "List<")) {
        return "[]const u8";
    }

    // Plain List type -> slice
    if (std.mem.eql(u8, type_name, "List")) {
        return "[]const u8";
    }

    // Generic types Map<K,V> -> std.StringHashMap
    if (std.mem.startsWith(u8, type_name, "Map<")) {
        return "std.StringHashMap([]const u8)";
    }

    // Plain Map type -> std.StringHashMap
    if (std.mem.eql(u8, type_name, "Map")) {
        return "std.StringHashMap([]const u8)";
    }

    // Handle trailing ? (nullable)
    if (type_name.len > 0 and type_name[type_name.len - 1] == '?') {
        return "?[]const u8";
    }

    // Object type
    if (std.mem.eql(u8, type_name, "Object")) {
        return "[]const u8";
    }

    // Unknown complex types -> []const u8
    if (std.mem.eql(u8, type_name, "JsonSchema")) return "[]const u8";
    if (std.mem.eql(u8, type_name, "Role")) return "[]const u8";
    if (std.mem.eql(u8, type_name, "PluginManifest")) return "[]const u8";
    if (std.mem.eql(u8, type_name, "PluginConfig")) return "[]const u8";
    if (std.mem.eql(u8, type_name, "StreamEvent")) return "[]const u8";
    if (std.mem.eql(u8, type_name, "TokenStats")) return "[]const u8";

    return type_name;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "stripQuotes" {
    try std.testing.expectEqualStrings("hello", stripQuotes("\"hello\""));
    try std.testing.expectEqualStrings("hello", stripQuotes("hello"));
}

test "parseU64" {
    try std.testing.expectEqual(@as(?u64, 123), parseU64("123"));
    try std.testing.expectEqual(@as(?u64, 42), parseU64("  42  "));
    try std.testing.expectEqual(@as(?u64, null), parseU64("abc"));
}

test "extractIntParam" {
    try std.testing.expectEqual(@as(?i32, 5), extractIntParam("{ n: 5 }", "n"));
    try std.testing.expectEqual(@as(?i32, -3), extractIntParam("{ n: -3 }", "n"));
    try std.testing.expectEqual(@as(?i32, null), extractIntParam("{ x: 5 }", "n"));
}

test "mapType" {
    try std.testing.expectEqualStrings("[]const u8", mapType("String"));
    try std.testing.expectEqualStrings("i64", mapType("Int"));
    try std.testing.expectEqualStrings("f64", mapType("f64"));
}
