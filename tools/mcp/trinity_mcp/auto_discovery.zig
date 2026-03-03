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
        .name = "tri_consciousness",
        .display_name = "Quantum Consciousness",
        .description = "Calculate quantum consciousness metrics for frequency + brain wave",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"frequency_hertz":{"type":"number"},"brain_wave_freq":{"type":"number"}},"required":["frequency_hertz","brain_wave_freq"]}
    },
    .{
        .name = "tri_q_music",
        .display_name = "Quantum Music Resonance",
        .description = "Calculate φ-coherence for musical frequencies",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"frequencies":{"type":"array","items":{"type":"number"}}},"required":["frequencies"]}
    },
    .{
        .name = "tri_q_viz",
        .display_name = "Quantum Visualization",
        .description = "Generate Bloch sphere visualization data for quantum states",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"state":{"type":"string","enum":["zero","one","plus","minus","phi"]}}}
    },
    .{
        .name = "tri_bio_codon",
        .display_name = "Biology Codon Lookup",
        .description = "Look up codon → amino acid translation",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"codon":{"type":"string","minLength":3,"maxLength":3}},"required":["codon"]}
    },
    .{
        .name = "tri_cosmos_hubble",
        .display_name = "Cosmology Hubble",
        .description = "Sacred cosmology: Hubble tension resolution via φ",
        .input_schema = \\{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{}}
    },
    .{
        .name = "tri_constants",
        .display_name = "Sacred Constants",
        .description = "Show φ, π, e, Lucas numbers, Fibonacci",
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
