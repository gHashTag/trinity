// ═══════════════════════════════════════════════════════════════════════════
// ast.zig - Abstract Syntax Tree for Tri Language
// ═══════════════════════════════════════════════════════════════════════════
//
// Sacred formula: V = n × 3^k × π^m × φ^p × e^q
// Golden identity: φ² + 1/φ² = 3
//
// Issue #408: ADT Enum + Exhaustive Match + Pipe
//
// ═══════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// Location in source file for error reporting
pub const SourceLocation = struct {
    line: usize,
    column: usize,
};

/// All AST node types
pub const Node = union(enum) {
    // ═════════════════════════════════════════════════════════════════════
    // ADT ENUM (Rust-style) - Data-carrying enums
    // ═════════════════════════════════════════════════════════════════════════

    /// Function definition: fn name(params) -> return_type { body }
    Function: FunctionDecl,

    /// Struct definition: struct Name { fields }
    StructDef: StructDecl,

    /// Enum definition: enum Name { Variant(data), Variant, ... }
    EnumDef: EnumDecl,

    /// Type alias: type NewType = BaseType
    TypeAlias: TypeAliasDecl,

    // ═════════════════════════════════════════════════════════════════════════════
    // STATEMENTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Return statement: return expr
    Return: ReturnStmt,

    /// Let binding: let name = expr
    Let: LetStmt,

    /// If statement with optional else
    If: IfStmt,

    /// While loop
    While: WhileStmt,

    /// For loop: for var in start..end { body }
    For: ForStmt,

    /// Expression statement (function call, etc.)
    Expression: ExprStmt,

    // ═════════════════════════════════════════════════════════════════════════════════════
    // EXPRESSIONS (with ADT variants)
    // ═════════════════════════════════════════════════════════════════════════════════════════════

    /// Integer literal
    IntLiteral: IntLiteralExpr,

    /// Float literal
    FloatLiteral: FloatLiteralExpr,

    /// String literal
    StringLiteral: StringLiteralExpr,

    /// Character literal (trit literal 'tr')
    CharLiteral: CharLiteralExpr,

    /// Boolean literal (true/false)
    BoolLiteral: BoolLiteralExpr,

    /// Identifier reference
    Identifier: IdentifierExpr,

    /// Binary operation: a op b
    BinaryOp: BinaryOpExpr,

    /// Unary operation: op a
    UnaryOp: UnaryOpExpr,

    /// Function call: func(arg1, arg2, ...)
    Call: CallExpr,

    /// Field access: obj.field
    FieldAccess: FieldAccessExpr,

    /// Array access: arr[index]
    ArrayAccess: ArrayAccessExpr,

    /// PIPE EXPRESSION: expr |> func |> func2 |> ...
    Pipe: PipeExpr,

    /// MATCH EXPRESSION (exhaustive match)
    Match: MatchExpr,

    /// ARRAY literal: [a, b, c, ...]
    ArrayLiteral: ArrayLiteralExpr,

    /// Named pipeline reference: pipeline_name
    PipelineRef: PipelineRefExpr,
};

/// Function declaration
pub const FunctionDecl = struct {
    name: []const u8,
    params: []Param,
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
    fields: []Field,
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
    variants: []EnumVariant,
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

/// Return statement
pub const ReturnStmt = struct {
    value: Expression,
    loc: SourceLocation,
};

/// Let statement
pub const LetStmt = struct {
    name: []const u8,
    value: Expression,
    loc: SourceLocation,
};

/// If statement
pub const IfStmt = struct {
    condition: Expression,
    then_branch: []const Statement,
    else_branch: ?[]const Statement,
    loc: SourceLocation,
};

/// While loop
pub const WhileStmt = struct {
    condition: Expression,
    body: []const Statement,
    loc: SourceLocation,
};

/// For loop
pub const ForStmt = struct {
    var_name: []const u8,
    range: Range,
    body: []const Statement,
    loc: SourceLocation,
};

/// Loop range
pub const Range = union(enum) {
    /// start..end
    To: struct { start: Expression, end: Expression },
    /// start..=end (inclusive)
    ToEq: struct { start: Expression, end: Expression },
};

/// All statement types
pub const Statement = union(enum) {
    Return: ReturnStmt,
    Let: LetStmt,
    If: IfStmt,
    While: WhileStmt,
    For: ForStmt,
    Expression: ExpressionStmt,
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
    left: Expression,
    op: BinaryOperator,
    right: Expression,
    loc: SourceLocation,
};

/// Unary operator expression
pub const UnaryOpExpr = struct {
    op: UnaryOperator,
    operand: Expression,
    loc: SourceLocation,
};

/// Function call expression
pub const CallExpr = struct {
    callee: Expression,
    args: []Expression,
    loc: SourceLocation,
};

/// Field access expression
pub const FieldAccessExpr = struct {
    object: Expression,
    field: []const u8,
    loc: SourceLocation,
};

/// Array access expression
pub const ArrayAccessExpr = struct {
    array: Expression,
    index: Expression,
    loc: SourceLocation,
};

/// PIPE EXPRESSION - Elixir-style pipe chain
/// expr |> func1 |> func2 |> ... |> funcN
pub const PipeExpr = struct {
    /// Initial value
    source: Expression,
    /// Pipeline stages (functions to pipe through)
    stages: []Expression,
    loc: SourceLocation,
};

/// MATCH EXPRESSION - Rust/Elixir exhaustive match
/// match value {
///     Variant1(data) => action1,
///     Variant2        => action2,
///     Variant3(data) => action3,
/// }
pub const MatchExpr = struct {
    /// Value to match against
    value: Expression,
    /// Match arms (pattern + guard + body)
    arms: []MatchArm,
    loc: SourceLocation,
};

/// Single match arm
pub const MatchArm = struct {
    /// Pattern to match (ADT variant, literal, wildcard, etc.)
    pattern: Pattern,
    /// Optional guard: | condition = expr
    guard: ?Guard,
    /// Body expression if pattern matches (and guard passes)
    body: Expression,
    loc: SourceLocation,
};

/// Guard condition - Haskell-style
/// | condition = expr
pub const Guard = struct {
    /// Boolean expression (must evaluate to true)
    condition: Expression,
    loc: SourceLocation,
};

/// Array literal expression
pub const ArrayLiteralExpr = struct {
    elements: []Expression,
    loc: SourceLocation,
};

/// Named pipeline reference
pub const PipelineRefExpr = struct {
    name: []const u8,
    loc: SourceLocation,
};

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
    /// Array type: [T]
    Array: TypeArray,
    /// Function type: fn(args) -> return
    Function: TypeFunction,
    /// Struct type (name of struct)
    Struct: TypeStruct,
    /// Enum type (name of enum)
    Enum: TypeEnum,
    /// Reference to defined type
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

/// Array type [T]
pub const TypeArray = struct {
    element_type: Type,
    /// Optional fixed size (e.g., [8]trit)
    size: ?usize,
};

/// Function type fn(args) -> return
pub const TypeFunction = struct {
    params: []Type,
    return_type: Type,
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

/// Binary operators
pub const BinaryOperator = enum(u4) {
    // Arithmetic
    Add,
    Sub,
    Mul,
    Div,
    Mod,

    // Logic
    BitAnd,
    BitOr,
    BitXor,
    BitNot,
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

    // Ternary logic
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

/// ═════════════════════════════════════════════════════════════════════════
// PATTERNS (for match arms)
// ═════════════════════════════════════════════════════════════════════════════════════

/// Pattern for matching (ADT variant, literal, wildcard, etc.)
pub const Pattern = union(enum) {
    /// Wildcard pattern: _ (matches anything)
    Wildcard: PatternWildcard,

    /// Literal pattern: 42, true, 'tr', "string"
    Literal: PatternLiteral,

    /// Identifier pattern (binds name)
    Identifier: PatternIdentifier,

    /// Enum variant pattern: Variant(data)
    EnumVariant: PatternEnumVariant,

    /// Struct pattern: Struct { field: pattern, ... }
    Struct: PatternStruct,

    /// Array pattern: [p1, p2, ...]
    Array: PatternArray,

    /// Range pattern: start..=end
    Range: PatternRange,
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
};

/// Identifier pattern
pub const PatternIdentifier = struct {
    name: []const u8,
};

/// Enum variant pattern
pub const PatternEnumVariant = struct {
    /// Name of enum
    enum_name: []const u8,
    /// Name of variant
    variant_name: []const u8,
    /// Optional nested pattern for variant data
    data_pattern: ?Pattern,
};

/// Struct pattern
pub const PatternStruct = struct {
    /// Name of struct
    struct_name: []const u8,
    /// Field patterns: name => pattern
    field_patterns: []FieldPattern,
};

/// Field pattern in struct match
pub const FieldPattern = struct {
    field_name: []const u8,
    pattern: Pattern,
};

/// Array pattern
pub const PatternArray = struct {
    elements: []Pattern,
};

/// Range pattern
pub const PatternRange = struct {
    start: Expression,
    end: Expression,
    inclusive: bool,
};

/// ═══════════════════════════════════════════════════════════════════════
// NAMED PIPELINES (Elixir-style reusable pipe chains)
// ═════════════════════════════════════════════════════════════════════════════════════

/// Named pipeline definition
/// pipeline flow = input |> filter |> map |> output
pub const PipelineDecl = struct {
    name: []const u8,
    /// Parameters (optional)
    params: []Param,
    /// Pipeline body (must be a pipe expression or identifier)
    body: Expression,
    loc: SourceLocation,
};
