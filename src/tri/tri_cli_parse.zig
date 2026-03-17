// ═════════════════════════════════════════════════════════════════════════════
// TRI CLI Parse
// ═════════════════════════════════════════════════════════════════════════════
//
// Command parsing logic.
// Extracted from tri_utils.zig for modularity.
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const cli_types = @import("tri_cli_types.zig");

pub fn parseCommand(arg: []const u8) cli_types.Command {
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
    if (std.mem.eql(u8, arg, "chain")) return .chain;
    if (std.mem.eql(u8, arg, "decompose")) return .decompose;
    if (std.mem.eql(u8, arg, "plan")) return .plan;
    if (std.mem.eql(u8, arg, "verify")) return .verify;
    if (std.mem.eql(u8, arg, "verdict")) return .verdict;
    // Test REPL (Cycle 101)
    if (std.mem.eql(u8, arg, "test-repl") or std.mem.eql(u8, arg, "test_repl")) return .test_repl;
    // Spec & Loop (v8.27)
    if (std.mem.eql(u8, arg, "spec-create") or std.mem.eql(u8, arg, "spec_create")) return .spec_create;
    if (std.mem.eql(u8, arg, "loop-decide") or std.mem.eql(u8, arg, "loop_decide")) return .loop_decide;
    // TVC (Distributed Learning)
    if (std.mem.eql(u8, arg, "tvc-demo") or std.mem.eql(u8, arg, "tvc")) return .tvc_demo;
    if (std.mem.eql(u8, arg, "tvc-stats")) return .tvc_stats;
    // Multi-Agent System
    if (std.mem.eql(u8, arg, "agents-demo") or std.mem.eql(u8, arg, "agents")) return .agents_demo;
    if (std.mem.eql(u8, arg, "agents-bench")) return .agents_bench;
    // Long Context
    if (std.mem.eql(u8, arg, "context-demo")) return .context_demo;
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
    // Multi-Modal Unified
    if (std.mem.eql(u8, arg, "multimodal-demo") or std.mem.eql(u8, arg, "multimodal")) return .multimodal_demo;
    if (std.mem.eql(u8, arg, "multimodal-bench")) return .multimodal_bench;
    // Multi-Modal Tool Use
    if (std.mem.eql(u8, arg, "tooluse-demo") or std.mem.eql(u8, arg, "tooluse")) return .tooluse_demo;
    if (std.mem.eql(u8, arg, "tooluse-bench")) return .tooluse_bench;
    // Unified Multi-Modal Agent
    if (std.mem.eql(u8, arg, "unified-demo") or std.mem.eql(u8, arg, "unified")) return .unified_demo;
    if (std.mem.eql(u8, arg, "unified-bench")) return .unified_bench;
    // Autonomous Agent
    if (std.mem.eql(u8, arg, "auto-demo") or std.mem.eql(u8, arg, "auto")) return .auto_demo;
    if (std.mem.eql(u8, arg, "auto-bench")) return .auto_bench;
    // Multi-Agent Orchestration
    if (std.mem.eql(u8, arg, "orch-demo") or std.mem.eql(u8, arg, "orch")) return .orch_demo;
    if (std.mem.eql(u8, arg, "orch-bench")) return .orch_bench;
    // Multi-Modal Multi-Agent
    if (std.mem.eql(u8, arg, "mmo-demo") or std.mem.eql(u8, arg, "mmo")) return .mm_orch_demo;
    if (std.mem.eql(u8, arg, "mmo-bench")) return .mm_orch_bench;
    // Agent Memory & Cross-Modal Learning
    if (std.mem.eql(u8, arg, "memory-demo")) return .memory_demo;
    if (std.mem.eql(u8, arg, "memory-bench")) return .memory_bench;
    // Persistent Memory & Disk Serialization
    if (std.mem.eql(u8, arg, "persist-demo") or std.mem.eql(u8, arg, "persist")) return .persist_demo;
    if (std.mem.eql(u8, arg, "persist-bench")) return .persist_bench;
    // Dynamic Agent Spawning & Load Balancing
    if (std.mem.eql(u8, arg, "spawn-demo") or std.mem.eql(u8, arg, "spawn")) return .spawn_demo;
    if (std.mem.eql(u8, arg, "spawn-bench")) return .spawn_bench;
    // Distributed Multi-Node Agents
    if (std.mem.eql(u8, arg, "cluster-demo") or std.mem.eql(u8, arg, "cluster")) return .cluster_demo;
    if (std.mem.eql(u8, arg, "cluster-bench")) return .cluster_bench;
    // Adaptive Work-Stealing Scheduler
    if (std.mem.eql(u8, arg, "worksteal-demo") or std.mem.eql(u8, arg, "worksteal") or std.mem.eql(u8, arg, "steal")) return .worksteal_demo;
    if (std.mem.eql(u8, arg, "worksteal-bench") or std.mem.eql(u8, arg, "steal-bench")) return .worksteal_bench;
    // Plugin & Extension System
    if (std.mem.eql(u8, arg, "plugin-demo") or std.mem.eql(u8, arg, "plugin") or std.mem.eql(u8, arg, "ext")) return .plugin_demo;
    if (std.mem.eql(u8, arg, "plugin-bench")) return .plugin_bench;
    // Agent Communication Protocol
    if (std.mem.eql(u8, arg, "comms-demo") or std.mem.eql(u8, arg, "comms") or std.mem.eql(u8, arg, "msg")) return .comms_demo;
    if (std.mem.eql(u8, arg, "comms-bench")) return .comms_bench;
    // Observability & Tracing System
    if (std.mem.eql(u8, arg, "observe-demo") or std.mem.eql(u8, arg, "observe") or std.mem.eql(u8, arg, "otel")) return .observe_demo;
    if (std.mem.eql(u8, arg, "observe-bench")) return .observe_bench;
    // Consensus & Coordination Protocol
    if (std.mem.eql(u8, arg, "consensus-demo") or std.mem.eql(u8, arg, "consensus") or std.mem.eql(u8, arg, "raft")) return .consensus_demo;
    if (std.mem.eql(u8, arg, "consensus-bench")) return .consensus_bench;
    // Speculative Execution Engine
    if (std.mem.eql(u8, arg, "specexec-demo") or std.mem.eql(u8, arg, "specexec")) return .specexec_demo;
    if (std.mem.eql(u8, arg, "specexec-bench")) return .specexec_bench;
    // Adaptive Resource Governor
    if (std.mem.eql(u8, arg, "governor-demo") or std.mem.eql(u8, arg, "governor") or std.mem.eql(u8, arg, "gov")) return .governor_demo;
    if (std.mem.eql(u8, arg, "governor-bench")) return .governor_bench;
    // Federated Learning Protocol
    if (std.mem.eql(u8, arg, "fedlearn-demo") or std.mem.eql(u8, arg, "fedlearn") or std.mem.eql(u8, arg, "fl")) return .fedlearn_demo;
    if (std.mem.eql(u8, arg, "fedlearn-bench")) return .fedlearn_bench;
    // Event Sourcing & CQRS Engine
    if (std.mem.eql(u8, arg, "eventsrc-demo") or std.mem.eql(u8, arg, "eventsrc") or std.mem.eql(u8, arg, "es")) return .eventsrc_demo;
    if (std.mem.eql(u8, arg, "eventsrc-bench")) return .eventsrc_bench;
    // Capability-Based Security Model
    if (std.mem.eql(u8, arg, "capsec-demo") or std.mem.eql(u8, arg, "capsec") or std.mem.eql(u8, arg, "sec")) return .capsec_demo;
    if (std.mem.eql(u8, arg, "capsec-bench")) return .capsec_bench;
    // Distributed Transaction Coordinator
    if (std.mem.eql(u8, arg, "dtxn-demo") or std.mem.eql(u8, arg, "dtxn")) return .dtxn_demo;
    if (std.mem.eql(u8, arg, "dtxn-bench")) return .dtxn_bench;
    // Adaptive Caching & Memoization
    if (std.mem.eql(u8, arg, "cache-demo") or std.mem.eql(u8, arg, "cache") or std.mem.eql(u8, arg, "memo")) return .cache_demo;
    if (std.mem.eql(u8, arg, "cache-bench")) return .cache_bench;
    // Contract-Based Agent Negotiation
    if (std.mem.eql(u8, arg, "contract-demo") or std.mem.eql(u8, arg, "contract") or std.mem.eql(u8, arg, "sla")) return .contract_demo;
    if (std.mem.eql(u8, arg, "contract-bench")) return .contract_bench;
    // Temporal Workflow Engine
    if (std.mem.eql(u8, arg, "workflow-demo") or std.mem.eql(u8, arg, "workflow") or std.mem.eql(u8, arg, "wf")) return .workflow_demo;
    if (std.mem.eql(u8, arg, "workflow-bench")) return .workflow_bench;
    // Sacred Mathematics (v3.6)
    if (std.mem.eql(u8, arg, "math")) return .math;
    if (std.mem.eql(u8, arg, "constants")) return .constants_cmd;
    if (std.mem.eql(u8, arg, "phi")) return .phi;
    if (std.mem.eql(u8, arg, "fib")) return .fib;
    if (std.mem.eql(u8, arg, "lucas")) return .lucas;
    if (std.mem.eql(u8, arg, "spiral")) return .spiral;
    if (std.mem.eql(u8, arg, "gematria")) return .gematria;
    if (std.mem.eql(u8, arg, "formula")) return .formula;
    if (std.mem.eql(u8, arg, "sacred")) return .sacred;
    // Sacred Biology (v14.0) — sub-commands handled by .bio
    if (std.mem.eql(u8, arg, "bio") or std.mem.eql(u8, arg, "bio-dna") or std.mem.eql(u8, arg, "bio-rna") or std.mem.eql(u8, arg, "bio-protein") or std.mem.eql(u8, arg, "bio-phi-genome") or std.mem.eql(u8, arg, "bio-codon")) return .bio;
    // Sacred Cosmology (v15.0) — sub-commands handled by .cosmos
    if (std.mem.eql(u8, arg, "cosmos") or std.mem.eql(u8, arg, "cosmos-hubble") or std.mem.eql(u8, arg, "cosmos-dark") or std.mem.eql(u8, arg, "cosmos-predict") or std.mem.eql(u8, arg, "cosmos-expand") or std.mem.eql(u8, arg, "cosmos-bigbang")) return .cosmos;
    // Sacred Neuroscience (v16.0) — sub-commands handled by .neuro
    if (std.mem.eql(u8, arg, "neuro") or std.mem.eql(u8, arg, "neuro-waves") or std.mem.eql(u8, arg, "neuro-consciousness") or std.mem.eql(u8, arg, "neuro-regions") or std.mem.eql(u8, arg, "neuro-network") or std.mem.eql(u8, arg, "neuro-synapse") or std.mem.eql(u8, arg, "neuro-neurons")) return .neuro;
    // Sacred Intelligence
    if (std.mem.eql(u8, arg, "intelligence") or std.mem.eql(u8, arg, "intel")) return .intelligence;
    // Sacred Agents (Cycle 98)
    if (std.mem.eql(u8, arg, "identity")) return .identity;
    if (std.mem.eql(u8, arg, "swarm")) return .swarm;
    if (std.mem.eql(u8, arg, "govern")) return .govern;
    if (std.mem.eql(u8, arg, "dashboard")) return .dashboard;
    if (std.mem.eql(u8, arg, "omega")) return .omega;
    if (std.mem.eql(u8, arg, "math-agent")) return .math_agent;
    // Dev Utilities
    if (std.mem.eql(u8, arg, "doctor")) return .doctor;
    if (std.mem.eql(u8, arg, "clean")) return .clean;
    if (std.mem.eql(u8, arg, "fmt")) return .fmt_cmd;
    if (std.mem.eql(u8, arg, "stats")) return .stats_cmd;
    if (std.mem.eql(u8, arg, "igla")) return .igla;
    // Testing (Cycle 100)
    if (std.mem.eql(u8, arg, "test-repl") or std.mem.eql(u8, arg, "test-repl-cmd")) return .test_repl;

    return .none;
}

test "parseCommand known commands" {
    try std.testing.expectEqual(cli_types.Command.chat, parseCommand("chat"));
    try std.testing.expectEqual(cli_types.Command.code, parseCommand("code"));
    try std.testing.expectEqual(cli_types.Command.gen, parseCommand("gen"));
    try std.testing.expectEqual(cli_types.Command.test_cmd, parseCommand("test"));
    try std.testing.expectEqual(cli_types.Command.commit, parseCommand("commit"));
    try std.testing.expectEqual(cli_types.Command.verdict, parseCommand("verdict"));
    try std.testing.expectEqual(cli_types.Command.doctor, parseCommand("doctor"));
    try std.testing.expectEqual(cli_types.Command.math, parseCommand("math"));
    try std.testing.expectEqual(cli_types.Command.phi, parseCommand("phi"));
    try std.testing.expectEqual(cli_types.Command.sacred, parseCommand("sacred"));
}

test "parseCommand unknown returns none" {
    try std.testing.expectEqual(cli_types.Command.none, parseCommand(""));
    try std.testing.expectEqual(cli_types.Command.none, parseCommand("nonexistent"));
    try std.testing.expectEqual(cli_types.Command.none, parseCommand("xyz123"));
}
