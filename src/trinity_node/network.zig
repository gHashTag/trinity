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
