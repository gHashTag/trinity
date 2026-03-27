const std = @import("std");
const amygdala = @import("src/brain/amygdala.zig");

pub fn main() !void {
    const result1 = amygdala.Amygdala.analyzeError("segfault and panic at address 0x0");
    std.debug.print("segfault+panic: score={d}, level={}\n", .{ result1.score, result1.level });

    const result2 = amygdala.Amygdala.analyzeError("panic: reached unreachable code");
    std.debug.print("panic: score={d}, level={}\n", .{ result2.score, result2.level });

    const result3 = amygdala.Amygdala.analyzeError("connection timeout after 30s");
    std.debug.print("timeout: score={d}, level={}\n", .{ result3.score, result3.level });

    const result4 = amygdala.Amygdala.analyzeError("");
    std.debug.print("empty: score={d}, level={}\n", .{ result4.score, result4.level });
}
