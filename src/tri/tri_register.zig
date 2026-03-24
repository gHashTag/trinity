// @origin(spec:tri_register.tri) @regen(manual-impl)
// TRI CLI - Command Registration v3.0 — Unified Registry
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const tri_command_registry = @import("tri_command_registry.zig");
const CommandRegistry = tri_command_registry.CommandRegistry;
const CommandMetadata = tri_command_registry.CommandMetadata;
const CommandCategory = tri_command_registry.CommandCategory;
const CommandFn = tri_command_registry.CommandFn;
const Subcommand = tri_command_registry.Subcommand;

// Unified registry — single source of truth for metadata
const sacred_module = @import("sacred");
const command_table = sacred_module;

// Import command modules
const bio_commands = @import("tri_biology.zig");
const cosmos_commands = @import("tri_cosmology.zig");
const dark_matter_commands = @import("tri_dark_matter.zig");
const neuro_commands = @import("tri_neuro.zig");
const string_commands = @import("tri_string.zig");
const music_commands = @import("tri_music.zig");
const vsa_commands = @import("tri_vsa.zig");
const tri_context = @import("tri_context.zig");
const commands = @import("tri_commands.zig");
const pipeline = @import("tri_pipeline.zig");
const demos = @import("tri_demos.zig");
const math_commands = @import("math/commands.zig");
const utils = @import("tri_utils.zig");
const research_commands = @import("tri_research.zig");
const query_commands = @import("tri_query_commands.zig");
const cmd_list = @import("tri_cmd_list.zig");
const mcp_cmd = @import("tri_mcp.zig");
const sacred_v2 = @import("tri_sacred_v2.zig");
const sacred_fpga = @import("tri_sacred_fpga.zig");
const tri_train = @import("metabolism.zig");
const tri_zenodo = @import("tri_zenodo.zig");

// Global state pointer (set by main before registration)
var g_state: ?*utils.CLIState = null;

/// Adapter for commands that need CLIState (with args)
fn stateAdapter(comptime fn_ptr: anytype) CommandFn {
    return struct {
        fn fn_(_: std.mem.Allocator, args: []const []const u8) !void {
            if (g_state) |state| {
                fn_ptr(state, args);
            } else {
                std.debug.print("Error: CLIState not initialized\n", .{});
            }
        }
    }.fn_;
}

/// Adapter for commands that need CLIState (without args)
fn stateAdapter1(comptime fn_ptr: anytype) CommandFn {
    return struct {
        fn fn_(_: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            if (g_state) |state| {
                fn_ptr(state);
            } else {
                std.debug.print("Error: CLIState not initialized\n", .{});
            }
        }
    }.fn_;
}

// EXECUTE FUNCTION MAP — CLI-specific wiring

const ExecuteEntry = struct {
    name: []const u8,
    execute: CommandFn,
};

/// Comptime table mapping command name → execute fn pointer
const execute_map = [_]ExecuteEntry{
    // ── Sacred Science ──
    .{ .name = "bio", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return bio_commands.runBioCommand(a, args);
        }
    }.f },
    .{ .name = "cosmos", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return cosmos_commands.runCosmosCommand(a, args);
        }
    }.f },
    .{ .name = "dm", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return dark_matter_commands.runDarkMatterCommand(a, args);
        }
    }.f },
    // .{ .name = "gravity", .execute = struct { fn f(a: std.mem.Allocator, args: []const []const u8) !void { return gravity_commands.runGravityCommand(a, args); } }.f }, // disabled: module broken
    .{ .name = "neuro", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return neuro_commands.runNeuroCommand(a, args);
        }
    }.f },
    .{ .name = "string", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return string_commands.runStringCommand(a, args);
        }
    }.f },
    .{ .name = "vsa", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return vsa_commands.runVsaCommand(a, args);
        }
    }.f },

    // ── Blind Spots (8 New Domains) ──
    // .{ .name = "blindspots", .execute = struct { fn f(a: std.mem.Allocator, args: []const []const u8) !void { return blindspots_commands.runBlindSpotsCommand(a, args); } }.f }, // disabled: file missing

    // ── QCD Transition (Sprint 2) ──
    // .{ .name = "qcd", .execute = struct { fn f(a: std.mem.Allocator, args: []const []const u8) !void { return qcd_commands.runQcdCommand(a, args); } }.f }, // disabled: file missing

    // ── Math ──
    .{ .name = "math", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return math_commands.runMathCommand(a, args);
        }
    }.f },
    .{ .name = "constants", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return math_commands.runConstantsCommand(a, args);
        }
    }.f },
    .{ .name = "phi", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return math_commands.runPhiCommand(a, args);
        }
    }.f },
    .{ .name = "fib", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return math_commands.runFibCommand(a, args);
        }
    }.f },
    .{ .name = "lucas", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return math_commands.runLucasCommand(a, args);
        }
    }.f },
    .{ .name = "spiral", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return math_commands.runSpiralCommand(a, args);
        }
    }.f },
    .{ .name = "gematria", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return math_commands.runGematriaTopLevel(a, args);
        }
    }.f },
    .{ .name = "formula", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return math_commands.runFormulaCommand(a, args);
        }
    }.f },
    .{ .name = "sacred", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return math_commands.runSacredCommand(a, args);
        }
    }.f },
    .{ .name = "particles", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return math_commands.runParticlesCommand(a, args);
        }
    }.f },

    // ── Sacred Formula Engine v1.1 (Evidence-based) ──
    .{ .name = "math-table", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return sacred_v2.runSacredTable(a, args);
        }
    }.f },
    .{ .name = "math-verify", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return sacred_v2.runSacredVerify(a, args);
        }
    }.f },
    .{ .name = "math-explain", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return sacred_v2.runSacredExplain(a, args);
        }
    }.f },
    .{ .name = "math-doctor", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return sacred_v2.runSacredDoctor(a, args);
        }
    }.f },
    .{ .name = "math-diff", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return sacred_v2.runSacredDiff(a, args);
        }
    }.f },
    // ── Music ──
    .{ .name = "music", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return music_commands.cmdShowSacredFrequencies(a, args);
        }
    }.f },
    .{ .name = "frequency", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return music_commands.cmdNoteToFrequency(a, args);
        }
    }.f },
    .{ .name = "scale", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return music_commands.cmdShowScale(a, args);
        }
    }.f },
    .{ .name = "chord", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return music_commands.cmdAnalyzeChord(a, args);
        }
    }.f },
    .{ .name = "resonance", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return music_commands.cmdCalculateResonance(a, args);
        }
    }.f },
    .{ .name = "waveform", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return music_commands.cmdGenerateWaveform(a, args);
        }
    }.f },
    .{ .name = "harmony", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return music_commands.cmdAnalyzeHarmony(a, args);
        }
    }.f },
    .{ .name = "phi-series", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return music_commands.cmdPhiSeries(a, args);
        }
    }.f },

    // ── AI & Chat ──
    .{ .name = "chat", .execute = stateAdapter(utils.runChatCommand) },
    .{ .name = "code", .execute = stateAdapter(utils.runCodeCommand) },

    // ── SWE Agent ──
    .{ .name = "fix", .execute = struct {
        fn f(_: std.mem.Allocator, args: []const []const u8) !void {
            if (g_state) |s| utils.runSWECommand(s, .BugFix, args);
        }
    }.f },
    .{ .name = "explain", .execute = struct {
        fn f(_: std.mem.Allocator, args: []const []const u8) !void {
            if (g_state) |s| utils.runSWECommand(s, .Explain, args);
        }
    }.f },
    //.{ .name = "test", .execute = struct { fn f(a: std.mem.Allocator, args: []const []const u8) !void { return commands.runTestCommand(a, args); } }.f }, // disabled: not implemented
    .{ .name = "doc", .execute = struct {
        fn f(_: std.mem.Allocator, args: []const []const u8) !void {
            if (g_state) |s| utils.runSWECommand(s, .Document, args);
        }
    }.f },
    .{ .name = "refactor", .execute = struct {
        fn f(_: std.mem.Allocator, args: []const []const u8) !void {
            if (g_state) |s| utils.runSWECommand(s, .Refactor, args);
        }
    }.f },
    .{ .name = "reason", .execute = struct {
        fn f(_: std.mem.Allocator, args: []const []const u8) !void {
            if (g_state) |s| utils.runSWECommand(s, .Reason, args);
        }
    }.f },

    // ── Git ──
    .{ .name = "commit", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runGitCommand(a, "commit", args);
        }
    }.f },
    .{ .name = "diff", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runGitCommand(a, "diff", args);
        }
    }.f },
    .{ .name = "status", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runGitCommand(a, "status", args);
        }
    }.f },
    .{ .name = "log", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runGitCommand(a, "log", args);
        }
    }.f },

    // ── Golden Chain Pipeline ──
    .{ .name = "pipeline", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            pipeline.runPipelineCommand(a, args);
        }
    }.f },
    .{ .name = "chain", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            pipeline.runChainCommand(a, args);
        }
    }.f },
    .{ .name = "decompose", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            pipeline.runDecomposeCommand(a, args);
        }
    }.f },
    .{ .name = "plan", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            pipeline.runPlanCommand(a, args);
        }
    }.f },
    .{ .name = "spec-create", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            pipeline.runSpecCreateCommand(a, args);
        }
    }.f },
    .{ .name = "loop-decide", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            pipeline.runLoopDecideCommand(a, args);
        }
    }.f },
    .{ .name = "verify", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            pipeline.runVerifyCommand(a);
        }
    }.f },
    .{ .name = "toxic-verdict", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            pipeline.runVerdictCommand(a);
        }
    }.f },

    // ── VIBEE / Dev ──
    .{ .name = "gen", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runGenCommand(a, args);
        }
    }.f },
    .{ .name = "convert", .execute = struct {
        fn f(_: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runConvertCommand(args);
        }
    }.f },
    .{ .name = "serve", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runServeCommand(a, args);
        }
    }.f },
    .{ .name = "bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            return commands.runBenchCommand(a);
        }
    }.f },
    .{ .name = "evolve", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runBrainSimulateCommand(a, args);
        }
    }.f },

    // ── TVC ──
    .{ .name = "tvc-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runTVCDemo();
        }
    }.f },
    .{ .name = "tvc-stats", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runTVCStats();
        }
    }.f },

    // ── Demo & Benchmark Commands ──
    .{ .name = "agents-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runAgentsDemo();
        }
    }.f },
    .{ .name = "agents-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runAgentsBench();
        }
    }.f },
    .{ .name = "context-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runContextDemo();
        }
    }.f },
    .{ .name = "context-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runContextBench();
        }
    }.f },
    .{ .name = "rag-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runRAGDemo();
        }
    }.f },
    .{ .name = "rag-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runRAGBench();
        }
    }.f },
    .{ .name = "voice-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runVoiceIODemo();
        }
    }.f },
    .{ .name = "voice-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runVoiceIOBench();
        }
    }.f },
    .{ .name = "sandbox-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runSandboxDemo();
        }
    }.f },
    .{ .name = "sandbox-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runSandboxBench();
        }
    }.f },
    .{ .name = "stream-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runStreamPipelineDemo();
        }
    }.f },
    .{ .name = "stream-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runStreamPipelineBench();
        }
    }.f },
    .{ .name = "vision-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runVisionDemo();
        }
    }.f },
    .{ .name = "vision-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runVisionBench();
        }
    }.f },
    .{ .name = "finetune-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runFineTuneDemo();
        }
    }.f },
    .{ .name = "finetune-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runFineTuneBench();
        }
    }.f },
    .{ .name = "batched-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runBatchedDemo();
        }
    }.f },
    .{ .name = "batched-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runBatchedBench();
        }
    }.f },
    .{ .name = "priority-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runPriorityDemo();
        }
    }.f },
    .{ .name = "priority-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runPriorityBench();
        }
    }.f },
    .{ .name = "deadline-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runDeadlineDemo();
        }
    }.f },
    .{ .name = "deadline-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runDeadlineBench();
        }
    }.f },
    .{ .name = "multimodal-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runMultiModalDemo();
        }
    }.f },
    .{ .name = "multimodal-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runMultiModalBench();
        }
    }.f },
    .{ .name = "tooluse-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runToolUseDemo();
        }
    }.f },
    .{ .name = "tooluse-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runToolUseBench();
        }
    }.f },
    .{ .name = "unified-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runUnifiedAgentDemo();
        }
    }.f },
    .{ .name = "unified-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runUnifiedAgentBench();
        }
    }.f },
    .{ .name = "autonomous-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runAutonomousAgentDemo();
        }
    }.f },
    .{ .name = "autonomous-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runAutonomousAgentBench();
        }
    }.f },
    .{ .name = "orchestration-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runOrchestrationDemo();
        }
    }.f },
    .{ .name = "orchestration-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runOrchestrationBench();
        }
    }.f },
    .{ .name = "mm-orch-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runMMOrchDemo();
        }
    }.f },
    .{ .name = "mm-orch-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runMMOrchBench();
        }
    }.f },
    .{ .name = "memory-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runMemoryDemo();
        }
    }.f },
    .{ .name = "memory-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runMemoryBench();
        }
    }.f },
    .{ .name = "persist-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runPersistDemo();
        }
    }.f },
    .{ .name = "persist-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runPersistBench();
        }
    }.f },
    .{ .name = "spawn-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runSpawnDemo();
        }
    }.f },
    .{ .name = "spawn-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runSpawnBench();
        }
    }.f },
    .{ .name = "cluster-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runClusterDemo();
        }
    }.f },
    .{ .name = "cluster-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runClusterBench();
        }
    }.f },
    .{ .name = "worksteal-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runWorkStealDemo();
        }
    }.f },
    .{ .name = "worksteal-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runWorkStealBench();
        }
    }.f },
    .{ .name = "plugin-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runPluginDemo();
        }
    }.f },
    .{ .name = "plugin-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runPluginBench();
        }
    }.f },
    .{ .name = "comms-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runCommsDemo();
        }
    }.f },
    .{ .name = "comms-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runCommsBench();
        }
    }.f },
    .{ .name = "observe-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runObserveDemo();
        }
    }.f },
    .{ .name = "observe-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runObserveBench();
        }
    }.f },
    .{ .name = "consensus-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runConsensusDemo();
        }
    }.f },
    .{ .name = "consensus-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runConsensusBench();
        }
    }.f },
    .{ .name = "specexec-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runSpecExecDemo();
        }
    }.f },
    .{ .name = "specexec-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runSpecExecBench();
        }
    }.f },
    .{ .name = "governor-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runGovernorDemo();
        }
    }.f },
    .{ .name = "governor-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runGovernorBench();
        }
    }.f },
    .{ .name = "fedlearn-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runFedLearnDemo();
        }
    }.f },
    .{ .name = "fedlearn-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runFedLearnBench();
        }
    }.f },
    .{ .name = "eventsrc-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runEventSrcDemo();
        }
    }.f },
    .{ .name = "eventsrc-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runEventSrcBench();
        }
    }.f },
    .{ .name = "capsec-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runCapSecDemo();
        }
    }.f },
    .{ .name = "capsec-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runCapSecBench();
        }
    }.f },
    .{ .name = "dtxn-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runDTxnDemo();
        }
    }.f },
    .{ .name = "dtxn-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runDTxnBench();
        }
    }.f },
    .{ .name = "cache-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runCacheDemo();
        }
    }.f },
    .{ .name = "cache-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runCacheBench();
        }
    }.f },
    .{ .name = "contract-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runContractDemo();
        }
    }.f },
    .{ .name = "contract-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runContractBench();
        }
    }.f },
    .{ .name = "workflow-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runWorkflowDemo();
        }
    }.f },
    .{ .name = "workflow-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runWorkflowBench();
        }
    }.f },

    // ── Distributed ──
    .{ .name = "distributed", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runDistributedCommand(a, args);
        }
    }.f },
    .{ .name = "multi-cluster", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runMultiClusterCommand(a, args);
        }
    }.f },

    // ── Codebase Context ──
    .{ .name = "analyze", .execute = stateAdapter1(tri_context.runAnalyzeCommand) },
    .{ .name = "search", .execute = stateAdapter(tri_context.runSearchCommand) },
    .{ .name = "query", .execute = struct {
        fn f(allocator: std.mem.Allocator, args: []const []const u8) !void {
            return query_commands.runQueryCommand(allocator, args);
        }
    }.f },
    .{ .name = "context-info", .execute = stateAdapter1(tri_context.runContextInfoCommand) },
    .{ .name = "intelligence", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            if (g_state) |s| tri_context.runIntelligenceCommand(a, s, args) catch |err| {
                std.debug.print("Error: {}\n", .{err});
            };
        }
    }.f },

    // ── Dev Utilities ──
    .{ .name = "doctor", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runDoctorCommand(a, args);
        }
    }.f },
    .{ .name = "regen", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            const regen_mod = @import("regen.zig");
            return regen_mod.runRegenCLI(a, args);
        }
    }.f },
    .{ .name = "clean", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runCleanCommand(a, args);
        }
    }.f },
    .{ .name = "fmt", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runFmtCommand(a, args);
        }
    }.f },
    .{ .name = "stats", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runStatsCommand(a, args);
        }
    }.f },
    .{ .name = "igla", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runIglaCommand(a, args);
        }
    }.f },

    // ── Research ──
    .{ .name = "research", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return research_commands.runResearchCommand(a, args);
        }
    }.f },

    // ── Sacred Intelligence ──
    //.{ .name = "identity", .execute = struct { fn f(a: std.mem.Allocator, args: []const []const u8) !void { return commands.runIdentityCommand(a, args); } }.f }, // disabled: not implemented
    //.{ .name = "swarm", .execute = struct { fn f(a: std.mem.Allocator, args: []const []const u8) !void { return commands.runSwarmCommand(a, args); } }.f }, // disabled: not implemented
    //.{ .name = "govern", .execute = struct { fn f(a: std.mem.Allocator, args: []const []const u8) !void { return commands.runGovernCommand(a, args); } }.f }, // disabled: not implemented
    //.{ .name = "dashboard", .execute = struct { fn f(a: std.mem.Allocator, args: []const []const u8) !void { return commands.runDashboardCommand(a, args); } }.f }, // disabled: not implemented
    //.{ .name = "omega", .execute = struct { fn f(a: std.mem.Allocator, args: []const []const u8) !void { return commands.runOmegaCommand(a, args); } }.f }, // disabled: not implemented

    // ── DePIN ──
    //.{ .name = "wallet", .execute = struct { fn f(a: std.mem.Allocator, args: []const []const u8) !void { return commands.runWalletCommand(a, args); } }.f }, // disabled: not implemented
    //.{ .name = "mesh", .execute = struct { fn f(a: std.mem.Allocator, args: []const []const u8) !void { return commands.runMeshCommand(a, args); } }.f }, // disabled: not implemented
    //.{ .name = "reputation", .execute = struct { fn f(a: std.mem.Allocator, args: []const []const u8) !void { return commands.runReputationCommand(a, args); } }.f }, // disabled: not implemented
    //.{ .name = "hardware", .execute = struct { fn f(a: std.mem.Allocator, args: []const []const u8) !void { return commands.runHardwareCommand(a, args); } }.f }, // disabled: not implemented
    //.{ .name = "math-agent", .execute = struct { fn f(a: std.mem.Allocator, args: []const []const u8) !void { return commands.runMathAgentCommand(a, args); } }.f }, // disabled: not implemented

    // ── Temporal / System ──
    .{ .name = "time", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runTimeCommand(a, args);
        }
    }.f },
    .{ .name = "install", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            return commands.runInstallCommand(a);
        }
    }.f },
    .{ .name = "build", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            return commands.runBuildCommand(a);
        }
    }.f },
    //.{ .name = "deploy", .execute = struct { fn f(a: std.mem.Allocator, args: []const []const u8) !void { _ = args; return commands.runDeployCommand(a); } }.f }, // disabled: not implemented
    .{ .name = "deck", .execute = struct {
        fn f(a: std.mem.Allocator, _: []const []const u8) !void {
            return commands.runDeckCommand(a);
        }
    }.f },
    .{ .name = "fpga-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runFpgaDemoCommand(a, args);
        }
    }.f },
    .{ .name = "fpga", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return runFpgaCommand(a, args);
        }
    }.f },
    .{ .name = "train", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return tri_train.runTrainCommand(a, args);
        }
    }.f },
    .{ .name = "zenodo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return tri_zenodo.runZenodoCommand(a, args);
        }
    }.f },
    .{ .name = "sacred-full-cycle", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            return commands.runSacredFullCycleCommand(a);
        }
    }.f },
    .{ .name = "quantum", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runQuantumCommand(a, args);
        }
    }.f },
    .{ .name = "release-cosmic", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            return commands.runReleaseCosmicCommand(a);
        }
    }.f },
    .{ .name = "omega-cmd", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runOmegaPhaseCommand(a, args);
        }
    }.f },
    .{ .name = "all-cmd", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runAllCommand(a, args);
        }
    }.f },
    .{ .name = "holo-cmd", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runHoloCommand(a, args);
        }
    }.f },
    .{ .name = "release-absolute", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            return commands.runReleaseAbsoluteCommand(a);
        }
    }.f },
    .{ .name = "omega-evolve", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            return commands.runOmegaEvolveCommand(a);
        }
    }.f },
    //.{ .name = "conscious", .execute = struct { fn f(a: std.mem.Allocator, args: []const []const u8) !void { return commands.runConsciousCommand(a, args); } }.f }, // disabled: not implemented
    .{ .name = "launch", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runLaunchCommand(a, args);
        }
    }.f },

    // ── Needle ──
    .{ .name = "needle", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runNeedleCommand(a, args);
        }
    }.f },
    .{ .name = "needle-search", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runNeedleSearchCommand(a, args);
        }
    }.f },
    .{ .name = "needle-check", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runNeedleCheckCommand(a, args);
        }
    }.f },

    // ── Info ──
    .{ .name = "deps", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            utils.printInfo();
        }
    }.f },
    .{ .name = "info", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            utils.printInfo();
        }
    }.f },
    .{ .name = "version", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            utils.printVersion();
        }
    }.f },
    //.{ .name = "docs-gen", .execute = struct { fn f(a: std.mem.Allocator, args: []const []const u8) !void { return utils.runDocsGenCommand(a, args); } }.f }, // disabled: not implemented
    //.{ .name = "registry-validate", .execute = struct { fn f(_: std.mem.Allocator, args: []const []const u8) !void { _ = args; utils.runRegistryValidateCommand() catch {}; } }.f }, // disabled: not implemented

    // ── Completion ──
    .{ .name = "completion", .execute = struct {
        fn f(_: std.mem.Allocator, args: []const []const u8) !void {
            if (args.len == 0) {
                var reg = CommandRegistry.init(std.heap.page_allocator) catch return;
                defer reg.deinit();
                const cg = @import("tri_completion.zig").CompletionGenerator{ .registry = &reg, .tri_path = "tri" };
                try cg.printInstallHelp();
                return;
            }
            if (std.mem.eql(u8, args[0], "--install")) {
                var reg = CommandRegistry.init(std.heap.page_allocator) catch return;
                defer reg.deinit();
                const cg = @import("tri_completion.zig").CompletionGenerator{ .registry = &reg, .tri_path = "tri" };
                try cg.installCompletions();
            } else {
                std.debug.print("Usage: tri completion [--bash|--zsh|--fish|--install]\n", .{});
            }
        }
    }.f },

    // ── Help ──
    .{ .name = "help", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            if (args.len >= 2 and std.mem.eql(u8, args[1], "--search")) {
                std.debug.print("Search: {s}\n", .{args[0]});
            } else if (args.len >= 2 and std.mem.eql(u8, args[1], "--category")) {
                std.debug.print("Category: {s}\n", .{args[0]});
            } else {
                const HelpSystem = @import("tri_help.zig").HelpSystem;
                var reg = CommandRegistry.init(std.heap.page_allocator) catch return;
                defer reg.deinit();
                const hs = HelpSystem{ .registry = &reg, .allocator = std.heap.page_allocator };
                try hs.printCategorized();
            }
        }
    }.f },

    // ── Test REPL ──
    .{ .name = "test-repl", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runReplTestCommand(a, args);
        }
    }.f },

    // ── FPGA & FORGE Toolchain ──
    .{ .name = "fpga", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return runFpgaCommand(a, args);
        }
    }.f },
    .{ .name = "train", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return tri_train.runTrainCommand(a, args);
        }
    }.f },
    .{ .name = "zenodo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return tri_zenodo.runZenodoCommand(a, args);
        }
    }.f },
    .{ .name = "forge-bench", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            return runForgeBenchCommand(a);
        }
    }.f },
    .{ .name = "forge-verdict", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return runForgeVerdictCommand(a, args);
        }
    }.f },
    .{ .name = "sacred-const", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return sacred_fpga.runSacredConstCommand(a, args);
        }
    }.f },

    // ── Pipeline Demo ──
    .{ .name = "pipeline-demo", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            pipeline.runPipelineCommand(a, args);
        }
    }.f },

    // ── CLI Tools (P1.6) ──
    .{ .name = "commands", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return cmd_list.runCommandsList(a, args);
        }
    }.f },
    .{ .name = "mcp", .execute = struct {
        fn f(a: std.mem.Allocator, args: []const []const u8) !void {
            return mcp_cmd.runMcpCommand(a, args);
        }
    }.f },
};

/// Convert unified registry category to CLI registry category
fn mapCategory(cat: sacred_module.CommandCategory) CommandCategory {
    return switch (cat) {
        .ai => .ai,
        .dev => .dev,
        .git => .git,
        .math => .math,
        .science => .science,
        .sacred => .sacred,
        .system => .system,
        .demo => .demo,
        .benchmark => .benchmark,
        .advanced => .advanced,
        .depin => .depin,
    };
}

comptime {
    @setEvalBranchQuota(500_000);

    // 8a. All execute_map entries must exist in command_table (no orphaned handlers)
    // Note: Fix sacred module to export all_commands
    _ = command_table; // Suppress unused warning
    //for (&execute_map) |*entry| {
    //    var found = false;
    //    for (&command_table.all_commands) |*cmd| {
    //        if (std.mem.eql(u8, entry.name, cmd.name)) {
    //            found = true;
    //            break;
    //        }
    //    }
    //    if (!found) {
    //        @compileError("execute_map has entry '" ++ entry.name ++ "' but command_table does not contain it");
    //    }
    //}
}

// =============================================================================
// EXECUTE LOOKUP
// =============================================================================

/// Find execute fn for a command name (comptime linear scan of execute_map)
fn findExecuteFn(name: []const u8) ?CommandFn {
    for (&execute_map) |*entry| {
        if (std.mem.eql(u8, entry.name, name)) return entry.execute;
    }
    return null;
}

// =============================================================================
// REGISTRATION — reads metadata from unified table, wires execute fns
// =============================================================================

/// Register all commands with metadata from unified table + execute fns from this module
pub fn registerAllCommands(registry: *CommandRegistry, state: *utils.CLIState) !void {
    g_state = state;

    // Note: Iterate over command_table.all_commands when sacred module exports it
    // For now, register commands from execute_map
    for (&execute_map) |*entry| {
        try registry.register(.{
            .name = entry.name,
            .aliases = &[_][]const u8{},
            .description = "TRI command", // placeholder
            .long_help = null,
            .category = .Dev,
            .examples = &[_][]const u8{},
            .has_subcommands = false,
            .subcommands = &[_]Subcommand{},
            .execute = entry.execute,
        });
    }
}

// =============================================================================
// FPGA COMMANDS
// =============================================================================

// Import real tri_fpga commands (VIBEE + openXC7 Pipeline)
const tri_fpga = @import("tri_fpga.zig");
const tri_fpga_experience = @import("tri_fpga_experience.zig");

const fpga_commands = struct {
    pub fn runFpgaGen(allocator: std.mem.Allocator, args: []const []const u8) !void {
        _ = allocator;
        _ = args;
        std.debug.print("{s}Note:{s} tri fpga gen not implemented - use zig build vibee instead.\n", .{ YELLOW, RESET });
    }
    pub fn runFpgaFlash(allocator: std.mem.Allocator, args: []const []const u8) !void {
        return tri_fpga.runFpgaFlashCommand(allocator, args);
    }
    pub fn runFpgaGenTri(allocator: std.mem.Allocator, args: []const []const u8) !void {
        _ = allocator;
        _ = args;
        std.debug.print("{s}Note:{s} .tri DSL not supported - use .tri specs instead.\n", .{ YELLOW, RESET });
        std.debug.print("Example: tri fpga gen specs/fpga/blink.tri\n", .{});
    }
    pub fn runFpgaSynth(allocator: std.mem.Allocator, args: []const []const u8) !void {
        return tri_fpga.runFpgaSynthCommand(allocator, args);
    }
    pub fn runFpgaVerdict(allocator: std.mem.Allocator, args: []const []const u8) !void {
        return tri_fpga.runFpgaStatusCommand(allocator, args);
    }
    pub fn runFpgaTest(allocator: std.mem.Allocator, args: []const []const u8) !void {
        // test = build + verify (synth + flash + camera check)
        return tri_fpga.runFpgaVerifyCommand(allocator, args);
    }
    pub fn runFpgaVerify(allocator: std.mem.Allocator, args: []const []const u8) !void {
        return tri_fpga.runFpgaVerifyCommand(allocator, args);
    }
    pub fn runFpgaEye(allocator: std.mem.Allocator, args: []const []const u8) !void {
        return tri_fpga.runFpgaEyeCommand(allocator, args);
    }
    pub fn runFpgaBuildUart(allocator: std.mem.Allocator, args: []const []const u8) !void {
        return tri_fpga.runFpgaBuildUartCommand(allocator, args);
    }
    pub fn runFpgaFlashUart(allocator: std.mem.Allocator, args: []const []const u8) !void {
        return tri_fpga.runFpgaFlashUartCommand(allocator, args);
    }
    pub fn runFpgaUartTest(allocator: std.mem.Allocator, args: []const []const u8) !void {
        return tri_fpga.runFpgaUartTestCommand(allocator, args);
    }
};

/// Run fpga command - dispatches to gen/verdict/flash/gen-tri/synth subcommands
pub fn runFpgaCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const unified_mod = @import("../tri/unified_output.zig");

    if (args.len < 1) {
        // Show help with UnifiedOutput in JSON mode
        var output = try unified_mod.UnifiedOutput.init(allocator, "fpga", .forge);
        defer output.deinit();

        try output.setSummary("FPGA command requires a subcommand");
        try output.addWarning("NO_SUBCOMMAND", "Usage: tri fpga <subcommand> [args]");

        // Build subcommands list for data field
        var data_json = try std.ArrayList(u8).initCapacity(allocator, 512);
        defer data_json.deinit(allocator);
        const data_writer = data_json.writer(allocator);

        try data_json.append(allocator, '{');
        try data_writer.print("\"subcommands\":[", .{});
        const subcommands = &[_][]const u8{
            "synth", "flash", "build", "verify", "snap", "status", "gen", "test", "jtag", "uart", "power",
        };
        for (subcommands, 0..) |sc, i| {
            if (i > 0) try data_json.append(allocator, ',');
            try data_writer.print("\"{s}\"", .{sc});
        }
        try data_json.appendSlice(allocator, "],");
        try data_writer.print("\"examples\":[", .{});
        const examples = &[_][]const u8{
            "tri fpga gen specs/fpga/blink.tri",
            "tri fpga gen-tri fpga/specs/uart.tri",
            "tri fpga synth fpga/specs/uart.tri --strategy consciousness",
            "tri fpga verdict",
            "tri fpga flash fpga/output/uart.bit",
            "tri fpga test",
        };
        for (examples, 0..) |ex, i| {
            if (i > 0) try data_json.append(allocator, ',');
            try data_writer.print("\"{s}\"", .{ex});
        }
        try data_json.appendSlice(allocator, "]}");

        output.data_raw = try allocator.dupe(u8, data_json.items);
        output.finalize();
        try output.print();
        return;
    }

    const subcommand = args[0];
    const sub_args = args[1..];

    if (std.mem.eql(u8, subcommand, "gen")) {
        return fpga_commands.runFpgaGen(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "gen-tri")) {
        return fpga_commands.runFpgaGenTri(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "synth")) {
        return fpga_commands.runFpgaSynth(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "verdict") or std.mem.eql(u8, subcommand, "status")) {
        return fpga_commands.runFpgaVerdict(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "flash")) {
        return fpga_commands.runFpgaFlash(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "build")) {
        return tri_fpga.runFpgaBuildCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "test")) {
        return fpga_commands.runFpgaTest(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "verify")) {
        return fpga_commands.runFpgaVerify(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "snap")) {
        return tri_fpga.runFpgaSnapCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "eye")) {
        return fpga_commands.runFpgaEye(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "uart")) {
        return tri_fpga.runFpgaUartCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "build-uart")) {
        return fpga_commands.runFpgaBuildUart(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "flash-uart")) {
        return fpga_commands.runFpgaFlashUart(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "uart-test")) {
        return fpga_commands.runFpgaUartTest(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "power")) {
        return tri_fpga.runFpgaPowerCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "infer")) {
        return tri_fpga.runFpgaInferCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "status")) {
        return tri_fpga.runFpgaStatusCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "read")) {
        return tri_fpga.runFpgaReadCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "experience")) {
        return tri_fpga_experience.runFpgaExperienceCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "probe")) {
        return runFpgaProbeCommand(allocator);
    } else if (std.mem.eql(u8, subcommand, "jtag")) {
        return runJtagCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "mount")) {
        return runFpgaMountCommand(allocator);
    } else if (std.mem.eql(u8, subcommand, "unmount")) {
        return runFpgaUnmountCommand(allocator);
    } else {
        // Unknown subcommand - use UnifiedOutput for error
        var output = try unified_mod.UnifiedOutput.init(allocator, "fpga", .forge);
        defer output.deinit();

        output.setStatus(.failure);
        try output.setSummary("Unknown subcommand");
        try output.addError("UNKNOWN_SUBCOMMAND", subcommand);

        var data_json = try std.ArrayList(u8).initCapacity(allocator, 128);
        defer data_json.deinit(allocator);
        const data_writer = data_json.writer(allocator);

        try data_json.append(allocator, '{');
        try data_writer.print("\"subcommand\":\"{s}\",\"valid_subcommands\":[", .{subcommand});
        const valid_subs = &[_][]const u8{ "gen", "gen-tri", "synth", "verdict", "flash", "test", "verify", "eye", "snap", "status", "build", "read", "experience", "probe", "jtag", "mount", "unmount", "uart", "build-uart", "flash-uart", "uart-test", "power" };
        for (valid_subs, 0..) |vs, i| {
            if (i > 0) try data_json.append(allocator, ',');
            try data_writer.print("\"{s}\"", .{vs});
        }
        try data_json.appendSlice(allocator, "]}");

        output.data_raw = try allocator.dupe(u8, data_json.items);
        output.finalize();
        try output.print();
    }
}

/// P1.6: Run command by name from execute_map
/// This allows main.zig to dispatch to registered commands
pub fn runCommand(allocator: std.mem.Allocator, name: []const u8, args: []const []const u8) !void {
    for (execute_map) |entry| {
        if (std.mem.eql(u8, entry.name, name)) {
            return entry.execute(allocator, args);
        }
    }
    // Command not found
    const unified_mod = @import("../tri/unified_output.zig");
    var output = try unified_mod.UnifiedOutput.init(allocator, name, .agent);
    defer output.deinit();
    output.setStatus(.denied);
    try output.setSummary("Unknown command");
    try output.addError("UNKNOWN_COMMAND", name);
    try output.print();
}

/// Run forge-bench command - FORGE regression suite
fn runForgeBenchCommand(allocator: std.mem.Allocator) !void {
    const forge_bin = findForgeBinary(allocator) orelse {
        std.debug.print("{s}Error:{s} FORGE binary not found. Run 'zig build forge' first.\n", .{ RED, RESET });
        return error.ForgeNotFound;
    };

    var argv = try std.ArrayList([]const u8).initCapacity(allocator, 4);
    defer argv.deinit(allocator);

    try argv.append(allocator, forge_bin);
    try argv.append(allocator, "bench");

    var child = std.process.Child.init(argv.items, allocator);
    child.stderr_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    _ = try child.spawnAndWait();
}

/// Mount FPGA virtual filesystem via macFUSE + JTAG bridge
fn runFpgaMountCommand(allocator: std.mem.Allocator) !void {
    const fpga_fs_path = "fpga/tools/fpga_fs";
    const mount_point = "/mnt/fpga";

    std.debug.print("{s}FPGA Mount:{s} Mounting virtual filesystem at {s}\n", .{ CYAN, RESET, mount_point });
    std.debug.print("\x1b[2mNote:\x1b[0m Requires sudo, macFUSE, and connected JTAG cable\n\n", .{});

    // Create mount point if needed
    var mkdir_argv = [_][]const u8{ "sudo", "mkdir", "-p", mount_point };
    var mkdir_child = std.process.Child.init(&mkdir_argv, allocator);
    mkdir_child.stderr_behavior = .Inherit;
    mkdir_child.stdout_behavior = .Inherit;
    _ = try mkdir_child.spawnAndWait();

    // Launch fpga_fs daemon
    var argv = [_][]const u8{ "sudo", fpga_fs_path, mount_point };
    var child = std.process.Child.init(&argv, allocator);
    child.stderr_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    const term = try child.spawnAndWait();
    if (term.Exited != 0) {
        std.debug.print("\n{s}Mount failed (exit {d}).{s}\n", .{ RED, term.Exited, RESET });
        std.debug.print("Check: macFUSE installed? Cable connected? FPGA programmed?\n", .{});
    }
}

/// Unmount FPGA virtual filesystem
fn runFpgaUnmountCommand(allocator: std.mem.Allocator) !void {
    const mount_point = "/mnt/fpga";
    std.debug.print("{s}FPGA Unmount:{s} Unmounting {s}\n", .{ CYAN, RESET, mount_point });

    var argv = [_][]const u8{ "umount", mount_point };
    var child = std.process.Child.init(&argv, allocator);
    child.stderr_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    const term = try child.spawnAndWait();
    if (term.Exited != 0) {
        std.debug.print("\n{s}Unmount failed.{s} Try: sudo umount -f {s}\n", .{ RED, RESET, mount_point });
    } else {
        std.debug.print("  Unmounted successfully.\n", .{});
    }
}

/// Run fpga probe command — calls jtag_switcher probe via child process
fn runFpgaProbeCommand(allocator: std.mem.Allocator) !void {
    const probe_path = "fpga/tools/jtag_switcher";
    std.debug.print("{s}Running hardware probe...{s}\n", .{ CYAN, RESET });
    std.debug.print("\x1b[2mNote:\x1b[0m Requires sudo and connected Platform Cable USB II\n\n", .{});

    var argv = [_][]const u8{ "sudo", probe_path, "probe" };
    var child = std.process.Child.init(&argv, allocator);
    child.stderr_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    const term = try child.spawnAndWait();
    if (term.Exited != 0) {
        std.debug.print("\n{s}Probe failed (exit {d}).{s} Check cable connection.\n", .{ RED, term.Exited, RESET });
    }
}

/// Run JTAG command — dispatches to jtag_switcher binary (DLC-10 Platform Cable USB II)
/// Usage: tri fpga jtag <write|readback|verify|status|idcode|dna|reg|probe|debug> [args]
fn runJtagCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const jtag_path = "fpga/tools/jtag_switcher";

    if (args.len < 1) {
        std.debug.print(
            \\{s}DLC-10 JTAG Switcher{s} — XC7A100T via Platform Cable USB II
            \\
            \\Usage: tri fpga jtag <command> [args]
            \\
            \\Commands:
            \\  write <file.bit>    Write bitstream to FPGA (~5 min for 3.6 MB)
            \\  readback <out.bin>  Read back configuration (1.4 MB, ~4 min)
            \\  verify <file.bit>   UG470-compliant compare (ECC/BRAM masking)
            \\  status              Read STAT register (DONE, CRC, etc.)
            \\  idcode              Read JTAG IDCODE
            \\  dna                 Read 57-bit Device DNA
            \\  reg <hex>           Read any config register by address
            \\  probe               Full FX2/CPLD/TDI/TDO diagnostic
            \\  debug               6-step config path diagnosis
            \\  bridge status       BSCANE2 bridge inference status + tok/s
            \\  bridge measure      Full report with token sequence
            \\  bridge run [s] [n]  Set seed, trigger inference, measure
            \\  bridge read <hex>   Read any bridge register
            \\
            \\Examples:
            \\  tri fpga jtag write fpga/openxc7-synth/hslm_full_top.bit
            \\  tri fpga jtag verify fpga/openxc7-synth/hslm_full_top.bit
            \\  tri fpga jtag status
            \\
        , .{ CYAN, RESET });
        return;
    }

    std.debug.print("{s}JTAG:{s} {s}", .{ CYAN, RESET, args[0] });
    for (args[1..]) |a| std.debug.print(" {s}", .{a});
    std.debug.print("\n", .{});

    // Build argv: sudo jtag_switcher <subcommand> [args...]
    var argv = try std.ArrayList([]const u8).initCapacity(allocator, args.len + 2);
    defer argv.deinit(allocator);
    try argv.append(allocator, "sudo");
    try argv.append(allocator, jtag_path);
    for (args) |a| try argv.append(allocator, a);

    var child = std.process.Child.init(argv.items, allocator);
    child.stderr_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    const term = try child.spawnAndWait();
    if (term.Exited != 0) {
        std.debug.print("\n{s}JTAG command failed (exit {d}).{s} Check cable connection.\n", .{ RED, term.Exited, RESET });
    }
}

/// Run forge-verdict command - FORGE compatibility verdict
fn runForgeVerdictCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    return fpga_commands.runFpgaVerdict(allocator, args);
}

/// Helper: find FORGE binary
fn findForgeBinary(allocator: std.mem.Allocator) ?[]const u8 {
    const paths = [_][]const u8{
        "zig-out/bin/forge",
        "./zig-out/bin/forge",
    };

    for (paths) |path| {
        if (std.fs.cwd().access(path, .{})) |_| {
            return allocator.dupe(u8, path) catch return null;
        } else |_| continue;
    }
    return null;
}

const YELLOW = "\x1b[0;33m";
const CYAN = "\x1b[0;36m";
const RED = "\x1b[0;31m";
const RESET = "\x1b[0m";

test "register ANSI codes" {
    try std.testing.expectEqualStrings("\x1b[0;33m", YELLOW);
    try std.testing.expectEqualStrings("\x1b[0m", RESET);
}
