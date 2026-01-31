const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Library module
    const trinity_mod = b.addModule("trinity", .{
        .root_source_file = b.path("src/trinity.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Library artifact
    const lib = b.addStaticLibrary(.{
        .name = "trinity",
        .root_source_file = b.path("src/trinity.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    // Tests
    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/trinity.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    // VSA tests
    const vsa_tests = b.addTest(.{
        .root_source_file = b.path("src/vsa.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_vsa_tests = b.addRunArtifact(vsa_tests);
    test_step.dependOn(&run_vsa_tests.step);

    // VM tests
    const vm_tests = b.addTest(.{
        .root_source_file = b.path("src/vm.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_vm_tests = b.addRunArtifact(vm_tests);
    test_step.dependOn(&run_vm_tests.step);

    // Benchmark executable
    const bench = b.addExecutable(.{
        .name = "trinity-bench",
        .root_source_file = b.path("src/vsa.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    b.installArtifact(bench);

    const run_bench = b.addRunArtifact(bench);
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);

    // Examples
    const example_memory = b.addExecutable(.{
        .name = "example-memory",
        .root_source_file = b.path("examples/memory.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_memory.root_module.addImport("trinity", trinity_mod);
    b.installArtifact(example_memory);

    const example_sequence = b.addExecutable(.{
        .name = "example-sequence",
        .root_source_file = b.path("examples/sequence.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_sequence.root_module.addImport("trinity", trinity_mod);
    b.installArtifact(example_sequence);

    const example_vm = b.addExecutable(.{
        .name = "example-vm",
        .root_source_file = b.path("examples/vm.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_vm.root_module.addImport("trinity", trinity_mod);
    b.installArtifact(example_vm);

    // Run examples step
    const run_memory = b.addRunArtifact(example_memory);
    const run_sequence = b.addRunArtifact(example_sequence);
    const run_vm_example = b.addRunArtifact(example_vm);

    const examples_step = b.step("examples", "Run all examples");
    examples_step.dependOn(&run_memory.step);
    examples_step.dependOn(&run_sequence.step);
    examples_step.dependOn(&run_vm_example.step);
}
