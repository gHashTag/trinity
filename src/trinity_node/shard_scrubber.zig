// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY SHARD SCRUBBER v1.6 - Periodic SHA256 Re-Verification
// Detect bit-rot and silent corruption before PoS catches it
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const storage_mod = @import("storage.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// SCRUB RESULT
// ═══════════════════════════════════════════════════════════════════════════════

pub const ScrubResult = struct {
    detected_at: i64,
    expected_hash: [32]u8,
    actual_hash: [32]u8,
};

pub const ScrubStats = struct {
    total_scrubs: u64,
    shards_checked: u64,
    corruptions_found: u64,
    last_scrub_time: i64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// SHARD SCRUBBER
// ═══════════════════════════════════════════════════════════════════════════════

pub const ShardScrubber = struct {
    allocator: std.mem.Allocator,
    corrupted_shards: std.AutoHashMap([32]u8, ScrubResult),
    scrub_interval_secs: i64,
    last_scrub_time: i64,
    mutex: std.Thread.Mutex,

    // Stats
    total_scrubs: u64,
    shards_checked: u64,
    corruptions_found: u64,

    pub fn init(allocator: std.mem.Allocator) ShardScrubber {
        return .{
            .allocator = allocator,
            .corrupted_shards = std.AutoHashMap([32]u8, ScrubResult).init(allocator),
            .scrub_interval_secs = 600, // 10 minutes default
            .last_scrub_time = 0,
            .mutex = .{},
            .total_scrubs = 0,
            .shards_checked = 0,
            .corruptions_found = 0,
        };
    }

    pub fn deinit(self: *ShardScrubber) void {
        self.corrupted_shards.deinit();
    }

    /// Scrub all shards on a storage provider, re-computing SHA256 and comparing
    /// Returns the number of corrupted shards found in this scrub round
    pub fn scrubNode(self: *ShardScrubber, provider: *storage_mod.StorageProvider) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var found: u32 = 0;
        self.total_scrubs += 1;

        var iter = provider.shards.iterator();
        while (iter.next()) |entry| {
            const expected_hash = entry.key_ptr.*;
            const data = entry.value_ptr.*;

            self.shards_checked += 1;

            // Re-compute SHA256
            var actual_hash: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(data, &actual_hash, .{});

            if (!std.mem.eql(u8, &actual_hash, &expected_hash)) {
                // Corruption detected
                self.corrupted_shards.put(expected_hash, .{
                    .detected_at = std.time.timestamp(),
                    .expected_hash = expected_hash,
                    .actual_hash = actual_hash,
                }) catch |err| {
                    std.log.debug("shard_scrubber: corrupted shard record failed: {}", .{err});
                };
                self.corruptions_found += 1;
                found += 1;
            }
        }

        self.last_scrub_time = std.time.timestamp();
        return found;
    }

    /// Check if a specific shard has been flagged as corrupted
    pub fn isCorrupted(self: *ShardScrubber, shard_hash: [32]u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.corrupted_shards.contains(shard_hash);
    }

    /// Get all corrupted shard hashes
    pub fn getCorruptedShards(self: *ShardScrubber, allocator: std.mem.Allocator) ![][32]u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var result = std.ArrayListUnmanaged([32]u8){};
        errdefer result.deinit(allocator);

        var iter = self.corrupted_shards.keyIterator();
        while (iter.next()) |key| {
            try result.append(allocator, key.*);
        }

        return result.toOwnedSlice(allocator);
    }

    /// Clear a corrupted shard entry (e.g., after re-downloading)
    pub fn clearCorrupted(self: *ShardScrubber, shard_hash: [32]u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        _ = self.corrupted_shards.remove(shard_hash);
    }

    /// Check if it's time to run a scrub
    pub fn shouldScrub(self: *ShardScrubber) bool {
        const now = std.time.timestamp();
        return (now - self.last_scrub_time) >= self.scrub_interval_secs;
    }

    /// Get scrub stats
    pub fn getStats(self: *ShardScrubber) ScrubStats {
        self.mutex.lock();
        defer self.mutex.unlock();
        return .{
            .total_scrubs = self.total_scrubs,
            .shards_checked = self.shards_checked,
            .corruptions_found = self.corruptions_found,
            .last_scrub_time = self.last_scrub_time,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "scrub honest data finds zero corruptions" {
    const allocator = std.testing.allocator;

    var scrubber = ShardScrubber.init(allocator);
    defer scrubber.deinit();

    var provider = storage_mod.StorageProvider.init(allocator, .{
        .max_bytes = 1024 * 1024,
        .shard_size = 64,
        .replication_factor = 1,
        .rs_parity_ratio = 0,
    });
    defer provider.deinit();

    // Store 3 honest shards
    for (0..3) |i| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(i + 1));
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(&data, &hash, .{});
        _ = try provider.storeShard(hash, &data);
    }

    const corrupted = scrubber.scrubNode(&provider);
    try std.testing.expectEqual(@as(u32, 0), corrupted);
    try std.testing.expectEqual(@as(u64, 3), scrubber.shards_checked);
    try std.testing.expectEqual(@as(u64, 1), scrubber.total_scrubs);
}

test "scrub detects tampered data" {
    const allocator = std.testing.allocator;

    var scrubber = ShardScrubber.init(allocator);
    defer scrubber.deinit();

    var provider = storage_mod.StorageProvider.init(allocator, .{
        .max_bytes = 1024 * 1024,
        .shard_size = 64,
        .replication_factor = 1,
        .rs_parity_ratio = 0,
    });
    defer provider.deinit();

    // Store an honest shard
    var data: [64]u8 = undefined;
    @memset(&data, 0x42);
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&data, &hash, .{});
    _ = try provider.storeShard(hash, &data);

    // Tamper with the shard data directly (bypass API)
    if (provider.shards.getPtr(hash)) |ptr| {
        ptr.*[0] = 0xFF; // Corrupt first byte
    }

    const corrupted = scrubber.scrubNode(&provider);
    try std.testing.expectEqual(@as(u32, 1), corrupted);
    try std.testing.expect(scrubber.isCorrupted(hash));
}

test "getCorruptedShards returns all corrupted hashes" {
    const allocator = std.testing.allocator;

    var scrubber = ShardScrubber.init(allocator);
    defer scrubber.deinit();

    var provider = storage_mod.StorageProvider.init(allocator, .{
        .max_bytes = 1024 * 1024,
        .shard_size = 64,
        .replication_factor = 1,
        .rs_parity_ratio = 0,
    });
    defer provider.deinit();

    // Store 2 shards
    var hashes: [2][32]u8 = undefined;
    for (0..2) |i| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(i + 0x10));
        std.crypto.hash.sha2.Sha256.hash(&data, &hashes[i], .{});
        _ = try provider.storeShard(hashes[i], &data);
    }

    // Tamper with both
    for (0..2) |i| {
        if (provider.shards.getPtr(hashes[i])) |ptr| {
            ptr.*[0] = 0xFF;
        }
    }

    _ = scrubber.scrubNode(&provider);
    const corrupted = try scrubber.getCorruptedShards(allocator);
    defer allocator.free(corrupted);

    try std.testing.expectEqual(@as(usize, 2), corrupted.len);
}

test "clearCorrupted removes entry" {
    const allocator = std.testing.allocator;

    var scrubber = ShardScrubber.init(allocator);
    defer scrubber.deinit();

    var provider = storage_mod.StorageProvider.init(allocator, .{
        .max_bytes = 1024 * 1024,
        .shard_size = 64,
        .replication_factor = 1,
        .rs_parity_ratio = 0,
    });
    defer provider.deinit();

    var data: [64]u8 = undefined;
    @memset(&data, 0x55);
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&data, &hash, .{});
    _ = try provider.storeShard(hash, &data);

    // Tamper and scrub
    if (provider.shards.getPtr(hash)) |ptr| {
        ptr.*[0] = 0x00;
    }
    _ = scrubber.scrubNode(&provider);
    try std.testing.expect(scrubber.isCorrupted(hash));

    // Clear and verify
    scrubber.clearCorrupted(hash);
    try std.testing.expect(!scrubber.isCorrupted(hash));
}

test "shouldScrub respects interval" {
    const allocator = std.testing.allocator;

    var scrubber = ShardScrubber.init(allocator);
    defer scrubber.deinit();
    scrubber.scrub_interval_secs = 600;

    // Initially should scrub (last_scrub_time = 0)
    try std.testing.expect(scrubber.shouldScrub());

    // After setting recent time, should not scrub
    scrubber.last_scrub_time = std.time.timestamp();
    try std.testing.expect(!scrubber.shouldScrub());
}

test "stats accumulate across multiple scrubs" {
    const allocator = std.testing.allocator;

    var scrubber = ShardScrubber.init(allocator);
    defer scrubber.deinit();

    var provider = storage_mod.StorageProvider.init(allocator, .{
        .max_bytes = 1024 * 1024,
        .shard_size = 64,
        .replication_factor = 1,
        .rs_parity_ratio = 0,
    });
    defer provider.deinit();

    // Store 2 honest shards
    for (0..2) |i| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(i + 1));
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(&data, &hash, .{});
        _ = try provider.storeShard(hash, &data);
    }

    // Scrub twice
    _ = scrubber.scrubNode(&provider);
    _ = scrubber.scrubNode(&provider);

    const stats = scrubber.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.total_scrubs);
    try std.testing.expectEqual(@as(u64, 4), stats.shards_checked); // 2 shards * 2 scrubs
    try std.testing.expectEqual(@as(u64, 0), stats.corruptions_found);
}
