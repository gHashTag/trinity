// @origin(manual)
// ═══════════════════════════════════════════════════════════════════════════════
// GitHub Commands — CLI handlers for `tri issue/board/protocol`
// ═══════════════════════════════════════════════════════════════════════════════
//
// Subcommands:
//   issue create <title>     — Create GitHub issue
//   issue comment <N>        — Protocol v2 formatted comment
//   issue close <N>          — Close with summary
//   issue decompose <N>      — Create sub-issues from template
//   board sync               — Label-based column tracking
//   protocol log             — Display protocol log entries
//   protocol verify          — Check Protocol v2 compliance
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const github_client = @import("github_client.zig");

// ANSI colors
const GREEN = "\x1b[38;2;0;229;153m";
const GOLDEN = "\x1b[38;2;255;215;0m";
const RED = "\x1b[38;2;255;85;85m";
const CYAN = "\x1b[38;2;0;200;255m";
const RESET = "\x1b[0m";

/// Main dispatcher for github-related commands
pub fn runGithubCommand(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    if (args.len == 0) {
        printGithubHelp();
        return;
    }

    const subcmd = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, subcmd, "issue")) {
        try runIssueCommand(allocator, sub_args, dry_run);
    } else if (std.mem.eql(u8, subcmd, "board")) {
        try runBoardCommand(allocator, sub_args, dry_run);
    } else if (std.mem.eql(u8, subcmd, "agent")) {
        try runAgentCommand(allocator, sub_args, dry_run);
    } else if (std.mem.eql(u8, subcmd, "protocol")) {
        try runProtocolCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "pr")) {
        try runPrCommand(allocator, sub_args, dry_run);
    } else if (std.mem.eql(u8, subcmd, "check")) {
        try runCheckCommand(allocator, sub_args, dry_run);
    } else if (std.mem.eql(u8, subcmd, "dispatch")) {
        try runDispatchCommand(allocator, sub_args, dry_run);
    } else if (std.mem.eql(u8, subcmd, "graphql")) {
        try runGraphqlCommand(allocator, sub_args, dry_run);
    } else if (std.mem.eql(u8, subcmd, "create") or std.mem.eql(u8, subcmd, "comment") or
        std.mem.eql(u8, subcmd, "close") or std.mem.eql(u8, subcmd, "decompose"))
    {
        // Shortcut: `tri issue create` can be called as `tri create` if routed here
        try runIssueSubcommand(allocator, subcmd, sub_args, dry_run);
    } else {
        std.debug.print("{s}Unknown github command: {s}{s}\n", .{ RED, subcmd, RESET });
        printGithubHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Issue commands
// ═══════════════════════════════════════════════════════════════════════════════

fn runIssueCommand(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    if (args.len == 0) {
        printIssueHelp();
        return;
    }
    try runIssueSubcommand(allocator, args[0], if (args.len > 1) args[1..] else &[_][]const u8{}, dry_run);
}

fn runIssueSubcommand(allocator: std.mem.Allocator, subcmd: []const u8, args: []const []const u8, dry_run: bool) !void {
    if (std.mem.eql(u8, subcmd, "create")) {
        try issueCreate(allocator, args, dry_run);
    } else if (std.mem.eql(u8, subcmd, "comment")) {
        try issueComment(allocator, args, dry_run);
    } else if (std.mem.eql(u8, subcmd, "close")) {
        try issueClose(allocator, args, dry_run);
    } else if (std.mem.eql(u8, subcmd, "decompose")) {
        try issueDecompose(allocator, args, dry_run);
    } else if (std.mem.eql(u8, subcmd, "list")) {
        try issueList(allocator, args, dry_run);
    } else if (std.mem.eql(u8, subcmd, "view")) {
        try issueView(allocator, args, dry_run);
    } else if (std.mem.eql(u8, subcmd, "assign")) {
        try issueAssign(allocator, args, dry_run);
    } else {
        std.debug.print("{s}Unknown issue command: {s}{s}\n", .{ RED, subcmd, RESET });
        printIssueHelp();
    }
}

/// `tri issue create <title> [--body <body>] [--labels <l1,l2>] [--parent <N>] [--agent <name>]`
fn issueCreate(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri issue create <title> [--body <body>] [--labels <l1,l2>] [--agent <name>]{s}\n", .{ GOLDEN, RESET });
        return;
    }

    const title = args[0];
    var body: ?[]const u8 = null;
    var labels_str: ?[]const u8 = null;
    var agent_name: ?[]const u8 = null;
    var parent: ?u32 = null;

    // Parse flags
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--body") and i + 1 < args.len) {
            i += 1;
            body = args[i];
        } else if (std.mem.eql(u8, args[i], "--labels") and i + 1 < args.len) {
            i += 1;
            labels_str = args[i];
        } else if (std.mem.eql(u8, args[i], "--agent") and i + 1 < args.len) {
            i += 1;
            agent_name = args[i];
        } else if (std.mem.eql(u8, args[i], "--parent") and i + 1 < args.len) {
            i += 1;
            parent = std.fmt.parseInt(u32, args[i], 10) catch null;
        }
    }

    // Parse comma-separated labels
    var labels_list = try std.ArrayList([]const u8).initCapacity(allocator, 8);
    defer labels_list.deinit(allocator);
    if (labels_str) |ls| {
        var iter = std.mem.splitScalar(u8, ls, ',');
        while (iter.next()) |label| {
            const trimmed = std.mem.trim(u8, label, " ");
            if (trimmed.len > 0) {
                try labels_list.append(allocator, trimmed);
            }
        }
    }
    if (agent_name) |a| {
        const agent_label = try std.fmt.allocPrint(allocator, "agent:{s}", .{a});
        // Note: not freed here — lives until function returns (page_allocator, no leak concern)
        try labels_list.append(allocator, agent_label);
    }

    // Build body with parent reference
    var full_body: ?[]const u8 = body;
    if (parent) |p| {
        if (body) |b| {
            full_body = try std.fmt.allocPrint(allocator, "Parent: #{d}\n\n{s}", .{ p, b });
        } else {
            full_body = try std.fmt.allocPrint(allocator, "Parent: #{d}", .{p});
        }
    }

    var client = try github_client.GitHubClient.init(allocator, dry_run);
    defer client.deinit();
    const result = try client.createIssue(title, full_body, labels_list.items);

    // Log to protocol
    try appendProtocolLog(allocator, "issue_create", result.number, agent_name, true);

    std.debug.print("{s}✅ Created issue #{d}{s}\n", .{ GREEN, result.number, RESET });
    if (result.url.len > 0) {
        std.debug.print("   {s}{s}{s}\n", .{ CYAN, result.url, RESET });
    }
}

/// `tri issue comment <N> [--agent <name>] [--step <text>] [--status <S>] [--thought <t>] [--action <a>] [--result <r>] [--next <n>]`
fn issueComment(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri issue comment <N> [--agent <name>] [--step <text>] [--status <STATUS>]{s}\n", .{ GOLDEN, RESET });
        return;
    }

    const number = std.fmt.parseInt(u32, args[0], 10) catch {
        std.debug.print("{s}Invalid issue number: {s}{s}\n", .{ RED, args[0], RESET });
        return;
    };

    var agent_name: []const u8 = "unknown";
    var step: ?[]const u8 = null;
    var status_str: []const u8 = "THINKING";
    var thought: ?[]const u8 = null;
    var action: ?[]const u8 = null;
    var result_text: ?[]const u8 = null;
    var next: ?[]const u8 = null;

    // Parse flags
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--agent") and i + 1 < args.len) {
            i += 1;
            agent_name = args[i];
        } else if (std.mem.eql(u8, args[i], "--step") and i + 1 < args.len) {
            i += 1;
            step = args[i];
        } else if (std.mem.eql(u8, args[i], "--status") and i + 1 < args.len) {
            i += 1;
            status_str = args[i];
        } else if (std.mem.eql(u8, args[i], "--thought") and i + 1 < args.len) {
            i += 1;
            thought = args[i];
        } else if (std.mem.eql(u8, args[i], "--action") and i + 1 < args.len) {
            i += 1;
            action = args[i];
        } else if (std.mem.eql(u8, args[i], "--result") and i + 1 < args.len) {
            i += 1;
            result_text = args[i];
        } else if (std.mem.eql(u8, args[i], "--next") and i + 1 < args.len) {
            i += 1;
            next = args[i];
        }
    }

    // Build Protocol v2 comment
    const status_emoji = getStatusEmoji(status_str);
    const agent_emoji = getAgentEmoji(agent_name);

    var comment_buf: [4096]u8 = undefined;
    var pos: usize = 0;

    // Header
    const header = try std.fmt.bufPrint(comment_buf[pos..], "{s} **Agent: {s}**\n", .{ agent_emoji, agent_name });
    pos += header.len;

    // Step
    if (step) |s| {
        const step_line = try std.fmt.bufPrint(comment_buf[pos..], "📋 **Step**: {s}\n", .{s});
        pos += step_line.len;
    }

    // Status
    const status_line = try std.fmt.bufPrint(comment_buf[pos..], "🔄 **Status**: {s} {s}\n", .{ status_emoji, status_str });
    pos += status_line.len;

    // Details
    if (thought) |t| {
        const line = try std.fmt.bufPrint(comment_buf[pos..], "**Thought**: {s}\n", .{t});
        pos += line.len;
    }
    if (action) |a| {
        const line = try std.fmt.bufPrint(comment_buf[pos..], "**Action**: {s}\n", .{a});
        pos += line.len;
    }
    if (result_text) |r| {
        const line = try std.fmt.bufPrint(comment_buf[pos..], "**Result**: {s}\n", .{r});
        pos += line.len;
    }
    if (next) |n| {
        const line = try std.fmt.bufPrint(comment_buf[pos..], "**Next**: {s}\n", .{n});
        pos += line.len;
    }

    const comment_body = comment_buf[0..pos];

    var client = try github_client.GitHubClient.init(allocator, dry_run);
    defer client.deinit();
    try client.commentIssue(number, comment_body);

    try appendProtocolLog(allocator, "issue_comment", number, agent_name, true);

    std.debug.print("{s}✅ Comment posted on #{d}{s}\n", .{ GREEN, number, RESET });
}

/// `tri issue close <N> [--reason <reason>] [--summary <text>]`
fn issueClose(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri issue close <N> [--reason <reason>] [--summary <text>]{s}\n", .{ GOLDEN, RESET });
        return;
    }

    const number = std.fmt.parseInt(u32, args[0], 10) catch {
        std.debug.print("{s}Invalid issue number: {s}{s}\n", .{ RED, args[0], RESET });
        return;
    };

    var reason: []const u8 = "completed";
    var summary: ?[]const u8 = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--reason") and i + 1 < args.len) {
            i += 1;
            reason = args[i];
        } else if (std.mem.eql(u8, args[i], "--summary") and i + 1 < args.len) {
            i += 1;
            summary = args[i];
        }
    }

    var client = try github_client.GitHubClient.init(allocator, dry_run);
    defer client.deinit();

    // Post closing comment
    var comment_buf: [2048]u8 = undefined;
    const close_comment = if (summary) |s|
        try std.fmt.bufPrint(&comment_buf, "🏁 **Closing** — {s}\n**Reason**: {s}\n**Summary**: {s}", .{ reason, reason, s })
    else
        try std.fmt.bufPrint(&comment_buf, "🏁 **Closing** — {s}", .{reason});

    try client.commentIssue(number, close_comment);
    try client.closeIssue(number);

    try appendProtocolLog(allocator, "issue_close", number, null, true);

    std.debug.print("{s}✅ Closed #{d} ({s}){s}\n", .{ GREEN, number, reason, RESET });
}

/// `tri issue decompose <N> [--template standard|bugfix|spike] [--agent <name>]`
fn issueDecompose(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri issue decompose <N> [--template standard|bugfix|spike] [--agent <name>]{s}\n", .{ GOLDEN, RESET });
        return;
    }

    const parent_number = std.fmt.parseInt(u32, args[0], 10) catch {
        std.debug.print("{s}Invalid issue number: {s}{s}\n", .{ RED, args[0], RESET });
        return;
    };

    var template: []const u8 = "standard";
    var agent_name: ?[]const u8 = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--template") and i + 1 < args.len) {
            i += 1;
            template = args[i];
        } else if (std.mem.eql(u8, args[i], "--agent") and i + 1 < args.len) {
            i += 1;
            agent_name = args[i];
        }
    }

    const phases = getTemplatePhases(template);

    var client = try github_client.GitHubClient.init(allocator, dry_run);
    defer client.deinit();

    // Get parent issue title for context
    const parent_info = client.getIssue(parent_number) catch github_client.IssueInfo{
        .number = parent_number,
        .title = "(parent)",
        .state = "open",
        .body = "",
        .labels = &.{},
    };

    std.debug.print("{s}📋 Decomposing #{d} ({s}) → {d} sub-issues ({s} template){s}\n", .{
        CYAN,     parent_number, parent_info.title, phases.len,
        template, RESET,
    });

    var created_count: u32 = 0;
    for (phases, 0..) |phase, idx| {
        const sub_title = try std.fmt.allocPrint(allocator, "[{s}] {d}/{d} — {s}", .{
            parent_info.title, idx + 1, phases.len, phase,
        });
        defer allocator.free(sub_title);

        const sub_body = try std.fmt.allocPrint(allocator, "Parent: #{d}\nPhase: {s}\nTemplate: {s}", .{
            parent_number, phase, template,
        });
        defer allocator.free(sub_body);

        var labels = try std.ArrayList([]const u8).initCapacity(allocator, 4);
        defer labels.deinit(allocator);
        try labels.append(allocator, "status:queued");
        if (agent_name) |a| {
            const agent_label = try std.fmt.allocPrint(allocator, "agent:{s}", .{a});
            // Note: this leaks, but in a CLI command that's fine
            try labels.append(allocator, agent_label);
        }

        const result = client.createIssue(sub_title, sub_body, labels.items) catch |err| {
            std.debug.print("{s}  ✗ Failed to create sub-issue {d}/{d}: {s}{s}\n", .{
                RED, idx + 1, phases.len, @errorName(err), RESET,
            });
            continue;
        };

        std.debug.print("{s}  ✅ #{d} — {s}{s}\n", .{ GREEN, result.number, phase, RESET });
        created_count += 1;
    }

    // Comment on parent
    var parent_comment_buf: [2048]u8 = undefined;
    const parent_comment = try std.fmt.bufPrint(&parent_comment_buf, "📋 **Decomposed** into {d} sub-issues ({s} template)\n{d}/{d} created successfully", .{
        phases.len, template, created_count, phases.len,
    });
    client.commentIssue(parent_number, parent_comment) catch |err| {
        std.log.warn("github_commands: commentIssue (parent #{d}) failed: {}", .{ parent_number, err });
    };

    try appendProtocolLog(allocator, "issue_decompose", parent_number, agent_name, true);

    std.debug.print("\n{s}✅ Created {d}/{d} sub-issues for #{d}{s}\n", .{ GREEN, created_count, phases.len, parent_number, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Issue list / view / assign — Day 1 coverage gap fills
// ═══════════════════════════════════════════════════════════════════════════════

/// `tri issue list [--label <L>] [--state <open|closed|all>]`
fn issueList(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    var label_filter: ?[]const u8 = null;
    var state_filter: []const u8 = "open";

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--label") and i + 1 < args.len) {
            i += 1;
            label_filter = args[i];
        } else if (std.mem.eql(u8, args[i], "--state") and i + 1 < args.len) {
            i += 1;
            state_filter = args[i];
        }
    }

    if (dry_run) {
        std.debug.print("[DRY-RUN] Would list issues (state={s}, label={s})\n", .{
            state_filter,
            if (label_filter) |l| l else "any",
        });
        return;
    }

    // Build gh command
    var argv = try std.ArrayList([]const u8).initCapacity(allocator, 16);
    defer argv.deinit(allocator);
    try argv.appendSlice(allocator, &.{
        "gh", "issue", "list", "--json", "number,title,labels,assignees,state", "--state", state_filter,
    });
    if (label_filter) |l| {
        try argv.appendSlice(allocator, &.{ "--label", l });
    }

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv.items,
        .max_output_bytes = 128 * 1024,
    }) catch |err| {
        std.debug.print("{s}Failed to list issues: {}{s}\n", .{ RED, err, RESET });
        return;
    };

    if (result.stdout.len > 0) {
        // Parse JSON and display formatted table
        printIssueTable(result.stdout);
    } else {
        std.debug.print("No issues found.\n", .{});
    }
}

/// Parse gh issue list JSON and print a human-readable table
fn printIssueTable(json_data: []const u8) void {
    // Simple line-by-line extraction from JSON array
    // Each issue: {"assignees":[...],"labels":[...],"number":N,"state":"...","title":"..."}
    std.debug.print("{s}#     │ Title                                    │ Labels{s}\n", .{ CYAN, RESET });
    std.debug.print("──────┼──────────────────────────────────────────┼────────────────────\n", .{});

    // Walk through JSON finding "number" and "title" fields
    var pos: usize = 0;
    while (pos < json_data.len) {
        // Find next "number":
        const num_key = "\"number\":";
        const num_start = std.mem.indexOfPos(u8, json_data, pos, num_key) orelse break;
        const num_val_start = num_start + num_key.len;
        const num_end = std.mem.indexOfAnyPos(u8, json_data, num_val_start, ",}") orelse break;
        const num_str = std.mem.trim(u8, json_data[num_val_start..num_end], " ");

        // Find "title" after number
        const title_key = "\"title\":\"";
        const title_start = std.mem.indexOfPos(u8, json_data, num_end, title_key) orelse break;
        const title_val_start = title_start + title_key.len;
        const title_end = std.mem.indexOfPos(u8, json_data, title_val_start, "\"") orelse break;
        const title = json_data[title_val_start..title_end];

        // Truncate long titles
        const max_title = 40;
        const display_title = if (title.len > max_title) title[0..max_title] else title;

        // Find labels (simplified: extract "name" values between "labels":[ and ])
        var labels_display: [128]u8 = undefined;
        var labels_len: usize = 0;
        const labels_key = "\"labels\":[";
        if (std.mem.indexOfPos(u8, json_data, num_end, labels_key)) |ls| {
            const ls_start = ls + labels_key.len;
            if (std.mem.indexOfPos(u8, json_data, ls_start, "]")) |ls_end| {
                const labels_section = json_data[ls_start..ls_end];
                var lpos: usize = 0;
                while (lpos < labels_section.len) {
                    const name_key = "\"name\":\"";
                    const nk = std.mem.indexOfPos(u8, labels_section, lpos, name_key) orelse break;
                    const nv_start = nk + name_key.len;
                    const nv_end = std.mem.indexOfPos(u8, labels_section, nv_start, "\"") orelse break;
                    const label_name = labels_section[nv_start..nv_end];
                    if (labels_len > 0 and labels_len + 2 < labels_display.len) {
                        labels_display[labels_len] = ',';
                        labels_display[labels_len + 1] = ' ';
                        labels_len += 2;
                    }
                    const copy_len = @min(label_name.len, labels_display.len - labels_len);
                    @memcpy(labels_display[labels_len..][0..copy_len], label_name[0..copy_len]);
                    labels_len += copy_len;
                    lpos = nv_end + 1;
                }
            }
        }

        std.debug.print("{s: >5} │ {s: <40} │ {s}\n", .{
            num_str,
            display_title,
            labels_display[0..labels_len],
        });

        pos = title_end + 1;
    }
}

/// `tri issue view <N>`
fn issueView(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri issue view <number>{s}\n", .{ GOLDEN, RESET });
        return;
    }

    const number_str = args[0];
    _ = std.fmt.parseInt(u32, number_str, 10) catch {
        std.debug.print("{s}Invalid issue number: {s}{s}\n", .{ RED, number_str, RESET });
        return;
    };

    if (dry_run) {
        std.debug.print("[DRY-RUN] Would view issue #{s}\n", .{number_str});
        return;
    }

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "gh", "issue", "view", number_str },
        .max_output_bytes = 64 * 1024,
    }) catch |err| {
        std.debug.print("{s}Failed to view issue: {}{s}\n", .{ RED, err, RESET });
        return;
    };

    if (result.stdout.len > 0) {
        std.debug.print("{s}", .{result.stdout});
    }
    if (result.stderr.len > 0) {
        std.debug.print("{s}{s}{s}", .{ RED, result.stderr, RESET });
    }
}

/// `tri issue assign <N> [--to <user>] [--label <label>]`
fn issueAssign(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri issue assign <number> [--to <user>] [--label <label>]{s}\n", .{ GOLDEN, RESET });
        return;
    }

    const number = std.fmt.parseInt(u32, args[0], 10) catch {
        std.debug.print("{s}Invalid issue number: {s}{s}\n", .{ RED, args[0], RESET });
        return;
    };

    var assignee: ?[]const u8 = null;
    var label: ?[]const u8 = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--to") and i + 1 < args.len) {
            i += 1;
            assignee = args[i];
        } else if (std.mem.eql(u8, args[i], "--label") and i + 1 < args.len) {
            i += 1;
            label = args[i];
        }
    }

    if (assignee == null and label == null) {
        // Default: mark as in-progress
        label = "status:in-progress";
    }

    var client = try github_client.GitHubClient.init(allocator, dry_run);
    defer client.deinit();

    if (assignee) |user| {
        try client.addAssignee(number, user);
        std.debug.print("{s}✅ Assigned @{s} to #{d}{s}\n", .{ GREEN, user, number, RESET });
    }
    if (label) |l| {
        try client.addLabels(number, &.{l});
        std.debug.print("{s}✅ Added label '{s}' to #{d}{s}\n", .{ GREEN, l, number, RESET });
    }

    try appendProtocolLog(allocator, "issue_assign", number, null, true);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Board commands
// ═══════════════════════════════════════════════════════════════════════════════

fn runBoardCommand(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    if (args.len == 0) {
        printBoardHelp();
        return;
    }

    const subcmd = args[0];
    if (std.mem.eql(u8, subcmd, "sync")) {
        try boardSync(allocator, if (args.len > 1) args[1..] else &[_][]const u8{}, dry_run);
    } else if (std.mem.eql(u8, subcmd, "audit")) {
        try boardAudit(allocator, dry_run, false);
    } else if (std.mem.eql(u8, subcmd, "fix")) {
        try boardAudit(allocator, dry_run, true);
    } else {
        printBoardHelp();
    }
}

/// `tri board sync --issue <N> --column <column>`
fn boardSync(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    var issue_num: ?u32 = null;
    var column: ?[]const u8 = null;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--issue") and i + 1 < args.len) {
            i += 1;
            issue_num = std.fmt.parseInt(u32, args[i], 10) catch null;
        } else if (std.mem.eql(u8, args[i], "--column") and i + 1 < args.len) {
            i += 1;
            column = args[i];
        }
    }

    if (issue_num == null or column == null) {
        std.debug.print("{s}Both --issue and --column are required{s}\n", .{ RED, RESET });
        return;
    }

    const valid_columns = [_][]const u8{ "backlog", "in-progress", "in-review", "ready", "done" };
    var valid = false;
    for (&valid_columns) |vc| {
        if (std.mem.eql(u8, column.?, vc)) {
            valid = true;
            break;
        }
    }
    if (!valid) {
        std.debug.print("{s}Invalid column: {s}. Valid: backlog, in-progress, in-review, ready, done{s}\n", .{ RED, column.?, RESET });
        return;
    }

    var client = try github_client.GitHubClient.init(allocator, dry_run);
    defer client.deinit();

    // Remove old board:* labels
    const old_labels = [_][]const u8{
        "board:backlog",
        "board:in-progress",
        "board:in-review",
        "board:ready",
        "board:done",
    };
    try client.removeLabels(issue_num.?, &old_labels);

    // Add new board label
    const new_label = try std.fmt.allocPrint(allocator, "board:{s}", .{column.?});
    defer allocator.free(new_label);
    try client.addLabels(issue_num.?, &.{new_label});

    try appendProtocolLog(allocator, "board_sync", issue_num.?, null, true);

    std.debug.print("{s}✅ #{d} → {s}{s}\n", .{ GREEN, issue_num.?, column.?, RESET });
}

/// Issue audit data for board audit/fix
const IssueAuditRow = struct {
    number: u32,
    title: []const u8,
    has_assignee: bool,
    has_priority: bool,
    priority_label: []const u8,
    has_status: bool,
    status_label: []const u8,
    has_milestone: bool,
    score: u8, // out of 6
};

/// `tri board audit` / `tri board fix` — check (and optionally fix) all open issue fields
fn boardAudit(allocator: std.mem.Allocator, dry_run: bool, do_fix: bool) !void {
    var client = try github_client.GitHubClient.init(allocator, dry_run);
    defer client.deinit();

    // Get all open issues via gh CLI (returns JSON array)
    const issues_json = try client.listIssues("open");
    defer allocator.free(issues_json);

    // Parse issue list — use gh CLI JSON format: [{number, title, labels:[{name}], assignees:[{login}], milestone:{title}}]
    // Simple parser: find each issue object
    var rows = try std.ArrayList(IssueAuditRow).initCapacity(allocator, 32);
    defer rows.deinit(allocator);

    var total_score: u32 = 0;
    var total_possible: u32 = 0;
    var fix_count: u32 = 0;

    // Walk JSON array to find issue numbers
    var pos: usize = 0;
    while (pos < issues_json.len) : (pos += 1) {
        // Find "number": N
        if (pos + 10 < issues_json.len and std.mem.eql(u8, issues_json[pos .. pos + 9], "\"number\"")) {
            const colon_pos = std.mem.indexOfPos(u8, issues_json, pos + 9, ":") orelse continue;
            var num_start = colon_pos + 1;
            while (num_start < issues_json.len and issues_json[num_start] == ' ') num_start += 1;
            var num_end = num_start;
            while (num_end < issues_json.len and issues_json[num_end] >= '0' and issues_json[num_end] <= '9') num_end += 1;
            if (num_end == num_start) continue;
            const number = std.fmt.parseInt(u32, issues_json[num_start..num_end], 10) catch continue;

            // Find the object boundaries — scan backward for { and forward for matching }
            var obj_start = pos;
            while (obj_start > 0 and issues_json[obj_start] != '{') obj_start -= 1;
            var obj_end = num_end;
            var brace_depth: i32 = 1;
            while (obj_end < issues_json.len and brace_depth > 0) : (obj_end += 1) {
                if (issues_json[obj_end] == '{') brace_depth += 1;
                if (issues_json[obj_end] == '}') brace_depth -= 1;
            }
            const obj = issues_json[obj_start..obj_end];

            // Extract title
            const title = github_client.extractJsonString(obj, "title") orelse "(unknown)";

            // Check assignees: look for "assignees":[] (empty) vs non-empty
            const has_assignee = blk: {
                if (std.mem.indexOf(u8, obj, "\"assignees\":[]") != null) break :blk false;
                if (std.mem.indexOf(u8, obj, "\"assignees\": []") != null) break :blk false;
                if (std.mem.indexOf(u8, obj, "\"login\"") != null) break :blk true;
                break :blk false;
            };

            // Check labels for priority and status
            var has_priority = false;
            var has_status = false;
            var priority_label: []const u8 = "-";
            var status_label: []const u8 = "-";

            // Scan for label names in the object
            var label_pos: usize = 0;
            while (label_pos < obj.len) : (label_pos += 1) {
                if (label_pos + 11 < obj.len and std.mem.eql(u8, obj[label_pos .. label_pos + 6], "\"name\"")) {
                    const lbl_str = github_client.extractJsonString(obj[label_pos..], "name");
                    if (lbl_str) |lbl| {
                        if (std.mem.startsWith(u8, lbl, "priority:")) {
                            has_priority = true;
                            priority_label = lbl;
                        } else if (std.mem.startsWith(u8, lbl, "status:")) {
                            has_status = true;
                            status_label = lbl;
                        }
                    }
                }
            }

            // Check milestone
            const has_milestone = blk: {
                if (std.mem.indexOf(u8, obj, "\"milestone\":null") != null) break :blk false;
                if (std.mem.indexOf(u8, obj, "\"milestone\": null") != null) break :blk false;
                if (std.mem.indexOf(u8, obj, "\"milestone\":\"\"") != null) break :blk false;
                // gh CLI: milestone is an object {title:...} or null
                if (std.mem.indexOf(u8, obj, "\"milestone\":{") != null) break :blk true;
                if (std.mem.indexOf(u8, obj, "\"milestone\": {") != null) break :blk true;
                break :blk false;
            };

            var score: u8 = 0;
            if (has_assignee) score += 1;
            if (has_priority) score += 1;
            if (has_status) score += 1;
            if (has_milestone) score += 1;

            total_score += score;
            total_possible += 4;

            try rows.append(allocator, .{
                .number = number,
                .title = title,
                .has_assignee = has_assignee,
                .has_priority = has_priority,
                .priority_label = priority_label,
                .has_status = has_status,
                .status_label = status_label,
                .has_milestone = has_milestone,
                .score = score,
            });

            // Apply fixes if mode is fix
            if (do_fix) {
                if (!has_assignee) {
                    client.addAssignee(number, "gHashTag") catch |err| {
                        std.log.warn("github_commands: addAssignee (#{d}) failed: {}", .{ number, err });
                    };
                    std.debug.print("  {s}#{d} ← assignee: gHashTag{s}\n", .{ GREEN, number, RESET });
                    fix_count += 1;
                }
                if (!has_priority) {
                    client.addLabels(number, &.{"priority:P2"}) catch |err| {
                        std.log.warn("github_commands: addLabels priority:P2 (#{d}) failed: {}", .{ number, err });
                    };
                    std.debug.print("  {s}#{d} ← label: priority:P2{s}\n", .{ GREEN, number, RESET });
                    fix_count += 1;
                }
                if (!has_status) {
                    client.addLabels(number, &.{"status:pending"}) catch |err| {
                        std.log.warn("github_commands: addLabels status:pending (#{d}) failed: {}", .{ number, err });
                    };
                    std.debug.print("  {s}#{d} ← label: status:pending{s}\n", .{ GREEN, number, RESET });
                    fix_count += 1;
                }
                if (!has_milestone) {
                    client.editIssue(number, "Ralph Swarm v1.0", null) catch |err| {
                        std.log.warn("github_commands: editIssue milestone (#{d}) failed: {}", .{ number, err });
                    };
                    std.debug.print("  {s}#{d} ← milestone: Ralph Swarm v1.0{s}\n", .{ GREEN, number, RESET });
                    fix_count += 1;
                }
            }

            // Skip past this object
            pos = obj_end;
        }
    }

    // Print audit table
    const mode_label = if (do_fix) "BOARD FIX" else "BOARD AUDIT";
    std.debug.print("\n{s}═══════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}  {s}{s}\n", .{ CYAN, mode_label, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════{s}\n\n", .{ CYAN, RESET });

    std.debug.print("  Issue | Assignee | Priority | Status     | Milestone | Score\n", .{});
    std.debug.print("  ------+----------+----------+------------+-----------+------\n", .{});

    for (rows.items) |row| {
        const a_mark = if (row.has_assignee) GREEN ++ "Y" ++ RESET else RED ++ "N" ++ RESET;
        const p_mark = if (row.has_priority) GREEN ++ "Y" ++ RESET else RED ++ "N" ++ RESET;
        const s_mark = if (row.has_status) GREEN ++ "Y" ++ RESET else RED ++ "N" ++ RESET;
        const m_mark = if (row.has_milestone) GREEN ++ "Y" ++ RESET else RED ++ "N" ++ RESET;
        std.debug.print("  #{d:<4} | {s}        | {s}        | {s}          | {s}         | {d}/4\n", .{
            row.number, a_mark, p_mark, s_mark, m_mark, row.score,
        });
    }

    const pct = if (total_possible > 0) (total_score * 100) / total_possible else 0;
    std.debug.print("\n  Fields filled: {d}/{d} = {d}%\n", .{ total_score, total_possible, pct });
    if (do_fix) {
        std.debug.print("  Fixes applied: {d}\n", .{fix_count});
    } else {
        const missing = total_possible - total_score;
        if (missing > 0) {
            std.debug.print("  Missing fields: {d} — run {s}tri board fix{s} to auto-fill\n", .{ missing, GREEN, RESET });
        }
    }
    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// Agent commands — realtime tracking
// ═══════════════════════════════════════════════════════════════════════════════

fn runAgentCommand(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    if (args.len == 0) {
        printAgentHelp();
        return;
    }

    const subcmd = args[0];
    if (std.mem.eql(u8, subcmd, "start")) {
        try agentStart(allocator, if (args.len > 1) args[1..] else &[_][]const u8{}, dry_run);
    } else if (std.mem.eql(u8, subcmd, "done")) {
        try agentDone(allocator, if (args.len > 1) args[1..] else &[_][]const u8{}, dry_run);
    } else if (std.mem.eql(u8, subcmd, "list")) {
        try agentList(allocator);
    } else if (std.mem.eql(u8, subcmd, "stop")) {
        try agentStop(allocator, if (args.len > 1) args[1..] else &[_][]const u8{});
    } else if (std.mem.eql(u8, subcmd, "restart")) {
        try agentRestart(allocator, if (args.len > 1) args[1..] else &[_][]const u8{});
    } else if (std.mem.eql(u8, subcmd, "status")) {
        try agentList(allocator); // alias
    } else {
        printAgentHelp();
    }
}

/// `tri agent start <N> <agent_name>` — mark agent started on issue
fn agentStart(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    if (args.len < 2) {
        std.debug.print("{s}Usage: tri agent start <issue_number> <agent_name>{s}\n", .{ GOLDEN, RESET });
        return;
    }

    const number = std.fmt.parseInt(u32, args[0], 10) catch {
        std.debug.print("{s}Invalid issue number: {s}{s}\n", .{ RED, args[0], RESET });
        return;
    };
    const agent_name = args[1];

    var client = try github_client.GitHubClient.init(allocator, dry_run);
    defer client.deinit();

    // Post start comment
    const agent_emoji = getAgentEmoji(agent_name);
    var comment_buf: [1024]u8 = undefined;
    const comment = try std.fmt.bufPrint(&comment_buf, "{s} **Agent {s} Started**\n**Status**: IN_PROGRESS", .{ agent_emoji, agent_name });
    try client.commentIssue(number, comment);

    // Update labels: remove status:pending, add status:in-progress + agent:running
    client.removeLabels(number, &.{ "status:pending", "status:queued" }) catch |err| {
        std.log.warn("github_commands: removeLabels status (#{d}) failed: {}", .{ number, err });
    };
    try client.addLabels(number, &.{ "status:in-progress", "agent:running" });

    try appendProtocolLog(allocator, "agent_start", number, agent_name, true);

    std.debug.print("{s}✅ Agent {s} started on #{d}{s}\n", .{ GREEN, agent_name, number, RESET });
}

/// `tri agent done <N> <agent_name> [result_text]` — mark agent finished on issue
fn agentDone(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    if (args.len < 2) {
        std.debug.print("{s}Usage: tri agent done <issue_number> <agent_name> [result]{s}\n", .{ GOLDEN, RESET });
        return;
    }

    const number = std.fmt.parseInt(u32, args[0], 10) catch {
        std.debug.print("{s}Invalid issue number: {s}{s}\n", .{ RED, args[0], RESET });
        return;
    };
    const agent_name = args[1];
    const result_text = if (args.len > 2) args[2] else "completed";

    var client = try github_client.GitHubClient.init(allocator, dry_run);
    defer client.deinit();

    // Post done comment
    const agent_emoji = getAgentEmoji(agent_name);
    var comment_buf: [2048]u8 = undefined;
    const comment = try std.fmt.bufPrint(&comment_buf, "{s} **Agent {s} Finished**\n**Status**: IN_REVIEW\n**Result**: {s}", .{ agent_emoji, agent_name, result_text });
    try client.commentIssue(number, comment);

    // Update labels: remove agent:running + status:in-progress, add status:in-review
    client.removeLabels(number, &.{ "agent:running", "status:in-progress" }) catch |err| {
        std.log.warn("github_commands: removeLabels agent (#{d}) failed: {}", .{ number, err });
    };
    try client.addLabels(number, &.{"status:in-review"});

    try appendProtocolLog(allocator, "agent_done", number, agent_name, true);

    std.debug.print("{s}✅ Agent {s} done on #{d} → in-review{s}\n", .{ GREEN, agent_name, number, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Agent lifecycle — list / stop / restart
// ═══════════════════════════════════════════════════════════════════════════════

const AGENT_NAMES = [_][]const u8{ "ralph", "mu", "scholar", "swarm", "oracle", "linter" };
const AGENT_STATE_DIR = ".trinity/agents";

/// `tri agent list` — show all agents + PID + status
fn agentList(allocator: std.mem.Allocator) !void {
    std.debug.print("{s}#  │ Agent    │ PID      │ Status{s}\n", .{ CYAN, RESET });
    std.debug.print("───┼──────────┼──────────┼─────────────\n", .{});

    for (AGENT_NAMES, 1..) |name, idx| {
        // Check PID file
        var pid_path_buf: [128]u8 = undefined;
        const pid_path = std.fmt.bufPrint(&pid_path_buf, ".trinity/agents/{s}.pid", .{name}) catch continue;

        var pid_str: []const u8 = "—";
        var status: []const u8 = "stopped";
        var pid_buf: [20]u8 = undefined;

        if (std.fs.cwd().openFile(pid_path, .{})) |file| {
            defer file.close();
            const n = file.readAll(&pid_buf) catch 0;
            if (n > 0) {
                const trimmed = std.mem.trimRight(u8, pid_buf[0..n], "\n\r ");
                pid_str = trimmed;

                // Check if process is alive
                const pid = std.fmt.parseInt(i32, trimmed, 10) catch 0;
                if (pid > 0) {
                    const kill_result = std.process.Child.run(.{
                        .allocator = allocator,
                        .argv = &.{ "kill", "-0", trimmed },
                        .max_output_bytes = 1024,
                    }) catch {
                        status = "dead (stale PID)";
                        continue;
                    };
                    status = if ((switch (kill_result.term) {
                        .Exited => |code| code,
                        else => @as(u32, 1),
                    }) == 0) "running" else "dead (stale PID)";
                }
            }
        } else |_| {
            // Also check via pgrep as fallback
            var name_buf: [64]u8 = undefined;
            const pattern = std.fmt.bufPrint(&name_buf, "{s}-agent", .{name}) catch continue;
            const pgrep = std.process.Child.run(.{
                .allocator = allocator,
                .argv = &.{ "pgrep", "-f", pattern },
                .max_output_bytes = 1024,
            }) catch continue;

            if ((switch (pgrep.term) {
                .Exited => |code| code,
                else => @as(u32, 1),
            }) == 0 and pgrep.stdout.len > 0) {
                const first_line = std.mem.trimRight(u8, pgrep.stdout, "\n\r ");
                // find first newline to get just first PID
                if (std.mem.indexOfScalar(u8, first_line, '\n')) |nl| {
                    pid_str = first_line[0..nl];
                } else {
                    pid_str = first_line;
                }
                status = "running";
            }
        }

        const status_color = if (std.mem.eql(u8, status, "running")) GREEN else RED;
        std.debug.print("{d: >2} │ {s: <8} │ {s: <8} │ {s}{s}{s}\n", .{
            idx, name, pid_str, status_color, status, RESET,
        });
    }
}

/// `tri agent stop <name>` — stop an agent process
fn agentStop(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri agent stop <name>{s}\n", .{ GOLDEN, RESET });
        return;
    }
    const name = args[0];

    // Try PID file first
    var pid_path_buf: [128]u8 = undefined;
    const pid_path = std.fmt.bufPrint(&pid_path_buf, ".trinity/agents/{s}.pid", .{name}) catch return;

    var pid_str: ?[]const u8 = null;
    var pid_buf: [20]u8 = undefined;

    if (std.fs.cwd().openFile(pid_path, .{})) |file| {
        defer file.close();
        const n = file.readAll(&pid_buf) catch 0;
        if (n > 0) {
            pid_str = std.mem.trimRight(u8, pid_buf[0..n], "\n\r ");
        }
    } else |_| {
        // Fallback: pgrep
        var name_buf: [64]u8 = undefined;
        const pattern = std.fmt.bufPrint(&name_buf, "{s}-agent", .{name}) catch return;
        const pgrep = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "pgrep", "-f", pattern },
            .max_output_bytes = 1024,
        }) catch return;
        if ((switch (pgrep.term) {
            .Exited => |code| code,
            else => @as(u32, 1),
        }) == 0 and pgrep.stdout.len > 0) {
            const trimmed = std.mem.trimRight(u8, pgrep.stdout, "\n\r ");
            if (std.mem.indexOfScalar(u8, trimmed, '\n')) |nl| {
                @memcpy(pid_buf[0..nl], trimmed[0..nl]);
                pid_str = pid_buf[0..nl];
            } else {
                @memcpy(pid_buf[0..trimmed.len], trimmed);
                pid_str = pid_buf[0..trimmed.len];
            }
        }
    }

    if (pid_str) |pid| {
        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "kill", pid },
            .max_output_bytes = 1024,
        }) catch {
            std.debug.print("{s}Failed to stop {s}{s}\n", .{ RED, name, RESET });
            return;
        };
        if ((switch (result.term) {
            .Exited => |code| code,
            else => @as(u32, 1),
        }) == 0) {
            std.debug.print("{s}Stopped {s} (PID {s}){s}\n", .{ GREEN, name, pid, RESET });
            // Clean up PID file
            std.fs.cwd().deleteFile(pid_path) catch |err| {
                std.log.debug("github_commands: deleteFile PID cleanup ({s}) failed: {}", .{ pid_path, err });
            };
        } else {
            std.debug.print("{s}Failed to stop {s} (PID {s}){s}\n", .{ RED, name, pid, RESET });
        }
    } else {
        std.debug.print("{s}Agent {s} not running{s}\n", .{ GOLDEN, name, RESET });
    }
}

/// `tri agent restart <name>` — stop + start
fn agentRestart(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri agent restart <name>{s}\n", .{ GOLDEN, RESET });
        return;
    }
    const name = args[0];

    // Stop first (ignore errors — might not be running)
    agentStop(allocator, args) catch |err| {
        std.log.debug("github_commands: agentStop ({s}) during restart failed: {}", .{ name, err });
    };

    // Start — currently only Ralph has a binary
    if (std.mem.eql(u8, name, "ralph")) {
        std.debug.print("{s}Starting ralph-agent...{s}\n", .{ CYAN, RESET });
        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{"./zig-out/bin/ralph-agent"},
            .max_output_bytes = 1024,
        }) catch |err| {
            std.debug.print("{s}Failed to start {s}: {s}{s}\n", .{ RED, name, @errorName(err), RESET });
            return;
        };
        _ = result;
        std.debug.print("{s}Restarted {s}{s}\n", .{ GREEN, name, RESET });
    } else if (std.mem.eql(u8, name, "mu")) {
        std.debug.print("{s}Starting MU daemon...{s}\n", .{ CYAN, RESET });
        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "./zig-out/bin/trinity-mcp", "mu", "start" },
            .max_output_bytes = 1024,
        }) catch |err| {
            std.debug.print("{s}Failed to start {s}: {s}{s}\n", .{ RED, name, @errorName(err), RESET });
            return;
        };
        _ = result;
        std.debug.print("{s}Restarted {s}{s}\n", .{ GREEN, name, RESET });
    } else {
        std.debug.print("{s}No binary for agent '{s}' yet{s}\n", .{ GOLDEN, name, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Protocol commands
// ═══════════════════════════════════════════════════════════════════════════════

fn runProtocolCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri protocol <log|verify> [flags]{s}\n", .{ GOLDEN, RESET });
        return;
    }

    if (std.mem.eql(u8, args[0], "log")) {
        try protocolLog(allocator, if (args.len > 1) args[1..] else &[_][]const u8{});
    } else if (std.mem.eql(u8, args[0], "verify")) {
        try protocolVerify(allocator, if (args.len > 1) args[1..] else &[_][]const u8{});
    } else {
        std.debug.print("{s}Unknown protocol command: {s}{s}\n", .{ RED, args[0], RESET });
    }
}

/// `tri protocol log [--today] [--issue <N>] [--agent <name>]`
fn protocolLog(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var filter_today = false;
    var filter_issue: ?u32 = null;
    var filter_agent: ?[]const u8 = null;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--today")) {
            filter_today = true;
        } else if (std.mem.eql(u8, args[i], "--issue") and i + 1 < args.len) {
            i += 1;
            filter_issue = std.fmt.parseInt(u32, args[i], 10) catch null;
        } else if (std.mem.eql(u8, args[i], "--agent") and i + 1 < args.len) {
            i += 1;
            filter_agent = args[i];
        }
    }

    // Determine which log files to read
    const protocol_dir = ".trinity/protocol";

    if (filter_today) {
        // Get today's date via timestamp
        const date_str = try getTodayDateStr(allocator);
        defer allocator.free(date_str);
        const filename = try std.fmt.allocPrint(allocator, "{s}/{s}.jsonl", .{ protocol_dir, date_str });
        defer allocator.free(filename);
        try displayLogFile(filename, filter_issue, filter_agent);
    } else {
        // List all log files
        var dir = std.fs.cwd().openDir(protocol_dir, .{ .iterate = true }) catch {
            std.debug.print("{s}No protocol logs found in {s}/{s}\n", .{ GOLDEN, protocol_dir, RESET });
            return;
        };
        defer dir.close();

        var iter = dir.iterate();
        var found = false;
        while (try iter.next()) |entry| {
            if (std.mem.endsWith(u8, entry.name, ".jsonl")) {
                const filepath = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ protocol_dir, entry.name });
                defer allocator.free(filepath);
                std.debug.print("\n{s}═══ {s} ═══{s}\n", .{ CYAN, entry.name, RESET });
                try displayLogFile(filepath, filter_issue, filter_agent);
                found = true;
            }
        }
        if (!found) {
            std.debug.print("{s}No protocol logs found{s}\n", .{ GOLDEN, RESET });
        }
    }
}

/// `tri protocol verify --issue <N>`
fn protocolVerify(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var issue_num: ?u32 = null;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--issue") and i + 1 < args.len) {
            i += 1;
            issue_num = std.fmt.parseInt(u32, args[i], 10) catch null;
        }
    }

    if (issue_num == null) {
        std.debug.print("{s}Usage: tri protocol verify --issue <N>{s}\n", .{ GOLDEN, RESET });
        return;
    }

    // Count protocol entries for this issue
    const protocol_dir = ".trinity/protocol";
    var total_entries: u32 = 0;
    var has_create = false;
    var has_comment = false;
    var has_close = false;

    var dir = std.fs.cwd().openDir(protocol_dir, .{ .iterate = true }) catch {
        std.debug.print("{s}✗ No protocol logs found — compliance FAILED{s}\n", .{ RED, RESET });
        return;
    };
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (std.mem.endsWith(u8, entry.name, ".jsonl")) {
            const filepath = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ protocol_dir, entry.name });
            defer allocator.free(filepath);
            const content = std.fs.cwd().readFileAlloc(allocator, filepath, 1024 * 1024) catch continue;
            defer allocator.free(content);
            const issue_str = try std.fmt.allocPrint(allocator, "\"issue\":{d}", .{issue_num.?});
            defer allocator.free(issue_str);
            var lines_iter = std.mem.splitScalar(u8, content, '\n');
            while (lines_iter.next()) |line| {
                if (line.len == 0) continue;
                if (std.mem.indexOf(u8, line, issue_str) != null) {
                    total_entries += 1;
                    if (std.mem.indexOf(u8, line, "\"issue_create\"") != null) has_create = true;
                    if (std.mem.indexOf(u8, line, "\"issue_comment\"") != null) has_comment = true;
                    if (std.mem.indexOf(u8, line, "\"issue_close\"") != null) has_close = true;
                }
            }
        }
    }

    std.debug.print("\n{s}Protocol v2 Compliance — Issue #{d}{s}\n", .{ CYAN, issue_num.?, RESET });
    std.debug.print("─────────────────────────────────\n", .{});

    const check = if (has_create) "✅" else "❌";
    std.debug.print("  {s} Issue created via protocol\n", .{check});
    const check2 = if (has_comment) "✅" else "❌";
    std.debug.print("  {s} Has protocol comments (≥2 required)\n", .{check2});
    const check3 = if (total_entries >= 2) "✅" else "❌";
    std.debug.print("  {s} Total entries: {d} (min 2)\n", .{ check3, total_entries });
    const check4 = if (has_close) "✅" else "⬜";
    std.debug.print("  {s} Issue closed via protocol\n", .{check4});

    const compliant = has_create and has_comment and total_entries >= 2;
    if (compliant) {
        std.debug.print("\n{s}✅ COMPLIANT{s}\n", .{ GREEN, RESET });
    } else {
        std.debug.print("\n{s}❌ NOT COMPLIANT{s}\n", .{ RED, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Protocol logging
// ═══════════════════════════════════════════════════════════════════════════════

/// Append a JSONL entry to the protocol log
fn appendProtocolLog(allocator: std.mem.Allocator, action: []const u8, issue: u32, agent: ?[]const u8, ok: bool) !void {
    const protocol_dir = ".trinity/protocol";

    // Ensure directory exists
    std.fs.cwd().makePath(protocol_dir) catch |err| {
        std.log.warn("github_commands: makePath ({s}) failed: {}", .{ protocol_dir, err });
    };

    const date_str = try getTodayDateStr(allocator);
    defer allocator.free(date_str);
    const filepath = try std.fmt.allocPrint(allocator, "{s}/{s}.jsonl", .{ protocol_dir, date_str });
    defer allocator.free(filepath);

    const timestamp = std.time.timestamp();
    const agent_str = agent orelse "unknown";
    const ok_str = if (ok) "true" else "false";

    var buf: [512]u8 = undefined;
    const line = try std.fmt.bufPrint(&buf, "{{\"ts\":{d},\"action\":\"{s}\",\"issue\":{d},\"agent\":\"{s}\",\"ok\":{s}}}\n", .{
        timestamp, action, issue, agent_str, ok_str,
    });

    const file = try std.fs.cwd().createFile(filepath, .{ .truncate = false });
    defer file.close();
    try file.seekFromEnd(0);
    try file.writeAll(line);
}

fn displayLogFile(filepath: []const u8, filter_issue: ?u32, filter_agent: ?[]const u8) !void {
    // Use page_allocator for simplicity in this CLI display function
    const allocator = std.heap.page_allocator;
    const content = std.fs.cwd().readFileAlloc(allocator, filepath, 1024 * 1024) catch {
        std.debug.print("{s}No log file: {s}{s}\n", .{ GOLDEN, filepath, RESET });
        return;
    };
    defer allocator.free(content);

    var count: u32 = 0;
    var lines_iter = std.mem.splitScalar(u8, content, '\n');

    while (lines_iter.next()) |line| {
        if (line.len == 0) continue;
        var show = true;

        if (filter_issue) |num| {
            var num_buf: [32]u8 = undefined;
            const issue_str = std.fmt.bufPrint(&num_buf, "\"issue\":{d}", .{num}) catch continue;
            if (std.mem.indexOf(u8, line, issue_str) == null) show = false;
        }

        if (filter_agent) |agent| {
            var agent_buf: [128]u8 = undefined;
            const agent_str = std.fmt.bufPrint(&agent_buf, "\"agent\":\"{s}\"", .{agent}) catch continue;
            if (std.mem.indexOf(u8, line, agent_str) == null) show = false;
        }

        if (show) {
            std.debug.print("  {s}\n", .{line});
            count += 1;
        }
    }

    if (count == 0) {
        std.debug.print("  (no matching entries)\n", .{});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════════

fn getTemplatePhases(template: []const u8) []const []const u8 {
    if (std.mem.eql(u8, template, "bugfix")) {
        return &[_][]const u8{ "REPRODUCE", "DIAGNOSE", "FIX", "TEST" };
    } else if (std.mem.eql(u8, template, "spike")) {
        return &[_][]const u8{ "RESEARCH", "PROTOTYPE", "EVALUATE" };
    } else {
        // standard (default)
        return &[_][]const u8{ "RESEARCH", "PLAN", "IMPLEMENT", "TEST", "VERIFY" };
    }
}

fn getStatusEmoji(status: []const u8) []const u8 {
    if (std.mem.eql(u8, status, "THINKING")) return "🤔";
    if (std.mem.eql(u8, status, "ACTING")) return "⚡";
    if (std.mem.eql(u8, status, "DONE")) return "✅";
    if (std.mem.eql(u8, status, "FAILED")) return "❌";
    return "🔄";
}

fn getAgentEmoji(agent: []const u8) []const u8 {
    if (std.mem.eql(u8, agent, "ralph")) return "🤖";
    if (std.mem.eql(u8, agent, "mu")) return "🔱";
    if (std.mem.eql(u8, agent, "scholar")) return "📚";
    if (std.mem.eql(u8, agent, "oracle")) return "🔮";
    if (std.mem.eql(u8, agent, "linter")) return "🔍";
    return "🤖";
}

fn getTodayDateStr(allocator: std.mem.Allocator) ![]u8 {
    const timestamp = std.time.timestamp();
    const epoch_seconds = std.time.epoch.EpochSeconds{ .secs = @intCast(timestamp) };
    const epoch_day = epoch_seconds.getEpochDay();
    const year_day = epoch_day.calculateYearDay();
    const month_day = year_day.calculateMonthDay();
    return std.fmt.allocPrint(allocator, "{d}-{d:0>2}-{d:0>2}", .{
        year_day.year,
        @intFromEnum(month_day.month),
        month_day.day_index + 1,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// PR commands (Phase 1)
// ═══════════════════════════════════════════════════════════════════════════════

fn runPrCommand(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    if (args.len == 0) {
        printPrHelp();
        return;
    }
    const subcmd = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, subcmd, "create")) {
        try prCreate(allocator, sub_args, dry_run);
    } else if (std.mem.eql(u8, subcmd, "list")) {
        try prList(allocator, sub_args, dry_run);
    } else if (std.mem.eql(u8, subcmd, "merge")) {
        try prMerge(allocator, sub_args, dry_run);
    } else if (std.mem.eql(u8, subcmd, "view")) {
        try prView(allocator, sub_args, dry_run);
    } else if (std.mem.eql(u8, subcmd, "review")) {
        try prReview(allocator, sub_args, dry_run);
    } else if (std.mem.eql(u8, subcmd, "diff")) {
        try prDiff(allocator, sub_args, dry_run);
    } else {
        std.debug.print("{s}Unknown pr command: {s}{s}\n", .{ RED, subcmd, RESET });
        printPrHelp();
    }
}

fn prCreate(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    var head: ?[]const u8 = null;
    var base: []const u8 = "main";
    var title: ?[]const u8 = null;
    var body: ?[]const u8 = null;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--head") and i + 1 < args.len) {
            i += 1;
            head = args[i];
        } else if (std.mem.eql(u8, args[i], "--base") and i + 1 < args.len) {
            i += 1;
            base = args[i];
        } else if (std.mem.eql(u8, args[i], "--title") and i + 1 < args.len) {
            i += 1;
            title = args[i];
        } else if (std.mem.eql(u8, args[i], "--body") and i + 1 < args.len) {
            i += 1;
            body = args[i];
        } else if (title == null) {
            title = args[i];
        }
    }

    if (head == null or title == null) {
        std.debug.print("{s}Usage: tri pr create --head <branch> [--base main] --title <title> [--body <body>]{s}\n", .{ GOLDEN, RESET });
        return;
    }

    var client = github_client.GitHubClient.init(allocator, dry_run) catch |err| {
        std.debug.print("{s}GitHub client init failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer client.deinit();

    const result = try client.createPr(head.?, base, title.?, body);
    std.debug.print("{s}✓ PR #{d} created{s}\n", .{ GREEN, result.number, RESET });
    std.debug.print("  {s}{s}{s}\n", .{ CYAN, result.url, RESET });
}

fn prList(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    var state_filter: []const u8 = "open";
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--state") and i + 1 < args.len) {
            i += 1;
            state_filter = args[i];
        }
    }

    var client = github_client.GitHubClient.init(allocator, dry_run) catch |err| {
        std.debug.print("{s}GitHub client init failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer client.deinit();

    const response = try client.listPrs(state_filter);
    defer allocator.free(response);

    // Parse and display PR list
    std.debug.print("{s}Pull Requests ({s}):{s}\n", .{ CYAN, state_filter, RESET });
    // Simple display: look for "number" and "title" pairs
    var pos: usize = 0;
    var count: usize = 0;
    while (pos < response.len) {
        const num_needle = "\"number\":";
        const num_idx = std.mem.indexOfPos(u8, response, pos, num_needle) orelse break;
        const num_start = num_idx + num_needle.len;
        var num_end = num_start;
        while (num_end < response.len and response[num_end] >= '0' and response[num_end] <= '9') : (num_end += 1) {}
        const pr_num = std.fmt.parseInt(u32, response[num_start..num_end], 10) catch break;

        const title_str = github_client.extractJsonString(response[num_idx..], "title") orelse "(untitled)";
        const state_str = github_client.extractJsonString(response[num_idx..], "state") orelse "";

        const state_icon: []const u8 = if (std.mem.eql(u8, state_str, "open")) "🟢" else "🟣";
        std.debug.print("  {s} #{d} {s}{s}{s}\n", .{ state_icon, pr_num, GREEN, title_str, RESET });
        pos = num_end;
        count += 1;
    }
    if (count == 0) {
        std.debug.print("  (no PRs found)\n", .{});
    }
}

fn prMerge(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri pr merge <N> [--method squash|merge|rebase]{s}\n", .{ GOLDEN, RESET });
        return;
    }

    const number = std.fmt.parseInt(u32, args[0], 10) catch {
        std.debug.print("{s}Invalid PR number: {s}{s}\n", .{ RED, args[0], RESET });
        return;
    };

    var method: []const u8 = "squash";
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--method") and i + 1 < args.len) {
            i += 1;
            method = args[i];
        }
    }

    var client = github_client.GitHubClient.init(allocator, dry_run) catch |err| {
        std.debug.print("{s}GitHub client init failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer client.deinit();

    try client.mergePr(number, method);
    std.debug.print("{s}✓ PR #{d} merged ({s}){s}\n", .{ GREEN, number, method, RESET });
}

fn prView(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri pr view <N>{s}\n", .{ GOLDEN, RESET });
        return;
    }

    const number = std.fmt.parseInt(u32, args[0], 10) catch {
        std.debug.print("{s}Invalid PR number: {s}{s}\n", .{ RED, args[0], RESET });
        return;
    };

    var client = github_client.GitHubClient.init(allocator, dry_run) catch |err| {
        std.debug.print("{s}GitHub client init failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer client.deinit();

    const pr = try client.getPr(number);
    std.debug.print("{s}PR #{d}{s}\n", .{ CYAN, pr.number, RESET });
    std.debug.print("  State: {s}\n", .{pr.state});
    std.debug.print("  URL:   {s}\n", .{pr.url});
}

fn prReview(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri pr review <N> --approve|--comment|--changes [--body <text>]{s}\n", .{ GOLDEN, RESET });
        return;
    }

    const number = std.fmt.parseInt(u32, args[0], 10) catch {
        std.debug.print("{s}Invalid PR number: {s}{s}\n", .{ RED, args[0], RESET });
        return;
    };

    var event: []const u8 = "COMMENT";
    var body: ?[]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--approve")) {
            event = "APPROVE";
        } else if (std.mem.eql(u8, args[i], "--comment")) {
            event = "COMMENT";
        } else if (std.mem.eql(u8, args[i], "--changes")) {
            event = "REQUEST_CHANGES";
        } else if (std.mem.eql(u8, args[i], "--body") and i + 1 < args.len) {
            i += 1;
            body = args[i];
        }
    }

    var client = github_client.GitHubClient.init(allocator, dry_run) catch |err| {
        std.debug.print("{s}GitHub client init failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer client.deinit();

    try client.createPrReview(number, event, body);
    std.debug.print("{s}✓ PR #{d} reviewed ({s}){s}\n", .{ GREEN, number, event, RESET });
}

fn prDiff(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri pr diff <N>{s}\n", .{ GOLDEN, RESET });
        return;
    }

    const number = std.fmt.parseInt(u32, args[0], 10) catch {
        std.debug.print("{s}Invalid PR number: {s}{s}\n", .{ RED, args[0], RESET });
        return;
    };

    var client = github_client.GitHubClient.init(allocator, dry_run) catch |err| {
        std.debug.print("{s}GitHub client init failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer client.deinit();

    const diff = try client.getPrDiff(number);
    defer allocator.free(diff);
    std.debug.print("{s}", .{diff});
}

// ═══════════════════════════════════════════════════════════════════════════════
// Check Run commands (Phase 2)
// ═══════════════════════════════════════════════════════════════════════════════

fn runCheckCommand(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    if (args.len == 0) {
        printCheckHelp();
        return;
    }
    const subcmd = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, subcmd, "create")) {
        try checkCreate(allocator, sub_args, dry_run);
    } else if (std.mem.eql(u8, subcmd, "pass")) {
        try checkUpdate(allocator, sub_args, dry_run, "success");
    } else if (std.mem.eql(u8, subcmd, "fail")) {
        try checkUpdate(allocator, sub_args, dry_run, "failure");
    } else {
        std.debug.print("{s}Unknown check command: {s}{s}\n", .{ RED, subcmd, RESET });
        printCheckHelp();
    }
}

fn checkCreate(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri check create <name> --sha <sha>{s}\n", .{ GOLDEN, RESET });
        return;
    }

    const name = args[0];
    var sha: ?[]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--sha") and i + 1 < args.len) {
            i += 1;
            sha = args[i];
        }
    }

    var sha_owned: ?[]const u8 = null;
    defer if (sha_owned) |s| allocator.free(s);

    if (sha == null) {
        // Auto-detect HEAD sha
        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "git", "rev-parse", "HEAD" },
            .max_output_bytes = 256,
        }) catch {
            std.debug.print("{s}Failed to detect HEAD sha. Use --sha <sha>{s}\n", .{ RED, RESET });
            return;
        };
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);
        const trimmed = std.mem.trimRight(u8, result.stdout, "\n\r ");
        sha_owned = allocator.dupe(u8, trimmed) catch {
            std.debug.print("{s}Out of memory{s}\n", .{ RED, RESET });
            return;
        };
        sha = sha_owned;
    }

    var client = github_client.GitHubClient.init(allocator, dry_run) catch |err| {
        std.debug.print("{s}GitHub client init failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer client.deinit();

    const check = try client.createCheckRun(name, sha.?, "in_progress");
    std.debug.print("{s}✓ Check run created (id={d}){s}\n", .{ GREEN, check.id, RESET });
}

fn checkUpdate(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool, conclusion: []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri check pass|fail <id> [--title <t>] [--summary <s>]{s}\n", .{ GOLDEN, RESET });
        return;
    }

    const check_id = std.fmt.parseInt(i64, args[0], 10) catch {
        std.debug.print("{s}Invalid check run ID: {s}{s}\n", .{ RED, args[0], RESET });
        return;
    };

    var title: ?[]const u8 = null;
    var summary: ?[]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--title") and i + 1 < args.len) {
            i += 1;
            title = args[i];
        } else if (std.mem.eql(u8, args[i], "--summary") and i + 1 < args.len) {
            i += 1;
            summary = args[i];
        }
    }

    var client = github_client.GitHubClient.init(allocator, dry_run) catch |err| {
        std.debug.print("{s}GitHub client init failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer client.deinit();

    try client.updateCheckRun(check_id, "completed", conclusion, title, summary);
    std.debug.print("{s}✓ Check run {d} → {s}{s}\n", .{ GREEN, check_id, conclusion, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Dispatch commands (Phase 4)
// ═══════════════════════════════════════════════════════════════════════════════

fn runDispatchCommand(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri dispatch <event-type> [--payload <json>]{s}\n", .{ GOLDEN, RESET });
        return;
    }

    const event_type = args[0];
    var payload: ?[]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--payload") and i + 1 < args.len) {
            i += 1;
            payload = args[i];
        }
    }

    var client = github_client.GitHubClient.init(allocator, dry_run) catch |err| {
        std.debug.print("{s}GitHub client init failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer client.deinit();

    try client.repositoryDispatch(event_type, payload);
    std.debug.print("{s}✓ Dispatched event \"{s}\"{s}\n", .{ GREEN, event_type, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// GraphQL command
// ═══════════════════════════════════════════════════════════════════════════════

fn runGraphqlCommand(allocator: std.mem.Allocator, args: []const []const u8, dry_run: bool) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri graphql <query-string> [--vars <json>]{s}\n", .{ GOLDEN, RESET });
        return;
    }

    const query = args[0];
    var vars: ?[]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--vars") and i + 1 < args.len) {
            i += 1;
            vars = args[i];
        }
    }

    var client = github_client.GitHubClient.init(allocator, dry_run) catch |err| {
        std.debug.print("{s}GitHub client init failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer client.deinit();

    const result = try client.graphqlQuery(query, vars);
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result});
}

// ═══════════════════════════════════════════════════════════════════════════════
// Help functions
// ═══════════════════════════════════════════════════════════════════════════════

fn printGithubHelp() void {
    std.debug.print(
        \\{0s}GitHub Integration Commands{1s}
        \\
        \\  {2s}tri issue create <title>{1s}     Create a new issue
        \\  {2s}tri issue comment <N>{1s}         Post Protocol v2 comment
        \\  {2s}tri issue close <N>{1s}           Close with summary
        \\  {2s}tri issue decompose <N>{1s}       Create sub-issues from template
        \\  {2s}tri issue list{1s}                List issues [--label X] [--state S]
        \\  {2s}tri issue view <N>{1s}            Show issue details
        \\  {2s}tri issue assign <N>{1s}          Assign [--to user] [--label label]
        \\  {2s}tri board sync{1s}                Sync board column via labels
        \\  {2s}tri board audit{1s}               Check field completeness (read-only)
        \\  {2s}tri board fix{1s}                 Auto-fill empty fields
        \\  {2s}tri agent start <N> <name>{1s}    Mark agent started on issue
        \\  {2s}tri agent done <N> <name>{1s}     Mark agent finished on issue
        \\  {2s}tri protocol log{1s}              Display protocol log
        \\  {2s}tri protocol verify{1s}           Check Protocol v2 compliance
        \\  {2s}tri pr create{1s}                 Create pull request
        \\  {2s}tri pr list{1s}                   List pull requests
        \\  {2s}tri pr merge <N>{1s}              Merge pull request
        \\  {2s}tri pr view <N>{1s}               View PR details
        \\  {2s}tri pr review <N>{1s}             Review PR (approve/comment/changes)
        \\  {2s}tri pr diff <N>{1s}               Show PR diff
        \\  {2s}tri check create <name>{1s}       Create check run on HEAD
        \\  {2s}tri check pass <id>{1s}           Mark check run as passed
        \\  {2s}tri check fail <id>{1s}           Mark check run as failed
        \\  {2s}tri dispatch <event>{1s}          Trigger repository_dispatch
        \\  {2s}tri graphql <query>{1s}           Execute GraphQL query
        \\
        \\Use --dry-run to preview without API calls.
        \\
    , .{ CYAN, RESET, GREEN });
}

fn printBoardHelp() void {
    std.debug.print(
        \\{0s}Board Commands{1s}
        \\
        \\  {2s}tri board sync{1s}    --issue <N> --column <col>  Sync column via labels
        \\  {2s}tri board audit{1s}                               Check all issue fields (read-only)
        \\  {2s}tri board fix{1s}                                 Auto-fill empty fields
        \\
        \\Columns: backlog, in-progress, in-review, ready, done
        \\
    , .{ CYAN, RESET, GREEN });
}

fn printAgentHelp() void {
    std.debug.print(
        \\{0s}Agent Commands{1s}
        \\
        \\  {2s}tri agent list{1s}                     Show all agents + PID + status
        \\  {2s}tri agent start <N> <name>{1s}         Mark agent started on issue
        \\  {2s}tri agent done <N> <name> [result]{1s}  Mark agent finished
        \\  {2s}tri agent stop <name>{1s}              Stop agent process
        \\  {2s}tri agent restart <name>{1s}           Restart agent
        \\  {2s}tri agent status{1s}                   Alias for list
        \\
        \\Example:
        \\  tri agent list
        \\  tri agent start 45 ralph
        \\  tri agent done 45 ralph "9/9 tests pass"
        \\  tri agent stop ralph
        \\
    , .{ CYAN, RESET, GREEN });
}

fn printPrHelp() void {
    std.debug.print(
        \\{0s}PR Commands{1s}
        \\
        \\  {2s}create{1s}   --head <branch> [--base main] --title <title> [--body <b>]
        \\  {2s}list{1s}     [--state open|closed|all]
        \\  {2s}merge <N>{1s} [--method squash|merge|rebase]
        \\  {2s}view <N>{1s}  Show PR details
        \\  {2s}review <N>{1s} --approve|--comment|--changes [--body <text>]
        \\  {2s}diff <N>{1s}  Show PR diff
        \\
    , .{ CYAN, RESET, GREEN });
}

fn printCheckHelp() void {
    std.debug.print(
        \\{0s}Check Run Commands{1s}
        \\
        \\  {2s}create <name>{1s}  [--sha <sha>]  Create check run (auto-detects HEAD)
        \\  {2s}pass <id>{1s}      [--title <t>] [--summary <s>]  Mark success
        \\  {2s}fail <id>{1s}      [--title <t>] [--summary <s>]  Mark failure
        \\
    , .{ CYAN, RESET, GREEN });
}

fn printIssueHelp() void {
    std.debug.print(
        \\{0s}Issue Commands{1s}
        \\
        \\  {2s}create <title>{1s}   [--body <b>] [--labels <l1,l2>] [--agent <a>] [--parent <N>]
        \\  {2s}comment <N>{1s}      [--agent <a>] [--step <s>] [--status <S>] [--thought <t>]
        \\                    [--action <a>] [--result <r>] [--next <n>]
        \\  {2s}close <N>{1s}        [--reason <r>] [--summary <s>]
        \\  {2s}decompose <N>{1s}    [--template standard|bugfix|spike] [--agent <a>]
        \\  {2s}list{1s}             [--label <L>] [--state open|closed|all]
        \\  {2s}view <N>{1s}         Show issue details
        \\  {2s}assign <N>{1s}       [--to <user>] [--label <label>]
        \\
    , .{ CYAN, RESET, GREEN });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "getTemplatePhases standard" {
    const phases = getTemplatePhases("standard");
    try std.testing.expectEqual(@as(usize, 5), phases.len);
    try std.testing.expectEqualStrings("RESEARCH", phases[0]);
    try std.testing.expectEqualStrings("VERIFY", phases[4]);
}

test "getTemplatePhases bugfix" {
    const phases = getTemplatePhases("bugfix");
    try std.testing.expectEqual(@as(usize, 4), phases.len);
    try std.testing.expectEqualStrings("REPRODUCE", phases[0]);
}

test "getTemplatePhases spike" {
    const phases = getTemplatePhases("spike");
    try std.testing.expectEqual(@as(usize, 3), phases.len);
}

test "getStatusEmoji" {
    try std.testing.expectEqualStrings("🤔", getStatusEmoji("THINKING"));
    try std.testing.expectEqualStrings("✅", getStatusEmoji("DONE"));
    try std.testing.expectEqualStrings("❌", getStatusEmoji("FAILED"));
}

test "getAgentEmoji" {
    try std.testing.expectEqualStrings("🤖", getAgentEmoji("ralph"));
    try std.testing.expectEqualStrings("🔱", getAgentEmoji("mu"));
    try std.testing.expectEqualStrings("📚", getAgentEmoji("scholar"));
}

test "getTodayDateStr format" {
    const allocator = std.testing.allocator;
    const date = try getTodayDateStr(allocator);
    defer allocator.free(date);
    // Should be YYYY-MM-DD format
    try std.testing.expect(date.len >= 10);
    try std.testing.expect(date[4] == '-');
}
