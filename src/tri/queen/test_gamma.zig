const std = @import("std");
const queen_bridge = @import("queen_bridge.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Log issue #477 start
    try queen_bridge.logGitHubIssueStart(
        allocator,
        "gamma",
        477,
        "feat(demos): Terminal Recording System",
        &[_][]const u8{ "agent:ralph", "task:code" },
    );

    // Log a step
    try queen_bridge.logGitHubIssueStep(
        allocator,
        "gamma",
        477,
        "Implement terminal recording system",
        &[_][]const u8{ "src/tri/recorder.zig" },
    );

    // Complete issue
    try queen_bridge.logGitHubIssueComplete(
        allocator,
        "gamma",
        477,
        "merged",
        4,
        523,
    );

    std.debug.print("✓ Episodes logged to .trinity/logs/agent-gamma.jsonl\n", .{});
}
