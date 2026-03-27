//! tri/io — Tagged IO operations
//! Auto-generated from specs/tri/tri_io.tri
//! TTT Dogfood v0.2 Stage 77

const std = @import("std");

/// Tagged IO computation
pub fn IO(comptime T: type) type {
    return struct {
        is_performed: bool,
        value: T,

        const Self = @This();

        /// Lift pure value into IO
        pub fn pure(val: T) Self {
            return .{ .is_performed = false, .value = val };
        }

        /// Create performed IO action
        pub fn makePerformed(val: T) Self {
            return .{ .is_performed = true, .value = val };
        }

        /// Check if performed
        pub fn isPerformed(self: Self) bool {
            return self.is_performed;
        }

        /// Transform IO result
        pub fn map(self: Self, comptime U: type, fn_map: *const fn (T) U) IO(U) {
            return .{
                .is_performed = self.is_performed,
                .value = fn_map(self.value),
            };
        }

        /// Execute IO computation (mark as performed)
        pub fn perform(self: *Self) T {
            self.is_performed = true;
            return self.value;
        }

        /// Unsafe: extract value without performing
        pub fn unsafeExtract(self: Self) T {
            return self.value;
        }
    };
}

test "IO.pure" {
    const io = IO(i32).pure(42);
    try std.testing.expect(!io.isPerformed());
    try std.testing.expectEqual(@as(i32, 42), io.unsafeExtract());
}

test "IO.makePerformed" {
    const io = IO(i32).makePerformed(42);
    try std.testing.expect(io.isPerformed());
}

test "IO.map" {
    const io = IO(i32).pure(5);
    const mapped = io.map(i32, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);

    try std.testing.expectEqual(@as(i32, 10), mapped.unsafeExtract());
}

test "IO.perform" {
    var io = IO(i32).pure(42);
    try std.testing.expect(!io.isPerformed());

    const val = io.perform();
    try std.testing.expect(io.isPerformed());
    try std.testing.expectEqual(@as(i32, 42), val);
}
