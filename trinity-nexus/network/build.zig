const std = @import("std");

// Build file for trinity-network module (Zig 0.15.x)
// Part of Trinity Nexus modular architecture — NEXUS-008 wired
// Dependencies: trinity-core, trinity-symb

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Resolve dependencies from build.zig.zon
    const core_dep = b.dependency("trinity_core", .{
        .target = target,
        .optimize = optimize,
    });
    const symb_dep = b.dependency("trinity_symb", .{
        .target = target,
        .optimize = optimize,
    });

    // Module with dependencies
    const mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "trinity-core", .module = core_dep.module("trinity_core") },
            .{ .name = "trinity-symb", .module = symb_dep.module("trinity_symb") },
        },
    });

    // Expose named module for dependent packages (tools, canvas, etc.)
    b.modules.put(b.dupe("trinity_network"), mod) catch @panic("OOM");

    // Library
    const lib = b.addLibrary(.{
        .name = "trinity-network",
        .linkage = .static,
        .root_module = mod,
    });
    b.installArtifact(lib);

    // Tests
    const tests = b.addTest(.{ .root_module = mod });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run trinity-network tests");
    test_step.dependOn(&run_tests.step);
}
