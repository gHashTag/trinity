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
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(lib);

    // Tests
    const main_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    // VSA tests
    const vsa_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vsa.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_vsa_tests = b.addRunArtifact(vsa_tests);
    test_step.dependOn(&run_vsa_tests.step);

    // VM tests
    const vm_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vm.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_vm_tests = b.addRunArtifact(vm_tests);
    test_step.dependOn(&run_vm_tests.step);

    // Benchmark executable
    const bench = b.addExecutable(.{
        .name = "trinity-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vsa.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    b.installArtifact(bench);

    const run_bench = b.addRunArtifact(bench);
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);

    // Examples
    const example_memory = b.addExecutable(.{
        .name = "example-memory",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/memory.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "trinity", .module = trinity_mod }},
        }),
    });
    b.installArtifact(example_memory);

    const example_sequence = b.addExecutable(.{
        .name = "example-sequence",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/sequence.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "trinity", .module = trinity_mod }},
        }),
    });
    b.installArtifact(example_sequence);

    const example_vm = b.addExecutable(.{
        .name = "example-vm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/vm.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "trinity", .module = trinity_mod }},
        }),
    });
    b.installArtifact(example_vm);

    // Run examples step
    const run_memory = b.addRunArtifact(example_memory);
    const run_sequence = b.addRunArtifact(example_sequence);
    const run_vm_example = b.addRunArtifact(example_vm);

    const examples_step = b.step("examples", "Run all examples");
    examples_step.dependOn(&run_memory.step);
    examples_step.dependOn(&run_sequence.step);
    examples_step.dependOn(&run_vm_example.step);

    // Firebird CLI
    const firebird = b.addExecutable(.{
        .name = "firebird",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/firebird/cli.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    b.installArtifact(firebird);

    const run_firebird = b.addRunArtifact(firebird);
    if (b.args) |args| {
        run_firebird.addArgs(args);
    }
    const firebird_step = b.step("firebird", "Run Firebird CLI");
    firebird_step.dependOn(&run_firebird.step);

    // Firebird tests
    const firebird_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/firebird/b2t_integration.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_firebird_tests = b.addRunArtifact(firebird_tests);
    test_step.dependOn(&run_firebird_tests.step);

    // WASM parser tests
    const wasm_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/firebird/wasm_parser.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_wasm_tests = b.addRunArtifact(wasm_tests);
    test_step.dependOn(&run_wasm_tests.step);

    // Cross-platform release builds
    const release_step = b.step("release", "Build release binaries for all platforms");

    const targets: []const std.Target.Query = &.{
        .{ .cpu_arch = .x86_64, .os_tag = .linux },
        .{ .cpu_arch = .x86_64, .os_tag = .macos },
        .{ .cpu_arch = .aarch64, .os_tag = .macos },
        .{ .cpu_arch = .x86_64, .os_tag = .windows },
    };

    for (targets) |t| {
        const release_target = b.resolveTargetQuery(t);
        const release_exe = b.addExecutable(.{
            .name = "firebird",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/firebird/cli.zig"),
                .target = release_target,
                .optimize = .ReleaseFast,
            }),
        });

        const target_output = b.addInstallArtifact(release_exe, .{
            .dest_dir = .{
                .override = .{
                    .custom = b.fmt("release/{s}-{s}", .{
                        @tagName(t.cpu_arch.?),
                        @tagName(t.os_tag.?),
                    }),
                },
            },
        });

        release_step.dependOn(&target_output.step);
    }

    // Extension WASM tests
    const extension_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/firebird/extension_wasm.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_extension_tests = b.addRunArtifact(extension_tests);
    test_step.dependOn(&run_extension_tests.step);

    // DePIN tests
    const depin_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/firebird/depin.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_depin_tests = b.addRunArtifact(depin_tests);
    test_step.dependOn(&run_depin_tests.step);
}
