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
