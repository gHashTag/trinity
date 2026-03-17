// @origin(spec:github_client.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// GitHub API Client — Dual-mode transport (native HTTP / gh CLI fallback)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Provides native GitHub REST API integration for Trinity Protocol v2.
// Detects GITHUB_TOKEN/GH_TOKEN for native HTTP, falls back to `gh` CLI.
// Supports --dry-run mode for testing without API calls.
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const Mode = enum {
    native_http,
    gh_cli,
    dry_run,
};

pub const IssueResult = struct {
    number: u32,
    url: []const u8,
};

pub const IssueInfo = struct {
    number: u32,
    title: []const u8,
    state: []const u8,
    body: []const u8,
    labels: []const []const u8,
};

pub const PrResult = struct {
    number: u32,
    url: []const u8,
    state: []const u8,
};

pub const CheckRunResult = struct {
    id: i64,
    url: []const u8,
};

pub const GitHubClient = struct {
    allocator: std.mem.Allocator,
    token: ?[]const u8,
    owner: []const u8,
    repo: []const u8,
    mode: Mode,

    const Self = @This();

    const GITHUB_API_HOST = "api.github.com";

    /// Initialize client: detect token, owner/repo, select mode
    pub fn init(allocator: std.mem.Allocator, dry_run: bool) !Self {
        return initWithMode(allocator, dry_run, null);
    }

    /// Initialize client with explicit mode (null = auto-detect)
    pub fn initWithMode(allocator: std.mem.Allocator, dry_run: bool, preferred_mode: ?Mode) !Self {
        if (dry_run) {
            const owner_repo = detectOwnerRepo(allocator) catch {
                return Self{
                    .allocator = allocator,
                    .token = null,
                    .owner = "unknown",
                    .repo = "unknown",
                    .mode = .dry_run,
                };
            };
            return Self{
                .allocator = allocator,
                .token = null,
                .owner = owner_repo.owner,
                .repo = owner_repo.repo,
                .mode = .dry_run,
            };
        }

        // Priority: GitHub App → PAT (GITHUB_TOKEN/GH_TOKEN) → gh CLI
        const github_app_auth = @import("github_app_auth.zig");
        const token = blk: {
            // Try GitHub App auth first
            if (github_app_auth.GitHubAppAuth.isAvailable()) {
                var app_auth = github_app_auth.GitHubAppAuth.init(allocator) catch break :blk @as(?[]const u8, null);
                const app_token = app_auth.getToken() catch {
                    app_auth.deinit();
                    break :blk @as(?[]const u8, null);
                };
                const duped = allocator.dupe(u8, app_token) catch {
                    app_auth.deinit();
                    break :blk @as(?[]const u8, null);
                };
                app_auth.deinit();
                break :blk @as(?[]const u8, duped);
            }
            // Fall back to PAT
            break :blk std.process.getEnvVarOwned(allocator, "GITHUB_TOKEN") catch
                std.process.getEnvVarOwned(allocator, "GH_TOKEN") catch
                @as(?[]const u8, null);
        };

        const owner_repo = try detectOwnerRepo(allocator);

        // Determine mode: preferred_mode -> GITHUB_USE_CLI env var -> auto-detect based on token
        const mode: Mode = blk: {
            if (preferred_mode) |m| break :blk m;
            const use_cli = std.process.hasEnvVarConstant("GITHUB_USE_CLI");
            break :blk if (use_cli or token == null) .gh_cli else .native_http;
        };

        return Self{
            .allocator = allocator,
            .token = token,
            .owner = owner_repo.owner,
            .repo = owner_repo.repo,
            .mode = mode,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.token) |t| self.allocator.free(t);
        self.token = null;
    }

    /// Create an issue on GitHub
    pub fn createIssue(self: *Self, title: []const u8, body: ?[]const u8, labels: []const []const u8) !IssueResult {
        switch (self.mode) {
            .dry_run => {
                std.debug.print("\x1b[38;2;255;215;0m[DRY RUN]\x1b[0m Would create issue: \"{s}\"\n", .{title});
                if (body) |b| {
                    std.debug.print("  Body: {s}\n", .{b});
                }
                if (labels.len > 0) {
                    std.debug.print("  Labels: ", .{});
                    for (labels, 0..) |l, i| {
                        if (i > 0) std.debug.print(", ", .{});
                        std.debug.print("{s}", .{l});
                    }
                    std.debug.print("\n", .{});
                }
                return IssueResult{ .number = 0, .url = "https://github.com/dry-run/0" };
            },
            .native_http => {
                var json_buf: [8192]u8 = undefined;
                const json_body = try buildCreateIssueJson(&json_buf, title, body, labels);
                const path = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/issues", .{ self.owner, self.repo });
                defer self.allocator.free(path);
                const response = try self.httpRequest("POST", path, json_body);
                defer self.allocator.free(response);
                return parseIssueResult(response);
            },
            .gh_cli => {
                var argv = try std.ArrayList([]const u8).initCapacity(self.allocator, 16);
                defer argv.deinit(self.allocator);
                try argv.appendSlice(self.allocator, &.{ "gh", "issue", "create", "--title", title });
                if (body) |b| {
                    try argv.appendSlice(self.allocator, &.{ "--body", b });
                } else {
                    try argv.appendSlice(self.allocator, &.{ "--body", "" });
                }
                for (labels) |l| {
                    try argv.appendSlice(self.allocator, &.{ "--label", l });
                }
                const result = try self.ghCliRun(argv.items);
                defer self.allocator.free(result);
                return parseGhIssueCreateOutput(result);
            },
        }
    }

    /// Post a comment on an issue
    pub fn commentIssue(self: *Self, number: u32, body: []const u8) !void {
        switch (self.mode) {
            .dry_run => {
                std.debug.print("\x1b[38;2;255;215;0m[DRY RUN]\x1b[0m Would comment on #{d}:\n{s}\n", .{ number, body });
            },
            .native_http => {
                var json_buf: [16384]u8 = undefined;
                var escape_buf: [8192]u8 = undefined;
                const escaped = escapeJson(body, &escape_buf);
                const json_body = std.fmt.bufPrint(&json_buf, "{{\"body\":\"{s}\"}}", .{escaped}) catch return error.BufferOverflow;
                const path = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/issues/{d}/comments", .{ self.owner, self.repo, number });
                defer self.allocator.free(path);
                const response = try self.httpRequest("POST", path, json_body);
                self.allocator.free(response);
            },
            .gh_cli => {
                const num_str = try std.fmt.allocPrint(self.allocator, "{d}", .{number});
                defer self.allocator.free(num_str);
                const result = try self.ghCliRun(&.{ "gh", "issue", "comment", num_str, "--body", body });
                self.allocator.free(result);
            },
        }
    }

    /// Close an issue
    pub fn closeIssue(self: *Self, number: u32) !void {
        switch (self.mode) {
            .dry_run => {
                std.debug.print("\x1b[38;2;255;215;0m[DRY RUN]\x1b[0m Would close issue #{d}\n", .{number});
            },
            .native_http => {
                var json_buf: [256]u8 = undefined;
                const json_body = std.fmt.bufPrint(&json_buf, "{{\"state\":\"closed\"}}", .{}) catch return error.BufferOverflow;
                const path = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/issues/{d}", .{ self.owner, self.repo, number });
                defer self.allocator.free(path);
                const response = try self.httpRequest("PATCH", path, json_body);
                self.allocator.free(response);
            },
            .gh_cli => {
                const num_str = try std.fmt.allocPrint(self.allocator, "{d}", .{number});
                defer self.allocator.free(num_str);
                const result = try self.ghCliRun(&.{ "gh", "issue", "close", num_str });
                self.allocator.free(result);
            },
        }
    }

    /// Add labels to an issue
    pub fn addLabels(self: *Self, number: u32, labels: []const []const u8) !void {
        if (labels.len == 0) return;

        switch (self.mode) {
            .dry_run => {
                std.debug.print("\x1b[38;2;255;215;0m[DRY RUN]\x1b[0m Would add labels to #{d}: ", .{number});
                for (labels, 0..) |l, i| {
                    if (i > 0) std.debug.print(", ", .{});
                    std.debug.print("{s}", .{l});
                }
                std.debug.print("\n", .{});
            },
            .native_http => {
                var json_buf: [2048]u8 = undefined;
                const json_body = try buildLabelsJson(&json_buf, labels);
                const path = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/issues/{d}/labels", .{ self.owner, self.repo, number });
                defer self.allocator.free(path);
                const response = try self.httpRequest("POST", path, json_body);
                self.allocator.free(response);
            },
            .gh_cli => {
                const num_str = try std.fmt.allocPrint(self.allocator, "{d}", .{number});
                defer self.allocator.free(num_str);
                var argv = try std.ArrayList([]const u8).initCapacity(self.allocator, 16);
                defer argv.deinit(self.allocator);
                try argv.appendSlice(self.allocator, &.{ "gh", "issue", "edit", num_str });
                for (labels) |l| {
                    try argv.appendSlice(self.allocator, &.{ "--add-label", l });
                }
                const result = try self.ghCliRun(argv.items);
                self.allocator.free(result);
            },
        }
    }

    /// Remove labels from an issue (used for board sync)
    pub fn removeLabels(self: *Self, number: u32, labels: []const []const u8) !void {
        if (labels.len == 0) return;

        switch (self.mode) {
            .dry_run => {
                std.debug.print("\x1b[38;2;255;215;0m[DRY RUN]\x1b[0m Would remove labels from #{d}: ", .{number});
                for (labels, 0..) |l, i| {
                    if (i > 0) std.debug.print(", ", .{});
                    std.debug.print("{s}", .{l});
                }
                std.debug.print("\n", .{});
            },
            .native_http => {
                for (labels) |label| {
                    const path = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/issues/{d}/labels/{s}", .{ self.owner, self.repo, number, label });
                    defer self.allocator.free(path);
                    // DELETE label - ignore errors (label may not exist)
                    const response = self.httpRequest("DELETE", path, null) catch continue;
                    self.allocator.free(response);
                }
            },
            .gh_cli => {
                const num_str = try std.fmt.allocPrint(self.allocator, "{d}", .{number});
                defer self.allocator.free(num_str);
                var argv = try std.ArrayList([]const u8).initCapacity(self.allocator, 16);
                defer argv.deinit(self.allocator);
                try argv.appendSlice(self.allocator, &.{ "gh", "issue", "edit", num_str });
                for (labels) |l| {
                    try argv.appendSlice(self.allocator, &.{ "--remove-label", l });
                }
                const result = self.ghCliRun(argv.items) catch return;
                self.allocator.free(result);
            },
        }
    }

    /// Edit issue fields (milestone, assignees)
    pub fn editIssue(self: *Self, number: u32, milestone: ?[]const u8, assignee: ?[]const u8) !void {
        switch (self.mode) {
            .dry_run => {
                std.debug.print("\x1b[38;2;255;215;0m[DRY RUN]\x1b[0m Would edit issue #{d}", .{number});
                if (milestone) |m| std.debug.print(" milestone={s}", .{m});
                if (assignee) |a| std.debug.print(" assignee={s}", .{a});
                std.debug.print("\n", .{});
            },
            .native_http => {
                var json_buf: [2048]u8 = undefined;
                var pos: usize = 0;
                const start = "{";
                @memcpy(json_buf[pos .. pos + start.len], start);
                pos += start.len;
                var has_field = false;
                if (milestone) |m| {
                    var escape_buf: [512]u8 = undefined;
                    const escaped = escapeJson(m, &escape_buf);
                    const field = std.fmt.bufPrint(json_buf[pos..], "\"milestone\":\"{s}\"", .{escaped}) catch return error.BufferOverflow;
                    pos += field.len;
                    has_field = true;
                }
                if (assignee) |a| {
                    if (has_field) {
                        json_buf[pos] = ',';
                        pos += 1;
                    }
                    var escape_buf: [256]u8 = undefined;
                    const escaped = escapeJson(a, &escape_buf);
                    const field = std.fmt.bufPrint(json_buf[pos..], "\"assignees\":[\"{s}\"]", .{escaped}) catch return error.BufferOverflow;
                    pos += field.len;
                }
                json_buf[pos] = '}';
                pos += 1;
                const path = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/issues/{d}", .{ self.owner, self.repo, number });
                defer self.allocator.free(path);
                const response = try self.httpRequest("PATCH", path, json_buf[0..pos]);
                self.allocator.free(response);
            },
            .gh_cli => {
                var argv = try std.ArrayList([]const u8).initCapacity(self.allocator, 8);
                defer argv.deinit(self.allocator);
                const num_str = try std.fmt.allocPrint(self.allocator, "{d}", .{number});
                defer self.allocator.free(num_str);
                try argv.appendSlice(self.allocator, &.{ "gh", "issue", "edit", num_str });
                if (milestone) |m| {
                    try argv.appendSlice(self.allocator, &.{ "--milestone", m });
                }
                if (assignee) |a| {
                    try argv.appendSlice(self.allocator, &.{ "--add-assignee", a });
                }
                const result = try self.ghCliRun(argv.items);
                self.allocator.free(result);
            },
        }
    }

    /// Add assignee to an issue
    pub fn addAssignee(self: *Self, number: u32, assignee: []const u8) !void {
        switch (self.mode) {
            .dry_run => {
                std.debug.print("\x1b[38;2;255;215;0m[DRY RUN]\x1b[0m Would add assignee {s} to #{d}\n", .{ assignee, number });
            },
            .native_http => {
                var json_buf: [512]u8 = undefined;
                var escape_buf: [256]u8 = undefined;
                const escaped = escapeJson(assignee, &escape_buf);
                const json_body = std.fmt.bufPrint(&json_buf, "{{\"assignees\":[\"{s}\"]}}", .{escaped}) catch return error.BufferOverflow;
                const path = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/issues/{d}/assignees", .{ self.owner, self.repo, number });
                defer self.allocator.free(path);
                const response = try self.httpRequest("POST", path, json_body);
                self.allocator.free(response);
            },
            .gh_cli => {
                const num_str = try std.fmt.allocPrint(self.allocator, "{d}", .{number});
                defer self.allocator.free(num_str);
                const result = try self.ghCliRun(&.{ "gh", "issue", "edit", num_str, "--add-assignee", assignee });
                self.allocator.free(result);
            },
        }
    }

    /// List open issues (returns raw JSON)
    pub fn listIssues(self: *Self, state_filter: []const u8) ![]const u8 {
        switch (self.mode) {
            .dry_run => {
                std.debug.print("\x1b[38;2;255;215;0m[DRY RUN]\x1b[0m Would list issues (state={s})\n", .{state_filter});
                return try self.allocator.dupe(u8, "[]");
            },
            .native_http => {
                const path = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/issues?state={s}&per_page=50", .{ self.owner, self.repo, state_filter });
                defer self.allocator.free(path);
                return try self.httpRequest("GET", path, null);
            },
            .gh_cli => {
                return try self.ghCliRun(&.{ "gh", "issue", "list", "--state", state_filter, "--json", "number,title,labels,assignees,milestone,state", "--limit", "50" });
            },
        }
    }

    /// Get issue info
    /// Caller must call freeIssueInfo() when done with the result.
    pub fn getIssue(self: *Self, number: u32) !IssueInfo {
        switch (self.mode) {
            .dry_run => {
                return IssueInfo{
                    .number = number,
                    .title = "(dry-run)",
                    .state = "open",
                    .body = "",
                    .labels = &.{},
                };
            },
            .native_http => {
                const path = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/issues/{d}", .{ self.owner, self.repo, number });
                defer self.allocator.free(path);
                const response = try self.httpRequest("GET", path, null);
                defer self.allocator.free(response);
                const info = parseIssueInfo(response) catch |err| return err;
                // Dupe strings so they outlive the freed response buffer
                return IssueInfo{
                    .number = info.number,
                    .title = self.allocator.dupe(u8, info.title) catch "(oom)",
                    .state = self.allocator.dupe(u8, info.state) catch "unknown",
                    .body = self.allocator.dupe(u8, info.body) catch "",
                    .labels = &.{},
                };
            },
            .gh_cli => {
                const num_str = try std.fmt.allocPrint(self.allocator, "{d}", .{number});
                defer self.allocator.free(num_str);
                const result = try self.ghCliRun(&.{ "gh", "issue", "view", num_str, "--json", "number,title,state,body,labels" });
                defer self.allocator.free(result);
                const info = parseIssueInfo(result) catch |err| return err;
                // Dupe strings so they outlive the freed result buffer
                return IssueInfo{
                    .number = info.number,
                    .title = self.allocator.dupe(u8, info.title) catch "(oom)",
                    .state = self.allocator.dupe(u8, info.state) catch "unknown",
                    .body = self.allocator.dupe(u8, info.body) catch "",
                    .labels = &.{},
                };
            },
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PR operations
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create a pull request
    pub fn createPr(self: *Self, head: []const u8, base: []const u8, title: []const u8, body_text: ?[]const u8) !PrResult {
        switch (self.mode) {
            .dry_run => {
                std.debug.print("\x1b[38;2;255;215;0m[DRY RUN]\x1b[0m Would create PR: \"{s}\" ({s} → {s})\n", .{ title, head, base });
                return PrResult{ .number = 0, .url = "https://github.com/dry-run/pull/0", .state = "open" };
            },
            .native_http => {
                const json_body = try self.buildPrJson(title, head, base, body_text);
                defer self.allocator.free(json_body);
                const path = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/pulls", .{ self.owner, self.repo });
                defer self.allocator.free(path);
                const response = try self.httpRequest("POST", path, json_body);
                defer self.allocator.free(response);
                return parsePrResult(response);
            },
            .gh_cli => {
                var argv = try std.ArrayList([]const u8).initCapacity(self.allocator, 16);
                defer argv.deinit(self.allocator);
                try argv.appendSlice(self.allocator, &.{ "gh", "pr", "create", "--head", head, "--base", base, "--title", title });
                if (body_text) |b| {
                    try argv.appendSlice(self.allocator, &.{ "--body", b });
                } else {
                    try argv.appendSlice(self.allocator, &.{ "--body", "" });
                }
                const result = try self.ghCliRun(argv.items);
                defer self.allocator.free(result);
                // gh pr create outputs the URL
                const trimmed = std.mem.trimRight(u8, result, "\n\r ");
                const last_slash = std.mem.lastIndexOf(u8, trimmed, "/") orelse return error.ParseError;
                const num_str = trimmed[last_slash + 1 ..];
                const number = std.fmt.parseInt(u32, num_str, 10) catch return error.ParseError;
                return PrResult{ .number = number, .url = trimmed, .state = "open" };
            },
        }
    }

    /// Merge a pull request
    pub fn mergePr(self: *Self, number: u32, merge_method: []const u8) !void {
        switch (self.mode) {
            .dry_run => {
                std.debug.print("\x1b[38;2;255;215;0m[DRY RUN]\x1b[0m Would merge PR #{d} (method={s})\n", .{ number, merge_method });
            },
            .native_http => {
                var json_buf: [256]u8 = undefined;
                var escape_buf: [64]u8 = undefined;
                const escaped = escapeJson(merge_method, &escape_buf);
                const json_body = std.fmt.bufPrint(&json_buf, "{{\"merge_method\":\"{s}\"}}", .{escaped}) catch return error.BufferOverflow;
                const path = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/pulls/{d}/merge", .{ self.owner, self.repo, number });
                defer self.allocator.free(path);
                const response = try self.httpRequest("PUT", path, json_body);
                self.allocator.free(response);
            },
            .gh_cli => {
                const num_str = try std.fmt.allocPrint(self.allocator, "{d}", .{number});
                defer self.allocator.free(num_str);
                const method_flag = if (std.mem.eql(u8, merge_method, "rebase"))
                    "--rebase"
                else if (std.mem.eql(u8, merge_method, "merge"))
                    "--merge"
                else
                    "--squash";
                const result = try self.ghCliRun(&.{ "gh", "pr", "merge", num_str, method_flag, "--delete-branch" });
                self.allocator.free(result);
            },
        }
    }

    /// List pull requests
    pub fn listPrs(self: *Self, state_filter: []const u8) ![]const u8 {
        switch (self.mode) {
            .dry_run => {
                std.debug.print("\x1b[38;2;255;215;0m[DRY RUN]\x1b[0m Would list PRs (state={s})\n", .{state_filter});
                return try self.allocator.dupe(u8, "[]");
            },
            .native_http => {
                const path = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/pulls?state={s}&per_page=30", .{ self.owner, self.repo, state_filter });
                defer self.allocator.free(path);
                return try self.httpRequest("GET", path, null);
            },
            .gh_cli => {
                return try self.ghCliRun(&.{ "gh", "pr", "list", "--state", state_filter, "--json", "number,title,state,headRefName,baseRefName,url", "--limit", "30" });
            },
        }
    }

    /// Get a single PR
    pub fn getPr(self: *Self, number: u32) !PrResult {
        switch (self.mode) {
            .dry_run => {
                return PrResult{ .number = number, .url = "(dry-run)", .state = "open" };
            },
            .native_http => {
                const path = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/pulls/{d}", .{ self.owner, self.repo, number });
                defer self.allocator.free(path);
                const response = try self.httpRequest("GET", path, null);
                defer self.allocator.free(response);
                return parsePrResult(response);
            },
            .gh_cli => {
                const num_str = try std.fmt.allocPrint(self.allocator, "{d}", .{number});
                defer self.allocator.free(num_str);
                const result = try self.ghCliRun(&.{ "gh", "pr", "view", num_str, "--json", "number,state,url" });
                defer self.allocator.free(result);
                return parsePrResult(result);
            },
        }
    }

    /// Create a PR review (APPROVE, COMMENT, REQUEST_CHANGES)
    pub fn createPrReview(self: *Self, number: u32, event: []const u8, body_text: ?[]const u8) !void {
        switch (self.mode) {
            .dry_run => {
                std.debug.print("\x1b[38;2;255;215;0m[DRY RUN]\x1b[0m Would review PR #{d}: {s}\n", .{ number, event });
            },
            .native_http => {
                var json_buf: [4096]u8 = undefined;
                var pos: usize = 0;
                var escape_buf: [64]u8 = undefined;
                const escaped_event = escapeJson(event, &escape_buf);
                const start = std.fmt.bufPrint(&json_buf, "{{\"event\":\"{s}\"", .{escaped_event}) catch return error.BufferOverflow;
                pos = start.len;
                if (body_text) |b| {
                    var body_escape_buf: [2048]u8 = undefined;
                    const escaped_body = escapeJson(b, &body_escape_buf);
                    const body_part = std.fmt.bufPrint(json_buf[pos..], ",\"body\":\"{s}\"", .{escaped_body}) catch return error.BufferOverflow;
                    pos += body_part.len;
                }
                json_buf[pos] = '}';
                pos += 1;
                const path = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/pulls/{d}/reviews", .{ self.owner, self.repo, number });
                defer self.allocator.free(path);
                const response = try self.httpRequest("POST", path, json_buf[0..pos]);
                self.allocator.free(response);
            },
            .gh_cli => {
                const num_str = try std.fmt.allocPrint(self.allocator, "{d}", .{number});
                defer self.allocator.free(num_str);
                const event_flag = if (std.mem.eql(u8, event, "APPROVE"))
                    "--approve"
                else if (std.mem.eql(u8, event, "REQUEST_CHANGES"))
                    "--request-changes"
                else
                    "--comment";
                var argv = try std.ArrayList([]const u8).initCapacity(self.allocator, 8);
                defer argv.deinit(self.allocator);
                try argv.appendSlice(self.allocator, &.{ "gh", "pr", "review", num_str, event_flag });
                if (body_text) |b| {
                    try argv.appendSlice(self.allocator, &.{ "--body", b });
                }
                const result = try self.ghCliRun(argv.items);
                self.allocator.free(result);
            },
        }
    }

    /// Get PR diff
    pub fn getPrDiff(self: *Self, number: u32) ![]const u8 {
        switch (self.mode) {
            .dry_run => {
                std.debug.print("\x1b[38;2;255;215;0m[DRY RUN]\x1b[0m Would get diff for PR #{d}\n", .{number});
                return try self.allocator.dupe(u8, "(dry-run diff)");
            },
            .native_http => {
                const path = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/pulls/{d}", .{ self.owner, self.repo, number });
                defer self.allocator.free(path);
                return try self.httpRequestWithAccept("GET", path, null, "application/vnd.github.diff");
            },
            .gh_cli => {
                const num_str = try std.fmt.allocPrint(self.allocator, "{d}", .{number});
                defer self.allocator.free(num_str);
                return try self.ghCliRun(&.{ "gh", "pr", "diff", num_str });
            },
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // GraphQL
    // ═══════════════════════════════════════════════════════════════════════════

    /// Execute a GraphQL query against GitHub API
    pub fn graphqlQuery(self: *Self, query: []const u8, variables_json: ?[]const u8) ![]const u8 {
        switch (self.mode) {
            .dry_run => {
                std.debug.print("\x1b[38;2;255;215;0m[DRY RUN]\x1b[0m Would execute GraphQL query ({d} chars)\n", .{query.len});
                return try self.allocator.dupe(u8, "{}");
            },
            .native_http => {
                const escaped_query = try jsonEscapeAlloc(self.allocator, query);
                defer self.allocator.free(escaped_query);
                const json_body = if (variables_json) |vars|
                    try std.fmt.allocPrint(self.allocator, "{{\"query\":\"{s}\",\"variables\":{s}}}", .{ escaped_query, vars })
                else
                    try std.fmt.allocPrint(self.allocator, "{{\"query\":\"{s}\"}}", .{escaped_query});
                defer self.allocator.free(json_body);
                return try self.httpRequest("POST", "/graphql", json_body);
            },
            .gh_cli => {
                var argv = try std.ArrayList([]const u8).initCapacity(self.allocator, 8);
                defer argv.deinit(self.allocator);
                try argv.appendSlice(self.allocator, &.{ "gh", "api", "graphql", "-f", try std.fmt.allocPrint(self.allocator, "query={s}", .{query}) });
                if (variables_json) |vars| {
                    try argv.appendSlice(self.allocator, &.{ "--input", vars });
                }
                return try self.ghCliRun(argv.items);
            },
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Check Runs (Phase 2)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create a check run on a commit
    pub fn createCheckRun(self: *Self, name: []const u8, head_sha: []const u8, status: []const u8) !CheckRunResult {
        switch (self.mode) {
            .dry_run => {
                std.debug.print("\x1b[38;2;255;215;0m[DRY RUN]\x1b[0m Would create check run \"{s}\" on {s} (status={s})\n", .{ name, head_sha, status });
                return CheckRunResult{ .id = 0, .url = "https://github.com/dry-run/check/0" };
            },
            .native_http => {
                var json_buf: [2048]u8 = undefined;
                var name_esc: [256]u8 = undefined;
                var sha_esc: [64]u8 = undefined;
                var status_esc: [32]u8 = undefined;
                const escaped_name = escapeJson(name, &name_esc);
                const escaped_sha = escapeJson(head_sha, &sha_esc);
                const escaped_status = escapeJson(status, &status_esc);
                const json_body = std.fmt.bufPrint(&json_buf, "{{\"name\":\"{s}\",\"head_sha\":\"{s}\",\"status\":\"{s}\"}}", .{ escaped_name, escaped_sha, escaped_status }) catch return error.BufferOverflow;
                const path = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/check-runs", .{ self.owner, self.repo });
                defer self.allocator.free(path);
                const response = try self.httpRequest("POST", path, json_body);
                defer self.allocator.free(response);
                const id = extractJsonNumber(response, "id") orelse return error.ParseError;
                return CheckRunResult{ .id = id, .url = extractJsonString(response, "html_url") orelse "" };
            },
            .gh_cli => {
                // gh CLI doesn't have native check-run support, use gh api with -f flags
                const api_path = try std.fmt.allocPrint(self.allocator, "repos/{s}/{s}/check-runs", .{ self.owner, self.repo });
                defer self.allocator.free(api_path);
                const result = try self.ghCliRun(&.{ "gh", "api", api_path, "-X", "POST", "-f", try std.fmt.allocPrint(self.allocator, "name={s}", .{name}), "-f", try std.fmt.allocPrint(self.allocator, "head_sha={s}", .{head_sha}), "-f", try std.fmt.allocPrint(self.allocator, "status={s}", .{status}) });
                defer self.allocator.free(result);
                const id = extractJsonNumber(result, "id") orelse return CheckRunResult{ .id = 0, .url = "" };
                return CheckRunResult{ .id = id, .url = extractJsonString(result, "html_url") orelse "" };
            },
        }
    }

    /// Update a check run (complete with conclusion)
    pub fn updateCheckRun(self: *Self, check_run_id: i64, status: []const u8, conclusion: ?[]const u8, title: ?[]const u8, summary: ?[]const u8) !void {
        switch (self.mode) {
            .dry_run => {
                std.debug.print("\x1b[38;2;255;215;0m[DRY RUN]\x1b[0m Would update check run {d}: status={s}", .{ check_run_id, status });
                if (conclusion) |c| std.debug.print(" conclusion={s}", .{c});
                std.debug.print("\n", .{});
            },
            .native_http => {
                var json_buf: [4096]u8 = undefined;
                var pos: usize = 0;
                var status_esc: [32]u8 = undefined;
                const start = std.fmt.bufPrint(&json_buf, "{{\"status\":\"{s}\"", .{escapeJson(status, &status_esc)}) catch return error.BufferOverflow;
                pos = start.len;
                if (conclusion) |c| {
                    var conc_esc: [32]u8 = undefined;
                    const part = std.fmt.bufPrint(json_buf[pos..], ",\"conclusion\":\"{s}\"", .{escapeJson(c, &conc_esc)}) catch return error.BufferOverflow;
                    pos += part.len;
                }
                if (title != null or summary != null) {
                    const output_start = ",\"output\":{";
                    @memcpy(json_buf[pos .. pos + output_start.len], output_start);
                    pos += output_start.len;
                    var has_field = false;
                    if (title) |t| {
                        var title_esc: [256]u8 = undefined;
                        const part = std.fmt.bufPrint(json_buf[pos..], "\"title\":\"{s}\"", .{escapeJson(t, &title_esc)}) catch return error.BufferOverflow;
                        pos += part.len;
                        has_field = true;
                    }
                    if (summary) |s| {
                        if (has_field) {
                            json_buf[pos] = ',';
                            pos += 1;
                        }
                        var sum_esc: [2048]u8 = undefined;
                        const part = std.fmt.bufPrint(json_buf[pos..], "\"summary\":\"{s}\"", .{escapeJson(s, &sum_esc)}) catch return error.BufferOverflow;
                        pos += part.len;
                    }
                    json_buf[pos] = '}';
                    pos += 1;
                }
                json_buf[pos] = '}';
                pos += 1;
                const path = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/check-runs/{d}", .{ self.owner, self.repo, check_run_id });
                defer self.allocator.free(path);
                const response = try self.httpRequest("PATCH", path, json_buf[0..pos]);
                self.allocator.free(response);
            },
            .gh_cli => {
                std.debug.print("Check run update via gh CLI not supported, use GITHUB_TOKEN\n", .{});
            },
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Repository Dispatch (Phase 4)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Trigger a repository_dispatch event
    pub fn repositoryDispatch(self: *Self, event_type: []const u8, payload_json: ?[]const u8) !void {
        switch (self.mode) {
            .dry_run => {
                std.debug.print("\x1b[38;2;255;215;0m[DRY RUN]\x1b[0m Would dispatch event \"{s}\"\n", .{event_type});
            },
            .native_http => {
                var json_buf: [4096]u8 = undefined;
                var type_esc: [256]u8 = undefined;
                const escaped_type = escapeJson(event_type, &type_esc);
                const json_body = if (payload_json) |p|
                    std.fmt.bufPrint(&json_buf, "{{\"event_type\":\"{s}\",\"client_payload\":{s}}}", .{ escaped_type, p }) catch return error.BufferOverflow
                else
                    std.fmt.bufPrint(&json_buf, "{{\"event_type\":\"{s}\"}}", .{escaped_type}) catch return error.BufferOverflow;
                const path = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/dispatches", .{ self.owner, self.repo });
                defer self.allocator.free(path);
                const response = try self.httpRequest("POST", path, json_body);
                self.allocator.free(response);
            },
            .gh_cli => {
                const api_path = try std.fmt.allocPrint(self.allocator, "repos/{s}/{s}/dispatches", .{ self.owner, self.repo });
                defer self.allocator.free(api_path);
                const event_arg = try std.fmt.allocPrint(self.allocator, "event_type={s}", .{event_type});
                defer self.allocator.free(event_arg);
                if (payload_json) |p| {
                    const payload_arg = try std.fmt.allocPrint(self.allocator, "client_payload={s}", .{p});
                    defer self.allocator.free(payload_arg);
                    const result = try self.ghCliRun(&.{ "gh", "api", api_path, "-X", "POST", "-f", event_arg, "-f", payload_arg });
                    self.allocator.free(result);
                } else {
                    const result = try self.ghCliRun(&.{ "gh", "api", api_path, "-X", "POST", "-f", event_arg });
                    self.allocator.free(result);
                }
            },
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Internal: JSON builders
    // ═══════════════════════════════════════════════════════════════════════════

    fn buildPrJson(self: *Self, title: []const u8, head: []const u8, base: []const u8, body_text: ?[]const u8) ![]const u8 {
        var title_esc: [1024]u8 = undefined;
        var head_esc: [256]u8 = undefined;
        var base_esc: [256]u8 = undefined;
        const escaped_title = escapeJson(title, &title_esc);
        const escaped_head = escapeJson(head, &head_esc);
        const escaped_base = escapeJson(base, &base_esc);
        if (body_text) |b| {
            var body_esc: [4096]u8 = undefined;
            const escaped_body = escapeJson(b, &body_esc);
            return std.fmt.allocPrint(self.allocator, "{{\"title\":\"{s}\",\"head\":\"{s}\",\"base\":\"{s}\",\"body\":\"{s}\"}}", .{ escaped_title, escaped_head, escaped_base, escaped_body });
        }
        return std.fmt.allocPrint(self.allocator, "{{\"title\":\"{s}\",\"head\":\"{s}\",\"base\":\"{s}\"}}", .{ escaped_title, escaped_head, escaped_base });
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Internal: HTTP transport
    // ═══════════════════════════════════════════════════════════════════════════

    fn httpRequest(self: *Self, method_str: []const u8, path: []const u8, body: ?[]const u8) ![]const u8 {
        return self.httpRequestWithAccept(method_str, path, body, "application/vnd.github+json");
    }

    fn httpRequestWithAccept(self: *Self, method_str: []const u8, path: []const u8, body: ?[]const u8, accept: []const u8) ![]const u8 {
        const method: std.http.Method = if (std.mem.eql(u8, method_str, "GET"))
            .GET
        else if (std.mem.eql(u8, method_str, "POST"))
            .POST
        else if (std.mem.eql(u8, method_str, "PATCH"))
            .PATCH
        else if (std.mem.eql(u8, method_str, "PUT"))
            .PUT
        else if (std.mem.eql(u8, method_str, "DELETE"))
            .DELETE
        else
            .GET;

        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();

        const uri_str = try std.fmt.allocPrint(self.allocator, "https://{s}{s}", .{ GITHUB_API_HOST, path });
        defer self.allocator.free(uri_str);

        const uri = std.Uri.parse(uri_str) catch return error.InvalidUrl;

        var auth_buf: [512]u8 = undefined;
        const auth_header_val: ?[]const u8 = if (self.token) |t|
            std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{t}) catch null
        else
            null;

        var extra_headers_with_auth = [_]std.http.Header{
            .{ .name = "User-Agent", .value = "trinity-cli/1.0" },
            .{ .name = "Accept", .value = accept },
            .{ .name = "X-GitHub-Api-Version", .value = "2022-11-28" },
            .{ .name = "Authorization", .value = auth_header_val orelse "" },
        };
        const headers_count: usize = if (auth_header_val != null) 4 else 3;

        var req = client.request(method, uri, .{
            .extra_headers = extra_headers_with_auth[0..headers_count],
            .redirect_behavior = .unhandled,
        }) catch return error.ConnectionFailed;
        defer req.deinit();

        if (body) |b| {
            req.transfer_encoding = .{ .content_length = b.len };
            var body_writer = req.sendBodyUnflushed(&.{}) catch return error.RequestFailed;
            body_writer.writer.writeAll(b) catch return error.RequestFailed;
            body_writer.end() catch return error.RequestFailed;
            if (req.connection) |conn| conn.flush() catch return error.RequestFailed;
        }

        var redirect_buf: [0]u8 = .{};
        var response = req.receiveHead(&redirect_buf) catch return error.RequestFailed;

        const status_code = @intFromEnum(response.head.status);
        if (status_code != 200 and status_code != 201 and status_code != 204) {
            std.debug.print("\x1b[38;2;255;85;85mGitHub API error: {d} {s}\x1b[0m\n", .{
                status_code,
                path,
            });
            return error.GitHubApiError;
        }

        var transfer_buffer: [8192]u8 = undefined;
        var reader = response.reader(&transfer_buffer);
        const response_body = reader.allocRemaining(self.allocator, std.Io.Limit.limited(1 * 1024 * 1024)) catch
            return error.OutOfMemory;

        return response_body;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Internal: gh CLI fallback
    // ═══════════════════════════════════════════════════════════════════════════

    fn ghCliRun(self: *Self, argv: []const []const u8) ![]const u8 {
        // Pass GH_TOKEN to gh CLI subprocess for authentication
        // This works around keyring access issues in subprocesses
        var child_env = try std.process.getEnvMap(self.allocator);
        defer child_env.deinit();

        // If we have a token from init, pass it to gh CLI
        if (self.token) |tok| {
            try child_env.put("GH_TOKEN", tok);
        } else {
            // Otherwise try to get GH_TOKEN from environment for the subprocess
            if (std.process.getEnvVarOwned(self.allocator, "GH_TOKEN")) |tok| {
                defer self.allocator.free(tok);
                try child_env.put("GH_TOKEN", tok);
            } else |_| {}
        }

        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = argv,
            .max_output_bytes = 1024 * 1024,
            .env_map = &child_env,
        });
        defer self.allocator.free(result.stderr);

        const gh_exit = switch (result.term) {
            .Exited => |code| code,
            else => @as(u32, 1),
        };
        if (gh_exit != 0) {
            std.debug.print("\x1b[38;2;255;85;85mgh CLI failed (exit {d})\x1b[0m\n", .{gh_exit});
            std.debug.print("\x1b[38;2;255;85;85mstderr: {s}\x1b[0m\n", .{result.stderr});
            self.allocator.free(result.stdout);
            return error.GhCliFailed;
        }

        return result.stdout;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Utility functions
// ═══════════════════════════════════════════════════════════════════════════════

const OwnerRepo = struct {
    owner: []const u8,
    repo: []const u8,
};

/// Detect owner/repo from `git remote get-url origin`
pub fn detectOwnerRepo(allocator: std.mem.Allocator) !OwnerRepo {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "remote", "get-url", "origin" },
        .max_output_bytes = 4096,
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if ((switch (result.term) {
        .Exited => |code| code,
        else => @as(u32, 1),
    }) != 0) return error.GitRemoteFailed;

    const url = std.mem.trimRight(u8, result.stdout, "\n\r ");
    const parsed = try parseGitRemoteUrl(url);
    // Dupe strings so they outlive the freed stdout buffer
    return OwnerRepo{
        .owner = try allocator.dupe(u8, parsed.owner),
        .repo = try allocator.dupe(u8, parsed.repo),
    };
}

/// Parse SSH or HTTPS git remote URL into owner/repo
pub fn parseGitRemoteUrl(url: []const u8) !OwnerRepo {
    // SSH: git@github.com:owner/repo.git
    if (std.mem.startsWith(u8, url, "git@")) {
        const colon_idx = std.mem.indexOf(u8, url, ":") orelse return error.InvalidRemoteUrl;
        const path = url[colon_idx + 1 ..];
        return parseOwnerRepoFromPath(path);
    }

    // HTTPS: https://github.com/owner/repo.git
    if (std.mem.startsWith(u8, url, "https://") or std.mem.startsWith(u8, url, "http://")) {
        // Find path after host
        const after_scheme = if (std.mem.startsWith(u8, url, "https://")) url[8..] else url[7..];
        const slash_idx = std.mem.indexOf(u8, after_scheme, "/") orelse return error.InvalidRemoteUrl;
        const path = after_scheme[slash_idx + 1 ..];
        return parseOwnerRepoFromPath(path);
    }

    return error.InvalidRemoteUrl;
}

fn parseOwnerRepoFromPath(path: []const u8) !OwnerRepo {
    const slash_idx = std.mem.indexOf(u8, path, "/") orelse return error.InvalidRemoteUrl;
    const owner = path[0..slash_idx];
    var repo = path[slash_idx + 1 ..];

    // Strip .git suffix
    if (std.mem.endsWith(u8, repo, ".git")) {
        repo = repo[0 .. repo.len - 4];
    }
    // Strip trailing whitespace
    repo = std.mem.trimRight(u8, repo, " \n\r\t");

    if (owner.len == 0 or repo.len == 0) return error.InvalidRemoteUrl;

    return OwnerRepo{ .owner = owner, .repo = repo };
}

/// Escape a string for inclusion in JSON
pub fn escapeJson(input: []const u8, buf: []u8) []const u8 {
    var pos: usize = 0;
    for (input) |c| {
        const to_write: []const u8 = switch (c) {
            '"' => "\\\"",
            '\\' => "\\\\",
            '\n' => "\\n",
            '\r' => "\\r",
            '\t' => "\\t",
            else => &[_]u8{c},
        };
        if (pos + to_write.len > buf.len) break;
        @memcpy(buf[pos .. pos + to_write.len], to_write);
        pos += to_write.len;
    }
    return buf[0..pos];
}

/// Heap-allocated JSON escape (for arbitrarily long strings like GraphQL queries)
pub fn jsonEscapeAlloc(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    // Worst case: every char needs escaping (2x)
    var result = try std.ArrayList(u8).initCapacity(allocator, input.len);
    for (input) |c| {
        switch (c) {
            '"' => try result.appendSlice(allocator, "\\\""),
            '\\' => try result.appendSlice(allocator, "\\\\"),
            '\n' => try result.appendSlice(allocator, "\\n"),
            '\r' => try result.appendSlice(allocator, "\\r"),
            '\t' => try result.appendSlice(allocator, "\\t"),
            else => try result.append(allocator, c),
        }
    }
    return try result.toOwnedSlice(allocator);
}

/// Parse PR result from GitHub API JSON response
fn parsePrResult(json: []const u8) !PrResult {
    const number = extractJsonNumber(json, "number") orelse return error.ParseError;
    return PrResult{
        .number = @intCast(number),
        .url = extractJsonString(json, "html_url") orelse extractJsonString(json, "url") orelse "",
        .state = extractJsonString(json, "state") orelse "unknown",
    };
}

fn buildCreateIssueJson(buf: []u8, title: []const u8, body: ?[]const u8, labels: []const []const u8) ![]const u8 {
    var escape_title_buf: [1024]u8 = undefined;
    const escaped_title = escapeJson(title, &escape_title_buf);

    var pos: usize = 0;

    // Start JSON
    const start = "{\"title\":\"";
    if (pos + start.len + escaped_title.len + 1 > buf.len) return error.Overflow;
    @memcpy(buf[pos .. pos + start.len], start);
    pos += start.len;
    @memcpy(buf[pos .. pos + escaped_title.len], escaped_title);
    pos += escaped_title.len;
    buf[pos] = '"';
    pos += 1;

    // Body
    if (body) |b| {
        var escape_body_buf: [4096]u8 = undefined;
        const escaped_body = escapeJson(b, &escape_body_buf);
        const body_prefix = ",\"body\":\"";
        if (pos + body_prefix.len + escaped_body.len + 1 > buf.len) return error.Overflow;
        @memcpy(buf[pos .. pos + body_prefix.len], body_prefix);
        pos += body_prefix.len;
        @memcpy(buf[pos .. pos + escaped_body.len], escaped_body);
        pos += escaped_body.len;
        buf[pos] = '"';
        pos += 1;
    }

    // Labels
    if (labels.len > 0) {
        const labels_prefix = ",\"labels\":[";
        if (pos + labels_prefix.len >= buf.len) return error.Overflow;
        @memcpy(buf[pos .. pos + labels_prefix.len], labels_prefix);
        pos += labels_prefix.len;
        for (labels, 0..) |label, i| {
            if (i > 0) {
                buf[pos] = ',';
                pos += 1;
            }
            if (pos + 2 >= buf.len) return error.Overflow;
            buf[pos] = '"';
            pos += 1;
            var escape_label_buf: [256]u8 = undefined;
            const escaped_label = escapeJson(label, &escape_label_buf);
            if (pos + escaped_label.len + 1 >= buf.len) return error.Overflow;
            @memcpy(buf[pos .. pos + escaped_label.len], escaped_label);
            pos += escaped_label.len;
            buf[pos] = '"';
            pos += 1;
        }
        buf[pos] = ']';
        pos += 1;
    }

    buf[pos] = '}';
    pos += 1;

    return buf[0..pos];
}

fn buildLabelsJson(buf: []u8, labels: []const []const u8) ![]const u8 {
    var pos: usize = 0;
    const start = "{\"labels\":[";
    @memcpy(buf[pos .. pos + start.len], start);
    pos += start.len;

    for (labels, 0..) |label, i| {
        if (i > 0) {
            buf[pos] = ',';
            pos += 1;
        }
        buf[pos] = '"';
        pos += 1;
        var escape_buf: [256]u8 = undefined;
        const escaped = escapeJson(label, &escape_buf);
        @memcpy(buf[pos .. pos + escaped.len], escaped);
        pos += escaped.len;
        buf[pos] = '"';
        pos += 1;
    }

    const end = "]}";
    @memcpy(buf[pos .. pos + end.len], end);
    pos += end.len;

    return buf[0..pos];
}

/// Parse issue number and URL from GitHub API JSON response
fn parseIssueResult(json: []const u8) !IssueResult {
    // Simple extraction: find "number": N and "html_url": "..."
    const number = extractJsonNumber(json, "number") orelse return error.ParseError;
    _ = extractJsonString(json, "html_url"); // URL is in response but we don't need to own it
    return IssueResult{
        .number = @intCast(number),
        .url = "", // Caller can construct from owner/repo/number
    };
}

/// Parse issue info from GitHub API JSON response
fn parseIssueInfo(json: []const u8) !IssueInfo {
    const number = extractJsonNumber(json, "number") orelse return error.ParseError;
    return IssueInfo{
        .number = @intCast(number),
        .title = extractJsonString(json, "title") orelse "(unknown)",
        .state = extractJsonString(json, "state") orelse "unknown",
        .body = extractJsonString(json, "body") orelse "",
        .labels = &.{},
    };
}

/// Parse `gh issue create` output: last line contains the URL with issue number
fn parseGhIssueCreateOutput(output: []const u8) !IssueResult {
    // Output format: https://github.com/owner/repo/issues/N
    const trimmed = std.mem.trimRight(u8, output, "\n\r ");
    // Find last /
    const last_slash = std.mem.lastIndexOf(u8, trimmed, "/") orelse return error.ParseError;
    const num_str = trimmed[last_slash + 1 ..];
    const number = std.fmt.parseInt(u32, num_str, 10) catch return error.ParseError;
    return IssueResult{
        .number = number,
        .url = trimmed,
    };
}

/// Extract a number value from JSON by key (simple parser)
fn extractJsonNumber(json: []const u8, key: []const u8) ?i64 {
    var i: usize = 0;
    while (i + key.len + 3 < json.len) : (i += 1) {
        if (json[i] == '"' and i + key.len + 1 < json.len and
            std.mem.eql(u8, json[i + 1 .. i + 1 + key.len], key) and
            json[i + 1 + key.len] == '"')
        {
            // Found the key, now skip to ':'
            var j = i + 2 + key.len;
            while (j < json.len and json[j] == ' ') : (j += 1) {}
            if (j < json.len and json[j] == ':') {
                j += 1;
                while (j < json.len and json[j] == ' ') : (j += 1) {}
                // Parse number
                var end = j;
                if (end < json.len and json[end] == '-') end += 1;
                while (end < json.len and json[end] >= '0' and json[end] <= '9') : (end += 1) {}
                if (end > j) {
                    return std.fmt.parseInt(i64, json[j..end], 10) catch null;
                }
            }
        }
    }
    return null;
}

/// Extract a string value from JSON by key (simple parser)
pub fn extractJsonString(json: []const u8, key: []const u8) ?[]const u8 {
    var i: usize = 0;
    while (i + key.len + 3 < json.len) : (i += 1) {
        if (json[i] == '"' and i + key.len + 1 < json.len and
            std.mem.eql(u8, json[i + 1 .. i + 1 + key.len], key) and
            json[i + 1 + key.len] == '"')
        {
            var j = i + 2 + key.len;
            while (j < json.len and json[j] == ' ') : (j += 1) {}
            if (j < json.len and json[j] == ':') {
                j += 1;
                while (j < json.len and json[j] == ' ') : (j += 1) {}
                if (j < json.len and json[j] == '"') {
                    j += 1;
                    const start = j;
                    while (j < json.len and json[j] != '"') : (j += 1) {
                        if (json[j] == '\\') j += 1; // skip escaped char
                    }
                    return json[start..j];
                }
            }
        }
    }
    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "parseGitRemoteUrl SSH" {
    const result = try parseGitRemoteUrl("git@github.com:gHashTag/trinity.git");
    try std.testing.expectEqualStrings("gHashTag", result.owner);
    try std.testing.expectEqualStrings("trinity", result.repo);
}

test "parseGitRemoteUrl HTTPS" {
    const result = try parseGitRemoteUrl("https://github.com/gHashTag/trinity.git");
    try std.testing.expectEqualStrings("gHashTag", result.owner);
    try std.testing.expectEqualStrings("trinity", result.repo);
}

test "parseGitRemoteUrl HTTPS no .git" {
    const result = try parseGitRemoteUrl("https://github.com/gHashTag/trinity");
    try std.testing.expectEqualStrings("gHashTag", result.owner);
    try std.testing.expectEqualStrings("trinity", result.repo);
}

test "escapeJson basic" {
    var buf: [256]u8 = undefined;
    const result = escapeJson("hello \"world\"\nnewline", &buf);
    try std.testing.expectEqualStrings("hello \\\"world\\\"\\nnewline", result);
}

test "escapeJson backslash and tab" {
    var buf: [256]u8 = undefined;
    const result = escapeJson("path\\to\tthing", &buf);
    try std.testing.expectEqualStrings("path\\\\to\\tthing", result);
}

test "extractJsonNumber" {
    const json = "{\"number\": 42, \"id\": 123}";
    try std.testing.expectEqual(@as(i64, 42), extractJsonNumber(json, "number").?);
    try std.testing.expectEqual(@as(i64, 123), extractJsonNumber(json, "id").?);
}

test "extractJsonString" {
    const json = "{\"title\": \"hello world\", \"state\": \"open\"}";
    try std.testing.expectEqualStrings("hello world", extractJsonString(json, "title").?);
    try std.testing.expectEqualStrings("open", extractJsonString(json, "state").?);
}

test "buildLabelsJson" {
    var buf: [1024]u8 = undefined;
    const labels = &[_][]const u8{ "bug", "urgent" };
    const result = try buildLabelsJson(&buf, labels);
    try std.testing.expectEqualStrings("{\"labels\":[\"bug\",\"urgent\"]}", result);
}

test "parseGhIssueCreateOutput" {
    const output = "https://github.com/gHashTag/trinity/issues/42\n";
    const result = try parseGhIssueCreateOutput(output);
    try std.testing.expectEqual(@as(u32, 42), result.number);
}

test "parsePrResult" {
    const json = "{\"number\": 7, \"html_url\": \"https://github.com/o/r/pull/7\", \"state\": \"open\"}";
    const result = try parsePrResult(json);
    try std.testing.expectEqual(@as(u32, 7), result.number);
    try std.testing.expectEqualStrings("open", result.state);
}

test "jsonEscapeAlloc" {
    const allocator = std.testing.allocator;
    const result = try jsonEscapeAlloc(allocator, "hello \"world\"\nnewline");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello \\\"world\\\"\\nnewline", result);
}

test "jsonEscapeAlloc graphql query" {
    const allocator = std.testing.allocator;
    const query = "{ repository(owner: \"o\", name: \"r\") { pullRequests(first: 10) { nodes { number } } } }";
    const result = try jsonEscapeAlloc(allocator, query);
    defer allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "\\\"o\\\"") != null);
}
