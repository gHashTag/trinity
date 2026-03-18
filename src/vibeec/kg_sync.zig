// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY KG SYNC v1.0 — SYM-003 Decentralized Knowledge Graph Sync + $TRI Rewards
// Kademlia-style DHT for KG triple distribution across swarm peers
// Proof-of-Knowledge challenge/verify for $TRI reward gating
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS (from kg_sync.tri)
// ═══════════════════════════════════════════════════════════════════════════════

pub const MAX_TRIPLE_SIZE: usize = 256;
pub const MAX_SUBJECT_LEN: usize = 64;
pub const MAX_PREDICATE_LEN: usize = 32;
pub const MAX_OBJECT_LEN: usize = 128;
pub const REPLICATION_FACTOR: u32 = 3;
pub const MIN_SYNC_CONFIDENCE: f64 = 0.6;
pub const REWARD_KG_TRIPLE_WEI: u128 = 200_000_000_000_000; // 0.0002 TRI per triple
pub const MIN_CONTRIBUTION_FOR_REWARD: u32 = 5;
pub const PROOF_CHALLENGE_TIMEOUT_SECS: i64 = 30;

// ═══════════════════════════════════════════════════════════════════════════════
// Q1: TRIPLE SERIALIZATION (Wire Format)
// ═══════════════════════════════════════════════════════════════════════════════

/// Fixed-size serialized triple for wire transport (MAX_TRIPLE_SIZE bytes total)
/// Layout: [subject:64][predicate:32][object:128][confidence_u32:4][source_node:32][timestamp:8] = 268
/// We use 256 for the triple content portion (64+32+128+4=228, padded to 256)
pub const SerializedTriple = struct {
    subject: [MAX_SUBJECT_LEN]u8,
    predicate: [MAX_PREDICATE_LEN]u8,
    object: [MAX_OBJECT_LEN]u8,
    confidence_u32: u32, // float * 10000
    source_node: [32]u8,
    timestamp: i64,

    pub const WIRE_SIZE: usize = MAX_SUBJECT_LEN + MAX_PREDICATE_LEN + MAX_OBJECT_LEN + 4 + 32 + 8; // 268

    /// Get subject as trimmed slice
    pub fn getSubject(self: *const SerializedTriple) []const u8 {
        return trimNulls(&self.subject);
    }

    /// Get predicate as trimmed slice
    pub fn getPredicate(self: *const SerializedTriple) []const u8 {
        return trimNulls(&self.predicate);
    }

    /// Get object as trimmed slice
    pub fn getObject(self: *const SerializedTriple) []const u8 {
        return trimNulls(&self.object);
    }

    /// Get confidence as float
    pub fn getConfidence(self: *const SerializedTriple) f64 {
        return @as(f64, @floatFromInt(self.confidence_u32)) / 10000.0;
    }
};

/// Trim trailing null bytes from a fixed buffer
fn trimNulls(buf: []const u8) []const u8 {
    var end: usize = buf.len;
    while (end > 0 and buf[end - 1] == 0) {
        end -= 1;
    }
    return buf[0..end];
}

/// Pack subject/predicate/object + confidence into SerializedTriple
pub fn serializeTriple(
    subject: []const u8,
    predicate: []const u8,
    object: []const u8,
    confidence: f64,
    source_node: [32]u8,
) SerializedTriple {
    var result: SerializedTriple = .{
        .subject = [_]u8{0} ** MAX_SUBJECT_LEN,
        .predicate = [_]u8{0} ** MAX_PREDICATE_LEN,
        .object = [_]u8{0} ** MAX_OBJECT_LEN,
        .confidence_u32 = @intFromFloat(confidence * 10000.0),
        .source_node = source_node,
        .timestamp = std.time.timestamp(),
    };

    const s_len = @min(subject.len, MAX_SUBJECT_LEN);
    const p_len = @min(predicate.len, MAX_PREDICATE_LEN);
    const o_len = @min(object.len, MAX_OBJECT_LEN);

    @memcpy(result.subject[0..s_len], subject[0..s_len]);
    @memcpy(result.predicate[0..p_len], predicate[0..p_len]);
    @memcpy(result.object[0..o_len], object[0..o_len]);

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Q1: TRIPLE HASHING (DHT Key + Dedup)
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute deterministic 32-byte hash for a triple (used as DHT key)
/// Uses Wyhash spread across 32 bytes for XOR-distance compatibility
pub fn tripleHash(subject: []const u8, predicate: []const u8, object: []const u8) [32]u8 {
    var hasher = std.hash.Wyhash.init(0);
    hasher.update(subject);
    hasher.update("|");
    hasher.update(predicate);
    hasher.update("|");
    hasher.update(object);
    const h1 = hasher.final();

    // Second hash with different seed for more bits
    var hasher2 = std.hash.Wyhash.init(1);
    hasher2.update(object);
    hasher2.update("~");
    hasher2.update(subject);
    hasher2.update("~");
    hasher2.update(predicate);
    const h2 = hasher2.final();

    // Third hash
    var hasher3 = std.hash.Wyhash.init(2);
    hasher3.update(predicate);
    hasher3.update("#");
    hasher3.update(object);
    hasher3.update("#");
    hasher3.update(subject);
    const h3 = hasher3.final();

    // Fourth hash
    var hasher4 = std.hash.Wyhash.init(3);
    hasher4.update(subject);
    hasher4.update(predicate);
    hasher4.update(object);
    const h4 = hasher4.final();

    var result: [32]u8 = undefined;
    std.mem.writeInt(u64, result[0..8], h1, .little);
    std.mem.writeInt(u64, result[8..16], h2, .little);
    std.mem.writeInt(u64, result[16..24], h3, .little);
    std.mem.writeInt(u64, result[24..32], h4, .little);
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Q1: XOR DISTANCE (Kademlia DHT)
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute byte-wise XOR distance between two 32-byte IDs
pub fn xorDistance(a: [32]u8, b: [32]u8) [32]u8 {
    var result: [32]u8 = undefined;
    for (0..32) |i| {
        result[i] = a[i] ^ b[i];
    }
    return result;
}

/// Compare two XOR distances (returns true if a < b)
fn distanceLessThan(a: [32]u8, b: [32]u8) bool {
    for (0..32) |i| {
        if (a[i] < b[i]) return true;
        if (a[i] > b[i]) return false;
    }
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Q1: KG TRIPLE DHT
// ═══════════════════════════════════════════════════════════════════════════════

pub const KgDHTStats = struct {
    triples_stored: u64,
    triples_retrieved: u64,
    triples_distributed: u64,
    triples_received: u64,
    triples_rejected: u64,
    triples_duplicate: u64,
    sync_rounds: u64,
};

pub const KgTripleDHT = struct {
    local_triples: std.AutoHashMap([32]u8, SerializedTriple),
    allocator: std.mem.Allocator,
    replication_factor: u32,
    local_node_id: [32]u8,

    // Stats
    stats: KgDHTStats,

    // Peer node IDs for distribution (simplified: just IDs, no real network)
    peer_nodes: std.ArrayListUnmanaged([32]u8),

    pub fn init(allocator: std.mem.Allocator, local_node_id: [32]u8) KgTripleDHT {
        return .{
            .local_triples = std.AutoHashMap([32]u8, SerializedTriple).init(allocator),
            .allocator = allocator,
            .replication_factor = REPLICATION_FACTOR,
            .local_node_id = local_node_id,
            .stats = std.mem.zeroes(KgDHTStats),
            .peer_nodes = .{},
        };
    }

    pub fn deinit(self: *KgTripleDHT) void {
        self.local_triples.deinit();
        self.peer_nodes.deinit(self.allocator);
    }

    /// Add a peer node to the DHT routing table
    pub fn addPeer(self: *KgTripleDHT, node_id: [32]u8) !void {
        // Skip self
        if (std.mem.eql(u8, &node_id, &self.local_node_id)) return;
        // Skip duplicates
        for (self.peer_nodes.items) |existing| {
            if (std.mem.eql(u8, &existing, &node_id)) return;
        }
        try self.peer_nodes.append(self.allocator, node_id);
    }

    /// Store a triple locally and track distribution to k closest peers
    pub fn storeTriple(self: *KgTripleDHT, hash: [32]u8, triple: SerializedTriple) !void {
        // Dedup check
        if (self.local_triples.contains(hash)) {
            self.stats.triples_duplicate += 1;
            return;
        }

        try self.local_triples.put(hash, triple);
        self.stats.triples_stored += 1;

        // Find k closest peers and track distribution
        const responsible = try self.findResponsiblePeers(hash);
        defer self.allocator.free(responsible);
        self.stats.triples_distributed += @intCast(responsible.len);
    }

    /// Retrieve a triple by hash
    pub fn retrieveTriple(self: *KgTripleDHT, hash: [32]u8) ?SerializedTriple {
        if (self.local_triples.get(hash)) |triple| {
            self.stats.triples_retrieved += 1;
            return triple;
        }
        return null;
    }

    /// Handle inbound triple from remote peer (sync)
    pub fn syncInbound(self: *KgTripleDHT, triple: SerializedTriple) !SyncResult {
        // Confidence gate
        if (triple.getConfidence() < MIN_SYNC_CONFIDENCE) {
            self.stats.triples_rejected += 1;
            return .rejected_low_confidence;
        }

        // Compute hash for dedup
        const hash = tripleHash(triple.getSubject(), triple.getPredicate(), triple.getObject());

        // Dedup
        if (self.local_triples.contains(hash)) {
            self.stats.triples_duplicate += 1;
            return .duplicate;
        }

        // Accept
        try self.local_triples.put(hash, triple);
        self.stats.triples_received += 1;
        return .accepted;
    }

    /// Find k closest peers by XOR distance to a hash
    pub fn findResponsiblePeers(self: *KgTripleDHT, target_hash: [32]u8) ![][32]u8 {
        if (self.peer_nodes.items.len == 0) {
            return self.allocator.alloc([32]u8, 0);
        }

        const PeerDist = struct {
            node_id: [32]u8,
            distance: [32]u8,
        };

        var peer_dists = try self.allocator.alloc(PeerDist, self.peer_nodes.items.len);
        defer self.allocator.free(peer_dists);

        for (self.peer_nodes.items, 0..) |peer_id, i| {
            peer_dists[i] = .{
                .node_id = peer_id,
                .distance = xorDistance(target_hash, peer_id),
            };
        }

        std.mem.sort(PeerDist, peer_dists, {}, struct {
            fn lessThan(_: void, a: PeerDist, b_val: PeerDist) bool {
                return distanceLessThan(a.distance, b_val.distance);
            }
        }.lessThan);

        const k = @min(self.replication_factor, @as(u32, @intCast(peer_dists.len)));
        const result = try self.allocator.alloc([32]u8, k);
        for (0..k) |i| {
            result[i] = peer_dists[i].node_id;
        }
        return result;
    }

    /// Get local triple count
    pub fn getTripleCount(self: *KgTripleDHT) u32 {
        return @intCast(self.local_triples.count());
    }

    /// Get stats
    pub fn getStats(self: *KgTripleDHT) KgDHTStats {
        return self.stats;
    }
};

pub const SyncResult = enum {
    accepted,
    duplicate,
    rejected_low_confidence,
};

// ═══════════════════════════════════════════════════════════════════════════════
// Q3: PROOF OF KNOWLEDGE
// ═══════════════════════════════════════════════════════════════════════════════

pub const ProofOfKnowledge = struct {
    challenge_id: [32]u8,
    challenger_id: [32]u8,
    target_id: [32]u8,
    triple_hash: [32]u8,
    timestamp: i64,
};

pub const ProofResponse = struct {
    challenge_id: [32]u8,
    prover_id: [32]u8,
    subject: [MAX_SUBJECT_LEN]u8,
    predicate: [MAX_PREDICATE_LEN]u8,
    object: [MAX_OBJECT_LEN]u8,

    pub fn getSubject(self: *const ProofResponse) []const u8 {
        return trimNulls(&self.subject);
    }
    pub fn getPredicate(self: *const ProofResponse) []const u8 {
        return trimNulls(&self.predicate);
    }
    pub fn getObject(self: *const ProofResponse) []const u8 {
        return trimNulls(&self.object);
    }
};

/// Create a Proof-of-Knowledge challenge for a target node
pub fn createChallenge(
    challenger_id: [32]u8,
    target_id: [32]u8,
    triple_hash: [32]u8,
) ProofOfKnowledge {
    // Generate challenge ID from inputs
    var hasher = std.hash.Wyhash.init(10);
    hasher.update(&challenger_id);
    hasher.update(&target_id);
    hasher.update(&triple_hash);
    const h1 = hasher.final();

    var hasher2 = std.hash.Wyhash.init(11);
    hasher2.update(&triple_hash);
    hasher2.update(&challenger_id);
    const h2 = hasher2.final();

    var hasher3 = std.hash.Wyhash.init(12);
    hasher3.update(&target_id);
    hasher3.update(&triple_hash);
    const h3 = hasher3.final();

    var hasher4 = std.hash.Wyhash.init(13);
    hasher4.update(&challenger_id);
    hasher4.update(&target_id);
    const h4 = hasher4.final();

    var challenge_id: [32]u8 = undefined;
    std.mem.writeInt(u64, challenge_id[0..8], h1, .little);
    std.mem.writeInt(u64, challenge_id[8..16], h2, .little);
    std.mem.writeInt(u64, challenge_id[16..24], h3, .little);
    std.mem.writeInt(u64, challenge_id[24..32], h4, .little);

    return .{
        .challenge_id = challenge_id,
        .challenger_id = challenger_id,
        .target_id = target_id,
        .triple_hash = triple_hash,
        .timestamp = std.time.timestamp(),
    };
}

/// Respond to a PoK challenge using local DHT store
pub fn respondToChallenge(
    challenge: ProofOfKnowledge,
    dht: *KgTripleDHT,
) ?ProofResponse {
    // Look up the triple by hash
    const triple = dht.retrieveTriple(challenge.triple_hash) orelse return null;

    var response: ProofResponse = .{
        .challenge_id = challenge.challenge_id,
        .prover_id = dht.local_node_id,
        .subject = triple.subject,
        .predicate = triple.predicate,
        .object = triple.object,
    };
    _ = &response;
    return response;
}

/// Verify a PoK response: hash the provided fields and compare to challenge
pub fn verifyProof(
    challenge: ProofOfKnowledge,
    response: ProofResponse,
) bool {
    // Challenge IDs must match
    if (!std.mem.eql(u8, &challenge.challenge_id, &response.challenge_id)) return false;

    // Hash the response fields and compare to challenge triple_hash
    const computed = tripleHash(
        response.getSubject(),
        response.getPredicate(),
        response.getObject(),
    );
    return std.mem.eql(u8, &computed, &challenge.triple_hash);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Q4: $TRI KG REWARDS
// ═══════════════════════════════════════════════════════════════════════════════

pub const KgContribution = struct {
    node_id: [32]u8,
    triples_contributed: u32,
    triples_accepted: u32,
    rewards_earned_wei: u128,
    last_contribution_time: i64,
};

pub const KgRewardCalculator = struct {
    contributions: std.AutoHashMap([32]u8, KgContribution),
    allocator: std.mem.Allocator,

    // Global stats
    total_rewards_paid: u128,
    total_triples_rewarded: u64,

    pub fn init(allocator: std.mem.Allocator) KgRewardCalculator {
        return .{
            .contributions = std.AutoHashMap([32]u8, KgContribution).init(allocator),
            .allocator = allocator,
            .total_rewards_paid = 0,
            .total_triples_rewarded = 0,
        };
    }

    pub fn deinit(self: *KgRewardCalculator) void {
        self.contributions.deinit();
    }

    /// Record a contribution from a node
    pub fn recordContribution(self: *KgRewardCalculator, node_id: [32]u8, accepted_count: u32) !void {
        const result = try self.contributions.getOrPut(node_id);
        if (!result.found_existing) {
            result.value_ptr.* = .{
                .node_id = node_id,
                .triples_contributed = 0,
                .triples_accepted = 0,
                .rewards_earned_wei = 0,
                .last_contribution_time = 0,
            };
        }
        result.value_ptr.triples_contributed += accepted_count;
        result.value_ptr.triples_accepted += accepted_count;
        result.value_ptr.last_contribution_time = std.time.timestamp();
    }

    /// Calculate reward for a node (returns wei, 0 if below minimum)
    pub fn calculateReward(self: *KgRewardCalculator, node_id: [32]u8) u128 {
        const contrib = self.contributions.get(node_id) orelse return 0;
        if (contrib.triples_accepted < MIN_CONTRIBUTION_FOR_REWARD) return 0;
        return @as(u128, contrib.triples_accepted) * REWARD_KG_TRIPLE_WEI;
    }

    /// Claim rewards for a node (returns amount, resets counter)
    pub fn claimReward(self: *KgRewardCalculator, node_id: [32]u8) u128 {
        const ptr = self.contributions.getPtr(node_id) orelse return 0;
        const reward = self.calculateReward(node_id);
        if (reward == 0) return 0;

        ptr.rewards_earned_wei += reward;
        self.total_rewards_paid += reward;
        self.total_triples_rewarded += ptr.triples_accepted;
        ptr.triples_accepted = 0; // Reset accepted count after claim
        return reward;
    }

    /// Get contribution record for a node
    pub fn getContribution(self: *KgRewardCalculator, node_id: [32]u8) ?KgContribution {
        return self.contributions.get(node_id);
    }

    /// Format wei to TRI
    pub fn weiToTri(wei: u128) f64 {
        return @as(f64, @floatFromInt(wei)) / 1_000_000_000_000_000_000.0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Q5: SYNC ORCHESTRATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const SyncOrchestratorStats = struct {
    responses_processed: u64,
    triples_extracted: u64,
    triples_synced: u64,
    rewards_calculated: u64,
};

/// Global sync stats (zero-init)
pub var g_sync_stats: SyncOrchestratorStats = .{
    .responses_processed = 0,
    .triples_extracted = 0,
    .triples_synced = 0,
    .rewards_calculated = 0,
};

/// Orchestrate: extract triples from text, store in DHT, track contribution
pub fn syncExtractedTriples(
    subject: []const u8,
    predicate: []const u8,
    object: []const u8,
    confidence: f64,
    dht: *KgTripleDHT,
    rewards: *KgRewardCalculator,
) !bool {
    // Confidence gate
    if (confidence < MIN_SYNC_CONFIDENCE) return false;

    // Serialize
    const triple = serializeTriple(subject, predicate, object, confidence, dht.local_node_id);

    // Hash for DHT key
    const hash = tripleHash(subject, predicate, object);

    // Store in DHT (handles dedup internally)
    const prev_stored = dht.stats.triples_stored;
    try dht.storeTriple(hash, triple);

    // If new triple stored (not dedup), track contribution
    if (dht.stats.triples_stored > prev_stored) {
        try rewards.recordContribution(dht.local_node_id, 1);
        g_sync_stats.triples_synced += 1;
        return true;
    }
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "serialize/deserialize roundtrip" {
    const node = [_]u8{0x42} ** 32;
    const triple = serializeTriple("paris", "is_capital_of", "france", 0.85, node);

    try std.testing.expectEqualSlices(u8, "paris", triple.getSubject());
    try std.testing.expectEqualSlices(u8, "is_capital_of", triple.getPredicate());
    try std.testing.expectEqualSlices(u8, "france", triple.getObject());

    // Confidence: 0.85 * 10000 = 8500 -> 8500 / 10000 = 0.85
    const conf = triple.getConfidence();
    try std.testing.expect(conf > 0.84 and conf < 0.86);
}

test "tripleHash deterministic" {
    const h1 = tripleHash("paris", "is_capital_of", "france");
    const h2 = tripleHash("paris", "is_capital_of", "france");
    try std.testing.expectEqualSlices(u8, &h1, &h2);

    // Different input = different hash
    const h3 = tripleHash("london", "is_capital_of", "uk");
    try std.testing.expect(!std.mem.eql(u8, &h1, &h3));
}

test "KgTripleDHT store and retrieve" {
    const allocator = std.testing.allocator;
    const node_id = [_]u8{0x42} ** 32;

    var dht = KgTripleDHT.init(allocator, node_id);
    defer dht.deinit();

    const triple = serializeTriple("paris", "is_capital_of", "france", 0.85, node_id);
    const hash = tripleHash("paris", "is_capital_of", "france");

    try dht.storeTriple(hash, triple);

    // Retrieve
    const retrieved = dht.retrieveTriple(hash);
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualSlices(u8, "paris", retrieved.?.getSubject());

    // Missing hash
    const missing = [_]u8{0xBB} ** 32;
    try std.testing.expect(dht.retrieveTriple(missing) == null);

    try std.testing.expectEqual(@as(u32, 1), dht.getTripleCount());
}

test "KgTripleDHT dedup" {
    const allocator = std.testing.allocator;
    const node_id = [_]u8{0x42} ** 32;

    var dht = KgTripleDHT.init(allocator, node_id);
    defer dht.deinit();

    const triple = serializeTriple("paris", "is_capital_of", "france", 0.85, node_id);
    const hash = tripleHash("paris", "is_capital_of", "france");

    try dht.storeTriple(hash, triple);
    try dht.storeTriple(hash, triple); // duplicate

    try std.testing.expectEqual(@as(u32, 1), dht.getTripleCount());
    try std.testing.expectEqual(@as(u64, 1), dht.stats.triples_stored);
    try std.testing.expectEqual(@as(u64, 1), dht.stats.triples_duplicate);
}

test "KgTripleDHT syncInbound confidence gate" {
    const allocator = std.testing.allocator;
    const node_id = [_]u8{0x42} ** 32;

    var dht = KgTripleDHT.init(allocator, node_id);
    defer dht.deinit();

    // Low confidence -> rejected
    const low_conf = serializeTriple("x", "y", "z", 0.3, [_]u8{0x01} ** 32);
    const r1 = try dht.syncInbound(low_conf);
    try std.testing.expectEqual(SyncResult.rejected_low_confidence, r1);
    try std.testing.expectEqual(@as(u64, 1), dht.stats.triples_rejected);

    // High confidence -> accepted
    const high_conf = serializeTriple("paris", "is_capital_of", "france", 0.8, [_]u8{0x02} ** 32);
    const r2 = try dht.syncInbound(high_conf);
    try std.testing.expectEqual(SyncResult.accepted, r2);
    try std.testing.expectEqual(@as(u64, 1), dht.stats.triples_received);

    // Duplicate -> duplicate
    const dup = serializeTriple("paris", "is_capital_of", "france", 0.9, [_]u8{0x03} ** 32);
    const r3 = try dht.syncInbound(dup);
    try std.testing.expectEqual(SyncResult.duplicate, r3);
}

test "KgTripleDHT findResponsiblePeers XOR ordering" {
    const allocator = std.testing.allocator;
    const local_id = [_]u8{0xFF} ** 32;

    var dht = KgTripleDHT.init(allocator, local_id);
    defer dht.deinit();

    // Add 5 peers
    for (0..5) |i| {
        const peer_id = [_]u8{@intCast(i + 1)} ** 32;
        try dht.addPeer(peer_id);
    }

    // Find peers closest to 0x03..03
    const target = [_]u8{0x03} ** 32;
    const responsible = try dht.findResponsiblePeers(target);
    defer allocator.free(responsible);

    // Should return k=3 peers
    try std.testing.expectEqual(@as(usize, 3), responsible.len);

    // Closest should be 0x03..03 (XOR distance = 0)
    try std.testing.expectEqual([_]u8{0x03} ** 32, responsible[0]);

    // Verify ordering
    for (0..responsible.len - 1) |i| {
        const d_i = xorDistance(target, responsible[i]);
        const d_next = xorDistance(target, responsible[i + 1]);
        try std.testing.expect(!distanceLessThan(d_next, d_i));
    }
}

test "ProofOfKnowledge challenge/verify cycle" {
    const allocator = std.testing.allocator;
    const challenger = [_]u8{0x01} ** 32;
    const target = [_]u8{0x02} ** 32;

    var dht = KgTripleDHT.init(allocator, target);
    defer dht.deinit();

    // Store a triple in target's DHT
    const triple = serializeTriple("earth", "has", "moon", 0.9, target);
    const hash = tripleHash("earth", "has", "moon");
    try dht.storeTriple(hash, triple);

    // Create challenge
    const challenge = createChallenge(challenger, target, hash);
    try std.testing.expectEqual(challenger, challenge.challenger_id);
    try std.testing.expectEqual(target, challenge.target_id);

    // Respond
    const response = respondToChallenge(challenge, &dht);
    try std.testing.expect(response != null);
    try std.testing.expectEqualSlices(u8, "earth", response.?.getSubject());

    // Verify
    try std.testing.expect(verifyProof(challenge, response.?));

    // Tampered response fails
    var tampered = response.?;
    tampered.subject[0] = 'X';
    try std.testing.expect(!verifyProof(challenge, tampered));
}

test "ProofOfKnowledge challenge for missing triple" {
    const allocator = std.testing.allocator;
    const target = [_]u8{0x02} ** 32;

    var dht = KgTripleDHT.init(allocator, target);
    defer dht.deinit();

    // Challenge for a triple the node doesn't have
    const hash = tripleHash("unknown", "relation", "entity");
    const challenge = createChallenge([_]u8{0x01} ** 32, target, hash);
    const response = respondToChallenge(challenge, &dht);
    try std.testing.expect(response == null);
}

test "KgRewardCalculator basic flow" {
    const allocator = std.testing.allocator;
    var calc = KgRewardCalculator.init(allocator);
    defer calc.deinit();

    const node = [_]u8{0x42} ** 32;

    // Below minimum -> no reward
    try calc.recordContribution(node, 3);
    try std.testing.expectEqual(@as(u128, 0), calc.calculateReward(node));

    // Add more to reach minimum
    try calc.recordContribution(node, 7); // total: 10
    const reward = calc.calculateReward(node);
    try std.testing.expectEqual(@as(u128, 10 * REWARD_KG_TRIPLE_WEI), reward);

    // Claim
    const claimed = calc.claimReward(node);
    try std.testing.expectEqual(reward, claimed);

    // After claim, accepted resets
    try std.testing.expectEqual(@as(u128, 0), calc.calculateReward(node));

    // Verify total tracked
    try std.testing.expectEqual(claimed, calc.total_rewards_paid);
}

test "KgRewardCalculator weiToTri conversion" {
    const one_tri = 1_000_000_000_000_000_000;
    try std.testing.expectEqual(@as(f64, 1.0), KgRewardCalculator.weiToTri(one_tri));

    const reward_10 = 10 * REWARD_KG_TRIPLE_WEI;
    const tri_val = KgRewardCalculator.weiToTri(reward_10);
    try std.testing.expect(tri_val > 0.0 and tri_val < 1.0);
}

test "syncExtractedTriples full pipeline" {
    const allocator = std.testing.allocator;
    const node_id = [_]u8{0x42} ** 32;

    var dht = KgTripleDHT.init(allocator, node_id);
    defer dht.deinit();

    var rewards = KgRewardCalculator.init(allocator);
    defer rewards.deinit();

    // Reset global stats
    g_sync_stats = .{ .responses_processed = 0, .triples_extracted = 0, .triples_synced = 0, .rewards_calculated = 0 };

    // Sync a triple
    const stored = try syncExtractedTriples("python", "is_a", "language", 0.85, &dht, &rewards);
    try std.testing.expect(stored);
    try std.testing.expectEqual(@as(u64, 1), g_sync_stats.triples_synced);

    // Low confidence rejected
    const rejected = try syncExtractedTriples("x", "y", "z", 0.3, &dht, &rewards);
    try std.testing.expect(!rejected);

    // Duplicate rejected
    const dup = try syncExtractedTriples("python", "is_a", "language", 0.85, &dht, &rewards);
    try std.testing.expect(!dup);

    // Verify contribution tracked
    const contrib = rewards.getContribution(node_id);
    try std.testing.expect(contrib != null);
    try std.testing.expectEqual(@as(u32, 1), contrib.?.triples_accepted);
}

test "xorDistance properties" {
    // d(a, a) = 0
    const a = [_]u8{0x42} ** 32;
    const d_aa = xorDistance(a, a);
    try std.testing.expectEqual([_]u8{0} ** 32, d_aa);

    // Symmetry
    const b = [_]u8{0xFF} ** 32;
    const d_ab = xorDistance(a, b);
    const d_ba = xorDistance(b, a);
    try std.testing.expectEqualSlices(u8, &d_ab, &d_ba);
}
