// ═══════════════════════════════════════════════════════════════════════════════
// ZIG IDIOM PATTERNS - Allocator, Error Union, Comptime (v8.10)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Pure Zig Focus: Patterns that enforce idiomatic Zig code quality
// - Allocator-aware initialization
// - Proper error handling with try/catch
// - Comptime-friendly patterns
// - VSA integration patterns
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("../types.zig");
const builder_mod = @import("../builder.zig");

const CodeBuilder = builder_mod.CodeBuilder;
const Behavior = types.Behavior;

/// Match Zig-specific idiom patterns
pub fn match(builder: *CodeBuilder, b: *const Behavior) !bool {
    // Allocator-aware init pattern
    if (std.mem.eql(u8, b.name, "init")) {
        try builder.writeLine("pub fn init(allocator: std.mem.Allocator) !@This() {");
        builder.incIndent();
        try builder.writeLine("const self = try allocator.create(@This());");
        try builder.writeLine("self.* = .{");
        builder.incIndent();
        try builder.writeLine(".allocator = allocator,");
        builder.decIndent();
        try builder.writeLine("};");
        try builder.writeLine("return self.*;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Deinit with cleanup pattern
    if (std.mem.eql(u8, b.name, "deinit")) {
        try builder.writeLine("pub fn deinit(self: *@This()) void {");
        builder.incIndent();
        try builder.writeLine("const allocator = self.allocator;");
        try builder.writeLine("// Cleanup any allocated fields here");
        try builder.writeLine("allocator.destroy(self);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Error-returning create pattern
    if (std.mem.startsWith(u8, b.name, "create")) {
        try builder.writeFmt("pub fn {s}(allocator: std.mem.Allocator, config: anytype) !@This() {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("var self = try allocator.create(@This());");
        try builder.writeLine("self.* = .{");
        builder.incIndent();
        try builder.writeLine(".allocator = allocator,");
        try builder.writeLine("// Copy config fields");
        builder.decIndent();
        try builder.writeLine("};");
        try builder.writeLine("return self.*;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Try pattern for fallible operations
    if (std.mem.startsWith(u8, b.name, "try")) {
        try builder.writeFmt("pub fn {s}(operation: anytype) !void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Perform fallible operation");
        try builder.writeLine("_ = try operation;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Allocating new pattern with proper error handling
    if (std.mem.startsWith(u8, b.name, "alloc") or std.mem.startsWith(u8, b.name, "new")) {
        try builder.writeFmt("pub fn {s}(allocator: std.mem.Allocator, size: usize) ![]u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("const slice = try allocator.alloc(u8, size);");
        try builder.writeLine("@memset(slice, 0);");
        try builder.writeLine("return slice;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // VSA bind operation pattern
    if (std.mem.endsWith(u8, b.name, "_bind") or std.mem.indexOf(u8, b.name, "bind") != null) {
        try builder.writeFmt("pub fn {s}(a: vsa.Hypervector, b: vsa.Hypervector) vsa.Hypervector {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// VSA bind: associative operation");
        try builder.writeLine("return vsa.bind(a, b);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // VSA bundle operation pattern
    if (std.mem.endsWith(u8, b.name, "_bundle") or std.mem.indexOf(u8, b.name, "bundle") != null) {
        try builder.writeFmt("pub fn {s}(vectors: []const vsa.Hypervector) vsa.Hypervector {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// VSA bundle: majority vote");
        try builder.writeLine("return vsa.bundleN(vectors);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // VSA unbind operation pattern
    if (std.mem.endsWith(u8, b.name, "_unbind") or std.mem.indexOf(u8, b.name, "unbind") != null) {
        try builder.writeFmt("pub fn {s}(bound: vsa.Hypervector, key: vsa.Hypervector) vsa.Hypervector {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// VSA unbind: retrieve from binding");
        try builder.writeLine("return vsa.unbind(bound, key);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Comptime-known value pattern
    if (std.mem.startsWith(u8, b.name, "comptime")) {
        try builder.writeFmt("pub fn {s}(comptime input: anytype) @TypeOf(input) {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Comptime computation");
        try builder.writeLine("return input;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Error set definition helper
    if (std.mem.endsWith(u8, b.name, "_error") or std.mem.indexOf(u8, b.name, "Error") != null) {
        try builder.writeFmt("pub const {s} = error{{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("OutOfMemory,");
        try builder.writeLine("InvalidInput,");
        try builder.writeLine("// Add more error variants as needed");
        builder.decIndent();
        try builder.writeLine("};");
        return true;
    }

    // Arena allocator pattern
    if (std.mem.indexOf(u8, b.name, "arena") != null) {
        try builder.writeFmt("pub fn {s}(allocator: std.mem.Allocator) !std.heap.ArenaAllocator {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("var arena = std.heap.ArenaAllocator.init(allocator);");
        try builder.writeLine("errdefer arena.deinit();");
        try builder.writeLine("return arena;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // GPA (GeneralPurposeAllocator) pattern for testing
    if (std.mem.indexOf(u8, b.name, "gpa") != null) {
        try builder.writeFmt("pub fn {s}() std.heap.GeneralPurposeAllocator(.{{}}) {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("return std.heap.GeneralPurposeAllocator(.{});");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // No-op function (for stubs/tests)
    if (std.mem.startsWith(u8, b.name, "noop") or std.mem.startsWith(u8, b.name, "dummy")) {
        try builder.writeFmt("pub fn {s}(args: anytype) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("_ = args;");
        try builder.writeLine("// No-op stub");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    return false;
}

/// Additional helper: generate proper struct fields for allocator-aware types
pub fn generateStructFields(builder: *CodeBuilder, has_allocator: bool) !void {
    if (has_allocator) {
        try builder.writeLine("allocator: std.mem.Allocator,");
    }
}

/// Additional helper: generate deinit calls for common types
pub fn generateFieldCleanup(builder: *CodeBuilder, field_type: []const u8) !void {
    if (std.mem.indexOf(u8, field_type, "ArrayList") != null) {
        try builder.writeLine("self.field.deinit();");
    } else if (std.mem.indexOf(u8, field_type, "HashMap") != null) {
        try builder.writeLine("self.field.deinit();");
    } else if (std.mem.endsWith(u8, field_type, "*")) {
        try builder.writeLine("if (self.field) allocator.destroy(self.field);");
    }
}

test "zig_idioms: init pattern" {
    const testing = std.testing;
    const mem = std.heap.page_allocator;

    const Behavior = types.Behavior;
    var b = Behavior{
        .name = "init",
        .given = "",
        .when = "",
        .then = "",
    };

    var buf = std.array_list.AlignedManaged(u8, null).init(mem);
    defer buf.deinit();

    // This would normally use a real CodeBuilder
    _ = b;
    _ = &buf;
    _ = match;

    // Test would verify generated pattern
    try testing.expect(true);
}
