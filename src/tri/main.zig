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
const math_commands = @import("math/commands.zig");
const tri_context = @import("tri_context.zig");

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

    // Special handling for "test --repl" command (Cycle 100)
    if (args.len >= 3 and std.mem.eql(u8, args[1], "test")) {
        if (std.mem.eql(u8, args[2], "--repl") or std.mem.eql(u8, args[2], "-r")) {
            const cmd_args = if (args.len > 3) args[3..] else &[_][]const u8{};
            try commands.runReplTestCommand(allocator, cmd_args);
            return;
        }
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
        .gen => try commands.runGenCommand(allocator, cmd_args),
        .convert => try commands.runConvertCommand(cmd_args),
        .serve => try commands.runServeCommand(allocator, cmd_args),
        .bench => try commands.runBenchCommand(allocator),
        .evolve => try commands.runEvolveCommand(cmd_args),
        // Git commands
        .commit => try commands.runGitCommand(allocator, "commit", cmd_args),
        .diff => try commands.runGitCommand(allocator, "diff", cmd_args),
        .status => try commands.runGitCommand(allocator, "status", cmd_args),
        .log => try commands.runGitCommand(allocator, "log", cmd_args),
        // Golden Chain Pipeline
        .pipeline => pipeline.runPipelineCommand(allocator, cmd_args),
        .decompose => pipeline.runDecomposeCommand(allocator, cmd_args),
        .plan => pipeline.runPlanCommand(allocator, cmd_args),
        .multi_cluster => try commands.runMultiClusterCommand(allocator, cmd_args),
        .verify => pipeline.runVerifyCommand(allocator),
        .verdict => pipeline.runVerdictCommand(allocator),
        // Test REPL (Cycle 101)
        .test_repl => try commands.runReplTestCommand(allocator, cmd_args),
        // Spec & Loop (v8.27)
        .spec_create => pipeline.runSpecCreateCommand(allocator, cmd_args),
        .loop_decide => pipeline.runLoopDecideCommand(allocator, cmd_args),
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
        .distributed => try commands.runDistributedCommand(allocator, cmd_args),
        // Sacred Mathematics (v3.6)
        .math => math_commands.runMathCommand(allocator, cmd_args) catch |err| {
            std.debug.print("Math error: {}\n", .{err});
        },
        .constants_cmd => math_commands.runConstantsCommand(allocator, cmd_args) catch |err| {
            std.debug.print("Constants error: {}\n", .{err});
        },
        .phi => math_commands.runPhiCommand(allocator, cmd_args) catch |err| {
            std.debug.print("Phi error: {}\n", .{err});
        },
        .fib => math_commands.runFibCommand(allocator, cmd_args) catch |err| {
            std.debug.print("Fib error: {}\n", .{err});
        },
        .lucas => math_commands.runLucasCommand(allocator, cmd_args) catch |err| {
            std.debug.print("Lucas error: {}\n", .{err});
        },
        .spiral => math_commands.runSpiralCommand(allocator, cmd_args) catch |err| {
            std.debug.print("Spiral error: {}\n", .{err});
        },
        .gematria => math_commands.runGematriaTopLevel(allocator, cmd_args) catch |err| {
            std.debug.print("Gematria error: {}\n", .{err});
        },
        .formula_cmd => math_commands.runFormulaCommand(allocator, cmd_args) catch |err| {
            std.debug.print("Formula error: {}\n", .{err});
        },
        .sacred => math_commands.runSacredCommand(allocator, cmd_args) catch |err| {
            std.debug.print("Sacred error: {}\n", .{err});
        },
        // Intelligence System
        .intelligence => tri_context.runIntelligenceCommand(allocator, &state, cmd_args) catch |err| {
            std.debug.print("Intelligence error: {}\n", .{err});
        },
        // Dev Utilities
        .doctor => try commands.runDoctorCommand(allocator),
        .clean => try commands.runCleanCommand(allocator),
        .fmt_cmd => try commands.runFmtCommand(allocator),
        .stats_cmd => try commands.runStatsCommand(allocator),
        .igla => try commands.runIglaCommand(allocator),
        // Cycle 98: Sacred Intelligence
        .identity => try commands.runIdentityCommand(allocator, cmd_args),
        .swarm => try commands.runSwarmCommand(allocator, cmd_args),
        .govern => try commands.runGovernCommand(allocator, cmd_args),
        .dashboard => try commands.runDashboardCommand(allocator, cmd_args),
        .omega => try commands.runOmegaCommand(allocator, cmd_args),
        .math_agent => try commands.runMathAgentCommand(allocator, cmd_args),
        // Codebase Context (Cycle 92)
        .analyze => tri_context.runAnalyzeCommand(&state),
        .search_cmd => tri_context.runSearchCommand(&state, cmd_args),
        .context_info => tri_context.runContextInfoCommand(&state),
        // Autonomous Evolution (Cycle 97)
        .auto_commit => utils.runAutoCommitCommand(&state, cmd_args) catch |err| {
            std.debug.print("Auto-commit error: {}\n", .{err});
        },
        .ml_optimize => utils.runMLOptimizeCommand(&state, cmd_args) catch |err| {
            std.debug.print("ML optimize error: {}\n", .{err});
        },
        .deploy_dashboard => utils.runDeployDashboardCommand(&state, cmd_args) catch |err| {
            std.debug.print("Deploy dashboard error: {}\n", .{err});
        },
        .self_host => utils.runSelfHostCommand(&state, cmd_args) catch |err| {
            std.debug.print("Self-host error: {}\n", .{err});
        },
        .safeguards_show => utils.runSafeguardsShowCommand(&state, cmd_args) catch |err| {
            std.debug.print("Safeguards show error: {}\n", .{err});
        },
        .safeguards_disable => utils.runSafeguardsDisableCommand(&state, cmd_args) catch |err| {
            std.debug.print("Safeguards disable error: {}\n", .{err});
        },
        .deps => utils.printInfo(),
        .info => utils.printInfo(),
        .version => utils.printVersion(),
        .help => utils.printHelp(),
        .orchestrate_v2 => {
            const CYAN = "\x1b[36m";
            const GREEN = "\x1b[32m";
            const GOLDEN = "\x1b[33m";
            const RESET = "\x1b[0m";
            std.debug.print("\n{s}╔══════════════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
            std.debug.print("{s}║  TRINITY ORCHESTRATOR v2.0 — Universal Intelligent Command System    ║{s}\n", .{ CYAN, RESET });
            std.debug.print("{s}╚══════════════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });
            std.debug.print("{s}Features:{s}\n", .{ GREEN, RESET });
            std.debug.print("  • Sequential/parallel/conditional execution strategies\n", .{});
            std.debug.print("  • Sacred Intelligence integration (φ-weighted scoring)\n", .{});
            std.debug.print("  • Rollback capabilities (git-based snapshots)\n", .{});
            std.debug.print("  • Workflow YAML/JSON file support\n", .{});
            std.debug.print("  • Universal command registry (147+ commands)\n\n", .{});
            std.debug.print("{s}Usage:{s}\n", .{ GREEN, RESET });
            std.debug.print("  tri flow <workflow-file>     Execute workflow from file\n", .{});
            std.debug.print("  tri orchestrator <cmd>        Intelligent command routing\n", .{});
            std.debug.print("  tri orchestrate-v2 <args>     Direct orchestration\n\n", .{});
            std.debug.print("{s}Example workflow:{s}\n", .{ GREEN, RESET });
            std.debug.print("  steps:\n", .{});
            std.debug.print("    - command: spec_create\n", .{});
            std.debug.print("      args: {{ name: my_feature }}\n", .{});
            std.debug.print("    - command: gen\n", .{});
            std.debug.print("      depends_on: [spec_create]\n", .{});
            std.debug.print("    - command: verify\n", .{});
            std.debug.print("      depends_on: [gen]\n\n", .{});
            std.debug.print("{s}Status: {s}Core generated, ready for integration{s}\n\n", .{ GOLDEN, GREEN, RESET });
        },
    }
}
