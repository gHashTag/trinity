// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - Unified Trinity Command Line Interface
// ═══════════════════════════════════════════════════════════════════════════════
//
// Single entry point for all Trinity functionality:
// - Interactive REPL (default)
// - Code generation
// - SWE Agent (fix, explain, test, doc, refactor, reason)
// - VIBEE compilation
// - Conversions (b2t, wasm, gguf)
// - HTTP server
// - Benchmarks
//
// ARCHITECTURE:
// main.zig        - Entry point, Command enum, dispatch (~200 lines)
// tri_colors.zig  - Shared ANSI color constants
// tri_utils.zig   - CLIState, REPL, help, banner, parseCommand
// tri_commands.zig - Tool commands (gen, convert, serve, bench, evolve, git)
// tri_pipeline.zig- Golden Chain pipeline commands
// tri_demos.zig   - All demo & benchmark functions (~7200 lines)
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Decomposed modules
const utils = @import("tri_utils.zig");
const commands = @import("tri_commands.zig");
const pipeline = @import("tri_pipeline.zig");
const demos = @import("tri_demos.zig");
const strict_mode = @import("tri_strict.zig");
const math_mod = @import("tri_math.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    // Use page_allocator to avoid leak-check spam from GGUF reader metadata strings
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var state = try utils.CLIState.init(allocator);
    defer state.deinit();

    // No arguments = interactive mode
    if (args.len < 2) {
        try utils.runInteractiveMode(&state);
        return;
    }

    const cmd = utils.parseCommand(args[1]);
    const cmd_args = if (args.len > 2) args[2..] else &[_][]const u8{};

    switch (cmd) {
        .none => {
            // Treat as chat message
            utils.runChatCommand(&state, args[1..]);
        },
        .chat => utils.runChatCommand(&state, cmd_args),
        .code => utils.runCodeCommand(&state, cmd_args),
        .fix => utils.runSWECommand(&state, .BugFix, cmd_args),
        .explain => utils.runSWECommand(&state, .Explain, cmd_args),
        .test_cmd => utils.runSWECommand(&state, .Test, cmd_args),
        .doc => utils.runSWECommand(&state, .Document, cmd_args),
        .refactor => utils.runSWECommand(&state, .Refactor, cmd_args),
        .reason => utils.runSWECommand(&state, .Reason, cmd_args),
        .gen => commands.runGenCommand(allocator, cmd_args),
        .convert => commands.runConvertCommand(cmd_args),
        .serve => commands.runServeCommand(allocator, cmd_args),
        .bench => commands.runBenchCommand(allocator),
        .evolve => commands.runEvolveCommand(cmd_args),
        // Git commands
        .commit => commands.runGitCommand(allocator, "commit", cmd_args),
        .diff => commands.runGitCommand(allocator, "diff", cmd_args),
        .status => commands.runGitCommand(allocator, "status", cmd_args),
        .log => commands.runGitCommand(allocator, "log", cmd_args),
        // Golden Chain Pipeline
        .pipeline => pipeline.runPipelineCommand(allocator, cmd_args),
        .decompose => pipeline.runDecomposeCommand(allocator, cmd_args),
        .plan => pipeline.runPlanCommand(allocator, cmd_args),
        .verify => pipeline.runVerifyCommand(allocator),
        .verdict => pipeline.runVerdictCommand(allocator),
        // TVC (Distributed Learning)
        .tvc_demo => demos.runTVCDemo(),
        .tvc_stats => demos.runTVCStats(),
        // Multi-Agent System
        .agents_demo => demos.runAgentsDemo(),
        .agents_bench => demos.runAgentsBench(),
        // Long Context
        .context_demo => demos.runContextDemo(),
        .context_bench => demos.runContextBench(),
        // RAG
        .rag_demo => demos.runRAGDemo(),
        .rag_bench => demos.runRAGBench(),
        // Voice I/O
        .voice_demo => demos.runVoiceIODemo(),
        .voice_bench => demos.runVoiceIOBench(),
        // Code Sandbox
        .sandbox_demo => demos.runSandboxDemo(),
        .sandbox_bench => demos.runSandboxBench(),
        // Streaming Multi-Modal Pipeline (Cycle 38)
        .stream_demo => demos.runStreamPipelineDemo(),
        .stream_bench => demos.runStreamPipelineBench(),
        // Local Vision
        .vision_demo => demos.runVisionDemo(),
        .vision_bench => demos.runVisionBench(),
        // Fine-Tuning Engine
        .finetune_demo => demos.runFineTuneDemo(),
        .finetune_bench => demos.runFineTuneBench(),
        // Batched Stealing
        .batched_demo => demos.runBatchedDemo(),
        .batched_bench => demos.runBatchedBench(),
        // Priority Queue
        .priority_demo => demos.runPriorityDemo(),
        .priority_bench => demos.runPriorityBench(),
        // Deadline Scheduling
        .deadline_demo => demos.runDeadlineDemo(),
        .deadline_bench => demos.runDeadlineBench(),
        // Multi-Modal Unified (Cycle 26)
        .multimodal_demo => demos.runMultiModalDemo(),
        .multimodal_bench => demos.runMultiModalBench(),
        // Multi-Modal Tool Use (Cycle 27)
        .tooluse_demo => demos.runToolUseDemo(),
        .tooluse_bench => demos.runToolUseBench(),
        // Unified Multi-Modal Agent (Cycle 30)
        .unified_demo => demos.runUnifiedAgentDemo(),
        .unified_bench => demos.runUnifiedAgentBench(),
        // Autonomous Agent (Cycle 31)
        .autonomous_demo => demos.runAutonomousAgentDemo(),
        .autonomous_bench => demos.runAutonomousAgentBench(),
        // Multi-Agent Orchestration (Cycle 32)
        .orchestration_demo => demos.runOrchestrationDemo(),
        .orchestration_bench => demos.runOrchestrationBench(),
        // MM Multi-Agent Orchestration (Cycle 33)
        .mm_orch_demo => demos.runMMOrchDemo(),
        .mm_orch_bench => demos.runMMOrchBench(),
        // Agent Memory & Cross-Modal Learning (Cycle 34)
        .memory_demo => demos.runMemoryDemo(),
        .memory_bench => demos.runMemoryBench(),
        // Persistent Memory & Disk Serialization (Cycle 35)
        .persist_demo => demos.runPersistDemo(),
        .persist_bench => demos.runPersistBench(),
        // Dynamic Agent Spawning & Load Balancing (Cycle 36)
        .spawn_demo => demos.runSpawnDemo(),
        .spawn_bench => demos.runSpawnBench(),
        // Distributed Multi-Node Agents (Cycle 37)
        .cluster_demo => demos.runClusterDemo(),
        .cluster_bench => demos.runClusterBench(),
        // Adaptive Work-Stealing Scheduler (Cycle 39)
        .worksteal_demo => demos.runWorkStealDemo(),
        .worksteal_bench => demos.runWorkStealBench(),
        // Plugin & Extension System (Cycle 40)
        .plugin_demo => demos.runPluginDemo(),
        .plugin_bench => demos.runPluginBench(),
        // Agent Communication Protocol (Cycle 41)
        .comms_demo => demos.runCommsDemo(),
        .comms_bench => demos.runCommsBench(),
        // Observability & Tracing System (Cycle 42)
        .observe_demo => demos.runObserveDemo(),
        .observe_bench => demos.runObserveBench(),
        // Consensus & Coordination Protocol (Cycle 43)
        .consensus_demo => demos.runConsensusDemo(),
        .consensus_bench => demos.runConsensusBench(),
        // Speculative Execution Engine (Cycle 44)
        .specexec_demo => demos.runSpecExecDemo(),
        .specexec_bench => demos.runSpecExecBench(),
        // Adaptive Resource Governor (Cycle 45)
        .governor_demo => demos.runGovernorDemo(),
        .governor_bench => demos.runGovernorBench(),
        // Federated Learning Protocol (Cycle 46)
        .fedlearn_demo => demos.runFedLearnDemo(),
        .fedlearn_bench => demos.runFedLearnBench(),
        // Event Sourcing & CQRS Engine (Cycle 47)
        .eventsrc_demo => demos.runEventSrcDemo(),
        .eventsrc_bench => demos.runEventSrcBench(),
        // Capability-Based Security Model (Cycle 48)
        .capsec_demo => demos.runCapSecDemo(),
        .capsec_bench => demos.runCapSecBench(),
        // Distributed Transaction Coordinator (Cycle 49)
        .dtxn_demo => demos.runDTxnDemo(),
        .dtxn_bench => demos.runDTxnBench(),
        // Adaptive Caching & Memoization (Cycle 50)
        .cache_demo => demos.runCacheDemo(),
        .cache_bench => demos.runCacheBench(),
        // Contract-Based Agent Negotiation (Cycle 51)
        .contract_demo => demos.runContractDemo(),
        .contract_bench => demos.runContractBench(),
        // Temporal Workflow Engine (Cycle 52)
        .workflow_demo => demos.runWorkflowDemo(),
        .workflow_bench => demos.runWorkflowBench(),
        // Distributed Inference
        .distributed => commands.runDistributedCommand(allocator, cmd_args),
        // Dev Utilities (Cycle 78)
        .doctor => commands.runDoctorCommand(allocator),
        .clean => commands.runCleanCommand(allocator),
        .fmt_cmd => commands.runFmtCommand(allocator),
        .stats_cmd => commands.runStatsCommand(allocator),
        .igla => commands.runIglaCommand(allocator),
        .test_all => commands.runTestAllCommand(allocator),
        // Code Analysis
        .analyze => commands.runAnalyzeCommand(allocator, cmd_args),
        .search_cmd => commands.runSearchCommand(allocator, cmd_args),
        .deps => commands.runDepsCommand(allocator, cmd_args),
        .info => utils.printInfo(),
        .version => utils.printVersion(),
        .help => utils.printHelp(),
        // New Commands - VIBEE First Integration
        .improve => commands.runImproveCommand(allocator, cmd_args),
        .gguf_chat => commands.runGgufChatCommand(allocator, cmd_args),
        .metal => commands.runMetalCommand(allocator),
        .validate => commands.runValidateCommand(allocator, cmd_args),
        .prometheus => commands.runPrometheusCommand(allocator, cmd_args),
        .tvc_compile => commands.runTVCCompileCommand(allocator, cmd_args),
        .competitive_repl => commands.runCompetitiveReplCommand(allocator, cmd_args),
        .kg_server => commands.runKGServerCommand(allocator, cmd_args),
        // VIBEE-First Strict Mode
        .strict => strict_mode.runStrictCommand(allocator, cmd_args),
        // Cycle 81: LSP + Auto-fix
        .lsp => commands.runLspCommand(allocator, cmd_args),
        .autofix => commands.runAutofixCommand(allocator, cmd_args),
        .lint => commands.runLintCommand(allocator, cmd_args),
        // Cycle 82: Sacred Math
        .math => math_mod.runMathCommand(cmd_args),
        .constants_cmd => math_mod.runConstantsCommand(),
        .phi_cmd => math_mod.runPhiCommand(cmd_args),
        .fib_cmd => math_mod.runFibCommand(cmd_args),
        .lucas_cmd => math_mod.runLucasCommand(cmd_args),
        .spiral_cmd => math_mod.runSpiralCommand(cmd_args),
        .math_verify => math_mod.runMathVerifyCommand(),
        .math_bench => math_mod.runMathBenchCommand(),
        .math_compare => math_mod.runMathCompareCommand(cmd_args),
    }
}
