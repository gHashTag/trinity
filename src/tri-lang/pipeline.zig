// ═══════════════════════════════════════════════════════════════════
// Pipeline (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_pipeline.zig");

pub const PipelineError = gen.PipelineError;
pub const IOError = gen.IOError;
pub const OptLevel = gen.OptLevel;
pub const CompileOptions = gen.CompileOptions;
pub const PipelineResult = gen.PipelineResult;
pub const TriParser = gen.TriParser;
pub const optimize = gen.optimize;
pub const optimizeWithOptions = gen.optimizeWithOptions;
pub const compile = gen.compile;
pub const compileWithOptions = gen.compileWithOptions;
pub const compileWithOptLevel = gen.compileWithOptLevel;
pub const compileSource = gen.compileSource;
pub const compileFile = gen.compileFile;

// Manual (disabled):
// const manual = @import("pipeline_manual.zig");
// pub const PipelineError = manual.PipelineError;
// ... (all other exports)
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════
