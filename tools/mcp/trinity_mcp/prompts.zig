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
}
