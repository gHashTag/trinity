// ═══════════════════════════════════════════════════════════════════════════════
// CODEGEN MODULE - Public exports for Zig code generation
// ═══════════════════════════════════════════════════════════════════════════════
//
// Modular decomposition of zig_codegen.zig for clean code and easier maintenance
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

// Core components
pub const types = @import("types.zig");
pub const builder = @import("builder.zig");
pub const utils = @import("utils.zig");
pub const utils_fix = @import("utils_fix.zig");
pub const patterns = @import("patterns.zig");
pub const tests_gen = @import("tests_gen.zig");
pub const emitter = @import("emitter.zig");
pub const type_resolver = @import("type_resolver.zig");
pub const zig_idioms = @import("zig_idioms.zig");
pub const signature = @import("signature.zig");
pub const body_emitter = @import("body_emitter.zig");
pub const vsa_emitter = @import("vsa_emitter.zig");
pub const struct_emitters = @import("struct_emitters.zig");

// Primary exports
pub const ZigCodeGen = emitter.ZigCodeGen;
pub const CodeBuilder = builder.CodeBuilder;
pub const PatternMatcher = patterns.PatternMatcher;
pub const TestGenerator = tests_gen.TestGenerator;
pub const ZigIdioms = zig_idioms.ZigIdioms;

// Type re-exports from parser
pub const VibeeSpec = types.VibeeSpec;
pub const ZigMode = types.ZigMode;
pub const AllocatorStrategy = types.AllocatorStrategy;
pub const Behavior = types.Behavior;
pub const TypeDef = types.TypeDef;
pub const Constant = types.Constant;
pub const CreationPattern = types.CreationPattern;

// Utility functions
pub const mapType = utils.mapType;
pub const cleanTypeName = utils.cleanTypeName;
pub const escapeReservedWord = utils.escapeReservedWord;
pub const stripQuotes = utils.stripQuotes;
pub const parseU64 = utils.parseU64;
pub const parseF64 = utils.parseF64;
pub const extractNumber = utils.extractNumber;
pub const extractIntParam = utils.extractIntParam;
pub const extractFloatParam = utils.extractFloatParam;

// Fixed generic type utilities
pub const mapTypeFixed = utils_fix.mapTypeFixed;
pub const extractInnerType = utils_fix.extractInnerType;

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "module imports" {
    const std = @import("std");
    _ = ZigCodeGen;
    _ = CodeBuilder;
    _ = PatternMatcher;
    _ = TestGenerator;
    std.debug.print("All modules imported successfully\n", .{});
}
