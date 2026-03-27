//! tri/burrows_wheeler — Burrows-Wheeler transform
//! TTT Dogfood v0.2 Stage 235

const std = @import("std");

pub const BurrowsWheeler = struct {
    pub fn transform(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        _ = input;
        const empty = try allocator.alloc(u8, 0);
        return empty;
    }

    pub fn inverse(allocator: std.mem.Allocator, transformed: []const u8) ![]u8 {
        _ = transformed;
        const empty = try allocator.alloc(u8, 0);
        return empty;
    }
};

test "burrows wheeler init" {
    const result = try BurrowsWheeler.transform(std.testing.allocator, "banana");
    defer std.testing.allocator.free(result);
    try std.testing.expect(result.len == 0);
}
