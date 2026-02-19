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

    // Pattern: distance* -> cosine distance (1 - cosine_similarity)
    if (std.mem.startsWith(u8, b.name, "distance")) {
        try builder.writeFmt("pub fn {s}(a: []const i8, b_vec: []const i8) f32 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Cosine distance: 1.0 - dot(a,b) / (|a| * |b|)");
        try builder.writeLine("var dot: i32 = 0;");
        try builder.writeLine("var norm_a: i32 = 0;");
        try builder.writeLine("var norm_b: i32 = 0;");
        try builder.writeLine("for (a, b_vec) |av, bv| {");
        builder.incIndent();
        try builder.writeLine("dot += @as(i32, av) * @as(i32, bv);");
        try builder.writeLine("norm_a += @as(i32, av) * @as(i32, av);");
        try builder.writeLine("norm_b += @as(i32, bv) * @as(i32, bv);");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("const denom = @sqrt(@as(f32, @floatFromInt(norm_a))) * @sqrt(@as(f32, @floatFromInt(norm_b)));");
        try builder.writeLine("if (denom == 0) return 1.0;");
        try builder.writeLine("return 1.0 - @as(f32, @floatFromInt(dot)) / denom;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: random* -> random ternary vector via xorshift64
    if (std.mem.startsWith(u8, b.name, "random")) {
        try builder.writeFmt("pub fn {s}(result: []i8, seed: u64) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Generate random ternary vector via xorshift64");
        try builder.writeLine("var state = seed;");
        try builder.writeLine("for (result) |*r| {");
        builder.incIndent();
        try builder.writeLine("state ^= state << 13;");
        try builder.writeLine("state ^= state >> 7;");
        try builder.writeLine("state ^= state << 17;");
        try builder.writeLine("const rem = state % 3;");
        try builder.writeLine("r.* = if (rem == 0) -1 else if (rem == 1) 0 else 1;");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: ones* -> fill vector with 1s
    if (std.mem.startsWith(u8, b.name, "ones")) {
        try builder.writeFmt("pub fn {s}(result: []i8) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Fill vector with ones");
        try builder.writeLine("@memset(result, 1);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: zeros* -> fill vector with 0s
    if (std.mem.startsWith(u8, b.name, "zeros") or std.mem.startsWith(u8, b.name, "zero_")) {
        try builder.writeFmt("pub fn {s}(result: []i8) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Fill vector with zeros");
        try builder.writeLine("@memset(result, 0);");
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

    // Pattern: vector* / vec* -> vector copy
    if (std.mem.startsWith(u8, b.name, "vector") or std.mem.startsWith(u8, b.name, "vec")) {
        try builder.writeFmt("pub fn {s}(src: []const i8, dst: []i8) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Copy vector: src → dst");
        try builder.writeLine("@memcpy(dst, src);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: analogy* -> analogy solving: D = bind(unbind(B,A), C)
    if (std.mem.startsWith(u8, b.name, "analogy")) {
        try builder.writeFmt("pub fn {s}(a: []const i8, b_vec: []const i8, c: []const i8, result: []i8) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Solve analogy A:B::C:? → D = bind(unbind(B,A), C)");
        try builder.writeLine("for (a, 0..) |av, i| {");
        builder.incIndent();
        try builder.writeLine("// unbind: B * A (self-inverse)");
        try builder.writeLine("const unbound = @as(i16, b_vec[i]) * @as(i16, av);");
        try builder.writeLine("const ub: i8 = if (unbound > 0) 1 else if (unbound < 0) -1 else 0;");
        try builder.writeLine("// bind: unbound * C");
        try builder.writeLine("const bound = @as(i16, ub) * @as(i16, c[i]);");
        try builder.writeLine("result[i] = if (bound > 0) 1 else if (bound < 0) -1 else 0;");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    return false;
}
