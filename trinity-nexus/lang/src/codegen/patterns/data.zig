// ═══════════════════════════════════════════════════════════════════════════════
// DATA PATTERNS - Format & Data Transform (FDT: 13%)
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

/// Match data transform patterns
pub fn match(builder: *CodeBuilder, b: *const Behavior) !bool {
    // Pattern: encode* -> ternary encoding (byte → 6 trits)
    if (std.mem.startsWith(u8, b.name, "encode")) {
        try builder.writeFmt("pub fn {s}(input: []const u8, output: []i8) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Ternary encoding: each byte → 6 balanced trits");
        try builder.writeLine("// 3^6 = 729 > 256, so 6 trits suffice for 1 byte");
        try builder.writeLine("for (input, 0..) |byte, i| {");
        builder.incIndent();
        try builder.writeLine("var val = @as(i16, byte) - 128; // center around 0");
        try builder.writeLine("const base = i * 6;");
        try builder.writeLine("for (0..6) |t| {");
        builder.incIndent();
        try builder.writeLine("const rem = @mod(val + 1, 3) - 1; // balanced mod: -1, 0, 1");
        try builder.writeLine("output[base + t] = @as(i8, @intCast(rem));");
        try builder.writeLine("val = @divTrunc(val - rem, 3);");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: decode* -> ternary decoding (6 trits → byte)
    if (std.mem.startsWith(u8, b.name, "decode")) {
        try builder.writeFmt("pub fn {s}(trits: []const i8, output: []u8) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Ternary decoding: 6 balanced trits → 1 byte");
        try builder.writeLine("const n_bytes = trits.len / 6;");
        try builder.writeLine("for (0..n_bytes) |i| {");
        builder.incIndent();
        try builder.writeLine("var val: i16 = 0;");
        try builder.writeLine("var power: i16 = 1;");
        try builder.writeLine("for (0..6) |t| {");
        builder.incIndent();
        try builder.writeLine("val += @as(i16, trits[i * 6 + t]) * power;");
        try builder.writeLine("power *= 3;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("output[i] = @as(u8, @intCast(val + 128));");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: quantize* -> float-to-ternary quantization
    if (std.mem.startsWith(u8, b.name, "quantize")) {
        try builder.writeFmt("pub fn {s}(values: []const f32, output: []i8, threshold: f32) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Ternary quantization: >threshold → 1, <-threshold → -1, else 0");
        try builder.writeLine("for (values, 0..) |v, i| {");
        builder.incIndent();
        try builder.writeLine("output[i] = if (v > threshold) 1 else if (v < -threshold) -1 else 0;");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: dequantize* -> dequantization
    if (std.mem.startsWith(u8, b.name, "dequantize")) {
        try builder.writeFmt("pub fn {s}(values: []const i8, scale: f32) []f32 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Dequantize int8 to float: f32 = int8 * scale");
        try builder.writeLine("const result = builder.allocator.alloc(f32, values.len) catch return &[_]f32{};");
        try builder.writeLine("for (values, 0..) |v, i| { result[i] = @as(f32, @floatFromInt(v)) * scale; }");
        try builder.writeLine("return result;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: pack* -> pack data
    if (std.mem.startsWith(u8, b.name, "pack")) {
        try builder.writeFmt("pub fn {s}(trits: []const i8) []u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Pack 5 trits (-1,0,1) into 1 byte (3^5=243 < 256)");
        try builder.writeLine("const num_bytes = (trits.len + 4) / 5;");
        try builder.writeLine("var result = try builder.allocator.alloc(u8, num_bytes);");
        try builder.writeLine("for (0..num_bytes) |byte_idx| {");
        builder.incIndent();
        try builder.writeLine("var val: u8 = 0;");
        try builder.writeLine("for (0..5) |trit_idx| {");
        builder.incIndent();
        try builder.writeLine("const trit = if (byte_idx * 5 + trit_idx < trits.len) trits[byte_idx * 5 + trit_idx] else 0;");
        try builder.writeLine("const encoded = @as(u8, @intCast(@as(i8, @intCast(trit)) + 1)); // -1,0,1 -> 0,1,2");
        try builder.writeLine("val |= encoded << (3 * trit_idx);");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("result[byte_idx] = val;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("return result;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: unpack* -> unpack data
    if (std.mem.startsWith(u8, b.name, "unpack")) {
        try builder.writeFmt("pub fn {s}(bytes: []const u8) []i8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Unpack 1 byte into 5 trits");
        try builder.writeLine("const num_trits = bytes.len * 5;");
        try builder.writeLine("var result = try builder.allocator.alloc(i8, num_trits);");
        try builder.writeLine("for (bytes, 0..) |b, byte_idx| {");
        builder.incIndent();
        try builder.writeLine("for (0..5) |trit_idx| {");
        builder.incIndent();
        try builder.writeLine("const encoded = (b >> (3 * trit_idx)) & 0x07; // 3 bits per trit");
        try builder.writeLine("result[byte_idx * 5 + trit_idx] = @as(i8, @intCast(encoded)) - 1; // 0,1,2 -> -1,0,1");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("return result;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: compress* -> compression
    if (std.mem.startsWith(u8, b.name, "compress")) {
        try builder.writeFmt("pub fn {s}(data: []const u8) []u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Compress data");
        try builder.writeLine("_ = data;");
        try builder.writeLine("return &[_]u8{};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: serialize* -> serialization
    if (std.mem.startsWith(u8, b.name, "serialize")) {
        try builder.writeFmt("pub fn {s}(value: anytype, allocator: std.mem.Allocator) ![]u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Serialize to length-prefixed bytes");
        try builder.writeLine("_ = value;");
        try builder.writeLine("return allocator.alloc(u8, 0);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: deserialize* -> deserialization
    if (std.mem.startsWith(u8, b.name, "deserialize")) {
        try builder.writeFmt("pub fn {s}(bytes: []const u8, comptime T: type) !T {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Deserialize from length-prefixed bytes");
        try builder.writeLine("_ = bytes;");
        try builder.writeLine("return error.NotImplemented;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: transform* -> transformation
    if (std.mem.startsWith(u8, b.name, "transform")) {
        try builder.writeFmt("pub fn {s}(input: []const f32, output: []f32, func: *const fn (f32) f32) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Apply function to each element");
        try builder.writeLine("for (input, 0..) |v, i| { output[i] = func(v); }");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: convert* -> conversion
    if (std.mem.startsWith(u8, b.name, "convert")) {
        try builder.writeFmt("pub fn {s}(input: anytype, target_format: anytype) @TypeOf(input) {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Convert between formats");
        try builder.writeLine("_ = target_format;");
        try builder.writeLine("return input;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: normalize* -> min-max normalization
    if (std.mem.startsWith(u8, b.name, "normalize")) {
        try builder.writeFmt("pub fn {s}(input: []const f32, output: []f32) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Min-max normalization: (x - min) / (max - min)");
        try builder.writeLine("var min_val: f32 = input[0];");
        try builder.writeLine("var max_val: f32 = input[0];");
        try builder.writeLine("for (input) |v| {");
        builder.incIndent();
        try builder.writeLine("if (v < min_val) min_val = v;");
        try builder.writeLine("if (v > max_val) max_val = v;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("const range = max_val - min_val;");
        try builder.writeLine("if (range == 0) { @memset(output, 0); return; }");
        try builder.writeLine("for (input, 0..) |v, i| { output[i] = (v - min_val) / range; }");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: format* -> formatting
    if (std.mem.startsWith(u8, b.name, "format")) {
        try builder.writeFmt("pub fn {s}(data: anytype) []const u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Format data as string");
        try builder.writeLine("_ = data;");
        try builder.writeLine("return \"\";");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: parse* -> parsing
    if (std.mem.startsWith(u8, b.name, "parse")) {
        try builder.writeFmt("pub fn {s}(input: []const u8) !ParseResult {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Parse input");
        try builder.writeLine("_ = input;");
        try builder.writeLine("return ParseResult{};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: token* -> tokenization
    if (std.mem.startsWith(u8, b.name, "token")) {
        try builder.writeFmt("pub fn {s}(text: []const u8, allocator: std.mem.Allocator) ![][]const u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Simple whitespace tokenization");
        try builder.writeLine("var tokens = std.ArrayList([]const u8).init(allocator);");
        try builder.writeLine("var iter = std.mem.tokenizeScalar(u8, text, ' ');");
        try builder.writeLine("while (iter.next()) |token| { try tokens.append(token); }");
        try builder.writeLine("return tokens.toOwnedSlice();");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: translate* -> translation
    if (std.mem.startsWith(u8, b.name, "translate")) {
        try builder.writeFmt("pub fn {s}(text: []const u8, target_lang: []const u8) []const u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Translate text");
        try builder.writeLine("_ = text; _ = target_lang;");
        try builder.writeLine("return \"Translation placeholder\";");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: explain* -> explanation
    if (std.mem.startsWith(u8, b.name, "explain")) {
        try builder.writeFmt("pub fn {s}(input: []const u8) []const u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Generate explanation");
        try builder.writeLine("_ = input;");
        try builder.writeLine("return \"Explanation placeholder\";");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: summarize* -> summarization
    if (std.mem.startsWith(u8, b.name, "summarize")) {
        try builder.writeFmt("pub fn {s}(content: []const u8) []const u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Summarize content");
        try builder.writeLine("_ = content;");
        try builder.writeLine("return \"Summary placeholder\";");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: extract* -> extraction
    if (std.mem.startsWith(u8, b.name, "extract")) {
        try builder.writeFmt("pub fn {s}(source: anytype) ExtractResult {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Extract data from source");
        try builder.writeLine("_ = source;");
        try builder.writeLine("return ExtractResult{};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: split* -> splitting
    if (std.mem.startsWith(u8, b.name, "split")) {
        try builder.writeFmt("pub fn {s}(data: []const u8, delimiter: u8, allocator: std.mem.Allocator) ![][]const u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Split data by delimiter");
        try builder.writeLine("var parts = std.ArrayList([]const u8).init(allocator);");
        try builder.writeLine("var iter = std.mem.tokenizeScalar(u8, data, delimiter);");
        try builder.writeLine("while (iter.next()) |part| { try parts.append(part); }");
        try builder.writeLine("return parts.toOwnedSlice();");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: chunk* -> chunking
    if (std.mem.startsWith(u8, b.name, "chunk")) {
        try builder.writeFmt("pub fn {s}(data: anytype, size: usize) []@TypeOf(data) {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Split into chunks of given size");
        try builder.writeLine("_ = data; _ = size;");
        try builder.writeLine("return &[_]@TypeOf(data){};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: fallback* -> fallback handling
    if (std.mem.startsWith(u8, b.name, "fallback")) {
        try builder.writeFmt("pub fn {s}(primary: anytype, backup: @TypeOf(primary)) @TypeOf(primary) {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Return backup if primary fails");
        try builder.writeLine("_ = backup;");
        try builder.writeLine("return primary;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: honest* -> honest response
    if (std.mem.startsWith(u8, b.name, "honest")) {
        try builder.writeFmt("pub fn {s}(query: []const u8) []const u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Honest response (acknowledge limitations)");
        try builder.writeLine("_ = query;");
        try builder.writeLine("return \"I cannot do that as an AI.\";");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: unknown* -> unknown handling
    if (std.mem.startsWith(u8, b.name, "unknown")) {
        try builder.writeFmt("pub fn {s}(input: []const u8) []const u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Handle unknown input honestly");
        try builder.writeLine("_ = input;");
        try builder.writeLine("return \"I don't know the answer to that.\";");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    return false;
}
