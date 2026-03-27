//! tri/state — Pure stateful computations (simplified)
//! Auto-generated from specs/tri/tri_state.tri
//! TTT Dogfood v0.2 Stage 76

const std = @import("std");

/// State transformation S -> (S, T)
pub fn StateResult(comptime S: type, comptime T: type) type {
    return struct { state: S, value: T };
}

/// State transformation (simplified - uses comptime values)
pub fn StatePure(comptime S: type, comptime T: type, val: T) StateResult(S, T) {
    return .{ .state = undefined, .value = val };
}

test "StatePure" {
    const result = StatePure(i32, i32, 42);
    try std.testing.expectEqual(@as(i32, 42), result.value);
}

test "StateResult struct" {
    const result = StateResult(i32, i32){ .state = 10, .value = 20 };
    try std.testing.expectEqual(@as(i32, 10), result.state);
    try std.testing.expectEqual(@as(i32, 20), result.value);
}
