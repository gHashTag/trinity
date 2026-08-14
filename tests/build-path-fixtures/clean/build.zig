// Clean fixture: every path build.zig names exists, and every relative import
// resolves. Used by the self-test as the case that must report nothing.
const std = @import("std");
pub fn build(b: *std.Build) void {
    _ = b.addModule("fixture", .{ .root_source_file = b.path("src/root.zig") });
}
