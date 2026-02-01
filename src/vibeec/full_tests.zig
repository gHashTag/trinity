const std = @import("std");
const scaled = @import("scaled_codex.zig");
const dao = @import("dao_integration.zig");

test "ScaledCodex - ThreadPool stress" {
    const allocator = std.testing.allocator;
    var app = try scaled.NetworkCodex.init(allocator);
    defer app.deinit();

    app.mode = .TURBO;

    // Fire multiple jobs rapidly
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        const args = [_][]const u8{ "chat", "parallel_test" };
        try app.fire(&args);
    }
}

test "DAOManager - APY Accuracy" {
    const allocator = std.testing.allocator;
    var mgr = dao.DAOManager.init(allocator);
    defer mgr.deinit();

    try mgr.stake(1000, .GOLD); // 20%

    // Mock passing of 1 year (simulated start_time)
    mgr.stakes.items[0].start_time -= 31536000;

    const reward = mgr.calculateRewards();
    try std.testing.expect(reward >= 199.9 and reward <= 200.1);
}

test "ScaledCodex - Self-Healing redirect" {
    const allocator = std.testing.allocator;
    var app = try scaled.NetworkCodex.init(allocator);
    defer app.deinit();

    const args = [_][]const u8{ "corrupted_reflex", "hello" };
    try app.fire(&args);
    // Should print "Unknown command... Defaulting to chat"
}
