const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    // Minimal working build - just HSLM CLI first
    const hslm_cli = b.addExecutable(.{
        .name = "hslm-cli",
        .root_source_file = b.path("src/hslm/cli.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(hslm_cli);

    const hslm_run = b.addRunArtifact(hslm_cli);
    const hslm_step = b.step("hslm", "Build and run HSLM CLI");
    hslm_step.dependOn(&hslm_run.step);
    b.default_step = hslm_step;
}
