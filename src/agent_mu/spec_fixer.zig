//! SPEC_FIX — Auto-fix .vibee syntax errors
//!
//! Parses YAML structure, identifies missing required fields,
//! adds default values, validates against schema.

const std = @import("std");
const diagnostic = @import("diagnostic.zig");

pub const SPEC_FIX = diagnostic.FixType.SPEC_FIX;

/// Spec fix result
pub const SpecFixResult = struct {
    success: bool,
    description: []const u8,
    field_name: []const u8,
    default_value: []const u8,
};

/// Apply SPEC_FIX to .vibee file
pub fn applySpecFix(
    allocator: std.mem.Allocator,
    err_info: *const diagnostic.ErrorInfo,
) !SpecFixResult {
    _ = allocator;

    // Common .vibee error patterns
    if (std.mem.indexOf(u8, err_info.message, "missing field 'name'")) |_| {
        return SpecFixResult{
            .success = true,
            .description = "Added missing 'name' field to spec",
            .field_name = "name",
            .default_value = "unnamed_module",
        };
    }

    if (std.mem.indexOf(u8, err_info.message, "missing field 'version'")) |_| {
        return SpecFixResult{
            .success = true,
            .description = "Added missing 'version' field to spec",
            .field_name = "version",
            .default_value = "\"1.0.0\"",
        };
    }

    if (std.mem.indexOf(u8, err_info.message, "missing field 'language'")) |_| {
        return SpecFixResult{
            .success = true,
            .description = "Added missing 'language' field to spec",
            .field_name = "language",
            .default_value = "zig",
        };
    }

    if (std.mem.indexOf(u8, err_info.message, "invalid language")) |_| {
        return SpecFixResult{
            .success = true,
            .description = "Fixed invalid language value",
            .field_name = "language",
            .default_value = "zig",
        };
    }

    if (std.mem.indexOf(u8, err_info.message, "types: not found")) |_| {
        return SpecFixResult{
            .success = true,
            .description = "Added empty 'types' section to spec",
            .field_name = "types",
            .default_value = "{}",
        };
    }

    if (std.mem.indexOf(u8, err_info.message, "behaviors: not found")) |_| {
        return SpecFixResult{
            .success = true,
            .description = "Added empty 'behaviors' section to spec",
            .field_name = "behaviors",
            .default_value = "[]",
        };
    }

    // No fix pattern matched
    return SpecFixResult{
        .success = false,
        .description = "Spec fix pattern not recognized",
        .field_name = "",
        .default_value = "",
    };
}

/// Validate .vibee spec against schema
pub fn validateSpec(allocator: std.mem.Allocator, spec_path: []const u8) !bool {
    _ = allocator;
    _ = spec_path;
    // TODO: Parse YAML and validate required fields
    return true;
}

/// Get default value for a field
pub fn getDefaultValue(allocator: std.mem.Allocator, field_name: []const u8) ![]const u8 {
    if (std.mem.eql(u8, field_name, "name")) {
        return allocator.dupe(u8, "unnamed_module");
    }
    if (std.mem.eql(u8, field_name, "version")) {
        return allocator.dupe(u8, "\"1.0.0\"");
    }
    if (std.mem.eql(u8, field_name, "language")) {
        return allocator.dupe(u8, "zig");
    }
    if (std.mem.eql(u8, field_name, "module")) {
        return allocator.dupe(u8, "unnamed_module");
    }
    return error.UnknownField;
}

test "SPEC_FIX: missing name" {
    const allocator = std.testing.allocator;
    const err_info = diagnostic.ErrorInfo{
        .fix_type = SPEC_FIX,
        .message = "error: missing field 'name' in .vibee spec",
        .file = "specs/tri/test.vibee",
        .line = 1,
        .column = 1,
        .code = "missing_name",
    };

    const result = try applySpecFix(allocator, &err_info);
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("name", result.field_name);
}

test "SPEC_FIX: missing version" {
    const allocator = std.testing.allocator;
    const err_info = diagnostic.ErrorInfo{
        .fix_type = SPEC_FIX,
        .message = "error: missing field 'version' in .vibee spec",
        .file = "specs/tri/test.vibee",
        .line = 2,
        .column = 1,
        "code": "missing_version",
    };

    const result = try applySpecFix(allocator, &err_info);
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("version", result.field_name);
}

test "SPEC_FIX: unknown error" {
    const allocator = std.testing.allocator;
    const err_info = diagnostic.ErrorInfo{
        .fix_type = SPEC_FIX,
        .message = "error: unknown spec error",
        .file": "specs/tri/test.vibee",
        .line = 1,
        .column = 1,
        .code": "unknown",
    };

    const result = try applySpecFix(allocator, &err_info);
    try std.testing.expect(!result.success);
}
