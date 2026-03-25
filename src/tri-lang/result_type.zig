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
};

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
        .Ok => |v| .{ .Ok = mapper(v) },
        .Err => |e| .{ .Err = e },
    };
}

/// Map over the error value, keep Ok unchanged
pub fn mapError(comptime T: type, comptime E: type, comptime F: type, result: Result(T, E), mapper: fn (E) F) Result(T, F) {
    return switch (result) {
        .Ok => |v| .{ .Ok = v },
        .Err => |e| .{ .Err = mapper(e) },
    };
}

/// Chain: if Ok, apply function; if Err, keep error
pub fn andThen(comptime T: type, comptime U: type, comptime E: type, result: Result(T, E), mapper: fn (T) Result(U, E)) Result(U, E) {
    return switch (result) {
        .Ok => |v| mapper(v),
        .Err => |e| .{ .Err = e },
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
        .Err => |e| return .Err{e},
    };
}

// ═══════════════════════════════════════════════════════════════════════
// MATCH: Exhaustive pattern matching for Result
// ═══════════════════════════════════════════════════════════════════════

/// Match over Result with both Ok and Err handlers required
/// Usage: match(result, okHandler, errHandler)
pub fn match(comptime T: type, comptime E: type, comptime U: type, result: Result(T, E), ok_handler: fn (T) U, err_handler: fn (E) U) U {
    return switch (result) {
        .Ok => |v| ok_handler(v),
        .Err => |e| err_handler(e),
    };
}

// ═══════════════════════════════════════════════════════════════════════
// TYPE-CHECKER: Runtime exhaustive match enforcement
// ═══════════════════════════════════════════════════════════════════════

/// MatchedResult - runtime token that tracks if Result was properly matched
/// Note: True compile-time enforcement requires Tri compiler type system
pub const MatchedResult = struct {
    matched: bool,

    /// Create a new unmatched result
    pub fn init() MatchedResult {
        return MatchedResult{ .matched = false };
    }

    /// Mark this result as matched (both Ok and Err handled)
    pub fn markMatched(self: *MatchedResult) void {
        self.matched = true;
    }

    /// Verify result was matched - panics if not
    pub fn verify(self: *const MatchedResult) void {
        if (!self.matched) {
            std.debug.panic("Result was not exhaustively matched - both Ok and Err must be handled", .{});
        }
    }
};

/// mustMatch - creates a token that requires explicit matching
/// Use verify() to check match was called
///
/// Usage:
/// ```zig
/// var checked = mustMatch(i32, NeuroError, result);
/// defer checked.verify();
/// const value = match(i32, NeuroError, i32, result, okFn, errFn);
/// checked.markMatched();
/// ```
pub fn mustMatch(comptime T: type, comptime E: type, result: Result(T, E)) MatchedResult {
    _ = result;
    return MatchedResult.init();
}

/// unwrapChecked - only safe after explicit match
/// Panics if result wasn't matched first
pub fn unwrapChecked(comptime T: type, comptime E: type, result: Result(T, E), checked: *const MatchedResult) T {
    checked.verify();
    return unwrap(T, E, result);
}

// ═══════════════════════════════════════════════════════════════════════
// TRI-27 LOWERING
// ═══════════════════════════════════════════════════════════════════════

/// Lowered Result representation for TRI-27 VM
/// Ok(v) → register with flag=0
/// Err(e) → register with flag=1
pub const LoweredResult = struct {
    /// Register containing value or error code
    value: u32,
    /// Error flag: false=Ok, true=Err
    is_error: bool,
};

/// Lower Result to TRI-27 register + flag representation
/// Note: This is a simplified version that works for enums and integers
pub fn lowerToTRI27(comptime T: type, comptime E: type, result: Result(T, E)) LoweredResult {
    return switch (result) {
        .Ok => |v| .{
            .value = @as(u32, v), // Direct cast for enums/integers
            .is_error = false,
        },
        .Err => |e| .{
            .value = @as(u32, e), // Direct cast for enums/integers
            .is_error = true,
        },
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

// Helper functions for tests
fn castI32ToI64(x: i32) i64 {
    return @intCast(x);
}

fn neuroToParse(e: NeuroError) ParseError {
    _ = e;
    return .UnexpectedToken;
}

fn alwaysOk(x: i32) Result(bool, NeuroError) {
    _ = x;
    return .{ .Ok = true };
}

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
    const mapped = map(i32, i64, NeuroError, result, castI32ToI64);
    try std.testing.expectEqual(@as(i64, 41), mapped.Ok);
}

test "result_map_error" {
    const result: Result(i32, NeuroError) = .{ .Err = .InvalidInput };
    const mapped = mapError(i32, NeuroError, ParseError, result, neuroToParse);
    try std.testing.expectEqual(ParseError.UnexpectedToken, mapped.Err);
}

test "result_and_then_ok" {
    const result: Result(i32, NeuroError) = .{ .Ok = 42 };
    const chained = andThen(i32, bool, NeuroError, result, alwaysOk);
    try std.testing.expect(chained.Ok);
}

test "result_and_then_err" {
    const result: Result(i32, NeuroError) = .{ .Err = .InvalidInput };
    const chained = andThen(i32, bool, NeuroError, result, alwaysOk);
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

// Test helper functions for match
fn okHandlerAdd10(v: i32) i32 {
    return v + 10;
}

fn errHandlerZero(e: NeuroError) i32 {
    _ = e;
    return 0;
}

fn errHandlerReturnErrorCode(e: NeuroError) i32 {
    return @intFromEnum(e);
}

test "result_match_ok_branch" {
    const result: Result(i32, NeuroError) = .{ .Ok = 42 };
    const value = match(i32, NeuroError, i32, result, okHandlerAdd10, errHandlerZero);
    try std.testing.expectEqual(@as(i32, 52), value);
}

test "result_match_err_branch" {
    const result: Result(i32, NeuroError) = .{ .Err = .InvalidInput };
    const value = match(i32, NeuroError, i32, result, okHandlerAdd10, errHandlerReturnErrorCode);
    try std.testing.expectEqual(@as(i32, 0), value);
}

test "result_tri27_lowering_ok" {
    const result: Result(u8, u8) = .{ .Ok = 42 };
    const lowered = lowerToTRI27(u8, u8, result);
    try std.testing.expectEqual(@as(u32, 42), lowered.value);
    try std.testing.expect(!lowered.is_error);
}

test "result_tri27_lowering_err" {
    const result: Result(u8, u8) = .{ .Err = 1 };
    const lowered = lowerToTRI27(u8, u8, result);
    try std.testing.expectEqual(@as(u32, 1), lowered.value);
    try std.testing.expect(lowered.is_error);
}

// ═══════════════════════════════════════════════════════════════════════
// TYPE-CHECKER TESTS
// ═══════════════════════════════════════════════════════════════════════

test "mustMatch_with_proper_match" {
    const result: Result(i32, NeuroError) = .{ .Ok = 42 };

    var checked = mustMatch(i32, NeuroError, result);
    defer {
        if (!checked.matched) {
            @panic("Result was not matched");
        }
    }

    const value = match(i32, NeuroError, i32, result, okHandlerAdd10, errHandlerZero);
    checked.markMatched();

    try std.testing.expectEqual(@as(i32, 52), value);
    try std.testing.expect(checked.matched);
}

test "mustMatch_with_err_match" {
    const result: Result(i32, NeuroError) = .{ .Err = .InvalidInput };

    var checked = mustMatch(i32, NeuroError, result);
    defer {
        if (!checked.matched) {
            @panic("Result was not matched");
        }
    }

    const value = match(i32, NeuroError, i32, result, okHandlerAdd10, errHandlerReturnErrorCode);
    checked.markMatched();

    try std.testing.expectEqual(@as(i32, 0), value);
    try std.testing.expect(checked.matched);
}

test "unwrapChecked_after_match" {
    const result: Result(i32, NeuroError) = .{ .Ok = 99 };

    var checked = mustMatch(i32, NeuroError, result);
    defer checked.verify();

    // First match the result
    _ = match(i32, NeuroError, i32, result, okHandlerAdd10, errHandlerZero);
    checked.markMatched();

    // Now unwrapChecked is safe
    const unwrapped = unwrapChecked(i32, NeuroError, result, &checked);
    try std.testing.expectEqual(@as(i32, 99), unwrapped);
}

// Note: Testing panic case requires expectPanic which varies by Zig version
// In production, unwrapChecked will panic if called without matching first
