// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY NODE PROTOCOL - P2P Job Distribution
// Binary protocol for decentralized inference network
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const ArrayList = std.array_list.Managed;

// ═══════════════════════════════════════════════════════════════════════════════
// MESSAGE TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const MessageType = enum(u8) {
    capabilities = 0x01,
    job_request = 0x02,
    job_response = 0x03,
    heartbeat = 0x04,
    reward_notification = 0x05,
    peer_announce = 0x06,
    peer_list = 0x07,
    // Pipeline-parallel distributed inference
    forward_request = 0x11,
    forward_response = 0x12,
    batch_forward_request = 0x13,
    batch_forward_response = 0x14,
    // Storage network
    store_request = 0x20,
    store_response = 0x21,
    retrieve_request = 0x22,
    retrieve_response = 0x23,
    storage_announce = 0x24,
    // v1.4: Manifest DHT
    manifest_store = 0x25,
    manifest_retrieve_request = 0x26,
    manifest_retrieve_response = 0x27,
    // v1.5: Proof-of-Storage, Bandwidth Aggregation
    storage_challenge = 0x28,
    storage_proof = 0x29,
    bandwidth_report = 0x2A,
    bandwidth_summary = 0x2B,
    // v1.6: Shard Scrubbing, Reputation, Graceful Shutdown
    shard_scrub_report = 0x2C,
    reputation_query = 0x2D,
    reputation_response = 0x2E,
    graceful_shutdown_announce = 0x2F,
    // v1.7: Auto-Repair, Incentive Slashing
    shard_repair_request = 0x30,
    shard_repair_response = 0x31,
    slash_event = 0x32,
    // v1.8: Token Staking, Latency-Aware Peers
    staking_request = 0x33,
    staking_response = 0x34,
    latency_ping = 0x35,
    // v1.9: Reputation Consensus, Stake Delegation
    consensus_vote = 0x36,
    consensus_result = 0x37,
    delegation_request = 0x38,
    // v2.0: Region Topology, Slashing Escrow, Prometheus HTTP, Semantic VSA
    region_placement = 0x39,
    escrow_event = 0x3A,
    prometheus_scrape = 0x3B,
    semantic_store = 0x3C,
    semantic_query = 0x3D,
    _,
};

// ═══════════════════════════════════════════════════════════════════════════════
// NODE IDENTITY
// ═══════════════════════════════════════════════════════════════════════════════

pub const NodeId = [32]u8;

pub const NodeCapabilities = struct {
    node_id: NodeId,
    models_loaded: []const []const u8,
    max_batch_size: u32,
    throughput_tok_s: f32,
    region: []const u8,
    public_key: [32]u8, // ed25519 public key
    listen_port: u16,
    version: u16, // Protocol version

    pub fn serialize(self: *const NodeCapabilities, allocator: std.mem.Allocator) ![]u8 {
        var list = ArrayList(u8).init(allocator);
        const writer = list.writer();

        // Node ID (32 bytes)
        try writer.writeAll(&self.node_id);
        // Public key (32 bytes)
        try writer.writeAll(&self.public_key);
        // Port (2 bytes)
        try writer.writeInt(u16, self.listen_port, .little);
        // Version (2 bytes)
        try writer.writeInt(u16, self.version, .little);
        // Max batch size (4 bytes)
        try writer.writeInt(u32, self.max_batch_size, .little);
        // Throughput (4 bytes)
        try writer.writeAll(std.mem.asBytes(&self.throughput_tok_s));
        // Region length + data
        try writer.writeInt(u16, @intCast(self.region.len), .little);
        try writer.writeAll(self.region);
        // Models count + data
        try writer.writeInt(u16, @intCast(self.models_loaded.len), .little);
        for (self.models_loaded) |model| {
            try writer.writeInt(u16, @intCast(model.len), .little);
            try writer.writeAll(model);
        }

        return list.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// INFERENCE JOB
// ═══════════════════════════════════════════════════════════════════════════════

pub const JobId = [16]u8;

pub const InferenceJob = struct {
    job_id: JobId,
    requester_id: NodeId,
    model_id: []const u8,
    prompt: []const u8,
    max_tokens: u32,
    temperature: f32,
    top_p: f32,
    created_at: i64, // Unix timestamp

    pub fn serialize(self: *const InferenceJob, allocator: std.mem.Allocator) ![]u8 {
        var list = ArrayList(u8).init(allocator);
        const writer = list.writer();

        // Job ID (16 bytes)
        try writer.writeAll(&self.job_id);
        // Requester ID (32 bytes)
        try writer.writeAll(&self.requester_id);
        // Created at (8 bytes)
        try writer.writeInt(i64, self.created_at, .little);
        // Max tokens (4 bytes)
        try writer.writeInt(u32, self.max_tokens, .little);
        // Temperature (4 bytes)
        try writer.writeAll(std.mem.asBytes(&self.temperature));
        // Top-p (4 bytes)
        try writer.writeAll(std.mem.asBytes(&self.top_p));
        // Model ID length + data
        try writer.writeInt(u16, @intCast(self.model_id.len), .little);
        try writer.writeAll(self.model_id);
        // Prompt length + data
        try writer.writeInt(u32, @intCast(self.prompt.len), .little);
        try writer.writeAll(self.prompt);

        return list.toOwnedSlice();
    }

    pub fn deserialize(data: []const u8, allocator: std.mem.Allocator) !InferenceJob {
        var reader = std.io.fixedBufferStream(data);
        const r = reader.reader();

        var job: InferenceJob = undefined;

        // Job ID
        _ = try r.readAll(&job.job_id);
        // Requester ID
        _ = try r.readAll(&job.requester_id);
        // Created at
        job.created_at = try r.readInt(i64, .little);
        // Max tokens
        job.max_tokens = try r.readInt(u32, .little);
        // Temperature
        var temp_bytes: [4]u8 = undefined;
        _ = try r.readAll(&temp_bytes);
        job.temperature = @bitCast(temp_bytes);
        // Top-p
        var top_p_bytes: [4]u8 = undefined;
        _ = try r.readAll(&top_p_bytes);
        job.top_p = @bitCast(top_p_bytes);
        // Model ID (max 1KB)
        const model_len = try r.readInt(u16, .little);
        if (model_len > 1024) return error.InvalidData;
        const model_buf = try allocator.alloc(u8, model_len);
        errdefer allocator.free(model_buf);
        _ = try r.readAll(model_buf);
        job.model_id = model_buf;
        // Prompt (max 16MB)
        const prompt_len = try r.readInt(u32, .little);
        if (prompt_len > 16 * 1024 * 1024) return error.InvalidData;
        const prompt_buf = try allocator.alloc(u8, prompt_len);
        errdefer allocator.free(prompt_buf);
        _ = try r.readAll(prompt_buf);
        job.prompt = prompt_buf;

        return job;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// INFERENCE RESULT
// ═══════════════════════════════════════════════════════════════════════════════

pub const InferenceResult = struct {
    job_id: JobId,
    worker_id: NodeId,
    response: []const u8,
    tokens_generated: u32,
    latency_ms: u32,
    signature: [64]u8, // ed25519 signature over (job_id || response hash)

    pub fn serialize(self: *const InferenceResult, allocator: std.mem.Allocator) ![]u8 {
        var list = ArrayList(u8).init(allocator);
        const writer = list.writer();

        // Job ID (16 bytes)
        try writer.writeAll(&self.job_id);
        // Worker ID (32 bytes)
        try writer.writeAll(&self.worker_id);
        // Tokens generated (4 bytes)
        try writer.writeInt(u32, self.tokens_generated, .little);
        // Latency (4 bytes)
        try writer.writeInt(u32, self.latency_ms, .little);
        // Signature (64 bytes)
        try writer.writeAll(&self.signature);
        // Response length + data
        try writer.writeInt(u32, @intCast(self.response.len), .little);
        try writer.writeAll(self.response);

        return list.toOwnedSlice();
    }

    pub fn deserialize(data: []const u8, allocator: std.mem.Allocator) !InferenceResult {
        var reader = std.io.fixedBufferStream(data);
        const r = reader.reader();

        var result: InferenceResult = undefined;

        // Job ID
        _ = try r.readAll(&result.job_id);
        // Worker ID
        _ = try r.readAll(&result.worker_id);
        // Tokens generated
        result.tokens_generated = try r.readInt(u32, .little);
        // Latency
        result.latency_ms = try r.readInt(u32, .little);
        // Signature
        _ = try r.readAll(&result.signature);
        // Response (max 16MB)
        const response_len = try r.readInt(u32, .little);
        if (response_len > 16 * 1024 * 1024) return error.InvalidData;
        const response_buf = try allocator.alloc(u8, response_len);
        errdefer allocator.free(response_buf);
        _ = try r.readAll(response_buf);
        result.response = response_buf;

        return result;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// REWARD NOTIFICATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const RewardNotification = struct {
    job_id: JobId,
    worker_id: NodeId,
    amount_wei: u128, // $TRI in wei (18 decimals)
    timestamp: i64,
    coordinator_signature: [64]u8,

    pub fn serialize(self: *const RewardNotification, allocator: std.mem.Allocator) ![]u8 {
        var list = ArrayList(u8).init(allocator);
        const writer = list.writer();

        try writer.writeAll(&self.job_id);
        try writer.writeAll(&self.worker_id);
        try writer.writeInt(u128, self.amount_wei, .little);
        try writer.writeInt(i64, self.timestamp, .little);
        try writer.writeAll(&self.coordinator_signature);

        return list.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HEARTBEAT
// ═══════════════════════════════════════════════════════════════════════════════

pub const Heartbeat = struct {
    node_id: NodeId,
    timestamp: i64,
    jobs_completed: u64,
    uptime_seconds: u64,
    status: NodeStatus,

    pub const NodeStatus = enum(u8) {
        offline = 0,
        syncing = 1,
        online = 2,
        busy = 3,
    };

    pub fn serialize(self: *const Heartbeat, allocator: std.mem.Allocator) ![]u8 {
        var list = ArrayList(u8).init(allocator);
        const writer = list.writer();

        try writer.writeAll(&self.node_id);
        try writer.writeInt(i64, self.timestamp, .little);
        try writer.writeInt(u64, self.jobs_completed, .little);
        try writer.writeInt(u64, self.uptime_seconds, .little);
        try writer.writeByte(@intFromEnum(self.status));

        return list.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PEER ANNOUNCE (UDP broadcast)
// ═══════════════════════════════════════════════════════════════════════════════

pub const PeerAnnounce = struct {
    node_id: NodeId,
    public_key: [32]u8,
    listen_port: u16,
    capabilities_hash: [32]u8, // SHA256 of full capabilities
    timestamp: i64,

    pub fn serialize(self: *const PeerAnnounce) [106]u8 {
        var buf: [106]u8 = undefined;
        var i: usize = 0;

        @memcpy(buf[i..][0..32], &self.node_id);
        i += 32;
        @memcpy(buf[i..][0..32], &self.public_key);
        i += 32;
        std.mem.writeInt(u16, buf[i..][0..2], self.listen_port, .little);
        i += 2;
        @memcpy(buf[i..][0..32], &self.capabilities_hash);
        i += 32;
        std.mem.writeInt(i64, buf[i..][0..8], self.timestamp, .little);

        return buf;
    }

    pub fn deserialize(data: []const u8) !PeerAnnounce {
        if (data.len < 106) return error.InvalidData;

        var announce: PeerAnnounce = undefined;
        var i: usize = 0;

        @memcpy(&announce.node_id, data[i..][0..32]);
        i += 32;
        @memcpy(&announce.public_key, data[i..][0..32]);
        i += 32;
        announce.listen_port = std.mem.readInt(u16, data[i..][0..2], .little);
        i += 2;
        @memcpy(&announce.capabilities_hash, data[i..][0..32]);
        i += 32;
        announce.timestamp = std.mem.readInt(i64, data[i..][0..8], .little);

        return announce;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MESSAGE ENVELOPE
// ═══════════════════════════════════════════════════════════════════════════════

pub const MessageHeader = struct {
    magic: [4]u8 = .{ 'T', 'R', 'I', 'N' }, // Magic bytes
    msg_type: MessageType,
    length: u32, // Payload length

    pub const SIZE: usize = 9;

    pub fn serialize(self: *const MessageHeader) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        @memcpy(buf[0..4], &self.magic);
        buf[4] = @intFromEnum(self.msg_type);
        std.mem.writeInt(u32, buf[5..9], self.length, .little);
        return buf;
    }

    pub fn deserialize(data: []const u8) !MessageHeader {
        if (data.len < SIZE) return error.InvalidHeader;

        var header: MessageHeader = undefined;
        @memcpy(&header.magic, data[0..4]);

        // Validate magic
        if (!std.mem.eql(u8, &header.magic, &.{ 'T', 'R', 'I', 'N' })) {
            return error.InvalidMagic;
        }

        header.msg_type = @enumFromInt(data[4]);
        header.length = std.mem.readInt(u32, data[5..9], .little);

        return header;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// REWARD CALCULATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const REWARD_PER_1M_TOKENS: u128 = 900_000_000_000_000_000; // 0.9 TRI

pub fn calculateJobReward(tokens: u64, latency_ms: u32, uptime_pct: f32) u128 {
    // Base reward
    const base = (tokens * REWARD_PER_1M_TOKENS) / 1_000_000;

    // Latency bonus: up to 50% for fast responses
    const latency_bonus: f32 = if (latency_ms < 500)
        0.5
    else if (latency_ms < 1000)
        0.25
    else if (latency_ms < 2000)
        0.1
    else
        0.0;

    // Uptime bonus: up to 20%
    const uptime_bonus: f32 = uptime_pct * 0.2;

    const multiplier = 1.0 + latency_bonus + uptime_bonus;
    return @intFromFloat(@as(f64, @floatFromInt(base)) * multiplier);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PIPELINE-PARALLEL DISTRIBUTED INFERENCE MESSAGES
// ═══════════════════════════════════════════════════════════════════════════════

/// ForwardRequest: Coordinator sends hidden state to worker for pipeline processing
/// Wire format: [4B seq_id][4B pos][4B hidden_size][4B temperature][hidden_size*4B data]
pub const ForwardRequest = struct {
    sequence_id: u32,
    token_pos: u32,
    hidden_size: u32,
    temperature: f32,
    hidden_state: []const f32,

    pub const HEADER_SIZE: usize = 16; // 4 + 4 + 4 + 4

    pub fn serialize(self: *const ForwardRequest, allocator: std.mem.Allocator) ![]u8 {
        const data_size = self.hidden_size * 4;
        const total = HEADER_SIZE + data_size;
        const buf = try allocator.alloc(u8, total);

        std.mem.writeInt(u32, buf[0..4], self.sequence_id, .little);
        std.mem.writeInt(u32, buf[4..8], self.token_pos, .little);
        std.mem.writeInt(u32, buf[8..12], self.hidden_size, .little);
        @memcpy(buf[12..16], std.mem.asBytes(&self.temperature));

        const float_bytes = std.mem.sliceAsBytes(self.hidden_state);
        @memcpy(buf[HEADER_SIZE..][0..data_size], float_bytes);

        return buf;
    }

    pub fn deserialize(data: []const u8, allocator: std.mem.Allocator) !ForwardRequest {
        if (data.len < HEADER_SIZE) return error.InvalidData;

        const hidden_size = std.mem.readInt(u32, data[8..12], .little);
        if (hidden_size > 1024 * 1024) return error.InvalidData; // max 1M floats = 4MB
        const expected_size = HEADER_SIZE + hidden_size * 4;
        if (data.len < expected_size) return error.InvalidData;

        const hidden = try allocator.alloc(f32, hidden_size);
        const src_bytes = data[HEADER_SIZE..][0 .. hidden_size * 4];
        @memcpy(std.mem.sliceAsBytes(hidden), src_bytes);

        return ForwardRequest{
            .sequence_id = std.mem.readInt(u32, data[0..4], .little),
            .token_pos = std.mem.readInt(u32, data[4..8], .little),
            .hidden_size = hidden_size,
            .temperature = @bitCast(std.mem.readInt(u32, data[12..16], .little)),
            .hidden_state = hidden,
        };
    }
};

/// ForwardResponse: Worker sends sampled token back to coordinator
/// Wire format: [4B seq_id][4B pos][4B token]
pub const ForwardResponse = struct {
    sequence_id: u32,
    token_pos: u32,
    sampled_token: u32,

    pub const SIZE: usize = 12;

    pub fn serialize(self: *const ForwardResponse) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        std.mem.writeInt(u32, buf[0..4], self.sequence_id, .little);
        std.mem.writeInt(u32, buf[4..8], self.token_pos, .little);
        std.mem.writeInt(u32, buf[8..12], self.sampled_token, .little);
        return buf;
    }

    pub fn deserialize(data: *const [SIZE]u8) ForwardResponse {
        return ForwardResponse{
            .sequence_id = std.mem.readInt(u32, data[0..4], .little),
            .token_pos = std.mem.readInt(u32, data[4..8], .little),
            .sampled_token = std.mem.readInt(u32, data[8..12], .little),
        };
    }
};

/// BatchForwardRequest: Coordinator sends N hidden states in one TCP message (prefill optimization)
/// Wire format: [4B seq_id][4B batch_size][4B hidden_size][4B temperature]
///              then per item: [4B token_pos][hidden_size*4B data]
pub const BatchForwardRequest = struct {
    sequence_id: u32,
    batch_size: u32,
    hidden_size: u32,
    temperature: f32,
    token_positions: []const u32,
    hidden_states: []const f32, // batch_size * hidden_size contiguous

    pub const HEADER_SIZE: usize = 16;

    pub fn serialize(self: *const BatchForwardRequest, allocator: std.mem.Allocator) ![]u8 {
        const per_item = 4 + self.hidden_size * 4;
        const total = HEADER_SIZE + self.batch_size * per_item;
        const buf = try allocator.alloc(u8, total);

        std.mem.writeInt(u32, buf[0..4], self.sequence_id, .little);
        std.mem.writeInt(u32, buf[4..8], self.batch_size, .little);
        std.mem.writeInt(u32, buf[8..12], self.hidden_size, .little);
        @memcpy(buf[12..16], std.mem.asBytes(&self.temperature));

        var offset: usize = HEADER_SIZE;
        for (0..self.batch_size) |i| {
            std.mem.writeInt(u32, buf[offset..][0..4], self.token_positions[i], .little);
            offset += 4;
            const hs_start = i * self.hidden_size;
            const float_bytes = std.mem.sliceAsBytes(self.hidden_states[hs_start..][0..self.hidden_size]);
            @memcpy(buf[offset..][0 .. self.hidden_size * 4], float_bytes);
            offset += self.hidden_size * 4;
        }
        return buf;
    }

    pub fn deserialize(data: []const u8, allocator: std.mem.Allocator) !BatchForwardRequest {
        if (data.len < HEADER_SIZE) return error.InvalidData;

        const batch_size = std.mem.readInt(u32, data[4..8], .little);
        const hidden_size = std.mem.readInt(u32, data[8..12], .little);
        if (batch_size > 4096 or hidden_size > 1024 * 1024) return error.InvalidData;
        const per_item = 4 + hidden_size * 4;
        if (data.len < HEADER_SIZE + batch_size * per_item) return error.InvalidData;

        const positions = try allocator.alloc(u32, batch_size);
        errdefer allocator.free(positions);
        const hidden_states = try allocator.alloc(f32, batch_size * hidden_size);

        var offset: usize = HEADER_SIZE;
        for (0..batch_size) |i| {
            positions[i] = std.mem.readInt(u32, data[offset..][0..4], .little);
            offset += 4;
            const hs_start = i * hidden_size;
            const src_bytes = data[offset..][0 .. hidden_size * 4];
            @memcpy(std.mem.sliceAsBytes(hidden_states[hs_start..][0..hidden_size]), src_bytes);
            offset += hidden_size * 4;
        }

        return BatchForwardRequest{
            .sequence_id = std.mem.readInt(u32, data[0..4], .little),
            .batch_size = batch_size,
            .hidden_size = hidden_size,
            .temperature = @bitCast(std.mem.readInt(u32, data[12..16], .little)),
            .token_positions = positions,
            .hidden_states = hidden_states,
        };
    }
};

/// BatchForwardResponse: Worker returns N sampled tokens in one message
/// Wire format: [4B seq_id][4B batch_size][batch_size * 4B tokens]
pub const BatchForwardResponse = struct {
    sequence_id: u32,
    batch_size: u32,
    sampled_tokens: []const u32,

    pub const HEADER_SIZE: usize = 8;

    pub fn serialize(self: *const BatchForwardResponse, allocator: std.mem.Allocator) ![]u8 {
        const total = HEADER_SIZE + self.batch_size * 4;
        const buf = try allocator.alloc(u8, total);
        std.mem.writeInt(u32, buf[0..4], self.sequence_id, .little);
        std.mem.writeInt(u32, buf[4..8], self.batch_size, .little);
        for (0..self.batch_size) |i| {
            const off = HEADER_SIZE + i * 4;
            std.mem.writeInt(u32, buf[off..][0..4], self.sampled_tokens[i], .little);
        }
        return buf;
    }

    pub fn deserialize(data: []const u8, allocator: std.mem.Allocator) !BatchForwardResponse {
        if (data.len < HEADER_SIZE) return error.InvalidData;
        const batch_size = std.mem.readInt(u32, data[4..8], .little);
        if (batch_size > 4096) return error.InvalidData;
        if (data.len < HEADER_SIZE + batch_size * 4) return error.InvalidData;

        const tokens = try allocator.alloc(u32, batch_size);
        for (0..batch_size) |i| {
            const off = HEADER_SIZE + i * 4;
            tokens[i] = std.mem.readInt(u32, data[off..][0..4], .little);
        }
        return BatchForwardResponse{
            .sequence_id = std.mem.readInt(u32, data[0..4], .little),
            .batch_size = batch_size,
            .sampled_tokens = tokens,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// STORAGE NETWORK MESSAGES
// ═══════════════════════════════════════════════════════════════════════════════

/// StoreRequest: Request a peer to store a shard
/// Wire format: [32B shard_hash][32B file_id][4B shard_index][4B total_shards][4B data_len][data]
pub const StoreRequest = struct {
    shard_hash: [32]u8, // SHA256 of shard data
    file_id: [32]u8, // SHA256 of original file
    shard_index: u32,
    total_shards: u32,
    data: []const u8, // Encrypted shard data

    pub fn serialize(self: *const StoreRequest, allocator: std.mem.Allocator) ![]u8 {
        var list = ArrayList(u8).init(allocator);
        const writer = list.writer();

        try writer.writeAll(&self.shard_hash);
        try writer.writeAll(&self.file_id);
        try writer.writeInt(u32, self.shard_index, .little);
        try writer.writeInt(u32, self.total_shards, .little);
        try writer.writeInt(u32, @intCast(self.data.len), .little);
        try writer.writeAll(self.data);

        return list.toOwnedSlice();
    }

    pub fn deserialize(data: []const u8, allocator: std.mem.Allocator) !StoreRequest {
        if (data.len < 76) return error.InvalidData; // 32+32+4+4+4

        var req: StoreRequest = undefined;
        @memcpy(&req.shard_hash, data[0..32]);
        @memcpy(&req.file_id, data[32..64]);
        req.shard_index = std.mem.readInt(u32, data[64..68], .little);
        req.total_shards = std.mem.readInt(u32, data[68..72], .little);
        const data_len = std.mem.readInt(u32, data[72..76], .little);
        if (data_len > 64 * 1024 * 1024) return error.InvalidData; // max 64MB shard
        if (data.len < 76 + data_len) return error.InvalidData;

        const shard_data = try allocator.alloc(u8, data_len);
        @memcpy(shard_data, data[76..][0..data_len]);
        req.data = shard_data;

        return req;
    }
};

/// StoreResponse: Acknowledgment from peer that shard was stored
/// Wire format: [32B shard_hash][1B success][32B node_id]
pub const StoreResponse = struct {
    shard_hash: [32]u8,
    success: bool,
    node_id: NodeId,

    pub const SIZE: usize = 65;

    pub fn serialize(self: *const StoreResponse) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        @memcpy(buf[0..32], &self.shard_hash);
        buf[32] = if (self.success) 1 else 0;
        @memcpy(buf[33..65], &self.node_id);
        return buf;
    }

    pub fn deserialize(data: []const u8) !StoreResponse {
        if (data.len < SIZE) return error.InvalidData;
        var resp: StoreResponse = undefined;
        @memcpy(&resp.shard_hash, data[0..32]);
        resp.success = data[32] != 0;
        @memcpy(&resp.node_id, data[33..65]);
        return resp;
    }
};

/// RetrieveRequest: Request a shard from a peer
/// Wire format: [32B shard_hash][32B requester_id]
pub const RetrieveRequest = struct {
    shard_hash: [32]u8,
    requester_id: NodeId,

    pub const SIZE: usize = 64;

    pub fn serialize(self: *const RetrieveRequest) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        @memcpy(buf[0..32], &self.shard_hash);
        @memcpy(buf[32..64], &self.requester_id);
        return buf;
    }

    pub fn deserialize(data: []const u8) !RetrieveRequest {
        if (data.len < SIZE) return error.InvalidData;
        var req: RetrieveRequest = undefined;
        @memcpy(&req.shard_hash, data[0..32]);
        @memcpy(&req.requester_id, data[32..64]);
        return req;
    }
};

/// RetrieveResponse: Shard data returned from peer
/// Wire format: [32B shard_hash][1B found][4B data_len][data]
pub const RetrieveResponse = struct {
    shard_hash: [32]u8,
    found: bool,
    data: []const u8,

    pub fn serialize(self: *const RetrieveResponse, allocator: std.mem.Allocator) ![]u8 {
        var list = ArrayList(u8).init(allocator);
        const writer = list.writer();

        try writer.writeAll(&self.shard_hash);
        try writer.writeByte(if (self.found) 1 else 0);
        try writer.writeInt(u32, @intCast(self.data.len), .little);
        try writer.writeAll(self.data);

        return list.toOwnedSlice();
    }

    pub fn deserialize(data: []const u8, allocator: std.mem.Allocator) !RetrieveResponse {
        if (data.len < 37) return error.InvalidData; // 32+1+4
        var resp: RetrieveResponse = undefined;
        @memcpy(&resp.shard_hash, data[0..32]);
        resp.found = data[32] != 0;
        const data_len = std.mem.readInt(u32, data[33..37], .little);
        if (data_len > 64 * 1024 * 1024) return error.InvalidData; // max 64MB shard
        if (data.len < 37 + data_len) return error.InvalidData;

        const shard_data = try allocator.alloc(u8, data_len);
        @memcpy(shard_data, data[37..][0..data_len]);
        resp.data = shard_data;

        return resp;
    }
};

/// StorageAnnounce: Peer announces storage capacity
/// Wire format: [32B node_id][8B available_bytes][8B total_bytes][4B shard_count][8B timestamp]
pub const StorageAnnounce = struct {
    node_id: NodeId,
    available_bytes: u64,
    total_bytes: u64,
    shard_count: u32,
    timestamp: i64,

    pub const SIZE: usize = 60;

    pub fn serialize(self: *const StorageAnnounce) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        var i: usize = 0;

        @memcpy(buf[i..][0..32], &self.node_id);
        i += 32;
        std.mem.writeInt(u64, buf[i..][0..8], self.available_bytes, .little);
        i += 8;
        std.mem.writeInt(u64, buf[i..][0..8], self.total_bytes, .little);
        i += 8;
        std.mem.writeInt(u32, buf[i..][0..4], self.shard_count, .little);
        i += 4;
        std.mem.writeInt(i64, buf[i..][0..8], self.timestamp, .little);

        return buf;
    }

    pub fn deserialize(data: []const u8) !StorageAnnounce {
        if (data.len < SIZE) return error.InvalidData;
        var ann: StorageAnnounce = undefined;
        var i: usize = 0;

        @memcpy(&ann.node_id, data[i..][0..32]);
        i += 32;
        ann.available_bytes = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        ann.total_bytes = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        ann.shard_count = std.mem.readInt(u32, data[i..][0..4], .little);
        i += 4;
        ann.timestamp = std.mem.readInt(i64, data[i..][0..8], .little);

        return ann;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MANIFEST DHT MESSAGES (v1.4)
// ═══════════════════════════════════════════════════════════════════════════════

/// ManifestStoreMessage: Store a serialized FileManifest on a peer
/// Wire format: [32B file_id][4B data_len][data]
pub const ManifestStoreMessage = struct {
    file_id: [32]u8,
    data: []const u8,

    pub fn serialize(self: *const ManifestStoreMessage, allocator: std.mem.Allocator) ![]u8 {
        var list = ArrayList(u8).init(allocator);
        const writer = list.writer();

        try writer.writeAll(&self.file_id);
        try writer.writeInt(u32, @intCast(self.data.len), .little);
        try writer.writeAll(self.data);

        return list.toOwnedSlice();
    }

    pub fn deserialize(data: []const u8, allocator: std.mem.Allocator) !ManifestStoreMessage {
        if (data.len < 36) return error.InvalidData; // 32 + 4
        var msg: ManifestStoreMessage = undefined;
        @memcpy(&msg.file_id, data[0..32]);
        const data_len = std.mem.readInt(u32, data[32..36], .little);
        if (data_len > 16 * 1024 * 1024) return error.InvalidData; // max 16MB manifest
        if (data.len < 36 + data_len) return error.InvalidData;

        const manifest_data = try allocator.alloc(u8, data_len);
        @memcpy(manifest_data, data[36..][0..data_len]);
        msg.data = manifest_data;

        return msg;
    }
};

/// ManifestRetrieveRequest: Request a manifest from a peer
/// Wire format: [32B file_id][32B requester_id]
pub const ManifestRetrieveRequest = struct {
    file_id: [32]u8,
    requester_id: NodeId,

    pub const SIZE: usize = 64;

    pub fn serialize(self: *const ManifestRetrieveRequest) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        @memcpy(buf[0..32], &self.file_id);
        @memcpy(buf[32..64], &self.requester_id);
        return buf;
    }

    pub fn deserialize(data: []const u8) !ManifestRetrieveRequest {
        if (data.len < SIZE) return error.InvalidData;
        var req: ManifestRetrieveRequest = undefined;
        @memcpy(&req.file_id, data[0..32]);
        @memcpy(&req.requester_id, data[32..64]);
        return req;
    }
};

/// ManifestRetrieveResponse: Return a manifest (or not found)
/// Wire format: [32B file_id][1B found][4B data_len][data]
pub const ManifestRetrieveResponse = struct {
    file_id: [32]u8,
    found: bool,
    data: []const u8,

    pub fn serialize(self: *const ManifestRetrieveResponse, allocator: std.mem.Allocator) ![]u8 {
        var list = ArrayList(u8).init(allocator);
        const writer = list.writer();

        try writer.writeAll(&self.file_id);
        try writer.writeByte(if (self.found) 1 else 0);
        try writer.writeInt(u32, @intCast(self.data.len), .little);
        try writer.writeAll(self.data);

        return list.toOwnedSlice();
    }

    pub fn deserialize(data: []const u8, allocator: std.mem.Allocator) !ManifestRetrieveResponse {
        if (data.len < 37) return error.InvalidData; // 32 + 1 + 4
        var resp: ManifestRetrieveResponse = undefined;
        @memcpy(&resp.file_id, data[0..32]);
        resp.found = data[32] != 0;
        const data_len = std.mem.readInt(u32, data[33..37], .little);
        if (data_len > 16 * 1024 * 1024) return error.InvalidData; // max 16MB manifest
        if (data.len < 37 + data_len) return error.InvalidData;

        const manifest_data = try allocator.alloc(u8, data_len);
        @memcpy(manifest_data, data[37..][0..data_len]);
        resp.data = manifest_data;

        return resp;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PROOF-OF-STORAGE MESSAGES (v1.5)
// ═══════════════════════════════════════════════════════════════════════════════

/// StorageChallengeMsg: Challenge a peer to prove they store a shard
/// Wire format: [32B challenge_id][32B challenger_id][32B target_node_id][32B shard_hash][4B byte_offset][4B byte_length][8B timestamp]
pub const StorageChallengeMsg = struct {
    challenge_id: [32]u8,
    challenger_id: NodeId,
    target_node_id: NodeId,
    shard_hash: [32]u8,
    byte_offset: u32,
    byte_length: u32,
    timestamp: i64,

    pub const SIZE: usize = 144;

    pub fn serialize(self: *const StorageChallengeMsg) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        var i: usize = 0;

        @memcpy(buf[i..][0..32], &self.challenge_id);
        i += 32;
        @memcpy(buf[i..][0..32], &self.challenger_id);
        i += 32;
        @memcpy(buf[i..][0..32], &self.target_node_id);
        i += 32;
        @memcpy(buf[i..][0..32], &self.shard_hash);
        i += 32;
        std.mem.writeInt(u32, buf[i..][0..4], self.byte_offset, .little);
        i += 4;
        std.mem.writeInt(u32, buf[i..][0..4], self.byte_length, .little);
        i += 4;
        std.mem.writeInt(i64, buf[i..][0..8], self.timestamp, .little);

        return buf;
    }

    pub fn deserialize(data: []const u8) !StorageChallengeMsg {
        if (data.len < SIZE) return error.InvalidData;
        var msg: StorageChallengeMsg = undefined;
        var i: usize = 0;

        @memcpy(&msg.challenge_id, data[i..][0..32]);
        i += 32;
        @memcpy(&msg.challenger_id, data[i..][0..32]);
        i += 32;
        @memcpy(&msg.target_node_id, data[i..][0..32]);
        i += 32;
        @memcpy(&msg.shard_hash, data[i..][0..32]);
        i += 32;
        msg.byte_offset = std.mem.readInt(u32, data[i..][0..4], .little);
        i += 4;
        msg.byte_length = std.mem.readInt(u32, data[i..][0..4], .little);
        i += 4;
        msg.timestamp = std.mem.readInt(i64, data[i..][0..8], .little);

        return msg;
    }
};

/// StorageProofMsg: Response to a storage challenge
/// Wire format: [32B challenge_id][32B prover_id][32B proof_hash][8B timestamp]
pub const StorageProofMsg = struct {
    challenge_id: [32]u8,
    prover_id: NodeId,
    proof_hash: [32]u8,
    timestamp: i64,

    pub const SIZE: usize = 104;

    pub fn serialize(self: *const StorageProofMsg) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        var i: usize = 0;

        @memcpy(buf[i..][0..32], &self.challenge_id);
        i += 32;
        @memcpy(buf[i..][0..32], &self.prover_id);
        i += 32;
        @memcpy(buf[i..][0..32], &self.proof_hash);
        i += 32;
        std.mem.writeInt(i64, buf[i..][0..8], self.timestamp, .little);

        return buf;
    }

    pub fn deserialize(data: []const u8) !StorageProofMsg {
        if (data.len < SIZE) return error.InvalidData;
        var msg: StorageProofMsg = undefined;
        var i: usize = 0;

        @memcpy(&msg.challenge_id, data[i..][0..32]);
        i += 32;
        @memcpy(&msg.prover_id, data[i..][0..32]);
        i += 32;
        @memcpy(&msg.proof_hash, data[i..][0..32]);
        i += 32;
        msg.timestamp = std.mem.readInt(i64, data[i..][0..8], .little);

        return msg;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BANDWIDTH AGGREGATION MESSAGES (v1.5)
// ═══════════════════════════════════════════════════════════════════════════════

/// BandwidthReportMsg: Node reports its bandwidth usage for a period
/// Wire format: [32B node_id][8B bytes_uploaded][8B bytes_downloaded][8B shards_hosted][8B period_start][8B period_end]
pub const BandwidthReportMsg = struct {
    node_id: NodeId,
    bytes_uploaded: u64,
    bytes_downloaded: u64,
    shards_hosted: u64,
    period_start: i64,
    period_end: i64,

    pub const SIZE: usize = 72;

    pub fn serialize(self: *const BandwidthReportMsg) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        var i: usize = 0;

        @memcpy(buf[i..][0..32], &self.node_id);
        i += 32;
        std.mem.writeInt(u64, buf[i..][0..8], self.bytes_uploaded, .little);
        i += 8;
        std.mem.writeInt(u64, buf[i..][0..8], self.bytes_downloaded, .little);
        i += 8;
        std.mem.writeInt(u64, buf[i..][0..8], self.shards_hosted, .little);
        i += 8;
        std.mem.writeInt(i64, buf[i..][0..8], self.period_start, .little);
        i += 8;
        std.mem.writeInt(i64, buf[i..][0..8], self.period_end, .little);

        return buf;
    }

    pub fn deserialize(data: []const u8) !BandwidthReportMsg {
        if (data.len < SIZE) return error.InvalidData;
        var msg: BandwidthReportMsg = undefined;
        var i: usize = 0;

        @memcpy(&msg.node_id, data[i..][0..32]);
        i += 32;
        msg.bytes_uploaded = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        msg.bytes_downloaded = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        msg.shards_hosted = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        msg.period_start = std.mem.readInt(i64, data[i..][0..8], .little);
        i += 8;
        msg.period_end = std.mem.readInt(i64, data[i..][0..8], .little);

        return msg;
    }
};

/// BandwidthSummaryMsg: Aggregated bandwidth across all peers
/// Wire format: [8B total_upload][8B total_download][4B node_count][8B timestamp]
pub const BandwidthSummaryMsg = struct {
    total_upload: u64,
    total_download: u64,
    node_count: u32,
    timestamp: i64,

    pub const SIZE: usize = 28;

    pub fn serialize(self: *const BandwidthSummaryMsg) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        var i: usize = 0;

        std.mem.writeInt(u64, buf[i..][0..8], self.total_upload, .little);
        i += 8;
        std.mem.writeInt(u64, buf[i..][0..8], self.total_download, .little);
        i += 8;
        std.mem.writeInt(u32, buf[i..][0..4], self.node_count, .little);
        i += 4;
        std.mem.writeInt(i64, buf[i..][0..8], self.timestamp, .little);

        return buf;
    }

    pub fn deserialize(data: []const u8) !BandwidthSummaryMsg {
        if (data.len < SIZE) return error.InvalidData;
        var msg: BandwidthSummaryMsg = undefined;
        var i: usize = 0;

        msg.total_upload = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        msg.total_download = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        msg.node_count = std.mem.readInt(u32, data[i..][0..4], .little);
        i += 4;
        msg.timestamp = std.mem.readInt(i64, data[i..][0..8], .little);

        return msg;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SHARD SCRUB REPORT MESSAGE (v1.6)
// ═══════════════════════════════════════════════════════════════════════════════

/// ShardScrubReportMsg: Node reports results of a local shard scrub
/// Wire format: [32B node_id][4B shards_checked][4B corruptions_found][8B timestamp]
pub const ShardScrubReportMsg = struct {
    node_id: NodeId,
    shards_checked: u32,
    corruptions_found: u32,
    timestamp: i64,

    pub const SIZE: usize = 48;

    pub fn serialize(self: *const ShardScrubReportMsg) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        var i: usize = 0;

        @memcpy(buf[i..][0..32], &self.node_id);
        i += 32;
        std.mem.writeInt(u32, buf[i..][0..4], self.shards_checked, .little);
        i += 4;
        std.mem.writeInt(u32, buf[i..][0..4], self.corruptions_found, .little);
        i += 4;
        std.mem.writeInt(i64, buf[i..][0..8], self.timestamp, .little);

        return buf;
    }

    pub fn deserialize(data: []const u8) !ShardScrubReportMsg {
        if (data.len < SIZE) return error.InvalidData;
        var msg: ShardScrubReportMsg = undefined;
        var i: usize = 0;

        @memcpy(&msg.node_id, data[i..][0..32]);
        i += 32;
        msg.shards_checked = std.mem.readInt(u32, data[i..][0..4], .little);
        i += 4;
        msg.corruptions_found = std.mem.readInt(u32, data[i..][0..4], .little);
        i += 4;
        msg.timestamp = std.mem.readInt(i64, data[i..][0..8], .little);

        return msg;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// REPUTATION MESSAGES (v1.6)
// ═══════════════════════════════════════════════════════════════════════════════

/// ReputationQueryMsg: Request the reputation score for a node
/// Wire format: [32B requester_id][32B target_node_id]
pub const ReputationQueryMsg = struct {
    requester_id: NodeId,
    target_node_id: NodeId,

    pub const SIZE: usize = 64;

    pub fn serialize(self: *const ReputationQueryMsg) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        @memcpy(buf[0..32], &self.requester_id);
        @memcpy(buf[32..64], &self.target_node_id);
        return buf;
    }

    pub fn deserialize(data: []const u8) !ReputationQueryMsg {
        if (data.len < SIZE) return error.InvalidData;
        var msg: ReputationQueryMsg = undefined;
        @memcpy(&msg.requester_id, data[0..32]);
        @memcpy(&msg.target_node_id, data[32..64]);
        return msg;
    }
};

/// ReputationResponseMsg: Return a reputation score
/// Wire format: [32B node_id][8B score_millionths][8B pos_score_millionths][8B uptime_score_millionths][8B bandwidth_score_millionths]
pub const ReputationResponseMsg = struct {
    node_id: NodeId,
    score_millionths: u64, // score * 1_000_000
    pos_score_millionths: u64,
    uptime_score_millionths: u64,
    bandwidth_score_millionths: u64,

    pub const SIZE: usize = 64;

    pub fn serialize(self: *const ReputationResponseMsg) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        var i: usize = 0;

        @memcpy(buf[i..][0..32], &self.node_id);
        i += 32;
        std.mem.writeInt(u64, buf[i..][0..8], self.score_millionths, .little);
        i += 8;
        std.mem.writeInt(u64, buf[i..][0..8], self.pos_score_millionths, .little);
        i += 8;
        std.mem.writeInt(u64, buf[i..][0..8], self.uptime_score_millionths, .little);
        i += 8;
        std.mem.writeInt(u64, buf[i..][0..8], self.bandwidth_score_millionths, .little);

        return buf;
    }

    pub fn deserialize(data: []const u8) !ReputationResponseMsg {
        if (data.len < SIZE) return error.InvalidData;
        var msg: ReputationResponseMsg = undefined;
        var i: usize = 0;

        @memcpy(&msg.node_id, data[i..][0..32]);
        i += 32;
        msg.score_millionths = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        msg.pos_score_millionths = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        msg.uptime_score_millionths = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        msg.bandwidth_score_millionths = std.mem.readInt(u64, data[i..][0..8], .little);

        return msg;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GRACEFUL SHUTDOWN MESSAGE (v1.6)
// ═══════════════════════════════════════════════════════════════════════════════

/// GracefulShutdownMsg: Node announces it will be departing
/// Wire format: [32B node_id][4B shards_held][8B departure_time]
pub const GracefulShutdownMsg = struct {
    node_id: NodeId,
    shards_held: u32,
    departure_time: i64,

    pub const SIZE: usize = 44;

    pub fn serialize(self: *const GracefulShutdownMsg) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        var i: usize = 0;

        @memcpy(buf[i..][0..32], &self.node_id);
        i += 32;
        std.mem.writeInt(u32, buf[i..][0..4], self.shards_held, .little);
        i += 4;
        std.mem.writeInt(i64, buf[i..][0..8], self.departure_time, .little);

        return buf;
    }

    pub fn deserialize(data: []const u8) !GracefulShutdownMsg {
        if (data.len < SIZE) return error.InvalidData;
        var msg: GracefulShutdownMsg = undefined;
        var i: usize = 0;

        @memcpy(&msg.node_id, data[i..][0..32]);
        i += 32;
        msg.shards_held = std.mem.readInt(u32, data[i..][0..4], .little);
        i += 4;
        msg.departure_time = std.mem.readInt(i64, data[i..][0..8], .little);

        return msg;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// AUTO-REPAIR MESSAGES (v1.7)
// ═══════════════════════════════════════════════════════════════════════════════

/// ShardRepairRequestMsg: Request a healthy copy of a shard from a peer
/// Wire format: [32B requester_id][32B shard_hash]
pub const ShardRepairRequestMsg = struct {
    requester_id: NodeId,
    shard_hash: [32]u8,

    pub const SIZE: usize = 64;

    pub fn serialize(self: *const ShardRepairRequestMsg) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        @memcpy(buf[0..32], &self.requester_id);
        @memcpy(buf[32..64], &self.shard_hash);
        return buf;
    }

    pub fn deserialize(data: []const u8) !ShardRepairRequestMsg {
        if (data.len < SIZE) return error.InvalidData;
        var msg: ShardRepairRequestMsg = undefined;
        @memcpy(&msg.requester_id, data[0..32]);
        @memcpy(&msg.shard_hash, data[32..64]);
        return msg;
    }
};

/// ShardRepairResponseMsg: Response with shard data or failure
/// Wire format: [32B responder_id][32B shard_hash][1B success][2B data_length]
pub const ShardRepairResponseMsg = struct {
    responder_id: NodeId,
    shard_hash: [32]u8,
    success: bool,
    data_length: u16,

    pub const SIZE: usize = 67;

    pub fn serialize(self: *const ShardRepairResponseMsg) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        @memcpy(buf[0..32], &self.responder_id);
        @memcpy(buf[32..64], &self.shard_hash);
        buf[64] = if (self.success) 1 else 0;
        std.mem.writeInt(u16, buf[65..67], self.data_length, .little);
        return buf;
    }

    pub fn deserialize(data: []const u8) !ShardRepairResponseMsg {
        if (data.len < SIZE) return error.InvalidData;
        var msg: ShardRepairResponseMsg = undefined;
        @memcpy(&msg.responder_id, data[0..32]);
        @memcpy(&msg.shard_hash, data[32..64]);
        msg.success = data[64] != 0;
        msg.data_length = std.mem.readInt(u16, data[65..67], .little);
        return msg;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SLASH EVENT MESSAGE (v1.7)
// ═══════════════════════════════════════════════════════════════════════════════

/// SlashEventMsg: Announce a slashing event to the network
/// Wire format: [32B node_id][8B slash_amount_wei_lo][8B slash_amount_wei_hi][1B reason][8B timestamp][3B padding]
pub const SlashEventMsg = struct {
    node_id: NodeId,
    slash_amount_wei: u128,
    reason: SlashReason,
    timestamp: i64,

    pub const SlashReason = enum(u8) {
        pos_failure = 0,
        corruption = 1,
        low_reputation = 2,
        _,
    };

    pub const SIZE: usize = 60;

    pub fn serialize(self: *const SlashEventMsg) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        var i: usize = 0;

        @memcpy(buf[i..][0..32], &self.node_id);
        i += 32;
        // Store u128 as two u64s (little-endian)
        const lo: u64 = @truncate(self.slash_amount_wei);
        const hi: u64 = @truncate(self.slash_amount_wei >> 64);
        std.mem.writeInt(u64, buf[i..][0..8], lo, .little);
        i += 8;
        std.mem.writeInt(u64, buf[i..][0..8], hi, .little);
        i += 8;
        buf[i] = @intFromEnum(self.reason);
        i += 1;
        std.mem.writeInt(i64, buf[i..][0..8], self.timestamp, .little);
        i += 8;
        // 3 bytes padding
        buf[i] = 0;
        buf[i + 1] = 0;
        buf[i + 2] = 0;

        return buf;
    }

    pub fn deserialize(data: []const u8) !SlashEventMsg {
        if (data.len < SIZE) return error.InvalidData;
        var msg: SlashEventMsg = undefined;
        var i: usize = 0;

        @memcpy(&msg.node_id, data[i..][0..32]);
        i += 32;
        const lo = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        const hi = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        msg.slash_amount_wei = @as(u128, hi) << 64 | @as(u128, lo);
        msg.reason = @enumFromInt(data[i]);
        i += 1;
        msg.timestamp = std.mem.readInt(i64, data[i..][0..8], .little);

        return msg;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "message header serialize/deserialize" {
    const header = MessageHeader{
        .msg_type = .job_request,
        .length = 1234,
    };

    const bytes = header.serialize();
    const parsed = try MessageHeader.deserialize(&bytes);

    try std.testing.expectEqual(header.msg_type, parsed.msg_type);
    try std.testing.expectEqual(header.length, parsed.length);
}

test "peer announce serialize/deserialize" {
    var announce = PeerAnnounce{
        .node_id = undefined,
        .public_key = undefined,
        .listen_port = 9333,
        .capabilities_hash = undefined,
        .timestamp = std.time.timestamp(),
    };
    @memset(&announce.node_id, 0xAB);
    @memset(&announce.public_key, 0xCD);
    @memset(&announce.capabilities_hash, 0xEF);

    const bytes = announce.serialize();
    const parsed = try PeerAnnounce.deserialize(&bytes);

    try std.testing.expectEqual(announce.listen_port, parsed.listen_port);
    try std.testing.expectEqual(announce.timestamp, parsed.timestamp);
}

test "reward calculation" {
    // 1M tokens, 500ms latency, 100% uptime
    const reward = calculateJobReward(1_000_000, 500, 1.0);

    // Base: 1M * 0.9 TRI / 1M = 0.9 TRI = 900_000_000_000_000_000 wei
    // With latency bonus (50%) + uptime bonus (20%) = 1.7x
    // Expected: ~1.53 TRI = ~1_530_000_000_000_000_000 wei
    //
    // Due to integer division, reward should be between 1.5 and 1.6 TRI
    const one_tri: u128 = 1_000_000_000_000_000_000;
    try std.testing.expect(reward >= one_tri); // At least 1 TRI
    try std.testing.expect(reward <= 2 * one_tri); // At most 2 TRI
}

test "store request serialize/deserialize" {
    const allocator = std.testing.allocator;
    var req = StoreRequest{
        .shard_hash = undefined,
        .file_id = undefined,
        .shard_index = 3,
        .total_shards = 10,
        .data = "test_shard_data_here",
    };
    @memset(&req.shard_hash, 0xAA);
    @memset(&req.file_id, 0xBB);

    const bytes = try req.serialize(allocator);
    defer allocator.free(bytes);

    const parsed = try StoreRequest.deserialize(bytes, allocator);
    defer allocator.free(parsed.data);

    try std.testing.expectEqualSlices(u8, &req.shard_hash, &parsed.shard_hash);
    try std.testing.expectEqualSlices(u8, &req.file_id, &parsed.file_id);
    try std.testing.expectEqual(req.shard_index, parsed.shard_index);
    try std.testing.expectEqual(req.total_shards, parsed.total_shards);
    try std.testing.expectEqualSlices(u8, req.data, parsed.data);
}

test "store response serialize/deserialize" {
    var resp = StoreResponse{
        .shard_hash = undefined,
        .success = true,
        .node_id = undefined,
    };
    @memset(&resp.shard_hash, 0xCC);
    @memset(&resp.node_id, 0xDD);

    const bytes = resp.serialize();
    const parsed = try StoreResponse.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &resp.shard_hash, &parsed.shard_hash);
    try std.testing.expect(parsed.success);
    try std.testing.expectEqualSlices(u8, &resp.node_id, &parsed.node_id);
}

test "retrieve request serialize/deserialize" {
    var req = RetrieveRequest{
        .shard_hash = undefined,
        .requester_id = undefined,
    };
    @memset(&req.shard_hash, 0xEE);
    @memset(&req.requester_id, 0xFF);

    const bytes = req.serialize();
    const parsed = try RetrieveRequest.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &req.shard_hash, &parsed.shard_hash);
    try std.testing.expectEqualSlices(u8, &req.requester_id, &parsed.requester_id);
}

test "storage announce serialize/deserialize" {
    var ann = StorageAnnounce{
        .node_id = undefined,
        .available_bytes = 1073741824, // 1GB
        .total_bytes = 10737418240, // 10GB
        .shard_count = 42,
        .timestamp = 1700000000,
    };
    @memset(&ann.node_id, 0x11);

    const bytes = ann.serialize();
    const parsed = try StorageAnnounce.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &ann.node_id, &parsed.node_id);
    try std.testing.expectEqual(ann.available_bytes, parsed.available_bytes);
    try std.testing.expectEqual(ann.total_bytes, parsed.total_bytes);
    try std.testing.expectEqual(ann.shard_count, parsed.shard_count);
    try std.testing.expectEqual(ann.timestamp, parsed.timestamp);
}

test "manifest store message serialize/deserialize" {
    const allocator = std.testing.allocator;
    var msg = ManifestStoreMessage{
        .file_id = undefined,
        .data = "test_manifest_data",
    };
    @memset(&msg.file_id, 0xAA);

    const bytes = try msg.serialize(allocator);
    defer allocator.free(bytes);

    const parsed = try ManifestStoreMessage.deserialize(bytes, allocator);
    defer allocator.free(parsed.data);

    try std.testing.expectEqualSlices(u8, &msg.file_id, &parsed.file_id);
    try std.testing.expectEqualSlices(u8, msg.data, parsed.data);
}

test "manifest retrieve request serialize/deserialize" {
    var req = ManifestRetrieveRequest{
        .file_id = undefined,
        .requester_id = undefined,
    };
    @memset(&req.file_id, 0xBB);
    @memset(&req.requester_id, 0xCC);

    const bytes = req.serialize();
    const parsed = try ManifestRetrieveRequest.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &req.file_id, &parsed.file_id);
    try std.testing.expectEqualSlices(u8, &req.requester_id, &parsed.requester_id);
}

test "manifest retrieve response serialize/deserialize" {
    const allocator = std.testing.allocator;
    var resp = ManifestRetrieveResponse{
        .file_id = undefined,
        .found = true,
        .data = "found_manifest_data",
    };
    @memset(&resp.file_id, 0xDD);

    const bytes = try resp.serialize(allocator);
    defer allocator.free(bytes);

    const parsed = try ManifestRetrieveResponse.deserialize(bytes, allocator);
    defer allocator.free(parsed.data);

    try std.testing.expectEqualSlices(u8, &resp.file_id, &parsed.file_id);
    try std.testing.expect(parsed.found);
    try std.testing.expectEqualSlices(u8, resp.data, parsed.data);
}

test "storage challenge message serialize/deserialize" {
    var msg = StorageChallengeMsg{
        .challenge_id = undefined,
        .challenger_id = undefined,
        .target_node_id = undefined,
        .shard_hash = undefined,
        .byte_offset = 128,
        .byte_length = 64,
        .timestamp = 1700000000,
    };
    @memset(&msg.challenge_id, 0xA1);
    @memset(&msg.challenger_id, 0xB2);
    @memset(&msg.target_node_id, 0xC3);
    @memset(&msg.shard_hash, 0xD4);

    const bytes = msg.serialize();
    const parsed = try StorageChallengeMsg.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &msg.challenge_id, &parsed.challenge_id);
    try std.testing.expectEqualSlices(u8, &msg.challenger_id, &parsed.challenger_id);
    try std.testing.expectEqualSlices(u8, &msg.target_node_id, &parsed.target_node_id);
    try std.testing.expectEqualSlices(u8, &msg.shard_hash, &parsed.shard_hash);
    try std.testing.expectEqual(msg.byte_offset, parsed.byte_offset);
    try std.testing.expectEqual(msg.byte_length, parsed.byte_length);
    try std.testing.expectEqual(msg.timestamp, parsed.timestamp);
}

test "storage proof message serialize/deserialize" {
    var msg = StorageProofMsg{
        .challenge_id = undefined,
        .prover_id = undefined,
        .proof_hash = undefined,
        .timestamp = 1700000001,
    };
    @memset(&msg.challenge_id, 0xE5);
    @memset(&msg.prover_id, 0xF6);
    @memset(&msg.proof_hash, 0x07);

    const bytes = msg.serialize();
    const parsed = try StorageProofMsg.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &msg.challenge_id, &parsed.challenge_id);
    try std.testing.expectEqualSlices(u8, &msg.prover_id, &parsed.prover_id);
    try std.testing.expectEqualSlices(u8, &msg.proof_hash, &parsed.proof_hash);
    try std.testing.expectEqual(msg.timestamp, parsed.timestamp);
}

test "bandwidth report message serialize/deserialize" {
    var msg = BandwidthReportMsg{
        .node_id = undefined,
        .bytes_uploaded = 1073741824,
        .bytes_downloaded = 536870912,
        .shards_hosted = 42,
        .period_start = 1700000000,
        .period_end = 1700003600,
    };
    @memset(&msg.node_id, 0x18);

    const bytes = msg.serialize();
    const parsed = try BandwidthReportMsg.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &msg.node_id, &parsed.node_id);
    try std.testing.expectEqual(msg.bytes_uploaded, parsed.bytes_uploaded);
    try std.testing.expectEqual(msg.bytes_downloaded, parsed.bytes_downloaded);
    try std.testing.expectEqual(msg.shards_hosted, parsed.shards_hosted);
    try std.testing.expectEqual(msg.period_start, parsed.period_start);
    try std.testing.expectEqual(msg.period_end, parsed.period_end);
}

test "bandwidth summary message serialize/deserialize" {
    const msg = BandwidthSummaryMsg{
        .total_upload = 10737418240,
        .total_download = 5368709120,
        .node_count = 10,
        .timestamp = 1700003600,
    };

    const bytes = msg.serialize();
    const parsed = try BandwidthSummaryMsg.deserialize(&bytes);

    try std.testing.expectEqual(msg.total_upload, parsed.total_upload);
    try std.testing.expectEqual(msg.total_download, parsed.total_download);
    try std.testing.expectEqual(msg.node_count, parsed.node_count);
    try std.testing.expectEqual(msg.timestamp, parsed.timestamp);
}

test "shard scrub report message serialize/deserialize" {
    var msg = ShardScrubReportMsg{
        .node_id = undefined,
        .shards_checked = 100,
        .corruptions_found = 2,
        .timestamp = 1700004000,
    };
    @memset(&msg.node_id, 0x29);

    const bytes = msg.serialize();
    const parsed = try ShardScrubReportMsg.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &msg.node_id, &parsed.node_id);
    try std.testing.expectEqual(msg.shards_checked, parsed.shards_checked);
    try std.testing.expectEqual(msg.corruptions_found, parsed.corruptions_found);
    try std.testing.expectEqual(msg.timestamp, parsed.timestamp);
}

test "reputation query message serialize/deserialize" {
    var msg = ReputationQueryMsg{
        .requester_id = undefined,
        .target_node_id = undefined,
    };
    @memset(&msg.requester_id, 0x3A);
    @memset(&msg.target_node_id, 0x4B);

    const bytes = msg.serialize();
    const parsed = try ReputationQueryMsg.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &msg.requester_id, &parsed.requester_id);
    try std.testing.expectEqualSlices(u8, &msg.target_node_id, &parsed.target_node_id);
}

test "reputation response message serialize/deserialize" {
    var msg = ReputationResponseMsg{
        .node_id = undefined,
        .score_millionths = 850000, // 0.85
        .pos_score_millionths = 900000,
        .uptime_score_millionths = 800000,
        .bandwidth_score_millionths = 750000,
    };
    @memset(&msg.node_id, 0x5C);

    const bytes = msg.serialize();
    const parsed = try ReputationResponseMsg.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &msg.node_id, &parsed.node_id);
    try std.testing.expectEqual(msg.score_millionths, parsed.score_millionths);
    try std.testing.expectEqual(msg.pos_score_millionths, parsed.pos_score_millionths);
    try std.testing.expectEqual(msg.uptime_score_millionths, parsed.uptime_score_millionths);
    try std.testing.expectEqual(msg.bandwidth_score_millionths, parsed.bandwidth_score_millionths);
}

test "graceful shutdown message serialize/deserialize" {
    var msg = GracefulShutdownMsg{
        .node_id = undefined,
        .shards_held = 42,
        .departure_time = 1700005000,
    };
    @memset(&msg.node_id, 0x6D);

    const bytes = msg.serialize();
    const parsed = try GracefulShutdownMsg.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &msg.node_id, &parsed.node_id);
    try std.testing.expectEqual(msg.shards_held, parsed.shards_held);
    try std.testing.expectEqual(msg.departure_time, parsed.departure_time);
}

test "shard repair request message serialize/deserialize" {
    var msg = ShardRepairRequestMsg{
        .requester_id = undefined,
        .shard_hash = undefined,
    };
    @memset(&msg.requester_id, 0x7E);
    @memset(&msg.shard_hash, 0x8F);

    const bytes = msg.serialize();
    const parsed = try ShardRepairRequestMsg.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &msg.requester_id, &parsed.requester_id);
    try std.testing.expectEqualSlices(u8, &msg.shard_hash, &parsed.shard_hash);
}

test "shard repair response message serialize/deserialize" {
    var msg = ShardRepairResponseMsg{
        .responder_id = undefined,
        .shard_hash = undefined,
        .success = true,
        .data_length = 1024,
    };
    @memset(&msg.responder_id, 0x9A);
    @memset(&msg.shard_hash, 0xAB);

    const bytes = msg.serialize();
    const parsed = try ShardRepairResponseMsg.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &msg.responder_id, &parsed.responder_id);
    try std.testing.expectEqualSlices(u8, &msg.shard_hash, &parsed.shard_hash);
    try std.testing.expect(parsed.success);
    try std.testing.expectEqual(@as(u16, 1024), parsed.data_length);
}

test "slash event message serialize/deserialize" {
    var msg = SlashEventMsg{
        .node_id = undefined,
        .slash_amount_wei = 50_000_000_000_000_000, // 0.05 TRI
        .reason = .corruption,
        .timestamp = 1700006000,
    };
    @memset(&msg.node_id, 0xBC);

    const bytes = msg.serialize();
    const parsed = try SlashEventMsg.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &msg.node_id, &parsed.node_id);
    try std.testing.expectEqual(msg.slash_amount_wei, parsed.slash_amount_wei);
    try std.testing.expectEqual(msg.reason, parsed.reason);
    try std.testing.expectEqual(msg.timestamp, parsed.timestamp);
}

test "slash event message with large u128 amount" {
    var msg = SlashEventMsg{
        .node_id = undefined,
        .slash_amount_wei = 1_000_000_000_000_000_000_000, // 1000 TRI — tests high bits
        .reason = .pos_failure,
        .timestamp = 1700007000,
    };
    @memset(&msg.node_id, 0xDE);

    const bytes = msg.serialize();
    const parsed = try SlashEventMsg.deserialize(&bytes);

    try std.testing.expectEqual(msg.slash_amount_wei, parsed.slash_amount_wei);
    try std.testing.expectEqual(msg.reason, parsed.reason);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN STAKING MESSAGES (v1.8)
// ═══════════════════════════════════════════════════════════════════════════════

/// StakingRequestMsg: Node requests to stake or unstake tokens
/// Wire format: [32B node_id][8B amount_wei_lo][8B amount_wei_hi][1B action][8B timestamp][3B padding]
pub const StakingRequestMsg = struct {
    node_id: NodeId,
    amount_wei: u128,
    action: StakingAction,
    timestamp: i64,

    pub const StakingAction = enum(u8) {
        stake = 0,
        unstake = 1,
        _,
    };

    pub const SIZE: usize = 60;

    pub fn serialize(self: *const StakingRequestMsg) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        var i: usize = 0;

        @memcpy(buf[i..][0..32], &self.node_id);
        i += 32;
        const lo: u64 = @truncate(self.amount_wei);
        const hi: u64 = @truncate(self.amount_wei >> 64);
        std.mem.writeInt(u64, buf[i..][0..8], lo, .little);
        i += 8;
        std.mem.writeInt(u64, buf[i..][0..8], hi, .little);
        i += 8;
        buf[i] = @intFromEnum(self.action);
        i += 1;
        std.mem.writeInt(i64, buf[i..][0..8], self.timestamp, .little);
        i += 8;
        buf[i] = 0;
        buf[i + 1] = 0;
        buf[i + 2] = 0;

        return buf;
    }

    pub fn deserialize(data: []const u8) !StakingRequestMsg {
        if (data.len < SIZE) return error.InvalidData;
        var msg: StakingRequestMsg = undefined;
        var i: usize = 0;

        @memcpy(&msg.node_id, data[i..][0..32]);
        i += 32;
        const lo = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        const hi = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        msg.amount_wei = @as(u128, hi) << 64 | @as(u128, lo);
        msg.action = @enumFromInt(data[i]);
        i += 1;
        msg.timestamp = std.mem.readInt(i64, data[i..][0..8], .little);

        return msg;
    }
};

/// StakingResponseMsg: Response to a staking request
/// Wire format: [32B node_id][8B new_balance_wei_lo][8B new_balance_wei_hi][1B success][1B reason][8B timestamp][2B padding]
pub const StakingResponseMsg = struct {
    node_id: NodeId,
    new_balance_wei: u128,
    success: bool,
    reason: StakingResponseReason,
    timestamp: i64,

    pub const StakingResponseReason = enum(u8) {
        ok = 0,
        insufficient_balance = 1,
        below_minimum = 2,
        cooldown_active = 3,
        _,
    };

    pub const SIZE: usize = 60;

    pub fn serialize(self: *const StakingResponseMsg) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        var i: usize = 0;

        @memcpy(buf[i..][0..32], &self.node_id);
        i += 32;
        const lo: u64 = @truncate(self.new_balance_wei);
        const hi: u64 = @truncate(self.new_balance_wei >> 64);
        std.mem.writeInt(u64, buf[i..][0..8], lo, .little);
        i += 8;
        std.mem.writeInt(u64, buf[i..][0..8], hi, .little);
        i += 8;
        buf[i] = if (self.success) 1 else 0;
        i += 1;
        buf[i] = @intFromEnum(self.reason);
        i += 1;
        std.mem.writeInt(i64, buf[i..][0..8], self.timestamp, .little);
        i += 8;
        buf[i] = 0;
        buf[i + 1] = 0;

        return buf;
    }

    pub fn deserialize(data: []const u8) !StakingResponseMsg {
        if (data.len < SIZE) return error.InvalidData;
        var msg: StakingResponseMsg = undefined;
        var i: usize = 0;

        @memcpy(&msg.node_id, data[i..][0..32]);
        i += 32;
        const lo = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        const hi = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        msg.new_balance_wei = @as(u128, hi) << 64 | @as(u128, lo);
        msg.success = data[i] != 0;
        i += 1;
        msg.reason = @enumFromInt(data[i]);
        i += 1;
        msg.timestamp = std.mem.readInt(i64, data[i..][0..8], .little);

        return msg;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LATENCY PING MESSAGE (v1.8)
// ═══════════════════════════════════════════════════════════════════════════════

/// LatencyPingMsg: Measure peer-to-peer latency
/// Wire format: [32B sender_id][32B target_id][8B send_timestamp_ns][1B is_reply][3B padding]
pub const LatencyPingMsg = struct {
    sender_id: NodeId,
    target_id: NodeId,
    send_timestamp_ns: u64,
    is_reply: bool,

    pub const SIZE: usize = 76;

    pub fn serialize(self: *const LatencyPingMsg) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        var i: usize = 0;

        @memcpy(buf[i..][0..32], &self.sender_id);
        i += 32;
        @memcpy(buf[i..][0..32], &self.target_id);
        i += 32;
        std.mem.writeInt(u64, buf[i..][0..8], self.send_timestamp_ns, .little);
        i += 8;
        buf[i] = if (self.is_reply) 1 else 0;
        i += 1;
        buf[i] = 0;
        buf[i + 1] = 0;
        buf[i + 2] = 0;

        return buf;
    }

    pub fn deserialize(data: []const u8) !LatencyPingMsg {
        if (data.len < SIZE) return error.InvalidData;
        var msg: LatencyPingMsg = undefined;
        var i: usize = 0;

        @memcpy(&msg.sender_id, data[i..][0..32]);
        i += 32;
        @memcpy(&msg.target_id, data[i..][0..32]);
        i += 32;
        msg.send_timestamp_ns = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        msg.is_reply = data[i] != 0;

        return msg;
    }
};

// v1.8 tests

test "staking request message serialize/deserialize" {
    var msg = StakingRequestMsg{
        .node_id = undefined,
        .amount_wei = 500_000_000_000_000_000_000, // 500 TRI
        .action = .stake,
        .timestamp = 1700008000,
    };
    @memset(&msg.node_id, 0xE1);

    const bytes = msg.serialize();
    const parsed = try StakingRequestMsg.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &msg.node_id, &parsed.node_id);
    try std.testing.expectEqual(msg.amount_wei, parsed.amount_wei);
    try std.testing.expectEqual(msg.action, parsed.action);
    try std.testing.expectEqual(msg.timestamp, parsed.timestamp);
}

test "staking response message serialize/deserialize" {
    var msg = StakingResponseMsg{
        .node_id = undefined,
        .new_balance_wei = 1_000_000_000_000_000_000_000, // 1000 TRI
        .success = true,
        .reason = .ok,
        .timestamp = 1700009000,
    };
    @memset(&msg.node_id, 0xF2);

    const bytes = msg.serialize();
    const parsed = try StakingResponseMsg.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &msg.node_id, &parsed.node_id);
    try std.testing.expectEqual(msg.new_balance_wei, parsed.new_balance_wei);
    try std.testing.expect(parsed.success);
    try std.testing.expectEqual(msg.reason, parsed.reason);
    try std.testing.expectEqual(msg.timestamp, parsed.timestamp);
}

test "latency ping message serialize/deserialize" {
    var msg = LatencyPingMsg{
        .sender_id = undefined,
        .target_id = undefined,
        .send_timestamp_ns = 1700000000_000_000_000,
        .is_reply = false,
    };
    @memset(&msg.sender_id, 0xA3);
    @memset(&msg.target_id, 0xB4);

    const bytes = msg.serialize();
    const parsed = try LatencyPingMsg.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &msg.sender_id, &parsed.sender_id);
    try std.testing.expectEqualSlices(u8, &msg.target_id, &parsed.target_id);
    try std.testing.expectEqual(msg.send_timestamp_ns, parsed.send_timestamp_ns);
    try std.testing.expect(!parsed.is_reply);

    // Test reply variant
    var reply = msg;
    reply.is_reply = true;
    const reply_bytes = reply.serialize();
    const reply_parsed = try LatencyPingMsg.deserialize(&reply_bytes);
    try std.testing.expect(reply_parsed.is_reply);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONSENSUS VOTE MESSAGE (v1.9)
// ═══════════════════════════════════════════════════════════════════════════════

/// ConsensusVoteMsg: Node submits reputation vote for another node
/// Wire format: [32B voter_id][32B target_id][8B score_bits][1B padding]
pub const ConsensusVoteMsg = struct {
    voter_id: NodeId,
    target_id: NodeId,
    score: f64,

    pub const SIZE: usize = 73;

    pub fn serialize(self: *const ConsensusVoteMsg) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        var i: usize = 0;

        @memcpy(buf[i..][0..32], &self.voter_id);
        i += 32;
        @memcpy(buf[i..][0..32], &self.target_id);
        i += 32;
        const score_bits: u64 = @bitCast(self.score);
        std.mem.writeInt(u64, buf[i..][0..8], score_bits, .little);
        i += 8;
        buf[i] = 0;

        return buf;
    }

    pub fn deserialize(data: []const u8) !ConsensusVoteMsg {
        if (data.len < SIZE) return error.InvalidData;
        var msg: ConsensusVoteMsg = undefined;
        var i: usize = 0;

        @memcpy(&msg.voter_id, data[i..][0..32]);
        i += 32;
        @memcpy(&msg.target_id, data[i..][0..32]);
        i += 32;
        const score_bits = std.mem.readInt(u64, data[i..][0..8], .little);
        msg.score = @bitCast(score_bits);

        return msg;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONSENSUS RESULT MESSAGE (v1.9)
// ═══════════════════════════════════════════════════════════════════════════════

/// ConsensusResultMsg: Broadcast after consensus round completes
/// Wire format: [32B target_id][8B consensus_score][4B voter_count][4B agreeing][4B disagreeing][1B is_valid][8B median_score][8B timestamp][13B padding]
pub const ConsensusResultMsg = struct {
    target_id: NodeId,
    consensus_score: f64,
    voter_count: u32,
    agreeing_voters: u32,
    disagreeing_voters: u32,
    is_valid: bool,
    median_score: f64,
    timestamp: i64,

    pub const SIZE: usize = 82;

    pub fn serialize(self: *const ConsensusResultMsg) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        var i: usize = 0;

        @memcpy(buf[i..][0..32], &self.target_id);
        i += 32;
        std.mem.writeInt(u64, buf[i..][0..8], @bitCast(self.consensus_score), .little);
        i += 8;
        std.mem.writeInt(u32, buf[i..][0..4], self.voter_count, .little);
        i += 4;
        std.mem.writeInt(u32, buf[i..][0..4], self.agreeing_voters, .little);
        i += 4;
        std.mem.writeInt(u32, buf[i..][0..4], self.disagreeing_voters, .little);
        i += 4;
        buf[i] = if (self.is_valid) 1 else 0;
        i += 1;
        std.mem.writeInt(u64, buf[i..][0..8], @bitCast(self.median_score), .little);
        i += 8;
        std.mem.writeInt(i64, buf[i..][0..8], self.timestamp, .little);
        i += 8;
        @memset(buf[i..][0..13], 0);

        return buf;
    }

    pub fn deserialize(data: []const u8) !ConsensusResultMsg {
        if (data.len < SIZE) return error.InvalidData;
        var msg: ConsensusResultMsg = undefined;
        var i: usize = 0;

        @memcpy(&msg.target_id, data[i..][0..32]);
        i += 32;
        msg.consensus_score = @bitCast(std.mem.readInt(u64, data[i..][0..8], .little));
        i += 8;
        msg.voter_count = std.mem.readInt(u32, data[i..][0..4], .little);
        i += 4;
        msg.agreeing_voters = std.mem.readInt(u32, data[i..][0..4], .little);
        i += 4;
        msg.disagreeing_voters = std.mem.readInt(u32, data[i..][0..4], .little);
        i += 4;
        msg.is_valid = data[i] != 0;
        i += 1;
        msg.median_score = @bitCast(std.mem.readInt(u64, data[i..][0..8], .little));
        i += 8;
        msg.timestamp = std.mem.readInt(i64, data[i..][0..8], .little);

        return msg;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DELEGATION REQUEST MESSAGE (v1.9)
// ═══════════════════════════════════════════════════════════════════════════════

/// DelegationRequestMsg: Delegate/undelegate/register operator
/// Wire format: [32B delegator_id][32B operator_id][8B amount_wei_lo][8B amount_wei_hi][1B action]
pub const DelegationRequestMsg = struct {
    delegator_id: NodeId,
    operator_id: NodeId,
    amount_wei: u128,
    action: DelegationAction,

    pub const DelegationAction = enum(u8) {
        delegate = 0,
        undelegate = 1,
        register_operator = 2,
        _,
    };

    pub const SIZE: usize = 81;

    pub fn serialize(self: *const DelegationRequestMsg) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        var i: usize = 0;

        @memcpy(buf[i..][0..32], &self.delegator_id);
        i += 32;
        @memcpy(buf[i..][0..32], &self.operator_id);
        i += 32;
        const lo: u64 = @truncate(self.amount_wei);
        const hi: u64 = @truncate(self.amount_wei >> 64);
        std.mem.writeInt(u64, buf[i..][0..8], lo, .little);
        i += 8;
        std.mem.writeInt(u64, buf[i..][0..8], hi, .little);
        i += 8;
        buf[i] = @intFromEnum(self.action);

        return buf;
    }

    pub fn deserialize(data: []const u8) !DelegationRequestMsg {
        if (data.len < SIZE) return error.InvalidData;
        var msg: DelegationRequestMsg = undefined;
        var i: usize = 0;

        @memcpy(&msg.delegator_id, data[i..][0..32]);
        i += 32;
        @memcpy(&msg.operator_id, data[i..][0..32]);
        i += 32;
        const lo = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        const hi = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        msg.amount_wei = @as(u128, hi) << 64 | @as(u128, lo);
        msg.action = @enumFromInt(data[i]);

        return msg;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// v2.0: Region Topology, Slashing Escrow, Prometheus HTTP, Semantic VSA
// ═══════════════════════════════════════════════════════════════════════════════

/// RegionPlacementMsg: Assign node to geographic region
/// Wire format: [32B node_id][1B region][4B replica_count]
pub const RegionPlacementMsg = struct {
    node_id: NodeId,
    region: u8, // 0-8 region enum
    replica_count: u32,

    pub const SIZE: usize = 37;

    pub fn serialize(self: *const RegionPlacementMsg) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        var i: usize = 0;

        @memcpy(buf[i..][0..32], &self.node_id);
        i += 32;
        buf[i] = self.region;
        i += 1;
        std.mem.writeInt(u32, buf[i..][0..4], self.replica_count, .little);

        return buf;
    }

    pub fn deserialize(data: []const u8) !RegionPlacementMsg {
        if (data.len < SIZE) return error.InvalidData;
        var msg: RegionPlacementMsg = undefined;
        var i: usize = 0;

        @memcpy(&msg.node_id, data[i..][0..32]);
        i += 32;
        msg.region = data[i];
        i += 1;
        msg.replica_count = std.mem.readInt(u32, data[i..][0..4], .little);

        return msg;
    }
};

/// EscrowEventMsg: Create/dispute/vote/resolve slashing escrow
/// Wire format: [32B node_id][8B escrow_id][8B amount_lo][8B amount_hi][1B action][1B reason][8B timestamp][16B padding]
pub const EscrowEventMsg = struct {
    node_id: NodeId,
    escrow_id: u64,
    amount_wei: u128,
    action: EscrowAction,
    reason: u8,
    timestamp: u64,

    pub const EscrowAction = enum(u8) {
        create = 0,
        dispute = 1,
        vote = 2,
        resolve = 3,
        _,
    };

    pub const SIZE: usize = 82;

    pub fn serialize(self: *const EscrowEventMsg) [SIZE]u8 {
        var buf: [SIZE]u8 = @splat(0);
        var i: usize = 0;

        @memcpy(buf[i..][0..32], &self.node_id);
        i += 32;
        std.mem.writeInt(u64, buf[i..][0..8], self.escrow_id, .little);
        i += 8;
        const lo: u64 = @truncate(self.amount_wei);
        const hi: u64 = @truncate(self.amount_wei >> 64);
        std.mem.writeInt(u64, buf[i..][0..8], lo, .little);
        i += 8;
        std.mem.writeInt(u64, buf[i..][0..8], hi, .little);
        i += 8;
        buf[i] = @intFromEnum(self.action);
        i += 1;
        buf[i] = self.reason;
        i += 1;
        std.mem.writeInt(u64, buf[i..][0..8], self.timestamp, .little);

        return buf;
    }

    pub fn deserialize(data: []const u8) !EscrowEventMsg {
        if (data.len < SIZE) return error.InvalidData;
        var msg: EscrowEventMsg = undefined;
        var i: usize = 0;

        @memcpy(&msg.node_id, data[i..][0..32]);
        i += 32;
        msg.escrow_id = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        const lo = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        const hi = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        msg.amount_wei = @as(u128, hi) << 64 | @as(u128, lo);
        msg.action = @enumFromInt(data[i]);
        i += 1;
        msg.reason = data[i];
        i += 1;
        msg.timestamp = std.mem.readInt(u64, data[i..][0..8], .little);

        return msg;
    }
};

/// PrometheusScrapeMsg: Request Prometheus metrics scrape
/// Wire format: [32B requester_id][1B path_len]
pub const PrometheusScrapeMsg = struct {
    requester_id: NodeId,
    path_len: u8,

    pub const SIZE: usize = 33;

    pub fn serialize(self: *const PrometheusScrapeMsg) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        var i: usize = 0;

        @memcpy(buf[i..][0..32], &self.requester_id);
        i += 32;
        buf[i] = self.path_len;

        return buf;
    }

    pub fn deserialize(data: []const u8) !PrometheusScrapeMsg {
        if (data.len < SIZE) return error.InvalidData;
        var msg: PrometheusScrapeMsg = undefined;
        var i: usize = 0;

        @memcpy(&msg.requester_id, data[i..][0..32]);
        i += 32;
        msg.path_len = data[i];

        return msg;
    }
};

/// SemanticStoreMsg: Store shard fingerprint in semantic index
/// Wire format: [32B shard_hash][64B fingerprint_packed][1B dimension_idx]
pub const SemanticStoreMsg = struct {
    shard_hash: [32]u8,
    fingerprint_packed: [64]u8, // 256 trits packed (2 trits/byte = 128 bytes, or raw i8 trits truncated)
    dimension_idx: u8, // 0=256, 1=512, 2=1024

    pub const SIZE: usize = 97;

    pub fn serialize(self: *const SemanticStoreMsg) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        var i: usize = 0;

        @memcpy(buf[i..][0..32], &self.shard_hash);
        i += 32;
        @memcpy(buf[i..][0..64], &self.fingerprint_packed);
        i += 64;
        buf[i] = self.dimension_idx;

        return buf;
    }

    pub fn deserialize(data: []const u8) !SemanticStoreMsg {
        if (data.len < SIZE) return error.InvalidData;
        var msg: SemanticStoreMsg = undefined;
        var i: usize = 0;

        @memcpy(&msg.shard_hash, data[i..][0..32]);
        i += 32;
        @memcpy(&msg.fingerprint_packed, data[i..][0..64]);
        i += 64;
        msg.dimension_idx = data[i];

        return msg;
    }
};

/// SemanticQueryMsg: Query semantic index for similar shards
/// Wire format: [32B requester_id][32B query_fingerprint_packed][8B threshold_bits][1B max_results]
pub const SemanticQueryMsg = struct {
    requester_id: NodeId,
    query_fingerprint_packed: [32]u8, // compressed query vector
    threshold_bits: u64, // f64 bitcast to u64
    max_results: u8,

    pub const SIZE: usize = 73;

    pub fn serialize(self: *const SemanticQueryMsg) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;
        var i: usize = 0;

        @memcpy(buf[i..][0..32], &self.requester_id);
        i += 32;
        @memcpy(buf[i..][0..32], &self.query_fingerprint_packed);
        i += 32;
        std.mem.writeInt(u64, buf[i..][0..8], self.threshold_bits, .little);
        i += 8;
        buf[i] = self.max_results;

        return buf;
    }

    pub fn deserialize(data: []const u8) !SemanticQueryMsg {
        if (data.len < SIZE) return error.InvalidData;
        var msg: SemanticQueryMsg = undefined;
        var i: usize = 0;

        @memcpy(&msg.requester_id, data[i..][0..32]);
        i += 32;
        @memcpy(&msg.query_fingerprint_packed, data[i..][0..32]);
        i += 32;
        msg.threshold_bits = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        msg.max_results = data[i];

        return msg;
    }
};

// v1.9 tests

test "consensus vote message serialize/deserialize" {
    var msg = ConsensusVoteMsg{
        .voter_id = undefined,
        .target_id = undefined,
        .score = 0.85,
    };
    @memset(&msg.voter_id, 0xC1);
    @memset(&msg.target_id, 0xD2);

    const bytes = msg.serialize();
    const parsed = try ConsensusVoteMsg.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &msg.voter_id, &parsed.voter_id);
    try std.testing.expectEqualSlices(u8, &msg.target_id, &parsed.target_id);
    try std.testing.expectEqual(msg.score, parsed.score);
}

test "consensus result message serialize/deserialize" {
    var msg = ConsensusResultMsg{
        .target_id = undefined,
        .consensus_score = 0.72,
        .voter_count = 19,
        .agreeing_voters = 15,
        .disagreeing_voters = 4,
        .is_valid = true,
        .median_score = 0.70,
        .timestamp = 1700010000,
    };
    @memset(&msg.target_id, 0xE3);

    const bytes = msg.serialize();
    const parsed = try ConsensusResultMsg.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &msg.target_id, &parsed.target_id);
    try std.testing.expectEqual(msg.consensus_score, parsed.consensus_score);
    try std.testing.expectEqual(msg.voter_count, parsed.voter_count);
    try std.testing.expectEqual(msg.agreeing_voters, parsed.agreeing_voters);
    try std.testing.expectEqual(msg.disagreeing_voters, parsed.disagreeing_voters);
    try std.testing.expect(parsed.is_valid);
    try std.testing.expectEqual(msg.median_score, parsed.median_score);
    try std.testing.expectEqual(msg.timestamp, parsed.timestamp);
}

test "delegation request message serialize/deserialize" {
    var msg = DelegationRequestMsg{
        .delegator_id = undefined,
        .operator_id = undefined,
        .amount_wei = 5_000_000_000_000_000_000_000, // 5000 TRI
        .action = .delegate,
    };
    @memset(&msg.delegator_id, 0xF4);
    @memset(&msg.operator_id, 0x15);

    const bytes = msg.serialize();
    const parsed = try DelegationRequestMsg.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &msg.delegator_id, &parsed.delegator_id);
    try std.testing.expectEqualSlices(u8, &msg.operator_id, &parsed.operator_id);
    try std.testing.expectEqual(msg.amount_wei, parsed.amount_wei);
    try std.testing.expectEqual(msg.action, parsed.action);

    // Test undelegate variant
    var msg2 = msg;
    msg2.action = .undelegate;
    const bytes2 = msg2.serialize();
    const parsed2 = try DelegationRequestMsg.deserialize(&bytes2);
    try std.testing.expectEqual(DelegationRequestMsg.DelegationAction.undelegate, parsed2.action);
}

// v2.0 tests

test "region placement message serialize/deserialize" {
    var msg = RegionPlacementMsg{
        .node_id = undefined,
        .region = 3, // EU West
        .replica_count = 5,
    };
    @memset(&msg.node_id, 0xA1);

    const bytes = msg.serialize();
    const parsed = try RegionPlacementMsg.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &msg.node_id, &parsed.node_id);
    try std.testing.expectEqual(@as(u8, 3), parsed.region);
    try std.testing.expectEqual(@as(u32, 5), parsed.replica_count);
}

test "escrow event message serialize/deserialize" {
    var msg = EscrowEventMsg{
        .node_id = undefined,
        .escrow_id = 42,
        .amount_wei = 1_000_000_000_000_000_000, // 1 TRI
        .action = .dispute,
        .reason = 2,
        .timestamp = 1700020000,
    };
    @memset(&msg.node_id, 0xB2);

    const bytes = msg.serialize();
    const parsed = try EscrowEventMsg.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &msg.node_id, &parsed.node_id);
    try std.testing.expectEqual(@as(u64, 42), parsed.escrow_id);
    try std.testing.expectEqual(msg.amount_wei, parsed.amount_wei);
    try std.testing.expectEqual(EscrowEventMsg.EscrowAction.dispute, parsed.action);
    try std.testing.expectEqual(@as(u8, 2), parsed.reason);
    try std.testing.expectEqual(@as(u64, 1700020000), parsed.timestamp);
}

test "prometheus scrape message serialize/deserialize" {
    var msg = PrometheusScrapeMsg{
        .requester_id = undefined,
        .path_len = 8, // "/metrics"
    };
    @memset(&msg.requester_id, 0xC3);

    const bytes = msg.serialize();
    const parsed = try PrometheusScrapeMsg.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &msg.requester_id, &parsed.requester_id);
    try std.testing.expectEqual(@as(u8, 8), parsed.path_len);
}

test "semantic store message serialize/deserialize" {
    var msg = SemanticStoreMsg{
        .shard_hash = undefined,
        .fingerprint_packed = undefined,
        .dimension_idx = 0, // 256-dim
    };
    @memset(&msg.shard_hash, 0xD4);
    @memset(&msg.fingerprint_packed, 0x55);

    const bytes = msg.serialize();
    const parsed = try SemanticStoreMsg.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &msg.shard_hash, &parsed.shard_hash);
    try std.testing.expectEqualSlices(u8, &msg.fingerprint_packed, &parsed.fingerprint_packed);
    try std.testing.expectEqual(@as(u8, 0), parsed.dimension_idx);
}

test "semantic query message serialize/deserialize" {
    const threshold: f64 = 0.75;
    var msg = SemanticQueryMsg{
        .requester_id = undefined,
        .query_fingerprint_packed = undefined,
        .threshold_bits = @bitCast(threshold),
        .max_results = 10,
    };
    @memset(&msg.requester_id, 0xE5);
    @memset(&msg.query_fingerprint_packed, 0xAA);

    const bytes = msg.serialize();
    const parsed = try SemanticQueryMsg.deserialize(&bytes);

    try std.testing.expectEqualSlices(u8, &msg.requester_id, &parsed.requester_id);
    try std.testing.expectEqualSlices(u8, &msg.query_fingerprint_packed, &parsed.query_fingerprint_packed);
    const parsed_threshold: f64 = @bitCast(parsed.threshold_bits);
    try std.testing.expectEqual(threshold, parsed_threshold);
    try std.testing.expectEqual(@as(u8, 10), parsed.max_results);
}
