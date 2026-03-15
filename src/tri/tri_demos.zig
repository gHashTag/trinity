// @origin(spec:tri_demos.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - Demo & Benchmark Functions (Re-export Layer)
// ═══════════════════════════════════════════════════════════════════════════════
//
// All demo and benchmark functions for TRI CLI feature cycles.
// Split into themed sub-modules under demos/ for faster compilation.
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

// ── Sub-module imports ───────────────────────────────────────────────────────

const tvc_agent = @import("demos/tvc_agent_demo.zig");
const context_rag = @import("demos/context_rag_demo.zig");
const voice_sandbox = @import("demos/voice_sandbox_demo.zig");
const stream_vision = @import("demos/stream_vision_demo.zig");
const finetune_batch = @import("demos/finetune_batch_demo.zig");
const tooluse_vision2 = @import("demos/tooluse_vision2_demo.zig");
const voice_agent2 = @import("demos/voice_agent2_demo.zig");
const orchestration = @import("demos/orchestration_demo.zig");

// ── TVC & Agent demos (Cycles 14-15) ────────────────────────────────────────

pub const runTVCDemo = tvc_agent.runTVCDemo;
pub const runTVCStats = tvc_agent.runTVCStats;
pub const runAgentsDemo = tvc_agent.runAgentsDemo;
pub const runAgentsBench = tvc_agent.runAgentsBench;

// ── Context & RAG demos (Cycles 16-17) ──────────────────────────────────────

pub const runContextDemo = context_rag.runContextDemo;
pub const runContextBench = context_rag.runContextBench;
pub const runRAGDemo = context_rag.runRAGDemo;
pub const runRAGBench = context_rag.runRAGBench;

// ── Voice Legacy & Sandbox demos (Cycles 18-19) ────────────────────────────

pub const runVoiceDemoLegacy = voice_sandbox.runVoiceDemoLegacy;
pub const runVoiceBenchLegacy = voice_sandbox.runVoiceBenchLegacy;
pub const runSandboxDemo = voice_sandbox.runSandboxDemo;
pub const runSandboxBench = voice_sandbox.runSandboxBench;

// ── Stream & Vision Legacy demos (Cycles 19-20) ────────────────────────────

pub const runStreamDemo = stream_vision.runStreamDemo;
pub const runStreamBench = stream_vision.runStreamBench;
pub const runVisionDemoLegacy = stream_vision.runVisionDemoLegacy;
pub const runVisionBenchLegacy = stream_vision.runVisionBenchLegacy;

// ── Fine-tune, Batched, Priority, Deadline, MultiModal (Cycles 21-26) ──────

pub const runFineTuneDemo = finetune_batch.runFineTuneDemo;
pub const runFineTuneBench = finetune_batch.runFineTuneBench;
pub const runBatchedDemo = finetune_batch.runBatchedDemo;
pub const runBatchedBench = finetune_batch.runBatchedBench;
pub const runPriorityDemo = finetune_batch.runPriorityDemo;
pub const runPriorityBench = finetune_batch.runPriorityBench;
pub const runDeadlineDemo = finetune_batch.runDeadlineDemo;
pub const runDeadlineBench = finetune_batch.runDeadlineBench;
pub const runMultiModalDemo = finetune_batch.runMultiModalDemo;
pub const runMultiModalBench = finetune_batch.runMultiModalBench;

// ── Tool Use & Vision v2 demos (Cycles 27-28) ──────────────────────────────

pub const runToolUseDemo = tooluse_vision2.runToolUseDemo;
pub const runToolUseBench = tooluse_vision2.runToolUseBench;
pub const runVisionDemo = tooluse_vision2.runVisionDemo;
pub const runVisionBench = tooluse_vision2.runVisionBench;

// ── Voice IO & Agent v2 demos (Cycles 29-31) ───────────────────────────────

pub const runVoiceIODemo = voice_agent2.runVoiceIODemo;
pub const runVoiceIOBench = voice_agent2.runVoiceIOBench;
pub const runUnifiedAgentDemo = voice_agent2.runUnifiedAgentDemo;
pub const runUnifiedAgentBench = voice_agent2.runUnifiedAgentBench;
pub const runAutonomousAgentDemo = voice_agent2.runAutonomousAgentDemo;
pub const runAutonomousAgentBench = voice_agent2.runAutonomousAgentBench;

// ── Orchestration & remaining demos (Cycles 32-53) ─────────────────────────

pub const runOrchestrationDemo = orchestration.runOrchestrationDemo;
pub const runOrchestrationBench = orchestration.runOrchestrationBench;
pub const runMMOrchDemo = orchestration.runMMOrchDemo;
pub const runMMOrchBench = orchestration.runMMOrchBench;
pub const runMemoryDemo = orchestration.runMemoryDemo;
pub const runMemoryBench = orchestration.runMemoryBench;
pub const runPersistDemo = orchestration.runPersistDemo;
pub const runPersistBench = orchestration.runPersistBench;
pub const runSpawnDemo = orchestration.runSpawnDemo;
pub const runSpawnBench = orchestration.runSpawnBench;
pub const runClusterDemo = orchestration.runClusterDemo;
pub const runClusterBench = orchestration.runClusterBench;
pub const runStreamPipelineDemo = orchestration.runStreamPipelineDemo;
pub const runStreamPipelineBench = orchestration.runStreamPipelineBench;
pub const runWorkStealDemo = orchestration.runWorkStealDemo;
pub const runWorkStealBench = orchestration.runWorkStealBench;
pub const runPluginDemo = orchestration.runPluginDemo;
pub const runPluginBench = orchestration.runPluginBench;
pub const runCommsDemo = orchestration.runCommsDemo;
pub const runCommsBench = orchestration.runCommsBench;
pub const runObserveDemo = orchestration.runObserveDemo;
pub const runObserveBench = orchestration.runObserveBench;
pub const runConsensusDemo = orchestration.runConsensusDemo;
pub const runConsensusBench = orchestration.runConsensusBench;
pub const runSpecExecDemo = orchestration.runSpecExecDemo;
pub const runSpecExecBench = orchestration.runSpecExecBench;
pub const runGovernorDemo = orchestration.runGovernorDemo;
pub const runGovernorBench = orchestration.runGovernorBench;
pub const runFedLearnDemo = orchestration.runFedLearnDemo;
pub const runFedLearnBench = orchestration.runFedLearnBench;
pub const runEventSrcDemo = orchestration.runEventSrcDemo;
pub const runEventSrcBench = orchestration.runEventSrcBench;
pub const runCapSecDemo = orchestration.runCapSecDemo;
pub const runCapSecBench = orchestration.runCapSecBench;
pub const runDTxnDemo = orchestration.runDTxnDemo;
pub const runDTxnBench = orchestration.runDTxnBench;
pub const runCacheDemo = orchestration.runCacheDemo;
pub const runCacheBench = orchestration.runCacheBench;
pub const runContractDemo = orchestration.runContractDemo;
pub const runContractBench = orchestration.runContractBench;
pub const runWorkflowDemo = orchestration.runWorkflowDemo;
pub const runWorkflowBench = orchestration.runWorkflowBench;

test "demo re-exports are valid" {
    // Verify all re-exported function pointers are non-null
    try std.testing.expect(@intFromPtr(&runTVCDemo) != 0);
    try std.testing.expect(@intFromPtr(&runOrchestrationDemo) != 0);
    try std.testing.expect(@intFromPtr(&runWorkflowDemo) != 0);
    try std.testing.expect(@intFromPtr(&runCacheDemo) != 0);
}

const std = @import("std");
