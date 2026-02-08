// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - Utility Functions
// ═══════════════════════════════════════════════════════════════════════════════
//
// Banner, help, info, version, REPL, parseCommand, and input processing.
// Extracted from main.zig for faster compilation.
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("tri_colors.zig");
const trinity_swe = @import("trinity_swe");
const igla_hybrid_chat = @import("igla_hybrid_chat");
const igla_coder = @import("igla_coder");
const streaming = @import("streaming.zig");
const multilingual = @import("multilingual.zig");

const GREEN = colors.GREEN;
const GOLDEN = colors.GOLDEN;
const WHITE = colors.WHITE;
const GRAY = colors.GRAY;
const RED = colors.RED;
const CYAN = colors.CYAN;
const RESET = colors.RESET;
const VERSION = colors.VERSION;

pub const Command = enum {
    none, // Interactive REPL
    chat,
    code,
    gen,
    fix,
    explain,
    test_cmd,
    doc,
    refactor,
    reason,
    convert,
    serve,
    bench,
    evolve,
    // Git commands
    commit,
    diff,
    status,
    log,
    // Golden Chain Pipeline
    pipeline,
    decompose,
    plan,
    verify,
    verdict,
    // TVC (Distributed Learning)
    tvc_demo,
    tvc_stats,
    // Multi-Agent System
    agents_demo,
    agents_bench,
    // Long Context
    context_demo,
    context_bench,
    // RAG (Retrieval-Augmented Generation)
    rag_demo,
    rag_bench,
    // Voice I/O (TTS + STT)
    voice_demo,
    voice_bench,
    // Code Execution Sandbox
    sandbox_demo,
    sandbox_bench,
    // Streaming Output
    stream_demo,
    stream_bench,
    // Local Vision
    vision_demo,
    vision_bench,
    // Fine-Tuning Engine
    finetune_demo,
    finetune_bench,
    // Batched Stealing
    batched_demo,
    batched_bench,
    // Priority Queue
    priority_demo,
    priority_bench,
    // Deadline Scheduling
    deadline_demo,
    deadline_bench,
    // Multi-Modal Unified (Cycle 26)
    multimodal_demo,
    multimodal_bench,
    // Multi-Modal Tool Use (Cycle 27)
    tooluse_demo,
    tooluse_bench,
    // Unified Multi-Modal Agent (Cycle 30)
    unified_demo,
    unified_bench,
    // Autonomous Agent (Cycle 31)
    autonomous_demo,
    autonomous_bench,
    // Multi-Agent Orchestration (Cycle 32)
    orchestration_demo,
    orchestration_bench,
    // MM Multi-Agent Orchestration (Cycle 33)
    mm_orch_demo,
    mm_orch_bench,
    // Agent Memory & Cross-Modal Learning (Cycle 34)
    memory_demo,
    memory_bench,
    // Persistent Memory & Disk Serialization (Cycle 35)
    persist_demo,
    persist_bench,
    // Dynamic Agent Spawning & Load Balancing (Cycle 36)
    spawn_demo,
    spawn_bench,
    // Distributed Multi-Node Agents (Cycle 37)
    cluster_demo,
    cluster_bench,
    // Adaptive Work-Stealing Scheduler (Cycle 39)
    worksteal_demo,
    worksteal_bench,
    // Plugin & Extension System (Cycle 40)
    plugin_demo,
    plugin_bench,
    // Agent Communication Protocol (Cycle 41)
    comms_demo,
    comms_bench,
    // Observability & Tracing System (Cycle 42)
    observe_demo,
    observe_bench,
    // Consensus & Coordination Protocol (Cycle 43)
    consensus_demo,
    consensus_bench,
    // Speculative Execution Engine (Cycle 44)
    specexec_demo,
    specexec_bench,
    // Adaptive Resource Governor (Cycle 45)
    governor_demo,
    governor_bench,
    // Federated Learning Protocol (Cycle 46)
    fedlearn_demo,
    fedlearn_bench,
    // Event Sourcing & CQRS Engine (Cycle 47)
    eventsrc_demo,
    eventsrc_bench,
    // Capability-Based Security Model (Cycle 48)
    capsec_demo,
    capsec_bench,
    // Distributed Transaction Coordinator (Cycle 49)
    dtxn_demo,
    dtxn_bench,
    // Adaptive Caching & Memoization (Cycle 50)
    cache_demo,
    cache_bench,
    // Contract-Based Agent Negotiation (Cycle 51)
    contract_demo,
    contract_bench,
    // Temporal Workflow Engine (Cycle 52)
    workflow_demo,
    workflow_bench,
    // Distributed Inference
    distributed,
    // Info
    info,
    version,
    help,
};

pub const CLIState = struct {
    allocator: std.mem.Allocator,
    agent: trinity_swe.TrinitySWEAgent,
    chat_agent: igla_hybrid_chat.IglaHybridChat,
    coder: igla_coder.IglaLocalCoder,
    mode: trinity_swe.SWETaskType,
    language: trinity_swe.Language,
    verbose: bool,
    running: bool,
    stream_enabled: bool,

    const Self = @This();

    /// Default model path for auto-detection
    const DEFAULT_MODEL_PATH = "models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf";

    pub fn init(allocator: std.mem.Allocator) !Self {
        // Auto-detect model path
        const model_path: ?[]const u8 = blk: {
            std.fs.cwd().access(DEFAULT_MODEL_PATH, .{}) catch break :blk null;
            break :blk DEFAULT_MODEL_PATH;
        };

        return Self{
            .allocator = allocator,
            .agent = try trinity_swe.TrinitySWEAgent.init(allocator),
            .chat_agent = try igla_hybrid_chat.IglaHybridChat.init(allocator, model_path),
            .coder = igla_coder.IglaLocalCoder.init(allocator),
            .mode = .Explain,
            .language = .Zig,
            .verbose = true,
            .running = true,
            .stream_enabled = false,
        };
    }

    pub fn deinit(self: *Self) void {
        self.agent.deinit();
        self.chat_agent.deinit();
    }
};

pub fn printBanner() void {
    std.debug.print("\n", .{});
    std.debug.print("{s}╔══════════════════════════════════════════════════════════════╗{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}║              TRI CLI v{s} - Trinity Unified                   ║{s}\n", .{ GREEN, VERSION, RESET });
    std.debug.print("{s}║     100% Local AI | Code | Chat | SWE Agent                  ║{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}║     {s}φ² + 1/φ² = 3 = TRINITY{s}                                   ║{s}\n", .{ GREEN, GOLDEN, GREEN, RESET });
    std.debug.print("{s}╚══════════════════════════════════════════════════════════════╝{s}\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});
}

pub fn printHelp() void {
    std.debug.print("\n{s}TRI CLI - Trinity Unified Command Line{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    std.debug.print("{s}USAGE:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri                         Interactive REPL (default)\n", .{});
    std.debug.print("  tri <command> [args...]     Run specific command\n\n", .{});

    std.debug.print("{s}COMMANDS:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}chat{s} [--stream] <msg>       Interactive chat (--stream for typing effect)\n", .{ GREEN, RESET });
    std.debug.print("  {s}code{s} [--stream] <prompt>    Generate code (--stream for typing effect)\n", .{ GREEN, RESET });
    std.debug.print("  {s}gen{s} <spec.vibee>            Compile VIBEE spec to Zig/Verilog\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}SWE AGENT:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}fix{s} <file>                  Detect and fix bugs\n", .{ GREEN, RESET });
    std.debug.print("  {s}explain{s} <file|prompt>       Explain code or concept\n", .{ GREEN, RESET });
    std.debug.print("  {s}test{s} <file>                 Generate tests\n", .{ GREEN, RESET });
    std.debug.print("  {s}doc{s} <file>                  Generate documentation\n", .{ GREEN, RESET });
    std.debug.print("  {s}refactor{s} <file>             Suggest refactoring\n", .{ GREEN, RESET });
    std.debug.print("  {s}reason{s} <prompt>             Chain-of-thought reasoning\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}TOOLS:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}gen{s} <spec.vibee>            VIBEE → Zig/Verilog compiler\n", .{ GREEN, RESET });
    std.debug.print("  {s}convert{s} <file>              Convert WASM/Binary → Ternary\n", .{ GREEN, RESET });
    std.debug.print("  {s}serve{s} --model <path>        Start HTTP API server\n", .{ GREEN, RESET });
    std.debug.print("  {s}bench{s}                       Run performance benchmarks\n", .{ GREEN, RESET });
    std.debug.print("  {s}evolve{s} [--dim N]            Evolve fingerprint (Firebird)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}GIT:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}status{s}                      Git status --short\n", .{ GREEN, RESET });
    std.debug.print("  {s}diff{s}                        Git diff\n", .{ GREEN, RESET });
    std.debug.print("  {s}log{s}                         Git log --oneline -10\n", .{ GREEN, RESET });
    std.debug.print("  {s}commit{s} <message>            Git add -A && commit\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}GOLDEN CHAIN:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}pipeline run{s} <task>         Execute 17-link development cycle (incl TVC)\n", .{ GREEN, RESET });
    std.debug.print("  {s}pipeline status{s}             Show pipeline state\n", .{ GREEN, RESET });
    std.debug.print("  {s}decompose{s} <task>            Break task into sub-tasks\n", .{ GREEN, RESET });
    std.debug.print("  {s}verify{s}                      Run tests + benchmarks (Links 7-11)\n", .{ GREEN, RESET });
    std.debug.print("  {s}verdict{s}                     Generate toxic verdict (Link 14)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}TVC (DISTRIBUTED):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}tvc-demo{s}                    Run TVC chat demo (distributed learning)\n", .{ GREEN, RESET });
    std.debug.print("  {s}tvc-stats{s}                   Show TVC corpus statistics\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}MULTI-AGENT:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}agents-demo{s}                 Run multi-agent coordination demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}agents-bench{s}                Run multi-agent benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}LONG CONTEXT:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}context-demo{s}                Run long context demo (sliding window)\n", .{ GREEN, RESET });
    std.debug.print("  {s}context-bench{s}               Run context benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}RAG (RETRIEVAL):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}rag-demo{s}                    Run RAG demo (local retrieval)\n", .{ GREEN, RESET });
    std.debug.print("  {s}rag-bench{s}                   Run RAG benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}VOICE I/O MULTI-MODAL (Cycle 29):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}voice-demo{s}                  Run voice I/O multi-modal demo (STT+TTS+cross-modal)\n", .{ GREEN, RESET });
    std.debug.print("  {s}voice-bench{s}                 Run voice I/O benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}CODE SANDBOX:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}sandbox-demo{s}                Run code sandbox demo (safe execution)\n", .{ GREEN, RESET });
    std.debug.print("  {s}sandbox-bench{s}               Run sandbox benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}STREAMING MULTI-MODAL PIPELINE (Cycle 38):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}stream-demo, pipeline{s}       Run streaming multi-modal pipeline demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}stream-bench{s}                Run streaming pipeline benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}VISION UNDERSTANDING (Cycle 28):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}vision-demo{s}                 Run vision understanding demo (image analysis)\n", .{ GREEN, RESET });
    std.debug.print("  {s}vision-bench{s}                Run vision understanding benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}FINE-TUNING:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}finetune-demo{s}               Run fine-tuning demo (custom model adaptation)\n", .{ GREEN, RESET });
    std.debug.print("  {s}finetune-bench{s}              Run fine-tuning benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}MULTI-MODAL UNIFIED (Cycle 26):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}multimodal-demo{s}             Run multi-modal unified demo (text+vision+voice+code)\n", .{ GREEN, RESET });
    std.debug.print("  {s}multimodal-bench{s}            Run multi-modal benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}MULTI-MODAL TOOL USE (Cycle 27):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}tooluse-demo{s}               Run tool use demo (file/code/system from any modality)\n", .{ GREEN, RESET });
    std.debug.print("  {s}tooluse-bench{s}              Run tool use benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}UNIFIED MULTI-MODAL AGENT (Cycle 30):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}unified-demo{s}               Run unified agent demo (text+vision+voice+code+tools)\n", .{ GREEN, RESET });
    std.debug.print("  {s}unified-bench{s}              Run unified agent benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}AUTONOMOUS AGENT (Cycle 31):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}auto-demo{s}                  Run autonomous agent demo (self-directed task execution)\n", .{ GREEN, RESET });
    std.debug.print("  {s}auto-bench{s}                 Run autonomous agent benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}MULTI-AGENT ORCHESTRATION (Cycle 32):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}orch-demo{s}                  Run multi-agent orchestration demo (coordinator+specialists)\n", .{ GREEN, RESET });
    std.debug.print("  {s}orch-bench{s}                 Run multi-agent orchestration benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}MM MULTI-AGENT ORCHESTRATION (Cycle 33):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}mmo-demo{s}                   Run multi-modal multi-agent demo (all modalities+agents)\n", .{ GREEN, RESET });
    std.debug.print("  {s}mmo-bench{s}                  Run multi-modal multi-agent benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}AGENT MEMORY & CROSS-MODAL LEARNING (Cycle 34):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}memory-demo{s}                 Run agent memory & learning demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}memory-bench{s}                Run agent memory benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}PERSISTENT MEMORY & DISK SERIALIZATION (Cycle 35):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}persist-demo{s}                Run persistent memory demo (save/load TRMM)\n", .{ GREEN, RESET });
    std.debug.print("  {s}persist-bench{s}               Run persistent memory benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}DYNAMIC AGENT SPAWNING & LOAD BALANCING (Cycle 36):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}spawn-demo{s}                  Run dynamic agent spawning demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}spawn-bench{s}                 Run dynamic spawning benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}DISTRIBUTED MULTI-NODE AGENTS (Cycle 37):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}cluster-demo{s}                Run distributed multi-node agents demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}cluster-bench{s}               Run distributed agents benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}ADAPTIVE WORK-STEALING SCHEDULER (Cycle 39):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}worksteal-demo, steal{s}       Run adaptive work-stealing scheduler demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}worksteal-bench{s}             Run work-stealing benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}PLUGIN & EXTENSION SYSTEM (Cycle 40):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}plugin-demo, plugin, ext{s}    Run plugin & extension system demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}plugin-bench{s}                Run plugin system benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}AGENT COMMUNICATION PROTOCOL (Cycle 41):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}comms-demo, comms, msg{s}      Run agent communication protocol demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}comms-bench{s}                 Run communication benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}OBSERVABILITY & TRACING SYSTEM (Cycle 42):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}observe-demo, observe, otel{s}  Run observability & tracing demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}observe-bench{s}                Run observability benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}CONSENSUS & COORDINATION PROTOCOL (Cycle 43):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}consensus-demo, consensus, raft{s} Run consensus & coordination demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}consensus-bench{s}              Run consensus benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}SPECULATIVE EXECUTION ENGINE (Cycle 44):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}specexec-demo, specexec, spec{s} Run speculative execution demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}specexec-bench{s}               Run speculative execution benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}ADAPTIVE RESOURCE GOVERNOR (Cycle 45):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}governor-demo, governor, gov{s}  Run adaptive resource governor demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}governor-bench{s}               Run resource governor benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}FEDERATED LEARNING PROTOCOL (Cycle 46):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}fedlearn-demo, fedlearn, fl{s}  Run federated learning demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}fedlearn-bench{s}               Run federated learning benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}EVENT SOURCING & CQRS ENGINE (Cycle 47):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}eventsrc-demo, eventsrc, es{s}  Run event sourcing & CQRS demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}eventsrc-bench{s}               Run event sourcing benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}CAPABILITY-BASED SECURITY MODEL (Cycle 48):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}capsec-demo, capsec, sec{s}     Run capability security demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}capsec-bench{s}                 Run capability security benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}DISTRIBUTED TRANSACTION COORDINATOR (Cycle 49):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}dtxn-demo, dtxn, txn{s}         Run distributed transaction demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}dtxn-bench{s}                   Run distributed transaction benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}ADAPTIVE CACHING & MEMOIZATION (Cycle 50):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}cache-demo, cache, memo{s}       Run adaptive caching demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}cache-bench{s}                   Run adaptive caching benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}CONTRACT-BASED AGENT NEGOTIATION (Cycle 51):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}contract-demo, contract, sla{s}  Run contract negotiation demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}contract-bench{s}                Run contract negotiation benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}TEMPORAL WORKFLOW ENGINE (Cycle 52):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}workflow-demo, workflow, wf{s}    Run temporal workflow demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}workflow-bench{s}                 Run temporal workflow benchmark (Needle check)\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}INFO:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}info{s}                        System information\n", .{ GREEN, RESET });
    std.debug.print("  {s}version{s}                     Show version\n", .{ GREEN, RESET });
    std.debug.print("  {s}help{s}                        This help message\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}REPL COMMANDS:{s} (in interactive mode)\n", .{ CYAN, RESET });
    std.debug.print("  /chat /code /fix /explain /test /doc /reason\n", .{});
    std.debug.print("  /zig /python /rust /js    Set language\n", .{});
    std.debug.print("  /stats /verbose /help /quit\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("{s}MULTILINGUAL:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  Auto-detects: Russian, Chinese, English\n", .{});
    std.debug.print("  Examples:\n", .{});
    std.debug.print("    tri code \"напиши функцию фибоначчи\"    [RU]\n", .{});
    std.debug.print("    tri code \"写一个斐波那契函数\"           [ZH]\n", .{});
    std.debug.print("    tri code \"write fibonacci function\"   [EN]\n", .{});
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

pub fn printVersion() void {
    std.debug.print("{s}TRI CLI{s} v{s}\n", .{ GREEN, RESET, VERSION });
    std.debug.print("Trinity Unified Command Line Interface\n", .{});
    std.debug.print("φ² + 1/φ² = 3 = TRINITY\n", .{});
}

pub fn printInfo() void {
    std.debug.print("\n{s}═══ System Information ═══{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  TRI CLI Version: {s}\n", .{VERSION});
    std.debug.print("  Platform: {s}\n", .{@tagName(@import("builtin").os.tag)});
    std.debug.print("  Architecture: {s}\n", .{@tagName(@import("builtin").cpu.arch)});
    std.debug.print("  Mode: 100%% LOCAL\n", .{});
    std.debug.print("  Vocabulary: 50000 words\n", .{});
    std.debug.print("  Code Templates: 50+\n", .{});
    std.debug.print("  Chat Patterns: 60+\n", .{});
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

pub fn parseCommand(arg: []const u8) Command {
    if (std.mem.eql(u8, arg, "chat")) return .chat;
    if (std.mem.eql(u8, arg, "code")) return .code;
    if (std.mem.eql(u8, arg, "gen")) return .gen;
    if (std.mem.eql(u8, arg, "fix")) return .fix;
    if (std.mem.eql(u8, arg, "explain")) return .explain;
    if (std.mem.eql(u8, arg, "test")) return .test_cmd;
    if (std.mem.eql(u8, arg, "doc")) return .doc;
    if (std.mem.eql(u8, arg, "refactor")) return .refactor;
    if (std.mem.eql(u8, arg, "reason")) return .reason;
    if (std.mem.eql(u8, arg, "convert")) return .convert;
    if (std.mem.eql(u8, arg, "serve")) return .serve;
    if (std.mem.eql(u8, arg, "bench")) return .bench;
    if (std.mem.eql(u8, arg, "evolve")) return .evolve;
    // Git commands
    if (std.mem.eql(u8, arg, "commit")) return .commit;
    if (std.mem.eql(u8, arg, "diff")) return .diff;
    if (std.mem.eql(u8, arg, "status")) return .status;
    if (std.mem.eql(u8, arg, "log")) return .log;
    // Golden Chain Pipeline
    if (std.mem.eql(u8, arg, "pipeline") or std.mem.eql(u8, arg, "chain")) return .pipeline;
    if (std.mem.eql(u8, arg, "decompose")) return .decompose;
    if (std.mem.eql(u8, arg, "plan")) return .plan;
    if (std.mem.eql(u8, arg, "verify")) return .verify;
    if (std.mem.eql(u8, arg, "verdict")) return .verdict;
    // TVC (Distributed Learning)
    if (std.mem.eql(u8, arg, "tvc-demo") or std.mem.eql(u8, arg, "tvc")) return .tvc_demo;
    if (std.mem.eql(u8, arg, "tvc-stats")) return .tvc_stats;
    // Multi-Agent System
    if (std.mem.eql(u8, arg, "agents-demo") or std.mem.eql(u8, arg, "agents")) return .agents_demo;
    if (std.mem.eql(u8, arg, "agents-bench")) return .agents_bench;
    // Long Context
    if (std.mem.eql(u8, arg, "context-demo") or std.mem.eql(u8, arg, "context")) return .context_demo;
    if (std.mem.eql(u8, arg, "context-bench")) return .context_bench;
    // RAG
    if (std.mem.eql(u8, arg, "rag-demo") or std.mem.eql(u8, arg, "rag")) return .rag_demo;
    if (std.mem.eql(u8, arg, "rag-bench")) return .rag_bench;
    // Voice I/O
    if (std.mem.eql(u8, arg, "voice-demo") or std.mem.eql(u8, arg, "voice") or std.mem.eql(u8, arg, "mic")) return .voice_demo;
    if (std.mem.eql(u8, arg, "voice-bench") or std.mem.eql(u8, arg, "mic-bench")) return .voice_bench;
    // Code Sandbox
    if (std.mem.eql(u8, arg, "sandbox-demo") or std.mem.eql(u8, arg, "sandbox")) return .sandbox_demo;
    if (std.mem.eql(u8, arg, "sandbox-bench")) return .sandbox_bench;
    // Streaming Multi-Modal Pipeline (Cycle 38)
    if (std.mem.eql(u8, arg, "stream-demo") or std.mem.eql(u8, arg, "stream") or std.mem.eql(u8, arg, "pipeline")) return .stream_demo;
    if (std.mem.eql(u8, arg, "stream-bench") or std.mem.eql(u8, arg, "pipeline-bench")) return .stream_bench;
    // Local Vision
    if (std.mem.eql(u8, arg, "vision-demo") or std.mem.eql(u8, arg, "vision") or std.mem.eql(u8, arg, "eye")) return .vision_demo;
    if (std.mem.eql(u8, arg, "vision-bench") or std.mem.eql(u8, arg, "eye-bench")) return .vision_bench;
    // Fine-Tuning Engine
    if (std.mem.eql(u8, arg, "finetune-demo") or std.mem.eql(u8, arg, "finetune")) return .finetune_demo;
    if (std.mem.eql(u8, arg, "finetune-bench")) return .finetune_bench;
    // Batched Stealing
    if (std.mem.eql(u8, arg, "batched-demo") or std.mem.eql(u8, arg, "batched")) return .batched_demo;
    if (std.mem.eql(u8, arg, "batched-bench")) return .batched_bench;
    // Priority Queue
    if (std.mem.eql(u8, arg, "priority-demo") or std.mem.eql(u8, arg, "priority")) return .priority_demo;
    if (std.mem.eql(u8, arg, "priority-bench")) return .priority_bench;
    // Deadline Scheduling
    if (std.mem.eql(u8, arg, "deadline-demo") or std.mem.eql(u8, arg, "deadline")) return .deadline_demo;
    if (std.mem.eql(u8, arg, "deadline-bench")) return .deadline_bench;
    // Multi-Modal Unified (Cycle 26)
    if (std.mem.eql(u8, arg, "multimodal-demo") or std.mem.eql(u8, arg, "multimodal") or std.mem.eql(u8, arg, "mm")) return .multimodal_demo;
    if (std.mem.eql(u8, arg, "multimodal-bench") or std.mem.eql(u8, arg, "mm-bench")) return .multimodal_bench;
    // Multi-Modal Tool Use (Cycle 27)
    if (std.mem.eql(u8, arg, "tooluse-demo") or std.mem.eql(u8, arg, "tooluse") or std.mem.eql(u8, arg, "tools")) return .tooluse_demo;
    if (std.mem.eql(u8, arg, "tooluse-bench") or std.mem.eql(u8, arg, "tools-bench")) return .tooluse_bench;
    // Unified Multi-Modal Agent (Cycle 30)
    if (std.mem.eql(u8, arg, "unified-demo") or std.mem.eql(u8, arg, "unified") or std.mem.eql(u8, arg, "agent")) return .unified_demo;
    if (std.mem.eql(u8, arg, "unified-bench") or std.mem.eql(u8, arg, "agent-bench")) return .unified_bench;
    // Autonomous Agent (Cycle 31)
    if (std.mem.eql(u8, arg, "auto-demo") or std.mem.eql(u8, arg, "auto") or std.mem.eql(u8, arg, "autonomous")) return .autonomous_demo;
    if (std.mem.eql(u8, arg, "auto-bench") or std.mem.eql(u8, arg, "autonomous-bench")) return .autonomous_bench;
    // Multi-Agent Orchestration (Cycle 32)
    if (std.mem.eql(u8, arg, "orch-demo") or std.mem.eql(u8, arg, "orch") or std.mem.eql(u8, arg, "orchestrate")) return .orchestration_demo;
    if (std.mem.eql(u8, arg, "orch-bench") or std.mem.eql(u8, arg, "orchestrate-bench")) return .orchestration_bench;
    // MM Multi-Agent Orchestration (Cycle 33)
    if (std.mem.eql(u8, arg, "mmo-demo") or std.mem.eql(u8, arg, "mmo") or std.mem.eql(u8, arg, "mm-orch")) return .mm_orch_demo;
    if (std.mem.eql(u8, arg, "mmo-bench") or std.mem.eql(u8, arg, "mm-orch-bench")) return .mm_orch_bench;
    // Agent Memory & Cross-Modal Learning (Cycle 34)
    if (std.mem.eql(u8, arg, "memory-demo") or std.mem.eql(u8, arg, "memory") or std.mem.eql(u8, arg, "mem")) return .memory_demo;
    if (std.mem.eql(u8, arg, "memory-bench") or std.mem.eql(u8, arg, "mem-bench")) return .memory_bench;
    // Persistent Memory & Disk Serialization (Cycle 35)
    if (std.mem.eql(u8, arg, "persist-demo") or std.mem.eql(u8, arg, "persist") or std.mem.eql(u8, arg, "save")) return .persist_demo;
    if (std.mem.eql(u8, arg, "persist-bench") or std.mem.eql(u8, arg, "persist-bench") or std.mem.eql(u8, arg, "save-bench")) return .persist_bench;
    // Dynamic Agent Spawning & Load Balancing (Cycle 36)
    if (std.mem.eql(u8, arg, "spawn-demo") or std.mem.eql(u8, arg, "spawn") or std.mem.eql(u8, arg, "pool")) return .spawn_demo;
    if (std.mem.eql(u8, arg, "spawn-bench") or std.mem.eql(u8, arg, "pool-bench")) return .spawn_bench;
    // Distributed Multi-Node Agents (Cycle 37)
    if (std.mem.eql(u8, arg, "cluster-demo") or std.mem.eql(u8, arg, "cluster") or std.mem.eql(u8, arg, "nodes")) return .cluster_demo;
    if (std.mem.eql(u8, arg, "cluster-bench") or std.mem.eql(u8, arg, "nodes-bench")) return .cluster_bench;
    // Adaptive Work-Stealing Scheduler (Cycle 39)
    if (std.mem.eql(u8, arg, "worksteal-demo") or std.mem.eql(u8, arg, "worksteal") or std.mem.eql(u8, arg, "steal")) return .worksteal_demo;
    if (std.mem.eql(u8, arg, "worksteal-bench") or std.mem.eql(u8, arg, "steal-bench")) return .worksteal_bench;
    // Plugin & Extension System (Cycle 40)
    if (std.mem.eql(u8, arg, "plugin-demo") or std.mem.eql(u8, arg, "plugin") or std.mem.eql(u8, arg, "ext")) return .plugin_demo;
    if (std.mem.eql(u8, arg, "plugin-bench") or std.mem.eql(u8, arg, "ext-bench")) return .plugin_bench;
    // Agent Communication Protocol (Cycle 41)
    if (std.mem.eql(u8, arg, "comms-demo") or std.mem.eql(u8, arg, "comms") or std.mem.eql(u8, arg, "msg")) return .comms_demo;
    if (std.mem.eql(u8, arg, "comms-bench") or std.mem.eql(u8, arg, "msg-bench")) return .comms_bench;
    // Observability & Tracing System (Cycle 42)
    if (std.mem.eql(u8, arg, "observe-demo") or std.mem.eql(u8, arg, "observe") or std.mem.eql(u8, arg, "otel")) return .observe_demo;
    if (std.mem.eql(u8, arg, "observe-bench") or std.mem.eql(u8, arg, "otel-bench")) return .observe_bench;
    // Consensus & Coordination Protocol (Cycle 43)
    if (std.mem.eql(u8, arg, "consensus-demo") or std.mem.eql(u8, arg, "consensus") or std.mem.eql(u8, arg, "raft")) return .consensus_demo;
    if (std.mem.eql(u8, arg, "consensus-bench") or std.mem.eql(u8, arg, "raft-bench")) return .consensus_bench;
    // Speculative Execution Engine (Cycle 44)
    if (std.mem.eql(u8, arg, "specexec-demo") or std.mem.eql(u8, arg, "specexec") or std.mem.eql(u8, arg, "spec")) return .specexec_demo;
    if (std.mem.eql(u8, arg, "specexec-bench") or std.mem.eql(u8, arg, "spec-bench")) return .specexec_bench;
    // Adaptive Resource Governor (Cycle 45)
    if (std.mem.eql(u8, arg, "governor-demo") or std.mem.eql(u8, arg, "governor") or std.mem.eql(u8, arg, "gov")) return .governor_demo;
    if (std.mem.eql(u8, arg, "governor-bench") or std.mem.eql(u8, arg, "gov-bench")) return .governor_bench;
    // Federated Learning Protocol (Cycle 46)
    if (std.mem.eql(u8, arg, "fedlearn-demo") or std.mem.eql(u8, arg, "fedlearn") or std.mem.eql(u8, arg, "fl")) return .fedlearn_demo;
    if (std.mem.eql(u8, arg, "fedlearn-bench") or std.mem.eql(u8, arg, "fl-bench")) return .fedlearn_bench;
    // Event Sourcing & CQRS Engine (Cycle 47)
    if (std.mem.eql(u8, arg, "eventsrc-demo") or std.mem.eql(u8, arg, "eventsrc") or std.mem.eql(u8, arg, "es")) return .eventsrc_demo;
    if (std.mem.eql(u8, arg, "eventsrc-bench") or std.mem.eql(u8, arg, "es-bench")) return .eventsrc_bench;
    // Capability-Based Security Model (Cycle 48)
    if (std.mem.eql(u8, arg, "capsec-demo") or std.mem.eql(u8, arg, "capsec") or std.mem.eql(u8, arg, "sec")) return .capsec_demo;
    if (std.mem.eql(u8, arg, "capsec-bench") or std.mem.eql(u8, arg, "sec-bench")) return .capsec_bench;
    // Distributed Transaction Coordinator (Cycle 49)
    if (std.mem.eql(u8, arg, "dtxn-demo") or std.mem.eql(u8, arg, "dtxn") or std.mem.eql(u8, arg, "txn")) return .dtxn_demo;
    if (std.mem.eql(u8, arg, "dtxn-bench") or std.mem.eql(u8, arg, "txn-bench")) return .dtxn_bench;
    // Adaptive Caching & Memoization (Cycle 50)
    if (std.mem.eql(u8, arg, "cache-demo") or std.mem.eql(u8, arg, "cache") or std.mem.eql(u8, arg, "memo")) return .cache_demo;
    if (std.mem.eql(u8, arg, "cache-bench") or std.mem.eql(u8, arg, "memo-bench")) return .cache_bench;
    // Contract-Based Agent Negotiation (Cycle 51)
    if (std.mem.eql(u8, arg, "contract-demo") or std.mem.eql(u8, arg, "contract") or std.mem.eql(u8, arg, "sla")) return .contract_demo;
    if (std.mem.eql(u8, arg, "contract-bench") or std.mem.eql(u8, arg, "sla-bench")) return .contract_bench;
    // Temporal Workflow Engine (Cycle 52)
    if (std.mem.eql(u8, arg, "workflow-demo") or std.mem.eql(u8, arg, "workflow") or std.mem.eql(u8, arg, "wf")) return .workflow_demo;
    if (std.mem.eql(u8, arg, "workflow-bench") or std.mem.eql(u8, arg, "wf-bench")) return .workflow_bench;
    if (std.mem.eql(u8, arg, "distributed") or std.mem.eql(u8, arg, "dist")) return .distributed;
    // Info
    if (std.mem.eql(u8, arg, "info")) return .info;
    if (std.mem.eql(u8, arg, "version") or std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-v")) return .version;
    if (std.mem.eql(u8, arg, "help") or std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) return .help;
    return .none;
}

pub fn printPrompt(state: *CLIState) void {
    const mode_name = state.mode.getName();
    const lang_ext = state.language.getExtension();
    std.debug.print("{s}[{s}]{s} {s}[{s}]{s} > ", .{ GREEN, mode_name, RESET, GOLDEN, lang_ext, RESET });
}

pub fn processREPLCommand(state: *CLIState, cmd: []const u8) void {
    if (std.mem.eql(u8, cmd, "/chat")) {
        state.mode = .Chat;
        std.debug.print("{s}Mode: Chat{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/code")) {
        state.mode = .CodeGen;
        std.debug.print("{s}Mode: Code Generation{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/fix")) {
        state.mode = .BugFix;
        std.debug.print("{s}Mode: Bug Fix{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/explain")) {
        state.mode = .Explain;
        std.debug.print("{s}Mode: Explain{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/test")) {
        state.mode = .Test;
        std.debug.print("{s}Mode: Test Generation{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/doc")) {
        state.mode = .Document;
        std.debug.print("{s}Mode: Documentation{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/refactor")) {
        state.mode = .Refactor;
        std.debug.print("{s}Mode: Refactor{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/reason")) {
        state.mode = .Reason;
        std.debug.print("{s}Mode: Chain-of-Thought Reasoning{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/zig")) {
        state.language = .Zig;
        std.debug.print("{s}Language: Zig{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/python")) {
        state.language = .Python;
        std.debug.print("{s}Language: Python{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/rust")) {
        state.language = .Rust;
        std.debug.print("{s}Language: Rust{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/js") or std.mem.eql(u8, cmd, "/javascript")) {
        state.language = .JavaScript;
        std.debug.print("{s}Language: JavaScript{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/stats")) {
        printStats(state);
    } else if (std.mem.eql(u8, cmd, "/verbose")) {
        state.verbose = !state.verbose;
        std.debug.print("{s}Verbose: {s}{s}\n", .{ GREEN, if (state.verbose) "ON" else "OFF", RESET });
    } else if (std.mem.eql(u8, cmd, "/help")) {
        printREPLHelp();
    } else if (std.mem.eql(u8, cmd, "/quit") or std.mem.eql(u8, cmd, "/exit") or std.mem.eql(u8, cmd, "/q")) {
        state.running = false;
        std.debug.print("{s}Goodbye! φ² + 1/φ² = 3{s}\n", .{ GOLDEN, RESET });
    } else {
        std.debug.print("{s}Unknown command. Type /help for commands.{s}\n", .{ RED, RESET });
    }
}

pub fn printREPLHelp() void {
    std.debug.print("\n{s}REPL Commands:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}/chat{s}     - Chat mode\n", .{ GREEN, RESET });
    std.debug.print("  {s}/code{s}     - Code generation\n", .{ GREEN, RESET });
    std.debug.print("  {s}/fix{s}      - Bug fixing\n", .{ GREEN, RESET });
    std.debug.print("  {s}/explain{s}  - Explain code\n", .{ GREEN, RESET });
    std.debug.print("  {s}/test{s}     - Generate tests\n", .{ GREEN, RESET });
    std.debug.print("  {s}/doc{s}      - Generate docs\n", .{ GREEN, RESET });
    std.debug.print("  {s}/refactor{s} - Refactoring\n", .{ GREEN, RESET });
    std.debug.print("  {s}/reason{s}   - Chain-of-thought\n", .{ GREEN, RESET });
    std.debug.print("  {s}/zig{s}      - Zig language\n", .{ GREEN, RESET });
    std.debug.print("  {s}/python{s}   - Python language\n", .{ GREEN, RESET });
    std.debug.print("  {s}/rust{s}     - Rust language\n", .{ GREEN, RESET });
    std.debug.print("  {s}/js{s}       - JavaScript\n", .{ GREEN, RESET });
    std.debug.print("  {s}/stats{s}    - Statistics\n", .{ GREEN, RESET });
    std.debug.print("  {s}/verbose{s}  - Toggle verbose\n", .{ GREEN, RESET });
    std.debug.print("  {s}/quit{s}     - Exit\n", .{ GREEN, RESET });
    std.debug.print("\n{s}Just type to send a message!{s}\n\n", .{ GRAY, RESET });
}

pub fn printStats(state: *CLIState) void {
    const stats = state.agent.getStats();
    std.debug.print("\n{s}═══ Statistics ═══{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  Requests: {d}\n", .{stats.total_requests});
    std.debug.print("  Total Time: {d}μs ({d:.2}ms)\n", .{ stats.total_time_us, @as(f64, @floatFromInt(stats.total_time_us)) / 1000.0 });
    if (stats.total_time_us > 0) {
        const ops_per_sec = @as(f64, @floatFromInt(stats.total_requests)) / (@as(f64, @floatFromInt(stats.total_time_us)) / 1_000_000.0);
        std.debug.print("  Speed: {s}{d:.1} ops/s{s}\n", .{ GREEN, ops_per_sec, RESET });
    }
    std.debug.print("  Vocabulary: 50000 words\n", .{});
    std.debug.print("  Mode: 100%% LOCAL\n", .{});
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

pub fn processInput(state: *CLIState, input: []const u8) void {
    const trimmed = std.mem.trim(u8, input, " \t\n\r");
    if (trimmed.len == 0) return;

    // Check for REPL commands
    if (trimmed[0] == '/') {
        processREPLCommand(state, trimmed);
        return;
    }

    // Detect mode from input
    const detected_mode = detectMode(trimmed);
    const actual_mode = if (detected_mode != null) detected_mode.? else state.mode;

    // Process based on mode
    switch (actual_mode) {
        .Chat => {
            if (state.chat_agent.respond(trimmed)) |chat_response| {
                std.debug.print("\n{s}{s}{s}\n\n", .{ WHITE, chat_response.response, RESET });
            } else |err| {
                std.debug.print("\n{s}Chat error: {}{s}\n\n", .{ RED, err, RESET });
            }
        },
        .CodeGen => {
            const code_result = state.coder.generateCode(trimmed);
            if (code_result.is_match) {
                std.debug.print("\n{s}// Generated Code:{s}\n", .{ GRAY, RESET });
                std.debug.print("{s}{s}{s}\n\n", .{ WHITE, code_result.code, RESET });
                if (code_result.chain_of_thought.len > 0) {
                    std.debug.print("{s}{s}{s}\n\n", .{ GRAY, code_result.chain_of_thought, RESET });
                }
            } else {
                // Fallback to agent
                const request = trinity_swe.SWERequest{
                    .task_type = actual_mode,
                    .prompt = trimmed,
                    .language = state.language,
                };
                if (state.agent.process(request)) |result| {
                    std.debug.print("\n{s}{s}{s}\n", .{ WHITE, result.output, RESET });
                } else |_| {
                    std.debug.print("{s}Error processing request.{s}\n", .{ RED, RESET });
                }
            }
        },
        else => {
            const request = trinity_swe.SWERequest{
                .task_type = actual_mode,
                .prompt = trimmed,
                .language = state.language,
            };
            if (state.agent.process(request)) |result| {
                std.debug.print("\n{s}{s}{s}\n", .{ WHITE, result.output, RESET });
                if (state.verbose) {
                    if (result.reasoning) |reasoning| {
                        std.debug.print("{s}Reasoning: {s}{s}\n\n", .{ GRAY, reasoning, RESET });
                    }
                }
            } else |_| {
                std.debug.print("{s}Error processing request.{s}\n", .{ RED, RESET });
            }
        },
    }
}

pub fn detectMode(input: []const u8) ?trinity_swe.SWETaskType {
    const lower = blk: {
        var buf: [256]u8 = undefined;
        const len = @min(input.len, buf.len);
        for (input[0..len], 0..) |c, i| {
            buf[i] = std.ascii.toLower(c);
        }
        break :blk buf[0..len];
    };

    // Code generation patterns
    if (std.mem.indexOf(u8, lower, "напиши") != null or
        std.mem.indexOf(u8, lower, "создай") != null or
        std.mem.indexOf(u8, lower, "сгенерируй") != null or
        std.mem.indexOf(u8, lower, "write") != null or
        std.mem.indexOf(u8, lower, "create") != null or
        std.mem.indexOf(u8, lower, "generate") != null or
        std.mem.indexOf(u8, lower, "implement") != null or
        std.mem.indexOf(u8, lower, "code") != null or
        std.mem.indexOf(u8, lower, "function") != null or
        std.mem.indexOf(u8, lower, "fibonacci") != null or
        std.mem.indexOf(u8, lower, "quicksort") != null or
        std.mem.indexOf(u8, lower, "algorithm") != null)
    {
        return .CodeGen;
    }

    // Chat patterns
    if (std.mem.indexOf(u8, lower, "привет") != null or
        std.mem.indexOf(u8, lower, "hello") != null or
        std.mem.indexOf(u8, lower, "hi") != null or
        std.mem.indexOf(u8, lower, "как дела") != null or
        std.mem.indexOf(u8, lower, "how are") != null or
        std.mem.indexOf(u8, lower, "кто ты") != null or
        std.mem.indexOf(u8, lower, "who are") != null or
        std.mem.indexOf(u8, lower, "спасибо") != null or
        std.mem.indexOf(u8, lower, "thank") != null or
        std.mem.indexOf(u8, lower, "你好") != null)
    {
        return .Chat;
    }

    // Explain patterns
    if (std.mem.indexOf(u8, lower, "объясни") != null or
        std.mem.indexOf(u8, lower, "explain") != null or
        std.mem.indexOf(u8, lower, "what is") != null or
        std.mem.indexOf(u8, lower, "что такое") != null)
    {
        return .Explain;
    }

    return null;
}

pub fn runInteractiveMode(state: *CLIState) !void {
    printBanner();
    printREPLHelp();

    const stdin_file = std.fs.File.stdin();
    var buf: [4096]u8 = undefined;

    while (state.running) {
        printPrompt(state);

        // Read line character by character
        var line_len: usize = 0;
        while (line_len < buf.len - 1) {
            const read_result = stdin_file.read(buf[line_len .. line_len + 1]) catch break;
            if (read_result == 0) break; // EOF
            if (buf[line_len] == '\n') break;
            line_len += 1;
        }

        if (line_len > 0) {
            processInput(state, buf[0..line_len]);
        }
    }

    printStats(state);
}

pub fn runCodeCommand(state: *CLIState, args: []const []const u8) void {
    if (args.len < 1) {
        std.debug.print("{s}Usage: tri code <prompt>{s}\n", .{ RED, RESET });
        std.debug.print("Example: tri code \"fibonacci function\"\n", .{});
        return;
    }

    // Check for --stream flag
    var stream_mode = state.stream_enabled;
    var filtered_args: [64][]const u8 = undefined;
    var filtered_len: usize = 0;

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--stream") or std.mem.eql(u8, arg, "-s")) {
            stream_mode = true;
        } else if (filtered_len < filtered_args.len) {
            filtered_args[filtered_len] = arg;
            filtered_len += 1;
        }
    }

    // Join filtered args as prompt
    var prompt_buf: [4096]u8 = undefined;
    var pos: usize = 0;
    for (filtered_args[0..filtered_len], 0..) |arg, i| {
        if (i > 0 and pos < prompt_buf.len) {
            prompt_buf[pos] = ' ';
            pos += 1;
        }
        const copy_len = @min(arg.len, prompt_buf.len - pos);
        @memcpy(prompt_buf[pos..][0..copy_len], arg[0..copy_len]);
        pos += copy_len;
    }
    const prompt = prompt_buf[0..pos];

    // Detect language
    const lang_detection = multilingual.detectLanguage(prompt);
    std.debug.print("{s}Detected language:{s} {s} {s} (confidence: {d:.0}%)\n", .{
        CYAN,
        RESET,
        lang_detection.language.getFlag(),
        lang_detection.language.getName(),
        lang_detection.confidence * 100,
    });

    // Normalize prompt if not English
    const normalized_prompt = if (lang_detection.language != .english)
        multilingual.normalizePrompt(state.allocator, prompt) catch prompt
    else
        prompt;

    // Show normalized prompt if different
    if (lang_detection.language != .english and !std.mem.eql(u8, normalized_prompt, prompt)) {
        std.debug.print("{s}Normalized:{s} {s}\n", .{ GRAY, RESET, normalized_prompt });
    }

    std.debug.print("{s}Generating code for:{s} {s}\n\n", .{ CYAN, RESET, prompt });

    const code_result = state.coder.generateCode(prompt);
    if (code_result.is_match) {
        if (stream_mode) {
            var stream = streaming.createFastStreaming();
            stream.streamText(code_result.code);
            stream.streamChar('\n');
            if (code_result.chain_of_thought.len > 0) {
                stream.streamChar('\n');
                stream.streamText(code_result.chain_of_thought);
                stream.streamChar('\n');
            }
        } else {
            std.debug.print("{s}{s}{s}\n", .{ WHITE, code_result.code, RESET });
            if (code_result.chain_of_thought.len > 0) {
                std.debug.print("\n{s}{s}{s}\n", .{ GRAY, code_result.chain_of_thought, RESET });
            }
        }
    } else {
        // Fallback to SWE agent
        const request = trinity_swe.SWERequest{
            .task_type = .CodeGen,
            .prompt = prompt,
            .language = state.language,
        };
        if (state.agent.process(request)) |result| {
            if (stream_mode) {
                var stream = streaming.createFastStreaming();
                stream.streamText(result.output);
                stream.streamChar('\n');
            } else {
                std.debug.print("{s}{s}{s}\n", .{ WHITE, result.output, RESET });
            }
        } else |_| {
            std.debug.print("{s}Error generating code.{s}\n", .{ RED, RESET });
        }
    }
}

pub fn runChatCommand(state: *CLIState, args: []const []const u8) void {
    if (args.len > 0) {
        // Check for --stream flag
        var stream_mode = state.stream_enabled;
        var filtered_args: [64][]const u8 = undefined;
        var filtered_len: usize = 0;

        for (args) |arg| {
            if (std.mem.eql(u8, arg, "--stream") or std.mem.eql(u8, arg, "-s")) {
                stream_mode = true;
            } else if (filtered_len < filtered_args.len) {
                filtered_args[filtered_len] = arg;
                filtered_len += 1;
            }
        }

        // Build message from filtered args
        var msg_buf: [4096]u8 = undefined;
        var pos: usize = 0;
        for (filtered_args[0..filtered_len], 0..) |arg, i| {
            if (i > 0 and pos < msg_buf.len) {
                msg_buf[pos] = ' ';
                pos += 1;
            }
            const copy_len = @min(arg.len, msg_buf.len - pos);
            @memcpy(msg_buf[pos..][0..copy_len], arg[0..copy_len]);
            pos += copy_len;
        }
        const msg = msg_buf[0..pos];

        // Use hybrid chat (symbolic + LLM fallback)
        if (state.chat_agent.respond(msg)) |chat_response| {
            if (stream_mode) {
                var stream = streaming.createFastStreaming();
                stream.streamText(chat_response.response);
                stream.streamChar('\n');
            } else {
                std.debug.print("{s}{s}{s}\n", .{ WHITE, chat_response.response, RESET });
            }
        } else |err| {
            std.debug.print("{s}Chat error: {}{s}\n", .{ RED, err, RESET });
        }
    } else {
        // Interactive chat mode
        state.mode = .Chat;
        runInteractiveMode(state) catch {};
    }
}

pub fn runSWECommand(state: *CLIState, task_type: trinity_swe.SWETaskType, args: []const []const u8) void {
    if (args.len < 1) {
        std.debug.print("{s}Usage: tri {s} <file or prompt>{s}\n", .{ RED, @tagName(task_type), RESET });
        return;
    }

    var prompt_buf: [4096]u8 = undefined;
    var pos: usize = 0;
    for (args, 0..) |arg, i| {
        if (i > 0 and pos < prompt_buf.len) {
            prompt_buf[pos] = ' ';
            pos += 1;
        }
        const copy_len = @min(arg.len, prompt_buf.len - pos);
        @memcpy(prompt_buf[pos..][0..copy_len], arg[0..copy_len]);
        pos += copy_len;
    }
    const prompt = prompt_buf[0..pos];

    std.debug.print("{s}Processing ({s}):{s} {s}\n\n", .{ CYAN, @tagName(task_type), RESET, prompt });

    const request = trinity_swe.SWERequest{
        .task_type = task_type,
        .prompt = prompt,
        .language = state.language,
    };
    if (state.agent.process(request)) |result| {
        std.debug.print("{s}{s}{s}\n", .{ WHITE, result.output, RESET });
    } else |_| {
        std.debug.print("{s}Error processing request.{s}\n", .{ RED, RESET });
    }
}
