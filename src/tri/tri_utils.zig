// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - Utility Functions
// ═══════════════════════════════════════════════════════════════════════════════
//
// Command enum, CLIState, parseCommand, and module re-exports.
// Print functions moved to utils/print.zig, REPL functions moved to utils/repl.zig.
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("tri_colors.zig");
const trinity_swe = @import("trinity_swe");
const igla_hybrid_chat = @import("igla_hybrid_chat");
const igla_coder = @import("igla_coder");
const tvc = @import("tvc_corpus");
const tri_context = @import("tri_context.zig");

// Re-export print utilities
const print_utils = @import("utils/print.zig");
pub const printBanner = print_utils.printBanner;
pub const printHelp = print_utils.printHelp;
pub const printVersion = print_utils.printVersion;
pub const printInfo = print_utils.printInfo;
pub const printREPLHelp = print_utils.printREPLHelp;
pub const printStats = print_utils.printStats;
pub const printCommandHelp = print_utils.printCommandHelp;
pub const printIntelligenceHelp = print_utils.printIntelligenceHelp;
pub const Command = print_utils.Command;

// Re-export REPL utilities
const repl_utils = @import("utils/repl.zig");
pub const printPrompt = repl_utils.printPrompt;
pub const processREPLCommand = repl_utils.processREPLCommand;
pub const processInput = repl_utils.processInput;
pub const detectMode = repl_utils.detectMode;
pub const runInteractiveMode = repl_utils.runInteractiveMode;

const GREEN = colors.GREEN;
const GOLDEN = colors.GOLDEN;
const WHITE = colors.WHITE;
const GRAY = colors.GRAY;
const RED = colors.RED;
const CYAN = colors.CYAN;
const RESET = colors.RESET;
const VERSION = colors.VERSION;

// Sacred Intelligence is enabled by default
const SACRED_INTELLIGENCE_DEFAULT = true;

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

    // UX Flags (v1.1)
    dry_run: bool = false,
    yes: bool = false,
    output_format: OutputFormat = .text,

    // TVC Corpus for self-learning (heap-allocated, ~26MB)
    tvc_corpus: ?*tvc.TVCCorpus,

    // Codebase Context Manager (Cycle 92)
    context_mgr: ?*tri_context.ContextManager,

    const Self = @This();

    /// Output format for command results
    pub const OutputFormat = enum {
        text,
        json,
        yaml,
    };

    /// Default model path for auto-detection
    const DEFAULT_MODEL_PATH = "models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf";

    /// Default TVC corpus save path
    const TVC_CORPUS_PATH = "trinity_chat.tvc";

    pub fn init(allocator: std.mem.Allocator) !Self {
        // Auto-detect model path
        const model_path: ?[]const u8 = blk: {
            std.fs.cwd().access(DEFAULT_MODEL_PATH, .{}) catch break :blk null;
            break :blk DEFAULT_MODEL_PATH;
        };

        // Heap-allocate TVC corpus for self-learning (~26MB, must be on heap)
        const corpus = try allocator.create(tvc.TVCCorpus);
        corpus.initInPlace();
        // Try loading existing corpus from disk (load into heap-allocated struct)
        corpus.loadInto(TVC_CORPUS_PATH) catch |err| {
            std.log.debug("corpus load: {s}", .{@errorName(err)});
        };

        // Codebase Context Manager (Cycle 92)
        const ctx_mgr = try allocator.create(tri_context.ContextManager);
        ctx_mgr.* = tri_context.ContextManager.init(allocator);
        ctx_mgr.loadIndex() catch |err| {
            std.log.debug("context index load: {s}", .{@errorName(err)});
        };

        // Read API keys from environment
        const groq_key = std.process.getEnvVarOwned(allocator, "GROQ_API_KEY") catch null;
        const claude_key = std.process.getEnvVarOwned(allocator, "ANTHROPIC_API_KEY") catch null;
        const openai_key = std.process.getEnvVarOwned(allocator, "OPENAI_API_KEY") catch null;

        // Build hybrid config with TVC + multi-provider + multi-modal (v2.1)
        const config = igla_hybrid_chat.HybridConfig{
            .tvc_corpus_path = TVC_CORPUS_PATH,
            .groq_api_key = groq_key,
            .claude_api_key = claude_key,
            .openai_api_key = openai_key,
        };

        // Initialize hybrid chat with TVC corpus
        var chat = try igla_hybrid_chat.IglaHybridChat.initWithConfig(allocator, model_path, config);
        chat.corpus = corpus;

        return Self{
            .allocator = allocator,
            .agent = try trinity_swe.TrinitySWEAgent.init(allocator),
            .chat_agent = chat,
            .coder = igla_coder.IglaLocalCoder.init(allocator),
            .mode = .Explain,
            .language = .Zig,
            .verbose = true,
            .running = true,
            .stream_enabled = false,
            .tvc_corpus = corpus,
            .context_mgr = ctx_mgr,
        };
    }

    pub fn deinit(self: *Self) void {
        // Save context index before exit (Cycle 92)
        if (self.context_mgr) |mgr| {
            if (mgr.is_dirty) {
                mgr.saveIndex() catch |err| {
                    std.log.debug("context index save: {s}", .{@errorName(err)});
                };
            }
            mgr.deinit();
            self.allocator.destroy(mgr);
            self.context_mgr = null;
        }
        // Save TVC corpus to disk before exit
        if (self.tvc_corpus) |corpus| {
            corpus.save(TVC_CORPUS_PATH) catch |err| {
                std.log.debug("corpus save: {s}", .{@errorName(err)});
            };
            self.allocator.destroy(corpus);
            self.tvc_corpus = null;
        }
        // Free API key strings (allocated by getEnvVarOwned)
        if (self.chat_agent.config.groq_api_key) |key| {
            self.allocator.free(key);
        }
        if (self.chat_agent.config.claude_api_key) |key| {
            self.allocator.free(key);
        }
        if (self.chat_agent.config.openai_api_key) |key| {
            self.allocator.free(key);
        }
        self.chat_agent.deinit();
        self.agent.deinit();
    }
};

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
    if (std.mem.eql(u8, arg, "pipeline")) return .pipeline;
    if (std.mem.eql(u8, arg, "decompose")) return .decompose;
    if (std.mem.eql(u8, arg, "plan")) return .plan;
    if (std.mem.eql(u8, arg, "verify")) return .verify;
    if (std.mem.eql(u8, arg, "verdict")) return .verdict;
    // Test REPL (Cycle 101)
    if (std.mem.eql(u8, arg, "test-repl")) return .test_repl;
    // Spec & Loop (v8.27)
    if (std.mem.eql(u8, arg, "spec-create")) return .spec_create;
    if (std.mem.eql(u8, arg, "loop-decide")) return .loop_decide;
    // TVC (Distributed Learning)
    if (std.mem.eql(u8, arg, "tvc-demo")) return .tvc_demo;
    if (std.mem.eql(u8, arg, "tvc-stats")) return .tvc_stats;
    // Multi-Agent System
    if (std.mem.eql(u8, arg, "agents-demo")) return .agents_demo;
    if (std.mem.eql(u8, arg, "agents-bench")) return .agents_bench;
    // Long Context
    if (std.mem.eql(u8, arg, "context-demo")) return .context_demo;
    if (std.mem.eql(u8, arg, "context-bench")) return .context_bench;
    // RAG (Retrieval-Augmented Generation)
    if (std.mem.eql(u8, arg, "rag-demo")) return .rag_demo;
    if (std.mem.eql(u8, arg, "rag-bench")) return .rag_bench;
    // Voice I/O (TTS + STT)
    if (std.mem.eql(u8, arg, "voice-demo")) return .voice_demo;
    if (std.mem.eql(u8, arg, "voice-bench")) return .voice_bench;
    // Code Execution Sandbox
    if (std.mem.eql(u8, arg, "sandbox-demo")) return .sandbox_demo;
    if (std.mem.eql(u8, arg, "sandbox-bench")) return .sandbox_bench;
    // Streaming Output
    if (std.mem.eql(u8, arg, "stream-demo")) return .stream_demo;
    if (std.mem.eql(u8, arg, "stream-bench")) return .stream_bench;
    // Local Vision
    if (std.mem.eql(u8, arg, "vision-demo")) return .vision_demo;
    if (std.mem.eql(u8, arg, "vision-bench")) return .vision_bench;
    // Fine-Tuning Engine
    if (std.mem.eql(u8, arg, "finetune-demo")) return .finetune_demo;
    if (std.mem.eql(u8, arg, "finetune-bench")) return .finetune_bench;
    // Batched Stealing
    if (std.mem.eql(u8, arg, "batched-demo")) return .batched_demo;
    if (std.mem.eql(u8, arg, "batched-bench")) return .batched_bench;
    // Priority Queue
    if (std.mem.eql(u8, arg, "priority-demo")) return .priority_demo;
    if (std.mem.eql(u8, arg, "priority-bench")) return .priority_bench;
    // Deadline Scheduling
    if (std.mem.eql(u8, arg, "deadline-demo")) return .deadline_demo;
    if (std.mem.eql(u8, arg, "deadline-bench")) return .deadline_bench;
    // Multi-Modal Unified (Cycle 26)
    if (std.mem.eql(u8, arg, "multimodal-demo")) return .multimodal_demo;
    if (std.mem.eql(u8, arg, "multimodal-bench")) return .multimodal_bench;
    // Multi-Modal Tool Use (Cycle 27)
    if (std.mem.eql(u8, arg, "tooluse-demo")) return .tooluse_demo;
    if (std.mem.eql(u8, arg, "tooluse-bench")) return .tooluse_bench;
    // Unified Multi-Modal Agent (Cycle 30)
    if (std.mem.eql(u8, arg, "unified-demo")) return .unified_demo;
    if (std.mem.eql(u8, arg, "unified-bench")) return .unified_bench;
    // Autonomous Agent (Cycle 31)
    if (std.mem.eql(u8, arg, "auto-demo") or std.mem.eql(u8, arg, "autonomous-demo")) return .autonomous_demo;
    if (std.mem.eql(u8, arg, "auto-bench") or std.mem.eql(u8, arg, "autonomous-bench")) return .autonomous_bench;
    // Multi-Agent Orchestration (Cycle 32)
    if (std.mem.eql(u8, arg, "orch-demo") or std.mem.eql(u8, arg, "orchestration-demo")) return .orchestration_demo;
    if (std.mem.eql(u8, arg, "orch-bench") or std.mem.eql(u8, arg, "orchestration-bench")) return .orchestration_bench;
    // MM Multi-Agent Orchestration (Cycle 33)
    if (std.mem.eql(u8, arg, "mmo-demo") or std.mem.eql(u8, arg, "mm-orch-demo")) return .mm_orch_demo;
    if (std.mem.eql(u8, arg, "mmo-bench") or std.mem.eql(u8, arg, "mm-orch-bench")) return .mm_orch_bench;
    // Agent Memory & Cross-Modal Learning (Cycle 34)
    if (std.mem.eql(u8, arg, "memory-demo")) return .memory_demo;
    if (std.mem.eql(u8, arg, "memory-bench")) return .memory_bench;
    // Persistent Memory & Disk Serialization (Cycle 35)
    if (std.mem.eql(u8, arg, "persist-demo")) return .persist_demo;
    if (std.mem.eql(u8, arg, "persist-bench")) return .persist_bench;
    // Dynamic Agent Spawning & Load Balancing (Cycle 36)
    if (std.mem.eql(u8, arg, "spawn-demo")) return .spawn_demo;
    if (std.mem.eql(u8, arg, "spawn-bench")) return .spawn_bench;
    // Distributed Multi-Node Agents (Cycle 37)
    if (std.mem.eql(u8, arg, "cluster-demo")) return .cluster_demo;
    if (std.mem.eql(u8, arg, "cluster-bench")) return .cluster_bench;
    // Adaptive Work-Stealing Scheduler (Cycle 39)
    if (std.mem.eql(u8, arg, "worksteal-demo") or std.mem.eql(u8, arg, "steal-demo")) return .worksteal_demo;
    if (std.mem.eql(u8, arg, "worksteal-bench") or std.mem.eql(u8, arg, "steal-bench")) return .worksteal_bench;
    // Plugin & Extension System (Cycle 40)
    if (std.mem.eql(u8, arg, "plugin-demo") or std.mem.eql(u8, arg, "ext-demo")) return .plugin_demo;
    if (std.mem.eql(u8, arg, "plugin-bench") or std.mem.eql(u8, arg, "ext-bench")) return .plugin_bench;
    // Agent Communication Protocol (Cycle 41)
    if (std.mem.eql(u8, arg, "comms-demo") or std.mem.eql(u8, arg, "msg-demo")) return .comms_demo;
    if (std.mem.eql(u8, arg, "comms-bench") or std.mem.eql(u8, arg, "msg-bench")) return .comms_bench;
    // Observability & Tracing System (Cycle 42)
    if (std.mem.eql(u8, arg, "observe-demo") or std.mem.eql(u8, arg, "otel-demo")) return .observe_demo;
    if (std.mem.eql(u8, arg, "observe-bench") or std.mem.eql(u8, arg, "otel-bench")) return .observe_bench;
    // Consensus & Coordination Protocol (Cycle 43)
    if (std.mem.eql(u8, arg, "consensus-demo") or std.mem.eql(u8, arg, "raft-demo")) return .consensus_demo;
    if (std.mem.eql(u8, arg, "consensus-bench") or std.mem.eql(u8, arg, "raft-bench")) return .consensus_bench;
    // Speculative Execution Engine (Cycle 44)
    if (std.mem.eql(u8, arg, "specexec-demo") or std.mem.eql(u8, arg, "spec-demo")) return .specexec_demo;
    if (std.mem.eql(u8, arg, "specexec-bench") or std.mem.eql(u8, arg, "spec-bench")) return .specexec_bench;
    // Adaptive Resource Governor (Cycle 45)
    if (std.mem.eql(u8, arg, "governor-demo") or std.mem.eql(u8, arg, "gov-demo")) return .governor_demo;
    if (std.mem.eql(u8, arg, "governor-bench") or std.mem.eql(u8, arg, "gov-bench")) return .governor_bench;
    // Federated Learning Protocol (Cycle 46)
    if (std.mem.eql(u8, arg, "fedlearn-demo") or std.mem.eql(u8, arg, "fl-demo")) return .fedlearn_demo;
    if (std.mem.eql(u8, arg, "fedlearn-bench") or std.mem.eql(u8, arg, "fl-bench")) return .fedlearn_bench;
    // Event Sourcing & CQRS Engine (Cycle 47)
    if (std.mem.eql(u8, arg, "eventsrc-demo") or std.mem.eql(u8, arg, "es-demo")) return .eventsrc_demo;
    if (std.mem.eql(u8, arg, "eventsrc-bench") or std.mem.eql(u8, arg, "es-bench")) return .eventsrc_bench;
    // Capability-Based Security Model (Cycle 48)
    if (std.mem.eql(u8, arg, "capsec-demo") or std.mem.eql(u8, arg, "sec-demo")) return .capsec_demo;
    if (std.mem.eql(u8, arg, "capsec-bench") or std.mem.eql(u8, arg, "sec-bench")) return .capsec_bench;
    // Distributed Transaction Coordinator (Cycle 49)
    if (std.mem.eql(u8, arg, "dtxn-demo") or std.mem.eql(u8, arg, "txn-demo")) return .dtxn_demo;
    if (std.mem.eql(u8, arg, "dtxn-bench") or std.mem.eql(u8, arg, "txn-bench")) return .dtxn_bench;
    // Adaptive Caching & Memoization (Cycle 50)
    if (std.mem.eql(u8, arg, "cache-demo") or std.mem.eql(u8, arg, "memo-demo")) return .cache_demo;
    if (std.mem.eql(u8, arg, "cache-bench") or std.mem.eql(u8, arg, "memo-bench")) return .cache_bench;
    // Contract-Based Agent Negotiation (Cycle 51)
    if (std.mem.eql(u8, arg, "contract-demo") or std.mem.eql(u8, arg, "sla-demo")) return .contract_demo;
    if (std.mem.eql(u8, arg, "contract-bench") or std.mem.eql(u8, arg, "sla-bench")) return .contract_bench;
    // Temporal Workflow Engine (Cycle 52)
    if (std.mem.eql(u8, arg, "workflow-demo") or std.mem.eql(u8, arg, "wf-demo")) return .workflow_demo;
    if (std.mem.eql(u8, arg, "workflow-bench") or std.mem.eql(u8, arg, "wf-bench")) return .workflow_bench;
    // Distributed Inference
    if (std.mem.eql(u8, arg, "distributed")) return .distributed;
    // Multi-Cluster (Cycle #97)
    if (std.mem.eql(u8, arg, "multi-cluster")) return .multi_cluster;
    // Sacred Mathematics (v3.6)
    if (std.mem.eql(u8, arg, "math")) return .math;
    if (std.mem.eql(u8, arg, "constants")) return .constants_cmd;
    if (std.mem.eql(u8, arg, "phi")) return .phi;
    if (std.mem.eql(u8, arg, "fib")) return .fib;
    if (std.mem.eql(u8, arg, "lucas")) return .lucas;
    if (std.mem.eql(u8, arg, "spiral")) return .spiral;
    if (std.mem.eql(u8, arg, "gematria")) return .gematria;
    if (std.mem.eql(u8, arg, "formula")) return .formula_cmd;
    if (std.mem.eql(u8, arg, "sacred")) return .sacred;
    // Biology (v14.0)
    if (std.mem.eql(u8, arg, "bio")) return .bio;
    // Cosmology (v15.0)
    if (std.mem.eql(u8, arg, "cosmos")) return .cosmos;
    // Neuroscience (v16.0)
    if (std.mem.eql(u8, arg, "neuro")) return .neuro;
    // Chemistry (v6.0)
    if (std.mem.eql(u8, arg, "chem")) return .chem;
    // Intelligence System
    if (std.mem.eql(u8, arg, "intelligence") or std.mem.eql(u8, arg, "intel")) return .intelligence;
    // Dev Utilities
    if (std.mem.eql(u8, arg, "doctor")) return .doctor;
    if (std.mem.eql(u8, arg, "clean")) return .clean;
    if (std.mem.eql(u8, arg, "fmt")) return .fmt_cmd;
    if (std.mem.eql(u8, arg, "stats")) return .stats_cmd;
    if (std.mem.eql(u8, arg, "igla")) return .igla;
    // Cycle 98: Sacred Intelligence
    if (std.mem.eql(u8, arg, "identity")) return .identity;
    if (std.mem.eql(u8, arg, "swarm")) return .swarm;
    if (std.mem.eql(u8, arg, "mu")) return .mu;
    if (std.mem.eql(u8, arg, "govern")) return .govern;
    if (std.mem.eql(u8, arg, "dashboard")) return .dashboard;
    if (std.mem.eql(u8, arg, "omega")) return .omega;
    if (std.mem.eql(u8, arg, "math-agent")) return .math_agent;
    // Code Analysis
    if (std.mem.eql(u8, arg, "analyze")) return .analyze;
    if (std.mem.eql(u8, arg, "search") or std.mem.eql(u8, arg, "grep")) return .search_cmd;
    if (std.mem.eql(u8, arg, "deps")) return .deps;
    // Codebase Context (Cycle 92)
    if (std.mem.eql(u8, arg, "context-info") or std.mem.eql(u8, arg, "ctx-info")) return .context_info;
    // Temporal Engine v1.2 (Order #030)
    if (std.mem.eql(u8, arg, "time") or std.mem.eql(u8, arg, "arrow-time")) return .time;
    if (std.mem.eql(u8, arg, "install")) return .install;
    if (std.mem.eql(u8, arg, "build")) return .build_cmd;
    // Temporal Engine v1.3 (Order #031)
    if (std.mem.eql(u8, arg, "deck-generate")) return .deck_generate;
    if (std.mem.eql(u8, arg, "fpga-demo")) return .fpga_demo;
    if (std.mem.eql(u8, arg, "fpga")) return .fpga;
    if (std.mem.eql(u8, arg, "train")) return .train;
    // Cloud deployment (Railway integration)
    if (std.mem.eql(u8, arg, "cloud")) return .cloud;
    // Railway training farm (multi-account)
    if (std.mem.eql(u8, arg, "farm")) return .farm;
    if (std.mem.eql(u8, arg, "sacred-const")) return .sacred_const;
    if (std.mem.eql(u8, arg, "sacred-full-cycle")) return .sacred_full_cycle;
    // Quantum Trinity v1.4 (Order #032)
    if (std.mem.eql(u8, arg, "quantum")) return .quantum;
    if (std.mem.eql(u8, arg, "release-cosmic")) return .release_cosmic;
    // Omega Phase v2.0 (Order #033)
    if (std.mem.eql(u8, arg, "omega-cmd")) return .omega_cmd;
    if (std.mem.eql(u8, arg, "all")) return .all_cmd;
    if (std.mem.eql(u8, arg, "holo")) return .holo_cmd;
    if (std.mem.eql(u8, arg, "release-absolute")) return .release_absolute;
    if (std.mem.eql(u8, arg, "omega-evolve")) return .omega_evolve;
    // TRINITY OS v1.0 (Order #034)
    if (std.mem.eql(u8, arg, "launch")) return .launch;
    // P0.3: Job Runtime (Async Long-Running Commands)
    if (std.mem.eql(u8, arg, "job-start")) return .job_start;
    if (std.mem.eql(u8, arg, "job-status")) return .job_status;
    if (std.mem.eql(u8, arg, "job-logs")) return .job_logs;
    if (std.mem.eql(u8, arg, "job-artifacts")) return .job_artifacts;
    if (std.mem.eql(u8, arg, "job-cancel")) return .job_cancel;
    if (std.mem.eql(u8, arg, "job-list")) return .job_list;
    // Info
    if (std.mem.eql(u8, arg, "info")) return .info;
    if (std.mem.eql(u8, arg, "version")) return .version;
    if (std.mem.eql(u8, arg, "help")) return .help;
    // NEEDLE - Structural Editor Core
    if (std.mem.eql(u8, arg, "needle")) return .needle;
    if (std.mem.eql(u8, arg, "needle-search")) return .needle_search;
    if (std.mem.eql(u8, arg, "needle-check")) return .needle_check;
    // P1.6: CLI Tools
    if (std.mem.eql(u8, arg, "commands") or std.mem.eql(u8, arg, "list")) return .commands;
    if (std.mem.eql(u8, arg, "mcp")) return .mcp;
    // Spec Linter (Issue #68)
    if (std.mem.eql(u8, arg, "lint")) return .lint;
    // Spec Enricher (Issue #69)
    if (std.mem.eql(u8, arg, "enrich")) return .enrich;
    // Spec <-> Code Sync Checker (Issue #71)
    if (std.mem.eql(u8, arg, "sync-check")) return .sync_check;
    // GitHub Integration (Protocol v2)
    if (std.mem.eql(u8, arg, "github")) return .github;
    // Zenodo DOI Publishing
    if (std.mem.eql(u8, arg, "zenodo")) return .zenodo;
    // Autonomous Loop (Ralph Pattern)
    if (std.mem.eql(u8, arg, "loop")) return .loop;
    // Experience (episode storage & recall)
    if (std.mem.eql(u8, arg, "experience")) return .experience;
    // Faculty Board (A2A Dashboard)
    if (std.mem.eql(u8, arg, "faculty")) return .faculty;
    if (std.mem.eql(u8, arg, "research")) return .research;
    // Experiment Visualization
    if (std.mem.eql(u8, arg, "experiment")) return .experiment;
    // Golden Chain Individual Links (v5.0)
    if (std.mem.eql(u8, arg, "chain")) return .chain;
    // Observatory v5.2
    if (std.mem.eql(u8, arg, "trace")) return .trace;
    if (std.mem.eql(u8, arg, "eval")) return .eval;
    if (std.mem.eql(u8, arg, "metrics")) return .metrics;
    // Context Loader (Kiro-inspired)
    if (std.mem.eql(u8, arg, "context-load") or std.mem.eql(u8, arg, "ctx-load")) return .context_load;
    return .none;
}

// Re-export remaining functions from original tri_utils for compatibility
// These are functions that weren't moved to print.zig or repl.zig
pub const runCodeCommand = @import("tri_commands.zig").runCodeCommand;
pub const runChatCommand = @import("tri_commands.zig").runChatCommand;
pub const runSWECommand = @import("tri_commands.zig").runSWECommand;
pub const runIntelligenceCommand = @import("tri_commands.zig").runIntelligenceCommand;
