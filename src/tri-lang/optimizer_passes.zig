// ═══════════════════════════════════════════════════════════════════
// OptimizerPasses (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_optimizer_passes.zig");

pub const constantFoldPass = gen.constantFoldPass;
pub const getConstantFoldPass = gen.getConstantFoldPass;
pub const deadCodeElimPass = gen.deadCodeElimPass;
pub const getDeadCodeElimPass = gen.getDeadCodeElimPass;
pub const arrayFusionPass = gen.arrayFusionPass;
pub const getArrayFusionPass = gen.getArrayFusionPass;
pub const inlineExpansionPass = gen.inlineExpansionPass;
pub const getInlineExpansionPass = gen.getInlineExpansionPass;
pub const getStandardPasses = gen.getStandardPasses;
pub const getAggressivePasses = gen.getAggressivePasses;
pub const getMinimalPasses = gen.getMinimalPasses;

// Manual (disabled):
// const manual = @import("optimizer_passes_manual.zig");
// pub const constantFoldPass = manual.constantFoldPass;
// ... (all other exports)
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════
