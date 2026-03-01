const std = @import("std");

test "print with braces" {
    var buffer: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const w = fbs.writer();

    // This should work - double braces escape to single braces
    try w.print("{{[derive(Debug)]}}\n", .{});
    try std.testing.expectEqualSlices(u8, "[derive(Debug)]\n", fbs.getWritten());
}
