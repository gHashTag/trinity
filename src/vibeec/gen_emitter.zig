//! VIBEE Codegen Emitter — Generated from specs/vibee/emitter.tri
//! φ² + 1/φ² = 3 | TRINITY
//!
//! DO NOT EDIT: This file is generated from emitter.tri spec
//!
//! Zig code generation emitter for VIBEE specifications

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;

pub const parser_types = @import("gen_parser_types.zig");

// Re-export key types
pub const VibeeSpec = parser_types.VibeeSpec;
pub const TypeDef = parser_types.TypeDef;
pub const Behavior = parser_types.Behavior;
pub const Field = parser_types.Field;

// ============================================================================
// EMITTER CONFIGURATION
// ============================================================================

/// Code generation options
pub const EmitConfig = struct {
    /// Add file header with generation notice
    emit_header: bool = true,
    /// Add doc comments to generated code
    emit_docs: bool = true,
    /// Include test cases
    emit_tests: bool = true,
    /// Zig code generation mode
    zig_mode: parser_types.ZigMode = .standard,
    /// Allocator strategy
    allocator_strategy: parser_types.AllocatorStrategy = .param,
};

// ============================================================================
// CODE BUILDER
// ============================================================================

/// Incremental Zig code builder
pub const CodeBuilder = struct {
    allocator: Allocator,
    buffer: ArrayList(u8),
    indent_level: usize = 0,

    pub fn init(allocator: Allocator) CodeBuilder {
        return .{
            .allocator = allocator,
            .buffer = ArrayList(u8){},
        };
    }

    pub fn deinit(self: *CodeBuilder) void {
        self.buffer.deinit(self.allocator);
    }

    /// Get the generated code as string
    pub fn toString(self: *CodeBuilder) ![]u8 {
        return self.buffer.toOwnedSlice(self.allocator);
    }

    /// Add raw text to buffer
    pub fn append(self: *CodeBuilder, text: []const u8) !void {
        try self.buffer.appendSlice(self.allocator, text);
    }

    /// Add formatted line
    pub fn line(self: *CodeBuilder, comptime fmt: []const u8, args: anytype) !void {
        try self.indent();
        try self.append(std.fmt.allocPrint(self.allocator, fmt ++ "\n", args) catch return error.OutOfMemory);
    }

    /// Add blank line
    pub fn blank(self: *CodeBuilder) !void {
        try self.append("\n");
    }

    /// Add current indentation
    pub fn indent(self: *CodeBuilder) !void {
        var i: usize = 0;
        while (i < self.indent_level) : (i += 1) {
            try self.append("    ");
        }
    }

    /// Increase indent level
    pub fn pushIndent(self: *CodeBuilder) void {
        self.indent_level += 1;
    }

    /// Decrease indent level
    pub fn popIndent(self: *CodeBuilder) void {
        if (self.indent_level > 0) self.indent_level -= 1;
    }

    /// Add comment
    pub fn comment(self: *CodeBuilder, text: []const u8) !void {
        try self.line("// {s}", .{text});
    }

    /// Add block comment
    pub fn blockComment(self: *CodeBuilder, lines: []const []const u8) !void {
        for (lines) |l| {
            try self.line("// {s}", .{l});
        }
    }

    /// Add struct definition
    pub fn structDef(self: *CodeBuilder, name: []const u8, fields: []const Field) !void {
        try self.line("pub const {s} = struct {{", .{name});
        self.pushIndent();
        for (fields) |field| {
            try self.line("{s}: {s},", .{ field.name, field.type_name });
        }
        self.popIndent();
        try self.line("}};", .{});
    }

    /// Add function signature
    pub fn fnSig(self: *CodeBuilder, name: []const u8, params: []const Field, return_type: []const u8) !void {
        var param_str = ArrayList(u8).init(self.allocator);
        defer param_str.deinit(self.allocator);

        for (params, 0..) |param, i| {
            if (i > 0) try param_str.appendSlice(self.allocator, ", ");
            try param_str.writer().print("{s}: {s}", .{ param.name, param.type_name });
        }

        try self.line("pub fn {s}({s}) {s} {{", .{ name, param_str.items, return_type });
    }

    /// Add return statement
    pub fn ret(self: *CodeBuilder, value: []const u8) !void {
        try self.line("return {s};", .{value});
    }

    /// Add const declaration
    pub fn constDecl(self: *CodeBuilder, name: []const u8, type_name: []const u8, value: []const u8) !void {
        try self.line("pub const {s}: {s} = {s};", .{ name, type_name, value });
    }

    /// Add var declaration
    pub fn varDecl(self: *CodeBuilder, name: []const u8, type_name: []const u8, value: []const u8) !void {
        try self.line("var {s}: {s} = {s};", .{ name, type_name, value });
    }

    /// Add import statement
    pub fn importStmt(self: *CodeBuilder, path: []const u8, alias: ?[]const u8) !void {
        if (alias) |a| {
            try self.line("const {s} = @import(\"{s}\");", .{ a, path });
        } else {
            try self.line("const {s} = @import(\"{s}\");", .{ std.fs.path.basename(path), path });
        }
    }
};

// ============================================================================
// EMITTER
// ============================================================================

/// Emit Zig code from VIBEE specification
pub fn emit(allocator: Allocator, spec: *const VibeeSpec, config: EmitConfig) ![]const u8 {
    var builder = CodeBuilder.init(allocator);
    errdefer builder.deinit();

    // File header
    if (config.emit_header) {
        try builder.comment("Generated from VIBEE specification");
        try builder.comment("DO NOT EDIT: Modify .tri spec and regenerate");
        try builder.blank();
    }

    // Module doc comment
    if (config.emit_docs and spec.description.len > 0) {
        try builder.comment(spec.description);
        try builder.blank();
    }

    // Imports
    if (spec.imports.items.len > 0) {
        for (spec.imports.items) |imp| {
            try builder.importStmt(imp.path, imp.name);
        }
        try builder.blank();
    }

    // Constants
    if (spec.constants.items.len > 0) {
        try builder.comment("Constants");
        for (spec.constants.items) |c| {
            if (c.is_string) {
                try builder.constDecl(c.name, "[]const u8", std.fmt.allocPrint(allocator, "\"{s}\"", .{c.string_value}) catch return error.OutOfMemory);
            } else {
                try builder.constDecl(c.name, "f64", std.fmt.allocPrint(allocator, "{d}", .{c.value}) catch return error.OutOfMemory);
            }
        }
        try builder.blank();
    }

    // Types
    if (spec.types.items.len > 0) {
        for (spec.types.items) |t| {
            if (t.fields.items.len > 0) {
                try builder.structDef(t.name, t.fields.items);
                try builder.blank();
            }
        }
    }

    // Behaviors (functions)
    if (config.emit_tests and spec.behaviors.items.len > 0) {
        for (spec.behaviors.items) |b| {
            if (b.implementation.len > 0) {
                try builder.append(b.implementation);
                try builder.blank();
            }
        }
    }

    return builder.toString();
}

// ============================================================================
// TESTS
// ============================================================================

test "Emitter: CodeBuilder init" {
    const allocator = std.testing.allocator;
    var builder = CodeBuilder.init(allocator);
    defer builder.deinit();

    try std.testing.expectEqual(@as(usize, 0), builder.buffer.items.len);
    try std.testing.expectEqual(@as(usize, 0), builder.indent_level);
}

test "Emitter: CodeBuilder append" {
    const allocator = std.testing.allocator;
    var builder = CodeBuilder.init(allocator);
    defer builder.deinit();

    try builder.append("test");
    try std.testing.expectEqualStrings("test", builder.buffer.items);
}

test "Emitter: CodeBuilder line" {
    const allocator = std.testing.allocator;
    var builder = CodeBuilder.init(allocator);
    defer builder.deinit();

    try builder.line("test {d}", .{42});
    try std.testing.expectEqualStrings("test 42\n", builder.buffer.items);
}

test "Emitter: CodeBuilder indent" {
    const allocator = std.testing.allocator;
    var builder = CodeBuilder.init(allocator);
    defer builder.deinit();

    builder.pushIndent();
    try builder.line("test", .{});
    try std.testing.expectEqualStrings("    test\n", builder.buffer.items);
}

test "Emitter: CodeBuilder structDef" {
    const allocator = std.testing.allocator;
    var builder = CodeBuilder.init(allocator);
    defer builder.deinit();

    const fields = [_]Field{
        .{ .name = "x", .type_name = "f64", .constraint = "" },
        .{ .name = "y", .type_name = "f64", .constraint = "" },
    };

    try builder.structDef("Point", &fields);
    const result = builder.buffer.items;

    try std.testing.expect(std.mem.indexOf(u8, result, "pub const Point") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "x: f64") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "y: f64") != null);
}

test "Emitter: CodeBuilder comment" {
    const allocator = std.testing.allocator;
    var builder = CodeBuilder.init(allocator);
    defer builder.deinit();

    try builder.comment("test comment");
    try std.testing.expectEqualStrings("// test comment\n", builder.buffer.items);
}

test "Emitter: CodeBuilder constDecl" {
    const allocator = std.testing.allocator;
    var builder = CodeBuilder.init(allocator);
    defer builder.deinit();

    try builder.constDecl("TEST", "u32", "42");
    try std.testing.expectEqualStrings("pub const TEST: u32 = 42;\n", builder.buffer.items);
}

test "Emitter: CodeBuilder importStmt" {
    const allocator = std.testing.allocator;
    var builder = CodeBuilder.init(allocator);
    defer builder.deinit();

    try builder.importStmt("std", null);
    const result = builder.buffer.items;

    try std.testing.expect(std.mem.indexOf(u8, result, "@import") != null);
}

test "Emitter: emit basic spec" {
    const allocator = std.testing.allocator;
    var spec = VibeeSpec.init(allocator);
    defer spec.deinit(allocator);

    spec.name = "test_spec";
    spec.module = "test.module";

    const config = EmitConfig{};
    const result = try emit(allocator, &spec, config);
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "Generated from VIBEE") != null);
}
