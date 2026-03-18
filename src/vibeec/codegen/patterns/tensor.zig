// ═══════════════════════════════════════════════════════════════════════════════
// TENSOR PATTERNS - Multi-dimensional tensor operations
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

/// Match tensor operation patterns
pub fn match(builder: *CodeBuilder, b: *const Behavior) !bool {
    const when_text = b.when;

    // Pattern: tensor_create* -> create tensor from data
    if (std.mem.startsWith(u8, b.name, "tensor_create") or
        (std.mem.indexOf(u8, when_text, "tensor") != null and std.mem.indexOf(u8, when_text, "create") != null))
    {
        try builder.writeFmt("pub fn {s}(allocator: std.mem.Allocator, data: []const f32, shape: []const usize) !Tensor {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Create tensor from data with shape");
        try builder.writeLine("const total_size = blk: {");
        builder.incIndent();
        try builder.writeLine("var prod: usize = 1;");
        try builder.writeLine("for (shape) |s| prod *= s;");
        try builder.writeLine("break :blk prod;");
        builder.decIndent();
        try builder.writeLine("};");
        try builder.writeLine("const buffer = try allocator.alloc(f32, total_size);");
        try builder.writeLine("@memcpy(buffer, data[0..total_size]);");
        try builder.writeLine("");
        try builder.writeLine("const shape_copy = try allocator.dupe(usize, shape);");
        try builder.writeLine("");
        try builder.writeLine("return Tensor{");
        try builder.writeLine("    .allocator = allocator,");
        try builder.writeLine("    .data = buffer,");
        try builder.writeLine("    .shape = shape_copy,");
        try builder.writeLine("    .ndim = shape.len,");
        try builder.writeLine("};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: tensor_add* -> element-wise tensor addition
    if (std.mem.startsWith(u8, b.name, "tensor_add") or
        (std.mem.indexOf(u8, when_text, "tensor") != null and std.mem.indexOf(u8, when_text, "add") != null))
    {
        try builder.writeFmt("pub fn {s}(allocator: std.mem.Allocator, a: Tensor, b: Tensor) !Tensor {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Element-wise tensor addition");
        try builder.writeLine("// Check shapes match");
        try builder.writeLine("if (a.ndim != b.ndim) return error.ShapeMismatch;");
        try builder.writeLine("for (0..a.ndim) |i| {");
        builder.incIndent();
        try builder.writeLine("if (a.shape[i] != b.shape[i]) return error.ShapeMismatch;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("const result_data = try allocator.alloc(f32, a.data.len);");
        try builder.writeLine("for (a.data, b.data, 0..) |av, bv, i| {");
        builder.incIndent();
        try builder.writeLine("result_data[i] = av + bv;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("return Tensor{");
        try builder.writeLine("    .allocator = allocator,");
        try builder.writeLine("    .data = result_data,");
        try builder.writeLine("    .shape = try allocator.dupe(usize, a.shape),");
        try builder.writeLine("    .ndim = a.ndim,");
        try builder.writeLine("};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: tensor_mul* -> element-wise tensor multiplication
    if (std.mem.startsWith(u8, b.name, "tensor_mul") or
        (std.mem.indexOf(u8, when_text, "tensor") != null and std.mem.indexOf(u8, when_text, "multiply") != null))
    {
        try builder.writeFmt("pub fn {s}(allocator: std.mem.Allocator, a: Tensor, b: Tensor) !Tensor {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Element-wise tensor multiplication");
        try builder.writeLine("// Check shapes match");
        try builder.writeLine("if (a.ndim != b.ndim) return error.ShapeMismatch;");
        try builder.writeLine("for (0..a.ndim) |i| {");
        builder.incIndent();
        try builder.writeLine("if (a.shape[i] != b.shape[i]) return error.ShapeMismatch;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("const result_data = try allocator.alloc(f32, a.data.len);");
        try builder.writeLine("for (a.data, b.data, 0..) |av, bv, i| {");
        builder.incIndent();
        try builder.writeLine("result_data[i] = av * bv;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("return Tensor{");
        try builder.writeLine("    .allocator = allocator,");
        try builder.writeLine("    .data = result_data,");
        try builder.writeLine("    .shape = try allocator.dupe(usize, a.shape),");
        try builder.writeLine("    .ndim = a.ndim,");
        try builder.writeLine("};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: tensor_matmul* -> matrix multiplication
    if (std.mem.startsWith(u8, b.name, "tensor_matmul") or
        (std.mem.indexOf(u8, when_text, "tensor") != null and std.mem.indexOf(u8, when_text, "matmul") != null))
    {
        try builder.writeFmt("pub fn {s}(allocator: std.mem.Allocator, a: Tensor, b: Tensor) !Tensor {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Matrix multiplication: C = A @ B");
        try builder.writeLine("// A: (m, k), B: (k, n) -> C: (m, n)");
        try builder.writeLine("if (a.ndim != 2 or b.ndim != 2) return error.NotMatrix;");
        try builder.writeLine("if (a.shape[1] != b.shape[0]) return error.DimensionMismatch;");
        try builder.writeLine("");
        try builder.writeLine("const m = a.shape[0];");
        try builder.writeLine("const k = a.shape[1];");
        try builder.writeLine("const n = b.shape[1];");
        try builder.writeLine("");
        try builder.writeLine("const result_data = try allocator.alloc(f32, m * n);");
        try builder.writeLine("@memset(result_data, 0);");
        try builder.writeLine("");
        try builder.writeLine("// Naive O(m*k*n) matrix multiplication");
        try builder.writeLine("for (0..m) |i| {");
        builder.incIndent();
        try builder.writeLine("for (0..n) |j| {");
        builder.incIndent();
        try builder.writeLine("var sum: f32 = 0;");
        try builder.writeLine("for (0..k) |p| {");
        builder.incIndent();
        try builder.writeLine("sum += a.data[i * k + p] * b.data[p * n + j];");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("result_data[i * n + j] = sum;");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("return Tensor{");
        try builder.writeLine("    .allocator = allocator,");
        try builder.writeLine("    .data = result_data,");
        try builder.writeLine("    .shape = &[_]usize{ m, n },");
        try builder.writeLine("    .ndim = 2,");
        try builder.writeLine("};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TENSOR TYPE DEFINITION (generated with patterns)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Tensor = struct {
    allocator: std.mem.Allocator,
    data: []f32,
    shape: []usize,
    ndim: usize,

    pub fn deinit(self: *const Tensor) void {
        self.allocator.free(self.data);
        self.allocator.free(self.shape);
    }

    pub fn size(self: *const Tensor) usize {
        return self.data.len;
    }
};
