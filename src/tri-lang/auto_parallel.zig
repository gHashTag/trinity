// ═══════════════════════════════════════════════════════════════════
// AutoParallel (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_auto_parallel.zig");

pub const SourceLocation = gen.SourceLocation;
pub const DagNode = gen.DagNode;
pub const Dag = gen.Dag;
pub const DepAnalyzer = gen.DepAnalyzer;
pub const Scheduler = gen.Scheduler;
pub const WorkerStatus = gen.WorkerStatus;
pub const Worker = gen.Worker;
pub const RaceDetector = gen.RaceDetector;
pub const VarAccess = gen.VarAccess;
pub const Race = gen.Race;
pub const RaceType = gen.RaceType;
pub const PipelineStage = gen.PipelineStage;
pub const StageFn = gen.StageFn;
pub const extractPipeline = gen.extractPipeline;

// Manual (disabled):
// const manual = @import("auto_parallel_manual.zig");
// pub const SourceLocation = manual.SourceLocation;
// ... (all other exports)
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════
