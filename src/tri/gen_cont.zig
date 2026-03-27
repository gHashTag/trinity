//! tri/cont — Continuation-passing style (simplified)
//! Auto-generated from specs/tri/tri_cont.tri
//! TTT Dogfood v0.2 Stage 80

const std = @import("std");

/// Run continuation with value
pub fn runContSimple(comptime R: type, comptime T: type, val: T, cont: *const fn (T) R) R {
    return cont(val);
}

/// Identity continuation
pub fn identityCont(comptime T: type, val: T) T {
    return val;
}

test "runContSimple" {
    const result = runContSimple(i32, i32, 42, struct {
        fn id(x: i32) i32 {
            return x;
        }
    }.id);

    try std.testing.expectEqual(@as(i32, 42), result);
}

test "identityCont" {
    try std.testing.expectEqual(@as(i32, 99), identityCont(i32, 99));
}
