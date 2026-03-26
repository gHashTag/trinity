// ═══════════════════════════════════════════════════════════════════
// IntegrationTest (GENERATED from .tri spec)
// TTT Dogfood v0.1: Self-hosted codegen
// DO NOT EDIT — Generated from specs/tri-lang/integration_test.tri
//
// Integration Tests for Tri Language
// Tests end-to-end compilation from expressions to bytecode
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════

const std = @import("std");

const TypedExpr = @import("typechecker.zig").TypedExpr;
const compile = @import("pipeline.zig").compile;

fn buildReticularRapheExpr(allocator: std.mem.Allocator) !*TypedExpr {
    const x_var = try allocator.create(TypedExpr);
    x_var.* = .{ .Var = .{ .name = "x" } };
    const y_var = try allocator.create(TypedExpr);
    y_var.* = .{ .Var = .{ .name = "y" } };
    const then_body = try allocator.create(TypedExpr);
    then_body.* = .{ .BinOp = .{ .left = x_var, .op = .Add, .right = y_var } };

    const x_var2 = try allocator.create(TypedExpr);
    x_var2.* = .{ .Var = .{ .name = "x" } };
    const y_var2 = try allocator.create(TypedExpr);
    y_var2.* = .{ .Var = .{ .name = "y" } };
    const else_body = try allocator.create(TypedExpr);
    else_body.* = .{ .BinOp = .{ .left = x_var2, .op = .Sub, .right = y_var2 } };

    const cond = try allocator.create(TypedExpr);
    cond.* = .{ .Bool = .{ .value = true } };
    const if_expr = try allocator.create(TypedExpr);
    if_expr.* = .{ .If = .{ .condition = cond, .then_branch = then_body, .else_branch = else_body } };

    const y_val = try allocator.create(TypedExpr);
    y_val.* = .{ .Int = .{ .value = 10 } };
    const let_y = try allocator.create(TypedExpr);
    let_y.* = .{ .Let = .{ .name = "y", .value = y_val, .body = if_expr } };

    const x_val = try allocator.create(TypedExpr);
    x_val.* = .{ .Int = .{ .value = 42 } };
    const result = try allocator.create(TypedExpr);
    result.* = .{ .Let = .{ .name = "x", .value = x_val, .body = let_y } };

    return result;
}

test "integration: reticular raphe compiles" {
    const a = std.testing.allocator;
    const expr = try buildReticularRapheExpr(a);

    const result = try compile(a, expr);
    defer result.deinit(a);

    try std.testing.expect(result.bytecode.len > 0);
    try std.testing.expect(result.inferred_type == .Int);
}

test "integration: bytecode has LOADI" {
    const a = std.testing.allocator;
    const expr = try buildReticularRapheExpr(a);

    const result = try compile(a, expr);
    defer result.deinit(a);

    var has_loadi = false;
    for (result.bytecode) |byte| {
        if (byte == 0x10) has_loadi = true;
    }
    try std.testing.expect(has_loadi);
}

test "integration: write .t27 file" {
    const a = std.testing.allocator;
    const expr = try buildReticularRapheExpr(a);

    const result = try compile(a, expr);
    defer result.deinit(a);

    const tmp_path = "tmp_reticular_raphe.t27";
    defer std.fs.cwd().deleteFile(tmp_path) catch {};

    const file = try std.fs.cwd().createFile(tmp_path, .{});
    defer file.close();
    try file.writeAll(result.bytecode);

    const content = try std.fs.cwd().readFileAlloc(a, tmp_path, 1024);
    defer a.free(content);

    try std.testing.expectEqualStrings(result.bytecode, content);
}

// ═══════════════════════════════════════════════════════════════════════
// WAVE 3: EFFECTS + HANDLERS INTEGRATION TESTS
// ═════════════════════════════════════════════════════════════════════════════════════

fn buildPerformExpr(allocator: std.mem.Allocator) !*TypedExpr {
    // perform state.get()
    const arg = try allocator.create(TypedExpr);
    arg.* = .{ .Int = .{ .value = 42 } };

    const args = try allocator.alloc(*const TypedExpr, 1);
    args[0] = arg;

    const perform = try allocator.create(TypedExpr);
    perform.* = .{ .Perform = .{
        .effect_name = "State",
        .operation = "get",
        .args = args,
    } };

    return perform;
}

fn buildHandleExpr(allocator: std.mem.Allocator) !*TypedExpr {
    // handle state { get(x) => x }
    const body = try allocator.create(TypedExpr);
    body.* = .{ .Int = .{ .value = 0 } };

    const param = try allocator.create(TypedExpr);
    param.* = .{ .Var = .{ .name = "x" } };

    const handler_body = try allocator.create(TypedExpr);
    handler_body.* = .{ .Var = .{ .name = "x" } };

    const clauses = try allocator.create(@import("typechecker.zig").HandlerClauseTyped);
    clauses.* = .{
        .operation = "get",
        .param_pattern = .{ .Var = "x" },
        .body = handler_body,
    };

    const clause_slice = try allocator.alloc(@import("typechecker.zig").HandlerClauseTyped, 1);
    clause_slice[0] = clauses.*;

    const handle = try allocator.create(TypedExpr);
    handle.* = .{ .Handle = .{
        .effect_name = "State",
        .clauses = clause_slice,
        .body = body,
    } };

    return handle;
}

fn buildTryExpr(allocator: std.mem.Allocator) !*TypedExpr {
    // try { perform state.get() } with { get(x) => x }
    const perform = try buildPerformExpr(allocator);

    const handler_body = try allocator.create(TypedExpr);
    handler_body.* = .{ .Var = .{ .name = "x" } };

    const clauses = try allocator.create(@import("typechecker.zig").HandlerClauseTyped);
    clauses.* = .{
        .operation = "get",
        .param_pattern = .{ .Var = "x" },
        .body = handler_body,
    };

    const clause_slice = try allocator.alloc(@import("typechecker.zig").HandlerClauseTyped, 1);
    clause_slice[0] = clauses.*;

    const try_expr = try allocator.create(TypedExpr);
    try_expr.* = .{ .Try = .{
        .computation = perform,
        .handlers = clause_slice,
    } };

    return try_expr;
}

test "integration: perform expression compiles" {
    const a = std.testing.allocator;
    const expr = try buildPerformExpr(a);

    const result = try compile(a, expr);
    defer result.deinit(a);

    try std.testing.expect(result.bytecode.len > 0);
}

test "integration: perform bytecode has EFFECT_PERFORM" {
    const a = std.testing.allocator;
    const expr = try buildPerformExpr(a);

    const result = try compile(a, expr);
    defer result.deinit(a);

    // Check for EFFECT_PERFORM opcode (0x7A)
    var has_effect_perform = false;
    for (result.bytecode) |byte| {
        if (byte == 0x7A) has_effect_perform = true;
    }
    try std.testing.expect(has_effect_perform);
}

test "integration: handle expression compiles" {
    const a = std.testing.allocator;
    const expr = try buildHandleExpr(a);

    const result = try compile(a, expr);
    defer result.deinit(a);

    try std.testing.expect(result.bytecode.len > 0);
}

test "integration: try expression compiles" {
    const a = std.testing.allocator;
    const expr = try buildTryExpr(a);

    const result = try compile(a, expr);
    defer result.deinit(a);

    try std.testing.expect(result.bytecode.len > 0);
}

test "integration: try bytecode has both opcodes" {
    const a = std.testing.allocator;
    const expr = try buildTryExpr(a);

    const result = try compile(a, expr);
    defer result.deinit(a);

    // Check for EFFECT_PERFORM (0x7A) and EFFECT_HANDLE (0x7B)
    var has_perform = false;
    var has_handle = false;
    for (result.bytecode) |byte| {
        if (byte == 0x7A) has_perform = true;
        if (byte == 0x7B) has_handle = true;
    }
    try std.testing.expect(has_perform);
    try std.testing.expect(has_handle);
}
