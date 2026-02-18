const std = @import("std");

// Build file for trinity-core module (Zig 0.15.x)
// Part of Trinity Nexus modular architecture — NEXUS-008 wired

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Module (no dependencies — foundation)
    const mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Library
    const lib = b.addLibrary(.{
        .name = "trinity-core",
        .linkage = .static,
        .root_module = mod,
    });
    b.installArtifact(lib);

    // Tests
    const tests = b.addTest(.{ .root_module = mod });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run trinity-core tests");
    test_step.dependOn(&run_tests.step);
}
