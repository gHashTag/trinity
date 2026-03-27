//! VIBEE Parser Types — Generated from specs/vibee/parser_types.tri
//! φ² + 1/φ² = 3 | TRINITY
//!
//! DO NOT EDIT: This file is generated from parser_types.tri spec
//!
//! Shared type definitions for VIBEE parser system

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;

// ============================================================================
// ZIG MODE & ALLOCATOR STRATEGY
// ============================================================================

/// Zig code generation mode (Cycle 74: Zig Idioms Enhancement)
pub const ZigMode = enum { standard, idiomatic, wasm };

/// Allocator injection strategy for idiomatic Zig
pub const AllocatorStrategy = enum { none, param, arena, gpa };

// ============================================================================
// CORE TYPES
// ============================================================================

/// Constant value definition
pub const Constant = struct {
    name: []const u8,
    value: f64,
    string_value: []const u8,
    is_string: bool,
    description: []const u8,
};

/// Import definition for @import statements in generated code
pub const Import = struct {
    name: []const u8, // Alias name (e.g., "vsa")
    path: []const u8, // Path to import (e.g., "../src/vsa.zig")
};

/// Reset definition for state machine
pub const ResetDef = struct {
    reset_type: []const u8, // none, sync, async
    level: []const u8, // low, high
};

/// Field definition for structs
pub const Field = struct {
    name: []const u8,
    type_name: []const u8,
    constraint: []const u8 = "", // Validation constraint (e.g., "> 0", ">= 10 and <= 600")
};

/// Creation pattern for transformative operations
pub const CreationPattern = struct {
    name: []const u8,
    source: []const u8,
    transformer: []const u8,
    result: []const u8,
};

/// Test case for behavior verification
pub const TestCase = struct {
    name: []const u8,
    input: []const u8,
    expected: []const u8,
    tolerance: ?f64,
};

/// Memory export for FPGA/device integration
pub const MemoryExport = struct {
    name: []const u8,
    size: usize,
    type_name: ?[]const u8,
    alignment: usize,
};

/// PAS prediction for learning systems
pub const PasPrediction = struct {
    target: []const u8,
    current: []const u8,
    predicted: []const u8,
    confidence: f64,
    pattern: []const u8,
    status: ?[]const u8,
    timeline: ?[]const u8,
};

// ============================================================================
// COMPOSITE TYPES (with nested collections)
// ============================================================================

/// Type definition (struct, enum, union)
pub const TypeDef = struct {
    name: []const u8,
    base: ?[]const u8,
    fields: ArrayList(Field),
    constraints: ArrayList([]const u8),
    generic: ?[]const u8,
    description: []const u8,
    enum_variants: ArrayList([]const u8),
    consts: std.StringHashMap([]const u8),
    implements: ArrayList([]const u8),

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
            .implements = .{},
        };
    }

    pub fn deinit(self: *TypeDef, allocator: Allocator) void {
        self.fields.deinit(allocator);
        self.constraints.deinit(allocator);
        self.enum_variants.deinit(allocator);
        {
            var it = self.consts.iterator();
            while (it.next()) |entry| {
                allocator.free(entry.key_ptr.*);
                allocator.free(entry.value_ptr.*);
            }
        }
        self.consts.deinit();
        self.implements.deinit(allocator);
    }
};

/// Behavior definition (function contract)
pub const Behavior = struct {
    name: []const u8,
    owner: ?[]const u8, // Which struct owns this method
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

    pub fn deinit(self: *Behavior, allocator: Allocator) void {
        self.test_cases.deinit(allocator);
    }
};

/// Algorithm definition for computational operations
pub const Algorithm = struct {
    name: []const u8,
    inputs: ArrayList([]const u8),
    outputs: ArrayList([]const u8),
    steps: ArrayList([]const u8),
    big_o: []const u8,

    pub fn init(allocator: Allocator) Algorithm {
        _ = allocator;
        return Algorithm{
            .name = "",
            .inputs = .{},
            .outputs = .{},
            .steps = .{},
            .big_o = "",
        };
    }

    pub fn deinit(self: *Algorithm, allocator: Allocator) void {
        self.inputs.deinit(allocator);
        self.outputs.deinit(allocator);
        self.steps.deinit(allocator);
    }
};

// ============================================================================
// SPECIFICATION ROOT
// ============================================================================

/// Complete VIBEE specification
pub const VibeeSpec = struct {
    name: []const u8,
    version: []const u8,
    language: []const u8, // zig, varlog (Verilog), python
    module: []const u8,
    description: []const u8,
    author: []const u8,
    license: []const u8,
    zig_mode: ZigMode,
    allocator_strategy: AllocatorStrategy,

    // Collections
    types: ArrayList(TypeDef),
    behaviors: ArrayList(Behavior),
    algorithms: ArrayList(Algorithm),
    constants: ArrayList(Constant),
    imports: ArrayList(Import),
    tests: ArrayList(TestCase),

    pub fn init(allocator: Allocator) VibeeSpec {
        _ = allocator;
        return .{
            .name = "",
            .version = "1.0.0",
            .language = "zig",
            .module = "",
            .description = "",
            .author = "",
            .license = "MIT",
            .zig_mode = .standard,
            .allocator_strategy = .none,
            .types = .{},
            .behaviors = .{},
            .algorithms = .{},
            .constants = .{},
            .imports = .{},
            .tests = .{},
        };
    }

    pub fn deinit(self: *VibeeSpec, allocator: Allocator) void {
        // Note: Only free strings that were allocated (not string literals from init)
        // We track this by checking if the string doesn't match the default values
        if (self.name.len > 0 and self.name.ptr[0] != 0) {
            // Check if it's not a literal by comparing address
            // This is a simple heuristic - in production, use a flag
            allocator.free(self.name);
        }
        if (self.module.len > 0) {
            allocator.free(self.module);
        }
        if (self.description.len > 0) {
            allocator.free(self.description);
        }
        if (self.version.len > 0 and !std.mem.eql(u8, self.version, "1.0.0")) {
            allocator.free(self.version);
        }
        if (self.language.len > 0 and !std.mem.eql(u8, self.language, "zig")) {
            allocator.free(self.language);
        }
        if (self.author.len > 0 and !std.mem.eql(u8, self.author, "")) {
            allocator.free(self.author);
        }
        if (self.license.len > 0 and !std.mem.eql(u8, self.license, "MIT")) {
            allocator.free(self.license);
        }

        for (self.types.items) |*t| t.deinit(allocator);
        self.types.deinit(allocator);

        for (self.behaviors.items) |*b| b.deinit(allocator);
        self.behaviors.deinit(allocator);

        for (self.algorithms.items) |*a| a.deinit(allocator);
        self.algorithms.deinit(allocator);

        self.constants.deinit(allocator);
        self.imports.deinit(allocator);
        self.tests.deinit(allocator);
    }
};

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/// Create a field definition
pub fn makeField(allocator: Allocator, name: []const u8, type_name: []const u8) !Field {
    return Field{
        .name = try allocator.dupe(u8, name),
        .type_name = try allocator.dupe(u8, type_name),
        .constraint = "",
    };
}

/// Create a test case
pub fn makeTestCase(
    allocator: Allocator,
    name: []const u8,
    input: []const u8,
    expected: []const u8,
) !TestCase {
    return TestCase{
        .name = try allocator.dupe(u8, name),
        .input = try allocator.dupe(u8, input),
        .expected = try allocator.dupe(u8, expected),
        .tolerance = null,
    };
}

// ============================================================================
// TESTS
// ============================================================================

test "VIBEE Parser Types: TypeDef init" {
    const allocator = std.testing.allocator;
    var type_def = TypeDef.init(allocator);
    defer type_def.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), type_def.fields.items.len);
    try std.testing.expectEqual(@as(usize, 0), type_def.constraints.items.len);
}

test "VIBEE Parser Types: Behavior init" {
    const allocator = std.testing.allocator;
    var behavior = Behavior.init(allocator);
    defer behavior.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), behavior.test_cases.items.len);
}

test "VIBEE Parser Types: VibeeSpec init" {
    const allocator = std.testing.allocator;
    var spec = VibeeSpec.init(allocator);
    defer spec.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), spec.types.items.len);
    try std.testing.expectEqual(@as(usize, 0), spec.behaviors.items.len);
    try std.testing.expectEqualStrings("zig", spec.language);
    try std.testing.expectEqual(ZigMode.standard, spec.zig_mode);
}

test "VIBEE Parser Types: makeField" {
    const allocator = std.testing.allocator;
    const field = try makeField(allocator, "test_field", "u32");
    defer {
        allocator.free(field.name);
        allocator.free(field.type_name);
    }

    try std.testing.expectEqualStrings("test_field", field.name);
    try std.testing.expectEqualStrings("u32", field.type_name);
}

test "VIBEE Parser Types: makeTestCase" {
    const allocator = std.testing.allocator;
    const test_case = try makeTestCase(allocator, "test_1", "input", "output");
    defer {
        allocator.free(test_case.name);
        allocator.free(test_case.input);
        allocator.free(test_case.expected);
    }

    try std.testing.expectEqualStrings("test_1", test_case.name);
    try std.testing.expectEqualStrings("input", test_case.input);
    try std.testing.expectEqualStrings("output", test_case.expected);
}

test "VIBEE Parser Types: ZigMode enum" {
    try std.testing.expectEqual(@as(usize, 3), @typeInfo(ZigMode).@"enum".fields.len);
}

test "VIBEE Parser Types: AllocatorStrategy enum" {
    try std.testing.expectEqual(@as(usize, 4), @typeInfo(AllocatorStrategy).@"enum".fields.len);
}
