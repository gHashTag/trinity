// @origin(spec:dev_github_integration.tri) @regen(manual-impl)
// Trinity S³AI: GitHub Integration for Rigid Process Framework
// Phase 4: Connect dev workflow to GitHub issues for audit trail
//
// φ² + 1/φ² = 3 = TRINITY
//

const std = @import("std");
const Allocator = std.mem.Allocator;

/// GitHub Issue Integration for Dev Workflow
pub const DevGithub = struct {
    // Create or update GitHub issue when starting dev session
    pub fn startIssue(allocator: Allocator, issue_number: u32, title: []const u8) !u32 {
        _ = title;
        const issue_str = try std.fmt.allocPrint(allocator, "{d}", .{issue_number});
        defer allocator.free(issue_str);

        const cmd = [_][]const u8{ "gh", "issue", "create", "--title", "Dev Session Started", "--body", "Starting development session", "--label", "status:in-progress" };

        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &cmd,
        }) catch |err| {
            std.debug.print("gh issue create failed: {}\n", .{err});
            return err;
        };
        defer {
            allocator.free(result.stdout);
            allocator.free(result.stderr);
        }

        if (result.term == .Exited and result.exit_code == 0) {
            std.debug.print("Created issue for dev session #{d}\n", .{issue_number});
            return issue_number;
        }

        return DevGithubError.GitFailed;
    }

    /// Post status update comment to GitHub issue
    pub fn postStatusUpdate(allocator: Allocator, issue_number: u32, status: []const u8, context: []const u8) !void {
        _ = context;
        var status_buf = try std.ArrayList(u8).init(allocator);
        defer status_buf.deinit();

        try status_buf.writer().print("🔄 **Status**: {s}\n", .{status});
        try status_buf.writer().print("**Agent**: Claude (tri dev)\n", .{});
        const body = try status_buf.toOwnedSlice(allocator);
        defer allocator.free(body);

        const issue_str = try std.fmt.allocPrint(allocator, "{d}", .{issue_number});
        defer allocator.free(issue_str);

        const cmd = [_][]const u8{ "gh", "issue", "comment", issue_str, "--body", body };

        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &cmd,
        }) catch |err| {
            std.debug.print("gh issue comment failed: {}\n", .{err});
            return err;
        };
        defer {
            allocator.free(result.stdout);
            allocator.free(result.stderr);
        }
    }

    /// Post test results comment
    pub fn postTestResults(allocator: Allocator, issue_number: u32, passed: bool, details: []const u8) !void {
        _ = details;
        var comment_buf = try std.ArrayList(u8).init(allocator);
        defer comment_buf.deinit();

        const status_str = if (passed) "✅ PASSED" else "❌ FAILED";
        try comment_buf.writer().print("🧪 **Test Results**: {s}\n", .{status_str});

        const body = try comment_buf.toOwnedSlice(allocator);
        defer allocator.free(body);

        const issue_str = try std.fmt.allocPrint(allocator, "{d}", .{issue_number});
        defer allocator.free(issue_str);

        const cmd = [_][]const u8{ "gh", "issue", "comment", issue_str, "--body", body };

        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &cmd,
        }) catch |err| {
            std.debug.print("gh issue comment failed: {}\n", .{err});
            return err;
        };
        defer {
            allocator.free(result.stdout);
            allocator.free(result.stderr);
        }
    }

    /// Post commit summary comment
    pub fn postCommitSummary(allocator: Allocator, issue_number: u32, files: []const []const u8, message: []const u8) !void {
        var comment_buf = try std.ArrayList(u8).init(allocator);
        defer comment_buf.deinit();

        try comment_buf.writer().print("📦 **Commit**: Files changed, ready for PR\n", .{});
        try comment_buf.writer().print("**Message**:\n{s}\n", .{message});

        const body = try comment_buf.toOwnedSlice(allocator);
        defer allocator.free(body);

        const issue_str = try std.fmt.allocPrint(allocator, "{d}", .{issue_number});
        defer allocator.free(issue_str);

        const cmd = [_][]const u8{ "gh", "issue", "comment", issue_str, "--body", body };

        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &cmd,
        }) catch |err| {
            std.debug.print("gh issue comment failed: {}\n", .{err});
            return err;
        };
        defer {
            allocator.free(result.stdout);
            allocator.free(result.stderr);
        }
    }
};

const DevGithubError = error{
    GitFailed,
    CommandFailed,
};
