// ═══════════════════════════════════════════════════════════════════════════════
// AST (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_ast.zig");

// Program and Declarations
pub const SourceLocation = gen.SourceLocation;
pub const Program = gen.Program;
pub const Declaration = gen.Declaration;
pub const Node = gen.Node;
pub const FunctionDecl = gen.FunctionDecl;
pub const Param = gen.Param;
pub const StructDecl = gen.StructDecl;
pub const Field = gen.Field;
pub const EnumDecl = gen.EnumDecl;
pub const EnumVariant = gen.EnumVariant;
pub const TypeAliasDecl = gen.TypeAliasDecl;
pub const PipelineDecl = gen.PipelineDecl;
pub const EffectDecl = gen.EffectDecl;
pub const EffectOperation = gen.EffectOperation;

// Statements
pub const Statement = gen.Statement;
pub const ReturnStmt = gen.ReturnStmt;
pub const LetStmt = gen.LetStmt;
pub const IfStmt = gen.IfStmt;
pub const WhileStmt = gen.WhileStmt;
pub const ForStmt = gen.ForStmt;
pub const ExprStmt = gen.ExprStmt;
pub const EffectStmt = gen.EffectStmt;
pub const Range = gen.Range;
pub const EffectId = gen.EffectId;
pub const HandlerBody = gen.HandlerBody;
pub const HandlerClause = gen.HandlerClause;

// Expressions
pub const Expr = gen.Expr;
pub const Expression = gen.Expression;
pub const IntLiteralExpr = gen.IntLiteralExpr;
pub const FloatLiteralExpr = gen.FloatLiteralExpr;
pub const StringLiteralExpr = gen.StringLiteralExpr;
pub const CharLiteralExpr = gen.CharLiteralExpr;
pub const BoolLiteralExpr = gen.BoolLiteralExpr;
pub const IdentifierExpr = gen.IdentifierExpr;
pub const BinaryOpExpr = gen.BinaryOpExpr;
pub const UnaryOpExpr = gen.UnaryOpExpr;
pub const CallExpr = gen.CallExpr;
pub const FieldAccessExpr = gen.FieldAccessExpr;
pub const ArrayAccessExpr = gen.ArrayAccessExpr;
pub const ArrayLiteralExpr = gen.ArrayLiteralExpr;
pub const PipeExpr = gen.PipeExpr;
pub const MatchExpr = gen.MatchExpr;
pub const MatchArm = gen.MatchArm;
pub const Guard = gen.Guard;
pub const PipelineRefExpr = gen.PipelineRefExpr;
pub const HoleExpr = gen.HoleExpr;
pub const PerformExpr = gen.PerformExpr;
pub const HandleExpr = gen.HandleExpr;
pub const TryExpr = gen.TryExpr;
pub const MapExpr = gen.MapExpr;
pub const ReduceExpr = gen.ReduceExpr;
pub const ScanExpr = gen.ScanExpr;
pub const ScanType = gen.ScanType;
pub const FilterExpr = gen.FilterExpr;
pub const FlatMapExpr = gen.FlatMapExpr;
pub const ZipExpr = gen.ZipExpr;

// Patterns
pub const Pattern = gen.Pattern;
pub const PatternWildcard = gen.PatternWildcard;
pub const PatternLiteral = gen.PatternLiteral;
pub const LiteralValue = gen.LiteralValue;
pub const PatternIdentifier = gen.PatternIdentifier;
pub const PatternEnumVariant = gen.PatternEnumVariant;
pub const PatternStruct = gen.PatternStruct;
pub const FieldPattern = gen.FieldPattern;
pub const PatternArray = gen.PatternArray;
pub const PatternRange = gen.PatternRange;
pub const PatternHole = gen.PatternHole;

// Types
pub const Type = gen.Type;
pub const TypeTrit = gen.TypeTrit;
pub const Bank = gen.Bank;
pub const TypeInt = gen.TypeInt;
pub const TypeFloat = gen.TypeFloat;
pub const TypeString = gen.TypeString;
pub const TypeBool = gen.TypeBool;
pub const TypeArray = gen.TypeArray;
pub const TypeArrayFixed = gen.TypeArrayFixed;
pub const TypeFunction = gen.TypeFunction;
pub const TypeResult = gen.TypeResult;
pub const TypeLinear = gen.TypeLinear;
pub const TypeBanked = gen.TypeBanked;
pub const OwnershipMode = gen.OwnershipMode;
pub const TypeStruct = gen.TypeStruct;
pub const TypeEnum = gen.TypeEnum;
pub const TypeNamed = gen.TypeNamed;
pub const TypePlatform = gen.TypePlatform;
pub const PlatformTarget = gen.PlatformTarget;

// Operators
pub const BinaryOperator = gen.BinaryOperator;
pub const UnaryOperator = gen.UnaryOperator;

// Manual (disabled):
// const manual = @import("ast_manual.zig");
// pub const SourceLocation = manual.SourceLocation;
// ... (all other exports)
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
