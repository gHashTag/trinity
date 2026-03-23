//! STORM P4 — Standalone Test (bypasses tri_commands.zig)
const std = @import("std");

const gc = @import("golden_chain.zig");

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var chain = try gc.GoldenChain.init(allocator);
    defer chain.deinit();

    std.debug.print("\n🧪 STORM P4 — Standalone Test\n", .{});

    const task = "Test STORM P4 features";
    const result = try chain.run(task);

    std.debug.print("\n✅ Status: {d}\n", .{result});
    return result;
}
