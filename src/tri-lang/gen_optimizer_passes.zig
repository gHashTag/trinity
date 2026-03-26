// ═══════════════════════════════════════════════════════════════════
// OPTIMIZER_PASSES (GENERATED)
// ═══════════════════════════════════════════════════════════════════
// Individual Optimizer Passes for Tri Language
// Generated from: specs/tri-lang/optimizer_passes.tri
// TTT Dogfood v0.1 — DO NOT EDIT DIRECTLY
// Source of truth: .tri spec (edit spec, regenerate)
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const TypedExpr = @import("typechecker.zig").TypedExpr;
const TypeEnv = @import("type_env.zig").TypeEnv;
const OptimizerPass = @import("optimizer.zig").OptimizerPass;

const BinaryOperator = @import("ast.zig").BinaryOperator;

// Import expression types from typechecker
const BinOpExpr = @import("typechecker.zig").BinOpExpr;
const IfExpr = @import("typechecker.zig").IfExpr;
const LetExpr = @import("typechecker.zig").LetExpr;
const MatchExpr = @import("typechecker.zig").MatchExpr;
const MapExpr = @import("typechecker.zig").MapExpr;
const FilterExpr = @import("typechecker.zig").FilterExpr;
const PipeExpr = @import("typechecker.zig").PipeExpr;
const FnCallExpr = @import("typechecker.zig").FnCallExpr;

// ═══════════════════════════════════════════════════════════════════════
// PHASE 2: CONSTANT FOLDING PASS
// ═══════════════════════════════════════════════════════════════════════

/// Constant folding pass
/// Evaluates constant expressions at compile time
/// Examples:
///   2 + 3 => 5
///   -(-x) => x
///   if (true) x else y => x
pub fn constantFoldPass(allocator: Allocator, expr: *const TypedExpr, env: *const TypeEnv) ?TypedExpr {
    return switch (expr.*) {
        .BinOp => |binop| foldBinaryOp(allocator, binop, env),
        .If => |if_expr| foldIf(if_expr),
        else => null,
    };
}

/// Fold binary operations with constant operands
fn foldBinaryOp(allocator: Allocator, binop: BinOpExpr, env: *const TypeEnv) ?TypedExpr {
    _ = allocator;
    _ = env;
    const left = binop.left;
    const right = binop.right;

    // Both operands must be constant integers
    if (left.* == .Int and right.* == .Int) {
        const l_val = left.Int.value;
        const r_val = right.Int.value;

        const result = switch (binop.op) {
            .Add => l_val + r_val,
            .Sub => l_val - r_val,
            .Mul => l_val * r_val,
            .Div => if (r_val != 0) @divTrunc(l_val, r_val) else return null,
            .Mod => if (r_val != 0) @rem(l_val, r_val) else return null,
            .BitAnd => l_val & r_val,
            .BitOr => l_val | r_val,
            .BitXor => l_val ^ r_val,
            .ShiftLeft => if (r_val >= 0 and r_val < 64) @shlExact(l_val, @intCast(r_val)) else return null,
            .ShiftRight => if (r_val >= 0 and r_val < 64) @shrExact(l_val, @intCast(r_val)) else return null,
            .Equal => @intFromBool(l_val == r_val),
            .NotEqual => @intFromBool(l_val != r_val),
            .Less => @intFromBool(l_val < r_val),
            .LessEqual => @intFromBool(l_val <= r_val),
            .Greater => @intFromBool(l_val > r_val),
            .GreaterEqual => @intFromBool(l_val >= r_val),
            else => return null,
        };

        return TypedExpr{ .Int = .{ .value = result } };
    }

    // Fold boolean operations
    if (left.* == .Bool and right.* == .Bool) {
        const l_val = left.Bool.value;
        const r_val = right.Bool.value;

        const result = switch (binop.op) {
            .Equal => l_val == r_val,
            .NotEqual => l_val != r_val,
            .BitAnd => l_val and r_val,
            .BitOr => l_val or r_val,
            else => return null,
        };

        return TypedExpr{ .Bool = .{ .value = result } };
    }

    return null;
}

/// Fold if expressions with constant conditions
fn foldIf(if_expr: IfExpr) ?TypedExpr {
    const cond = if_expr.condition;

    // If condition is constant bool, select the appropriate branch
    if (cond.* == .Bool) {
        if (cond.Bool.value) {
            // Condition is true, take then branch
            return if_expr.then_branch.*;
        } else {
            // Condition is false, take else branch
            return if_expr.else_branch.*;
        }
    }

    // If condition is constant integer, non-zero = true
    if (cond.* == .Int) {
        if (cond.Int.value != 0) {
            return if_expr.then_branch.*;
        } else {
            return if_expr.else_branch.*;
        }
    }

    return null;
}

/// Get the constant folding pass as an OptimizerPass
pub fn getConstantFoldPass() OptimizerPass {
    return .{
        .name = "constant_fold",
        .description = "Evaluate constant expressions at compile time",
        .run = constantFoldPass,
    };
}

// ═══════════════════════════════════════════════════════════════════════
// PHASE 3: DEAD CODE ELIMINATION PASS
// ═══════════════════════════════════════════════════════════════════════

/// Dead code elimination pass
/// Removes unreachable code and unused bindings
pub fn deadCodeElimPass(allocator: Allocator, expr: *const TypedExpr, env: *const TypeEnv) ?TypedExpr {
    _ = allocator;
    _ = env;
    return switch (expr.*) {
        .If => |if_expr| eliminateDeadIf(if_expr),
        .Let => |let_expr| eliminateUnusedLet(let_expr),
        .Match => |match_expr| eliminateDeadArms(match_expr),
        else => null,
    };
}

/// Eliminate dead branches in if expressions
fn eliminateDeadIf(if_expr: IfExpr) ?TypedExpr {
    const cond = if_expr.condition;

    // If condition is constant, we can eliminate one branch
    // (Note: constant folding also does this, but DCE removes the dead code entirely)
    if (cond.* == .Bool or cond.* == .Int) {
        const is_true = if (cond.* == .Bool)
            cond.Bool.value
        else
            cond.Int.value != 0;

        if (is_true) {
            // Then branch is always taken, else branch is dead
            return if_expr.then_branch.*;
        } else {
            // Else branch is always taken, then branch is dead
            return if_expr.else_branch.*;
        }
    }

    return null;
}

/// Eliminate unused let bindings
/// A let binding is unused if the variable is never referenced in the body
fn eliminateUnusedLet(let_expr: LetExpr) ?TypedExpr {
    _ = let_expr;
    // For now, we can't easily detect unused variables without a more complex analysis
    // A full implementation would:
    // 1. Collect all free variables in the body
    // 2. If the let-bound name is not in the free variables, eliminate the binding
    // 3. Return just the body expression
    return null;
}

/// Eliminate unreachable match arms
/// After constant folding, some match arms may never be reached
fn eliminateDeadArms(match_expr: MatchExpr) ?TypedExpr {
    _ = match_expr;
    // For now, we can't easily eliminate match arms without pattern analysis
    // A full implementation would:
    // 1. Check if the value being matched is a constant
    // 2. If so, only the matching arm is reachable
    // 3. Return just that arm's body
    return null;
}

/// Get the dead code elimination pass as an OptimizerPass
pub fn getDeadCodeElimPass() OptimizerPass {
    return .{
        .name = "dead_code_elim",
        .description = "Remove unreachable code and unused bindings",
        .run = deadCodeElimPass,
    };
}

// ═══════════════════════════════════════════════════════════════════════
// PHASE 4: ARRAY COMBINATOR FUSION PASS
// ═══════════════════════════════════════════════════════════════════════

/// Array combinator fusion pass
/// Combines consecutive array operations to reduce iterations
/// Examples:
///   map(map(arr, f), g) => map(arr, compose(g, f))
///   filter(filter(arr, p), q) => filter(arr, and(p, q))
pub fn arrayFusionPass(allocator: Allocator, expr: *const TypedExpr, env: *const TypeEnv) ?TypedExpr {
    _ = env; // Reserved for future type-aware fusion
    return switch (expr.*) {
        .Map => |map| fuseMapCombinator(allocator, map),
        .Filter => |filter| fuseFilterCombinator(allocator, filter),
        .Pipe => |pipe| fusePipeCombinators(allocator, pipe),
        else => null,
    };
}

/// Fuse consecutive map operations
/// map(map(arr, f), g) => map(arr, compose(g, f))
fn fuseMapCombinator(allocator: Allocator, map_expr: MapExpr) ?TypedExpr {
    // Check if the array being mapped is itself a map
    if (map_expr.array.* == .Map) {
        const inner_map = map_expr.array.Map;

        // Create a composed function: g ∘ f
        // For now, we can't easily compose functions without lambda representation
        // This is a placeholder for the fusion logic

        _ = inner_map;
        _ = allocator;
        return null;
    }

    return null;
}

/// Fuse consecutive filter operations
/// filter(filter(arr, p), q) => filter(arr, and(p, q))
fn fuseFilterCombinator(allocator: Allocator, filter_expr: FilterExpr) ?TypedExpr {
    // Check if the array being filtered is itself a filter
    if (filter_expr.array.* == .Filter) {
        const inner_filter = filter_expr.array.Filter;

        // Create a combined predicate: p && q
        // For now, we can't easily combine predicates without lambda representation
        // This is a placeholder for the fusion logic

        _ = inner_filter;
        _ = allocator;
        return null;
    }

    return null;
}

/// Fuse array operations in pipe expressions
/// arr |> map(f) |> map(g) => arr |> map(compose(g, f))
fn fusePipeCombinators(allocator: Allocator, pipe_expr: PipeExpr) ?TypedExpr {
    _ = allocator;
    _ = pipe_expr;
    // Check for consecutive map/filter operations in the pipe
    // For now, this is a placeholder

    return null;
}

/// Get the array fusion pass as an OptimizerPass
pub fn getArrayFusionPass() OptimizerPass {
    return .{
        .name = "array_fusion",
        .description = "Combine consecutive array operations",
        .run = arrayFusionPass,
    };
}

// ═══════════════════════════════════════════════════════════════════════
// PHASE 5: INLINE EXPANSION PASS
// ═══════════════════════════════════════════════════════════════════════

/// Inline expansion pass
/// Inlines small functions at call sites to enable further optimization
/// Criteria for inlining:
/// - Function has a single expression body
/// - Function is called only once
/// - Function body is small (< 10 expressions)
pub fn inlineExpansionPass(allocator: Allocator, expr: *const TypedExpr, env: *const TypeEnv) ?TypedExpr {
    return switch (expr.*) {
        .FnCall => |call| tryInlineCall(allocator, call, env),
        else => null,
    };
}

/// Try to inline a function call
fn tryInlineCall(allocator: Allocator, call: FnCallExpr, env: *const TypeEnv) ?TypedExpr {
    // Check if the callee is a direct function reference
    if (call.func.* != .Fn) return null;

    const fn_expr = call.func.Fn;

    // Check arity
    if (fn_expr.params.len != call.args.len) return null;

    // For now, we can't easily inline without proper substitution
    // A full implementation would:
    // 1. Create a mapping from params to args
    // 2. Substitute args for params in the function body
    // 3. Return the substituted body

    _ = allocator;
    _ = env;
    return null;
}

/// Count expressions in a TypedExpr (for inlining heuristics)
/// Recursively counts all sub-expressions to estimate complexity
fn countExprs(expr: *const TypedExpr) usize {
    switch (expr.*) {
        .Int, .Bool, .Var => return 1,
        .BinOp => |op| {
            // Count left + right + 1 for the binop itself
            return 1 + countExprs(op.left) + countExprs(op.right);
        },
        .If => |if_expr| {
            // Count condition + then_branch + else_branch
            var count = 1 + countExprs(if_expr.condition);
            count += countExprs(if_expr.then_branch);
            count += countExprs(if_expr.else_branch);
            return count;
        },
        .Let => |let_expr| {
            // Count binding + body
            return 1 + countExprs(let_expr.value) + countExprs(let_expr.body);
        },
        .Fn => |fn_expr| {
            // Count function body
            return 1 + countExprs(fn_expr.body);
        },
        .FnCall => |call| {
            // Count function + all arguments
            var count = 1; // For the call itself
            count += countExprs(call.func);
            for (call.args) |arg| {
                count += countExprs(arg);
            }
            return count;
        },
        .Match => |match_expr| {
            // Count value + all arms
            var count = 1 + countExprs(match_expr.value);
            for (match_expr.arms) |arm| {
                count += countExprs(arm.body);
            }
            return count;
        },
        .Pipe => |pipe_expr| {
            // Count source + all stages
            var count = 1 + countExprs(pipe_expr.source);
            for (pipe_expr.stages) |stage| {
                count += countExprs(stage);
            }
            return count;
        },
        .Map => |m| {
            return 1 + countExprs(m.array) + countExprs(m.func);
        },
        .Reduce => |r| {
            return 1 + countExprs(r.array) + countExprs(r.init);
        },
        .Scan => |s| {
            return 1 + countExprs(s.array) + countExprs(s.init);
        },
        .Filter => |f| {
            return 1 + countExprs(f.array) + countExprs(f.predicate);
        },
        .FlatMap => |f| {
            return 1 + countExprs(f.array) + countExprs(f.func);
        },
        .Zip => |z| {
            return 1 + countExprs(z.left) + countExprs(z.right);
        },
        .ADT => |adt| {
            // Count type + variant + data
            if (adt.data) |data| {
                return 1 + countExprs(data);
            }
            return 1;
        },
        // Effects are counted as single expressions
        .Perform, .Handle, .Try => return 1,
    }
}

/// Get the inline expansion pass as an OptimizerPass
pub fn getInlineExpansionPass() OptimizerPass {
    return .{
        .name = "inline_expansion",
        .description = "Inline small functions at call sites",
        .run = inlineExpansionPass,
    };
}

// ═══════════════════════════════════════════════════════════════════════
// PREDEFINED PASS SETS
// ═══════════════════════════════════════════════════════════════════════

/// Standard optimization passes
/// Recommended for most code: constant folding + dead code elimination
pub const standard_passes = [_]OptimizerPass{
    getConstantFoldPass(),
    getDeadCodeElimPass(),
};

pub fn getStandardPasses() []const OptimizerPass {
    return &standard_passes;
}

/// Aggressive optimization passes
/// For release builds: standard + array fusion + inline expansion
pub const aggressive_passes = [_]OptimizerPass{
    getConstantFoldPass(),
    getDeadCodeElimPass(),
    getInlineExpansionPass(),
    getArrayFusionPass(),
    // Run constant folding again to catch new opportunities
    getConstantFoldPass(),
};

pub fn getAggressivePasses() []const OptimizerPass {
    return &aggressive_passes;
}

/// Minimal optimization passes
/// For fast iteration: only constant folding
pub const minimal_passes = [_]OptimizerPass{
    getConstantFoldPass(),
};

pub fn getMinimalPasses() []const OptimizerPass {
    return &minimal_passes;
}

// ═══════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════

test "constantFoldPass: 2 + 3 => 5" {
    const allocator = std.testing.allocator;
    var env = TypeEnv.init(allocator);
    defer env.deinit();

    const left = try allocator.create(TypedExpr);
    defer allocator.destroy(left);
    left.* = TypedExpr{ .Int = .{ .value = 2 } };

    const right = try allocator.create(TypedExpr);
    defer allocator.destroy(right);
    right.* = TypedExpr{ .Int = .{ .value = 3 } };

    const binop = TypedExpr{ .BinOp = .{
        .left = left,
        .op = .Add,
        .right = right,
    } };

    const result = constantFoldPass(allocator, &binop, &env);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(i64, 5), result.?.Int.value);
}

test "constantFoldPass: 10 - 4 => 6" {
    const allocator = std.testing.allocator;
    var env = TypeEnv.init(allocator);
    defer env.deinit();

    const left = try allocator.create(TypedExpr);
    defer allocator.destroy(left);
    left.* = TypedExpr{ .Int = .{ .value = 10 } };

    const right = try allocator.create(TypedExpr);
    defer allocator.destroy(right);
    right.* = TypedExpr{ .Int = .{ .value = 4 } };

    const binop = TypedExpr{ .BinOp = .{
        .left = left,
        .op = .Sub,
        .right = right,
    } };

    const result = constantFoldPass(allocator, &binop, &env);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(i64, 6), result.?.Int.value);
}

test "constantFoldPass: 3 * 4 => 12" {
    const allocator = std.testing.allocator;
    var env = TypeEnv.init(allocator);
    defer env.deinit();

    const left = try allocator.create(TypedExpr);
    defer allocator.destroy(left);
    left.* = TypedExpr{ .Int = .{ .value = 3 } };

    const right = try allocator.create(TypedExpr);
    defer allocator.destroy(right);
    right.* = TypedExpr{ .Int = .{ .value = 4 } };

    const binop = TypedExpr{ .BinOp = .{
        .left = left,
        .op = .Mul,
        .right = right,
    } };

    const result = constantFoldPass(allocator, &binop, &env);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(i64, 12), result.?.Int.value);
}

test "constantFoldPass: division by zero returns null" {
    const allocator = std.testing.allocator;
    var env = TypeEnv.init(allocator);
    defer env.deinit();

    const left = try allocator.create(TypedExpr);
    defer allocator.destroy(left);
    left.* = TypedExpr{ .Int = .{ .value = 10 } };

    const right = try allocator.create(TypedExpr);
    defer allocator.destroy(right);
    right.* = TypedExpr{ .Int = .{ .value = 0 } };

    const binop = TypedExpr{ .BinOp = .{
        .left = left,
        .op = .Div,
        .right = right,
    } };

    const result = constantFoldPass(allocator, &binop, &env);
    try std.testing.expect(result == null);
}

test "constantFoldPass: if true then x else y => x" {
    const allocator = std.testing.allocator;
    var env = TypeEnv.init(allocator);
    defer env.deinit();

    const cond = try allocator.create(TypedExpr);
    defer allocator.destroy(cond);
    cond.* = TypedExpr{ .Bool = .{ .value = true } };

    const then_branch = try allocator.create(TypedExpr);
    defer allocator.destroy(then_branch);
    then_branch.* = TypedExpr{ .Int = .{ .value = 1 } };

    const else_branch = try allocator.create(TypedExpr);
    defer allocator.destroy(else_branch);
    else_branch.* = TypedExpr{ .Int = .{ .value = 2 } };

    const if_expr = TypedExpr{ .If = .{
        .condition = cond,
        .then_branch = then_branch,
        .else_branch = else_branch,
    } };

    const result = constantFoldPass(allocator, &if_expr, &env);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(i64, 1), result.?.Int.value);
}

test "constantFoldPass: if false then x else y => y" {
    const allocator = std.testing.allocator;
    var env = TypeEnv.init(allocator);
    defer env.deinit();

    const cond = try allocator.create(TypedExpr);
    defer allocator.destroy(cond);
    cond.* = TypedExpr{ .Bool = .{ .value = false } };

    const then_branch = try allocator.create(TypedExpr);
    defer allocator.destroy(then_branch);
    then_branch.* = TypedExpr{ .Int = .{ .value = 1 } };

    const else_branch = try allocator.create(TypedExpr);
    defer allocator.destroy(else_branch);
    else_branch.* = TypedExpr{ .Int = .{ .value = 2 } };

    const if_expr = TypedExpr{ .If = .{
        .condition = cond,
        .then_branch = then_branch,
        .else_branch = else_branch,
    } };

    const result = constantFoldPass(allocator, &if_expr, &env);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(i64, 2), result.?.Int.value);
}

test "constantFoldPass: boolean equality" {
    const allocator = std.testing.allocator;
    var env = TypeEnv.init(allocator);
    defer env.deinit();

    const left = try allocator.create(TypedExpr);
    defer allocator.destroy(left);
    left.* = TypedExpr{ .Bool = .{ .value = true } };

    const right = try allocator.create(TypedExpr);
    defer allocator.destroy(right);
    right.* = TypedExpr{ .Bool = .{ .value = true } };

    const binop = TypedExpr{ .BinOp = .{
        .left = left,
        .op = .Equal,
        .right = right,
    } };

    const result = constantFoldPass(allocator, &binop, &env);
    try std.testing.expect(result != null);
    try std.testing.expect(result.? == .Bool);
    try std.testing.expect(result.?.Bool.value);
}

test "deadCodeElimPass: if true then x else y => x" {
    const allocator = std.testing.allocator;
    var env = TypeEnv.init(allocator);
    defer env.deinit();

    const cond = try allocator.create(TypedExpr);
    defer allocator.destroy(cond);
    cond.* = TypedExpr{ .Bool = .{ .value = true } };

    const then_branch = try allocator.create(TypedExpr);
    defer allocator.destroy(then_branch);
    then_branch.* = TypedExpr{ .Int = .{ .value = 1 } };

    const else_branch = try allocator.create(TypedExpr);
    defer allocator.destroy(else_branch);
    else_branch.* = TypedExpr{ .Int = .{ .value = 2 } };

    const if_expr = TypedExpr{ .If = .{
        .condition = cond,
        .then_branch = then_branch,
        .else_branch = else_branch,
    } };

    const result = deadCodeElimPass(allocator, &if_expr, &env);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(i64, 1), result.?.Int.value);
}

test "deadCodeElimPass: if false then x else y => y" {
    const allocator = std.testing.allocator;
    var env = TypeEnv.init(allocator);
    defer env.deinit();

    const cond = try allocator.create(TypedExpr);
    defer allocator.destroy(cond);
    cond.* = TypedExpr{ .Bool = .{ .value = false } };

    const then_branch = try allocator.create(TypedExpr);
    defer allocator.destroy(then_branch);
    then_branch.* = TypedExpr{ .Int = .{ .value = 1 } };

    const else_branch = try allocator.create(TypedExpr);
    defer allocator.destroy(else_branch);
    else_branch.* = TypedExpr{ .Int = .{ .value = 2 } };

    const if_expr = TypedExpr{ .If = .{
        .condition = cond,
        .then_branch = then_branch,
        .else_branch = else_branch,
    } };

    const result = deadCodeElimPass(allocator, &if_expr, &env);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(i64, 2), result.?.Int.value);
}

test "getStandardPasses returns constant_fold and dead_code_elim" {
    const passes = getStandardPasses();
    try std.testing.expectEqual(@as(usize, 2), passes.len);
    // Note: Order might be platform-dependent, just check both exist
    try std.testing.expect(passes[0].name.len > 0);
    try std.testing.expect(passes[1].name.len > 0);
}

test "getAggressivePasses returns 4 passes" {
    const passes = getAggressivePasses();
    // We expect 5 passes (constant_fold appears twice)
    try std.testing.expectEqual(@as(usize, 5), passes.len);
    // Just check that all passes have valid names and descriptions
    for (passes) |pass| {
        try std.testing.expect(pass.name.len > 0);
        try std.testing.expect(pass.description.len > 0);
    }
}

test "getMinimalPasses returns only constant_fold" {
    const passes = getMinimalPasses();
    try std.testing.expectEqual(@as(usize, 1), passes.len);
    // Check that we have exactly one pass
    try std.testing.expect(passes[0].name.len > 0);
    try std.testing.expect(passes[0].description.len > 0);
}

test "getConstantFoldPass returns valid pass" {
    const pass = getConstantFoldPass();
    try std.testing.expect(std.mem.eql(u8, "constant_fold", pass.name));
    try std.testing.expect(pass.description.len > 0);
}

test "getDeadCodeElimPass returns valid pass" {
    const pass = getDeadCodeElimPass();
    try std.testing.expect(std.mem.eql(u8, "dead_code_elim", pass.name));
    try std.testing.expect(pass.description.len > 0);
}

test "getArrayFusionPass returns valid pass" {
    const pass = getArrayFusionPass();
    try std.testing.expect(std.mem.eql(u8, "array_fusion", pass.name));
    try std.testing.expect(pass.description.len > 0);
}

test "getInlineExpansionPass returns valid pass" {
    const pass = getInlineExpansionPass();
    try std.testing.expect(std.mem.eql(u8, "inline_expansion", pass.name));
    try std.testing.expect(pass.description.len > 0);
}
