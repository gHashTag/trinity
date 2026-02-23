// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE PARSER - Парсер .tri спецификаций
// ═══════════════════════════════════════════════════════════════════════════════
//
// Парсит YAML-подобный формат .tri файлов (legacy .vibee supported)
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
// ТИПЫ СПЕЦИФИКАЦИИ
// ═══════════════════════════════════════════════════════════════════════════════

/// Zig code generation mode (Cycle 74: Zig Idioms Enhancement)
pub const ZigMode = enum { standard, idiomatic, wasm };

/// Allocator injection strategy for idiomatic Zig
pub const AllocatorStrategy = enum { none, param, arena, gpa };

pub const VibeeSpec = struct {
    name: []const u8,
    version: []const u8,
    language: []const u8, // Target language: zig, verilog, python, etc.
    languages: ArrayList([]const u8), // Multi-language targets: [zig, python, typescript]
    author: []const u8,
    license: []const u8,
    targets: ArrayList([]const u8),
    fpga_target: []const u8, // generic, xilinx, intel, lattice
    pipeline: []const u8, // none, auto, stage1, stage2
    target_frequency: u32, // MHz
    imports: ArrayList(Import), // Custom @import statements
    constants: ArrayList(Constant),
    types: ArrayList(TypeDef),
    creation_patterns: ArrayList(CreationPattern),
    behaviors: ArrayList(Behavior),
    algorithms: ArrayList(Algorithm),
    wasm_exports: WasmExports,
    pas_predictions: ArrayList(PasPrediction),
    // HDL-specific fields
    signals: ArrayList(Signal),
    fsms: ArrayList(FSMDef),
    reset: ResetDef,
    // Top-level test cases (independent of behaviors)
    test_cases: ArrayList(TestCase),
    allocator: Allocator,
    // Source content ownership - all string fields are slices into this
    source_content: []const u8,
    owns_source: bool,
    // Zig idiom control (Cycle 74)
    zig_mode: ZigMode,
    allocator_strategy: AllocatorStrategy,
    error_sets: ArrayList([]const u8),

    pub fn init(allocator: Allocator) VibeeSpec {
        return .{
            .name = "",
            .version = "",
            .language = "zig", // Default to Zig
            .languages = .{}, // Empty = single language mode
            .author = "",
            .license = "",
            .targets = .{},
            .fpga_target = "generic",
            .pipeline = "none",
            .target_frequency = 100,
            .imports = .{}, // Custom imports
            .constants = .{},
            .types = .{},
            .creation_patterns = .{},
            .behaviors = .{},
            .algorithms = .{},
            .wasm_exports = WasmExports.init(allocator),
            .pas_predictions = .{},
            .signals = .{},
            .fsms = .{},
            .reset = ResetDef{ .reset_type = "async", .level = "low" }, // Default
            .test_cases = .{}, // Top-level test cases
            .allocator = allocator,
            .source_content = "",
            .owns_source = false,
            .zig_mode = .idiomatic, // Cycle 76: idiomatic by default
            .allocator_strategy = .param, // Cycle 76: param is safest default
            .error_sets = .{},
        };
    }

    pub fn deinit(self: *VibeeSpec) void {
        // Free source content only if we own it (allocated via readToEndAlloc)
        if (self.owns_source and self.source_content.len > 0) {
            self.allocator.free(self.source_content);
        }

        // Освобождаем вложенные структуры
        for (self.types.items) |*t| {
            t.fields.deinit(self.allocator);
            t.constraints.deinit(self.allocator);
            t.enum_variants.deinit(self.allocator);
        }
        for (self.behaviors.items) |*b| {
            b.test_cases.deinit(self.allocator);
        }
        for (self.algorithms.items) |*a| {
            a.steps.deinit(self.allocator);
        }
        for (self.fsms.items) |*f| {
            f.states.deinit(self.allocator);
            f.transitions.deinit(self.allocator);
            for (f.outputs.items) |*out| {
                out.signals.deinit();
            }
            f.outputs.deinit(self.allocator);
            f.timers.deinit(self.allocator);
        }

        // Освобождаем основные списки
        self.languages.deinit(self.allocator);
        self.targets.deinit(self.allocator);
        self.imports.deinit(self.allocator);
        self.constants.deinit(self.allocator);
        self.types.deinit(self.allocator);
        self.creation_patterns.deinit(self.allocator);
        self.behaviors.deinit(self.allocator);
        self.algorithms.deinit(self.allocator);
        self.wasm_exports.deinit(self.allocator);
        self.pas_predictions.deinit(self.allocator);
        self.signals.deinit(self.allocator);
        self.fsms.deinit(self.allocator);
        self.test_cases.deinit(self.allocator);
        self.error_sets.deinit(self.allocator);
    }
};

pub const Constant = struct {
    name: []const u8,
    value: f64,
    description: []const u8,
};

/// Import definition for @import statements in generated code
pub const Import = struct {
    name: []const u8, // Alias name (e.g., "vsa")
    path: []const u8, // Path to import (e.g., "../src/vsa.zig")
};

pub const ResetDef = struct {
    reset_type: []const u8, // none, sync, async
    level: []const u8, // low, high
};

pub const TypeDef = struct {
    name: []const u8,
    base: ?[]const u8,
    fields: ArrayList(Field),
    constraints: ArrayList([]const u8),
    generic: ?[]const u8,
    description: []const u8,
    enum_variants: ArrayList([]const u8),
    consts: std.StringHashMap([]const u8), // VIBEE Generator v2: const name -> value

    pub fn init(allocator: Allocator) TypeDef {
        return TypeDef{
            .name = "",
            .base = null,
            .fields = .{},
            .constraints = .{},
            .generic = null,
            .description = "",
            .enum_variants = .{},
            .consts = std.StringHashMap([]const u8).init(allocator),
        };
    }
};

pub const Field = struct {
    name: []const u8,
    type_name: []const u8,
};

// HDL Signal definition for FPGA targets
pub const Signal = struct {
    name: []const u8,
    width: u32,
    direction: []const u8, // input, output, inout, wire, reg
    signed: bool,
    default_value: ?i64,
};

// FSM Transition
pub const FSMTransition = struct {
    from_state: []const u8,
    to_state: []const u8,
    condition: []const u8, // Verilog condition expression
};

// FSM Output assignment
pub const FSMOutput = struct {
    state: []const u8,
    signals: std.StringHashMap([]const u8), // signal_name -> value (e.g., "busy" -> "1'b1")

    pub fn init(allocator: Allocator) FSMOutput {
        return .{
            .state = "",
            .signals = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *FSMOutput) void {
        self.signals.deinit(self.allocator);
    }
};

// FSM Timer configuration
pub const FSMTimer = struct {
    state: []const u8,
    timeout_constant: []const u8,
    timeout_value: i64,
};

// FSM (Finite State Machine) definition
pub const FSMDef = struct {
    name: []const u8,
    initial_state: []const u8,
    encoding: []const u8, // onehot, binary, gray
    states: ArrayList([]const u8),
    transitions: ArrayList(FSMTransition),
    outputs: ArrayList(FSMOutput),
    timers: ArrayList(FSMTimer),

    pub fn init(allocator: Allocator) FSMDef {
        _ = allocator;
        return FSMDef{
            .name = "",
            .initial_state = "",
            .encoding = "onehot",
            .states = .{},
            .transitions = .{},
            .outputs = .{},
            .timers = .{},
        };
    }
};

pub const CreationPattern = struct {
    name: []const u8,
    source: []const u8,
    transformer: []const u8,
    result: []const u8,
};

pub const Behavior = struct {
    name: []const u8,
    owner: ?[]const u8, // VIBEE Generator v2: Which struct owns this method
    given: []const u8,
    when: []const u8,
    then: []const u8,
    implementation: []const u8, // Zig code for function body
    test_cases: ArrayList(TestCase),

    pub fn init(allocator: Allocator) Behavior {
        _ = allocator;
        return Behavior{
            .name = "",
            .owner = null,
            .given = "",
            .when = "",
            .then = "",
            .implementation = "",
            .test_cases = .{},
        };
    }
};

pub const TestCase = struct {
    name: []const u8,
    input: []const u8,
    expected: []const u8,
    tolerance: ?f64,
};

pub const Algorithm = struct {
    name: []const u8,
    description: []const u8,
    complexity: []const u8,
    pattern: []const u8,
    steps: ArrayList([]const u8),

    pub fn init(allocator: Allocator) Algorithm {
        _ = allocator;
        return Algorithm{
            .name = "",
            .description = "",
            .complexity = "",
            .pattern = "",
            .steps = .{},
        };
    }
};

pub const WasmExports = struct {
    functions: ArrayList([]const u8),
    memory: ArrayList(MemoryExport),

    pub fn init(allocator: Allocator) WasmExports {
        _ = allocator;
        return WasmExports{
            .functions = .{},
            .memory = .{},
        };
    }

    pub fn deinit(self: *WasmExports, allocator: Allocator) void {
        self.functions.deinit(allocator);
        self.memory.deinit(allocator);
    }
};

pub const MemoryExport = struct {
    name: []const u8,
    size: usize,
    type_name: ?[]const u8,
    alignment: usize,
};

pub const PasPrediction = struct {
    target: []const u8,
    current: []const u8,
    predicted: []const u8,
    confidence: f64,
    pattern: []const u8,
    status: ?[]const u8,
    timeline: ?[]const u8,
};

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

    /// Parse language array syntax: [zig, python, typescript]
    fn parseLanguageArray(self: *Self, languages: *ArrayList([]const u8)) !void {
        if (self.pos >= self.source.len or self.source[self.pos] != '[') return;
        self.pos += 1; // skip '['

        while (self.pos < self.source.len) {
            self.skipInlineWhitespace();
            if (self.pos >= self.source.len) break;

            // Check for end of array
            if (self.source[self.pos] == ']') {
                self.pos += 1; // skip ']'
                break;
            }

            // Skip comma separator
            if (self.source[self.pos] == ',') {
                self.pos += 1;
                continue;
            }

            // Read language name
            const start = self.pos;
            while (self.pos < self.source.len) {
                const c = self.source[self.pos];
                if (c == ',' or c == ']' or c == ' ' or c == '\t' or c == '\n' or c == '\r') break;
                self.pos += 1;
            }
            const lang = std.mem.trim(u8, self.source[start..self.pos], " \t");
            if (lang.len > 0) {
                try languages.append(self.allocator, lang);
            }
        }
    }

    fn parseTargets(self: *Self, targets: *ArrayList([]const u8)) !void {
        self.skipWhitespaceAndComments();
        while (self.pos < self.source.len) {
            self.skipWhitespaceAndComments();
            if (self.pos >= self.source.len) break;

            if (self.source[self.pos] != '-') break;
            self.pos += 1; // skip '-'
            self.skipWhitespaceAndComments();

            const target = self.readValue();
            if (target.len > 0) {
                try targets.append(self.allocator, target);
            }
        }
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

            // Проверяем что это не следующая секция
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
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 6) break;
            self.pos += indent;

            if (self.pos >= self.source.len or self.source[self.pos] != '-') {
                self.pos -= indent;
                break;
            }
            self.pos += 1; // skip '-'
            self.skipInlineWhitespace();

            var out = FSMOutput.init(self.allocator);

            // Read first key (should be 'state')
            const first_key = self.readKey();
            if (std.mem.eql(u8, first_key, "state")) {
                self.skipColon();
                out.state = self.readValue();
                self.skipToNextLine();

                // Read output signal values (any key except 'state')
                while (self.pos < self.source.len) {
                    self.skipEmptyLinesAndComments();
                    if (self.pos >= self.source.len) break;

                    const prop_indent = self.countIndent();
                    if (prop_indent < 8) break;
                    self.pos += prop_indent;

                    const prop_key = self.readKey();
                    if (prop_key.len == 0) break;
                    self.skipColon();

                    const val = self.readQuotedOrValue();
                    // Store any signal name -> value mapping
                    try out.signals.put(prop_key, val);
                    self.skipToNextLine();
                }
            } else {
                self.skipToNextLine();
                continue;
            }

            if (out.state.len > 0) {
                try outputs.append(self.allocator, out);
            }
        }
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

    // VIBEE Generator v2: Parse const definitions (name: "value")
    fn parseConsts(self: *Self, consts: *std.StringHashMap([]const u8)) !void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 6) break;
            self.pos += indent;

            const const_name = self.readKey();
            if (const_name.len == 0) break;
            self.skipColon();

            const const_value = self.readValue();
            // Store the name (owned) and value (reference to source)
            const name_owned = try self.allocator.dupe(u8, const_name);
            try consts.put(name_owned, const_value);
            self.skipToNextLine();
        }
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

            // Behaviors начинаются с '-'
            if (self.pos >= self.source.len or self.source[self.pos] != '-') {
                self.pos -= indent;
                break;
            }
            self.pos += 1;
            self.skipInlineWhitespace();

            var behavior = Behavior.init(self.allocator);

            // Первое поле на той же строке: "- name: value"
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
        // Parse top-level test_cases: (indent 2, not nested under behaviors)
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            if (self.pos >= self.source.len or self.source[self.pos] != '-') {
                self.pos -= indent;
                break;
            }
            self.pos += 1;
            self.skipInlineWhitespace();

            var test_case = TestCase{
                .name = "",
                .input = "",
                .expected = "",
                .tolerance = null,
            };

            // First field on same line
            const first_key = self.readKey();
            if (first_key.len > 0) {
                self.skipColon();
                if (std.mem.eql(u8, first_key, "name")) {
                    test_case.name = self.readValue();
                } else if (std.mem.eql(u8, first_key, "given")) {
                    test_case.input = self.readValue();
                } else if (std.mem.eql(u8, first_key, "input")) {
                    test_case.input = self.readBraceValue();
                }
            }
            self.skipToNextLine();

            // Read remaining fields
            while (self.pos < self.source.len) {
                self.skipEmptyLinesAndComments();
                if (self.pos >= self.source.len) break;

                const field_indent = self.countIndent();
                if (field_indent < 4) break;
                self.pos += field_indent;

                const field_key = self.readKey();
                if (field_key.len == 0) {
                    self.pos -= field_indent;
                    break;
                }
                self.skipColon();

                if (std.mem.eql(u8, field_key, "name")) {
                    test_case.name = self.readValue();
                } else if (std.mem.eql(u8, field_key, "given") or std.mem.eql(u8, field_key, "input")) {
                    // Support both "given" (from test_cases) and "input" (from behavior test_cases)
                    if (self.pos < self.source.len and self.source[self.pos] == '"') {
                        test_case.input = self.readValue();
                    } else {
                        test_case.input = self.readBraceValue();
                    }
                } else if (std.mem.eql(u8, field_key, "expected")) {
                    test_case.expected = self.readValue();
                } else if (std.mem.eql(u8, field_key, "tolerance")) {
                    const tol_str = self.readValue();
                    test_case.tolerance = std.fmt.parseFloat(f64, tol_str) catch null;
                }
                self.skipToNextLine();
            }

            try test_cases.append(self.allocator, test_case);
        }
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

    fn parseSteps(self: *Self, steps: *ArrayList([]const u8)) !void {
        while (self.pos < self.source.len) {
            self.skipWhitespaceAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 6) break;

            if (self.source[self.pos] != '-') break;
            self.pos += 1;
            self.skipWhitespaceAndComments();

            const step = self.readQuotedOrValue();
            if (step.len > 0) {
                try steps.append(self.allocator, step);
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

    fn parseFunctionList(self: *Self, functions: *ArrayList([]const u8)) !void {
        while (self.pos < self.source.len) {
            self.skipWhitespaceAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 4) break;

            if (self.source[self.pos] != '-') break;
            self.pos += 1;
            self.skipWhitespaceAndComments();

            const func = self.readValue();
            if (func.len > 0) {
                try functions.append(self.allocator, func);
            }
        }
    }

    fn parseWasmMemoryExports(self: *Self, memory: *ArrayList(MemoryExport)) !void {
        const s = try parser_sections.parseWasmMemoryExports(self.source, self.pos, self.line, self.allocator, memory);
        self.pos = s.pos;
        self.line = s.line;
    }

    fn parseMemoryExports(self: *Self, memory: *ArrayList(MemoryExport)) !void {
        while (self.pos < self.source.len) {
            self.skipWhitespaceAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 4) break;

            const name = self.readKey();
            if (name.len == 0) break;
            self.skipColon();

            var mem_export = MemoryExport{
                .name = name,
                .size = 0,
                .type_name = null,
                .alignment = 8,
            };

            while (self.pos < self.source.len) {
                self.skipWhitespaceAndComments();
                if (self.pos >= self.source.len) break;

                const field_indent = self.countIndent();
                if (field_indent <= 4) break;

                const field_key = self.readKey();
                if (field_key.len == 0) break;
                self.skipColon();

                if (std.mem.eql(u8, field_key, "size")) {
                    const size_str = self.readValue();
                    mem_export.size = std.fmt.parseInt(usize, size_str, 10) catch 0;
                } else if (std.mem.eql(u8, field_key, "type")) {
                    mem_export.type_name = self.readValue();
                } else if (std.mem.eql(u8, field_key, "alignment")) {
                    const align_str = self.readValue();
                    mem_export.alignment = std.fmt.parseInt(usize, align_str, 10) catch 8;
                }
            }

            try memory.append(self.allocator, mem_export);
        }
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
