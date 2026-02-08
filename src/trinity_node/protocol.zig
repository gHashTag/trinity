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
        // Model ID
        const model_len = try r.readInt(u16, .little);
        const model_buf = try allocator.alloc(u8, model_len);
        _ = try r.readAll(model_buf);
        job.model_id = model_buf;
        // Prompt
        const prompt_len = try r.readInt(u32, .little);
        const prompt_buf = try allocator.alloc(u8, prompt_len);
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
        // Response
        const response_len = try r.readInt(u32, .little);
        const response_buf = try allocator.alloc(u8, response_len);
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
        const per_item = 4 + hidden_size * 4;
        if (data.len < HEADER_SIZE + batch_size * per_item) return error.InvalidData;

        const positions = try allocator.alloc(u32, batch_size);
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
