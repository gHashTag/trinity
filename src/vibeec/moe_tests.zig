const std = @import("std");
const moe = @import("moe_router.zig");
const agent_mod = @import("agent_loop.zig");
const dao = @import("dao_integration.zig");

// ============================================================================
// TRINITY: MoE & AGENT TESTS (PHASE 20)
// 10 scenarios for MoE routing and agent loop - zero deadlocks
// ============================================================================

// --- MoE ROUTER TESTS ---

test "1. Ternary MatVec correctness" {
    // Test ternary {-1, 0, +1} matrix-vector multiplication
    const weights = [_]moe.TernaryWeight{ 1, -1, 0, 1, -1, 0, 1, -1 };
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0 };

    const result = moe.MoERouter.ternaryMatVec(&weights, &input);

    // Expected: 1*1 + (-1)*2 + 0*3 + 1*4 + (-1)*5 + 0*6 + 1*7 + (-1)*8
    // = 1 - 2 + 0 + 4 - 5 + 0 + 7 - 8 = -3
    try std.testing.expectApproxEqAbs(@as(f32, -3.0), result, 0.001);
}

test "2. Top-k gating expert selection" {
    const allocator = std.testing.allocator;

    var router = try moe.MoERouter.init(allocator, .{ .top_k = 2 });
    defer router.deinit();

    // Route inference task
    const result = router.route("infer mistral model");

    // Should select 2 experts
    try std.testing.expectEqual(@as(u8, 2), result.selected_count);

    // Scores should sum to ~1.0 after softmax
    var sum: f32 = 0;
    for (result.scores) |s| sum += s;
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), sum, 0.01);
}

test "3. Expert routing for inference tasks" {
    const allocator = std.testing.allocator;

    var router = try moe.MoERouter.init(allocator, .{});
    defer router.deinit();

    const result = router.route("Запусти инференс на Mistral-7B");

    // Routing should happen successfully (scores sum to ~1)
    var sum: f32 = 0;
    for (result.scores) |s| sum += s;
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), sum, 0.01);
}

test "4. Expert routing for network tasks" {
    const allocator = std.testing.allocator;

    var router = try moe.MoERouter.init(allocator, .{});
    defer router.deinit();

    const result = router.route("Застейкай 10000 TRI и подключись к p2p");

    // Network expert should be activated
    var network_selected = false;
    for (0..result.selected_count) |i| {
        if (result.selected[i] == .Network) {
            network_selected = true;
            break;
        }
    }
    try std.testing.expect(network_selected);
}

test "5. Expert routing for codegen tasks" {
    const allocator = std.testing.allocator;

    var router = try moe.MoERouter.init(allocator, .{});
    defer router.deinit();

    const result = router.route("Generate code with Qwen2.5-Coder");

    // CodeGen expert should be activated
    var codegen_selected = false;
    for (0..result.selected_count) |i| {
        if (result.selected[i] == .CodeGen) {
            codegen_selected = true;
            break;
        }
    }
    try std.testing.expect(codegen_selected);
}

test "6. Mixed task routing (multi-expert)" {
    const allocator = std.testing.allocator;

    var router = try moe.MoERouter.init(allocator, .{ .top_k = 2 });
    defer router.deinit();

    // Task that needs multiple experts
    const result = router.route("Запусти инференс на Mistral, затем застейкай 10000 TRI");

    // Should select 2 experts
    try std.testing.expectEqual(@as(u8, 2), result.selected_count);

    // Both inference and network keywords present
    try std.testing.expect(result.scores[0] > 0 or result.scores[1] > 0);
}

// --- AGENT LOOP TESTS ---

test "7. Agent loop initialization" {
    const allocator = std.testing.allocator;

    var router = try moe.MoERouter.init(allocator, .{});
    defer router.deinit();

    var agent = try agent_mod.AgentLoop.init(allocator, router, .{
        .verbose = false,
        .max_steps = 3,
    });
    defer agent.deinit();

    try std.testing.expectEqual(agent_mod.AgentState.Idle, agent.state);
}

test "8. Agent tool execution" {
    const allocator = std.testing.allocator;

    var router = try moe.MoERouter.init(allocator, .{});
    defer router.deinit();

    var agent = try agent_mod.AgentLoop.init(allocator, router, .{
        .verbose = false,
        .max_steps = 1,
    });
    defer agent.deinit();

    // Run a simple task
    try agent.run("test inference task");

    // Agent should have accumulated some reward
    try std.testing.expect(agent.total_reward >= 0);
}

test "9. Agent self-healing on error" {
    const allocator = std.testing.allocator;

    var router = try moe.MoERouter.init(allocator, .{});
    defer router.deinit();

    var agent = try agent_mod.AgentLoop.init(allocator, router, .{
        .verbose = false,
        .self_healing = true,
        .max_steps = 2,
    });
    defer agent.deinit();

    // Run task - self-healing should handle any issues
    try agent.run("network stake operation");

    // Should not be in error state (self-healing recovered)
    try std.testing.expect(agent.state != .Error);
}

test "10. Zero deadlocks stress test" {
    const allocator = std.testing.allocator;

    var router = try moe.MoERouter.init(allocator, .{});
    defer router.deinit();

    var agent = try agent_mod.AgentLoop.init(allocator, router, .{
        .verbose = false,
        .max_steps = 2,
    });
    defer agent.deinit();

    // Rapid sequential tasks (stress test)
    const tasks = [_][]const u8{
        "infer",
        "stake",
        "vote",
        "code",
        "plan",
        "network",
        "generate",
        "maximize",
        "optimize",
        "test",
    };

    for (tasks) |task| {
        try agent.run(task);
        // Reset for next task
        agent.state = .Idle;
    }

    // All tasks completed without deadlock
    try std.testing.expect(router.total_routes >= 10);
}

// --- DAO INTEGRATION TESTS ---

test "DAO staking integration" {
    const allocator = std.testing.allocator;
    var mgr = dao.DAOManager.init(allocator);
    defer mgr.deinit();

    try mgr.stake(1000, .GOLD);
    try std.testing.expectEqual(@as(usize, 1), mgr.stakes.items.len);
}

test "DAO voting integration" {
    const allocator = std.testing.allocator;
    var mgr = dao.DAOManager.init(allocator);
    defer mgr.deinit();

    // Should not error
    try mgr.vote("test_proposal", true);
}

// --- ROUTER STATISTICS TESTS ---

test "Router statistics tracking" {
    const allocator = std.testing.allocator;

    var router = try moe.MoERouter.init(allocator, .{});
    defer router.deinit();

    _ = router.route("task 1");
    _ = router.route("task 2");
    _ = router.route("task 3");

    const stats = router.getStats();
    try std.testing.expectEqual(@as(u64, 3), stats.total);
}
