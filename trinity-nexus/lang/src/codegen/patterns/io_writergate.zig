// ═══════════════════════════════════════════════════════════════════════════════
// WRITERGATE I/O PATTERNS - Zig 0.15 (v8.11)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Features:
// - std.Io.Reader / Writer vtable interface
// - peek(), discard(), splat() methods
// - Generic I/O with anytype
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const CodeBuilder = @import("../builder.zig").CodeBuilder;
const Behavior = @import("../types.zig").Behavior;

/// Generate Reader pattern
/// Matches behavior names with "read", "load", "fetch"
pub fn matchReader(builder: *CodeBuilder, b: *const Behavior) !bool {
    if (std.mem.indexOf(u8, b.name, "read") == null and
        std.mem.indexOf(u8, b.name, "load") == null and
        std.mem.indexOf(u8, b.name, "fetch") == null)
    {
        return false;
    }

    try builder.writeFmt("pub fn {s}(reader: anytype, allocator: std.mem.Allocator) ![]u8 {{\n", .{b.name});
    builder.incIndent();
    try builder.writeLine("// Use std.Io.Reader interface (Zig 0.15)");
    try builder.writeLine("var buffer = std.ArrayList(u8).init(allocator);");
    try builder.writeLine("errdefer buffer.deinit();");
    try builder.writeLine("");
    try builder.writeLine("const chunk_size = 4096;");
    try builder.writeLine("while (true) {");
    builder.incIndent();
    try builder.writeLine("const chunk = try allocator.alloc(u8, chunk_size);");
    try builder.writeLine("defer allocator.free(chunk);");
    try builder.writeLine("");
    try builder.writeLine("const n = try reader.readAll(chunk);");
    try builder.writeLine("if (n == 0) break;");
    try builder.writeLine("try buffer.appendSlice(chunk[0..n]);");
    builder.decIndent();
    try builder.writeLine("}");
    try builder.writeLine("");
    try builder.writeLine("return buffer.toOwnedSlice();");
    builder.decIndent();
    try builder.writeLine("}");
    return true;
}

/// Generate Writer pattern
/// Matches behavior names with "write", "save", "store"
pub fn matchWriter(builder: *CodeBuilder, b: *const Behavior) !bool {
    if (std.mem.indexOf(u8, b.name, "write") == null and
        std.mem.indexOf(u8, b.name, "save") == null and
        std.mem.indexOf(u8, b.name, "store") == null)
    {
        return false;
    }

    try builder.writeFmt("pub fn {s}(writer: anytype, data: []const u8) !void {{\n", .{b.name});
    builder.incIndent();
    try builder.writeLine("// Use std.Io.Writer interface (Zig 0.15)");
    try builder.writeLine("// Ensure all data is written");
    try builder.writeLine("var offset: usize = 0;");
    try builder.writeLine("while (offset < data.len) {");
    builder.incIndent();
    try builder.writeLine("const n = try writer.write(data[offset..]);");
    try builder.writeLine("if (n == 0) return error.BrokenPipe;");
    try builder.writeLine("offset += n;");
    builder.decIndent();
    try builder.writeLine("}");
    try builder.writeLine("");
    try builder.writeLine("// Flush to ensure data is written");
    try builder.writeLine("try writer.flush();");
    builder.decIndent();
    try builder.writeLine("}");
    return true;
}

/// Generate peek pattern (lookahead without consuming)
/// Matches behavior names with "peek", "lookahead", "preview"
pub fn matchPeek(builder: *CodeBuilder, b: *const Behavior) !bool {
    if (std.mem.indexOf(u8, b.name, "peek") == null and
        std.mem.indexOf(u8, b.name, "lookahead") == null and
        std.mem.indexOf(u8, b.name, "preview") == null)
    {
        return false;
    }

    try builder.writeFmt("pub fn {s}(stream: anytype) !u8 {{\n", .{b.name});
    builder.incIndent();
    try builder.writeLine("// Peek at next byte without consuming (Zig 0.15)");
    try builder.writeLine("if (comptime std.meta.hasMethod(@TypeOf(stream), \"peek\")) {");
    builder.incIndent();
    try builder.writeLine("return try stream.peek();");
    builder.decIndent();
    try builder.writeLine("} else {");
    builder.incIndent();
    try builder.writeLine("// Fallback: read and buffer");
    try builder.writeLine("@compileError(\"Stream does not support peek\");");
    builder.decIndent();
    try builder.writeLine("}");
    builder.decIndent();
    try builder.writeLine("}");
    return true;
}

/// Generate discard pattern (skip bytes)
/// Matches behavior names with "discard", "skip", "advance"
pub fn matchDiscard(builder: *CodeBuilder, b: *const Behavior) !bool {
    if (std.mem.indexOf(u8, b.name, "discard") == null and
        std.mem.indexOf(u8, b.name, "skip") == null and
        std.mem.indexOf(u8, b.name, "advance") == null)
    {
        return false;
    }

    try builder.writeFmt("pub fn {s}(stream: anytype, n: usize) !void {{\n", .{b.name});
    builder.incIndent();
    try builder.writeLine("// Discard/skip n bytes (Zig 0.15)");
    try builder.writeLine("if (comptime std.meta.hasMethod(@TypeOf(stream), \"discard\")) {");
    builder.incIndent();
    try builder.writeLine("try stream.discard(n);");
    builder.decIndent();
    try builder.writeLine("} else {");
    builder.incIndent();
    try builder.writeLine("// Fallback: read and ignore");
    try builder.writeLine("var buf: [1024]u8 = undefined;");
    try builder.writeLine("var remaining: usize = n;");
    try builder.writeLine("while (remaining > 0) {");
    builder.incIndent();
    try builder.writeLine("const to_read = @min(remaining, buf.len);");
    try builder.writeLine("const actual = try stream.read(buf[0..to_read]);");
    try builder.writeLine("if (actual == 0) return error.UnexpectedEndOfStream;");
    try builder.writeLine("remaining -= actual;");
    builder.decIndent();
    try builder.writeLine("}");
    builder.decIndent();
    try builder.writeLine("}");
    builder.decIndent();
    try builder.writeLine("}");
    return true;
}

/// Generate splat pattern (write repeated data)
/// Matches behavior names with "splat", "fill", "repeat"
pub fn matchSplat(builder: *CodeBuilder, b: *const Behavior) !bool {
    if (std.mem.indexOf(u8, b.name, "splat") == null and
        std.mem.indexOf(u8, b.name, "fill") == null and
        std.mem.indexOf(u8, b.name, "repeat") == null)
    {
        return false;
    }

    try builder.writeFmt("pub fn {s}(writer: anytype, byte: u8, count: usize) !void {{\n", .{b.name});
    builder.incIndent();
    try builder.writeLine("// Splat: write repeated byte pattern (Zig 0.15)");
    try builder.writeLine("if (comptime std.meta.hasMethod(@TypeOf(writer), \"splat\")) {");
    builder.incIndent();
    try builder.writeLine("try writer.splat(byte, count);");
    builder.decIndent();
    try builder.writeLine("} else {");
    builder.incIndent();
    try builder.writeLine("// Fallback: write chunk by chunk");
    try builder.writeLine("var buf: [4096]u8 = undefined;");
    try builder.writeLine("@memset(buf[0..], byte);");
    try builder.writeLine("");
    try builder.writeLine("var remaining: usize = count;");
    try builder.writeLine("while (remaining > 0) {");
    builder.incIndent();
    try builder.writeLine("const to_write = @min(remaining, buf.len);");
    try builder.writeLine("try writer.writeAll(buf[0..to_write]);");
    try builder.writeLine("remaining -= to_write;");
    builder.decIndent();
    try builder.writeLine("}");
    builder.decIndent();
    try builder.writeLine("}");
    try builder.writeLine("");
    try builder.writeLine("try writer.flush();");
    builder.decIndent();
    try builder.writeLine("}");
    return true;
}

/// Generate buffered reader wrapper
/// Matches behavior names with "buffered", "buffer"
pub fn matchBuffered(builder: *CodeBuilder, b: *const Behavior) !bool {
    if (std.mem.indexOf(u8, b.name, "buffered") == null and
        std.mem.indexOf(u8, b.name, "buffer") == null)
    {
        return false;
    }

    try builder.writeFmt("pub fn {s}(source: anytype, size: usize) !std.io.BufferedReader(size, @TypeOf(source)) {{\n", .{b.name});
    builder.incIndent();
    try builder.writeLine("// Create buffered reader (Zig 0.15 std.io)");
    try builder.writeLine("return std.io.bufferedReader(source, .{ .size = size });");
    builder.decIndent();
    try builder.writeLine("}");
    return true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MATCH ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

/// Match any I/O-related pattern
pub fn match(builder: *CodeBuilder, b: *const Behavior) !bool {
    if (try matchReader(builder, b)) return true;
    if (try matchWriter(builder, b)) return true;
    if (try matchPeek(builder, b)) return true;
    if (try matchDiscard(builder, b)) return true;
    if (try matchSplat(builder, b)) return true;
    if (try matchBuffered(builder, b)) return true;
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "writergate: matchReader" {
    const testing = std.testing;
    const mem = std.heap.page_allocator;

    var buf = std.array_list.ArrayList(u8).init(mem);
    defer buf.deinit();

    const writer = buf.writer();
    var builder = CodeBuilder.init(mem);
    builder.setOutputWriter(writer);

    const b = Behavior{
        .name = "readFile",
        .given = "",
        .when = "",
        .then = "",
        .implementation = "",
        .test_cases = &.{},
    };

    const matched = try match(&builder, &b);
    try testing.expect(matched);

    const output = buf.items;
    try testing.expect(std.mem.indexOf(u8, output, "std.Io.Reader") != null);
}

test "writergate: matchWriter" {
    const testing = std.testing;
    const mem = std.heap.page_allocator;

    var buf = std.array_list.ArrayList(u8).init(mem);
    defer buf.deinit();

    const writer = buf.writer();
    var builder = CodeBuilder.init(mem);
    builder.setOutputWriter(writer);

    const b = Behavior{
        .name = "writeData",
        .given = "",
        .when = "",
        .then = "",
        .implementation = "",
        .test_cases = &.{},
    };

    const matched = try match(&builder, &b);
    try testing.expect(matched);

    const output = buf.items;
    try testing.expect(std.mem.indexOf(u8, output, "std.Io.Writer") != null);
}

const Behavior = @import("../types.zig").Behavior;
