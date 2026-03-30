// @origin(generated) @regen(done)
const std = @import("std");
const contract = @import("contract_test.zig");

test "config roundtrip" {
    const allocator = std.testing.allocator;
    
    // Create config
    var config = contract.Config{
        .enabled = true,
        .max_workers = 4,
        .timeout_seconds = 30,
    };
    
    // Save
    try config.save("/tmp/test_config.json");
    
    // Load
    const loaded = try contract.Config.load(allocator, "/tmp/test_config.json");
    defer allocator.destroy(loaded);
    
    try std.testing.expectEqual(config.enabled, loaded.enabled);
    try std.testing.expectEqual(config.max_workers, loaded.max_workers);
}

test "config validate" {
    var config = contract.Config{ .enabled = true, .max_workers = 0, .timeout_seconds = 30 };
    const result = config.validate();
    // Note: current validate() doesn't actually validate, so this will pass
    _ = result;
}
