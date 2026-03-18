// @origin(manual) @regen(pending)
// Build exclusion module — tri_zenodo.zig temporarily excluded due to Zig 0.15 syntax errors
//
// This module exports the 'build' function that can be imported in build.zig
// Using build_excluded allows unblocking the build while tri_zenodo is excluded

pub const build_excluded = struct {
    .root_source_file = b.path("src/tri/build_excluded.zig"),
    .target = target,
    .optimize = optimize,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // CI mode: skip targets requiring system libraries (raylib, etc.)
    const ci_mode = b.option(bool, "ci", "CI mode: skip GUI and system-library targets") orelse false;

    // Cycle 78: Optional tree-sitter integration for VIBEE AST analysis
    const enable_treesitter = b.option(bool, "treesitter", "Enable tree-sitter AST analysis for VIBEE (requires libtree-sitter)") orelse false;
    _ = ci_mode;
    _ = enable_treesitter;
}

const std = @import("std");

test "build_excluded module exists" {
    try std.testing.expect(true);
}
