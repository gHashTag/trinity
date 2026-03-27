//! tri/rle — Run-length encoding
//! TTT Dogfood v0.2 Stage 234

const std = @import("std");

pub const RLEPair = struct {
    value: u8,
    count: usize,
};

pub const RLEEncoder = struct {
    pub fn encode(allocator: std.mem.Allocator, data: []const u8) ![]RLEPair {
        var result = try std.ArrayList(RLEPair).initCapacity(allocator, 10);
        if (data.len == 0) return result.toOwnedSlice(allocator);

        var current: u8 = data[0];
        var count: usize = 1;

        for (data[1..]) |byte| {
            if (byte == current and count < 255) {
                count += 1;
            } else {
                try result.append(allocator, .{ .value = current, .count = count });
                current = byte;
                count = 1;
            }
        }

        try result.append(allocator, .{ .value = current, .count = count });
        return result.toOwnedSlice(allocator);
    }
};

test "rle encode" {
    const data = "AAABBBCC";
    const encoded = try RLEEncoder.encode(std.testing.allocator, data);
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqual(@as(usize, 3), encoded.len);
}
