// ═══════════════════════════════════════════════════════════════════════════════
// PARSER TYPES — Shared Type Definitions for VIBEE Parser
// ═══════════════════════════════════════════════════════════════════════════════
//
// Cycle 87: IGLA Phase 7 — Type extraction
// Purpose: Break circular dependency between vibee_parser ↔ parser_sections
//
// Before: parser_sections imports vibee_parser for types
//         vibee_parser imports parser_sections for functions
//         (circular: works in Zig but architecturally fragile)
//
// After:  parser_types ← parser_sections (types only)
//         parser_types ← vibee_parser (types + re-exports)
//         parser_sections ← vibee_parser (functions only)
//         (clean DAG, no cycles)
//
// IGLA ([CYR:Игла]) — уtoол, убandin[CYR:ающ]andй [CYR:ручной] code
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;

// ═══════════════════════════════════════════════════════════════════════════════
// ZIG MODE & ALLOCATOR STRATEGY
// ═══════════════════════════════════════════════════════════════════════════════

/// Zig code generation mode (Cycle 74: Zig Idioms Enhancement)
pub const ZigMode = enum { standard, idiomatic, wasm };

/// Allocator injection strategy for idiomatic Zig
pub const AllocatorStrategy = enum { none, param, arena, gpa };

// ═══════════════════════════════════════════════════════════════════════════════
// CORE TYPES
// ═══════════════════════════════════════════════════════════════════════════════

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

pub const Field = struct {
    name: []const u8,
    type_name: []const u8,
};

pub const CreationPattern = struct {
    name: []const u8,
    source: []const u8,
    transformer: []const u8,
    result: []const u8,
};

pub const TestCase = struct {
    name: []const u8,
    input: []const u8,
    expected: []const u8,
    tolerance: ?f64,
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
// COMPOSITE TYPES (with nested collections)
// ═══════════════════════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════════════════════
// HDL TYPES
// ═══════════════════════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE SPEC (top-level)
// ═══════════════════════════════════════════════════════════════════════════════

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

        // Free in[CYR:ложенные] with[CYR:тру]to[CYR:туры]
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

        // Free оwithноin[CYR:ные] withпandwithtoand
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
