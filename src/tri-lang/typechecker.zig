// ═══════════════════════════════════════════════════════════════════
// Typechecker (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_typechecker.zig");

pub const TypedExpr = gen.TypedExpr;
pub const IntExpr = gen.IntExpr;
pub const BoolExpr = gen.BoolExpr;
pub const VarExpr = gen.VarExpr;
pub const BinOpExpr = gen.BinOpExpr;
pub const IfExpr = gen.IfExpr;
pub const LetExpr = gen.LetExpr;
pub const FnExpr = gen.FnExpr;
pub const FnCallExpr = gen.FnCallExpr;
pub const ADTExpr = gen.ADTExpr;
pub const MatchExpr = gen.MatchExpr;
pub const PipeExpr = gen.PipeExpr;
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
pub const HandlerClauseTyped = gen.HandlerClauseTyped;
pub const MatchArm = gen.MatchArm;
pub const MatchPattern = gen.MatchPattern;
pub const ADTPattern = gen.ADTPattern;
pub const TypeError = gen.TypeError;
pub const InferResult = gen.InferResult;
pub const Bank = gen.Bank;
pub const LinearTracker = gen.LinearTracker;
pub const infer = gen.infer;
pub const checkResultExhaustive = gen.checkResultExhaustive;
pub const checkResultMatch = gen.checkResultMatch;
pub const checkBankSafety = gen.checkBankSafety;
pub const getBankFromType = gen.getBankFromType;
pub const checkLinearUsage = gen.checkLinearUsage;

// Manual (disabled):
// const manual = @import("typechecker_manual.zig");
// pub const TypedExpr = manual.TypedExpr;
// ... (all other exports)
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════
