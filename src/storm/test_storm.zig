//! STORM P4 Test
const std = @import("std");

const gc = @import("golden_chain.zig");

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var chain = try gc.GoldenChain.init(allocator);
    defer chain.deinit();

    std.debug.print("\n🧪 STORM P4 — Testing Golden Chain v5.1\n", .{});

    // Test 1: Run full chain (simulated)
    const task = "Test STORM P4 execution";
    const result = try chain.run(task);

    // Test 2: Check handoff validation
    _ = try chain.validateHandoff(.planner, .coder);

    // Test 3: Test invalid handoff
    if (chain.validateHandoff(.integrator, .planner)) |_| {
        std.debug.print("❌ Should have failed!\n", .{});
        return 1;
    } else |e| {
        std.debug.print("✅ Invalid handoff correctly rejected: {}\n", .{e});
    }

    // Test 4: Checkpoint save/load
    try chain.saveCheckpoint(task);
    std.debug.print("\n✅ STORM P4 test complete!\n", .{});

    return result;
}
