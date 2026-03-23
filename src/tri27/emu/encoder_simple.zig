const std = @import("std");
const allocator = std.testing.allocator;

test "encode nop correctly" {
    const expected = @as(u32, 0x02);
    const encoded = encode_nop(0);
    try std.testing.expectEqual(expected, encoded);
}

pub fn encode_nop(rd: u5) u32 {
    return (rd << 2);
}

pub fn encode_add(rd: u5, rs1: u5, rs2: u5) u32 {
    return (rd << 5) | (rs1 << 1) | rs2;
}

pub fn encode_halt() u32 {
    return 0xFF;
}
