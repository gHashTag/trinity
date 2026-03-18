const std = @import("std");
test "ArrayList init" {
    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();
    try list.append('a');
    try std.testing.expectEqual(@as(usize, 1), list.items.len);
}
