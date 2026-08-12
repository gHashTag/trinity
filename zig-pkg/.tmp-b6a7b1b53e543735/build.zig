const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // zig-golden-float dependency
    const zig_golden_float = b.dependency("zig_golden_float", .{
        .target = target,
        .optimize = optimize,
    });

    // Library module
    const hdc_mod = b.addModule("zig-hdc", .{
        .root_source_file = b.path("src/sequence_hdc.zig"),
    });

    // Add zig-golden-float as import
    hdc_mod.addImport("zig_golden_float", zig_golden_float.module("golden-float"));

    // Export VSA facade
    const vsa_mod = b.addModule("zig-hdc-vsa", .{
        .root_source_file = b.path("src/vsa.zig"),
    });
    vsa_mod.addImport("zig_golden_float", zig_golden_float.module("golden-float"));

    // Export sequence_hdc module
    const seq_mod = b.addModule("zig-hdc-sequence", .{
        .root_source_file = b.path("src/sequence_hdc.zig"),
    });
    seq_mod.addImport("zig_golden_float", zig_golden_float.module("golden-float"));

    // Tests
    const tests = b.addTest(.{
        .root_source_file = b.path("src/vsa.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests.root_module.addImport("zig_golden_float", zig_golden_float.module("golden-float"));
    b.installArtifact(tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
