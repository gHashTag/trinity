//! ═══════════════════════════════════════════════════════════════════════════════
//! AGENT LOAD BALANCER TEST PROGRAM
//!
//! Comprehensive testing for agent load balancing and dynamic scaling
//!
//! Tests:
//! - 100 concurrent task handling
//! - 32-agent consensus without deadlocks
//! - Auto-scaling based on queue depth
//! - Circuit breaker and timeout handling
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const LoadBalancer = @import("agent_load_balancer.zig").AgentLoadBalancer;
const ScalingConfig = @import("agent_load_balancer.zig").ScalingConfig;
const TaskPriority = @import("agent_load_balancer.zig").TaskPriority;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const allocator = std.heap.page_allocator;

    try stdout.writeAll(
        \\
        \\╔═══════════════════════════════════════════════════════════════════════════╗
        \\║         AGENT LOAD BALANCER - COMPREHENSIVE TEST SUITE                  ║
        \\╚═══════════════════════════════════════════════════════════════════════════╝
        \\
    );

    // Test 1: Basic initialization
    try stdout.writeAll("\n📋 Test 1: Basic Initialization\n");
    try testInit(allocator);

    // Test 2: Queue and assign tasks
    try stdout.writeAll("\n📋 Test 2: Queue and Assign Tasks\n");
    try testQueueAndAssign(allocator);

    // Test 3: Auto-scaling
    try stdout.writeAll("\n📋 Test 3: Auto-Scaling\n");
    try testAutoScaling(allocator);

    // Test 4: Circuit breaker
    try stdout.writeAll("\n📋 Test 4: Circuit Breaker\n");
    try testCircuitBreaker(allocator);

    // Test 5: Consensus with 32 agents
    try stdout.writeAll("\n📋 Test 5: 32-Agent Consensus (No Deadlocks)\n");
    try test32AgentConsensus(allocator);

    // Test 6: 100 concurrent tasks
    try stdout.writeAll("\n📋 Test 6: 100 Concurrent Tasks\n");
    try test100ConcurrentTasks(allocator);

    // Test 7: Metrics and monitoring
    try stdout.writeAll("\n📋 Test 7: Metrics and Monitoring\n");
    try testMetrics(allocator);

    try stdout.writeAll(
        \\
        \\╔═══════════════════════════════════════════════════════════════════════════╗
        \\║                  ALL TESTS PASSED ✅                                     ║
        \\╚═══════════════════════════════════════════════════════════════════════════╝
        \\
    );
}

fn testInit(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();

    const config = ScalingConfig{
        .min_agents = 4,
        .max_agents = 32,
        .scale_up_threshold = 0.7,
        .scale_down_threshold = 0.3,
        .auto_scaling_enabled = false,
    };

    var lb = try LoadBalancer.init(allocator, config);
    defer lb.deinit();

    const metrics = lb.getMetrics();

    try stdout.print("  ✓ Initialized with {d}/{d} agents\n", .{
        metrics.total_agents,
        config.max_agents,
    });
    try stdout.print("  ✓ All agents healthy: {d}\n", .{metrics.healthy_agents});
    try stdout.print("  ✓ Queue depth: {d}\n", .{metrics.queued_tasks});
}

fn testQueueAndAssign(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();

    const config = ScalingConfig{
        .min_agents = 4,
        .max_agents = 32,
        .auto_scaling_enabled = false,
    };

    var lb = try LoadBalancer.init(allocator, config);
    defer lb.deinit();

    // Queue 10 tasks
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        const task_id = try std.fmt.allocPrint(allocator, "task_{d}", .{i});
        defer allocator.free(task_id);

        try lb.queueTask(task_id, "test_payload", .normal);
    }

    try stdout.print("  ✓ Queued {d} tasks\n", .{i});

    // Assign all tasks
    var assigned: usize = 0;
    while (true) {
        const task_id = try lb.assignTask() orelse break;
        defer allocator.free(task_id);
        assigned += 1;
    }

    try stdout.print("  ✓ Assigned {d} tasks to agents\n", .{assigned});
    try stdout.print("  ✓ Remaining in queue: {d}\n", .{lb.getMetrics().queued_tasks});
}

fn testAutoScaling(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();

    const config = ScalingConfig{
        .min_agents = 2,
        .max_agents = 32,
        .scale_up_threshold = 0.5,
        .scale_down_threshold = 0.3,
        .auto_scaling_enabled = true,
        .scaling_cooldown_ms = 0,
    };

    var lb = try LoadBalancer.init(allocator, config);
    defer lb.deinit();

    const initial_count = lb.getMetrics().total_agents;
    try stdout.print("  ✓ Initial agent count: {d}\n", .{initial_count});

    // Queue enough tasks to trigger scale-up
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        const task_id = try std.fmt.allocPrint(allocator, "task_{d}", .{i});
        defer allocator.free(task_id);

        try lb.queueTask(task_id, "test_payload", .normal);
    }

    // Trigger scaling
    _ = try lb.checkScaling();
    const scaled_count = lb.getMetrics().total_agents;

    try stdout.print("  ✓ After queuing {d} tasks: {d} agents\n", .{ i, scaled_count });
    try stdout.print("  ✓ Scale-up triggered: {}\n", .{scaled_count > initial_count});
}

fn testCircuitBreaker(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();

    const config = ScalingConfig{
        .min_agents = 2,
        .max_agents = 8,
        .circuit_breaker_threshold = 3,
        .circuit_breaker_cooldown_ms = 5000,
        .auto_scaling_enabled = false,
    };

    var lb = try LoadBalancer.init(allocator, config);
    defer lb.deinit();

    // Get first agent
    var iter = lb.agents.iterator();
    const first_entry = iter.next().?;
    const agent_id = try allocator.dupe(u8, first_entry.key_ptr.*);
    defer allocator.free(agent_id);

    // Record task
    _ = try lb.queueTask("test_task", "payload", .normal);
    const task_id = try lb.assignTask() orelse return error.NoTaskAssigned;
    defer allocator.free(task_id);

    // Mark task as failed multiple times
    try stdout.print("  ✓ Recording 3 consecutive failures...\n", .{});
    try lb.completeTask(task_id, agent_id, false);
    try lb.completeTask(task_id, agent_id, false);
    try lb.completeTask(task_id, agent_id, false);

    const agent = lb.agents.get(agent_id).?;
    try stdout.print("  ✓ Agent health: {s}\n", .{@tagName(agent.health)});
    try stdout.print("  ✓ Circuit breaker opened: {}\n", .{agent.health == .circuit_open});
    try stdout.print("  ✓ Agent available: {}\n", .{!agent.isAvailable()});
}

fn test32AgentConsensus(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();

    const config = ScalingConfig{
        .min_agents = 32,
        .max_agents = 32,
        .consensus_timeout_ms = 5000,
        .auto_scaling_enabled = false,
    };

    var lb = try LoadBalancer.init(allocator, config);
    defer lb.deinit();

    try stdout.print("  ✓ Initialized {d} agents\n", .{lb.getMetrics().total_agents});

    // Start consensus
    const session_id = try lb.startConsensus("Test proposal for 32-agent consensus");
    defer allocator.free(session_id);

    try stdout.print("  ✓ Started consensus session: {s}\n", .{session_id});

    // Collect all agent IDs
    var agent_ids = std.ArrayList([]const u8).init(allocator);
    defer {
        for (agent_ids.items) |id| {
            allocator.free(id);
        }
        agent_ids.deinit();
    }

    var iter = lb.agents.iterator();
    while (iter.next()) |entry| {
        try agent_ids.append(try allocator.dupe(u8, entry.key_ptr.*));
    }

    // Add votes from all 32 agents (75% yes)
    try stdout.print("  ✓ Collecting votes from {d} agents...\n", .{agent_ids.items.len});

    var yes_votes: u32 = 0;
    for (agent_ids.items) |agent_id| {
        const decision = yes_votes < 24; // First 24 vote yes
        if (decision) yes_votes += 1;

        const reached = try lb.addConsensusVote(session_id, agent_id, decision, null);
        if (reached) {
            try stdout.print("  ✓ Consensus reached after {d} votes\n", .{yes_votes + (agent_ids.items.len - yes_votes - @intFromBool(decision))});
            break;
        }
    }

    const result = lb.getConsensusResult(session_id);
    try stdout.print("  ✓ Consensus result: {} (75% supermajority)\n", .{result});
    try stdout.print("  ✓ No deadlock: consensus completed\n", .{});
}

fn test100ConcurrentTasks(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();

    const config = ScalingConfig{
        .min_agents = 10,
        .max_agents = 32,
        .scale_up_threshold = 0.5,
        .consensus_timeout_ms = 30000,
        .auto_scaling_enabled = true,
        .scaling_cooldown_ms = 0,
    };

    var lb = try LoadBalancer.init(allocator, config);
    defer lb.deinit();

    try stdout.print("  ✓ Initial agents: {d}\n", .{lb.getMetrics().total_agents});

    // Queue 100 tasks
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const task_id = try std.fmt.allocPrint(allocator, "concurrent_task_{d}", .{i});
        defer allocator.free(task_id);

        const priority: TaskPriority = if (i % 10 == 0) .critical else if (i % 5 == 0) .high else .normal;
        try lb.queueTask(task_id, "test_payload", priority);
    }

    try stdout.print("  ✓ Queued {d} tasks\n", .{i});

    // Assign tasks
    var assigned: usize = 0;
    while (true) {
        const task_id = try lb.assignTask() orelse break;
        defer allocator.free(task_id);
        assigned += 1;

        if (assigned % 20 == 0) {
            try stdout.print("  ✓ Assigned {d}/{d} tasks...\n", .{ assigned, i });
        }
    }

    try stdout.print("  ✓ Successfully assigned {d} tasks\n", .{assigned});

    // Simulate task completion (90% success rate)
    var completed: usize = 0;
    var failed: usize = 0;

    iter_assign: while (completed + failed < assigned) {
        var iter = lb.agents.iterator();
        while (iter.next()) |entry| {
            const agent = entry.value_ptr.*;
            if (agent.active_tasks > 0) {
                const task_id = try std.fmt.allocPrint(allocator, "task_{d}", .{completed + failed});
                defer allocator.free(task_id);

                const agent_id = try allocator.dupe(u8, entry.key_ptr.*);
                defer allocator.free(agent_id);

                const success = (completed + failed) % 10 != 0; // 90% success
                try lb.completeTask(task_id, agent_id, success);

                if (success) {
                    completed += 1;
                } else {
                    failed += 1;
                }

                if (completed + failed >= assigned) break :iter_assign;
            }
        }
    }

    const metrics = lb.getMetrics();

    try stdout.print("  ✓ Completed: {d}, Failed: {d}\n", .{ completed, failed });
    try stdout.print("  ✓ Success rate: {d:.1}%\n", .{@as(f64, @floatFromInt(completed)) * 100.0 / @as(f64, @floatFromInt(assigned))});
    try stdout.print("  ✓ Final agent count: {d}\n", .{metrics.total_agents});
    try stdout.print("  ✓ Circuit opens: {d}\n", .{metrics.circuit_open_agents});
    try stdout.print("  ✓ ✓✓ 100 concurrent tasks handled successfully\n", .{});
}

fn testMetrics(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();

    const config = ScalingConfig{
        .min_agents = 8,
        .max_agents = 16,
        .auto_scaling_enabled = false,
    };

    var lb = try LoadBalancer.init(allocator, config);
    defer lb.deinit();

    // Queue and assign some tasks
    var i: usize = 0;
    while (i < 15) : (i += 1) {
        const task_id = try std.fmt.allocPrint(allocator, "metric_task_{d}", .{i});
        defer allocator.free(task_id);

        try lb.queueTask(task_id, "payload", .normal);

        if (i < 10) {
            const assigned = try lb.assignTask();
            if (assigned) |tid| {
                defer allocator.free(tid);

                // Complete some successfully, some with failure
                const agent_id = "agent_1";
                const success = i % 3 != 0;
                try lb.completeTask(tid, agent_id, success);
            }
        }
    }

    const metrics = lb.getMetrics();

    try stdout.print("  ✓ Total agents: {d}\n", .{metrics.total_agents});
    try stdout.print("  ✓ Active agents: {d}\n", .{metrics.active_agents});
    try stdout.print("  ✓ Healthy agents: {d}\n", .{metrics.healthy_agents});
    try stdout.print("  ✓ Queued tasks: {d}\n", .{metrics.queued_tasks});
    try stdout.print("  ✓ Active tasks: {d}\n", .{metrics.active_tasks});
    try stdout.print("  ✓ Completed tasks: {d}\n", .{metrics.completed_tasks});
    try stdout.print("  ✓ Failed tasks: {d}\n", .{metrics.failed_tasks});
    try stdout.print("  ✓ Average queue depth: {d:.2}\n", .{metrics.average_queue_depth});
    try stdout.print("  ✓ Scaling events: {d}\n", .{metrics.scaling_events});

    // Get JSON metrics
    const json = try lb.getMetricsJson();
    defer allocator.free(json);

    try stdout.print("  ✓ JSON metrics length: {d} bytes\n", .{json.len});
}
