// @origin(spec:dev_github_integration.tri) @regen(manual-impl)
// Trinity S³AI: GitHub Integration for Rigid Process Framework
// Phase 4: Connect dev workflow to GitHub issues for audit trail
//
// φ² + 1/φ² = 3 = TRINITY
//

const std = @import("std");
const Allocator = std.mem.Allocator;
const github_commands = @import("github_commands.zig");

/// GitHub Issue Integration for Dev Workflow
pub const DevGithub = struct {
    // Create or update GitHub issue when starting dev session
    pub fn startIssue(allocator: Allocator, issue_number: u32, title: []const u8) !u32 {
        var issue_id_buf: [32]u8 = undefined;
        const issue_str = try std.fmt.allocPrint(allocator, "{d}", .{issue_number});
        defer allocator.free(issue_str);

        var i: usize = 0;
        while (i < issue_str.len) : (i += 1) {
            issue_id_buf[i] = issue_str[i];
        }

        const cmd = [_][]const u8{ "gh", "issue", "create", "--title", title, "--body", "Starting development session", "--label", "status:in-progress" };

        const result = try std.process.Child.run(.{
            .allocator = allocator,
            .argv = &cmd,
        });

        _ = result;

        // Extract issue number from response (simplified)
        if (result.term == .Exited and result.exit_code == 0) {
            std.debug.print("Created issue #{d} for dev session", .{issue_number});
            return issue_number;
        }

        return DevGithubError.GitFailed;
    }

    /// Post status update comment to GitHub issue
    pub fn postStatusUpdate(allocator: Allocator, issue_number: u32, status: []const u8, context: []const u8) !void {
        var status_buf = try std.ArrayList(u8).init(allocator);
        defer status_buf.deinit(allocator);

        try status_buf.writer().print("🔄 **Status**: {s}", .{status});
        if (context.len > 0) {
            try status_buf.writer().print("\n**Context**:\n{s}", .{context});
        }
        try status_buf.writer().print("\n**Agent**: Claude (tri dev)\n");
        const body = try status_buf.toOwnedSlice(allocator);

        const cmd = [_][]const u8{ "gh", "issue", "comment", &[_][]const u8{ issue_id_buf[0..std.fmt.count(issue_str.len)] }, "--body", body };

        const result = try std.process.Child.run(.{
            .allocator = allocator,
            .argv = &cmd,
        });

        _ = result;
    }

    /// Post test results comment
    pub fn postTestResults(allocator: Allocator, issue_number: u32, passed: bool, details: []const u8) !void {
        var comment_buf = try std.ArrayList(u8).init(allocator);
        defer comment_buf.deinit(allocator);

        try comment_buf.writer().print("🧪 **Test Results**: {s}\n", .{if (passed) "✅ PASSED" else "❌ FAILED"});

        if (details.len > 0) {
            try comment_buf.writer().print("\n**Details**:\n{s}", .{details});
        }

        const body = try comment_buf.toOwnedSlice(allocator);

        const cmd = [_][]const u8{ "gh", "issue", "comment", &[_][]const u8{ issue_id_buf[0..std.fmt.count(issue_str.len)] }, "--body", body };

        const result = try std.process.Child.run(.{
            .allocator = allocator,
            .argv = &cmd,
        });

        _ = result;
    }

    /// Post commit summary comment
    pub fn postCommitSummary(allocator: Allocator, issue_number: u32, files: []const []const u8, message: []const u8) !void {
        var comment_buf = try std.ArrayList(u8).init(allocator);
        defer comment_buf.deinit(allocator);

        try comment_buf.writer().print("📦 **Commit**: Files changed, ready for PR\n");

        if (files.len > 0) {
            try comment_buf.writer().print("\n**Files**:\n{s}", .{files});
        }

        try comment_buf.writer().print("\n**Message**:\n{s}", .{message});

        const body = try comment_buf.toOwnedSlice(allocator);

        const cmd = [_][]const u8{ "gh", "issue", "comment", &[_][]const u8{ issue_id_buf[0..std.fmt.count(issue_str.len)] }, "--body", body };

        const result = try std.process.Child.run(.{
            .allocator = allocator,
            .argv = &cmd,
        });

        _ = result;
    }
};

const DevGithubError = error{
    GitFailed,
    CommandFailed,
};
