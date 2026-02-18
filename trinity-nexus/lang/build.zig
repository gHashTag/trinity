const std = @import("std");

// Build file for trinity-lang module (Zig 0.15.x)
// Part of Trinity Nexus modular architecture — NEXUS-008 wired
// Dependency: trinity-core

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Resolve dependencies from build.zig.zon
    const core_dep = b.dependency("trinity_core", .{
        .target = target,
        .optimize = optimize,
    });

    // Module with core dependency
    const mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "trinity-core", .module = core_dep.module("trinity_core") },
        },
    });

    // Library
    const lib = b.addLibrary(.{
        .name = "trinity-lang",
        .linkage = .static,
        .root_module = mod,
    });
    b.installArtifact(lib);

    // Tests
    const tests = b.addTest(.{ .root_module = mod });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run trinity-lang tests");
    test_step.dependOn(&run_tests.step);
}
