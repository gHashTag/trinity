const std = @import("std"); pub fn main() !void { const stdout = std.fs.getStdOut().writer(); try stdout.print("hello\n", .{}); }
