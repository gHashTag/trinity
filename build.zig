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

    // VIBEE codegen tests (rl patterns, mod dispatch, registry)
    const vibeec_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vibeec/codegen_tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_vibeec_tests = b.addRunArtifact(vibeec_tests);
    test_step.dependOn(&run_vibeec_tests.step);

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
    // IGLA Hybrid Chat module (symbolic + LLM fallback)
    const vibeec_hybrid_chat = b.createModule(.{
        .root_source_file = b.path("src/vibeec/igla_hybrid_chat.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "igla_chat", .module = vibeec_chat },
            .{ .name = "tvc_corpus", .module = tvc_corpus_mod },
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
                .{ .name = "igla_hybrid_chat", .module = vibeec_hybrid_chat },
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

    // Emergent Photon AI v0.3 - IMMERSIVE COSMIC CANVAS
    // No UI panels. No buttons. Pure emergent wave intelligence.
    // phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
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

    // Emergent Photon AI v0.4 - TRINITY COSMIC CANVAS
    // Full Trinity functionality emerges from wave interference
    // Chat/Code/Vision/Voice/Tools/Autonomous all in cosmic canvas
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
    b.installArtifact(trinity_canvas);

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
        const wasm_hybrid_chat = b.createModule(.{
            .root_source_file = b.path("src/wasm_stubs/igla_hybrid_chat_stub.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "igla_chat", .module = wasm_igla_chat },
                .{ .name = "tvc_corpus", .module = wasm_tvc_corpus },
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
            b.installArtifact(wasm_canvas);
            wasm_step.dependOn(b.getInstallStep());
        }
    }

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

    // Quark Tests — VSA Ternary Logic Proofs (Cycle 58-59)
    // Self-contained proofs: bind inverse, bundle majority, permute cycle, etc.
    const quark_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("generated/quark_tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vsa", .module = vsa_mod },
            },
        }),
    });
    const run_quark_tests = b.addRunArtifact(quark_tests);
    const quark_step = b.step("test-quark", "Test VSA Quark Proofs (18 ternary algebra proofs)");
    quark_step.dependOn(&run_quark_tests.step);
    test_step.dependOn(&run_quark_tests.step);

    // Storage Init — Basic Disk Shards + VSA Fingerprints (Cycle 59)
    const storage_init_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("generated/init.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vsa", .module = vsa_mod },
            },
        }),
    });
    const run_storage_init = b.addRunArtifact(storage_init_tests);
    const storage_init_step = b.step("test-storage-init", "Test Storage Init (disk shards + VSA fingerprints)");
    storage_init_step.dependOn(&run_storage_init.step);
    test_step.dependOn(&run_storage_init.step);

    // Generated Shard Manager — Cohesive Storage API + Manifest + Splitting (Cycle 61)
    const gen_shard_mgr_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("generated/manager.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vsa", .module = vsa_mod },
            },
        }),
    });
    const run_gen_shard_mgr = b.addRunArtifact(gen_shard_mgr_tests);
    const gen_shard_mgr_step = b.step("test-shard-manager-gen", "Test Generated Shard Manager (manifest + splitting + search)");
    gen_shard_mgr_step.dependOn(&run_gen_shard_mgr.step);
    test_step.dependOn(&run_gen_shard_mgr.step);
}
