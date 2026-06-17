const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get package dependencies
    const vsa_dep = b.dependency("vsa", .{
        .target = target,
        .optimize = optimize,
    });
    const hybrid_dep = b.dependency("hybrid", .{
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addStaticLibrary(.{
        .name = "vm",
        .root_source_file = b.path("src/vm.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Wire package dependencies
    lib.root_module.addImport("vsa", vsa_dep.module("vsa"));
    lib.root_module.addImport("hybrid", hybrid_dep.module("hybrid"));

    b.installArtifact(lib);
}
