const std = @import("std");

test "print with brackets" {
    var buffer: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const w = fbs.writer();

    // Brackets are NOT special in Zig format strings
    try w.print("[derive(Debug)]\n", .{});
    try std.testing.expectEqualSlices(u8, "[derive(Debug)]\n", fbs.getWritten());
}

test "print with braces" {
    var buffer: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const w = fbs.writer();

    // Single { is special, double {{ outputs literal {
    try w.print("{{[derive(Debug)]}}\n", .{});
    try std.testing.expectEqualSlices(u8, "{[derive(Debug)]}\n", fbs.getWritten());

    // To output [derive(Debug)] we just print it directly
    fbs.reset();
    try w.print("#[derive(Debug)]\n", .{});
    try std.testing.expectEqualSlices(u8, "#[derive(Debug)]\n", fbs.getWritten());
}
