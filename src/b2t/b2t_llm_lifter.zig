// B2T LLM-Enhanced Lifter
// Улучшение качества TVC IR через LLM-ассистирование
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const b2t_disasm = @import("b2t_disasm.zig");
const b2t_lifter = @import("b2t_lifter.zig");
const b2t_llm_assist = @import("b2t_llm_assist.zig");
const b2t_rag = @import("b2t_rag.zig");
const b2t_prompts = @import("b2t_prompts.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// ENHANCED IR TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const StructField = struct {
    name: []const u8,
    field_type: []const u8,
    offset: u32,
    size: u32,
};

pub const StructDef = struct {
    name: []const u8,
    fields: std.ArrayList(StructField),
    size: u32,
    alignment: u32,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) StructDef {
        return StructDef{
            .name = name,
            .fields = std.ArrayList(StructField).init(allocator),
            .size = 0,
            .alignment = 1,
        };
    }

    pub fn deinit(self: *StructDef) void {
        self.fields.deinit();
    }
};

pub const CodeComment = struct {
    line: u32,
    comment: []const u8,
    comment_type: CommentType,
};

pub const CommentType = enum {
    function_purpose, // Назначение функции
    parameter_description, // Описание параметра
    return_value, // Описание возврата
    algorithm_step, // Шаг алгоритма
    warning, // Предупреждение
    todo, // TODO
};

pub const EnhancedTVCFunction = struct {
    allocator: std.mem.Allocator,
    base: b2t_lifter.TVCFunction,
    semantic_name: []const u8,
    semantic_signature: []const u8,
    variable_names: std.AutoHashMap(u32, []const u8),
    type_annotations: std.AutoHashMap(u32, []const u8),
    struct_definitions: std.ArrayList(StructDef),
    comments: std.ArrayList(CodeComment),
    confidence: f32,

    pub fn init(allocator: std.mem.Allocator, base_func: b2t_lifter.TVCFunction) EnhancedTVCFunction {
        return EnhancedTVCFunction{
            .allocator = allocator,
            .base = base_func,
            .semantic_name = "",
            .semantic_signature = "",
            .variable_names = std.AutoHashMap(u32, []const u8).init(allocator),
            .type_annotations = std.AutoHashMap(u32, []const u8).init(allocator),
            .struct_definitions = std.ArrayList(StructDef).init(allocator),
            .comments = std.ArrayList(CodeComment).init(allocator),
            .confidence = 0.0,
        };
    }

    pub fn deinit(self: *EnhancedTVCFunction) void {
        self.variable_names.deinit();
        self.type_annotations.deinit();
        for (self.struct_definitions.items) |*s| {
            s.deinit();
        }
        self.struct_definitions.deinit();
        self.comments.deinit();
        self.base.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LIFTING STAGES
// ═══════════════════════════════════════════════════════════════════════════════

pub const LiftingStage = enum {
    disassembly, // Дизассемблирование
    basic_lifting, // Базовый lifting
    ssa_conversion, // SSA преобразование
    type_inference, // Вывод типов
    name_recovery, // Восстановление имён
    struct_recovery, // Восстановление структур
    pattern_recognition, // Распознавание паттернов
    comment_generation, // Генерация комментариев
    final_validation, // Финальная валидация
};

pub const LiftingProgress = struct {
    current_stage: LiftingStage,
    stages_completed: std.ArrayList(LiftingStage),
    llm_calls: u32,
    tokens_used: u32,
    time_elapsed_ms: u64,

    pub fn init(allocator: std.mem.Allocator) LiftingProgress {
        return LiftingProgress{
            .current_stage = .disassembly,
            .stages_completed = std.ArrayList(LiftingStage).init(allocator),
            .llm_calls = 0,
            .tokens_used = 0,
            .time_elapsed_ms = 0,
        };
    }

    pub fn deinit(self: *LiftingProgress) void {
        self.stages_completed.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const LLMLiftingConfig = struct {
    enable_name_recovery: bool = true,
    enable_type_inference: bool = true,
    enable_struct_recovery: bool = true,
    enable_pattern_recognition: bool = true,
    enable_comments: bool = true,
    max_llm_calls_per_function: u32 = 10,
    confidence_threshold: f32 = 0.7,
    use_rag: bool = true,
    rag_examples_count: u32 = 5,
    fallback_on_error: bool = true,
};

// ═══════════════════════════════════════════════════════════════════════════════
// LLM LIFTER ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

pub const LLMLifterEngine = struct {
    allocator: std.mem.Allocator,
    config: LLMLiftingConfig,
    llm_assist: b2t_llm_assist.LLMAssistEngine,
    rag_engine: b2t_rag.RAGEngine,
    prompt_builder: b2t_prompts.PromptBuilder,
    progress: LiftingProgress,

    pub fn init(allocator: std.mem.Allocator, config: LLMLiftingConfig) LLMLifterEngine {
        return LLMLifterEngine{
            .allocator = allocator,
            .config = config,
            .llm_assist = b2t_llm_assist.LLMAssistEngine.init(allocator),
            .rag_engine = b2t_rag.RAGEngine.init(allocator),
            .prompt_builder = b2t_prompts.PromptBuilder.init(allocator),
            .progress = LiftingProgress.init(allocator),
        };
    }

    pub fn deinit(self: *LLMLifterEngine) void {
        self.llm_assist.deinit();
        self.rag_engine.deinit();
        self.prompt_builder.deinit();
        self.progress.deinit();
    }

    /// Полный пайплайн lifting с LLM
    pub fn liftWithLLM(self: *LLMLifterEngine, disasm_result: *const b2t_disasm.DisassemblyResult) !std.ArrayList(EnhancedTVCFunction) {
        var enhanced_functions = std.ArrayList(EnhancedTVCFunction).init(self.allocator);

        // Базовый lifting
        var lifter = b2t_lifter.Lifter.init(self.allocator);
        defer lifter.deinit();

        const module = try lifter.liftModule(disasm_result);
        defer module.deinit();

        self.progress.current_stage = .basic_lifting;
        try self.progress.stages_completed.append(.disassembly);

        // Улучшение каждой функции
        for (module.functions.items) |func| {
            const enhanced = try self.enhanceFunction(func);
            try enhanced_functions.append(enhanced);
        }

        try self.progress.stages_completed.append(.basic_lifting);
        self.progress.current_stage = .final_validation;

        return enhanced_functions;
    }

    /// Улучшение одной функции
    fn enhanceFunction(self: *LLMLifterEngine, func: b2t_lifter.TVCFunction) !EnhancedTVCFunction {
        var enhanced = EnhancedTVCFunction.init(self.allocator, func);

        // Извлечение контекста
        if (self.config.enable_name_recovery or self.config.enable_type_inference) {
            try self.llm_assist.extractDataFlow(&func);
        }

        // Восстановление имён
        if (self.config.enable_name_recovery) {
            try self.recoverNames(&enhanced);
        }

        // Вывод типов
        if (self.config.enable_type_inference) {
            try self.inferTypes(&enhanced);
        }

        // Восстановление структур
        if (self.config.enable_struct_recovery) {
            try self.recoverStructs(&enhanced);
        }

        // Генерация комментариев
        if (self.config.enable_comments) {
            try self.generateComments(&enhanced);
        }

        return enhanced;
    }

    /// Восстановление имён переменных
    fn recoverNames(self: *LLMLifterEngine, enhanced: *EnhancedTVCFunction) !void {
        // Анализ контекста для восстановления имён
        for (enhanced.base.values.items) |value| {
            const suggested_name = self.suggestVariableName(value);
            if (suggested_name) |name| {
                try enhanced.variable_names.put(value.id, name);
            }
        }
    }

    fn suggestVariableName(self: *LLMLifterEngine, value: b2t_lifter.TVCValue) ?[]const u8 {
        _ = self;
        // Простая эвристика на основе типа
        return switch (value.value_type) {
            .trit_ptr => "ptr",
            .trit32 => "value",
            .trit64 => "data",
            else => null,
        };
    }

    /// Вывод типов
    fn inferTypes(self: *LLMLifterEngine, enhanced: *EnhancedTVCFunction) !void {
        for (enhanced.base.values.items) |value| {
            const inferred_type = self.inferType(value);
            if (inferred_type) |t| {
                try enhanced.type_annotations.put(value.id, t);
            }
        }
    }

    fn inferType(self: *LLMLifterEngine, value: b2t_lifter.TVCValue) ?[]const u8 {
        _ = self;
        return switch (value.value_type) {
            .trit32 => "i32",
            .trit64 => "i64",
            .trit_ptr => "*void",
            .void => "void",
            else => null,
        };
    }

    /// Восстановление структур
    fn recoverStructs(self: *LLMLifterEngine, enhanced: *EnhancedTVCFunction) !void {
        // Анализ паттернов доступа к памяти
        for (enhanced.base.blocks.items) |block| {
            for (block.instructions.items) |inst| {
                if (inst.opcode == .t_load or inst.opcode == .t_store) {
                    // Потенциальный доступ к структуре
                    _ = try self.detectStructAccess(inst);
                }
            }
        }
    }

    fn detectStructAccess(self: *LLMLifterEngine, inst: b2t_lifter.TVCInstruction) !?StructDef {
        _ = self;
        _ = inst;
        // TODO: Реализовать детекцию структур
        return null;
    }

    /// Генерация комментариев
    fn generateComments(_: *LLMLifterEngine, enhanced: *EnhancedTVCFunction) !void {
        // Комментарий к функции
        try enhanced.comments.append(CodeComment{
            .line = 0,
            .comment = "// TODO: Add function description",
            .comment_type = .function_purpose,
        });

        // Комментарии к параметрам
        for (enhanced.base.params.items) |_| {
            try enhanced.comments.append(CodeComment{
                .line = 0,
                .comment = "// Parameter",
                .comment_type = .parameter_description,
            });
        }
    }

    /// Получение прогресса
    pub fn getProgress(self: *LLMLifterEngine) LiftingProgress {
        return self.progress;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "llm lifter engine init and deinit" {
    const config = LLMLiftingConfig{};
    var engine = LLMLifterEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    try std.testing.expect(engine.config.enable_name_recovery);
}

test "lifting progress init" {
    var progress = LiftingProgress.init(std.testing.allocator);
    defer progress.deinit();

    try std.testing.expectEqual(LiftingStage.disassembly, progress.current_stage);
}

test "enhanced tvc function init" {
    const base_func = b2t_lifter.TVCFunction.init(std.testing.allocator, 0);
    var enhanced = EnhancedTVCFunction.init(std.testing.allocator, base_func);
    defer enhanced.deinit();

    try std.testing.expectEqual(@as(f32, 0.0), enhanced.confidence);
}

test "struct def init and deinit" {
    var struct_def = StructDef.init(std.testing.allocator, "TestStruct");
    defer struct_def.deinit();

    try std.testing.expect(std.mem.eql(u8, struct_def.name, "TestStruct"));
}
