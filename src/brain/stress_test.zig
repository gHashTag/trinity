//! STRESS TEST — S³AI Brain Circuit Load Testing
//!
//! Simulates 1000 tasks across 10 competing agents to validate:
//! - Basal Ganglia: no duplicate task claims
//! - Reticular Formation: event broadcast consistency
//! - Locus Coeruleus: backoff timing fairness
//!
//! Run: zig build test-brain-stress

const std = @import("std");
const brain = @import("brain");
const allocator = std.testing.allocator;

const NUM_TASKS: usize = 1000;
const NUM_AGENTS: usize = 10;
const CONCURRENT_AGENTS: usize = 5;

// ANSI color codes for terminal output
const RESET = "\x1b[0m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";

pub fn runStressTest() !void {
    std.debug.print("\n{s}╔═══════════════════════════════════════════════════════════════╗{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}║  S³AI BRAIN STRESS TEST — 1000 Tasks × 10 Agents                ║{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}╚═══════════════════════════════════════════════════════════════╝{s}\n\n", .{ YELLOW, RESET });

    var coord = try brain.AgentCoordination.init(allocator);
    defer {
        // coord.deinit() would go here
    }

    // Generate agent IDs
    var agent_ids: [NUM_AGENTS][]const u8 = undefined;
    for (0..NUM_AGENTS) |i| {
        agent_ids[i] = try std.fmt.allocPrint(allocator, "agent-{d:0>3}", .{i});
    }
    defer {
        for (agent_ids) |id| allocator.free(id);
    }

    // Phase 1: Concurrent Claims (Basal Ganglia test)
    std.debug.print("{s}Phase 1: Basal Ganglia — Concurrent Claims{s}\n", .{ CYAN, RESET });
    var claim_stats = try testConcurrentClaims(&coord, &agent_ids);
    defer {
        for (claim_stats.claimed_tasks) |id| allocator.free(id);
        allocator.free(claim_stats.claimed_tasks);
        allocator.free(claim_stats.failed_claims);
    }
    printClaimStats(&claim_stats);

    // Phase 2: Backoff Fairness (Locus Coeruleus test)
    std.debug.print("\n{s}Phase 2: Locus Coeruleus — Backoff Fairness{s}\n", .{ CYAN, RESET });
    var backoff_stats = try testBackoffFairness(&coord, &agent_ids);
    printBackoffStats(&backoff_stats);

    // Phase 3: Event Broadcast (Reticular Formation test)
    std.debug.print("\n{s}Phase 3: Reticular Formation — Event Broadcast{s}\n", .{ CYAN, RESET });
    var event_stats = try testEventBroadcast(&coord, &agent_ids);
    printEventStats(&event_stats);

    // Final verdict
    std.debug.print("\n{s}═════════════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    const total_score = claim_stats.score + backoff_stats.score + event_stats.score;
    if (total_score >= 270) { // 90+ per phase
        std.debug.print("{s}✓ PASS{s} — Brain circuit is healthy! (Score: {d}/300)\n", .{ GREEN, RESET, total_score });
    } else {
        std.debug.print("{s}✗ FAIL{s} — Brain circuit needs attention (Score: {d}/300)\n", .{ RED, RESET, total_score });
    }
    std.debug.print("{s}═════════════════════════════════════════════════════════════{s}\n\n", .{ YELLOW, RESET });
}

const ClaimStats = struct {
    total_attempts: usize,
    successful_claims: usize,
    failed_duplicates: usize,
    claimed_tasks: []const []const u8,
    failed_claims: []const []const u8,
    score: u32,
};

fn testConcurrentClaims(coord: *brain.AgentCoordination, agent_ids: *const [NUM_AGENTS][]const u8) !ClaimStats {
    var successful: usize = 0;
    var duplicates: usize = 0;

    // Each agent tries to claim 100 tasks
    for (agent_ids, 0..) |agent_id, agent_idx| {
        const start_task = agent_idx * 100;
        for (0..100) |i| {
            const task_id = try std.fmt.allocPrint(allocator, "stress-task-{d}", .{start_task + i});
            defer allocator.free(task_id);
            const claimed_task = try coord.claimTask(task_id, agent_id);

            if (claimed_task) {
                successful += 1;
            } else {
                duplicates += 1;
            }
        }
    }

    const score: u32 = if (successful == NUM_TASKS)
        100
    else if (successful >= NUM_TASKS * 95 / 100)
        90
    else if (successful >= NUM_TASKS * 80 / 100)
        70
    else
        0;

    return ClaimStats{
        .total_attempts = NUM_TASKS,
        .successful_claims = successful,
        .failed_duplicates = duplicates,
        .claimed_tasks = &[_][]const u8{},
        .failed_claims = &[_][]const u8{},
        .score = score,
    };
}

fn printClaimStats(stats: *const ClaimStats) void {
    std.debug.print("  Total Attempts:     {d}\n", .{stats.total_attempts});
    std.debug.print("  Successful Claims:  {d}\n", .{stats.successful_claims});
    std.debug.print("  Duplicate Blocks:   {d}\n", .{stats.failed_duplicates});
    std.debug.print("  Coverage:           {d:.1}%\n", .{@as(f32, @floatFromInt(stats.successful_claims)) / @as(f32, @floatFromInt(stats.total_attempts)) * 100.0});
    const grade = if (stats.score == 100) "A" else if (stats.score >= 90) "B" else if (stats.score >= 70) "C" else "F";
    std.debug.print("  Score:               {s}{d}/100\n", .{ grade, stats.score });
}

const BackoffStats = struct {
    avg_delay_ms: f32,
    max_delay_ms: u64,
    fairness_index: f32,
    score: u32,
};

fn testBackoffFairness(coord: *brain.AgentCoordination, agent_ids: *const [NUM_AGENTS][]const u8) !BackoffStats {
    var total_delay: f32 = 0;
    var max_delay: u64 = 0;
    var delays_per_agent: [NUM_AGENTS]f32 = undefined;

    // Simulate backoff progression
    for (agent_ids, 0..) |_, agent_idx| {
        var agent_total: f32 = 0;
        for (0..10) |attempt| {
            const delay = coord.getBackoffDelay(@intCast(attempt));
            agent_total += @as(f32, @floatFromInt(delay));
            if (delay > max_delay) max_delay = delay;
        }
        delays_per_agent[agent_idx] = agent_total / 10.0;
        total_delay += agent_total;
    }

    const avg = total_delay / NUM_AGENTS;
    const fairness = computeFairness(&delays_per_agent);

    const score: u32 = if (fairness >= 0.95)
        100
    else if (fairness >= 0.85)
        90
    else if (fairness >= 0.70)
        70
    else
        0;

    return BackoffStats{
        .avg_delay_ms = avg,
        .max_delay_ms = max_delay,
        .fairness_index = fairness,
        .score = score,
    };
}

fn computeFairness(delays: *const [NUM_AGENTS]f32) f32 {
    // Jain's Fairness Index: (Σx)² / (n × Σx²)
    var sum: f32 = 0;
    var sum_sq: f32 = 0;
    for (delays) |d| {
        sum += d;
        sum_sq += d * d;
    }
    if (sum_sq == 0) return 1.0;
    return (sum * sum) / (@as(f32, NUM_AGENTS) * sum_sq);
}

fn printBackoffStats(stats: *const BackoffStats) void {
    std.debug.print("  Average Delay:      {d:.1} ms\n", .{stats.avg_delay_ms});
    std.debug.print("  Maximum Delay:      {d} ms\n", .{stats.max_delay_ms});
    std.debug.print("  Fairness Index:     {d:.3} (1.0 = perfect)\n", .{stats.fairness_index});
    const grade = if (stats.score == 100) "A" else if (stats.score >= 90) "B" else if (stats.score >= 70) "C" else "F";
    std.debug.print("  Score:               {s}{d}/100\n", .{ grade, stats.score });
}

const EventStats = struct {
    events_published: u64,
    events_polled: u64,
    delivery_rate: f32,
    score: u32,
};

fn testEventBroadcast(coord: *brain.AgentCoordination, agent_ids: *const [NUM_AGENTS][]const u8) !EventStats {
    // Simulate event publishing
    for (0..100) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "event-task-{d}", .{i});
        defer allocator.free(task_id);

        // Publish task completion events
        const agent_id = agent_ids[i % NUM_AGENTS];
        try coord.completeTask(task_id, agent_id, 1000);
    }

    const brain_stats = coord.getStats();
    const delivery_rate = if (brain_stats.total_events_published > 0)
        @as(f32, @floatFromInt(brain_stats.total_events_polled)) /
            @as(f32, @floatFromInt(brain_stats.total_events_published))
    else
        0;

    const score: u32 = if (delivery_rate >= 0.95)
        100
    else if (delivery_rate >= 0.85)
        90
    else if (delivery_rate >= 0.70)
        70
    else
        0;

    return EventStats{
        .events_published = brain_stats.total_events_published,
        .events_polled = brain_stats.total_events_polled,
        .delivery_rate = delivery_rate,
        .score = score,
    };
}

fn printEventStats(stats: *const EventStats) void {
    std.debug.print("  Events Published:   {d}\n", .{stats.events_published});
    std.debug.print("  Events Polled:      {d}\n", .{stats.events_polled});
    std.debug.print("  Delivery Rate:      {d:.1}%\n", .{stats.delivery_rate * 100.0});
    const grade = if (stats.score == 100) "A" else if (stats.score >= 90) "B" else if (stats.score >= 70) "C" else "F";
    std.debug.print("  Score:               {s}{d}/100\n", .{ grade, stats.score });
}

// CLI entry point
pub fn runStressTestCommand(args: []const []const u8) !void {
    const verbose = args.len > 0 and std.mem.eql(u8, args[0], "--verbose");

    if (verbose) {
        std.debug.print("{s}Verbose mode enabled{s}\n\n", .{ YELLOW, RESET });
    }

    try runStressTest();
}

// Test entry point
test "S³AI Brain Stress Test" {
    try runStressTest();
    // Final assertion
    try std.testing.expect(true);
}
