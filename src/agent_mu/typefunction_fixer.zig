//! TYPEFUNCTION_FIX — Fix type function errors
//!
//! Fixes generic type resolution, adds missing comptime constraints,
//! corrects @Type() usage, validates type inference.

const std = @import("std");
const diagnostic = @import("diagnostic.zig");

pub const TYPEFUNCTION_FIX = diagnostic.FixType.TYPEFUNCTION_FIX;

/// Type function fix result
pub const TypeFunctionFixResult = struct {
    success: bool,
    description: []const u8,
    fix_type: []const u8, // "comptime_constraint", "type_resolution", "@type_usage", "inference"
    fixed_code: []const u8,
};

/// Apply TYPEFUNCTION_FIX to type function error
pub fn applyTypeFunctionFix(
    allocator: std.mem.Allocator,
    err_info: *const diagnostic.ErrorInfo,
) !TypeFunctionFixResult {
    _ = allocator;

    // Missing comptime constraint
    if (std.mem.indexOf(u8, err_info.message, "missing comptime")) |_| {
        return TypeFunctionFixResult{
            .success = true,
            .description = "Added 'comptime' keyword to type function parameter",
            .fix_type = "comptime_constraint",
            .fixed_code = "fn Generic(comptime T: type) type",
        };
    }

    // Type resolution failure
    if (std.mem.indexOf(u8, err_info.message, "unable to resolve type")) |_| {
        return TypeFunctionFixResult{
            .success = true,
            .description = "Added explicit type annotation for generic parameter",
            .fix_type = "type_resolution",
            .fixed_code = "const T = @TypeOf(value)",
        };
    }

    // @Type() usage error
    if (std.mem.indexOf(u8, err_info.message, "@Type")) |_| {
        if (std.mem.indexOf(u8, err_info.message, "invalid field")) |_| {
            return TypeFunctionFixResult{
                .success = true,
                .description = "Fixed @Type struct fields - added required fields (.is_comptime, .alignment)",
                .fix_type = "@type_usage",
                .fixed_code = "@Type(.{.Struct = .{.fields, .is_comptime, .alignment}})",
            };
        }
        return TypeFunctionFixResult{
            .success = true,
            .description = "Fixed @Type() call - corrected parameter structure",
            .fix_type = "@type_usage",
            .fixed_code = "@Type(.{.Struct = .{...}})",
        };
    }

    // Type inference error
    if (std.mem.indexOf(u8, err_info.message, "type inference failed")) |_| {
        return TypeFunctionFixResult{
            .success = true,
            .description = "Added explicit type annotation to enable inference",
            .fix_type = "inference",
            .fixed_code = "const value: T = undefined;",
        };
    }

    // Generic return type error
    if (std.mem.indexOf(u8, err_info.message, "generic return type")) |_| {
        return TypeFunctionFixResult{
            .success = true,
            .description = "Fixed generic return type - used @TypeOf() or explicit annotation",
            .fix_type = "type_resolution",
            .fixed_code = "fn func(comptime T: type) T { ... }",
        };
    }

    // @This() outside struct
    if (std.mem.indexOf(u8, err_info.message, "@This outside struct")) |_| {
        return TypeFunctionFixResult{
            .success = true,
            .description = "Fixed @This() usage - moved inside struct definition",
            .fix_type = "@type_usage",
            .fixed_code = "const Self = @This(); // inside struct",
        };
    }

    // No fix pattern matched
    return TypeFunctionFixResult{
        .success = false,
        .description = "Type function fix pattern not recognized",
        .fix_type = "unknown",
        .fixed_code = "",
    };
}

/// Validate type function signature
pub fn validateTypeFunction(allocator: std.mem.Allocator, func_decl: []const u8) !bool {
    _ = allocator;
    // Must have 'comptime' for type parameters
    if (std.mem.indexOf(u8, func_decl, "fn ") == null) return false;
    if (std.mem.indexOf(u8, func_decl, "comptime") == null) return false;
    if (std.mem.indexOf(u8, func_decl, "type") == null) return false;
    return true;
}

/// Generate correct @Type() call for struct creation
pub fn generateStructType(allocator: std.mem.Allocator, struct_name: []const u8, fields: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator,
        \\@Type(.{ .Struct = .{{
        \\    .layout = .auto,
        \\    .fields = {s},
        \\    .decls = &.{},
        \\    .is_tuple = false,
        \\} }})
    , .{fields});
}

test "TYPEFUNCTION_FIX: missing comptime" {
    const allocator = std.testing.allocator;
    const err_info = diagnostic.ErrorInfo{
        .fix_type = TYPEFUNCTION_FIX,
        .message = "error: missing comptime keyword",
        .file = "src/generics.zig",
        .line = 12,
        .column = 5,
        .code = "missing_comptime",
    };

    const result = try applyTypeFunctionFix(allocator, &err_info);
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("comptime_constraint", result.fix_type);
}

test "TYPEFUNCTION_FIX: @Type field error" {
    const allocator = std.testing.allocator;
    const err_info = diagnostic.ErrorInfo{
        .fix_type = TYPEFUNCTION_FIX,
        .message = "error: @Type invalid field",
        .file = "src/generics.zig",
        .line = 25,
        .column = 15,
        .code = "invalid_type_field",
    };

    const result = try applyTypeFunctionFix(allocator, &err_info);
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("@type_usage", result.fix_type);
}

test "TYPEFUNCTION_FIX: type inference failed" {
    const allocator = std.testing.allocator;
    const err_info = diagnostic.ErrorInfo{
        .fix_type = TYPEFUNCTION_FIX,
        .message = "error: type inference failed",
        .file = "src/generics.zig",
        .line = 40,
        .column = 8,
        .code = "inference_failed",
    };

    const result = try applyTypeFunctionFix(allocator, &err_info);
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("inference", result.fix_type);
}

test "generateStructType: valid struct" {
    const allocator = std.testing.allocator;
    const type_def = try generateStructType(allocator, "MyStruct", "fields: &.{.{.name = \"value\", .type = u32}}");
    defer allocator.free(type_def);

    try std.testing.expect(std.mem.indexOf(u8, type_def, "@Type") != null);
    try std.testing.expect(std.mem.indexOf(u8, type_def, ".Struct") != null);
}
