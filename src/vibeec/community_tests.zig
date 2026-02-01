const std = @import("std");
const eco = @import("ecosystem_codex.zig");
const p2p = @import("p2p_module.zig");

test "SwarmManager - Massive Scale Simulation" {
    const allocator = std.testing.allocator;
    var swarm = try p2p.SwarmManager.init(allocator);
    defer swarm.deinit();

    try std.testing.expect(swarm.nodes.items.len == 10);
    swarm.simulateGossip();

    for (swarm.nodes.items) |node| {
        try std.testing.expect(node.balance > 0);
    }
}

test "EcosystemCodex - NL Commands" {
    const allocator = std.testing.allocator;
    var app = try eco.EcosystemCodex.init(allocator);
    defer app.deinit();

    const args = [_][]const u8{"run network"};
    try app.fire(&args);
    // Verified by observation of logs during test run if needed,
    // but here we just ensure no crash.
}

test "EcosystemCodex - Localization" {
    const allocator = std.testing.allocator;
    var app = try eco.EcosystemCodex.init(allocator);
    defer app.deinit();

    app.lang = .RU;
    const args = [_][]const u8{"unknown_command"};
    try app.fire(&args);
    // Should trigger RU self-healing message
}
