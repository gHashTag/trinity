const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // S³AI Brain — Self-Evolving Architecture
    // ═══════════════════════════════════════════════════════════════════
    const brain_tests = b.addTest(.{
        .root_source_file = b.path("src/brain/brain.zig"),
        .name = "brain-test",
        .target = target,
        .optimize = optimize,
    });
    const run_brain_tests = b.addRunArtifact(brain_tests);
    const brain_tests_step = b.step("test-brain", "Run S³AI Brain Tests");
    brain_tests_step.dependOn(&run_brain_tests.step);
}
