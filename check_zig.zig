const std = @import("std");
pub fn main() !void {
    var list = std.ArrayListUnmanaged(u32){};
    const val: u32 = list.pop();
    _ = val;
}
