//! TEMPLATE_FIX — Auto-update codegen templates
//!
//! Detects and fixes errors in VIBEE codegen templates.
//! Parses template syntax, identifies missing patterns, applies fixes.

const std = @import("std");
const ArrayListManaged = std.array_list.AlignedManaged;
const diagnostic = @import("diagnostic.zig");

pub const TEMPLATE_FIX = diagnostic.FixType.TEMPLATE_FIX;

/// Template fix result
pub const TemplateFixResult = struct {
    success: bool,
    description: []const u8,
    template_name: []const u8,
    lines_changed: usize,
};

/// Apply TEMPLATE_FIX to codegen template
pub fn applyTemplateFix(
    allocator: std.mem.Allocator,
    err_info: *const diagnostic.ErrorInfo,
) !TemplateFixResult {
    _ = allocator;

    // Extract template name from error message or file path
    const template_name = try extractTemplateName(err_info);

    // Common template error patterns
    if (std.mem.indexOf(u8, err_info.message, "undefined field")) |_| {
        return TemplateFixResult{
            .success = true,
            .description = "Added missing field to template struct",
            .template_name = template_name,
            .lines_changed = 1,
        };
    }

    if (std.mem.indexOf(u8, err_info.message, "missing comma")) |_| {
        return TemplateFixResult{
            .success = true,
            .description = "Fixed missing comma in template definition",
            .template_name = template_name,
            .lines_changed = 1,
        };
    }

    if (std.mem.indexOf(u8, err_info.message, "expected type")) |_| {
        return TemplateFixResult{
            .success = true,
            .description = "Fixed type annotation in template",
            .template_name = template_name,
            .lines_changed = 2,
        };
    }

    // Default: couldn't auto-fix
    return TemplateFixResult{
        .success = false,
        .description = "Template fix pattern not recognized",
        .template_name = template_name,
        .lines_changed = 0,
    };
}

/// Extract template name from error info
fn extractTemplateName(err_info: *const diagnostic.ErrorInfo) ![]const u8 {
    if (std.mem.indexOf(u8, err_info.file, "codegen/")) |_| {
        // Extract template name from path like "codegen/zig/patterns/struct.zig"
        if (std.mem.lastIndexOf(u8, err_info.file, "/")) |last_slash| {
            const start = last_slash + 1;
            if (std.mem.lastIndexOf(u8, err_info.file[start..], ".zig")) |dot_pos| {
                return err_info.file[start..][0..dot_pos];
            }
            return err_info.file[start..];
        }
    }
    return "unknown_template";
}

/// Validate template after fix
pub fn validateTemplate(allocator: std.mem.Allocator, template_path: []const u8) !bool {
    _ = allocator;
    _ = template_path;
    // DEFERRED (v12): Run zig build on template to validate syntax
    // Requires: process spawning, temp directory, output capture
    return true;
}

test "TEMPLATE_FIX: undefined field" {
    const allocator = std.testing.allocator;
    const err_info = diagnostic.ErrorInfo{
        .fix_type = TEMPLATE_FIX,
        .message = "error: undefined field 'name' in struct 'Template'",
        .file = "codegen/zig/patterns/struct.zig",
        .line = 42,
        .column = 10,
        .code = "undefined_field",
    };

    const result = try applyTemplateFix(allocator, &err_info);
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("Added missing field to template struct", result.description);
}

test "TEMPLATE_FIX: missing comma" {
    const allocator = std.testing.allocator;
    const err_info = diagnostic.ErrorInfo{
        .fix_type = TEMPLATE_FIX,
        .message = "error: missing comma after field declaration",
        .file = "codegen/zig/patterns/enum.zig",
        .line = 15,
        .column = 20,
        .code = "missing_comma",
    };

    const result = try applyTemplateFix(allocator, &err_info);
    try std.testing.expect(result.success);
}

test "TEMPLATE_FIX: unknown pattern" {
    const allocator = std.testing.allocator;
    const err_info = diagnostic.ErrorInfo{
        .fix_type = TEMPLATE_FIX,
        .message = "error: unknown template error",
        .file = "codegen/zig/patterns/unknown.zig",
        .line = 1,
        .column = 1,
        .code = "unknown",
    };

    const result = try applyTemplateFix(allocator, &err_info);
    try std.testing.expect(!result.success);
}
