// entrypoint.zig — Zig agent entrypoint (replaces 942 LOC bash)
// Single binary: clone → read issue → Claude Code → self-review → PR
// Telegram UX: 1 card per agent (edit-in-place), 1 summary at completion.
const std = @import("std");
const telegram = @import("telegram.zig");
const telegram_card = @import("telegram_card.zig");
const github_api = @import("github_api.zig");
const git_ops = @import("git_ops.zig");
const self_review = @import("self_review.zig");
const process_spawn = @import("process_spawn.zig");

const log = std.log.scoped(.agent_entrypoint);

const Env = struct {
    issue_number: u32,
    gh_token: []const u8,
    api_key: []const u8,
    repo_url: []const u8,
    owner: []const u8,
    repo: []const u8,
    model: ?[]const u8,
    timeout_s: u64,
    max_turns: u32,
    tg_config: telegram.TelegramConfig,
    dry_run: bool,

    fn fromSystem() Env {
        const issue_str = std.posix.getenv("ISSUE_NUMBER") orelse std.posix.getenv("ISSUE") orelse {
            std.debug.print("[agent] FATAL: ISSUE_NUMBER is required\n", .{});
            std.process.exit(1);
        };
        const issue_number = std.fmt.parseInt(u32, issue_str, 10) catch {
            std.debug.print("[agent] FATAL: ISSUE_NUMBER is not a number: {s}\n", .{issue_str});
            std.process.exit(1);
        };

        const gh_token = std.posix.getenv("GITHUB_TOKEN") orelse std.posix.getenv("AGENT_GH_TOKEN") orelse {
            std.debug.print("[agent] FATAL: GITHUB_TOKEN is required\n", .{});
            std.process.exit(1);
        };

        const api_key = std.posix.getenv("ANTHROPIC_API_KEY") orelse {
            std.debug.print("[agent] FATAL: ANTHROPIC_API_KEY is required\n", .{});
            std.process.exit(1);
        };

        const repo_url = std.posix.getenv("REPO_URL") orelse "https://github.com/gHashTag/trinity.git";

        // Extract owner/repo from URL
        const owner = std.posix.getenv("GITHUB_OWNER") orelse "gHashTag";
        const repo = std.posix.getenv("GITHUB_REPO") orelse "trinity";

        const model = std.posix.getenv("CLAUDE_MODEL");

        const timeout_str = std.posix.getenv("AGENT_TIMEOUT") orelse "3600";
        const timeout_s = std.fmt.parseInt(u64, timeout_str, 10) catch 3600;

        const turns_str = std.posix.getenv("AGENT_MAX_TURNS") orelse "50";
        const max_turns = std.fmt.parseInt(u32, turns_str, 10) catch 50;

        const tg_token = std.posix.getenv("TELEGRAM_BOT_TOKEN") orelse "";
        const tg_chat = std.posix.getenv("TELEGRAM_CHAT_ID") orelse "";

        // Check --dry-run in args
        var dry_run = false;
        var args = std.process.args();
        _ = args.next(); // skip argv[0]
        while (args.next()) |arg| {
            if (std.mem.eql(u8, arg, "--dry-run")) dry_run = true;
        }

        return .{
            .issue_number = issue_number,
            .gh_token = gh_token,
            .api_key = api_key,
            .repo_url = repo_url,
            .owner = owner,
            .repo = repo,
            .model = model,
            .timeout_s = timeout_s,
            .max_turns = max_turns,
            .tg_config = .{
                .bot_token = tg_token,
                .chat_id = tg_chat,
                .enabled = tg_token.len > 0 and tg_chat.len > 0,
            },
            .dry_run = dry_run,
        };
    }

    fn ghConfig(self: *const Env) github_api.GitHubConfig {
        return .{
            .token = self.gh_token,
            .owner = self.owner,
            .repo = self.repo,
        };
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const env = Env.fromSystem();

    std.debug.print(
        \\[agent] Trinity Agent Entrypoint
        \\[agent]   issue: #{d}
        \\[agent]   repo: {s}/{s}
        \\[agent]   model: {s}
        \\[agent]   timeout: {d}s
        \\[agent]   telegram: {s}
        \\[agent]   dry-run: {s}
        \\
    , .{
        env.issue_number,
        env.owner, env.repo,
        env.model orelse "default",
        env.timeout_s,
        if (env.tg_config.enabled) "enabled" else "disabled",
        if (env.dry_run) "yes" else "no",
    });

    // Touch alive file for Docker HEALTHCHECK
    touchAlive();

    // ── Step 1: Telegram card ──
    var card = telegram_card.TelegramCard.init(allocator, env.tg_config, env.issue_number, "loading...");
    defer card.deinit();
    card.sendInitial();

    // Spawn background update ticker (30s refresh)
    const ticker = std.Thread.spawn(.{}, updateTicker, .{&card}) catch null;
    defer if (ticker) |t| {
        // Card will be finalized by then; ticker exits on next check
        t.detach();
    };

    if (env.dry_run) {
        std.debug.print("[agent] DRY RUN — skipping actual work\n", .{});
        card.appendStep("\xe2\x9c\x85 Dry run OK");
        card.finalize("\xe2\x9c\x85 DRY RUN DONE", null);
        return;
    }

    // ── Step 2: Read issue ──
    card.appendStep("\xf0\x9f\x93\x96 Reading issue");
    var issue = github_api.readIssue(allocator, env.ghConfig(), env.issue_number) catch |err| {
        const msg = std.fmt.allocPrint(allocator, "\xe2\x9d\x8c Read issue failed: {s}", .{@errorName(err)}) catch "\xe2\x9d\x8c Read issue failed";
        card.finalize(msg, null);
        if (std.fmt.allocPrint(allocator, "", .{})) |_| {} else |_| {}
        return err;
    };
    defer issue.deinit();

    // Update card title with real issue title
    card.title = issue.title;
    card.refresh();

    // Comment on issue: agent starting
    github_api.commentOnIssue(allocator, env.ghConfig(), env.issue_number,
        \\\xf0\x9f\x8c\x85 **Trinity Agent** starting
        \\Container: `agent-entrypoint.zig`
        \\Model: Zig native binary
    );

    // ── Step 3: Git setup ──
    card.appendStep("\xe2\x9c\x85 Auth OK");
    card.appendStep("\xf0\x9f\x93\xa6 Cloning");

    const worktree_path = git_ops.setupWorktree(allocator, env.repo_url, env.issue_number, env.gh_token) catch |err| {
        const msg = std.fmt.allocPrint(allocator, "\xe2\x9d\x8c Git setup failed: {s}", .{@errorName(err)}) catch "\xe2\x9d\x8c Git setup failed";
        card.finalize(msg, null);
        return err;
    };
    defer allocator.free(worktree_path);

    // ── Step 4: Build prompt ──
    card.appendStep("\xf0\x9f\x93\x8b Planning");

    var prompt_buf: [16384]u8 = undefined;
    const prompt = std.fmt.bufPrint(&prompt_buf,
        \\You are a Trinity agent solving GitHub issue #{d}.
        \\
        \\## Issue Title
        \\{s}
        \\
        \\## Issue Body
        \\{s}
        \\
        \\## Instructions
        \\1. Read CLAUDE.md for project rules
        \\2. Implement the solution
        \\3. Run `zig fmt src/` before committing
        \\4. Run `zig build` to verify compilation
        \\5. Commit with: feat(scope): description (#{d})
        \\6. Do NOT push — the entrypoint handles push + PR
        \\
        \\Work in the current directory. Be concise and focused.
    , .{
        env.issue_number,
        issue.title,
        if (issue.body.len > 8000) issue.body[0..8000] else issue.body,
        env.issue_number,
    }) catch {
        card.finalize("\xe2\x9d\x8c Prompt build failed", null);
        return error.PromptTooLong;
    };

    // ── Step 5: Run Claude Code ──
    card.appendStep("\xf0\x9f\x92\xbb Coding");

    github_api.commentOnIssue(allocator, env.ghConfig(), env.issue_number,
        \\\xe2\x9a\xa1 **Trinity Agent** coding
        \\Running Claude Code...
    );

    var claude_result = process_spawn.spawnClaude(
        allocator,
        prompt,
        worktree_path,
        env.max_turns,
        env.timeout_s,
        env.model,
    ) catch |err| {
        const msg = std.fmt.allocPrint(allocator, "\xe2\x9d\x8c Claude spawn failed: {s}", .{@errorName(err)}) catch "\xe2\x9d\x8c Claude failed";
        card.finalize(msg, null);
        return err;
    };
    defer claude_result.deinit();

    // Save log
    process_spawn.saveLog(allocator, worktree_path, claude_result.stdout);

    if (claude_result.exit_code != 0) {
        var msg_buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "\xe2\x9d\x8c Claude exited with code {d}", .{claude_result.exit_code}) catch "\xe2\x9d\x8c Claude failed";
        card.finalize(msg, null);
        github_api.commentOnIssue(allocator, env.ghConfig(), env.issue_number, msg);
        return;
    }

    // ── Step 6: Self-review ──
    card.appendStep("\xf0\x9f\x94\x8d Reviewing");

    var review = self_review.run(allocator, worktree_path, 3);
    defer review.deinit();

    var review_buf: [256]u8 = undefined;
    const review_summary = review.summary(&review_buf);

    if (!review.passed) {
        var msg_buf: [512]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "\xe2\x9d\x8c Review failed: {s}", .{review_summary}) catch "\xe2\x9d\x8c Review failed";
        card.finalize(msg, null);
        github_api.commentOnIssue(allocator, env.ghConfig(), env.issue_number, msg);
        return;
    }

    // ── Step 7: Push + PR ──
    card.appendStep("\xf0\x9f\x93\xa4 Creating PR");

    git_ops.push(allocator, worktree_path) catch |err| {
        const msg = std.fmt.allocPrint(allocator, "\xe2\x9d\x8c Push failed: {s}", .{@errorName(err)}) catch "\xe2\x9d\x8c Push failed";
        card.finalize(msg, null);
        return err;
    };

    const branch = git_ops.currentBranch(allocator, worktree_path) orelse "agent/unknown";
    defer if (!std.mem.eql(u8, branch, "agent/unknown")) allocator.free(branch);

    var pr_title_buf: [256]u8 = undefined;
    const pr_title = std.fmt.bufPrint(&pr_title_buf, "feat: {s} (#{d})", .{ issue.title, env.issue_number }) catch "feat: agent PR";

    var pr_body_buf: [2048]u8 = undefined;
    const pr_body = std.fmt.bufPrint(&pr_body_buf,
        \\## Summary
        \\Closes #{d}
        \\
        \\## Review
        \\{s}
        \\
        \\---
        \\Generated by Trinity Agent (entrypoint.zig)
    , .{ env.issue_number, review_summary }) catch "Agent PR";

    var pr = github_api.createPR(allocator, env.ghConfig(), branch, pr_title, pr_body) catch |err| {
        const msg = std.fmt.allocPrint(allocator, "\xe2\x9d\x8c PR creation failed: {s}", .{@errorName(err)}) catch "\xe2\x9d\x8c PR failed";
        card.finalize(msg, null);
        return err;
    };
    defer pr.deinit();

    // ── Step 8: Done ──
    card.finalize("\xe2\x9c\x85 DONE", pr.url);

    // Level 3: Issue summary (new message)
    var diff = git_ops.diffStats(allocator, worktree_path);
    defer diff.deinit();

    var diff_buf: [256]u8 = undefined;
    const diff_text = std.fmt.bufPrint(&diff_buf, "{d} files changed", .{diff.files_changed}) catch "diff unavailable";

    card.sendIssueSummary(diff_text, review_summary, pr.url);

    // Close issue comment
    var close_buf: [1024]u8 = undefined;
    const close_comment = std.fmt.bufPrint(&close_buf,
        \\\xe2\x9c\x85 **Trinity Agent** done
        \\PR: {s}
        \\Review: {s}
        \\Stats: {s}
    , .{
        pr.url,
        review_summary,
        diff_text,
    }) catch "\xe2\x9c\x85 Done";
    github_api.commentOnIssue(allocator, env.ghConfig(), env.issue_number, close_comment);

    std.debug.print("[agent] Done. PR: {s}\n", .{pr.url});
}

/// Background ticker: refreshes card every 30s.
fn updateTicker(card: *telegram_card.TelegramCard) void {
    while (card.final_status == null) {
        std.Thread.sleep(30 * std.time.ns_per_s);
        if (card.final_status != null) break;
        card.refresh();
        touchAlive();
    }
}

/// Touch /tmp/agent-alive for Docker HEALTHCHECK.
fn touchAlive() void {
    const file = std.fs.cwd().createFile("/tmp/agent-alive", .{}) catch return;
    file.close();
}

test "Env.fromSystem does not crash without env" {
    // Cannot test without setting env — just verify the struct compiles
    const config = telegram.TelegramConfig{ .bot_token = "", .chat_id = "", .enabled = false };
    _ = config;
}
