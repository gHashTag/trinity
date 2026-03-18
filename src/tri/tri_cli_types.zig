// ═════════════════════════════════════════════════════════════════════════════
// TRI CLI Types
// ═════════════════════════════════════════════════════════════════════════════
//
// Command enum and CLIState struct.
// Extracted from tri_utils.zig for modularity.
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("tri_colors.zig");
const tri_context = @import("tri_context.zig");

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
    // Test REPL (Cycle 101)
    test_repl,
    // Spec & Loop (v8.27)
    spec_create,
    loop_decide,
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
    // Multi-Modal Unified
    multimodal_demo,
    multimodal_bench,
    // Multi-Modal Tool Use
    tooluse_demo,
    tooluse_bench,
    // Unified Multi-Modal Agent
    unified_demo,
    unified_bench,
    unified_cmd,
    // Autonomous Agent
    autonomous_demo,
    autonomous_bench,
    auto_demo,
    auto_bench,
    // Multi-Agent Orchestration
    orchestration_demo,
    orchestration_bench,
    orch_demo,
    orch_bench,
    // Multi-Modal Multi-Agent
    mm_orch_demo,
    mm_orch_bench,
    distributed,
    fmt_cmd,
    research,
    mu,
    context_info,
    // Agent Memory & Cross-Modal Learning
    memory_demo,
    memory_bench,
    // Persistent Memory & Disk Serialization
    persist_demo,
    persist_bench,
    // Dynamic Agent Spawning & Load Balancing
    spawn_demo,
    spawn_bench,
    // Distributed Multi-Node Agents
    cluster_demo,
    cluster_bench,
    // Adaptive Work-Stealing Scheduler
    worksteal_demo,
    worksteal_bench,
    // Plugin & Extension System
    plugin_demo,
    plugin_bench,
    // Agent Communication Protocol
    comms_demo,
    comms_bench,
    // Observability & Tracing System
    observe_demo,
    observe_bench,
    // Consensus & Coordination Protocol
    consensus_demo,
    consensus_bench,
    // Speculative Execution Engine
    specexec_demo,
    specexec_bench,
    // Adaptive Resource Governor
    governor_demo,
    governor_bench,
    // Federated Learning Protocol
    fedlearn_demo,
    fedlearn_bench,
    // Event Sourcing & CQRS Engine
    eventsrc_demo,
    eventsrc_bench,
    // Capability-Based Security Model
    capsec_demo,
    capsec_bench,
    // Distributed Transaction Coordinator
    dtxn_demo,
    dtxn_bench,
    // Adaptive Caching & Memoization
    cache_demo,
    cache_bench,
    // Contract-Based Agent Negotiation
    contract_demo,
    contract_bench,
    // Temporal Workflow Engine
    workflow_demo,
    workflow_bench,
    // Sacred Mathematics (v3.6)
    math,
    constants_cmd,
    phi,
    fib,
    lucas,
    spiral,
    gematria,
    formula,
    sacred,
    sacred_const,
    // Sacred Biology (v14.0)
    bio,
    // Sacred Cosmology (v15.0)
    cosmos,
    // Sacred Neuroscience (v16.0)
    neuro,
    // Sacred Intelligence
    intelligence,
    // Sacred Agents (Cycle 98)
    identity,
    swarm,
    govern,
    dashboard,
    omega,
    math_agent,
    // Autonomous Evolution (Cycle 97)
    // Dev Utilities
    doctor,
    clean,
    stats,
    igla,
    build_cmd,
    deck_generate,
    // Testing (Cycle 100)
    test_repl_cmd,
    // Chain aliases
    chain,
    // Job System
    job_start,
    job_status,
    job_cmd,
    job_exec,
    job_list,
    job_logs,
    job_artifacts,
    job_cancel,
    // Other commands
    commands,
    mcp,
    chem,
    garden,
    zenodo,
    ourob,
    hslm,
    verif,
    railway,
    stats_cmd,
    notify,
    biff,
    croc,
    swe,
    analyze,
    search_cmd,
    find_cmd,
    context_cmd,
    rag_cmd,
    voice_cmd,
    vision_cmd,
    sandbox_cmd,
    finetune_cmd,
    time,
    fpga,
    fpga_demo,
    train,
    cloud,
    farm,
    loop,
    experience,
    sacred_full_cycle,
    quantum,
    release_cosmic,
    omega_cmd,
    all_cmd,
    holo_cmd,
    release_absolute,
    omega_evolve,
    launch,
    needle,
    needle_search,
    needle_check,
    deps,
    info,
    identity_cmd,
    swarm_cmd,
    govern_cmd,
    replay,
    version,
    help,
    lint,
    enrich,
    sync_check,
    install,
    github,
    faculty,
    experiment,
    trace,
    eval,
    metrics,
    context_load,
    multi_cluster,
};

pub const OutputFormat = enum {
    text,
    json,
    yaml,
};

pub const CLIState = struct {
    allocator: std.mem.Allocator,
    history: std.ArrayListUnmanaged([]const u8),
    command_history: std.ArrayListUnmanaged([]const u8),
    context: tri_context.ContextManager,
    current_language: []const u8,
    streaming_mode: bool,
    verbose: bool,
    dry_run: bool,
    yes: bool,
    output_format: OutputFormat,

    pub fn init(allocator: std.mem.Allocator) !CLIState {
        return .{
            .allocator = allocator,
            .history = .{},
            .command_history = .{},
            .context = tri_context.ContextManager.init(allocator),
            .current_language = "en",
            .streaming_mode = false,
            .verbose = false,
            .dry_run = false,
            .yes = false,
            .output_format = .text,
        };
    }

    pub fn deinit(self: *CLIState) void {
        self.history.deinit(self.allocator);
        self.command_history.deinit(self.allocator);
        self.context.deinit();
    }
};

test "Command enum values" {
    try std.testing.expect(@intFromEnum(Command.chat) != @intFromEnum(Command.code));
    try std.testing.expect(@intFromEnum(Command.none) != @intFromEnum(Command.verdict));
    try std.testing.expect(@intFromEnum(Command.doctor) != @intFromEnum(Command.math));
}

test "OutputFormat default" {
    const fmt: OutputFormat = .text;
    try std.testing.expectEqual(OutputFormat.text, fmt);
}

test "CLIState init and deinit" {
    const alloc = std.testing.allocator;
    var state = try CLIState.init(alloc);
    defer state.deinit();
    try std.testing.expectEqualStrings("en", state.current_language);
    try std.testing.expect(!state.verbose);
    try std.testing.expect(!state.dry_run);
}
