// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY NODE NETWORK - Main Network Layer
// TCP Job Server + UDP Discovery + Gossip Sync
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const protocol = @import("protocol.zig");
const discovery = @import("discovery.zig");
const wallet_mod = @import("wallet.zig");
const crypto = @import("crypto.zig");
const storage_mod = @import("storage.zig");
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
const network_stats_mod = @import("network_stats.zig");
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

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const JOB_PORT: u16 = 9334;
pub const MAX_CONNECTIONS: usize = 64;
pub const MAX_PENDING_JOBS: usize = 256;
pub const JOB_TIMEOUT_MS: u64 = 60000; // 1 minute

// ═══════════════════════════════════════════════════════════════════════════════
// NETWORK STATUS
// ═══════════════════════════════════════════════════════════════════════════════

pub const NetworkStatus = enum {
    disconnected,
    connecting,
    connected,
    syncing,
    ready,
};

// ═══════════════════════════════════════════════════════════════════════════════
// JOB QUEUE
// ═══════════════════════════════════════════════════════════════════════════════

pub const PendingJob = struct {
    job: protocol.InferenceJob,
    received_at: i64,
    client_addr: std.net.Address,
};

pub const JobQueue = struct {
    jobs: [MAX_PENDING_JOBS]?PendingJob,
    head: usize,
    tail: usize,
    count: usize,
    mutex: std.Thread.Mutex,

    pub fn init() JobQueue {
        return JobQueue{
            .jobs = [_]?PendingJob{null} ** MAX_PENDING_JOBS,
            .head = 0,
            .tail = 0,
            .count = 0,
            .mutex = .{},
        };
    }

    /// Push job to queue
    pub fn push(self: *JobQueue, job: PendingJob) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.count >= MAX_PENDING_JOBS) return false;

        self.jobs[self.tail] = job;
        self.tail = (self.tail + 1) % MAX_PENDING_JOBS;
        self.count += 1;
        return true;
    }

    /// Pop job from queue
    pub fn pop(self: *JobQueue) ?PendingJob {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.count == 0) return null;

        const job = self.jobs[self.head];
        self.jobs[self.head] = null;
        self.head = (self.head + 1) % MAX_PENDING_JOBS;
        self.count -= 1;
        return job;
    }

    /// Get queue size
    pub fn size(self: *JobQueue) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.count;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// NETWORK NODE
// ═══════════════════════════════════════════════════════════════════════════════

pub const NetworkNode = struct {
    allocator: std.mem.Allocator,
    wallet: *wallet_mod.Wallet,
    discovery_service: *discovery.DiscoveryService,
    job_queue: JobQueue,
    status: NetworkStatus,
    running: std.atomic.Value(bool),
    job_server_thread: ?std.Thread,
    job_server_socket: ?std.posix.socket_t,
    listen_port: u16,

    // Stats
    jobs_received: u64,
    jobs_completed: u64,
    jobs_failed: u64,
    start_time: i64,

    // Storage
    storage_provider: ?*storage_mod.StorageProvider,
    storage_peer_registry: ?*storage_discovery.StoragePeerRegistry,
    // v1.3: Remote storage distributor
    remote_distributor: ?*remote_storage.NetworkShardDistributor,
    // v1.4: Connection pool and manifest DHT
    connection_pool: ?*connection_pool_mod.ConnectionPool,
    manifest_dht: ?*manifest_dht_mod.ManifestDHT,

    // v1.5: Proof-of-Storage, Shard Rebalancer, Bandwidth Aggregator
    proof_of_storage: ?*proof_of_storage_mod.ProofOfStorageEngine,
    shard_rebalancer: ?*shard_rebalancer_mod.ShardRebalancer,
    bandwidth_aggregator: ?*bandwidth_aggregator_mod.BandwidthAggregator,

    // v1.6: Shard Scrubber, Node Reputation, Graceful Shutdown, Network Stats
    shard_scrubber: ?*shard_scrubber_mod.ShardScrubber,
    node_reputation: ?*node_reputation_mod.NodeReputationSystem,
    graceful_shutdown: ?*graceful_shutdown_mod.GracefulShutdownManager,
    network_stats_reporter: ?*network_stats_mod.NetworkStatsReporter,

    // v1.7: Auto-Repair, Incentive Slashing, Prometheus Metrics
    auto_repair: ?*auto_repair_mod.AutoRepairEngine,
    incentive_slashing: ?*incentive_slashing_mod.IncentiveSlashingEngine,
    prometheus_exporter: ?*prometheus_metrics_mod.PrometheusExporter,

    // v1.8: Rate-Limited Repair, Token Staking, Latency-Aware Peers, RS Repair, Metrics HTTP
    repair_rate_limiter: ?*repair_rate_limiter_mod.RepairRateLimiter,
    token_staking: ?*token_staking_mod.TokenStakingEngine,
    peer_latency: ?*peer_latency_mod.PeerLatencyTracker,
    rs_repair: ?*rs_repair_mod.RsRepairEngine,
    metrics_http: ?*metrics_http_mod.MetricsHttpServer,

    // v1.9: Erasure Repair, Reputation Consensus, Stake Delegation
    erasure_repair: ?*erasure_repair_mod.ErasureRepairEngine,
    reputation_consensus: ?*reputation_consensus_mod.ReputationConsensus,
    stake_delegation: ?*stake_delegation_mod.StakeDelegationEngine,

    // v2.0: Region Topology, Slashing Escrow, Prometheus HTTP, Semantic VSA
    region_topology: ?*region_topology_mod.RegionTopology,
    slashing_escrow: ?*slashing_escrow_mod.SlashingEscrow,
    prometheus_http_endpoint: ?*prometheus_http_mod.PrometheusHttpEndpoint,
    vsa_encoder: ?*vsa_shard_encoder_mod.VsaShardEncoder,
    semantic_index: ?*semantic_index_mod.SemanticIndex,

    // Callbacks
    on_job_received: ?*const fn (*NetworkNode, protocol.InferenceJob) void,

    pub fn init(allocator: std.mem.Allocator, wallet: *wallet_mod.Wallet, listen_port: u16) !*NetworkNode {
        const self = try allocator.create(NetworkNode);
        errdefer allocator.destroy(self);

        // Initialize discovery service
        const disc = try discovery.DiscoveryService.init(
            allocator,
            wallet.getNodeId(),
            wallet.getPublicKey(),
            listen_port,
        );
        errdefer disc.deinit();

        self.* = NetworkNode{
            .allocator = allocator,
            .wallet = wallet,
            .discovery_service = disc,
            .job_queue = JobQueue.init(),
            .status = .disconnected,
            .running = std.atomic.Value(bool).init(false),
            .job_server_thread = null,
            .job_server_socket = null,
            .listen_port = listen_port,
            .jobs_received = 0,
            .jobs_completed = 0,
            .jobs_failed = 0,
            .start_time = 0,
            .storage_provider = null,
            .storage_peer_registry = null,
            .remote_distributor = null,
            .connection_pool = null,
            .manifest_dht = null,
            .proof_of_storage = null,
            .shard_rebalancer = null,
            .bandwidth_aggregator = null,
            .shard_scrubber = null,
            .node_reputation = null,
            .graceful_shutdown = null,
            .network_stats_reporter = null,
            .auto_repair = null,
            .incentive_slashing = null,
            .prometheus_exporter = null,
            .repair_rate_limiter = null,
            .token_staking = null,
            .peer_latency = null,
            .rs_repair = null,
            .metrics_http = null,
            .erasure_repair = null,
            .reputation_consensus = null,
            .stake_delegation = null,
            .region_topology = null,
            .slashing_escrow = null,
            .prometheus_http_endpoint = null,
            .vsa_encoder = null,
            .semantic_index = null,
            .on_job_received = null,
        };

        return self;
    }

    pub fn deinit(self: *NetworkNode) void {
        self.stop();
        self.discovery_service.deinit();
        self.allocator.destroy(self);
    }

    /// Start network node
    pub fn start(self: *NetworkNode) !void {
        if (self.running.load(.acquire)) return;

        self.running.store(true, .release);
        self.status = .connecting;
        self.start_time = std.time.timestamp();

        // Start discovery
        try self.discovery_service.start();

        // Start TCP job server
        try self.startJobServer();

        self.status = .ready;
    }

    /// Stop network node
    pub fn stop(self: *NetworkNode) void {
        self.running.store(false, .release);
        self.status = .disconnected;

        // Stop discovery
        self.discovery_service.stop();

        // Stop job server
        if (self.job_server_socket) |sock| {
            std.posix.close(sock);
            self.job_server_socket = null;
        }

        if (self.job_server_thread) |thread| {
            thread.join();
            self.job_server_thread = null;
        }
    }

    /// Start TCP job server
    fn startJobServer(self: *NetworkNode) !void {
        // Create TCP socket
        const sock = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.STREAM, 0);
        errdefer std.posix.close(sock);

        // Enable address reuse
        const reuse: i32 = 1;
        try std.posix.setsockopt(sock, std.posix.SOL.SOCKET, std.posix.SO.REUSEADDR, std.mem.asBytes(&reuse));

        // Bind to job port
        const addr = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, self.listen_port);
        try std.posix.bind(sock, &addr.any, addr.getOsSockLen());

        // Listen
        try std.posix.listen(sock, 10);

        self.job_server_socket = sock;
        self.job_server_thread = try std.Thread.spawn(.{}, jobServerLoop, .{self});
    }

    /// Job server loop - accepts connections and receives jobs
    fn jobServerLoop(self: *NetworkNode) void {
        const sock = self.job_server_socket orelse return;

        while (self.running.load(.acquire)) {
            var client_addr: std.posix.sockaddr = undefined;
            var addr_len: std.posix.socklen_t = @sizeOf(std.posix.sockaddr);

            const client_sock = std.posix.accept(sock, &client_addr, &addr_len, 0) catch |err| {
                if (err == error.WouldBlock) continue;
                break;
            };
            defer std.posix.close(client_sock);

            // Handle connection
            self.handleConnection(client_sock, std.net.Address{ .any = client_addr }) catch {};
        }
    }

    /// Handle incoming connection
    fn handleConnection(self: *NetworkNode, sock: std.posix.socket_t, client_addr: std.net.Address) !void {
        var buf: [65536]u8 = undefined;

        // Read message header
        var header_buf: [protocol.MessageHeader.SIZE]u8 = undefined;
        const header_len = try std.posix.recv(sock, &header_buf, 0);
        if (header_len != protocol.MessageHeader.SIZE) return;

        const header = try protocol.MessageHeader.deserialize(&header_buf);

        // Read payload
        if (header.length > buf.len) return error.PayloadTooLarge;
        const payload_len = try std.posix.recv(sock, buf[0..header.length], 0);
        if (payload_len != header.length) return;

        // Handle message by type
        switch (header.msg_type) {
            .job_request => {
                const job = try protocol.InferenceJob.deserialize(buf[0..payload_len], self.allocator);
                self.jobs_received += 1;

                // Add to queue
                const pending = PendingJob{
                    .job = job,
                    .received_at = std.time.timestamp(),
                    .client_addr = client_addr,
                };
                _ = self.job_queue.push(pending);

                // Call callback if set
                if (self.on_job_received) |cb| {
                    cb(self, job);
                }
            },
            .heartbeat => {
                // Respond with our heartbeat
                const hb = protocol.Heartbeat{
                    .node_id = self.wallet.getNodeId(),
                    .timestamp = std.time.timestamp(),
                    .jobs_completed = self.jobs_completed,
                    .uptime_seconds = @intCast(std.time.timestamp() - self.start_time),
                    .status = if (self.job_queue.size() > 0) .busy else .online,
                };
                const payload = try hb.serialize(self.allocator);
                defer self.allocator.free(payload);

                const resp_header = protocol.MessageHeader{
                    .msg_type = .heartbeat,
                    .length = @intCast(payload.len),
                };
                _ = try std.posix.send(sock, &resp_header.serialize(), 0);
                _ = try std.posix.send(sock, payload, 0);
            },
            .store_request => {
                if (self.storage_provider) |sp| {
                    const req = protocol.StoreRequest.deserialize(buf[0..payload_len], self.allocator) catch return;
                    defer self.allocator.free(req.data);
                    const resp = sp.handleStoreRequest(req, self.wallet.getNodeId()) catch return;
                    const resp_bytes = resp.serialize();
                    const resp_header = protocol.MessageHeader{
                        .msg_type = .store_response,
                        .length = @intCast(resp_bytes.len),
                    };
                    _ = std.posix.send(sock, &resp_header.serialize(), 0) catch return;
                    _ = std.posix.send(sock, &resp_bytes, 0) catch return;
                }
            },
            .retrieve_request => {
                if (self.storage_provider) |sp| {
                    const req = protocol.RetrieveRequest.deserialize(buf[0..payload_len]) catch return;
                    const resp = sp.handleRetrieveRequest(req);
                    const resp_bytes = resp.serialize(self.allocator) catch return;
                    defer self.allocator.free(resp_bytes);
                    const resp_header = protocol.MessageHeader{
                        .msg_type = .retrieve_response,
                        .length = @intCast(resp_bytes.len),
                    };
                    _ = std.posix.send(sock, &resp_header.serialize(), 0) catch return;
                    _ = std.posix.send(sock, resp_bytes, 0) catch return;
                }
            },
            .storage_announce => {
                // Parse and track storage capacity from peer
                const announce = protocol.StorageAnnounce.deserialize(buf[0..payload_len]) catch return;
                if (self.storage_peer_registry) |registry| {
                    registry.updateFromAnnounce(announce, client_addr);
                }
            },
            .manifest_store => {
                // v1.4: Handle incoming manifest store
                if (self.manifest_dht) |dht| {
                    const msg = protocol.ManifestStoreMessage.deserialize(buf[0..payload_len], self.allocator) catch return;
                    defer self.allocator.free(msg.data);
                    dht.handleManifestStore(msg.file_id, msg.data) catch {};
                }
            },
            .manifest_retrieve_request => {
                // v1.4: Handle manifest retrieve request
                if (self.manifest_dht) |dht| {
                    const req = protocol.ManifestRetrieveRequest.deserialize(buf[0..payload_len]) catch return;
                    const data = dht.handleManifestRetrieve(req.file_id);
                    const resp = protocol.ManifestRetrieveResponse{
                        .file_id = req.file_id,
                        .found = data != null,
                        .data = data orelse "",
                    };
                    const resp_bytes = resp.serialize(self.allocator) catch return;
                    defer self.allocator.free(resp_bytes);
                    const resp_header = protocol.MessageHeader{
                        .msg_type = .manifest_retrieve_response,
                        .length = @intCast(resp_bytes.len),
                    };
                    _ = std.posix.send(sock, &resp_header.serialize(), 0) catch return;
                    _ = std.posix.send(sock, resp_bytes, 0) catch return;
                }
            },
            .storage_challenge => {
                // v1.5: Handle incoming storage challenge
                if (self.storage_provider) |sp| {
                    const challenge = protocol.StorageChallengeMsg.deserialize(buf[0..payload_len]) catch return;
                    const proof = proof_of_storage_mod.ProofOfStorageEngine.respondToChallenge(
                        challenge,
                        sp,
                        self.wallet.getNodeId(),
                    ) catch return;
                    const proof_bytes = proof.serialize();
                    const resp_header = protocol.MessageHeader{
                        .msg_type = .storage_proof,
                        .length = @intCast(proof_bytes.len),
                    };
                    _ = std.posix.send(sock, &resp_header.serialize(), 0) catch return;
                    _ = std.posix.send(sock, &proof_bytes, 0) catch return;
                }
            },
            .storage_proof => {
                // v1.5: Handle incoming storage proof
                if (self.proof_of_storage) |pos| {
                    if (self.storage_provider) |sp| {
                        const proof = protocol.StorageProofMsg.deserialize(buf[0..payload_len]) catch return;
                        const valid = pos.verifyProof(proof, sp) catch return;
                        if (!valid) {
                            // Mark peer as unreliable if proof failed
                            if (self.storage_peer_registry) |registry| {
                                if (pos.isUnreliable(proof.prover_id)) {
                                    registry.markUnreliable(proof.prover_id);
                                }
                            }
                        }
                    }
                }
            },
            .bandwidth_report => {
                // v1.5: Handle incoming bandwidth report
                if (self.bandwidth_aggregator) |agg| {
                    const msg = protocol.BandwidthReportMsg.deserialize(buf[0..payload_len]) catch return;
                    agg.recordReport(.{
                        .node_id = msg.node_id,
                        .bytes_uploaded = msg.bytes_uploaded,
                        .bytes_downloaded = msg.bytes_downloaded,
                        .shards_hosted = msg.shards_hosted,
                        .period_start = msg.period_start,
                        .period_end = msg.period_end,
                    });
                }
            },
            .shard_scrub_report => {
                // v1.6: Handle incoming shard scrub report
                _ = protocol.ShardScrubReportMsg.deserialize(buf[0..payload_len]) catch return;
                // Log/track scrub reports from peers (informational)
            },
            .reputation_query => {
                // v1.6: Handle reputation query
                if (self.node_reputation) |rep| {
                    const query = protocol.ReputationQueryMsg.deserialize(buf[0..payload_len]) catch return;
                    const score = rep.getScore(query.target_node_id);
                    const resp = protocol.ReputationResponseMsg{
                        .node_id = query.target_node_id,
                        .score_millionths = @intFromFloat(score.score * 1_000_000.0),
                        .pos_score_millionths = @intFromFloat(score.pos_score * 1_000_000.0),
                        .uptime_score_millionths = @intFromFloat(score.uptime_score * 1_000_000.0),
                        .bandwidth_score_millionths = @intFromFloat(score.bandwidth_score * 1_000_000.0),
                    };
                    const resp_bytes = resp.serialize();
                    const resp_header = protocol.MessageHeader{
                        .msg_type = .reputation_response,
                        .length = @intCast(resp_bytes.len),
                    };
                    _ = std.posix.send(sock, &resp_header.serialize(), 0) catch return;
                    _ = std.posix.send(sock, &resp_bytes, 0) catch return;
                }
            },
            .graceful_shutdown_announce => {
                // v1.6: Handle graceful shutdown announcement from departing peer
                if (self.shard_rebalancer) |rebalancer| {
                    const msg = protocol.GracefulShutdownMsg.deserialize(buf[0..payload_len]) catch return;
                    _ = rebalancer.removeNode(msg.node_id);
                    // Trigger rebalance on next poll cycle
                    rebalancer.last_rebalance_time = 0;
                }
            },
            .shard_repair_request => {
                // v1.7: Handle shard repair request — respond with shard data if we have it
                if (self.storage_provider) |sp| {
                    const req = protocol.ShardRepairRequestMsg.deserialize(buf[0..payload_len]) catch return;
                    const shard_data = sp.retrieveShard(req.shard_hash);
                    const resp = protocol.ShardRepairResponseMsg{
                        .responder_id = self.wallet.getNodeId(),
                        .shard_hash = req.shard_hash,
                        .success = shard_data != null,
                        .data_length = if (shard_data) |d| @intCast(d.len) else 0,
                    };
                    const resp_bytes = resp.serialize();
                    const resp_header = protocol.MessageHeader{
                        .msg_type = .shard_repair_response,
                        .length = @intCast(resp_bytes.len),
                    };
                    _ = std.posix.send(sock, &resp_header.serialize(), 0) catch return;
                    _ = std.posix.send(sock, &resp_bytes, 0) catch return;
                    // Send actual shard data after header
                    if (shard_data) |d| {
                        _ = std.posix.send(sock, d, 0) catch return;
                    }
                }
            },
            .shard_repair_response => {
                // v1.7: Handle repair response (informational — actual repair uses direct peer access)
                _ = protocol.ShardRepairResponseMsg.deserialize(buf[0..payload_len]) catch return;
            },
            .slash_event => {
                // v1.7: Handle incoming slash event notification
                _ = protocol.SlashEventMsg.deserialize(buf[0..payload_len]) catch return;
                // Log slash event for monitoring
            },
            .staking_request => {
                // v1.8: Handle staking request
                if (self.token_staking) |staking| {
                    const req = protocol.StakingRequestMsg.deserialize(buf[0..payload_len]) catch return;
                    const result: ?token_staking_mod.StakeResult = switch (req.action) {
                        .stake => staking.stake(req.node_id, req.amount_wei),
                        .unstake => staking.unstake(req.node_id),
                        else => null,
                    };
                    const resp = protocol.StakingResponseMsg{
                        .node_id = req.node_id,
                        .new_balance_wei = if (result) |r| r.staked_wei else 0,
                        .success = if (result) |r| r.success else false,
                        .reason = .ok,
                        .timestamp = std.time.timestamp(),
                    };
                    const resp_bytes = resp.serialize();
                    const resp_header = protocol.MessageHeader{
                        .msg_type = .staking_response,
                        .length = @intCast(resp_bytes.len),
                    };
                    _ = std.posix.send(sock, &resp_header.serialize(), 0) catch return;
                    _ = std.posix.send(sock, &resp_bytes, 0) catch return;
                }
            },
            .staking_response => {
                // v1.8: Handle staking response (informational)
                _ = protocol.StakingResponseMsg.deserialize(buf[0..payload_len]) catch return;
            },
            .latency_ping => {
                // v1.8: Handle latency ping — respond with pong
                const ping = protocol.LatencyPingMsg.deserialize(buf[0..payload_len]) catch return;
                if (!ping.is_reply) {
                    // Send pong back
                    const pong = protocol.LatencyPingMsg{
                        .sender_id = self.wallet.getNodeId(),
                        .target_id = ping.sender_id,
                        .send_timestamp_ns = ping.send_timestamp_ns,
                        .is_reply = true,
                    };
                    const pong_bytes = pong.serialize();
                    const pong_header = protocol.MessageHeader{
                        .msg_type = .latency_ping,
                        .length = @intCast(pong_bytes.len),
                    };
                    _ = std.posix.send(sock, &pong_header.serialize(), 0) catch return;
                    _ = std.posix.send(sock, &pong_bytes, 0) catch return;
                } else {
                    // Record latency from pong
                    if (self.peer_latency) |tracker| {
                        const now_i128 = std.time.nanoTimestamp();
                        if (now_i128 > 0) {
                            const now_ns: u64 = @intCast(@as(u128, @intCast(now_i128)));
                            if (now_ns > ping.send_timestamp_ns) {
                                tracker.recordLatency(ping.sender_id, now_ns - ping.send_timestamp_ns);
                            }
                        }
                    }
                }
            },
            .consensus_vote => {
                // v1.9: Handle reputation consensus vote
                if (self.reputation_consensus) |consensus| {
                    const vote = protocol.ConsensusVoteMsg.deserialize(buf[0..payload_len]) catch return;
                    consensus.submitVote(vote.voter_id, vote.target_id, vote.score) catch {};
                }
            },
            .consensus_result => {
                // v1.9: Handle consensus result (informational)
                _ = protocol.ConsensusResultMsg.deserialize(buf[0..payload_len]) catch return;
            },
            .delegation_request => {
                // v1.9: Handle stake delegation request
                if (self.stake_delegation) |delegation| {
                    const req = protocol.DelegationRequestMsg.deserialize(buf[0..payload_len]) catch return;
                    switch (req.action) {
                        .delegate => {
                            _ = delegation.delegate(req.delegator_id, req.operator_id, req.amount_wei);
                        },
                        .undelegate => {
                            _ = delegation.undelegate(req.delegator_id);
                        },
                        .register_operator => {
                            delegation.registerOperator(req.operator_id, 0.10) catch {};
                        },
                        _ => {},
                    }
                }
            },
            .region_placement => {
                // v2.0: Handle region placement — register node in geo-region
                if (self.region_topology) |topo| {
                    const msg = protocol.RegionPlacementMsg.deserialize(buf[0..payload_len]) catch return;
                    const region: region_topology_mod.Region = @enumFromInt(msg.region);
                    topo.registerNode(msg.node_id, region) catch {};
                }
            },
            .escrow_event => {
                // v2.0: Handle slashing escrow events
                if (self.slashing_escrow) |escrow| {
                    const msg = protocol.EscrowEventMsg.deserialize(buf[0..payload_len]) catch return;
                    switch (msg.action) {
                        .create => {
                            const reason: slashing_escrow_mod.SlashReason = @enumFromInt(msg.reason);
                            _ = escrow.createEscrow(msg.node_id, msg.amount_wei, reason, @intCast(msg.timestamp)) catch {};
                        },
                        .dispute => {
                            _ = escrow.fileDispute(msg.escrow_id, msg.node_id, @intCast(msg.timestamp));
                        },
                        .vote => {
                            _ = escrow.vote(msg.escrow_id, msg.node_id, true, @intCast(msg.timestamp)) catch {};
                        },
                        .resolve => {
                            _ = escrow.resolveEscrow(msg.escrow_id, @intCast(msg.timestamp));
                        },
                        _ => {},
                    }
                }
            },
            .prometheus_scrape => {
                // v2.0: Handle Prometheus scrape request — respond with metrics
                _ = protocol.PrometheusScrapeMsg.deserialize(buf[0..payload_len]) catch return;
                if (self.prometheus_http_endpoint) |endpoint| {
                    const stats = endpoint.getStats();
                    _ = stats; // Metrics served via HTTP endpoint, not TCP
                }
            },
            .semantic_store => {
                // v2.0: Handle semantic fingerprint store — index shard in semantic index
                if (self.semantic_index) |idx| {
                    if (self.vsa_encoder) |encoder| {
                        const msg = protocol.SemanticStoreMsg.deserialize(buf[0..payload_len]) catch return;
                        // Unpack fingerprint from packed bytes into Hypervector
                        var fp = vsa_shard_encoder_mod.Hypervector.zero(256);
                        for (0..@min(64, fp.dim)) |i| {
                            const byte_val = msg.fingerprint_packed[i];
                            // Decode: 0=0, 1=+1, 2=-1
                            fp.trits[i] = if (byte_val == 1) 1 else if (byte_val == 2) @as(vsa_shard_encoder_mod.Trit, -1) else 0;
                        }
                        _ = encoder; // Encoder not needed for pre-computed fingerprint
                        idx.indexShardWithFingerprint(msg.shard_hash, fp) catch {};
                    }
                }
            },
            .semantic_query => {
                // v2.0: Handle semantic query — search for similar shards
                if (self.semantic_index) |idx| {
                    const msg = protocol.SemanticQueryMsg.deserialize(buf[0..payload_len]) catch return;
                    const threshold: f64 = @bitCast(msg.threshold_bits);
                    const max_results: usize = @intCast(msg.max_results);
                    const results = idx.searchByContent(
                        &msg.query_fingerprint_packed,
                        threshold,
                        max_results,
                    ) catch return;
                    defer self.allocator.free(results);
                    // Results are available; in production would serialize and send back
                }
            },
            else => {},
        }
    }

    /// Get next pending job
    pub fn getNextJob(self: *NetworkNode) ?PendingJob {
        return self.job_queue.pop();
    }

    /// Submit job result
    pub fn submitResult(self: *NetworkNode, result: protocol.InferenceResult) !void {
        // Find client peer by node ID
        const peer = self.discovery_service.peers.getPeer(result.worker_id) orelse return error.PeerNotFound;

        // Connect to peer
        const sock = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.STREAM, 0);
        defer std.posix.close(sock);

        try std.posix.connect(sock, &peer.address.any, peer.address.getOsSockLen());

        // Send result
        const payload = try result.serialize(self.allocator);
        defer self.allocator.free(payload);

        const header = protocol.MessageHeader{
            .msg_type = .job_response,
            .length = @intCast(payload.len),
        };

        _ = try std.posix.send(sock, &header.serialize(), 0);
        _ = try std.posix.send(sock, payload, 0);

        self.jobs_completed += 1;
    }

    /// Broadcast storage capacity to network
    pub fn broadcastStorageAnnounce(self: *NetworkNode) !void {
        const sp = self.storage_provider orelse return;
        const stats = sp.getStats();

        const announce = protocol.StorageAnnounce{
            .node_id = self.wallet.getNodeId(),
            .available_bytes = stats.available_bytes,
            .total_bytes = stats.max_bytes,
            .shard_count = stats.total_shards,
            .timestamp = std.time.timestamp(),
        };

        const payload = announce.serialize();

        const header = protocol.MessageHeader{
            .msg_type = .storage_announce,
            .length = @intCast(payload.len),
        };

        // Send to all known peers
        const peers = try self.discovery_service.getAlivePeers();
        defer self.allocator.free(peers);

        for (peers) |peer| {
            const sock = std.posix.socket(std.posix.AF.INET, std.posix.SOCK.STREAM, 0) catch continue;
            defer std.posix.close(sock);

            std.posix.connect(sock, &peer.address.any, peer.address.getOsSockLen()) catch continue;

            _ = std.posix.send(sock, &header.serialize(), 0) catch continue;
            _ = std.posix.send(sock, &payload, 0) catch continue;
        }
    }

    /// Broadcast capabilities to network
    pub fn broadcastCapabilities(self: *NetworkNode, capabilities: protocol.NodeCapabilities) !void {
        const payload = try capabilities.serialize(self.allocator);
        defer self.allocator.free(payload);

        const header = protocol.MessageHeader{
            .msg_type = .capabilities,
            .length = @intCast(payload.len),
        };

        // Send to all known peers
        const peers = try self.discovery_service.getAlivePeers();
        defer self.allocator.free(peers);

        for (peers) |peer| {
            const sock = std.posix.socket(std.posix.AF.INET, std.posix.SOCK.STREAM, 0) catch continue;
            defer std.posix.close(sock);

            std.posix.connect(sock, &peer.address.any, peer.address.getOsSockLen()) catch continue;

            _ = std.posix.send(sock, &header.serialize(), 0) catch continue;
            _ = std.posix.send(sock, payload, 0) catch continue;
        }
    }

    /// Get network stats
    pub fn getStats(self: *NetworkNode) NetworkStats {
        const uptime = if (self.start_time > 0)
            @as(u64, @intCast(std.time.timestamp() - self.start_time))
        else
            0;

        return NetworkStats{
            .status = self.status,
            .peer_count = self.discovery_service.getPeerCount(),
            .jobs_received = self.jobs_received,
            .jobs_completed = self.jobs_completed,
            .jobs_failed = self.jobs_failed,
            .pending_jobs = self.job_queue.size(),
            .uptime_seconds = uptime,
        };
    }

    /// Poll for network events (non-blocking)
    pub fn poll(self: *NetworkNode) void {
        // Prune dead peers periodically
        _ = self.discovery_service.peers.pruneDeadPeers();

        // Prune stale storage peers
        if (self.storage_peer_registry) |registry| {
            _ = registry.pruneStale();
        }

        // v1.4: Prune idle connections
        if (self.connection_pool) |pool| {
            _ = pool.pruneIdle();
        }

        // v1.5: Proof-of-Storage challenge rounds
        if (self.proof_of_storage) |pos| {
            if (pos.shouldChallenge()) {
                // Challenge logic would be invoked here in production
                // (requires iterating storage_peer_registry + shard hashes)
                pos.last_challenge_time = std.time.timestamp();
            }
        }

        // v1.5: Shard rebalancing
        if (self.shard_rebalancer) |rebalancer| {
            if (rebalancer.shouldRebalance()) {
                // Rebalance logic would be invoked here in production
                rebalancer.last_rebalance_time = std.time.timestamp();
            }
        }

        // v1.5: Bandwidth aggregation
        if (self.bandwidth_aggregator) |agg| {
            if (agg.shouldAggregate()) {
                _ = agg.aggregate();
            }
        }

        // v1.6: Periodic shard scrubbing
        if (self.shard_scrubber) |scrubber| {
            if (scrubber.shouldScrub()) {
                if (self.storage_provider) |sp| {
                    _ = scrubber.scrubNode(sp);
                }
            }
        }

        // v1.7: Auto-repair after scrub detects corruption
        if (self.auto_repair) |_| {
            if (self.shard_scrubber) |scrub| {
                const scrub_stats = scrub.getStats();
                if (scrub_stats.corruptions_found > 0) {
                    // In production, would call repair.repairFromScrub(scrub, local_idx, peers)
                    // Requires peer array — handled by higher-level orchestration
                }
            }
        }

        // v1.6: Update reputation scores for peers
        if (self.node_reputation) |rep| {
            // v1.7: Apply reputation decay
            if (rep.decay_enabled) {
                _ = rep.getScoreAtTime([_]u8{0} ** 32, std.time.timestamp());
            }

            if (self.storage_peer_registry) |registry| {
                var iter = registry.peers.iterator();
                while (iter.next()) |entry| {
                    const score = rep.getScore(entry.key_ptr.*);
                    registry.updateReputation(entry.key_ptr.*, score.score);
                }
            }
        }

        // v1.8: Rate-limited repair (replaces raw auto-repair when enabled)
        if (self.repair_rate_limiter) |limiter| {
            if (limiter.canRepair()) {
                if (self.shard_scrubber) |scrub2| {
                    const scrub2_stats = scrub2.getStats();
                    if (scrub2_stats.corruptions_found > 0) {
                        // In production, would call limiter.throttledRepair(scrub2, local_idx, peers)
                        // Requires peer array — handled by higher-level orchestration
                    }
                }
            }
        }

        // v2.0: Region topology — resolve expired escrows periodically
        if (self.slashing_escrow) |escrow| {
            // Try resolving up to 10 pending escrows per poll
            var esc_id: u64 = 1;
            while (esc_id < 100) : (esc_id += 1) {
                _ = escrow.resolveEscrow(esc_id, std.time.timestamp());
            }
        }

        // v1.5: Update discovery service with current storage info
        if (self.storage_provider) |sp| {
            const stats = sp.getStats();
            self.discovery_service.setStorageInfo(
                stats.available_bytes,
                stats.max_bytes,
                stats.total_shards,
            );
        }
    }

    /// Find storage peers with at least min_bytes available
    pub fn findStoragePeers(self: *NetworkNode, min_bytes: u64) ![]storage_discovery.StoragePeerInfo {
        if (self.storage_peer_registry) |registry| {
            return registry.findPeersWithCapacity(min_bytes, self.allocator);
        }
        return self.allocator.alloc(storage_discovery.StoragePeerInfo, 0);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// NETWORK STATS
// ═══════════════════════════════════════════════════════════════════════════════

pub const NetworkStats = struct {
    status: NetworkStatus,
    peer_count: usize,
    jobs_received: u64,
    jobs_completed: u64,
    jobs_failed: u64,
    pending_jobs: usize,
    uptime_seconds: u64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "job queue operations" {
    var queue = JobQueue.init();

    const job = PendingJob{
        .job = undefined,
        .received_at = std.time.timestamp(),
        .client_addr = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 9334),
    };

    try std.testing.expect(queue.push(job));
    try std.testing.expectEqual(@as(usize, 1), queue.size());

    const popped = queue.pop();
    try std.testing.expect(popped != null);
    try std.testing.expectEqual(@as(usize, 0), queue.size());
}

test "v2.0 module imports compile" {
    // Verify all v2.0 module types are accessible
    _ = region_topology_mod.RegionTopology;
    _ = slashing_escrow_mod.SlashingEscrow;
    _ = prometheus_http_mod.PrometheusHttpEndpoint;
    _ = vsa_shard_encoder_mod.VsaShardEncoder;
    _ = semantic_index_mod.SemanticIndex;
}

test "v2.0 protocol message types exist" {
    // Verify v2.0 message types are wired
    try std.testing.expectEqual(@as(u8, 0x39), @intFromEnum(protocol.MessageType.region_placement));
    try std.testing.expectEqual(@as(u8, 0x3A), @intFromEnum(protocol.MessageType.escrow_event));
    try std.testing.expectEqual(@as(u8, 0x3B), @intFromEnum(protocol.MessageType.prometheus_scrape));
    try std.testing.expectEqual(@as(u8, 0x3C), @intFromEnum(protocol.MessageType.semantic_store));
    try std.testing.expectEqual(@as(u8, 0x3D), @intFromEnum(protocol.MessageType.semantic_query));
}
