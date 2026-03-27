//! tri/protobuf — Protocol buffers placeholder
//! TTT Dogfood v0.2 Stage 258

const std = @import("std");

pub fn encodeProtobuf(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    _ = data;
    return allocator.alloc(u8, 0);
}

pub fn decodeProtobuf(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    _ = data;
    return allocator.alloc(u8, 0);
}

test "protobuf" {
    const encoded = try encodeProtobuf(std.testing.allocator, "test");
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(encoded.len == 0);
}
