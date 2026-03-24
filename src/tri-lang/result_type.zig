// ═══════════════════════════════════════════════════════════════════════════
// result_type.zig - Result Type for Tri Language (Gleam/Rust-style)
// ═══════════════════════════════════════════════════════════════════════════
//
// Sacred formula: V = n × 3^k × π^m × φ^p × e^q
// Golden identity: φ² + 1/φ² = 3
//
// Issue #410: Result Type + No Exceptions
//
// Implements:
// - Result<T, E> type (Ok(value) | Err(error))
// - No exceptions: errors as values
// - Exhaustive match forces error handling
// - Map, andThen, withDefault operations
//
// ═══════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// Location in source file for error reporting
pub const SourceLocation = struct {
    line: usize,
    column: usize,
};

// ═══════════════════════════════════════════════════════════════════════
// RESULT TYPE
// ═════════════════════════════════════════════════════════════════════════════════════

/// Result<T, E> - Represents success (Ok) or error (Err)
/// Errors are values, not exceptions (Gleam/Rust-style)
pub fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        /// Success value
        Ok: T,
        /// Error value
        Err: E,
    };
}

// ═══════════════════════════════════════════════════════════════════════
// COMMON ERROR TYPES
// ═════════════════════════════════════════════════════════════════════════════════════

/// NeuroError - common errors for neural operations
pub const NeuroError = enum(u8) {
    /// Invalid input data
    InvalidInput = 0,
    /// Buffer overflow
    BufferOverflow = 1,
    /// Division by zero
    DivisionByZero = 2,
    /// Type mismatch
    TypeMismatch = 3,
    /// Out of memory
    OutOfMemory = 4,
    /// Invalid state
    InvalidState = 5,
    /// Timeout
    Timeout = 6,
    /// Network error
    NetworkError = 7,
    /// Unknown error
    Unknown = 255,
};

/// ParseError - errors for parsing operations
pub const ParseError = enum(u8) {
    UnexpectedEnd = 0,
    UnexpectedToken = 1,
    InvalidSyntax = 2,
    InvalidLiteral = 3,
}

/// EpisodeError - errors for episode operations
pub const EpisodeError = enum(u8) {
    NotFound = 0,
    Corrupted = 1,
    TooOld = 2,
    InvalidFormat = 3,
};

// ═══════════════════════════════════════════════════════════════════════
// RESULT OPERATIONS
// ═════════════════════════════════════════════════════════════════════════════════════

/// Map over the Ok value, keep Err unchanged
pub fn map(comptime T: type, comptime U: type, comptime E: type, result: Result(T, E), mapper: fn (T) U) Result(U, E) {
    return switch (result) {
        .Ok => |v| .Ok { mapper(v) },
        .Err => |e| .Err { e },
    };
}

/// Map over the error value, keep Ok unchanged
pub fn mapError(comptime T: type, comptime E: type, comptime F: type, result: Result(T, E), mapper: fn (E) F) Result(T, F) {
    return switch (result) {
        .Ok => |v| .Ok { v },
        .Err => |e| .Err { mapper(e) },
    };
}

/// Chain: if Ok, apply function; if Err, keep error
pub fn andThen(comptime T: type, comptime U: type, comptime E: type, result: Result(T, E), mapper: fn (T) Result(U, E)) Result(U, E) {
    return switch (result) {
        .Ok => |v| mapper(v),
        .Err => |e| .Err { e },
    };
}

/// Get the Ok value, or default if Err
pub fn withDefault(comptime T: type, comptime E: type, result: Result(T, E), default: T) T {
    return switch (result) {
        .Ok => |v| v,
        .Err => default,
    };
}

/// Get the Ok value, or compute default from error
pub fn withDefaultLazy(comptime T: type, comptime E: type, result: Result(T, E), default_fn: fn (E) T) T {
    return switch (result) {
        .Ok => |v| v,
        .Err => |e| default_fn(e),
    };
}

/// Unwrap: get Ok value, panic on Err (use sparingly!)
pub fn unwrap(comptime T: type, comptime E: type, result: Result(T, E)) T {
    return switch (result) {
        .Ok => |v| v,
        .Err => |e| {
            std.debug.panic("unwrap called on Err: {}", .{e});
        },
    };
}

/// Unwrap or: get Ok value, or return default
pub fn unwrapOr(comptime T: type, comptime E: type, result: Result(T, E), default: T) T {
    return switch (result) {
        .Ok => |v| v,
        .Err => default,
    };
}

/// Check if result is Ok
pub fn isOk(comptime T: type, comptime E: type, result: Result(T, E)) bool {
    return switch (result) {
        .Ok => true,
        .Err => false,
    };
}

/// Check if result is Err
pub fn isErr(comptime T: type, comptime E: type, result: Result(T, E)) bool {
    return switch (result) {
        .Ok => false,
        .Err => true,
    };
}

// ═══════════════════════════════════════════════════════════════════════
// TRY MACRO (for Zig code generation)
// ═════════════════════════════════════════════════════════════════════════════════════

/// TRY macro - early return on Err
/// Usage: try result;
/// Expands to: const unwrapped = try unwrapOr(result);
pub fn tryMacro(comptime T: type, comptime E: type, result: Result(T, E)) T {
    return switch (result) {
        .Ok => |v| v,
        .Err => |e| return .Err { e },
    };
}

// ═══════════════════════════════════════════════════════════════════════
// EXAMPLE USAGE (as comments for documentation)
// ═════════════════════════════════════════════════════════════════════════════════════

// Example 1: Load episode with Result type
// In Tri:
// ```
// fn load_episode(id: tword) Result(Episode, EpisodeError) {
//     // ... implementation
// }
//
// fn process_episode(id: tword) Quality {
//     match load_episode(id) {
//         Ok(ep) => classify(ep.quality),
//         Err(.NotFound) => .Unknown,
//         Err(.Corrupted) => .Bad,
//         _ => .Unknown,
//     }
// }
// ```

// Example 2: Chain multiple operations
// ```
// fn validate_and_parse(input: []u8) Result(ParsedData, ParseError) {
//     return validate(input)
//         |> andThen(parse)
//         |> andThen(verify)
// }
// ```

// Example 3: Map error to user-friendly message
// ```
// fn load_user(id: u32) Result(User, NeuroError) {
//     return database_find(id)
//         |> mapError(|err| switch (err) {
//             .NotFound => .NotFound,
//             _ => .NetworkError,
//         })
// }
// ```

// ═══════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════

test "result_ok" {
    const result: Result(i32, NeuroError) = .{ .Ok = 42 };
    try std.testing.expectEqual(@as(i32, 42), result.Ok);
    try std.testing.expect(isOk(i32, NeuroError, result));
    try std.testing.expect(!isErr(i32, NeuroError, result));
}

test "result_err" {
    const result: Result(i32, NeuroError) = .{ .Err = .InvalidInput };
    try std.testing.expectEqual(NeuroError.InvalidInput, result.Err);
    try std.testing.expect(!isOk(i32, NeuroError, result));
    try std.testing.expect(isErr(i32, NeuroError, result));
}

test "result_map" {
    const result: Result(i32, NeuroError) = .{ .Ok = 41 };
    const mapped = map(i32, i64, NeuroError, result, struct { fn inner(x: i32) i64 { return @intCast(x); }.inner);
    try std.testing.expectEqual(@as(i64, 41), mapped.Ok);
}

test "result_map_error" {
    const result: Result(i32, NeuroError) = .{ .Err = .InvalidInput };
    const mapped = mapError(i32, NeuroError, ParseError, result, struct { fn inner(x: NeuroError) ParseError { return .UnexpectedToken; }.inner);
    try std.testing.expectEqual(ParseError.UnexpectedToken, mapped.Err);
}

test "result_and_then_ok" {
    const result: Result(i32, NeuroError) = .{ .Ok = 42 };
    const chained = andThen(i32, bool, NeuroError, result, struct { fn inner(x: i32) Result(bool, NeuroError) { return .{ .Ok = true }; }.inner);
    try std.testing.expect(chained.Ok);
}

test "result_and_then_err" {
    const result: Result(i32, NeuroError) = .{ .Err = .InvalidInput };
    const chained = andThen(i32, bool, NeuroError, result, struct { fn inner(x: i32) Result(bool, NeuroError) { return .{ .Ok = true }; }.inner);
    try std.testing.expectEqual(NeuroError.InvalidInput, chained.Err);
}

test "result_with_default" {
    const ok_result: Result(i32, NeuroError) = .{ .Ok = 42 };
    try std.testing.expectEqual(@as(i32, 42), withDefault(i32, NeuroError, ok_result, 0));

    const err_result: Result(i32, NeuroError) = .{ .Err = .InvalidInput };
    try std.testing.expectEqual(@as(i32, 0), withDefault(i32, NeuroError, err_result, 0));
}

test "result_unwrap_or" {
    const ok_result: Result(i32, NeuroError) = .{ .Ok = 42 };
    try std.testing.expectEqual(@as(i32, 42), unwrapOr(i32, NeuroError, ok_result, -1));

    const err_result: Result(i32, NeuroError) = .{ .Err = .InvalidInput };
    try std.testing.expectEqual(@as(i32, -1), unwrapOr(i32, NeuroError, err_result, -1));
}
