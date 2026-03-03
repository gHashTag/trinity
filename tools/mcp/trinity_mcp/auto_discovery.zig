//! MCP Auto-Discovery Module
//!
//! Auto-generates MCP tool definitions from TRI Command enum.
//! φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

/// Command metadata for MCP auto-discovery
pub const CommandMetadata = struct {
    name: []const u8,
    description: []const u8,
    category: []const u8,
    mcp_enabled: bool = true,
    input_schema: ?[]const u8 = null,
};

/// Get metadata for a command by name
/// Returns metadata for core MCP tools or a default for unknown commands
pub fn getCommandMetadataByName(cmd_name: []const u8) CommandMetadata {
    // Core Trinity MCP Server tools
    const desc: []const u8 = blk: {
        if (std.mem.eql(u8, cmd_name, "mcp_health")) break :blk "Check server health status";
        if (std.mem.eql(u8, cmd_name, "mcp_version")) break :blk "Get server version and protocol info";
        if (std.mem.eql(u8, cmd_name, "mcp_stats")) break :blk "Get server statistics";
        if (std.mem.eql(u8, cmd_name, "mcp_resources_list")) break :blk "List available resources";
        if (std.mem.eql(u8, cmd_name, "mcp_resources_read")) break :blk "Read a resource by URI";
        if (std.mem.eql(u8, cmd_name, "mcp_prometheus_metrics")) break :blk "Get Prometheus metrics";
        break :blk "Execute MCP command";
    };

    const category: []const u8 = getCommandCategory(cmd_name);

    return .{
        .name = cmd_name,
        .description = desc,
        .category = category,
        .mcp_enabled = true,
        .input_schema = null,
    };
}

/// Get category for a command
fn getCommandCategory(cmd: []const u8) []const u8 {
    // Core commands
    if (std.mem.eql(u8, cmd, "chat") or std.mem.eql(u8, cmd, "code") or
        std.mem.eql(u8, cmd, "gen") or std.mem.eql(u8, cmd, "fix") or
        std.mem.eql(u8, cmd, "explain") or std.mem.eql(u8, cmd, "test_cmd") or
        std.mem.eql(u8, cmd, "doc") or std.mem.eql(u8, cmd, "refactor") or
        std.mem.eql(u8, cmd, "reason")) {
        return "core";
    }

    // VIBEE commands
    if (std.mem.eql(u8, cmd, "convert") or std.mem.eql(u8, cmd, "serve") or
        std.mem.eql(u8, cmd, "bench") or std.mem.eql(u8, cmd, "evolve")) {
        return "vibee";
    }

    // Git commands
    if (std.mem.eql(u8, cmd, "commit") or std.mem.eql(u8, cmd, "diff") or
        std.mem.eql(u8, cmd, "status") or std.mem.eql(u8, cmd, "log")) {
        return "git";
    }

    // Golden Chain Pipeline
    if (std.mem.eql(u8, cmd, "pipeline") or std.mem.eql(u8, cmd, "decompose") or
        std.mem.eql(u8, cmd, "plan") or std.mem.eql(u8, cmd, "verify") or
        std.mem.eql(u8, cmd, "verdict")) {
        return "pipeline";
    }

    // Sacred Math
    if (std.mem.eql(u8, cmd, "math") or std.mem.eql(u8, cmd, "constants_cmd") or
        std.mem.eql(u8, cmd, "phi") or std.mem.eql(u8, cmd, "fib") or
        std.mem.eql(u8, cmd, "lucas") or std.mem.eql(u8, cmd, "spiral") or
        std.mem.eql(u8, cmd, "gematria") or std.mem.eql(u8, cmd, "formula_cmd") or
        std.mem.eql(u8, cmd, "sacred")) {
        return "math";
    }

    // Sacred Science
    if (std.mem.eql(u8, cmd, "bio") or std.mem.eql(u8, cmd, "cosmos") or
        std.mem.eql(u8, cmd, "neuro")) {
        return "science";
    }

    // Demo/Bench commands
    if (std.mem.indexOf(u8, cmd, "_demo") != null or std.mem.indexOf(u8, cmd, "_bench") != null) {
        return "demo";
    }

    // Dev utilities
    if (std.mem.eql(u8, cmd, "doctor") or std.mem.eql(u8, cmd, "clean") or
        std.mem.eql(u8, cmd, "fmt_cmd") or std.mem.eql(u8, cmd, "stats_cmd") or
        std.mem.eql(u8, cmd, "igla")) {
        return "dev";
    }

    // Sacred Intelligence
    if (std.mem.eql(u8, cmd, "identity") or std.mem.eql(u8, cmd, "swarm") or
        std.mem.eql(u8, cmd, "govern") or std.mem.eql(u8, cmd, "dashboard") or
        std.mem.eql(u8, cmd, "omega") or std.mem.eql(u8, cmd, "math_agent")) {
        return "intelligence";
    }

    // Info
    if (std.mem.eql(u8, cmd, "info") or std.mem.eql(u8, cmd, "version") or
        std.mem.eql(u8, cmd, "help")) {
        return "info";
    }

    return "general";
}

/// Command descriptions array (indexed by Command enum)
fn commandDescriptions() []const []const u8 {
    return &[_][]const u8{
        "Interactive REPL mode",                                 // none
        "Interactive chat (vision + voice + tools)",              // chat
        "Generate code with typing effect",                       // code
        "Compile VIBEE spec to Zig/Verilog",                      // gen
        "Detect and fix bugs",                                    // fix
        "Explain code or concept",                                // explain
        "Generate tests for code",                                // test_cmd
        "Generate documentation",                                 // doc
        "Suggest refactoring",                                    // refactor
        "Chain-of-thought reasoning",                             // reason
        "Convert VIBEE spec to another format",                   // convert
        "Start TRI API server",                                   // serve
        "Run performance benchmarks",                             // bench
        "Evolve VIBEE specification",                             // evolve
        "Git commit (add -A && commit)",                          // commit
        "Git diff",                                               // diff
        "Git status --short",                                     // status
        "Git log --oneline",                                      // log
        "Execute 17-link Golden Chain",                           // pipeline
        "Break task into sub-tasks (Link 4)",                     // decompose
        "Generate implementation plan (Link 5)",                  // plan
        "Run tests + benchmarks (Links 7-11)",                    // verify
        "Generate toxic verdict (Link 14)",                       // verdict
        "Test REPL commands",                                     // test_repl
        "Create new .vibee specification template",               // spec_create
        "Loop decision: CONTINUE/EXIT (Link 17)",                 // loop_decide
        "Run TVC chat demo",                                      // tvc_demo
        "Show TVC corpus statistics",                             // tvc_stats
        "Multi-agent coordination demo",                          // agents_demo
        "Multi-agent coordination benchmark",                     // agents_bench
        "Long context handling demo",                             // context_demo
        "Long context handling benchmark",                        // context_bench
        "Retrieval-augmented generation demo",                    // rag_demo
        "Retrieval-augmented generation benchmark",               // rag_bench
        "Voice I/O (TTS + STT) demo",                             // voice_demo
        "Voice I/O benchmark",                                    // voice_bench
        "Code execution sandbox demo",                            // sandbox_demo
        "Code execution sandbox benchmark",                       // sandbox_bench
        "Streaming output demo",                                  // stream_demo
        "Streaming output benchmark",                             // stream_bench
        "Local vision analysis demo",                             // vision_demo
        "Local vision benchmark",                                 // vision_bench
        "Fine-tuning engine demo",                                // finetune_demo
        "Fine-tuning benchmark",                                  // finetune_bench
        "Batched work-stealing demo",                             // batched_demo
        "Batched work-stealing benchmark",                        // batched_bench
        "Priority queue scheduling demo",                         // priority_demo
        "Priority queue scheduling benchmark",                    // priority_bench
        "Deadline scheduling demo",                               // deadline_demo
        "Deadline scheduling benchmark",                          // deadline_bench
        "Multi-modal unified demo",                               // multimodal_demo
        "Multi-modal unified benchmark",                          // multimodal_bench
        "Multi-modal tool use demo",                              // tooluse_demo
        "Multi-modal tool use benchmark",                         // tooluse_bench
        "Unified agent demo",                                     // unified_demo
        "Unified agent benchmark",                                // unified_bench
        "Autonomous agent demo",                                  // autonomous_demo
        "Autonomous agent benchmark",                             // autonomous_bench
        "Multi-agent orchestration demo",                         // orchestration_demo
        "Multi-agent orchestration benchmark",                    // orchestration_bench
        "Multi-modal orchestration demo",                         // mm_orch_demo
        "Multi-modal orchestration benchmark",                    // mm_orch_bench
        "Agent memory demo",                                      // memory_demo
        "Agent memory benchmark",                                 // memory_bench
        "Persistent memory demo",                                 // persist_demo
        "Persistent memory benchmark",                            // persist_bench
        "Dynamic agent spawning demo",                            // spawn_demo
        "Dynamic agent spawning benchmark",                       // spawn_bench
        "Multi-node cluster demo",                                // cluster_demo
        "Multi-node cluster benchmark",                           // cluster_bench
        "Work-stealing scheduler demo",                           // worksteal_demo
        "Work-stealing scheduler benchmark",                      // worksteal_bench
        "Plugin system demo",                                     // plugin_demo
        "Plugin system benchmark",                                // plugin_bench
        "Agent communication demo",                               // comms_demo
        "Agent communication benchmark",                          // comms_bench
        "Observability demo",                                     // observe_demo
        "Observability benchmark",                                // observe_bench
        "Consensus protocol demo",                                // consensus_demo
        "Consensus protocol benchmark",                           // consensus_bench
        "Speculative execution demo",                             // specexec_demo
        "Speculative execution benchmark",                        // specexec_bench
        "Resource governor demo",                                 // governor_demo
        "Resource governor benchmark",                            // governor_bench
        "Federated learning demo",                                // fedlearn_demo
        "Federated learning benchmark",                           // fedlearn_bench
        "Event sourcing demo",                                    // eventsrc_demo
        "Event sourcing benchmark",                               // eventsrc_bench
        "Capability security demo",                               // capsec_demo
        "Capability security benchmark",                          // capsec_bench
        "Distributed transaction demo",                           // dtxn_demo
        "Distributed transaction benchmark",                      // dtxn_bench
        "Adaptive caching demo",                                  // cache_demo
        "Adaptive caching benchmark",                             // cache_bench
        "Contract negotiation demo",                              // contract_demo
        "Contract negotiation benchmark",                         // contract_bench
        "Temporal workflow demo",                                 // workflow_demo
        "Temporal workflow benchmark",                            // workflow_bench
        "Distributed inference",                                  // distributed
        "Multi-cluster mode",                                     // multi_cluster
        "Sacred mathematics dispatcher",                          // math
        "Show sacred constants (φ, π, e, μ, χ, σ, ε...)",        // constants_cmd
        "Compute φⁿ (golden ratio power)",                        // phi
        "Fibonacci with BigInt",                                  // fib
        "Lucas L(n) — L(2)=3=TRINITY",                           // lucas
        "φ-spiral coordinates",                                   // spiral
        "Gematria analysis (word → number)",                      // gematria
        "Mathematical formulas",                                  // formula_cmd
        "Sacred mathematics suite",                               // sacred
        "Biology v14.0 — DNA/RNA/Protein analysis",              // bio
        "Cosmology v15.0 — Hubble, dark energy, expansion",      // cosmos
        "Neuroscience v16.0 — Brain waves, consciousness",       // neuro
        "Intelligence system",                                    // intelligence
        "System diagnostics",                                     // doctor
        "Clean build artifacts",                                  // clean
        "Format code",                                            // fmt_cmd
        "Show project statistics",                                // stats_cmd
        "IGLA agent interface",                                   // igla
        "Sacred identity",                                        // identity
        "Swarm intelligence",                                     // swarm
        "Governance system",                                      // govern
        "Dashboard",                                              // dashboard
        "Omega system",                                           // omega
        "Math agent",                                             // math_agent
        "Code analysis",                                          // analyze
        "Code search",                                            // search_cmd
        "Dependency analysis",                                    // deps
        "Codebase context",                                       // context_info
        "Temporal Trinity system",                                // time
        "Install components",                                     // install
        "Build project",                                          // build_cmd
        "Generate deck",                                          // deck_generate
        "FPGA demo",                                              // fpga_demo
        "Full sacred cycle",                                      // sacred_full_cycle
        "Quantum Trinity",                                        // quantum
        "Release cosmic",                                         // release_cosmic
        "Omega command",                                          // omega_cmd
        "All command",                                            // all_cmd
        "Holo command",                                           // holo_cmd
        "Release absolute",                                       // release_absolute
        "Omega evolve",                                           // omega_evolve
        "TRINITY OS boot",                                        // launch
        "System information",                                     // info
        "Show version",                                           // version
        "Show help",                                              // help
        "NEEDLE structural editor",                               // needle
        "NEEDLE search",                                          // needle_search
        "NEEDLE check",                                           // needle_check
    };
}

/// Generate MCP tools list JSON from core MCP tools
/// Note: This returns the Trinity MCP Server's native tools, not TRI commands
pub fn generateToolsList(allocator: std.mem.Allocator) ![]const u8 {
    // Core Trinity MCP Server tools (not TRI commands)
    const core_tools = [_]struct { name: []const u8, description: []const u8, category: []const u8 }{
        .{ .name = "mcp_health", .description = "Check server health status", .category = "server" },
        .{ .name = "mcp_version", .description = "Get server version and protocol info", .category = "server" },
        .{ .name = "mcp_stats", .description = "Get server statistics", .category = "server" },
        .{ .name = "mcp_resources_list", .description = "List available resources", .category = "resources" },
        .{ .name = "mcp_resources_read", .description = "Read a resource by URI", .category = "resources" },
        .{ .name = "mcp_prometheus_metrics", .description = "Get Prometheus metrics", .category = "monitoring" },
    };

    var json_list = std.array_list.Managed(u8).init(allocator);
    defer json_list.deinit();
    try json_list.appendSlice("{\"jsonrpc\":\"2.0\",\"result\":{\"tools\":[");

    for (core_tools, 0..) |tool, i| {
        if (i > 0) try json_list.append(',');
        try json_list.print(
            "{{\"name\":\"{s}\",\"description\":\"{s}\",\"category\":\"{s}\"}}"
        , .{ tool.name, tool.description, tool.category });
    }

    try json_list.appendSlice("]}}");
    return json_list.toOwnedSlice();
}

/// Count total tools available
pub fn countTools() usize {
    // Core Trinity MCP Server tools
    return 6;
}

/// Get tool name for a command (with "tri_" prefix)
pub fn getToolName(cmd: []const u8) []const u8 {
    if (std.mem.startsWith(u8, cmd, "tri_")) {
        return cmd;
    }
    // For internal command names, add "tri_" prefix
    return cmd; // Note: this would need proper allocation in production
}
