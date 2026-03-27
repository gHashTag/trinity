//! tri/assertion — Custom assertions
//! TTT Dogfood v0.2 Stage 306

const std = @import("std");

pub const AssertionError = error{
    NotEqual,
    IsNull,
    Failed,
};

pub fn assertEqual(expected: i32, actual: i32) !void {
    if (expected != actual) return AssertionError.NotEqual;
}

pub fn assertNotNull(ptr: ?*anyopaque) !void {
    if (ptr == null) return AssertionError.IsNull;
}

pub fn assert(condition: bool) !void {
    if (!condition) return AssertionError.Failed;
}

test "assertions" {
    try assertEqual(42, 42);
    try assertNotNull(@ptrFromInt(1));
    try assert(true);
}
