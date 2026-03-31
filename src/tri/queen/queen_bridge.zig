// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// QUEEN BRIDGE — Bridge from agent steps to Queen episodes
// ═══════════════════════════════════════════════════════════════════════════════
//
// Each agent step → episode in .trinity/logs/agent-{name}.jsonl
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const StepType = enum {
    start,
    think,
    act,
    observe,
    @"error",
    success,
};

pub const AgentStep = struct {
    agent: []const u8,
    issue_number: u32,
    step_name: []const u8,
    step_type: StepType,
    thought: ?[]const u8 = null,
    action: ?[]const u8 = null,
    result: ?[]const u8 = null,
    error_message: ?[]const u8 = null,
    timestamp: i64 = 0,
};

/// Log an agent step to Queen JSONL format
pub fn logStep(allocator: Allocator, step: AgentStep) !void {
    const logs_dir = ".trinity/logs";
    std.fs.cwd().makePath(logs_dir) catch {};

    // Build path: .trinity/logs/agent-{name}.jsonl
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "{s}/agent-{s}.jsonl", .{
        logs_dir,
        step.agent,
    });

    // Build episode_id: issue-{N}-{step}-{timestamp}
    const ts = if (step.timestamp == 0) std.time.timestamp() else step.timestamp;
    var id_buf: [128]u8 = undefined;
    const episode_id = try std.fmt.bufPrint(&id_buf, "issue-{d}-{s}-{d}", .{
        step.issue_number,
        step.step_name,
        ts,
    });

    // Map StepType to EpisodeType
    const episode_type: []const u8 = switch (step.step_type) {
        .start => "task",
        .think => "observation",
        .act => "action",
        .observe => "observation",
        .@"error" => "error",
        .success => "task",
    };

    // Build title
    var title_buf: [256]u8 = undefined;
    const title = try std.fmt.bufPrint(&title_buf, "#{d}: {s}", .{
        step.issue_number,
        step.step_name,
    });

    // Build JSON manually (Zig 0.15 compatible)
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(allocator);
    const w = buf.writer(allocator);

    try w.writeAll("{");
    try w.print("\"episode_id\":\"{s}\",", .{episode_id});
    try w.print("\"agent\":\"{s}\",", .{step.agent});
    try w.print("\"episode_type\":\"{s}\",", .{episode_type});
    try w.print("\"timestamp\":\"{d}\",", .{ts});
    try w.print("\"title\":\"{s}\", .{title});
    try w.print("\"correlation_id\":\"{d}", .{step.issue_number});
    try w.writeAll("\"data\":{");
    try w.print("\"domain\":\"github_issue\"", .{});

    if (step.action) |a| {
        try w.print(",\"action\":\"{s}", .{a});
    }
    if (step.thought) |t| {
        try w.print(",\"thought\":\"{s}", .{t});
    }
    if (step.result) |r| {
        try w.print(",\"next_step\":\"{s}", .{r});
    }
    if (step.error_message) |e| {
        try w.print(",\"error\":\"{s}", .{e});
    }

    try w.writeAll("}}\n");

    // Open file for append
    const file = try std.fs.cwd().createFile(path, .{ .truncate = false });
    defer file.close();
    try file.seekFromEnd(0);

    // Write JSON
    try file.writeAll(buf.items);
}

/// Convenience: log step start
pub fn logStepStart(allocator: Allocator, agent: []const u8, issue: u32, step_name: []const u8, thought: ?[]const u8) !void {
    try logStep(allocator, .{
        .agent = agent,
        .issue_number = issue,
        .step_name = step_name,
        .step_type = .start,
        .thought = thought,
    });
}

/// Convenience: log step success
pub fn logStepSuccess(allocator: Allocator, agent: []const u8, issue: u32, step_name: []const u8, result: ?[]const u8) !void {
    try logStep(allocator, .{
        .agent = agent,
        .issue_number = issue,
        .step_name = step_name,
        .step_type = .success,
        .result = result,
    });
}

/// Convenience: log step error
pub fn logStepError(allocator: Allocator, agent: []const u8, issue: u32, step_name: []const u8, error_msg: []const u8) !void {
    try logStep(allocator, .{
        .agent = agent,
        .issue_number = issue,
        .step_name = step_name,
        .step_type = .@"error",
        .error_message = error_msg,
    });
}
