// Direct memory test - bypass executor byte order issues
const std = @import("std");
const testing = std.testing;

const cpu_state = @import("cpu_state.zig");

test "raw: little endian write read" {
    const allocator = testing.allocator;
    var cpu = try cpu_state.CPUState.init(allocator);
    defer cpu.deinit();

    const mem_bytes = std.mem.sliceAsBytes(cpu.memory);

    // Test little-endian encoding: 0x4D (HALT) should be stored as DD CC BB AA
    const test_word: u32 = 0xAABBCCDD;

    mem_bytes[0] = @as(u8, @truncate(test_word)); // 0xDD
    mem_bytes[1] = @as(u8, @truncate(test_word >> 8)); // 0xCC
    mem_bytes[2] = @as(u8, @truncate(test_word >> 16)); // 0xBB
    mem_bytes[3] = @as(u8, @truncate(test_word >> 24)); // 0xAA

    // Read back
    const read_back = @as(u32, mem_bytes[0]) |
        (@as(u32, mem_bytes[1]) << 8) |
        (@as(u32, mem_bytes[2]) << 16) |
        (@as(u32, mem_bytes[3]) << 24);

    try testing.expectEqual(@as(u32, 0xAABBCCDD), read_back);

    // Check individual bytes
    try testing.expectEqual(@as(u8, 0xDD), mem_bytes[0]);
    try testing.expectEqual(@as(u8, 0xCC), mem_bytes[1]);
    try testing.expectEqual(@as(u8, 0xBB), mem_bytes[2]);
    try testing.expectEqual(@as(u8, 0xAA), mem_bytes[3]);
}

test "raw: verify Trit27 zero init" {
    const allocator = testing.allocator;
    var cpu = try cpu_state.CPUState.init(allocator);
    defer cpu.deinit();

    // All ternary registers should be zero (Trit27.trits = 0)
    for (0..27) |i| {
        try testing.expectEqual(@as(i64, 0), cpu.t27[i].trits);
    }
}
