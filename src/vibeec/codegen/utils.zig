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

/// Extract inner type from generic type like "List<Float>" -> "Float"
/// Now supports nested generics like "List<List<T>>" -> "List<T>"
pub fn extractInnerType(composite: []const u8, prefix: []const u8, suffix: []const u8) []const u8 {
    _ = suffix; // Not needed with bracket counting
    // Check if starts with prefix
    if (!std.mem.startsWith(u8, composite, prefix)) {
        return composite;
    }

    // Find matching closing bracket using bracket counting for nested generics
    const start = prefix.len;
    const end = findMatchingBracketPos(composite, start) orelse return composite;

    return std.mem.trim(u8, composite[start..end], " ");
}

/// Find matching closing bracket position for nested generics
/// Returns position of matching '>' after start_pos, or null if unmatched
fn findMatchingBracketPos(str: []const u8, start_pos: usize) ?usize {
    var depth: usize = 1;
    var i = start_pos;
    while (i < str.len) : (i += 1) {
        const c = str[i];
        if (c == '<') depth += 1 else if (c == '>') {
            depth -= 1;
            if (depth == 0) return i;
        }
    }
    return null; // Unmatched brackets
}

/// Map VIBEE type to Zig type with proper generic handling
/// VIBEE Generator v2: Support raw Zig types in field definitions
pub fn mapType(type_name: []const u8) []const u8 {
    // VIBEE Generator v2: Strip surrounding quotes from raw Zig types
    // YAML contains \"[256]u8\" which parses to "[256]u8" (9 chars)
    // First pass: strip outer quotes "[256]u8" -> [256]u8 (or \"[256]u8\")
    var first_pass = type_name;
    if (first_pass.len >= 2 and first_pass[0] == '"' and first_pass[first_pass.len - 1] == '"') {
        first_pass = first_pass[1 .. first_pass.len - 1];
    }

    // Second pass: strip \" patterns from both ends \"[256]u8\" -> [256]u8
    // Pattern at both ends is: backslash (\) then quote (")
    const clean_input = if (first_pass.len >= 4)
        if (first_pass[0] == '\\' and first_pass[1] == '"' and
            first_pass[first_pass.len - 2] == '\\' and first_pass[first_pass.len - 1] == '"')
            first_pass[2 .. first_pass.len - 2]
        else
            first_pass
    else
        first_pass;

    // Primitive types
    if (std.mem.eql(u8, clean_input, "f64")) return "f64";
    if (std.mem.eql(u8, clean_input, "f32")) return "f32";
    if (std.mem.eql(u8, clean_input, "i32")) return "i32";
    if (std.mem.eql(u8, clean_input, "i64")) return "i64";
    if (std.mem.eql(u8, clean_input, "u32")) return "u32";
    if (std.mem.eql(u8, clean_input, "u64")) return "u64";
    if (std.mem.eql(u8, clean_input, "u8")) return "u8";
    if (std.mem.eql(u8, clean_input, "u16")) return "u16";
    if (std.mem.eql(u8, clean_input, "usize")) return "usize";
    if (std.mem.eql(u8, clean_input, "bool")) return "bool";

    // VIBEE types -> Zig types
    if (std.mem.eql(u8, clean_input, "String")) return "[]const u8";
    if (std.mem.eql(u8, clean_input, "Int")) return "i64";
    if (std.mem.eql(u8, clean_input, "Float")) return "f64";
    if (std.mem.eql(u8, clean_input, "Bool")) return "bool";
    if (std.mem.eql(u8, clean_input, "Bytes")) return "[]const u8";
    if (std.mem.eql(u8, clean_input, "Timestamp")) return "i64";
    if (std.mem.eql(u8, clean_input, "Duration")) return "i64";
    if (std.mem.eql(u8, clean_input, "Any")) return "[]const u8";
    if (std.mem.eql(u8, clean_input, "Void")) return "void";
    if (std.mem.eql(u8, clean_input, "Error")) return "anyerror";

    // Case-insensitive aliases (specs may use lowercase or mixed case)
    if (std.mem.eql(u8, clean_input, "string")) return "[]const u8";
    if (std.mem.eql(u8, clean_input, "int")) return "i64";
    if (std.mem.eql(u8, clean_input, "float")) return "f64";

    // Extended integer types
    if (std.mem.eql(u8, clean_input, "Int64")) return "i64";
    if (std.mem.eql(u8, clean_input, "Int32")) return "i32";
    if (std.mem.eql(u8, clean_input, "Int16")) return "i16";
    if (std.mem.eql(u8, clean_input, "Int8")) return "i8";
    if (std.mem.eql(u8, clean_input, "UInt")) return "u32";
    if (std.mem.eql(u8, clean_input, "UInt64")) return "u64";
    if (std.mem.eql(u8, clean_input, "UInt32")) return "u32";
    if (std.mem.eql(u8, clean_input, "UInt16")) return "u16";
    if (std.mem.eql(u8, clean_input, "UInt8")) return "u8";
    if (std.mem.eql(u8, clean_input, "UInt4")) return "u4";
    if (std.mem.eql(u8, clean_input, "Float32")) return "f32";
    if (std.mem.eql(u8, clean_input, "Float64")) return "f64";

    // Short capitalization aliases (U64, U32, etc.)
    if (std.mem.eql(u8, clean_input, "U64")) return "u64";
    if (std.mem.eql(u8, clean_input, "U32")) return "u32";
    if (std.mem.eql(u8, clean_input, "U16")) return "u16";
    if (std.mem.eql(u8, clean_input, "U8")) return "u8";
    if (std.mem.eql(u8, clean_input, "I64")) return "i64";
    if (std.mem.eql(u8, clean_input, "I32")) return "i32";
    if (std.mem.eql(u8, clean_input, "I16")) return "i16";
    if (std.mem.eql(u8, clean_input, "I8")) return "i8";
    if (std.mem.eql(u8, clean_input, "Int2")) return "i2";
    if (std.mem.eql(u8, clean_input, "UInt2")) return "u2";
    if (std.mem.eql(u8, clean_input, "Trit")) return "i2";

    // VIBEE spec Array[T][N] -> Zig [N]T
    // e.g. Array[Int8][10000] -> [10000]i8
    if (std.mem.startsWith(u8, clean_input, "Array[")) {
        // Find inner type between first [ and ]
        if (std.mem.indexOf(u8, clean_input[6..], "]")) |end_inner| {
            const inner_type = clean_input[6 .. 6 + end_inner];
            const inner_zig = mapType(inner_type);
            // Find size between second [ and ]
            const after_first_bracket = 6 + end_inner + 1;
            if (after_first_bracket < clean_input.len and clean_input[after_first_bracket] == '[') {
                if (std.mem.indexOf(u8, clean_input[after_first_bracket + 1 ..], "]")) |end_size| {
                    const size_str = clean_input[after_first_bracket + 1 .. after_first_bracket + 1 + end_size];
                    // Return known combinations as static strings
                    if (std.mem.eql(u8, inner_zig, "i8") and std.mem.eql(u8, size_str, "10000")) return "[10000]i8";
                    if (std.mem.eql(u8, inner_zig, "u8") and std.mem.eql(u8, size_str, "10000")) return "[10000]u8";
                    if (std.mem.eql(u8, inner_zig, "i8") and std.mem.eql(u8, size_str, "256")) return "[256]i8";
                    if (std.mem.eql(u8, inner_zig, "u8") and std.mem.eql(u8, size_str, "256")) return "[256]u8";
                    // Fallback: return slice type for safety
                    if (std.mem.eql(u8, inner_zig, "i8")) return "[]i8";
                    if (std.mem.eql(u8, inner_zig, "u8")) return "[]u8";
                    return "[]const u8";
                }
            }
        }
        return "[]const u8"; // fallback
    }

    // VIBEE Generator v2: Check if this is a raw Zig type (array, pointer, optional)
    // Array types: [N]T — check if T needs mapping (e.g. [4]UInt8 -> [4]u8)
    if (std.mem.startsWith(u8, clean_input, "[")) {
        // Find the closing bracket to get N and T
        if (std.mem.indexOf(u8, clean_input, "]")) |close_bracket| {
            const inner_type = clean_input[close_bracket + 1 ..];
            const mapped = mapType(inner_type);
            // If inner type mapped to something different, need to construct new type
            if (!std.mem.eql(u8, inner_type, mapped)) {
                // Known combinations for static string returns
                const size_part = clean_input[0 .. close_bracket + 1];
                if (std.mem.eql(u8, size_part, "[4]") and std.mem.eql(u8, mapped, "u8")) return "[4]u8";
                if (std.mem.eql(u8, size_part, "[8]") and std.mem.eql(u8, mapped, "u8")) return "[8]u8";
                if (std.mem.eql(u8, size_part, "[16]") and std.mem.eql(u8, mapped, "u8")) return "[16]u8";
                if (std.mem.eql(u8, size_part, "[32]") and std.mem.eql(u8, mapped, "u8")) return "[32]u8";
                if (std.mem.eql(u8, size_part, "[64]") and std.mem.eql(u8, mapped, "u8")) return "[64]u8";
                if (std.mem.eql(u8, size_part, "[256]") and std.mem.eql(u8, mapped, "u8")) return "[256]u8";
                if (std.mem.eql(u8, size_part, "[4]") and std.mem.eql(u8, mapped, "i8")) return "[4]i8";
                if (std.mem.eql(u8, size_part, "[256]") and std.mem.eql(u8, mapped, "i8")) return "[256]i8";
                // Fallback: return as-is (already valid if inner is a Zig type)
            }
        }
        return clean_input;
    }
    // Pointer types: *T, *const T
    if (std.mem.startsWith(u8, clean_input, "*")) return clean_input;
    // Optional types: ?T
    if (std.mem.startsWith(u8, clean_input, "?")) return clean_input;

    // Pointer type Ptr<T> -> *T (use opaque pointer for generated code)
    if (std.mem.startsWith(u8, clean_input, "Ptr<")) {
        return "*anyopaque";
    }

    // Allocator
    if (std.mem.eql(u8, clean_input, "Allocator")) {
        return "std.mem.Allocator";
    }

    // Codebook -> opaque VSA codebook type
    if (std.mem.eql(u8, clean_input, "Codebook")) {
        return "*anyopaque";
    }

    // Map/Dict types -> use StringHashMap equivalent or just []const u8
    if (std.mem.startsWith(u8, clean_input, "Map(") or std.mem.startsWith(u8, clean_input, "Map<") or
        std.mem.startsWith(u8, clean_input, "map(") or std.mem.startsWith(u8, clean_input, "map<") or
        std.mem.startsWith(u8, clean_input, "Dict(") or std.mem.startsWith(u8, clean_input, "Dict<"))
    {
        return "[]const u8"; // Simplified: maps as serialized data
    }
    // Set types -> []const u8
    if (std.mem.startsWith(u8, clean_input, "Set<") or std.mem.startsWith(u8, clean_input, "set<") or
        std.mem.startsWith(u8, clean_input, "Set(") or std.mem.startsWith(u8, clean_input, "set("))
    {
        return "[]const u8";
    }
    if (std.mem.eql(u8, clean_input, "Map") or std.mem.eql(u8, clean_input, "Dict") or
        std.mem.eql(u8, clean_input, "HashMap"))
    {
        return "[]const u8";
    }

    // Tuple types -> struct or array (simplified to slice)
    if (std.mem.startsWith(u8, clean_input, "Tuple")) {
        return "[]const u8";
    }

    // 2D/3D array types -> flatten to slice
    if (std.mem.startsWith(u8, clean_input, "2D") or std.mem.startsWith(u8, clean_input, "3D")) {
        return "[]const u8";
    }

    // Handle parenthesis notation: List(T) -> same as List<T>
    if (std.mem.startsWith(u8, clean_input, "List(") and clean_input.len > 5) {
        if (std.mem.indexOf(u8, clean_input[5..], ")")) |end| {
            const inner = std.mem.trim(u8, clean_input[5 .. 5 + end], " ");
            const inner_zig = mapType(inner);
            if (std.mem.eql(u8, inner_zig, "[]const u8")) return "[]const u8";
            if (std.mem.eql(u8, inner_zig, "i64")) return "[]const i64";
            if (std.mem.eql(u8, inner_zig, "f64")) return "[]const f64";
            if (std.mem.eql(u8, inner_zig, "bool")) return "[]const bool";
            return "[]const u8";
        }
    }

    // Handle function types: function(T) R -> *const fn() void
    if (std.mem.startsWith(u8, clean_input, "function(") or std.mem.startsWith(u8, clean_input, "Function(")) {
        return "*const fn() void";
    }

    // Generic types List<T> or List[T] -> []const T
    // Handle bracket notation List[T] by treating it the same as List<T>
    if (std.mem.startsWith(u8, clean_input, "List[") and clean_input.len > 5) {
        // List[SearchResult] -> extract inner type between [ and ]
        const inner_start: usize = 5;
        var inner_end: usize = clean_input.len;
        if (std.mem.indexOfScalar(u8, clean_input[inner_start..], ']')) |pos| {
            inner_end = inner_start + pos;
        }
        const inner = std.mem.trim(u8, clean_input[inner_start..inner_end], " ");
        if (std.mem.eql(u8, inner, "String")) return "[]const u8";
        if (std.mem.eql(u8, inner, "Int")) return "[]const i64";
        if (std.mem.eql(u8, inner, "Float")) return "[]const f64";
        if (std.mem.eql(u8, inner, "Bool")) return "[]const bool";
        // For custom inner types, return slice of u8 (serialized)
        return "[]const u8";
    }
    // Lowercase list<T> -> same as List<T>
    if (std.mem.startsWith(u8, clean_input, "list<") and clean_input.len > 5) {
        const inner = extractInnerType(clean_input, "list<", ">");
        if (std.mem.eql(u8, inner, "String") or std.mem.eql(u8, inner, "string")) return "[]const u8";
        if (std.mem.eql(u8, inner, "Int") or std.mem.eql(u8, inner, "int")) return "[]const i64";
        if (std.mem.eql(u8, inner, "Float") or std.mem.eql(u8, inner, "float")) return "[]const f64";
        if (std.mem.eql(u8, inner, "Bool") or std.mem.eql(u8, inner, "bool")) return "[]const bool";
        const inner_zig = mapType(inner);
        if (std.mem.eql(u8, inner_zig, "[]const u8")) return "[]const []const u8";
        return "[]const u8";
    }
    // Generic types List<T> -> []const T (FIXED: recursively parse inner type)
    if (std.mem.startsWith(u8, clean_input, "List<")) {
        const inner = extractInnerType(clean_input, "List<", ">");
        // Check inner type FIRST before calling mapType recursively
        // This avoids double-conversion (String -> []const u8 -> []const []const u8)
        if (std.mem.eql(u8, inner, "String")) return "[]const u8";
        if (std.mem.eql(u8, inner, "Int")) return "[]const i64";
        if (std.mem.eql(u8, inner, "Float")) return "[]const f64";
        if (std.mem.eql(u8, inner, "Bool")) return "[]const bool";
        if (std.mem.eql(u8, inner, "usize")) return "[]const usize";
        if (std.mem.eql(u8, inner, "u8")) return "[]u8";
        // For complex inner types (generics, custom types), use mapType recursively
        const inner_zig = mapType(inner);
        // Nested generics support for already-converted types
        if (std.mem.eql(u8, inner_zig, "[]const u8")) return "[]const []const u8"; // List<List<String>>
        if (std.mem.eql(u8, inner_zig, "[]const i64")) return "[]const []const i64"; // List<List<Int>>
        if (std.mem.eql(u8, inner_zig, "[]const f64")) return "[]const []const f64"; // List<List<Float>>
        if (std.mem.eql(u8, inner_zig, "[]i64")) return "[][]i64";
        if (std.mem.eql(u8, inner_zig, "[]f64")) return "[][]f64";
        if (std.mem.eql(u8, inner_zig, "?i64")) return "[]?i64"; // List<Option<Int>>
        if (std.mem.eql(u8, inner_zig, "?f64")) return "[]?f64";
        return "[]const u8"; // fallback
    }

    // Space syntax: "List T" (e.g. "List Float", "List TheoryState", "List String")
    if (std.mem.startsWith(u8, clean_input, "List ") and clean_input.len > 5) {
        const inner = std.mem.trim(u8, clean_input[5..], " ");
        if (inner.len > 0) {
            if (std.mem.eql(u8, inner, "String")) return "[]const u8";
            if (std.mem.eql(u8, inner, "Int")) return "[]const i64";
            if (std.mem.eql(u8, inner, "Float")) return "[]const f64";
            if (std.mem.eql(u8, inner, "Bool")) return "[]const bool";
            if (std.mem.eql(u8, inner, "usize")) return "[]const usize";
            if (std.mem.eql(u8, inner, "u8")) return "[]u8";
            const inner_zig = mapType(inner);
            if (std.mem.eql(u8, inner_zig, "[]const u8")) return "[]const []const u8";
            return "[]const u8"; // custom types fallback to serialized
        }
    }

    // Plain List type -> slice
    if (std.mem.eql(u8, clean_input, "List")) {
        return "[]const u8";
    }

    // Generic types Option[T] -> ?T (bracket notation)
    if (std.mem.startsWith(u8, clean_input, "Option[") and clean_input.len > 7) {
        const inner_start: usize = 7;
        var inner_end: usize = clean_input.len;
        if (std.mem.indexOfScalar(u8, clean_input[inner_start..], ']')) |pos| {
            inner_end = inner_start + pos;
        }
        const inner = std.mem.trim(u8, clean_input[inner_start..inner_end], " ");
        const inner_zig = mapType(inner);
        if (std.mem.eql(u8, inner_zig, "f64")) return "?f64";
        if (std.mem.eql(u8, inner_zig, "i64")) return "?i64";
        if (std.mem.eql(u8, inner_zig, "bool")) return "?bool";
        if (std.mem.eql(u8, inner_zig, "[]const u8")) return "?[]const u8";
        return "?[]const u8";
    }

    // Generic types Option<T> -> ?T (FIXED: parse inner type)
    if (std.mem.startsWith(u8, clean_input, "Option<")) {
        const inner = extractInnerType(clean_input, "Option<", ">");
        const inner_zig = mapType(inner);
        // Map common inner types to correct optional types
        if (std.mem.eql(u8, inner_zig, "f64")) return "?f64";
        if (std.mem.eql(u8, inner_zig, "f32")) return "?f32";
        if (std.mem.eql(u8, inner_zig, "i64")) return "?i64";
        if (std.mem.eql(u8, inner_zig, "i32")) return "?i32";
        if (std.mem.eql(u8, inner_zig, "usize")) return "?usize";
        if (std.mem.eql(u8, inner_zig, "bool")) return "?bool";
        if (std.mem.eql(u8, inner_zig, "[]f64")) return "?[]f64";
        if (std.mem.eql(u8, inner_zig, "[]const u8")) return "?[]const u8";
        return "?[]const u8"; // fallback
    }

    // HashMap<K,V>
    if (std.mem.startsWith(u8, clean_input, "HashMap<")) {
        return "std.AutoHashMap(usize, *anyopaque)";
    }

    // Map<K,V>
    if (std.mem.startsWith(u8, clean_input, "Map<")) {
        return "std.StringHashMap([]const u8)";
    }

    // Plain Map type
    if (std.mem.eql(u8, clean_input, "Map")) {
        return "std.StringHashMap([]const u8)";
    }

    // Handle trailing ? (nullable)
    if (clean_input.len > 0 and clean_input[clean_input.len - 1] == '?') {
        return "?[]const u8";
    }

    // Object type
    if (std.mem.eql(u8, clean_input, "Object")) {
        return "[]const u8";
    }

    // Unknown complex types -> []const u8
    if (std.mem.eql(u8, clean_input, "JsonSchema")) return "[]const u8";
    if (std.mem.eql(u8, clean_input, "Role")) return "[]const u8";
    if (std.mem.eql(u8, clean_input, "PluginManifest")) return "[]const u8";
    if (std.mem.eql(u8, clean_input, "PluginConfig")) return "[]const u8";
    if (std.mem.eql(u8, clean_input, "StreamEvent")) return "[]const u8";
    if (std.mem.eql(u8, clean_input, "TokenStats")) return "[]const u8";

    // Handle Tensor type specially
    if (std.mem.eql(u8, clean_input, "Tensor")) {
        return "Tensor";
    }

    // Unknown types - return as-is (could be custom types or raw Zig types)
    return clean_input;
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

test "extractInnerType" {
    try std.testing.expectEqualStrings("Float", extractInnerType("List<Float>", "List<", ">"));
    try std.testing.expectEqualStrings("Int", extractInnerType("Option<Int>", "Option<", ">"));
    try std.testing.expectEqualStrings("usize", extractInnerType("List<usize>", "List<", ">"));
}

test "mapType - primitives" {
    try std.testing.expectEqualStrings("[]const u8", mapType("String"));
    try std.testing.expectEqualStrings("i64", mapType("Int"));
    try std.testing.expectEqualStrings("bool", mapType("Bool"));
    try std.testing.expectEqualStrings("f64", mapType("f64"));
}

test "mapType - generics (FIXED)" {
    // List<T> maps to []const T
    try std.testing.expectEqualStrings("[]const f64", mapType("List<Float>"));
    try std.testing.expectEqualStrings("[]const i64", mapType("List<Int>"));
    try std.testing.expectEqualStrings("[]const usize", mapType("List<usize>"));
    try std.testing.expectEqualStrings("[]const bool", mapType("List<Bool>"));

    // Option<T> maps to ?T
    try std.testing.expectEqualStrings("?f64", mapType("Option<Float>"));
    try std.testing.expectEqualStrings("?i64", mapType("Option<Int>"));
    try std.testing.expectEqualStrings("?bool", mapType("Option<Bool>"));
}

test "mapType - space syntax (P0 fix)" {
    // List T (space syntax from .tri specs)
    try std.testing.expectEqualStrings("[]const u8", mapType("List String"));
    try std.testing.expectEqualStrings("[]const f64", mapType("List Float"));
    try std.testing.expectEqualStrings("[]const i64", mapType("List Int"));
    try std.testing.expectEqualStrings("[]const bool", mapType("List Bool"));
    try std.testing.expectEqualStrings("[]const u8", mapType("List TheoryState"));
    try std.testing.expectEqualStrings("[]const u8", mapType("List Prediction"));
}
