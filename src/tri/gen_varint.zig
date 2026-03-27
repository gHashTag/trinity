//! tri/varint — Variable-length integer encoding
//! TTT Dogfood v0.2 Stage 237

const std = @import("std");

pub fn encodeVarint(allocator: std.mem.Allocator, value: u64) ![]u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, 10);
    var v = value;

    while (v >= 0x80) {
        try result.append(allocator, @as(u8, @intCast(v & 0x7F | 0x80)));
        v >>= 7;
    }

    try result.append(allocator, @as(u8, @intCast(v)));
    return result.toOwnedSlice(allocator);
}

pub fn decodeVarint(data: []const u8) struct { value: u64, bytes: usize } {
    var value: u64 = 0;
    var shift: usize = 0;

    for (data, 0..) |byte, i| {
        value |= (@as(u64, byte & 0x7F)) << @intCast(shift);
        if ((byte & 0x80) == 0) {
            return .{ .value = value, .bytes = i + 1 };
        }
        shift += 7;
        if (shift >= 64) return .{ .value = 0, .bytes = 0 };
    }

    return .{ .value = value, .bytes = data.len };
}

test "varint encode decode" {
    const encoded = try encodeVarint(std.testing.allocator, 300);
    defer std.testing.allocator.free(encoded);
    const decoded = decodeVarint(encoded);
    try std.testing.expectEqual(@as(u64, 300), decoded.value);
}
