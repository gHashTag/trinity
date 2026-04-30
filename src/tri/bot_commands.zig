const std = @import("std");

pub const BotCommand = enum {
    worktree,
    pr,
    board,
    unknown,
};

pub const CommandResult = struct {
    success: bool,
    message: []const u8,
    url: ?[]const u8,

    pub fn ok(msg: []const u8) CommandResult {
        return .{ .success = true, .message = msg, .url = null };
    }

    pub fn okWithURL(msg: []const u8, url: []const u8) CommandResult {
        return .{ .success = true, .message = msg, .url = url };
    }

    pub fn fail(msg: []const u8) CommandResult {
        return .{ .success = false, .message = msg, .url = null };
    }
};

pub const WorktreeManager = struct {
    allocator: std.mem.Allocator,
    repo_path: []const u8,

    pub fn init(allocator: std.mem.Allocator, repo_path: []const u8) WorktreeManager {
        return .{ .allocator = allocator, .repo_path = repo_path };
    }

    pub fn createWorktree(self: *const WorktreeManager, name: []const u8) !CommandResult {
        var cmd = std.process.Child.init(
            &[_][]const u8{ "git", "worktree", "add", name },
            self.allocator,
        );
        cmd.cwd = self.repo_path;

        const term = cmd.wait() catch {
            return CommandResult.fail("Failed to create worktree");
        };

        switch (term) {
            .Exited => |code| {
                if (code == 0) {
                    var buf: [256]u8 = undefined;
                    const msg = std.fmt.bufPrint(&buf, "Worktree '{s}' created", .{name}) catch "Worktree created";
                    return CommandResult.ok(self.allocator.dupe(u8, msg) catch msg);
                } else {
                    return CommandResult.fail("git worktree add failed");
                }
            },
            else => return CommandResult.fail("git worktree add interrupted"),
        }
    }

    pub fn listWorktrees(self: *const WorktreeManager) !CommandResult {
        var cmd = std.process.Child.init(
            &[_][]const u8{ "git", "worktree", "list", "--porcelain" },
            self.allocator,
        );
        cmd.cwd = self.repo_path;

        const term = cmd.wait() catch {
            return CommandResult.fail("Failed to list worktrees");
        };

        switch (term) {
            .Exited => |code| {
                if (code == 0) {
                    return CommandResult.ok("Worktrees listed");
                } else {
                    return CommandResult.fail("git worktree list failed");
                }
            },
            else => return CommandResult.fail("git worktree list interrupted"),
        }
    }

    pub fn removeWorktree(self: *const WorktreeManager, name: []const u8) !CommandResult {
        var cmd = std.process.Child.init(
            &[_][]const u8{ "git", "worktree", "remove", name },
            self.allocator,
        );
        cmd.cwd = self.repo_path;

        const term = cmd.wait() catch {
            return CommandResult.fail("Failed to remove worktree");
        };

        switch (term) {
            .Exited => |code| {
                if (code == 0) {
                    return CommandResult.ok("Worktree removed");
                } else {
                    return CommandResult.fail("git worktree remove failed");
                }
            },
            else => return CommandResult.fail("git worktree remove interrupted"),
        }
    }
};

pub const PRManager = struct {
    allocator: std.mem.Allocator,
    repo_path: []const u8,
    repo_remote: []const u8,

    pub fn init(allocator: std.mem.Allocator, repo_path: []const u8, repo_remote: []const u8) PRManager {
        return .{ .allocator = allocator, .repo_path = repo_path, .repo_remote = repo_remote };
    }

    pub fn createPR(self: *const PRManager, title: []const u8, body: []const u8) !CommandResult {
        var cmd = std.process.Child.init(
            &[_][]const u8{ "gh", "pr", "create", "--title", title, "--body", body },
            self.allocator,
        );
        cmd.cwd = self.repo_path;

        const term = cmd.wait() catch {
            return CommandResult.fail("Failed to create PR");
        };

        switch (term) {
            .Exited => |code| {
                if (code == 0) {
                    return CommandResult.ok("PR created");
                } else {
                    return CommandResult.fail("gh pr create failed");
                }
            },
            else => return CommandResult.fail("gh pr create interrupted"),
        }
    }

    pub fn viewPR(self: *const PRManager, pr_number: u32) !CommandResult {
        var num_buf: [16]u8 = undefined;
        const num_str = std.fmt.bufPrint(&num_buf, "{d}", .{pr_number}) catch "0";

        var cmd = std.process.Child.init(
            &[_][]const u8{ "gh", "pr", "view", num_str },
            self.allocator,
        );
        cmd.cwd = self.repo_path;

        const term = cmd.wait() catch {
            return CommandResult.fail("Failed to view PR");
        };

        switch (term) {
            .Exited => |code| {
                if (code == 0) {
                    return CommandResult.ok("PR details retrieved");
                } else {
                    return CommandResult.fail("PR not found");
                }
            },
            else => return CommandResult.fail("gh pr view interrupted"),
        }
    }
};

pub const BoardManager = struct {
    allocator: std.mem.Allocator,
    repo_path: []const u8,

    pub fn init(allocator: std.mem.Allocator, repo_path: []const u8) BoardManager {
        return .{ .allocator = allocator, .repo_path = repo_path };
    }

    pub fn showBoard(self: *const BoardManager) !CommandResult {
        var cmd = std.process.Child.init(
            &[_][]const u8{ "gh", "issue", "list", "--limit", "20" },
            self.allocator,
        );
        cmd.cwd = self.repo_path;

        const term = cmd.wait() catch {
            return CommandResult.fail("Failed to fetch board");
        };

        switch (term) {
            .Exited => |code| {
                if (code == 0) {
                    return CommandResult.ok("Board fetched");
                } else {
                    return CommandResult.fail("gh issue list failed");
                }
            },
            else => return CommandResult.fail("gh issue list interrupted"),
        }
    }
};

pub fn parseCommand(text: []const u8) struct { cmd: BotCommand, args: []const u8 } {
    if (std.mem.startsWith(u8, text, "/worktree")) {
        const args = if (text.len > 10) text[10..] else "";
        return .{ .cmd = .worktree, .args = args };
    }
    if (std.mem.startsWith(u8, text, "/pr")) {
        const args = if (text.len > 4) text[4..] else "";
        return .{ .cmd = .pr, .args = args };
    }
    if (std.mem.startsWith(u8, text, "/board")) {
        return .{ .cmd = .board, .args = "" };
    }
    return .{ .cmd = .unknown, .args = text };
}

test "parse worktree command" {
    const result = parseCommand("/worktree feature-x");
    try std.testing.expectEqual(BotCommand.worktree, result.cmd);
    try std.testing.expectEqualStrings("feature-x", result.args);
}

test "parse pr command with number" {
    const result = parseCommand("/pr 54");
    try std.testing.expectEqual(BotCommand.pr, result.cmd);
    try std.testing.expectEqualStrings("54", result.args);
}

test "parse pr command without number" {
    const result = parseCommand("/pr");
    try std.testing.expectEqual(BotCommand.pr, result.cmd);
    try std.testing.expectEqualStrings("", result.args);
}

test "parse board command" {
    const result = parseCommand("/board");
    try std.testing.expectEqual(BotCommand.board, result.cmd);
}

test "parse unknown command" {
    const result = parseCommand("/unknown");
    try std.testing.expectEqual(BotCommand.unknown, result.cmd);
}

test "command result ok" {
    const r = CommandResult.ok("test");
    try std.testing.expect(r.success);
    try std.testing.expectEqualStrings("test", r.message);
    try std.testing.expect(r.url == null);
}

test "command result fail" {
    const r = CommandResult.fail("error");
    try std.testing.expect(!r.success);
}
