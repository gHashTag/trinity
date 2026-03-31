// @origin(manual) @regen(pending)
// ═════════════════════════════════════════════════════════════════════════════
// GITHUB WEBHOOK HANDLER — Receives GitHub events and creates Queen episodes
// ═════════════════════════════════════════════════════════════════════════════
//
// HTTP endpoint: POST /webhooks/github
// Content-Type: application/json
// Secret: X-Hub-Signature-256 header verification
//
// φ² + 1/φ² = 3 = TRININITY
// ═════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const queen_bridge = @import("queen_bridge.zig");

pub const GithubWebhook = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) GithubWebhook {
        return .{ .allocator = allocator };
    }

    /// Parse GitHub webhook payload and create appropriate Queen episode
    pub fn handleEvent(self: *GithubWebhook, payload: []const u8) !void {
        const event = try parseWebhookEvent(self.allocator, payload);

        switch (event) {
            .issue_opened => |ev| {
                try queen_bridge.logGitHubIssueStart(
                    self.allocator,
                    "gamma",
                    ev.issue_number,
                    ev.title,
                    ev.labels,
                );
                std.debug.print("γ: Issue #{d} opened: {s}\n", .{ ev.issue_number, ev.title });
            },
            .issue_comment => |ev| {
                try queen_bridge.logGitHubIssueStep(
                    self.allocator,
                    "gamma",
                    ev.issue_number,
                    ev.comment_body,
                    &[_][]const u8{},
                );
                std.debug.print("γ: Comment on issue #{d}\n", .{ev.issue_number});
            },
            .issue_closed => |ev| {
                try queen_bridge.logGitHubIssueComplete(
                    self.allocator,
                    "gamma",
                    ev.issue_number,
                    "closed",
                    ev.files_changed,
                    ev.duration_sec,
                );
                std.debug.print("γ: Issue #{d} closed\n", .{ ev.issue_number });
            },
            .unknown => {
                std.debug.print("γ: Unknown webhook event\n", .{});
            },
        }
    }
};

// ═════════════════════════════════════════════════════════════════════════════
// WEBHOOK EVENT TYPES
// ═════════════════════════════════════════════════════════════════════════════

pub const WebhookEvent = union(enum) {
    issue_opened: IssueOpenedEvent,
    issue_comment: IssueCommentEvent,
    issue_closed: IssueClosedEvent,
    unknown,

    pub const IssueOpenedEvent = struct {
        issue_number: u32,
        title: []const u8,
        labels: [][]const u8,
    };

    pub const IssueCommentEvent = struct {
        issue_number: u32,
        comment_body: []const u8,
    };

    pub const IssueClosedEvent = struct {
        issue_number: u32,
        files_changed: u32,
        duration_sec: u32,
    };
};

/// Parse GitHub webhook payload (simplified JSON parser)
fn parseWebhookEvent(allocator: Allocator, payload: []const u8) !WebhookEvent {
    // Extract "action" field
    const action_idx = std.mem.indexOf(u8, payload, "\"action\":") orelse return WebhookEvent.unknown;
    const action_start = action_idx + 10;
    const action_end = std.mem.indexOfPos(u8, payload, action_start, "\"") orelse payload.len;
    const action = payload[action_start..action_end];

    // Check for issue
    if (std.mem.indexOf(u8, payload, "\"issue\"") != null) {
        const number_idx = std.mem.indexOf(u8, payload, "\"number\":") orelse return WebhookEvent.unknown;
        const number_start = number_idx + 10;
        var number_end = number_start;
        while (number_end < payload.len and payload[number_end] >= '0' and payload[number_end] <= '9') : (number_end += 1) {}
        const issue_number = std.fmt.parseInt(u32, payload[number_start..number_end], 10) catch 0;

        const title_idx = std.mem.indexOf(u8, payload, "\"title\":") orelse return WebhookEvent.unknown;
        const title_start = title_idx + 10;
        const title_end = std.mem.indexOfPos(u8, payload, title_start, "\"") orelse payload.len;
        const title = payload[title_start..title_end];

        // Parse labels array - direct allocation for simplicity
        var label_ptrs: [10][]const u8 = undefined; // max 10 labels
        var label_count: usize = 0;

        const labels_idx = std.mem.indexOf(u8, payload, "\"labels\":") orelse return WebhookEvent.unknown;
        {
            var label_start = labels_idx + 10;
            while (label_start < payload.len and label_count < label_ptrs.len) : (label_start += 1) {
                if (payload[label_start] == '"') {
                    label_start += 1;
                    const label_end = std.mem.indexOfPos(u8, payload, label_start, "\"") orelse break;
                    if (label_end > label_start) {
                        label_ptrs[label_count] = payload[label_start..label_end];
                        label_count += 1;
                        label_start = label_end + 1;
                    }
                } else if (payload[label_start] == ']') {
                    break;
                }
            }
        }

        const labels = try allocator.alloc([]const u8, label_count);
        for (label_ptrs[0..label_count], 0..) |label, i| {
            labels[i] = label;
        }

        // Map action to event type
        if (std.mem.eql(u8, action, "opened") or std.mem.eql(u8, action, "reopened")) {
            return WebhookEvent{
                .issue_opened = .{
                    .issue_number = issue_number,
                    .title = title,
                    .labels = labels,
                },
            };
        }

        if (std.mem.eql(u8, action, "closed")) {
            return WebhookEvent{
                .issue_closed = .{
                    .issue_number = issue_number,
                    .files_changed = 0, // TODO: extract from PR
                    .duration_sec = 0,  // TODO: calculate from opened timestamp
                },
            };
        }
    }

    // Check for comment
    if (std.mem.indexOf(u8, payload, "\"comment\"") != null) {
        const number_idx = std.mem.indexOf(u8, payload, "\"number\":") orelse return WebhookEvent.unknown;
        const number_start = number_idx + 10;
        var number_end = number_start;
        while (number_end < payload.len and payload[number_end] >= '0' and payload[number_end] <= '9') : (number_end += 1) {}
        const issue_number = std.fmt.parseInt(u32, payload[number_start..number_end], 10) catch 0;

        const body_idx = std.mem.indexOf(u8, payload, "\"body\":") orelse return WebhookEvent.unknown;
        const body_start = body_idx + 8;
        const body_end = std.mem.indexOfPos(u8, payload, body_start, "\"") orelse payload.len;
        const comment_body = payload[body_start..body_end];

        return WebhookEvent{
            .issue_comment = .{
                .issue_number = issue_number,
                .comment_body = comment_body,
            },
        };
    }

    return WebhookEvent.unknown;
}

// ═════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════

test "github_webhook: parse issue opened" {
    const payload = "{\"action\":\"opened\",\"issue\":{\"number\":477,\"title\":\"Test\",\"labels\":[\"feature\",\"fpga\"]}}";
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var handler = GithubWebhook.init(allocator);
    try handler.handleEvent(payload);

    // Check episode was created
    const file = try std.fs.cwd().openFile(".trinity/logs/agent-gamma.jsonl", .{});
    defer file.close();
    const content = try file.readToEndAlloc(allocator, 1_000_000);
    defer allocator.free(content);
    try std.testing.expect(content.len > 0);
}
