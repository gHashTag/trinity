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
}
