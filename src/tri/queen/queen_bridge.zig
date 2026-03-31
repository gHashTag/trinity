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
    action: ?[]const u8 = null,
    labels: ?[]const []const u8 = null,
    files: ?[]const []const u8 = null,
    metrics: ?Metrics = null,
    thought: ?[]const u8 = null,
    result: ?[]const u8 = null,
    error_message: ?[]const u8 = null,
    timestamp: i64 = 0,

    pub const Metrics = struct {
        status: ?[]const u8 = null,
        files_changed: ?u32 = null,
        lines_added: ?u32 = null,
        files_touched: ?u32 = null,
    };
};

/// Log an agent step to Queen JSONL format (proper JSON with escaping)
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

    // Build JSON with proper escaping
    var buf = try std.ArrayList(u8).initCapacity(allocator, 1024);
    defer buf.deinit(allocator);
    const w = buf.writer(allocator);

    try w.writeAll("{");
    try w.writeAll("\"episode_id\":\"");
    try w.writeAll(escapeString(allocator, episode_id));
    try w.writeAll("\",");
    try w.writeAll("\"agent\":\"");
    try w.writeAll(escapeString(allocator, step.agent));
    try w.writeAll("\",");
    try w.print("\"episode_type\":\"{s}\",", .{episode_type});
    try w.print("\"timestamp\":{d},", .{ts});
    try w.writeAll("\"title\":\"");
    try w.writeAll(escapeString(allocator, title));
    try w.writeAll("\",");
    try w.print("\"correlation_id\":{d},", .{step.issue_number});
    try w.writeAll("\"data\":{");

    // Build data object
    try w.writeAll("{");
    try w.print("\"domain\":\"github_issue\"", .{});

    if (step.action) |a| {
        try w.writeAll(",\"action\":\"");
        try w.writeAll(escapeString(allocator, a));
        try w.writeAll("\"");
    }
    if (step.labels) |labels| {
        try w.writeAll(",\"labels\":[");
        for (labels, 0..) |label, i| {
            if (i > 0) try w.writeAll(",");
            const escaped = escapeString(allocator, label);
            try w.writeAll("\"");
            try w.writeAll(escaped);
            try w.writeAll("\"");
        }
        try w.writeAll("]");
    }
    if (step.files) |files| {
        try w.writeAll(",\"files\":[");
        for (files, 0..) |file, i| {
            if (i > 0) try w.writeAll(",");
            const escaped = escapeString(allocator, file);
            try w.writeAll("\"");
            try w.writeAll(escaped);
            try w.writeAll("\"");
        }
        try w.writeAll("]");
    }
    if (step.metrics) |m| {
        try w.writeAll(",\"metrics\":{");
        var need_comma = false;
        if (m.status) |s| {
            try w.writeAll("\"status\":\"");
            try w.writeAll(escapeString(allocator, s));
            try w.writeAll("\"");
            need_comma = true;
        }
        if (m.files_changed) |fc| {
            if (need_comma) try w.writeAll(",");
            try w.print("\"files_changed\":{d}", .{fc});
            need_comma = true;
        }
        if (m.lines_added) |la| {
            if (need_comma) try w.writeAll(",");
            try w.print("\"lines_added\":{d}", .{la});
            need_comma = true;
        }
        if (m.files_touched) |ft| {
            if (need_comma) try w.writeAll(",");
            try w.print("\"files_touched\":{d}", .{ft});
        }
        try w.writeAll("}");
    }
    if (step.thought) |t| {
        try w.writeAll(",\"thought\":\"");
        try w.writeAll(escapeString(allocator, t));
        try w.writeAll("\"");
    }
    if (step.result) |r| {
        try w.writeAll(",\"next_step\":\"");
        try w.writeAll(escapeString(allocator, r));
        try w.writeAll("\"");
    }
    if (step.error_message) |e| {
        try w.writeAll(",\"error\":\"");
        try w.writeAll(escapeString(allocator, e));
        try w.writeAll("\"");
    }

    try w.writeAll("}");  // Close data object
    try w.writeAll("}");  // Close episode object

    // Open file for append
    const file = try std.fs.cwd().createFile(path, .{ .truncate = false });
    defer file.close();
    try file.seekFromEnd(0);

    // Write JSON with newline
    try file.writeAll(buf.items);
    try file.writeAll("\n");
}

/// Escape JSON string (minimal: quotes, backslashes, newlines)
/// Returns escaped string (caller owns memory)
fn escapeString(allocator: Allocator, s: []const u8) []const u8 {
    var escaped = std.ArrayList(u8).initCapacity(allocator, s.len + s.len / 4) catch return s;
    defer escaped.deinit(allocator);
    const w = escaped.writer(allocator);

    for (s) |c| {
        switch (c) {
            '\\' => w.writeAll("\\\\") catch {},
            '"' => w.writeAll("\\\"") catch {},
            '\n' => w.writeAll("\\n") catch {},
            '\r' => w.writeAll("\\r") catch {},
            '\t' => w.writeAll("\\t") catch {},
            else => w.writeByte(c) catch {},
        }
    }

    return escaped.toOwnedSlice(allocator) catch s;
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

// ═════════════════════════════════════════════════════════════════════════════
// GitHub Episode API — for γ agent to log issue work
// ═════════════════════════════════════════════════════════════════════════════

/// Start working on a GitHub issue
pub fn logGitHubIssueStart(allocator: Allocator, agent: []const u8, issue_number: u32, title: []const u8, labels: []const []const u8) !void {
    try logStep(allocator, .{
        .agent = agent,
        .issue_number = issue_number,
        .step_name = title,
        .step_type = .start,
        .action = "issue.start",
        .labels = labels,
    });
}

/// Record a step within an issue
pub fn logGitHubIssueStep(allocator: Allocator, agent: []const u8, issue_number: u32, description: []const u8, files: []const []const u8) !void {
    try logStep(allocator, .{
        .agent = agent,
        .issue_number = issue_number,
        .step_name = description,
        .step_type = .act,
        .action = "issue.step",
        .files = files,
    });
}

/// Complete an issue successfully
pub fn logGitHubIssueComplete(allocator: Allocator, agent: []const u8, issue_number: u32, status: []const u8, files_changed: u32, lines_added: u32) !void {
    try logStep(allocator, .{
        .agent = agent,
        .issue_number = issue_number,
        .step_name = "Issue complete",
        .step_type = .success,
        .action = "issue.complete",
        .metrics = .{
            .status = status,
            .files_changed = files_changed,
            .lines_added = lines_added,
        },
    });
}

/// Log issue failure
pub fn logGitHubIssueFail(allocator: Allocator, agent: []const u8, issue_number: u32, error_message: []const u8, files_touched: u32) !void {
    try logStep(allocator, .{
        .agent = agent,
        .issue_number = issue_number,
        .step_name = "Issue failed",
        .step_type = .@"error",
        .action = "issue.fail",
        .error_message = error_message,
        .metrics = .{
            .files_touched = files_touched,
        },
    });
}
