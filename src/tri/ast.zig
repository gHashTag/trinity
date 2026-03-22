//! AST — Abstract Syntax Tree for Tri language
//! v0.2 — Node types for parsed code

const Token = @import("token.zig").Token;
pub const TritValue = Token.TritValue;

// Main AST node
pub const Node = union(enum) {
    program: []Statement,
};

// Function declaration payload
pub const FnDecl = struct {
    name: []const u8,
    params: []Param,
    body: []Statement,
    return_type: Type,
};

// Variable declaration payload
pub const VarDecl = struct {
    name: []const u8,
    type: Type,
    init: ?Expression,
};

// Match expression payload
pub const MatchExpr = struct {
    value: Expression,
    arms: []MatchArm,
};

// Return statement payload
pub const ReturnStmt = struct {
    value: ?Expression,
};

// Expression types
pub const Expression = union(enum) {
    literal_trit: TritValue,
    literal_int: i64,
    literal_float: f64,
    identifier: []const u8,
    wildcard,
    binary_op: struct { op: BinOp, left: Expression, right: Expression },
    call: struct { func: []const u8, args: []Expression },
};

// Binary operator types
pub const BinOp = enum {
    at_at,     // @@
    plus_plus,  // ++
    tilde,      // ~
    plus,       // +
    minus,      // -
    times,      // *
    eq,         // ==
    neq,        // !=
    gt,         // >
    lt,         // <
};

// Match arm pattern
pub const Pattern = union(enum) {
    literal_trit: TritValue,
    wildcard,
    identifier: []const u8,
};

// Match arm
pub const MatchArm = struct {
    pattern: Pattern,
    body: []Statement,
};

// Function parameter
pub const Param = struct {
    name: []const u8,
    type: Type,
};

// Statement types
pub const Statement = union(enum) {
    fn_decl: FnDecl,
    var_decl: VarDecl,
    expression: Expression,
    return_stmt: ReturnStmt,
    match_expr: MatchExpr,
};

// Array type payload
pub const ArrayType = struct {
    size: usize,
    elem: *Type,
};

// Type enum
pub const Type = union(enum) {
    trit: void,
    t3: void,
    t9: void,
    t27: void,
    gf16: void,
    tf3: void,
    void: void,
    array: ArrayType,
    type_struct: []Field,
};

// Struct field
pub const Field = struct {
    name: []const u8,
    type: Type,
};
