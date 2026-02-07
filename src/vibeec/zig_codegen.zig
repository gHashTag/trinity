// ═══════════════════════════════════════════════════════════════════════════════
// ZIG CODE GENERATION - Facade for modular codegen
// ═══════════════════════════════════════════════════════════════════════════════
//
// This file is a facade that re-exports the modular codegen components.
// The actual implementation is split into:
//   - codegen/types.zig      - Type definitions
//   - codegen/builder.zig    - CodeBuilder for output generation
//   - codegen/utils.zig      - Utility functions (mapType, etc.)
//   - codegen/patterns.zig   - Pattern matching (DSL, VSA, Metal, etc.)
//   - codegen/tests_gen.zig  - Test generation from behaviors
//   - codegen/emitter.zig    - Main ZigCodeGen engine
//   - codegen/mod.zig        - Module re-exports
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import modular components
pub const codegen = @import("codegen/mod.zig");
pub const vibee_parser = @import("vibee_parser.zig");

// Re-export main types
pub const ZigCodeGen = codegen.ZigCodeGen;
pub const CodeBuilder = codegen.CodeBuilder;
pub const PatternMatcher = codegen.PatternMatcher;
pub const TestGenerator = codegen.TestGenerator;

// Re-export parser types
pub const VibeeSpec = vibee_parser.VibeeSpec;
pub const Behavior = vibee_parser.Behavior;
pub const TypeDef = vibee_parser.TypeDef;
pub const Constant = vibee_parser.Constant;
pub const CreationPattern = vibee_parser.CreationPattern;
pub const TestCase = vibee_parser.TestCase;

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN ENTRY POINT - For backward compatibility
// ═══════════════════════════════════════════════════════════════════════════════

/// Generate Zig code from a .vibee file
pub fn generateFromFile(allocator: Allocator, vibee_path: []const u8, output_path: []const u8) !void {
    // Read .vibee file
    const file = try std.fs.cwd().openFile(vibee_path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(source);

    // Parse
    var parser = vibee_parser.VibeeParser.init(allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    // Generate Zig code
    var gen = ZigCodeGen.init(allocator);
    defer gen.deinit();

    const output = try gen.generate(&spec);

    // Write to file
    const out_file = try std.fs.cwd().createFile(output_path, .{});
    defer out_file.close();

    try out_file.writeAll(output);
}

/// Generate Zig code from a VibeeSpec (for programmatic use)
pub fn generateFromSpec(allocator: Allocator, spec: *const VibeeSpec) ![]const u8 {
    var gen = ZigCodeGen.init(allocator);
    defer gen.deinit();
    return try gen.generate(spec);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "zig_codegen facade imports" {
    _ = ZigCodeGen;
    _ = CodeBuilder;
    _ = PatternMatcher;
    _ = TestGenerator;
    std.debug.print("Facade imports successful\n", .{});
}

test "codegen submodules" {
    _ = @import("codegen/types.zig");
    _ = @import("codegen/builder.zig");
    _ = @import("codegen/utils.zig");
    _ = @import("codegen/patterns.zig");
    _ = @import("codegen/tests_gen.zig");
    _ = @import("codegen/emitter.zig");
    _ = @import("codegen/mod.zig");
}
