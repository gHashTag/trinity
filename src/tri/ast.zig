//! Strand III: Language & Hardware Bridge
//!
//! TRI-27 compiler component or VSA operations for Trinity S³AI.
//!
//! AST — Abstract Syntax Tree for Tri language
//! v1.0 — Full statement types including control flow

const Token = @import("token.zig").Token;
pub const TritValue = @import("token.zig").TritValue;

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

// If statement payload
pub const IfStmt = struct {
    condition: *Expression,
    then_block: []Statement,
    else_block: ?[]Statement,
};

// While statement payload
pub const WhileStmt = struct {
    condition: *Expression,
    body: []Statement,
};

// Return statement payload
pub const ReturnStmt = struct {
    value: ?Expression,
};

// Match expression payload
pub const MatchExpr = struct {
    value: *Expression,
    arms: []MatchArm,
};

// Expression types
pub const Expression = union(enum) {
    literal_trit: TritValue,
    literal_int: i64,
    literal_float: f64,
    identifier: []const u8,
    wildcard,
    binary_op: BinaryOp,
    call: CallExpr,
};

// Binary operation payload
pub const BinaryOp = struct {
    op: BinOp,
    left: *Expression,
    right: *Expression,
};

// Function call payload
pub const CallExpr = struct {
    func: []const u8,
    args: []Expression,
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

// Binary operator types
pub const BinOp = enum {
    at_at,       // @@
    plus_plus,    // ++
    tilde,        // ~
    plus,         // +
    minus,        // -
    times,        // *
    eq,           // ==
    neq,          // !=
    gt,           // >
    lt,           // <
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
    if_stmt: IfStmt,
    while_stmt: WhileStmt,
};

// Array type payload
pub const ArrayType = struct {
    size: usize,
    elem: *Type,
};

// Type enum
pub const Type = union(enum) {
    t_trit: void,
    t_t3: void,
    t_t9: void,
    t_t27: void,
    t_gf16: void,
    t_tf3: void,
    t_void: void,
    array: ArrayType,
};

// Struct field
pub const Field = struct {
    name: []const u8,
    type: Type,
};

// φ² + 1/φ² = 3 | TRINITY
