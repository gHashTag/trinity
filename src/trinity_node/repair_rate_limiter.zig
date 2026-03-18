// =============================================================================
// TRINITY REPAIR RATE LIMITER v1.8 - Throttled Auto-Repair with Circuit Breaker
// Prevents repair storms by limiting repairs per window + circuit breaker on failures
// V = n * 3^k * pi^m * phi^p * e^q
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");
const auto_repair_mod = @import("auto_repair.zig");
const storage_mod = @import("storage.zig");
const shard_scrubber_mod = @import("shard_scrubber.zig");

// =============================================================================
// RATE LIMITER CONFIGURATION
// =============================================================================

pub const RateLimiterConfig = struct {
    /// Maximum repairs allowed per window
    max_repairs_per_window: u32 = 10,
    /// Window duration in seconds
    window_secs: i64 = 60,
    /// Circuit breaker: max consecutive failures before halting
    max_consecutive_failures: u32 = 5,
    /// Cooldown after circuit breaker trips (seconds)
    cooldown_secs: i64 = 300,
};

pub const RateLimiterStats = struct {
    total_allowed: u64,
    total_throttled: u64,
    total_circuit_breaks: u64,
    current_window_repairs: u32,
    circuit_breaker_open: bool,
    consecutive_failures: u32,
};

// =============================================================================
// REPAIR RATE LIMITER
// =============================================================================

pub const RepairRateLimiter = struct {
    allocator: std.mem.Allocator,
    config: RateLimiterConfig,
    repair_engine: auto_repair_mod.AutoRepairEngine,

    // Window tracking
    window_start: i64,
    window_repairs: u32,

    // Circuit breaker
    consecutive_failures: u32,
    circuit_breaker_open: bool,
    circuit_break_time: i64,

    // Stats
    total_allowed: u64,
    total_throttled: u64,
    total_circuit_breaks: u64,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) RepairRateLimiter {
        return initWithConfig(allocator, .{});
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: RateLimiterConfig) RepairRateLimiter {
        return .{
            .allocator = allocator,
            .config = config,
            .repair_engine = auto_repair_mod.AutoRepairEngine.init(allocator),
            .window_start = std.time.timestamp(),
            .window_repairs = 0,
            .consecutive_failures = 0,
            .circuit_breaker_open = false,
            .circuit_break_time = 0,
            .total_allowed = 0,
            .total_throttled = 0,
            .total_circuit_breaks = 0,
            .mutex = .{},
        };
    }

    pub fn deinit(self: *RepairRateLimiter) void {
        self.repair_engine.deinit();
    }

    /// Check if a repair is currently allowed
    pub fn canRepair(self: *RepairRateLimiter) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.canRepairUnlocked();
    }

    fn canRepairUnlocked(self: *RepairRateLimiter) bool {
        const now = std.time.timestamp();

        // Check circuit breaker
        if (self.circuit_breaker_open) {
            if (now - self.circuit_break_time >= self.config.cooldown_secs) {
                // Cooldown expired — reset circuit breaker
                self.circuit_breaker_open = false;
                self.consecutive_failures = 0;
            } else {
                return false;
            }
        }

        // Check window
        if (now - self.window_start >= self.config.window_secs) {
            // New window — reset counter
            self.window_start = now;
            self.window_repairs = 0;
        }

        return self.window_repairs < self.config.max_repairs_per_window;
    }

    /// Throttled repair: respects rate limit and circuit breaker
    /// Returns number of shards actually repaired (may be less than available)
    pub fn throttledRepair(
        self: *RepairRateLimiter,
        scrubber: *shard_scrubber_mod.ShardScrubber,
        local_peer_idx: usize,
        peers: []*storage_mod.StorageProvider,
    ) !u32 {
        // Get corrupted shards
        const corrupted = try scrubber.getCorruptedShards(self.allocator);
        defer self.allocator.free(corrupted);

        var repaired: u32 = 0;

        for (corrupted) |hash| {
            // Check rate limit
            self.mutex.lock();
            if (!self.canRepairUnlocked()) {
                self.total_throttled += 1;
                self.mutex.unlock();
                continue;
            }
            self.mutex.unlock();

            // Attempt single shard repair
            var found_healthy = false;
            for (peers, 0..) |peer, idx| {
                if (idx == local_peer_idx) continue;

                if (peer.retrieveShard(hash)) |healthy_data| {
                    var verify_hash: [32]u8 = undefined;
                    std.crypto.hash.sha2.Sha256.hash(healthy_data, &verify_hash, .{});

                    if (std.mem.eql(u8, &verify_hash, &hash)) {
                        const local = peers[local_peer_idx];
                        if (local.shards.fetchRemove(hash)) |kv| {
                            local.used_bytes -= kv.value.len;
                            local.allocator.free(kv.value);
                        }

                        _ = local.storeShard(hash, healthy_data) catch {
                            self.mutex.lock();
                            self.consecutive_failures += 1;
                            self.checkCircuitBreaker();
                            self.mutex.unlock();
                            continue;
                        };

                        scrubber.clearCorrupted(hash);

                        self.mutex.lock();
                        self.window_repairs += 1;
                        self.total_allowed += 1;
                        self.consecutive_failures = 0; // Reset on success
                        self.repair_engine.repairs_attempted += 1;
                        self.repair_engine.repairs_succeeded += 1;
                        self.repair_engine.shards_replaced += 1;
                        self.mutex.unlock();

                        repaired += 1;
                        found_healthy = true;
                        break;
                    }
                }
            }

            if (!found_healthy) {
                self.mutex.lock();
                self.consecutive_failures += 1;
                self.repair_engine.repairs_attempted += 1;
                self.repair_engine.repairs_failed += 1;
                self.checkCircuitBreaker();
                self.mutex.unlock();
            }
        }

        return repaired;
    }

    fn checkCircuitBreaker(self: *RepairRateLimiter) void {
        if (self.consecutive_failures >= self.config.max_consecutive_failures) {
            self.circuit_breaker_open = true;
            self.circuit_break_time = std.time.timestamp();
            self.total_circuit_breaks += 1;
        }
    }

    /// Manually reset the circuit breaker
    pub fn resetCircuitBreaker(self: *RepairRateLimiter) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.circuit_breaker_open = false;
        self.consecutive_failures = 0;
    }

    /// Get stats
    pub fn getStats(self: *RepairRateLimiter) RateLimiterStats {
        self.mutex.lock();
        defer self.mutex.unlock();
        return .{
            .total_allowed = self.total_allowed,
            .total_throttled = self.total_throttled,
            .total_circuit_breaks = self.total_circuit_breaks,
            .current_window_repairs = self.window_repairs,
            .circuit_breaker_open = self.circuit_breaker_open,
            .consecutive_failures = self.consecutive_failures,
        };
    }

    /// Get underlying repair engine stats
    pub fn getRepairStats(self: *RepairRateLimiter) auto_repair_mod.AutoRepairStats {
        return self.repair_engine.getStats();
    }
};

// =============================================================================
// TESTS
// =============================================================================

test "rate limiter allows repairs within limit" {
    const allocator = std.testing.allocator;

    var limiter = RepairRateLimiter.initWithConfig(allocator, .{
        .max_repairs_per_window = 5,
        .window_secs = 60,
        .max_consecutive_failures = 3,
        .cooldown_secs = 300,
    });
    defer limiter.deinit();

    // Create 3 nodes with replicated shards
    var nodes: [3]storage_mod.StorageProvider = undefined;
    for (0..3) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..3) |i| nodes[i].deinit();

    var peers: [3]*storage_mod.StorageProvider = undefined;
    for (0..3) |i| peers[i] = &nodes[i];

    // Store 3 shards on all 3 nodes
    var hashes: [3][32]u8 = undefined;
    for (0..3) |s| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(s + 0x10));
        std.crypto.hash.sha2.Sha256.hash(&data, &hashes[s], .{});
        for (0..3) |i| _ = try nodes[i].storeShard(hashes[s], &data);
    }

    // Corrupt all 3 on node 0
    for (0..3) |s| {
        if (nodes[0].shards.getPtr(hashes[s])) |ptr| ptr.*[0] ^= 0xFF;
    }

    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();
    _ = scrubber.scrubNode(&nodes[0]);

    // Rate limit is 5 — should repair all 3
    const repaired = try limiter.throttledRepair(&scrubber, 0, &peers);
    try std.testing.expectEqual(@as(u32, 3), repaired);

    const stats = limiter.getStats();
    try std.testing.expectEqual(@as(u64, 3), stats.total_allowed);
    try std.testing.expectEqual(@as(u64, 0), stats.total_throttled);
    try std.testing.expect(!stats.circuit_breaker_open);
}

test "rate limiter throttles when over limit" {
    const allocator = std.testing.allocator;

    var limiter = RepairRateLimiter.initWithConfig(allocator, .{
        .max_repairs_per_window = 2, // Only 2 per window
        .window_secs = 60,
        .max_consecutive_failures = 10,
        .cooldown_secs = 300,
    });
    defer limiter.deinit();

    var nodes: [3]storage_mod.StorageProvider = undefined;
    for (0..3) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..3) |i| nodes[i].deinit();

    var peers: [3]*storage_mod.StorageProvider = undefined;
    for (0..3) |i| peers[i] = &nodes[i];

    // Store 5 shards on all nodes
    var hashes: [5][32]u8 = undefined;
    for (0..5) |s| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(s + 0x20));
        std.crypto.hash.sha2.Sha256.hash(&data, &hashes[s], .{});
        for (0..3) |i| _ = try nodes[i].storeShard(hashes[s], &data);
    }

    // Corrupt all 5 on node 0
    for (0..5) |s| {
        if (nodes[0].shards.getPtr(hashes[s])) |ptr| ptr.*[0] ^= 0xFF;
    }

    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();
    _ = scrubber.scrubNode(&nodes[0]);

    // Rate limit is 2 — should repair only 2, throttle 3
    const repaired = try limiter.throttledRepair(&scrubber, 0, &peers);
    try std.testing.expectEqual(@as(u32, 2), repaired);

    const stats = limiter.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.total_allowed);
    try std.testing.expectEqual(@as(u64, 3), stats.total_throttled);
}

test "circuit breaker trips after consecutive failures" {
    const allocator = std.testing.allocator;

    var limiter = RepairRateLimiter.initWithConfig(allocator, .{
        .max_repairs_per_window = 100,
        .window_secs = 60,
        .max_consecutive_failures = 2, // Trip after 2 failures
        .cooldown_secs = 9999, // Long cooldown for testing
    });
    defer limiter.deinit();

    // Create 2 nodes — no replicas, so all repairs fail
    var nodes: [2]storage_mod.StorageProvider = undefined;
    for (0..2) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..2) |i| nodes[i].deinit();

    var peers: [2]*storage_mod.StorageProvider = undefined;
    for (0..2) |i| peers[i] = &nodes[i];

    // Store 3 shards only on node 0 (no replicas)
    var hashes: [3][32]u8 = undefined;
    for (0..3) |s| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(s + 0x30));
        std.crypto.hash.sha2.Sha256.hash(&data, &hashes[s], .{});
        _ = try nodes[0].storeShard(hashes[s], &data);
    }

    // Corrupt all 3
    for (0..3) |s| {
        if (nodes[0].shards.getPtr(hashes[s])) |ptr| ptr.*[0] ^= 0xFF;
    }

    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();
    _ = scrubber.scrubNode(&nodes[0]);

    // Should attempt repairs, fail, trip circuit breaker after 2
    const repaired = try limiter.throttledRepair(&scrubber, 0, &peers);
    try std.testing.expectEqual(@as(u32, 0), repaired);

    const stats = limiter.getStats();
    try std.testing.expect(stats.circuit_breaker_open);
    try std.testing.expectEqual(@as(u64, 1), stats.total_circuit_breaks);
    // After 2 failures, circuit breaker opens, 3rd is throttled
    try std.testing.expect(stats.total_throttled >= 1);
}

test "manual circuit breaker reset" {
    const allocator = std.testing.allocator;

    var limiter = RepairRateLimiter.initWithConfig(allocator, .{
        .max_repairs_per_window = 100,
        .window_secs = 60,
        .max_consecutive_failures = 1, // Trips immediately
        .cooldown_secs = 9999,
    });
    defer limiter.deinit();

    // Force circuit breaker
    limiter.mutex.lock();
    limiter.consecutive_failures = 1;
    limiter.checkCircuitBreaker();
    limiter.mutex.unlock();

    try std.testing.expect(limiter.getStats().circuit_breaker_open);
    try std.testing.expect(!limiter.canRepair());

    // Reset
    limiter.resetCircuitBreaker();
    try std.testing.expect(!limiter.getStats().circuit_breaker_open);
    try std.testing.expect(limiter.canRepair());
}

test "canRepair checks rate limit" {
    const allocator = std.testing.allocator;

    var limiter = RepairRateLimiter.initWithConfig(allocator, .{
        .max_repairs_per_window = 2,
        .window_secs = 60,
        .max_consecutive_failures = 100,
        .cooldown_secs = 300,
    });
    defer limiter.deinit();

    try std.testing.expect(limiter.canRepair());

    // Simulate using up the window
    limiter.mutex.lock();
    limiter.window_repairs = 2;
    limiter.mutex.unlock();

    try std.testing.expect(!limiter.canRepair());
}
