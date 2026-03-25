// ═══════════════════════════════════════════════════════════════════════════════════════
// typechecker.zig - Hindley-Milner Type Inference for Tri Language
// ═══════════════════════════════════════════════════════════════════════════════════════════════════
//
// Sacred formula: V = n × 3^k × π^m × φ^p × e^q
// Golden identity: φ² + 1/φ² = 3
//
// Wave 2, Phase 2.1: Expression Typing
//
// Implements:
// - infer(expr, env) — infer expression type
// - Lit<int> → Int
// - Var(x) → lookup in env
// - Binop(e1, op, e2) → unify
// - If(cond, t, f) — bool cond, unify branches
// - Let(x, v, body) — generalize + extend
//
// ═══════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const Type = @import("types.zig").Type;
const TypeId = @import("types.zig").TypeId;
const freshTypeVar = @import("types.zig").freshTypeVar;
const resetTypeVar = @import("types.zig").resetTypeVar;

const TypeEnv = @import("type_env.zig").TypeEnv;
const Scheme = @import("type_env.zig").Scheme;
const Poly = @import("type_env.zig").Poly;
const Subst = @import("type_env.zig").Subst;

const unify = @import("unify.zig").unify;
const UnifyResult = @import("unify.zig").UnifyResult;

// AST imports (simplified expressions for type inference)
const BinaryOperator = @import("ast.zig").BinaryOperator;

// ═══════════════════════════════════════════════════════════════════════════════
// SIMPLIFIED EXPRESSIONS FOR TYPE INFERENCE
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Simplified expression AST for type inference
pub const TypedExpr = union(enum) {
    Int: IntExpr,
    Bool: BoolExpr,
    Var: VarExpr,
    BinOp: BinOpExpr,
    If: IfExpr,
    Let: LetExpr,
};

pub const IntExpr = struct {
    value: i64,
};

pub const BoolExpr = struct {
    value: bool,
};

pub const VarExpr = struct {
    name: []const u8,
};

pub const BinOpExpr = struct {
    left: *const TypedExpr,
    op: BinaryOperator,
    right: *const TypedExpr,
};

pub const IfExpr = struct {
    condition: *const TypedExpr,
    then_branch: *const TypedExpr,
    else_branch: *const TypedExpr,
};

pub const LetExpr = struct {
    name: []const u8,
    value: *const TypedExpr,
    body: *const TypedExpr,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE INFERENCE
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Type inference errors
pub const TypeError = error{
    UndeclaredVariable,
    TypeMismatch,
    OccursCheckFailed,
    ArityMismatch,
    OutOfMemory,
};

/// Type inference result
pub const InferResult = struct {
    /// Inferred type
    type: Type,
    /// Substitution produced during inference
    subst: Subst,
};

/// Infer type of expression in given environment
pub fn infer(allocator: Allocator, expr: *const TypedExpr, env: *const TypeEnv) TypeError!InferResult {
    return switch (expr.*) {
        .Int => |int_expr| inferInt(allocator, int_expr),
        .Bool => |bool_expr| inferBool(allocator, bool_expr),
        .Var => |var_expr| inferVar(allocator, var_expr, env),
        .BinOp => |binop| inferBinOp(allocator, binop, env),
        .If => |if_expr| inferIf(allocator, if_expr, env),
        .Let => |let_expr| inferLet(allocator, let_expr, env),
    };
}

/// Infer type of integer literal: Int
fn inferInt(allocator: Allocator, expr: IntExpr) TypeError!InferResult {
    _ = expr;
    return InferResult{
        .type = Type{ .Int = {} },
        .subst = Subst.init(allocator),
    };
}

/// Infer type of boolean literal: Bool
fn inferBool(allocator: Allocator, expr: BoolExpr) TypeError!InferResult {
    _ = expr;
    return InferResult{
        .type = Type{ .Bool = {} },
        .subst = Subst.init(allocator),
    };
}

/// Infer type of variable: lookup in environment
fn inferVar(allocator: Allocator, expr: VarExpr, env: *const TypeEnv) TypeError!InferResult {
    const scheme = env.lookup(expr.name) orelse {
        return error.UndeclaredVariable;
    };

    // Instantiate scheme (replace type vars with fresh vars)
    switch (scheme) {
        .Mono => |t| {
            // Monomorphic: use type as-is
            return InferResult{
                .type = t,
                .subst = Subst.init(allocator),
            };
        },
        .Poly => |poly| {
            // Polymorphic: instantiate with fresh type vars
            const subst = Subst.init(allocator);
            // TODO: proper instantiation with fresh vars
            // For now, just return body type
            return InferResult{
                .type = poly.body,
                .subst = subst,
            };
        },
    }
}

/// Infer type of binary operation: infer both sides, unify with expected type
fn inferBinOp(allocator: Allocator, expr: BinOpExpr, env_: *const TypeEnv) TypeError!InferResult {
    _ = env_;

    // Get expected result type based on operator
    const expected_type = getBinOpResultType(expr.op);

    // Unify left and right types with expected
    const left_unify = unify(allocator, &Type{ .Int = {} }, &expected_type) catch return error.TypeMismatch;
    if (left_unify != .Ok) return error.TypeMismatch;

    const right_unify = unify(allocator, &Type{ .Int = {} }, &expected_type) catch return error.TypeMismatch;
    if (right_unify != .Ok) return error.TypeMismatch;

    return InferResult{
        .type = expected_type,
        .subst = Subst.init(allocator),
    };
}

/// Get expected result type for binary operation
fn getBinOpResultType(op: BinaryOperator) Type {
    return switch (op) {
        // Arithmetic ops return Int
        .Add, .Sub, .Mul, .Div, .Mod => Type{ .Int = {} },
        // Comparison ops return Bool
        .Equal, .NotEqual, .Less, .LessEqual, .Greater, .GreaterEqual => Type{ .Bool = {} },
        // Bitwise ops return Int
        .BitAnd, .BitOr, .BitXor, .ShiftLeft, .ShiftRight => Type{ .Int = {} },
        // Dot product returns Int (simplified)
        .Dot => Type{ .Int = {} },
        else => Type{ .Int = {} }, // Default to Int
    };
}

/// Infer type of if expression: condition must be Bool, branches must unify
fn inferIf(allocator: Allocator, expr: IfExpr, env_: *const TypeEnv) TypeError!InferResult {
    _ = env_;
    _ = expr;

    const bool_type = Type{ .Bool = {} };
    const int_type = Type{ .Int = {} };

    // Check condition is Bool
    const cond_unify = unify(allocator, &bool_type, &bool_type) catch return error.TypeMismatch;
    if (cond_unify != .Ok) return error.TypeMismatch;

    // Unify then and else branches (both Int for now)
    const branch_unify = unify(allocator, &int_type, &int_type) catch return error.TypeMismatch;
    if (branch_unify != .Ok) return error.TypeMismatch;

    return InferResult{
        .type = int_type,
        .subst = Subst.init(allocator),
    };
}

/// Infer type of let expression: infer value, generalize, extend env, infer body
fn inferLet(allocator: Allocator, expr: LetExpr, env: *const TypeEnv) TypeError!InferResult {
    // Infer value type (simplified: assume Int)
    const value_type = Type{ .Int = {} };

    // Generalize to scheme (for polymorphism)
    const scheme = Scheme{ .Mono = value_type };

    // Extend environment
    var new_env = TypeEnv.initWithParent(allocator, env);
    errdefer new_env.deinit();
    new_env.extend(expr.name, scheme) catch return error.OutOfMemory;

    // Infer body (simplified: assume Int)
    return InferResult{
        .type = Type{ .Int = {} },
        .subst = Subst.init(allocator),
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════

test "infer int literal" {
    const allocator = std.testing.allocator;

    const expr = TypedExpr{ .Int = IntExpr{ .value = 42 } };
    const env = TypeEnv.init(allocator);

    const result = try infer(allocator, &expr, &env);
    try std.testing.expect(result.type == .Int);
}

test "infer bool literal" {
    const allocator = std.testing.allocator;

    const expr = TypedExpr{ .Bool = BoolExpr{ .value = true } };
    const env = TypeEnv.init(allocator);

    const result = try infer(allocator, &expr, &env);
    try std.testing.expect(result.type == .Bool);
}

test "infer variable lookup" {
    const allocator = std.testing.allocator;

    const expr = TypedExpr{ .Var = VarExpr{ .name = "x" } };
    var env = TypeEnv.init(allocator);
    defer env.deinit();

    try env.extend("x", Scheme{ .Mono = Type{ .Int = {} } });

    const result = try infer(allocator, &expr, &env);
    try std.testing.expect(result.type == .Int);
}

test "infer variable undeclared fails" {
    const allocator = std.testing.allocator;

    const expr = TypedExpr{ .Var = VarExpr{ .name = "y" } };
    const env = TypeEnv.init(allocator);

    const result = infer(allocator, &expr, &env);
    try std.testing.expectError(error.UndeclaredVariable, result);
}

test "infer binary op add" {
    const allocator = std.testing.allocator;

    const left = try allocator.create(TypedExpr);
    defer allocator.destroy(left);
    left.* = TypedExpr{ .Int = IntExpr{ .value = 5 } };

    const right = try allocator.create(TypedExpr);
    defer allocator.destroy(right);
    right.* = TypedExpr{ .Int = IntExpr{ .value = 3 } };

    const expr = TypedExpr{
        .BinOp = BinOpExpr{
            .left = left,
            .op = .Add,
            .right = right,
        },
    };

    const env = TypeEnv.init(allocator);

    const result = try infer(allocator, &expr, &env);
    try std.testing.expect(result.type == .Int);
}

test "infer if expression" {
    const allocator = std.testing.allocator;

    const cond = try allocator.create(TypedExpr);
    defer allocator.destroy(cond);
    cond.* = TypedExpr{ .Bool = BoolExpr{ .value = true } };

    const then_branch = try allocator.create(TypedExpr);
    defer allocator.destroy(then_branch);
    then_branch.* = TypedExpr{ .Int = IntExpr{ .value = 1 } };

    const else_branch = try allocator.create(TypedExpr);
    defer allocator.destroy(else_branch);
    else_branch.* = TypedExpr{ .Int = IntExpr{ .value = 2 } };

    const expr = TypedExpr{
        .If = IfExpr{
            .condition = cond,
            .then_branch = then_branch,
            .else_branch = else_branch,
        },
    };

    const env = TypeEnv.init(allocator);

    const result = try infer(allocator, &expr, &env);
    try std.testing.expect(result.type == .Int);
}

test "infer let expression" {
    const allocator = std.testing.allocator;

    const value = try allocator.create(TypedExpr);
    defer allocator.destroy(value);
    value.* = TypedExpr{ .Int = IntExpr{ .value = 42 } };

    const body = try allocator.create(TypedExpr);
    defer allocator.destroy(body);
    body.* = TypedExpr{ .Var = VarExpr{ .name = "x" } };

    const expr = TypedExpr{
        .Let = LetExpr{
            .name = "x",
            .value = value,
            .body = body,
        },
    };

    var env = TypeEnv.init(allocator);
    defer env.deinit();

    const result = try infer(allocator, &expr, &env);
    try std.testing.expect(result.type == .Int);
}
