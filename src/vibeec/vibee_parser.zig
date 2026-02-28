// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE PARSER - Парсер .tri спецификаций
// ═══════════════════════════════════════════════════════════════════════════════
//
// Парсит YAML-подобный format .tri файлов (legacy .vibee supported)
// Автор: Dmitrii Vasilev
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
pub const parser_utils = @import("parser_utils.zig");
const parser_sections = @import("parser_sections.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// ТИПЫ СПЕЦИФИКАЦИИ (re-exported from parser_types.zig)
// ═══════════════════════════════════════════════════════════════════════════════

pub const parser_types = @import("parser_types.zig");
pub const ZigMode = parser_types.ZigMode;
pub const AllocatorStrategy = parser_types.AllocatorStrategy;
pub const VibeeSpec = parser_types.VibeeSpec;
pub const Constant = parser_types.Constant;
pub const Import = parser_types.Import;
pub const ResetDef = parser_types.ResetDef;
pub const TypeDef = parser_types.TypeDef;
pub const Field = parser_types.Field;
pub const Signal = parser_types.Signal;
pub const FSMTransition = parser_types.FSMTransition;
pub const FSMOutput = parser_types.FSMOutput;
pub const FSMTimer = parser_types.FSMTimer;
pub const FSMDef = parser_types.FSMDef;
pub const CreationPattern = parser_types.CreationPattern;
pub const Behavior = parser_types.Behavior;
pub const TestCase = parser_types.TestCase;
pub const Algorithm = parser_types.Algorithm;
pub const WasmExports = parser_types.WasmExports;
pub const MemoryExport = parser_types.MemoryExport;
pub const PasPrediction = parser_types.PasPrediction;

// ═══════════════════════════════════════════════════════════════════════════════
// ПАРСЕР
// ═══════════════════════════════════════════════════════════════════════════════

pub const VibeeParser = struct {
    allocator: Allocator,
    source: []const u8,
    pos: usize,
    line: usize,

    const Self = @This();

    pub fn init(allocator: Allocator, source: []const u8) VibeeParser {
        return .{
            .allocator = allocator,
            .source = source,
            .pos = 0,
            .line = 1,
        };
    }

    pub fn parse(self: *Self) !VibeeSpec {
        var spec = VibeeSpec.init(self.allocator);
        // Transfer source ownership to spec - all parsed strings are slices into this
        spec.source_content = self.source;

        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const key = self.readKey();
            if (key.len == 0) {
                self.pos += 1;
                continue;
            }

            // Пропускаем только ":"
            if (self.pos < self.source.len and self.source[self.pos] == ':') {
                self.pos += 1;
            }

            if (std.mem.eql(u8, key, "name")) {
                self.skipInlineWhitespace();
                spec.name = self.readValue();
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "version")) {
                self.skipInlineWhitespace();
                spec.version = self.readQuotedValue();
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "language")) {
                self.skipInlineWhitespace();
                // Check for array syntax: [zig, python, typescript]
                if (self.pos < self.source.len and self.source[self.pos] == '[') {
                    try self.parseLanguageArray(&spec.languages);
                    // Set primary language to first item for backward compat
                    if (spec.languages.items.len > 0) {
                        spec.language = spec.languages.items[0];
                    }
                    self.skipToNextLine();
                } else {
                    spec.language = self.readValue();
                    self.skipToNextLine();
                }
            } else if (std.mem.eql(u8, key, "author")) {
                self.skipInlineWhitespace();
                spec.author = self.readQuotedValue();
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "license")) {
                self.skipInlineWhitespace();
                spec.license = self.readQuotedValue();
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "fpga_target")) {
                self.skipInlineWhitespace();
                spec.fpga_target = self.readValue();
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "pipeline")) {
                self.skipInlineWhitespace();
                spec.pipeline = self.readValue();
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "target_frequency")) {
                self.skipInlineWhitespace();
                const val = self.readValue();
                spec.target_frequency = std.fmt.parseInt(u32, val, 10) catch 100;
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "zig_mode")) {
                self.skipInlineWhitespace();
                const val = self.readValue();
                if (std.mem.eql(u8, val, "idiomatic")) {
                    spec.zig_mode = .idiomatic;
                } else if (std.mem.eql(u8, val, "wasm")) {
                    spec.zig_mode = .wasm;
                } else {
                    spec.zig_mode = .idiomatic; // Cycle 76: default to idiomatic
                }
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "allocator_strategy")) {
                self.skipInlineWhitespace();
                const val = self.readValue();
                if (std.mem.eql(u8, val, "param")) {
                    spec.allocator_strategy = .param;
                } else if (std.mem.eql(u8, val, "arena")) {
                    spec.allocator_strategy = .arena;
                } else if (std.mem.eql(u8, val, "gpa")) {
                    spec.allocator_strategy = .gpa;
                } else {
                    spec.allocator_strategy = .param; // Cycle 76: default to param
                }
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "targets")) {
                self.skipToNextLine();
                try self.parseTargets(&spec.targets);
            } else if (std.mem.eql(u8, key, "constants")) {
                self.skipToNextLine();
                try self.parseConstants(&spec.constants);
            } else if (std.mem.eql(u8, key, "imports")) {
                self.skipToNextLine();
                try self.parseImports(&spec.imports);
            } else if (std.mem.eql(u8, key, "types")) {
                self.skipToNextLine();
                try self.parseTypes(&spec.types);
            } else if (std.mem.eql(u8, key, "creation_patterns")) {
                self.skipToNextLine();
                try self.parseCreationPatterns(&spec.creation_patterns);
            } else if (std.mem.eql(u8, key, "behaviors")) {
                self.skipToNextLine();
                try self.parseBehaviors(&spec.behaviors);
            } else if (std.mem.eql(u8, key, "algorithms")) {
                self.skipToNextLine();
                try self.parseAlgorithms(&spec.algorithms);
            } else if (std.mem.eql(u8, key, "wasm_exports")) {
                self.skipToNextLine();
                try self.parseWasmExports(&spec.wasm_exports);
            } else if (std.mem.eql(u8, key, "pas_predictions")) {
                self.skipToNextLine();
                try self.parsePasPredictions(&spec.pas_predictions);
            } else if (std.mem.eql(u8, key, "signals")) {
                self.skipToNextLine();
                try self.parseSignals(&spec.signals);
            } else if (std.mem.eql(u8, key, "fsm")) {
                self.skipToNextLine();
                try self.parseFSMs(&spec.fsms);
            } else if (std.mem.eql(u8, key, "test_cases")) {
                self.skipToNextLine();
                try self.parseTopLevelTestCases(&spec.test_cases);
            } else if (std.mem.eql(u8, key, "reset")) {
                self.skipInlineWhitespace();
                const reset_val = self.readValue();
                if (std.mem.eql(u8, reset_val, "none")) {
                    spec.reset.reset_type = "none";
                    self.skipToNextLine();
                } else {
                    self.skipToNextLine();
                    try self.parseReset(&spec.reset);
                }
            } else {
                self.skipToNextLine();
            }
        }

        return spec;
    }

    fn skipWhitespaceAndComments(self: *Self) void {
        const s = parser_utils.skipWhitespaceAndComments(self.source, self.pos, self.line);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn readKey(self: *Self) []const u8 {
        const r = parser_utils.readKey(self.source, self.pos);
        self.pos = r.new_pos;
        return r.key;
    }

    fn skipColon(self: *Self) void {
        self.pos = parser_utils.skipColon(self.source, self.pos);
    }

    fn readValue(self: *Self) []const u8 {
        const r = parser_utils.readValue(self.source, self.pos);
        self.pos = r.new_pos;
        return r.value;
    }

    fn readQuotedValue(self: *Self) []const u8 {
        const r = parser_utils.readQuotedValue(self.source, self.pos);
        self.pos = r.new_pos;
        return r.value;
    }

    fn parseLanguageArray(self: *Self, languages: *ArrayList([]const u8)) !void {
        self.pos = try parser_sections.parseLanguageArray(self.source, self.pos, self.allocator, languages);
    }

    fn parseTargets(self: *Self, targets: *ArrayList([]const u8)) !void {
        const s = try parser_sections.parseTargets(self.source, self.pos, self.line, self.allocator, targets);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn parseConstants(self: *Self, constants: *ArrayList(Constant)) !void {
        const s = try parser_sections.parseConstants(self.source, self.pos, self.line, self.allocator, constants);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn parseImports(self: *Self, imports: *ArrayList(Import)) !void {
        const s = try parser_sections.parseImports(self.source, self.pos, self.line, self.allocator, imports);
        self.pos = s.pos;
        self.line = s.line;
    }


    fn skipToNextLine(self: *Self) void {
        const s = parser_utils.skipToNextLine(self.source, self.pos, self.line);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn skipInlineWhitespace(self: *Self) void {
        self.pos = parser_utils.skipInlineWhitespace(self.source, self.pos);
    }

    fn skipEmptyLinesAndComments(self: *Self) void {
        const s = parser_utils.skipEmptyLinesAndComments(self.source, self.pos, self.line);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn parseTypes(self: *Self, types: *ArrayList(TypeDef)) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            const name = self.readKey();
            if (name.len == 0) break;

            // Проверяем what this не следующая секция
            if (std.mem.eql(u8, name, "creation_patterns") or
                std.mem.eql(u8, name, "behaviors") or
                std.mem.eql(u8, name, "algorithms") or
                std.mem.eql(u8, name, "wasm_exports"))
            {
                self.pos -= name.len + indent;
                break;
            }

            self.skipColon();
            self.skipToNextLine();

            var typedef = TypeDef.init(self.allocator);
            typedef.name = name;

            // Читаем вложенные поля
            while (self.pos < self.source.len) {
                self.skipEmptyLinesAndComments();
                if (self.pos >= self.source.len) break;

                const field_indent = self.countIndent();
                if (field_indent < 4) break;
                self.pos += field_indent;

                const field_key = self.readKey();
                if (field_key.len == 0) break;
                self.skipColon();

                if (std.mem.eql(u8, field_key, "base")) {
                    typedef.base = self.readValue();
                    self.skipToNextLine();
                } else if (std.mem.eql(u8, field_key, "description")) {
                    typedef.description = self.readQuotedValue();
                    self.skipToNextLine();
                } else if (std.mem.eql(u8, field_key, "generic")) {
                    typedef.generic = self.readValue();
                    self.skipToNextLine();
                } else if (std.mem.eql(u8, field_key, "fields")) {
                    self.skipToNextLine();
                    try self.parseFields(&typedef.fields);
                } else if (std.mem.eql(u8, field_key, "consts")) {
                    self.skipToNextLine();
                    try self.parseConsts(&typedef.consts);
                } else if (std.mem.eql(u8, field_key, "enum")) {
                    self.skipToNextLine();
                    try self.parseEnum(&typedef.enum_variants);
                } else if (std.mem.eql(u8, field_key, "constraints")) {
                    self.skipToNextLine();
                    try self.parseConstraints(&typedef.constraints);
                } else {
                    self.skipToNextLine();
                }
            }

            try types.append(self.allocator, typedef);
        }
    }

    fn skipNestedBlock(self: *Self, min_indent: usize) void {
        const s = parser_utils.skipNestedBlock(self.source, self.pos, self.line, min_indent);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn parseSignals(self: *Self, signals: *ArrayList(Signal)) !void {
        const s = try parser_sections.parseSignals(self.source, self.pos, self.line, self.allocator, signals);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn parseReset(self: *Self, reset: *ResetDef) !void {
        const s = try parser_sections.parseReset(self.source, self.pos, self.line, reset);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn parseFSMs(self: *Self, fsms: *ArrayList(FSMDef)) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            // Check for list item
            if (self.pos >= self.source.len or self.source[self.pos] != '-') {
                self.pos -= indent;
                break;
            }
            self.pos += 1; // skip '-'
            self.skipInlineWhitespace();

            var fsm = FSMDef.init(self.allocator);

            // Read FSM properties
            const first_key = self.readKey();
            if (std.mem.eql(u8, first_key, "name")) {
                self.skipColon();
                fsm.name = self.readValue();
                self.skipToNextLine();

                // Read remaining properties
                while (self.pos < self.source.len) {
                    self.skipEmptyLinesAndComments();
                    if (self.pos >= self.source.len) break;

                    const prop_indent = self.countIndent();
                    if (prop_indent < 4) break;
                    self.pos += prop_indent;

                    const prop_key = self.readKey();
                    if (prop_key.len == 0) break;
                    self.skipColon();

                    if (std.mem.eql(u8, prop_key, "initial")) {
                        fsm.initial_state = self.readValue();
                        self.skipToNextLine();
                    } else if (std.mem.eql(u8, prop_key, "encoding")) {
                        fsm.encoding = self.readValue();
                        self.skipToNextLine();
                    } else if (std.mem.eql(u8, prop_key, "states")) {
                        self.skipToNextLine();
                        // Parse states list
                        while (self.pos < self.source.len) {
                            self.skipEmptyLinesAndComments();
                            if (self.pos >= self.source.len) break;

                            const state_indent = self.countIndent();
                            if (state_indent < 6) break;
                            self.pos += state_indent;

                            if (self.pos >= self.source.len or self.source[self.pos] != '-') {
                                self.pos -= state_indent;
                                break;
                            }
                            self.pos += 1; // skip '-'
                            self.skipInlineWhitespace();

                            const state_name = self.readValue();
                            if (state_name.len > 0) {
                                try fsm.states.append(self.allocator, state_name);
                            }
                            self.skipToNextLine();
                        }
                    } else if (std.mem.eql(u8, prop_key, "transitions")) {
                        self.skipToNextLine();
                        try self.parseFSMTransitions(&fsm.transitions);
                    } else if (std.mem.eql(u8, prop_key, "outputs")) {
                        self.skipToNextLine();
                        try self.parseFSMOutputs(&fsm.outputs);
                    } else if (std.mem.eql(u8, prop_key, "timers")) {
                        self.skipToNextLine();
                        try self.parseFSMTimers(&fsm.timers);
                    } else {
                        self.skipToNextLine();
                    }
                }
            } else {
                self.skipToNextLine();
                continue;
            }

            if (fsm.name.len > 0) {
                try fsms.append(self.allocator, fsm);
            }
        }
    }

    fn parseFSMTransitions(self: *Self, transitions: *ArrayList(FSMTransition)) !void {
        const s = try parser_sections.parseFSMTransitions(self.source, self.pos, self.line, self.allocator, transitions);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn parseFSMOutputs(self: *Self, outputs: *ArrayList(FSMOutput)) !void {
        const s = try parser_sections.parseFSMOutputs(self.source, self.pos, self.line, self.allocator, outputs);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn parseFSMTimers(self: *Self, timers: *ArrayList(FSMTimer)) !void {
        const s = try parser_sections.parseFSMTimers(self.source, self.pos, self.line, self.allocator, timers);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn parseConstraints(self: *Self, constraints: *ArrayList([]const u8)) !void {
        const s = try parser_sections.parseConstraints(self.source, self.pos, self.line, self.allocator, constraints);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn parseFields(self: *Self, fields: *ArrayList(Field)) !void {
        const s = try parser_sections.parseFields(self.source, self.pos, self.line, self.allocator, fields);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn parseConsts(self: *Self, consts: *std.StringHashMap([]const u8)) !void {
        const s = try parser_sections.parseConsts(self.source, self.pos, self.line, self.allocator, consts);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn parseEnum(self: *Self, enum_variants: *ArrayList([]const u8)) !void {
        const s = try parser_sections.parseEnum(self.source, self.pos, self.line, self.allocator, enum_variants);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn parseCreationPatterns(self: *Self, patterns: *ArrayList(CreationPattern)) !void {
        const s = try parser_sections.parseCreationPatterns(self.source, self.pos, self.line, self.allocator, patterns);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn parseBehaviors(self: *Self, behaviors: *ArrayList(Behavior)) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            // Behaviors начинаются with '-'
            if (self.pos >= self.source.len or self.source[self.pos] != '-') {
                self.pos -= indent;
                break;
            }
            self.pos += 1;
            self.skipInlineWhitespace();

            var behavior = Behavior.init(self.allocator);

            // Первое поле on той же строке: "- name: value"
            const first_key = self.readKey();
            if (first_key.len > 0) {
                self.skipColon();
                if (std.mem.eql(u8, first_key, "name")) {
                    behavior.name = self.readValue();
                }
            }
            self.skipToNextLine();

            // Читаем остальные поля behavior
            while (self.pos < self.source.len) {
                self.skipEmptyLinesAndComments();
                if (self.pos >= self.source.len) break;

                const peek_indent = self.countIndent();
                if (peek_indent < 4) break;
                self.pos += peek_indent;

                const field_key = self.readKey();
                if (field_key.len == 0) break;
                self.skipColon();

                if (std.mem.eql(u8, field_key, "name")) {
                    behavior.name = self.readValue();
                    self.skipToNextLine();
                } else if (std.mem.eql(u8, field_key, "owner")) {
                    const owner_value = self.readValue();
                    if (owner_value.len > 0) {
                        behavior.owner = owner_value;
                    }
                    self.skipToNextLine();
                } else if (std.mem.eql(u8, field_key, "given")) {
                    behavior.given = self.readQuotedOrValue();
                    self.skipToNextLine();
                } else if (std.mem.eql(u8, field_key, "when")) {
                    behavior.when = self.readQuotedOrValue();
                    self.skipToNextLine();
                } else if (std.mem.eql(u8, field_key, "then")) {
                    behavior.then = self.readQuotedOrValue();
                    self.skipToNextLine();
                } else if (std.mem.eql(u8, field_key, "implementation")) {
                    behavior.implementation = self.readMultilineBlock();
                } else if (std.mem.eql(u8, field_key, "test_cases")) {
                    self.skipToNextLine();
                    try self.parseTestCases(&behavior.test_cases);
                } else {
                    self.skipToNextLine();
                }
            }

            if (behavior.name.len > 0) {
                try behaviors.append(self.allocator, behavior);
            }
        }
    }

    fn parseTestCases(self: *Self, test_cases: *ArrayList(TestCase)) !void {
        const s = try parser_sections.parseTestCases(self.source, self.pos, self.line, self.allocator, test_cases);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn parseTopLevelTestCases(self: *Self, test_cases: *ArrayList(TestCase)) !void {
        const s = try parser_sections.parseTopLevelTestCases(self.source, self.pos, self.line, self.allocator, test_cases);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn parseAlgorithms(self: *Self, algorithms: *ArrayList(Algorithm)) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            const name = self.readKey();
            if (name.len == 0) break;

            // Check for next section
            if (std.mem.eql(u8, name, "wasm_exports") or
                std.mem.eql(u8, name, "behaviors") or
                std.mem.eql(u8, name, "pas_predictions"))
            {
                self.pos -= name.len + indent;
                break;
            }

            self.skipColon();
            self.skipToNextLine();

            var algorithm = Algorithm.init(self.allocator);
            algorithm.name = name;

            // Read nested fields
            while (self.pos < self.source.len) {
                self.skipEmptyLinesAndComments();
                if (self.pos >= self.source.len) break;

                const field_indent = self.countIndent();
                if (field_indent < 4) break;
                self.pos += field_indent;

                const field_key = self.readKey();
                if (field_key.len == 0) break;
                self.skipColon();

                if (std.mem.eql(u8, field_key, "description")) {
                    algorithm.description = self.readQuotedOrValue();
                    self.skipToNextLine();
                } else if (std.mem.eql(u8, field_key, "complexity")) {
                    algorithm.complexity = self.readQuotedOrValue();
                    self.skipToNextLine();
                } else if (std.mem.eql(u8, field_key, "pattern")) {
                    algorithm.pattern = self.readValue();
                    self.skipToNextLine();
                } else if (std.mem.eql(u8, field_key, "steps")) {
                    self.skipToNextLine();
                    try self.parseAlgorithmSteps(&algorithm.steps);
                } else if (std.mem.eql(u8, field_key, "formula")) {
                    self.skipToNextLine(); // Skip formula line
                } else {
                    self.skipToNextLine();
                }
            }

            if (algorithm.name.len > 0) {
                try algorithms.append(self.allocator, algorithm);
            }
        }
    }

    fn parseAlgorithmSteps(self: *Self, steps: *ArrayList([]const u8)) !void {
        const s = try parser_sections.parseAlgorithmSteps(self.source, self.pos, self.line, self.allocator, steps);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn parseWasmExports(self: *Self, exports: *WasmExports) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            const key = self.readKey();
            if (key.len == 0) break;

            // Check for next section
            if (std.mem.eql(u8, key, "pas_predictions") or
                std.mem.eql(u8, key, "behaviors") or
                std.mem.eql(u8, key, "algorithms"))
            {
                self.pos -= key.len + indent;
                break;
            }

            self.skipColon();
            self.skipToNextLine();

            if (std.mem.eql(u8, key, "functions")) {
                try self.parseWasmFunctionList(&exports.functions);
            } else if (std.mem.eql(u8, key, "memory")) {
                try self.parseWasmMemoryExports(&exports.memory);
            }
        }
    }

    fn parseWasmFunctionList(self: *Self, functions: *ArrayList([]const u8)) !void {
        const s = try parser_sections.parseWasmFunctionList(self.source, self.pos, self.line, self.allocator, functions);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn parseWasmMemoryExports(self: *Self, memory: *ArrayList(MemoryExport)) !void {
        const s = try parser_sections.parseWasmMemoryExports(self.source, self.pos, self.line, self.allocator, memory);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn parsePasPredictions(self: *Self, predictions: *ArrayList(PasPrediction)) !void {
        const s = try parser_sections.parsePasPredictions(self.source, self.pos, self.line, self.allocator, predictions);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn countIndent(self: *Self) usize {
        return parser_utils.countIndent(self.source, self.pos);
    }

    fn skipLine(self: *Self) void {
        const s = parser_utils.skipLine(self.source, self.pos, self.line);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn skipBlock(self: *Self) void {
        const s = parser_utils.skipBlock(self.source, self.pos, self.line);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn readQuotedOrValue(self: *Self) []const u8 {
        const r = parser_utils.readQuotedOrValue(self.source, self.pos, self.line);
        self.pos = r.new_pos;
        self.line = r.new_line;
        return r.value;
    }

    fn readMultilineBlock(self: *Self) []const u8 {
        const r = parser_utils.readMultilineBlock(self.source, self.pos, self.line);
        self.pos = r.new_pos;
        self.line = r.new_line;
        return r.value;
    }

    fn readBraceValue(self: *Self) []const u8 {
        const r = parser_utils.readBraceValue(self.source, self.pos, self.line);
        self.pos = r.new_pos;
        self.line = r.new_line;
        return r.value;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ТЕСТЫ
// ═══════════════════════════════════════════════════════════════════════════════

test "parse simple spec" {
    const source =
        \\name: phi_core
        \\version: "24.φ"
        \\author: "Dmitrii Vasilev"
        \\
    ;

    var parser = VibeeParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqualStrings("phi_core", spec.name);
    try std.testing.expectEqualStrings("24.φ", spec.version);
}

test "parse types with constraints" {
    const source =
        \\name: test_spec
        \\version: "1.0"
        \\
        \\types:
        \\  PhiFloat:
        \\    base: f64
        \\    constraints:
        \\      - "value >= 0"
        \\      - "is_phi_power(value)"
        \\    description: "φ-optimized number"
        \\
    ;

    var parser = VibeeParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqual(@as(usize, 1), spec.types.items.len);
    const typedef = spec.types.items[0];
    try std.testing.expectEqualStrings("PhiFloat", typedef.name);
    try std.testing.expectEqual(@as(usize, 2), typedef.constraints.items.len);
    try std.testing.expectEqualStrings("value >= 0", typedef.constraints.items[0]);
}

test "parse algorithms" {
    const source =
        \\name: algo_spec
        \\version: "1.0"
        \\
        \\algorithms:
        \\  phi_power_fast:
        \\    description: "Fast φ exponentiation"
        \\    complexity: "O(log n)"
        \\    pattern: D&C
        \\    steps:
        \\      - "If n = 0, return 1"
        \\      - "result = 1, base = φ"
        \\
    ;

    var parser = VibeeParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqual(@as(usize, 1), spec.algorithms.items.len);
    const algo = spec.algorithms.items[0];
    try std.testing.expectEqualStrings("phi_power_fast", algo.name);
    try std.testing.expectEqualStrings("O(log n)", algo.complexity);
}

test "parse wasm_exports" {
    const source =
        \\name: wasm_spec
        \\version: "1.0"
        \\
        \\wasm_exports:
        \\  functions:
        \\    - phi_power
        \\    - fibonacci
        \\  memory:
        \\    global_buffer:
        \\      size: 65536
        \\      alignment: 16
        \\
    ;

    var parser = VibeeParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqual(@as(usize, 2), spec.wasm_exports.functions.items.len);
    try std.testing.expectEqualStrings("phi_power", spec.wasm_exports.functions.items[0]);
    try std.testing.expectEqual(@as(usize, 1), spec.wasm_exports.memory.items.len);
}

test "parse pas_predictions" {
    const source =
        \\name: pas_spec
        \\version: "1.0"
        \\
        \\pas_predictions:
        \\  - target: phi_power
        \\    current: "O(n)"
        \\    predicted: "O(log n)"
        \\    confidence: 0.95
        \\    pattern: D&C
        \\    status: implemented
        \\
    ;

    var parser = VibeeParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqual(@as(usize, 1), spec.pas_predictions.items.len);
    const pred = spec.pas_predictions.items[0];
    try std.testing.expectEqualStrings("phi_power", pred.target);
    try std.testing.expectEqualStrings("O(n)", pred.current);
    try std.testing.expectEqualStrings("O(log n)", pred.predicted);
    try std.testing.expect(pred.confidence > 0.9);
}

test "parse multi-language array syntax" {
    const source =
        \\name: multilang_spec
        \\version: "2.0"
        \\language: [zig, python, typescript]
        \\
    ;

    var parser = VibeeParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqualStrings("multilang_spec", spec.name);
    // Primary language should be first item
    try std.testing.expectEqualStrings("zig", spec.language);
    // Languages array should contain all targets
    try std.testing.expectEqual(@as(usize, 3), spec.languages.items.len);
    try std.testing.expectEqualStrings("zig", spec.languages.items[0]);
    try std.testing.expectEqualStrings("python", spec.languages.items[1]);
    try std.testing.expectEqualStrings("typescript", spec.languages.items[2]);
}

test "parse single language backward compat" {
    const source =
        \\name: single_lang
        \\version: "1.0"
        \\language: python
        \\
    ;

    var parser = VibeeParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqualStrings("python", spec.language);
    // languages array should be empty for single-language specs
    try std.testing.expectEqual(@as(usize, 0), spec.languages.items.len);
}
