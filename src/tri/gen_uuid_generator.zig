//! tri/uuid_generator — UUID v4 generator
//! TTT Dogfood v0.2 Stage 250

const std = @import("std");

pub fn generateV4(allocator: std.mem.Allocator) ![16]u8 {
    var uuid = try allocator.alloc(u8, 16);
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    
    for (0..16) |i| {
        uuid[i] = prng.random().byte();
    }
    
    uuid[6] = (uuid[6] & 0x0F) | 0x40;
    uuid[8] = (uuid[8] & 0x3F) | 0x80;
    
    const result: [16]u8 = uuid[0..16].*;
    allocator.free(uuid);
    return result;
}

test "uuid v4" {
    const uuid = try generateV4(std.testing.allocator);
    try std.testing.expect(uuid.len == 16);
}
