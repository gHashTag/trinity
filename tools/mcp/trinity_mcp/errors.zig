//! MCP Error Handling Module
//!
//! Structured JSON-RPC 2.0 compliant error responses.
//! φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

/// Standard JSON-RPC 2.0 error codes
pub const ErrorCode = enum(i32) {
    // Standard JSON-RPC 2.0 errors
    parse_error = -32700,
    invalid_request = -32600,
    method_not_found = -32601,
    invalid_params = -32602,
    internal_error = -32603,

    // Trinity-specific errors (-32000 to -32099 range)
    triton_encoding_error = -32001,
    vsa_computation_error = -32002,
    timeout = -32003,
    resource_not_found = -32004,
    input_sanitization_failed = -32005,
    command_not_found = -32006,
    subprocess_error = -32007,
};

/// Error data for additional context
pub const ErrorData = struct {
    type: []const u8,
    details: []const u8,
    command: ?[]const u8 = null,
    position: ?usize = null,
};

/// Write structured JSON-RPC 2.0 error response
pub fn writeJsonError(writer: anytype, code: ErrorCode, message: []const u8) !void {
    try writer.print(
        \\{{"jsonrpc":"2.0","error":{{"code":{d},"message":"{s}"}}}}
    , .{ @intFromEnum(code), message });
}

/// Write structured JSON-RPC 2.0 error response with data
pub fn writeJsonErrorWithData(writer: anytype, code: ErrorCode, message: []const u8, data: ErrorData) !void {
    try writer.print(
        \\{{"jsonrpc":"2.0","error":{{"code":{d},"message":"{s}","data":{{"type":"{s}","details":"{s}"
    , .{ @intFromEnum(code), message, data.type, data.details });

    if (data.command) |cmd| {
        try writer.print("\\,\"command\":\"{s}", .{cmd});
    }
    if (data.position) |pos| {
        try writer.print("\\,\"position\":{d}", .{pos});
    }

    try writer.writeAll("}}}\n");
}

/// Get error message for error code
pub fn getErrorMessage(code: ErrorCode) []const u8 {
    return switch (code) {
        .parse_error => "Parse error: Invalid JSON",
        .invalid_request => "Invalid request: Malformed JSON-RPC",
        .method_not_found => "Method not found: Unknown MCP method",
        .invalid_params => "Invalid params: Parameter validation failed",
        .internal_error => "Internal error: Server error",
        .triton_encoding_error => "Triton encoding error: Invalid trit values",
        .vsa_computation_error => "VSA computation error",
        .timeout => "Timeout: Operation exceeded time limit",
        .resource_not_found => "Resource not found",
        .input_sanitization_failed => "Input sanitization failed: Dangerous pattern detected",
        .command_not_found => "Command not found",
        .subprocess_error => "Subprocess execution error",
    };
}

/// Create ErrorData from error details
pub fn createErrorData(allocator: std.mem.Allocator, error_type: []const u8, details: []const u8) !ErrorData {
    return .{
        .type = try allocator.dupe(u8, error_type),
        .details = try allocator.dupe(u8, details),
    };
}
