// ═══════════════════════════════════════════════════════════════════
// Optimizer (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_optimizer.zig");

pub const OptimizerResult = gen.OptimizerResult;
pub const OptimizerPass = gen.OptimizerPass;
pub const OptimizerStats = gen.OptimizerStats;
pub const OptimizerConfig = gen.OptimizerConfig;
pub const Optimizer = gen.Optimizer;
pub const OptimizerBuilder = gen.OptimizerBuilder;
pub const standardPasses = gen.standardPasses;
pub const aggressivePasses = gen.aggressivePasses;
pub const minimalPasses = gen.minimalPasses;

// Manual (disabled):
// const manual = @import("optimizer_manual.zig");
// pub const OptimizerResult = manual.OptimizerResult;
// ... (all other exports)
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════
