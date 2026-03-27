const std = @import("std");
const amygdala_old = @import("/tmp/amygdala_old.zig");
const amygdala_new = @import("src/brain/amygdala.zig");

pub fn main() !void {
    const task = "security-patch-needed";
    const realm = "unknown";
    const priority = "high";

    const old = amygdala_old.Amygdala.analyzeTask(task, realm, priority);
    const new = amygdala_new.Amygdala.analyzeTask(task, realm, priority);

    std.debug.print("OLD: score={d}, level={}\n", .{ old.score, old.level });
    std.debug.print("NEW: score={d}, level={}\n", .{ new.score, new.level });
}
