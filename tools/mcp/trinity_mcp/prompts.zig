// @origin(spec:prompts.tri) @regen(manual-impl)
//! Trinity MCP Prompts - Sacred Formula Templates
//! V = n × 3^k × π^m × φ^p × e^q | φ² + 1/φ² = 3 = TRINITY
// @origin(manual) @regen(pending)
const std = @import("std");

/// Prompt argument metadata
pub const Argument = struct {
    name: []const u8,
    description: []const u8,
    required: bool,
};

/// Prompt metadata
pub const PromptDef = struct {
    name: []const u8,
    description: []const u8,
    arguments: []const Argument,
};

/// All available prompts
pub const prompts = [_]PromptDef{
    .{
        .name = "sacred_formula_analysis",
        .description = "Analyze any value using Trinity's sacred formula V = n * 3^k * pi^m * phi^p * e^q",
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

/// Generate JSON list of all available prompts (MCP format)
pub fn generatePromptsList(allocator: std.mem.Allocator) ![]const u8 {
    var buf: std.ArrayList(u8) = .{};
    errdefer buf.deinit(allocator);

    try buf.appendSlice(allocator, "{\"prompts\":[");

    for (prompts, 0..) |p, i| {
        if (i > 0) try buf.appendSlice(allocator, ",");
        const writer = buf.writer(allocator);
        try writer.print(
            "{{\"name\":\"{s}\",\"description\":\"{s}\",\"arguments\":[",
            .{ p.name, p.description },
        );

        for (p.arguments, 0..) |arg, j| {
            if (j > 0) try buf.appendSlice(allocator, ",");
            try writer.print(
                "{{\"name\":\"{s}\",\"description\":\"{s}\",\"required\":{s}}}",
                .{ arg.name, arg.description, if (arg.required) "true" else "false" },
            );
        }

        try buf.appendSlice(allocator, "]}");
    }

    try buf.appendSlice(allocator, "]}");
    return buf.toOwnedSlice(allocator);
}

/// Check if a prompt name exists
pub fn hasPrompt(name: []const u8) bool {
    for (prompts) |p| {
        if (std.mem.eql(u8, p.name, name)) return true;
    }
    return false;
}

/// Generate prompt content response (MCP prompts/get format)
pub fn generatePromptGetResponse(allocator: std.mem.Allocator, name: []const u8, args_json: ?[]const u8) ![]const u8 {
    _ = args_json;
    var buf: std.ArrayList(u8) = .{};
    errdefer buf.deinit(allocator);

    if (std.mem.eql(u8, name, "sacred_formula_analysis")) {
        try appendEscapedPrompt(allocator, &buf,
            \\Analyze using Trinity's sacred formula:
            \\V = n * 3^k * pi^m * phi^p * e^q
            \\
            \\Where:
            \\- 3 = TRINITY (phi^2 + 1/phi^2 = 3)
            \\- pi = 3.141592653589793
            \\- phi = 1.618033988749895 (golden ratio)
            \\- e = 2.718281828459045
            \\
            \\Find integer exponents n, k, m, p, q.
            \\Show step-by-step derivation with error percentage.
        );
    } else if (std.mem.eql(u8, name, "sacred_derivation")) {
        try appendEscapedPrompt(allocator, &buf,
            \\Generate sacred formula derivation:
            \\1. Target experimental value
            \\2. Formula: V = n * 3^k * pi^m * phi^p * e^q
            \\3. Parameter fitting process
            \\4. Step-by-step calculation
            \\5. Final comparison with error %
        );
    } else if (std.mem.eql(u8, name, "gematria_analysis")) {
        try appendEscapedPrompt(allocator, &buf,
            \\Perform gematria analysis:
            \\1. Gematria value (letter-to-number mapping)
            \\2. Reduced value (digit sum)
            \\3. Sacred formula fit: V = n * 3^k * pi^m * phi^p * e^q
            \\4. Interpretation
        );
    } else if (std.mem.eql(u8, name, "trinity_code_review")) {
        try appendEscapedPrompt(allocator, &buf,
            \\Review code using Trinity principles:
            \\1. Sacred Mathematics: Does it honor phi, pi, e patterns?
            \\2. Ternary Logic: Are {-1, 0, +1} patterns used appropriately?
            \\3. Formula Integration: Can results fit V = n * 3^k * pi^m * phi^p * e^q?
            \\4. Code Quality: DRY, error handling, performance
        );
    } else if (std.mem.eql(u8, name, "sacred_exploration")) {
        try appendEscapedPrompt(allocator, &buf,
            \\Explore sacred mathematics:
            \\1. What is it and its significance?
            \\2. How does it relate to V = n * 3^k * pi^m * phi^p * e^q?
            \\3. Key numerical relationships
            \\4. Manifestations in nature, physics, consciousness
            \\5. Practical applications
        );
    } else {
        return error.PromptNotFound;
    }

    return buf.toOwnedSlice(allocator);
}

/// Append JSON-escaped prompt text wrapped in MCP messages format
fn appendEscapedPrompt(allocator: std.mem.Allocator, buf: *std.ArrayList(u8), text: []const u8) !void {
    try buf.appendSlice(allocator, "{\"messages\":[{\"role\":\"user\",\"content\":{\"type\":\"text\",\"text\":\"");
    for (text) |c| {
        switch (c) {
            '\\' => try buf.appendSlice(allocator, "\\\\"),
            '"' => try buf.appendSlice(allocator, "\\\""),
            '\n' => try buf.appendSlice(allocator, "\\n"),
            '\r' => try buf.appendSlice(allocator, "\\r"),
            '\t' => try buf.appendSlice(allocator, "\\t"),
            else => try buf.append(allocator, c),
        }
    }
    try buf.appendSlice(allocator, "\"}}]}");
}
