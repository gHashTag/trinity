// ═══════════════════════════════════════════════════════════════════════════════
// CODEGEN UTILS FIX - Proper generic type handling
// ═══════════════════════════════════════════════════════════════════════════════
//
// This is a patch for utils.zig to fix generic type mapping
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// Extract inner type from generic type like "List<Float>" -> "Float"
pub fn extractInnerType(composite: []const u8, prefix: []const u8, suffix: []const u8) []const u8 {
    // Check if starts with prefix
    if (!std.mem.startsWith(u8, composite, prefix)) {
        return composite;
    }

    // Find the suffix (closing >)
    const start = prefix.len;
    const end = std.mem.indexOf(u8, composite[start..], suffix) orelse return composite;

    return std.mem.trim(u8, composite[start..][0..end], " ");
}

/// Map VIBEE type to Zig type with proper generic handling
pub fn mapTypeFixed(type_name: []const u8) []const u8 {

    // Primitive types
    if (std.mem.eql(u8, type_name, "f64")) return "f64";
    if (std.mem.eql(u8, type_name, "f32")) return "f32";
    if (std.mem.eql(u8, type_name, "i32")) return "i32";
    if (std.mem.eql(u8, type_name, "i64")) return "i64";
    if (std.mem.eql(u8, type_name, "u32")) return "u32";
    if (std.mem.eql(u8, type_name, "u64")) return "u64";
    if (std.mem.eql(u8, type_name, "usize")) return "usize";
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
    if (std.mem.eql(u8, type_name, "UInt")) return "u32";
    if (std.mem.eql(u8, type_name, "UInt64")) return "u64";
    if (std.mem.eql(u8, type_name, "UInt32")) return "u32";
    if (std.mem.eql(u8, type_name, "UInt16")) return "u16";
    if (std.mem.eql(u8, type_name, "UInt8")) return "u8";
    if (std.mem.eql(u8, type_name, "UInt4")) return "u4";
    if (std.mem.eql(u8, type_name, "Int64")) return "i64";
    if (std.mem.eql(u8, type_name, "Int32")) return "i32";
    if (std.mem.eql(u8, type_name, "Int16")) return "i16";
    if (std.mem.eql(u8, type_name, "Int8")) return "i8";

    // Allocator
    if (std.mem.eql(u8, type_name, "Allocator")) return "std.mem.Allocator";

    // Generic types List<T> -> []T
    if (std.mem.startsWith(u8, type_name, "List<")) {
        const inner = extractInnerType(type_name, "List<", ">");
        const inner_zig = mapTypeFixed(inner);
        // For now, return slice type
        // In full implementation, would allocate proper string
        if (std.mem.eql(u8, inner_zig, "f64")) return "[]f64";
        if (std.mem.eql(u8, inner_zig, "f32")) return "[]f32";
        if (std.mem.eql(u8, inner_zig, "i64")) return "[]i64";
        if (std.mem.eql(u8, inner_zig, "usize")) return "[]usize";
        if (std.mem.eql(u8, inner_zig, "bool")) return "[]bool";
        if (std.mem.eql(u8, inner_zig, "[]const u8")) return "[]const []const u8";
        return "[]const u8"; // fallback
    }

    // Plain List type -> slice
    if (std.mem.eql(u8, type_name, "List")) {
        return "[]const u8";
    }

    // Generic types Option<T> -> ?T
    if (std.mem.startsWith(u8, type_name, "Option<")) {
        const inner = extractInnerType(type_name, "Option<", ">");
        const inner_zig = mapTypeFixed(inner);
        // For now, return optional type
        if (std.mem.eql(u8, inner_zig, "f64")) return "?f64";
        if (std.mem.eql(u8, inner_zig, "f32")) return "?f32";
        if (std.mem.eql(u8, inner_zig, "i64")) return "?i64";
        if (std.mem.eql(u8, inner_zig, "usize")) return "?usize";
        if (std.mem.eql(u8, inner_zig, "bool")) return "?bool";
        if (std.mem.eql(u8, inner_zig, "[]f64")) return "?[]f64";
        if (std.mem.eql(u8, inner_zig, "[]const u8")) return "?[]const u8";
        return "?[]const u8"; // fallback
    }

    // HashMap<K,V>
    if (std.mem.startsWith(u8, type_name, "HashMap<")) {
        return "std.AutoHashMap(usize, *anyopaque)";
    }

    // Map<K,V>
    if (std.mem.startsWith(u8, type_name, "Map<")) {
        return "std.StringHashMap([]const u8)";
    }

    // Plain Map type
    if (std.mem.eql(u8, type_name, "Map")) {
        return "std.StringHashMap([]const u8)";
    }

    // Handle Tensor type specially
    if (std.mem.eql(u8, type_name, "Tensor")) {
        return "Tensor";
    }

    // Unknown types - return as-is (could be custom types)
    return type_name;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "extractInnerType" {
    try std.testing.expectEqualStrings("Float", extractInnerType("List<Float>", "List<", ">"));
    try std.testing.expectEqualStrings("Int", extractInnerType("Option<Int>", "Option<", ">"));
    try std.testing.expectEqualStrings("usize", extractInnerType("List<usize>", "List<", ">"));
}

test "mapTypeFixed - primitives" {
    try std.testing.expectEqualStrings("f64", mapTypeFixed("Float"));
    try std.testing.expectEqualStrings("i64", mapTypeFixed("Int"));
    try std.testing.expectEqualStrings("bool", mapTypeFixed("Bool"));
    try std.testing.expectEqualStrings("[]const u8", mapTypeFixed("String"));
}

test "mapTypeFixed - generics" {
    try std.testing.expectEqualStrings("[]f64", mapTypeFixed("List<Float>"));
    try std.testing.expectEqualStrings("[]i64", mapTypeFixed("List<Int>"));
    try std.testing.expectEqualStrings("[]usize", mapTypeFixed("List<usize>"));
    try std.testing.expectEqualStrings("?f64", mapTypeFixed("Option<Float>"));
}
