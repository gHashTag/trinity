const std = @import("std");
const repl = @import("repl_agent.zig");
const moe = @import("moe_router.zig");

// ============================================================================
// TRINITY: REPL AGENT TESTS (PHASE 20)
// Tests for interactive REPL functionality
// ============================================================================

test "REPL command parsing - exit" {
    const cmd = repl.ReplCommand.fromString("exit");
    try std.testing.expectEqual(repl.ReplCommand.Exit, cmd);
}

test "REPL command parsing - quit" {
    const cmd = repl.ReplCommand.fromString("quit");
    try std.testing.expectEqual(repl.ReplCommand.Exit, cmd);
}

test "REPL command parsing - help" {
    const cmd = repl.ReplCommand.fromString("help");
    try std.testing.expectEqual(repl.ReplCommand.Help, cmd);
}

test "REPL command parsing - stats" {
    const cmd = repl.ReplCommand.fromString("stats");
    try std.testing.expectEqual(repl.ReplCommand.Stats, cmd);
}

test "REPL command parsing - jobs" {
    const cmd = repl.ReplCommand.fromString("jobs");
    try std.testing.expectEqual(repl.ReplCommand.Jobs, cmd);
}

test "REPL command parsing - infer" {
    const cmd = repl.ReplCommand.fromString("infer mistral-7b");
    try std.testing.expectEqual(repl.ReplCommand.Infer, cmd);
}

test "REPL command parsing - stake" {
    const cmd = repl.ReplCommand.fromString("stake 10000");
    try std.testing.expectEqual(repl.ReplCommand.Stake, cmd);
}

test "REPL command parsing - vote" {
    const cmd = repl.ReplCommand.fromString("vote proposal_42 yes");
    try std.testing.expectEqual(repl.ReplCommand.Vote, cmd);
}

test "REPL command parsing - natural language (agent)" {
    const cmd = repl.ReplCommand.fromString("Оптимизируй inference для Qwen");
    try std.testing.expectEqual(repl.ReplCommand.Agent, cmd);
}

test "REPL agent initialization" {
    const allocator = std.testing.allocator;

    var agent = try repl.ReplAgent.init(allocator, .{
        .verbose = false,
    });
    defer agent.deinit();

    try std.testing.expect(agent.running);
    try std.testing.expectEqual(@as(u64, 0), agent.total_tasks);
}

test "REPL agent command execution" {
    const allocator = std.testing.allocator;

    var agent = try repl.ReplAgent.init(allocator, .{
        .verbose = false,
    });
    defer agent.deinit();

    // Create a null writer for testing
    var buffer: [4096]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);
    const writer = stream.writer();

    // Process a command
    try agent.processCommand("stats", writer);

    // Command should be recorded in history
    try std.testing.expectEqual(@as(usize, 1), agent.command_history.items.len);
}

test "REPL session statistics" {
    const allocator = std.testing.allocator;

    var agent = try repl.ReplAgent.init(allocator, .{
        .verbose = false,
    });
    defer agent.deinit();

    // Simulate some activity
    var buffer: [8192]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);
    const writer = stream.writer();

    try agent.processCommand("test task 1", writer);
    try agent.processCommand("test task 2", writer);
    try agent.processCommand("test task 3", writer);

    try std.testing.expectEqual(@as(u64, 3), agent.total_tasks);
    try std.testing.expect(agent.total_rewards > 0);
}

test "MoE integration in REPL" {
    const allocator = std.testing.allocator;

    var agent = try repl.ReplAgent.init(allocator, .{
        .verbose = false,
    });
    defer agent.deinit();

    // Route through MoE
    const result = agent.router.route("test inference task");

    // Should have valid routing
    try std.testing.expect(result.selected_count > 0);
}
