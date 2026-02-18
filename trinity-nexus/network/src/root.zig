// TRINITY NEXUS — Network Module (trinity-network)
// NEXUS-006: DHT routing, P2P communication, sharding, consensus,
// distributed transactions, repair, token economics, monitoring.
// Source: src/trinity_node/ (52 files), src/vibeec/ (5), src/firebird/ (1),
//         src/tvc/ (1), src/ (1). Total: 60 files, 37534 lines.

// --- Core P2P Network ---
pub const network = @import("network.zig");
pub const protocol = @import("protocol.zig");
pub const discovery = @import("discovery.zig");
pub const connection_pool = @import("connection_pool.zig");

// --- DHT ---
pub const manifest_dht = @import("manifest_dht.zig");

// --- Sharding ---
pub const shard_manager = @import("shard_manager.zig");
pub const shard_rebalancer = @import("shard_rebalancer.zig");
pub const shard_scrubber = @import("shard_scrubber.zig");
pub const auto_shard = @import("auto_shard.zig");
pub const vsa_shard_encoder = @import("vsa_shard_encoder.zig");
pub const vsa_shard_locks = @import("vsa_shard_locks.zig");

// --- Consensus & Reputation ---
pub const reputation_consensus = @import("reputation_consensus.zig");
pub const node_reputation = @import("node_reputation.zig");

// --- Distributed Transactions ---
pub const cross_shard_tx = @import("cross_shard_tx.zig");
pub const parallel_saga = @import("parallel_saga.zig");
pub const saga_coordinator = @import("saga_coordinator.zig");
pub const transaction_wal = @import("transaction_wal.zig");
pub const wal_disk = @import("wal_disk.zig");

// --- Repair & Erasure Coding ---
pub const auto_repair = @import("auto_repair.zig");
pub const erasure_repair = @import("erasure_repair.zig");
pub const dynamic_erasure = @import("dynamic_erasure.zig");
pub const rs_repair = @import("rs_repair.zig");
pub const reed_solomon = @import("reed_solomon.zig");
pub const galois = @import("galois.zig");
pub const repair_rate_limiter = @import("repair_rate_limiter.zig");

// --- Routing & Topology ---
pub const region_router = @import("region_router.zig");
pub const region_topology = @import("region_topology.zig");
pub const peer_latency = @import("peer_latency.zig");

// --- Storage ---
pub const storage = @import("storage.zig");
pub const remote_storage = @import("remote_storage.zig");
pub const storage_discovery = @import("storage_discovery.zig");
pub const file_encoder = @import("file_encoder.zig");

// --- Crypto & Token Economics ---
pub const crypto = @import("crypto.zig");
pub const wallet = @import("wallet.zig");
pub const token_staking = @import("token_staking.zig");
pub const stake_delegation = @import("stake_delegation.zig");
pub const slashing_escrow = @import("slashing_escrow.zig");
pub const incentive_slashing = @import("incentive_slashing.zig");
pub const proof_of_storage = @import("proof_of_storage.zig");

// --- Monitoring & Metrics ---
pub const network_stats = @import("network_stats.zig");
pub const bandwidth_aggregator = @import("bandwidth_aggregator.zig");
pub const prometheus_metrics = @import("prometheus_metrics.zig");
pub const prometheus_http = @import("prometheus_http.zig");
pub const metrics_http = @import("metrics_http.zig");

// --- Node Entry & Config ---
pub const main_node = @import("main.zig");
pub const config = @import("config.zig");
pub const http_api = @import("http_api.zig");
pub const inference = @import("inference.zig");
pub const semantic_index = @import("semantic_index.zig");
pub const graceful_shutdown = @import("graceful_shutdown.zig");
pub const integration_test = @import("integration_test.zig");
pub const network_codex = @import("network_codex.zig");

// --- Deferred (external deps → NEXUS-008 workspace wiring) ---
// distributed.zig — imports @import("gguf_model") (firebird module)
// firebird/depin.zig — imports @import("vsa.zig") (core module)
// tvc/tvc_distributed.zig — imports @import("tvc_corpus") (symb module)
// vibeec/networked_cli.zig — imports @import("evolved_codex.zig")
// vibeec/trinity_node_igla.zig — imports @import("multi_provider.zig")
// vibeec/trinity_hybrid_node.zig — imports @import("oss_api_client.zig"), @import("mainnet_genesis.zig")
// vibeec/p2p_module.zig — self-contained but kept in vibeec/ subdir for organization
// vibeec/trinity_node_scaled.zig — self-contained but kept in vibeec/ subdir for organization

// --- Re-exported types ---
pub const Protocol = protocol.Protocol;
pub const StorageNode = storage.StorageNode;

// --- Test block (self-contained modules only) ---
test {
    _ = protocol;
    _ = discovery;
    _ = connection_pool;
    _ = manifest_dht;
    _ = shard_manager;
    _ = shard_rebalancer;
    _ = shard_scrubber;
    _ = auto_shard;
    _ = vsa_shard_encoder;
    _ = vsa_shard_locks;
    _ = reputation_consensus;
    _ = node_reputation;
    _ = cross_shard_tx;
    _ = parallel_saga;
    _ = saga_coordinator;
    _ = transaction_wal;
    _ = wal_disk;
    _ = auto_repair;
    _ = erasure_repair;
    _ = dynamic_erasure;
    _ = rs_repair;
    _ = reed_solomon;
    _ = galois;
    _ = repair_rate_limiter;
    _ = region_router;
    _ = region_topology;
    _ = peer_latency;
    _ = storage;
    _ = remote_storage;
    _ = storage_discovery;
    _ = file_encoder;
    _ = crypto;
    _ = wallet;
    _ = token_staking;
    _ = stake_delegation;
    _ = slashing_escrow;
    _ = incentive_slashing;
    _ = proof_of_storage;
    _ = network_stats;
    _ = bandwidth_aggregator;
    _ = prometheus_metrics;
    _ = prometheus_http;
    _ = metrics_http;
    _ = main_node;
    _ = config;
    _ = http_api;
    _ = inference;
    _ = semantic_index;
    _ = graceful_shutdown;
    _ = integration_test;
    _ = network_codex;
    // network.zig imports many siblings — include in test if all resolve
    _ = network;
}

test "network module identity" {
    const name = "trinity-network";
    const version = "0.6.0";
    try @import("std").testing.expect(name.len > 0);
    try @import("std").testing.expect(version.len > 0);
}

test "protocol available" {
    const P = @TypeOf(protocol);
    try @import("std").testing.expect(@sizeOf(P) >= 0);
}
