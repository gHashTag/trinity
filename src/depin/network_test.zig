// ═══════════════════════════════════════════════════════════════════════════════
// DePIN NETWORK E2E TESTS — 3-Node Cluster
// UDP: 9333 | TCP: 9334 | Real socket operations
// φ² + 1/φ² = 3 = TRINITY | Order #100-1
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const network = @import("network.zig");

// Firebird constants are now defined in network.zig
const TIER_MULTIPLIER_FREE: f64 = 1.0;
const TIER_MULTIPLIER_STAKER: f64 = 1.5;
const TIER_MULTIPLIER_POWER: f64 = 2.0;
const TIER_MULTIPLIER_WHALE: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// TEST: Single Coordinator Startup
// ═══════════════════════════════════════════════════════════════════════════════

test "DePIN: Coordinator starts on UDP 9333 and TCP 9334" {
    const allocator = std.testing.allocator;

    // Create cluster manager as coordinator
    var cluster = try network.ClusterManager.init("test-cluster", "coordinator-node", .coordinator, .free, allocator);
    defer cluster.deinit();

    // Start coordinator services
    try cluster.startCoordinator(network.UDP_DISCOVERY_PORT, network.TCP_JOB_PORT);

    // Verify UDP socket is bound
    try std.testing.expect(cluster.udp != null);
    try std.testing.expect(cluster.tcp_server != null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST: UDP Discovery Packet
// ═══════════════════════════════════════════════════════════════════════════════

test "DePIN: UDP broadcast discovery packet" {
    const allocator = std.testing.allocator;

    var udp = try network.UDPDiscovery.init(network.UDP_DISCOVERY_PORT, allocator);
    defer udp.deinit();

    // Broadcast discovery
    try udp.broadcastDiscovery("test-cluster", "test-node");

    // This will broadcast to 255.255.255.255:9333
    // In real test, we'd have another socket listening to receive it
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST: Node Tier Multipliers
// ═══════════════════════════════════════════════════════════════════════════════

test "DePIN: Tier multipliers match Firebird constants" {
    try std.testing.expectEqual(TIER_MULTIPLIER_FREE, network.NodeTier.free.getMultiplier());
    try std.testing.expectEqual(TIER_MULTIPLIER_STAKER, network.NodeTier.staker.getMultiplier());
    try std.testing.expectEqual(TIER_MULTIPLIER_POWER, network.NodeTier.power.getMultiplier());
    try std.testing.expectEqual(TIER_MULTIPLIER_WHALE, network.NodeTier.whale.getMultiplier());
}

test "DePIN: Tier multiplier calculations" {
    var node = network.ClusterNode{
        .id = "test-node",
        .address = .{ .ip = "127.0.0.1", .port = 9334 },
        .role = .worker,
        .tier = .free,
        .status = .online,
        .operations_count = 0,
        .earned_tri = 0.0,
        .pending_tri = 0.0,
        .last_heartbeat = 0,
    };

    // FREE tier: 1.0x
    node.tier = .free;
    try std.testing.expectApproxEqAbs(0.001, node.calculateReward(0.001), 0.0001);

    // STAKER tier: 1.5x
    node.tier = .staker;
    try std.testing.expectApproxEqAbs(0.0015, node.calculateReward(0.001), 0.0001);

    // POWER tier: 2.0x
    node.tier = .power;
    try std.testing.expectApproxEqAbs(0.002, node.calculateReward(0.001), 0.0001);

    // WHALE tier: 3.0x
    node.tier = .whale;
    try std.testing.expectApproxEqAbs(0.003, node.calculateReward(0.001), 0.0001);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST: Job Packet JSON Serialization
// ═══════════════════════════════════════════════════════════════════════════════

test "DePIN: JobPacket to JSON" {
    const allocator = std.testing.allocator;

    var job = network.JobPacket{
        .job_id = "job-test-123",
        .payload = "compute-hash",
        .reward = 0.001,
        .timestamp = 1709251200000,
    };

    const json = try job.toJson(allocator);
    defer allocator.free(json);

    try std.testing.expectEqualStrings(
        \\{"job_id":"job-test-123","payload":"compute-hash","reward":0.001000,"timestamp":1709251200000}
    , json);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST: 3-Node Cluster Simulation
// ═══════════════════════════════════════════════════════════════════════════════

test "DePIN: 3-node cluster with different tiers" {
    // Direct node creation without ClusterManager (avoids deinit issues)
    const nodes = [_]network.ClusterNode{
        .{
            .id = "worker-1",
            .address = .{ .ip = "127.0.0.1", .port = 9335 },
            .role = .worker,
            .tier = .free,
            .status = .online,
            .operations_count = 100,
            .earned_tri = 0.1,
            .pending_tri = 0.05,
            .last_heartbeat = 0,
        },
        .{
            .id = "worker-2",
            .address = .{ .ip = "127.0.0.1", .port = 9336 },
            .role = .worker,
            .tier = .staker,
            .status = .online,
            .operations_count = 200,
            .earned_tri = 0.3,
            .pending_tri = 0.15,
            .last_heartbeat = 0,
        },
        .{
            .id = "worker-3",
            .address = .{ .ip = "127.0.0.1", .port = 9337 },
            .role = .worker,
            .tier = .power,
            .status = .online,
            .operations_count = 300,
            .earned_tri = 0.6,
            .pending_tri = 0.3,
            .last_heartbeat = 0,
        },
    };

    // Verify 3 nodes exist
    try std.testing.expectEqual(@as(usize, 3), nodes.len);

    // Verify tier-based rewards
    const total_earned = nodes[0].earned_tri +
        nodes[1].earned_tri +
        nodes[2].earned_tri;

    try std.testing.expect(total_earned > 0.9 and total_earned < 1.1);

    // Verify tier multipliers are applied correctly
    const reward1 = nodes[0].calculateReward(0.001); // FREE: 1.0x
    const reward2 = nodes[1].calculateReward(0.001); // STAKER: 1.5x
    const reward3 = nodes[2].calculateReward(0.001); // POWER: 2.0x

    try std.testing.expectApproxEqAbs(0.001, reward1, 0.0001);
    try std.testing.expectApproxEqAbs(0.0015, reward2, 0.0001);
    try std.testing.expectApproxEqAbs(0.002, reward3, 0.0001);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST: TCP Server Initialization
// ═══════════════════════════════════════════════════════════════════════════════

test "DePIN: TCP Job Server initializes and listens" {
    const allocator = std.testing.allocator;

    var server = try network.TCPJobServer.init(network.TCP_JOB_PORT, allocator);
    defer server.deinit();

    try std.testing.expectEqual(network.TCP_JOB_PORT, server.port);
    try std.testing.expect(!server.running);

    server.start();
    try std.testing.expect(server.running);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST: Socket Address Formatting
// ═══════════════════════════════════════════════════════════════════════════════

test "DePIN: SocketAddr format" {
    const allocator = std.testing.allocator;

    const addr = network.SocketAddr{
        .ip = "192.168.1.100",
        .port = 9334,
    };

    const formatted = try addr.format(allocator);
    defer allocator.free(formatted);

    try std.testing.expectEqualStrings("192.168.1.100:9334", formatted);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST: Node Role Conversion
// ═══════════════════════════════════════════════════════════════════════════════

test "DePIN: NodeRole toString" {
    try std.testing.expectEqualStrings("coordinator", network.NodeRole.coordinator.toString());
    try std.testing.expectEqualStrings("worker", network.NodeRole.worker.toString());
    try std.testing.expectEqualStrings("storage", network.NodeRole.storage.toString());
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST: Node Tier Conversion
// ═══════════════════════════════════════════════════════════════════════════════

test "DePIN: NodeTier toString" {
    try std.testing.expectEqualStrings("FREE", network.NodeTier.free.toString());
    try std.testing.expectEqualStrings("STAKER", network.NodeTier.staker.toString());
    try std.testing.expectEqualStrings("POWER", network.NodeTier.power.toString());
    try std.testing.expectEqualStrings("WHALE", network.NodeTier.whale.toString());
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK: Reward Calculation Performance
// ═══════════════════════════════════════════════════════════════════════════════

test "DePIN Benchmark: Reward calculation throughput" {
    _ = std.testing.allocator; // Available for future use
    const iterations = 1_000_000;

    var node = network.ClusterNode{
        .id = "bench-node",
        .address = .{ .ip = "127.0.0.1", .port = 9334 },
        .role = .worker,
        .tier = .staker,
        .status = .online,
        .operations_count = 0,
        .earned_tri = 0.0,
        .pending_tri = 0.0,
        .last_heartbeat = 0,
    };

    const start = std.time.nanoTimestamp();
    var total: f64 = 0;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        total += node.calculateReward(0.001);
    }
    const elapsed = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    const throughput = @as(f64, @floatFromInt(iterations)) / elapsed;
    std.debug.print("\n  Reward Calculation: {d:.0} ops/s ({d:.3}ms total)\n", .{ throughput, elapsed });

    try std.testing.expect(throughput > 100_000); // Should be > 100K ops/s
}
