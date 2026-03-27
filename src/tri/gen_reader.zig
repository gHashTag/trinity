//! tri/reader — Environment reading (simplified)
//! Auto-generated from specs/tri/tri_reader.tri
//! TTT Dogfood v0.2 Stage 78

const std = @import("std");

/// Reader result - just return the value
pub fn ReaderPure(comptime R: type, comptime T: type, val: T, env: R) T {
    _ = env;
    return val;
}

/// Get the environment
pub fn ReaderAsk(comptime R: type, env: R) R {
    return env;
}

test "ReaderPure" {
    const result = ReaderPure(i32, i32, 42, 999);
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "ReaderAsk" {
    const result = ReaderAsk(i32, 123);
    try std.testing.expectEqual(@as(i32, 123), result);
}
