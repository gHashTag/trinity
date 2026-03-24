// ═══════════════════════════════════════════════════════════════════════════
// ast.zig - Abstract Syntax Tree for Tri Language
// ═══════════════════════════════════════════════════════════════════════════
//
// Sacred formula: V = n × 3^k × π^m × φ^p × e^q
// Golden identity: φ² + 1/φ² = 3
//
// Issue #408: ADT Enum + Exhaustive Match + Pipe
//
// NOTE:
// - Чётко разделены уровни: Program / Declaration / Statement / Expr / Pattern / Type
// - Все рекурсивные ссылки идут через *const (указатели), чтобы избежать бесконечных типов
// - BinaryOperator uses enum(u5), чтобы влезли все варианты
//
// ═══════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// Location in source file for error reporting
pub const SourceLocation = struct {
    line: usize,
    column: usize,
};

// ╔════════════════════════════════════════════════════════════════════════╗
// ║ Program and Declarations                                                ║
// ╚════════════════════════════════════════════════════════════════════════╝

/// Top-level program
pub const Program = struct {
    declarations: []const Declaration,
};

/// Top-level declarations
pub const Declaration = union(enum) {
    Function: FunctionDecl,
    StructDef: StructDecl,
    EnumDef: EnumDecl,
    TypeAlias: TypeAliasDecl,
    Pipeline: PipelineDecl,
    // Later: EffectDecl, TestDecl, etc.
};

/// Function declaration: fn name(params) -> return_type { body }
pub const FunctionDecl = struct {
    name: []const u8,
    params: []const Param,
    return_type: Type,
    body: []const Statement,
    loc: SourceLocation,
};

/// Parameter
pub const Param = struct {
    name: []const u8,
    param_type: Type,
    loc: SourceLocation,
};

/// Struct declaration
pub const StructDecl = struct {
    name: []const u8,
    fields: []const Field,
    loc: SourceLocation,
};

/// Struct field
pub const Field = struct {
    name: []const u8,
    field_type: Type,
    loc: SourceLocation,
};

/// Enum declaration
pub const EnumDecl = struct {
    name: []const u8,
    variants: []const EnumVariant,
    loc: SourceLocation,
};

/// Enum variant (data-carrying)
pub const EnumVariant = struct {
    name: []const u8,
    /// Optional data type (e.g., Active(gf16) has gf16 data)
    data_type: ?Type,
    loc: SourceLocation,
};

/// Type alias
pub const TypeAliasDecl = struct {
    name: []const u8,
    aliased_type: Type,
    loc: SourceLocation,
};

/// Named pipeline definition
/// pipeline flow = input |> filter |> map |> output
pub const PipelineDecl = struct {
    name: []const u8,
    /// Parameters (optional)
    params: []const Param,
    /// Pipeline body (pipe expression or identifier)
    body: Expr,
    loc: SourceLocation,
};

// ╔════════════════════════════════════════════════════════════════════════╗
// ║ Statements                                                              ║
// ╚════════════════════════════════════════════════════════════════════════╝

/// All statement types
pub const Statement = union(enum) {
    Return: ReturnStmt,
    Let: LetStmt,
    If: IfStmt,
    While: WhileStmt,
    For: ForStmt,
    Expression: ExprStmt,
};

/// Return statement: return expr
pub const ReturnStmt = struct {
    value: Expr,
    loc: SourceLocation,
};

/// Let binding: let name = expr
pub const LetStmt = struct {
    name: []const u8,
    value: Expr,
    loc: SourceLocation,
};

/// If statement with optional else
pub const IfStmt = struct {
    condition: Expr,
    then_branch: []const Statement,
    else_branch: ?[]const Statement,
    loc: SourceLocation,
};

/// While loop
pub const WhileStmt = struct {
    condition: Expr,
    body: []const Statement,
    loc: SourceLocation,
};

/// For loop: for var in start..end { body }
pub const ForStmt = struct {
    var_name: []const u8,
    range: Range,
    body: []const Statement,
    loc: SourceLocation,
};

/// Expression statement (function call, etc.)
pub const ExprStmt = struct {
    expr: Expr,
    loc: SourceLocation,
};

/// Loop range
pub const Range = union(enum) {
    /// start..end
    To: struct { start: Expr, end: Expr },
    /// start..=end (inclusive)
    ToEq: struct { start: Expr, end: Expr },
};

// ╔════════════════════════════════════════════════════════════════════════╗
// ║ Expressions                                                            ║
// ╚════════════════════════════════════════════════════════════════════════╝

/// All expressions
pub const Expr = union(enum) {
    // Literals
    IntLiteral: IntLiteralExpr,
    FloatLiteral: FloatLiteralExpr,
    StringLiteral: StringLiteralExpr,
    CharLiteral: CharLiteralExpr,
    BoolLiteral: BoolLiteralExpr,

    // Identifiers and calls
    Identifier: IdentifierExpr,
    Call: CallExpr,

    // Operations
    BinaryOp: BinaryOpExpr,
    UnaryOp: UnaryOpExpr,

    // Access
    FieldAccess: FieldAccessExpr,
    ArrayAccess: ArrayAccessExpr,

    // Collections
    ArrayLiteral: ArrayLiteralExpr,

    // Pipe / Match / Pipeline
    Pipe: PipeExpr,
    Match: MatchExpr,
    PipelineRef: PipelineRefExpr,

    // Typed hole (for autocode generation)
    Hole: HoleExpr,
};

/// Integer literal
pub const IntLiteralExpr = struct {
    value: i64,
    loc: SourceLocation,
};

/// Float literal
pub const FloatLiteralExpr = struct {
    value: f64,
    loc: SourceLocation,
};

/// String literal
pub const StringLiteralExpr = struct {
    value: []const u8,
    loc: SourceLocation,
};

/// Character (trit) literal
pub const CharLiteralExpr = struct {
    value: u8,
    loc: SourceLocation,
};

/// Boolean literal
pub const BoolLiteralExpr = struct {
    value: bool,
    loc: SourceLocation,
};

/// Identifier expression
pub const IdentifierExpr = struct {
    name: []const u8,
    loc: SourceLocation,
};

/// Binary operator expression
pub const BinaryOpExpr = struct {
    left: Expr,
    op: BinaryOperator,
    right: Expr,
    loc: SourceLocation,
};

/// Unary operator expression
pub const UnaryOpExpr = struct {
    op: UnaryOperator,
    operand: Expr,
    loc: SourceLocation,
};

/// Function call expression: callee(args...)
pub const CallExpr = struct {
    callee: Expr,
    args: []const Expr,
    loc: SourceLocation,
};

/// Field access expression: obj.field
pub const FieldAccessExpr = struct {
    object: Expr,
    field: []const u8,
    loc: SourceLocation,
};

/// Array access expression: arr[index]
pub const ArrayAccessExpr = struct {
    array: Expr,
    index: Expr,
    loc: SourceLocation,
};

/// PIPE EXPRESSION - Elixir-style pipe chain
/// expr |> func1 |> func2 |> ... |> funcN
pub const PipeExpr = struct {
    /// Initial value
    source: Expr,
    /// Pipeline stages (functions or identifiers to pipe through)
    stages: []const Expr,
    loc: SourceLocation,
};

/// MATCH EXPRESSION - Rust/Elixir exhaustive match
/// match value {
///     Variant1(data) => action1,
///     Variant2        => action2,
///     Variant3(data)  => action3,
/// }
pub const MatchExpr = struct {
    /// Value to match against
    value: Expr,
    /// Match arms (pattern + guard + body)
    arms: []const MatchArm,
    loc: SourceLocation,
};

/// Array literal expression
pub const ArrayLiteralExpr = struct {
    elements: []const Expr,
    loc: SourceLocation,
};

/// Named pipeline reference
pub const PipelineRefExpr = struct {
    name: []const u8,
    loc: SourceLocation,
};

/// Typed hole expression: ?hole_name
pub const HoleExpr = struct {
    name: []const u8,
    expected_type: ?*const Type,
    loc: SourceLocation,
};

// ╔════════════════════════════════════════════════════════════════════════╗
// ║ Match Arms, Guards, Patterns                                           ║
// ╚════════════════════════════════════════════════════════════════════════╝

/// Single match arm
pub const MatchArm = struct {
    /// Pattern to match (ADT variant, literal, wildcard, etc.)
    pattern: Pattern,
    /// Optional guard: | condition
    guard: ?Guard,
    /// Body expression if pattern matches (and guard passes)
    body: Expr,
    loc: SourceLocation,
};

/// Guard condition - Haskell-style
/// | condition
pub const Guard = struct {
    /// Boolean expression (must evaluate to true)
    condition: Expr,
    loc: SourceLocation,
};

/// Pattern for matching (ADT variant, literal, wildcard, etc.)
pub const Pattern = union(enum) {
    /// Wildcard pattern: _ (matches anything)
    Wildcard: PatternWildcard,

    /// Literal pattern: 42, true, 'tr', "string"
    Literal: PatternLiteral,

    /// Identifier pattern (binds name)
    Identifier: PatternIdentifier,

    /// Enum variant pattern: Enum.Variant(data)
    EnumVariant: PatternEnumVariant,

    /// Struct pattern: Struct { field: pattern, ... }
    Struct: PatternStruct,

    /// Array pattern: [p1, p2, ...]
    Array: PatternArray,

    /// Range pattern: start..=end
    Range: PatternRange,

    /// Typed hole in pattern (for synthesis)
    Hole: PatternHole,
};

/// Wildcard pattern
pub const PatternWildcard = void;

/// Literal pattern
pub const PatternLiteral = struct {
    value: LiteralValue,
};

/// Literal values for patterns
pub const LiteralValue = union(enum) {
    Int: i64,
    Float: f64,
    String: []const u8,
    Char: u8,
    Bool: bool,
    // Later: BitPattern, TritPattern
};

/// Identifier pattern
pub const PatternIdentifier = struct {
    name: []const u8,
};

/// Enum variant pattern
pub const PatternEnumVariant = struct {
    /// Name of enum (optional; may be inferred)
    enum_name: ?[]const u8,
    /// Name of variant
    variant_name: []const u8,
    /// Optional nested pattern for variant data
    data_pattern: ?*const Pattern,
};

/// Struct pattern
pub const PatternStruct = struct {
    /// Name of struct
    struct_name: []const u8,
    /// Field patterns: name => pattern
    field_patterns: []const FieldPattern,
};

/// Field pattern in struct match
pub const FieldPattern = struct {
    field_name: []const u8,
    pattern: Pattern,
};

/// Array pattern
pub const PatternArray = struct {
    elements: []const Pattern,
};

/// Range pattern
pub const PatternRange = struct {
    start: Expr,
    end: Expr,
    inclusive: bool,
};

/// Typed hole pattern: ?name
pub const PatternHole = struct {
    name: []const u8,
    expected_type: ?Type,
};

// ╔════════════════════════════════════════════════════════════════════════╗
// ║ Types                                                                  ║
// ╚════════════════════════════════════════════════════════════════════════╝

/// All types in Tri
pub const Type = union(enum) {
    /// Native ternary types
    Trit: TypeTrit,
    /// Integer types
    Int: TypeInt,
    /// Float types
    Float: TypeFloat,
    /// String type
    String: TypeString,
    /// Boolean type
    Bool: TypeBool,
    /// Array type: [T] or [N]T
    Array: TypeArray,
    /// Function type: fn(args) -> return
    Function: TypeFunction,
    /// Result type: Result(T, E) - no exceptions
    Result: TypeResult,
    /// Struct type (name of struct)
    Struct: TypeStruct,
    /// Enum type (name of enum)
    Enum: TypeEnum,
    /// Named type reference / alias
    Named: TypeNamed,
};

/// Trit types (native)
pub const TypeTrit = enum(u2) {
    /// Single trit: {-1, 0, +1}
    Trit = 0,
    /// 3 trits packed
    Trit3 = 1,
    /// 9 trits packed
    Trit9 = 2,
    /// 27 trits packed
    Trit27 = 3,
};

/// Integer types
pub const TypeInt = enum(u2) {
    I8 = 0,
    I16 = 1,
    I32 = 2,
    I64 = 3,
};

/// Float types
pub const TypeFloat = enum(u2) {
    F16 = 0,
    F32 = 1,
    F64 = 2,
};

/// String type
pub const TypeString = void;

/// Boolean type
pub const TypeBool = void;

/// Array type [T] or [N]T
pub const TypeArray = struct {
    element_type: *const Type,
    /// Optional fixed size (e.g., [8]trit)
    size: ?usize,
};

/// Function type fn(args) -> return
pub const TypeFunction = struct {
    params: []const Type,
    return_type: *const Type,
};

/// Result type: Result(T, E) - no exceptions
pub const TypeResult = struct {
    ok_type: *const Type,
    err_type: *const Type,
};

/// Struct type
pub const TypeStruct = struct {
    name: []const u8,
};

/// Enum type
pub const TypeEnum = struct {
    name: []const u8,
};

/// Named type reference
pub const TypeNamed = struct {
    name: []const u8,
};

// ╔════════════════════════════════════════════════════════════════════════╗
// ║ Operators                                                              ║
// ╚════════════════════════════════════════════════════════════════════════╝

/// Binary operators
pub const BinaryOperator = enum(u5) {
    // Arithmetic
    Add,
    Sub,
    Mul,
    Div,
    Mod,

    // Bitwise / ternary logic (some reserved for ternary ops later)
    BitAnd,
    BitOr,
    BitXor,
    ShiftLeft,
    ShiftRight,

    // Comparison
    Equal,
    NotEqual,
    Less,
    LessEqual,
    Greater,
    GreaterEqual,

    // Sacred operations (dot product)
    Dot,

    // Ternary logic (placeholders)
    TernaryAnd,
    TernaryOr,
    TernaryNot,
    TernaryXor,
};

/// Unary operators
pub const UnaryOperator = enum(u3) {
    Neg,
    BitNot,
    Deref,
};
