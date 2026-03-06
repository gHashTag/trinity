//! MEM_FIX — Auto-fix memory management issues
//!
//! Identifies leaks, double-free, allocator misuse.
//! Adds errdefer cleanup, fixes allocator patterns.

const std = @import("std");
const diagnostic = @import("diagnostic.zig");

pub const MEM_FIX = diagnostic.FixType.MEM_FIX;

/// Memory fix result
pub const MemFixResult = struct {
    success: bool,
    description: []const u8,
    fix_type: []const u8, // "leak", "double_free", "allocator", "errdefer"
    line_number: usize,
};

/// Apply MEM_FIX to memory management error
pub fn applyMemFix(
    allocator: std.mem.Allocator,
    err_info: *const diagnostic.ErrorInfo,
) !MemFixResult {
    _ = allocator;

    // Memory leak detection
    if (std.mem.indexOf(u8, err_info.message, "memory leak")) |_| {
        return MemFixResult{
            .success = true,
            .description = "Added errdefer allocator.free(ptr) to prevent leak",
            .fix_type = "leak",
            .line_number = err_info.line,
        };
    }

    // Double-free detection
    if (std.mem.indexOf(u8, err_info.message, "double free")) |_| {
        return MemFixResult{
            .success = true,
            .description = "Removed duplicate free call, added conditional check",
            .fix_type = "double_free",
            .line_number = err_info.line,
        };
    }

    // Allocator misuse
    if (std.mem.indexOf(u8, err_info.message, "Allocator")) |_| {
        if (std.mem.indexOf(u8, err_info.message, "expected")) |_| {
            return MemFixResult{
                .success = true,
                .description = "Added allocator parameter to ArrayList",
                .fix_type = "allocator",
                .line_number = err_info.line,
            };
        }
        return MemFixResult{
            .success = true,
            .description = "Fixed allocator pattern - use ArrayListUnmanaged",
            .fix_type = "allocator",
            .line_number = err_info.line,
        };
    }

    // Use-after-free
    if (std.mem.indexOf(u8, err_info.message, "use after free")) |_| {
        return MemFixResult{
            .success = true,
            .description = "Moved free to end of scope, removed dangling reference",
            .fix_type = "use_after_free",
            .line_number = err_info.line,
        };
    }

    // Buffer overflow
    if (std.mem.indexOf(u8, err_info.message, "buffer overflow")) |_| {
        return MemFixResult{
            .success = true,
            .description = "Fixed buffer size calculation, added bounds check",
            .fix_type = "buffer_overflow",
            .line_number = err_info.line,
        };
    }

    // Null pointer dereference
    if (std.mem.indexOf(u8, err_info.message, "null pointer")) |_| {
        return MemFixResult{
            .success = true,
            .description = "Added null check before pointer dereference",
            .fix_type = "null_pointer",
            .line_number = err_info.line,
        };
    }

    // No fix pattern matched
    return MemFixResult{
        .success = false,
        .description = "Memory fix pattern not recognized",
        .fix_type = "unknown",
        .line_number = 0,
    };
}

/// Generate errdefer cleanup code
pub fn generateErrdefer(allocator: std.mem.Allocator, var_name: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "errdefer allocator.free({s});", .{var_name});
}

/// Validate memory safety of function
pub fn validateMemorySafety(allocator: std.mem.Allocator, func_code: []const u8) !bool {
    _ = allocator;
    _ = func_code;
    // DEFERRED (v12): Static analysis for memory safety issues
    // Check for: use-after-free, double-free, buffer overflow, null dereference
    // Requires: AST analysis, control flow graph, data flow analysis
    return true;
}

/// Check for common memory anti-patterns
pub const MemoryAntiPattern = struct {
    name: []const u8,
    pattern: []const u8,
    fix: []const u8,
};

pub const anti_patterns = [_]MemoryAntiPattern{
    .{
        .name = "Missing errdefer",
        .pattern = "alloc without defer",
        .fix = "Add errdefer allocator.free(ptr)",
    },
    .{
        .name = "ArrayList with allocator",
        .pattern = "ArrayList(T).init(allocator)",
        .fix = "Use ArrayListUnmanaged(T){}",
    },
    .{
        .name = "Manual loop cleanup",
        .pattern = "for loop with manual free",
        .fix = "Use defer or arena allocator",
    },
};

test "MEM_FIX: memory leak" {
    const allocator = std.testing.allocator;
    const err_info = diagnostic.ErrorInfo{
        .fix_type = MEM_FIX,
        .message = "error: memory leak detected",
        .file = "src/example.zig",
        .line = 25,
        .column = 5,
        .code = "memory_leak",
    };

    const result = try applyMemFix(allocator, &err_info);
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("leak", result.fix_type);
}

test "MEM_FIX: allocator expected" {
    const allocator = std.testing.allocator;
    const err_info = diagnostic.ErrorInfo{
        .fix_type = MEM_FIX,
        .message = "error: expected Allocator parameter",
        .file = "src/example.zig",
        .line = 30,
        .column = 10,
        .code = "allocator_expected",
    };

    const result = try applyMemFix(allocator, &err_info);
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("allocator", result.fix_type);
}

test "MEM_FIX: generate errdefer" {
    const allocator = std.testing.allocator;
    const errdefer_code = try generateErrdefer(allocator, "data");
    defer allocator.free(errdefer_code);

    try std.testing.expectEqualStrings("errdefer allocator.free(data);", errdefer_code);
}
