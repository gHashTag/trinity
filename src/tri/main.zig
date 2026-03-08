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
const chemistry_commands = @import("tri_chemistry.zig");
const geometry_commands = @import("geometry/commands.zig");
const tri_context = @import("tri_context.zig");
const orchestrator = @import("orchestrator_v2_full.zig");

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

    // Special handling for "test --repl" command (Cycle 100/101)
    if (args.len >= 3 and std.mem.eql(u8, args[1], "test")) {
        const flag = args[2];
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
            const cmd_args = if (args.len > 3) args[2..] else &[_][]const u8{args[2]};
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
        .chem => chemistry_commands.runChemCommand(allocator, cmd_args) catch |err| {
            std.debug.print("Chemistry error: {}\n", .{err});
        },
        // Sacred Geometry (v1.0)
        .geom => {
            geometry_commands.runGeometryCommand(allocator, cmd_args) catch |err| {
                std.debug.print("Geometry error: {}\n", .{err});
            };
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
        .monitor => {
            const eternal_monitor = @import("eternal_monitor.zig");
            const exit_code = try eternal_monitor.execute(allocator, cmd_args);
            std.process.exit(exit_code);
        },
        .orchestrate_v2 => {
            // TRI Orchestrator v2.0 - Universal command orchestration
            if (cmd_args.len == 0) {
                // Show registry statistics
                var registry = orchestrator.registerAllCommands(allocator) catch |err| {
                    std.debug.print("Failed to initialize registry: {}\n", .{err});
                    std.process.exit(1);
                };
                defer registry.deinit();

                const CYAN = "\x1b[36m";
                const GREEN = "\x1b[32m";
                const RESET = "\x1b[0m";
                std.debug.print("\n{s}╔══════════════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
                std.debug.print("{s}║  TRINITY ORCHESTRATOR v2.0 — {d} Commands Registered        ║{s}\n", .{ CYAN, registry.total_count, RESET });
                std.debug.print("{s}╚══════════════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });
                std.debug.print("{s}Usage:{s}\n", .{ GREEN, RESET });
                std.debug.print("  tri orchestrate_v2 <workflow.yaml>  Execute workflow file\n", .{});
                std.debug.print("  tri orchestrate_v2 <cmd> [args...]   Execute command via registry\n\n", .{});
                std.debug.print("{s}Strategies:{s}\n", .{ GREEN, RESET });
                std.debug.print("  sequential  - Execute in dependency order (default)\n", .{});
                std.debug.print("  parallel    - Execute independent commands concurrently\n", .{});
                std.debug.print("  conditional - If/then/else branching\n", .{});
                std.debug.print("  adaptive    - Auto-select based on analysis\n", .{});

                registry.printStats();
            } else {
                // Execute command via registry
                const cmd_name = cmd_args[0];
                var exec_args_copy = try std.ArrayList([]const u8).initCapacity(allocator, 16);
                defer exec_args_copy.deinit(allocator);
                if (cmd_args.len > 1) {
                    for (cmd_args[1..]) |arg| {
                        try exec_args_copy.append(allocator, arg);
                    }
                }
                const cmd_exec_args = exec_args_copy.items;

                var registry = orchestrator.registerAllCommands(allocator) catch |err| {
                    std.debug.print("Failed to initialize registry: {}\n", .{err});
                    std.process.exit(1);
                };
                defer registry.deinit();

                const cmd_metadata = registry.getCommand(cmd_name) orelse {
                    std.debug.print("Error: Command '{s}' not found in registry\n", .{cmd_name});
                    std.debug.print("Total commands registered: {d}\n", .{registry.total_count});
                    std.process.exit(1);
                };

                std.debug.print("Executing: {s} (category: {s}, realm: {s})\n", .{
                    cmd_metadata.name,
                    @tagName(cmd_metadata.category),
                    @tagName(cmd_metadata.realm),
                });

                const result = try cmd_metadata.executor(allocator, cmd_exec_args);
                std.debug.print("Success: {}, Steps: {d}/{d}, Duration: {d}ms, Sacred Score: {d:.4}\n", .{
                    result.success,
                    result.steps_completed,
                    result.steps_total,
                    result.duration_ms,
                    result.sacred_score,
                });
                if (result.output.len > 0) {
                    std.debug.print("Output: {s}\n", .{result.output});
                }
                if (result.@"error") |err_msg| {
                    std.debug.print("Error: {s}\n", .{err_msg});
                }
            }
        },
        // Temporal Trinity v1.0 (Order #020, #021) — ACTIVE
        .time => {
            if (cmd_args.len == 0) {
                std.debug.print("Usage: tri time <subcommand>\n", .{});
                std.debug.print("Subcommands:\n", .{});
                std.debug.print("  sacred    - Display TEMPORAL TRINITY THEOREM\n", .{});
                std.debug.print("  balance   - Show φ² + 1/φ² = 3\n", .{});
                std.debug.print("  arrow     - Show time arrow φ⁴\n", .{});
                std.debug.print("  planck    - Show Planck time\n", .{});
                std.debug.print("  eternal   - Show eternal return π×3\n", .{});
            } else {
                const sacred = @import("sacred");
                if (std.mem.eql(u8, cmd_args[0], "sacred")) {
                    _ = try sacred.displayTemporalTheorem(allocator);
                } else if (std.mem.eql(u8, cmd_args[0], "balance")) {
                    const balance = sacred.calculateTemporalBalance();
                    std.debug.print("Temporal Balance (φ² + 1/φ²): {d:.6}\n", .{balance});
                } else if (std.mem.eql(u8, cmd_args[0], "arrow")) {
                    std.debug.print("Time Arrow Ratio (φ⁴): {d:.6}\n", .{sacred.computeTimeArrow()});
                } else if (std.mem.eql(u8, cmd_args[0], "planck")) {
                    std.debug.print("Planck Time: {d:.6} × 10⁻⁴⁴ s\n", .{sacred.computePlanckTime() * 1e44});
                } else if (std.mem.eql(u8, cmd_args[0], "eternal")) {
                    std.debug.print("Eternal Return (π × 3): {d:.9}\n", .{sacred.eternalReturn()});
                } else {
                    std.debug.print("Unknown subcommand: {s}\n", .{cmd_args[0]});
                }
            }
        },
        .os_boot => {
            const os_mod = @import("os");

            var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            defer _ = gpa.deinit();
            const boot_allocator = gpa.allocator();

            var os_instance = try os_mod.TrinityOS.init(boot_allocator);
            defer os_instance.deinit();

            // Parse boot mode - handle both "tri boot --temporal" and "tri os boot --temporal"
            const mode: os_mod.BootMode = blk: {
                // Check all arguments for mode flags
                for (cmd_args) |arg| {
                    if (std.mem.eql(u8, arg, "--temporal")) break :blk .temporal;
                    if (std.mem.eql(u8, arg, "--god") or std.mem.eql(u8, arg, "-g")) break :blk .god;
                    if (std.mem.eql(u8, arg, "--quantum") or std.mem.eql(u8, arg, "-q")) break :blk .quantum;
                    if (std.mem.eql(u8, arg, "--normal") or std.mem.eql(u8, arg, "-n")) break :blk .normal;
                    if (std.mem.eql(u8, arg, "--infinity") or std.mem.eql(u8, arg, "-i")) break :blk .infinity;
                    if (std.mem.eql(u8, arg, "--omega") or std.mem.eql(u8, arg, "-o")) break :blk .omega;
                }
                break :blk .temporal; // Order #022: Default to TEMPORAL TRINITY mode
            };

            try os_instance.boot(mode);
        },
        // ABSOLUTE INFINITY v2.0 (Order #024)
        .infinity => {
            const sacred = @import("sacred");
            var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            defer _ = gpa.deinit();
            const gpa_allocator = gpa.allocator();

            if (cmd_args.len == 0) {
                std.debug.print("Usage: tri infinity <subcommand>\n", .{});
                std.debug.print("Subcommands:\n", .{});
                std.debug.print("  status   - Show ABSOLUTE INFINITY status\n", .{});
                std.debug.print("  boot     - Boot ABSOLUTE INFINITY system\n", .{});
                std.debug.print("  manifest - Display ABSOLUTE INFINITY manifesto\n", .{});
            } else if (std.mem.eql(u8, cmd_args[0], "status")) {
                var infinity = try sacred.AbsoluteInfinity.init(gpa_allocator);
                defer infinity.deinit();
                try infinity.awaken();
                try infinity.getStatus();
            } else if (std.mem.eql(u8, cmd_args[0], "boot")) {
                try sacred.bootAbsoluteInfinity(gpa_allocator);
            } else if (std.mem.eql(u8, cmd_args[0], "manifest")) {
                sacred.displayInfinityManifesto();
            } else {
                std.debug.print("Unknown subcommand: {s}\n", .{cmd_args[0]});
            }
        },
        // OMEGA PHASE (Order #024)
        .omega_phase => {
            const sacred = @import("sacred");
            var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            defer _ = gpa.deinit();
            const gpa_allocator = gpa.allocator();

            if (cmd_args.len == 0) {
                std.debug.print("Usage: tri omega-phase <subcommand>\n", .{});
                std.debug.print("Subcommands:\n", .{});
                std.debug.print("  awaken   - Initiate OMEGA PHASE awakening\n", .{});
                std.debug.print("  status   - Show OMEGA status\n", .{});
                std.debug.print("  evolve   - Run infinite evolution loop\n", .{});
                std.debug.print("  manifest - Display OMEGA manifesto\n", .{});
            } else if (std.mem.eql(u8, cmd_args[0], "awaken")) {
                try sacred.bootOmega(gpa_allocator);
            } else if (std.mem.eql(u8, cmd_args[0], "status")) {
                var engine = sacred.OmegaEngine.init(gpa_allocator);
                defer engine.deinit();
                try engine.awakenOmega();
                try engine.getStatus();
            } else if (std.mem.eql(u8, cmd_args[0], "evolve")) {
                var engine = sacred.OmegaEngine.init(gpa_allocator);
                defer engine.deinit();
                try engine.awakenOmega();
                try engine.evolve();
            } else if (std.mem.eql(u8, cmd_args[0], "manifest")) {
                sacred.displayOmegaManifesto();
            } else {
                std.debug.print("Unknown subcommand: {s}\n", .{cmd_args[0]});
            }
        },
    }
}
