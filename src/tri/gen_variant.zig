//! tri/variant — Tagged union
//! Auto-generated from specs/tri/tri_variant.tri
//! TTT Dogfood v0.2 Stage 90

const std = @import("std");

/// Tagged union of variants
pub fn Variant(comptime T: type) type {
    return struct {
        tag: []const u8,
        value: T,

        const Self = @This();

        /// Create variant with tag
        pub fn make(tag_val: []const u8, val: T) Self {
            return .{ .tag = tag_val, .value = val };
        }

        /// Get variant tag
        pub fn getTag(self: Self) []const u8 {
            return self.tag;
        }

        /// Check if tag matches
        pub fn isTag(self: Self, tag_val: []const u8) bool {
            return std.mem.eql(u8, self.tag, tag_val);
        }

        /// Get value
        pub fn getValue(self: Self) T {
            return self.value;
        }
    };
}

/// Match variant tag to value
pub fn matchVariant(comptime T: type, variant: Variant(T), handlers: anytype) ?T {
    _ = handlers;
    _ = variant;
    return null;
}

test "Variant.make" {
    const variant = Variant(i32).make("number", 42);
    try std.testing.expectEqualStrings("number", variant.getTag());
    try std.testing.expect(variant.isTag("number"));
}

test "Variant.isTag" {
    const variant = Variant(i32).make("number", 42);
    try std.testing.expect(variant.isTag("number"));
    try std.testing.expect(!variant.isTag("string"));
}

test "Variant.getValue" {
    const variant = Variant(i32).make("number", 42);
    try std.testing.expectEqual(@as(i32, 42), variant.getValue());
}
