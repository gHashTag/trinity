// spec_to_ir: VIBEE Spec → IR Module Converter
// TDGS-3 Phase 5: Complete the VIBEE → IR → TRI-27 pipeline
//
// Converts parsed VIBEE spec to IR Module for emit_t27_from_ir
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

const VibeeSpec = @import("parser_types.zig").VibeeSpec;
const Behavior = @import("parser_types.zig").Behavior;
const IR = @import("ir.zig");

// ═══════════════════════════════════════════════════════════════════════════════
/// SPEC TO IR CONVERTER
// ═══════════════════════════════════════════════════════════════════════════════

pub const SpecToIrConverter = struct {
    allocator: Allocator,
    module: *IR.Module,

    pub fn init(allocator: Allocator, spec_name: []const u8) !SpecToIrConverter {
        const module = try allocator.create(IR.Module);
        module.* = IR.Module.init(allocator, spec_name);
        return .{
            .allocator = allocator,
            .module = module,
        };
    }

    pub fn deinit(self: *SpecToIrConverter) void {
        self.module.deinit();
        self.allocator.destroy(self.module);
    }

    /// Convert VIBEE spec to IR Module
    pub fn convertSpec(self: *SpecToIrConverter, spec: *const VibeeSpec) !*IR.Module {
        // Create a "main" function from the first behavior
        if (spec.behaviors.items.len > 0) {
            const behavior = &spec.behaviors.items[0];
            _ = try self.convertBehavior(behavior);
        }

        return self.module;
    }

    /// Convert a single behavior to IR function
    fn convertBehavior(self: *SpecToIrConverter, behavior: *const Behavior) !*IR.Function {
        const func = try self.module.createFunction(behavior.name, .i32);
        const entry = try func.createBlock("entry");

        // For now, generate a simple constant return
        // TODO: Parse given/when/then to generate actual IR
        const const_val = try func.constInt(.i32, 42);
        try func.buildRet(entry, const_val);

        return func;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
/// HIGH-LEVEL API
// ═══════════════════════════════════════════════════════════════════════════════

/// Convert VIBEE spec to IR Module
pub fn specToIr(allocator: Allocator, spec: *const VibeeSpec) !*IR.Module {
    var converter = try SpecToIrConverter.init(allocator, spec.name);
    errdefer converter.deinit();
    return try converter.convertSpec(spec);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "SpecToIrConverter: init and deinit" {
    const allocator = std.testing.allocator;
    var converter = try SpecToIrConverter.init(allocator, "test");
    defer converter.deinit();

    try std.testing.expectEqualStrings("test", converter.module.name);
}

test "SpecToIrConverter: convert simple spec" {
    const allocator = std.testing.allocator;

    // Create a minimal spec
    var spec = VibeeSpec{
        .name = "test_spec",
        .version = "1.0",
        .language = "zig",
        .languages = std.ArrayListUnmanaged([]const u8){},
        .author = "test",
        .license = "MIT",
        .targets = std.ArrayListUnmanaged([]const u8){},
        .fpga_target = "generic",
        .pipeline = "auto",
        .target_frequency = 100,
        .imports = std.ArrayListUnmanaged(@import("parser_types.zig").Import){},
        .constants = std.ArrayListUnmanaged(@import("parser_types.zig").Constant){},
        .types = std.ArrayListUnmanaged(@import("parser_types.zig").TypeDef){},
        .creation_patterns = std.ArrayListUnmanaged(@import("parser_types.zig").CreationPattern){},
        .behaviors = std.ArrayListUnmanaged(Behavior){},
        .algorithms = std.ArrayListUnmanaged(@import("parser_types.zig").Algorithm){},
        .wasm_exports = .{ .functions = .{}, .memory = .{} },
        .pas_predictions = std.ArrayListUnmanaged(@import("parser_types.zig").PasPrediction){},
        .signals = std.ArrayListUnmanaged(@import("parser_types.zig").Signal){},
        .fsms = std.ArrayListUnmanaged(@import("parser_types.zig").FSMDef){},
        .reset = .{ .reset_type = "none", .level = "low" },
        .test_cases = std.ArrayListUnmanaged(@import("parser_types.zig").TestCase){},
        .allocator = allocator,
        .source_content = "",
        .owns_source = false,
        .zig_mode = .standard,
        .allocator_strategy = .none,
        .error_sets = std.ArrayListUnmanaged([]const u8){},
    };
    defer spec.deinit();

    // Add a simple behavior
    try spec.behaviors.append(allocator, Behavior{
        .name = "test_behavior",
        .owner = null,
        .given = "",
        .when = "",
        .then = "",
        .implementation = "",
        .test_cases = std.ArrayListUnmanaged(@import("parser_types.zig").TestCase){},
        .spec_annotation = null,
        .requires = std.ArrayListUnmanaged([]const u8){},
        .ensures = std.ArrayListUnmanaged([]const u8){},
        .examples = std.ArrayListUnmanaged(@import("parser_types.zig").TestCase){},
    });

    // Convert to IR
    var converter = try SpecToIrConverter.init(allocator, spec.name);
    defer converter.deinit();
    const module = try converter.convertSpec(&spec);

    // Verify module has the function
    try std.testing.expectEqual(@as(usize, 1), module.functions.count());
}
