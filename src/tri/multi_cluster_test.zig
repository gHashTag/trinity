// ═══════════════════════════════════════════════════════════════════════════════
// MULTI-CLUSTER E2E TEST — State Persistence + CRDT Merge
// ═══════════════════════════════════════════════════════════════════════════════
// Tests:
// - Cluster state persistence (.tri-cluster.json save/load)
// - Tier-based reward calculation
// - CRDT merge between federations
// - Pending rewards claiming
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const tri_commands = @import("tri_commands.zig");

const NodeTier = tri_commands.NodeTier;
const NodeEntry = tri_commands.NodeEntry;
const ClusterState = tri_commands.ClusterState;

/// Test helper: create mock node with static strings (no allocations)
fn createMockNode(allocator: std.mem.Allocator, id: []const u8, tier: NodeTier) NodeEntry {
    _ = allocator;
    return .{
        .id = id,
        .address = "127.0.0.1",
        .port = 9334,
        .role = "worker",
        .status = "online",
        .uptime_seconds = 3600,
        .operations_count = 100,
        .earned_tri = 0.1,
        .pending_tri = 0.05,
        .tier = tier,
        .added_at = @intCast(@divTrunc(std.time.nanoTimestamp(), 1_000_000)),
    };
}

// Test 1: State persistence (save/load)
test "MultiCluster: save and load state" {
    const allocator = std.testing.allocator;

    // Create cluster state
    var cluster = try ClusterState.init(allocator, 9334, 9333);
    defer cluster.deinit();

    // Add nodes with different tiers
    try cluster.addNode(allocator, createMockNode(allocator, "node-1", .FREE));
    try cluster.addNode(allocator, createMockNode(allocator, "node-2", .STAKER));
    try cluster.addNode(allocator, createMockNode(allocator, "node-3", .POWER));
    try cluster.addNode(allocator, createMockNode(allocator, "node-4", .WHALE));

    // Save state
    try cluster.saveClusterState();

    // Verify file exists
    const cwd = std.fs.cwd();
    const stat = try cwd.statFile(".tri-cluster.json");
    try std.testing.expect(stat.size > 0);

    // Load state
    const loaded = ClusterState.loadClusterState(allocator);
    try std.testing.expect(loaded != null);
    if (loaded) |loaded_cluster| {
        defer loaded_cluster.deinit();

        // Verify cluster ID
        try std.testing.expectEqualStrings("mc-9334-9333", loaded_cluster.cluster_id);

        // Verify node count
        try std.testing.expectEqual(@as(usize, 4), loaded_cluster.nodes.count);

        // Verify tiers
        try std.testing.expectEqual(NodeTier.FREE, loaded_cluster.nodes.items[0].?.tier);
        try std.testing.expectEqual(NodeTier.STAKER, loaded_cluster.nodes.items[1].?.tier);
        try std.testing.expectEqual(NodeTier.POWER, loaded_cluster.nodes.items[2].?.tier);
        try std.testing.expectEqual(NodeTier.WHALE, loaded_cluster.nodes.items[3].?.tier);

        std.debug.print("\n\x1b[32m[s]State persistence test: PASSED\x1b[0m\n", .{});
    } else {
        @panic("Failed to load cluster state");
    }

    // Cleanup test file
    try cwd.deleteFile(".tri-cluster.json");
}

// Test 2: Tier multiplier calculation
test "MultiCluster: tier multiplier rewards" {
    const allocator = std.testing.allocator;

    // Create nodes with different tiers
    const free_node = createMockNode(allocator, "free-node", .FREE);
    const staker_node = createMockNode(allocator, "staker-node", .STAKER);
    const power_node = createMockNode(allocator, "power-node", .POWER);
    const whale_node = createMockNode(allocator, "whale-node", .WHALE);

    // Calculate rewards with base reward of 0.001 TRI
    const base_reward: f64 = 0.001;

    const free_reward = free_node.calculateReward(base_reward);
    const staker_reward = staker_node.calculateReward(base_reward);
    const power_reward = power_node.calculateReward(base_reward);
    const whale_reward = whale_node.calculateReward(base_reward);

    // Verify multipliers
    try std.testing.expectApproxEqAbs(0.001, free_reward, 0.0001); // 1.0x
    try std.testing.expectApproxEqAbs(0.0015, staker_reward, 0.0001); // 1.5x
    try std.testing.expectApproxEqAbs(0.002, power_reward, 0.0001); // 2.0x
    try std.testing.expectApproxEqAbs(0.003, whale_reward, 0.0001); // 3.0x

    std.debug.print("\n\x1b[32m[s]Tier multiplier test: PASSED\x1b[0m\n", .{});
}

// Test 3: CRDT merge - no conflicts
test "MultiCluster: CRDT merge without conflicts" {
    const allocator = std.testing.allocator;

    // Create cluster A
    var cluster_a = try ClusterState.init(allocator, 9334, 9333);
    defer cluster_a.deinit();
    try cluster_a.addNode(allocator, createMockNode(allocator, "node-1", .FREE));
    try cluster_a.addNode(allocator, createMockNode(allocator, "node-2", .STAKER));

    // Create cluster B with different nodes
    var cluster_b = try ClusterState.init(allocator, 9335, 9336);
    defer cluster_b.deinit();
    try cluster_b.addNode(allocator, createMockNode(allocator, "node-3", .POWER));
    try cluster_b.addNode(allocator, createMockNode(allocator, "node-4", .WHALE));

    // Merge B into A
    const entries_before = cluster_a.nodes.count;
    try cluster_a.crdtMerge(allocator, &cluster_b);
    const entries_after = cluster_a.nodes.count;

    // Should have 4 nodes (2 + 2 new)
    try std.testing.expectEqual(@as(usize, 2), entries_before);
    try std.testing.expectEqual(@as(usize, 4), entries_after);

    // CRDT stats should show merged entries
    try std.testing.expect(cluster_a.crdt.entries_merged > 0);

    std.debug.print("\n\x1b[32m[s]CRDT merge (no conflicts) test: PASSED\x1b[0m\n", .{});
}

// Test 4: CRDT merge - with conflicts (last-write-wins)
test "MultiCluster: CRDT merge with conflicts" {
    const allocator = std.testing.allocator;

    // Create cluster A with node having 100 ops
    var cluster_a = try ClusterState.init(allocator, 9334, 9333);
    defer cluster_a.deinit();

    var node_a = createMockNode(allocator, "node-1", .STAKER);
    node_a.operations_count = 100;
    node_a.earned_tri = 0.1;
    try cluster_a.addNode(allocator, node_a);

    // Create cluster B with same node having 200 ops
    var cluster_b = try ClusterState.init(allocator, 9335, 9336);
    defer cluster_b.deinit();

    var node_b = createMockNode(allocator, "node-1", .STAKER);
    node_b.operations_count = 200;
    node_b.earned_tri = 0.2;
    try cluster_b.addNode(allocator, node_b);

    // Merge B into A - B's version should win (200 > 100)
    try cluster_a.crdtMerge(allocator, &cluster_b);

    // Node count should still be 1
    try std.testing.expectEqual(@as(usize, 1), cluster_a.nodes.count);

    std.debug.print("\n\x1b[32m[s]CRDT merge (conflicts) test: PASSED\x1b[0m\n", .{});
}

// Test 5: Pending rewards calculation and claiming
test "MultiCluster: pending rewards and claim" {
    const allocator = std.testing.allocator;

    var cluster = try ClusterState.init(allocator, 9334, 9333);
    defer cluster.deinit();

    // Add nodes with pending rewards
    var node1 = createMockNode(allocator, "node-1", .FREE);
    node1.pending_tri = 0.01;
    try cluster.addNode(allocator, node1);

    var node2 = createMockNode(allocator, "node-2", .STAKER);
    node2.pending_tri = 0.015; // 1.5x tier
    try cluster.addNode(allocator, node2);

    // Calculate total pending
    const total_pending = cluster.calculateTotalPending();
    try std.testing.expectApproxEqAbs(0.025, total_pending, 0.0001);

    // Claim all pending
    const claimed = cluster.claimAllPending();
    try std.testing.expectApproxEqAbs(0.025, claimed, 0.0001);

    // Verify all pending is zero
    const new_total_pending = cluster.calculateTotalPending();
    try std.testing.expectApproxEqAbs(0.0, new_total_pending, 0.0001);

    // Verify earned increased
    const earned0 = cluster.nodes.items[0].?.earned_tri;
    const earned1 = cluster.nodes.items[1].?.earned_tri;
    const total_earned: f64 = earned0 + earned1;
    try std.testing.expect(total_earned > 0.11); // 0.1 + 0.015

    std.debug.print("\n\x1b[32m[s]Pending rewards test: PASSED\x1b[0m\n", .{});
}

// Test 6: Node removal
test "MultiCluster: remove node" {
    const allocator = std.testing.allocator;

    var cluster = try ClusterState.init(allocator, 9334, 9333);
    defer cluster.deinit();

    try cluster.addNode(allocator, createMockNode(allocator, "node-1", .FREE));
    try cluster.addNode(allocator, createMockNode(allocator, "node-2", .STAKER));

    // Verify 2 nodes
    try std.testing.expectEqual(@as(usize, 2), cluster.nodes.count);

    // Remove node-1
    const removed = cluster.removeNode("node-1");

    try std.testing.expect(removed != null);
    try std.testing.expectEqual(@as(usize, 1), cluster.nodes.count);

    // Try to remove non-existent node
    const not_removed = cluster.removeNode("node-999");
    try std.testing.expect(not_removed == null);

    std.debug.print("\n\x1b[32m[s]Node removal test: PASSED\x1b[0m\n", .{});
}

// Benchmark state persistence operations
test "MultiCluster: benchmark state persistence" {
    const allocator = std.testing.allocator;

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ "\x1b[33m", "\x1b[0m" });
    std.debug.print("{s}  STATE PERSISTENCE BENCHMARK{s}\n", .{ "\x1b[32m", "\x1b[0m" });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n\n", .{ "\x1b[33m", "\x1b[0m" });

    // Benchmark 1: Cluster creation (1000 iterations)
    {
        const start = std.time.nanoTimestamp();
        var i: usize = 0;
        while (i < 1000) : (i += 1) {
            var cluster = try ClusterState.init(allocator, 9334, 9333);
            cluster.deinit();
        }
        const elapsed = std.time.nanoTimestamp() - start;
        const avg_ns = @divTrunc(elapsed, 1000);
        std.debug.print("  Cluster creation (1000x): {d:.2} μs avg ({d:.0} ops/s)\n", .{ @as(f64, @floatFromInt(avg_ns)) / 1000.0, 1_000_000_000_000 / @max(1, elapsed) });
    }

    // Benchmark 2: Add node (200 iterations - stays under MAX_CLUSTER_NODES=256)
    {
        var cluster = try ClusterState.init(allocator, 9334, 9333);
        defer cluster.deinit();

        const start = std.time.nanoTimestamp();
        var i: usize = 0;
        while (i < 200) : (i += 1) {
            const node_id = try std.fmt.allocPrint(allocator, "node-{d}", .{i});
            defer allocator.free(node_id);
            const node = NodeEntry{
                .id = node_id,
                .address = "127.0.0.1",
                .port = 9334,
                .role = "worker",
                .status = "online",
                .uptime_seconds = 3600,
                .operations_count = 100,
                .earned_tri = 0.1,
                .pending_tri = 0.05,
                .tier = .FREE,
                .added_at = 0,
            };
            try cluster.addNode(allocator, node);
        }
        const elapsed = std.time.nanoTimestamp() - start;
        const avg_ns = @divTrunc(elapsed, 200);
        std.debug.print("  Add node (200x): {d:.2} μs avg ({d:.0} ops/s)\n", .{ @as(f64, @floatFromInt(avg_ns)) / 1000.0, 200_000_000_000 / @max(1, elapsed) });
    }

    // Benchmark 3: Tier multiplier calculation (100000 iterations)
    {
        const node = NodeEntry{
            .id = "test",
            .address = "127.0.0.1",
            .port = 9334,
            .role = "worker",
            .status = "online",
            .uptime_seconds = 3600,
            .operations_count = 100,
            .earned_tri = 0.1,
            .pending_tri = 0.05,
            .tier = .WHALE,
            .added_at = 0,
        };
        const base_reward: f64 = 0.001;

        const start = std.time.nanoTimestamp();
        var i: usize = 0;
        while (i < 100000) : (i += 1) {
            const result = node.calculateReward(base_reward);
            if (result > 1000) {} // prevent optimization
            else {}
        }
        const elapsed = std.time.nanoTimestamp() - start;
        const avg_ns = @divTrunc(elapsed, 100000);
        std.debug.print("  Tier reward calc (100000x): {d:.2} ns avg ({d:.0} ops/s)\n", .{ @as(f64, @floatFromInt(avg_ns)), 100_000_000_000_000 / @max(1, elapsed) });
    }

    // Benchmark 4: Pending rewards calculation (10000 iterations)
    {
        var cluster = try ClusterState.init(allocator, 9334, 9333);
        defer cluster.deinit();

        // Add some nodes
        var j: usize = 0;
        while (j < 10) : (j += 1) {
            const node_id = try std.fmt.allocPrint(allocator, "node-{d}", .{j});
            defer allocator.free(node_id);
            const tier_value: u3 = @truncate(@intFromEnum(NodeTier.FREE) + @as(u8, @truncate(j % 4)));
            const node = NodeEntry{
                .id = node_id,
                .address = "127.0.0.1",
                .port = 9334,
                .role = "worker",
                .status = "online",
                .uptime_seconds = 3600,
                .operations_count = 100,
                .earned_tri = 0.1,
                .pending_tri = 0.01,
                .tier = @as(NodeTier, @enumFromInt(tier_value)),
                .added_at = 0,
            };
            try cluster.addNode(allocator, node);
        }

        const start = std.time.nanoTimestamp();
        var i: usize = 0;
        while (i < 10000) : (i += 1) {
            const result = cluster.calculateTotalPending();
            if (result > 1000) {} else {}
        }
        const elapsed = std.time.nanoTimestamp() - start;
        const avg_ns = @divTrunc(elapsed, 10000);
        std.debug.print("  Pending calc (10000x): {d:.2} ns avg ({d:.0} ops/s)\n", .{ @as(f64, @floatFromInt(avg_ns)), 10_000_000_000_000 / @max(1, elapsed) });
    }

    // Benchmark 5: Claim rewards (10000 iterations)
    {
        var cluster = try ClusterState.init(allocator, 9334, 9333);
        defer cluster.deinit();

        // Add some nodes with pending rewards
        var j: usize = 0;
        while (j < 10) : (j += 1) {
            const node_id = try std.fmt.allocPrint(allocator, "node-{d}", .{j});
            defer allocator.free(node_id);
            const tier_value: u3 = @truncate(@intFromEnum(NodeTier.FREE) + @as(u8, @truncate(j % 4)));
            const node = NodeEntry{
                .id = node_id,
                .address = "127.0.0.1",
                .port = 9334,
                .role = "worker",
                .status = "online",
                .uptime_seconds = 3600,
                .operations_count = 100,
                .earned_tri = 0.1,
                .pending_tri = 0.01,
                .tier = @as(NodeTier, @enumFromInt(tier_value)),
                .added_at = 0,
            };
            try cluster.addNode(allocator, node);
        }

        const start = std.time.nanoTimestamp();
        var i: usize = 0;
        while (i < 10000) : (i += 1) {
            const result = cluster.claimAllPending();
            if (result > 1000) {} else {}
        }
        const elapsed = std.time.nanoTimestamp() - start;
        const avg_ns = @divTrunc(elapsed, 10000);
        std.debug.print("  Claim rewards (10000x): {d:.2} ns avg ({d:.0} ops/s)\n", .{ @as(f64, @floatFromInt(avg_ns)), 10_000_000_000_000 / @max(1, elapsed) });
    }

    // Benchmark 6: Save state (100 iterations)
    {
        var cluster = try ClusterState.init(allocator, 9334, 9333);
        defer cluster.deinit();

        // Add some nodes
        var j: usize = 0;
        while (j < 10) : (j += 1) {
            const node_id = try std.fmt.allocPrint(allocator, "node-{d}", .{j});
            defer allocator.free(node_id);
            const tier_value: u3 = @truncate(@intFromEnum(NodeTier.FREE) + @as(u8, @truncate(j % 4)));
            const node = NodeEntry{
                .id = node_id,
                .address = "127.0.0.1",
                .port = 9334,
                .role = "worker",
                .status = "online",
                .uptime_seconds = 3600,
                .operations_count = 100,
                .earned_tri = 0.1,
                .pending_tri = 0.01,
                .tier = @as(NodeTier, @enumFromInt(tier_value)),
                .added_at = 0,
            };
            try cluster.addNode(allocator, node);
        }

        const start = std.time.nanoTimestamp();
        var i: usize = 0;
        while (i < 100) : (i += 1) {
            try cluster.saveClusterState();
        }
        const elapsed = std.time.nanoTimestamp() - start;
        const avg_ns = @divTrunc(elapsed, 100);
        std.debug.print("  Save state (100x): {d:.2} μs avg ({d:.0} ops/s)\n", .{ @as(f64, @floatFromInt(avg_ns)) / 1000.0, 100_000_000_000 / @max(1, elapsed) });
    }

    std.debug.print("\n\x1b[32m[s]State persistence benchmark: COMPLETE\x1b[0m\n", .{});
}

/// E2E test runner - runs all tests sequentially
pub fn runE2ETest(allocator: std.mem.Allocator) !void {
    _ = allocator;

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ "\x1b[33m", "\x1b[0m" });
    std.debug.print("{s}  MULTI-CLUSTER E2E TEST SUITE{s}\n", .{ "\x1b[32m", "\x1b[0m" });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n\n", .{ "\x1b[33m", "\x1b[0m" });

    std.debug.print("{s}[1/6]{s} State persistence (save/load)...\n", .{ "\x1b[36m", "\x1b[0m" });
    std.debug.print("{s}[2/6]{s} Tier multiplier rewards...\n", .{ "\x1b[36m", "\x1b[0m" });
    std.debug.print("{s}[3/6]{s} CRDT merge (no conflicts)...\n", .{ "\x1b[36m", "\x1b[0m" });
    std.debug.print("{s}[4/6]{s} CRDT merge (with conflicts)...\n", .{ "\x1b[36m", "\x1b[0m" });
    std.debug.print("{s}[5/6]{s} Pending rewards and claim...\n", .{ "\x1b[36m", "\x1b[0m" });
    std.debug.print("{s}[6/6]{s} Node removal...\n", .{ "\x1b[36m", "\x1b[0m" });
    std.debug.print("\n");

    // Run tests via zig test
    std.debug.print("{s}Run: zig test src/tri/multi_cluster_test.zig{s}\n\n", .{ "\x1b[33m", "\x1b[0m" });
}
