const std = @import("std");

test "ArrayList init" {
    const allocator = std.testing.allocator;
    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();
    try list.append('a');
}
