const std = @import("std");

// Build file for Zig 0.15.x
// For Zig 0.13.x use build.zig

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // CI mode: skip targets requiring system libraries (raylib, etc.)
    const ci_mode = b.option(bool, "ci", "CI mode: skip GUI and system-library targets") orelse false;

    // Cycle 78: Optional tree-sitter integration for VIBEE AST analysis
    const enable_treesitter = b.option(bool, "treesitter", "Enable tree-sitter AST analysis for VIBEE (requires libtree-sitter)") orelse false;

    // Library module for imports
    const trinity_mod = b.createModule(.{
        .root_source_file = b.path("src/trinity.zig"),
        .target = target,
        .optimize = optimize,
    });

    // VIBEEC compiler module — single source of truth from trinity-nexus/lang
    const trinity_lang_mod = b.createModule(.{
        .root_source_file = b.path("trinity-nexus/lang/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Generated serve module — from .tri spec: specs/integration/full-serve-v1.tri
    // Links libc because full-serve-v1.zig uses std.c.getpid() for daemonize
    const serve_full_mod = b.createModule(.{
        .root_source_file = b.path("trinity-nexus/output/lang/zig/full-serve-v1.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
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

    // ═══════════════════════════════════════════════════════════════════════════
    // libtrinity-vsa — C API shared/static library
    // ═══════════════════════════════════════════════════════════════════════════

    const c_api_mod = b.createModule(.{
        .root_source_file = b.path("src/c_api.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });

    // Shared library (.so / .dylib / .dll)
    const libvsa_shared = b.addLibrary(.{
        .name = "trinity-vsa",
        .linkage = .dynamic,
        .root_module = c_api_mod,
    });
    libvsa_shared.linkLibC();
    const install_shared = b.addInstallArtifact(libvsa_shared, .{});

    // Static library (.a / .lib)
    const libvsa_static = b.addLibrary(.{
        .name = "trinity-vsa-static",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/c_api.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    libvsa_static.linkLibC();
    const install_static = b.addInstallArtifact(libvsa_static, .{});

    // Install C header
    const install_header = b.addInstallHeaderFile(
        b.path("libs/c/libtrinityvsa/include/trinity_vsa.h"),
        "trinity_vsa.h",
    );

    // Convenience step: zig build libvsa
    const libvsa_step = b.step("libvsa", "Build libtrinity-vsa (C API shared + static + header)");
    libvsa_step.dependOn(&install_shared.step);
    libvsa_step.dependOn(&install_static.step);
    libvsa_step.dependOn(&install_header.step);

    // Cross-platform libvsa release builds
    const libvsa_release_step = b.step("release-libvsa", "Build libtrinity-vsa for all platforms");

    const libvsa_targets: []const std.Target.Query = &.{
        .{ .cpu_arch = .x86_64, .os_tag = .linux },
        .{ .cpu_arch = .aarch64, .os_tag = .linux },
        .{ .cpu_arch = .x86_64, .os_tag = .macos },
        .{ .cpu_arch = .aarch64, .os_tag = .macos },
    };

    for (libvsa_targets) |t| {
        const release_target = b.resolveTargetQuery(t);
        const release_lib = b.addLibrary(.{
            .name = "trinity-vsa",
            .linkage = .static,
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/c_api.zig"),
                .target = release_target,
                .optimize = .ReleaseFast,
                .link_libc = true,
            }),
        });

        const target_output = b.addInstallArtifact(release_lib, .{
            .dest_dir = .{
                .override = .{
                    .custom = b.fmt("release-libvsa/{s}-{s}", .{
                        @tagName(t.cpu_arch.?),
                        @tagName(t.os_tag.?),
                    }),
                },
            },
        });

        libvsa_release_step.dependOn(&target_output.step);
    }

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

    // Benchmark tests
    const bench_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("benchmarks/benchmark_test.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{.{ .name = "vsa", .module = trinity_mod }},
        }),
    });
    const run_bench_tests = b.addRunArtifact(bench_tests);
    const bench_test_step = b.step("bench-test", "Run benchmark tests");
    bench_test_step.dependOn(&run_bench_tests.step);

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

    // E2E + Benchmarks + Verdict tests (Phase 4)
    const e2e_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/e2e_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_e2e_tests = b.addRunArtifact(e2e_tests);
    test_step.dependOn(&run_e2e_tests.step);
    const e2e_step = b.step("e2e", "Run E2E tests + benchmarks + verdict");
    e2e_step.dependOn(&run_e2e_tests.step);

    // C API tests (libtrinity-vsa)
    const c_api_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/c_api.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_c_api_tests = b.addRunArtifact(c_api_tests);
    test_step.dependOn(&run_c_api_tests.step);

    // VIBEE codegen tests — use trinity-lang module as source of truth
    const vibeec_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vibeec/codegen_tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "trinity-lang", .module = trinity_lang_mod },
            },
        }),
    });
    const run_vibeec_tests = b.addRunArtifact(vibeec_tests);
    test_step.dependOn(&run_vibeec_tests.step);

    // TRI-TRACE tests (DEV-001)
    const trace_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/igla/trace.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_trace_tests = b.addRunArtifact(trace_tests);
    test_step.dependOn(&run_trace_tests.step);

    // AGENT MU v8.20 tests — Swarm collaboration, live self-modification
    const swarm_collab_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/agent_mu/swarm_collaboration.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_swarm_collab_tests = b.addRunArtifact(swarm_collab_tests);
    test_step.dependOn(&run_swarm_collab_tests.step);

    const production_hardening_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/agent_mu/production_hardening_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_production_hardening_tests = b.addRunArtifact(production_hardening_tests);
    test_step.dependOn(&run_production_hardening_tests.step);

    const production_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/agent_mu/production_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_production_tests = b.addRunArtifact(production_tests);
    test_step.dependOn(&run_production_tests.step);

    // trinity-search CLI — Semantic search over text files
    const trinity_search = b.addExecutable(.{
        .name = "trinity-search",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_search.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    b.installArtifact(trinity_search);

    const run_search = b.addRunArtifact(trinity_search);
    if (b.args) |args| {
        run_search.addArgs(args);
    }
    const search_step = b.step("search", "Run trinity-search (semantic search CLI)");
    search_step.dependOn(&run_search.step);

    // trinity-query CLI — Knowledge Graph Query (Level 11.24)
    const trinity_query = b.addExecutable(.{
        .name = "trinity-query",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/query_cli.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    b.installArtifact(trinity_query);

    const run_query = b.addRunArtifact(trinity_query);
    if (b.args) |args| {
        run_query.addArgs(args);
    }
    const query_step = b.step("query", "Run trinity-query (KG query CLI)");
    query_step.dependOn(&run_query.step);

    // Core Benchmark executable
    const bench_core = b.addExecutable(.{
        .name = "bench-core",
        .root_module = b.createModule(.{
            .root_source_file = b.path("benchmarks/bench_core.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{.{ .name = "vsa", .module = trinity_mod }},
        }),
    });
    b.installArtifact(bench_core);

    const run_bench_core = b.addRunArtifact(bench_core);
    const bench_step = b.step("bench", "Run core benchmarks");
    bench_step.dependOn(&run_bench_core.step);

    // Compression Benchmark executable
    const bench_compress = b.addExecutable(.{
        .name = "bench-compress",
        .root_module = b.createModule(.{
            .root_source_file = b.path("benchmarks/bench_compression.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    b.installArtifact(bench_compress);

    const run_bench_compress = b.addRunArtifact(bench_compress);
    const bench_compress_step = b.step("bench-compress", "Run compression benchmarks (TCV1-TCV5 vs gzip)");
    bench_compress_step.dependOn(&run_bench_compress.step);

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

    // SOTA Tech Report Demo (SYM-001)
    const sota_report = b.addExecutable(.{
        .name = "sota-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/sota_report_demo.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "trinity", .module = trinity_mod }},
        }),
    });
    b.installArtifact(sota_report);

    const run_sota = b.addRunArtifact(sota_report);
    const sota_step = b.step("sota-report", "Run SOTA Tech Report validation");
    sota_step.dependOn(&run_sota.step);

    // PAS Demo v8.20 — Before/After Comparison Demonstration
    const pas_demo = b.addExecutable(.{
        .name = "pas-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/agent_mu/pas_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(pas_demo);

    const run_pas_demo = b.addRunArtifact(pas_demo);
    const pas_demo_step = b.step("pas-demo", "Run PAS v8.20 before/after comparison demo");
    pas_demo_step.dependOn(&run_pas_demo.step);

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
        const fluent_release_chat = b.createModule(.{
            .root_source_file = b.path("src/vibeec/igla_local_chat.zig"),
            .target = release_target,
            .optimize = .ReleaseFast,
        });
        const fluent_release_exe = b.addExecutable(.{
            .name = "fluent",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/vibeec/igla_fluent_cli.zig"),
                .target = release_target,
                .optimize = .ReleaseFast,
                .imports = &.{
                    .{ .name = "igla_chat", .module = fluent_release_chat },
                },
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

    // DePIN Network tests — UDP/TCP/CRDT (Golden Chain #100)
    const depin_network_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/depin/network.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_depin_network_tests = b.addRunArtifact(depin_network_tests);
    test_step.dependOn(&run_depin_network_tests.step);

    // Unified API tests — REST+GraphQL+gRPC+WebSocket (Golden Chain #101)
    const api_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/api/unified_server.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_api_tests = b.addRunArtifact(api_tests);
    test_step.dependOn(&run_api_tests.step);

    // Trinity Node - File Encoder tests
    const file_encoder_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/file_encoder.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_file_encoder_tests = b.addRunArtifact(file_encoder_tests);
    test_step.dependOn(&run_file_encoder_tests.step);

    // Trinity Node - Protocol tests
    const protocol_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/protocol.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_protocol_tests = b.addRunArtifact(protocol_tests);
    test_step.dependOn(&run_protocol_tests.step);

    // Trinity Node - Storage tests
    const storage_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/storage.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_storage_tests = b.addRunArtifact(storage_tests);
    test_step.dependOn(&run_storage_tests.step);

    // Trinity Node - Shard Manager tests
    const shard_manager_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/shard_manager.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_shard_manager_tests = b.addRunArtifact(shard_manager_tests);
    test_step.dependOn(&run_shard_manager_tests.step);

    // Trinity Node - Storage Discovery tests
    const storage_discovery_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/storage_discovery.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_storage_discovery_tests = b.addRunArtifact(storage_discovery_tests);
    test_step.dependOn(&run_storage_discovery_tests.step);

    // Trinity Node - Remote Storage tests (v1.3)
    const remote_storage_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/remote_storage.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_remote_storage_tests = b.addRunArtifact(remote_storage_tests);
    test_step.dependOn(&run_remote_storage_tests.step);

    // Trinity Node - Crypto tests
    const crypto_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/crypto.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_crypto_tests = b.addRunArtifact(crypto_tests);
    test_step.dependOn(&run_crypto_tests.step);

    // Trinity Node - Galois Field GF(2^8) tests (v1.4)
    const galois_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/galois.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_galois_tests = b.addRunArtifact(galois_tests);
    test_step.dependOn(&run_galois_tests.step);

    // Trinity Node - Reed-Solomon erasure coding tests (v1.4)
    const reed_solomon_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/reed_solomon.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_reed_solomon_tests = b.addRunArtifact(reed_solomon_tests);
    test_step.dependOn(&run_reed_solomon_tests.step);

    // Trinity Node - Connection Pool tests (v1.4)
    const connection_pool_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/connection_pool.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_connection_pool_tests = b.addRunArtifact(connection_pool_tests);
    test_step.dependOn(&run_connection_pool_tests.step);

    // Trinity Node - Manifest DHT tests (v1.4)
    const manifest_dht_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/manifest_dht.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_manifest_dht_tests = b.addRunArtifact(manifest_dht_tests);
    test_step.dependOn(&run_manifest_dht_tests.step);

    // Trinity Node - Integration tests: 10+ node simulation (v1.4 + v1.5)
    const integration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/integration_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_integration_tests = b.addRunArtifact(integration_tests);
    test_step.dependOn(&run_integration_tests.step);

    // Trinity Node - Proof-of-Storage tests (v1.5)
    const pos_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/proof_of_storage.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_pos_tests = b.addRunArtifact(pos_tests);
    test_step.dependOn(&run_pos_tests.step);

    // Trinity Node - Shard Rebalancer tests (v1.5)
    const rebalancer_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/shard_rebalancer.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_rebalancer_tests = b.addRunArtifact(rebalancer_tests);
    test_step.dependOn(&run_rebalancer_tests.step);

    // Trinity Node - Bandwidth Aggregator tests (v1.5)
    const bw_agg_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/bandwidth_aggregator.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_bw_agg_tests = b.addRunArtifact(bw_agg_tests);
    test_step.dependOn(&run_bw_agg_tests.step);

    // Trinity Node - Shard Scrubber tests (v1.6)
    const scrubber_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/shard_scrubber.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_scrubber_tests = b.addRunArtifact(scrubber_tests);
    test_step.dependOn(&run_scrubber_tests.step);

    // Trinity Node - Node Reputation tests (v1.6)
    const reputation_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/node_reputation.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_reputation_tests = b.addRunArtifact(reputation_tests);
    test_step.dependOn(&run_reputation_tests.step);

    // Trinity Node - Graceful Shutdown tests (v1.6)
    const shutdown_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/graceful_shutdown.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_shutdown_tests = b.addRunArtifact(shutdown_tests);
    test_step.dependOn(&run_shutdown_tests.step);

    // Trinity Node - Network Stats tests (v1.6)
    const netstats_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/network_stats.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_netstats_tests = b.addRunArtifact(netstats_tests);
    test_step.dependOn(&run_netstats_tests.step);

    // Trinity Node - Auto-Repair tests (v1.7)
    const auto_repair_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/auto_repair.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_auto_repair_tests = b.addRunArtifact(auto_repair_tests);
    test_step.dependOn(&run_auto_repair_tests.step);

    // Trinity Node - Incentive Slashing tests (v1.7)
    const slashing_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/incentive_slashing.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_slashing_tests = b.addRunArtifact(slashing_tests);
    test_step.dependOn(&run_slashing_tests.step);

    // Trinity Node - Prometheus Metrics tests (v1.7)
    const prometheus_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/prometheus_metrics.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_prometheus_tests = b.addRunArtifact(prometheus_tests);
    test_step.dependOn(&run_prometheus_tests.step);

    // Trinity Node - Repair Rate Limiter tests (v1.8)
    const rate_limiter_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/repair_rate_limiter.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_rate_limiter_tests = b.addRunArtifact(rate_limiter_tests);
    test_step.dependOn(&run_rate_limiter_tests.step);

    // Trinity Node - Token Staking tests (v1.8)
    const token_staking_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/token_staking.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_token_staking_tests = b.addRunArtifact(token_staking_tests);
    test_step.dependOn(&run_token_staking_tests.step);

    // Trinity Node - Peer Latency tests (v1.8)
    const peer_latency_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/peer_latency.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_peer_latency_tests = b.addRunArtifact(peer_latency_tests);
    test_step.dependOn(&run_peer_latency_tests.step);

    // Trinity Node - RS Repair tests (v1.8)
    const rs_repair_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/rs_repair.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_rs_repair_tests = b.addRunArtifact(rs_repair_tests);
    test_step.dependOn(&run_rs_repair_tests.step);

    // Trinity Node - Metrics HTTP tests (v1.8)
    const metrics_http_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/metrics_http.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_metrics_http_tests = b.addRunArtifact(metrics_http_tests);
    test_step.dependOn(&run_metrics_http_tests.step);

    // Trinity Node - Erasure-Coded Repair tests (v1.9)
    const erasure_repair_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/erasure_repair.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_erasure_repair_tests = b.addRunArtifact(erasure_repair_tests);
    test_step.dependOn(&run_erasure_repair_tests.step);

    // Trinity Node - Reputation Consensus tests (v1.9)
    const reputation_consensus_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/reputation_consensus.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_reputation_consensus_tests = b.addRunArtifact(reputation_consensus_tests);
    test_step.dependOn(&run_reputation_consensus_tests.step);

    // Trinity Node - Stake Delegation tests (v1.9)
    const stake_delegation_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/stake_delegation.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_stake_delegation_tests = b.addRunArtifact(stake_delegation_tests);
    test_step.dependOn(&run_stake_delegation_tests.step);

    // Trinity Node - Region Topology tests (v2.0)
    const region_topology_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/region_topology.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_region_topology_tests = b.addRunArtifact(region_topology_tests);
    test_step.dependOn(&run_region_topology_tests.step);

    // Trinity Node - Slashing Escrow tests (v2.0)
    const slashing_escrow_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/slashing_escrow.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_slashing_escrow_tests = b.addRunArtifact(slashing_escrow_tests);
    test_step.dependOn(&run_slashing_escrow_tests.step);

    // Trinity Node - Prometheus HTTP Endpoint tests (v2.0)
    const prometheus_http_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/prometheus_http.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_prometheus_http_tests = b.addRunArtifact(prometheus_http_tests);
    test_step.dependOn(&run_prometheus_http_tests.step);

    // Trinity Node - VSA Shard Encoder tests (v2.0)
    const vsa_shard_encoder_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/vsa_shard_encoder.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_vsa_shard_encoder_tests = b.addRunArtifact(vsa_shard_encoder_tests);
    test_step.dependOn(&run_vsa_shard_encoder_tests.step);

    // Trinity Node - Semantic Index tests (v2.0)
    const semantic_index_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/semantic_index.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_semantic_index_tests = b.addRunArtifact(semantic_index_tests);
    test_step.dependOn(&run_semantic_index_tests.step);

    // Trinity Node - Cross-Shard Transactions tests (v2.1)
    const cross_shard_tx_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/cross_shard_tx.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_cross_shard_tx_tests = b.addRunArtifact(cross_shard_tx_tests);
    test_step.dependOn(&run_cross_shard_tx_tests.step);

    // Trinity Node - VSA Shard Locks tests (v2.1)
    const vsa_shard_locks_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/vsa_shard_locks.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_vsa_shard_locks_tests = b.addRunArtifact(vsa_shard_locks_tests);
    test_step.dependOn(&run_vsa_shard_locks_tests.step);

    // Trinity Node - Region-Aware Router tests (v2.1)
    const region_router_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/region_router.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_region_router_tests = b.addRunArtifact(region_router_tests);
    test_step.dependOn(&run_region_router_tests.step);

    // Trinity Node - Dynamic Erasure Coding tests (v2.2)
    const dynamic_erasure_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/dynamic_erasure.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_dynamic_erasure_tests = b.addRunArtifact(dynamic_erasure_tests);
    test_step.dependOn(&run_dynamic_erasure_tests.step);

    // Trinity Node - Saga Coordinator tests (v2.3)
    const saga_coordinator_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/saga_coordinator.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_saga_coordinator_tests = b.addRunArtifact(saga_coordinator_tests);
    test_step.dependOn(&run_saga_coordinator_tests.step);

    // Trinity Node - Transaction WAL tests (v2.4)
    const transaction_wal_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/transaction_wal.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_transaction_wal_tests = b.addRunArtifact(transaction_wal_tests);
    test_step.dependOn(&run_transaction_wal_tests.step);

    // Trinity Node - Parallel Saga tests (v2.5)
    const parallel_saga_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/parallel_saga.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_parallel_saga_tests = b.addRunArtifact(parallel_saga_tests);
    test_step.dependOn(&run_parallel_saga_tests.step);

    // Trinity Node - WAL Disk Persistence tests (v2.6)
    const wal_disk_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/wal_disk.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_wal_disk_tests = b.addRunArtifact(wal_disk_tests);
    test_step.dependOn(&run_wal_disk_tests.step);

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

    // Ralph CLI is in trinity-nexus/tools - run from there:
    //   cd trinity-nexus/tools && zig build ralph

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

    // Shared chat module (used by fluent CLI, hybrid chat, TRI, etc.)
    const vibeec_chat = b.createModule(.{
        .root_source_file = b.path("src/vibeec/igla_local_chat.zig"),
        .target = target,
        .optimize = optimize,
    });

    const vibeec_fluent_chat = b.createModule(.{
        .root_source_file = b.path("src/vibeec/igla_fluent_chat_engine.zig"),
        .target = target,
        .optimize = optimize,
    });

    // VSA module for TRI (moved up: needed by tvc_corpus_mod and fluent CLI)
    const vsa_tri = b.createModule(.{
        .root_source_file = b.path("src/vsa.zig"),
        .target = target,
        .optimize = optimize,
    });
    // TVC Corpus module for TRI (moved up: needed by fluent CLI and hybrid chat)
    const tvc_corpus_mod = b.createModule(.{
        .root_source_file = b.path("src/tvc/tvc_corpus.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "vsa", .module = vsa_tri },
        },
    });

    // IGLA Knowledge Graph module (self-contained VSA KG for chat routing)
    const igla_kg_mod = b.createModule(.{
        .root_source_file = b.path("src/vibeec/igla_knowledge_graph.zig"),
        .target = target,
        .optimize = optimize,
    });

    // LLM Triples Extractor module (SYM-002: pattern-based extraction) - defined early for fluent CLI
    const triples_parser_mod = b.createModule(.{
        .root_source_file = b.path("src/vibeec/triples_parser.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Fluent CLI - Local Chat with History Truncation (NO HANG!)
    const fluent_cli = b.addExecutable(.{
        .name = "fluent",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vibeec/igla_fluent_cli.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "igla_chat", .module = vibeec_chat },
                .{ .name = "tvc_corpus", .module = tvc_corpus_mod },
                .{ .name = "igla_kg", .module = igla_kg_mod },
                .{ .name = "triples_parser", .module = triples_parser_mod },
            },
        }),
    });
    b.installArtifact(fluent_cli);

    const run_fluent_cli = b.addRunArtifact(fluent_cli);
    if (b.args) |args| {
        run_fluent_cli.addArgs(args);
    }
    const fluent_cli_step = b.step("fluent", "Run Fluent CLI (Local Chat with History Truncation)");
    fluent_cli_step.dependOn(&run_fluent_cli.step);

    // VIBEE Compiler CLI — single source of truth in src/vibeec/
    // VIBEE Compiler CLI — single source of truth in src/vibeec/
    // Build options module for compile-time feature detection
    const ts_options = b.addOptions();
    ts_options.addOption(bool, "enable_treesitter", enable_treesitter);

    // AGENT MU module for post-generation verification
    const agent_mu_mod = b.createModule(.{
        .root_source_file = b.path("src/agent_mu/agent_mu.zig"),
        .target = target,
        .optimize = optimize,
    });

    const vibee = b.addExecutable(.{
        .name = "vibee",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vibeec/gen_cmd.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Cycle 78: Inject build options and optional tree-sitter modules
    vibee.root_module.addOptions("build_options", ts_options);
    vibee.root_module.addImport("agent_mu", agent_mu_mod);
    if (enable_treesitter) {
        const ts_zig_mod = b.createModule(.{
            .root_source_file = b.path("src/tvc/treesitter/zig.zig"),
            .target = target,
            .optimize = optimize,
        });
        ts_zig_mod.linkSystemLibrary("tree-sitter", .{});
        ts_zig_mod.link_libc = true;
        // Stub: tree_sitter_zig() returns NULL until real grammar is compiled
        ts_zig_mod.addCSourceFile(.{
            .file = b.path("src/tvc/treesitter/zig_lang_stub.c"),
        });
        vibee.root_module.addImport("treesitter_zig", ts_zig_mod);
        // NOTE: ast_nodes.zig not wired yet (needs Zig 0.15 ArrayList migration)
        // The treesitter_analyzer only uses zig_parser for AST traversal
    }

    b.installArtifact(vibee);

    const run_vibee = b.addRunArtifact(vibee);
    if (b.args) |args| {
        run_vibee.addArgs(args);
    }
    const vibee_step = b.step("vibee", "Run VIBEE Compiler CLI");
    vibee_step.dependOn(&run_vibee.step);

    // VIBEE Self-Improvement Engine — VIBEE improves VIBEE
    const self_improve = b.addExecutable(.{
        .name = "vibee-self-improve",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vibeec/self_improver.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(self_improve);

    const run_self_improve = b.addRunArtifact(self_improve);
    const self_improve_step = b.step("self-improve", "Run VIBEE Self-Improvement Loop");
    self_improve_step.dependOn(&run_self_improve.step);

    // ═══════════════════════════════════════════════════════════════════════════
    // TREE-SITTER MODULE (with C stub for builds without tree-sitter)
    // ═══════════════════════════════════════════════════════════════════════════
    // Used by NEEDLE matcher Tier 1 (AST-based matching)
    // The C stub (zig_lang_stub.c) makes tree_sitter_zig() return NULL,
    // so createZigParser() returns error.LanguageNotFound - safely handled
    // Created before needle_mod since needle depends on it

    const ts_zig_mod = b.createModule(.{
        .root_source_file = b.path("src/tvc/treesitter/zig.zig"),
        .target = target,
        .optimize = optimize,
    });
    ts_zig_mod.link_libc = true;
    // Add stub include path for tree_sitter/api.h when library is not installed
    ts_zig_mod.addIncludePath(b.path("src/tvc/treesitter"));
    // C stub: tree_sitter_zig() returns NULL until real grammar is compiled
    ts_zig_mod.addCSourceFile(.{
        .file = b.path("src/tvc/treesitter/zig_lang_stub.c"),
    });
    // Only link actual tree-sitter library if explicitly enabled
    if (enable_treesitter) {
        ts_zig_mod.linkSystemLibrary("tree-sitter", .{});
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // NEEDLE — Structural Editor Core (Tier 0 + Tier 1)
    // ═══════════════════════════════════════════════════════════════════════════
    // Best-in-market code editor: Aider + ast-grep + VT Code combined
    // Tier 0: Fuzzy text fallback (Aider-style layered matching)
    // Tier 1: Structural AST matching (ast-grep-like queries)
    // Tier 2: Semantic VSA search (future)

    const needle_mod = b.createModule(.{
        .root_source_file = b.path("src/needle/mod.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "treesitter_zig", .module = ts_zig_mod },
        },
    });

    const needle_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/needle/mod.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "treesitter_zig", .module = ts_zig_mod },
            },
        }),
    });

    const run_needle_tests = b.addRunArtifact(needle_tests);
    const needle_test_step = b.step("needle-test", "Run NEEDLE tests");
    needle_test_step.dependOn(&run_needle_tests.step);

    // ═══════════════════════════════════════════════════════════════════════════
    // NEEDLE-MCP — Model Context Protocol Server
    // ═══════════════════════════════════════════════════════════════════════════
    // Native Zig MCP server exposing NEEDLE as Claude Code tool

    const needle_mcp = b.addExecutable(.{
        .name = "needle-mcp",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/mcp/needle_mcp/server.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "needle", .module = needle_mod },
                .{ .name = "vsa", .module = vsa_tri },
                .{ .name = "treesitter_zig", .module = ts_zig_mod },
            },
        }),
    });
    b.installArtifact(needle_mcp);

    // Don't auto-run the MCP server - it's an interactive stdio service
    // Users run it via Claude Code mcp.json or manually
    // const run_needle_mcp = b.addRunArtifact(needle_mcp);
    // const needle_mcp_step = b.step("needle-mcp", "Run NEEDLE MCP Server (stdio transport)");
    // needle_mcp_step.dependOn(&run_needle_mcp.step);

    // ═══════════════════════════════════════════════════════════════════════════
    // TRINITY-MCP — Full Trinity MCP Server (35+ tools)
    // ═══════════════════════════════════════════════════════════════════════════
    // Native Zig MCP server exposing ALL Trinity CLI commands as Claude Code tools

    const trinity_mcp = b.addExecutable(.{
        .name = "trinity-mcp",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/mcp/trinity_mcp/server.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "needle", .module = needle_mod },
                .{ .name = "vsa", .module = vsa_tri },
                .{ .name = "treesitter_zig", .module = ts_zig_mod },
            },
        }),
    });
    b.installArtifact(trinity_mcp);

    // Don't auto-run the MCP server - it's an interactive stdio service
    // const run_trinity_mcp = b.addRunArtifact(trinity_mcp);
    // const trinity_mcp_step = b.step("trinity-mcp", "Run TRINITY MCP Server (35+ tools)");
    // trinity_mcp_step.dependOn(&run_trinity_mcp.step);

    // ═══════════════════════════════════════════════════════════════════════════
    // RALPH AGENT — Autonomous Sleep-Wake Daemon
    const ralph_agent = b.addExecutable(.{
        .name = "ralph-agent",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/mcp/trinity_mcp/agent/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(ralph_agent);

    const run_agent = b.addRunArtifact(ralph_agent);
    if (b.args) |args| run_agent.addArgs(args);
    const agent_step = b.step("agent", "Run Ralph autonomous agent daemon");
    agent_step.dependOn(&run_agent.step);

    // Ralph Hook — Tiny binary for Claude Code hooks → Telegram
    const ralph_hook = b.addExecutable(.{
        .name = "ralph-hook",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/mcp/trinity_mcp/agent/ralph_hook.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(ralph_hook);

    // Pipeline Guard — PreToolUse hook: block edits to .zig files with .tri specs
    const pipeline_guard = b.addExecutable(.{
        .name = "pipeline-guard",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/hooks/pipeline_guard.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(pipeline_guard);

    // TRI BOT — Telegram bot as Claude Code CLI remote control
    const tri_bot = b.addExecutable(.{
        .name = "tri-bot",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/mcp/trinity_mcp/bot/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(tri_bot);

    const run_tri_bot = b.addRunArtifact(tri_bot);
    if (b.args) |args| run_tri_bot.addArgs(args);
    const tri_bot_step = b.step("tri-bot", "Run TRI BOT \xe2\x80\x94 Telegram Claude Code remote control");
    tri_bot_step.dependOn(&run_tri_bot.step);

    // ═══════════════════════════════════════════════════════════════════════════
    // PHI LOOP — 999 Links of Cosmic Consciousness Gene
    const phi_loop = b.addExecutable(.{
        .name = "phi-loop",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vibeec/phi_loop_cli.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(phi_loop);

    const run_phi_loop = b.addRunArtifact(phi_loop);
    const phi_loop_step = b.step("phi-loop", "Run PHI LOOP — 999 Links of Cosmic Consciousness");
    phi_loop_step.dependOn(&run_phi_loop.step);

    // ═══════════════════════════════════════════════════════════════════════════
    // FORGE OF KOSCHEI v1.0 — Independent Ternary FPGA Toolchain
    // ═══════════════════════════════════════════════════════════════════════════

    const forge = b.addExecutable(.{
        .name = "forge",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/forge/main.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    b.installArtifact(forge);

    const run_forge = b.addRunArtifact(forge);
    if (b.args) |run_args| {
        run_forge.addArgs(run_args);
    }
    const forge_step = b.step("forge", "Run FORGE OF KOSCHEI — Independent Ternary FPGA Toolchain");
    forge_step.dependOn(&run_forge.step);

    // ═══════════════════════════════════════════════════════════════════════════
    // TERNARY QUANTUM VM — Qutrit-based Quantum Virtual Machine
    // ═══════════════════════════════════════════════════════════════════════════

    const quantum = b.addExecutable(.{
        .name = "quantum",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/quantum/main.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    b.installArtifact(quantum);

    const run_quantum = b.addRunArtifact(quantum);
    if (b.args) |run_args| {
        run_quantum.addArgs(run_args);
    }
    const quantum_step = b.step("quantum", "Run Ternary Quantum VM — Qutrit computation");
    quantum_step.dependOn(&run_quantum.step);

    // ═══════════════════════════════════════════════════════════════════════════
    // BEAL CONJECTURE SCANNER — SIMD-accelerated counterexample search
    // ═══════════════════════════════════════════════════════════════════════════

    const beal = b.addExecutable(.{
        .name = "beal",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/beal/main.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    b.installArtifact(beal);

    const run_beal = b.addRunArtifact(beal);
    if (b.args) |run_args| {
        run_beal.addArgs(run_args);
    }
    const beal_step = b.step("beal", "Run BEAL Conjecture Scanner — Find counterexamples to A^x + B^y = C^z");
    beal_step.dependOn(&run_beal.step);

    // Beal tests
    const beal_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/beal.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_beal_tests = b.addRunArtifact(beal_tests);
    test_step.dependOn(&run_beal_tests.step);

    // ═══════════════════════════════════════════════════════════════════════════
    // HSLM — Hybrid Symbolic Language Model Training CLI
    // ═══════════════════════════════════════════════════════════════════════════

    const hslm_train = b.addExecutable(.{
        .name = "hslm-train",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/hslm/cli.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    b.installArtifact(hslm_train);

    const run_hslm_train = b.addRunArtifact(hslm_train);
    if (b.args) |run_args| {
        run_hslm_train.addArgs(run_args);
    }
    const hslm_step = b.step("hslm-train", "Run HSLM — Hybrid Symbolic Language Model trainer");
    hslm_step.dependOn(&run_hslm_train.step);

    // HSLM tests
    const hslm_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/hslm/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_hslm_tests = b.addRunArtifact(hslm_tests);
    test_step.dependOn(&run_hslm_tests.step);

    // ═══════════════════════════════════════════════════════════════════════════
    // Trinity Orchestrator — REMOVED (generated.old/ deleted)
    // ═══════════════════════════════════════════════════════════════════════════

    // Meta-Evolution — REMOVED (generated.old/ deleted)
    // ═══════════════════════════════════════════════════════════════════════════

    // TMUX Golden Chain Integration — REMOVED (generated.old/ deleted)
    // ═══════════════════════════════════════════════════════════════════════════

    // V8 Production Swarm Runtime — REMOVED (generated.old/ deleted)

    // Vibeec modules for TRI
    const vibeec_swe = b.createModule(.{
        .root_source_file = b.path("src/vibeec/trinity_swe_agent.zig"),
        .target = target,
        .optimize = optimize,
    });
    const vibeec_coder = b.createModule(.{
        .root_source_file = b.path("src/vibeec/igla_local_coder.zig"),
        .target = target,
        .optimize = optimize,
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
    // IGLA Hybrid Chat module (symbolic + LLM fallback + KG)
    const vibeec_hybrid_chat = b.createModule(.{
        .root_source_file = b.path("src/vibeec/igla_hybrid_chat.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "igla_chat", .module = vibeec_chat },
            .{ .name = "tvc_corpus", .module = tvc_corpus_mod },
            .{ .name = "igla_kg", .module = igla_kg_mod },
            .{ .name = "triples_parser", .module = triples_parser_mod },
        },
    });
    // Golden Chain Agent (8-node unified pipeline)
    const golden_chain_mod = b.createModule(.{
        .root_source_file = b.path("src/vibeec/golden_chain.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "igla_hybrid_chat", .module = vibeec_hybrid_chat },
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
    // PAS Orchestrator module
    const pas_orchestrator_mod = b.createModule(.{
        .root_source_file = b.path("src/agent_mu/pas_orchestrator.zig"),
        .target = target,
        .optimize = optimize,
    });
    // Unified API Layer (Golden Chain #102)
    const api_mod = b.createModule(.{
        .root_source_file = b.path("src/api/unified_server.zig"),
        .target = target,
        .optimize = optimize,
    });
    // TRI Utils module (Cycle 100: for testing)
    const tri_colors_mod = b.createModule(.{
        .root_source_file = b.path("src/tri/tri_colors.zig"),
        .target = target,
        .optimize = optimize,
    });
    const tri_utils_mod = b.createModule(.{
        .root_source_file = b.path("src/tri/tri_utils.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "tri_colors", .module = tri_colors_mod },
        },
    });
    // TRI Commands module (Cycle 100: for testing)
    const tri_commands_mod = b.createModule(.{
        .root_source_file = b.path("src/tri/tri_commands.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "tri_colors", .module = tri_colors_mod },
            .{ .name = "serve_full", .module = serve_full_mod },
        },
    });

    // ═══════════════════════════════════════════════════════════════════════════════
    // P1.5: Registry Module — Moved here before tri (needed for P1.6 commands/mcp)
    // ═══════════════════════════════════════════════════════════════════════════════

    const registry_mod = b.createModule(.{
        .root_source_file = b.path("src/registry/mcp_gen.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "command_def", .module = trinity_mod },
        },
    });

    // TRI - Unified Trinity CLI
    // Sacred modules (v6.0)
    const sacred_const_mod = b.createModule(.{
        .root_source_file = b.path("src/sacred/const.zig"),
        .target = target,
        .optimize = optimize,
    });
    const sacred_mod = b.createModule(.{
        .root_source_file = b.path("src/sacred/sacred.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "const", .module = sacred_const_mod },
        },
    });

    // OS Boot module (Temporal Trinity v1.0 — Order #021)
    const os_mod = b.createModule(.{
        .root_source_file = b.path("src/os/boot.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sacred", .module = sacred_mod },
        },
    });

    // BSD Elliptic Curve Scanner module
    const bsd_mod = b.createModule(.{
        .root_source_file = b.path("src/bsd/scanner.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tri = b.addExecutable(.{
        .name = "tri",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tri/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "trinity_swe", .module = vibeec_swe },
                .{ .name = "igla_chat", .module = vibeec_chat },
                .{ .name = "igla_hybrid_chat", .module = vibeec_hybrid_chat },
                .{ .name = "igla_coder", .module = vibeec_coder },
                .{ .name = "vsa", .module = vsa_tri },
                .{ .name = "tvc_corpus", .module = tvc_corpus_mod },
                .{ .name = "tvc_distributed", .module = tvc_distributed_mod },
                .{ .name = "igla_tvc_chat", .module = igla_tvc_chat_mod },
                .{ .name = "pas_orchestrator", .module = pas_orchestrator_mod },
                // Unified API Layer (Golden Chain #102)
                .{ .name = "api", .module = api_mod },
                // Sacred modules (v6.0)
                .{ .name = "sacred", .module = sacred_mod },
                // Generated serve module (from .tri spec: specs/integration/full-serve-v1.tri)
                .{ .name = "serve_full", .module = serve_full_mod },
                // OS Boot module (Temporal Trinity v1.0 — Order #021)
                .{ .name = "os", .module = os_mod },
                // BSD Elliptic Curve Scanner module
                .{ .name = "bsd", .module = bsd_mod },
                // P1.6: Registry module for commands export and MCP tools
                .{ .name = "registry", .module = registry_mod },
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

    // Cycle 100: REPL Testing Infrastructure
    // Test suite for TRI CLI commands with sacred assertions
    const tri_testing = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tri/testing/repl_tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "tri_utils", .module = tri_utils_mod },
                .{ .name = "tri_commands", .module = tri_commands_mod },
                .{ .name = "trinity_swe", .module = vibeec_swe },
                .{ .name = "igla_chat", .module = vibeec_chat },
                .{ .name = "igla_hybrid_chat", .module = vibeec_hybrid_chat },
                .{ .name = "igla_coder", .module = vibeec_coder },
                .{ .name = "vsa", .module = vsa_tri },
                .{ .name = "tvc_corpus", .module = tvc_corpus_mod },
                .{ .name = "tvc_distributed", .module = tvc_distributed_mod },
                .{ .name = "igla_tvc_chat", .module = igla_tvc_chat_mod },
                .{ .name = "pas_orchestrator", .module = pas_orchestrator_mod },
                .{ .name = "api", .module = api_mod },
            },
        }),
    });
    const run_tri_testing = b.addRunArtifact(tri_testing);
    const tri_testing_step = b.step("test-repl", "Run TRI REPL Tests (Cycle 100)");
    tri_testing_step.dependOn(&run_tri_testing.step);

    // ═══════════════════════════════════════════════════════════════════════════════
    // TRI CLI Utility Modules — Unit Tests
    // ═══════════════════════════════════════════════════════════════════════════════

    // Config module tests
    const tri_config_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tri/tri_config.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_tri_config_tests = b.addRunArtifact(tri_config_tests);
    const tri_config_tests_step = b.step("test-tri-config", "Run TRI Config Tests");
    tri_config_tests_step.dependOn(&run_tri_config_tests.step);

    // History module tests
    const tri_history_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tri/tri_history.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_tri_history_tests = b.addRunArtifact(tri_history_tests);
    const tri_history_tests_step = b.step("test-tri-history", "Run TRI History Tests");
    tri_history_tests_step.dependOn(&run_tri_history_tests.step);

    // Error handling tests
    const tri_error_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tri/tri_error.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_tri_error_tests = b.addRunArtifact(tri_error_tests);
    const tri_error_tests_step = b.step("test-tri-error", "Run TRI Error Tests");
    tri_error_tests_step.dependOn(&run_tri_error_tests.step);

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

    // GGUF model module (for distributed inference)
    // Single module — gguf_model.zig internally imports gguf_inference.zig
    const gguf_model_mod = b.createModule(.{
        .root_source_file = b.path("src/vibeec/gguf_model.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Trinity Node - Decentralized Inference Network
    const trinity_node = b.addExecutable(.{
        .name = "trinity-node",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/trinity_node/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "gguf_model", .module = gguf_model_mod },
            },
        }),
    });
    b.installArtifact(trinity_node);

    const run_node = b.addRunArtifact(trinity_node);
    if (b.args) |args| {
        run_node.addArgs(args);
    }
    const node_step = b.step("node", "Run Trinity Node - Decentralized Inference");
    node_step.dependOn(&run_node.step);

    // Trinity Node GUI - with Raylib UI (requires raylib installed)
    // Install raylib: brew install raylib (macOS) / apt install libraylib-dev (Linux)
    // Skipped in CI mode (-Dci=true) since raylib is not available
    if (!ci_mode) {
        const trinity_node_gui = b.addExecutable(.{
            .name = "trinity-node-gui",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/trinity_node/main_gui.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        trinity_node_gui.linkSystemLibrary("raylib");
        trinity_node_gui.linkLibC();
        b.installArtifact(trinity_node_gui);

        const run_node_gui = b.addRunArtifact(trinity_node_gui);
        if (b.args) |args| {
            run_node_gui.addArgs(args);
        }
        const node_gui_step = b.step("node-gui", "Run Trinity Node with Raylib GUI");
        node_gui_step.dependOn(&run_node_gui.step);

        // Emergent Photon AI Demo - Interactive wave visualization
        // phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
        const photon_demo = b.addExecutable(.{
            .name = "photon-demo",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/vsa/photon_demo.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        photon_demo.linkSystemLibrary("raylib");
        photon_demo.linkLibC();
        b.installArtifact(photon_demo);

        const run_photon_demo = b.addRunArtifact(photon_demo);
        if (b.args) |args| {
            run_photon_demo.addArgs(args);
        }
        const photon_demo_step = b.step("photon-demo", "Run Emergent Photon AI Demo");
        photon_demo_step.dependOn(&run_photon_demo.step);
    } // end if (!ci_mode) — GUI targets

    // Emergent Photon AI v0.3 - IMMERSIVE COSMIC CANVAS
    // No UI panels. No buttons. Pure emergent wave intelligence.
    // phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
    // Skipped in CI mode (-Dci=true) since raylib is not available
    if (!ci_mode) {
        const photon_immersive = b.addExecutable(.{
            .name = "photon-immersive",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/vsa/photon_immersive.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        photon_immersive.linkSystemLibrary("raylib");
        photon_immersive.linkLibC();
        b.installArtifact(photon_immersive);

        const run_photon_immersive = b.addRunArtifact(photon_immersive);
        if (b.args) |args| {
            run_photon_immersive.addArgs(args);
        }
        const photon_immersive_step = b.step("photon-immersive", "Run Immersive Cosmic Canvas (v0.3)");
        photon_immersive_step.dependOn(&run_photon_immersive.step);
    }

    // Emergent Photon AI v0.4 - TRINITY COSMIC CANVAS
    // Full Trinity functionality emerges from wave interference
    // Chat/Code/Vision/Voice/Tools/Autonomous all in cosmic canvas
    // Skipped in CI mode (-Dci=true) since raylib is not available
    if (!ci_mode) {
    const trinity_canvas = b.addExecutable(.{
        .name = "trinity-canvas",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vsa/photon_trinity_canvas.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "igla_chat", .module = vibeec_chat },
                .{ .name = "igla_fluent_chat", .module = vibeec_fluent_chat },
                .{ .name = "igla_hybrid_chat", .module = vibeec_hybrid_chat },
                .{ .name = "golden_chain", .module = golden_chain_mod },
                .{ .name = "tvc_corpus", .module = tvc_corpus_mod },
                .{ .name = "auto_shard", .module = b.createModule(.{
                    .root_source_file = b.path("src/trinity_node/auto_shard.zig"),
                    .target = target,
                    .optimize = optimize,
                }) },
            },
        }),
    });
    trinity_canvas.linkSystemLibrary("raylib");
    // v8.4: Add raygui include path and C implementation
    trinity_canvas.addIncludePath(b.path("external/raygui/src"));
    trinity_canvas.addCSourceFile(.{ .file = b.path("src/vsa/raygui_impl.c") });
    // TEMP: Disable install until raygui.h is available
    // b.installArtifact(trinity_canvas);

    const run_trinity_canvas = b.addRunArtifact(trinity_canvas);
    if (b.args) |args| {
        run_trinity_canvas.addArgs(args);
    }
    const trinity_canvas_step = b.step("trinity-canvas", "Run Trinity Cosmic Canvas (v1.9 Emergent Wave)");
    trinity_canvas_step.dependOn(&run_trinity_canvas.step);

    // ═══════════════════════════════════════════════════════════════════════════
    // Trinity Canvas WASM — compiles the same canvas for browsers via Emscripten
    // Build: zig build trinity-canvas-wasm -Dtarget=wasm32-emscripten
    // Output: zig-out/web/ (trinity-canvas.html, .js, .wasm, .data)
    // ═══════════════════════════════════════════════════════════════════════════
    {
        // WASM stub modules (replace system-dependent chat/network/fs)
        const wasm_igla_chat = b.createModule(.{
            .root_source_file = b.path("src/wasm_stubs/igla_chat_stub.zig"),
            .target = target,
            .optimize = optimize,
        });
        const wasm_fluent_chat = b.createModule(.{
            .root_source_file = b.path("src/wasm_stubs/igla_fluent_chat_stub.zig"),
            .target = target,
            .optimize = optimize,
        });
        const wasm_tvc_corpus = b.createModule(.{
            .root_source_file = b.path("src/wasm_stubs/tvc_corpus_stub.zig"),
            .target = target,
            .optimize = optimize,
        });
        const wasm_auto_shard = b.createModule(.{
            .root_source_file = b.path("src/wasm_stubs/auto_shard_stub.zig"),
            .target = target,
            .optimize = optimize,
        });
        const wasm_igla_kg = b.createModule(.{
            .root_source_file = b.path("src/wasm_stubs/igla_knowledge_graph_stub.zig"),
            .target = target,
            .optimize = optimize,
        });
        const wasm_hybrid_chat = b.createModule(.{
            .root_source_file = b.path("src/wasm_stubs/igla_hybrid_chat_stub.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "igla_chat", .module = wasm_igla_chat },
                .{ .name = "tvc_corpus", .module = wasm_tvc_corpus },
                .{ .name = "igla_kg", .module = wasm_igla_kg },
                .{ .name = "triples_parser", .module = triples_parser_mod },
            },
        });
        const wasm_golden_chain = b.createModule(.{
            .root_source_file = b.path("src/wasm_stubs/golden_chain_stub.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "igla_hybrid_chat", .module = wasm_hybrid_chat },
            },
        });

        const wasm_root = b.createModule(.{
            // ONE SOURCE OF TRUTH: same file as native build, with is_emscripten gates
            .root_source_file = b.path("src/vsa/photon_trinity_canvas.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "igla_chat", .module = wasm_igla_chat },
                .{ .name = "igla_fluent_chat", .module = wasm_fluent_chat },
                .{ .name = "igla_hybrid_chat", .module = wasm_hybrid_chat },
                .{ .name = "golden_chain", .module = wasm_golden_chain },
                .{ .name = "tvc_corpus", .module = wasm_tvc_corpus },
                .{ .name = "auto_shard", .module = wasm_auto_shard },
            },
        });

        const wasm_step = b.step("trinity-canvas-wasm", "Build Trinity Canvas for Web (WASM via Emscripten)");

        if (target.query.os_tag == .emscripten) {
            // ── Emscripten WASM build (raylib-zig emsdk helpers) ──
            const raylib_zig = @import("raylib");

            // Get raylib C library compiled for emscripten
            const raylib_dep = b.dependency("raylib", .{
                .target = target,
                .optimize = optimize,
            });
            const raylib_artifact = raylib_dep.artifact("raylib");

            // Link raylib C library and add its include path for @cImport("raylib.h")
            wasm_root.linkLibrary(raylib_artifact);
            wasm_root.addIncludePath(raylib_dep.path("src"));

            const wasm = b.addLibrary(.{
                .name = "trinity-canvas",
                .root_module = wasm_root,
                .linkage = .static,
            });

            const install_dir: std.Build.InstallDir = .{ .custom = "web" };
            const emcc_flags = raylib_zig.emsdk.emccDefaultFlags(b.allocator, .{
                .optimize = optimize,
                .asyncify = true,
            });
            var emcc_settings = raylib_zig.emsdk.emccDefaultSettings(b.allocator, .{
                .optimize = optimize,
            });
            // Trinity Canvas needs ~256MB for grid + fonts + particles
            emcc_settings.put("ALLOW_MEMORY_GROWTH", "1") catch unreachable;
            emcc_settings.put("INITIAL_MEMORY", "268435456") catch unreachable; // 256MB

            const emcc_link = raylib_zig.emsdk.emccStep(b, raylib_artifact, wasm, .{
                .optimize = optimize,
                .flags = emcc_flags,
                .settings = emcc_settings,
                .shell_file_path = b.path("src/wasm_stubs/shell.html"),
                .install_dir = install_dir,
                .embed_paths = &.{.{ .src_path = b.pathFromRoot("assets/fonts"), .virtual_path = "assets/fonts" }},
            });

            wasm_step.dependOn(emcc_link);
        } else {
            // ── Native build (for compilation check without emsdk) ──
            const wasm_canvas = b.addExecutable(.{
                .name = "trinity-canvas-wasm-check",
                .root_module = wasm_root,
            });
            wasm_canvas.linkSystemLibrary("raylib");
            wasm_canvas.linkLibC();
            // TEMP: Disable install until raygui.h is available
            // b.installArtifact(wasm_canvas);
            wasm_step.dependOn(b.getInstallStep());
        }
    }
    } // end if (!ci_mode) — raylib canvas targets

    // Photon Terminal v1.0 - TERNARY EMERGENT TUI
    // Not a grid of cells — a living wave field in your terminal.
    const photon_terminal = b.addExecutable(.{
        .name = "photon-terminal",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vsa/photon_terminal.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(photon_terminal);

    const run_photon_terminal = b.addRunArtifact(photon_terminal);
    if (b.args) |args| {
        run_photon_terminal.addArgs(args);
    }
    const photon_terminal_step = b.step("photon-terminal", "Run Photon Terminal (Emergent TUI v1.0)");
    photon_terminal_step.dependOn(&run_photon_terminal.step);

    // VSA module (re-exports HybridBigInt from hybrid.zig) — REMOVED (unused after generated.old/ cleanup)

    // Quark Tests, VSA Math Proofs, Bundle Opt, Large Analogies — REMOVED (generated.old/ deleted)

    // LLM Triples Extractor (SYM-002: pattern-based triple extraction from text)
    const triples_parser_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vibeec/triples_parser.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_triples_parser = b.addRunArtifact(triples_parser_tests);
    const triples_parser_step = b.step("test-triples-parser", "Test LLM Triples Extractor (SYM-002: pattern-based extraction)");
    triples_parser_step.dependOn(&run_triples_parser.step);
    test_step.dependOn(&run_triples_parser.step);

    // KG Pipeline Integration (SYM-004: extract triples from LLM responses -> KG)
    const kg_pipeline_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vibeec/kg_pipeline.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_kg_pipeline = b.addRunArtifact(kg_pipeline_tests);
    const kg_pipeline_step = b.step("test-kg-pipeline", "Test KG Pipeline Integration (SYM-004: triples extraction -> KG)");
    kg_pipeline_step.dependOn(&run_kg_pipeline.step);
    test_step.dependOn(&run_kg_pipeline.step);

    // KG Sync DHT (SYM-003: Decentralized KG Sync + $TRI Rewards)
    const kg_sync_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vibeec/kg_sync.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_kg_sync = b.addRunArtifact(kg_sync_tests);
    const kg_sync_step = b.step("test-kg-sync", "Test KG Sync DHT (SYM-003: Kademlia DHT + $TRI rewards)");
    kg_sync_step.dependOn(&run_kg_sync.step);
    test_step.dependOn(&run_kg_sync.step);

    // SYM-005 TRI SOTA MVP Demo (Decentralized Knowledge Collector)
    const kg_sync_mod = b.createModule(.{
        .root_source_file = b.path("src/vibeec/kg_sync.zig"),
        .target = target,
        .optimize = optimize,
    });
    const sym_005_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vibeec/sym_005_demo.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "triples_parser", .module = triples_parser_mod },
                .{ .name = "kg_sync", .module = kg_sync_mod },
            },
        }),
    });
    const run_sym_005 = b.addRunArtifact(sym_005_tests);
    const sym_005_step = b.step("test-sym-005", "Test SYM-005 TRI SOTA MVP (full symbolic pipeline)");
    sym_005_step.dependOn(&run_sym_005.step);
    test_step.dependOn(&run_sym_005.step);

    // OPT-PC01 Prefix Caching Completion (Phase 3-5)
    const kv_cache_mod = b.createModule(.{
        .root_source_file = b.path("src/vibeec/kv_cache.zig"),
        .target = target,
        .optimize = optimize,
    });
    const prefix_cache_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vibeec/prefix_cache_completion.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kv_cache", .module = kv_cache_mod },
            },
        }),
    });
    const run_prefix_cache = b.addRunArtifact(prefix_cache_tests);
    const prefix_cache_step = b.step("test-prefix-cache", "Test OPT-PC01 Prefix Caching (Phase 3-5 completion)");
    prefix_cache_step.dependOn(&run_prefix_cache.step);
    test_step.dependOn(&run_prefix_cache.step);

    // VSA Math Benchmark executable (MATH-003) — REMOVED (generated.old/ deleted)

    // Storage Init tests — REMOVED (generated.old/ deleted)

    // Generated Shard Manager tests — REMOVED (generated.old/ deleted)

    // ShardManager API tests — REMOVED (generated.old/ deleted)

    // Network transfer tests — REMOVED (generated.old/ deleted)

    // Erasure coding tests — REMOVED (generated.old/ deleted)

    // Pipeline tests — REMOVED (generated.old/ deleted)

    // Network pipeline tests — REMOVED (generated.old/ deleted)

    // Discovery tests — REMOVED (generated.old/ deleted)

    // Proof-of-Storage tests — REMOVED (generated.old/ deleted)

    // Kademlia DHT tests — REMOVED (generated.old/ deleted)

    // Live Swarm tests — REMOVED (generated.old/ deleted)

    // Live Rewards tests — REMOVED (generated.old/ deleted)

    // Swarm Watch tests — REMOVED (generated.old/ deleted)

    // Ternary KV Cache tests — REMOVED (generated.old/ deleted)

    // Ternary MatMul tests — REMOVED (generated.old/ deleted)

    // Paged Attention tests — REMOVED (generated.old/ deleted)

    // Continuous Batching tests — REMOVED (generated.old/ deleted)

    // Speculative Decoding tests — REMOVED (generated.old/ deleted)

    // GGUF Parser tests — REMOVED (generated.old/ deleted)

    // Transformer Forward Pass tests — REMOVED (generated.old/ deleted)

    // Hardware Abstraction tests — REMOVED (generated.old/ deleted)

    // JIT Compilation tests — REMOVED (generated.old/ deleted)

    // FPGA Acceleration tests — REMOVED (generated.old/ deleted)

    // ═══════════════════════════════════════════════════════════════════════════════
    // P1.5: Registry Export — Generate registry.json from CommandDef
    // ═══════════════════════════════════════════════════════════════════════════════


    const registry_export_exe = b.addExecutable(.{
        .name = "export-registry",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/registry/export_cli.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "mcp_gen", .module = registry_mod },
                .{ .name = "trinity", .module = trinity_mod },
            },
        }),
    });

    const run_registry_export = b.addRunArtifact(registry_export_exe);
    run_registry_export.addArg(".trinity/registry.json");

    const registry_step = b.step("export-registry", "Export command registry to .trinity/registry.json");
    registry_step.dependOn(&run_registry_export.step);

    // Also run as part of build step
    // b.getInstallStep().dependOn(&run_registry_export.step);

    // ═══════════════════════════════════════════════════════════════════════════════
    // TRI-API — Direct Anthropic API Agent (Issue #60)
    // ═══════════════════════════════════════════════════════════════════════════════

    const tri_api = b.addExecutable(.{
        .name = "tri-api",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tri-api/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(tri_api);
    const run_tri_api = b.addRunArtifact(tri_api);
    if (b.args) |args| run_tri_api.addArgs(args);
    const tri_api_step = b.step("tri-api", "Run TRI-API — Direct Anthropic API Agent");
    tri_api_step.dependOn(&run_tri_api.step);

}
