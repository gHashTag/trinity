const std = @import("std");

// Build file for Zig 0.15.x
// For Zig 0.13.x use build.zig

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Library module for imports
    const trinity_mod = b.createModule(.{
        .root_source_file = b.path("src/trinity.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Library artifact
    const lib = b.addLibrary(.{
        .name = "trinity",
        .linkage = .static,
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

    const targets_list: []const std.Target.Query = &.{
        .{ .cpu_arch = .x86_64, .os_tag = .linux },
        .{ .cpu_arch = .x86_64, .os_tag = .macos },
        .{ .cpu_arch = .aarch64, .os_tag = .macos },
        .{ .cpu_arch = .x86_64, .os_tag = .windows },
    };

    for (targets_list) |t| {
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

    // Cross-platform Fluent CLI release builds
    const fluent_release_step = b.step("release-fluent", "Build Fluent CLI binaries for all platforms");

    for (targets_list) |t| {
        const release_target = b.resolveTargetQuery(t);
        const fluent_release_exe = b.addExecutable(.{
            .name = "fluent",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/vibeec/igla_fluent_cli.zig"),
                .target = release_target,
                .optimize = .ReleaseFast,
            }),
        });

        const fluent_target_output = b.addInstallArtifact(fluent_release_exe, .{
            .dest_dir = .{
                .override = .{
                    .custom = b.fmt("release-fluent/{s}-{s}", .{
                        @tagName(t.cpu_arch.?),
                        @tagName(t.os_tag.?),
                    }),
                },
            },
        });

        fluent_release_step.dependOn(&fluent_target_output.step);
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

    // B2T CLI
    const b2t = b.addExecutable(.{
        .name = "b2t",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/b2t/b2t_cli.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(b2t);

    const run_b2t = b.addRunArtifact(b2t);
    if (b.args) |args| {
        run_b2t.addArgs(args);
    }
    const b2t_step = b.step("b2t", "Run B2T CLI");
    b2t_step.dependOn(&run_b2t.step);

    // Claude UI Demo
    const claude_ui = b.addExecutable(.{
        .name = "claude-ui",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vibeec/claude_ui.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(claude_ui);

    const run_claude_ui = b.addRunArtifact(claude_ui);
    const claude_ui_step = b.step("claude-ui", "Run Claude UI Demo");
    claude_ui_step.dependOn(&run_claude_ui.step);

    // Trinity CLI - Interactive AI Agent
    const trinity_cli = b.addExecutable(.{
        .name = "trinity-cli",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vibeec/trinity_cli.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(trinity_cli);

    const run_trinity_cli = b.addRunArtifact(trinity_cli);
    if (b.args) |args| {
        run_trinity_cli.addArgs(args);
    }
    const trinity_cli_step = b.step("cli", "Run Trinity CLI (Interactive AI Agent)");
    trinity_cli_step.dependOn(&run_trinity_cli.step);

    // Fluent CLI - Local Chat with History Truncation (NO HANG!)
    const fluent_cli = b.addExecutable(.{
        .name = "fluent",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vibeec/igla_fluent_cli.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(fluent_cli);

    const run_fluent_cli = b.addRunArtifact(fluent_cli);
    if (b.args) |args| {
        run_fluent_cli.addArgs(args);
    }
    const fluent_cli_step = b.step("fluent", "Run Fluent CLI (Local Chat with History Truncation)");
    fluent_cli_step.dependOn(&run_fluent_cli.step);

    // VIBEE Compiler CLI
    const vibee = b.addExecutable(.{
        .name = "vibee",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vibeec/gen_cmd.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(vibee);

    const run_vibee = b.addRunArtifact(vibee);
    if (b.args) |args| {
        run_vibee.addArgs(args);
    }
    const vibee_step = b.step("vibee", "Run VIBEE Compiler CLI");
    vibee_step.dependOn(&run_vibee.step);

    // Vibeec modules for TRI
    const vibeec_swe = b.createModule(.{
        .root_source_file = b.path("src/vibeec/trinity_swe_agent.zig"),
        .target = target,
        .optimize = optimize,
    });
    const vibeec_chat = b.createModule(.{
        .root_source_file = b.path("src/vibeec/igla_local_chat.zig"),
        .target = target,
        .optimize = optimize,
    });
    const vibeec_coder = b.createModule(.{
        .root_source_file = b.path("src/vibeec/igla_local_coder.zig"),
        .target = target,
        .optimize = optimize,
    });
    // VSA module for TRI
    const vsa_tri = b.createModule(.{
        .root_source_file = b.path("src/vsa.zig"),
        .target = target,
        .optimize = optimize,
    });
    // TVC Corpus module for TRI (distributed learning)
    const tvc_corpus_mod = b.createModule(.{
        .root_source_file = b.path("src/tvc/tvc_corpus.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "vsa", .module = vsa_tri },
        },
    });
    // TVC Distributed module for TRI (file-based sharing)
    const tvc_distributed_mod = b.createModule(.{
        .root_source_file = b.path("src/tvc/tvc_distributed.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "tvc_corpus", .module = tvc_corpus_mod },
        },
    });
    // IGLA TVC Chat module (fluent chat + TVC integration)
    const igla_tvc_chat_mod = b.createModule(.{
        .root_source_file = b.path("src/vibeec/igla_tvc_chat.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "igla_chat", .module = vibeec_chat },
            .{ .name = "tvc_corpus", .module = tvc_corpus_mod },
        },
    });
    // TRI - Unified Trinity CLI
    const tri = b.addExecutable(.{
        .name = "tri",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tri/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "trinity_swe", .module = vibeec_swe },
                .{ .name = "igla_chat", .module = vibeec_chat },
                .{ .name = "igla_coder", .module = vibeec_coder },
                .{ .name = "vsa", .module = vsa_tri },
                .{ .name = "tvc_corpus", .module = tvc_corpus_mod },
                .{ .name = "tvc_distributed", .module = tvc_distributed_mod },
                .{ .name = "igla_tvc_chat", .module = igla_tvc_chat_mod },
            },
        }),
    });
    b.installArtifact(tri);

    const run_tri = b.addRunArtifact(tri);
    if (b.args) |args| {
        run_tri.addArgs(args);
    }
    const tri_step = b.step("tri", "Run TRI - Unified Trinity CLI");
    tri_step.dependOn(&run_tri.step);

    // Trinity Hybrid Local Coder (IGLA + Ollama)
    const hybrid_local = b.addExecutable(.{
        .name = "trinity-hybrid",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vibeec/trinity_hybrid_local.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    b.installArtifact(hybrid_local);

    const run_hybrid = b.addRunArtifact(hybrid_local);
    if (b.args) |args| {
        run_hybrid.addArgs(args);
    }
    const hybrid_step = b.step("hybrid", "Run Trinity Hybrid Local Coder (IGLA + Ollama)");
    hybrid_step.dependOn(&run_hybrid.step);

    // VSA module (re-exports HybridBigInt from hybrid.zig)
    const vsa_mod = b.createModule(.{
        .root_source_file = b.path("src/vsa.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Generated VSA Imported System tests (Cycle 27)
    // Uses vsa module only - hybrid types accessed via vsa.HybridBigInt
    const vsa_imported_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("generated/vsa_imported_system.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vsa", .module = vsa_mod },
            },
        }),
    });
    const run_vsa_imported = b.addRunArtifact(vsa_imported_tests);
    const vsa_imported_step = b.step("test-vsa-imported", "Test VSA Imported System (real @import)");
    vsa_imported_step.dependOn(&run_vsa_imported.step);
}
