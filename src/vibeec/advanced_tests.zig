const std = @import("std");
const evolved = @import("evolved_codex.zig");
const net_mod = @import("networked_cli.zig");

test "NetworkOrganism - Mobile Mutation" {
    const allocator = std.testing.allocator;
    var app = try evolved.EvolvedCodex.init(allocator);
    defer app.deinit();

    var net = net_mod.NetworkOrganism.init(allocator, app);

    // Set mobile constraints
    net.stats.latency_ms = 150;
    net.stats.bandwidth_mbps = 2.0;

    app.mode = .TURBO; // Start in High-Perf mode
    try net.syncWithTrinityL2();

    // Target: Should mutate back to STANDARD because of network constraints
    try std.testing.expect(app.mode == .STANDARD);
}

test "NetworkOrganism - Economic Growth" {
    const allocator = std.testing.allocator;
    var app = try evolved.EvolvedCodex.init(allocator);
    defer app.deinit();

    var net = net_mod.NetworkOrganism.init(allocator, app);

    try std.testing.expect(net.tri_balance == 0.0);
    net.earnMockTRI("test_job");
    try std.testing.expect(net.tri_balance > 0.0);
}

test "EvolvedCodex - SIMD scratchpad integration" {
    const allocator = std.testing.allocator;
    var app = try evolved.EvolvedCodex.init(allocator);
    defer app.deinit();

    try std.testing.expect(app.pre_alloc_buffer.len == 4096);

    const args = [_][]const u8{ "chat", "ping" };
    try app.fire(&args);
}
