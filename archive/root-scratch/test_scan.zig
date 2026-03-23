const std = @import("std");
const amygdala = @import("src/brain/amygdala.zig");

pub fn main() !void {
    const result = amygdala.Amygdala.analyzeTask("security-patch-needed", "unknown", "high");
    std.debug.print("analyzeTask('security-patch-needed', 'unknown', 'high') = score={d}, level={}\n", .{result.score, result.level});
}
