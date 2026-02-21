//! Error diagnostic and classification for AGENT MU
//!
//! Parses Zig compiler error messages and classifies them into FixType categories
//! for automatic fixing.

const std = @import("std");

/// Type of fix required for the error
pub const FixType = enum {
    /// Error in .vibee spec syntax (missing colon, invalid type, etc.)
    SPEC_FIX,
    /// Bug in vibee compiler itself (needs patch in src/vibeec/)
    GENERATOR_PATCH,
    /// Error in code generation template (wrong pattern, missing boilerplate)
    TEMPLATE_FIX,
    /// Missing import statement in generated code
    IMPORT_FIX,
    /// Type mismatch or incorrect type usage
    TYPE_FIX,
    /// Syntax error in generated Zig code (missing semicolon, etc.)
    SYNTAX_FIX,
    /// Unknown error type - requires manual review
    UNKNOWN,
};

/// Parsed error information
pub const ErrorInfo = struct {
    /// Type of fix required
    fix_type: FixType,
    /// Full error message
    message: []const u8,
    /// File where error occurred
    file: []const u8,
    /// Line number (0 if unknown)
    line: u32,
    /// Column number (0 if unknown)
    column: u32,
    /// Error code (e.g., "expected type 'T', found '[]const u8'")
    code: []const u8,

    /// Free allocated memory
    pub fn deinit(self: *ErrorInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.message);
        allocator.free(self.file);
        allocator.free(self.code);
        self.* = undefined;
    }
};

/// Parse error message and extract location
///
/// Zig error format:
///   /path/to/file.zig:42:15: error: expected type 'T', found '[]const u8'
///   /path/to/file.zig:42:15: error: use of undeclared identifier 'foo'
///   /path/to/file.zig: note: declared here
fn parseErrorLine(allocator: std.mem.Allocator, line: []const u8) !ErrorInfo {
    // Find the error marker
    const error_marker = ": error:";
    const error_pos = std.mem.indexOf(u8, line, error_marker) orelse return error.UnknownError;

    // Split into location and message parts
    const location_part = line[0..error_pos];
    const message_part = line[error_pos + error_marker.len..];

    // Parse location: /path/to/file.zig:42:15
    var location_parts = std.mem.splitScalar(u8, location_part, ':');

    const file = location_parts.first();
    const line_str = location_parts.next() orelse "";
    const column_str = location_parts.next() orelse "";

    const line_num = std.fmt.parseInt(u32, line_str, 10) catch 0;
    const column_num = std.fmt.parseInt(u32, column_str, 10) catch 0;

    // Clean up message (trim whitespace and "error:" prefix if present)
    var message = std.mem.trim(u8, message_part, &std.ascii.whitespace);
    message = std.mem.trim(u8, message, "error:");

    return ErrorInfo{
        .fix_type = .UNKNOWN,
        .message = try allocator.dupe(u8, message),
        .file = try allocator.dupe(u8, file),
        .line = line_num,
        .column = column_num,
        .code = try allocator.dupe(u8, message),
    };
}

/// Classify error into FixType based on error message content
fn classifyError(err_info: *ErrorInfo) void {
    const msg = err_info.message;

    // Check for import errors
    if (std.mem.indexOf(u8, msg, "use of undeclared identifier") != null or
        std.mem.indexOf(u8, msg, "no such file or directory") != null or
        std.mem.indexOf(u8, msg, "@import(\"std\")") != null)
    {
        err_info.fix_type = .IMPORT_FIX;
        return;
    }

    // Check for type errors
    if (std.mem.indexOf(u8, msg, "expected type") != null or
        std.mem.indexOf(u8, msg, "cannot convert") != null or
        std.mem.indexOf(u8, msg, "type mismatch") != null or
        std.mem.indexOf(u8, msg, "not a function") != null)
    {
        err_info.fix_type = .TYPE_FIX;
        return;
    }

    // Check for syntax errors
    if (std.mem.indexOf(u8, msg, "expected ')'") != null or
        std.mem.indexOf(u8, msg, "expected ';'") != null or
        std.mem.indexOf(u8, msg, "expected '}'") != null or
        std.mem.indexOf(u8, msg, "expected ','") != null or
        std.mem.indexOf(u8, msg, "expected token") != null or
        std.mem.indexOf(u8, msg, "extra token") != null or
        std.mem.indexOf(u8, msg, "syntax error") != null or
        std.mem.indexOf(u8, msg, "formatting check failed") != null)
    {
        err_info.fix_type = .SYNTAX_FIX;
        return;
    }

    // Check for template/codegen errors (structural issues)
    if (std.mem.indexOf(u8, msg, "struct has no member") != null or
        std.mem.indexOf(u8, msg, "no field named") != null or
        std.mem.indexOf(u8, msg, "container does not support") != null)
    {
        err_info.fix_type = .TEMPLATE_FIX;
        return;
    }

    // Check if error is in generated code (implies GENERATOR_PATCH)
    if (std.mem.indexOf(u8, err_info.file, "trinity/output") != null or
        std.mem.indexOf(u8, err_info.file, "generated") != null)
    {
        // Error in generated output - likely a generator issue
        err_info.fix_type = .GENERATOR_PATCH;
        return;
    }

    // Check if error is in a .vibee spec file
    if (std.mem.endsWith(u8, err_info.file, ".vibee")) {
        err_info.fix_type = .SPEC_FIX;
        return;
    }

    // Default: unknown error
    err_info.fix_type = .UNKNOWN;
}

/// Parse stderr from zig build and classify errors
///
/// Searches through stderr for error lines and returns the first
/// classified error found.
///
/// Parameters:
///   - allocator: Memory allocator
///   - stderr: Standard error output from zig build
///
/// Returns: ErrorInfo struct with parsed and classified error
pub fn parse(allocator: std.mem.Allocator, stderr: []const u8) !ErrorInfo {
    var lines = std.mem.splitScalar(u8, stderr, '\n');

    while (lines.next()) |line| {
        // Skip empty lines
        if (line.len == 0) continue;

        // Skip warning lines (we only care about errors for now)
        if (std.mem.indexOf(u8, line, ": warning:") != null) continue;

        // Look for error lines
        if (std.mem.indexOf(u8, line, ": error:") != null) {
            var err_info = try parseErrorLine(allocator, line);
            classifyError(&err_info);
            return err_info;
        }
    }

    // No error found - return a generic error
    return ErrorInfo{
        .fix_type = .UNKNOWN,
        .message = try allocator.dupe(u8, "No error found in stderr"),
        .file = try allocator.dupe(u8, "unknown"),
        .line = 0,
        .column = 0,
        .code = try allocator.dupe(u8, "unknown"),
    };
}

/// Check if an error is auto-fixable
pub fn isAutoFixable(fix_type: FixType) bool {
    return switch (fix_type) {
        .IMPORT_FIX => true,
        .SYNTAX_FIX => true,  // Some syntax errors are fixable
        .SPEC_FIX => false,   // Requires spec modification
        .GENERATOR_PATCH => false,  // Requires generator code change
        .TEMPLATE_FIX => false,     // Requires template modification
        .TYPE_FIX => false,    // Usually requires design decision
        .UNKNOWN => false,
    };
}

/// Get a human-readable description of the fix type
pub fn fixTypeDescription(fix_type: FixType) []const u8 {
    return switch (fix_type) {
        .SPEC_FIX => "Error in .vibee spec syntax",
        .GENERATOR_PATCH => "Bug in vibee compiler (needs patch)",
        .TEMPLATE_FIX => "Error in code generation template",
        .IMPORT_FIX => "Missing import statement",
        .TYPE_FIX => "Type mismatch or incorrect type",
        .SYNTAX_FIX => "Zig syntax error",
        .UNKNOWN => "Unknown error type",
    };
}

test "diagnostic: parse error line" {
    const allocator = std.testing.allocator;

    const error_line = "/path/to/file.zig:42:15: error: expected type 'T', found '[]const u8'";

    const err_info = try parse(allocator, error_line);
    defer err_info.deinit(allocator);

    try std.testing.expectEqual(@as(u32, 42), err_info.line);
    try std.testing.expectEqual(@as(u32, 15), err_info.column);
    try std.testing.expectEqualStrings("/path/to/file.zig", err_info.file);
    try std.testing.expectEqual(FixType.TYPE_FIX, err_info.fix_type);
}

test "diagnostic: undeclared identifier -> IMPORT_FIX" {
    const allocator = std.testing.allocator;

    const error_line = "/path/to/file.zig:10:5: error: use of undeclared identifier 'std'";

    const err_info = try parse(allocator, error_line);
    defer err_info.deinit(allocator);

    try std.testing.expectEqual(FixType.IMPORT_FIX, err_info.fix_type);
}

test "diagnostic: syntax error -> SYNTAX_FIX" {
    const allocator = std.testing.allocator;

    const error_line = "/path/to/file.zig:5:3: error: expected ';' after expression";

    const err_info = try parse(allocator, error_line);
    defer err_info.deinit(allocator);

    try std.testing.expectEqual(FixType.SYNTAX_FIX, err_info.fix_type);
}

test "diagnostic: .vibee error -> SPEC_FIX" {
    const allocator = std.testing.allocator;

    const error_line = "/specs/test.vibee:8:2: error: invalid YAML syntax";

    const err_info = try parse(allocator, error_line);
    defer err_info.deinit(allocator);

    try std.testing.expectEqual(FixType.SPEC_FIX, err_info.fix_type);
}

const ErrorClassificationError = error{
    UnknownError,
};
