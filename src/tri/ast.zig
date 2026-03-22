//! AST — Abstract Syntax Tree for Tri language
//! v0.2 — Node types for parsed code

const Token = @import("token.zig").Token;

pub const Node = union(enum) {
    program: []Statement,
    fn_decl: struct {
        name: []const u8,
        params: []Param,
        body: []Statement,
        return_type: Type,
    },
    var_decl: struct {
        name: []const u8,
        type: Type,
        init: ?Expression,
    },
    match_expr: struct {
        value: Expression,
        arms: []MatchArm,
    },
    binary_op: struct {
        op: BinOp,
        left: Expression,
        right: Expression,
    },
    call: struct {
        func: []const u8,
        args: []Expression,
    },
};

pub const Statement = union(enum) {
    fn_decl,
    var_decl,
    expression: Expression,
    return_stmt: struct { value: ?Expression },
};

pub const Expression = union(enum) {
    literal_trit: TritValue,
    literal_int: i64,
    literal_float: f64,
    identifier: []const u8,
    binary_op,
    call,
};

pub const Param = struct {
    name: []const u8,
    type: Type,
};

pub const MatchArm = struct {
    pattern: Pattern,
    body: []Statement,
};

pub const Pattern = union(enum) {
    trit_lit: TritValue,
    wildcard,
};

pub const BinOp = enum {
    at_at,    // @@
    plus_plus,// ++
    tilde,    // ~
    plus,     // +
    minus,    // -
    times,    // *
    eq,       // ==
    neq,      // !=
    gt,       // >
    lt,       // <
};

pub const Type = enum {
    trit,
    t3,
    t9,
    t27,
    gf16,
    tf3,
    void,
    array: struct { size: usize, elem: *Type },
    struct: []Field,
};

pub const Field = struct {
    name: []const u8,
    type: Type,
};
