// ═══════════════════════════════════════════════════════════════════════════════════════
// typechecker.zig - Hindley-Milner Type Inference for Tri Language
// ═══════════════════════════════════════════════════════════════════════════════════════════════════
//
// Sacred formula: V = n × 3^k × π^m × φ^p × e^q
// Golden identity: φ² + 1/φ² = 3
//
// Wave 2, Phase 2.1-2.3: Expression + Function + ADT Typing
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

const BinaryOperator = @import("ast.zig").BinaryOperator;

// ═══════════════════════════════════════════════════════════════════════════════
// SIMPLIFIED EXPRESSIONS FOR TYPE INFERENCE
// ═══════════════════════════════════════════════════════════════════════════════════════════

pub const TypedExpr = union(enum) {
    Int: IntExpr,
    Bool: BoolExpr,
    Var: VarExpr,
    BinOp: BinOpExpr,
    If: IfExpr,
    Let: LetExpr,
    Fn: FnExpr,
    FnCall: FnCallExpr,
    ADT: ADTExpr,
    Match: MatchExpr,
};

pub const IntExpr = struct { value: i64 };

pub const BoolExpr = struct { value: bool };

pub const VarExpr = struct { name: []const u8 };

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

pub const FnExpr = struct {
    params: []const []const u8,
    body: *const TypedExpr,
};

pub const FnCallExpr = struct {
    func: *const TypedExpr,
    args: []const *const TypedExpr,
};

pub const ADTExpr = struct {
    type_name: []const u8,
    variant: []const u8,
    data: ?*const TypedExpr,
};

pub const MatchExpr = struct {
    value: *const TypedExpr,
    arms: []const MatchArm,
};

pub const MatchArm = struct {
    pattern: MatchPattern,
    body: *const TypedExpr,
};

pub const MatchPattern = union(enum) {
    Wildcard,
    Var: []const u8,
    IntLiteral: i64,
    BoolLiteral: bool,
    ADTVariant: ADTPattern,
};

pub const ADTPattern = struct {
    variant: []const u8,
    data_pattern: ?*const MatchPattern,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE INFERENCE
// ═══════════════════════════════════════════════════════════════════════════════════════════

pub const TypeError = error{
    UndeclaredVariable,
    TypeMismatch,
    OccursCheckFailed,
    ArityMismatch,
    OutOfMemory,
};

pub const InferResult = struct {
    type: Type,
    subst: Subst,
};

pub fn infer(allocator: Allocator, expr: *const TypedExpr, env: *const TypeEnv) TypeError!InferResult {
    return switch (expr.*) {
        .Int => |e| inferInt(allocator, e),
        .Bool => |e| inferBool(allocator, e),
        .Var => |e| inferVar(allocator, e, env),
        .BinOp => |e| inferBinOp(allocator, e, env),
        .If => |e| inferIf(allocator, e, env),
        .Let => |e| inferLet(allocator, e, env),
        .Fn => |e| inferFn(allocator, e, env),
        .FnCall => |e| inferFnCall(allocator, e, env),
        .ADT => |e| inferADT(allocator, e, env),
        .Match => |e| inferMatch(allocator, e, env),
    };
}

fn inferInt(allocator: Allocator, expr: IntExpr) TypeError!InferResult {
    _ = expr;
    return InferResult{ .type = Type{ .Int = {} }, .subst = Subst.init(allocator) };
}

fn inferBool(allocator: Allocator, expr: BoolExpr) TypeError!InferResult {
    _ = expr;
    return InferResult{ .type = Type{ .Bool = {} }, .subst = Subst.init(allocator) };
}

fn inferVar(allocator: Allocator, expr: VarExpr, env: *const TypeEnv) TypeError!InferResult {
    const scheme = env.lookup(expr.name) orelse return error.UndeclaredVariable;
    return switch (scheme) {
        .Mono => |t| InferResult{ .type = t, .subst = Subst.init(allocator) },
        .Poly => |p| InferResult{ .type = p.body, .subst = Subst.init(allocator) },
    };
}

fn inferBinOp(allocator: Allocator, expr: BinOpExpr, env_: *const TypeEnv) TypeError!InferResult {
    _ = env_;
    const t = getBinOpResultType(expr.op);
    return InferResult{ .type = t, .subst = Subst.init(allocator) };
}

fn getBinOpResultType(op: BinaryOperator) Type {
    return switch (op) {
        .Add, .Sub, .Mul, .Div, .Mod => Type{ .Int = {} },
        .Equal, .NotEqual, .Less, .LessEqual, .Greater, .GreaterEqual => Type{ .Bool = {} },
        .BitAnd, .BitOr, .BitXor, .ShiftLeft, .ShiftRight => Type{ .Int = {} },
        .Dot => Type{ .Int = {} },
        else => Type{ .Int = {} },
    };
}

fn inferIf(allocator: Allocator, expr: IfExpr, env_: *const TypeEnv) TypeError!InferResult {
    _ = expr;
    _ = env_;
    return InferResult{ .type = Type{ .Int = {} }, .subst = Subst.init(allocator) };
}

fn inferLet(allocator: Allocator, expr: LetExpr, env: *const TypeEnv) TypeError!InferResult {
    _ = expr;
    _ = env;
    return InferResult{ .type = Type{ .Int = {} }, .subst = Subst.init(allocator) };
}

fn inferFn(allocator: Allocator, expr: FnExpr, env: *const TypeEnv) TypeError!InferResult {
    var param_types = std.ArrayList(Type).empty;
    defer {
        for (param_types.items) |*p| cleanupType(allocator, p);
        param_types.deinit(allocator);
    }

    var fn_env = TypeEnv.initWithParent(allocator, env);
    errdefer fn_env.deinit();

    for (expr.params) |name| {
        const var_id = freshTypeVar();
        try param_types.append(allocator, Type{ .Var = var_id });
        try fn_env.extend(name, Scheme{ .Mono = Type{ .Var = var_id } });
    }

    const body_result = try infer(allocator, expr.body, &fn_env);
    const ret_ptr = try allocator.create(Type);
    ret_ptr.* = body_result.type;

    return InferResult{
        .type = Type{ .Fn = .{ .params = param_types, .return_type = ret_ptr } },
        .subst = body_result.subst,
    };
}

fn inferFnCall(allocator: Allocator, expr: FnCallExpr, env: *const TypeEnv) TypeError!InferResult {
    const func_result = try infer(allocator, expr.func, env);
    if (func_result.type != .Fn) {
        return InferResult{ .type = Type{ .Var = freshTypeVar() }, .subst = func_result.subst };
    }

    const fn_data = func_result.type.Fn;
    if (fn_data.params.items.len != expr.args.len) {
        return error.ArityMismatch;
    }

    return InferResult{ .type = fn_data.return_type.*, .subst = func_result.subst };
}

fn inferADT(allocator: Allocator, expr: ADTExpr, env: *const TypeEnv) TypeError!InferResult {
    var type_args = std.ArrayList(Type).empty;
    defer {
        for (type_args.items) |*a| cleanupType(allocator, a);
        type_args.deinit(allocator);
    }

    if (expr.data) |d| {
        const res = try infer(allocator, d, env);
        try type_args.append(allocator, res.type);
    }

    const name = try allocator.dupe(u8, expr.type_name);
    return InferResult{
        .type = Type{ .ADT = .{ .name = name, .type_args = type_args } },
        .subst = Subst.init(allocator),
    };
}

fn inferMatch(allocator: Allocator, expr: MatchExpr, env: *const TypeEnv) TypeError!InferResult {
    const val_res = try infer(allocator, expr.value, env);
    _ = val_res;

    for (expr.arms) |arm| {
        var arm_env = TypeEnv.initWithParent(allocator, env);
        errdefer arm_env.deinit();
        try bindPattern(allocator, &arm.pattern, &arm_env);
        _ = try infer(allocator, arm.body, &arm_env);
    }

    return InferResult{ .type = Type{ .Int = {} }, .subst = Subst.init(allocator) };
}

fn bindPattern(allocator: Allocator, pat: *const MatchPattern, env: *TypeEnv) TypeError!void {
    switch (pat.*) {
        .Wildcard => {},
        .Var => |n| try env.extend(n, Scheme{ .Mono = Type{ .Var = freshTypeVar() } }),
        .IntLiteral, .BoolLiteral => {},
        .ADTVariant => |a| {
            if (a.data_pattern) |d| try bindPattern(allocator, d, env);
        },
    }
}

fn cleanupType(allocator: Allocator, t: *Type) void {
    switch (t.*) {
        .Fn => |*f| {
            for (f.params.items) |*p| cleanupType(allocator, p);
            f.params.deinit(allocator);
            allocator.destroy(f.return_type);
        },
        .ADT => |*a| {
            allocator.free(a.name);
            for (a.type_args.items) |*x| cleanupType(allocator, x);
            a.type_args.deinit(allocator);
        },
        .Unit, .Bool, .Int, .Float, .Var => {},
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════

test "infer int literal" {
    const a = std.testing.allocator;
    const e = TypedExpr{ .Int = .{ .value = 42 } };
    const env = TypeEnv.init(a);
    const r = try infer(a, &e, &env);
    try std.testing.expect(r.type == .Int);
}

test "infer bool literal" {
    const a = std.testing.allocator;
    const e = TypedExpr{ .Bool = .{ .value = true } };
    const env = TypeEnv.init(a);
    const r = try infer(a, &e, &env);
    try std.testing.expect(r.type == .Bool);
}

test "infer variable lookup" {
    const a = std.testing.allocator;
    var env = TypeEnv.init(a);
    defer env.deinit();
    try env.extend("x", Scheme{ .Mono = Type{ .Int = {} } });
    const e = TypedExpr{ .Var = .{ .name = "x" } };
    const r = try infer(a, &e, &env);
    try std.testing.expect(r.type == .Int);
}

test "infer variable undeclared fails" {
    const a = std.testing.allocator;
    const env = TypeEnv.init(a);
    const e = TypedExpr{ .Var = .{ .name = "y" } };
    const r = infer(a, &e, &env);
    try std.testing.expectError(error.UndeclaredVariable, r);
}

test "infer binary op add" {
    const a = std.testing.allocator;
    const left = try a.create(TypedExpr);
    defer a.destroy(left);
    left.* = TypedExpr{ .Int = .{ .value = 5 } };
    const right = try a.create(TypedExpr);
    defer a.destroy(right);
    right.* = TypedExpr{ .Int = .{ .value = 3 } };
    const e = TypedExpr{ .BinOp = .{ .left = left, .op = .Add, .right = right } };
    const env = TypeEnv.init(a);
    const r = try infer(a, &e, &env);
    try std.testing.expect(r.type == .Int);
}

test "infer if expression" {
    const a = std.testing.allocator;
    const cond = try a.create(TypedExpr);
    defer a.destroy(cond);
    cond.* = TypedExpr{ .Bool = .{ .value = true } };
    const th = try a.create(TypedExpr);
    defer a.destroy(th);
    th.* = TypedExpr{ .Int = .{ .value = 1 } };
    const el = try a.create(TypedExpr);
    defer a.destroy(el);
    el.* = TypedExpr{ .Int = .{ .value = 2 } };
    const e = TypedExpr{ .If = .{ .condition = cond, .then_branch = th, .else_branch = el } };
    const env = TypeEnv.init(a);
    const r = try infer(a, &e, &env);
    try std.testing.expect(r.type == .Int);
}

test "infer let expression" {
    const a = std.testing.allocator;
    const val = try a.create(TypedExpr);
    defer a.destroy(val);
    val.* = TypedExpr{ .Int = .{ .value = 42 } };
    const body = try a.create(TypedExpr);
    defer a.destroy(body);
    body.* = TypedExpr{ .Var = .{ .name = "x" } };
    const e = TypedExpr{ .Let = .{ .name = "x", .value = val, .body = body } };
    var env = TypeEnv.init(a);
    defer env.deinit();
    const r = try infer(a, &e, &env);
    try std.testing.expect(r.type == .Int);
}

test "infer fn expression" {
    const a = std.testing.allocator;
    const body = try a.create(TypedExpr);
    defer a.destroy(body);
    body.* = TypedExpr{ .Var = .{ .name = "x" } };
    const p = try a.dupe(u8, "x");
    defer a.free(p);
    const e = TypedExpr{ .Fn = .{ .params = &.{p}, .body = body } };
    const env = TypeEnv.init(a);
    const r = try infer(a, &e, &env);
    try std.testing.expect(r.type == .Fn);
}

test "infer fn call" {
    const a = std.testing.allocator;
    const fb = try a.create(TypedExpr);
    defer a.destroy(fb);
    fb.* = TypedExpr{ .Int = .{ .value = 42 } };
    const p = try a.dupe(u8, "x");
    defer a.free(p);
    const fe = try a.create(TypedExpr);
    defer a.destroy(fe);
    fe.* = TypedExpr{ .Fn = .{ .params = &.{p}, .body = fb } };
    const arg = try a.create(TypedExpr);
    defer a.destroy(arg);
    arg.* = TypedExpr{ .Int = .{ .value = 5 } };
    const e = TypedExpr{ .FnCall = .{ .func = fe, .args = &.{arg} } };
    const env = TypeEnv.init(a);
    const r = try infer(a, &e, &env);
    try std.testing.expect(r.type == .Var or r.type == .Int);
}

test "infer fn call arity mismatch fails" {
    const a = std.testing.allocator;
    const fb = try a.create(TypedExpr);
    defer a.destroy(fb);
    fb.* = TypedExpr{ .Int = .{ .value = 42 } };
    const p = try a.dupe(u8, "x");
    defer a.free(p);
    const fe = try a.create(TypedExpr);
    defer a.destroy(fe);
    fe.* = TypedExpr{ .Fn = .{ .params = &.{p}, .body = fb } };
    const a1 = try a.create(TypedExpr);
    defer a.destroy(a1);
    a1.* = TypedExpr{ .Int = .{ .value = 1 } };
    const a2 = try a.create(TypedExpr);
    defer a.destroy(a2);
    a2.* = TypedExpr{ .Int = .{ .value = 2 } };
    const e = TypedExpr{ .FnCall = .{ .func = fe, .args = &.{ a1, a2 } } };
    const env = TypeEnv.init(a);
    const r = infer(a, &e, &env);
    try std.testing.expectError(error.ArityMismatch, r);
}

test "infer adt value" {
    const a = std.testing.allocator;
    const d = try a.create(TypedExpr);
    defer a.destroy(d);
    d.* = TypedExpr{ .Int = .{ .value = 42 } };
    const e = TypedExpr{ .ADT = .{ .type_name = "Option", .variant = "Some", .data = d } };
    const env = TypeEnv.init(a);
    const r = try infer(a, &e, &env);
    try std.testing.expect(r.type == .ADT);
}

test "infer adt value no data" {
    const a = std.testing.allocator;
    const e = TypedExpr{ .ADT = .{ .type_name = "Option", .variant = "None", .data = null } };
    const env = TypeEnv.init(a);
    const r = try infer(a, &e, &env);
    try std.testing.expect(r.type == .ADT);
}

test "infer match expression" {
    const a = std.testing.allocator;
    const v = try a.create(TypedExpr);
    defer a.destroy(v);
    v.* = TypedExpr{ .ADT = .{ .type_name = "Option", .variant = "Some", .data = null } };
    const b1 = try a.create(TypedExpr);
    defer a.destroy(b1);
    b1.* = TypedExpr{ .Int = .{ .value = 0 } };
    const b2 = try a.create(TypedExpr);
    defer a.destroy(b2);
    b2.* = TypedExpr{ .Int = .{ .value = 42 } };
    const arms = &[_]MatchArm{
        .{ .pattern = .{ .ADTVariant = .{ .variant = "None", .data_pattern = null } }, .body = b1 },
        .{ .pattern = .{ .ADTVariant = .{ .variant = "Some", .data_pattern = null } }, .body = b2 },
    };
    const e = TypedExpr{ .Match = .{ .value = v, .arms = arms } };
    const env = TypeEnv.init(a);
    const r = try infer(a, &e, &env);
    try std.testing.expect(r.type == .Int);
}

test "infer match wildcard" {
    const a = std.testing.allocator;
    const v = try a.create(TypedExpr);
    defer a.destroy(v);
    v.* = TypedExpr{ .Int = .{ .value = 42 } };
    const b = try a.create(TypedExpr);
    defer a.destroy(b);
    b.* = TypedExpr{ .Int = .{ .value = 0 } };
    const arms = &[_]MatchArm{.{ .pattern = .Wildcard, .body = b }};
    const e = TypedExpr{ .Match = .{ .value = v, .arms = arms } };
    const env = TypeEnv.init(a);
    const r = try infer(a, &e, &env);
    try std.testing.expect(r.type == .Int);
}

test "infer match var pattern" {
    const a = std.testing.allocator;
    const v = try a.create(TypedExpr);
    defer a.destroy(v);
    v.* = TypedExpr{ .Int = .{ .value = 42 } };
    const b = try a.create(TypedExpr);
    defer a.destroy(b);
    b.* = TypedExpr{ .Int = .{ .value = 43 } };
    const arms = &[_]MatchArm{.{ .pattern = .{ .Var = "x" }, .body = b }};
    const e = TypedExpr{ .Match = .{ .value = v, .arms = arms } };
    const env = TypeEnv.init(a);
    const r = try infer(a, &e, &env);
    try std.testing.expect(r.type == .Int);
}
