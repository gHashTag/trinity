const std = @import("std");
const encoder = @import("./encoder_simple.zig");

test "encode nop correctly" {
    const expected = @as(u32, 0x02, 0x00, 0x00, 0x00, 0x00);
    const encoded = encoder.encode_nop(0);
    try std.testing.expectEqual(expected, encoded);
}
