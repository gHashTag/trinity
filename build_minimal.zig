const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/hslm/cli.zig"),
        .target = target,
        .optimize = optimize,
    });
    const hslm_cli = b.addExecutable(.{
        .name = "hslm-cli",
        .root_module = root_mod,
    });
    b.installArtifact(hslm_cli);

    const hslm_run = b.addRunArtifact(hslm_cli);
    const hslm_step = b.step("hslm", "Build and run HSLM CLI");
    hslm_step.dependOn(&hslm_run.step);
    b.default_step = hslm_step;
}
