//! Auto-fixing for AGENT MU
//!
//! Applies automatic fixes to generated code based on error classification.
//! Phase 3 feature - extends basic verification with actual fixes.

const std = @import("std");
const diagnostic = @import("diagnostic.zig");

/// Result of a fix attempt
pub const FixResult = struct {
    success: bool,
    description: []const u8,
    files_modified: [][]const u8,

    /// Free allocated memory
    pub fn deinit(self: *FixResult, allocator: std.mem.Allocator) void {
        allocator.free(self.description);
        for (self.files_modified) |f| allocator.free(f);
        allocator.free(self.files_modified);
        self.* = undefined;
    }
};

/// Apply automatic formatting using zig fmt
fn applyFormatFix(allocator: std.mem.Allocator, file_path: []const u8) !FixResult {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zig", "fmt", file_path },
    });
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    const success = result.term == .Exited and result.term.Exited == 0;

    return FixResult{
        .success = success,
        .description = try allocator.dupe(u8, "Applied zig fmt"),
        .files_modified = try allocator.dupe([]const u8, &[_][]const u8{file_path}),
    };
}

/// Apply fix based on error information
///
/// Phase 3: Auto-fixes format errors and other simple issues.
///
/// Parameters:
///   - allocator: Memory allocator
///   - err_info: Parsed error information
///   - file_path: Path to the file that needs fixing
///
/// Returns: FixResult with success status and details
pub fn applyFix(
    allocator: std.mem.Allocator,
    err_info: *const diagnostic.ErrorInfo,
    file_path: []const u8,
) !FixResult {
    switch (err_info.fix_type) {
        .SYNTAX_FIX => {
            // Check if it's a formatting error
            if (std.mem.indexOf(u8, err_info.message, "formatting check failed") != null) {
                return applyFormatFix(allocator, file_path);
            }

            // TODO: Phase 3 - Implement other syntax fixes (semicolons, braces)
            return FixResult{
                .success = false,
                .description = try allocator.dupe(u8, "Syntax fixing not yet implemented for this error"),
                .files_modified = &[_][]const u8{},
            };
        },
        .IMPORT_FIX => {
            // TODO: Phase 3 - Implement import adding
            return FixResult{
                .success = false,
                .description = try allocator.dupe(u8, "Import fixing not yet implemented"),
                .files_modified = &[_][]const u8{},
            };
        },
        .TEMPLATE_FIX => {
            // Requires modifying codegen templates - manual review needed
            return FixResult{
                .success = false,
                .description = try allocator.dupe(u8, "Template fixes require manual review"),
                .files_modified = &[_][]const u8{},
            };
        },
        .SPEC_FIX => {
            // Requires modifying .vibee spec - manual review needed
            return FixResult{
                .success = false,
                .description = try allocator.dupe(u8, "Spec fixes require manual review"),
                .files_modified = &[_][]const u8{},
            };
        },
        .TYPE_FIX => {
            // Type mismatches usually require design decisions
            return FixResult{
                .success = false,
                .description = try allocator.dupe(u8, "Type fixes require manual review"),
                .files_modified = &[_][]const u8{},
            };
        },
        .GENERATOR_PATCH => {
            // Requires modifying vibee compiler itself
            return FixResult{
                .success = false,
                .description = try allocator.dupe(u8, "Generator patches require manual review"),
                .files_modified = &[_][]const u8{},
            };
        },
        .UNKNOWN => {
            return FixResult{
                .success = false,
                .description = try allocator.dupe(u8, "Unknown error type - manual review required"),
                .files_modified = &[_][]const u8{},
            };
        },
    }
}

/// Check if a fix type is supported for auto-fixing
pub fn isFixable(fix_type: diagnostic.FixType) bool {
    return switch (fix_type) {
        .IMPORT_FIX => true,    // Will be implemented in Phase 3
        .SYNTAX_FIX => true,    // Format fixing implemented
        .SPEC_FIX => false,
        .GENERATOR_PATCH => false,
        .TEMPLATE_FIX => false,
        .TYPE_FIX => false,
        .UNKNOWN => false,
    };
}

test "fixer: applyFormatFix" {
    const allocator = std.testing.allocator;

    // Create a temporary unformatted file
    const tmp = try std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const test_file = "test_unformatted.zig";
    try tmp.dir.writeFile(test_file,
        \\const std=@import("std");
        \\pub fn add(a:i32,b:i32)i32{return a+b;}
    );

    const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ tmp.dir.path, test_file });
    defer allocator.free(path);

    const result = try applyFormatFix(allocator, path);
    defer result.deinit(allocator);

    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("Applied zig fmt", result.description);
}
