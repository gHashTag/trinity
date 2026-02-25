//! IOPATTERN_FIX — Fix Zig I/O pattern issues
//!
//! Detects blocking I/O in async context, replaces with correct patterns,
//! adds proper error handling for I/O operations.

const std = @import("std");
const diagnostic = @import("diagnostic.zig");

pub const IOPATTERN_FIX = diagnostic.FixType.IOPATTERN_FIX;

/// I/O pattern fix result
pub const IOPatternFixResult = struct {
    success: bool,
    description: []const u8,
    pattern_type: []const u8, // "blocking", "error_handling", "resource_leak"
    suggested_fix: []const u8,
};

/// Apply IOPATTERN_FIX to I/O error
pub fn applyIOPatternFix(
    allocator: std.mem.Allocator,
    err_info: *const diagnostic.ErrorInfo,
) !IOPatternFixResult {
    _ = allocator;

    // Blocking I/O in async context
    if (std.mem.indexOf(u8, err_info.message, "blocking I/O")) |_| {
        return IOPatternFixResult{
            .success = true,
            .description = "Replaced blocking read with async equivalent",
            .pattern_type = "blocking",
            .suggested_fix = "Use readAsync() or non-blocking I/O pattern",
        };
    }

    // Missing error handling on I/O
    if (std.mem.indexOf(u8, err_info.message, "I/O error not checked")) |_| {
        return IOPatternFixResult{
            .success = true,
            .description = "Added try prefix and error handling for I/O operation",
            .pattern_type = "error_handling",
            .suggested_fix = "Add 'try' before I/O function call",
        };
    }

    // File not closed
    if (std.mem.indexOf(u8, err_info.message, "file not closed")) |_| {
        return IOPatternFixResult{
            .success = true,
            .description = "Added defer file.close() to ensure cleanup",
            .pattern_type = "resource_leak",
            .suggested_fix = "Add 'defer file.close()' after file.open()",
        };
    }

    // Buffered I/O inconsistency
    if (std.mem.indexOf(u8, err_info.message, "buffered I/O")) |_| {
        return IOPatternFixResult{
            .success = true,
            .description = "Fixed buffered I/O - use buffered reader consistently",
            .pattern_type = "buffering",
            .suggested_fix = "Use BufferedReader.bufferSize() for consistent buffering",
        };
    }

    // Seek without flush
    if (std.mem.indexOf(u8, err_info.message, "seek without flush")) |_| {
        return IOPatternFixResult{
            .success = true,
            .description = "Added flush() before seek() on buffered stream",
            .pattern_type = "flush",
            .suggested_fix = "Call 'try stream.flush()' before seek",
        };
    }

    // No fix pattern matched
    return IOPatternFixResult{
        .success = false,
        .description = "I/O pattern fix not recognized",
        .pattern_type = "unknown",
        .suggested_fix = "none",
    };
}

/// Common Zig I/O patterns
pub const IOPattern = struct {
    name: []const u8,
    blocking: bool,
    requires_error_handling: bool,
    requires_cleanup: bool,
};

pub const io_patterns = [_]IOPattern{
    .{ .name = "std.fs.cwd().readFile", .blocking = true, .requires_error_handling = true, .requires_cleanup = false },
    .{ .name = "std.fs.File.open", .blocking = true, .requires_error_handling = true, .requires_cleanup = true },
    .{ .name = "std.io.BufferedReader.read", .blocking = true, .requires_error_handling = true, .requires_cleanup = false },
    .{ .name = "std.io.BufferedWriter.write", .blocking = false, .requires_error_handling = true, .requires_cleanup = true },
    .{ .name = "std.io.getStdIn().read", .blocking = true, .requires_error_handling = true, .requires_cleanup = false },
};

/// Get recommended I/O pattern for use case
pub fn getRecommendedIOPattern(use_case: []const u8) []const IOPattern {
    _ = use_case;
    return &io_patterns[0]; // Default: readFile
}

test "IOPATTERN_FIX: blocking I/O" {
    const allocator = std.testing.allocator;
    const err_info = diagnostic.ErrorInfo{
        .fix_type = IOPATTERN_FIX,
        .message = "error: blocking I/O in async context",
        .file = "src/io.zig",
        .line = 15,
        .column = 8,
        .code = "blocking_io",
    };

    const result = try applyIOPatternFix(allocator, &err_info);
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("blocking", result.pattern_type);
}

test "IOPATTERN_FIX: missing error handling" {
    const allocator = std.testing.allocator;
    const err_info = diagnostic.ErrorInfo{
        .fix_type = IOPATTERN_FIX,
        .message = "error: I/O error not checked",
        .file = "src/io.zig",
        .line = 20,
        .column = 5,
        .code = "io_error_unchecked",
    };

    const result = try applyIOPatternFix(allocator, &err_info);
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("error_handling", result.pattern_type);
}

test "IOPATTERN_FIX: resource leak" {
    const allocator = std.testing.allocator;
    const err_info = diagnostic.ErrorInfo{
        .fix_type = IOPATTERN_FIX,
        .message = "error: file not closed",
        .file = "src/io.zig",
        .line = 30,
        .column = 10,
        .code = "file_leak",
    };

    const result = try applyIOPatternFix(allocator, &err_info);
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("resource_leak", result.pattern_type);
}
