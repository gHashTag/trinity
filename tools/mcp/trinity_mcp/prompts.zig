<<<<<<< HEAD
//! Trinity MCP Prompts - Sacred Formula Templates
//! V = n × 3^k × π^m × φ^p × e^q | φ² + 1/φ² = 3 = TRINITY
const std = @import("std");

/// Prompt argument metadata
pub const Argument = struct {
    name: []const u8,
    description: []const u8,
    required: bool,
};

/// Prompt metadata
pub const Prompt = struct {
    name: []const u8,
    description: []const u8,
    arguments: []const Argument,
};

/// Generate JSON list of all available prompts
pub fn generatePromptsList(allocator: std.mem.Allocator) ![]const u8 {
    const prompts = [_]Prompt{
        .{
            .name = "sacred_formula_analysis",
            .description = "Analyze any value using Trinity's sacred formula V = n × 3^k × π^m × φ^p × e^q",
            .arguments = &[_]Argument{
                .{ .name = "value", .description = "Target value to analyze", .required = true },
                .{ .name = "extended", .description = "Use extended bounds for fitting", .required = false },
            },
        },
        .{
            .name = "sacred_derivation",
            .description = "Generate step-by-step sacred formula derivation for a known constant",
            .arguments = &[_]Argument{
                .{ .name = "constant", .description = "Constant name (alpha, proton_electron_mass, etc.)", .required = true },
            },
        },
        .{
            .name = "gematria_analysis",
            .description = "Analyze text using Coptic gematria with sacred formula fitting",
            .arguments = &[_]Argument{
                .{ .name = "text", .description = "Text to analyze", .required = true },
                .{ .name = "method", .description = "Gematria method (coptic, hebrew, english)", .required = false },
            },
        },
        .{
            .name = "trinity_code_review",
            .description = "Review code using Trinity principles: sacred math, ternary logic, formula integration",
            .arguments = &[_]Argument{
                .{ .name = "file_path", .description = "Path to file to review", .required = true },
                .{ .name = "focus", .description = "Focus area (sacred, ternary, formula, quality)", .required = false },
            },
        },
        .{
            .name = "sacred_exploration",
            .description = "Explore sacred mathematical patterns and their relationships",
            .arguments = &[_]Argument{
                .{ .name = "topic", .description = "Topic to explore (phi, fibonacci, lucas, trinity, consciousness)", .required = false },
            },
        },
    };

    var json_buffer = std.ArrayList(u8).init(allocator);
    defer json_buffer.deinit();

    try json_buffer.appendSlice("{\"prompts\":[");

    for (prompts, 0..) |p, i| {
        if (i > 0) try json_buffer.appendSlice(",");

        try json_buffer.print(
            \\{{"name":"{s}","description":"{s}","arguments":[
        , .{ p.name, p.description });

        for (p.arguments, 0..) |arg, j| {
            if (j > 0) try json_buffer.appendSlice(",");
            try json_buffer.print(
                \\{{"name":"{s}","description":"{s}","required":{s}}}
            , .{ arg.name, arg.description, if (arg.required) "true" else "false" });
        }

        try json_buffer.appendSlice("]}");
    }

    try json_buffer.appendSlice("]}");

    return json_buffer.toOwnedSlice();
}

/// Check if a prompt name exists
pub fn hasPrompt(name: []const u8) bool {
    if (std.mem.eql(u8, name, "sacred_formula_analysis")) return true;
    if (std.mem.eql(u8, name, "sacred_derivation")) return true;
    if (std.mem.eql(u8, name, "gematria_analysis")) return true;
    if (std.mem.eql(u8, name, "trinity_code_review")) return true;
    if (std.mem.eql(u8, name, "sacred_exploration")) return true;
    return false;
}

/// Generate prompt content with arguments substituted
pub fn generatePromptGetResponse(
    allocator: std.mem.Allocator,
    name: []const u8,
    args: ?[]const u8
) ![]const u8 {
    const args_slice = args orelse "";

    if (std.mem.eql(u8, name, "sacred_formula_analysis")) {
        return formatSacredFormulaAnalysis(allocator, args_slice);
    }

    if (std.mem.eql(u8, name, "sacred_derivation")) {
        return formatSacredDerivation(allocator, args_slice);
    }

    if (std.mem.eql(u8, name, "gematria_analysis")) {
        return formatGematriaAnalysis(allocator, args_slice);
    }

    if (std.mem.eql(u8, name, "trinity_code_review")) {
        return formatTrinityCodeReview(allocator, args_slice);
    }

    if (std.mem.eql(u8, name, "sacred_exploration")) {
        return formatSacredExploration(allocator, args_slice);
    }

    return error.PromptNotFound;
}

/// Format sacred formula analysis prompt
fn formatSacredFormulaAnalysis(allocator: std.mem.Allocator, args: []const u8) ![]const u8 {
    // Parse value from args (simplified - assumes "value:137.036" format)
    const default_value = "137.036";
    const value = if (args.len > 0) args else default_value;

    const prompt =
        \\Analyze the value {s} using Trinity's sacred formula:
        \\
        \\V = n × 3^k × π^m × φ^p × e^q
        \\
        \\Where:
        \\- 3 = TRINITY (φ² + 1/φ² = 3)
        \\- π = 3.141592653589793 (circle constant)
        \\- φ = 1.618033988749895 (golden ratio)
        \\- e = 2.718281828459045 (Euler's number)
        \\
        \\Find integer exponents n, k, m, p, q such that:
        \\V ≈ {s}
        \\
        \\Show step-by-step derivation and include:
        \\1. The fitted parameters (n, k, m, p, q)
        \\2. Computed value vs target
        \\3. Error percentage
        \\4. Physical/sacred interpretation
        \\
        \\Remember: φ² + 1/φ² = 3 = TRINITY
    ;

    return std.fmt.allocPrint(allocator, prompt, .{ value, value });
}

/// Format sacred derivation prompt
fn formatSacredDerivation(allocator: std.mem.Allocator, args: []const u8) ![]const u8 {
    const default_constant = "alpha";
    const constant = if (args.len > 0) args else default_constant;

    const prompt =
        \\Generate the sacred formula derivation for {s}:
        \\
        \\Show:
        \\1. Target experimental value
        \\2. Formula: V = n × 3^k × π^m × φ^p × e^q
        \\3. Parameter fitting process
        \\4. Step-by-step calculation:
        \\   - Calculate 3^k
        \\   - Calculate π^m
        \\   - Calculate φ^p
        \\   - Calculate e^q
        \\   - Combine: n × 3^k × π^m × φ^p × e^q
        \\5. Final comparison with error %
        \\
        \\Output format:
        \\┌─────────────────────────────────────┐
        \\│ SACRED DERIVATION: {s}           │
        \\├─────────────────────────────────────┤
        \\│ [detailed steps]                    │
        \\└─────────────────────────────────────┘
        \\
        \\Remember: φ² + 1/φ² = 3 = TRINITY
    ;

    return std.fmt.allocPrint(allocator, prompt, .{constant, constant});
}

/// Format gematria analysis prompt
fn formatGematriaAnalysis(allocator: std.mem.Allocator, args: []const u8) ![]const u8 {
    const default_text = "TRINITY";
    const text = if (args.len > 0) args else default_text;

    const prompt =
        \\Perform gematria analysis on: "{s}"
        \\
        \\Method: Coptic
        \\
        \\Calculate:
        \\1. Gematria value (A=1, B=2, ..., Θ=9, I=10, ...)
        \\2. Reduced value (sum of digits until single digit)
        \\3. Sacred formula fit: V = n × 3^k × π^m × φ^p × e^q
        \\4. Interpretation
        \\
        \\Show glyph-by-glyph breakdown with character values:
        \\
        \\┌─────────┬───────┬─────────┐
        \\│ Glyph   │ Value │ Coptic  │
        \\├─────────┼───────┼─────────┤
        \\│ T       │ 400   │ Ⲧ       │
        \\│ R       │ 100   │ Ⲣ       │
        \\│ I       │ 10    │ ⲓ       │
        \\│ N       │ 50    │ Ⲛ       │
        \\│ I       │ 10    │ ⲓ       │
        \\│ T       │ 400   │ Ⲧ       │
        \\│ Y       │ 400   │ Ⲩ       │
        \\├─────────┼───────┼─────────┤
        \\│ Total   │ 1370  │         │
        \\└─────────┴───────┴─────────┘
        \\
        \\Remember: φ² + 1/φ² = 3 = TRINITY
    ;

    return std.fmt.allocPrint(allocator, prompt, .{text});
}

/// Format Trinity code review prompt
fn formatTrinityCodeReview(allocator: std.mem.Allocator, args: []const u8) ![]const u8 {
    const default_path = "src/main.zig";
    const file_path = if (args.len > 0) args else default_path;

    const prompt =
        \\Review {s} using Trinity principles:
        \\
        \\Focus: all
        \\
        \\Review Criteria:
        \\1. Sacred Mathematics: Does it honor φ, π, e patterns?
        \\2. Ternary Logic: Are {-1, 0, +1} patterns used appropriately?
        \\3. Formula Integration: Can results fit V = n × 3^k × π^m × φ^p × e^q?
        \\4. Code Quality: DRY, error handling, performance
        \\
        \\Provide:
        \\- Strengths (with φ rating: φ⁻³ to φ³)
        \\- Issues (with severity -1/0/+1)
        \\- Sacred formula optimization opportunities
        \\- Specific improvements with code examples
        \\
        \\Output format:
        \\┌─────────────────────────────────────┐
        \\│ TRINITY CODE REVIEW: {s}         │
        \\├─────────────────────────────────────┤
        \\│ RATING: φ² (Excellent)              │
        \\├─────────────────────────────────────┤
        \\│ [Strengths, Issues, Improvements]   │
        \\└─────────────────────────────────────┘
        \\
        \\Remember: φ² + 1/φ² = 3 = TRINITY
    ;

    return std.fmt.allocPrint(allocator, prompt, .{ file_path, file_path });
}

/// Format sacred exploration prompt
fn formatSacredExploration(allocator: std.mem.Allocator, args: []const u8) ![]const u8 {
    const default_topic = "phi";
    const topic = if (args.len > 0) args else default_topic;

    const prompt =
        \\Explore sacred mathematics: {s}
        \\
        \\Guiding Questions:
        \\1. What is the {s} and its significance?
        \\2. How does it relate to V = n × 3^k × π^m × φ^p × e^q?
        \\3. What are the key numerical relationships?
        \\4. How does it manifest in nature, physics, or consciousness?
        \\5. What are the practical applications?
        \\
        \\Include:
        \\- Mathematical definitions
        \\- Visual/geometric interpretations
        \\- Real-world examples
        \\- Connections to TRINITY (φ² + 1/φ² = 3)
        \\
        \\Remember: The sacred formula connects all constants.
    ;

    return std.fmt.allocPrint(allocator, prompt, .{ topic, topic });
=======
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
>>>>>>> ralph/nexus-src
}
