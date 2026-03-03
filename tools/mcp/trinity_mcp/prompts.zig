//! MCP Prompts Module
//!
//! Exposes prompt templates via MCP protocol.
//! φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

/// Prompt argument definition
pub const Arg = struct {
    name: []const u8,
    description: []const u8,
    required: bool = false,
};

/// Prompt template definition
pub const Prompt = struct {
    name: []const u8,
    description: []const u8,
    template: []const u8,
    args: []const Arg,
};

/// Available prompts
pub const prompts = [_]Prompt{
    .{
        .name = "code_review",
        .description = "Review code for quality, bugs, and improvements",
        .template =
            \\Please review the following code for:
            \\1. Code quality and style
            \\2. Potential bugs
            \\3. Performance issues
            \\4. Security vulnerabilities
            \\5. Suggestions for improvement
            \\
            \\Code:
            \\{code}
        ,
        .args = &[_]Arg{
            .{
                .name = "code",
                .description = "Code to review",
                .required = true,
            },
        },
    },
    .{
        .name = "sacred_math_analysis",
        .description = "Analyze mathematical patterns through sacred geometry lens",
        .template =
            \\Analyze the following mathematical expression for sacred geometry patterns:
            \\
            \\Expression: {expr}
            \\
            \\Consider:
            \\- Golden ratio (φ = 1.618...) relationships
            \\- Trinity patterns (φ² + 1/φ² = 3)
            \\- Lucas number connections
            \\- Fibonacci spiral approximations
            \\- Ternary computation (-1, 0, +1) patterns
        ,
        .args = &[_]Arg{
            .{
                .name = "expr",
                .description = "Mathematical expression to analyze",
                .required = true,
            },
        },
    },
    .{
        .name = "vibee_spec_helper",
        .description = "Generate VIBEE specification from natural language",
        .template =
            \\Convert the following feature description into a VIBEE specification:
            \\
            \\{description}
            \\
            \\Output the spec in YAML format with:
            \\- name: module_name
            \\- version: "1.0.0"
            \\- language: zig or varlog
            \\- types: with fields
            \\- behaviors: with given/when/then clauses
        ,
        .args = &[_]Arg{
            .{
                .name = "description",
                .description = "Feature description to convert",
                .required = true,
            },
        },
    },
    .{
        .name = "trinity_identity",
        .description = "Explore the Trinity identity φ² + 1/φ² = 3",
        .template =
            \\The Trinity Identity: φ² + 1/φ² = 3
            \\
            \\This is not a claim — it is a theorem.
            \\This is not a promise — it is a proof.
            \\This is not simulated — it is GPU verified.
            \\
            \\{aspect}
            \\
            \\Explain this aspect of the Trinity identity and its significance
            \\for ternary computation, the Golden Chain, and sacred mathematics.
        ,
        .args = &[_]Arg{
            .{
                .name = "aspect",
                .description = "Specific aspect to explore (proof, significance, computation, etc.)",
                .required = false,
            },
        },
    },
    .{
        .name = "golden_chain_analysis",
        .description = "Analyze development cycle using Golden Chain metrics",
        .template =
            \\Analyze the following Golden Chain development cycle:
            \\
            \\{metrics}
            \\
            \\Evaluate:
            \\1. Cycle completion time
            \\2. Code quality score
            \\3. Test coverage percentage
            \\4. Automation level
            \\5. Regression pattern detection
            \\
            \\Provide recommendations for the next cycle iteration based on
            \\SUCCESS_HISTORY.md patterns and REGRESSION_PATTERNS.md warnings.
        ,
        .args = &[_]Arg{
            .{
                .name = "metrics",
                .description = "Golden Chain metrics (JSON or text format)",
                .required = true,
            },
        },
    },
};

/// Generate prompts list JSON
pub fn generatePromptsList(allocator: std.mem.Allocator) ![]const u8 {
    var json_list = std.array_list.Managed(u8).init(allocator);
    try json_list.appendSlice("{\"jsonrpc\":\"2.0\",\"result\":{\"prompts\":[");

    for (prompts, 0..) |prompt, i| {
        if (i > 0) try json_list.append(',');

        // Start prompt object
        try json_list.print(
            "{{\"name\":\"{s}\",\"description\":\"{s}\",\"arguments\":["
        , .{ prompt.name, prompt.description });

        // Add arguments
        for (prompt.args, 0..) |arg, j| {
            if (j > 0) try json_list.append(',');
            try json_list.print(
                "{{\"name\":\"{s}\",\"description\":\"{s}\",\"required\":{s}}}"
            , .{ arg.name, arg.description, if (arg.required) "true" else "false" });
        }

        try json_list.appendSlice("]}}");
    }

    try json_list.appendSlice("]}}");
    return json_list.toOwnedSlice();
}

/// Get prompt by name
pub fn getPrompt(name: []const u8) !*const Prompt {
    for (&prompts) |*prompt| {
        if (std.mem.eql(u8, prompt.name, name)) {
            return prompt;
        }
    }
    return error.PromptNotFound;
}

/// Render prompt template with arguments
pub fn renderPrompt(allocator: std.mem.Allocator, prompt: *const Prompt, args_map: std.StringHashMap([]const u8)) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    var template = prompt.template;

    // Simple template replacement: {key} -> value
    while (std.mem.indexOf(u8, template, "{")) |start_idx| {
        // Add text before placeholder
        try result.appendSlice(template[0..start_idx]);

        // Find closing brace
        const end_idx = std.mem.indexOf(u8, template[start_idx..], "}") orelse {
            // No closing brace, treat as literal
            try result.appendSlice(template[start_idx..start_idx + 1]);
            template = template[start_idx + 1 ..];
            continue;
        };

        // Extract key
        const key = template[start_idx + 1 .. start_idx + end_idx];

        // Look up value
        if (args_map.get(key)) |value| {
            try result.appendSlice(value);
        } else {
            // Keep placeholder if not found
            try result.appendSlice(template[0 .. start_idx + end_idx + 1]);
        }

        template = template[start_idx + end_idx + 1 ..];
    }

    // Add remaining text
    try result.appendSlice(template);

    return result.toOwnedSlice();
}

/// Check if a prompt exists
pub fn hasPrompt(name: []const u8) bool {
    for (prompts) |prompt| {
        if (std.mem.eql(u8, prompt.name, name)) {
            return true;
        }
    }
    return false;
}

/// Generate prompt GET response (MCP spec format)
pub fn generatePromptGetResponse(allocator: std.mem.Allocator, name: []const u8, args_map: ?std.StringHashMap([]const u8)) ![]const u8 {
    _ = args_map; // Argument interpolation not yet implemented
    const prompt = try getPrompt(name);

    var json_list = std.array_list.Managed(u8).init(allocator);
    try json_list.appendSlice("{\"jsonrpc\":\"2.0\",\"result\":{\"messages\":[");
    try json_list.appendSlice("{\"role\":\"user\",\"content\":{");

    // Return template with JSON string escaping
    try json_list.appendSlice("\"type\":\"text\",\"text\":\"");
    try jsonEscapeString(allocator, &json_list, prompt.template);
    try json_list.appendSlice("\"}");

    try json_list.appendSlice("}]}}");
    return json_list.toOwnedSlice();
}

/// JSON escape a string and append to ArrayList
fn jsonEscapeString(allocator: std.mem.Allocator, list: *std.array_list.Managed(u8), str: []const u8) !void {
    _ = allocator;
    for (str) |c| {
        switch (c) {
            '\\' => try list.appendSlice("\\\\"),
            '"' => try list.appendSlice("\\\""),
            '\n' => try list.appendSlice("\\n"),
            '\r' => try list.appendSlice("\\r"),
            '\t' => try list.appendSlice("\\t"),
            else => try list.append(c),
        }
    }
}
