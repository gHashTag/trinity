// Broken fixture, three planted faults of the three kinds the check separates:
//
//   src/gone.zig      named by build.zig and absent          -> dangling path
//   src/used.zig      imported and the alias IS used         -> LIKELY
//   src/unused.zig    imported and the alias is never used   -> LATENT
//
// The last one matters: Zig analyses top-level declarations lazily, so an
// import bound to a name nothing mentions is never loaded and is not a fault
// today. A check that called it one would be crying wolf.
const std = @import("std");
pub fn build(b: *std.Build) void {
    _ = b.addModule("fixture", .{ .root_source_file = b.path("src/root.zig") });
    _ = b.addModule("absent", .{ .root_source_file = b.path("src/gone.zig") });
}
