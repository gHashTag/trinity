// ═══════════════════════════════════════════════════════════════════════════════
// Pipe Expression Desugaring (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_pipe.zig");

pub const PipeExprValue = gen.PipeExprValue;
pub const PipeExpr = gen.PipeExpr;
pub const desugarPipe = gen.desugarPipe;
pub const isPipelineStage = gen.isPipelineStage;
pub const validatePipe = gen.validatePipe;

// Manual (disabled):
// const manual = @import("pipe_manual.zig");
// pub const PipeExpr = manual.PipeExpr;
// ... etc
//
// φ² + 1/φ² = 3 | TRINITY
// ═════════════════════════════════════════════════════════════════════════════
