// context_builder.zig — Assemble structured wake prompt for Claude CLI
const std = @import("std");
const github_poller = @import("github_poller.zig");

pub const WakeContext = struct {
    identity: []const u8,
    handover_content: ?[]const u8,
    issues_json: ?[]const u8,
    current_issue: ?[]const u8,
    current_branch: ?[]const u8,
    wake_count: u32,
};

const instructions =
    \\You are Ralph, an autonomous development agent. Follow this protocol:
    \\
    \\1. Read HANDOVER above — understand where the previous session left off
    \\2. Pick the highest-priority pending issue (or continue current one)
    \\3. Claim the issue: add `status:in-progress` label, assign yourself
    \\4. Create branch: `ralph/w1/{issue-slug}`
    \\5. Implement via Golden Chain: spec → gen → test → assess → commit
    \\6. Run quality gates: `zig build && zig build test && zig fmt --check src/`
    \\7. Create PR with `Closes #{N}` in body
    \\8. BEFORE SESSION ENDS: Write .ralph/HANDOVER.md with:
    \\   - What was accomplished
    \\   - Current branch and issue
    \\   - What needs to happen next
    \\   - Any blockers or concerns
    \\
    \\CRITICAL: Always write HANDOVER.md before finishing. This is your memory.
;

/// Build a structured prompt from all context sources.
pub fn build(allocator: std.mem.Allocator, ctx: WakeContext) ![]const u8 {
    const handover_section = ctx.handover_content orelse "No handover found. This is a fresh start.";
    const issue_section = ctx.current_issue orelse "none";
    const branch_section = ctx.current_branch orelse "none";

    // Build issues summary
    var issue_summary: []const u8 = "No pending issues found. Agent should be IDLE.";
    var issue_summary_allocated = false;
    defer if (issue_summary_allocated) allocator.free(issue_summary);

    if (ctx.issues_json) |json| {
        const max_json = @min(json.len, 4096);
        const num = github_poller.extractFirstIssueNumber(json);
        const title = github_poller.extractFirstIssueTitle(json);

        if (num) |n| {
            if (title) |t| {
                issue_summary = std.fmt.allocPrint(allocator, "First pending: #{d} — {s}\n\n```json\n{s}\n```", .{ n, t, json[0..max_json] }) catch "Issues available (format error)";
                issue_summary_allocated = true;
            } else {
                issue_summary = std.fmt.allocPrint(allocator, "First pending: #{d}\n\n```json\n{s}\n```", .{ n, json[0..max_json] }) catch "Issues available (format error)";
                issue_summary_allocated = true;
            }
        } else {
            issue_summary = std.fmt.allocPrint(allocator, "```json\n{s}\n```", .{json[0..max_json]}) catch "Issues available (format error)";
            issue_summary_allocated = true;
        }
    }

    return std.fmt.allocPrint(allocator,
        \\# IDENTITY
        \\
        \\{s}
        \\
        \\# HANDOVER FROM PREVIOUS SESSION
        \\
        \\{s}
        \\
        \\# CURRENT STATE
        \\
        \\- Wake count: {d}
        \\- Current issue: {s}
        \\- Current branch: {s}
        \\
        \\# PENDING GITHUB ISSUES
        \\
        \\{s}
        \\
        \\# INSTRUCTIONS
        \\
        \\{s}
        \\
    , .{
        ctx.identity,
        handover_section,
        ctx.wake_count,
        issue_section,
        branch_section,
        issue_summary,
        instructions,
    });
}

test "build produces structured prompt" {
    const allocator = std.testing.allocator;
    const ctx = WakeContext{
        .identity = "Test identity",
        .handover_content = null,
        .issues_json = null,
        .current_issue = null,
        .current_branch = null,
        .wake_count = 1,
    };
    const prompt = try build(allocator, ctx);
    defer allocator.free(prompt);
    try std.testing.expect(std.mem.indexOf(u8, prompt, "IDENTITY") != null);
    try std.testing.expect(std.mem.indexOf(u8, prompt, "INSTRUCTIONS") != null);
    try std.testing.expect(std.mem.indexOf(u8, prompt, "Wake count: 1") != null);
}
