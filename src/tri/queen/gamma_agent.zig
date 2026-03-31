// @origin(manual) @regen(pending)
// ═════════════════════════════════════════════════════════════════════════════
// GAMMA AGENT — GitHub Issue → Queen Episode Bridge
// ═════════════════════════════════════════════════════════════════════════════
//
// γ-agent monitors GitHub issues and creates Queen episodes for each step:
//   issue opened → task episode
//   issue comment → observation episode
//   PR created → action episode
//   PR merged → task episode (success)
//   build failed → error episode
//
// φ² + 1/φ² = 3 = TRINITY
// ═════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const queen_bridge = @import("queen_bridge.zig");

pub const GammaAgent = struct {
    queen_url: []const u8,
    agent_name: []const u8 = "gamma",

    pub fn init(queen_url: []const u8) GammaAgent {
        return .{
            .queen_url = queen_url,
        };
    }
};

/// Map GitHub issue action to Queen StepType
pub fn mapIssueAction(action: []const u8) queen_bridge.StepType {
    if (std.mem.eql(u8, action, "opened")) return .start;
    if (std.mem.eql(u8, action, "reopened")) return .start;
    if (std.mem.eql(u8, action, "commented")) return .think;
    if (std.mem.eql(u8, action, "assigned")) return .observe;
    if (std.mem.eql(u8, action, "closed")) return .success;
    return .observe; // default
}

/// Map GitHub pull request action to Queen StepType
pub fn mapPullRequestAction(action: []const u8) queen_bridge.StepType {
    if (std.mem.eql(u8, action, "opened")) return .act;
    if (std.mem.eql(u8, action, "closed")) return .success;
    if (std.mem.eql(u8, action, "merged")) return .success;
    return .observe; // default
}

/// Create episode from GitHub issue opened event
pub fn logIssueOpened(
    allocator: Allocator,
    issue_number: u32,
    title: []const u8,
    labels: []const []const u8,
) !void {
    try queen_bridge.logGitHubIssueStart(allocator, "gamma", issue_number, title, labels);
}

/// Create episode from GitHub issue action (legacy, use specific functions)
pub fn logIssueEvent(
    allocator: Allocator,
    queen_url: []const u8,
    issue_number: u32,
    action: []const u8,
    title: []const u8,
    thought: ?[]const u8,
) !void {
    _ = queen_url;
    _ = thought; // TODO: use thought in episode data

    // For opened issues, use specialized API
    if (std.mem.eql(u8, action, "opened") or std.mem.eql(u8, action, "reopened")) {
        // Empty labels slice for now
        try queen_bridge.logGitHubIssueStart(allocator, "gamma", issue_number, title, &[_][]const u8{});
        return;
    }

    // For other actions, use general logStep
    const step_type = mapIssueAction(action);
    try queen_bridge.logStep(allocator, .{
        .agent = "gamma",
        .issue_number = issue_number,
        .step_name = title,
        .step_type = step_type,
        .action = action,
        .result = if (step_type == .success) "Issue closed" else null,
    });
}

/// Create episode from GitHub comment event
pub fn logCommentEvent(
    allocator: Allocator,
    queen_url: []const u8,
    issue_number: u32,
    comment_body: []const u8,
    author: []const u8,
) !void {
    _ = queen_url;
    var thought_buf: [1024]u8 = undefined;
    const thought = std.fmt.bufPrint(&thought_buf, "Comment by {s}: {s}", .{
        author, comment_body[0..@min(comment_body.len, 500)],
    }) catch comment_body;

    try queen_bridge.logStep(allocator, .{
        .agent = "gamma",
        .issue_number = issue_number,
        .step_name = "comment",
        .step_type = .think,
        .thought = thought,
    });
}

/// Create episode from GitHub pull request event
pub fn logPullRequestEvent(
    allocator: Allocator,
    queen_url: []const u8,
    issue_number: u32,
    pr_number: u32,
    action: []const u8,
    title: []const u8,
) !void {
    _ = queen_url;
    const step_type = mapPullRequestAction(action);

    var action_buf: [256]u8 = undefined;
    const action_str = std.fmt.bufPrint(&action_buf, "PR #{d}: {s}", .{
        pr_number, title[0..@min(title.len, 200)],
    }) catch "PR created";

    try queen_bridge.logStep(allocator, .{
        .agent = "gamma",
        .issue_number = issue_number,
        .step_name = "pull_request",
        .step_type = step_type,
        .action = action_str,
        .result = if (step_type == .success) "PR merged" else null,
    });
}

/// Create error episode from build failure
pub fn logBuildError(
    allocator: Allocator,
    queen_url: []const u8,
    issue_number: u32,
    error_message: []const u8,
) !void {
    _ = queen_url;
    try queen_bridge.logStep(allocator, .{
        .agent = "gamma",
        .issue_number = issue_number,
        .step_name = "build",
        .step_type = .@"error",
        .error_message = error_message,
    });
}

/// Create success episode after completing a task
pub fn logTaskComplete(
    allocator: Allocator,
    queen_url: []const u8,
    issue_number: u32,
    result_summary: []const u8,
) !void {
    _ = queen_url;

    try queen_bridge.logStep(allocator, .{
        .agent = "gamma",
        .issue_number = issue_number,
        .step_name = "task_complete",
        .step_type = queen_bridge.StepType.success,
        .result = result_summary,
    });
}

// ═════════════════════════════════════════════════════════════════════════════
// GITHUB WEBHOOK HANDLER
// ═════════════════════════════════════════════════════════════════════════════

pub const WebhookEvent = union(enum) {
    issue: IssueEvent,
    issue_comment: IssueCommentEvent,
    pull_request: PullRequestEvent,
    unknown,

    pub const IssueEvent = struct {
        action: []const u8,
        issue_number: u32,
        title: []const u8,
        body: []const u8,
        sender: []const u8,
    };

    pub const IssueCommentEvent = struct {
        action: []const u8,
        issue_number: u32,
        comment_body: []const u8,
        sender: []const u8,
    };

    pub const PullRequestEvent = struct {
        action: []const u8,
        pr_number: u32,
        issue_number: u32,
        title: []const u8,
        sender: []const u8,
    };
};

/// Parse GitHub webhook payload (simplified)
pub fn parseWebhookPayload(payload: []const u8) !WebhookEvent {
    // Simple JSON parsing for GitHub webhook events
    // In production, use proper JSON parser

    const action_idx = std.mem.indexOf(u8, payload, "\"action\":") orelse return WebhookEvent.unknown;
    const action_start = action_idx + 10; // skip "action":"
    const action_end = std.mem.indexOfPos(u8, payload, action_start, "\"") orelse payload.len;
    const action = payload[action_start..action_end];

    // Check for pull_request first
    if (std.mem.indexOf(u8, payload, "\"pull_request\"") != null) {
        // Pull request event
        const pr_idx = std.mem.indexOf(u8, payload, "\"number\":") orelse return WebhookEvent.unknown;
        const pr_start = pr_idx + 10;
        var pr_end = pr_start;
        while (pr_end < payload.len and payload[pr_end] >= '0' and payload[pr_end] <= '9') : (pr_end += 1) {}
        const pr_number = std.fmt.parseInt(u32, payload[pr_start..pr_end], 10) catch 0;

        // Try to extract issue number from PR title (format: "feat(...): ... (#N)")
        var issue_number: u32 = 0;
        if (std.mem.indexOf(u8, payload, "\"title\":") != null) {
            const title_start = std.mem.indexOf(u8, payload, "\"title\":") orelse return WebhookEvent.unknown;
            const title_end = std.mem.indexOfPos(u8, payload, title_start, "\"") orelse payload.len;
            const title = payload[title_start..title_end];

            // Look for (#N) pattern at end of title
            if (std.mem.lastIndexOf(u8, title, "(#")) |hash_idx| {
                const num_start = hash_idx + 2;
                var num_end = num_start;
                while (num_end < title.len and title[num_end] >= '0' and title[num_end] <= '9') : (num_end += 1) {}
                issue_number = std.fmt.parseInt(u32, title[num_start..num_end], 10) catch 0;
            }
        }

        return WebhookEvent{
            .pull_request = .{
                .action = action,
                .pr_number = pr_number,
                .issue_number = issue_number,
                .title = "PR",
                .sender = "unknown",
            },
        };
    }

    // Check for issue event
    if (std.mem.indexOf(u8, payload, "\"issue\"") != null) {
        // Issue or issue_comment event
        const number_idx = std.mem.indexOf(u8, payload, "\"number\":") orelse return WebhookEvent.unknown;
        const number_start = number_idx + 10;
        var number_end = number_start;
        while (number_end < payload.len and payload[number_end] >= '0' and payload[number_end] <= '9') : (number_end += 1) {}
        const issue_number = std.fmt.parseInt(u32, payload[number_start..number_end], 10) catch 0;

        const title_idx = std.mem.indexOf(u8, payload, "\"title\":") orelse return WebhookEvent.unknown;
        const title_start = title_idx + 10;
        const title_end = std.mem.indexOfPos(u8, payload, title_start, "\"") orelse payload.len;
        const title = payload[title_start..title_end];

        // Check for comment (issue_comment event)
        if (std.mem.indexOf(u8, payload, "\"comment\"") != null) {
            // Issue comment event
            const body_idx = std.mem.indexOf(u8, payload, "\"body\":") orelse return WebhookEvent.unknown;
            const body_start = body_idx + 9;
            const body_end = std.mem.indexOfPos(u8, payload, body_start, "\"") orelse payload.len;
            const comment_body = payload[body_start..body_end];

            return WebhookEvent{
                .issue_comment = .{
                    .action = action,
                    .issue_number = issue_number,
                    .comment_body = comment_body,
                    .sender = "unknown",
                },
            };
        }

        // Issue event
        const body_idx = std.mem.indexOf(u8, payload, "\"body\":") orelse return WebhookEvent.unknown;
        const body_start = body_idx + 9;
        const body_end = std.mem.indexOfPos(u8, payload, body_start, "\"") orelse payload.len;
        const issue_body = payload[body_start..body_end];

        return WebhookEvent{
            .issue = .{
                .action = action,
                .issue_number = issue_number,
                .title = title,
                .body = issue_body,
                .sender = "unknown",
            },
        };
    }

    return WebhookEvent.unknown;
}

/// Handle webhook event and create appropriate episode
pub fn handleWebhookEvent(
    allocator: Allocator,
    queen_url: []const u8,
    event: WebhookEvent,
) !void {
    switch (event) {
        .issue => |ev| {
            try logIssueEvent(allocator, queen_url, ev.issue_number, ev.action, ev.title, ev.body);
            std.debug.print("γ-agent: Logged issue event #{d} ({s})\n", .{ ev.issue_number, ev.action });
        },
        .issue_comment => |ev| {
            try logCommentEvent(allocator, queen_url, ev.issue_number, ev.comment_body, ev.sender);
            std.debug.print("γ-agent: Logged comment on issue #{d}\n", .{ev.issue_number});
        },
        .pull_request => |ev| {
            try logPullRequestEvent(allocator, queen_url, ev.issue_number, ev.pr_number, ev.action, ev.title);
            std.debug.print("γ-agent: Logged PR event for issue #{d}\n", .{ev.issue_number});
        },
        .unknown => {
            std.debug.print("γ-agent: Unknown webhook event\n", .{});
        },
    }
}

// ═════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════

test "gamma_agent: mapIssueAction" {
    try std.testing.expectEqual(mapIssueAction("opened"), .start);
    try std.testing.expectEqual(mapIssueAction("reopened"), .start);
    try std.testing.expectEqual(mapIssueAction("commented"), .think);
    try std.testing.expectEqual(mapIssueAction("assigned"), .observe);
    try std.testing.expectEqual(mapIssueAction("closed"), .success);
    try std.testing.expectEqual(mapIssueAction("unknown"), .observe);
}

test "gamma_agent: mapPullRequestAction" {
    try std.testing.expectEqual(mapPullRequestAction("opened"), .act);
    try std.testing.expectEqual(mapPullRequestAction("merged"), .success);
    try std.testing.expectEqual(mapPullRequestAction("unknown"), .observe);
}

test "gamma_agent: GammaAgent init" {
    const agent = GammaAgent.init("http://localhost:8080");
    try std.testing.expectEqualStrings(agent.queen_url, "http://localhost:8080");
    try std.testing.expectEqualStrings(agent.agent_name, "gamma");
}
