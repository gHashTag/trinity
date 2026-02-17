// ═══════════════════════════════════════════════════════════════════════════════
// DSL PATTERNS - $fs, $http, $json, $crypto, $db
// ═══════════════════════════════════════════════════════════════════════════════
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("../types.zig");
const builder_mod = @import("../builder.zig");

const CodeBuilder = builder_mod.CodeBuilder;
const Behavior = types.Behavior;

/// Try to generate code from DSL patterns like $fs.*, $http.*, etc.
pub fn match(builder: *CodeBuilder, b: *const Behavior) !bool {
    const when_text = b.when;

    // $fs.read pattern
    if (std.mem.indexOf(u8, when_text, "$fs.read") != null) {
        try builder.writeFmt("pub fn {s}(path: []const u8) ![]const u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("const file = try std.fs.cwd().openFile(path, .{});");
        try builder.writeLine("defer file.close();");
        try builder.writeLine("return try file.readToEndAlloc(std.heap.page_allocator, 1024 * 1024);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // $fs.write pattern
    if (std.mem.indexOf(u8, when_text, "$fs.write") != null) {
        try builder.writeFmt("pub fn {s}(path: []const u8, content: []const u8) !void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("const file = try std.fs.cwd().createFile(path, .{});");
        try builder.writeLine("defer file.close();");
        try builder.writeLine("try file.writeAll(content);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // $fs.exists pattern
    if (std.mem.indexOf(u8, when_text, "$fs.exists") != null) {
        try builder.writeFmt("pub fn {s}(path: []const u8) bool {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("std.fs.cwd().access(path, .{}) catch return false;");
        try builder.writeLine("return true;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // $http.get pattern
    if (std.mem.indexOf(u8, when_text, "$http.get") != null) {
        try builder.writeFmt("pub fn {s}(url: []const u8) ![]const u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// HTTP GET request");
        try builder.writeLine("_ = url;");
        try builder.writeLine("return \"HTTP response placeholder\";");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // $http.post pattern
    if (std.mem.indexOf(u8, when_text, "$http.post") != null) {
        try builder.writeFmt("pub fn {s}(url: []const u8, body: []const u8) ![]const u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// HTTP POST request");
        try builder.writeLine("_ = url; _ = body;");
        try builder.writeLine("return \"HTTP response placeholder\";");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // $json.parse pattern
    if (std.mem.indexOf(u8, when_text, "$json.parse") != null) {
        try builder.writeFmt("pub fn {s}(json_str: []const u8) !std.json.Value {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("var parser = std.json.Parser.init(std.heap.page_allocator, false);");
        try builder.writeLine("defer parser.deinit();");
        try builder.writeLine("return try parser.parse(json_str);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // $json.stringify pattern
    if (std.mem.indexOf(u8, when_text, "$json.stringify") != null) {
        try builder.writeFmt("pub fn {s}(value: anytype) ![]const u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("var buffer: [4096]u8 = undefined;");
        try builder.writeLine("var stream = std.io.fixedBufferStream(&buffer);");
        try builder.writeLine("try std.json.stringify(value, .{}, stream.writer());");
        try builder.writeLine("return buffer[0..stream.pos];");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // $crypto.hash pattern
    if (std.mem.indexOf(u8, when_text, "$crypto.hash") != null) {
        try builder.writeFmt("pub fn {s}(data: []const u8) [32]u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("var hash: [32]u8 = undefined;");
        try builder.writeLine("std.crypto.hash.sha2.Sha256.hash(data, &hash, .{});");
        try builder.writeLine("return hash;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // $db.query pattern
    if (std.mem.indexOf(u8, when_text, "$db.query") != null) {
        try builder.writeFmt("pub fn {s}(query: []const u8) ![]const u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Database query placeholder");
        try builder.writeLine("_ = query;");
        try builder.writeLine("return \"Query result placeholder\";");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    return false;
}
