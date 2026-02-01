// B2T Prompts - Distortion-Aware Prompt Templates
// Шаблоны промптов для LLM-ассистированной декомпиляции
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY
//
// Научная основа:
// - FidelityGPT: Distortion-aware prompt templates
// - ICL4Decomp: In-context learning с примерами
// - Chain-of-Thought: Пошаговое рассуждение

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
    \\Ты Maxwell — автономный агент-декомпилятор, работающий на принципах троичной логики.
    \\
    \\ТВОЯ РОЛЬ:
    \\- Анализировать декомпилированный код и находить семантические искажения
    \\- Восстанавливать осмысленные имена переменных и функций
    \\- Исправлять структуру потока управления
    \\- Выводить корректные типы данных
    \\
    \\ПРИНЦИПЫ ТРОИЧНОЙ ЛОГИКИ:
    \\- Для каждого решения рассматривай три исхода: отрицательный, нейтральный, положительный
    \\- Используй формулу: φ² + 1/φ² = 3 = TRINITY
    \\- Неопределённость — это не ошибка, а третье состояние
    \\
    \\ОГРАНИЧЕНИЯ:
    \\- Генерируй ТОЛЬКО код, без объяснений (если не запрошено)
    \\- Сохраняй семантику оригинала
    \\- Не добавляй функциональность, которой не было
    \\
    \\ФОРМАТ ОТВЕТА:
    \\```c
    \\// исправленный код
    \\```
;

pub const DISTORTION_DETECTOR_PROMPT =
    \\Ты эксперт по анализу качества декомпиляции.
    \\
    \\ТВОЯ ЗАДАЧА:
    \\Найти семантические искажения в декомпилированном коде.
    \\
    \\ТИПЫ ИСКАЖЕНИЙ:
    \\1. variable_naming — бессмысленные имена (v1, v2, sub_1234)
    \\2. type_inference — неверные типы (int вместо pointer)
    \\3. control_flow — искажённые циклы и условия
    \\4. loop_structure — потеря структуры for/while
    \\5. function_boundary — неверные границы функций
    \\6. calling_convention — ошибки ABI
    \\7. memory_access — неверные указатели
    \\8. constant_propagation — потеря констант
    \\9. dead_code — ложный мёртвый код
    \\10. inlining_artifact — артефакты инлайнинга
    \\
    \\ФОРМАТ ОТВЕТА:
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
    \\Ты эксперт по восстановлению семантики из бинарного кода.
    \\
    \\КОНТЕКСТ:
    \\Тебе дан декомпилированный код с искажениями и дополнительный контекст:
    \\- Граф потока данных (data flow)
    \\- Граф вызовов (call graph)
    \\- Строковые литералы
    \\- Импортируемые символы
    \\
    \\ТВОЯ ЗАДАЧА:
    \\Восстановить осмысленный код, используя весь доступный контекст.
    \\
    \\СТРАТЕГИЯ:
    \\1. Проанализируй строковые литералы — они часто указывают на назначение
    \\2. Изучи граф вызовов — имена библиотечных функций информативны
    \\3. Проследи поток данных — откуда приходят и куда уходят значения
    \\4. Примени паттерны — типичные конструкции (malloc/free, open/close)
    \\
    \\φ² + 1/φ² = 3 = TRINITY
;

// ═══════════════════════════════════════════════════════════════════════════════
// DISTORTION-SPECIFIC TEMPLATES
// ═══════════════════════════════════════════════════════════════════════════════

pub const VARIABLE_NAMING_TEMPLATE = PromptTemplate{
    .name = "variable_naming_fix",
    .template =
    \\Исправь имена переменных в этом коде:
    \\```
    \\{code}
    \\```
    \\
    \\КОНТЕКСТ:
    \\- Строки в коде: {string_refs}
    \\- Вызываемые функции: {callees}
    \\
    \\ОБНАРУЖЕННЫЕ ПРОБЛЕМЫ:
    \\{distortions}
    \\
    \\ПРИМЕРЫ ИСПРАВЛЕНИЙ:
    \\{examples}
    \\
    \\Выведи ТОЛЬКО исправленный код.
    ,
    .distortion_aware = true,
    .examples_count = 3,
};

pub const TYPE_INFERENCE_TEMPLATE = PromptTemplate{
    .name = "type_inference_fix",
    .template =
    \\Исправь типы в этом коде:
    \\```
    \\{code}
    \\```
    \\
    \\КОНТЕКСТ:
    \\- Сигнатуры вызываемых функций: {signatures}
    \\- Размеры данных: {sizes}
    \\
    \\ОБНАРУЖЕННЫЕ ПРОБЛЕМЫ:
    \\{distortions}
    \\
    \\ПРИМЕРЫ:
    \\{examples}
    \\
    \\Выведи ТОЛЬКО исправленный код с правильными типами.
    ,
    .distortion_aware = true,
    .examples_count = 5,
};

pub const CONTROL_FLOW_TEMPLATE = PromptTemplate{
    .name = "control_flow_fix",
    .template =
    \\Восстанови структуру потока управления:
    \\```
    \\{code}
    \\```
    \\
    \\TVC IR показывает правильную структуру:
    \\```
    \\{tvc_ir}
    \\```
    \\
    \\ПРИМЕРЫ ВОССТАНОВЛЕНИЯ:
    \\{examples}
    \\
    \\Преобразуй goto в структурные конструкции.
    \\Выведи ТОЛЬКО исправленный код.
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

    /// Построение промпта для детекции искажений
    pub fn buildDetectionPrompt(self: *PromptBuilder, code: []const u8) ![]const u8 {
        self.buffer.clearRetainingCapacity();
        const writer = self.buffer.writer();

        try writer.writeAll(DISTORTION_DETECTOR_PROMPT);
        try writer.writeAll("\n\nКОД ДЛЯ АНАЛИЗА:\n```\n");
        try writer.writeAll(code);
        try writer.writeAll("\n```\n");

        return self.buffer.items;
    }

    /// Построение промпта для исправления
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

        // Подстановка переменных в шаблон
        const template_copy = template.template;

        // Замена {code}
        if (std.mem.indexOf(u8, template_copy, "{code}")) |_| {
            try writer.writeAll("КОД:\n```\n");
            try writer.writeAll(code);
            try writer.writeAll("\n```\n\n");
        }

        // Замена {distortions}
        if (std.mem.indexOf(u8, template_copy, "{distortions}")) |_| {
            try writer.writeAll("ИСКАЖЕНИЯ:\n");
            for (distortions) |d| {
                try writer.print("- Строка {d}: {s} (severity: {d:.2})\n", .{
                    d.line_number,
                    d.description,
                    d.severity,
                });
            }
            try writer.writeAll("\n");
        }

        // Замена {examples}
        if (std.mem.indexOf(u8, template_copy, "{examples}")) |_| {
            try writer.writeAll("ПРИМЕРЫ:\n");
            for (examples, 0..) |example, i| {
                try writer.print("Пример {d}:\n```\n{s}\n```\n\n", .{ i + 1, example });
            }
        }

        return self.buffer.items;
    }

    /// Построение Chain-of-Thought промпта
    pub fn buildCoTPrompt(self: *PromptBuilder, code: []const u8, context: []const u8) ![]const u8 {
        self.buffer.clearRetainingCapacity();
        const writer = self.buffer.writer();

        try writer.writeAll(SEMANTIC_RECOVERER_PROMPT);
        try writer.writeAll("\n\n");

        try writer.writeAll("КОД:\n```\n");
        try writer.writeAll(code);
        try writer.writeAll("\n```\n\n");

        try writer.writeAll("КОНТЕКСТ:\n");
        try writer.writeAll(context);
        try writer.writeAll("\n\n");

        try writer.writeAll(
            \\ПОШАГОВОЕ РАССУЖДЕНИЕ:
            \\
            \\Шаг 1: Анализ строковых литералов
            \\Что они говорят о назначении функции?
            \\
            \\Шаг 2: Анализ графа вызовов
            \\Какие функции вызываются? Что это говорит о функциональности?
            \\
            \\Шаг 3: Анализ потока данных
            \\Откуда приходят входные данные? Куда уходят выходные?
            \\
            \\Шаг 4: Детекция искажений
            \\Какие искажения присутствуют? В каком порядке исправлять?
            \\
            \\Шаг 5: Применение исправлений
            \\Исправь искажения по приоритету.
            \\
            \\Шаг 6: Финальная валидация
            \\Код компилируется? Семантика эквивалентна оригиналу?
            \\
            \\Выведи финальный исправленный код.
        );

        return self.buffer.items;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TEMPLATE SELECTOR
// ═══════════════════════════════════════════════════════════════════════════════

/// Выбор шаблона на основе типа искажения
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
    try std.testing.expect(std.mem.indexOf(u8, prompt, "Шаг 1") != null);
}
