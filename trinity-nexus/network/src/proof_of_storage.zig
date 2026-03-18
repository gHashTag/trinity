// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY PROOF-OF-STORAGE v1.5 - Cryptographic Storage Verification
// Challenge-response protocol to verify peers actually store claimed shards
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const protocol = @import("protocol.zig");
const storage_mod = @import("storage.zig");
const storage_discovery = @import("storage_discovery.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// PROOF-OF-STORAGE ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

pub const ProofOfStorageEngine = struct {
    allocator: std.mem.Allocator,
    pending_challenges: std.AutoHashMap([32]u8, protocol.StorageChallengeMsg),
    failed_challenges: std.AutoHashMap([32]u8, u32), // node_id -> failure count
    challenge_interval_secs: i64,
    max_failures: u32,
    last_challenge_time: i64,

    // Stats
    challenges_issued: u64,
    challenges_passed: u64,
    challenges_failed: u64,

    pub fn init(allocator: std.mem.Allocator) ProofOfStorageEngine {
        return .{
            .allocator = allocator,
            .pending_challenges = std.AutoHashMap([32]u8, protocol.StorageChallengeMsg).init(allocator),
            .failed_challenges = std.AutoHashMap([32]u8, u32).init(allocator),
            .challenge_interval_secs = 300, // 5 minutes
            .max_failures = 3,
            .last_challenge_time = 0,
            .challenges_issued = 0,
            .challenges_passed = 0,
            .challenges_failed = 0,
        };
    }

    pub fn deinit(self: *ProofOfStorageEngine) void {
        self.pending_challenges.deinit();
        self.failed_challenges.deinit();
    }

    /// Issue a challenge for a specific shard to a specific node
    pub fn createChallenge(
        self: *ProofOfStorageEngine,
        challenger_id: [32]u8,
        target_node_id: [32]u8,
        shard_hash: [32]u8,
        shard_size: u32,
    ) !protocol.StorageChallengeMsg {
        // Generate random challenge ID
        var challenge_id: [32]u8 = undefined;
        std.crypto.random.bytes(&challenge_id);

        // Random byte range within shard
        const max_offset = if (shard_size > 64) shard_size - 64 else 0;
        const byte_offset = if (max_offset > 0) std.crypto.random.intRangeAtMost(u32, 0, max_offset) else 0;
        const byte_length = @min(@as(u32, 64), shard_size - byte_offset);

        const challenge = protocol.StorageChallengeMsg{
            .challenge_id = challenge_id,
            .challenger_id = challenger_id,
            .target_node_id = target_node_id,
            .shard_hash = shard_hash,
            .byte_offset = byte_offset,
            .byte_length = byte_length,
            .timestamp = std.time.timestamp(),
        };

        try self.pending_challenges.put(challenge_id, challenge);
        self.challenges_issued += 1;
        self.last_challenge_time = std.time.timestamp();

        return challenge;
    }

    /// Generate a proof in response to a challenge (called by the challenged node)
    pub fn respondToChallenge(
        challenge: protocol.StorageChallengeMsg,
        storage_provider: *storage_mod.StorageProvider,
        responder_id: [32]u8,
    ) !protocol.StorageProofMsg {
        // Retrieve the shard data
        const shard_data = storage_provider.shards.get(challenge.shard_hash) orelse
            return error.ShardNotFound;

        // Extract the requested byte range
        const end = challenge.byte_offset + challenge.byte_length;
        if (end > shard_data.len) return error.InvalidRange;
        const byte_range = shard_data[challenge.byte_offset..end];

        // Compute SHA256 of the byte range
        var proof_hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(byte_range, &proof_hash, .{});

        return protocol.StorageProofMsg{
            .challenge_id = challenge.challenge_id,
            .prover_id = responder_id,
            .proof_hash = proof_hash,
            .timestamp = std.time.timestamp(),
        };
    }

    /// Verify a proof against the pending challenge using local shard copy
    pub fn verifyProof(
        self: *ProofOfStorageEngine,
        proof: protocol.StorageProofMsg,
        storage_provider: *storage_mod.StorageProvider,
    ) !bool {
        // Look up the pending challenge
        const challenge = self.pending_challenges.get(proof.challenge_id) orelse
            return error.UnknownChallenge;

        // Compute expected hash from local copy
        const shard_data = storage_provider.shards.get(challenge.shard_hash) orelse
            return error.ShardNotFound;

        const end = challenge.byte_offset + challenge.byte_length;
        if (end > shard_data.len) return error.InvalidRange;
        const byte_range = shard_data[challenge.byte_offset..end];

        var expected_hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(byte_range, &expected_hash, .{});

        // Remove from pending
        _ = self.pending_challenges.remove(proof.challenge_id);

        // Compare hashes
        if (std.mem.eql(u8, &proof.proof_hash, &expected_hash)) {
            self.challenges_passed += 1;
            return true;
        } else {
            self.challenges_failed += 1;
            // Increment failure count for this node
            const result = try self.failed_challenges.getOrPut(proof.prover_id);
            if (result.found_existing) {
                result.value_ptr.* += 1;
            } else {
                result.value_ptr.* = 1;
            }
            return false;
        }
    }

    /// Check if it's time to issue a new challenge round
    pub fn shouldChallenge(self: *ProofOfStorageEngine) bool {
        const now = std.time.timestamp();
        return (now - self.last_challenge_time) >= self.challenge_interval_secs;
    }

    /// Get failure count for a node
    pub fn getFailureCount(self: *ProofOfStorageEngine, node_id: [32]u8) u32 {
        return self.failed_challenges.get(node_id) orelse 0;
    }

    /// Check if a node has exceeded max failures
    pub fn isUnreliable(self: *ProofOfStorageEngine, node_id: [32]u8) bool {
        return self.getFailureCount(node_id) >= self.max_failures;
    }

    /// Get stats
    pub fn getStats(self: *ProofOfStorageEngine) PosStats {
        return .{
            .challenges_issued = self.challenges_issued,
            .challenges_passed = self.challenges_passed,
            .challenges_failed = self.challenges_failed,
            .pending_count = @intCast(self.pending_challenges.count()),
        };
    }
};

pub const PosStats = struct {
    challenges_issued: u64,
    challenges_passed: u64,
    challenges_failed: u64,
    pending_count: u32,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "create challenge produces valid fields" {
    const allocator = std.testing.allocator;

    var engine = ProofOfStorageEngine.init(allocator);
    defer engine.deinit();

    const challenger_id = [_]u8{0xAA} ** 32;
    const target_id = [_]u8{0xBB} ** 32;
    const shard_hash = [_]u8{0xCC} ** 32;

    const challenge = try engine.createChallenge(challenger_id, target_id, shard_hash, 512);

    try std.testing.expectEqualSlices(u8, &challenger_id, &challenge.challenger_id);
    try std.testing.expectEqualSlices(u8, &target_id, &challenge.target_node_id);
    try std.testing.expectEqualSlices(u8, &shard_hash, &challenge.shard_hash);
    try std.testing.expect(challenge.byte_offset + challenge.byte_length <= 512);
    try std.testing.expect(challenge.byte_length > 0);
    try std.testing.expectEqual(@as(u64, 1), engine.challenges_issued);
}

test "respond to challenge produces correct proof" {
    const allocator = std.testing.allocator;

    // Create a storage provider with a shard
    var provider = storage_mod.StorageProvider.init(allocator, .{
        .max_bytes = 1024 * 1024,
        .shard_size = 256,
        .replication_factor = 1,
        .rs_parity_ratio = 0,
    });
    defer provider.deinit();

    // Store a shard with known data
    var shard_data: [256]u8 = undefined;
    for (0..256) |i| shard_data[i] = @intCast(i);
    var shard_hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&shard_data, &shard_hash, .{});
    _ = try provider.storeShard(shard_hash, &shard_data);

    // Create a challenge for byte range [10..74] (64 bytes)
    const challenge = protocol.StorageChallengeMsg{
        .challenge_id = [_]u8{0x01} ** 32,
        .challenger_id = [_]u8{0xAA} ** 32,
        .target_node_id = [_]u8{0xBB} ** 32,
        .shard_hash = shard_hash,
        .byte_offset = 10,
        .byte_length = 64,
        .timestamp = std.time.timestamp(),
    };

    const responder_id = [_]u8{0xBB} ** 32;
    const proof = try ProofOfStorageEngine.respondToChallenge(challenge, &provider, responder_id);

    // Verify the proof hash manually
    var expected_hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(shard_data[10..74], &expected_hash, .{});
    try std.testing.expectEqualSlices(u8, &expected_hash, &proof.proof_hash);
    try std.testing.expectEqualSlices(u8, &responder_id, &proof.prover_id);
}

test "verify proof succeeds for honest node" {
    const allocator = std.testing.allocator;

    var engine = ProofOfStorageEngine.init(allocator);
    defer engine.deinit();

    // Both challenger and prover have the same shard
    var provider = storage_mod.StorageProvider.init(allocator, .{
        .max_bytes = 1024 * 1024,
        .shard_size = 128,
        .replication_factor = 1,
        .rs_parity_ratio = 0,
    });
    defer provider.deinit();

    var shard_data: [128]u8 = undefined;
    for (0..128) |i| shard_data[i] = @intCast((i * 7 + 13) % 256);
    var shard_hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&shard_data, &shard_hash, .{});
    _ = try provider.storeShard(shard_hash, &shard_data);

    const challenger_id = [_]u8{0xAA} ** 32;
    const target_id = [_]u8{0xBB} ** 32;
    const challenge = try engine.createChallenge(challenger_id, target_id, shard_hash, 128);

    // Prover responds honestly
    const proof = try ProofOfStorageEngine.respondToChallenge(challenge, &provider, target_id);

    // Challenger verifies
    const valid = try engine.verifyProof(proof, &provider);
    try std.testing.expect(valid);
    try std.testing.expectEqual(@as(u64, 1), engine.challenges_passed);
    try std.testing.expectEqual(@as(u64, 0), engine.challenges_failed);
}

test "verify proof fails for tampered data" {
    const allocator = std.testing.allocator;

    var engine = ProofOfStorageEngine.init(allocator);
    defer engine.deinit();

    // Challenger's storage
    var challenger_provider = storage_mod.StorageProvider.init(allocator, .{
        .max_bytes = 1024 * 1024,
        .shard_size = 128,
        .replication_factor = 1,
        .rs_parity_ratio = 0,
    });
    defer challenger_provider.deinit();

    var shard_data: [128]u8 = undefined;
    for (0..128) |i| shard_data[i] = @intCast(i);
    var shard_hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&shard_data, &shard_hash, .{});
    _ = try challenger_provider.storeShard(shard_hash, &shard_data);

    const challenger_id = [_]u8{0xAA} ** 32;
    const target_id = [_]u8{0xBB} ** 32;
    const challenge = try engine.createChallenge(challenger_id, target_id, shard_hash, 128);

    // Prover sends a fake proof (wrong hash)
    const fake_proof = protocol.StorageProofMsg{
        .challenge_id = challenge.challenge_id,
        .prover_id = target_id,
        .proof_hash = [_]u8{0xFF} ** 32, // Wrong hash
        .timestamp = std.time.timestamp(),
    };

    const valid = try engine.verifyProof(fake_proof, &challenger_provider);
    try std.testing.expect(!valid);
    try std.testing.expectEqual(@as(u64, 1), engine.challenges_failed);
    try std.testing.expectEqual(@as(u32, 1), engine.getFailureCount(target_id));
}

test "unreliable after max failures" {
    const allocator = std.testing.allocator;

    var engine = ProofOfStorageEngine.init(allocator);
    defer engine.deinit();
    engine.max_failures = 3;

    var provider = storage_mod.StorageProvider.init(allocator, .{
        .max_bytes = 1024 * 1024,
        .shard_size = 64,
        .replication_factor = 1,
        .rs_parity_ratio = 0,
    });
    defer provider.deinit();

    var shard_data: [64]u8 = undefined;
    @memset(&shard_data, 0x42);
    var shard_hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&shard_data, &shard_hash, .{});
    _ = try provider.storeShard(shard_hash, &shard_data);

    const challenger_id = [_]u8{0xAA} ** 32;
    const target_id = [_]u8{0xBB} ** 32;

    // Fail 3 times
    for (0..3) |_| {
        const challenge = try engine.createChallenge(challenger_id, target_id, shard_hash, 64);
        const fake_proof = protocol.StorageProofMsg{
            .challenge_id = challenge.challenge_id,
            .prover_id = target_id,
            .proof_hash = [_]u8{0x00} ** 32,
            .timestamp = std.time.timestamp(),
        };
        _ = try engine.verifyProof(fake_proof, &provider);
    }

    try std.testing.expectEqual(@as(u32, 3), engine.getFailureCount(target_id));
    try std.testing.expect(engine.isUnreliable(target_id));

    // Another node with 0 failures is still reliable
    const good_node = [_]u8{0xCC} ** 32;
    try std.testing.expect(!engine.isUnreliable(good_node));
}

test "challenge timing respects interval" {
    const allocator = std.testing.allocator;

    var engine = ProofOfStorageEngine.init(allocator);
    defer engine.deinit();
    engine.challenge_interval_secs = 300;

    // Initially should challenge (last_challenge_time = 0)
    try std.testing.expect(engine.shouldChallenge());

    // After issuing a challenge, should not challenge again immediately
    engine.last_challenge_time = std.time.timestamp();
    try std.testing.expect(!engine.shouldChallenge());
}
