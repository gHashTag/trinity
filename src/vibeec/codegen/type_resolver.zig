// ═══════════════════════════════════════════════════════════════════════════════
// TYPE RESOLVER — Generated from specs/tri/holy_core_type_resolver.tri
// ═══════════════════════════════════════════════════════════════════════════════
//
// Cycle 79: First Holy Core module migrated to VIBEE-first
// Source of truth: specs/tri/holy_core_type_resolver.tri
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("types.zig");

const TypeDef = types.TypeDef;
const Allocator = std.mem.Allocator;

pub const CodegenError = error{
    UnmatchedBrackets,
    InvalidMapType,
    InvalidHashMapType,
};

// ─── Helper: ASCII lowercase ───

pub fn toLowerASCII(c: u8) u8 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

// ─── Helper: Case-Insensitive Contains ───

pub fn containsCI(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (haystack.len < needle.len) return false;
    const limit = haystack.len - needle.len + 1;
    for (0..limit) |i| {
        var found = true;
        for (0..needle.len) |j| {
            const h = toLowerASCII(haystack[i + j]);
            const n = toLowerASCII(needle[j]);
            if (h != n) {
                found = false;
                break;
            }
        }
        if (found) return true;
    }
    return false;
}

// ─── Primitive Type Resolution ───

pub fn resolveTypeName(spec_types: []const TypeDef, type_name: []const u8) []const u8 {
    if (std.mem.eql(u8, type_name, "String")) return "[]const u8";
    if (std.mem.eql(u8, type_name, "Int")) return "i64";
    if (std.mem.eql(u8, type_name, "Float")) return "f64";
    if (std.mem.eql(u8, type_name, "Bool")) return "bool";
    if (std.mem.eql(u8, type_name, "usize")) return "usize";
    if (std.mem.eql(u8, type_name, "u8")) return "u8";
    if (std.mem.eql(u8, type_name, "u32")) return "u32";
    if (std.mem.eql(u8, type_name, "u64")) return "u64";
    if (std.mem.eql(u8, type_name, "i32")) return "i32";
    if (std.mem.eql(u8, type_name, "i64")) return "i64";
    if (std.mem.eql(u8, type_name, "f32")) return "f32";
    if (std.mem.eql(u8, type_name, "f64")) return "f64";
    if (std.mem.eql(u8, type_name, "void")) return "void";
    if (std.mem.eql(u8, type_name, "anytype")) return "anytype";

    for (spec_types) |t| {
        if (std.mem.eql(u8, t.name, type_name)) {
            return type_name;
        }
    }

    return type_name;
}

// ─── Bracket Matching ───

pub fn findMatchingBracket(str: []const u8, start_pos: usize) ?usize {
    var depth: usize = 1;
    var i = start_pos;
    while (i < str.len) : (i += 1) {
        const c = str[i];
        if (c == '<') depth += 1 else if (c == '>') {
            depth -= 1;
            if (depth == 0) return i;
        }
    }
    return null;
}

// ─── Complex Type Parsing (no-alloc fast path) ───

pub fn parseComplexTypeNoAlloc(spec_types: []const TypeDef, type_str: []const u8) ?[]const u8 {
    if (std.mem.startsWith(u8, type_str, "Option<")) {
        const end_pos = findMatchingBracket(type_str, 8) orelse return null;
        const inner = type_str[8..end_pos];
        const resolved = parseComplexTypeNoAlloc(spec_types, inner) orelse return null;
        if (std.mem.eql(u8, resolved, "i64")) return "?i64";
        if (std.mem.eql(u8, resolved, "f64")) return "?f64";
        if (std.mem.eql(u8, resolved, "bool")) return "?bool";
        if (std.mem.eql(u8, resolved, "[]const u8")) return "?[]const u8";
        if (std.mem.eql(u8, resolved, "[]const i64")) return "?[]const i64";
        if (std.mem.eql(u8, resolved, "[]const f64")) return "?[]const f64";
        return null;
    }

    if (std.mem.startsWith(u8, type_str, "List<")) {
        const end_pos = findMatchingBracket(type_str, 5) orelse return null;
        const inner = type_str[5..end_pos];
        const resolved = parseComplexTypeNoAlloc(spec_types, inner) orelse return null;
        if (std.mem.eql(u8, resolved, "i64")) return "[]const i64";
        if (std.mem.eql(u8, resolved, "f64")) return "[]const f64";
        if (std.mem.eql(u8, resolved, "bool")) return "[]const bool";
        if (std.mem.eql(u8, resolved, "u8")) return "[]const u8";
        if (std.mem.eql(u8, resolved, "usize")) return "[]const usize";
        if (std.mem.eql(u8, resolved, "[]const u8")) return "[]const []const u8";
        if (std.mem.eql(u8, resolved, "[]const i64")) return "[]const []const i64";
        if (std.mem.eql(u8, resolved, "[]const f64")) return "[]const []const f64";
        if (std.mem.eql(u8, resolved, "?i64")) return "[]const ?i64";
        if (std.mem.eql(u8, resolved, "?f64")) return "[]const ?f64";
        return null;
    }

    if (std.mem.eql(u8, type_str, "String")) return "[]const u8";
    if (std.mem.eql(u8, type_str, "Int")) return "i64";
    if (std.mem.eql(u8, type_str, "Float")) return "f64";
    if (std.mem.eql(u8, type_str, "Bool")) return "bool";
    if (std.mem.eql(u8, type_str, "usize")) return "usize";
    if (std.mem.eql(u8, type_str, "u8")) return "u8";
    if (std.mem.eql(u8, type_str, "void")) return "void";
    if (std.mem.eql(u8, type_str, "anytype")) return "anytype";

    return null;
}

// ─── Complex Type Parsing (allocating path) ───

pub fn parseComplexType(allocator: Allocator, spec_types: []const TypeDef, type_str: []const u8) ![]const u8 {
    if (std.mem.startsWith(u8, type_str, "Option<")) {
        const end_pos = findMatchingBracket(type_str, 8) orelse
            return error.UnmatchedBrackets;
        const inner = type_str[8..end_pos];
        const resolved = try parseComplexType(allocator, spec_types, inner);
        return try std.fmt.allocPrint(allocator, "?{s}", .{resolved});
    }

    if (std.mem.startsWith(u8, type_str, "List<")) {
        const end_pos = findMatchingBracket(type_str, 5) orelse
            return error.UnmatchedBrackets;
        const inner = type_str[5..end_pos];
        const resolved = try parseComplexType(allocator, spec_types, inner);
        return try std.fmt.allocPrint(allocator, "[]const {s}", .{resolved});
    }

    if (std.mem.startsWith(u8, type_str, "Map<")) {
        const end_pos = findMatchingBracket(type_str, 4) orelse
            return error.UnmatchedBrackets;
        const inner = type_str[4..end_pos];
        const comma_idx = std.mem.indexOf(u8, inner, ",") orelse return error.InvalidMapType;
        const key_type = try parseComplexType(allocator, spec_types, inner[0..comma_idx]);
        const value_type = try parseComplexType(allocator, spec_types, inner[comma_idx + 1 ..]);
        if (std.mem.eql(u8, key_type, "[]const u8") or std.mem.eql(u8, key_type, "String")) {
            return try std.fmt.allocPrint(allocator, "std.StringHashMap({s})", .{value_type});
        }
        return try std.fmt.allocPrint(allocator, "std.AutoHashMap({s}, {s})", .{ key_type, value_type });
    }

    if (std.mem.startsWith(u8, type_str, "HashMap<")) {
        const end_pos = findMatchingBracket(type_str, 8) orelse
            return error.UnmatchedBrackets;
        const inner = type_str[8..end_pos];
        const comma_idx = std.mem.indexOf(u8, inner, ",") orelse return error.InvalidHashMapType;
        const key_type = try parseComplexType(allocator, spec_types, inner[0..comma_idx]);
        const value_type = try parseComplexType(allocator, spec_types, inner[comma_idx + 1 ..]);
        return try std.fmt.allocPrint(allocator, "std.AutoHashMap({s}, {s})", .{ key_type, value_type });
    }

    if (type_str.len > 0 and type_str[0] == '[' and type_str[type_str.len - 1] == ']') {
        const inner = type_str[1 .. type_str.len - 1];
        if (inner.len > 0) {
            const resolved = resolveTypeName(spec_types, inner);
            return try std.fmt.allocPrint(allocator, "[{s}]", .{resolved});
        }
        return type_str;
    }

    if (type_str.len > 0 and type_str[0] == '*') {
        return type_str;
    }

    return resolveTypeName(spec_types, type_str);
}

// ─── Semantic Type Mapping ───

pub fn mapSemanticType(type_name: []const u8) []const u8 {
    const semantic_map = [_]struct { []const u8, []const u8 }{
        .{ "probability", "f32" },
        .{ "probabilities", "[]f32" },
        .{ "similarity", "f32" },
        .{ "score", "f32" },
        .{ "confidence", "f32" },
        .{ "accuracy", "f32" },
        .{ "count", "usize" },
        .{ "index", "usize" },
        .{ "size", "usize" },
        .{ "length", "usize" },
        .{ "tensor", "Tensor" },
        .{ "embedding", "[]const f32" },
        .{ "embeddings", "[]const []f32" },
        .{ "distribution", "[]f32" },
        .{ "vector", "[]const i8" },
        .{ "hypervector", "[]const i8" },
        .{ "matrix", "[]const f32" },
        .{ "agent", "AgentInfo" },
        .{ "wallet", "Wallet" },
        .{ "task", "Task" },
        .{ "tenant", "Tenant" },
    };

    for (semantic_map) |entry| {
        if (containsCI(type_name, entry[0])) {
            return entry[1];
        }
    }

    if (containsCI(type_name, "int")) return "i64";
    if (containsCI(type_name, "float") or containsCI(type_name, "f32")) return "f32";
    if (containsCI(type_name, "string") or containsCI(type_name, "text")) return "[]const u8";
    if (containsCI(type_name, "bool")) return "bool";

    return type_name;
}

// ─── Full Type Resolution (spec + semantic + primitive) ───

pub fn resolveTypeFromSpec(spec_types: []const TypeDef, type_name: []const u8) []const u8 {
    for (spec_types) |t| {
        if (std.mem.eql(u8, t.name, type_name)) {
            return type_name;
        }
    }

    const semantic = mapSemanticType(type_name);
    if (!std.mem.eql(u8, semantic, type_name)) {
        return semantic;
    }

    return resolveTypeName(spec_types, type_name);
}

// ─── Phrase Extraction Helpers ───

pub fn extractCount(phrase: []const u8) ?usize {
    if (containsCI(phrase, "two") or containsCI(phrase, "pair")) return 2;
    if (containsCI(phrase, "three") or containsCI(phrase, "triple")) return 3;
    if (containsCI(phrase, "four")) return 4;
    if (containsCI(phrase, "five")) return 5;
    if (containsCI(phrase, "six")) return 6;
    if (containsCI(phrase, "seven")) return 7;
    if (containsCI(phrase, "eight")) return 8;
    if (containsCI(phrase, "nine")) return 9;
    if (containsCI(phrase, "ten")) return 10;
    if (containsCI(phrase, "multiple")) return null;
    return null;
}

pub fn extractBaseType(phrase: []const u8) []const u8 {
    const type_markers = [_][]const u8{
        "Vec3",   "Vec2",   "Vec4",   "vec3",   "vec2",  "vec4",
        "Tensor", "tensor", "Matrix", "matrix", "Agent", "Wallet",
        "Task",   "Tenant",
    };

    for (type_markers) |marker| {
        if (containsCI(phrase, marker)) {
            return marker;
        }
    }

    if (containsCI(phrase, "vector") or containsCI(phrase, "hypervector")) return "[]const i8";
    if (containsCI(phrase, "tensor")) return "Tensor";
    if (containsCI(phrase, "matrix")) return "[]const f32";
    if (containsCI(phrase, "agent")) return "AgentInfo";
    if (containsCI(phrase, "wallet")) return "Wallet";

    return "anytype";
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "resolveTypeName: primitives" {
    const empty: []const TypeDef = &.{};
    try std.testing.expectEqualStrings("[]const u8", resolveTypeName(empty, "String"));
    try std.testing.expectEqualStrings("i64", resolveTypeName(empty, "Int"));
    try std.testing.expectEqualStrings("f64", resolveTypeName(empty, "Float"));
    try std.testing.expectEqualStrings("bool", resolveTypeName(empty, "Bool"));
    try std.testing.expectEqualStrings("usize", resolveTypeName(empty, "usize"));
    try std.testing.expectEqualStrings("void", resolveTypeName(empty, "void"));
}

test "resolveTypeName: pass-through unknown" {
    const empty: []const TypeDef = &.{};
    try std.testing.expectEqualStrings("MyCustomType", resolveTypeName(empty, "MyCustomType"));
}

test "findMatchingBracket: simple" {
    const s = "List<Int>";
    try std.testing.expectEqual(@as(?usize, 8), findMatchingBracket(s, 5));
}

test "findMatchingBracket: nested" {
    const s = "Map<String,List<Int>>";
    try std.testing.expectEqual(@as(?usize, 20), findMatchingBracket(s, 4));
}

test "findMatchingBracket: unmatched returns null" {
    const s = "List<Int";
    try std.testing.expectEqual(@as(?usize, null), findMatchingBracket(s, 5));
}

test "parseComplexTypeNoAlloc: Option<Int>" {
    const empty: []const TypeDef = &.{};
    try std.testing.expectEqualStrings("?i64", parseComplexTypeNoAlloc(empty, "Option<Int>").?);
}

test "parseComplexTypeNoAlloc: List<String>" {
    const empty: []const TypeDef = &.{};
    try std.testing.expectEqualStrings("[]const u8", parseComplexTypeNoAlloc(empty, "List<String>").?);
}

test "parseComplexTypeNoAlloc: nested List<List<Int>>" {
    const empty: []const TypeDef = &.{};
    try std.testing.expectEqualStrings("[]const []const i64", parseComplexTypeNoAlloc(empty, "List<List<Int>>").?);
}

test "parseComplexType: Map<String,Int>" {
    const empty: []const TypeDef = &.{};
    const result = try parseComplexType(std.testing.allocator, empty, "Map<String,Int>");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("std.StringHashMap(i64)", result);
}

test "parseComplexType: Option<Float>" {
    const empty: []const TypeDef = &.{};
    const result = try parseComplexType(std.testing.allocator, empty, "Option<Float>");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("?f64", result);
}

test "mapSemanticType: probability" {
    try std.testing.expectEqualStrings("f32", mapSemanticType("probability"));
}

test "mapSemanticType: embedding" {
    try std.testing.expectEqualStrings("[]const f32", mapSemanticType("embedding"));
}

test "containsCI: case insensitive" {
    try std.testing.expect(containsCI("Hello World", "hello"));
    try std.testing.expect(containsCI("TENSOR", "tensor"));
    try std.testing.expect(!containsCI("short", "longneedle"));
}

test "extractCount: word to number" {
    try std.testing.expectEqual(@as(?usize, 2), extractCount("two vectors"));
    try std.testing.expectEqual(@as(?usize, 3), extractCount("triple bond"));
    try std.testing.expectEqual(@as(?usize, null), extractCount("multiple items"));
    try std.testing.expectEqual(@as(?usize, null), extractCount("unknown"));
}

test "extractBaseType: type markers" {
    try std.testing.expectEqualStrings("Vec3", extractBaseType("Vec3 vectors"));
    try std.testing.expectEqualStrings("[]const i8", extractBaseType("some hypervector data"));
    try std.testing.expectEqualStrings("anytype", extractBaseType("random stuff"));
}

test "resolveTypeFromSpec: custom type" {
    // We can't easily construct TypeDef with all fields, so test with empty spec
    const empty: []const TypeDef = &.{};
    // Should fall through to semantic, then primitive
    try std.testing.expectEqualStrings("f32", resolveTypeFromSpec(empty, "probability"));
    try std.testing.expectEqualStrings("[]const u8", resolveTypeFromSpec(empty, "String"));
}
