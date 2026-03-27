//! VIBEE Codegen Body Emitter — Generated from specs/vibee/body_emitter.tri
//! φ² + 1/φ² = 3 | TRINITY
//!
//! DO NOT EDIT: This file is generated from body_emitter.tri spec
//!
//! Function body code generation for VIBEE

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;

pub const parser_types = @import("gen_parser_types.zig");
pub const emitter = @import("gen_emitter.zig");

// Re-export key types
pub const VibeeSpec = parser_types.VibeeSpec;
pub const TypeDef = parser_types.TypeDef;
pub const Behavior = parser_types.Behavior;
pub const Field = parser_types.Field;
pub const CodeBuilder = emitter.CodeBuilder;

// ============================================================================
// BODY GENERATION CONTEXT
// ============================================================================

/// Context for generating function bodies
pub const BodyContext = struct {
    builder: *CodeBuilder,
    function_name: []const u8,
    return_type: []const u8,
    params: []const Field,
    body_impl: []const u8,

    pub fn init(builder: *CodeBuilder, function_name: []const u8, return_type: []const u8, params: []const Field, body_impl: []const u8) BodyContext {
        return .{
            .builder = builder,
            .function_name = function_name,
            .return_type = return_type,
            .params = params,
            .body_impl = body_impl,
        };
    }
};

// ============================================================================
// BODY GENERATION FUNCTIONS
// ============================================================================

/// Generate simple return body
pub fn generateReturn(ctx: *const BodyContext, value_expr: []const u8) !void {
    const return_stmt = std.fmt.allocPrint(
        ctx.builder.allocator,
        "return {s};\n",
        .{value_expr},
    ) catch return error.OutOfMemory;
    try ctx.builder.append(return_stmt);
}

/// Generate if-else body
pub fn generateIfElse(
    ctx: *const BodyContext,
    condition: []const u8,
    then_expr: []const u8,
    else_expr: []const u8,
) !void {
    try ctx.builder.append("if (");
    try ctx.builder.append(condition);
    try ctx.builder.append(") {\n    ");
    try ctx.builder.append(then_expr);
    try ctx.builder.append("\n} else {\n    ");
    try ctx.builder.append(else_expr);
    try ctx.builder.append("\n}\n");
}

/// Generate for loop body
pub fn generateForLoop(
    ctx: *const BodyContext,
    loop_var: []const u8,
    range_expr: []const u8,
    body_stmts: []const []const u8,
) !void {
    try ctx.builder.append("for (");
    try ctx.builder.append(range_expr);
    try ctx.builder.append(") |");
    try ctx.builder.append(loop_var);
    try ctx.builder.append("| {\n");

    for (body_stmts) |stmt| {
        try ctx.builder.append("    ");
        try ctx.builder.append(stmt);
        try ctx.builder.append("\n");
    }

    try ctx.builder.append("}\n");
}

/// Generate while loop body
pub fn generateWhileLoop(
    ctx: *const BodyContext,
    condition: []const u8,
    body_stmts: []const []const u8,
) !void {
    try ctx.builder.append("while (");
    try ctx.builder.append(condition);
    try ctx.builder.append(") {\n");

    for (body_stmts) |stmt| {
        try ctx.builder.append("    ");
        try ctx.builder.append(stmt);
        try ctx.builder.append("\n");
    }

    try ctx.builder.append("}\n");
}

/// Generate variable assignment
pub fn generateAssignment(
    ctx: *const BodyContext,
    var_name: []const u8,
    value_expr: []const u8,
) !void {
    const assign = std.fmt.allocPrint(
        ctx.builder.allocator,
        "{s} = {s};\n",
        .{ var_name, value_expr },
    ) catch return error.OutOfMemory;
    try ctx.builder.append(assign);
}

/// Generate function call
pub fn generateCall(
    ctx: *const BodyContext,
    func_name: []const u8,
    args: []const []const u8,
) !void {
    // Build arguments string
    var args_str = try ArrayList(u8).initCapacity(ctx.builder.allocator, args.len * 10);
    defer args_str.deinit(ctx.builder.allocator);

    for (args, 0..) |arg, i| {
        if (i > 0) try args_str.append(ctx.builder.allocator, ',');
        try args_str.appendSlice(ctx.builder.allocator, arg);
    }

    const call = std.fmt.allocPrint(
        ctx.builder.allocator,
        "{s}({s});\n",
        .{ func_name, args_str.items },
    ) catch return error.OutOfMemory;
    try ctx.builder.append(call);
}

// ============================================================================
// TESTS
// ============================================================================

test "Body Emitter: generateReturn" {
    const allocator = std.testing.allocator;
    var builder = CodeBuilder.init(allocator);
    defer builder.deinit();

    const ctx = BodyContext.init(&builder, "test", "u32", &.{}, "");
    try generateReturn(&ctx, "42");

    try std.testing.expect(std.mem.indexOf(u8, builder.buffer.items, "return 42") != null);
}

test "Body Emitter: generateIfElse" {
    const allocator = std.testing.allocator;
    var builder = CodeBuilder.init(allocator);
    defer builder.deinit();

    const ctx = BodyContext.init(&builder, "test", "u32", &.{}, "");
    try generateIfElse(&ctx, "x > 0", "return 1", "return 0");

    try std.testing.expect(std.mem.indexOf(u8, builder.buffer.items, "if (x > 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, builder.buffer.items, "return 1") != null);
}

test "Body Emitter: generateAssignment" {
    const allocator = std.testing.allocator;
    var builder = CodeBuilder.init(allocator);
    defer builder.deinit();

    const ctx = BodyContext.init(&builder, "test", "u32", &.{}, "");
    try generateAssignment(&ctx, "result", "42");

    try std.testing.expect(std.mem.indexOf(u8, builder.buffer.items, "result = 42") != null);
}

test "Body Emitter: generateCall" {
    const allocator = std.testing.allocator;
    var builder = CodeBuilder.init(allocator);
    defer builder.deinit();

    const ctx = BodyContext.init(&builder, "test", "u32", &.{}, "");
    const args = [_][]const u8{ "a", "b", "c" };
    try generateCall(&ctx, "foo", &args);

    try std.testing.expect(std.mem.indexOf(u8, builder.buffer.items, "foo") != null);
}

test "Body Emitter: generateForLoop" {
    const allocator = std.testing.allocator;
    var builder = CodeBuilder.init(allocator);
    defer builder.deinit();

    const ctx = BodyContext.init(&builder, "test", "u32", &.{}, "");
    const stmts = [_][]const u8{ "x += 1;", "result += x;" };
    try generateForLoop(&ctx, "i", "0..10", &stmts);

    try std.testing.expect(std.mem.indexOf(u8, builder.buffer.items, "for") != null);
}

test "Body Emitter: generateWhileLoop" {
    const allocator = std.testing.allocator;
    var builder = CodeBuilder.init(allocator);
    defer builder.deinit();

    const ctx = BodyContext.init(&builder, "test", "u32", &.{}, "");
    const stmts = [_][]const u8{ "x += 1;", "result += x;" };
    try generateWhileLoop(&ctx, "x < 10", &stmts);

    try std.testing.expect(std.mem.indexOf(u8, builder.buffer.items, "while (x < 10)") != null);
}

test "Body Emitter: BodyContext init" {
    const allocator = std.testing.allocator;
    var builder = CodeBuilder.init(allocator);
    defer builder.deinit();

    const ctx = BodyContext.init(&builder, "test_func", "u32", &.{}, "body_code");
    try std.testing.expectEqualStrings("test_func", ctx.function_name);
    try std.testing.expectEqualStrings("u32", ctx.return_type);
}
