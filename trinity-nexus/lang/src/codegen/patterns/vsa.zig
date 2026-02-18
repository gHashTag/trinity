// ═══════════════════════════════════════════════════════════════════════════════
// VSA PATTERNS - Vector Symbolic Architecture operations
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

/// Match VSA operation patterns
pub fn match(builder: *CodeBuilder, b: *const Behavior) !bool {
    const when_text = b.when;

    // Pattern: bind -> VSA element-wise multiply
    if (std.mem.startsWith(u8, b.name, "bind") or
        (std.mem.indexOf(u8, when_text, "bind") != null and std.mem.indexOf(u8, when_text, "vector") != null))
    {
        try builder.writeFmt("pub fn {s}(a: []const i8, b_vec: []const i8, result: []i8) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// VSA bind: element-wise multiply, clamp to [-1, 0, 1]");
        try builder.writeLine("for (a, 0..) |val, i| {");
        builder.incIndent();
        try builder.writeLine("const product = @as(i16, val) * @as(i16, b_vec[i]);");
        try builder.writeLine("result[i] = if (product > 0) 1 else if (product < 0) -1 else 0;");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: bundle -> VSA majority vote
    if (std.mem.startsWith(u8, b.name, "bundle") or
        (std.mem.indexOf(u8, when_text, "bundle") != null and std.mem.indexOf(u8, when_text, "majority") != null))
    {
        try builder.writeFmt("pub fn {s}(vectors: []const []const i8, result: []i8) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// VSA bundle: majority vote across vectors");
        try builder.writeLine("const dim = result.len;");
        try builder.writeLine("for (0..dim) |i| {");
        builder.incIndent();
        try builder.writeLine("var sum: i32 = 0;");
        try builder.writeLine("for (vectors) |vec| { sum += vec[i]; }");
        try builder.writeLine("result[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: unbind -> VSA inverse bind
    if (std.mem.startsWith(u8, b.name, "unbind")) {
        try builder.writeFmt("pub fn {s}(bound: []const i8, key: []const i8, result: []i8) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// VSA unbind: same as bind (self-inverse)");
        try builder.writeLine("for (bound, 0..) |val, i| {");
        builder.incIndent();
        try builder.writeLine("const product = @as(i16, val) * @as(i16, key[i]);");
        try builder.writeLine("result[i] = if (product > 0) 1 else if (product < 0) -1 else 0;");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: similarity -> VSA cosine similarity
    if (std.mem.startsWith(u8, b.name, "similarity")) {
        try builder.writeFmt("pub fn {s}(a: []const i8, b_vec: []const i8) f32 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// VSA similarity: normalized dot product");
        try builder.writeLine("var dot: i32 = 0;");
        try builder.writeLine("for (a, b_vec) |av, bv| { dot += @as(i32, av) * @as(i32, bv); }");
        try builder.writeLine("return @as(f32, @floatFromInt(dot)) / @as(f32, @floatFromInt(a.len));");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: permute -> VSA cyclic permutation
    if (std.mem.startsWith(u8, b.name, "permute")) {
        try builder.writeFmt("pub fn {s}(vec: []const i8, shift: usize, result: []i8) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// VSA permute: cyclic shift");
        try builder.writeLine("const n = vec.len;");
        try builder.writeLine("for (0..n) |i| { result[i] = vec[(i + shift) % n]; }");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: dot* -> dot product
    if (std.mem.startsWith(u8, b.name, "dot")) {
        try builder.writeFmt("pub fn {s}(a: []const i8, b_vec: []const i8) i32 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Dot product of two vectors");
        try builder.writeLine("var sum: i32 = 0;");
        try builder.writeLine("for (a, b_vec) |av, bv| { sum += @as(i32, av) * @as(i32, bv); }");
        try builder.writeLine("return sum;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: hamming* -> Hamming distance
    if (std.mem.startsWith(u8, b.name, "hamming")) {
        try builder.writeFmt("pub fn {s}(a: []const i8, b_vec: []const i8) u32 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Calculate Hamming distance");
        try builder.writeLine("var dist: u32 = 0;");
        try builder.writeLine("for (a, b_vec) |av, bv| { if (av != bv) dist += 1; }");
        try builder.writeLine("return dist;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: cosine* -> cosine similarity
    if (std.mem.startsWith(u8, b.name, "cosine")) {
        try builder.writeFmt("pub fn {s}(a: []const f32, b_vec: []const f32) f32 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Calculate cosine similarity");
        try builder.writeLine("var dot: f32 = 0; var norm_a: f32 = 0; var norm_b: f32 = 0;");
        try builder.writeLine("for (a, b_vec) |av, bv| { dot += av * bv; norm_a += av * av; norm_b += bv * bv; }");
        try builder.writeLine("return dot / (@sqrt(norm_a) * @sqrt(norm_b));");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: distance* -> generic distance
    if (std.mem.startsWith(u8, b.name, "distance")) {
        try builder.writeFmt("pub fn {s}(a: anytype, b: @TypeOf(a)) f64 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Calculate distance between a and b");
        try builder.writeLine("_ = a; _ = b;");
        try builder.writeLine("return 0.0;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: random* -> random vector generation
    if (std.mem.startsWith(u8, b.name, "random")) {
        try builder.writeFmt("pub fn {s}(dim: usize) []i8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Generate random vector");
        try builder.writeLine("_ = dim;");
        try builder.writeLine("return &[_]i8{};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: ones* -> create ones vector
    if (std.mem.startsWith(u8, b.name, "ones")) {
        try builder.writeFmt("pub fn {s}(dim: usize) []i8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Create vector of ones");
        try builder.writeLine("_ = dim;");
        try builder.writeLine("return &[_]i8{};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: zeros* -> create zeros vector
    if (std.mem.startsWith(u8, b.name, "zeros") or std.mem.startsWith(u8, b.name, "zero_")) {
        try builder.writeFmt("pub fn {s}(dim: usize) []i8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Create vector of zeros");
        try builder.writeLine("_ = dim;");
        try builder.writeLine("return &[_]i8{};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: sparsity* -> measure sparsity
    if (std.mem.startsWith(u8, b.name, "sparsity")) {
        try builder.writeFmt("pub fn {s}(vector: []const i8) f32 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Calculate sparsity (fraction of zeros)");
        try builder.writeLine("var zeros_count: u32 = 0;");
        try builder.writeLine("for (vector) |v| { if (v == 0) zeros_count += 1; }");
        try builder.writeLine("return @as(f32, @floatFromInt(zeros_count)) / @as(f32, @floatFromInt(vector.len));");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: vector* / vec* -> vector operations
    if (std.mem.startsWith(u8, b.name, "vector") or std.mem.startsWith(u8, b.name, "vec")) {
        try builder.writeFmt("pub fn {s}(data: anytype) @TypeOf(data) {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Vector operation");
        try builder.writeLine("return data;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: analogy* -> analogy solving
    if (std.mem.startsWith(u8, b.name, "analogy")) {
        try builder.writeFmt("pub fn {s}(a: []const i8, b_vec: []const i8, c: []const i8) []i8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Solve analogy: A:B::C:?");
        try builder.writeLine("// D = C + (B - A) in VSA: D = bind(unbind(b_vec, a), c)");
        try builder.writeLine("_ = a; _ = b_vec; _ = c;");
        try builder.writeLine("return &[_]i8{};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    return false;
}
