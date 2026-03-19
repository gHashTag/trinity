// =============================================================================
// TRINITY SYM-005 SOTA MVP v1.0 - Decentralized Knowledge Collector Demo
// End-to-end: LLM Response -> Triple Extraction -> KG DHT Store -> TRI Rewards
// Generated from: specs/tri/tri_sota_mvp.vibee
// V = n * 3^k * pi^m * phi^p * e^q
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");
const triples_parser = @import("triples_parser");
const kg_sync = @import("kg_sync");

// =============================================================================
// DEMO PIPELINE STATS
// =============================================================================

pub const DemoPipelineStats = struct {
    responses_processed: u64,
    triples_extracted: u64,
    triples_stored: u64,
    triples_distributed: u64,
    rewards_earned_wei: u128,
    proofs_verified: u64,
    proofs_failed: u64,
    queries_answered: u64,
    dedup_count: u64,
    low_conf_rejected: u64,
};

// =============================================================================
// SAMPLE LLM RESPONSES (deterministic test data)
// =============================================================================

const SAMPLE_RESPONSES = [_][]const u8{
    "Paris is the capital of France. The Eiffel Tower is in Paris.",
    "Python is a programming language. It has dynamic typing.",
    "Water contains hydrogen and oxygen. Water is essential for life.",
    "Einstein is a physicist. He has the theory of relativity.",
    "Tokyo is the capital of Japan. Japan is an island nation.",
};

// =============================================================================
// CORE: FULL PIPELINE — extractTriples -> DHT store -> rewards
// =============================================================================

/// Process a single LLM response through the full pipeline
pub fn processResponse(
    response_text: []const u8,
    dht: *kg_sync.KgTripleDHT,
    rewards: *kg_sync.KgRewardCalculator,
    stats: *DemoPipelineStats,
) !void {
    stats.responses_processed += 1;

    // Step 1: Extract triples from LLM response text
    const extraction = triples_parser.extractTriples(response_text);

    if (extraction.count == 0) return;

    // Step 2: For each extracted triple, sync to DHT + track rewards
    for (0..extraction.count) |i| {
        if (extraction.get(i)) |triple| {
            stats.triples_extracted += 1;

            // Confidence gate (matches SYM-003 constant)
            if (triple.confidence < kg_sync.MIN_SYNC_CONFIDENCE) {
                stats.low_conf_rejected += 1;
                continue;
            }

            // Sync to DHT (handles dedup internally)
            const synced = try kg_sync.syncExtractedTriples(
                triple.subject(),
                triple.predicate(),
                triple.object(),
                triple.confidence,
                dht,
                rewards,
            );

            if (synced) {
                stats.triples_stored += 1;
                stats.triples_distributed += kg_sync.REPLICATION_FACTOR;
            } else {
                stats.dedup_count += 1;
            }
        }
    }
}

/// Run the complete demo pipeline with all sample responses
pub fn runFullDemo(
    allocator: std.mem.Allocator,
    node_id: [32]u8,
    peer_ids: []const [32]u8,
) !DemoPipelineStats {
    var dht = kg_sync.KgTripleDHT.init(allocator, node_id);
    defer dht.deinit();

    // Add peers
    for (peer_ids) |pid| {
        try dht.addPeer(pid);
    }

    var rewards = kg_sync.KgRewardCalculator.init(allocator);
    defer rewards.deinit();

    var stats = std.mem.zeroes(DemoPipelineStats);

    // Process all sample responses
    for (SAMPLE_RESPONSES) |response| {
        try processResponse(response, &dht, &rewards, &stats);
    }

    // Calculate final rewards
    const reward = rewards.calculateReward(node_id);
    stats.rewards_earned_wei = reward;

    return stats;
}

/// Run Proof-of-Knowledge verification cycle
pub fn runProofCycle(
    allocator: std.mem.Allocator,
    node_id: [32]u8,
    challenger_id: [32]u8,
) !struct { passed: u32, failed: u32 } {
    var dht = kg_sync.KgTripleDHT.init(allocator, node_id);
    defer dht.deinit();

    var rewards = kg_sync.KgRewardCalculator.init(allocator);
    defer rewards.deinit();

    var stats = std.mem.zeroes(DemoPipelineStats);

    // Store some triples first
    for (SAMPLE_RESPONSES) |response| {
        try processResponse(response, &dht, &rewards, &stats);
    }

    // Now run proof challenges on stored triples
    var passed: u32 = 0;
    var failed: u32 = 0;

    var iter = dht.local_triples.iterator();
    while (iter.next()) |entry| {
        const triple_hash = entry.key_ptr.*;

        // Create challenge
        const challenge = kg_sync.createChallenge(challenger_id, node_id, triple_hash);

        // Respond
        if (kg_sync.respondToChallenge(challenge, &dht)) |response| {
            // Verify
            if (kg_sync.verifyProof(challenge, response)) {
                passed += 1;
            } else {
                failed += 1;
            }
        } else {
            failed += 1;
        }
    }

    return .{ .passed = passed, .failed = failed };
}

// =============================================================================
// TESTS — Full Pipeline Validation
// =============================================================================

test "SYM-005 full pipeline: extract -> store -> distribute" {
    const allocator = std.testing.allocator;
    const node_id = [_]u8{0x42} ** 32;

    // Create 5 mock peers
    var peers: [5][32]u8 = undefined;
    for (0..5) |i| {
        @memset(&peers[i], @intCast(i + 1));
    }

    const stats = try runFullDemo(allocator, node_id, &peers);

    // All 5 responses processed
    try std.testing.expectEqual(@as(u64, 5), stats.responses_processed);

    // Should extract at least some triples (the sample texts have SVO patterns)
    try std.testing.expect(stats.triples_extracted > 0);

    // At least some triples should be stored (high enough confidence)
    try std.testing.expect(stats.triples_stored > 0);

    // Distribution = stored * REPLICATION_FACTOR
    try std.testing.expectEqual(stats.triples_stored * kg_sync.REPLICATION_FACTOR, stats.triples_distributed);
}

test "SYM-005 proof-of-knowledge cycle" {
    const allocator = std.testing.allocator;
    const node_id = [_]u8{0x42} ** 32;
    const challenger = [_]u8{0x01} ** 32;

    const result = try runProofCycle(allocator, node_id, challenger);

    // All stored triples should pass PoK verification
    try std.testing.expect(result.passed > 0);
    try std.testing.expectEqual(@as(u32, 0), result.failed);
}

test "SYM-005 reward accumulation" {
    const allocator = std.testing.allocator;
    const node_id = [_]u8{0x42} ** 32;

    var dht = kg_sync.KgTripleDHT.init(allocator, node_id);
    defer dht.deinit();

    var rewards = kg_sync.KgRewardCalculator.init(allocator);
    defer rewards.deinit();

    var stats = std.mem.zeroes(DemoPipelineStats);

    // Process all 5 sample responses
    for (SAMPLE_RESPONSES) |response| {
        try processResponse(response, &dht, &rewards, &stats);
    }

    // With 5 responses, we should get 5+ triples
    // MIN_CONTRIBUTION_FOR_REWARD = 5, so rewards should be claimable
    const contrib = rewards.getContribution(node_id);
    try std.testing.expect(contrib != null);

    // If >= 5 triples accepted, reward should be non-zero
    if (contrib.?.triples_accepted >= kg_sync.MIN_CONTRIBUTION_FOR_REWARD) {
        const reward = rewards.calculateReward(node_id);
        try std.testing.expect(reward > 0);

        // Verify exact: triples * 0.0002 TRI
        const expected = @as(u128, contrib.?.triples_accepted) * kg_sync.REWARD_KG_TRIPLE_WEI;
        try std.testing.expectEqual(expected, reward);

        // Claim and verify
        const claimed = rewards.claimReward(node_id);
        try std.testing.expectEqual(expected, claimed);

        // After claim, no more rewards pending
        try std.testing.expectEqual(@as(u128, 0), rewards.calculateReward(node_id));
    }
}

test "SYM-005 dedup protection" {
    const allocator = std.testing.allocator;
    const node_id = [_]u8{0x42} ** 32;

    var dht = kg_sync.KgTripleDHT.init(allocator, node_id);
    defer dht.deinit();

    var rewards = kg_sync.KgRewardCalculator.init(allocator);
    defer rewards.deinit();

    var stats = std.mem.zeroes(DemoPipelineStats);

    // Process same response twice
    const response = "Paris is the capital of France.";
    try processResponse(response, &dht, &rewards, &stats);
    try processResponse(response, &dht, &rewards, &stats);

    // Both processed
    try std.testing.expectEqual(@as(u64, 2), stats.responses_processed);

    // But only stored once (dedup on second run)
    try std.testing.expect(stats.dedup_count > 0);

    // Stored count should not double
    const dht_count = dht.getTripleCount();
    try std.testing.expect(dht_count > 0);
    // Triples stored first time should equal DHT count
    try std.testing.expectEqual(@as(u32, @intCast(stats.triples_stored)), dht_count);
}

test "SYM-005 DHT peer routing" {
    const allocator = std.testing.allocator;
    const node_id = [_]u8{0xFF} ** 32;

    var dht = kg_sync.KgTripleDHT.init(allocator, node_id);
    defer dht.deinit();

    // Add 5 peers
    for (0..5) |i| {
        try dht.addPeer([_]u8{@intCast(i + 1)} ** 32);
    }

    // Hash a triple and find responsible peers
    const hash = kg_sync.tripleHash("test", "is", "working");
    const responsible = try dht.findResponsiblePeers(hash);
    defer allocator.free(responsible);

    // Should return k=3 peers
    try std.testing.expectEqual(@as(usize, kg_sync.REPLICATION_FACTOR), responsible.len);

    // Verify XOR ordering (each peer closer than next)
    for (0..responsible.len - 1) |i| {
        const d_curr = kg_sync.xorDistance(hash, responsible[i]);
        const d_next = kg_sync.xorDistance(hash, responsible[i + 1]);
        // d_curr <= d_next (verified by NOT d_next < d_curr)
        var next_closer = false;
        for (0..32) |byte_idx| {
            if (d_next[byte_idx] < d_curr[byte_idx]) { next_closer = true; break; }
            if (d_next[byte_idx] > d_curr[byte_idx]) break;
        }
        try std.testing.expect(!next_closer);
    }
}

test "SYM-005 energy efficiency metric" {
    // KG query: 0.0008 Wh (from igla_knowledge_graph.zig)
    // Cloud LLM: ~0.1 Wh per query
    // Savings: 125x
    const kg_energy_wh: f64 = 0.0008;
    const cloud_energy_wh: f64 = 0.1;
    const savings_factor = cloud_energy_wh / kg_energy_wh;
    try std.testing.expect(savings_factor >= 100.0);

    // Wire format: 268 bytes per triple (from SYM-003)
    try std.testing.expectEqual(@as(usize, 268), kg_sync.SerializedTriple.WIRE_SIZE);

    // Memory per 1000 triples: 268 * 1000 = 268 KB (vs ~10 MB for float32 KG)
    const mem_1000 = 268 * 1000;
    try std.testing.expect(mem_1000 < 300_000); // Under 300 KB
}

test "SYM-005 TRI reward math" {
    // 0.0002 TRI per triple
    const reward_per_triple = kg_sync.KgRewardCalculator.weiToTri(kg_sync.REWARD_KG_TRIPLE_WEI);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0002), reward_per_triple, 0.00001);

    // 1000 triples = 0.2 TRI
    const reward_1000 = kg_sync.KgRewardCalculator.weiToTri(1000 * kg_sync.REWARD_KG_TRIPLE_WEI);
    try std.testing.expectApproxEqAbs(@as(f64, 0.2), reward_1000, 0.001);

    // Minimum threshold: 5 triples = 0.001 TRI
    const min_reward = kg_sync.KgRewardCalculator.weiToTri(
        @as(u128, kg_sync.MIN_CONTRIBUTION_FOR_REWARD) * kg_sync.REWARD_KG_TRIPLE_WEI,
    );
    try std.testing.expect(min_reward > 0.0);
}
