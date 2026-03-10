//! Error diagnostic and classification for AGENT MU
//!
//! Parses Zig compiler error messages and classifies them into FixType categories
//! for automatic fixing.

const std = @import("std");

/// Type of fix required for the error
pub const FixType = enum {
    /// Error in .tri spec syntax (missing colon, invalid type, etc.)
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

    // === ZIG-SPECIFIC FIX TYPES (v8.10) ===

    /// Missing or incorrect allocator parameter (std.mem.Allocator, GPA, Arena)
    ALLOCATOR_FIX,
    /// Error union or error handling issues (!T, try, catch, errdefer)
    ERROR_UNION_FIX,
    /// Comptime-related errors (@setEvalBranchQuota, comptime blocks)
    COMPTIME_FIX,
    /// VSA-specific issues (Hypervector, bind/bundle operations)
    VSA_FIX,
    /// Memory management issues (leaks, missing deinit, use-after-free)
    MEM_FIX,

    // === ZIG 0.15 SPECIFIC FIX TYPES (v8.11) ===

    /// Writergate I/O pattern issues (std.Io.Reader/Writer, peek, discard, splat)
    IOPATTERN_FIX,
    /// Comptime quota exceeded (@setEvalBranchQuota)
    COMPTIME_QUOTA_FIX,
    /// Unmanaged container issues (ArrayListUnmanaged, HashMapUnmanaged)
    UNMANAGED_FIX,
    /// Type function errors (@Type, @typeInfo)
    TYPEFUNCTION_FIX,
    /// Inline/comptime hint issues
    INLINE_FIX,
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
    const message_part = line[error_pos + error_marker.len ..];

    // Parse location: /path/to/file.zig:42:15
    var location_parts = std.mem.splitScalar(u8, location_part, ':');

    const file = location_parts.first();
    const line_str = location_parts.next() orelse "";
    const column_str = location_parts.next() orelse "";

    const line_num = std.fmt.parseInt(u32, line_str, 10) catch 0;
    const column_num = std.fmt.parseInt(u32, column_str, 10) catch 0;

    // Clean up message (trim whitespace and "error:" prefix if present)
    var message = std.mem.trim(u8, message_part, &std.ascii.whitespace);
    // Remove "error:" prefix if present (literal string, not character set)
    if (std.mem.startsWith(u8, message, "error:")) {
        message = message["error:".len..];
        message = std.mem.trim(u8, message, &std.ascii.whitespace);
    }

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

    // Check if error is in a .tri spec file
    if (std.mem.endsWith(u8, err_info.file, ".tri")) {
        err_info.fix_type = .SPEC_FIX;
        return;
    }

    // === ZIG-SPECIFIC CLASSIFIERS (v8.10) ===

    // Allocator errors
    if (std.mem.indexOf(u8, msg, "no allocator") != null or
        std.mem.indexOf(u8, msg, "std.mem.Allocator") != null or
        std.mem.indexOf(u8, msg, " GPA") != null or
        std.mem.indexOf(u8, msg, "GeneralPurposeAllocator") != null or
        std.mem.indexOf(u8, msg, "ArenaAllocator") != null or
        std.mem.indexOf(u8, msg, "allocator") != null and std.mem.indexOf(u8, msg, "parameter") != null)
    {
        err_info.fix_type = .ALLOCATOR_FIX;
        return;
    }

    // Error union issues
    if (std.mem.indexOf(u8, msg, "error union") != null or
        std.mem.indexOf(u8, msg, "expected type '!'") != null or
        std.mem.indexOf(u8, msg, "inferred error set") != null or
        std.mem.indexOf(u8, msg, "error set not declared") != null or
        std.mem.indexOf(u8, msg, "cannot assign error to") != null or
        std.mem.indexOf(u8, msg, " void cannot be error") != null)
    {
        err_info.fix_type = .ERROR_UNION_FIX;
        return;
    }

    // Comptime issues
    if (std.mem.indexOf(u8, msg, "comptime") != null or
        std.mem.indexOf(u8, msg, "@setEvalBranchQuota") != null or
        std.mem.indexOf(u8, msg, "eval exceeded") != null or
        std.mem.indexOf(u8, msg, "unable to evaluate") != null or
        std.mem.indexOf(u8, msg, "not available at comptime") != null or
        std.mem.indexOf(u8, msg, "cannot be evaluated at comptime") != null)
    {
        err_info.fix_type = .COMPTIME_FIX;
        return;
    }

    // VSA-specific
    if (std.mem.indexOf(u8, msg, "Hypervector") != null or
        std.mem.indexOf(u8, msg, "vsa.") != null or
        std.mem.indexOf(u8, msg, "trinity.") != null or
        std.mem.indexOf(u8, msg, "bind") != null or std.mem.indexOf(u8, msg, "bundle") != null or
        std.mem.indexOf(u8, msg, "Hypervector") != null or
        std.mem.indexOf(u8, msg, "VectorSymbolic") != null)
    {
        err_info.fix_type = .VSA_FIX;
        return;
    }

    // Memory management
    if (std.mem.indexOf(u8, msg, "deinit") != null or
        std.mem.indexOf(u8, msg, "memory leak") != null or
        std.mem.indexOf(u8, msg, "use after free") != null or
        std.mem.indexOf(u8, msg, "leak detected") != null or
        std.mem.indexOf(u8, msg, "invalid pointer") != null or
        std.mem.indexOf(u8, msg, "cleanup") != null or
        std.mem.indexOf(u8, msg, "defer") != null and std.mem.indexOf(u8, msg, "missing") != null)
    {
        err_info.fix_type = .MEM_FIX;
        return;
    }

    // === ZIG 0.15 SPECIFIC CLASSIFIERS (v8.11) ===

    // Writergate I/O pattern errors
    if (std.mem.indexOf(u8, msg, "Reader") != null or
        std.mem.indexOf(u8, msg, "Writer") != null or
        std.mem.indexOf(u8, msg, "std.Io") != null or
        std.mem.indexOf(u8, msg, "std.io.") != null or
        std.mem.indexOf(u8, msg, "peek") != null or
        std.mem.indexOf(u8, msg, "discard") != null or
        std.mem.indexOf(u8, msg, "splat") != null or
        std.mem.indexOf(u8, msg, "bufferedReader") != null or
        std.mem.indexOf(u8, msg, "no method 'read'") != null or
        std.mem.indexOf(u8, msg, "no method 'write'") != null)
    {
        err_info.fix_type = .IOPATTERN_FIX;
        return;
    }

    // Comptime quota exceeded (specific to @setEvalBranchQuota)
    if (std.mem.indexOf(u8, msg, "Evaluation branch quota") != null or
        std.mem.indexOf(u8, msg, "branch quota") != null or
        std.mem.indexOf(u8, msg, "@setEvalBranchQuota") != null and std.mem.indexOf(u8, msg, "exceeded") != null or
        std.mem.indexOf(u8, msg, "comptime call depth") != null or
        std.mem.indexOf(u8, msg, "too much comptime") != null)
    {
        err_info.fix_type = .COMPTIME_QUOTA_FIX;
        return;
    }

    // Unmanaged container issues
    if (std.mem.indexOf(u8, msg, "Unmanaged") != null or
        std.mem.indexOf(u8, msg, "ArrayListUnmanaged") != null or
        std.mem.indexOf(u8, msg, "HashMapUnmanaged") != null or
        std.mem.indexOf(u8, msg, "no allocator passed") != null or
        std.mem.indexOf(u8, msg, "no field 'allocator'") != null or
        std.mem.indexOf(u8, msg, "cannot pass allocator to unmanaged") != null)
    {
        err_info.fix_type = .UNMANAGED_FIX;
        return;
    }

    // Type function errors
    if (std.mem.indexOf(u8, msg, "@Type") != null or
        std.mem.indexOf(u8, msg, "@typeInfo") != null or
        std.mem.indexOf(u8, msg, "type function") != null or
        std.mem.indexOf(u8, msg, "type deduction") != null or
        std.mem.indexOf(u8, msg, "StructField") != null or
        std.mem.indexOf(u8, msg, "invalid type value") != null)
    {
        err_info.fix_type = .TYPEFUNCTION_FIX;
        return;
    }

    // Inline/comptime hint issues
    if (std.mem.indexOf(u8, msg, "inline") != null and std.mem.indexOf(u8, msg, "callconv") != null or
        std.mem.indexOf(u8, msg, "inline hint") != null or
        std.mem.indexOf(u8, msg, "cannot inline") != null or
        std.mem.indexOf(u8, msg, "alwaysinline") != null or
        std.mem.indexOf(u8, msg, "neverinline") != null)
    {
        err_info.fix_type = .INLINE_FIX;
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
        .SYNTAX_FIX => true, // Some syntax errors are fixable
        .ALLOCATOR_FIX => false, // Requires design decision (where to add allocator)
        .ERROR_UNION_FIX => false, // Requires error handling strategy
        .COMPTIME_FIX => false, // Requires architectural change
        .VSA_FIX => false, // VSA-specific, requires domain knowledge
        .MEM_FIX => false, // Manual review needed
        .SPEC_FIX => false, // Requires spec modification
        .GENERATOR_PATCH => false, // Requires generator code change
        .TEMPLATE_FIX => false, // Requires template modification
        .TYPE_FIX => false, // Usually requires design decision
        .UNKNOWN => false,
        // Zig 0.15 specific (v8.11)
        .IOPATTERN_FIX => true, // Can add Reader/Writer methods automatically
        .COMPTIME_QUOTA_FIX => true, // Can add @setEvalBranchQuota call
        .UNMANAGED_FIX => false, // Requires design decision (managed vs unmanaged)
        .TYPEFUNCTION_FIX => false, // Requires type-level design
        .INLINE_FIX => false, // Compiler hint - requires profiling
    };
}

/// Get a human-readable description of the fix type
pub fn fixTypeDescription(fix_type: FixType) []const u8 {
    return switch (fix_type) {
        .SPEC_FIX => "Error in .tri spec syntax",
        .GENERATOR_PATCH => "Bug in vibee compiler (needs patch)",
        .TEMPLATE_FIX => "Error in code generation template",
        .IMPORT_FIX => "Missing import statement",
        .TYPE_FIX => "Type mismatch or incorrect type",
        .SYNTAX_FIX => "Zig syntax error",
        .UNKNOWN => "Unknown error type",
        // Zig-specific (v8.10)
        .ALLOCATOR_FIX => "Allocator parameter missing or incorrect",
        .ERROR_UNION_FIX => "Error union or error handling issue",
        .COMPTIME_FIX => "Comptime evaluation error",
        .VSA_FIX => "VSA (Vector Symbolic Architecture) issue",
        .MEM_FIX => "Memory management issue (leak, deinit, etc.)",
        // Zig 0.15 specific (v8.11)
        .IOPATTERN_FIX => "Writergate I/O pattern issue (Reader/Writer, peek, discard, splat)",
        .COMPTIME_QUOTA_FIX => "Comptime branch quota exceeded (needs @setEvalBranchQuota)",
        .UNMANAGED_FIX => "Unmanaged container issue (ArrayListUnmanaged, HashMapUnmanaged)",
        .TYPEFUNCTION_FIX => "Type function error (@Type, @typeInfo)",
        .INLINE_FIX => "Inline/comptime hint issue",
    };
}

test "diagnostic: parse error line" {
    const allocator = std.testing.allocator;

    const error_line = "/path/to/file.zig:42:15: error: expected type 'T', found '[]const u8'";

    var err_info = try parse(allocator, error_line);
    defer err_info.deinit(allocator);

    try std.testing.expectEqual(@as(u32, 42), err_info.line);
    try std.testing.expectEqual(@as(u32, 15), err_info.column);
    try std.testing.expectEqualStrings("/path/to/file.zig", err_info.file);
    try std.testing.expectEqual(FixType.TYPE_FIX, err_info.fix_type);
}

test "diagnostic: undeclared identifier -> IMPORT_FIX" {
    const allocator = std.testing.allocator;

    const error_line = "/path/to/file.zig:10:5: error: use of undeclared identifier 'std'";

    var err_info = try parse(allocator, error_line);
    defer err_info.deinit(allocator);

    try std.testing.expectEqual(FixType.IMPORT_FIX, err_info.fix_type);
}

test "diagnostic: syntax error -> SYNTAX_FIX" {
    const allocator = std.testing.allocator;

    const error_line = "/path/to/file.zig:5:3: error: expected ';' after expression";

    var err_info = try parse(allocator, error_line);
    defer err_info.deinit(allocator);

    try std.testing.expectEqual(FixType.SYNTAX_FIX, err_info.fix_type);
}

test "diagnostic: .tri error -> SPEC_FIX" {
    const allocator = std.testing.allocator;

    const error_line = "/specs/test.tri:8:2: error: invalid YAML syntax";

    var err_info = try parse(allocator, error_line);
    defer err_info.deinit(allocator);

    try std.testing.expectEqual(FixType.SPEC_FIX, err_info.fix_type);
}

const ErrorClassificationError = error{
    UnknownError,
};
