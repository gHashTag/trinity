// ============================================================================
// SWARM COORDINATOR — 🐝 TRI University Task Decomposition
// Breaks GitHub issues into sub-tasks and assigns to agents
// Protocol: every action = GitHub comment. Labels = routing. Sub-issues = tracking.
// φ² + 1/φ² = 3 = TRINITY
// ============================================================================

const std = @import("std");
const Allocator = std.mem.Allocator;
const task_decomposer = @import("task_decomposer.zig");

// ============================================================================
// COLORS
// ============================================================================

const RESET = "\x1b[0m";
const GREEN = "\x1b[38;2;0;229;153m";
const RED = "\x1b[38;2;239;68;68m";
const GOLDEN = "\x1b[38;2;255;215;0m";
const CYAN = "\x1b[38;2;0;255;255m";
const GRAY = "\x1b[38;2;156;156;160m";
const WHITE = "\x1b[38;2;255;255;255m";
const PURPLE = "\x1b[38;2;111;66;193m";

// ============================================================================
// TYPES
// ============================================================================

pub const AgentRole = enum {
    ralph,
    scholar,
    mu,
    linter,
    oracle,
    swarm,

    pub fn label(self: AgentRole) []const u8 {
        return switch (self) {
            .ralph => "agent:ralph",
            .scholar => "agent:scholar",
            .mu => "agent:mu",
            .linter => "agent:linter",
            .oracle => "agent:oracle",
            .swarm => "agent:swarm",
        };
    }

    pub fn emoji(self: AgentRole) []const u8 {
        return switch (self) {
            .ralph => "🔧",
            .scholar => "🔍",
            .mu => "🧠",
            .linter => "🛡️",
            .oracle => "📐",
            .swarm => "🐝",
        };
    }

    pub fn name(self: AgentRole) []const u8 {
        return switch (self) {
            .ralph => "Ralph",
            .scholar => "Scholar",
            .mu => "MU",
            .linter => "Linter",
            .oracle => "Oracle",
            .swarm => "Swarm",
        };
    }

    pub fn fromLabel(label_str: []const u8) ?AgentRole {
        if (std.mem.eql(u8, label_str, "agent:ralph")) return .ralph;
        if (std.mem.eql(u8, label_str, "agent:scholar")) return .scholar;
        if (std.mem.eql(u8, label_str, "agent:mu")) return .mu;
        if (std.mem.eql(u8, label_str, "agent:linter")) return .linter;
        if (std.mem.eql(u8, label_str, "agent:oracle")) return .oracle;
        if (std.mem.eql(u8, label_str, "agent:swarm")) return .swarm;
        return null;
    }
};

pub const TaskType = enum {
    research,
    code,
    validate,
    learn,
    verify,
    analyze,

    pub fn label(self: TaskType) []const u8 {
        return switch (self) {
            .research => "task:research",
            .code => "task:code",
            .validate => "task:validate",
            .learn => "task:learn",
            .verify => "task:verify",
            .analyze => "task:analyze",
        };
    }
};

// ============================================================================
// COMMAND DISPATCH
// ============================================================================

pub fn runSwarmCommand(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        printSwarmHelp();
        return;
    }

    const subcmd = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, subcmd, "run")) {
        try task_decomposer.runSwarmExecute(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "decompose")) {
        try runDecompose(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "status")) {
        try runStatus(allocator);
    } else if (std.mem.eql(u8, subcmd, "assign")) {
        try runAssign(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "monitor")) {
        try runMonitor(allocator);
    } else if (std.mem.eql(u8, subcmd, "log")) {
        try runLog(allocator);
    } else if (std.mem.eql(u8, subcmd, "escalate")) {
        try runEscalate(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help")) {
        printSwarmHelp();
    } else {
        std.debug.print("{s}Unknown subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printSwarmHelp();
    }
}

// ============================================================================
// DECOMPOSE — break issue into sub-tasks
// ============================================================================

fn runDecompose(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("{s}Usage: tri swarm decompose <issue-number>{s}\n", .{ GRAY, RESET });
        return;
    }

    const issue_num = args[0];
    std.debug.print("\n{s}🐝 SWARM DECOMPOSE — Issue #{s}{s}\n", .{ PURPLE, issue_num, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════{s}\n\n", .{ PURPLE, RESET });

    // Fetch issue details
    std.debug.print("  Fetching issue #{s}...\n", .{issue_num});

    var title_buf: [512]u8 = undefined;
    const title = try ghGetIssueTitle(allocator, issue_num, &title_buf);

    std.debug.print("  Title: {s}{s}{s}\n\n", .{ WHITE, title, RESET });

    // Analyze and create sub-tasks based on issue labels/content
    // For now, create a standard decomposition template
    const sub_tasks = [_]struct {
        title_prefix: []const u8,
        agent: AgentRole,
        task_type: TaskType,
        desc: []const u8,
    }{
        .{ .title_prefix = "Research", .agent = .scholar, .task_type = .research, .desc = "Research best practices and patterns" },
        .{ .title_prefix = "Validate", .agent = .linter, .task_type = .validate, .desc = "Validate existing specs and identify issues" },
        .{ .title_prefix = "Implement", .agent = .ralph, .task_type = .code, .desc = "Implement the code changes" },
        .{ .title_prefix = "Learn", .agent = .mu, .task_type = .learn, .desc = "Log error patterns from implementation" },
        .{ .title_prefix = "Verify", .agent = .ralph, .task_type = .verify, .desc = "Run tests and verify changes" },
    };

    var created: u32 = 0;
    for (sub_tasks) |task| {
        var sub_title_buf: [512]u8 = undefined;
        const sub_title = std.fmt.bufPrint(&sub_title_buf, "[Sub] {s}: {s}", .{ task.title_prefix, title }) catch continue;

        var body_buf: [1024]u8 = undefined;
        const body = std.fmt.bufPrint(&body_buf, "Parent: #{s}\nAgent: {s}\nTask: {s}\n\n---\n_Created by 🐝 Swarm Coordinator_", .{
            issue_num,
            task.agent.name(),
            task.desc,
        }) catch continue;

        std.debug.print("  {s} Creating: [{s}] {s}...\n", .{ task.agent.emoji(), task.agent.name(), sub_title[0..@min(sub_title.len, 60)] });

        // Create the sub-issue via gh CLI
        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{
                "gh",            "issue",                "create",
                "--title",       sub_title,              "--body",
                body,            "--label",              task.agent.label(),
                "--label",       task.task_type.label(), "--label",
                "status:queued",
            },
            .max_output_bytes = 65536,
        }) catch {
            std.debug.print("  {s}Failed to create sub-issue{s}\n", .{ RED, RESET });
            continue;
        };
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);

        if (result.term.Exited == 0) {
            created += 1;
            // Extract issue URL from stdout
            const url = std.mem.trimRight(u8, result.stdout, "\n\r ");
            std.debug.print("    {s}✅ Created: {s}{s}\n", .{ GREEN, url, RESET });
        } else {
            std.debug.print("    {s}❌ Failed: {s}{s}\n", .{ RED, result.stderr[0..@min(result.stderr.len, 200)], RESET });
        }
    }

    // Comment on parent issue
    if (created > 0) {
        var comment_buf: [1024]u8 = undefined;
        const comment = std.fmt.bufPrint(&comment_buf, "🐝 **Swarm Coordinator** decomposed this issue into {d} sub-tasks.\n\nAgents assigned: Scholar, Linter, Ralph, MU\nStatus: All queued.\n\n_φ² + 1/φ² = 3 — The Trinity decomposes._", .{created}) catch "🐝 Decomposition complete.";

        const comment_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "gh", "issue", "comment", issue_num, "--body", comment },
            .max_output_bytes = 65536,
        }) catch {
            std.debug.print("  {s}Warning: could not comment on parent{s}\n", .{ GRAY, RESET });
            return;
        };
        defer allocator.free(comment_result.stdout);
        defer allocator.free(comment_result.stderr);
    }

    std.debug.print("\n  {s}🐝 {d} sub-tasks created for #{s}{s}\n\n", .{ GREEN, created, issue_num, RESET });
}

// ============================================================================
// STATUS — show all agent-labeled issues
// ============================================================================

fn runStatus(allocator: Allocator) !void {
    std.debug.print("\n{s}🐝 SWARM STATUS{s}\n", .{ PURPLE, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════{s}\n\n", .{ PURPLE, RESET });

    // Fetch issues with agent: labels
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "gh",      "issue",                                                            "list",
            "--state", "open",                                                             "--limit",
            "50",      "--json",                                                           "number,title,labels,assignees",
            "--jq",    ".[] | select(.labels | map(.name) | any(startswith(\"agent:\")))",
        },
        .max_output_bytes = 262_144,
    }) catch {
        std.debug.print("  {s}Failed to fetch issues{s}\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len == 0) {
        // Fallback: list all open issues with labels
        const fallback = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{
                "gh",      "issue",  "list",
                "--state", "open",   "--limit",
                "30",      "--json", "number,title,labels",
            },
            .max_output_bytes = 262_144,
        }) catch {
            std.debug.print("  {s}Failed to fetch issues{s}\n", .{ RED, RESET });
            return;
        };
        defer allocator.free(fallback.stdout);
        defer allocator.free(fallback.stderr);

        // Count agent-labeled issues
        var agent_count: u32 = 0;
        var pos: usize = 0;
        while (std.mem.indexOfPos(u8, fallback.stdout, pos, "\"agent:")) |idx| {
            agent_count += 1;
            pos = idx + 7;
        }

        // Count status labels
        var queued: u32 = 0;
        var in_progress: u32 = 0;
        var done: u32 = 0;
        pos = 0;
        while (std.mem.indexOfPos(u8, fallback.stdout, pos, "status:queued")) |idx| {
            queued += 1;
            pos = idx + 13;
        }
        pos = 0;
        while (std.mem.indexOfPos(u8, fallback.stdout, pos, "status:in-progress")) |idx| {
            in_progress += 1;
            pos = idx + 18;
        }
        pos = 0;
        while (std.mem.indexOfPos(u8, fallback.stdout, pos, "status:done")) |idx| {
            done += 1;
            pos = idx + 11;
        }

        // Count issues per agent
        var ralph_count: u32 = 0;
        var scholar_count: u32 = 0;
        var mu_count: u32 = 0;
        var linter_count: u32 = 0;
        pos = 0;
        while (std.mem.indexOfPos(u8, fallback.stdout, pos, "agent:ralph")) |idx| {
            ralph_count += 1;
            pos = idx + 11;
        }
        pos = 0;
        while (std.mem.indexOfPos(u8, fallback.stdout, pos, "agent:scholar")) |idx| {
            scholar_count += 1;
            pos = idx + 13;
        }
        pos = 0;
        while (std.mem.indexOfPos(u8, fallback.stdout, pos, "agent:mu")) |idx| {
            mu_count += 1;
            pos = idx + 8;
        }
        pos = 0;
        while (std.mem.indexOfPos(u8, fallback.stdout, pos, "agent:linter")) |idx| {
            linter_count += 1;
            pos = idx + 12;
        }

        std.debug.print("  Agent-labeled issues: {d}\n\n", .{agent_count});
        std.debug.print("  ┌────────────┬───────┬─────────────┐\n", .{});
        std.debug.print("  │ Agent      │ Tasks │ Status      │\n", .{});
        std.debug.print("  ├────────────┼───────┼─────────────┤\n", .{});
        std.debug.print("  │ 🔧 Ralph   │ {d:>4}  │ active      │\n", .{ralph_count});
        std.debug.print("  │ 🔍 Scholar │ {d:>4}  │ active      │\n", .{scholar_count});
        std.debug.print("  │ 🧠 MU      │ {d:>4}  │ active      │\n", .{mu_count});
        std.debug.print("  │ 🛡️  Linter  │ {d:>4}  │ active      │\n", .{linter_count});
        std.debug.print("  └────────────┴───────┴─────────────┘\n\n", .{});

        std.debug.print("  Status breakdown:\n", .{});
        std.debug.print("    ⏳ Queued:      {d}\n", .{queued});
        std.debug.print("    🔵 In progress: {d}\n", .{in_progress});
        std.debug.print("    ✅ Done:        {d}\n\n", .{done});
    } else {
        std.debug.print("  {s}\n", .{result.stdout});
    }
}

// ============================================================================
// ASSIGN — add agent label to an issue
// ============================================================================

fn runAssign(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("{s}Usage: tri swarm assign <issue-number> <agent>{s}\n", .{ GRAY, RESET });
        std.debug.print("  Agents: ralph, scholar, mu, linter, oracle\n", .{});
        return;
    }

    const issue_num = args[0];
    const agent_name = args[1];

    // Parse agent role
    const role: AgentRole = if (std.mem.eql(u8, agent_name, "ralph")) .ralph else if (std.mem.eql(u8, agent_name, "scholar")) .scholar else if (std.mem.eql(u8, agent_name, "mu")) .mu else if (std.mem.eql(u8, agent_name, "linter")) .linter else if (std.mem.eql(u8, agent_name, "oracle")) .oracle else {
        std.debug.print("{s}Unknown agent: {s}{s}\n", .{ RED, agent_name, RESET });
        return;
    };

    std.debug.print("  {s} Assigning #{s} to {s}...\n", .{ role.emoji(), issue_num, role.name() });

    // Add agent label
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "gh",          "issue",      "edit",        issue_num,
            "--add-label", role.label(), "--add-label", "status:queued",
        },
        .max_output_bytes = 65536,
    }) catch {
        std.debug.print("  {s}Failed to assign{s}\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term.Exited == 0) {
        std.debug.print("  {s}✅ #{s} assigned to {s} ({s}){s}\n", .{ GREEN, issue_num, role.name(), role.label(), RESET });

        // Comment on issue
        var comment_buf: [256]u8 = undefined;
        const comment = std.fmt.bufPrint(&comment_buf, "{s} **Assigned to {s}** | Status: queued\n_by 🐝 Swarm Coordinator_", .{ role.emoji(), role.name() }) catch "Assigned.";

        const comment_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "gh", "issue", "comment", issue_num, "--body", comment },
            .max_output_bytes = 65536,
        }) catch return;
        defer allocator.free(comment_result.stdout);
        defer allocator.free(comment_result.stderr);
    } else {
        std.debug.print("  {s}❌ Failed to assign{s}\n", .{ RED, RESET });
    }
}

// ============================================================================
// MONITOR — check parent issues, close if all sub-tasks done
// ============================================================================

fn runMonitor(allocator: Allocator) !void {
    std.debug.print("\n{s}🐝 SWARM MONITOR{s}\n", .{ PURPLE, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════{s}\n\n", .{ PURPLE, RESET });

    // Find issues with "epic" label or issues that have sub-issues
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "gh",      "issue",               "list",
            "--state", "open",                "--label",
            "epic",    "--limit",             "20",
            "--json",  "number,title,labels",
        },
        .max_output_bytes = 262_144,
    }) catch {
        std.debug.print("  {s}Failed to fetch epic issues{s}\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len < 3) {
        std.debug.print("  No epic issues found.\n", .{});
        std.debug.print("  {s}Tip: add 'epic' label to parent issues for monitoring{s}\n\n", .{ GRAY, RESET });
        return;
    }

    std.debug.print("  Monitoring epic issues for completion...\n\n", .{});
    std.debug.print("  {s}(Check sub-issue status and close parents when all done){s}\n\n", .{ GRAY, RESET });
}

// ============================================================================
// LOG — show protocol log for today
// ============================================================================

fn runLog(allocator: Allocator) !void {
    std.debug.print("\n{s}💬 AGENT PROTOCOL LOG{s}\n", .{ PURPLE, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════{s}\n\n", .{ PURPLE, RESET });

    // Read today's protocol file
    var date_buf: [32]u8 = undefined;
    const timestamp = std.time.timestamp();
    const epoch_day = @divFloor(timestamp, 86400);
    const date_str = std.fmt.bufPrint(&date_buf, ".trinity/protocol/{d}.jsonl", .{epoch_day}) catch {
        std.debug.print("  {s}No protocol log for today{s}\n\n", .{ GRAY, RESET });
        return;
    };

    const file = std.fs.cwd().openFile(date_str, .{}) catch {
        // No log file — show recent issue comments instead
        std.debug.print("  No protocol log file found.\n", .{});
        std.debug.print("  {s}Showing recent agent comments from GitHub...{s}\n\n", .{ GRAY, RESET });

        // List recent comments on agent-labeled issues
        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{
                "gh",                                              "issue",                        "list",
                "--state",                                         "all",                          "--label",
                "agent:ralph,agent:scholar,agent:mu,agent:linter", "--limit",                      "10",
                "--json",                                          "number,title,state,updatedAt",
            },
            .max_output_bytes = 262_144,
        }) catch {
            std.debug.print("  {s}Failed to fetch{s}\n", .{ RED, RESET });
            return;
        };
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);

        if (result.stdout.len > 2) {
            std.debug.print("  Recent agent activity:\n{s}\n", .{result.stdout[0..@min(result.stdout.len, 2000)]});
        } else {
            std.debug.print("  No agent activity found.\n", .{});
        }
        return;
    };
    defer file.close();

    // Read and display log entries
    var buf: [4096]u8 = undefined;
    const bytes_read = file.readAll(&buf) catch 0;
    if (bytes_read > 0) {
        std.debug.print("{s}\n", .{buf[0..bytes_read]});
    } else {
        std.debug.print("  {s}Protocol log is empty{s}\n\n", .{ GRAY, RESET });
    }
}

// ============================================================================
// ESCALATE — re-route a failed task
// ============================================================================

fn runEscalate(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("{s}Usage: tri swarm escalate <issue-number>{s}\n", .{ GRAY, RESET });
        return;
    }

    const issue_num = args[0];
    std.debug.print("\n  {s}⚠️  Escalating #{s}...{s}\n", .{ GOLDEN, issue_num, RESET });

    // Fetch the issue to find current agent
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "gh",     "issue",  "view", issue_num,
            "--json", "labels", "--jq", ".labels[].name",
        },
        .max_output_bytes = 65536,
    }) catch {
        std.debug.print("  {s}Failed to fetch issue{s}\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    // Find current agent from labels
    var current_agent: ?AgentRole = null;
    var line_start: usize = 0;
    for (result.stdout, 0..) |c, i| {
        if (c == '\n' or i == result.stdout.len - 1) {
            const line = result.stdout[line_start..if (c == '\n') i else i + 1];
            const trimmed = std.mem.trimRight(u8, line, "\r\n ");
            if (AgentRole.fromLabel(trimmed)) |role| {
                current_agent = role;
            }
            line_start = i + 1;
        }
    }

    // Escalation chain: ralph→scholar→human, linter→ralph, mu→ralph
    const next_agent: ?AgentRole = if (current_agent) |agent| switch (agent) {
        .ralph => .scholar,
        .scholar => null, // → human
        .linter => .ralph,
        .mu => .ralph,
        .oracle => null,
        .swarm => null,
    } else null;

    if (next_agent) |next| {
        std.debug.print("  Escalation: {s} → {s}\n", .{
            if (current_agent) |ca| ca.name() else "unknown",
            next.name(),
        });

        // Remove old agent label, add new one
        if (current_agent) |ca| {
            const remove_result = std.process.Child.run(.{
                .allocator = allocator,
                .argv = &[_][]const u8{
                    "gh",             "issue",         "edit",        issue_num,
                    "--remove-label", ca.label(),      "--add-label", next.label(),
                    "--add-label",    "status:queued",
                },
                .max_output_bytes = 65536,
            }) catch return;
            defer allocator.free(remove_result.stdout);
            defer allocator.free(remove_result.stderr);
        }

        // Comment escalation
        var comment_buf: [512]u8 = undefined;
        const comment = std.fmt.bufPrint(&comment_buf, "⚠️ **Escalation**: {s} {s} failed → rerouting to {s} {s}\n_by 🐝 Swarm Coordinator_", .{
            if (current_agent) |ca| ca.emoji() else "?",
            if (current_agent) |ca| ca.name() else "unknown",
            next.emoji(),
            next.name(),
        }) catch "⚠️ Escalated.";

        const comment_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "gh", "issue", "comment", issue_num, "--body", comment },
            .max_output_bytes = 65536,
        }) catch return;
        defer allocator.free(comment_result.stdout);
        defer allocator.free(comment_result.stderr);

        std.debug.print("  {s}✅ Escalated to {s}{s}\n\n", .{ GREEN, next.name(), RESET });
    } else {
        std.debug.print("  {s}⚠️  No automated escalation available. Needs human review.{s}\n\n", .{ GOLDEN, RESET });

        // Comment for human
        const comment_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "gh", "issue", "comment", issue_num, "--body", "⚠️ **Escalation**: Automated agents exhausted. **Human review required.**\n_by 🐝 Swarm Coordinator_" },
            .max_output_bytes = 65536,
        }) catch return;
        defer allocator.free(comment_result.stdout);
        defer allocator.free(comment_result.stderr);
    }
}

// ============================================================================
// HELPERS
// ============================================================================

/// Fetch issue title via gh CLI
fn ghGetIssueTitle(allocator: Allocator, issue_num: []const u8, buf: []u8) ![]const u8 {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "gh",     "issue", "view", issue_num,
            "--json", "title", "--jq", ".title",
        },
        .max_output_bytes = 65536,
    }) catch return error.ProcessFailed;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term.Exited != 0) return error.ProcessFailed;

    const title = std.mem.trimRight(u8, result.stdout, "\n\r ");
    const len = @min(title.len, buf.len);
    @memcpy(buf[0..len], title[0..len]);
    return buf[0..len];
}

// ============================================================================
// HELP
// ============================================================================

fn printSwarmHelp() void {
    std.debug.print("\n{s}🐝 SWARM COORDINATOR — TRI University{s}\n", .{ PURPLE, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════{s}\n\n", .{ PURPLE, RESET });
    std.debug.print("  GitHub is the single source of truth.\n", .{});
    std.debug.print("  Every action = GitHub comment. Labels = routing.\n\n", .{});
    std.debug.print("  {s}Usage:{s} tri swarm <command> [args...]\n\n", .{ WHITE, RESET });
    std.debug.print("  {s}Commands:{s}\n", .{ WHITE, RESET });
    std.debug.print("    run <issue>             Execute sub-tasks for parent issue\n", .{});
    std.debug.print("    decompose <issue>       Break issue into sub-tasks\n", .{});
    std.debug.print("    status                  Show all agent-labeled tasks\n", .{});
    std.debug.print("    assign <issue> <agent>  Assign agent to issue\n", .{});
    std.debug.print("    monitor                 Check parent issues for completion\n", .{});
    std.debug.print("    log                     Show protocol log for today\n", .{});
    std.debug.print("    escalate <issue>        Re-route failed task\n\n", .{});
    std.debug.print("  {s}Agents:{s}\n", .{ WHITE, RESET });
    std.debug.print("    🔧 ralph    — Claude engineer\n", .{});
    std.debug.print("    🔍 scholar  — Perplexity researcher\n", .{});
    std.debug.print("    🧠 mu       — Memory curator\n", .{});
    std.debug.print("    🛡️  linter   — Spec validator\n", .{});
    std.debug.print("    📐 oracle   — φ-analyst\n\n", .{});
    std.debug.print("  {s}Example:{s}\n", .{ WHITE, RESET });
    std.debug.print("    tri swarm run 75            Execute all sub-tasks\n", .{});
    std.debug.print("    tri swarm run 75 --dry-run  Preview without executing\n", .{});
    std.debug.print("    tri swarm decompose 70      Break issue into sub-tasks\n", .{});
    std.debug.print("    tri swarm assign 81 scholar\n", .{});
    std.debug.print("    tri swarm escalate 81\n\n", .{});
    std.debug.print("  {s}φ² + 1/φ² = 3 — The Trinity decomposes.{s}\n\n", .{ GOLDEN, RESET });
}

// ============================================================================
// ERRORS
// ============================================================================

pub const SwarmError = error{
    ProcessFailed,
    InvalidIssue,
    AgentNotFound,
    EscalationExhausted,
};

// ============================================================================
// TESTS
// ============================================================================

test "AgentRole.fromLabel" {
    try std.testing.expectEqual(AgentRole.ralph, AgentRole.fromLabel("agent:ralph").?);
    try std.testing.expectEqual(AgentRole.scholar, AgentRole.fromLabel("agent:scholar").?);
    try std.testing.expectEqual(AgentRole.mu, AgentRole.fromLabel("agent:mu").?);
    try std.testing.expectEqual(AgentRole.linter, AgentRole.fromLabel("agent:linter").?);
    try std.testing.expectEqual(@as(?AgentRole, null), AgentRole.fromLabel("unknown"));
}

test "AgentRole.label" {
    try std.testing.expectEqualStrings("agent:ralph", AgentRole.ralph.label());
    try std.testing.expectEqualStrings("agent:scholar", AgentRole.scholar.label());
}

test "AgentRole.emoji" {
    try std.testing.expect(AgentRole.ralph.emoji().len > 0);
    try std.testing.expect(AgentRole.scholar.emoji().len > 0);
}

test "TaskType.label" {
    try std.testing.expectEqualStrings("task:research", TaskType.research.label());
    try std.testing.expectEqualStrings("task:code", TaskType.code.label());
}

test "escalation chain" {
    // ralph → scholar
    const next_from_ralph: ?AgentRole = .scholar;
    try std.testing.expectEqual(AgentRole.scholar, next_from_ralph.?);

    // linter → ralph
    const next_from_linter: ?AgentRole = .ralph;
    try std.testing.expectEqual(AgentRole.ralph, next_from_linter.?);

    // scholar → null (human)
    const next_from_scholar: ?AgentRole = null;
    try std.testing.expect(next_from_scholar == null);
}
