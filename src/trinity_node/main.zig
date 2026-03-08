// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY NODE - Decentralized Inference Network Node
// Desktop app for contributing compute and earning $TRI
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const builtin = @import("builtin");
const protocol = @import("protocol.zig");
const crypto = @import("crypto.zig");
const wallet_mod = @import("wallet.zig");
const network_mod = @import("network.zig");
const discovery = @import("discovery.zig");
const config_mod = @import("config.zig");
const inference_mod = @import("inference.zig");
const distributed = @import("distributed.zig");

// GUI is enabled separately via 'zig build node-gui' which links raylib
// This file is for headless mode; ui.zig has its own entry point

// ═══════════════════════════════════════════════════════════════════════════════
// VERSION
// ═══════════════════════════════════════════════════════════════════════════════

pub const VERSION = "0.1.0";
pub const PROTOCOL_VERSION: u16 = 1;

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND LINE ARGUMENTS
// ═══════════════════════════════════════════════════════════════════════════════

const storage_mod = @import("storage.zig");
const shard_manager_mod = @import("shard_manager.zig");
const storage_discovery = @import("storage_discovery.zig");
const remote_storage = @import("remote_storage.zig");
const connection_pool_mod = @import("connection_pool.zig");
const manifest_dht_mod = @import("manifest_dht.zig");
// v1.5: Proof-of-Storage, Shard Rebalancing, Bandwidth Aggregation
const proof_of_storage_mod = @import("proof_of_storage.zig");
const shard_rebalancer_mod = @import("shard_rebalancer.zig");
const bandwidth_aggregator_mod = @import("bandwidth_aggregator.zig");
// v1.6: Shard Scrubbing, Node Reputation, Graceful Shutdown, Network Stats
const shard_scrubber_mod = @import("shard_scrubber.zig");
const node_reputation_mod = @import("node_reputation.zig");
const graceful_shutdown_mod = @import("graceful_shutdown.zig");
const network_stats_reporter_mod = @import("network_stats.zig");
// v1.7: Auto-Repair, Incentive Slashing, Prometheus Metrics
const auto_repair_mod = @import("auto_repair.zig");
const incentive_slashing_mod = @import("incentive_slashing.zig");
const prometheus_metrics_mod = @import("prometheus_metrics.zig");
// v1.8: Rate-Limited Repair, Token Staking, Latency-Aware Peers, RS Repair, Metrics HTTP
const repair_rate_limiter_mod = @import("repair_rate_limiter.zig");
const token_staking_mod = @import("token_staking.zig");
const peer_latency_mod = @import("peer_latency.zig");
const rs_repair_mod = @import("rs_repair.zig");
const metrics_http_mod = @import("metrics_http.zig");
// v1.9: Erasure Repair, Reputation Consensus, Stake Delegation
const erasure_repair_mod = @import("erasure_repair.zig");
const reputation_consensus_mod = @import("reputation_consensus.zig");
const stake_delegation_mod = @import("stake_delegation.zig");
// v2.0: Region Topology, Slashing Escrow, Prometheus HTTP, Semantic VSA
const region_topology_mod = @import("region_topology.zig");
const slashing_escrow_mod = @import("slashing_escrow.zig");
const prometheus_http_mod = @import("prometheus_http.zig");
const vsa_shard_encoder_mod = @import("vsa_shard_encoder.zig");
const semantic_index_mod = @import("semantic_index.zig");
// v2.1: HTTP REST API
const http_api_mod = @import("http_api.zig");

const Args = struct {
    headless: bool = false,
    distributed: bool = false,
    storage: bool = false,
    storage_max_gb: u64 = 10,
    port: u16 = network_mod.JOB_PORT,
    model_path: ?[]const u8 = null,
    wallet_password: ?[]const u8 = null,
    store_file: ?[]const u8 = null,
    retrieve_id: ?[]const u8 = null,
    output_dir: ?[]const u8 = null,
    // v1.3: Remote storage, pinning, bandwidth, HKDF
    remote_enabled: bool = false,
    pin_hash: ?[]const u8 = null,
    unpin_hash: ?[]const u8 = null,
    show_bandwidth: bool = false,
    legacy_key: bool = false,
    // v1.4: DHT manifest retrieval
    retrieve_dht: ?[]const u8 = null,
    // v1.5: Proof-of-Storage, Rebalancing, Network Stats
    enable_pos: bool = false,
    enable_rebalance: bool = false,
    network_stats: bool = false,
    // v1.6: Shard Scrubbing, Reputation, Report
    enable_scrub: bool = false,
    enable_reputation: bool = false,
    show_report: bool = false,
    // v1.7: Auto-Repair, Slashing, Metrics
    enable_auto_repair: bool = false,
    enable_slashing: bool = false,
    show_metrics: bool = false,
    // v1.8: Rate-Limited Repair, Token Staking, Latency, RS Repair, Metrics HTTP
    enable_rate_limiter: bool = false,
    enable_staking: bool = false,
    enable_latency: bool = false,
    enable_rs_repair: bool = false,
    metrics_port: u16 = 9100,
    // v1.9: Erasure Repair, Reputation Consensus, Stake Delegation
    enable_erasure_repair: bool = false,
    enable_consensus: bool = false,
    enable_delegation: bool = false,
    // v2.0: Region Topology, Slashing Escrow, Prometheus HTTP, Semantic VSA
    enable_region_topology: bool = false,
    enable_escrow: bool = false,
    enable_prometheus_http: bool = false,
    enable_semantic: bool = false,
    prometheus_http_port: u16 = 9090,
    // v2.1: HTTP REST API
    enable_http_api: bool = false,
    http_api_port: u16 = 8080,
    help: bool = false,
};

fn parseArgs() Args {
    var args = Args{};
    var arg_iter = std.process.args();
    _ = arg_iter.skip(); // Skip program name

    while (arg_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--headless") or std.mem.eql(u8, arg, "-d")) {
            args.headless = true;
        } else if (std.mem.eql(u8, arg, "--distributed") or std.mem.eql(u8, arg, "--dist")) {
            args.distributed = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            args.help = true;
        } else if (std.mem.startsWith(u8, arg, "--port=")) {
            args.port = std.fmt.parseInt(u16, arg[7..], 10) catch network_mod.JOB_PORT;
        } else if (std.mem.startsWith(u8, arg, "--model=")) {
            args.model_path = arg[8..];
        } else if (std.mem.startsWith(u8, arg, "--password=")) {
            args.wallet_password = arg[11..];
        } else if (std.mem.eql(u8, arg, "--storage")) {
            args.storage = true;
        } else if (std.mem.startsWith(u8, arg, "--storage-max-gb=")) {
            args.storage_max_gb = std.fmt.parseInt(u64, arg[17..], 10) catch 10;
            args.storage = true;
        } else if (std.mem.startsWith(u8, arg, "--store=")) {
            args.store_file = arg[8..];
            args.storage = true;
        } else if (std.mem.startsWith(u8, arg, "--retrieve=")) {
            args.retrieve_id = arg[11..];
            args.storage = true;
        } else if (std.mem.startsWith(u8, arg, "--output=")) {
            args.output_dir = arg[9..];
        } else if (std.mem.eql(u8, arg, "--remote")) {
            args.remote_enabled = true;
        } else if (std.mem.startsWith(u8, arg, "--pin=")) {
            args.pin_hash = arg[6..];
            args.storage = true;
        } else if (std.mem.startsWith(u8, arg, "--unpin=")) {
            args.unpin_hash = arg[8..];
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--bandwidth")) {
            args.show_bandwidth = true;
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--legacy-key")) {
            args.legacy_key = true;
        } else if (std.mem.startsWith(u8, arg, "--retrieve-dht=")) {
            args.retrieve_dht = arg[15..];
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--pos")) {
            args.enable_pos = true;
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--rebalance")) {
            args.enable_rebalance = true;
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--network-stats")) {
            args.network_stats = true;
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--scrub")) {
            args.enable_scrub = true;
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--reputation")) {
            args.enable_reputation = true;
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--report")) {
            args.show_report = true;
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--auto-repair")) {
            args.enable_auto_repair = true;
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--slashing")) {
            args.enable_slashing = true;
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--metrics")) {
            args.show_metrics = true;
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--rate-limiter")) {
            args.enable_rate_limiter = true;
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--staking")) {
            args.enable_staking = true;
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--latency")) {
            args.enable_latency = true;
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--rs-repair")) {
            args.enable_rs_repair = true;
            args.storage = true;
        } else if (std.mem.startsWith(u8, arg, "--metrics-port=")) {
            args.metrics_port = std.fmt.parseInt(u16, arg[15..], 10) catch 9100;
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--erasure-repair")) {
            args.enable_erasure_repair = true;
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--consensus")) {
            args.enable_consensus = true;
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--delegation")) {
            args.enable_delegation = true;
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--region-topology")) {
            args.enable_region_topology = true;
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--escrow")) {
            args.enable_escrow = true;
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--prometheus-http")) {
            args.enable_prometheus_http = true;
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--semantic")) {
            args.enable_semantic = true;
            args.storage = true;
        } else if (std.mem.startsWith(u8, arg, "--prometheus-http-port=")) {
            args.prometheus_http_port = std.fmt.parseInt(u16, arg[22..], 10) catch 9090;
            args.storage = true;
        } else if (std.mem.eql(u8, arg, "--http-api")) {
            args.enable_http_api = true;
        } else if (std.mem.startsWith(u8, arg, "--http-api-port=")) {
            args.http_api_port = std.fmt.parseInt(u16, arg[16..], 10) catch 8080;
            args.enable_http_api = true;
        }
    }

    return args;
}

fn printHelp() void {
    const help =
        \\
        \\╔══════════════════════════════════════════════════════════════════════════╗
        \\║                     TRINITY NODE v{s}                                  ║
        \\║           Decentralized Inference Network                               ║
        \\║           φ² + 1/φ² = 3 = TRINITY                                       ║
        \\╚══════════════════════════════════════════════════════════════════════════╝
        \\
        \\USAGE:
        \\  trinity-node [OPTIONS]
        \\
        \\OPTIONS:
        \\  -h, --help              Show this help message
        \\  -d, --headless          Run in headless (daemon) mode
        \\  --port=PORT             Job server port (default: 9334)
        \\  --model=PATH            Path to GGUF model file
        \\  --password=PASS         Wallet password (will prompt if not provided)
        \\  --storage               Enable storage provider (earn $TRI for hosting)
        \\  --storage-max-gb=N      Max storage in GB (default: 10)
        \\  --store=FILE            Store a file to local storage (one-shot)
        \\  --retrieve=FILE_ID_HEX  Retrieve a file by ID (one-shot)
        \\  --output=DIR            Output directory for retrieved files (default: .)
        \\  --remote                Enable remote peer distribution (v1.3)
        \\  --pin=SHARD_HASH_HEX   Pin a shard to prevent LRU eviction (v1.3)
        \\  --unpin=SHARD_HASH_HEX  Unpin a shard (v1.3)
        \\  --bandwidth             Show bandwidth stats (v1.3)
        \\  --legacy-key            Use SHA256(password) key derivation (v1.2 compat)
        \\  --retrieve-dht=FILE_ID  Retrieve manifest via DHT (v1.4)
        \\  --pos                   Enable Proof-of-Storage challenges (v1.5)
        \\  --rebalance             Enable shard rebalancing (v1.5)
        \\  --network-stats         Show network-wide bandwidth stats (v1.5)
        \\  --scrub                 Enable periodic shard scrubbing (v1.6)
        \\  --reputation            Enable node reputation scoring (v1.6)
        \\  --report                Generate network health report (v1.6)
        \\  --auto-repair           Enable automatic shard repair from peers (v1.7)
        \\  --slashing              Enable incentive slashing for bad actors (v1.7)
        \\  --metrics               Generate Prometheus metrics output (v1.7)
        \\  --rate-limiter          Enable rate-limited repair with circuit breaker (v1.8)
        \\  --staking               Enable token staking for participation (v1.8)
        \\  --latency               Enable latency-aware peer selection (v1.8)
        \\  --rs-repair             Enable Reed-Solomon erasure recovery (v1.8)
        \\  --metrics-port=PORT     HTTP port for Prometheus scraping (default: 9100) (v1.8)
        \\  --erasure-repair        Enable erasure-coded shard repair (v1.9)
        \\  --consensus             Enable reputation consensus voting (v1.9)
        \\  --delegation            Enable stake delegation to operators (v1.9)
        \\  --region-topology       Enable geo-aware shard placement (v2.0)
        \\  --escrow                Enable slashing escrow with disputes (v2.0)
        \\  --prometheus-http       Enable Prometheus /metrics HTTP endpoint (v2.0)
        \\  --semantic              Enable VSA semantic content indexing (v2.0)
        \\  --prometheus-http-port=PORT  Prometheus HTTP port (default: 9090) (v2.0)
        \\  --http-api              Enable HTTP REST API server (v2.1)
        \\  --http-api-port=PORT    HTTP API port (default: 8080) (v2.1)
        \\
        \\EXAMPLES:
        \\  trinity-node                          # Start with GUI
        \\  trinity-node --headless               # Run as daemon
        \\  trinity-node --model=./model.gguf     # Use specific model
        \\  trinity-node --store=photo.jpg        # Store file, prints file_id
        \\  trinity-node --retrieve=abc123...     # Retrieve file by ID
        \\
        \\DIRECTORIES:
        \\  ~/.trinity/wallet.enc    Encrypted wallet file
        \\  ~/.trinity/config.json   Configuration
        \\  ~/.trinity/models/       Model files
        \\
        \\NETWORK:
        \\  UDP {d}                 Peer discovery
        \\  TCP {d}                 Job server
        \\
        \\REWARDS:
        \\  Base: 0.9 $TRI per 1M tokens
        \\  Latency bonus: up to +50%
        \\  Uptime bonus: up to +20%
        \\
    ;
    std.debug.print(help, .{ VERSION, discovery.DISCOVERY_PORT, network_mod.JOB_PORT });
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = parseArgs();

    if (args.help) {
        printHelp();
        return;
    }

    // Distributed inference mode — bypass normal node startup
    if (args.distributed) {
        const alloc = std.heap.page_allocator;
        const process_args = try std.process.argsAlloc(alloc);
        defer std.process.argsFree(alloc, process_args);
        const dist_args = if (process_args.len > 1) process_args[1..] else &[_][]const u8{};
        try distributed.runDistributed(alloc, dist_args);
        return;
    }

    // Print banner
    printBanner();

    // Ensure directories exist
    try config_mod.Config.ensureDirectories(allocator);

    // Load or create wallet
    std.debug.print("Loading wallet...\n", .{});
    const wallet_path = try config_mod.Config.getWalletPath(allocator);
    defer allocator.free(wallet_path);

    // DEFERRED (v12): Prompt for password via stdin if not provided
    const password = args.wallet_password orelse "trinity123";

    var wallet = wallet_mod.Wallet.loadOrCreate(wallet_path, password) catch |err| {
        std.debug.print("Failed to load wallet: {}\n", .{err});
        return err;
    };

    std.debug.print("Wallet address: {s}\n", .{wallet.getAddressHex()});
    std.debug.print("Balance: {d:.6} $TRI\n", .{wallet.getBalanceFormatted()});

    // Initialize network
    std.debug.print("Starting network on port {d}...\n", .{args.port});
    var network = try network_mod.NetworkNode.init(allocator, &wallet, args.port);
    defer network.deinit();

    // Initialize storage provider if --storage flag is set
    var storage_provider: ?storage_mod.StorageProvider = null;
    var shards_dir: ?[]u8 = null;
    if (args.storage) {
        // Get persistent storage directory
        shards_dir = config_mod.Config.getShardsDir(allocator) catch null;
        if (shards_dir != null) {
            try config_mod.Config.ensureStorageDirectories(allocator);
        }

        const max_bytes = args.storage_max_gb * 1024 * 1024 * 1024;
        storage_provider = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = max_bytes,
            .storage_dir = shards_dir,
        });
        network.storage_provider = if (storage_provider != null) &storage_provider.? else null;
        std.debug.print("Storage provider enabled: {d} GB max\n", .{args.storage_max_gb});

        // Startup recovery: load shard index from disk
        if (storage_provider != null) {
            const recovered = storage_provider.?.loadFromDisk() catch 0;
            if (recovered > 0) {
                std.debug.print("Recovered {d} shards from disk\n", .{recovered});
            }
        }
    }
    defer {
        if (storage_provider != null) storage_provider.?.deinit();
        if (shards_dir) |sd| allocator.free(sd);
    }

    // Initialize storage peer registry
    var storage_registry: ?storage_discovery.StoragePeerRegistry = null;
    if (args.storage) {
        storage_registry = storage_discovery.StoragePeerRegistry.init(allocator);
        network.storage_peer_registry = if (storage_registry != null) &storage_registry.? else null;
    }
    defer if (storage_registry != null) storage_registry.?.deinit();

    // v1.5: Initialize Proof-of-Storage engine
    var pos_engine: ?proof_of_storage_mod.ProofOfStorageEngine = null;
    if (args.enable_pos and args.storage) {
        pos_engine = proof_of_storage_mod.ProofOfStorageEngine.init(allocator);
        network.proof_of_storage = if (pos_engine != null) &pos_engine.? else null;
        std.debug.print("Proof-of-Storage enabled (challenge interval: 300s)\n", .{});
    }
    defer if (pos_engine != null) pos_engine.?.deinit();

    // v1.5: Initialize Shard Rebalancer
    var shard_rebalancer: ?shard_rebalancer_mod.ShardRebalancer = null;
    if (args.enable_rebalance and args.storage) {
        shard_rebalancer = shard_rebalancer_mod.ShardRebalancer.init(allocator, 3);
        network.shard_rebalancer = if (shard_rebalancer != null) &shard_rebalancer.? else null;
        std.debug.print("Shard rebalancer enabled (target replication: 3)\n", .{});
    }
    defer if (shard_rebalancer != null) shard_rebalancer.?.deinit();

    // v1.5: Initialize Bandwidth Aggregator
    var bw_aggregator: ?bandwidth_aggregator_mod.BandwidthAggregator = null;
    if (args.storage) {
        bw_aggregator = bandwidth_aggregator_mod.BandwidthAggregator.init(allocator);
        network.bandwidth_aggregator = if (bw_aggregator != null) &bw_aggregator.? else null;
    }
    defer if (bw_aggregator != null) bw_aggregator.?.deinit();

    // v1.6: Initialize Shard Scrubber
    var scrubber: ?shard_scrubber_mod.ShardScrubber = null;
    if (args.enable_scrub and args.storage) {
        scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
        network.shard_scrubber = if (scrubber != null) &scrubber.? else null;
        std.debug.print("Shard scrubber enabled (interval: 600s)\n", .{});
    }
    defer if (scrubber != null) scrubber.?.deinit();

    // v1.6: Initialize Node Reputation System
    var reputation: ?node_reputation_mod.NodeReputationSystem = null;
    if (args.enable_reputation and args.storage) {
        reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
        network.node_reputation = if (reputation != null) &reputation.? else null;
        std.debug.print("Node reputation enabled (weights: PoS=0.4, uptime=0.3, bw=0.3)\n", .{});
    }
    defer if (reputation != null) reputation.?.deinit();

    // v1.6: Initialize Graceful Shutdown Manager
    var shutdown_mgr: ?graceful_shutdown_mod.GracefulShutdownManager = null;
    if (args.storage) {
        shutdown_mgr = graceful_shutdown_mod.GracefulShutdownManager.init(allocator);
        network.graceful_shutdown = if (shutdown_mgr != null) &shutdown_mgr.? else null;
    }
    defer if (shutdown_mgr != null) shutdown_mgr.?.deinit();

    // v1.6: Initialize Network Stats Reporter
    var stats_reporter: ?network_stats_reporter_mod.NetworkStatsReporter = null;
    if (args.storage) {
        stats_reporter = network_stats_reporter_mod.NetworkStatsReporter.init(allocator);
        network.network_stats_reporter = if (stats_reporter != null) &stats_reporter.? else null;
    }

    // v1.7: Initialize Auto-Repair Engine
    var auto_repair_engine: ?auto_repair_mod.AutoRepairEngine = null;
    if (args.enable_auto_repair and args.storage) {
        auto_repair_engine = auto_repair_mod.AutoRepairEngine.init(allocator);
        network.auto_repair = if (auto_repair_engine != null) &auto_repair_engine.? else null;
        std.debug.print("Auto-repair enabled (scrub → repair from healthy peers)\n", .{});
    }
    defer if (auto_repair_engine != null) auto_repair_engine.?.deinit();

    // v1.7: Initialize Incentive Slashing Engine
    var slashing_engine: ?incentive_slashing_mod.IncentiveSlashingEngine = null;
    if (args.enable_slashing and args.storage) {
        slashing_engine = incentive_slashing_mod.IncentiveSlashingEngine.init(allocator);
        network.incentive_slashing = if (slashing_engine != null) &slashing_engine.? else null;
        std.debug.print("Incentive slashing enabled (threshold: 0.5, max slash: 80%)\n", .{});
    }
    defer if (slashing_engine != null) slashing_engine.?.deinit();

    // v1.7: Initialize Prometheus Metrics Exporter
    var metrics_exporter: ?prometheus_metrics_mod.PrometheusExporter = null;
    if (args.storage) {
        metrics_exporter = prometheus_metrics_mod.PrometheusExporter.init(allocator);
        network.prometheus_exporter = if (metrics_exporter != null) &metrics_exporter.? else null;
    }

    // v1.8: Initialize Rate-Limited Repair
    var rate_limiter: ?repair_rate_limiter_mod.RepairRateLimiter = null;
    if (args.enable_rate_limiter and args.storage) {
        rate_limiter = repair_rate_limiter_mod.RepairRateLimiter.init(allocator);
        network.repair_rate_limiter = if (rate_limiter != null) &rate_limiter.? else null;
        std.debug.print("Rate-limited repair enabled (max 10/min, circuit breaker: 5 failures)\n", .{});
    }
    defer if (rate_limiter != null) rate_limiter.?.deinit();

    // v1.8: Initialize Token Staking
    var staking_engine: ?token_staking_mod.TokenStakingEngine = null;
    if (args.enable_staking and args.storage) {
        staking_engine = token_staking_mod.TokenStakingEngine.init(allocator);
        network.token_staking = if (staking_engine != null) &staking_engine.? else null;
        std.debug.print("Token staking enabled (min stake: 100 TRI)\n", .{});
    }
    defer if (staking_engine != null) staking_engine.?.deinit();

    // v1.8: Initialize Peer Latency Tracker
    var latency_tracker: ?peer_latency_mod.PeerLatencyTracker = null;
    if (args.enable_latency and args.storage) {
        latency_tracker = peer_latency_mod.PeerLatencyTracker.init(allocator);
        network.peer_latency = if (latency_tracker != null) &latency_tracker.? else null;
        std.debug.print("Latency-aware peer selection enabled (EMA alpha: 0.3)\n", .{});
    }
    defer if (latency_tracker != null) latency_tracker.?.deinit();

    // v1.8: Initialize RS Repair Engine
    var rs_repair_engine: ?rs_repair_mod.RsRepairEngine = null;
    if (args.enable_rs_repair and args.storage) {
        rs_repair_engine = rs_repair_mod.RsRepairEngine.init(allocator);
        network.rs_repair = if (rs_repair_engine != null) &rs_repair_engine.? else null;
        std.debug.print("RS erasure recovery enabled (Reed-Solomon parity repair)\n", .{});
    }
    defer if (rs_repair_engine != null) rs_repair_engine.?.deinit();

    // v1.8: Initialize Metrics HTTP Server
    var metrics_http_server: ?metrics_http_mod.MetricsHttpServer = null;
    if (args.storage) {
        metrics_http_server = metrics_http_mod.MetricsHttpServer.init(allocator, args.metrics_port);
        network.metrics_http = if (metrics_http_server != null) &metrics_http_server.? else null;
    }
    defer if (metrics_http_server != null) metrics_http_server.?.deinit();

    // v1.9: Erasure Repair Engine
    var erasure_repair_engine: ?erasure_repair_mod.ErasureRepairEngine = null;
    if (args.enable_erasure_repair and args.storage) {
        erasure_repair_engine = erasure_repair_mod.ErasureRepairEngine.init(allocator);
        network.erasure_repair = if (erasure_repair_engine != null) &erasure_repair_engine.? else null;
    }
    defer if (erasure_repair_engine != null) erasure_repair_engine.?.deinit();

    // v1.9: Reputation Consensus
    var reputation_consensus: ?reputation_consensus_mod.ReputationConsensus = null;
    if (args.enable_consensus and args.storage) {
        reputation_consensus = reputation_consensus_mod.ReputationConsensus.init(allocator);
        network.reputation_consensus = if (reputation_consensus != null) &reputation_consensus.? else null;
    }
    defer if (reputation_consensus != null) reputation_consensus.?.deinit();

    // v1.9: Stake Delegation
    var stake_delegation: ?stake_delegation_mod.StakeDelegationEngine = null;
    if (args.enable_delegation and args.storage) {
        stake_delegation = stake_delegation_mod.StakeDelegationEngine.init(allocator);
        network.stake_delegation = if (stake_delegation != null) &stake_delegation.? else null;
    }
    defer if (stake_delegation != null) stake_delegation.?.deinit();

    // v2.0: Region Topology
    var region_topology: ?region_topology_mod.RegionTopology = null;
    if (args.enable_region_topology and args.storage) {
        region_topology = region_topology_mod.RegionTopology.init(allocator);
        network.region_topology = if (region_topology != null) &region_topology.? else null;
        std.debug.print("Region topology enabled (geo-aware shard placement)\n", .{});
    }
    defer if (region_topology != null) region_topology.?.deinit();

    // v2.0: Slashing Escrow
    var slashing_escrow: ?slashing_escrow_mod.SlashingEscrow = null;
    if (args.enable_escrow and args.storage) {
        slashing_escrow = slashing_escrow_mod.SlashingEscrow.init(allocator);
        network.slashing_escrow = if (slashing_escrow != null) &slashing_escrow.? else null;
        std.debug.print("Slashing escrow enabled (dispute window: 24h, governance voting)\n", .{});
    }
    defer if (slashing_escrow != null) slashing_escrow.?.deinit();

    // v2.0: Prometheus HTTP Endpoint
    var prometheus_http_endpoint: ?prometheus_http_mod.PrometheusHttpEndpoint = null;
    if (args.enable_prometheus_http and args.storage) {
        prometheus_http_endpoint = prometheus_http_mod.PrometheusHttpEndpoint.init(allocator);
        network.prometheus_http_endpoint = if (prometheus_http_endpoint != null) &prometheus_http_endpoint.? else null;
        std.debug.print("Prometheus HTTP endpoint enabled (port: {d})\n", .{args.prometheus_http_port});
    }
    defer if (prometheus_http_endpoint != null) prometheus_http_endpoint.?.deinit();

    // v2.1: HTTP REST API Server
    var http_api_server: ?http_api_mod.HttpApiServer = null;
    if (args.enable_http_api) {
        http_api_server = http_api_mod.HttpApiServer.initWithConfig(allocator, .{
            .port = args.http_api_port,
        });
        // Wire staking engine for tier-based access control (v2.2)
        if (staking_engine != null) {
            http_api_server.?.staking_engine = &staking_engine.?;
        }
        std.debug.print("HTTP REST API enabled (port: {d})\n", .{args.http_api_port});
    }
    defer if (http_api_server != null) http_api_server.?.deinit();

    // v2.0: VSA Shard Encoder + Semantic Index
    var vsa_encoder: ?vsa_shard_encoder_mod.VsaShardEncoder = null;
    var semantic_idx: ?semantic_index_mod.SemanticIndex = null;
    if (args.enable_semantic and args.storage) {
        vsa_encoder = vsa_shard_encoder_mod.VsaShardEncoder.init(allocator);
        network.vsa_encoder = if (vsa_encoder != null) &vsa_encoder.? else null;
        if (vsa_encoder != null) {
            semantic_idx = semantic_index_mod.SemanticIndex.init(allocator, &vsa_encoder.?);
            network.semantic_index = if (semantic_idx != null) &semantic_idx.? else null;
        }
        std.debug.print("Semantic VSA indexing enabled (dim: 256, content-addressable)\n", .{});
    }
    defer {
        if (semantic_idx != null) semantic_idx.?.deinit();
        if (vsa_encoder != null) vsa_encoder.?.deinit();
    }

    // v1.7: Show Prometheus metrics (one-shot)
    if (args.show_metrics) {
        if (stats_reporter) |*reporter| {
            const peers = [0]*storage_mod.StorageProvider{};
            const report = reporter.generateReport(
                &peers,
                if (shard_rebalancer != null) &shard_rebalancer.? else null,
                if (pos_engine != null) &pos_engine.? else null,
                if (bw_aggregator != null) &bw_aggregator.? else null,
                if (storage_registry != null) &storage_registry.? else null,
                if (scrubber != null) &scrubber.? else null,
                if (reputation != null) &reputation.? else null,
            );
            if (metrics_exporter) |*exporter| {
                const output = exporter.exportMetrics(report) catch {
                    std.debug.print("Failed to generate Prometheus metrics\n", .{});
                    return;
                };
                defer allocator.free(output);
                std.debug.print("{s}\n", .{output});
            }
        }
        return;
    }

    // v1.6: Show health report (one-shot)
    if (args.show_report) {
        if (stats_reporter) |*reporter| {
            const peers = [0]*storage_mod.StorageProvider{};
            const report = reporter.generateReport(
                &peers,
                if (shard_rebalancer != null) &shard_rebalancer.? else null,
                if (pos_engine != null) &pos_engine.? else null,
                if (bw_aggregator != null) &bw_aggregator.? else null,
                if (storage_registry != null) &storage_registry.? else null,
                if (scrubber != null) &scrubber.? else null,
                if (reputation != null) &reputation.? else null,
            );
            const text = reporter.formatText(report) catch {
                std.debug.print("Failed to generate report\n", .{});
                return;
            };
            defer allocator.free(text);
            std.debug.print("{s}\n", .{text});
        }
        return;
    }

    // v1.5: Show network stats (one-shot)
    if (args.network_stats) {
        if (bw_aggregator) |*agg| {
            const summary = agg.aggregate();
            std.debug.print("\n── Network Bandwidth Stats (v1.5) ──────────────────────────\n", .{});
            std.debug.print("  Reporting nodes: {d}\n", .{summary.node_count});
            std.debug.print("  Total upload:    {d} bytes ({d:.2} MB)\n", .{ summary.total_upload, @as(f64, @floatFromInt(summary.total_upload)) / (1024.0 * 1024.0) });
            std.debug.print("  Total download:  {d} bytes ({d:.2} MB)\n", .{ summary.total_download, @as(f64, @floatFromInt(summary.total_download)) / (1024.0 * 1024.0) });
            std.debug.print("────────────────────────────────────────────────────────────────\n", .{});
        } else {
            std.debug.print("No bandwidth data available.\n", .{});
        }
        return;
    }

    // CLI store/retrieve: one-shot operations, exit immediately
    if (args.store_file) |file_path| {
        if (storage_provider == null) {
            std.debug.print("Error: Storage provider not initialized\n", .{});
            return;
        }
        runStoreFile(allocator, &storage_provider.?, file_path, password, args.legacy_key) catch |err| {
            std.debug.print("Store failed: {s}\n", .{@errorName(err)});
        };
        return;
    }
    if (args.retrieve_id) |file_id_hex| {
        if (storage_provider == null) {
            std.debug.print("Error: Storage provider not initialized\n", .{});
            return;
        }
        runRetrieveFile(allocator, &storage_provider.?, file_id_hex, args.output_dir, password, args.legacy_key) catch |err| {
            std.debug.print("Retrieve failed: {s}\n", .{@errorName(err)});
        };
        return;
    }

    // v1.3: Pin/unpin shard operations
    if (args.pin_hash) |hash_hex| {
        if (storage_provider == null) {
            std.debug.print("Error: Storage provider not initialized\n", .{});
            return;
        }
        if (hash_hex.len != 64) {
            std.debug.print("Error: Shard hash must be 64 hex characters\n", .{});
            return;
        }
        var hex_buf: [64]u8 = undefined;
        @memcpy(&hex_buf, hash_hex);
        const shard_hash = storage_mod.hexToHash(hex_buf) orelse {
            std.debug.print("Error: Invalid hex in shard hash\n", .{});
            return;
        };
        storage_provider.?.pinShard(shard_hash);
        std.debug.print("Shard pinned: {s}\n", .{hash_hex});
        return;
    }
    if (args.unpin_hash) |hash_hex| {
        if (storage_provider == null) {
            std.debug.print("Error: Storage provider not initialized\n", .{});
            return;
        }
        if (hash_hex.len != 64) {
            std.debug.print("Error: Shard hash must be 64 hex characters\n", .{});
            return;
        }
        var hex_buf: [64]u8 = undefined;
        @memcpy(&hex_buf, hash_hex);
        const shard_hash = storage_mod.hexToHash(hex_buf) orelse {
            std.debug.print("Error: Invalid hex in shard hash\n", .{});
            return;
        };
        storage_provider.?.unpinShard(shard_hash);
        std.debug.print("Shard unpinned: {s}\n", .{hash_hex});
        return;
    }

    // v1.3: Show bandwidth stats
    if (args.show_bandwidth) {
        if (storage_provider == null) {
            std.debug.print("Error: Storage provider not initialized\n", .{});
            return;
        }
        const rw = storage_provider.?.getRewardStats();
        std.debug.print("\n── Bandwidth Stats ──────────────────────────────────────────\n", .{});
        std.debug.print("  Uploaded:    {d} bytes ({d:.2} MB)\n", .{ rw.bytes_uploaded, @as(f64, @floatFromInt(rw.bytes_uploaded)) / (1024.0 * 1024.0) });
        std.debug.print("  Downloaded:  {d} bytes ({d:.2} MB)\n", .{ rw.bytes_downloaded, @as(f64, @floatFromInt(rw.bytes_downloaded)) / (1024.0 * 1024.0) });
        std.debug.print("  Earned:      {d:.6} $TRI (total)\n", .{rw.earned_tri});
        std.debug.print("  Pinned:      {d} shards\n", .{storage_provider.?.getPinnedShardCount()});
        std.debug.print("  In memory:   {d} shards\n", .{storage_provider.?.getMemoryShardCount()});
        std.debug.print("────────────────────────────────────────────────────────────────\n", .{});
        return;
    }

    try network.start();
    std.debug.print("Network started. Status: {s}\n", .{@tagName(network.status)});

    if (args.headless) {
        // Headless mode - run daemon
        try runHeadless(allocator, network, &wallet, args.model_path);
    } else {
        // GUI mode - Raylib UI (requires linking raylib)
        // For now, just run headless with a message
        std.debug.print("\nGUI mode requires raylib. Running in headless mode.\n", .{});
        std.debug.print("Build with: zig build node-gui (when raylib is available)\n", .{});
        std.debug.print("Or use --headless flag for daemon mode.\n\n", .{});
        try runHeadless(allocator, network, &wallet, args.model_path);
    }
}

fn printBanner() void {
    const banner =
        \\
        \\  ████████╗██████╗ ██╗███╗   ██╗██╗████████╗██╗   ██╗
        \\  ╚══██╔══╝██╔══██╗██║████╗  ██║██║╚══██╔══╝╚██╗ ██╔╝
        \\     ██║   ██████╔╝██║██╔██╗ ██║██║   ██║    ╚████╔╝
        \\     ██║   ██╔══██╗██║██║╚██╗██║██║   ██║     ╚██╔╝
        \\     ██║   ██║  ██║██║██║ ╚████║██║   ██║      ██║
        \\     ╚═╝   ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚═╝   ╚═╝      ╚═╝
        \\
        \\              DECENTRALIZED INFERENCE NODE
        \\                    φ² + 1/φ² = 3
        \\
        \\  Version: {s}    Protocol: v{d}
        \\
    ;
    std.debug.print(banner, .{ VERSION, PROTOCOL_VERSION });
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEADLESS MODE
// ═══════════════════════════════════════════════════════════════════════════════

fn runHeadless(allocator: std.mem.Allocator, network: *network_mod.NetworkNode, wallet: *wallet_mod.Wallet, model_path: ?[]const u8) !void {
    std.debug.print("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  TRINITY NODE RUNNING (Headless Mode)                        ║\n", .{});
    std.debug.print("║  Press Ctrl+C to stop                                        ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    // Initialize inference engine
    const inference_config = inference_mod.InferenceConfig{
        .model_path = model_path orelse "models/tinyllama-q6k.gguf",
        .max_tokens = 256,
        .temperature = 0.7,
    };

    var inference_engine = inference_mod.InferenceEngine.init(allocator, inference_config);
    defer inference_engine.deinit();

    // Try to load model (optional - will use simulation if not available)
    var model_loaded = false;
    inference_engine.loadModel() catch |err| {
        std.debug.print("Note: Model not loaded ({s}). Using simulation mode.\n", .{@errorName(err)});
    };
    if (inference_engine.status == .ready) {
        model_loaded = true;
        std.debug.print("Model loaded successfully. Real inference enabled.\n", .{});
    }

    var last_stats_time: i64 = 0;
    const stats_interval: i64 = 10; // Print stats every 10 seconds
    // TODO: Re-enable when broadcastStorageAnnounce is implemented
    // var last_announce_time: i64 = 0;
    // const announce_interval: i64 = 60; // Announce storage every 60 seconds

    // Main loop
    while (true) {
        // Poll network
        network.poll();

        // Check for pending jobs
        if (network.getNextJob()) |pending_job| {
            std.debug.print("Received job: {x}\n", .{pending_job.job.job_id});

            var tokens_generated: u64 = 50;
            var latency_ms: u32 = 1000;

            if (model_loaded) {
                // Process with real inference engine
                const result = inference_engine.processJob(pending_job.job) catch |err| {
                    std.debug.print("Inference error: {s}\n", .{@errorName(err)});
                    continue;
                };
                tokens_generated = result.tokens_generated;
                latency_ms = result.latency_ms;

                std.debug.print("Generated {d} tokens in {d}ms\n", .{ tokens_generated, latency_ms });
            } else {
                // Simulate processing
                std.Thread.sleep(1 * std.time.ns_per_s);
            }

            // Record job completion
            const uptime_pct: f32 = 1.0;
            wallet.recordJob(tokens_generated, latency_ms, uptime_pct);

            std.debug.print("Job completed. Earned: {d:.6} $TRI\n", .{
                wallet_mod.weiToTri(protocol.calculateJobReward(tokens_generated, latency_ms, uptime_pct)),
            });
        }

        const now = std.time.timestamp();

        // Broadcast storage announce periodically
        // TODO: Implement broadcastStorageAnnounce in NetworkNode
        // if (now - last_announce_time >= announce_interval) {
        //     network.broadcastStorageAnnounce() catch {};
        //     last_announce_time = now;
        // }

        // Print stats periodically
        if (now - last_stats_time >= stats_interval) {
            const net_stats = network.getStats();
            const inf_stats = inference_engine.getStats();
            const storage_ptr: ?*storage_mod.StorageProvider = if (network.storage_provider) |ptr|
                @ptrCast(@alignCast(ptr))
            else
                null;
            printStats(net_stats, inf_stats, wallet, storage_ptr);
            last_stats_time = now;
        }

        // Sleep to avoid busy loop
        std.Thread.sleep(100 * std.time.ns_per_ms);
    }
}

fn printStats(net_stats: network_mod.NetworkStats, inf_stats: inference_mod.InferenceStats, wallet: *const wallet_mod.Wallet, storage_provider: ?*storage_mod.StorageProvider) void {
    std.debug.print("\n── Stats ──────────────────────────────────────────────────────\n", .{});
    std.debug.print("  Status:      {s}\n", .{@tagName(net_stats.status)});
    std.debug.print("  Peers:       {d}\n", .{net_stats.peer_count});
    std.debug.print("  Jobs:        {d} received / {d} completed\n", .{ net_stats.jobs_received, net_stats.jobs_completed });
    std.debug.print("  Pending:     {d}\n", .{net_stats.pending_jobs});
    std.debug.print("  Uptime:      {d}s\n", .{net_stats.uptime_seconds});
    std.debug.print("  ── Inference ──\n", .{});
    std.debug.print("  Model:       {s}\n", .{if (inf_stats.model_loaded) "Loaded" else "Simulation"});
    std.debug.print("  Processed:   {d} jobs, {d} tokens\n", .{ inf_stats.jobs_processed, inf_stats.tokens_generated });
    std.debug.print("  Speed:       {d:.2} tok/s\n", .{inf_stats.tokens_per_second});
    if (storage_provider) |sp| {
        const st = sp.getStats();
        const rw = sp.getRewardStats();
        std.debug.print("  ── Storage ──\n", .{});
        std.debug.print("  Shards:      {d}\n", .{st.total_shards});
        std.debug.print("  Used:        {d} bytes\n", .{st.used_bytes});
        std.debug.print("  Available:   {d} bytes\n", .{st.available_bytes});
        std.debug.print("  Retrievals:  {d}\n", .{rw.retrievals_served});
        std.debug.print("  Upload:      {d:.2} MB\n", .{@as(f64, @floatFromInt(rw.bytes_uploaded)) / (1024.0 * 1024.0)});
        std.debug.print("  Download:    {d:.2} MB\n", .{@as(f64, @floatFromInt(rw.bytes_downloaded)) / (1024.0 * 1024.0)});
        std.debug.print("  Earned:      {d:.6} $TRI (storage)\n", .{rw.earned_tri});
    }
    std.debug.print("  ── Wallet ──\n", .{});
    std.debug.print("  Balance:     {d:.6} $TRI\n", .{wallet.getBalanceFormatted()});
    std.debug.print("  Pending:     {d:.6} $TRI\n", .{wallet.getPendingFormatted()});
    std.debug.print("  Total:       {d:.6} $TRI\n", .{wallet.getTotalEarnedFormatted()});
    std.debug.print("────────────────────────────────────────────────────────────────\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// KEY DERIVATION (v1.3: HKDF-SHA256, v1.2 compat: SHA256)
// ═══════════════════════════════════════════════════════════════════════════════

/// v1.3: Derive encryption key using HKDF-SHA256
fn deriveEncryptionKeyHkdf(password: []const u8) [32]u8 {
    const HkdfSha256 = std.crypto.kdf.hkdf.HkdfSha256;
    const prk = HkdfSha256.extract("trinity-storage-v1.3", password);
    var key: [32]u8 = undefined;
    HkdfSha256.expand(&key, "file-encryption-key", prk);
    return key;
}

/// Get encryption key based on key derivation method
fn getEncryptionKey(password: []const u8, legacy: bool) [32]u8 {
    if (legacy) {
        return crypto.sha256(password); // v1.2 compat
    }
    return deriveEncryptionKeyHkdf(password); // v1.3 HKDF
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI STORE / RETRIEVE (v1.3: HKDF + Remote + Pinning)
// ═══════════════════════════════════════════════════════════════════════════════

fn runStoreFile(allocator: std.mem.Allocator, sp: *storage_mod.StorageProvider, file_path: []const u8, password: []const u8, legacy_key: bool) !void {
    std.debug.print("Storing file: {s}\n", .{file_path});

    // Read file from disk
    const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
        std.debug.print("Cannot open file: {s} ({s})\n", .{ file_path, @errorName(err) });
        return err;
    };
    defer file.close();

    const stat = try file.stat();
    const file_data = try allocator.alloc(u8, stat.size);
    defer allocator.free(file_data);
    const bytes_read = try file.readAll(file_data);
    if (bytes_read != stat.size) return error.IncompleteRead;

    // v1.3: HKDF key derivation (or legacy SHA256)
    const key = getEncryptionKey(password, legacy_key);

    // Create ShardManager and store locally
    const config = sp.config;
    const sm = shard_manager_mod.ShardManager.init(allocator, config);
    var peers = [_]*storage_mod.StorageProvider{sp};
    const manifest = try sm.storeFile(file_data, file_path, key, &peers);
    defer allocator.free(manifest.shard_hashes);

    // Persist manifest
    try sp.persistManifest(&manifest);

    // Print result
    const file_id_hex = storage_mod.hashToHex(manifest.file_id);
    std.debug.print("\nFile stored successfully!\n", .{});
    std.debug.print("  File ID:    {s}\n", .{file_id_hex});
    std.debug.print("  File:       {s}\n", .{file_path});
    std.debug.print("  Size:       {d} bytes\n", .{stat.size});
    std.debug.print("  Shards:     {d}\n", .{manifest.shard_count});
    std.debug.print("  Parity:     {s}\n", .{if (manifest.hasParity()) "yes (XOR)" else "no"});
    if (manifest.hasReedSolomon()) {
        std.debug.print("  RS Coding:  {d}+{d} (data+parity)\n", .{ manifest.rs_data_shards, manifest.rs_parity_shards });
    }
    std.debug.print("  Key:        {s}\n", .{if (legacy_key) "SHA256 (legacy)" else "HKDF-SHA256 (v1.3)"});
    std.debug.print("\nTo retrieve: trinity-node --retrieve={s}\n", .{file_id_hex});
}

fn runRetrieveFile(allocator: std.mem.Allocator, sp: *storage_mod.StorageProvider, file_id_hex: []const u8, output_dir: ?[]const u8, password: []const u8, legacy_key: bool) !void {
    std.debug.print("Retrieving file: {s}\n", .{file_id_hex});

    // Parse file_id from hex
    if (file_id_hex.len != 64) {
        std.debug.print("Error: File ID must be 64 hex characters (got {d})\n", .{file_id_hex.len});
        return error.InvalidFileId;
    }
    var hex_buf: [64]u8 = undefined;
    @memcpy(&hex_buf, file_id_hex);
    const file_id = storage_mod.hexToHash(hex_buf) orelse {
        std.debug.print("Error: Invalid hex in file ID\n", .{});
        return error.InvalidHex;
    };

    // Load manifest from disk
    const manifest = sp.loadManifest(file_id) catch |err| {
        std.debug.print("Error: Cannot load manifest ({s})\n", .{@errorName(err)});
        return err;
    };
    defer allocator.free(manifest.shard_hashes);

    // v1.3: HKDF key derivation (or legacy SHA256)
    const key = getEncryptionKey(password, legacy_key);

    // Retrieve file via ShardManager
    const config = sp.config;
    const sm = shard_manager_mod.ShardManager.init(allocator, config);
    var peers = [_]*storage_mod.StorageProvider{sp};
    const recovered = sm.retrieveFile(&manifest, key, &peers) catch |err| {
        std.debug.print("Error: Retrieval failed ({s})\n", .{@errorName(err)});
        return err;
    };
    defer allocator.free(recovered);

    // Write to output dir
    const file_name = manifest.getFileName();
    const out_dir = output_dir orelse ".";
    const out_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ out_dir, file_name });
    defer allocator.free(out_path);

    const out_file = try std.fs.cwd().createFile(out_path, .{});
    defer out_file.close();
    try out_file.writeAll(recovered);

    std.debug.print("\nFile retrieved successfully!\n", .{});
    std.debug.print("  Output:    {s}\n", .{out_path});
    std.debug.print("  Size:      {d} bytes\n", .{recovered.len});
    std.debug.print("  Original:  {d} bytes\n", .{manifest.original_size});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "version string" {
    try std.testing.expect(VERSION.len > 0);
}

test "args parsing" {
    // Just verify the struct can be created with v1.3/v1.4/v1.5 fields
    const args = Args{};
    try std.testing.expect(!args.headless);
    try std.testing.expectEqual(@as(u16, 9334), args.port);
    try std.testing.expect(!args.remote_enabled);
    try std.testing.expect(!args.legacy_key);
    try std.testing.expect(!args.show_bandwidth);
    try std.testing.expect(args.pin_hash == null);
    try std.testing.expect(args.unpin_hash == null);
    try std.testing.expect(args.retrieve_dht == null);
    // v1.5 fields
    try std.testing.expect(!args.enable_pos);
    try std.testing.expect(!args.enable_rebalance);
    try std.testing.expect(!args.network_stats);
    // v1.6 fields
    try std.testing.expect(!args.enable_scrub);
    try std.testing.expect(!args.enable_reputation);
    try std.testing.expect(!args.show_report);
    // v1.7 fields
    try std.testing.expect(!args.enable_auto_repair);
    try std.testing.expect(!args.enable_slashing);
    try std.testing.expect(!args.show_metrics);
    // v1.8 fields
    try std.testing.expect(!args.enable_rate_limiter);
    try std.testing.expect(!args.enable_staking);
    try std.testing.expect(!args.enable_latency);
    try std.testing.expect(!args.enable_rs_repair);
    try std.testing.expectEqual(@as(u16, 9100), args.metrics_port);
    // v1.9 fields
    try std.testing.expect(!args.enable_erasure_repair);
    try std.testing.expect(!args.enable_consensus);
    try std.testing.expect(!args.enable_delegation);
    // v2.0 fields
    try std.testing.expect(!args.enable_region_topology);
    try std.testing.expect(!args.enable_escrow);
    try std.testing.expect(!args.enable_prometheus_http);
    try std.testing.expect(!args.enable_semantic);
    try std.testing.expectEqual(@as(u16, 9090), args.prometheus_http_port);
    // v2.1 fields
    try std.testing.expect(!args.enable_http_api);
    try std.testing.expectEqual(@as(u16, 8080), args.http_api_port);
}

test "HKDF key derivation is deterministic" {
    const key1 = deriveEncryptionKeyHkdf("test_password");
    const key2 = deriveEncryptionKeyHkdf("test_password");
    try std.testing.expectEqualSlices(u8, &key1, &key2);
}

test "HKDF differs from SHA256" {
    const hkdf_key = deriveEncryptionKeyHkdf("test_password");
    const sha256_key = crypto.sha256("test_password");
    // HKDF output should differ from raw SHA256
    try std.testing.expect(!std.mem.eql(u8, &hkdf_key, &sha256_key));
}
