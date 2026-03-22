// @origin(spec:issue_github.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// Issue GitHub Agent — Extended GitHub Issue management for Trinity
// ═══════════════════════════════════════════════════════════════════════════════
//
// Extends github_commands.zig with new task types and parameters:
// - Task Types: ISSUE_CODE, ISSUE_RESEARCH, ISSUE_BUG, ISSUE_FEATURE, ISSUE_DOCS,
//                ISSUE_REFACTOR, ISSUE_MILESTONE, ISSUE_DEPLOY
// - Priority: CRITICAL, HIGH, MEDIUM, LOW
// - Blocking: NONE, BLOCKS_OTHERS, REQUIRES_BUILD, REQUIRES_TEST, REQUIRES_REVIEW, REQUIRES_DEPLOY
// - Dependencies: --depends-on flag
// - Acceptance Criteria: --acceptance flag
// - Files: --files flag
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const github_client = @import("../github_client.zig");
const github_commands = @import("../github_commands.zig");

// ANSI colors
const GREEN = "\x1b[38;2;0;229;153m";
const GOLDEN = "\x1b[38;2;255;215;0m";
const RED = "\x1b[38;2;255;85;85m";
const CYAN = "\x1b[38;2;0;200;255m";
const RESET = "\x1b[0m";

// ═══════════════════════════════════════════════════════════════════════════════
// Task Type Enumeration
// ═══════════════════════════════════════════════════════════════════════════════

pub const TaskType = enum(u8) {
    ISSUE_CODE = 0,
    ISSUE_RESEARCH = 1,
    ISSUE_BUG = 2,
    ISSUE_FEATURE = 3,
    ISSUE_DOCS = 4,
    ISSUE_REFACTOR = 5,
    ISSUE_MILESTONE = 6,
    ISSUE_DEPLOY = 7,

    pub fn displayName(self: TaskType) []const u8 {
        return switch (self) {
            .ISSUE_CODE => "CODE",
            .ISSUE_RESEARCH => "RESEARCH",
            .ISSUE_BUG => "BUG",
            .ISSUE_FEATURE => "FEATURE",
            .ISSUE_DOCS => "DOCS",
            .ISSUE_REFACTOR => "REFACTOR",
            .ISSUE_MILESTONE => "MILESTONE",
            .ISSUE_DEPLOY => "DEPLOY",
        };
    }

    pub fn emoji(self: TaskType) []const u8 {
        return switch (self) {
            .ISSUE_CODE => "💻",
            .ISSUE_RESEARCH => "🔬",
            .ISSUE_BUG => "🐛",
            .ISSUE_FEATURE => "✨",
            .ISSUE_DOCS => "📚",
            .ISSUE_REFACTOR => "♻️",
            .ISSUE_MILESTONE => "🏁",
            .ISSUE_DEPLOY => "🚀",
        };
    }

    pub fn fromString(s: []const u8) ?TaskType {
        if (std.mem.eql(u8, s, "CODE")) return .ISSUE_CODE;
        if (std.mem.eql(u8, s, "RESEARCH")) return .ISSUE_RESEARCH;
        if (std.mem.eql(u8, s, "BUG")) return .ISSUE_BUG;
        if (std.mem.eql(u8, s, "FEATURE")) return .ISSUE_FEATURE;
        if (std.mem.eql(u8, s, "DOCS")) return .ISSUE_DOCS;
        if (std.mem.eql(u8, s, "REFACTOR")) return .ISSUE_REFACTOR;
        if (std.mem.eql(u8, s, "MILESTONE")) return .ISSUE_MILESTONE;
        if (std.mem.eql(u8, s, "DEPLOY")) return .ISSUE_DEPLOY;
        return null;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Priority Enumeration
// ═══════════════════════════════════════════════════════════════════════════════

pub const TaskPriority = enum(u8) {
    CRITICAL = 0,
    HIGH = 1,
    MEDIUM = 2,
    LOW = 3,

    pub fn displayName(self: TaskPriority) []const u8 {
        return switch (self) {
            .CRITICAL => "CRITICAL",
            .HIGH => "HIGH",
            .MEDIUM => "MEDIUM",
            .LOW => "LOW",
        };
    }

    pub fn emoji(self: TaskPriority) []const u8 {
        return switch (self) {
            .CRITICAL => "🔴",
            .HIGH => "🟠",
            .MEDIUM => "🟡",
            .LOW => "🟢",
        };
    }

    pub fn labelName(self: TaskPriority) []const u8 {
        return switch (self) {
            .CRITICAL => "priority:P1",
            .HIGH => "priority:P2",
            .MEDIUM => "priority:P3",
            .LOW => "priority:P4",
        };
    }

    pub fn fromString(s: []const u8) ?TaskPriority {
        if (std.mem.eql(u8, s, "CRITICAL")) return .CRITICAL;
        if (std.mem.eql(u8, s, "HIGH")) return .HIGH;
        if (std.mem.eql(u8, s, "MEDIUM")) return .MEDIUM;
        if (std.mem.eql(u8, s, "LOW")) return .LOW;
        if (std.mem.eql(u8, s, "P1")) return .CRITICAL;
        if (std.mem.eql(u8, s, "P2")) return .HIGH;
        if (std.mem.eql(u8, s, "P3")) return .MEDIUM;
        if (std.mem.eql(u8, s, "P4")) return .LOW;
        return null;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Blocking Enumeration
// ═══════════════════════════════════════════════════════════════════════════════

pub const TaskBlocking = enum(u8) {
    NONE = 0,
    BLOCKS_OTHERS = 1,
    REQUIRES_BUILD = 2,
    REQUIRES_TEST = 3,
    REQUIRES_REVIEW = 4,
    REQUIRES_DEPLOY = 5,

    pub fn displayName(self: TaskBlocking) []const u8 {
        return switch (self) {
            .NONE => "none",
            .BLOCKS_OTHERS => "blocks_others",
            .REQUIRES_BUILD => "requires_build",
            .REQUIRES_TEST => "requires_test",
            .REQUIRES_REVIEW => "requires_review",
            .REQUIRES_DEPLOY => "requires_deploy",
        };
    }

    pub fn labelName(self: TaskBlocking) []const u8 {
        return switch (self) {
            .NONE => "blocking:none",
            .BLOCKS_OTHERS => "blocking:blocks_others",
            .REQUIRES_BUILD => "blocking:requires_build",
            .REQUIRES_TEST => "blocking:requires_test",
            .REQUIRES_REVIEW => "blocking:requires_review",
            .REQUIRES_DEPLOY => "blocking:requires_deploy",
        };
    }

    pub fn weight(self: TaskBlocking) u8 {
        return switch (self) {
            .NONE => 0,
            .BLOCKS_OTHERS => 10,
            .REQUIRES_BUILD => 50,
            .REQUIRES_TEST => 30,
            .REQUIRES_REVIEW => 20,
            .REQUIRES_DEPLOY => 40,
        };
    }

    pub fn fromString(s: []const u8) ?TaskBlocking {
        if (std.mem.eql(u8, s, "none")) return .NONE;
        if (std.mem.eql(u8, s, "blocks_others")) return .BLOCKS_OTHERS;
        if (std.mem.eql(u8, s, "requires_build")) return .REQUIRES_BUILD;
        if (std.mem.eql(u8, s, "requires_test")) return .REQUIRES_TEST;
        if (std.mem.eql(u8, s, "requires_review")) return .REQUIRES_REVIEW;
        if (std.mem.eql(u8, s, "requires_deploy")) return .REQUIRES_DEPLOY;
        return null;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Acceptance Criterion Enumeration
// ═══════════════════════════════════════════════════════════════════════════════

pub const AcceptanceCriterion = enum(u8) {
    UNIT_TEST_PASS = 0,
    ALL_TESTS_PASS = 1,
    DOCUMENTATION_APPROVED = 2,
    CODE_REVIEW_APPROVED = 3,
    BENCHMARKS_PASS = 4,
    SECURITY_CHECK = 5,

    pub fn displayName(self: AcceptanceCriterion) []const u8 {
        return switch (self) {
            .UNIT_TEST_PASS => "unit_test_pass",
            .ALL_TESTS_PASS => "all_tests_pass",
            .DOCUMENTATION_APPROVED => "documentation_approved",
            .CODE_REVIEW_APPROVED => "code_review_approved",
            .BENCHMARKS_PASS => "benchmarks_pass",
            .SECURITY_CHECK => "security_check",
        };
    }

    pub fn labelName(self: AcceptanceCriterion) []const u8 {
        return switch (self) {
            .UNIT_TEST_PASS => "acceptance:unit_test",
            .ALL_TESTS_PASS => "acceptance:all_tests",
            .DOCUMENTATION_APPROVED => "acceptance:docs_approved",
            .CODE_REVIEW_APPROVED => "acceptance:review_approved",
            .BENCHMARKS_PASS => "acceptance:benchmarks",
            .SECURITY_CHECK => "acceptance:security",
        };
    }

    pub fn fromString(s: []const u8) ?AcceptanceCriterion {
        if (std.mem.eql(u8, s, "unit_test")) return .UNIT_TEST_PASS;
        if (std.mem.eql(u8, s, "all_tests")) return .ALL_TESTS_PASS;
        if (std.mem.eql(u8, s, "docs")) return .DOCUMENTATION_APPROVED;
        if (std.mem.eql(u8, s, "review")) return .CODE_REVIEW_APPROVED;
        if (std.mem.eql(u8, s, "benchmarks")) return .BENCHMARKS_PASS;
        if (std.mem.eql(u8, s, "security")) return .SECURITY_CHECK;
        return null;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Extended Issue Creation Parameters
// ═══════════════════════════════════════════════════════════════════════════════

pub const CreateAgentTaskOptions = struct {
    title: []const u8,
    body: ?[]const u8 = null,
    task_type: TaskType = .ISSUE_CODE,
    priority: TaskPriority = .MEDIUM,
    blocking: TaskBlocking = .NONE,
    depends_on: ?[]const u32 = null,
    acceptance: ?[]const AcceptanceCriterion = null,
    files: ?[]const []const u8 = null,
    labels: ?[]const []const u8 = null,
    agent_name: ?[]const u8 = null,
    parent: ?u32 = null,
    time_estimate: ?[]const u8 = null,
};

// ═══════════════════════════════════════════════════════════════════════════════
// Main function: Create Agent Task with extended parameters
// ═══════════════════════════════════════════════════════════════════════════════

/// Create a GitHub issue with extended agent task parameters
/// Usage: tri agent create-task <title> [flags]
///
/// Flags:
///   --type <TYPE>              Task type (CODE|RESEARCH|BUG|FEATURE|DOCS|REFACTOR|MILESTONE|DEPLOY)
///   --priority <PRIORITY>        Priority (CRITICAL|HIGH|MEDIUM|LOW or P1|P2|P3|P4)
///   --blocking <TYPE>           Blocking relationship (none|blocks_others|requires_build|requires_test|requires_review|requires_deploy)
///   --depends-on <N,N,...>      Issue numbers this task depends on
///   --acceptance <C1,C2,...>    Acceptance criteria (unit_test|all_tests|docs|review|benchmarks|security)
///   --files <PATH,PATH,...>     Related file paths
///   --labels <L1,L2,...>        Additional labels
///   --agent <NAME>              Agent name (adds agent:NAME label)
///   --parent <N>                Parent issue number
///   --body <TEXT>               Issue body
///   --time-estimate <TEXT>      Time estimate (e.g., "2h", "1d")
pub fn createAgentTask(allocator: std.mem.Allocator, options: CreateAgentTaskOptions) !u32 {
    // Build extended body
    var body_buf = std.ArrayList(u8).init(allocator);
    defer body_buf.deinit();

    // Add header with task type
    try body_buf.writer().print("{s} {s}\n\n", .{ options.task_type.emoji(), options.task_type.displayName() });

    // Add body text if provided
    if (options.body) |b| {
        try body_buf.writer().print("{s}\n\n", .{b});
    }

    // Add structured metadata section
    try body_buf.writer().print("---\n\n", .{});

    // Add priority
    try body_buf.writer().print("**Priority**: {s} {s}\n", .{ options.priority.emoji(), options.priority.displayName() });

    // Add blocking info if set
    if (options.blocking != .NONE) {
        try body_buf.writer().print("**Blocking**: {s}\n", .{options.blocking.displayName()});
    }

    // Add dependencies if any
    if (options.depends_on) |deps| {
        try body_buf.writer().print("**Dependencies**: ", .{});
        for (deps, 0..) |dep, i| {
            if (i > 0) try body_buf.writer().print(", ", .{});
            try body_buf.writer().print("#{d}", .{dep});
        }
        try body_buf.writer().print("\n", .{});
    }

    // Add acceptance criteria if any
    if (options.acceptance) |criteria| {
        try body_buf.writer().print("**Acceptance Criteria**:\n", .{});
        for (criteria) |c| {
            try body_buf.writer().print("  - {s}\n", .{c.displayName()});
        }
        try body_buf.writer().print("\n", .{});
    }

    // Add files if any
    if (options.files) |files| {
        try body_buf.writer().print("**Files**:\n", .{});
        for (files) |file| {
            try body_buf.writer().print("  - `{s}`\n", .{file});
        }
        try body_buf.writer().print("\n", .{});
    }

    // Add time estimate if provided
    if (options.time_estimate) |te| {
        try body_buf.writer().print("**Time Estimate**: {s}\n", .{te});
    }

    // Add parent reference if set
    if (options.parent) |p| {
        try body_buf.writer().print("**Parent**: #{d}\n", .{p});
    }

    // Build labels list
    var labels_list = try std.ArrayList([]const u8).initCapacity(allocator, 16);
    defer labels_list.deinit(allocator);

    // Add task type label
    const type_label = try std.fmt.allocPrint(allocator, "type:{s}", .{options.task_type.displayName()});
    try labels_list.append(allocator, type_label);

    // Add priority label
    try labels_list.append(allocator, options.priority.labelName());

    // Add blocking label if set
    if (options.blocking != .NONE) {
        try labels_list.append(allocator, options.blocking.labelName());
    }

    // Add acceptance criteria labels
    if (options.acceptance) |criteria| {
        for (criteria) |c| {
            try labels_list.append(allocator, c.labelName());
        }
    }

    // Add custom labels if provided
    if (options.labels) |custom_labels| {
        for (custom_labels) |label| {
            try labels_list.append(allocator, label);
        }
    }

    // Add agent label if specified
    if (options.agent_name) |agent| {
        const agent_label = try std.fmt.allocPrint(allocator, "agent:{s}", .{agent});
        try labels_list.append(allocator, agent_label);
    }

    // Create issue using GitHub client
    var client = try github_client.GitHubClient.init(allocator, false);
    defer client.deinit();

    const result = try client.createIssue(options.title, body_buf.items, labels_list.items);

    // Log to protocol
    try appendProtocolLog(allocator, "agent_task_create", result.number, options.agent_name, true);

    // Print success message
    std.debug.print("{s}✅ Created {s} task #{d}{s}\n", .{ GREEN, options.task_type.displayName(), result.number, RESET });
    std.debug.print("   {s}{s}{s}\n", .{ CYAN, result.url, RESET });

    return result.number;
}

/// Parse command line arguments into CreateAgentTaskOptions
pub fn parseCreateTaskArgs(allocator: std.mem.Allocator, args: []const []const u8) !CreateAgentTaskOptions {
    if (args.len == 0) {
        return error.MissingTitle;
    }

    var options = CreateAgentTaskOptions{
        .title = args[0],
        .task_type = .ISSUE_CODE,
        .priority = .MEDIUM,
        .blocking = .NONE,
    };

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--type") and i + 1 < args.len) {
            i += 1;
            if (TaskType.fromString(args[i])) |t| {
                options.task_type = t;
            } else {
                std.debug.print("{s}Unknown task type: {s}{s}\n", .{ RED, args[i], RESET });
                return error.InvalidTaskType;
            }
        } else if (std.mem.eql(u8, arg, "--priority") and i + 1 < args.len) {
            i += 1;
            if (TaskPriority.fromString(args[i])) |p| {
                options.priority = p;
            } else {
                std.debug.print("{s}Unknown priority: {s}{s}\n", .{ RED, args[i], RESET });
                return error.InvalidPriority;
            }
        } else if (std.mem.eql(u8, arg, "--blocking") and i + 1 < args.len) {
            i += 1;
            if (TaskBlocking.fromString(args[i])) |b| {
                options.blocking = b;
            } else {
                std.debug.print("{s}Unknown blocking type: {s}{s}\n", .{ RED, args[i], RESET });
                return error.InvalidBlocking;
            }
        } else if (std.mem.eql(u8, arg, "--depends-on") and i + 1 < args.len) {
            i += 1;
            var deps_list = std.ArrayList(u32).initCapacity(allocator, 0);
            errdefer deps_list.deinit();

            var iter = std.mem.splitScalar(u8, args[i], ',');
            while (iter.next()) |dep_str| {
                const trimmed = std.mem.trim(u8, dep_str, &[_]u8{' '});
                const dep = std.fmt.parseInt(u32, trimmed, 10) catch |err| {
                    std.debug.print("{s}Invalid dependency number: {s} ({}){s}\n", .{ RED, trimmed, err, RESET });
                    continue;
                };
                try deps_list.append(allocator, dep);
            }
            if (deps_list.items.len > 0) {
                const deps_copy = try allocator.dupe(u32, deps_list.items);
                options.depends_on = deps_copy;
            }
        } else if (std.mem.eql(u8, arg, "--acceptance") and i + 1 < args.len) {
            i += 1;
            var acc_list = std.ArrayList(AcceptanceCriterion).init(allocator);
            errdefer acc_list.deinit();

            var iter = std.mem.splitScalar(u8, args[i], ',');
            while (iter.next()) |acc_str| {
                const trimmed = std.mem.trim(u8, acc_str, &[_]u8{' '});
                if (AcceptanceCriterion.fromString(trimmed)) |c| {
                    try acc_list.append(allocator, c);
                } else {
                    std.debug.print("{s}Unknown acceptance criterion: {s}{s}\n", .{ RED, trimmed, RESET });
                }
            }
            if (acc_list.items.len > 0) {
                const acc_copy = try allocator.dupe(AcceptanceCriterion, acc_list.items);
                options.acceptance = acc_copy;
            }
        } else if (std.mem.eql(u8, arg, "--files") and i + 1 < args.len) {
            i += 1;
            var files_list = std.ArrayList([]const u8).init(allocator);
            errdefer files_list.deinit();

            var iter = std.mem.splitScalar(u8, args[i], ',');
            while (iter.next()) |file_str| {
                const trimmed = std.mem.trim(u8, file_str, &[_]u8{' '});
                try files_list.append(allocator, trimmed);
            }
            if (files_list.items.len > 0) {
                const files_copy = try allocator.dupe([]const u8, files_list.items);
                options.files = files_copy;
            }
        } else if (std.mem.eql(u8, arg, "--labels") and i + 1 < args.len) {
            i += 1;
            var labels_list = std.ArrayList([]const u8).init(allocator);
            errdefer labels_list.deinit();

            var iter = std.mem.splitScalar(u8, args[i], ',');
            while (iter.next()) |label_str| {
                const trimmed = std.mem.trim(u8, label_str, &[_]u8{' '});
                try labels_list.append(allocator, trimmed);
            }
            if (labels_list.items.len > 0) {
                const labels_copy = try allocator.dupe([]const u8, labels_list.items);
                options.labels = labels_copy;
            }
        } else if (std.mem.eql(u8, arg, "--agent") and i + 1 < args.len) {
            i += 1;
            options.agent_name = args[i];
        } else if (std.mem.eql(u8, arg, "--parent") and i + 1 < args.len) {
            i += 1;
            options.parent = std.fmt.parseInt(u32, args[i], 10) catch null;
        } else if (std.mem.eql(u8, arg, "--body") and i + 1 < args.len) {
            i += 1;
            options.body = args[i];
        } else if (std.mem.eql(u8, arg, "--time-estimate") and i + 1 < args.len) {
            i += 1;
            options.time_estimate = args[i];
        }
    }

    return options;
}

/// Main entry point for `tri agent create-task` command
pub fn runCreateTaskCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        printCreateTaskHelp();
        return;
    }

    const options = try parseCreateTaskArgs(allocator, args);
    _ = try createAgentTask(allocator, options);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Update Task Status Command
// ═══════════════════════════════════════════════════════════════════════════════

pub const UpdateTaskOptions = struct {
    issue_number: u32,
    status: ?[]const u8 = null,
    progress: ?u8 = null,
    result: ?[]const u8 = null,
    blocking: ?TaskBlocking = null,
};

/// Update task status and post formatted comment
pub fn updateTaskStatus(allocator: std.mem.Allocator, options: UpdateTaskOptions) !void {
    var comment_buf = std.ArrayList(u8).init(allocator);
    defer comment_buf.deinit();

    try comment_buf.writer().print("🔄 **Status Update**\n\n", .{});

    if (options.status) |status| {
        try comment_buf.writer().print("**Status**: {s}\n", .{status});
    }

    if (options.progress) |p| {
        try comment_buf.writer().print("**Progress**: {d}%\n", .{p});
    }

    if (options.result) |result| {
        try comment_buf.writer().print("**Result**: {s}\n", .{result});
    }

    if (options.blocking) |blocking| {
        try comment_buf.writer().print("**Blocking**: {s}\n", .{blocking.displayName()});
    }

    var client = try github_client.GitHubClient.init(allocator, false);
    defer client.deinit();

    try client.commentIssue(options.issue_number, comment_buf.items);

    // Update labels based on status
    if (options.status) |status| {
        if (std.mem.eql(u8, status, "in-progress")) {
            client.removeLabels(options.issue_number, &.{ "status:pending", "status:queued" }) catch {};
            try client.addLabels(options.issue_number, &.{"status:in-progress"});
        } else if (std.mem.eql(u8, status, "done") or std.mem.eql(u8, status, "completed")) {
            client.removeLabels(options.issue_number, &.{ "status:in-progress", "agent:running" }) catch {};
            try client.addLabels(options.issue_number, &.{"status:in-review"});
        }
    }

    std.debug.print("{s}✅ Updated issue #{d}{s}\n", .{ GREEN, options.issue_number, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helper Functions
// ═══════════════════════════════════════════════════════════════════════════════

fn appendProtocolLog(allocator: std.mem.Allocator, action: []const u8, issue: u32, agent: ?[]const u8, ok: bool) !void {
    const protocol_dir = ".trinity/protocol";
    std.fs.cwd().makePath(protocol_dir) catch |err| {
        std.log.warn("issue_github: makePath ({s}) failed: {}", .{ protocol_dir, err });
    };

    const date_str = try getDateStr(allocator);
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

fn getDateStr(allocator: std.mem.Allocator) ![]u8 {
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

fn printCreateTaskHelp() void {
    std.debug.print(
        \\{0s}Create Agent Task — Extended GitHub Issue Management{1s}
        \\
        \\Usage: tri agent create-task <title> [flags]
        \\
        \\Flags:
        \\  --type <TYPE>              Task type (CODE|RESEARCH|BUG|FEATURE|DOCS|REFACTOR|MILESTONE|DEPLOY)
        \\  --priority <PRIORITY>        Priority (CRITICAL|HIGH|MEDIUM|LOW or P1|P2|P3|P4)
        \\  --blocking <TYPE>           Blocking relationship (none|blocks_others|requires_build|requires_test|requires_review|requires_deploy)
        \\  --depends-on <N,N,...>      Issue numbers this task depends on
        \\  --acceptance <C1,C2,...>    Acceptance criteria (unit_test|all_tests|docs|review|benchmarks|security)
        \\  --files <PATH,PATH,...>     Related file paths
        \\  --labels <L1,L2,...>        Additional labels
        \\  --agent <NAME>              Agent name (adds agent:NAME label)
        \\  --parent <N>                Parent issue number
        \\  --body <TEXT>               Issue body
        \\  --time-estimate <TEXT>      Time estimate (e.g., "2h", "1d")
        \\
        \\Examples:
        \\  tri agent create-task "Fix memory leak" --type BUG --priority CRITICAL
        \\  tri agent create-task "Add GPU support" --type FEATURE --priority HIGH --acceptance unit_test,benchmarks
        \\  tri agent create-task "Update docs" --type DOCS --priority LOW --files README.md,docs/api.md
        \\  tri agent create-task "Refactor parser" --type REFACTOR --blocking requires_test --depends-on 123,124
        \\
    , .{ CYAN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "TaskType fromString" {
    try std.testing.expectEqual(TaskType.ISSUE_CODE, TaskType.fromString("CODE").?);
    try std.testing.expectEqual(TaskType.ISSUE_RESEARCH, TaskType.fromString("RESEARCH").?);
    try std.testing.expectEqual(TaskType.ISSUE_BUG, TaskType.fromString("BUG").?);
    try std.testing.expectEqual(TaskType.ISSUE_FEATURE, TaskType.fromString("FEATURE").?);
    try std.testing.expect(TaskType.fromString("INVALID") == null);
}

test "TaskPriority fromString" {
    try std.testing.expectEqual(TaskPriority.CRITICAL, TaskPriority.fromString("CRITICAL").?);
    try std.testing.expectEqual(TaskPriority.HIGH, TaskPriority.fromString("HIGH").?);
    try std.testing.expectEqual(TaskPriority.MEDIUM, TaskPriority.fromString("MEDIUM").?);
    try std.testing.expectEqual(TaskPriority.LOW, TaskPriority.fromString("LOW").?);
    try std.testing.expectEqual(TaskPriority.CRITICAL, TaskPriority.fromString("P1").?);
    try std.testing.expect(TaskPriority.HIGH, TaskPriority.fromString("P2").?);
    try std.testing.expect(TaskPriority.MEDIUM, TaskPriority.fromString("P3").?);
    try std.testing.expect(TaskPriority.LOW, TaskPriority.fromString("P4").?);
    try std.testing.expect(TaskPriority.fromString("INVALID") == null);
}

test "TaskBlocking weight" {
    try std.testing.expectEqual(@as(u8, 0), TaskBlocking.NONE.weight());
    try std.testing.expectEqual(@as(u8, 10), TaskBlocking.BLOCKS_OTHERS.weight());
    try std.testing.expectEqual(@as(u8, 50), TaskBlocking.REQUIRES_BUILD.weight());
    try std.testing.expectEqual(@as(u8, 30), TaskBlocking.REQUIRES_TEST.weight());
    try std.testing.expectEqual(@as(u8, 20), TaskBlocking.REQUIRES_REVIEW.weight());
    try std.testing.expectEqual(@as(u8, 40), TaskBlocking.REQUIRES_DEPLOY.weight());
}

test "AcceptanceCriterion displayName" {
    try std.testing.expectEqualStrings("unit_test_pass", AcceptanceCriterion.UNIT_TEST_PASS.displayName());
    try std.testing.expectEqualStrings("all_tests_pass", AcceptanceCriterion.ALL_TESTS_PASS.displayName());
    try std.testing.expectEqualStrings("documentation_approved", AcceptanceCriterion.DOCUMENTATION_APPROVED.displayName());
}
