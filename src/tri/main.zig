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
const tri_config = @import("tri_config.zig");
const commands = @import("tri_commands.zig");
const pipeline = @import("tri_pipeline.zig");
const demos = @import("tri_demos.zig");
const math_commands = @import("math/commands.zig");
const bio_commands = @import("tri_biology.zig");
const cosmos_commands = @import("tri_cosmology.zig");
const neuro_commands = @import("tri_neuro.zig");
const chemistry_commands = @import("tri_chemistry.zig");
const tri_context = @import("tri_context.zig");
const orchestrator = @import("orchestrator_v2_full.zig");
const tri_job = @import("tri_job.zig");
const tri_register = @import("tri_register.zig");
const sacred_fpga = @import("tri_sacred_fpga.zig");
// P2.9: Namespace-aware command parsing
const tri_namespace = @import("tri_namespace.zig");
const tri_mcp = @import("tri_mcp.zig");
const tri_list = @import("tri_cmd_list.zig");
// P2.10: Observability layer
const observability = @import("observability.zig");
const structured_log = @import("structured_log.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    // Use page_allocator to avoid leak-check spam from GGUF reader metadata strings
    const allocator = std.heap.page_allocator;

    // P2.10: Initialize structured logging
    try structured_log.initGlobalLogger(allocator, .info);
    defer structured_log.deinitGlobalLogger();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var state = try utils.CLIState.init(allocator);
    defer state.deinit();

    // No arguments = interactive mode
    if (args.len < 2) {
        try utils.runInteractiveMode(&state);
        return;
    }

    // Parse global flags (before command)
    var arg_idx: usize = 1;
    // P0.3: Track if we're running in job context (spawned by job system)
    var is_internal_job_exec = false;
    while (arg_idx < args.len) : (arg_idx += 1) {
        const arg = args[arg_idx];

        // Stop at first non-flag argument (the command)
        if (arg[0] != '-') break;

        // Global flags
        if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
            state.verbose = true;
        } else if (std.mem.eql(u8, arg, "--dry-run")) {
            state.dry_run = true;
            std.debug.print("{s}DRY RUN MODE: No actual changes will be made{s}\n", .{ "\x1b[38;2;255;215;0m", "\x1b[0m" });
        } else if (std.mem.eql(u8, arg, "--yes") or std.mem.eql(u8, arg, "-y")) {
            state.yes = true;
        } else if (std.mem.eql(u8, arg, "--json")) {
            // P0.2: Convenience flag for JSON output
            state.output_format = .json;
            tri_config.setJsonOutput(true);
        } else if (std.mem.eql(u8, arg, "--output")) {
            if (arg_idx + 1 < args.len) {
                const fmt = args[arg_idx + 1];
                if (std.mem.eql(u8, fmt, "json")) {
                    state.output_format = .json;
                    tri_config.setJsonOutput(true); // P0.2: Set global JSON mode
                } else if (std.mem.eql(u8, fmt, "yaml")) {
                    state.output_format = .yaml;
                } else {
                    state.output_format = .text;
                }
                arg_idx += 1; // Skip the format argument
            }
        } else if (std.mem.eql(u8, arg, "--_internal-job-exec")) {
            // P0.3: Internal flag - running in job context, don't spawn another job
            is_internal_job_exec = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            // Global help - show all commands
            utils.printHelp();
            return;
        } else if (arg[0] == '-') {
            // Unknown flag, might be command-specific - pass through
            break;
        }
    }

    // Check if we have a command after flags
    if (arg_idx >= args.len) {
        // No command after flags
        try utils.runInteractiveMode(&state);
        return;
    }

    // Special handling for "test --repl" command (Cycle 100/101)
    if (arg_idx < args.len and std.mem.eql(u8, args[arg_idx], "test")) {
        const flag = if (arg_idx + 1 < args.len) args[arg_idx + 1] else "";
        // Handle all test-related flags
        if (std.mem.eql(u8, flag, "--repl") or
            std.mem.eql(u8, flag, "-r") or
            std.mem.eql(u8, flag, "--generate") or
            std.mem.eql(u8, flag, "-g") or
            std.mem.eql(u8, flag, "--coverage") or
            std.mem.eql(u8, flag, "--full") or
            std.mem.eql(u8, flag, "-f") or
            std.mem.eql(u8, flag, "--category") or
            std.mem.eql(u8, flag, "-c") or
            std.mem.eql(u8, flag, "--verbose") or
            std.mem.eql(u8, flag, "-v") or
            std.mem.eql(u8, flag, "--help") or
            std.mem.eql(u8, flag, "-h"))
        {
            // Include the flag in cmd_args so runReplTestCommand can process it
            const cmd_args = if (arg_idx + 1 < args.len) args[arg_idx + 1 ..] else &[_][]const u8{};
            try commands.runReplTestCommand(allocator, cmd_args);
            return;
        }
    }

    // P0.3: Special handling for "job <subcommand>" commands
    if (arg_idx < args.len and std.mem.eql(u8, args[arg_idx], "job")) {
        const subcommand = if (arg_idx + 1 < args.len) args[arg_idx + 1] else "";
        const job_cmd: utils.Command = if (std.mem.eql(u8, subcommand, "start"))
            .job_start
        else if (std.mem.eql(u8, subcommand, "status"))
            .job_status
        else if (std.mem.eql(u8, subcommand, "logs"))
            .job_logs
        else if (std.mem.eql(u8, subcommand, "artifacts"))
            .job_artifacts
        else if (std.mem.eql(u8, subcommand, "cancel"))
            .job_cancel
        else if (std.mem.eql(u8, subcommand, "list"))
            .job_list
        else if (subcommand.len == 0)
            .job_start // "job" alone defaults to job_start
        else
            .job_start; // Default for unknown subcommand

        const cmd_args = if (arg_idx + 2 < args.len) args[arg_idx + 2 ..] else &[_][]const u8{};

        switch (job_cmd) {
            .job_start => try tri_job.runJobStart(allocator, cmd_args),
            .job_status => try tri_job.runJobStatus(allocator, cmd_args),
            .job_logs => try tri_job.runJobLogs(allocator, cmd_args),
            .job_artifacts => try tri_job.runJobArtifacts(allocator, cmd_args),
            .job_cancel => try tri_job.runJobCancel(allocator, cmd_args),
            .job_list => try tri_job.runJobList(allocator, cmd_args),
            else => unreachable,
        }
        return;
    }

    // P2.9: Namespace-aware command dispatch
    // Check for `tri <namespace> <command>` syntax
    const remaining_args = if (arg_idx < args.len) args[arg_idx..] else &[_][]const u8{};
    const parsed = tri_namespace.parseCommand(remaining_args);

    switch (parsed) {
        .help => {
            utils.printHelp();
            return;
        },
        .namespaced => |ns_cmd| {
            // Namespace-based invocation: `tri dev bench`
            const ns = ns_cmd.namespace;
            const cmd_name = ns_cmd.command;

            // Handle empty command as namespace help
            if (cmd_name.len == 0) {
                try printNamespaceHelp(allocator, ns);
                return;
            }

            // Check for help within namespace
            if (std.mem.eql(u8, cmd_name, "help") or
                std.mem.eql(u8, cmd_name, "--help") or
                std.mem.eql(u8, cmd_name, "-h")) {
                try printNamespaceHelp(allocator, ns);
                return;
            }

            // Namespace-specific command dispatch
            const ns_cmd_args = if (arg_idx + 2 < args.len) args[arg_idx + 2 ..] else &[_][]const u8{};

            try dispatchNamespacedCommand(allocator, &state, ns, cmd_name, ns_cmd_args, is_internal_job_exec);
            return;
        },
        .flat => {
            // Fall through to existing flat dispatch (backward compatible)
        },
    }

    const cmd = utils.parseCommand(args[arg_idx]);
    const cmd_args = if (arg_idx + 1 < args.len) args[arg_idx + 1 ..] else &[_][]const u8{};

    // Handle --help after command (except for serve, which has its own help)
    if (cmd_args.len > 0 and (std.mem.eql(u8, cmd_args[0], "--help") or std.mem.eql(u8, cmd_args[0], "-h"))) {
        // serve command handles its own help via full-serve-v1 module
        if (cmd == .serve) {
            // Fall through to runServeCommand with --help flag
        } else {
            utils.printCommandHelp(cmd);
            return;
        }
    }

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
        .bench => if (is_internal_job_exec)
            try commands.runBenchCommandInternal(allocator)
        else
            try commands.runBenchCommandAsync(allocator, cmd_args),
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
        // Biology (v14.0)
        .bio => bio_commands.runBioCommand(allocator, cmd_args) catch |err| {
            std.debug.print("Bio error: {}\n", .{err});
        },
        // Cosmology (v15.0)
        .cosmos => cosmos_commands.runCosmosCommand(allocator, cmd_args) catch |err| {
            std.debug.print("Cosmos error: {}\n", .{err});
        },
        // Neuroscience (v16.0)
        .neuro => neuro_commands.runNeuroCommand(allocator, cmd_args) catch |err| {
            std.debug.print("Neuro error: {}\n", .{err});
        },
        // Chemistry (v6.0) - TODO: complete element data (missing optional fields)
        .chem => chemistry_commands.runChemCommand(allocator, cmd_args) catch |err| {
            std.debug.print("Chem error: {}\n", .{err});
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
        .identity => {
            std.debug.print("Identity command - TODO: Implement\n", .{});
        },
        .swarm => {
            std.debug.print("Swarm command - TODO: Implement\n", .{});
        },
        .govern => {
            std.debug.print("Govern command - TODO: Implement\n", .{});
        },
        .dashboard => {
            std.debug.print("Dashboard command - TODO: Implement\n", .{});
        },
        .omega => {
            std.debug.print("Omega command - TODO: Implement\n", .{});
        },
        .math_agent => {
            std.debug.print("Math agent command - TODO: Implement\n", .{});
        },
        // Codebase Context (Cycle 92)
        .analyze => tri_context.runAnalyzeCommand(&state),
        .search_cmd => tri_context.runSearchCommand(&state, cmd_args),
        .context_info => tri_context.runContextInfoCommand(&state),
        // Temporal Engine v1.2-v1.3 (Orders #030-031)
        .time => commands.runTimeCommand(allocator, cmd_args),
        .install => commands.runInstallCommand(allocator),
        .build_cmd => commands.runBuildCommand(allocator),
        .deck_generate => commands.runDeckCommand(allocator),
        .fpga_demo => commands.runFpgaDemoCommand(allocator, cmd_args),
        .fpga => try tri_register.runFpgaCommand(allocator, cmd_args),
        .sacred_const => try sacred_fpga.runSacredConstCommand(allocator, cmd_args),
        .sacred_full_cycle => commands.runSacredFullCycleCommand(allocator),
        // Quantum Trinity v1.4 (Order #032)
        .quantum => commands.runQuantumCommand(allocator, cmd_args),
        .release_cosmic => commands.runReleaseCosmicCommand(allocator),
        // Omega Phase v2.0 (Order #033)
        .omega_cmd => commands.runOmegaPhaseCommand(allocator, cmd_args),
        .all_cmd => commands.runAllCommand(allocator, cmd_args),
        .holo_cmd => commands.runHoloCommand(allocator, cmd_args),
        .release_absolute => commands.runReleaseAbsoluteCommand(allocator),
        .omega_evolve => commands.runOmegaEvolveCommand(allocator),
        // TRINITY OS v1.0 (Order #034)
        .launch => commands.runLaunchCommand(allocator, cmd_args),
        // NEEDLE - Structural Editor Core
        // P0.3: Job Runtime (Async Long-Running Commands) - handled before general switch
        .job_start => try tri_job.runJobStart(allocator, cmd_args),
        .job_status => try tri_job.runJobStatus(allocator, cmd_args),
        .job_logs => try tri_job.runJobLogs(allocator, cmd_args),
        .job_artifacts => try tri_job.runJobArtifacts(allocator, cmd_args),
        .job_cancel => try tri_job.runJobCancel(allocator, cmd_args),
        .job_list => try tri_job.runJobList(allocator, cmd_args),
        .needle => try commands.runNeedleCommand(allocator, cmd_args),
        .needle_search => try commands.runNeedleSearchCommand(allocator, cmd_args),
        .needle_check => try commands.runNeedleCheckCommand(allocator, cmd_args),
        .deps => utils.printInfo(),
        .info => utils.printInfo(),
        .version => utils.printVersion(),
        .help => utils.printHelp(),
        // P1.6: CLI Tools
        .commands => try tri_register.runCommand(allocator, "commands", cmd_args),
        .mcp => try tri_register.runCommand(allocator, "mcp", cmd_args),
        // .monitor => {  // TODO: Add monitor to Command enum in tri_utils.zig
        //     const eternal_monitor = @import("eternal_monitor.zig");
        //     const exit_code = try eternal_monitor.execute(allocator, cmd_args);
        //     std.process.exit(exit_code);
        // },
        // .orchestrate_v2 => {  // TODO: Add orchestrate_v2 to Command enum in tri_utils.zig
        //     // TRI Orchestrator v2.0 - Universal command orchestration
        //     if (cmd_args.len == 0) {
        //         // Show registry statistics
        //         var registry = orchestrator.registerAllCommands(allocator) catch |err| {
        //             std.debug.print("Failed to initialize registry: {}\n", .{err});
        //             std.process.exit(1);
        //         };
        //         defer registry.deinit();
        //
        //         const CYAN = "\x1b[36m";
        //         const GREEN = "\x1b[32m";
        //         const RESET = "\x1b[0m";
        //         std.debug.print("\n{s}╔══════════════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
        //         std.debug.print("{s}║  TRINITY ORCHESTRATOR v2.0 — {d} Commands Registered        ║{s}\n", .{ CYAN, registry.total_count, RESET });
        //         std.debug.print("{s}╚══════════════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });
        //         std.debug.print("{s}Usage:{s}\n", .{ GREEN, RESET });
        //         std.debug.print("  tri orchestrate_v2 <workflow.yaml>  Execute workflow file\n", .{});
        //         std.debug.print("  tri orchestrate_v2 <cmd> [args...]   Execute command via registry\n\n", .{});
        //         std.debug.print("{s}Strategies:{s}\n", .{ GREEN, RESET });
        //         std.debug.print("  sequential  - Execute in dependency order (default)\n", .{});
        //         std.debug.print("  parallel    - Execute independent commands concurrently\n", .{});
        //         std.debug.print("  conditional - If/then/else branching\n", .{});
        //         std.debug.print("  adaptive    - Auto-select based on analysis\n", .{});
        //
        //         registry.printStats();
        //     } else {
        //         // Execute command via registry
        //         const cmd_name = cmd_args[0];
        //         var exec_args_copy = try std.ArrayList([]const u8).initCapacity(allocator, 16);
        //         defer exec_args_copy.deinit(allocator);
        //         if (cmd_args.len > 1) {
        //             for (cmd_args[1..]) |arg| {
        //                 try exec_args_copy.append(allocator, arg);
        //             }
        //         }
        //         const cmd_exec_args = exec_args_copy.items;
        //
        //         var registry = orchestrator.registerAllCommands(allocator) catch |err| {
        //             std.debug.print("Failed to initialize registry: {}\n", .{err});
        //             std.process.exit(1);
        //         };
        //         defer registry.deinit();
        //
        //         const cmd_metadata = registry.getCommand(cmd_name) orelse {
        //             std.debug.print("Error: Command '{s}' not found in registry\n", .{cmd_name});
        //             std.debug.print("Total commands registered: {d}\n", .{registry.total_count});
        //             std.process.exit(1);
        //         };
        //
        //         std.debug.print("Executing: {s} (category: {s}, realm: {s})\n", .{
        //             cmd_metadata.name,
        //             @tagName(cmd_metadata.category),
        //             @tagName(cmd_metadata.realm),
        //         });
        //
        //         const result = try cmd_metadata.executor(allocator, cmd_exec_args);
        //         std.debug.print("Success: {}, Steps: {d}/{d}, Duration: {d}ms, Sacred Score: {d:.4}\n", .{
        //             result.success,
        //             result.steps_completed,
        //             result.steps_total,
        //             result.duration_ms,
        //             result.sacred_score,
        //         });
        //         if (result.output.len > 0) {
        //             std.debug.print("Output: {s}\n", .{result.output});
        //         }
        //         if (result.@"error") |err_msg| {
        //             std.debug.print("Error: {s}\n", .{err_msg});
        //         }
        //     }
        // },
        // Temporal Trinity v1.0 (Order #020, #021) — ACTIVE
        // Note: Simplified .time handler at line 288 takes precedence
        // .time => {
        //     if (cmd_args.len == 0) {
        //         std.debug.print("Usage: tri time <subcommand>\n", .{});
        //         std.debug.print("Subcommands:\n", .{});
        //         std.debug.print("  sacred    - Display TEMPORAL TRINITY THEOREM\n", .{});
        //         std.debug.print("  balance   - Show φ² + 1/φ² = 3\n", .{});
        //         std.debug.print("  arrow     - Show time arrow φ⁴\n", .{});
        //         std.debug.print("  planck    - Show Planck time\n", .{});
        //         std.debug.print("  eternal   - Show eternal return π×3\n", .{});
        //     } else {
        //         const sacred = @import("sacred");
        //         if (std.mem.eql(u8, cmd_args[0], "sacred")) {
        //             _ = try sacred.displayTemporalTheorem(allocator);
        //         } else if (std.mem.eql(u8, cmd_args[0], "balance")) {
        //             const balance = sacred.calculateTemporalBalance();
        //             std.debug.print("Temporal Balance (φ² + 1/φ²): {d:.6}\n", .{balance});
        //         } else if (std.mem.eql(u8, cmd_args[0], "arrow")) {
        //             std.debug.print("Time Arrow Ratio (φ⁴): {d:.6}\n", .{sacred.computeTimeArrow()});
        //         } else if (std.mem.eql(u8, cmd_args[0], "planck")) {
        //             std.debug.print("Planck Time: {d:.6} × 10⁻⁴⁴ s\n", .{sacred.computePlanckTime() * 1e44});
        //         } else if (std.mem.eql(u8, cmd_args[0], "eternal")) {
        //             std.debug.print("Eternal Return (π × 3): {d:.9}\n", .{sacred.eternalReturn()});
        //         } else {
        //             std.debug.print("Unknown subcommand: {s}\n", .{cmd_args[0]});
        //         }
        //     }
        // },
        // .os_boot => {  // TODO: Add os_boot to Command enum in tri_utils.zig
        //     const os_mod = @import("os");
        //
        //     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        //     defer _ = gpa.deinit();
        //     const boot_allocator = gpa.allocator();
        //
        //     var os_instance = try os_mod.TrinityOS.init(boot_allocator);
        //     defer os_instance.deinit();
        //
        //     // Parse boot mode - handle both "tri boot --temporal" and "tri os boot --temporal"
        //     const mode: os_mod.BootMode = blk: {
        //         // Check all arguments for mode flags
        //         for (cmd_args) |arg| {
        //             if (std.mem.eql(u8, arg, "--temporal")) break :blk .temporal;
        //             if (std.mem.eql(u8, arg, "--god") or std.mem.eql(u8, arg, "-g")) break :blk .god;
        //             if (std.mem.eql(u8, arg, "--quantum") or std.mem.eql(u8, arg, "-q")) break :blk .quantum;
        //             if (std.mem.eql(u8, arg, "--normal") or std.mem.eql(u8, arg, "-n")) break :blk .normal;
        //             if (std.mem.eql(u8, arg, "--infinity") or std.mem.eql(u8, arg, "-i")) break :blk .infinity;
        //             if (std.mem.eql(u8, arg, "--omega") or std.mem.eql(u8, arg, "-o")) break :blk .omega;
        //         }
        //         break :blk .temporal; // Order #022: Default to TEMPORAL TRINITY mode
        //     };
        //
        //     try os_instance.boot(mode);
        // },
        // ABSOLUTE INFINITY v2.0 (Order #024) - TODO: Add infinity to Command enum
        // .infinity => {
        //     const sacred = @import("sacred");
        //     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        //     defer _ = gpa.deinit();
        //     const gpa_allocator = gpa.allocator();
        //
        //     if (cmd_args.len == 0) {
        //         std.debug.print("Usage: tri infinity <subcommand>\n", .{});
        //         std.debug.print("Subcommands:\n", .{});
        //         std.debug.print("  status   - Show ABSOLUTE INFINITY status\n", .{});
        //         std.debug.print("  boot     - Boot ABSOLUTE INFINITY system\n", .{});
        //         std.debug.print("  manifest - Display ABSOLUTE INFINITY manifesto\n", .{});
        //     } else if (std.mem.eql(u8, cmd_args[0], "status")) {
        //         var infinity = try sacred.AbsoluteInfinity.init(gpa_allocator);
        //         defer infinity.deinit();
        //         try infinity.awaken();
        //         try infinity.getStatus();
        //     } else if (std.mem.eql(u8, cmd_args[0], "boot")) {
        //         try sacred.bootAbsoluteInfinity(gpa_allocator);
        //     } else if (std.mem.eql(u8, cmd_args[0], "manifest")) {
        //         sacred.displayInfinityManifesto();
        //     } else {
        //         std.debug.print("Unknown subcommand: {s}\n", .{cmd_args[0]});
        //     }
        // },
        // OMEGA PHASE (Order #024) - TODO: Add omega_phase to Command enum
        // .omega_phase => {
        //     const sacred = @import("sacred");
        //     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        //     defer _ = gpa.deinit();
        //     const gpa_allocator = gpa.allocator();
        //
        //     if (cmd_args.len == 0) {
        //         std.debug.print("Usage: tri omega-phase <subcommand>\n", .{});
        //         std.debug.print("Subcommands:\n", .{});
        //         std.debug.print("  awaken   - Initiate OMEGA PHASE awakening\n", .{});
        //         std.debug.print("  status   - Show OMEGA status\n", .{});
        //         std.debug.print("  evolve   - Run infinite evolution loop\n", .{});
        //         std.debug.print("  manifest - Display OMEGA manifesto\n", .{});
        //     } else if (std.mem.eql(u8, cmd_args[0], "awaken")) {
        //         try sacred.bootOmega(gpa_allocator);
        //     } else if (std.mem.eql(u8, cmd_args[0], "status")) {
        //         var engine = sacred.OmegaEngine.init(gpa_allocator);
        //         defer engine.deinit();
        //         try engine.awakenOmega();
        //         try engine.getStatus();
        //     } else if (std.mem.eql(u8, cmd_args[0], "evolve")) {
        //         var engine = sacred.OmegaEngine.init(gpa_allocator);
        //         defer engine.deinit();
        //         try engine.awakenOmega();
        //         try engine.evolve();
        //     } else if (std.mem.eql(u8, cmd_args[0], "manifest")) {
        //         sacred.displayOmegaManifesto();
        //     } else {
        //         std.debug.print("Unknown subcommand: {s}\n", .{cmd_args[0]});
        //     }
        // },
    }
}

// =============================================================================
// P2.9: Namespace-Aware Command Dispatch
// =============================================================================

/// Print help for a specific namespace
fn printNamespaceHelp(allocator: std.mem.Allocator, ns: tri_namespace.Namespace) !void {
    const ns_str = ns.toString();
    const desc = tri_namespace.namespaceDescription(ns);

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ "\x1b[38;2;255;215;0m", "\x1b[0m" });
    std.debug.print("{s}TRI {s} - {s}{s}\n", .{ "\x1b[38;2;0;229;153m", ns_str, desc, "\x1b[0m" });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n\n", .{ "\x1b[38;2;255;215;0m", "\x1b[0m" });

    std.debug.print("{s}Usage:{s} tri {s} <command>\n\n", .{ "\x1b[38;2;0;255;255m", "\x1b[0m", ns_str });

    std.debug.print("{s}Available commands:{s}\n", .{ "\x1b[38;2;0;255;255m", "\x1b[0m" });

    // Show example commands for this namespace
    const examples = try tri_namespace.namespaceExamples(allocator, ns);
    defer {
        for (examples) |ex| allocator.free(ex);
        allocator.free(examples);
    }

    for (examples) |ex| {
        std.debug.print("  {s}{s}{s}\n", .{ "\x1b[38;2;0;229;153m", ex, "\x1b[0m" });
    }

    std.debug.print("\n{s}Note:{s} Many commands work without the namespace prefix too.\n", .{ "\x1b[38;2;0;255;255m", "\x1b[0m" });
    std.debug.print("  Example: {s}tri bench{s} is equivalent to {s}tri dev bench{s}\n\n", .{ "\x1b[38;2;0;229;153m", "\x1b[0m", "\x1b[38;2;0;229;153m", "\x1b[0m" });
}

// =============================================================================
// P2.10: Observability Layer
// =============================================================================

/// Execute command with full observability tracking
fn executeWithObservability(
    allocator: std.mem.Allocator,
    command: []const u8,
    args: []const []const u8,
    comptime handlerFn: anytype,
    handlerArgs: anytype,
) !observability.ExitCode {
    // Create operation context
    var ctx = try observability.OperationContext.init(allocator, command, args);
    defer ctx.deinit();

    // Log command start
    if (structured_log.getGlobalLogger()) |logger| {
        try logger.withContext(.info, "Command started", .{
            .command = command,
            .args_len = args.len,
            .request_id = ctx.request_id.str(),
        });
    }

    // Execute command
    const result = handlerFn(handlerArgs);

    // Complete context
    const exit_code = if (result) |_| observability.ExitCode.success else |err| exitCodeFromError(err);
    try ctx.complete(exit_code);

    // Log result
    if (structured_log.getGlobalLogger()) |logger| {
        try logger.withContext(.info, "Command completed", .{
            .command = command,
            .duration_ms = ctx.duration.elapsedMs(),
            .exit_code = exit_code.toInt(),
            .request_id = ctx.request_id.str(),
        });
    }

    // Print summary for long-running commands
    if (ctx.duration.elapsedMs() > 1000) {
        std.debug.print("\n{s}Completed in {d:.1}s (request_id: {s}){s}\n", .{
            "\x1b[38;2;156;156;160m",
            ctx.duration.elapsedSeconds(),
            ctx.request_id.str(),
            "\x1b[0m",
        });
    }

    return exit_code;
}

/// Convert Zig error to ExitCode
fn exitCodeFromError(err: anyerror) observability.ExitCode {
    return switch (err) {
        error.FileNotFound => .no_input,
        error.AccessDenied => .no_perm,
        error.OutOfMemory => .os_err,
        error.InvalidArgument => .usage,
        error.NotOpen => .io_error,
        error.PipeFail => .io_error,
        else => .err, // ExitCode.err = 1
    };
}

/// Dispatch a namespace-based command
fn dispatchNamespacedCommand(
    allocator: std.mem.Allocator,
    state: *utils.CLIState,
    ns: tri_namespace.Namespace,
    cmd_name: []const u8,
    cmd_args: []const []const u8,
    is_internal_job_exec: bool,
) !void {
    // Map namespace+command to the appropriate handler
    // This maintains backward compatibility while enabling namespace syntax

    // For now, delegate to the existing flat command parsing
    // The namespace-aware routing will be expanded as commands are migrated

    // Convert namespace+command back to flat command for dispatch
    // This allows gradual migration - new commands can be namespace-only

    // DEV namespace commands
    if (ns == .dev) {
        if (std.mem.eql(u8, cmd_name, "test") or std.mem.eql(u8, cmd_name, "bench") or
            std.mem.eql(u8, cmd_name, "build") or std.mem.eql(u8, cmd_name, "fmt") or
            std.mem.eql(u8, cmd_name, "gen")) {
            // Dispatch to existing command handlers
            const cmd = utils.parseCommand(cmd_name);
            return dispatchCommand(allocator, state, cmd, cmd_args, is_internal_job_exec);
        }
    }

    // MCP namespace commands
    if (ns == .mcp) {
        if (std.mem.eql(u8, cmd_name, "export")) {
            // Build args: "export" + cmd_args
            var all_args = try std.ArrayList([]const u8).initCapacity(allocator, cmd_args.len + 1);
            defer all_args.deinit(allocator);
            try all_args.append(allocator, "export");
            try all_args.appendSlice(allocator, cmd_args);
            try tri_mcp.runMcpCommand(allocator, all_args.items);
            return;
        }
        if (std.mem.eql(u8, cmd_name, "doctor")) {
            const doctor_args = &[_][]const u8{"doctor"};
            try tri_mcp.runMcpCommand(allocator, doctor_args);
            return;
        }
        if (std.mem.eql(u8, cmd_name, "tools")) {
            const tools_args = &[_][]const u8{"tools"};
            try tri_mcp.runMcpCommand(allocator, tools_args);
            return;
        }
        // Pass through to mcp command handler
        try tri_mcp.runMcpCommand(allocator, cmd_args);
        return;
    }

    // SYSTEM namespace commands
    if (ns == .system) {
        if (std.mem.eql(u8, cmd_name, "doctor")) {
            try commands.runDoctorCommand(allocator);
            return;
        }
        if (std.mem.eql(u8, cmd_name, "clean")) {
            try commands.runCleanCommand(allocator);
            return;
        }
        if (std.mem.eql(u8, cmd_name, "info")) {
            try commands.runInfoCommand(allocator);
            return;
        }
    }

    // FORGE namespace commands - fall through to flat dispatch
    // (fpga commands handled by existing Command enum)

    // Fall back to flat command parsing for backward compatibility
    const cmd = utils.parseCommand(cmd_name);
    if (cmd == .none) {
        std.debug.print("{s}Unknown command: tri {s} {s}{s}\n", .{ "\x1b[38;2;255;100m", ns.toString(), cmd_name, "\x1b[0m" });
        std.debug.print("Use {s}tri help{s} or {s}tri {s} help{s} for available commands.\n", .{ "\x1b[38;2;0;229;153m", "\x1b[0m", "\x1b[38;2;0;229;153m", ns.toString(), "\x1b[0m" });
        return;
    }

    try dispatchCommand(allocator, state, cmd, cmd_args, is_internal_job_exec);
}

/// Helper to dispatch a Command enum to its handler
fn dispatchCommand(
    allocator: std.mem.Allocator,
    state: *utils.CLIState,
    cmd: utils.Command,
    cmd_args: []const []const u8,
    is_internal_job_exec: bool,
) !void {
    return switch (cmd) {
        .chat => utils.runChatCommand(state, cmd_args),
        .code => utils.runCodeCommand(state, cmd_args),
        .gen => commands.runGenCommand(allocator, cmd_args),
        .convert => commands.runConvertCommand(cmd_args),
        .serve => commands.runServeCommand(allocator, cmd_args),
        .bench => if (is_internal_job_exec)
            commands.runBenchCommandInternal(allocator)
        else
            commands.runBenchCommandAsync(allocator, cmd_args),
        .commit => commands.runGitCommand(allocator, "commit", cmd_args),
        .diff => commands.runGitCommand(allocator, "diff", cmd_args),
        .status => commands.runGitCommand(allocator, "status", cmd_args),
        .log => commands.runGitCommand(allocator, "log", cmd_args),
        .pipeline => pipeline.runPipelineCommand(allocator, cmd_args),
        .decompose => pipeline.runDecomposeCommand(allocator, cmd_args),
        .plan => pipeline.runPlanCommand(allocator, cmd_args),
        .verify => pipeline.runVerifyCommand(allocator),
        .verdict => pipeline.runVerdictCommand(allocator),
        .doctor => commands.runDoctorCommand(allocator),
        .commands => tri_list.runCommandsList(allocator, cmd_args),
        .mcp => tri_mcp.runMcpCommand(allocator, cmd_args),
        // Sacred Mathematics (core namespace)
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
        // Science commands (core namespace)
        .bio => bio_commands.runBioCommand(allocator, cmd_args) catch |err| {
            std.debug.print("Bio error: {}\n", .{err});
        },
        .cosmos => cosmos_commands.runCosmosCommand(allocator, cmd_args) catch |err| {
            std.debug.print("Cosmos error: {}\n", .{err});
        },
        .neuro => neuro_commands.runNeuroCommand(allocator, cmd_args) catch |err| {
            std.debug.print("Neuro error: {}\n", .{err});
        },
        .chem => chemistry_commands.runChemCommand(allocator, cmd_args) catch |err| {
            std.debug.print("Chem error: {}\n", .{err});
        },
        // SWE Agent commands (agent namespace)
        .fix => utils.runSWECommand(state, .BugFix, cmd_args),
        .explain => utils.runSWECommand(state, .Explain, cmd_args),
        .test_cmd => utils.runSWECommand(state, .Test, cmd_args),
        .doc => utils.runSWECommand(state, .Document, cmd_args),
        .refactor => utils.runSWECommand(state, .Refactor, cmd_args),
        .reason => utils.runSWECommand(state, .Reason, cmd_args),
        // FPGA commands (forge namespace)
        .fpga => try tri_register.runFpgaCommand(allocator, cmd_args),
        .sacred_const => try sacred_fpga.runSacredConstCommand(allocator, cmd_args),
        else => |c| {
            std.debug.print("{s}Command not yet accessible via namespace: {s}{s}\n", .{ "\x1b[38;2;255;100m", @tagName(c), "\x1b[0m" });
            std.debug.print("Use the flat command name for now (e.g., {s}tri {s}{s} instead of {s}tri <namespace> {s}{s})\n", .{ "\x1b[38;2;0;229;153m", @tagName(c), "\x1b[0m", "\x1b[38;2;0;229;153m", @tagName(c), "\x1b[0m" });
        },
    };
}
