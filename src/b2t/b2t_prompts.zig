// 🤖 TRINITY v0.11.0: Suborbital Order
// B2T Prompts - Distortion-Aware Prompt Templates
// Prompt templates for LLM-assisted decompilation
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY
//
// Scientific basis:
// - FidelityGPT: Distortion-aware prompt templates
// - ICL4Decomp: In-context learning with examples
// - Chain-of-Thought: Step-by-step reasoning

const std = @import("std");
const b2t_llm_assist = @import("b2t_llm_assist.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// PROMPT TEMPLATES
// ═══════════════════════════════════════════════════════════════════════════════

pub const PromptTemplate = struct {
    name: []const u8,
    template: []const u8,
    distortion_aware: bool,
    examples_count: u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// SYSTEM PROMPTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const MAXWELL_DECOMPILER_PROMPT =
    \\You are Maxwell — an autonomous decompiler agent working on ternary logic principles.
    \\
    \\YOUR ROLE:
    \\- Analyze decompiled code and find semantic distortions
    \\- Restore meaningful variable and function names
    \\- Correct control flow structure
    \\- Output correct data types
    \\
    \\PRINCIPLES OF TERNARY LOGIC:
    \\- For each decision, consider three outcomes: negative, neutral, positive
    \\- Use the formula: φ² + 1/φ² = 3 = TRINITY
    \\- Uncertainty is not an error, but a third state
    \\
    \\LIMITATIONS:
    \\- Generate ONLY code, without explanations (if not requested)
    \\- Preserve original semantics
    \\- Do not add functionality that wasn't present
    \\
    \\RESPONSE FORMAT:
    \\```c
    \\// corrected code
    \\```
;

pub const DISTORTION_DETECTOR_PROMPT =
    \\You are an expert in decompilation quality analysis.
    \\
    \\YOUR TASK:
    \\Find semantic distortions in decompiled code.
    \\
    \\DISTORTION TYPES:
    \\1. variable_naming — meaningless names (v1, v2, sub_1234)
    \\2. type_inference — incorrect types (int instead of pointer)
    \\3. control_flow — distorted loops and conditions
    \\4. loop_structure — loss of for/while structure
    \\5. function_boundary — incorrect function boundaries
    \\6. calling_convention — ABI errors
    \\7. memory_access — incorrect pointers
    \\8. constant_propagation — loss of constants
    \\9. dead_code — false dead code
    \\10. inlining_artifact — inlining artifacts
    \\
    \\RESPONSE FORMAT:
    \\```json
    \\{
    \\  "distortions": [
    \\    {
    \\      "type": "variable_naming",
    \\      "line": 5,
    \\      "severity": 0.8,
    \\      "description": "v1 should be 'buffer_size'"
    \\    }
    \\  ]
    \\}
    \\```
;

pub const SEMANTIC_RECOVERER_PROMPT =
    \\You are an expert at restoring semantics from binary code.
    \\
    \\CONTEXT:
    \\You are given decompiled code with distortions and additional context:
    \\- Data flow graph
    \\- Call graph
    \\- String literals
    \\- Imported symbols
    \\
    \\YOUR TASK:
    \\Restore meaningful code using all available context.
    \\
    \\STRATEGY:
    \\1. Analyze string literals — they often indicate purpose
    \\2. Study the call graph — library function names are informative
    \\3. Trace data flow — where values come from and go to
    \\4. Apply patterns — typical constructions (malloc/free, open/close)
    \\
    \\φ² + 1/φ² = 3 = TRINITY
;

// ═══════════════════════════════════════════════════════════════════════════════
// DISTORTION-SPECIFIC TEMPLATES
// ═══════════════════════════════════════════════════════════════════════════════

pub const VARIABLE_NAMING_TEMPLATE = PromptTemplate{
    .name = "variable_naming_fix",
    .template =
    \\Fix variable names in this code:
    \\```
    \\{code}
    \\```
    \\
    \\CONTEXT:
    \\- Strings in code: {string_refs}
    \\- Called functions: {callees}
    \\
    \\DETECTED PROBLEMS:
    \\{distortions}
    \\
    \\CORRECTION EXAMPLES:
    \\{examples}
    \\
    \\Output ONLY corrected code.
    ,
    .distortion_aware = true,
    .examples_count = 3,
};

pub const TYPE_INFERENCE_TEMPLATE = PromptTemplate{
    .name = "type_inference_fix",
    .template =
    \\Fix types in this code:
    \\```
    \\{code}
    \\```
    \\
    \\CONTEXT:
    \\- Called function signatures: {signatures}
    \\- Data sizes: {sizes}
    \\
    \\DETECTED PROBLEMS:
    \\{distortions}
    \\
    \\EXAMPLES:
    \\{examples}
    \\
    \\Output ONLY corrected code with correct types.
    ,
    .distortion_aware = true,
    .examples_count = 5,
};

pub const CONTROL_FLOW_TEMPLATE = PromptTemplate{
    .name = "control_flow_fix",
    .template =
    \\Restore control flow structure:
    \\```
    \\{code}
    \\```
    \\
    \\TVC IR shows the correct structure:
    \\```
    \\{tvc_ir}
    \\```
    \\
    \\RESTORATION EXAMPLES:
    \\{examples}
    \\
    \\Convert goto to structured constructs.
    \\Output ONLY corrected code.
    ,
    .distortion_aware = true,
    .examples_count = 3,
};

// ═══════════════════════════════════════════════════════════════════════════════
// PROMPT BUILDER
// ═══════════════════════════════════════════════════════════════════════════════

pub const PromptBuilder = struct {
    allocator: std.mem.Allocator,
    buffer: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) PromptBuilder {
        return PromptBuilder{
            .allocator = allocator,
            .buffer = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *PromptBuilder) void {
        self.buffer.deinit();
    }

    /// Build prompt for distortion detection
    pub fn buildDetectionPrompt(self: *PromptBuilder, code: []const u8) ![]const u8 {
        self.buffer.clearRetainingCapacity();
        const writer = self.buffer.writer();

        try writer.writeAll(DISTORTION_DETECTOR_PROMPT);
        try writer.writeAll("\n\nCODE FOR ANALYSIS:\n```\n");
        try writer.writeAll(code);
        try writer.writeAll("\n```\n");

        return self.buffer.items;
    }

    /// Build prompt for correction
    pub fn buildCorrectionPrompt(
        self: *PromptBuilder,
        template: PromptTemplate,
        code: []const u8,
        distortions: []const b2t_llm_assist.Distortion,
        examples: []const []const u8,
    ) ![]const u8 {
        self.buffer.clearRetainingCapacity();
        const writer = self.buffer.writer();

        try writer.writeAll(MAXWELL_DECOMPILER_PROMPT);
        try writer.writeAll("\n\n");

        // Substitute variables into template
        const template_copy = template.template;

        // Replace {code}
        if (std.mem.indexOf(u8, template_copy, "{code}")) |_| {
            try writer.writeAll("CODE:\n```\n");
            try writer.writeAll(code);
            try writer.writeAll("\n```\n\n");
        }

        // Replace {distortions}
        if (std.mem.indexOf(u8, template_copy, "{distortions}")) |_| {
            try writer.writeAll("DISTORTIONS:\n");
            for (distortions) |d| {
                try writer.print("- Line {d}: {s} (severity: {d:.2})\n", .{
                    d.line_number,
                    d.description,
                    d.severity,
                });
            }
            try writer.writeAll("\n");
        }

        // Replace {examples}
        if (std.mem.indexOf(u8, template_copy, "{examples}")) |_| {
            try writer.writeAll("EXAMPLES:\n");
            for (examples, 0..) |example, i| {
                try writer.print("Example {d}:\n```\n{s}\n```\n\n", .{ i + 1, example });
            }
        }

        return self.buffer.items;
    }

    /// Build Chain-of-Thought prompt
    pub fn buildCoTPrompt(self: *PromptBuilder, code: []const u8, context: []const u8) ![]const u8 {
        self.buffer.clearRetainingCapacity();
        const writer = self.buffer.writer();

        try writer.writeAll(SEMANTIC_RECOVERER_PROMPT);
        try writer.writeAll("\n\n");

        try writer.writeAll("CODE:\n```\n");
        try writer.writeAll(code);
        try writer.writeAll("\n```\n\n");

        try writer.writeAll("CONTEXT:\n");
        try writer.writeAll(context);
        try writer.writeAll("\n\n");

        try writer.writeAll(
            \\STEP-BY-STEP REASONING:
            \\
            \\Step 1: Analyze string literals
            \\What do they say about function purpose?
            \\
            \\Step 2: Analyze call graph
            \\Which functions are called? What does this say about functionality?
            \\
            \\Step 3: Analyze data flow
            \\Where do input data come from? Where do outputs go?
            \\
            \\Step 4: Distortion detection
            \\What distortions are present? In what order to fix?
            \\
            \\Step 5: Apply corrections
            \\Fix distortions by priority.
            \\
            \\Step 6: Final validation
            \\Does code compile? Is semantics equivalent to original?
            \\
            \\Output final corrected code.
        );

        return self.buffer.items;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TEMPLATE SELECTOR
// ═══════════════════════════════════════════════════════════════════════════════

/// Select template based on distortion type
pub fn selectTemplate(distortion_type: b2t_llm_assist.DistortionType) PromptTemplate {
    return switch (distortion_type) {
        .variable_naming => VARIABLE_NAMING_TEMPLATE,
        .type_inference => TYPE_INFERENCE_TEMPLATE,
        .control_flow, .loop_structure => CONTROL_FLOW_TEMPLATE,
        else => VARIABLE_NAMING_TEMPLATE, // Default
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "prompt builder init and deinit" {
    var builder = PromptBuilder.init(std.testing.allocator);
    defer builder.deinit();

    try std.testing.expectEqual(@as(usize, 0), builder.buffer.items.len);
}

test "build detection prompt" {
    var builder = PromptBuilder.init(std.testing.allocator);
    defer builder.deinit();

    const prompt = try builder.buildDetectionPrompt("int v1 = v2 + v3;");
    try std.testing.expect(prompt.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, prompt, "v1") != null);
}

test "select template for variable naming" {
    const template = selectTemplate(.variable_naming);
    try std.testing.expect(std.mem.eql(u8, template.name, "variable_naming_fix"));
    try std.testing.expect(template.distortion_aware);
}

test "build cot prompt" {
    var builder = PromptBuilder.init(std.testing.allocator);
    defer builder.deinit();

    const prompt = try builder.buildCoTPrompt("int x = 5;", "No context");
    try std.testing.expect(prompt.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, prompt, "Step 1") != null);
}
// φ² + 1/φ² = 3 | TRINITY
