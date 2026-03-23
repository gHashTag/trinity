const std = @import("std");
const amygdala_opt = @import("src/brain/amygdala_opt.zig");

pub fn main() !void {
    const result = amygdala_opt.Amygdala.analyzeError("segfault in critical module");
    std.debug.print("score: {d}, level: {any}\n", .{ result.score, result.level });
    std.debug.print("requiresAttention: {}\n", .{ amygdala_opt.Amygdala.requiresAttention(result) });
}
