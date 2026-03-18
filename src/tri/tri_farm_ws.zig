// @origin(spec:tri_farm_ws.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// TRI FARM WS — WebSocket Layer for Training Farm Evolution Server
// ═══════════════════════════════════════════════════════════════════════════════
//
// Phase 1: Outbound stream — snapshot on connect, broadcast events to all clients.
// Plugs into tri_farm_evolve.zig serve endpoint at /ws.
//
// RFC 6455 compliant: SHA-1 handshake, proper framing (no mask on server→client).
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// Types
// ═══════════════════════════════════════════════════════════════════════════════

pub const WsEventKind = enum(u8) {
    leader_update,
    inject,
    tune,
    health,
    kill,
    spawn,
    rung,
    snapshot,

    pub fn label(self: WsEventKind) []const u8 {
        return switch (self) {
            .leader_update => "leader_update",
            .inject => "inject",
            .tune => "tune",
            .health => "health",
            .kill => "kill",
            .spawn => "spawn",
            .rung => "rung",
            .snapshot => "snapshot",
        };
    }
};

pub const WsEvent = struct {
    kind: WsEventKind,
    timestamp: i64,
    payload: [512]u8 = undefined,
    payload_len: u16 = 0,

    pub fn payloadStr(self: *const WsEvent) []const u8 {
        return self.payload[0..self.payload_len];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// EventBus — lock-free-ish ring buffer (mutex for safety, minimal contention)
// ═══════════════════════════════════════════════════════════════════════════════

pub const RING_SIZE = 64;

pub const EventBus = struct {
    ring: [RING_SIZE]WsEvent = undefined,
    write_pos: usize = 0,
    read_pos: usize = 0,
    mutex: std.Thread.Mutex = .{},

    pub fn push(self: *EventBus, event: WsEvent) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.ring[self.write_pos % RING_SIZE] = event;
        self.write_pos +%= 1;
        // If writer laps reader, advance reader (drop oldest)
        if (self.write_pos -% self.read_pos > RING_SIZE) {
            self.read_pos = self.write_pos -% RING_SIZE;
        }
    }

    pub fn drain(self: *EventBus, out: []WsEvent) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        var count: usize = 0;
        while (self.read_pos != self.write_pos and count < out.len) {
            out[count] = self.ring[self.read_pos % RING_SIZE];
            self.read_pos +%= 1;
            count += 1;
        }
        return count;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// WsClient — one connected WebSocket peer
// ═══════════════════════════════════════════════════════════════════════════════

pub const WsClient = struct {
    stream: std.net.Stream,
    alive: std.atomic.Value(bool),
    write_mutex: std.Thread.Mutex = .{},

    pub fn init(stream: std.net.Stream) WsClient {
        return .{
            .stream = stream,
            .alive = std.atomic.Value(bool).init(true),
            .write_mutex = .{},
        };
    }

    pub fn sendText(self: *WsClient, payload: []const u8) void {
        if (!self.alive.load(.acquire)) return;
        self.write_mutex.lock();
        defer self.write_mutex.unlock();

        // Build WS frame: FIN + text opcode, no mask (server→client per RFC 6455)
        var header: [10]u8 = undefined;
        var hlen: usize = 0;
        header[0] = 0x81; // FIN + text
        hlen = 1;

        if (payload.len < 126) {
            header[1] = @intCast(payload.len);
            hlen = 2;
        } else if (payload.len < 65536) {
            header[1] = 126;
            header[2] = @intCast((payload.len >> 8) & 0xFF);
            header[3] = @intCast(payload.len & 0xFF);
            hlen = 4;
        } else {
            header[1] = 127;
            inline for (0..8) |i| {
                header[2 + i] = @intCast((payload.len >> @intCast(8 * (7 - i))) & 0xFF);
            }
            hlen = 10;
        }

        self.stream.writeAll(header[0..hlen]) catch {
            self.alive.store(false, .release);
            return;
        };
        self.stream.writeAll(payload) catch {
            self.alive.store(false, .release);
        };
    }

    pub fn sendClose(self: *WsClient) void {
        if (!self.alive.load(.acquire)) return;
        self.write_mutex.lock();
        defer self.write_mutex.unlock();
        const close_frame = [_]u8{ 0x88, 0x00 };
        self.stream.writeAll(&close_frame) catch {};
        self.alive.store(false, .release);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Broadcaster — manages client list + drain/broadcast loop
// ═══════════════════════════════════════════════════════════════════════════════

pub const MAX_CLIENTS = 16;

pub const Broadcaster = struct {
    clients: [MAX_CLIENTS]*WsClient = undefined,
    count: usize = 0,
    bus: *EventBus,
    mutex: std.Thread.Mutex = .{},
    running: std.atomic.Value(bool),

    pub fn init(bus: *EventBus) Broadcaster {
        return .{
            .bus = bus,
            .running = std.atomic.Value(bool).init(true),
        };
    }

    pub fn addClient(self: *Broadcaster, client: *WsClient) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.count >= MAX_CLIENTS) return false;
        self.clients[self.count] = client;
        self.count += 1;
        return true;
    }

    pub fn removeClient(self: *Broadcaster, client: *WsClient) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        var i: usize = 0;
        while (i < self.count) {
            if (self.clients[i] == client) {
                // Shift remaining
                var j: usize = i;
                while (j + 1 < self.count) : (j += 1) {
                    self.clients[j] = self.clients[j + 1];
                }
                self.count -= 1;
                return;
            }
            i += 1;
        }
    }

    /// Broadcast thread entry: drain bus every 100ms, batch events every 500ms,
    /// PING clients every 30s, clean dead connections unconditionally.
    pub fn broadcastLoop(self: *Broadcaster) void {
        var drain_buf: [RING_SIZE]WsEvent = undefined;
        var tick: u32 = 0;

        // Batch accumulator: collect events over 500ms window (5 ticks)
        var batch_buf: [8192]u8 = undefined;
        var batch_pos: usize = 0;
        var batch_count: usize = 0;

        while (self.running.load(.acquire)) {
            const drained = self.bus.drain(&drain_buf);

            // Accumulate events into batch buffer
            for (drain_buf[0..drained]) |*ev| {
                var json_buf: [1024]u8 = undefined;
                const json = formatEventJson(ev, &json_buf);
                // Comma separator between events
                if (batch_count > 0 and batch_pos + 1 < batch_buf.len) {
                    batch_buf[batch_pos] = ',';
                    batch_pos += 1;
                }
                if (batch_pos + json.len <= batch_buf.len) {
                    @memcpy(batch_buf[batch_pos..][0..json.len], json);
                    batch_pos += json.len;
                    batch_count += 1;
                }
            }

            tick += 1;

            // Flush batch every 500ms (5 × 100ms) or when buffer is >75% full
            if ((tick % 5 == 0 or batch_pos > 6000) and batch_count > 0) {
                var frame_buf: [8400]u8 = undefined;
                const frame = std.fmt.bufPrint(
                    &frame_buf,
                    "{{\"type\":\"batch\",\"count\":{d},\"events\":[{s}]}}",
                    .{ batch_count, batch_buf[0..batch_pos] },
                ) catch "";

                if (frame.len > 0) {
                    self.mutex.lock();
                    const client_count = self.count;
                    var snapshot: [MAX_CLIENTS]*WsClient = undefined;
                    for (0..client_count) |ci| {
                        snapshot[ci] = self.clients[ci];
                    }
                    self.mutex.unlock();

                    for (snapshot[0..client_count]) |c| {
                        c.sendText(frame);
                    }
                }

                batch_pos = 0;
                batch_count = 0;
            }

            // Every 30s (300 × 100ms): PING all clients + unconditional dead cleanup
            if (tick % 300 == 0) {
                self.mutex.lock();
                const cc = self.count;
                var snap: [MAX_CLIENTS]*WsClient = undefined;
                for (0..cc) |ci| {
                    snap[ci] = self.clients[ci];
                }
                self.mutex.unlock();

                const ping_frame = [_]u8{ 0x89, 0x00 }; // FIN + PING, 0 payload
                for (snap[0..cc]) |c| {
                    if (c.alive.load(.acquire)) {
                        c.write_mutex.lock();
                        c.stream.writeAll(&ping_frame) catch {
                            c.alive.store(false, .release);
                        };
                        c.write_mutex.unlock();
                    }
                }

                self.cleanDead();
            }

            std.Thread.sleep(100 * std.time.ns_per_ms);
        }
    }

    fn cleanDead(self: *Broadcaster) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        var i: usize = 0;
        while (i < self.count) {
            if (!self.clients[i].alive.load(.acquire)) {
                self.clients[i].stream.close();
                // Shift
                var j: usize = i;
                while (j + 1 < self.count) : (j += 1) {
                    self.clients[j] = self.clients[j + 1];
                }
                self.count -= 1;
            } else {
                i += 1;
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// WS Handshake + Client handling
// ═══════════════════════════════════════════════════════════════════════════════

/// Handle WS upgrade: do SHA-1 handshake, send snapshot, register in broadcaster, start reader.
/// Returns true if upgrade succeeded (stream is now owned by WS), false if not a WS request.
pub fn handleUpgrade(
    stream: std.net.Stream,
    request: []const u8,
    broadcaster: *Broadcaster,
    state_json: []const u8,
) bool {
    // Verify Upgrade header (case-insensitive check for "websocket")
    const has_upgrade = headerContains(request, "Upgrade:", "websocket");
    if (!has_upgrade) return false;

    // Extract Sec-WebSocket-Key
    const key = extractHeader(request, "Sec-WebSocket-Key:") orelse return false;

    // Compute accept key: SHA1(key + magic), base64
    const magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
    var concat_buf: [256]u8 = undefined;
    if (key.len + magic.len > concat_buf.len) return false;
    @memcpy(concat_buf[0..key.len], key);
    @memcpy(concat_buf[key.len..][0..magic.len], magic);
    const concat = concat_buf[0 .. key.len + magic.len];

    var hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(concat, &hash, .{});

    var accept_b64: [28]u8 = undefined;
    const accept_key = std.base64.standard.Encoder.encode(&accept_b64, &hash);

    // Send 101 response
    var resp_buf: [256]u8 = undefined;
    const response = std.fmt.bufPrint(
        &resp_buf,
        "HTTP/1.1 101 Switching Protocols\r\n" ++
            "Upgrade: websocket\r\n" ++
            "Connection: Upgrade\r\n" ++
            "Sec-WebSocket-Accept: {s}\r\n" ++
            "\r\n",
        .{accept_key},
    ) catch return false;

    stream.writeAll(response) catch return false;

    // Backpressure: 3s write timeout — slow clients get disconnected, not stall broadcaster
    const snd_timeout = std.posix.timeval{ .sec = 3, .usec = 0 };
    std.posix.setsockopt(stream.handle, std.posix.SOL.SOCKET, std.posix.SO.SNDTIMEO, std.mem.asBytes(&snd_timeout)) catch {};

    // Create client (static — lives on the reader thread stack via the broadcaster)
    var client = WsClient.init(stream);

    if (!broadcaster.addClient(&client)) {
        // Too many clients
        client.sendClose();
        return true; // we consumed the stream
    }

    // Send snapshot as first message
    var snap_buf: [2048]u8 = undefined;
    const snap_json = std.fmt.bufPrint(
        &snap_buf,
        "{{\"type\":\"snapshot\",\"data\":{s}}}",
        .{state_json},
    ) catch state_json;
    client.sendText(snap_json);

    // Reader loop (blocking — runs on accept thread, that's fine for Phase 1)
    clientReadLoop(&client, broadcaster);

    return true;
}

/// Per-client reader: handle ping/pong/close only (Phase 1 — no inbound commands)
fn clientReadLoop(client: *WsClient, broadcaster: *Broadcaster) void {
    var buf: [256]u8 = undefined;

    while (client.alive.load(.acquire)) {
        const n = client.stream.read(&buf) catch break;
        if (n == 0) break;

        // Parse minimal WS frame
        if (n >= 2) {
            const opcode = buf[0] & 0x0F;
            switch (opcode) {
                0x8 => break, // Close
                0x9 => { // Ping → Pong
                    const pong = [_]u8{ 0x8A, 0x00 };
                    client.stream.writeAll(&pong) catch break;
                },
                else => {}, // Ignore text/binary in Phase 1
            }
        }
    }

    client.alive.store(false, .release);
    broadcaster.removeClient(client);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Event construction + JSON formatting
// ═══════════════════════════════════════════════════════════════════════════════

pub fn makeEvent(kind: WsEventKind, name: []const u8, detail: []const u8) WsEvent {
    var ev = WsEvent{
        .kind = kind,
        .timestamp = std.time.milliTimestamp(),
    };
    // Build payload as JSON fragment: {"target":"name","detail":"detail"}
    const json = std.fmt.bufPrint(
        &ev.payload,
        "{{\"target\":\"{s}\",\"detail\":\"{s}\"}}",
        .{ name, detail },
    ) catch "";
    ev.payload_len = @intCast(json.len);
    return ev;
}

fn formatEventJson(ev: *const WsEvent, buf: []u8) []const u8 {
    const json = std.fmt.bufPrint(
        buf,
        "{{\"type\":\"{s}\",\"ts\":{d},{s}}}",
        .{
            ev.kind.label(),
            ev.timestamp,
            // Strip outer braces from payload and inline
            if (ev.payload_len > 2)
                ev.payload[1 .. ev.payload_len - 1]
            else
                "\"target\":\"\",\"detail\":\"\"",
        },
    ) catch return "{}";
    return json;
}

/// Format snapshot JSON from status endpoint data (reuses whatever serveStatus builds)
pub fn formatStatusSnapshot(
    best_ppl: f32,
    best_name: []const u8,
    alive: u32,
    dead: u32,
    total: u32,
    health_score: f32,
    leader_step: u32,
    buf: []u8,
) []const u8 {
    return std.fmt.bufPrint(
        buf,
        "{{\"best_ppl\":{d:.2},\"best\":\"{s}\",\"alive\":{d},\"dead\":{d},\"total\":{d},\"health_score\":{d:.0},\"leader_step\":{d}}}",
        .{ best_ppl, best_name, alive, dead, total, health_score, leader_step },
    ) catch "{}";
}

// ═══════════════════════════════════════════════════════════════════════════════
// HTTP header helpers
// ═══════════════════════════════════════════════════════════════════════════════

fn headerContains(request: []const u8, header_name: []const u8, value: []const u8) bool {
    var pos: usize = 0;
    while (pos < request.len) {
        // Find header name (case-insensitive for the value part)
        if (asciiStartsWithIgnoreCase(request[pos..], header_name)) {
            const after = pos + header_name.len;
            const line_end = std.mem.indexOfScalar(u8, request[after..], '\r') orelse (request.len - after);
            const hval = std.mem.trim(u8, request[after..][0..line_end], &[_]u8{' '});
            return asciiContainsIgnoreCase(hval, value);
        }
        // Advance to next line
        if (std.mem.indexOfScalar(u8, request[pos..], '\n')) |nl| {
            pos += nl + 1;
        } else break;
    }
    return false;
}

fn extractHeader(request: []const u8, header_name: []const u8) ?[]const u8 {
    var pos: usize = 0;
    while (pos < request.len) {
        if (asciiStartsWithIgnoreCase(request[pos..], header_name)) {
            const after = pos + header_name.len;
            const line_end = std.mem.indexOfScalar(u8, request[after..], '\r') orelse (request.len - after);
            return std.mem.trim(u8, request[after..][0..line_end], &[_]u8{' '});
        }
        if (std.mem.indexOfScalar(u8, request[pos..], '\n')) |nl| {
            pos += nl + 1;
        } else break;
    }
    return null;
}

fn asciiStartsWithIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (haystack.len < needle.len) return false;
    for (haystack[0..needle.len], needle) |h, n| {
        if (toLower(h) != toLower(n)) return false;
    }
    return true;
}

fn asciiContainsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (haystack.len < needle.len) return false;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (asciiStartsWithIgnoreCase(haystack[i..], needle)) return true;
    }
    return false;
}

fn toLower(c: u8) u8 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "EventBus push and drain" {
    var bus = EventBus{};
    const ev1 = makeEvent(.kill, "hslm-w7-12", "rung_1 fail");
    const ev2 = makeEvent(.spawn, "hslm-w7-60", "parent=w7-35");
    bus.push(ev1);
    bus.push(ev2);

    var out: [8]WsEvent = undefined;
    const n = bus.drain(&out);
    try std.testing.expectEqual(@as(usize, 2), n);
    try std.testing.expectEqual(WsEventKind.kill, out[0].kind);
    try std.testing.expectEqual(WsEventKind.spawn, out[1].kind);

    // Drain again — should be empty
    const n2 = bus.drain(&out);
    try std.testing.expectEqual(@as(usize, 0), n2);
}

test "EventBus ring wrap" {
    var bus = EventBus{};
    // Push more than RING_SIZE
    for (0..RING_SIZE + 10) |i| {
        var detail_buf: [32]u8 = undefined;
        const detail = std.fmt.bufPrint(&detail_buf, "event-{d}", .{i}) catch "x";
        bus.push(makeEvent(.spawn, "svc", detail));
    }
    // Should only get RING_SIZE events (oldest dropped)
    var out: [RING_SIZE]WsEvent = undefined;
    const n = bus.drain(&out);
    try std.testing.expectEqual(RING_SIZE, n);
}

test "makeEvent payload" {
    const ev = makeEvent(.kill, "w7-12", "ppl=42.5");
    const payload = ev.payloadStr();
    try std.testing.expect(std.mem.indexOf(u8, payload, "w7-12") != null);
    try std.testing.expect(std.mem.indexOf(u8, payload, "ppl=42.5") != null);
}

test "formatEventJson" {
    const ev = makeEvent(.tune, "w7-22", "lr 1e-3");
    var buf: [1024]u8 = undefined;
    const json = formatEventJson(&ev, &buf);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"type\":\"tune\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "w7-22") != null);
}

test "header helpers" {
    const req = "GET /ws HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n";
    try std.testing.expect(headerContains(req, "Upgrade:", "websocket"));
    try std.testing.expect(!headerContains(req, "Upgrade:", "http2"));
    const key = extractHeader(req, "Sec-WebSocket-Key:");
    try std.testing.expect(key != null);
    try std.testing.expectEqualStrings("dGhlIHNhbXBsZSBub25jZQ==", key.?);
}

test "formatStatusSnapshot" {
    var buf: [512]u8 = undefined;
    const json = formatStatusSnapshot(4.06, "hslm-w7-35", 26, 47, 73, &buf);
    try std.testing.expect(std.mem.indexOf(u8, json, "4.06") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "hslm-w7-35") != null);
}
