// ═══════════════════════════════════════════════════════════════════════════════
// TEST GENERATION - Generate tests from behaviors and test_cases
// ═══════════════════════════════════════════════════════════════════════════════
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("types.zig");
const builder_mod = @import("builder.zig");
const utils = @import("utils.zig");

const CodeBuilder = builder_mod.CodeBuilder;
const Behavior = types.Behavior;
const TestCase = types.TestCase;
const ZigMode = types.ZigMode;
const Allocator = std.mem.Allocator;

pub const TestGenerator = struct {
    builder: *CodeBuilder,
    allocator: Allocator,
    spec_name: []const u8 = "",
    zig_mode: ZigMode = .idiomatic, // Cycle 76: idiomatic by default

    const Self = @This();

    pub fn init(builder: *CodeBuilder, allocator: Allocator) Self {
        return Self{
            .builder = builder,
            .allocator = allocator,
            .spec_name = "",
            .zig_mode = .standard,
        };
    }

    pub fn withSpec(builder: *CodeBuilder, allocator: Allocator, spec_name: []const u8, zig_mode: ZigMode) Self {
        return Self{
            .builder = builder,
            .allocator = allocator,
            .spec_name = spec_name,
            .zig_mode = zig_mode,
        };
    }

    pub fn writeTests(self: *Self, behaviors: []const Behavior) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TESTS - Generated from behaviors and test_cases");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        // Track already added tests
        var added_tests = std.StringHashMap(void).init(self.allocator);
        defer added_tests.deinit();

        for (behaviors) |b| {
            // Skip duplicates
            if (added_tests.contains(b.name)) continue;
            added_tests.put(b.name, {}) catch continue;

            try self.builder.writeFmt("test \"{s}_behavior\" {{\n", .{sanitizeIdent(b.name)});
            self.builder.incIndent();
            try self.builder.writeFmt("// Given: {s}\n", .{b.given});
            try self.builder.writeFmt("// When: {s}\n", .{b.when});
            try self.builder.writeFmt("// Then: {s}\n", .{b.then});

            // Generate assertions from test_cases
            if (b.test_cases.items.len > 0) {
                for (b.test_cases.items) |tc| {
                    try self.generateTestAssertion(b.name, tc);
                }
            } else {
                // Fallback for known tests without test_cases
                try self.generateKnownTestAssertion(b.name, b.then);
            }

            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.newline();
        }

        // Add base constants test if not present
        if (!added_tests.contains("phi_constants")) {
            try self.builder.writeLine("test \"phi_constants\" {");
            try self.builder.writeLine("    try std.testing.expectApproxEqAbs(PHI * PHI_INV, 1.0, 1e-10);");
            try self.builder.writeLine("    try std.testing.expectApproxEqAbs(PHI_SQ - PHI, 1.0, 1e-10);");
            try self.builder.writeLine("}");
        }
    }

    /// Write tests from spec-level test_cases (independent of behaviors)
    /// These are full integration tests with names like "cluster_init_16"
    pub fn writeSpecLevelTests(self: *Self, test_cases: []const TestCase) !void {
        if (test_cases.len == 0) return;

        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// SPEC-LEVEL TESTS - Integration tests from test_cases:");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        // Generate test for each test case
        for (test_cases) |tc| {
            try self.builder.writeLine("test \"");
            try self.builder.writeLine(tc.name);
            try self.builder.writeLine("\" {");
            // TODO: Add test body based on tc.expected
            try self.builder.writeLine("}");
        }
    }
};
