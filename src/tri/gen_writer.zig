//! tri/writer — Logging output
//! Auto-generated from specs/tri/tri_writer.tri
//! TTT Dogfood v0.2 Stage 79

const std = @import("std");

/// Value paired with log
pub fn Writer(comptime W: type, comptime T: type) type {
    return struct {
        value: T,
        output: W,

        const Self = @This();

        /// Return value with empty log
        pub fn pure(val: T) Self {
            return .{
                .value = val,
                .output = std.mem.zeroes(W),
            };
        }

        /// Emit log entry
        pub fn tell(log_entry: W) Self {
            return .{
                .value = {},
                .output = log_entry,
            };
        }

        /// Map over value
        pub fn map(self: Self, comptime U: type, fn_map: *const fn (T) U) Writer(W, U) {
            return .{
                .value = fn_map(self.value),
                .output = self.output,
            };
        }

        /// Get both value and output
        pub fn run(self: Self) struct { value: T, output: W } {
            return .{ .value = self.value, .output = self.output };
        }
    };
}

test "Writer.pure" {
    const writer = Writer([]const u8, i32).pure(42);
    const result = writer.run();
    try std.testing.expectEqual(@as(i32, 42), result.value);
}

test "Writer.tell" {
    const writer = Writer([]const u8, void).tell("log entry");
    const result = writer.run();
    try std.testing.expectEqualStrings("log entry", result.output);
}

test "Writer.map" {
    const writer = Writer([]const u8, i32).pure(5);
    const mapped = writer.map(i32, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);

    try std.testing.expectEqual(@as(i32, 10), mapped.value);
}
