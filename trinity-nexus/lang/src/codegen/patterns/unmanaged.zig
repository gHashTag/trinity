// ═══════════════════════════════════════════════════════════════════════════════
// UNMANAGED CONTAINER PATTERNS - Zig 0.15 (v8.11)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Features:
// - ArrayListUnmanaged (no allocator stored)
// - HashMapUnmanaged
// - ArenaAllocator patterns
// - appendAssumeCapacity, bounded methods
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const CodeBuilder = @import("../builder.zig").CodeBuilder;
const Behavior = @import("../types.zig").Behavior;

/// Generate unmanaged ArrayList pattern
/// Matches behavior names with "list", "array", "buffer"
pub fn matchUnmanagedList(builder: *CodeBuilder, b: *const Behavior) !bool {
    if (std.mem.indexOf(u8, b.name, "list") == null and
        std.mem.indexOf(u8, b.name, "array") == null and
        std.mem.indexOf(u8, b.name, "buffer") == null)
    {
        return false;
    }

    try builder.writeFmt("pub fn {s}(allocator: std.mem.Allocator) !std.ArrayListUnmanaged(u8) {{\n", .{b.name});
    builder.incIndent();
    try builder.writeLine("// Unmanaged ArrayList - allocator not stored (Zig 0.15)");
    try builder.writeLine("var list: std.ArrayListUnmanaged(u8) = .empty;");
    try builder.writeLine("");
    try builder.writeLine("// Add items (must pass allocator explicitly)");
    try builder.writeLine("try list.append(allocator, 42);");
    try builder.writeLine("try list.appendSlice(allocator, &.{1, 2, 3});");
    try builder.writeLine("");
    try builder.writeLine("return list;");
    builder.decIndent();
    try builder.writeLine("}");
    return true;
}

/// Generate ArenaAllocator pattern
/// Matches behavior names with "arena", "pool", "scratchpad"
pub fn matchArenaPattern(builder: *CodeBuilder, b: *const Behavior) !bool {
    if (std.mem.indexOf(u8, b.name, "arena") == null and
        std.mem.indexOf(u8, b.name, "pool") == null and
        std.mem.indexOf(u8, b.name, "scratchpad") == null)
    {
        return false;
    }

    try builder.writeFmt("pub fn {s}(backing_allocator: std.mem.Allocator) !std.heap.ArenaAllocator {{\n", .{b.name});
    builder.incIndent();
    try builder.writeLine("// Arena allocator - bulk deallocation (Zig 0.15)");
    try builder.writeLine("var arena = std.heap.ArenaAllocator.init(backing_allocator);");
    try builder.writeLine("errdefer arena.deinit();");
    try builder.writeLine("");
    try builder.writeLine("// Use arena.allocator() for allocations");
    try builder.writeLine("// All memory freed at once when arena.deinit() is called");
    try builder.writeLine("");
    try builder.writeLine("return arena;");
    builder.decIndent();
    try builder.writeLine("}");
    return true;
}

/// Generate unmanaged HashMap pattern
/// Matches behavior names with "map", "dict", "table"
pub fn matchUnmanagedHashMap(builder: *CodeBuilder, b: *const Behavior) !bool {
    if (std.mem.indexOf(u8, b.name, "map") == null and
        std.mem.indexOf(u8, b.name, "dict") == null and
        std.mem.indexOf(u8, b.name, "table") == null)
    {
        return false;
    }

    try builder.writeFmt("pub fn {s}(allocator: std.mem.Allocator) !std.HashMapUnmanaged(u8, u32, std.AutoContext(u32)) {{\n", .{b.name});
    builder.incIndent();
    try builder.writeLine("// Unmanaged HashMap (Zig 0.15)");
    try builder.writeLine("var map: std.HashMapUnmanaged(u8, u32, std.AutoContext(u32)) = .{};");
    try builder.writeLine("");
    try builder.writeLine("try map.ensureTotalCapacity(allocator, 16);");
    try builder.writeLine("");
    try builder.writeLine("// Insert entries");
    try builder.writeLine("try map.put(allocator, 'a', 1);");
    try builder.writeLine("try map.put(allocator, 'b', 2);");
    try builder.writeLine("");
    try builder.writeLine("return map;");
    builder.decIndent();
    try builder.writeLine("}");
    return true;
}

/// Generate appendAssumeCapacity pattern
/// Matches behavior names with "push", "append_assume", "unchecked"
pub fn matchAppendAssumeCapacity(builder: *CodeBuilder, b: *const Behavior) !bool {
    if (std.mem.indexOf(u8, b.name, "push") == null and
        std.mem.indexOf(u8, b.name, "appendAssume") == null and
        std.mem.indexOf(u8, b.name, "unchecked") == null)
    {
        return false;
    }

    try builder.writeFmt("pub fn {s}(list: *std.ArrayListUnmanaged(u8), value: u8) void {{\n", .{b.name});
    builder.incIndent();
    try builder.writeLine("// Append with assumed capacity - bounds-check disabled");
    try builder.writeLine("// MUST ensure capacity exists before calling");
    try builder.writeLine("list.appendAssumeCapacity(value);");
    builder.decIndent();
    try builder.writeLine("}");
    return true;
}

/// Generate bounded array operations
/// Matches behavior names with "bounded", "fixed", "circular"
pub fn matchBoundedArray(builder: *CodeBuilder, b: *const Behavior) !bool {
    if (std.mem.indexOf(u8, b.name, "bounded") == null and
        std.mem.indexOf(u8, b.name, "fixed") == null and
        std.mem.indexOf(u8, b.name, "circular") == null)
    {
        return false;
    }

    try builder.writeFmt("pub fn {s}(comptime size: usize) type {{\n", .{b.name});
    builder.incIndent();
    try builder.writeLine("// Bounded array with fixed size");
    try builder.writeLine("return struct {");
    builder.incIndent();
    try builder.writeLine("buffer: [size]u8 = undefined,");
    try builder.writeLine("len: usize = 0,");
    try builder.writeLine("");
    try builder.writeLine("const Self = @This();");
    try builder.writeLine("");
    try builder.writeLine("pub fn push(self: *Self, value: u8) !void {");
    builder.incIndent();
    try builder.writeLine("if (self.len >= size) return error.OutOfBounds;");
    try builder.writeLine("self.buffer[self.len] = value;");
    try builder.writeLine("self.len += 1;");
    builder.decIndent();
    try builder.writeLine("}");
    try builder.writeLine("");
    try builder.writeLine("pub fn pop(self: *Self) ?u8 {");
    builder.incIndent();
    try builder.writeLine("if (self.len == 0) return null;");
    try builder.writeLine("self.len -= 1;");
    try builder.writeLine("return self.buffer[self.len];");
    builder.decIndent();
    try builder.writeLine("}");
    builder.decIndent();
    try builder.writeLine("};");
    builder.decIndent();
    try builder.writeLine("}");
    return true;
}

/// Generate GPA (GeneralPurposeAllocator) pattern
/// Matches behavior names with "gpa", "general", "leak_check"
pub fn matchGpaPattern(builder: *CodeBuilder, b: *const Behavior) !bool {
    if (std.mem.indexOf(u8, b.name, "gpa") == null and
        std.mem.indexOf(u8, b.name, "general") == null and
        std.mem.indexOf(u8, b.name, "leak_check") == null)
    {
        return false;
    }

    try builder.writeFmt("pub fn {s}() std.heap.GeneralPurposeAllocator(.{{}}) {{\n", .{b.name});
    builder.incIndent();
    try builder.writeLine("// GeneralPurposeAllocator for testing (Zig 0.15)");
    try builder.writeLine("// Detects memory leaks and use-after-free");
    try builder.writeLine("var gpa = std.heap.GeneralPurposeAllocator(.{");
    try builder.writeLine("    .stack_trace_frames = 12,");
    try builder.writeLine("});");
    try builder.writeLine("");
    try builder.writeLine("// Store GPA for leak checking at end of main()");
    try builder.writeLine("return gpa;");
    builder.decIndent();
    try builder.writeLine("}");
    return true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MATCH ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

/// Match any unmanaged container pattern
pub fn match(builder: *CodeBuilder, b: *const Behavior) !bool {
    if (try matchUnmanagedList(builder, b)) return true;
    if (try matchArenaPattern(builder, b)) return true;
    if (try matchUnmanagedHashMap(builder, b)) return true;
    if (try matchAppendAssumeCapacity(builder, b)) return true;
    if (try matchBoundedArray(builder, b)) return true;
    if (try matchGpaPattern(builder, b)) return true;
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "unmanaged: matchUnmanagedList" {
    const testing = std.testing;
    const mem = std.heap.page_allocator;

    var buf = std.array_list.ArrayList(u8).init(mem);
    defer buf.deinit();

    const writer = buf.writer();
    var builder = CodeBuilder.init(mem);
    builder.setOutputWriter(writer);

    const b = Behavior{
        .name = "listItems",
        .given = "",
        .when = "",
        .then = "",
        .implementation = "",
        .test_cases = &.{},
    };

    const matched = try match(&builder, &b);
    try testing.expect(matched);

    const output = buf.items;
    try testing.expect(std.mem.indexOf(u8, output, "ArrayListUnmanaged") != null);
}

test "unmanaged: matchArenaPattern" {
    const testing = std.testing;
    const mem = std.heap.page_allocator;

    var buf = std.array_list.ArrayList(u8).init(mem);
    defer buf.deinit();

    const writer = buf.writer();
    var builder = CodeBuilder.init(mem);
    builder.setOutputWriter(writer);

    const b = Behavior{
        .name = "arenaPool",
        .given = "",
        .when = "",
        .then = "",
        .implementation = "",
        .test_cases = &.{},
    };

    const matched = try match(&builder, &b);
    try testing.expect(matched);

    const output = buf.items;
    try testing.expect(std.mem.indexOf(u8, output, "ArenaAllocator") != null);
}

const Behavior = @import("../types.zig").Behavior;
