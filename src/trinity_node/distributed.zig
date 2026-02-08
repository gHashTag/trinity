// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY NODE - Pipeline-Parallel Distributed Inference (Optimized)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Splits a GGUF model's transformer layers across 2+ nodes.
// Each node loads a contiguous subset of layers and processes them sequentially.
// Hidden state (8KB for TinyLlama) is transferred between nodes via TCP.
//
// Optimizations (v2):
//   - Batch prefill: all prompt hidden states sent in 1 TCP round-trip
//   - TCP_NODELAY: disables Nagle buffering
//   - Coalesced writes: header+payload in single syscall
//   - Pre-allocated buffers: zero heap allocs in hot path
//   - Timing instrumentation: compute vs network breakdown
//
// Architecture:
//   [Coordinator: layers 0..N/2]  --TCP-->  [Worker: layers N/2..N]
//   embed(token)                            recv hidden_state
//   forwardShard()                          forwardShard()
//   send hidden_state                       computeLogits + sample
//   recv token                              send token
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const protocol = @import("protocol.zig");
const gguf_model = @import("gguf_model");

// ═══════════════════════════════════════════════════════════════════════════════
// SHARD CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const ShardConfig = struct {
    total_layers: u32,
    start_layer: u32, // inclusive
    end_layer: u32, // exclusive
    is_first: bool, // owns embedding
    is_last: bool, // owns output_norm + output_weight
    hidden_size: u32,
    model_path: []const u8,

    pub fn layerCount(self: ShardConfig) u32 {
        return self.end_layer - self.start_layer;
    }

    /// Auto-split for 2 nodes: coordinator gets first half, worker gets second half
    pub fn autoSplit(total_layers: u32, model_path: []const u8, hidden_size: u32) struct { coordinator: ShardConfig, worker: ShardConfig } {
        const mid = total_layers / 2;
        return .{
            .coordinator = ShardConfig{
                .total_layers = total_layers,
                .start_layer = 0,
                .end_layer = mid,
                .is_first = true,
                .is_last = false,
                .hidden_size = hidden_size,
                .model_path = model_path,
            },
            .worker = ShardConfig{
                .total_layers = total_layers,
                .start_layer = mid,
                .end_layer = total_layers,
                .is_first = false,
                .is_last = true,
                .hidden_size = hidden_size,
                .model_path = model_path,
            },
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PIPELINE WORKER (runs on second/subsequent nodes)
// ═══════════════════════════════════════════════════════════════════════════════

pub const PipelineWorker = struct {
    allocator: std.mem.Allocator,
    model: gguf_model.FullModel,
    shard: ShardConfig,
    listen_port: u16,
    running: std.atomic.Value(bool),
    server_thread: ?std.Thread = null,
    // Pre-allocated hot-path buffers (zero allocs per token)
    output_buf: []f32,
    logits_buf: []f32,
    probs_buf: []f32,

    pub fn init(allocator: std.mem.Allocator, shard: ShardConfig, port: u16) !PipelineWorker {
        std.debug.print("\n\x1b[38;2;255;215;0m[Worker] Initializing pipeline shard: layers {d}..{d}\x1b[0m\n", .{
            shard.start_layer, shard.end_layer,
        });

        var model = try gguf_model.FullModel.init(allocator, shard.model_path);
        try model.loadPartialWeights(shard.start_layer, shard.end_layer, shard.is_first, shard.is_last);

        std.debug.print("\x1b[38;2;0;229;153m[Worker] Model shard loaded. Listening on port {d}\x1b[0m\n", .{port});

        return PipelineWorker{
            .allocator = allocator,
            .model = model,
            .shard = shard,
            .listen_port = port,
            .running = std.atomic.Value(bool).init(true),
            .output_buf = try allocator.alloc(f32, shard.hidden_size),
            .logits_buf = try allocator.alloc(f32, model.config.vocab_size),
            .probs_buf = try allocator.alloc(f32, model.config.vocab_size),
        };
    }

    pub fn deinit(self: *PipelineWorker) void {
        self.stop();
        self.allocator.free(self.output_buf);
        self.allocator.free(self.logits_buf);
        self.allocator.free(self.probs_buf);
        self.model.deinit();
    }

    pub fn start(self: *PipelineWorker) !void {
        self.server_thread = try std.Thread.spawn(.{}, serverLoop, .{self});
    }

    pub fn stop(self: *PipelineWorker) void {
        self.running.store(false, .release);
        if (self.server_thread) |t| {
            t.join();
            self.server_thread = null;
        }
    }

    fn serverLoop(self: *PipelineWorker) void {
        const addr = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, self.listen_port);
        const sock = std.posix.socket(std.posix.AF.INET, std.posix.SOCK.STREAM, 0) catch |err| {
            std.debug.print("\x1b[38;2;239;68;68m[Worker] Socket error: {}\x1b[0m\n", .{err});
            return;
        };
        defer std.posix.close(sock);

        // Enable SO_REUSEADDR
        const optval: u32 = 1;
        std.posix.setsockopt(sock, std.posix.SOL.SOCKET, std.posix.SO.REUSEADDR, std.mem.asBytes(&optval)) catch {};

        std.posix.bind(sock, &addr.any, addr.getOsSockLen()) catch |err| {
            std.debug.print("\x1b[38;2;239;68;68m[Worker] Bind error on port {d}: {}\x1b[0m\n", .{ self.listen_port, err });
            return;
        };

        std.posix.listen(sock, 10) catch |err| {
            std.debug.print("\x1b[38;2;239;68;68m[Worker] Listen error: {}\x1b[0m\n", .{err});
            return;
        };

        std.debug.print("\x1b[38;2;0;229;153m[Worker] Listening on 0.0.0.0:{d} — ready for forward requests\x1b[0m\n", .{self.listen_port});

        while (self.running.load(.acquire)) {
            var client_addr: std.net.Address = undefined;
            var addr_len: std.posix.socklen_t = @sizeOf(std.posix.sockaddr);
            const client = std.posix.accept(sock, &client_addr.any, &addr_len, 0) catch |err| {
                if (!self.running.load(.acquire)) break;
                std.debug.print("\x1b[38;2;239;68;68m[Worker] Accept error: {}\x1b[0m\n", .{err});
                continue;
            };

            setTcpNodelay(client);
            std.debug.print("\x1b[38;2;0;255;255m[Worker] Connection from coordinator\x1b[0m\n", .{});
            self.handleSession(client);
            std.posix.close(client);
            std.debug.print("\x1b[38;2;156;156;160m[Worker] Session ended\x1b[0m\n", .{});
        }
    }

    /// Handle a persistent session — dispatches single and batch forward requests
    fn handleSession(self: *PipelineWorker, sock: std.posix.socket_t) void {
        var tokens_processed: u32 = 0;
        const session_start = std.time.milliTimestamp();

        while (self.running.load(.acquire)) {
            // Read message header (9 bytes: TRIN + type + length)
            var header_buf: [protocol.MessageHeader.SIZE]u8 = undefined;
            const header_read = readExact(sock, &header_buf) catch break;
            if (header_read < protocol.MessageHeader.SIZE) break;

            const header = protocol.MessageHeader.deserialize(&header_buf) catch break;

            switch (header.msg_type) {
                .forward_request => {
                    self.handleSingleForward(sock, header.length) catch break;
                    tokens_processed += 1;
                },
                .batch_forward_request => {
                    const batch_count = self.handleBatchForward(sock, header.length) catch break;
                    tokens_processed += batch_count;
                },
                else => break,
            }
        }

        const elapsed = std.time.milliTimestamp() - session_start;
        std.debug.print("\x1b[38;2;0;229;153m[Worker] Processed {d} tokens in {d}ms\x1b[0m\n", .{ tokens_processed, elapsed });
    }

    /// Handle a single-token forward request (used during decode phase)
    fn handleSingleForward(self: *PipelineWorker, sock: std.posix.socket_t, payload_len: u32) !void {
        // Read payload
        const payload = try self.allocator.alloc(u8, payload_len);
        defer self.allocator.free(payload);
        const payload_read = try readExact(sock, payload);
        if (payload_read < payload.len) return error.IncompleteRead;

        // Deserialize
        const req = try protocol.ForwardRequest.deserialize(payload, self.allocator);
        defer self.allocator.free(req.hidden_state);

        // Process through local layers (zero-alloc: uses pre-allocated output_buf)
        self.model.forwardShard(self.output_buf, req.hidden_state, req.token_pos);

        // Compute logits + sample (zero-alloc: uses pre-allocated logits_buf/probs_buf)
        var sampled_token: u32 = 0;
        if (self.shard.is_last) {
            self.model.computeLogitsInto(self.logits_buf, self.output_buf);
            sampled_token = self.model.sampleFromLogitsInto(self.logits_buf, self.probs_buf, req.temperature);
        }

        // Send response (coalesced header + payload)
        const resp = protocol.ForwardResponse{
            .sequence_id = req.sequence_id,
            .token_pos = req.token_pos,
            .sampled_token = sampled_token,
        };
        const resp_header = protocol.MessageHeader{
            .msg_type = .forward_response,
            .length = protocol.ForwardResponse.SIZE,
        };
        var combined: [protocol.MessageHeader.SIZE + protocol.ForwardResponse.SIZE]u8 = undefined;
        const hdr_bytes = resp_header.serialize();
        const resp_bytes = resp.serialize();
        @memcpy(combined[0..protocol.MessageHeader.SIZE], &hdr_bytes);
        @memcpy(combined[protocol.MessageHeader.SIZE..], &resp_bytes);
        _ = try std.posix.write(sock, &combined);
    }

    /// Handle a batched forward request (used during prefill phase)
    fn handleBatchForward(self: *PipelineWorker, sock: std.posix.socket_t, payload_len: u32) !u32 {
        // Read full payload
        const payload = try self.allocator.alloc(u8, payload_len);
        defer self.allocator.free(payload);
        const payload_read = try readExact(sock, payload);
        if (payload_read < payload.len) return error.IncompleteRead;

        // Deserialize batch request
        const req = try protocol.BatchForwardRequest.deserialize(payload, self.allocator);
        defer self.allocator.free(@constCast(req.token_positions));
        defer self.allocator.free(@constCast(req.hidden_states));

        // Allocate result tokens
        const sampled_tokens = try self.allocator.alloc(u32, req.batch_size);
        defer self.allocator.free(sampled_tokens);

        std.debug.print("\x1b[38;2;0;255;255m[Worker] Processing batch of {d} tokens: \x1b[0m", .{req.batch_size});

        // Process each token SEQUENTIALLY (KV cache must see tokens in order)
        for (0..req.batch_size) |i| {
            const hs_offset = i * req.hidden_size;
            const input_slice = req.hidden_states[hs_offset..][0..req.hidden_size];

            // Forward through local layers (zero-alloc)
            self.model.forwardShard(self.output_buf, input_slice, req.token_positions[i]);

            // Compute logits + sample (zero-alloc)
            if (self.shard.is_last) {
                self.model.computeLogitsInto(self.logits_buf, self.output_buf);
                sampled_tokens[i] = self.model.sampleFromLogitsInto(self.logits_buf, self.probs_buf, req.temperature);
            } else {
                sampled_tokens[i] = 0;
            }

            if (i % 5 == 0) std.debug.print(".", .{});
        }
        std.debug.print(" done\n", .{});

        // Send batch response
        const resp = protocol.BatchForwardResponse{
            .sequence_id = req.sequence_id,
            .batch_size = req.batch_size,
            .sampled_tokens = sampled_tokens,
        };
        const resp_payload = try resp.serialize(self.allocator);
        defer self.allocator.free(resp_payload);

        const resp_header = protocol.MessageHeader{
            .msg_type = .batch_forward_response,
            .length = @intCast(resp_payload.len),
        };
        const hdr_bytes = resp_header.serialize();
        _ = try std.posix.write(sock, &hdr_bytes);
        _ = try std.posix.write(sock, resp_payload);

        return req.batch_size;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PIPELINE COORDINATOR (runs on the first node)
// ═══════════════════════════════════════════════════════════════════════════════

pub const PipelineCoordinator = struct {
    allocator: std.mem.Allocator,
    model: gguf_model.FullModel,
    shard: ShardConfig,
    peer_host: []const u8,
    peer_port: u16,
    sock: ?std.posix.socket_t = null,
    // Timing instrumentation
    time_prefill_local_ms: i64 = 0,
    time_prefill_net_ms: i64 = 0,
    time_decode_compute_ms: i64 = 0,
    time_decode_net_ms: i64 = 0,

    pub fn init(allocator: std.mem.Allocator, shard: ShardConfig, peer_host: []const u8, peer_port: u16) !PipelineCoordinator {
        std.debug.print("\n\x1b[38;2;255;215;0m[Coordinator] Initializing pipeline shard: layers {d}..{d}\x1b[0m\n", .{
            shard.start_layer, shard.end_layer,
        });

        var model = try gguf_model.FullModel.init(allocator, shard.model_path);
        try model.loadPartialWeights(shard.start_layer, shard.end_layer, shard.is_first, shard.is_last);

        std.debug.print("\x1b[38;2;0;229;153m[Coordinator] Model shard loaded. Peer: {s}:{d}\x1b[0m\n", .{ peer_host, peer_port });

        return PipelineCoordinator{
            .allocator = allocator,
            .model = model,
            .shard = shard,
            .peer_host = peer_host,
            .peer_port = peer_port,
        };
    }

    pub fn deinit(self: *PipelineCoordinator) void {
        self.disconnect();
        self.model.deinit();
    }

    fn connect(self: *PipelineCoordinator) !void {
        if (self.sock != null) return;

        std.debug.print("\x1b[38;2;0;255;255m[Coordinator] Connecting to worker {s}:{d}...\x1b[0m\n", .{ self.peer_host, self.peer_port });

        // Parse host to IPv4
        var ip_parts: [4]u8 = .{ 127, 0, 0, 1 };
        var part_idx: usize = 0;
        var current: u8 = 0;
        for (self.peer_host) |c| {
            if (c == '.') {
                if (part_idx < 4) ip_parts[part_idx] = current;
                part_idx += 1;
                current = 0;
            } else if (c >= '0' and c <= '9') {
                current = current * 10 + (c - '0');
            }
        }
        if (part_idx < 4) ip_parts[part_idx] = current;

        const addr = std.net.Address.initIp4(ip_parts, self.peer_port);
        const sock = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.STREAM, 0);
        errdefer std.posix.close(sock);

        try std.posix.connect(sock, &addr.any, addr.getOsSockLen());
        setTcpNodelay(sock);
        self.sock = sock;

        std.debug.print("\x1b[38;2;0;229;153m[Coordinator] Connected to worker\x1b[0m\n", .{});
    }

    fn disconnect(self: *PipelineCoordinator) void {
        if (self.sock) |s| {
            std.posix.close(s);
            self.sock = null;
        }
    }

    /// Send hidden state to worker, receive sampled token back (single-token, for decode)
    fn forwardRemote(self: *PipelineCoordinator, hidden: []const f32, pos: u32, temperature: f32) !u32 {
        try self.connect();
        const sock = self.sock orelse return error.NotConnected;

        // Serialize forward request
        const req = protocol.ForwardRequest{
            .sequence_id = 0,
            .token_pos = pos,
            .hidden_size = self.shard.hidden_size,
            .temperature = temperature,
            .hidden_state = hidden,
        };
        const payload = try req.serialize(self.allocator);
        defer self.allocator.free(payload);

        // Send header + payload (coalesced into single write)
        const header = protocol.MessageHeader{
            .msg_type = .forward_request,
            .length = @intCast(payload.len),
        };
        const hdr_bytes = header.serialize();
        const combined = try self.allocator.alloc(u8, protocol.MessageHeader.SIZE + payload.len);
        defer self.allocator.free(combined);
        @memcpy(combined[0..protocol.MessageHeader.SIZE], &hdr_bytes);
        @memcpy(combined[protocol.MessageHeader.SIZE..], payload);
        _ = try std.posix.write(sock, combined);

        // Read response (header + payload coalesced read)
        var resp_buf: [protocol.MessageHeader.SIZE + protocol.ForwardResponse.SIZE]u8 = undefined;
        _ = try readExact(sock, &resp_buf);
        const resp_hdr = try protocol.MessageHeader.deserialize(resp_buf[0..protocol.MessageHeader.SIZE]);
        if (resp_hdr.msg_type != .forward_response) return error.UnexpectedResponse;
        const resp = protocol.ForwardResponse.deserialize(resp_buf[protocol.MessageHeader.SIZE..][0..protocol.ForwardResponse.SIZE]);

        return resp.sampled_token;
    }

    /// Send all prefill hidden states in one batch, receive all tokens back
    fn batchForwardRemote(
        self: *PipelineCoordinator,
        hidden_states: []const f32,
        positions: []const u32,
        batch_size: u32,
        temperature: f32,
    ) ![]u32 {
        try self.connect();
        const sock = self.sock orelse return error.NotConnected;

        const req = protocol.BatchForwardRequest{
            .sequence_id = 0,
            .batch_size = batch_size,
            .hidden_size = self.shard.hidden_size,
            .temperature = temperature,
            .token_positions = positions,
            .hidden_states = hidden_states,
        };
        const payload = try req.serialize(self.allocator);
        defer self.allocator.free(payload);

        // Send header + payload
        const header = protocol.MessageHeader{
            .msg_type = .batch_forward_request,
            .length = @intCast(payload.len),
        };
        const hdr_bytes = header.serialize();
        _ = try std.posix.write(sock, &hdr_bytes);
        _ = try std.posix.write(sock, payload);

        // Read batch response header
        var resp_hdr_buf: [protocol.MessageHeader.SIZE]u8 = undefined;
        _ = try readExact(sock, &resp_hdr_buf);
        const resp_hdr = try protocol.MessageHeader.deserialize(&resp_hdr_buf);
        if (resp_hdr.msg_type != .batch_forward_response) return error.UnexpectedResponse;

        // Read batch response payload
        const resp_payload = try self.allocator.alloc(u8, resp_hdr.length);
        defer self.allocator.free(resp_payload);
        _ = try readExact(sock, resp_payload);

        const resp = try protocol.BatchForwardResponse.deserialize(resp_payload, self.allocator);
        return @constCast(resp.sampled_tokens);
    }

    /// Generate tokens for a prompt using distributed pipeline
    pub fn generate(
        self: *PipelineCoordinator,
        prompt_tokens: []const u32,
        max_new_tokens: u32,
        temperature: f32,
    ) ![]u32 {
        const hidden_size = self.shard.hidden_size;
        var output_tokens: std.ArrayList(u32) = .empty;
        errdefer output_tokens.deinit(self.allocator);

        // Allocate hidden state buffers
        const hidden = try self.allocator.alloc(f32, hidden_size);
        defer self.allocator.free(hidden);
        const shard_output = try self.allocator.alloc(f32, hidden_size);
        defer self.allocator.free(shard_output);

        const total_start = std.time.milliTimestamp();

        // Connect to worker
        try self.connect();

        // ─── Phase 1: Prefill (BATCHED — 1 TCP round-trip for all tokens) ───
        const prefill_start = std.time.milliTimestamp();
        std.debug.print("\x1b[38;2;0;255;255m[Coordinator] Prefill {d} tokens (batched): \x1b[0m", .{prompt_tokens.len});

        const batch_size: u32 = @intCast(prompt_tokens.len);
        const all_hidden = try self.allocator.alloc(f32, batch_size * hidden_size);
        defer self.allocator.free(all_hidden);
        const positions = try self.allocator.alloc(u32, batch_size);
        defer self.allocator.free(positions);

        // Local compute: embed + forwardShard for all prompt tokens
        const local_start = std.time.milliTimestamp();
        for (prompt_tokens, 0..) |token, i| {
            const emb_offset = @as(usize, token) * hidden_size;
            @memcpy(hidden, self.model.token_embedding[emb_offset..][0..hidden_size]);
            self.model.forwardShard(shard_output, hidden, i);

            // Store in batch buffer
            const dest_offset = i * hidden_size;
            @memcpy(all_hidden[dest_offset..][0..hidden_size], shard_output);
            positions[i] = @intCast(i);

            if (i % 5 == 0) std.debug.print(".", .{});
        }
        self.time_prefill_local_ms = std.time.milliTimestamp() - local_start;
        std.debug.print(" local done ({d}ms), ", .{self.time_prefill_local_ms});

        // Network: send entire batch at once
        const net_start = std.time.milliTimestamp();
        const batch_tokens = try self.batchForwardRemote(all_hidden, positions, batch_size, temperature);
        defer self.allocator.free(batch_tokens);
        self.time_prefill_net_ms = std.time.milliTimestamp() - net_start;

        const prefill_time = std.time.milliTimestamp() - prefill_start;
        std.debug.print("batch ok ({d}ms, net={d}ms)\n", .{ prefill_time, self.time_prefill_net_ms });

        // Use last sampled token as starting point for decode
        var last_token: u32 = batch_tokens[batch_tokens.len - 1];
        try output_tokens.append(self.allocator, last_token);

        // ─── Phase 2: Decode (single-token per round-trip, autoregressive) ───
        std.debug.print("\x1b[38;2;0;255;255m[Coordinator] Generating: \x1b[0m", .{});
        var gen_count: u32 = 0;
        while (gen_count < max_new_tokens) : (gen_count += 1) {
            const pos = prompt_tokens.len + gen_count;

            // Embed last token
            const emb_offset = @as(usize, last_token) * hidden_size;
            if (emb_offset + hidden_size > self.model.token_embedding.len) break;
            @memcpy(hidden, self.model.token_embedding[emb_offset..][0..hidden_size]);

            // Local compute
            const compute_start = std.time.milliTimestamp();
            self.model.forwardShard(shard_output, hidden, pos);
            self.time_decode_compute_ms += std.time.milliTimestamp() - compute_start;

            // Network
            const decode_net_start = std.time.milliTimestamp();
            last_token = self.forwardRemote(shard_output, @intCast(pos), temperature) catch break;
            const decode_net_time = std.time.milliTimestamp() - decode_net_start;
            self.time_decode_net_ms += decode_net_time;

            try output_tokens.append(self.allocator, last_token);
            std.debug.print("[{d}ms]", .{decode_net_time});

            // EOS check
            if (last_token == 2) break;
        }

        const total_time = std.time.milliTimestamp() - total_start;

        // ─── Performance Summary ───
        std.debug.print("\n", .{});
        std.debug.print("\x1b[38;2;255;215;0m╔══════════════════════════════════════════════════════════╗\x1b[0m\n", .{});
        std.debug.print("\x1b[38;2;255;215;0m║         DISTRIBUTED INFERENCE PROFILE                    ║\x1b[0m\n", .{});
        std.debug.print("\x1b[38;2;255;215;0m╠══════════════════════════════════════════════════════════╣\x1b[0m\n", .{});
        std.debug.print("║  Prefill: {d} tokens                                    \n", .{prompt_tokens.len});
        std.debug.print("║    Local compute:  {d:>8}ms                             \n", .{self.time_prefill_local_ms});
        std.debug.print("║    Network (batch):{d:>8}ms                             \n", .{self.time_prefill_net_ms});
        std.debug.print("║    Total prefill:  {d:>8}ms                             \n", .{prefill_time});
        std.debug.print("║  Decode: {d} tokens                                     \n", .{gen_count});
        std.debug.print("║    Total compute:  {d:>8}ms                             \n", .{self.time_decode_compute_ms});
        std.debug.print("║    Total network:  {d:>8}ms                             \n", .{self.time_decode_net_ms});
        const decode_total = self.time_decode_compute_ms + self.time_decode_net_ms;
        std.debug.print("║    Total decode:   {d:>8}ms                             \n", .{decode_total});
        const net_total = self.time_prefill_net_ms + self.time_decode_net_ms;
        const net_pct = if (total_time > 0)
            @as(f64, @floatFromInt(net_total)) / @as(f64, @floatFromInt(total_time)) * 100.0
        else
            0.0;
        std.debug.print("║  Network fraction: {d:.1}%                               \n", .{net_pct});
        std.debug.print("║  Total:            {d:>8}ms                             \n", .{total_time});
        std.debug.print("\x1b[38;2;255;215;0m╚══════════════════════════════════════════════════════════╝\x1b[0m\n", .{});

        return output_tokens.toOwnedSlice(self.allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Read exactly `buf.len` bytes from socket, blocking until complete
fn readExact(sock: std.posix.socket_t, buf: []u8) !usize {
    var total: usize = 0;
    while (total < buf.len) {
        const n = std.posix.read(sock, buf[total..]) catch |err| {
            if (total > 0) return total;
            return err;
        };
        if (n == 0) return total; // EOF
        total += n;
    }
    return total;
}

/// Set TCP_NODELAY to disable Nagle's algorithm (reduces latency for small writes)
fn setTcpNodelay(sock: std.posix.socket_t) void {
    const optval: u32 = 1;
    std.posix.setsockopt(sock, std.posix.IPPROTO.TCP, std.posix.TCP.NODELAY, std.mem.asBytes(&optval)) catch {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// STANDALONE ENTRY POINT (for direct execution)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runDistributed(allocator: std.mem.Allocator, args: []const []const u8) !void {
    // Parse arguments
    var role: []const u8 = "worker";
    var model_path: []const u8 = "models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf";
    var layers_start: u32 = 11;
    var layers_end: u32 = 22;
    var port: u16 = 9335;
    var peer_host: []const u8 = "127.0.0.1";
    var peer_port: u16 = 9335;
    var prompt: []const u8 = "Hello, how are you?";
    var max_tokens: u32 = 20;
    var temperature: f32 = 0.7;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--role") and i + 1 < args.len) {
            i += 1;
            role = args[i];
        } else if (std.mem.eql(u8, arg, "--model") and i + 1 < args.len) {
            i += 1;
            model_path = args[i];
        } else if (std.mem.eql(u8, arg, "--layers") and i + 1 < args.len) {
            i += 1;
            // Parse "start-end" format, e.g. "0-10" or "11-21"
            const layer_arg = args[i];
            var dash_pos: usize = 0;
            for (layer_arg, 0..) |c, j| {
                if (c == '-') {
                    dash_pos = j;
                    break;
                }
            }
            if (dash_pos > 0) {
                layers_start = std.fmt.parseInt(u32, layer_arg[0..dash_pos], 10) catch 0;
                layers_end = (std.fmt.parseInt(u32, layer_arg[dash_pos + 1 ..], 10) catch 22) + 1; // exclusive
            }
        } else if (std.mem.eql(u8, arg, "--port") and i + 1 < args.len) {
            i += 1;
            port = std.fmt.parseInt(u16, args[i], 10) catch 9335;
        } else if (std.mem.eql(u8, arg, "--peer") and i + 1 < args.len) {
            i += 1;
            // Parse "host:port"
            const peer_arg = args[i];
            var colon_pos: usize = peer_arg.len;
            for (peer_arg, 0..) |c, j| {
                if (c == ':') {
                    colon_pos = j;
                    break;
                }
            }
            peer_host = peer_arg[0..colon_pos];
            if (colon_pos < peer_arg.len) {
                peer_port = std.fmt.parseInt(u16, peer_arg[colon_pos + 1 ..], 10) catch 9335;
            }
        } else if (std.mem.eql(u8, arg, "--prompt") and i + 1 < args.len) {
            i += 1;
            prompt = args[i];
        } else if (std.mem.eql(u8, arg, "--max-tokens") and i + 1 < args.len) {
            i += 1;
            max_tokens = std.fmt.parseInt(u32, args[i], 10) catch 20;
        } else if (std.mem.eql(u8, arg, "--temperature") and i + 1 < args.len) {
            i += 1;
            temperature = std.fmt.parseFloat(f32, args[i]) catch 0.7;
        }
    }

    std.debug.print("\n\x1b[38;2;255;215;0m═══ TRINITY DISTRIBUTED INFERENCE v2 (Batched) ═══\x1b[0m\n", .{});
    std.debug.print("Role: {s} | Layers: {d}..{d} | Model: {s}\n", .{ role, layers_start, layers_end, model_path });

    if (std.mem.eql(u8, role, "worker")) {
        const shard = ShardConfig{
            .total_layers = 22,
            .start_layer = layers_start,
            .end_layer = layers_end,
            .is_first = layers_start == 0,
            .is_last = true,
            .hidden_size = 2048,
            .model_path = model_path,
        };

        var worker = try PipelineWorker.init(allocator, shard, port);
        defer worker.deinit();

        // Run in foreground (blocking)
        worker.serverLoop();
    } else {
        const shard = ShardConfig{
            .total_layers = 22,
            .start_layer = layers_start,
            .end_layer = layers_end,
            .is_first = true,
            .is_last = false,
            .hidden_size = 2048,
            .model_path = model_path,
        };

        var coordinator = try PipelineCoordinator.init(allocator, shard, peer_host, peer_port);
        defer coordinator.deinit();

        std.debug.print("\x1b[38;2;0;255;255m[Coordinator] Prompt: \"{s}\"\x1b[0m\n", .{prompt});

        // Use BOS token (1) + simple byte tokenization
        var prompt_tokens: std.ArrayList(u32) = .empty;
        defer prompt_tokens.deinit(allocator);
        try prompt_tokens.append(allocator, 1); // BOS
        for (prompt) |byte| {
            try prompt_tokens.append(allocator, @as(u32, byte) + 100);
        }

        const tokens = try coordinator.generate(prompt_tokens.items, max_tokens, temperature);
        defer allocator.free(tokens);

        std.debug.print("\x1b[38;2;255;255;255m[Coordinator] Generated tokens: ", .{});
        for (tokens) |t| {
            std.debug.print("{d} ", .{t});
        }
        std.debug.print("\x1b[0m\n", .{});
    }
}
