// 🤖 TRINITY v0.11.0: Suborbital Order
// B2T LLM-Assisted Decompilation
// LLM integration to improve decompilation quality
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY
//
// Scientific basis:
// - ICL4Decomp (arXiv:2511.01763): +40% re-executability
// - FidelityGPT (arXiv:2510.19615): 89% detection accuracy
// - ReCopilot (arXiv:2505.16366): +13% via data flow context

const std = @import("std");
const b2t_disasm = @import("b2t_disasm.zig");
const b2t_lifter = @import("b2t_lifter.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const TRINITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// DISTORTION TYPES (per FidelityGPT)
// ═══════════════════════════════════════════════════════════════════════════════

pub const DistortionType = enum {
    variable_naming, // Loss of variable names
    type_inference, // Incorrect type inference
    control_flow, // Control flow distortion
    loop_structure, // Loss of loop structure
    function_boundary, // Incorrect function boundaries
    calling_convention, // Calling convention errors
    memory_access, // Incorrect memory access
    constant_propagation, // Loss of constants
    dead_code, // False dead code
    inlining_artifact, // Inlining artifacts
};

pub const Distortion = struct {
    distortion_type: DistortionType,
    location: u64, // Address in binary
    line_number: u32, // Line in decompiled code
    severity: f32, // 0.0-1.0, where 1.0 = critical
    description: []const u8,
    suggested_fix: ?[]const u8,
    confidence: f32, // Detection confidence
};

// ═══════════════════════════════════════════════════════════════════════════════
// SEMANTIC CONTEXT (per ReCopilot)
// ═══════════════════════════════════════════════════════════════════════════════

pub const DataFlowNode = struct {
    variable_id: u32,
    definition_site: u64, // Where defined
    use_sites: std.ArrayList(u64), // Where used
    type_hint: ?[]const u8,
    is_parameter: bool,
    is_return_value: bool,

    pub fn init(allocator: std.mem.Allocator, var_id: u32) DataFlowNode {
        return DataFlowNode{
            .variable_id = var_id,
            .definition_site = 0,
            .use_sites = std.ArrayList(u64).init(allocator),
            .type_hint = null,
            .is_parameter = false,
            .is_return_value = false,
        };
    }

    pub fn deinit(self: *DataFlowNode) void {
        self.use_sites.deinit();
    }
};

pub const CallGraphNode = struct {
    function_address: u64,
    function_name: ?[]const u8,
    callers: std.ArrayList(u64), // Who calls
    callees: std.ArrayList(u64), // Whom calls
    is_library: bool,
    signature_hint: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator, addr: u64) CallGraphNode {
        return CallGraphNode{
            .function_address = addr,
            .function_name = null,
            .callers = std.ArrayList(u64).init(allocator),
            .callees = std.ArrayList(u64).init(allocator),
            .is_library = false,
            .signature_hint = null,
        };
    }

    pub fn deinit(self: *CallGraphNode) void {
        self.callers.deinit();
        self.callees.deinit();
    }
};

pub const SemanticContext = struct {
    allocator: std.mem.Allocator,
    data_flow: std.ArrayList(DataFlowNode),
    call_graph: std.ArrayList(CallGraphNode),
    string_references: std.ArrayList([]const u8),
    import_hints: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) SemanticContext {
        return SemanticContext{
            .allocator = allocator,
            .data_flow = std.ArrayList(DataFlowNode).init(allocator),
            .call_graph = std.ArrayList(CallGraphNode).init(allocator),
            .string_references = std.ArrayList([]const u8).init(allocator),
            .import_hints = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *SemanticContext) void {
        for (self.data_flow.items) |*node| {
            node.deinit();
        }
        self.data_flow.deinit();
        for (self.call_graph.items) |*node| {
            node.deinit();
        }
        self.call_graph.deinit();
        self.string_references.deinit();
        self.import_hints.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LLM RESPONSE TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const CodeChange = struct {
    line_start: u32,
    line_end: u32,
    old_code: []const u8,
    new_code: []const u8,
    change_type: []const u8, // "rename", "retype", "restructure"
    rationale: []const u8,
};

pub const CorrectedCode = struct {
    original: []const u8,
    corrected: []const u8,
    changes: std.ArrayList(CodeChange),
    confidence: f32,
    reasoning: []const u8, // Chain-of-thought explanation

    pub fn init(allocator: std.mem.Allocator) CorrectedCode {
        return CorrectedCode{
            .original = "",
            .corrected = "",
            .changes = std.ArrayList(CodeChange).init(allocator),
            .confidence = 0.0,
            .reasoning = "",
        };
    }

    pub fn deinit(self: *CorrectedCode) void {
        self.changes.deinit();
    }
};

pub const DecompilationResult = struct {
    function_name: []const u8,
    original_address: u64,
    decompiled_code: []const u8,
    corrected_code: []const u8,
    distortions_found: std.ArrayList(Distortion),
    distortions_fixed: std.ArrayList(Distortion),
    fix_rate: f32, // % of distortions fixed
    re_executable: bool, // Can it be recompiled?
    tokens_used: u32,

    pub fn init(allocator: std.mem.Allocator) DecompilationResult {
        return DecompilationResult{
            .function_name = "",
            .original_address = 0,
            .decompiled_code = "",
            .corrected_code = "",
            .distortions_found = std.ArrayList(Distortion).init(allocator),
            .distortions_fixed = std.ArrayList(Distortion).init(allocator),
            .fix_rate = 0.0,
            .re_executable = false,
            .tokens_used = 0,
        };
    }

    pub fn deinit(self: *DecompilationResult) void {
        self.distortions_found.deinit();
        self.distortions_fixed.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LLM ASSIST ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

pub const LLMAssistEngine = struct {
    allocator: std.mem.Allocator,
    context: SemanticContext,
    distortions: std.ArrayList(Distortion),

    pub fn init(allocator: std.mem.Allocator) LLMAssistEngine {
        return LLMAssistEngine{
            .allocator = allocator,
            .context = SemanticContext.init(allocator),
            .distortions = std.ArrayList(Distortion).init(allocator),
        };
    }

    pub fn deinit(self: *LLMAssistEngine) void {
        self.context.deinit();
        self.distortions.deinit();
    }

    /// Distortion detection in decompiled code
    pub fn detectDistortions(self: *LLMAssistEngine, code: []const u8) ![]Distortion {
        // Analyze distortion patterns
        var lines = std.mem.splitScalar(u8, code, '\n');
        var line_num: u32 = 0;

        while (lines.next()) |line| {
            line_num += 1;
            const trimmed = std.mem.trim(u8, line, " \t");

            // Detect meaningless variable names
            if (self.detectVariableNamingIssue(trimmed)) {
                try self.distortions.append(Distortion{
                    .distortion_type = .variable_naming,
                    .location = 0,
                    .line_number = line_num,
                    .severity = 0.7,
                    .description = "Meaningless variable name",
                    .suggested_fix = null,
                    .confidence = 0.8,
                });
            }

            // Detect type issues
            if (self.detectTypeIssue(trimmed)) {
                try self.distortions.append(Distortion{
                    .distortion_type = .type_inference,
                    .location = 0,
                    .line_number = line_num,
                    .severity = 0.8,
                    .description = "Possible type inference error",
                    .suggested_fix = null,
                    .confidence = 0.6,
                });
            }
        }

        return self.distortions.items;
    }

    fn detectVariableNamingIssue(self: *LLMAssistEngine, line: []const u8) bool {
        _ = self;
        // Patterns of meaningless names: v1, v2, var_1234, sub_5678
        const patterns = [_][]const u8{ "v1", "v2", "v3", "var_", "sub_", "loc_", "arg_" };
        for (patterns) |pattern| {
            if (std.mem.indexOf(u8, line, pattern) != null) {
                return true;
            }
        }
        return false;
    }

    fn detectTypeIssue(self: *LLMAssistEngine, line: []const u8) bool {
        _ = self;
        // Patterns of type issues: void*, int instead of pointer
        if (std.mem.indexOf(u8, line, "void*") != null) return true;
        if (std.mem.indexOf(u8, line, "(int)") != null) return true;
        return false;
    }

    /// Extract data flow context from TVC IR
    pub fn extractDataFlow(self: *LLMAssistEngine, func: *const b2t_lifter.TVCFunction) !void {
        for (func.blocks.items) |block| {
            for (block.instructions.items) |inst| {
                if (inst.dest) |dest_id| {
                    var node = DataFlowNode.init(self.allocator, dest_id);
                    node.definition_site = inst.source_address;

                    // Analyze usages
                    for (inst.operands[0..inst.operand_count]) |operand| {
                        if (operand != dest_id) {
                            try node.use_sites.append(inst.source_address);
                        }
                    }

                    try self.context.data_flow.append(node);
                }
            }
        }
    }

    /// Build call graph
    pub fn buildCallGraph(self: *LLMAssistEngine, module: *const b2t_lifter.TVCModule) !void {
        for (module.functions.items) |func| {
            var node = CallGraphNode.init(self.allocator, func.id);
            node.function_name = if (func.name.len > 0) func.name else null;

            // Search calls in function
            for (func.blocks.items) |block| {
                for (block.instructions.items) |inst| {
                    if (inst.opcode == .t_call) {
                        const callee_id = inst.operands[0];
                        try node.callees.append(callee_id);
                    }
                }
            }

            try self.context.call_graph.append(node);
        }
    }

    /// Compute semantic intensity (per FidelityGPT)
    pub fn computeSemanticIntensity(self: *LLMAssistEngine, line: []const u8) f32 {
        _ = self;
        var intensity: f32 = 0.0;

        // Factors increasing intensity:
        // - Presence of pointers
        if (std.mem.indexOf(u8, line, "*") != null) intensity += 0.2;
        // - Type casting
        if (std.mem.indexOf(u8, line, "(") != null and std.mem.indexOf(u8, line, ")") != null) intensity += 0.15;
        // - Pointer arithmetic
        if (std.mem.indexOf(u8, line, "->") != null) intensity += 0.25;
        // - Meaningless names
        if (std.mem.indexOf(u8, line, "v1") != null or std.mem.indexOf(u8, line, "v2") != null) intensity += 0.3;

        return @min(intensity, 1.0);
    }

    /// Generate LLM prompt
    pub fn generatePrompt(self: *LLMAssistEngine, code: []const u8, distortions: []const Distortion) ![]const u8 {
        var prompt = std.ArrayList(u8).init(self.allocator);
        const writer = prompt.writer();

        try writer.writeAll("You are Maxwell — decompilation expert. Fix distortions in code.\n\n");
        try writer.writeAll("CODE:\n```\n");
        try writer.writeAll(code);
        try writer.writeAll("\n```\n\n");

        try writer.writeAll("DETECTED DISTORTIONS:\n");
        for (distortions) |d| {
            try writer.print("- Line {d}: {s} (severity: {d:.2})\n", .{
                d.line_number,
                d.description,
                d.severity,
            });
        }

        try writer.writeAll("\nCONTEXT:\n");
        try writer.print("- String references: {d}\n", .{self.context.string_references.items.len});
        try writer.print("- Functions in call graph: {d}\n", .{self.context.call_graph.items.len});

        try writer.writeAll("\nOutput ONLY the corrected code.\n");

        return prompt.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "detect variable naming issues" {
    var engine = LLMAssistEngine.init(std.testing.allocator);
    defer engine.deinit();

    const code = "int v1 = v2 + v3;";
    const distortions = try engine.detectDistortions(code);

    try std.testing.expect(distortions.len > 0);
    try std.testing.expectEqual(DistortionType.variable_naming, distortions[0].distortion_type);
}

test "compute semantic intensity" {
    var engine = LLMAssistEngine.init(std.testing.allocator);
    defer engine.deinit();

    const low_intensity = engine.computeSemanticIntensity("int x = 5;");
    const high_intensity = engine.computeSemanticIntensity("void* v1 = (int*)ptr->data;");

    try std.testing.expect(high_intensity > low_intensity);
}

test "semantic context init and deinit" {
    var ctx = SemanticContext.init(std.testing.allocator);
    defer ctx.deinit();

    try std.testing.expectEqual(@as(usize, 0), ctx.data_flow.items.len);
}
// φ² + 1/φ² = 3 | TRINITY
