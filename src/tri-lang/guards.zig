// ═══════════════════════════════════════════════════════════════════════════════
// Guards (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_guards.zig");

pub const GuardExpr = gen.GuardExpr;
pub const GuardBinaryOp = gen.GuardBinaryOp;
pub const GuardUnaryOp = gen.GuardUnaryOp;
pub const BinaryOperator = gen.BinaryOperator;
pub const UnaryOperator = gen.UnaryOperator;
pub const GuardResult = gen.GuardResult;
pub const Guard = gen.Guard;
pub const GuardCodegen = gen.GuardCodegen;
pub const evalGuard = gen.evalGuard;
pub const isTrivialGuard = gen.isTrivialGuard;
pub const guardAlwaysPasses = gen.guardAlwaysPasses;
pub const guardAlwaysFails = gen.guardAlwaysFails;
pub const compileGuard = gen.compileGuard;
pub const optimizeGuard = gen.optimizeGuard;

// Manual (disabled):
// const manual = @import("guards_manual.zig");
// pub const GuardExpr = manual.GuardExpr;
// ... etc
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
