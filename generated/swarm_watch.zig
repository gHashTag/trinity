// Trinity Swarm Watch: Real-time DHT & TRI Economy Monitor
// DEV-003: SWARM-WATCH — Live CLI dashboard for DHT health, rewards, sync events
// Generated from: specs/tri/swarm_watch.vibee
//
// Polls KgTripleDHT stats and KgRewardCalculator metrics, renders ANSI dashboard,
// exports Prometheus-format metrics. Ring buffer for recent sync events.

const std = @import("std");

// =============================================================================
// CONSTANTS
// =============================================================================

/// Golden ratio
const PHI: f64 = 1.6180339887;

/// Trinity identity: phi^2 + 1/phi^2 = 3
const TRINITY: f64 = 3.0;

/// TRI per triple (display units)
const REWARD_PER_TRIPLE_TRI: f64 = 0.0002;

/// Wei divisor (10^18)
const WEI_DIVISOR: f64 = 1_000_000_000_000_000_000.0;

/// Max sync events in ring buffer
const MAX_SYNC_EVENTS: usize = 64;

/// Max label length for string fields
const MAX_LABEL_LEN: usize = 32;

// ANSI color codes (Trinity palette)
const ANSI_RESET = "\x1b[0m";
const ANSI_BOLD = "\x1b[1m";
const ANSI_DIM = "\x1b[2m";
const ANSI_GOLD = "\x1b[33m"; // RAZUM
const ANSI_CYAN = "\x1b[36m"; // MATERIYA
const ANSI_PURPLE = "\x1b[35m"; // DUKH
const ANSI_GREEN = "\x1b[32m";
const ANSI_RED = "\x1b[31m";
const ANSI_WHITE = "\x1b[37m";

// =============================================================================
// TYPES
// =============================================================================

/// DHT health status classification
pub const HealthStatus = enum {
    idle,
    healthy,
    degraded,
    offline,

    pub fn label(self: HealthStatus) []const u8 {
        return switch (self) {
            .idle => "IDLE",
            .healthy => "HEALTHY",
            .degraded => "DEGRADED",
            .offline => "OFFLINE",
        };
    }

    pub fn color(self: HealthStatus) []const u8 {
        return switch (self) {
            .idle => ANSI_DIM,
            .healthy => ANSI_GREEN,
            .degraded => ANSI_GOLD,
            .offline => ANSI_RED,
        };
    }
};

/// DHT health snapshot
pub const DHTHealth = struct {
    acceptance_rate: f64 = 0.0,
    peer_count: u32 = 0,
    triples_stored: u64 = 0,
    sync_rounds: u64 = 0,
    status: HealthStatus = .idle,
};

/// TRI reward summary for display
pub const RewardSummary = struct {
    total_paid_tri: f64 = 0.0,
    pending_tri: f64 = 0.0,
    triples_rewarded: u64 = 0,
    per_triple_rate: f64 = REWARD_PER_TRIPLE_TRI,
};

/// Sync event type
pub const EventType = enum {
    store,
    retrieve,
    sync_inbound,
    sync_outbound,

    pub fn label(self: EventType) []const u8 {
        return switch (self) {
            .store => "STORE",
            .retrieve => "RETRIEVE",
            .sync_inbound => "SYNC_IN",
            .sync_outbound => "SYNC_OUT",
        };
    }
};

/// Sync result classification
pub const SyncResultType = enum {
    accepted,
    duplicate,
    rejected,

    pub fn label(self: SyncResultType) []const u8 {
        return switch (self) {
            .accepted => "OK",
            .duplicate => "DUP",
            .rejected => "REJ",
        };
    }

    pub fn color(self: SyncResultType) []const u8 {
        return switch (self) {
            .accepted => ANSI_GREEN,
            .duplicate => ANSI_DIM,
            .rejected => ANSI_RED,
        };
    }
};

/// A single sync event record
pub const SyncEvent = struct {
    event_type: EventType = .store,
    subject: [MAX_LABEL_LEN]u8 = [_]u8{0} ** MAX_LABEL_LEN,
    predicate: [MAX_LABEL_LEN]u8 = [_]u8{0} ** MAX_LABEL_LEN,
    object: [MAX_LABEL_LEN]u8 = [_]u8{0} ** MAX_LABEL_LEN,
    timestamp: i64 = 0,
    result: SyncResultType = .accepted,
};

/// Complete swarm snapshot for dashboard rendering
pub const SwarmSnapshot = struct {
    dht_health: DHTHealth = .{},
    rewards: RewardSummary = .{},
    recent_events: [MAX_SYNC_EVENTS]SyncEvent = [_]SyncEvent{.{}} ** MAX_SYNC_EVENTS,
    event_head: usize = 0,
    event_count: usize = 0,
    pipeline_extracted: u64 = 0,
    pipeline_stored: u64 = 0,
    pipeline_skipped: u64 = 0,
};

// =============================================================================
// INPUT TYPES (for polling external data)
// =============================================================================

/// Input from KgTripleDHT stats
pub const DhtStatsInput = struct {
    triples_stored: u64 = 0,
    triples_distributed: u64 = 0,
    triples_received: u64 = 0,
    triples_rejected: u64 = 0,
    triples_duplicate: u64 = 0,
    sync_rounds: u64 = 0,
    peer_count: u32 = 0,
};

/// Input from KgRewardCalculator
pub const RewardStatsInput = struct {
    total_paid_wei: u128 = 0,
    pending_wei: u128 = 0,
    triples_rewarded: u64 = 0,
};

// =============================================================================
// SWARM WATCH
// =============================================================================

pub const SwarmWatch = struct {
    snapshot: SwarmSnapshot = .{},

    const Self = @This();

    pub fn init() Self {
        return .{};
    }

    /// Poll DHT stats and update health snapshot
    pub fn pollDhtStats(self: *Self, input: DhtStatsInput) void {
        const total_ops = input.triples_distributed + input.triples_received;
        const acceptance_rate: f64 = if (total_ops > 0)
            @as(f64, @floatFromInt(total_ops - input.triples_rejected)) / @as(f64, @floatFromInt(total_ops))
        else
            0.0;

        self.snapshot.dht_health = .{
            .acceptance_rate = acceptance_rate,
            .peer_count = input.peer_count,
            .triples_stored = input.triples_stored,
            .sync_rounds = input.sync_rounds,
            .status = classifyHealth(acceptance_rate, input.peer_count, input.sync_rounds),
        };
    }

    /// Poll reward stats and update summary
    pub fn pollRewardStats(self: *Self, input: RewardStatsInput) void {
        self.snapshot.rewards = .{
            .total_paid_tri = @as(f64, @floatFromInt(input.total_paid_wei)) / WEI_DIVISOR,
            .pending_tri = @as(f64, @floatFromInt(input.pending_wei)) / WEI_DIVISOR,
            .triples_rewarded = input.triples_rewarded,
            .per_triple_rate = REWARD_PER_TRIPLE_TRI,
        };
    }

    /// Record a sync event into the ring buffer
    pub fn recordSyncEvent(
        self: *Self,
        event_type: EventType,
        subject: []const u8,
        predicate: []const u8,
        object: []const u8,
        result: SyncResultType,
    ) void {
        const idx = self.snapshot.event_head;
        self.snapshot.recent_events[idx] = .{
            .event_type = event_type,
            .subject = copyTruncate(subject),
            .predicate = copyTruncate(predicate),
            .object = copyTruncate(object),
            .timestamp = std.time.timestamp(),
            .result = result,
        };
        self.snapshot.event_head = (self.snapshot.event_head + 1) % MAX_SYNC_EVENTS;
        if (self.snapshot.event_count < MAX_SYNC_EVENTS) self.snapshot.event_count += 1;

        // Update pipeline counters
        self.snapshot.pipeline_extracted += 1;
        switch (result) {
            .accepted => self.snapshot.pipeline_stored += 1,
            .duplicate, .rejected => self.snapshot.pipeline_skipped += 1,
        }
    }

    /// Render ANSI dashboard to writer
    pub fn renderDashboard(self: *const Self, writer: anytype) !void {
        const snap = &self.snapshot;
        const h = &snap.dht_health;
        const r = &snap.rewards;

        // Header
        try writer.print("{s}{s}SWARM-WATCH{s} DEV-003 | Trinity DHT & Economy Monitor\n", .{ ANSI_BOLD, ANSI_CYAN, ANSI_RESET });
        try writer.writeAll(ANSI_DIM ++ ("=" ** 60) ++ ANSI_RESET ++ "\n");

        // DHT Health (MATERIYA column)
        try writer.print("\n{s}{s}DHT HEALTH{s}", .{ ANSI_BOLD, ANSI_CYAN, ANSI_RESET });
        try writer.print("  [{s}{s}{s}]\n", .{ h.status.color(), h.status.label(), ANSI_RESET });
        try writer.print("  Peers:       {s}{d}{s}\n", .{ ANSI_CYAN, h.peer_count, ANSI_RESET });
        try writer.print("  Triples:     {s}{d}{s}\n", .{ ANSI_CYAN, h.triples_stored, ANSI_RESET });
        try writer.print("  Sync Rounds: {d}\n", .{h.sync_rounds});
        try writer.print("  Accept Rate: {d:.1}%\n", .{h.acceptance_rate * 100.0});

        // Rewards (DUKH column)
        try writer.print("\n{s}{s}$TRI REWARDS{s}\n", .{ ANSI_BOLD, ANSI_PURPLE, ANSI_RESET });
        try writer.print("  Earned:   {s}{d:.6} TRI{s}\n", .{ ANSI_GOLD, r.total_paid_tri, ANSI_RESET });
        try writer.print("  Pending:  {s}{d:.6} TRI{s}\n", .{ ANSI_GOLD, r.pending_tri, ANSI_RESET });
        try writer.print("  Rewarded: {d} triples\n", .{r.triples_rewarded});
        try writer.print("  Rate:     {d:.4} TRI/triple\n", .{r.per_triple_rate});

        // Pipeline (RAZUM column)
        try writer.print("\n{s}{s}PIPELINE{s}\n", .{ ANSI_BOLD, ANSI_GOLD, ANSI_RESET });
        try writer.print("  Extracted: {d}  Stored: {d}  Skipped: {d}\n", .{
            snap.pipeline_extracted,
            snap.pipeline_stored,
            snap.pipeline_skipped,
        });

        // Recent events
        try writer.print("\n{s}{s}RECENT SYNC EVENTS{s} ({d}/{d})\n", .{
            ANSI_BOLD, ANSI_WHITE, ANSI_RESET, snap.event_count, MAX_SYNC_EVENTS,
        });

        const display_count = @min(snap.event_count, 8);
        if (display_count > 0) {
            var i: usize = 0;
            while (i < display_count) : (i += 1) {
                const raw_idx = if (snap.event_head >= i + 1)
                    snap.event_head - i - 1
                else
                    MAX_SYNC_EVENTS - (i + 1 - snap.event_head);
                const ev = &snap.recent_events[raw_idx];
                try writer.print("  {s}", .{ANSI_DIM});
                try writer.writeAll(ev.event_type.label());
                try writer.print("{s} {s}", .{ ANSI_RESET, ev.result.color() });
                try writer.writeAll(ev.result.label());
                try writer.print("{s} ", .{ANSI_RESET});
                try writer.writeAll(trimNull(&ev.subject));
                try writer.writeAll("\n");
            }
        } else {
            try writer.print("  {s}(no events){s}\n", .{ ANSI_DIM, ANSI_RESET });
        }
    }

    /// Export metrics in Prometheus text format
    pub fn exportMetrics(self: *const Self, writer: anytype) !void {
        const snap = &self.snapshot;
        const h = &snap.dht_health;
        const r = &snap.rewards;

        try writer.print("# HELP trinity_dht_peers Number of DHT peers\n", .{});
        try writer.print("# TYPE trinity_dht_peers gauge\n", .{});
        try writer.print("trinity_dht_peers {d}\n", .{h.peer_count});

        try writer.print("# HELP trinity_dht_triples_stored Number of triples in DHT\n", .{});
        try writer.print("# TYPE trinity_dht_triples_stored gauge\n", .{});
        try writer.print("trinity_dht_triples_stored {d}\n", .{h.triples_stored});

        try writer.print("# HELP trinity_dht_sync_rounds Total sync rounds completed\n", .{});
        try writer.print("# TYPE trinity_dht_sync_rounds counter\n", .{});
        try writer.print("trinity_dht_sync_rounds {d}\n", .{h.sync_rounds});

        try writer.print("# HELP trinity_dht_acceptance_rate DHT acceptance rate\n", .{});
        try writer.print("# TYPE trinity_dht_acceptance_rate gauge\n", .{});
        try writer.print("trinity_dht_acceptance_rate {d:.4}\n", .{h.acceptance_rate});

        try writer.print("# HELP trinity_tri_earned_total Total TRI earned\n", .{});
        try writer.print("# TYPE trinity_tri_earned_total counter\n", .{});
        try writer.print("trinity_tri_earned_total {d:.6}\n", .{r.total_paid_tri});

        try writer.print("# HELP trinity_tri_pending Pending TRI rewards\n", .{});
        try writer.print("# TYPE trinity_tri_pending gauge\n", .{});
        try writer.print("trinity_tri_pending {d:.6}\n", .{r.pending_tri});

        try writer.print("# HELP trinity_triples_rewarded Total triples rewarded\n", .{});
        try writer.print("# TYPE trinity_triples_rewarded counter\n", .{});
        try writer.print("trinity_triples_rewarded {d}\n", .{r.triples_rewarded});

        try writer.print("# HELP trinity_pipeline_extracted Total triples extracted\n", .{});
        try writer.print("# TYPE trinity_pipeline_extracted counter\n", .{});
        try writer.print("trinity_pipeline_extracted {d}\n", .{snap.pipeline_extracted});

        try writer.print("# HELP trinity_pipeline_stored Total triples stored\n", .{});
        try writer.print("# TYPE trinity_pipeline_stored counter\n", .{});
        try writer.print("trinity_pipeline_stored {d}\n", .{snap.pipeline_stored});

        try writer.print("# HELP trinity_pipeline_skipped Total triples skipped\n", .{});
        try writer.print("# TYPE trinity_pipeline_skipped counter\n", .{});
        try writer.print("trinity_pipeline_skipped {d}\n", .{snap.pipeline_skipped});
    }
};

// =============================================================================
// HELPERS
// =============================================================================

/// Classify DHT health from metrics
pub fn classifyHealth(acceptance_rate: f64, peer_count: u32, sync_rounds: u64) HealthStatus {
    if (sync_rounds == 0) return .idle;
    if (peer_count == 0) return .offline;
    if (acceptance_rate < 0.5) return .degraded;
    return .healthy;
}

/// Trim trailing null bytes from a fixed-size buffer, return slice
pub fn trimNull(buf: []const u8) []const u8 {
    var end: usize = buf.len;
    while (end > 0 and buf[end - 1] == 0) {
        end -= 1;
    }
    return buf[0..end];
}

/// Copy a slice into a fixed-size buffer, truncating if needed
pub fn copyTruncate(src: []const u8) [MAX_LABEL_LEN]u8 {
    var buf = [_]u8{0} ** MAX_LABEL_LEN;
    const copy_len = @min(src.len, MAX_LABEL_LEN);
    @memcpy(buf[0..copy_len], src[0..copy_len]);
    return buf;
}

// =============================================================================
// TESTS
// =============================================================================

test "SwarmWatch.init" {
    const sw = SwarmWatch.init();
    try std.testing.expectEqual(@as(u32, 0), sw.snapshot.dht_health.peer_count);
    try std.testing.expectEqual(@as(usize, 0), sw.snapshot.event_count);
    try std.testing.expectEqual(HealthStatus.idle, sw.snapshot.dht_health.status);
}

test "SwarmWatch.pollDhtStats" {
    var sw = SwarmWatch.init();
    sw.pollDhtStats(.{
        .triples_stored = 100,
        .triples_distributed = 50,
        .triples_received = 50,
        .triples_rejected = 10,
        .triples_duplicate = 5,
        .sync_rounds = 3,
        .peer_count = 4,
    });
    try std.testing.expectEqual(@as(u64, 100), sw.snapshot.dht_health.triples_stored);
    try std.testing.expectEqual(@as(u32, 4), sw.snapshot.dht_health.peer_count);
    try std.testing.expectEqual(HealthStatus.healthy, sw.snapshot.dht_health.status);
    try std.testing.expect(sw.snapshot.dht_health.acceptance_rate > 0.8);
}

test "SwarmWatch.pollRewardStats" {
    var sw = SwarmWatch.init();
    sw.pollRewardStats(.{
        .total_paid_wei = 1_000_000_000_000_000_000, // 1 TRI
        .pending_wei = 200_000_000_000_000, // 0.0002 TRI
        .triples_rewarded = 5000,
    });
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sw.snapshot.rewards.total_paid_tri, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0002), sw.snapshot.rewards.pending_tri, 0.0001);
    try std.testing.expectEqual(@as(u64, 5000), sw.snapshot.rewards.triples_rewarded);
}

test "SwarmWatch.recordSyncEvent" {
    var sw = SwarmWatch.init();
    sw.recordSyncEvent(.store, "Alice", "knows", "Bob", .accepted);
    try std.testing.expectEqual(@as(usize, 1), sw.snapshot.event_count);
    try std.testing.expectEqual(@as(u64, 1), sw.snapshot.pipeline_extracted);
    try std.testing.expectEqual(@as(u64, 1), sw.snapshot.pipeline_stored);
    try std.testing.expectEqual(@as(u64, 0), sw.snapshot.pipeline_skipped);

    sw.recordSyncEvent(.sync_inbound, "Bob", "likes", "Zig", .duplicate);
    try std.testing.expectEqual(@as(usize, 2), sw.snapshot.event_count);
    try std.testing.expectEqual(@as(u64, 1), sw.snapshot.pipeline_skipped);
}

test "SwarmWatch.renderDashboard" {
    var sw = SwarmWatch.init();
    sw.pollDhtStats(.{
        .triples_stored = 42,
        .triples_distributed = 10,
        .triples_received = 10,
        .triples_rejected = 1,
        .triples_duplicate = 0,
        .sync_rounds = 5,
        .peer_count = 3,
    });
    sw.pollRewardStats(.{
        .total_paid_wei = 400_000_000_000_000,
        .pending_wei = 200_000_000_000_000,
        .triples_rewarded = 2,
    });
    sw.recordSyncEvent(.store, "Trinity", "is", "ternary", .accepted);

    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try sw.renderDashboard(fbs.writer());
    const output = fbs.getWritten();
    try std.testing.expect(output.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, output, "SWARM-WATCH") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "DHT HEALTH") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "$TRI REWARDS") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "PIPELINE") != null);
}

test "SwarmWatch.exportMetrics" {
    var sw = SwarmWatch.init();
    sw.pollDhtStats(.{
        .triples_stored = 10,
        .triples_distributed = 5,
        .triples_received = 5,
        .triples_rejected = 0,
        .triples_duplicate = 0,
        .sync_rounds = 1,
        .peer_count = 2,
    });

    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try sw.exportMetrics(fbs.writer());
    const output = fbs.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, output, "trinity_dht_peers") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "trinity_dht_triples_stored") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "trinity_tri_earned_total") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "trinity_pipeline_extracted") != null);
}

test "classifyHealth" {
    try std.testing.expectEqual(HealthStatus.idle, classifyHealth(1.0, 5, 0));
    try std.testing.expectEqual(HealthStatus.offline, classifyHealth(1.0, 0, 1));
    try std.testing.expectEqual(HealthStatus.degraded, classifyHealth(0.3, 2, 1));
    try std.testing.expectEqual(HealthStatus.healthy, classifyHealth(0.9, 3, 5));
}

test "ring_buffer_overflow" {
    var sw = SwarmWatch.init();
    var i: usize = 0;
    while (i < MAX_SYNC_EVENTS + 10) : (i += 1) {
        sw.recordSyncEvent(.store, "s", "p", "o", .accepted);
    }
    try std.testing.expectEqual(MAX_SYNC_EVENTS, sw.snapshot.event_count);
    try std.testing.expectEqual(@as(u64, MAX_SYNC_EVENTS + 10), sw.snapshot.pipeline_extracted);
}

test "trimNull" {
    const buf = [_]u8{ 'H', 'e', 'l', 'l', 'o', 0, 0, 0 };
    const trimmed = trimNull(&buf);
    try std.testing.expectEqualStrings("Hello", trimmed);
}

test "copyTruncate" {
    const result = copyTruncate("Hello World");
    try std.testing.expectEqualStrings("Hello World", trimNull(&result));

    // Test truncation with long input
    const long = "A" ** (MAX_LABEL_LEN + 10);
    const truncated = copyTruncate(long);
    try std.testing.expectEqual(MAX_LABEL_LEN, trimNull(&truncated).len);
}
