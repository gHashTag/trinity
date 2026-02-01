// B2T LLM-Assisted Decompilation
// Интеграция LLM для улучшения качества декомпиляции
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY
//
// Научная основа:
// - ICL4Decomp (arXiv:2511.01763): +40% re-executability
// - FidelityGPT (arXiv:2510.19615): 89% detection accuracy
// - ReCopilot (arXiv:2505.16366): +13% через data flow context

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
// DISTORTION TYPES (по FidelityGPT)
// ═══════════════════════════════════════════════════════════════════════════════

pub const DistortionType = enum {
    variable_naming, // Потеря имён переменных
    type_inference, // Неверный вывод типов
    control_flow, // Искажение потока управления
    loop_structure, // Потеря структуры циклов
    function_boundary, // Неверные границы функций
    calling_convention, // Ошибки соглашения о вызовах
    memory_access, // Неверный доступ к памяти
    constant_propagation, // Потеря констант
    dead_code, // Ложный мёртвый код
    inlining_artifact, // Артефакты инлайнинга
};

pub const Distortion = struct {
    distortion_type: DistortionType,
    location: u64, // Адрес в бинарнике
    line_number: u32, // Строка в декомпилированном коде
    severity: f32, // 0.0-1.0, где 1.0 = критично
    description: []const u8,
    suggested_fix: ?[]const u8,
    confidence: f32, // Уверенность детекции
};

// ═══════════════════════════════════════════════════════════════════════════════
// SEMANTIC CONTEXT (по ReCopilot)
// ═══════════════════════════════════════════════════════════════════════════════

pub const DataFlowNode = struct {
    variable_id: u32,
    definition_site: u64, // Где определена
    use_sites: std.ArrayList(u64), // Где используется
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
    callers: std.ArrayList(u64), // Кто вызывает
    callees: std.ArrayList(u64), // Кого вызывает
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
    reasoning: []const u8, // Chain-of-thought объяснение

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
    fix_rate: f32, // % исправленных искажений
    re_executable: bool, // Можно ли перекомпилировать?
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

    /// Детекция искажений в декомпилированном коде
    pub fn detectDistortions(self: *LLMAssistEngine, code: []const u8) ![]Distortion {
        // Анализ паттернов искажений
        var lines = std.mem.splitScalar(u8, code, '\n');
        var line_num: u32 = 0;

        while (lines.next()) |line| {
            line_num += 1;
            const trimmed = std.mem.trim(u8, line, " \t");

            // Детекция бессмысленных имён переменных
            if (self.detectVariableNamingIssue(trimmed)) {
                try self.distortions.append(Distortion{
                    .distortion_type = .variable_naming,
                    .location = 0,
                    .line_number = line_num,
                    .severity = 0.7,
                    .description = "Бессмысленное имя переменной",
                    .suggested_fix = null,
                    .confidence = 0.8,
                });
            }

            // Детекция проблем с типами
            if (self.detectTypeIssue(trimmed)) {
                try self.distortions.append(Distortion{
                    .distortion_type = .type_inference,
                    .location = 0,
                    .line_number = line_num,
                    .severity = 0.8,
                    .description = "Возможная ошибка вывода типа",
                    .suggested_fix = null,
                    .confidence = 0.6,
                });
            }
        }

        return self.distortions.items;
    }

    fn detectVariableNamingIssue(self: *LLMAssistEngine, line: []const u8) bool {
        _ = self;
        // Паттерны бессмысленных имён: v1, v2, var_1234, sub_5678
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
        // Паттерны проблем с типами: void*, int вместо pointer
        if (std.mem.indexOf(u8, line, "void*") != null) return true;
        if (std.mem.indexOf(u8, line, "(int)") != null) return true;
        return false;
    }

    /// Извлечение контекста потока данных из TVC IR
    pub fn extractDataFlow(self: *LLMAssistEngine, func: *const b2t_lifter.TVCFunction) !void {
        for (func.blocks.items) |block| {
            for (block.instructions.items) |inst| {
                if (inst.dest) |dest_id| {
                    var node = DataFlowNode.init(self.allocator, dest_id);
                    node.definition_site = inst.source_address;

                    // Анализ использований
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

    /// Построение графа вызовов
    pub fn buildCallGraph(self: *LLMAssistEngine, module: *const b2t_lifter.TVCModule) !void {
        for (module.functions.items) |func| {
            var node = CallGraphNode.init(self.allocator, func.id);
            node.function_name = if (func.name.len > 0) func.name else null;

            // Поиск вызовов в функции
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

    /// Вычисление семантической интенсивности (по FidelityGPT)
    pub fn computeSemanticIntensity(self: *LLMAssistEngine, line: []const u8) f32 {
        _ = self;
        var intensity: f32 = 0.0;

        // Факторы, увеличивающие интенсивность:
        // - Наличие указателей
        if (std.mem.indexOf(u8, line, "*") != null) intensity += 0.2;
        // - Приведение типов
        if (std.mem.indexOf(u8, line, "(") != null and std.mem.indexOf(u8, line, ")") != null) intensity += 0.15;
        // - Арифметика с указателями
        if (std.mem.indexOf(u8, line, "->") != null) intensity += 0.25;
        // - Бессмысленные имена
        if (std.mem.indexOf(u8, line, "v1") != null or std.mem.indexOf(u8, line, "v2") != null) intensity += 0.3;

        return @min(intensity, 1.0);
    }

    /// Генерация промпта для LLM
    pub fn generatePrompt(self: *LLMAssistEngine, code: []const u8, distortions: []const Distortion) ![]const u8 {
        var prompt = std.ArrayList(u8).init(self.allocator);
        const writer = prompt.writer();

        try writer.writeAll("Ты Maxwell — эксперт по декомпиляции. Исправь искажения в коде.\n\n");
        try writer.writeAll("КОД:\n```\n");
        try writer.writeAll(code);
        try writer.writeAll("\n```\n\n");

        try writer.writeAll("ОБНАРУЖЕННЫЕ ИСКАЖЕНИЯ:\n");
        for (distortions) |d| {
            try writer.print("- Строка {d}: {s} (severity: {d:.2})\n", .{
                d.line_number,
                d.description,
                d.severity,
            });
        }

        try writer.writeAll("\nКОНТЕКСТ:\n");
        try writer.print("- Строковые ссылки: {d}\n", .{self.context.string_references.items.len});
        try writer.print("- Функции в графе вызовов: {d}\n", .{self.context.call_graph.items.len});

        try writer.writeAll("\nВыведи ТОЛЬКО исправленный код.\n");

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
