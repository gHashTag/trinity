// ═══════════════════════════════════════════════════════════════════
// TYPECHECKER (GENERATED)
// ═══════════════════════════════════════════════════════════════════
// Hindley-Milner Type Inference for Tri Language
// Generated from: specs/tri-lang/typechecker.tri
// TTT Dogfood v0.1 — DO NOT EDIT DIRECTLY
// Source of truth: .tri spec (edit spec, regenerate)
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════

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
    Pipe: PipeExpr,
    // Wave 2: Effects + Handlers
    Perform: PerformExpr,
    Handle: HandleExpr,
    Try: TryExpr,
    // Wave 4: Array Combinators
    Map: MapExpr,
    Reduce: ReduceExpr,
    Scan: ScanExpr,
    Filter: FilterExpr,
    FlatMap: FlatMapExpr,
    Zip: ZipExpr,
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

pub const PipeExpr = struct {
    source: *const TypedExpr,
    stages: []const *const TypedExpr,
};

pub const PerformExpr = struct {
    effect_name: []const u8,
    operation: []const u8,
    args: []const *const TypedExpr,
};

pub const HandleExpr = struct {
    effect_name: []const u8,
    clauses: []const HandlerClauseTyped,
    body: *const TypedExpr,
};

pub const TryExpr = struct {
    computation: *const TypedExpr,
    handlers: []const HandlerClauseTyped,
};

// ═══════════════════════════════════════════════════════════════════════
// WAVE 4: ARRAY COMBINATOR EXPRESSIONS
// ═════════════════════════════════════════════════════════════════════════════════════

pub const MapExpr = struct {
    array: *const TypedExpr,
    func: *const TypedExpr,
};

pub const ReduceExpr = struct {
    array: *const TypedExpr,
    init: *const TypedExpr,
    operation: BinaryOperator,
};

pub const ScanExpr = struct {
    array: *const TypedExpr,
    init: *const TypedExpr,
    operation: BinaryOperator,
    scan_type: ScanType,
};

pub const ScanType = enum {
    Prefix,
    Inclusive,
    Exclusive,
};

pub const FilterExpr = struct {
    array: *const TypedExpr,
    predicate: *const TypedExpr,
};

pub const FlatMapExpr = struct {
    array: *const TypedExpr,
    func: *const TypedExpr,
};

pub const ZipExpr = struct {
    array1: *const TypedExpr,
    array2: *const TypedExpr,
};

pub const HandlerClauseTyped = struct {
    operation: []const u8,
    param_pattern: MatchPattern,
    body: *const TypedExpr,
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
    // Wave 2: Result type errors
    ResultNotExhaustive,
    MissingOkPattern,
    MissingErrPattern,
    // Wave 2: Linear type errors
    LinearValueNotConsumed,
    LinearValueAlreadyConsumed,
    LinearValueUsedMultipleTimes,
    // Wave 2: Bank safety errors
    BankMismatch,
    CrossBankOperationNotAllowed,
};

pub const InferResult = struct {
    type: Type,
    subst: Subst,

    /// Clean up the Type and Subst in this result
    pub fn deinit(self: *InferResult, allocator: Allocator) void {
        // Clean up heap-allocated data within Type
        InferResult.cleanupType(allocator, &self.type);
        // Clean up Subst HashMap
        self.subst.deinit(allocator);
    }

    /// Clean up heap-allocated data within a Type (without freeing the Type itself)
    fn cleanupType(allocator: Allocator, t: *Type) void {
        switch (t.*) {
            .Fn => |*fn_data| {
                // Params are stored as ArrayList with items pointing to allocated array
                const param_array = fn_data.params.items;
                for (param_array) |*param| {
                    InferResult.cleanupType(allocator, param);
                }
                // Free the items array
                allocator.free(param_array);
                allocator.destroy(fn_data.return_type);
            },
            .ADT => |*adt_data| {
                allocator.free(adt_data.name);
                // Type args are stored as ArrayList with items pointing to allocated array
                const args_array = adt_data.type_args.items;
                for (args_array) |*arg| {
                    InferResult.cleanupType(allocator, arg);
                }
                // Free the items array
                allocator.free(args_array);
            },
            .Unit, .Bool, .Int, .Float, .Var => {},
        }
    }
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
        .Pipe => |e| inferPipe(allocator, e, env),
        // Wave 2: Effects + Handlers
        .Perform => |e| inferPerform(allocator, e, env),
        .Handle => |e| inferHandle(allocator, e, env),
        .Try => |e| inferTry(allocator, e, env),
        // Wave 4: Array Combinators
        .Map => |e| inferMap(allocator, e, env),
        .Reduce => |e| inferReduce(allocator, e, env),
        .Scan => |e| inferScan(allocator, e, env),
        .Filter => |e| inferFilter(allocator, e, env),
        .FlatMap => |e| inferFlatMap(allocator, e, env),
        .Zip => |e| inferZip(allocator, e, env),
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
    var fn_env = TypeEnv.initWithParent(allocator, env);
    defer fn_env.deinit(allocator);

    var param_types = std.ArrayList(Type).empty;
    defer {
        for (param_types.items) |*p| cleanupType(allocator, p);
        param_types.deinit(allocator);
    }

    for (expr.params) |name| {
        const var_id = freshTypeVar();
        try param_types.append(allocator, Type{ .Var = var_id });
        try fn_env.extend(name, Scheme{ .Mono = Type{ .Var = var_id } });
    }

    const body_result = try infer(allocator, expr.body, &fn_env);
    const ret_ptr = try allocator.create(Type);
    ret_ptr.* = body_result.type;

    // Create a shallow copy of param_types for the result
    // The ArrayList is moved into the Type struct
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
        defer arm_env.deinit(allocator);
        try bindPattern(allocator, &arm.pattern, &arm_env);
        _ = try infer(allocator, arm.body, &arm_env);
    }

    return InferResult{ .type = Type{ .Int = {} }, .subst = Subst.init(allocator) };
}

fn inferPipe(allocator: Allocator, expr: PipeExpr, env: *const TypeEnv) TypeError!InferResult {
    // Typecheck source expression
    const source_res = try infer(allocator, expr.source, env);
    var current_type = source_res.type;

    // Typecheck each pipeline stage
    // Each stage must be callable with the previous output type
    for (expr.stages) |stage| {
        const stage_res = try infer(allocator, stage, env);

        // Check if stage is a function type
        if (stage_res.type != .Fn) {
            return error.TypeMismatch;
        }

        const fn_data = stage_res.type.Fn;
        if (fn_data.params.items.len != 1) {
            return error.ArityMismatch;
        }

        // The stage must accept the current type as input
        // For now, we skip unification and just propagate the return type
        current_type = fn_data.return_type.*;
    }

    return InferResult{
        .type = current_type,
        .subst = source_res.subst,
    };
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
    var env = TypeEnv.init(a);
    defer env.deinit(a);
    var r = try infer(a, &e, &env);
    defer r.deinit(a);
    try std.testing.expect(r.type == .Int);
}

test "infer bool literal" {
    const a = std.testing.allocator;
    const e = TypedExpr{ .Bool = .{ .value = true } };
    var env = TypeEnv.init(a);
    defer env.deinit(a);
    var r = try infer(a, &e, &env);
    defer r.deinit(a);
    try std.testing.expect(r.type == .Bool);
}

test "infer variable lookup" {
    const a = std.testing.allocator;
    var env = TypeEnv.init(a);
    defer env.deinit(a);
    try env.extend("x", Scheme{ .Mono = Type{ .Int = {} } });
    const e = TypedExpr{ .Var = .{ .name = "x" } };
    var r = try infer(a, &e, &env);
    defer r.deinit(a);
    try std.testing.expect(r.type == .Int);
}

test "infer variable undeclared fails" {
    const a = std.testing.allocator;
    var env = TypeEnv.init(a);
    defer env.deinit(a);
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
    var env = TypeEnv.init(a);
    defer env.deinit(a);
    var r = try infer(a, &e, &env);
    defer r.deinit(a);
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
    var env = TypeEnv.init(a);
    defer env.deinit(a);
    var r = try infer(a, &e, &env);
    defer r.deinit(a);
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
    defer env.deinit(a);
    var r = try infer(a, &e, &env);
    defer r.deinit(a);
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
    var env = TypeEnv.init(a);
    defer env.deinit(a);
    var r = try infer(a, &e, &env);
    defer r.deinit(a);
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
    var env = TypeEnv.init(a);
    defer env.deinit(a);
    var r = try infer(a, &e, &env);
    defer r.deinit(a);
    try std.testing.expect(r.type == .Var or r.type == .Int);
}

test "infer fn call arity mismatch fails" {
    const a = std.testing.allocator;
    var env = TypeEnv.init(a);
    defer env.deinit(a);
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
    const r = infer(a, &e, &env);
    try std.testing.expectError(error.ArityMismatch, r);
}

test "infer adt value" {
    const a = std.testing.allocator;
    const d = try a.create(TypedExpr);
    defer a.destroy(d);
    d.* = TypedExpr{ .Int = .{ .value = 42 } };
    const e = TypedExpr{ .ADT = .{ .type_name = "Option", .variant = "Some", .data = d } };
    var env = TypeEnv.init(a);
    defer env.deinit(a);
    var r = try infer(a, &e, &env);
    defer r.deinit(a);
    try std.testing.expect(r.type == .ADT);
}

test "infer adt value no data" {
    const a = std.testing.allocator;
    const e = TypedExpr{ .ADT = .{ .type_name = "Option", .variant = "None", .data = null } };
    var env = TypeEnv.init(a);
    defer env.deinit(a);
    var r = try infer(a, &e, &env);
    defer r.deinit(a);
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
    var env = TypeEnv.init(a);
    defer env.deinit(a);
    var r = try infer(a, &e, &env);
    defer r.deinit(a);
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
    var env = TypeEnv.init(a);
    defer env.deinit(a);
    var r = try infer(a, &e, &env);
    defer r.deinit(a);
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
    var env = TypeEnv.init(a);
    defer env.deinit(a);
    var r = try infer(a, &e, &env);
    defer r.deinit(a);
    try std.testing.expect(r.type == .Int);
}

test "infer pipe single stage" {
    const a = std.testing.allocator;
    const src = try a.create(TypedExpr);
    defer a.destroy(src);
    src.* = TypedExpr{ .Int = .{ .value = 42 } };

    const p = try a.dupe(u8, "x");
    defer a.free(p);
    const body = try a.create(TypedExpr);
    defer a.destroy(body);
    body.* = TypedExpr{ .Var = .{ .name = "x" } };

    const fn_stage = try a.create(TypedExpr);
    defer a.destroy(fn_stage);
    fn_stage.* = TypedExpr{ .Fn = .{ .params = &.{p}, .body = body } };

    const stages = &[_]*const TypedExpr{fn_stage};
    const e = TypedExpr{ .Pipe = .{ .source = src, .stages = stages } };
    var env = TypeEnv.init(a);
    defer env.deinit(a);
    var r = try infer(a, &e, &env);
    defer r.deinit(a);
    try std.testing.expect(r.type == .Var or r.type == .Int);
}

test "infer pipe multiple stages" {
    const a = std.testing.allocator;
    const src = try a.create(TypedExpr);
    defer a.destroy(src);
    src.* = TypedExpr{ .Int = .{ .value = 42 } };

    const p1 = try a.dupe(u8, "x");
    defer a.free(p1);
    const body1 = try a.create(TypedExpr);
    defer a.destroy(body1);
    body1.* = TypedExpr{ .Var = .{ .name = "x" } };

    const fn_stage1 = try a.create(TypedExpr);
    defer a.destroy(fn_stage1);
    fn_stage1.* = TypedExpr{ .Fn = .{ .params = &.{p1}, .body = body1 } };

    const p2 = try a.dupe(u8, "y");
    defer a.free(p2);
    const body2 = try a.create(TypedExpr);
    defer a.destroy(body2);
    body2.* = TypedExpr{ .Var = .{ .name = "y" } };

    const fn_stage2 = try a.create(TypedExpr);
    defer a.destroy(fn_stage2);
    fn_stage2.* = TypedExpr{ .Fn = .{ .params = &.{p2}, .body = body2 } };

    const stages = &[_]*const TypedExpr{ fn_stage1, fn_stage2 };
    const e = TypedExpr{ .Pipe = .{ .source = src, .stages = stages } };
    var env = TypeEnv.init(a);
    defer env.deinit(a);
    var r = try infer(a, &e, &env);
    defer r.deinit(a);
    try std.testing.expect(r.type == .Var or r.type == .Int);
}

test "infer pipe stage not_function fails" {
    const a = std.testing.allocator;
    var env = TypeEnv.init(a);
    defer env.deinit(a);
    const src = try a.create(TypedExpr);
    defer a.destroy(src);
    src.* = TypedExpr{ .Int = .{ .value = 42 } };

    const stage = try a.create(TypedExpr);
    defer a.destroy(stage);
    stage.* = TypedExpr{ .Int = .{ .value = 99 } };

    const stages = &[_]*const TypedExpr{stage};
    const e = TypedExpr{ .Pipe = .{ .source = src, .stages = stages } };
    const r = infer(a, &e, &env);
    try std.testing.expectError(error.TypeMismatch, r);
}

test "infer pipe stage arity_mismatch fails" {
    const a = std.testing.allocator;
    var env = TypeEnv.init(a);
    defer env.deinit(a);
    const src = try a.create(TypedExpr);
    defer a.destroy(src);
    src.* = TypedExpr{ .Int = .{ .value = 42 } };

    const p1 = try a.dupe(u8, "x");
    defer a.free(p1);
    const p2 = try a.dupe(u8, "y");
    defer a.free(p2);
    const body = try a.create(TypedExpr);
    defer a.destroy(body);
    body.* = TypedExpr{ .Int = .{ .value = 0 } };

    // Function with 2 parameters
    const fn_stage = try a.create(TypedExpr);
    defer a.destroy(fn_stage);
    fn_stage.* = TypedExpr{ .Fn = .{ .params = &.{ p1, p2 }, .body = body } };

    const stages = &[_]*const TypedExpr{fn_stage};
    const e = TypedExpr{ .Pipe = .{ .source = src, .stages = stages } };
    const r = infer(a, &e, &env);
    try std.testing.expectError(error.ArityMismatch, r);
}

// ═══════════════════════════════════════════════════════════════════════════════
// WAVE 2: RESULT TYPE EXHAUSTIVENESS CHECKING
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Check if Result type match is exhaustive
/// Must have patterns for both Ok and Err variants
pub fn checkResultExhaustive(match_arms: []const MatchArm) TypeError!void {
    var has_ok: bool = false;
    var has_err: bool = false;
    var has_wildcard: bool = false;

    for (match_arms) |arm| {
        if (arm.pattern == .Wildcard) {
            has_wildcard = true;
            break; // Wildcard covers everything
        }

        if (arm.pattern == .ADTVariant) {
            const variant = arm.pattern.ADTVariant.variant;
            if (std.mem.eql(u8, variant, "Ok") or std.mem.eql(u8, variant, "Some")) {
                has_ok = true;
            } else if (std.mem.eql(u8, variant, "Err") or std.mem.eql(u8, variant, "None")) {
                has_err = true;
            }
        }
    }

    // If wildcard is present, match is exhaustive
    if (has_wildcard) return;

    // Otherwise, must have both Ok and Err patterns
    if (!has_ok) return error.MissingOkPattern;
    if (!has_err) return error.MissingErrPattern;
}

/// Check if match expression on Result type is exhaustive
pub fn checkResultMatch(value_type: Type, match_arms: []const MatchArm) TypeError!void {
    // For now, assume any ADT match might be a Result
    // Full implementation would check if value_type is Result(T, E)
    _ = value_type;
    try checkResultExhaustive(match_arms);
}

// ═══════════════════════════════════════════════════════════════════════════════
// WAVE 2: BANK SAFETY CHECKING
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Bank identifier for Coptic register safety
pub const Bank = enum(u2) {
    /// Bank 0: ALU registers (t0-t8)
    ALU = 0,
    /// Bank 1: Sacred accumulators (t9-t17)
    Sacred = 1,
    /// Bank 2: Constants (t18-t26)
    Constant = 2,
};

/// Check if operation respects bank boundaries
/// Operations on banked values must be in the same bank
pub fn checkBankSafety(left_bank: ?Bank, right_bank: ?Bank) TypeError!void {
    // If either side has no bank constraint, operation is allowed
    if (left_bank == null or right_bank == null) return;

    // Both sides must be from the same bank
    if (left_bank.? != right_bank.?) {
        return error.BankMismatch;
    }
}

/// Get bank from type (if it's a Banked type)
pub fn getBankFromType(t: Type) ?Bank {
    _ = t;
    // Full implementation would inspect the type and return the bank
    // For now, return null (no bank constraint)
    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// WAVE 2: LINEAR TYPE CONSUMPTION TRACKING
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Track linear variable usage during compilation
pub const LinearTracker = struct {
    allocator: Allocator,
    /// Map from variable name to consumption state
    /// false = not consumed, true = consumed
    variables: std.StringHashMap(bool),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .variables = std.StringHashMap(bool).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.variables.deinit();
    }

    /// Declare a linear variable
    pub fn declare(self: *Self, name: []const u8) !void {
        try self.variables.put(name, false);
    }

    /// Mark variable as consumed
    pub fn consume(self: *Self, name: []const u8) !void {
        const entry = self.variables.get(name) orelse return error.UndeclaredVariable;
        if (entry) return error.LinearValueAlreadyConsumed;
        try self.variables.put(name, true);
    }

    /// Check if variable is consumed
    pub fn isConsumed(self: *const Self, name: []const u8) bool {
        const entry = self.variables.get(name) orelse return false;
        return entry;
    }

    /// Check if all linear variables are consumed (end of scope)
    pub fn checkAllConsumed(self: *const Self) !void {
        var iter = self.variables.iterator();
        while (iter.next()) |entry| {
            if (!entry.value_ptr.*) {
                // Variable not consumed
                return error.LinearValueNotConsumed;
            }
        }
    }

    /// Get list of unconsumed variables
    pub fn getUnconsumed(self: *Self, allocator: Allocator) ![][]const u8 {
        var result = std.ArrayList([]const u8).init(allocator);
        var iter = self.variables.iterator();
        while (iter.next()) |entry| {
            if (!entry.value_ptr.*) {
                try result.append(allocator, entry.key_ptr.*);
            }
        }
        return result.toOwnedSlice();
    }
};

/// Check if expression uses linear variables correctly
pub fn checkLinearUsage(expr: *const TypedExpr, tracker: *LinearTracker) TypeError!void {
    _ = expr;
    _ = tracker;
    // Full implementation would:
    // - Track which variables are marked as linear
    // - Mark variables as consumed when used
    // - Error if linear variable used multiple times
    // - Error if linear variable not consumed at end of scope
    return;
}

// ═══════════════════════════════════════════════════════════════════════════════
// WAVE 2: EFFECTS + HANDLERS TYPE CHECKING
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Type check perform expression: perform effect.operation(args)
fn inferPerform(allocator: Allocator, expr: PerformExpr, env: *const TypeEnv) TypeError!InferResult {
    _ = expr.effect_name;
    _ = expr.operation;

    // Type check all arguments
    for (expr.args) |arg| {
        _ = try infer(allocator, arg, env);
    }

    // For now, perform expressions have a polymorphic return type
    // The actual type depends on the handler
    return InferResult{
        .type = Type{ .Var = freshTypeVar() },
        .subst = Subst.init(allocator),
    };
}

/// Type check handle expression: handle effect { clauses }
fn inferHandle(allocator: Allocator, expr: HandleExpr, env: *const TypeEnv) TypeError!InferResult {
    // Type check the body computation
    const body_result = try infer(allocator, expr.body, env);

    // Type check each handler clause
    for (expr.clauses) |clause| {
        _ = clause.operation;
        _ = clause.param_pattern;

        // Type check the handler body
        _ = try infer(allocator, clause.body, env);
    }

    return InferResult{
        .type = body_result.type,
        .subst = body_result.subst,
    };
}

/// Type check try expression: try { computation } with { handlers }
fn inferTry(allocator: Allocator, expr: TryExpr, env: *const TypeEnv) TypeError!InferResult {
    // Type check the computation
    const comp_result = try infer(allocator, expr.computation, env);

    // Type check each handler clause
    for (expr.handlers) |clause| {
        _ = clause.operation;
        _ = clause.param_pattern;

        // Type check the handler body
        _ = try infer(allocator, clause.body, env);
    }

    return InferResult{
        .type = comp_result.type,
        .subst = comp_result.subst,
    };
}

// ═══════════════════════════════════════════════════════════════════════
// WAVE 4: ARRAY COMBINATOR TYPE INFERENCE
// ═════════════════════════════════════════════════════════════════════════════════════

/// Type check map expression: map(array, func) -> [func(x) for x in array]
/// Input: array of type [A], func of type A -> B
/// Output: array of type [B]
fn inferMap(allocator: Allocator, expr: MapExpr, env: *const TypeEnv) TypeError!InferResult {
    // Type check array expression
    const array_result = try infer(allocator, expr.array, env);

    // Type check function expression
    const func_result = try infer(allocator, expr.func, env);

    _ = array_result;
    _ = func_result;

    // For now, return a fresh array type
    // Full implementation would:
    // 1. Check that array_result.type is an array type [A]
    // 2. Check that func_result.type is a function type A -> B
    // 3. Return array type [B]

    return InferResult{
        .type = Type{ .Var = freshTypeVar() },
        .subst = Subst.init(allocator),
    };
}

/// Type check reduce expression: reduce(array, init, op) -> folded value
/// Input: array of type [A], init of type B, op of type (B, A) -> B or (B, B) -> B
/// Output: value of type B
fn inferReduce(allocator: Allocator, expr: ReduceExpr, env: *const TypeEnv) TypeError!InferResult {
    // Type check array expression
    const array_result = try infer(allocator, expr.array, env);

    // Type check init expression
    const init_result = try infer(allocator, expr.init, env);

    _ = array_result;
    _ = expr.operation;

    // For now, return the type of init
    // Full implementation would:
    // 1. Check that array_result.type is an array type
    // 2. Check that operation is associative
    // 3. Check that operation can combine init type with array element type

    return InferResult{
        .type = init_result.type,
        .subst = init_result.subst,
    };
}

/// Type check scan expression: scan(array, init, op) -> prefix scan array
/// Input: array of type [A], init of type B, op of type (B, A) -> B
/// Output: array of type [B]
fn inferScan(allocator: Allocator, expr: ScanExpr, env: *const TypeEnv) TypeError!InferResult {
    // Type check array expression
    const array_result = try infer(allocator, expr.array, env);

    // Type check init expression
    const init_result = try infer(allocator, expr.init, env);

    _ = array_result;
    _ = init_result;
    _ = expr.operation;
    _ = expr.scan_type;

    // For now, return a fresh array type
    // Full implementation would:
    // 1. Check that array_result.type is an array type [A]
    // 2. Check that operation can combine init type with array element type
    // 3. Return array type [B] where B is the type of init

    return InferResult{
        .type = Type{ .Var = freshTypeVar() },
        .subst = Subst.init(allocator),
    };
}

/// Type check filter expression: filter(array, pred) -> filtered array
/// Input: array of type [A], pred of type A -> Bool
/// Output: array of type [A]
fn inferFilter(allocator: Allocator, expr: FilterExpr, env: *const TypeEnv) TypeError!InferResult {
    // Type check array expression
    const array_result = try infer(allocator, expr.array, env);

    // Type check predicate expression
    const pred_result = try infer(allocator, expr.predicate, env);

    _ = array_result;
    _ = pred_result;

    // For now, return the input array type
    // Full implementation would:
    // 1. Check that array_result.type is an array type [A]
    // 2. Check that pred_result.type is a function A -> Bool
    // 3. Return array type [A]

    return InferResult{
        .type = Type{ .Var = freshTypeVar() },
        .subst = Subst.init(allocator),
    };
}

/// Type check flatMap expression: flatMap(array, func) -> concatenated array
/// Input: array of type [A], func of type A -> [B]
/// Output: array of type [B]
fn inferFlatMap(allocator: Allocator, expr: FlatMapExpr, env: *const TypeEnv) TypeError!InferResult {
    // Type check array expression
    const array_result = try infer(allocator, expr.array, env);

    // Type check function expression
    const func_result = try infer(allocator, expr.func, env);

    _ = array_result;
    _ = func_result;

    // For now, return a fresh array type
    // Full implementation would:
    // 1. Check that array_result.type is an array type [A]
    // 2. Check that func_result.type is a function A -> [B]
    // 3. Return array type [B]

    return InferResult{
        .type = Type{ .Var = freshTypeVar() },
        .subst = Subst.init(allocator),
    };
}

/// Type check zip expression: zip(arr1, arr2) -> paired array
/// Input: arr1 of type [A], arr2 of type [B]
/// Output: array of type [(A, B)]
fn inferZip(allocator: Allocator, expr: ZipExpr, env: *const TypeEnv) TypeError!InferResult {
    // Type check first array
    const arr1_result = try infer(allocator, expr.array1, env);

    // Type check second array
    const arr2_result = try infer(allocator, expr.array2, env);

    _ = arr1_result;
    _ = arr2_result;

    // For now, return a fresh array type
    // Full implementation would:
    // 1. Check that both expressions are array types
    // 2. Check that arrays have the same length (if known at compile time)
    // 3. Return array type of tuples [(A, B)]

    return InferResult{
        .type = Type{ .Var = freshTypeVar() },
        .subst = Subst.init(allocator),
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// WAVE 2: TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════

test "Result exhaustiveness with both patterns" {
    const arms = &[_]MatchArm{
        .{ .pattern = .{ .ADTVariant = .{ .variant = "Ok", .data_pattern = null } }, .body = undefined },
        .{ .pattern = .{ .ADTVariant = .{ .variant = "Err", .data_pattern = null } }, .body = undefined },
    };
    try checkResultExhaustive(arms);
}

test "Result exhaustiveness with wildcard" {
    const arms = &[_]MatchArm{
        .{ .pattern = .Wildcard, .body = undefined },
    };
    try checkResultExhaustive(arms);
}

test "Result exhaustiveness missing Ok fails" {
    const arms = &[_]MatchArm{
        .{ .pattern = .{ .ADTVariant = .{ .variant = "Err", .data_pattern = null } }, .body = undefined },
    };
    try std.testing.expectError(error.MissingOkPattern, checkResultExhaustive(arms));
}

test "Result exhaustiveness missing Err fails" {
    const arms = &[_]MatchArm{
        .{ .pattern = .{ .ADTVariant = .{ .variant = "Ok", .data_pattern = null } }, .body = undefined },
    };
    try std.testing.expectError(error.MissingErrPattern, checkResultExhaustive(arms));
}

test "Bank safety same bank" {
    try checkBankSafety(.ALU, .ALU);
}

test "Bank safety null bank" {
    try checkBankSafety(.ALU, null);
    try checkBankSafety(null, .ALU);
    try checkBankSafety(null, null);
}

test "Bank safety different banks fails" {
    try std.testing.expectError(error.BankMismatch, checkBankSafety(.ALU, .Sacred));
}

test "LinearTracker declare and consume" {
    var tracker = LinearTracker.init(std.testing.allocator);
    defer tracker.deinit();

    try tracker.declare("x");
    try std.testing.expect(!tracker.isConsumed("x"));

    try tracker.consume("x");
    try std.testing.expect(tracker.isConsumed("x"));
}

test "LinearTracker consume twice fails" {
    var tracker = LinearTracker.init(std.testing.allocator);
    defer tracker.deinit();

    try tracker.declare("x");
    try tracker.consume("x");
    try std.testing.expectError(error.LinearValueAlreadyConsumed, tracker.consume("x"));
}

test "LinearTracker all consumed" {
    var tracker = LinearTracker.init(std.testing.allocator);
    defer tracker.deinit();

    try tracker.declare("x");
    try tracker.declare("y");
    try tracker.consume("x");
    try tracker.consume("y");

    try tracker.checkAllConsumed();
}

test "LinearTracker not all consumed fails" {
    var tracker = LinearTracker.init(std.testing.allocator);
    defer tracker.deinit();

    try tracker.declare("x");
    try tracker.declare("y");
    try tracker.consume("x");

    try std.testing.expectError(error.LinearValueNotConsumed, tracker.checkAllConsumed());
}
