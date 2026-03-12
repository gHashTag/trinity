// git_ops.zig — Git operations via child process for agent entrypoint
// Replaces bash git commands with typed Zig wrappers.
const std = @import("std");

pub const DiffStats = struct {
    files_changed: u32 = 0,
    insertions: u32 = 0,
    deletions: u32 = 0,
    summary: []const u8 = "",
    allocator: ?std.mem.Allocator = null,

    pub fn deinit(self: *DiffStats) void {
        if (self.allocator) |a| {
            if (self.summary.len > 0) a.free(self.summary);
        }
    }
};

/// Clone bare repo and set up worktree for the issue branch.
/// Returns the worktree path.
pub fn setupWorktree(
    allocator: std.mem.Allocator,
    repo_url: []const u8,
    issue_number: u32,
    gh_token: []const u8,
) ![]const u8 {
    // Build authenticated URL
    var auth_url_buf: [1024]u8 = undefined;
    const auth_url = try std.fmt.bufPrint(&auth_url_buf, "https://x-access-token:{s}@{s}", .{
        gh_token,
        stripProtocol(repo_url),
    });

    // Clone bare repo (or fetch if /bare-repo.git exists from Docker cache)
    const bare_path = "/bare-repo.git";
    if (std.fs.cwd().access(bare_path, .{})) {
        // Fetch latest
        _ = runGit(allocator, &.{ "git", "-C", bare_path, "fetch", "origin", "main", "--depth=1" }) catch {};
    } else |_| {
        // Fresh clone
        _ = try runGit(allocator, &.{ "git", "clone", "--bare", "--depth=1", "--single-branch", "--branch", "main", auth_url, bare_path });
    }

    // Create worktree
    var branch_buf: [128]u8 = undefined;
    const branch = try std.fmt.bufPrint(&branch_buf, "agent/issue-{d}", .{issue_number});

    const worktree_path = try std.fmt.allocPrint(allocator, "/workspace/issue-{d}", .{issue_number});

    // Create branch + worktree from main
    _ = runGit(allocator, &.{ "git", "-C", bare_path, "worktree", "add", "-b", branch, worktree_path, "origin/main" }) catch |err| {
        std.debug.print("[git] worktree add failed: {s}, trying without -b\n", .{@errorName(err)});
        // Branch may already exist
        _ = try runGit(allocator, &.{ "git", "-C", bare_path, "worktree", "add", worktree_path, branch });
    };

    // Set remote URL with auth (for push)
    _ = runGit(allocator, &.{ "git", "-C", worktree_path, "remote", "set-url", "origin", auth_url }) catch {};

    // Configure git user
    _ = runGit(allocator, &.{ "git", "-C", worktree_path, "config", "user.name", "Trinity Agent" }) catch {};
    _ = runGit(allocator, &.{ "git", "-C", worktree_path, "config", "user.email", "agent@trinity.dev" }) catch {};

    return worktree_path;
}

/// Push current branch to origin.
pub fn push(allocator: std.mem.Allocator, worktree_path: []const u8) !void {
    _ = try runGitRetry(allocator, &.{ "git", "-C", worktree_path, "push", "-u", "origin", "HEAD" }, 3);
}

/// Get diff stats between current branch and main.
pub fn diffStats(allocator: std.mem.Allocator, worktree_path: []const u8) DiffStats {
    const output = runGit(allocator, &.{ "git", "-C", worktree_path, "diff", "--stat", "origin/main..HEAD" }) catch return .{};

    const summary = allocator.dupe(u8, output) catch return .{};
    allocator.free(output);

    // Count files changed from stat output (lines containing '|')
    var files: u32 = 0;
    var lines_iter = std.mem.splitScalar(u8, summary, '\n');
    while (lines_iter.next()) |line| {
        if (std.mem.indexOf(u8, line, "|") != null) files += 1;
    }

    return .{
        .files_changed = files,
        .summary = summary,
        .allocator = allocator,
    };
}

/// Get current branch name.
pub fn currentBranch(allocator: std.mem.Allocator, worktree_path: []const u8) ?[]const u8 {
    const output = runGit(allocator, &.{ "git", "-C", worktree_path, "branch", "--show-current" }) catch return null;
    // Trim trailing newline
    const trimmed = std.mem.trim(u8, output, &std.ascii.whitespace);
    if (trimmed.len == 0) {
        allocator.free(output);
        return null;
    }
    const result = allocator.dupe(u8, trimmed) catch {
        allocator.free(output);
        return null;
    };
    allocator.free(output);
    return result;
}

// ── internal ──

fn stripProtocol(url: []const u8) []const u8 {
    if (std.mem.startsWith(u8, url, "https://")) return url[8..];
    if (std.mem.startsWith(u8, url, "http://")) return url[7..];
    return url;
}

fn runGit(allocator: std.mem.Allocator, argv: []const []const u8) ![]const u8 {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .max_output_bytes = 256 * 1024,
    });
    allocator.free(result.stderr);

    switch (result.term) {
        .Exited => |code| {
            if (code != 0) {
                allocator.free(result.stdout);
                return error.GitCommandFailed;
            }
        },
        else => {
            allocator.free(result.stdout);
            return error.GitCommandFailed;
        },
    }

    return result.stdout;
}

fn runGitRetry(allocator: std.mem.Allocator, argv: []const []const u8, max_attempts: u8) ![]const u8 {
    var attempt: u8 = 0;
    while (attempt < max_attempts) : (attempt += 1) {
        if (runGit(allocator, argv)) |output| return output else |err| {
            if (attempt + 1 < max_attempts) {
                std.debug.print("[git] attempt {d}/{d} failed: {s}, retrying...\n", .{ attempt + 1, max_attempts, @errorName(err) });
                std.Thread.sleep(2 * std.time.ns_per_s);
            } else return err;
        }
    }
    unreachable;
}

test "stripProtocol" {
    try std.testing.expectEqualStrings("github.com/foo/bar.git", stripProtocol("https://github.com/foo/bar.git"));
    try std.testing.expectEqualStrings("github.com/foo/bar.git", stripProtocol("http://github.com/foo/bar.git"));
    try std.testing.expectEqualStrings("github.com/foo", stripProtocol("github.com/foo"));
}
