//! Git Integration - High-level git operations using process.zig
//! Provides branch management, commit operations, and safety checks

const std = @import("std");
const Allocator = std.mem.Allocator;
const process = @import("process.zig");

pub const GitError = error{
    NotAGitRepository,
    DetachedHead,
    MainBranchProtected,
    CommitFailed,
    BranchCreationFailed,
    MergeConflict,
    ProcessError,
} || process.ProcessError;

pub const GitStatus = struct {
    branch: []const u8,
    staged: u32,
    unstaged: u32,
    untracked: u32,
    ahead: u32,
    behind: u32,

    pub fn deinit(self: *GitStatus, allocator: Allocator) void {
        allocator.free(self.branch);
    }
};

pub const CommitInfo = struct {
    sha: []const u8,
    short_sha: []const u8,
    message: []const u8,
    author: []const u8,
    timestamp: i64,

    pub fn deinit(self: *CommitInfo, allocator: Allocator) void {
        allocator.free(self.sha);
        allocator.free(self.short_sha);
        allocator.free(self.message);
        allocator.free(self.author);
    }
};

/// Get current git branch name
pub fn getCurrentBranch(allocator: Allocator) ![]const u8 {
    var result = try process.git(allocator, &[_][]const u8{"branch", "--show-current"});
    defer result.deinit(allocator);

    if (result.exit_code != 0) {
        return GitError.NotAGitRepository;
    }

    const branch = std.mem.trim(u8, result.stdout, " \t\r\n");
    return allocator.dupe(u8, branch);
}

/// Check if currently on main/master branch
pub fn isMainBranch() bool {
    const allocator = std.heap.page_allocator;
    const branch = getCurrentBranch(allocator) catch return false;
    defer allocator.free(branch);

    return std.mem.eql(u8, branch, "main") or std.mem.eql(u8, branch, "master");
}

/// Create a new feature branch from current HEAD
pub fn createFeatureBranch(allocator: Allocator, task_slug: []const u8) !void {
    if (isMainBranch()) {
        return GitError.MainBranchProtected;
    }

    const branch_name = try std.fmt.allocPrint(allocator, "ralph/{s}", .{task_slug});
    defer allocator.free(branch_name);

    var result = try process.git(allocator, &[_][]const u8{ "checkout", "-b", branch_name });
    defer result.deinit(allocator);

    if (result.exit_code != 0) {
        std.log.err("Failed to create branch: {s}", .{result.stderr});
        return GitError.BranchCreationFailed;
    }

    std.log.info("Created feature branch: {s}", .{branch_name});
}

/// Stage all changes and commit with message
pub fn commit(allocator: Allocator, message: []const u8) !void {
    if (isMainBranch()) {
        return GitError.MainBranchProtected;
    }

    // Stage all changes
    {
        var add_result = try process.git(allocator, &[_][]const u8{"add", "-A"});
        defer add_result.deinit(allocator);

        if (add_result.exit_code != 0) {
            return GitError.CommitFailed;
        }
    }

    // Commit
    {
        var commit_result = try process.git(allocator, &[_][]const u8{ "commit", "-m", message });
        defer commit_result.deinit(allocator);

        if (commit_result.exit_code != 0) {
            std.log.err("Commit failed: {s}", .{commit_result.stderr});
            return GitError.CommitFailed;
        }
    }

    std.log.info("Committed: {s}", .{message});
}

/// Get the current commit SHA (full length)
pub fn getCurrentSha(allocator: Allocator) ![]const u8 {
    var result = try process.git(allocator, &[_][]const u8{"rev-parse", "HEAD"});
    defer result.deinit(allocator);

    if (result.exit_code != 0) {
        return GitError.NotAGitRepository;
    }

    const sha = std.mem.trim(u8, result.stdout, " \t\r\n");
    return allocator.dupe(u8, sha);
}

/// Get the short commit SHA (7 characters)
pub fn getShortSha(allocator: Allocator) ![]const u8 {
    var result = try process.git(allocator, &[_][]const u8{"rev-parse", "--short", "HEAD"});
    defer result.deinit(allocator);

    if (result.exit_code != 0) {
        return GitError.NotAGitRepository;
    }

    const sha = std.mem.trim(u8, result.stdout, " \t\r\n");
    return allocator.dupe(u8, sha);
}

/// Get the last commit message
pub fn getLastCommitMessage(allocator: Allocator) ![]const u8 {
    var result = try process.git(allocator, &[_][]const u8{ "log", "-1", "--pretty=%s" });
    defer result.deinit(allocator);

    if (result.exit_code != 0) {
        return GitError.NotAGitRepository;
    }

    const msg = std.mem.trim(u8, result.stdout, " \t\r\n");
    return allocator.dupe(u8, msg);
}

/// Read .ralph/.loop_start_sha to get loop start point
pub fn getLoopStartSha(allocator: Allocator) ![]const u8 {
    const cwd = std.fs.cwd();
    const file = cwd.openFile(".ralph/.loop_start_sha", .{}) catch {
        return GitError.NotAGitRepository;
    };
    defer file.close();

    const content = file.readAllAlloc(allocator, 1024) catch {
        return GitError.NotAGitRepository;
    };
    errdefer allocator.free(content);

    const sha = std.mem.trim(u8, content, " \t\r\n");
    if (sha.len == 0) {
        allocator.free(content);
        return getCurrentSha(allocator);
    }

    return content;
}

/// Update .ralph/.loop_start_sha with current SHA
pub fn updateLoopStartSha(allocator: Allocator) !void {
    const sha = try getCurrentSha(allocator);
    defer allocator.free(sha);

    const cwd = std.fs.cwd();
    const file = try cwd.createFile(".ralph/.loop_start_sha", .{});
    defer file.close();

    try file.writeAll(sha);
    try file.writeAll("\n");
}

/// Get detailed git status
pub fn getStatus(allocator: Allocator) !GitStatus {
    var result = try process.git(allocator, &[_][]const u8{ "status", "--porcelain=v2", "--branch" });
    defer result.deinit(allocator);

    if (result.exit_code != 0) {
        return GitError.NotAGitRepository;
    }

    var status = GitStatus{
        .branch = &.{},
        .staged = 0,
        .unstaged = 0,
        .untracked = 0,
        .ahead = 0,
        .behind = 0,
    };

    var lines = std.mem.splitScalar(u8, result.stdout, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        if (std.mem.startsWith(u8, line, "# branch.name ")) {
            const branch_name = line["# branch.name ".len..];
            status.branch = try allocator.dupe(u8, branch_name);
        } else if (std.mem.startsWith(u8, line, "# branch.ab ")) {
            const ab_info = line["# branch.ab ".len..];
            var iter = std.mem.splitScalar(u8, ab_info, ' ');
            if (iter.next()) |ahead_str| {
                if (ahead_str.len > 0 and ahead_str[0] == '+') {
                    status.ahead = std.fmt.parseInt(u32, ahead_str[1..], 10) catch 0;
                }
            }
            if (iter.next()) |behind_str| {
                if (behind_str.len > 0 and behind_str[0] == '-') {
                    status.behind = std.fmt.parseInt(u32, behind_str[1..], 10) catch 0;
                }
            }
        } else if (line[0] == '1' or line[0] == '2') {
            var parts = std.mem.splitScalar(u8, line, ' ');
            _ = parts.next();
            if (parts.next()) |xy| {
                if (xy.len >= 2) {
                    if (xy[0] != '.' and xy[0] != '?') status.staged += 1;
                    if (xy.len > 1 and xy[1] != '.' and xy[1] != '?') status.unstaged += 1;
                }
            }
        } else if (line[0] == '?') {
            status.untracked += 1;
        }
    }

    return status;
}

/// Check if there are uncommitted changes
pub fn hasUncommittedChanges(allocator: Allocator) !bool {
    const status = try getStatus(allocator);
    defer status.deinit(allocator);

    return status.staged > 0 or status.unstaged > 0 or status.untracked > 0;
}

/// Push current branch to remote
pub fn push(allocator: Allocator) !void {
    var result = try process.git(allocator, &[_][]const u8{"push"});
    defer result.deinit(allocator);

    if (result.exit_code != 0) {
        std.log.err("Push failed: {s}", .{result.stderr});
        return GitError.ProcessError;
    }

    std.log.info("Pushed to remote", .{});
}

/// Pull with rebase from remote
pub fn pullRebase(allocator: Allocator) !void {
    var result = try process.git(allocator, &[_][]const u8{ "pull", "--rebase" });
    defer result.deinit(allocator);

    if (result.exit_code != 0) {
        std.log.err("Pull rebase failed: {s}", .{result.stderr});
        return GitError.MergeConflict;
    }

    std.log.info("Pulled with rebase", .{});
}

/// Get commit info for a specific SHA
pub fn getCommitInfo(allocator: Allocator, sha: []const u8) !CommitInfo {
    const format = "%H%n%h%n%s%n%an%n%ct";
    var result = try process.git(allocator, &[_][]const u8{ "log", "-1", "--format=" ++ format, sha });
    defer result.deinit(allocator);

    if (result.exit_code != 0) {
        return GitError.NotAGitRepository;
    }

    var iter = std.mem.splitScalar(u8, result.stdout, '\n');

    const full_sha = iter.next() orelse return GitError.NotAGitRepository;
    const short_sha = iter.next() orelse return GitError.NotAGitRepository;
    const subject = iter.next() orelse return GitError.NotAGitRepository;
    const author = iter.next() orelse return GitError.NotAGitRepository;
    const timestamp_str = iter.next() orelse return GitError.NotAGitRepository;

    const timestamp = std.fmt.parseInt(i64, std.mem.trim(u8, timestamp_str, " \t\r"), 10) catch 0;

    return CommitInfo{
        .sha = try allocator.dupe(u8, std.mem.trim(u8, full_sha, " \t\r")),
        .short_sha = try allocator.dupe(u8, std.mem.trim(u8, short_sha, " \t\r")),
        .message = try allocator.dupe(u8, std.mem.trim(u8, subject, " \t\r")),
        .author = try allocator.dupe(u8, std.mem.trim(u8, author, " \t\r")),
        .timestamp = timestamp,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "git: get current branch" {
    const allocator = std.testing.allocator;

    const branch = getCurrentBranch(allocator) catch |err| {
        if (err == GitError.NotAGitRepository) return error.SkipZigTest;
        return err;
    };
    defer allocator.free(branch);

    try std.testing.expect(branch.len > 0);
}

test "git: get short SHA" {
    const allocator = std.testing.allocator;

    const sha = getShortSha(allocator) catch |err| {
        if (err == GitError.NotAGitRepository) return error.SkipZigTest;
        return err;
    };
    defer allocator.free(sha);

    try std.testing.expect(sha.len > 0);
    try std.testing.expect(sha.len <= 10);
}
