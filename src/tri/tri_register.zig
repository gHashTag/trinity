// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - Command Registration v2.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// Central metadata-driven command registration
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const CommandRegistry = @import("tri_command_registry.zig").CommandRegistry;
const CommandMetadata = @import("tri_command_registry.zig").CommandMetadata;
const CommandCategory = @import("tri_command_registry.zig").CommandCategory;
const CommandFn = @import("tri_command_registry.zig").CommandFn;

// Import command modules
const bio_commands = @import("tri_biology.zig");
const cosmos_commands = @import("tri_cosmology.zig");
const neuro_commands = @import("tri_neuro.zig");
const tri_context = @import("tri_context.zig");
const commands = @import("tri_commands.zig");
const pipeline = @import("tri_pipeline.zig");
const demos = @import("tri_demos.zig");
const math_commands = @import("math/commands.zig");
const utils = @import("tri_utils.zig");

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

/// Register all commands with metadata
pub fn registerAllCommands(registry: *CommandRegistry, state: *utils.CLIState) !void {
    g_state = state;

    // ═══════════════════════════════════════════════════════════════════════════
    // SACRED SCIENCE (v14-v16) - Priority commands
    // ═══════════════════════════════════════════════════════════════════════════

    // Biology v14.0
    try registry.register(.{
        .name = "bio",
        .aliases = &.{ "biology" },
        .description = "Biology v14.0 — DNA/RNA/Protein sacred analysis",
        .long_help = "Analyze DNA, RNA, and protein sequences with sacred mathematics.\nUses φ-spiral encoding and Fibonacci patterns found in nature.",
        .category = .science,
        .examples = &.{
            "tri bio dna ATGCGT",
            "tri bio rna AUGCCAUAA",
            "tri bio protein MVHLTPEEK",
            "tri bio codon ATG",
        },
        .has_subcommands = true,
        .execute = struct { fn exec(a: std.mem.Allocator, args: []const []const u8) !void {
            return bio_commands.runBioCommand(a, args);
        } }.exec,
    });

    // Cosmology v15.0
    try registry.register(.{
        .name = "cosmos",
        .aliases = &.{ "cosmology" },
        .description = "Cosmology v15.0 — Universe through φ",
        .long_help = "Explore the universe through sacred mathematics.\nHubble tension resolution via φ, dark energy π-patterns.",
        .category = .science,
        .examples = &.{
            "tri cosmos hubble",
            "tri cosmos dark",
            "tri cosmos expand",
        },
        .execute = struct { fn exec(a: std.mem.Allocator, args: []const []const u8) !void {
            return cosmos_commands.runCosmosCommand(a, args);
        } }.exec,
    });

    // Neuroscience v16.0
    try registry.register(.{
        .name = "neuro",
        .aliases = &.{ "neuroscience" },
        .description = "Neuroscience v16.0 — Brain as sacred computer",
        .long_help = "The brain as a φ-patterned sacred computer.\nBrain waves follow golden ratio patterns. Consciousness computed via Ψ formula.",
        .category = .science,
        .examples = &.{
            "tri neuro waves",
            "tri neuro consciousness",
            "tri neuro regions",
            "tri neuro network",
        },
        .execute = struct { fn exec(a: std.mem.Allocator, args: []const []const u8) !void {
            return neuro_commands.runNeuroCommand(a, args);
        } }.exec,
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // MATH - Sacred Mathematics
    // ═══════════════════════════════════════════════════════════════════════════

    try registry.register(.{
        .name = "math",
        .aliases = &.{},
        .description = "Sacred mathematics dispatcher",
        .long_help = "Golden ratio φ, Lucas numbers, sacred geometry.",
        .category = .math,
        .examples = &.{
            "tri math",
            "tri constants",
            "tri phi 10",
            "tri fib 20",
        },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return math_commands.runMathCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "constants",
        .aliases = &.{ "const", "c" },
        .description = "Display sacred constants (φ, π, e, μ, χ, σ, ε)",
        .long_help = "Show all sacred mathematics constants used in Trinity.",
        .category = .math,
        .examples = &.{ "tri constants" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return math_commands.runConstantsCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "phi",
        .aliases = &.{},
        .description = "Compute φⁿ (golden ratio power)",
        .long_help = "Calculate the nth power of the golden ratio φ = (1+√5)/2.",
        .category = .math,
        .examples = &.{ "tri phi 10", "tri phi 100" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return math_commands.runPhiCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "fib",
        .aliases = &.{ "fibonacci" },
        .description = "Fibonacci numbers with BigInt",
        .long_help = "Calculate Fibonacci numbers F(n) using arbitrary precision.",
        .category = .math,
        .examples = &.{ "tri fib 10", "tri fib 100" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return math_commands.runFibCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "lucas",
        .aliases = &.{},
        .description = "Lucas numbers (L(2)=3=TRINITY)",
        .long_help = "Calculate Lucas numbers L(n). L(2)=3 represents TRINITY.",
        .category = .math,
        .examples = &.{ "tri lucas 10", "tri lucas 20" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return math_commands.runLucasCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "spiral",
        .aliases = &.{},
        .description = "φ-spiral coordinates",
        .long_help = "Generate golden spiral coordinates for visualization.",
        .category = .math,
        .examples = &.{ "tri spiral 10" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return math_commands.runSpiralCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "gematria",
        .aliases = &.{},
        .description = "Gematria word value calculator",
        .long_help = "Calculate gematria values using Hebrew/English systems.",
        .category = .math,
        .examples = &.{ "tri gematria hello" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return math_commands.runGematriaTopLevel(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "formula",
        .aliases = &.{},
        .description = "Sacred formula evaluator",
        .long_help = "Evaluate sacred mathematical formulas.",
        .category = .math,
        .examples = &.{ "tri formula 'phi^2 + 1/phi^2'" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return math_commands.runFormulaCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "sacred",
        .aliases = &.{},
        .description = "Sacred mathematics utilities",
        .long_help = "Various sacred mathematics operations and visualizations.",
        .category = .sacred,
        .examples = &.{ "tri sacred", "tri sacred trinity" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return math_commands.runSacredCommand(a, args);
        } }.exec,
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // AI & CHAT
    // ═══════════════════════════════════════════════════════════════════════════

    try registry.register(.{
        .name = "chat",
        .aliases = &.{ "c" },
        .description = "Interactive chat (vision + voice + tools)",
        .long_help = "Full-featured chat with multimodal input, streaming output, and tool use.",
        .category = .ai,
        .examples = &.{
            "tri chat 'explain zig'",
            "tri chat --stream",
            "tri chat --image path.jpg 'describe this'",
        },
        .execute = stateAdapter(utils.runChatCommand),
    });

    try registry.register(.{
        .name = "code",
        .aliases = &.{},
        .description = "Generate code with typing effect",
        .long_help = "AI code generation with typewriter animation.",
        .category = .ai,
        .examples = &.{ "tri code 'create a web server'" },
        .execute = stateAdapter(utils.runCodeCommand),
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // SWE AGENT (Software Engineering)
    // ═══════════════════════════════════════════════════════════════════════════

    try registry.register(.{
        .name = "fix",
        .aliases = &.{},
        .description = "Detect and fix bugs",
        .long_help = "SWE agent: Analyze code, find bugs, and apply fixes.",
        .category = .dev,
        .examples = &.{ "tri fix src/main.zig" },
        .execute = struct { fn exec (_: std.mem.Allocator, args: []const []const u8) !void {
            if (g_state) |s| utils.runSWECommand(s, .BugFix, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "explain",
        .aliases = &.{ "exp" },
        .description = "Explain code or concept",
        .long_help = "SWE agent: Provide detailed explanations of code.",
        .category = .dev,
        .examples = &.{ "tri explain src/vsa.zig" },
        .execute = struct { fn exec (_: std.mem.Allocator, args: []const []const u8) !void {
            if (g_state) |s| utils.runSWECommand(s, .Explain, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "test",
        .aliases = &.{},
        .description = "Generate tests",
        .long_help = "SWE agent: Create comprehensive test suites.",
        .category = .dev,
        .examples = &.{ "tri test src/vsa.zig" },
        .execute = struct { fn exec (_: std.mem.Allocator, args: []const []const u8) !void {
            if (g_state) |s| utils.runSWECommand(s, .Test, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "doc",
        .aliases = &.{ "document" },
        .description = "Generate documentation",
        .long_help = "SWE agent: Create documentation from code.",
        .category = .dev,
        .examples = &.{ "tri doc src/vsa.zig" },
        .execute = struct { fn exec (_: std.mem.Allocator, args: []const []const u8) !void {
            if (g_state) |s| utils.runSWECommand(s, .Document, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "refactor",
        .aliases = &.{},
        .description = "Suggest refactoring",
        .long_help = "SWE agent: Suggest and apply code improvements.",
        .category = .dev,
        .examples = &.{ "tri refactor src/main.zig" },
        .execute = struct { fn exec (_: std.mem.Allocator, args: []const []const u8) !void {
            if (g_state) |s| utils.runSWECommand(s, .Refactor, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "reason",
        .aliases = &.{},
        .description = "Chain-of-thought reasoning",
        .long_help = "SWE agent: Step-by-step logical reasoning.",
        .category = .ai,
        .examples = &.{ "tri reason 'how does VSA work'" },
        .execute = struct { fn exec (_: std.mem.Allocator, args: []const []const u8) !void {
            if (g_state) |s| utils.runSWECommand(s, .Reason, args);
        } }.exec,
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // GIT COMMANDS
    // ═══════════════════════════════════════════════════════════════════════════

    try registry.register(.{
        .name = "commit",
        .aliases = &.{},
        .description = "Git add -A && commit",
        .long_help = "Stage all changes and create a commit.",
        .category = .git,
        .examples = &.{ "tri commit 'fix bug'" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runGitCommand(a, "commit", args);
        } }.exec,
    });

    try registry.register(.{
        .name = "diff",
        .aliases = &.{},
        .description = "Git diff",
        .long_help = "Show unstaged changes.",
        .category = .git,
        .examples = &.{ "tri diff" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runGitCommand(a, "diff", args);
        } }.exec,
    });

    try registry.register(.{
        .name = "status",
        .aliases = &.{ "st" },
        .description = "Git status --short",
        .long_help = "Show working tree status.",
        .category = .git,
        .examples = &.{ "tri status" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runGitCommand(a, "status", args);
        } }.exec,
    });

    try registry.register(.{
        .name = "log",
        .aliases = &.{},
        .description = "Git log --oneline -10",
        .long_help = "Show recent commit history.",
        .category = .git,
        .examples = &.{ "tri log" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runGitCommand(a, "log", args);
        } }.exec,
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // GOLDEN CHAIN PIPELINE
    // ═══════════════════════════════════════════════════════════════════════════

    try registry.register(.{
        .name = "pipeline",
        .aliases = &.{},
        .description = "Execute 17-link Golden Chain",
        .long_help = "Run the full development pipeline from spec to deployment.",
        .category = .advanced,
        .examples = &.{ "tri pipeline run mytask" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            pipeline.runPipelineCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "decompose",
        .aliases = &.{},
        .description = "Break task into sub-tasks (Link 4)",
        .long_help = "Decompose a complex task into manageable sub-tasks.",
        .category = .advanced,
        .examples = &.{ "tri decompose 'build a web server'" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            pipeline.runDecomposeCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "plan",
        .aliases = &.{},
        .description = "Generate implementation plan (Link 5)",
        .long_help = "Create detailed implementation plan for a task.",
        .category = .advanced,
        .examples = &.{ "tri plan 'add feature'" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            pipeline.runPlanCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "spec-create",
        .aliases = &.{ "spec_create" },
        .description = "Create .vibee spec template (Link 6)",
        .long_help = "Generate a VIBEE specification file template.",
        .category = .dev,
        .examples = &.{ "tri spec-create mymodule" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            pipeline.runSpecCreateCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "loop-decide",
        .aliases = &.{ "loop_decide" },
        .description = "Loop decision: CONTINUE/EXIT (Link 17)",
        .long_help = "Decide whether to continue development loop or exit.",
        .category = .advanced,
        .examples = &.{ "tri loop-decide auto", "tri loop-decide" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            pipeline.runLoopDecideCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "verify",
        .aliases = &.{},
        .description = "Run tests + benchmarks (Links 7-11)",
        .long_help = "Execute verification pipeline: tests, benchmarks, analysis.",
        .category = .dev,
        .examples = &.{ "tri verify" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            pipeline.runVerifyCommand(a);
        } }.exec,
    });

    try registry.register(.{
        .name = "verdict",
        .aliases = &.{},
        .description = "Generate toxic verdict (Link 14)",
        .long_help = "Generate quality verdict on implementation.",
        .category = .advanced,
        .examples = &.{ "tri verdict" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            pipeline.runVerdictCommand(a);
        } }.exec,
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // VIBEE COMPILATION
    // ═══════════════════════════════════════════════════════════════════════════

    try registry.register(.{
        .name = "gen",
        .aliases = &.{ "generate" },
        .description = "Compile VIBEE spec to Zig/Verilog",
        .long_help = "Generate code from VIBEE specification files.",
        .category = .dev,
        .examples = &.{ "tri gen specs/myfile.vibee" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runGenCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "convert",
        .aliases = &.{},
        .description = "Convert between formats",
        .long_help = "Convert GGUF, WASM, and other formats.",
        .category = .dev,
        .examples = &.{ "tri convert model.gguf" },
        .execute = struct { fn exec (_: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runConvertCommand(args);
        } }.exec,
    });

    try registry.register(.{
        .name = "serve",
        .aliases = &.{ "server" },
        .description = "Start HTTP server",
        .long_help = "Launch HTTP API server.",
        .category = .dev,
        .examples = &.{ "tri serve --port 8080" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runServeCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "bench",
        .aliases = &.{ "benchmark" },
        .description = "Run performance benchmarks",
        .long_help = "Execute performance benchmarks.",
        .category = .benchmark,
        .examples = &.{ "tri bench" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            return commands.runBenchCommand(a);
        } }.exec,
    });

    try registry.register(.{
        .name = "evolve",
        .aliases = &.{},
        .description = "Evolve system",
        .long_help = "Self-improvement and evolution commands.",
        .category = .advanced,
        .examples = &.{ "tri evolve" },
        .execute = struct { fn exec (_: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runEvolveCommand(args);
        } }.exec,
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // TVC (Distributed Learning)
    // ═══════════════════════════════════════════════════════════════════════════

    try registry.register(.{
        .name = "tvc-demo",
        .aliases = &.{},
        .description = "Run TVC chat demo",
        .long_help = "Distributed learning demo with TVC corpus.",
        .category = .demo,
        .examples = &.{ "tri tvc-demo" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runTVCDemo();
        } }.exec,
    });

    try registry.register(.{
        .name = "tvc-stats",
        .aliases = &.{},
        .description = "Show TVC corpus statistics",
        .long_help = "Display TVC corpus statistics.",
        .category = .system,
        .examples = &.{ "tri tvc-stats" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runTVCStats();
        } }.exec,
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // DEMO & BENCHMARK COMMANDS (Cycles 1-52)
    // ═══════════════════════════════════════════════════════════════════════════

    // Multi-Agent System
    try registry.register(.{
        .name = "agents-demo",
        .aliases = &.{},
        .description = "Multi-Agent coordination demo",
        .long_help = "Demonstrates multi-agent coordination system.",
        .category = .demo,
        .examples = &.{ "tri agents-demo" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runAgentsDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "agents-bench",
        .aliases = &.{},
        .description = "Multi-Agent coordination benchmark",
        .long_help = "Benchmarks multi-agent coordination performance.",
        .category = .benchmark,
        .examples = &.{ "tri agents-bench" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runAgentsBench();
        } }.exec,
    });

    // Long Context
    try registry.register(.{
        .name = "context-demo",
        .aliases = &.{},
        .description = "Long context sliding window demo",
        .long_help = "Demonstrates long context handling with sliding window.",
        .category = .demo,
        .examples = &.{ "tri context-demo" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runContextDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "context-bench",
        .aliases = &.{},
        .description = "Long context benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runContextBench();
        } }.exec,
    });

    // RAG
    try registry.register(.{
        .name = "rag-demo",
        .aliases = &.{},
        .description = "Retrieval-Augmented Generation demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runRAGDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "rag-bench",
        .aliases = &.{},
        .description = "RAG benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runRAGBench();
        } }.exec,
    });

    // Voice I/O
    try registry.register(.{
        .name = "voice-demo",
        .aliases = &.{},
        .description = "Voice I/O (STT+TTS) demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runVoiceIODemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "voice-bench",
        .aliases = &.{},
        .description = "Voice I/O benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runVoiceIOBench();
        } }.exec,
    });

    // Code Sandbox
    try registry.register(.{
        .name = "sandbox-demo",
        .aliases = &.{},
        .description = "Code execution sandbox demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runSandboxDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "sandbox-bench",
        .aliases = &.{},
        .description = "Sandbox benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runSandboxBench();
        } }.exec,
    });

    // Streaming
    try registry.register(.{
        .name = "stream-demo",
        .aliases = &.{},
        .description = "Streaming multi-modal pipeline demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runStreamPipelineDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "stream-bench",
        .aliases = &.{},
        .description = "Streaming benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runStreamPipelineBench();
        } }.exec,
    });

    // Vision
    try registry.register(.{
        .name = "vision-demo",
        .aliases = &.{},
        .description = "Local vision demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runVisionDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "vision-bench",
        .aliases = &.{},
        .description = "Vision benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runVisionBench();
        } }.exec,
    });

    // Fine-tuning
    try registry.register(.{
        .name = "finetune-demo",
        .aliases = &.{},
        .description = "Fine-tuning engine demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runFineTuneDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "finetune-bench",
        .aliases = &.{},
        .description = "Fine-tuning benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runFineTuneBench();
        } }.exec,
    });

    // Batched Stealing
    try registry.register(.{
        .name = "batched-demo",
        .aliases = &.{},
        .description = "Batched stealing demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runBatchedDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "batched-bench",
        .aliases = &.{},
        .description = "Batched stealing benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runBatchedBench();
        } }.exec,
    });

    // Priority Queue
    try registry.register(.{
        .name = "priority-demo",
        .aliases = &.{},
        .description = "Priority queue demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runPriorityDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "priority-bench",
        .aliases = &.{},
        .description = "Priority queue benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runPriorityBench();
        } }.exec,
    });

    // Deadline Scheduling
    try registry.register(.{
        .name = "deadline-demo",
        .aliases = &.{},
        .description = "Deadline scheduling demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runDeadlineDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "deadline-bench",
        .aliases = &.{},
        .description = "Deadline scheduling benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runDeadlineBench();
        } }.exec,
    });

    // Multi-Modal Unified
    try registry.register(.{
        .name = "multimodal-demo",
        .aliases = &.{},
        .description = "Multi-modal unified demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runMultiModalDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "multimodal-bench",
        .aliases = &.{},
        .description = "Multi-modal unified benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runMultiModalBench();
        } }.exec,
    });

    // Tool Use
    try registry.register(.{
        .name = "tooluse-demo",
        .aliases = &.{},
        .description = "Multi-modal tool use demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runToolUseDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "tooluse-bench",
        .aliases = &.{},
        .description = "Tool use benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runToolUseBench();
        } }.exec,
    });

    // Unified Agent
    try registry.register(.{
        .name = "unified-demo",
        .aliases = &.{},
        .description = "Unified multi-modal agent demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runUnifiedAgentDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "unified-bench",
        .aliases = &.{},
        .description = "Unified agent benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runUnifiedAgentBench();
        } }.exec,
    });

    // Autonomous Agent
    try registry.register(.{
        .name = "autonomous-demo",
        .aliases = &.{},
        .description = "Autonomous agent demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runAutonomousAgentDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "autonomous-bench",
        .aliases = &.{},
        .description = "Autonomous agent benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runAutonomousAgentBench();
        } }.exec,
    });

    // Orchestration
    try registry.register(.{
        .name = "orchestration-demo",
        .aliases = &.{},
        .description = "Multi-agent orchestration demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runOrchestrationDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "orchestration-bench",
        .aliases = &.{},
        .description = "Orchestration benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runOrchestrationBench();
        } }.exec,
    });

    // MM Orchestration
    try registry.register(.{
        .name = "mm-orch-demo",
        .aliases = &.{},
        .description = "MM multi-agent orchestration demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runMMOrchDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "mm-orch-bench",
        .aliases = &.{},
        .description = "MM orchestration benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runMMOrchBench();
        } }.exec,
    });

    // Memory
    try registry.register(.{
        .name = "memory-demo",
        .aliases = &.{},
        .description = "Agent memory & cross-modal learning demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runMemoryDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "memory-bench",
        .aliases = &.{},
        .description = "Memory benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runMemoryBench();
        } }.exec,
    });

    // Persistent
    try registry.register(.{
        .name = "persist-demo",
        .aliases = &.{},
        .description = "Persistent memory & disk serialization demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runPersistDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "persist-bench",
        .aliases = &.{},
        .description = "Persistent memory benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runPersistBench();
        } }.exec,
    });

    // Spawn
    try registry.register(.{
        .name = "spawn-demo",
        .aliases = &.{},
        .description = "Dynamic agent spawning demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runSpawnDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "spawn-bench",
        .aliases = &.{},
        .description = "Spawn benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runSpawnBench();
        } }.exec,
    });

    // Cluster
    try registry.register(.{
        .name = "cluster-demo",
        .aliases = &.{},
        .description = "Distributed multi-node agents demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runClusterDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "cluster-bench",
        .aliases = &.{},
        .description = "Cluster benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runClusterBench();
        } }.exec,
    });

    // Work-stealing
    try registry.register(.{
        .name = "worksteal-demo",
        .aliases = &.{},
        .description = "Adaptive work-stealing scheduler demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runWorkStealDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "worksteal-bench",
        .aliases = &.{},
        .description = "Work-stealing benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runWorkStealBench();
        } }.exec,
    });

    // Plugin
    try registry.register(.{
        .name = "plugin-demo",
        .aliases = &.{},
        .description = "Plugin & extension system demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runPluginDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "plugin-bench",
        .aliases = &.{},
        .description = "Plugin benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runPluginBench();
        } }.exec,
    });

    // Comms
    try registry.register(.{
        .name = "comms-demo",
        .aliases = &.{},
        .description = "Agent communication protocol demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runCommsDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "comms-bench",
        .aliases = &.{},
        .description = "Communication benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runCommsBench();
        } }.exec,
    });

    // Observability
    try registry.register(.{
        .name = "observe-demo",
        .aliases = &.{},
        .description = "Observability & tracing demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runObserveDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "observe-bench",
        .aliases = &.{},
        .description = "Observability benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runObserveBench();
        } }.exec,
    });

    // Consensus
    try registry.register(.{
        .name = "consensus-demo",
        .aliases = &.{},
        .description = "Consensus & coordination demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runConsensusDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "consensus-bench",
        .aliases = &.{},
        .description = "Consensus benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runConsensusBench();
        } }.exec,
    });

    // Speculative Execution
    try registry.register(.{
        .name = "specexec-demo",
        .aliases = &.{},
        .description = "Speculative execution engine demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runSpecExecDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "specexec-bench",
        .aliases = &.{},
        .description = "Speculative execution benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runSpecExecBench();
        } }.exec,
    });

    // Governor
    try registry.register(.{
        .name = "governor-demo",
        .aliases = &.{},
        .description = "Adaptive resource governor demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runGovernorDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "governor-bench",
        .aliases = &.{},
        .description = "Governor benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runGovernorBench();
        } }.exec,
    });

    // Federated Learning
    try registry.register(.{
        .name = "fedlearn-demo",
        .aliases = &.{},
        .description = "Federated learning protocol demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runFedLearnDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "fedlearn-bench",
        .aliases = &.{},
        .description = "Federated learning benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runFedLearnBench();
        } }.exec,
    });

    // Event Sourcing
    try registry.register(.{
        .name = "eventsrc-demo",
        .aliases = &.{},
        .description = "Event sourcing & CQRS engine demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runEventSrcDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "eventsrc-bench",
        .aliases = &.{},
        .description = "Event sourcing benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runEventSrcBench();
        } }.exec,
    });

    // Capability Security
    try registry.register(.{
        .name = "capsec-demo",
        .aliases = &.{},
        .description = "Capability-based security demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runCapSecDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "capsec-bench",
        .aliases = &.{},
        .description = "Capability security benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runCapSecBench();
        } }.exec,
    });

    // Distributed Transactions
    try registry.register(.{
        .name = "dtxn-demo",
        .aliases = &.{},
        .description = "Distributed transaction coordinator demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runDTxnDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "dtxn-bench",
        .aliases = &.{},
        .description = "DTXN benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runDTxnBench();
        } }.exec,
    });

    // Cache
    try registry.register(.{
        .name = "cache-demo",
        .aliases = &.{},
        .description = "Adaptive caching & memoization demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runCacheDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "cache-bench",
        .aliases = &.{},
        .description = "Caching benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runCacheBench();
        } }.exec,
    });

    // Contract
    try registry.register(.{
        .name = "contract-demo",
        .aliases = &.{},
        .description = "Contract-based agent negotiation demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runContractDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "contract-bench",
        .aliases = &.{},
        .description = "Contract negotiation benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runContractBench();
        } }.exec,
    });

    // Workflow
    try registry.register(.{
        .name = "workflow-demo",
        .aliases = &.{},
        .description = "Temporal workflow engine demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runWorkflowDemo();
        } }.exec,
    });
    try registry.register(.{
        .name = "workflow-bench",
        .aliases = &.{},
        .description = "Workflow benchmark",
        .category = .benchmark,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            demos.runWorkflowBench();
        } }.exec,
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // DISTRIBUTED INFERENCE
    // ═══════════════════════════════════════════════════════════════════════════

    try registry.register(.{
        .name = "distributed",
        .aliases = &.{},
        .description = "Distributed inference",
        .category = .advanced,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runDistributedCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "multi-cluster",
        .aliases = &.{ "multi_cluster" },
        .description = "Multi-cluster orchestration",
        .category = .advanced,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runMultiClusterCommand(a, args);
        } }.exec,
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // CODEBASE CONTEXT (Cycle 92)
    // ═══════════════════════════════════════════════════════════════════════════

    try registry.register(.{
        .name = "analyze",
        .aliases = &.{},
        .description = "Analyze codebase structure",
        .category = .dev,
        .execute = stateAdapter1(tri_context.runAnalyzeCommand),
    });

    try registry.register(.{
        .name = "search",
        .aliases = &.{ "search-cmd" },
        .description = "Search codebase",
        .category = .dev,
        .execute = stateAdapter(tri_context.runSearchCommand),
    });

    try registry.register(.{
        .name = "context-info",
        .aliases = &.{ "context_info" },
        .description = "Show codebase context info",
        .category = .system,
        .execute = stateAdapter1(tri_context.runContextInfoCommand),
    });

    try registry.register(.{
        .name = "intelligence",
        .aliases = &.{},
        .description = "Sacred Intelligence system",
        .category = .sacred,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            if (g_state) |s| tri_context.runIntelligenceCommand(a, s, args) catch |err| {
                std.debug.print("Error: {}\n", .{err});
            };
        } }.exec,
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // DEV UTILITIES
    // ═══════════════════════════════════════════════════════════════════════════

    try registry.register(.{
        .name = "doctor",
        .aliases = &.{},
        .description = "Check system health",
        .category = .system,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            return commands.runDoctorCommand(a);
        } }.exec,
    });

    try registry.register(.{
        .name = "clean",
        .aliases = &.{},
        .description = "Clean build artifacts",
        .category = .system,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            return commands.runCleanCommand(a);
        } }.exec,
    });

    try registry.register(.{
        .name = "fmt",
        .aliases = &.{ "format" },
        .description = "Format code",
        .category = .dev,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            return commands.runFmtCommand(a);
        } }.exec,
    });

    try registry.register(.{
        .name = "stats",
        .aliases = &.{ "stats-cmd" },
        .description = "Show code statistics",
        .category = .system,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            return commands.runStatsCommand(a);
        } }.exec,
    });

    try registry.register(.{
        .name = "igla",
        .aliases = &.{},
        .description = "IGLA hybrid chat",
        .category = .ai,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            return commands.runIglaCommand(a);
        } }.exec,
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // SACRED INTELLIGENCE (Cycle 98)
    // ═══════════════════════════════════════════════════════════════════════════

    try registry.register(.{
        .name = "identity",
        .aliases = &.{},
        .description = "Sacred identity",
        .category = .sacred,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runIdentityCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "swarm",
        .aliases = &.{},
        .description = "Sacred swarm intelligence",
        .category = .sacred,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runSwarmCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "govern",
        .aliases = &.{},
        .description = "Sacred governance",
        .category = .sacred,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runGovernCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "dashboard",
        .aliases = &.{},
        .description = "Sacred dashboard",
        .category = .system,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runDashboardCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "omega",
        .aliases = &.{},
        .description = "Omega phase",
        .category = .sacred,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runOmegaCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "math-agent",
        .aliases = &.{ "math_agent" },
        .description = "Math agent",
        .category = .ai,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runMathAgentCommand(a, args);
        } }.exec,
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // TEMPORAL ENGINE (Order #030-031)
    // ═══════════════════════════════════════════════════════════════════════════

    try registry.register(.{
        .name = "time",
        .aliases = &.{},
        .description = "Temporal engine",
        .category = .advanced,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runTimeCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "install",
        .aliases = &.{},
        .description = "Install dependencies",
        .category = .system,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            return commands.runInstallCommand(a);
        } }.exec,
    });

    try registry.register(.{
        .name = "build",
        .aliases = &.{ "build-cmd" },
        .description = "Build project",
        .category = .dev,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            return commands.runBuildCommand(a);
        } }.exec,
    });

    try registry.register(.{
        .name = "deck",
        .aliases = &.{ "deck-generate" },
        .description = "Generate flash deck",
        .category = .dev,
        .execute = struct { fn exec (a: std.mem.Allocator, _: []const []const u8) !void {
            return commands.runDeckCommand(a);
        } }.exec,
    });

    try registry.register(.{
        .name = "fpga-demo",
        .aliases = &.{ "fpga_demo" },
        .description = "FPGA demo",
        .category = .demo,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runFpgaDemoCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "sacred-full-cycle",
        .aliases = &.{ "sacred_full_cycle" },
        .description = "Sacred full cycle",
        .category = .sacred,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            return commands.runSacredFullCycleCommand(a);
        } }.exec,
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // QUANTUM TRINITY (Order #032)
    // ═══════════════════════════════════════════════════════════════════════════

    try registry.register(.{
        .name = "quantum",
        .aliases = &.{},
        .description = "Quantum Trinity",
        .category = .sacred,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runQuantumCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "release-cosmic",
        .aliases = &.{ "release_cosmic" },
        .description = "Release cosmic energy",
        .category = .sacred,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            return commands.runReleaseCosmicCommand(a);
        } }.exec,
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // OMEGA PHASE (Order #033)
    // ═══════════════════════════════════════════════════════════════════════════

    try registry.register(.{
        .name = "omega-cmd",
        .aliases = &.{ "omega_cmd" },
        .description = "Omega command",
        .category = .sacred,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runOmegaPhaseCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "all-cmd",
        .aliases = &.{ "all_cmd" },
        .description = "All command",
        .category = .sacred,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runAllCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "holo-cmd",
        .aliases = &.{ "holo_cmd" },
        .description = "Holo command",
        .category = .sacred,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runHoloCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "release-absolute",
        .aliases = &.{ "release_absolute" },
        .description = "Release absolute",
        .category = .sacred,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            return commands.runReleaseAbsoluteCommand(a);
        } }.exec,
    });

    try registry.register(.{
        .name = "omega-evolve",
        .aliases = &.{ "omega_evolve" },
        .description = "Omega evolve",
        .category = .sacred,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = args;
            return commands.runOmegaEvolveCommand(a);
        } }.exec,
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // TRINITY OS (Order #034)
    // ═══════════════════════════════════════════════════════════════════════════

    try registry.register(.{
        .name = "launch",
        .aliases = &.{},
        .description = "Launch TRINITY OS",
        .category = .advanced,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runLaunchCommand(a, args);
        } }.exec,
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // NEEDLE - Structural Editor
    // ═══════════════════════════════════════════════════════════════════════════

    try registry.register(.{
        .name = "needle",
        .aliases = &.{},
        .description = "Structural editor core",
        .category = .dev,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runNeedleCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "needle-search",
        .aliases = &.{ "needle_search" },
        .description = "Needle search",
        .category = .dev,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runNeedleSearchCommand(a, args);
        } }.exec,
    });

    try registry.register(.{
        .name = "needle-check",
        .aliases = &.{ "needle_check" },
        .description = "Needle check",
        .category = .dev,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runNeedleCheckCommand(a, args);
        } }.exec,
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // INFO COMMANDS
    // ═══════════════════════════════════════════════════════════════════════════

    try registry.register(.{
        .name = "deps",
        .aliases = &.{},
        .description = "Show dependencies",
        .category = .system,
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            utils.printInfo();
        } }.exec,
    });

    try registry.register(.{
        .name = "info",
        .aliases = &.{},
        .description = "System information",
        .category = .system,
        .examples = &.{ "tri info" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            utils.printInfo();
        } }.exec,
    });

    try registry.register(.{
        .name = "version",
        .aliases = &.{ "v", "--version" },
        .description = "Show version",
        .category = .system,
        .examples = &.{ "tri version" },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            _ = args;
            utils.printVersion();
        } }.exec,
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // COMPLETION - Shell completion generation
    // ═══════════════════════════════════════════════════════════════════════════

    try registry.register(.{
        .name = "completion",
        .aliases = &.{},
        .description = "Generate shell completion scripts",
        .long_help = "Generate bash/zsh/fish completion scripts for tab completion.",
        .category = .system,
        .examples = &.{
            "tri completion --bash",
            "tri completion --zsh",
            "tri completion --install",
        },
        .execute = struct { fn exec (_: std.mem.Allocator, args: []const []const u8) !void {
            if (args.len == 0) {
                var registry_ = CommandRegistry.init(std.heap.page_allocator) catch return;
                defer registry_.deinit();
                const cg = @import("tri_completion.zig").CompletionGenerator{ .registry = &registry_, .tri_path = "tri" };
                try cg.printInstallHelp();
                return;
            }

            if (std.mem.eql(u8, args[0], "--install")) {
                var registry_ = CommandRegistry.init(std.heap.page_allocator) catch return;
                defer registry_.deinit();
                const cg = @import("tri_completion.zig").CompletionGenerator{ .registry = &registry_, .tri_path = "tri" };
                try cg.installCompletions();
            } else {
                std.debug.print("Usage: tri completion [--bash|--zsh|--fish|--install]\n", .{});
            }
        } }.exec,
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // HELP - Help system
    // ═══════════════════════════════════════════════════════════════════════════

    try registry.register(.{
        .name = "help",
        .aliases = &.{ "h", "?" },
        .description = "Show help information",
        .long_help = "Display help for commands.\nUse: tri help --search <query> or tri help --category <name>",
        .category = .system,
        .examples = &.{
            "tri help",
            "tri help --search dna",
            "tri help --category science",
            "tri bio --help",
        },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            _ = a;
            if (args.len >= 2 and std.mem.eql(u8, args[1], "--search")) {
                // Search functionality
                std.debug.print("Search: {s}\n", .{args[0]});
            } else if (args.len >= 2 and std.mem.eql(u8, args[1], "--category")) {
                // Category functionality
                std.debug.print("Category: {s}\n", .{args[0]});
            } else {
                // Default: show all categories
                const HelpSystem = @import("tri_help.zig").HelpSystem;
                var registry_ = CommandRegistry.init(std.heap.page_allocator) catch return;
                defer registry_.deinit();
                const hs = HelpSystem{ .registry = &registry_ };
                try hs.printCategorized();
            }
        } }.exec,
    });

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST REPL (Cycle 101) - Special handling
    // ═══════════════════════════════════════════════════════════════════════════

    try registry.register(.{
        .name = "test-repl",
        .aliases = &.{ "test_repl" },
        .description = "Test REPL (Cycle 101)",
        .long_help = "Interactive test REPL with --repl, --generate, --coverage flags.",
        .category = .dev,
        .examples = &.{
            "tri test --repl",
            "tri test -r",
            "tri test --generate",
        },
        .execute = struct { fn exec (a: std.mem.Allocator, args: []const []const u8) !void {
            return commands.runReplTestCommand(a, args);
        } }.exec,
    });
}
