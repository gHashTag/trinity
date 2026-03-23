//! STORM P5 — Standalone Integration Test
//! Tests Wave Protocol, Cost Tracking, Model Roulette together
const std = @import("std");

const gc = @import("golden_chain.zig");
const wp = @import("wave_protocol.zig");
const ct = @import("cost_tracker.zig");
const mr = @import("model_roulette.zig");

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n🧪 STORM P5 — Integration Test\n", .{});

    // Test 1: Cost Tracker
    std.debug.print("\n--- Cost Tracker Test ---\n", .{});
    var tracker = try ct.CostTracker.init(allocator);
    defer tracker.deinit();

    try tracker.track("agent-1", .{ .api_tokens = 1000, .cpu_ms = 500 });
    try tracker.track("agent-2", .{ .api_tokens = 2000, .cpu_ms = 1000 });
    try tracker.printSummary();

    const total = tracker.getTotal();
    std.debug.print("Total API tokens: {d}\n", .{total.api_tokens});
    if (total.api_tokens != 3000) {
        std.debug.print("❌ Cost tracker failed\n", .{});
        return 1;
    }

    // Test 2: Model Roulette
    std.debug.print("\n--- Model Roulette Test ---\n", .{});
    var roulette = try mr.ModelRoulette.init(allocator, null);
    defer roulette.deinit();

    const simple_model = try roulette.select(.{
        .task_complexity = .simple,
        .budget_tokens = 10_000,
        .prefer_speed = true,
        .context_size = 4096,
    });
    std.debug.print("Simple task model: {s}\n", .{@tagName(simple_model)});

    const critical_model = try roulette.select(.{
        .task_complexity = .critical,
        .budget_tokens = 1_000_000,
        .require_high_quality = true,
        .context_size = 32_768,
    });
    std.debug.print("Critical task model: {s}\n", .{@tagName(critical_model)});

    // Test 3: Wave Protocol Configuration
    std.debug.print("\n--- Wave Protocol Test ---\n", .{});
    var chain = try gc.GoldenChain.init(allocator);
    defer chain.deinit();

    var wave_proto = try wp.StormWaveProtocol.init(allocator, &chain);
    defer wave_proto.deinit();

    std.debug.print("Waves configured: {d}\n", .{wp.STORM_WAVES.len});

    var total_agents: u8 = 0;
    for (wp.STORM_WAVES) |wave| {
        std.debug.print("  Wave {d}: {s} ({d} agents, {d} links)\n", .{
            wave.id, wave.name, wave.agent_count, wave.links.len,
        });
        total_agents += wave.agent_count;
    }

    std.debug.print("\nTotal agents: {d}\n", .{total_agents});
    if (total_agents != 32) {
        std.debug.print("❌ Wave protocol configuration error\n", .{});
        return 1;
    }

    // Test 4: Cost Tracker with JSON export
    std.debug.print("\n--- Cost JSON Export Test ---\n", .{});
    const json = try tracker.exportToJson();
    defer allocator.free(json);
    std.debug.print("JSON export: {s}\n", .{json});

    // Test 5: Model Roulette for brain zones
    std.debug.print("\n--- Brain Zone Model Selection ---\n", .{});
    const ofc_model = try roulette.selectForBrainZone(.ofc);
    const striatum_model = try roulette.selectForBrainZone(.striatum);
    std.debug.print("OFC zone model: {s}\n", .{@tagName(ofc_model)});
    std.debug.print("Striatum zone model: {s}\n", .{@tagName(striatum_model)});

    std.debug.print("\n✅ STORM P5 integration test PASSED!\n", .{});
    return 0;
}
