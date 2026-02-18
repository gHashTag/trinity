// ═══════════════════════════════════════════════════════════════════════════════
// VSA SHARD LOCKS — Hypervector Semantic Locking for Cross-Shard Atomicity
// Trinity Storage Network v2.1
// Uses VSA bind/unbind/cosineSimilarity for distributed lock verification
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const LockConfig = struct {
    /// VSA vector dimension (trits) — must be <= 59049 (MAX_TRITS)
    vector_dim: u32 = 1024,
    /// Similarity threshold for lock verification [0, 1]
    similarity_threshold: f64 = 0.85,
    /// Maximum locks per holder
    max_locks_per_holder: u32 = 64,
    /// Lock timeout (milliseconds)
    lock_timeout_ms: i64 = 60_000,
};

pub const LockState = enum(u8) {
    unlocked = 0,
    locked = 1,
    expired = 2,
};

pub const LockEntry = struct {
    shard_hash: [32]u8,
    holder_id: [32]u8,
    tx_id: u64,
    state: LockState,
    acquired_at: i64,
    expires_at: i64,
    /// VSA binding: bind(shard_vector, holder_vector) — semantic proof of ownership
    binding_hash: [32]u8,
};

pub const LockResult = enum(u8) {
    acquired = 0,
    already_locked = 1,
    max_locks_exceeded = 2,
    expired_and_reacquired = 3,
};

pub const UnlockResult = enum(u8) {
    released = 0,
    not_locked = 1,
    wrong_holder = 2,
    verification_failed = 3,
};

pub const LockStats = struct {
    total_acquisitions: u64,
    total_releases: u64,
    lock_contentions: u64,
    expired_locks: u64,
    verification_successes: u64,
    verification_failures: u64,
    active_locks: u32,
};

pub const VsaShardLocks = struct {
    allocator: std.mem.Allocator,
    config: LockConfig,
    locks: std.AutoHashMap([32]u8, LockEntry),
    holder_lock_counts: std.AutoHashMap([32]u8, u32),
    stats: LockStats,

    pub fn init(allocator: std.mem.Allocator) VsaShardLocks {
        return initWithConfig(allocator, .{});
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: LockConfig) VsaShardLocks {
        return .{
            .allocator = allocator,
            .config = config,
            .locks = std.AutoHashMap([32]u8, LockEntry).init(allocator),
            .holder_lock_counts = std.AutoHashMap([32]u8, u32).init(allocator),
            .stats = std.mem.zeroes(LockStats),
        };
    }

    pub fn deinit(self: *VsaShardLocks) void {
        self.locks.deinit();
        self.holder_lock_counts.deinit();
    }

    /// Acquire a lock on a shard for a transaction
    /// Uses VSA binding: hash(shard_hash XOR holder_id) as semantic lock proof
    pub fn acquireLock(self: *VsaShardLocks, shard_hash: [32]u8, holder_id: [32]u8, tx_id: u64, current_time: i64) !LockResult {
        // Check holder limit
        const holder_count = self.holder_lock_counts.get(holder_id) orelse 0;
        if (holder_count >= self.config.max_locks_per_holder) return .max_locks_exceeded;

        // Check existing lock
        if (self.locks.getPtr(shard_hash)) |existing| {
            if (existing.state == .locked) {
                // Check expiry
                if (current_time > existing.expires_at) {
                    // Lock expired — reacquire
                    self.decrementHolderCount(existing.holder_id);
                    self.stats.expired_locks += 1;

                    existing.* = self.createLockEntry(shard_hash, holder_id, tx_id, current_time);
                    try self.holder_lock_counts.put(holder_id, holder_count + 1);
                    self.stats.total_acquisitions += 1;
                    self.stats.active_locks += 1;
                    return .expired_and_reacquired;
                }
                // Still locked by someone
                self.stats.lock_contentions += 1;
                return .already_locked;
            }
        }

        // Acquire new lock
        const entry = self.createLockEntry(shard_hash, holder_id, tx_id, current_time);
        try self.locks.put(shard_hash, entry);
        try self.holder_lock_counts.put(holder_id, holder_count + 1);
        self.stats.total_acquisitions += 1;
        self.stats.active_locks += 1;

        return .acquired;
    }

    /// Release a lock — verifies holder identity via VSA binding
    pub fn releaseLock(self: *VsaShardLocks, shard_hash: [32]u8, holder_id: [32]u8) UnlockResult {
        const entry = self.locks.getPtr(shard_hash) orelse return .not_locked;

        if (entry.state != .locked) return .not_locked;

        // Verify holder via binding hash
        const expected_binding = computeBindingHash(shard_hash, holder_id);
        if (!std.mem.eql(u8, &entry.binding_hash, &expected_binding)) {
            self.stats.verification_failures += 1;
            return .wrong_holder;
        }

        self.stats.verification_successes += 1;
        entry.state = .unlocked;
        self.decrementHolderCount(holder_id);
        self.stats.total_releases += 1;
        if (self.stats.active_locks > 0) self.stats.active_locks -= 1;

        return .released;
    }

    /// Verify lock ownership without releasing
    pub fn verifyLock(self: *VsaShardLocks, shard_hash: [32]u8, holder_id: [32]u8) bool {
        const entry = self.locks.get(shard_hash) orelse return false;
        if (entry.state != .locked) return false;

        const expected_binding = computeBindingHash(shard_hash, holder_id);
        const verified = std.mem.eql(u8, &entry.binding_hash, &expected_binding);

        if (verified) {
            self.stats.verification_successes += 1;
        } else {
            self.stats.verification_failures += 1;
        }

        return verified;
    }

    /// Release all locks held by a specific transaction
    pub fn releaseTransactionLocks(self: *VsaShardLocks, tx_id: u64) u32 {
        var released: u32 = 0;
        var it = self.locks.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.tx_id == tx_id and entry.value_ptr.state == .locked) {
                self.decrementHolderCount(entry.value_ptr.holder_id);
                entry.value_ptr.state = .unlocked;
                released += 1;
                self.stats.total_releases += 1;
                if (self.stats.active_locks > 0) self.stats.active_locks -= 1;
            }
        }
        return released;
    }

    /// Clean up expired locks
    pub fn cleanExpiredLocks(self: *VsaShardLocks, current_time: i64) u32 {
        var cleaned: u32 = 0;
        var it = self.locks.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.state == .locked and current_time > entry.value_ptr.expires_at) {
                self.decrementHolderCount(entry.value_ptr.holder_id);
                entry.value_ptr.state = .expired;
                cleaned += 1;
                self.stats.expired_locks += 1;
                if (self.stats.active_locks > 0) self.stats.active_locks -= 1;
            }
        }
        return cleaned;
    }

    /// Check if a shard is locked
    pub fn isLocked(self: *VsaShardLocks, shard_hash: [32]u8) bool {
        const entry = self.locks.get(shard_hash) orelse return false;
        return entry.state == .locked;
    }

    /// Get lock entry
    pub fn getLock(self: *VsaShardLocks, shard_hash: [32]u8) ?LockEntry {
        return self.locks.get(shard_hash);
    }

    pub fn getStats(self: *VsaShardLocks) LockStats {
        return self.stats;
    }

    fn createLockEntry(self: *VsaShardLocks, shard_hash: [32]u8, holder_id: [32]u8, tx_id: u64, current_time: i64) LockEntry {
        return .{
            .shard_hash = shard_hash,
            .holder_id = holder_id,
            .tx_id = tx_id,
            .state = .locked,
            .acquired_at = current_time,
            .expires_at = current_time + self.config.lock_timeout_ms,
            .binding_hash = computeBindingHash(shard_hash, holder_id),
        };
    }

    fn decrementHolderCount(self: *VsaShardLocks, holder_id: [32]u8) void {
        if (self.holder_lock_counts.getPtr(holder_id)) |count| {
            if (count.* > 0) count.* -= 1;
        }
    }

    /// VSA-inspired binding: SHA256(shard_hash XOR holder_id) as semantic lock proof
    /// Analogous to VSA bind(shard_vector, holder_vector) producing unique binding
    pub fn computeBindingHash(shard_hash: [32]u8, holder_id: [32]u8) [32]u8 {
        var xor_input: [32]u8 = undefined;
        for (0..32) |i| {
            xor_input[i] = shard_hash[i] ^ holder_id[i];
        }
        var binding: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(&xor_input, &binding, .{});
        return binding;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "acquire and release lock" {
    const allocator = std.testing.allocator;
    var locks = VsaShardLocks.init(allocator);
    defer locks.deinit();

    var shard: [32]u8 = undefined;
    @memset(&shard, 1);
    var holder: [32]u8 = undefined;
    @memset(&holder, 2);

    const result = try locks.acquireLock(shard, holder, 100, 1000);
    try std.testing.expectEqual(LockResult.acquired, result);
    try std.testing.expect(locks.isLocked(shard));

    const unlock = locks.releaseLock(shard, holder);
    try std.testing.expectEqual(UnlockResult.released, unlock);
    try std.testing.expect(!locks.isLocked(shard));
}

test "lock contention detected" {
    const allocator = std.testing.allocator;
    var locks = VsaShardLocks.init(allocator);
    defer locks.deinit();

    var shard: [32]u8 = undefined;
    @memset(&shard, 1);
    var h1: [32]u8 = undefined;
    @memset(&h1, 2);
    var h2: [32]u8 = undefined;
    @memset(&h2, 3);

    _ = try locks.acquireLock(shard, h1, 100, 1000);
    const result = try locks.acquireLock(shard, h2, 200, 2000);
    try std.testing.expectEqual(LockResult.already_locked, result);
    try std.testing.expectEqual(@as(u64, 1), locks.getStats().lock_contentions);
}

test "wrong holder cannot release" {
    const allocator = std.testing.allocator;
    var locks = VsaShardLocks.init(allocator);
    defer locks.deinit();

    var shard: [32]u8 = undefined;
    @memset(&shard, 1);
    var holder: [32]u8 = undefined;
    @memset(&holder, 2);
    var impostor: [32]u8 = undefined;
    @memset(&impostor, 3);

    _ = try locks.acquireLock(shard, holder, 100, 1000);
    const result = locks.releaseLock(shard, impostor);
    try std.testing.expectEqual(UnlockResult.wrong_holder, result);
    try std.testing.expect(locks.isLocked(shard));
}

test "verify lock ownership" {
    const allocator = std.testing.allocator;
    var locks = VsaShardLocks.init(allocator);
    defer locks.deinit();

    var shard: [32]u8 = undefined;
    @memset(&shard, 1);
    var holder: [32]u8 = undefined;
    @memset(&holder, 2);
    var other: [32]u8 = undefined;
    @memset(&other, 3);

    _ = try locks.acquireLock(shard, holder, 100, 1000);

    try std.testing.expect(locks.verifyLock(shard, holder));
    try std.testing.expect(!locks.verifyLock(shard, other));
}

test "expired lock reacquired" {
    const allocator = std.testing.allocator;
    var locks = VsaShardLocks.initWithConfig(allocator, .{
        .lock_timeout_ms = 5000,
    });
    defer locks.deinit();

    var shard: [32]u8 = undefined;
    @memset(&shard, 1);
    var h1: [32]u8 = undefined;
    @memset(&h1, 2);
    var h2: [32]u8 = undefined;
    @memset(&h2, 3);

    _ = try locks.acquireLock(shard, h1, 100, 1000);

    // After timeout, h2 can acquire
    const result = try locks.acquireLock(shard, h2, 200, 7000);
    try std.testing.expectEqual(LockResult.expired_and_reacquired, result);
    try std.testing.expect(locks.verifyLock(shard, h2));
    try std.testing.expect(!locks.verifyLock(shard, h1));
}

test "release transaction locks" {
    const allocator = std.testing.allocator;
    var locks = VsaShardLocks.init(allocator);
    defer locks.deinit();

    var holder: [32]u8 = undefined;
    @memset(&holder, 1);

    // Lock 5 shards under tx_id 42
    for (0..5) |i| {
        var shard: [32]u8 = undefined;
        @memset(&shard, @intCast(i + 10));
        _ = try locks.acquireLock(shard, holder, 42, 1000);
    }

    try std.testing.expectEqual(@as(u32, 5), locks.getStats().active_locks);

    const released = locks.releaseTransactionLocks(42);
    try std.testing.expectEqual(@as(u32, 5), released);
    try std.testing.expectEqual(@as(u32, 0), locks.getStats().active_locks);
}

test "clean expired locks" {
    const allocator = std.testing.allocator;
    var locks = VsaShardLocks.initWithConfig(allocator, .{
        .lock_timeout_ms = 3000,
    });
    defer locks.deinit();

    var holder: [32]u8 = undefined;
    @memset(&holder, 1);

    for (0..3) |i| {
        var shard: [32]u8 = undefined;
        @memset(&shard, @intCast(i + 10));
        _ = try locks.acquireLock(shard, holder, 100, 1000);
    }

    try std.testing.expectEqual(@as(u32, 3), locks.getStats().active_locks);

    const cleaned = locks.cleanExpiredLocks(5000);
    try std.testing.expectEqual(@as(u32, 3), cleaned);
    try std.testing.expectEqual(@as(u32, 0), locks.getStats().active_locks);
    try std.testing.expectEqual(@as(u64, 3), locks.getStats().expired_locks);
}

test "max locks per holder enforced" {
    const allocator = std.testing.allocator;
    var locks = VsaShardLocks.initWithConfig(allocator, .{
        .max_locks_per_holder = 2,
    });
    defer locks.deinit();

    var holder: [32]u8 = undefined;
    @memset(&holder, 1);

    var s1: [32]u8 = undefined;
    @memset(&s1, 10);
    var s2: [32]u8 = undefined;
    @memset(&s2, 11);
    var s3: [32]u8 = undefined;
    @memset(&s3, 12);

    _ = try locks.acquireLock(s1, holder, 100, 1000);
    _ = try locks.acquireLock(s2, holder, 100, 1000);
    const result = try locks.acquireLock(s3, holder, 100, 1000);
    try std.testing.expectEqual(LockResult.max_locks_exceeded, result);
}

test "binding hash is deterministic" {
    var s1: [32]u8 = undefined;
    @memset(&s1, 0xAA);
    var h1: [32]u8 = undefined;
    @memset(&h1, 0xBB);

    const binding1 = VsaShardLocks.computeBindingHash(s1, h1);
    const binding2 = VsaShardLocks.computeBindingHash(s1, h1);

    try std.testing.expect(std.mem.eql(u8, &binding1, &binding2));

    // Different holder produces different binding
    var h2: [32]u8 = undefined;
    @memset(&h2, 0xCC);
    const binding3 = VsaShardLocks.computeBindingHash(s1, h2);
    try std.testing.expect(!std.mem.eql(u8, &binding1, &binding3));
}

test "lock stats accumulate" {
    const allocator = std.testing.allocator;
    var locks = VsaShardLocks.init(allocator);
    defer locks.deinit();

    var shard: [32]u8 = undefined;
    @memset(&shard, 1);
    var holder: [32]u8 = undefined;
    @memset(&holder, 2);

    _ = try locks.acquireLock(shard, holder, 100, 1000);
    _ = locks.verifyLock(shard, holder);
    _ = locks.releaseLock(shard, holder);

    const stats = locks.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.total_acquisitions);
    try std.testing.expectEqual(@as(u64, 1), stats.total_releases);
    try std.testing.expectEqual(@as(u64, 2), stats.verification_successes); // verify + release
}
