// ═══════════════════════════════════════════════════════════════════════════════
// COMPTIME METAPROGRAMMING PATTERNS - Zig 0.15 (v8.11)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Features:
// - Type functions with @Type
// - @typeInfo reflection
// - Anonymous struct literals
// - Result-location semantics
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const CodeBuilder = @import("../builder.zig").CodeBuilder;
const Behavior = @import("../types.zig").Behavior;

/// Generate comptime type function pattern
/// Matches behavior names ending in "Type"
pub fn matchTypeFunction(builder: *CodeBuilder, b: *const Behavior) !bool {
    if (!std.mem.endsWith(u8, b.name, "Type")) return false;

    try builder.writeFmt("pub fn {s}(comptime T: type) type {{\n", .{b.name});
    builder.incIndent();
    try builder.writeLine("// Comptime type computation");
    try builder.writeLine("const info = @typeInfo(T);");
    try builder.writeLine("switch (info) {");
    builder.incIndent();
    try builder.writeLine(".Struct => |s| {");
    builder.incIndent();
    try builder.writeLine("// Struct-specific logic");
    try builder.writeLine("return T;");
    builder.decIndent();
    try builder.writeLine("},");
    try builder.writeLine(".Enum => |e| {");
    builder.incIndent();
    try builder.writeLine("// Enum-specific logic");
    try builder.writeLine("return T;");
    builder.decIndent();
    try builder.writeLine("},");
    try builder.writeLine(".Union => |u| {");
    builder.incIndent();
    try builder.writeLine("// Union-specific logic");
    try builder.writeLine("return T;");
    builder.decIndent();
    try builder.writeLine("},");
    try builder.writeLine(".Optional => |o| {");
    builder.incIndent();
    try builder.writeLine("// Optional-specific logic");
    try builder.writeLine("return T;");
    builder.decIndent();
    try builder.writeLine("},");
    try builder.writeLine(".else => @compileError(\"Unsupported type for \" ++ @typeName(T)),");
    builder.decIndent();
    try builder.writeLine("}");
    builder.decIndent();
    try builder.writeLine("}");
    return true;
}

/// Generate comptime-known value pattern
/// Matches behavior names starting with "comptime_" or containing "compute"
pub fn matchComptimeConst(builder: *CodeBuilder, b: *const Behavior) !bool {
    if (std.mem.startsWith(u8, b.name, "comptime_") or
        std.mem.indexOf(u8, b.name, "compute") != null)
    {
        try builder.writeFmt("pub const {s} = comptime blk: {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Comptime computation");
        try builder.writeLine("const result: u32 = 42;");
        try builder.writeLine("break :blk result;");
        builder.decIndent();
        try builder.writeLine("};");
        return true;
    }

    return false;
}

/// Generate comptime block pattern for type-safe operations
/// Matches behavior names like "make", "create", "build" with comptime
pub fn matchComptimeBlock(builder: *CodeBuilder, b: *const Behavior) !bool {
    if (std.mem.indexOf(u8, b.name, "make") == null and
        std.mem.indexOf(u8, b.name, "create") == null and
        std.mem.indexOf(u8, b.name, "build") == null)
    {
        return false;
    }

    try builder.writeFmt("pub fn {s}(comptime config: anytype) type {{\n", .{b.name});
    builder.incIndent();
    try builder.writeLine("// Comptime type construction");
    try builder.writeLine("const fields = comptime blk: {");
    builder.incIndent();
    try builder.writeLine("// Extract fields from config");
    try builder.writeLine("var field_list: []const std.builtin.Type.StructField = &.{};");
    try builder.writeLine("break :blk field_list;");
    builder.decIndent();
    try builder.writeLine("};");
    try builder.writeLine("");
    try builder.writeLine("return @Type(.{");
    builder.incIndent();
    try builder.writeLine(".Struct = .{");
    builder.incIndent();
    try builder.writeLine(".layout = .auto,");
    try builder.writeLine(".fields = fields,");
    try builder.writeLine(".decls = &.{},");
    try builder.writeLine(".is_tuple = false,");
    builder.decIndent();
    try builder.writeLine("},");
    builder.decIndent();
    try builder.writeLine("});");
    builder.decIndent();
    try builder.writeLine("}");
    return true;
}

/// Generate @setEvalBranchQuota pattern for intensive computations
/// Matches behavior names containing "heavy", "deep", "recursive"
pub fn matchEvalQuota(builder: *CodeBuilder, b: *const Behavior) !bool {
    if (std.mem.indexOf(u8, b.name, "heavy") == null and
        std.mem.indexOf(u8, b.name, "deep") == null and
        std.mem.indexOf(u8, b.name, "recursive") == null)
    {
        return false;
    }

    try builder.writeFmt("pub fn {s}(input: anytype) !void {{\n", .{b.name});
    builder.incIndent();
    try builder.writeLine("// Increase evaluation quota for deep recursion");
    try builder.writeLine("@setEvalBranchQuota(100_000);");
    try builder.writeLine("");
    try builder.writeLine("// Heavy computation here");
    try builder.writeLine("_ = input;");
    builder.decIndent();
    try builder.writeLine("}");
    return true;
}

/// Generate generic type deduction pattern
/// Matches behavior names ending in "Of" or containing "deduce"
pub fn matchTypeDeduction(builder: *CodeBuilder, b: *const Behavior) !bool {
    if (!std.mem.endsWith(u8, b.name, "Of") and
        std.mem.indexOf(u8, b.name, "deduce") == null)
    {
        return false;
    }

    try builder.writeFmt("pub fn {s}(value: anytype) @TypeOf(value) {{\n", .{b.name});
    builder.incIndent();
    try builder.writeLine("// Return the deduced type");
    try builder.writeLine("const T = @TypeOf(value);");
    try builder.writeLine("return T;");
    builder.decIndent();
    try builder.writeLine("}");
    return true;
}

/// Generate inline hint pattern
/// Matches behavior names with "inline", "fast"
pub fn matchInlineHint(builder: *CodeBuilder, b: *const Behavior) !bool {
    if (std.mem.indexOf(u8, b.name, "inline") == null and
        std.mem.indexOf(u8, b.name, "fast") == null)
    {
        return false;
    }

    try builder.writeFmt("pub inline fn {s}(args: anytype) @TypeOf(args) {{\n", .{b.name});
    builder.incIndent();
    try builder.writeLine("// Inline-optimized computation");
    try builder.writeLine("return args;");
    builder.decIndent();
    try builder.writeLine("}");
    return true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MATCH ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

/// Match any comptime-related pattern
pub fn match(builder: *CodeBuilder, b: *const Behavior) !bool {
    if (try matchTypeFunction(builder, b)) return true;
    if (try matchComptimeConst(builder, b)) return true;
    if (try matchComptimeBlock(builder, b)) return true;
    if (try matchEvalQuota(builder, b)) return true;
    if (try matchTypeDeduction(builder, b)) return true;
    if (try matchInlineHint(builder, b)) return true;
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "comptime: matchTypeFunction" {
    const testing = std.testing;
    const mem = std.heap.page_allocator;

    var buf = std.array_list.ArrayList(u8).init(mem);
    defer buf.deinit();

    const writer = buf.writer();
    var builder = CodeBuilder.init(mem);
    builder.setOutputWriter(writer);

    const b = Behavior{
        .name = "MyType",
        .given = "",
        .when = "",
        .then = "",
        .implementation = "",
        .test_cases = &.{},
    };

    const matched = try match(&builder, &b);
    try testing.expect(matched);

    const output = buf.items;
    try testing.expect(std.mem.indexOf(u8, output, "comptime T: type") != null);
    try testing.expect(std.mem.indexOf(u8, output, "@typeInfo") != null);
}

const Behavior = @import("../types.zig").Behavior;
