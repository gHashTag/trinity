<<<<<<< HEAD
//! Auto-discovery for Trinity MCP tools
//! Generates tools list from Trinity CLI commands
const std = @import("std");

/// Trinity Tool definition
const TrinityTool = struct {
    name: []const u8,
    display_name: []const u8,
    description: []const u8,
    input_schema: []const u8,
};

/// List of all Trinity tools exposed via MCP
const trinity_tools = [_]TrinityTool{
    // === SACRED MATH (9 tools) ===
    .{
        .name = "tri_constants",
        .display_name = "Sacred Constants",
        .description = "Show φ, π, e, Lucas numbers, Fibonacci",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{}}
    },
    .{
        .name = "tri_phi",
        .display_name = "Phi Power",
        .description = "Compute φⁿ for any integer n",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"n":{"type":"integer"}},"required":["n"]}
    },
    .{
        .name = "tri_fib",
        .display_name = "Fibonacci",
        .description = "Calculate Fibonacci numbers with BigInt",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"n":{"type":"integer"}},"required":["n"]}
    },
    .{
        .name = "tri_lucas",
        .display_name = "Lucas Numbers",
        .description = "Calculate Lucas L(n) — L(2)=3=TRINITY",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"n":{"type":"integer"}},"required":["n"]}
    },
    .{
        .name = "tri_spiral",
        .display_name = "Phi Spiral",
        .description = "Generate φ-spiral coordinates",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"points":{"type":"integer"}},"required":["points"]}
    },
    .{
        .name = "tri_quantum_constants",
        .display_name = "Quantum Constants",
        .description = "Show sacred quantum constants: φ, ħ, h, α",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{}}
    },
    .{
        .name = "tri_quantum_states",
        .display_name = "Quantum States",
        .description = "Show quantum states |0⟩, |1⟩, |+⟩, |−⟩, |φ⟩ with probabilities",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{}}
    },
    .{
        .name = "tri_bell_states",
        .display_name = "Bell States",
        .description = "Show Bell states (maximally entangled two-qubit states)",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{}}
    },
    .{
        .name = "tri_gematria",
        .display_name = "Gematria",
        .description = "Multi-language gematria calculation",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"text":{"type":"string"},"language":{"type":"string"}},"required":["text"]}
    },

    // === CHEMISTRY (5 tools) ===
    .{
        .name = "tri_chem_periodic",
        .display_name = "Periodic Table",
        .description = "Display ASCII periodic table (118 elements)",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{}}
    },
    .{
        .name = "tri_chem_element",
        .display_name = "Element Info",
        .description = "Show element information card by symbol or atomic number",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"element":{"type":"string"}},"required":["element"]}
    },
    .{
        .name = "tri_chem_mass",
        .display_name = "Molar Mass",
        .description = "Calculate molar mass of chemical formula (e.g., H2O = 18.015 g/mol)",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"formula":{"type":"string"}},"required":["formula"]}
    },
    .{
        .name = "tri_chem_formula",
        .display_name = "Formula Analysis",
        .description = "Analyze chemical formula composition",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"formula":{"type":"string"}},"required":["formula"]}
    },
    .{
        .name = "tri_chem_moles",
        .display_name = "Mole Calculator",
        .description = "Calculate moles, molecules, atoms from mass",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"mass":{"type":"number"},"formula":{"type":"string"}},"required":["mass","formula"]}
    },

    // === BIOLOGY (3 tools) ===
    .{
        .name = "tri_bio_dna",
        .display_name = "DNA Analysis",
        .description = "Analyze DNA sequence with sacred mathematics",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"sequence":{"type":"string"}},"required":["sequence"]}
    },
    .{
        .name = "tri_bio_codon",
        .display_name = "Codon Lookup",
        .description = "Look up codon → amino acid translation",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"codon":{"type":"string","minLength":3,"maxLength":3}},"required":["codon"]}
    },
    .{
        .name = "tri_bio_protein",
        .display_name = "Protein Analysis",
        .description = "Analyze protein sequence with φ-spiral encoding",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"sequence":{"type":"string"}},"required":["sequence"]}
    },

    // === COSMOLOGY (2 tools) ===
    .{
        .name = "tri_cosmos_hubble",
        .display_name = "Hubble Tension",
        .description = "Sacred cosmology: Hubble tension resolution via φ",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{}}
    },
    .{
        .name = "tri_cosmos_dark",
        .display_name = "Dark Energy",
        .description = "Dark energy π-patterns in universe expansion",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{}}
    },

    // === SACRED INTELLIGENCE (3 tools) ===
    .{
        .name = "tri_identity",
        .display_name = "Sacred Identity",
        .description = "Sacred identity system: node, generate, verify, reputation",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"subcommand":{"type":"string"}}}
    },
    .{
        .name = "tri_swarm",
        .display_name = "Swarm Intelligence",
        .description = "Swarm intelligence: status, coordinator, agents, tasks, converge",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"subcommand":{"type":"string"}}}
    },
    .{
        .name = "tri_govern",
        .display_name = "Governance System",
        .description = "Governance: proposals, vote, treasury, rewards",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"subcommand":{"type":"string"}}}
    },

    // === NEEDLE (3 tools) ===
    .{
        .name = "tri_needle",
        .display_name = "Needle Editor",
        .description = "AST-aware structural code editing",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"file":{"type":"string"},"query":{"type":"string"}}}
    },
    .{
        .name = "tri_needle_search",
        .display_name = "Needle Search",
        .description = "Search AST patterns in codebase",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"pattern":{"type":"string"}},"required":["pattern"]}
    },
    .{
        .name = "tri_needle_check",
        .display_name = "Needle Check",
        .description = "Lint and validate code quality",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"file":{"type":"string"}}}
    },

    // === MESH (3 tools) ===
    .{
        .name = "tri_mesh_status",
        .display_name = "Mesh Status",
        .description = "Trinity mesh network status",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{}}
    },
    .{
        .name = "tri_mesh_topology",
        .display_name = "Mesh Topology",
        .description = "Show mesh network topology",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{}}
    },
    .{
        .name = "tri_mesh_regions",
        .display_name = "Mesh Regions",
        .description = "Show mesh regions and nodes",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{}}
    },

    // === OMEGA (3 tools) ===
    .{
        .name = "tri_omega_status",
        .display_name = "Omega Status",
        .description = "Omega economy engine status",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{}}
    },
    .{
        .name = "tri_omega_rewards",
        .display_name = "Omega Rewards",
        .description = "View $TRI reward pool",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{}}
    },
    .{
        .name = "tri_omega_reputation",
        .display_name = "Reputation Leaderboard",
        .description = "Show Omega reputation leaderboard",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{}}
    },

    // === WALLET (3 tools) ===
    .{
        .name = "tri_wallet_balance",
        .display_name = "Wallet Balance",
        .description = "View $TRI wallet balance",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"address":{"type":"string"}}}
    },
    .{
        .name = "tri_wallet_claim",
        .display_name = "Claim Rewards",
        .description = "Claim $TRI rewards from Omega pool",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"amount":{"type":"number"}}}
    },
    .{
        .name = "tri_wallet_history",
        .display_name = "Claim History",
        .description = "View $TRI claim history",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{}}
    },

    // === DASHBOARD (3 tools) ===
    .{
        .name = "tri_dashboard_serve",
        .display_name = "Dashboard Server",
        .description = "Start Trinity HTTP dashboard",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"port":{"type":"integer"}}}
    },
    .{
        .name = "tri_dashboard_metrics",
        .display_name = "Dashboard Metrics",
        .description = "Get dashboard metrics",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{}}
    },
    .{
        .name = "tri_dashboard_nodes",
        .display_name = "Dashboard Nodes",
        .description = "Show connected nodes",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{}}
    },

    // === HARDWARE (2 tools) ===
    .{
        .name = "tri_hardware_info",
        .display_name = "Hardware Info",
        .description = "Show system hardware information",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{}}
    },
    .{
        .name = "tri_hardware_benchmark",
        .display_name = "Hardware Benchmark",
        .description = "Run hardware benchmarks",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{}}
    },
};

pub fn generateToolsList(allocator: std.mem.Allocator) ![]const u8 {
    // Use allocPrint for simplicity - it calculates the size internally
    var tool_strings: [trinity_tools.len][]const u8 = undefined;

    for (trinity_tools, 0..) |tool, i| {
        const json = try std.fmt.allocPrint(allocator,
            \\{{"name":"{s}","display_name":"{s}","description":"{s}","inputSchema":{s}}}
        , .{ tool.name, tool.display_name, tool.description, tool.input_schema });
        tool_strings[i] = json;
    }

    // Calculate exact size: opening + commas between tools + tools + closing
    var total_size: usize = 10; // "{\"tools\":["
    for (tool_strings) |json| {
        total_size += json.len;
    }
    total_size += tool_strings.len - 1; // commas between tools
    total_size += 2; // "]}"

    // Allocate result buffer
    const result = try allocator.alloc(u8, total_size);
    errdefer allocator.free(result);

    var pos: usize = 0;

    // Write opening
    @memcpy(result[pos..pos+10], "{\"tools\":[");
    pos += 10;

    // Write each tool
    for (tool_strings, 0..) |json, i| {
        if (i > 0) {
            result[pos] = ',';
            pos += 1;
        }
        @memcpy(result[pos..pos+json.len], json);
        pos += json.len;
        allocator.free(json); // Free temporary strings
    }

    // Write closing
    @memcpy(result[pos..pos+2], "]}");
    pos += 2;

    return result[0..pos];
}

pub fn countTools() usize {
    return trinity_tools.len;
=======
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
>>>>>>> ralph/nexus-src
}
