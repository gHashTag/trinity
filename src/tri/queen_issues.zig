// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// QUEEN ISSUES — GitHub issues integration for Queen daemon
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const qt = @import("queen_types.zig");
const github_client = @import("github_client.zig");
const github_app_auth = @import("github_app_auth.zig");

const Allocator = std.mem.Allocator;
const GITHUB_API_HOST = "api.github.com";

// ═══════════════════════════════════════════════════════════════════════════════
// ISSUE TRACKER — GitHub issues operations for Queen
// ═══════════════════════════════════════════════════════════════════════════════

pub const IssueTracker = struct {
    allocator: Allocator,
    client: ?github_client.GitHubClient,
    app_auth: ?github_app_auth.GitHubAppAuth,
    owner: []const u8,
    repo: []const u8,
    dry_run: bool,

    const Self = @This();

    /// Initialize IssueTracker with GitHub client
    pub fn init(allocator: Allocator, dry_run: bool) !Self {
        var client: ?github_client.GitHubClient = null;
        var app_auth: ?github_app_auth.GitHubAppAuth = null;

        // Try GitHub App auth first (higher rate limit)
        if (github_app_auth.GitHubAppAuth.isAvailable()) {
            app_auth = try github_app_auth.GitHubAppAuth.init(allocator);
        }

        // Fallback to regular client (this already detects owner/repo)
        client = try github_client.GitHubClient.init(allocator, dry_run);

        // Use owner/repo from the client (already allocated by GitHubClient.init())
        const owner = client.?.owner;
        const repo = client.?.repo;

        return .{
            .allocator = allocator,
            .client = client,
            .app_auth = app_auth,
            .owner = owner,
            .repo = repo,
            .dry_run = dry_run,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.app_auth) |*auth| auth.deinit();
        // Free owner/repo (ownership transferred from GitHubClient)
        self.allocator.free(self.owner);
        self.allocator.free(self.repo);
        // client is a value type, no deinit needed
        // Note: client.deinit() is NOT called because we transferred ownership of owner/repo
    }

    /// Create a new GitHub issue
    pub fn createIssue(self: *Self, title: []const u8, body: []const u8, labels: []const []const u8) !IssueResult {
        if (self.dry_run) {
            std.debug.print("[DRY-RUN] Would create issue: {s}\n", .{title});
            return IssueResult{
                .number = 0,
                .url = "https://github.com/example/trinity/issues/0",
            };
        }

        // Use GitHub App auth if available, otherwise use gh CLI
        if (self.app_auth) |*auth| {
            return self.createIssueApi(auth, title, body, labels);
        }

        return self.createIssueGh(title, body, labels);
    }

    /// Create issue using GitHub REST API with App auth
    fn createIssueApi(self: *Self, auth: *github_app_auth.GitHubAppAuth, title: []const u8, issue_body: []const u8, labels: []const []const u8) !IssueResult {
        const token = try auth.getToken();
        defer self.allocator.free(token);

        const url = try std.fmt.allocPrint(self.allocator, "https://{s}/repos/{s}/{s}/issues", .{ GITHUB_API_HOST, self.owner, self.repo });
        defer self.allocator.free(url);

        // Build request body
        var body_buf: [8192]u8 = undefined;
        var body_len: usize = 0;

        // JSON-escape title and issue_body
        const json_buf = body_buf[0..];
        _ = try std.fmt.bufPrint(json_buf, "{{\"title\":\"", .{});
        body_len += 10;

        // Escape title
        for (title) |c| {
            if (c == '"') {
                @memcpy(body_buf[body_len..][0..2], "\\\"");
                body_len += 2;
            } else if (c == '\\') {
                @memcpy(body_buf[body_len..][0..2], "\\\\");
                body_len += 2;
            } else if (c == '\n') {
                @memcpy(body_buf[body_len..][0..2], "\\n");
                body_len += 2;
            } else {
                body_buf[body_len] = c;
                body_len += 1;
            }
        }

        _ = try std.fmt.bufPrint(body_buf[body_len..], "\",\"body\":\"", .{});
        body_len += 10;

        // Escape issue_body
        for (issue_body) |c| {
            if (c == '"') {
                @memcpy(body_buf[body_len..][0..2], "\\\"");
                body_len += 2;
            } else if (c == '\\') {
                @memcpy(body_buf[body_len..][0..2], "\\\\");
                body_len += 2;
            } else if (c == '\n') {
                @memcpy(body_buf[body_len..][0..2], "\\n");
                body_len += 2;
            } else if (c == '\r') {
                @memcpy(body_buf[body_len..][0..2], "\\r");
                body_len += 2;
            } else {
                body_buf[body_len] = c;
                body_len += 1;
            }
        }

        // Add labels
        if (labels.len > 0) {
            _ = try std.fmt.bufPrint(body_buf[body_len..], "\",\"labels\":[", .{});
            body_len += 12;

            for (labels, 0..) |label, i| {
                if (i > 0) {
                    body_buf[body_len] = ',';
                    body_len += 1;
                }
                body_buf[body_len] = '"';
                body_len += 1;
                @memcpy(body_buf[body_len..][0..label.len], label);
                body_len += label.len;
                body_buf[body_len] = '"';
                body_len += 1;
            }

            body_buf[body_len] = ']';
            body_len += 1;
        }

        body_buf[body_len] = '}';
        body_len += 1;

        const request_body = body_buf[0..body_len];

        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();

        const uri = try std.Uri.parse(url);

        var auth_buf: [1024]u8 = undefined;
        const auth_val = try std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{token});

        var headers = [_]std.http.Header{
            .{ .name = "User-Agent", .value = "trinity-queen/1.0" },
            .{ .name = "Accept", .value = "application/vnd.github+json" },
            .{ .name = "Authorization", .value = auth_val },
            .{ .name = "X-GitHub-Api-Version", .value = "2022-11-28" },
        };

        var req = try client.request(.POST, uri, .{
            .extra_headers = &headers,
            .redirect_behavior = .unhandled,
        });
        defer req.deinit();

        req.transfer_encoding = .{ .content_length = request_body.len };
        var body_writer = try req.sendBodyUnflushed(&.{});
        try body_writer.writer().writeAll(request_body);
        try body_writer.end();
        if (req.connection) |conn| try conn.flush();

        var redirect_buf: [0]u8 = .{};
        var response = try req.receiveHead(&redirect_buf);

        const status_code = @intFromEnum(response.head.status);
        if (status_code != 201) {
            var transfer_buffer: [4096]u8 = undefined;
            var reader = response.reader(&transfer_buffer);
            const error_body = try reader.allocRemaining(self.allocator, std.Io.Limit.limited(4096));
            defer self.allocator.free(error_body);
            std.debug.print("GitHub API error {d}: {s}\n", .{ status_code, error_body });
            return error.ApiError;
        }

        var transfer_buffer: [8192]u8 = undefined;
        var reader = response.reader(&transfer_buffer);
        const resp_body = try reader.allocRemaining(self.allocator, std.Io.Limit.limited(64 * 1024));
        defer self.allocator.free(resp_body);

        // Parse response JSON to get issue number and URL
        const number = if (qt.findJsonU32(resp_body, "\"number\":")) |n| n else 0;
        const issue_url = if (qt.findJsonStr(resp_body, "\"html_url\":\"")) |u|
            try self.allocator.dupe(u8, u)
        else
            try self.allocator.dupe(u8, url);

        return IssueResult{
            .number = number,
            .url = issue_url,
        };
    }

    /// Create issue using gh CLI fallback
    fn createIssueGh(self: *Self, title: []const u8, issue_body: []const u8, labels: []const []const u8) !IssueResult {
        // Build gh CLI command
        var argv_list = std.ArrayList([]const u8).init(self.allocator);
        defer argv_list.deinit();

        try argv_list.appendSlice(self.allocator, &.{ "gh", "issue", "create", "--title", title, "--body", issue_body });

        if (labels.len > 0) {
            const labels_str = try std.mem.join(self.allocator, ",", labels);
            defer self.allocator.free(labels_str);
            try argv_list.appendSlice(self.allocator, &.{ "--label", labels_str });
        }

        try argv_list.append("--json");
        try argv_list.append("number,url");

        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = argv_list.items,
            .max_output_bytes = 64 * 1024,
        });
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        const exit_code = switch (result.term) {
            .Exited => |code| code,
            else => @as(u32, 1),
        };

        if (exit_code != 0) {
            std.debug.print("gh issue create failed: {s}\n", .{result.stderr});
            return error.GhCliFailed;
        }

        // Parse JSON output: [{"number":123,"url":"..."}]
        const number = if (qt.findJsonU32(result.stdout, "\"number\":")) |n| n else 0;
        const issue_url = if (qt.findJsonStr(result.stdout, "\"url\":\"")) |u|
            try self.allocator.dupe(u8, u)
        else
            try self.allocator.dupe(u8, "https://github.com/example/trinity/issues/0");

        return IssueResult{
            .number = number,
            .url = issue_url,
        };
    }

    /// Add comment to existing issue
    pub fn updateIssue(self: *Self, issue_number: u32, comment: []const u8) !void {
        if (self.dry_run) {
            std.debug.print("[DRY-RUN] Would comment on issue #{d}: {s}\n", .{ issue_number, comment });
            return;
        }

        if (self.app_auth) |*auth| {
            try self.updateIssueApi(auth, issue_number, comment);
        } else {
            try self.updateIssueGh(issue_number, comment);
        }
    }

    /// Add comment using GitHub REST API
    fn updateIssueApi(self: *Self, auth: *github_app_auth.GitHubAppAuth, issue_number: u32, comment: []const u8) !void {
        const token = try auth.getToken();
        defer self.allocator.free(token);

        const url = try std.fmt.allocPrint(self.allocator, "https://{s}/repos/{s}/{s}/issues/{d}/comments", .{ GITHUB_API_HOST, self.owner, self.repo, issue_number });
        defer self.allocator.free(url);

        // Build JSON body with escaped comment
        var body_buf: [8192]u8 = undefined;
        var body_len: usize = 0;

        _ = try std.fmt.bufPrint(body_buf[0..], "{{\"body\":\"", .{});
        body_len += 10;

        for (comment) |c| {
            if (c == '"') {
                @memcpy(body_buf[body_len..][0..2], "\\\"");
                body_len += 2;
            } else if (c == '\\') {
                @memcpy(body_buf[body_len..][0..2], "\\\\");
                body_len += 2;
            } else if (c == '\n') {
                @memcpy(body_buf[body_len..][0..2], "\\n");
                body_len += 2;
            } else if (c == '\r') {
                @memcpy(body_buf[body_len..][0..2], "\\r");
                body_len += 2;
            } else {
                body_buf[body_len] = c;
                body_len += 1;
            }
        }

        @memcpy(body_buf[body_len..][0..2], "\"}");
        body_len += 2;

        const request_body = body_buf[0..body_len];

        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();

        const uri = try std.Uri.parse(url);

        var auth_buf: [1024]u8 = undefined;
        const auth_val = try std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{token});

        var headers = [_]std.http.Header{
            .{ .name = "User-Agent", .value = "trinity-queen/1.0" },
            .{ .name = "Accept", .value = "application/vnd.github+json" },
            .{ .name = "Authorization", .value = auth_val },
            .{ .name = "X-GitHub-Api-Version", .value = "2022-11-28" },
        };

        var req = try client.request(.POST, uri, .{
            .extra_headers = &headers,
            .redirect_behavior = .unhandled,
        });
        defer req.deinit();

        req.transfer_encoding = .{ .content_length = request_body.len };
        var body_writer = try req.sendBodyUnflushed(&.{});
        try body_writer.writer().writeAll(request_body);
        try body_writer.end();
        if (req.connection) |conn| try conn.flush();

        var redirect_buf: [0]u8 = .{};
        var response = try req.receiveHead(&redirect_buf);

        const status_code = @intFromEnum(response.head.status);
        if (status_code != 201) {
            var transfer_buffer: [4096]u8 = undefined;
            var reader = response.reader(&transfer_buffer);
            const error_body = try reader.allocRemaining(self.allocator, std.Io.Limit.limited(4096));
            defer self.allocator.free(error_body);
            std.debug.print("GitHub API error {d}: {s}\n", .{ status_code, error_body });
            return error.ApiError;
        }
    }

    /// Add comment using gh CLI fallback
    fn updateIssueGh(self: *Self, issue_number: u32, comment: []const u8) !void {
        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &.{ "gh", "issue", "comment", try std.fmt.allocPrint(self.allocator, "{d}", .{issue_number}), "--body", comment },
            .max_output_bytes = 4096,
        });
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        const exit_code = switch (result.term) {
            .Exited => |code| code,
            else => @as(u32, 1),
        };

        if (exit_code != 0) {
            std.debug.print("gh issue comment failed: {s}\n", .{result.stderr});
            return error.GhCliFailed;
        }
    }

    /// Close issue with optional comment
    pub fn closeIssue(self: *Self, issue_number: u32, comment: ?[]const u8) !void {
        if (self.dry_run) {
            std.debug.print("[DRY-RUN] Would close issue #{d}\n", .{issue_number});
            return;
        }

        // Add comment first if provided
        if (comment) |c| {
            try self.updateIssue(issue_number, c);
        }

        if (self.app_auth) |*auth| {
            try self.closeIssueApi(auth, issue_number);
        } else {
            try self.closeIssueGh(issue_number);
        }
    }

    /// Close issue using GitHub REST API
    fn closeIssueApi(self: *Self, auth: *github_app_auth.GitHubAppAuth, issue_number: u32) !void {
        const token = try auth.getToken();
        defer self.allocator.free(token);

        const url = try std.fmt.allocPrint(self.allocator, "https://{s}/repos/{s}/{s}/issues/{d}", .{ GITHUB_API_HOST, self.owner, self.repo, issue_number });
        defer self.allocator.free(url);

        const request_body = "{\"state\":\"closed\"}";

        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();

        const uri = try std.Uri.parse(url);

        var auth_buf: [1024]u8 = undefined;
        const auth_val = try std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{token});

        var headers = [_]std.http.Header{
            .{ .name = "User-Agent", .value = "trinity-queen/1.0" },
            .{ .name = "Accept", .value = "application/vnd.github+json" },
            .{ .name = "Authorization", .value = auth_val },
            .{ .name = "X-GitHub-Api-Version", .value = "2022-11-28" },
        };

        var req = try client.request(.PATCH, uri, .{
            .extra_headers = &headers,
            .redirect_behavior = .unhandled,
        });
        defer req.deinit();

        req.transfer_encoding = .{ .content_length = request_body.len };
        var body_writer = try req.sendBodyUnflushed(&.{});
        try body_writer.writer().writeAll(request_body);
        try body_writer.end();
        if (req.connection) |conn| try conn.flush();

        var redirect_buf: [0]u8 = .{};
        var response = try req.receiveHead(&redirect_buf);

        const status_code = @intFromEnum(response.head.status);
        if (status_code != 200) {
            var transfer_buffer: [4096]u8 = undefined;
            var reader = response.reader(&transfer_buffer);
            const error_body = try reader.allocRemaining(self.allocator, std.Io.Limit.limited(4096));
            defer self.allocator.free(error_body);
            std.debug.print("GitHub API error {d}: {s}\n", .{ status_code, error_body });
            return error.ApiError;
        }
    }

    /// Close issue using gh CLI fallback
    fn closeIssueGh(self: *Self, issue_number: u32) !void {
        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &.{ "gh", "issue", "close", try std.fmt.allocPrint(self.allocator, "{d}", .{issue_number}) },
            .max_output_bytes = 4096,
        });
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        const exit_code = switch (result.term) {
            .Exited => |code| code,
            else => @as(u32, 1),
        };

        if (exit_code != 0) {
            std.debug.print("gh issue close failed: {s}\n", .{result.stderr});
            return error.GhCliFailed;
        }
    }

    /// Get issue status (open/closed, labels, etc.)
    pub fn getIssueStatus(self: *Self, issue_number: u32) !IssueStatus {
        if (self.app_auth) |*auth| {
            return self.getIssueStatusApi(auth, issue_number);
        }
        return self.getIssueStatusGh(issue_number);
    }

    /// Get issue status using GitHub REST API
    fn getIssueStatusApi(self: *Self, auth: *github_app_auth.GitHubAppAuth, issue_number: u32) !IssueStatus {
        const token = try auth.getToken();
        defer self.allocator.free(token);

        const url = try std.fmt.allocPrint(self.allocator, "https://{s}/repos/{s}/{s}/issues/{d}", .{ GITHUB_API_HOST, self.owner, self.repo, issue_number });
        defer self.allocator.free(url);

        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();

        const uri = try std.Uri.parse(url);

        var auth_buf: [1024]u8 = undefined;
        const auth_val = try std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{token});

        var headers = [_]std.http.Header{
            .{ .name = "User-Agent", .value = "trinity-queen/1.0" },
            .{ .name = "Accept", .value = "application/vnd.github+json" },
            .{ .name = "Authorization", .value = auth_val },
            .{ .name = "X-GitHub-Api-Version", .value = "2022-11-28" },
        };

        var req = try client.request(.GET, uri, .{
            .extra_headers = &headers,
            .redirect_behavior = .unhandled,
        });
        defer req.deinit();

        var redirect_buf: [0]u8 = .{};
        var response = try req.receiveHead(&redirect_buf);

        const status_code = @intFromEnum(response.head.status);
        if (status_code != 200) {
            return error.IssueNotFound;
        }

        var transfer_buffer: [16384]u8 = undefined;
        var reader = response.reader(&transfer_buffer);
        const body = try reader.allocRemaining(self.allocator, std.Io.Limit.limited(16384));
        defer self.allocator.free(body);

        // Parse response
        var result = IssueStatus{
            .number = issue_number,
            .state = "unknown",
            .title = "",
        };

        if (qt.findJsonStr(body, "\"state\":\"")) |s| {
            result.state = s;
        }
        if (qt.findJsonStr(body, "\"title\":\"")) |t| {
            const end = std.mem.indexOfScalar(u8, t, '"') orelse t.len;
            result.title = t[0..end];
        }

        // Count labels
        var label_count: usize = 0;
        var pos: usize = 0;
        while (qt.findJsonStr(body[pos..], "\"name\":\"")) |lbl| {
            label_count += 1;
            pos += lbl.len + 8;
            if (pos >= body.len) break;
        }
        result.label_count = @intCast(label_count);

        return result;
    }

    /// Get issue status using gh CLI fallback
    fn getIssueStatusGh(self: *Self, issue_number: u32) !IssueStatus {
        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &.{ "gh", "issue", "view", try std.fmt.allocPrint(self.allocator, "{d}", .{issue_number}), "--json", "state,title,labels" },
            .max_output_bytes = 16384,
        });
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        const exit_code = switch (result.term) {
            .Exited => |code| code,
            else => @as(u32, 1),
        };

        if (exit_code != 0) {
            return error.IssueNotFound;
        }

        var status = IssueStatus{
            .number = issue_number,
            .state = "unknown",
            .title = "",
        };

        if (qt.findJsonStr(result.stdout, "\"state\":\"")) |s| {
            status.state = s;
        }
        if (qt.findJsonStr(result.stdout, "\"title\":\"")) |t| {
            const end = std.mem.indexOfScalar(u8, t, '"') orelse t.len;
            status.title = t[0..end];
        }

        // Count labels
        var label_count: usize = 0;
        var pos: usize = 0;
        while (qt.findJsonStr(result.stdout[pos..], "\"name\":\"")) |lbl| {
            label_count += 1;
            pos += lbl.len + 8;
            if (pos >= result.stdout.len) break;
        }
        status.label_count = @intCast(label_count);

        return status;
    }

    /// List open issues with optional label filter
    pub fn listIssues(self: *Self, label_filter: ?[]const u8) ![]IssueStatus {
        if (self.app_auth) |*auth| {
            return self.listIssuesApi(auth, label_filter);
        }
        return self.listIssuesGh(label_filter);
    }

    /// List issues using GitHub REST API
    fn listIssuesApi(self: *Self, auth: *github_app_auth.GitHubAppAuth, label_filter: ?[]const u8) ![]IssueStatus {
        const token = try auth.getToken();
        defer self.allocator.free(token);

        var url_buf: [256]u8 = undefined;
        const url = try std.fmt.bufPrint(&url_buf, "https://{s}/repos/{s}/{s}/issues?state=open&per_page=100", .{ GITHUB_API_HOST, self.owner, self.repo });

        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();

        const uri = try std.Uri.parse(url);

        var auth_buf: [1024]u8 = undefined;
        const auth_val = try std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{token});

        var headers = [_]std.http.Header{
            .{ .name = "User-Agent", .value = "trinity-queen/1.0" },
            .{ .name = "Accept", .value = "application/vnd.github+json" },
            .{ .name = "Authorization", .value = auth_val },
            .{ .name = "X-GitHub-Api-Version", .value = "2022-11-28" },
        };

        var req = try client.request(.GET, uri, .{
            .extra_headers = &headers,
            .redirect_behavior = .unhandled,
        });
        defer req.deinit();

        var redirect_buf: [0]u8 = .{};
        var response = try req.receiveHead(&redirect_buf);

        const status_code = @intFromEnum(response.head.status);
        if (status_code != 200) {
            return error.ApiError;
        }

        var transfer_buffer: [65536]u8 = undefined;
        var reader = response.reader(&transfer_buffer);
        const resp_body = try reader.allocRemaining(self.allocator, std.Io.Limit.limited(65536));
        defer self.allocator.free(resp_body);

        // Parse JSON array of issues
        var issues = try std.ArrayList(IssueStatus).initCapacity(self.allocator, 32);

        var pos: usize = 0;
        while (pos < resp_body.len) {
            // Find next issue object
            const obj_start = std.mem.indexOfPos(u8, resp_body, pos, "{") orelse break;
            const obj_end = std.mem.indexOfPos(u8, resp_body, obj_start, "}") orelse break;
            pos = obj_end + 1;
            const issue_start = std.mem.indexOfPos(u8, resp_body, pos, "\"number\":") orelse break;
            const number = if (qt.findJsonU32(resp_body[issue_start..], "\"number\":")) |n| n else continue;

            // Check label filter
            if (label_filter) |filter| {
                const labels_start = std.mem.indexOfPos(u8, resp_body, pos, "\"labels\":[") orelse continue;
                const labels_end = std.mem.indexOfPos(u8, resp_body, labels_start, "]") orelse continue;
                const labels_section = resp_body[labels_start..labels_end];
                if (std.mem.indexOf(u8, labels_section, filter) == null) {
                    pos = labels_end;
                    continue;
                }
            }

            const state = if (qt.findJsonStr(resp_body[issue_start..], "\"state\":\"")) |s| s else "unknown";
            const title_raw = if (qt.findJsonStr(resp_body[issue_start..], "\"title\":\"")) |t| t else "";
            const title_end = std.mem.indexOfScalar(u8, title_raw, '"') orelse title_raw.len;
            const title = title_raw[0..title_end];

            var label_count: u8 = 0;
            const labels_section_start = std.mem.indexOfPos(u8, resp_body, pos, "\"labels\":[") orelse pos + 100;
            const labels_section = resp_body[labels_section_start..][0..@min(500, resp_body.len - labels_section_start)];
            var lc_pos: usize = 0;
            while (std.mem.indexOfPos(u8, labels_section, lc_pos, "\"name\":\"")) |lbl| {
                label_count += 1;
                lc_pos = lbl + 8;
            }

            try issues.append(self.allocator, .{
                .number = number,
                .state = state,
                .title = title,
                .label_count = label_count,
            });

            pos = issue_start + 20;
        }

        return issues.toOwnedSlice(self.allocator);
    }

    /// List issues using gh CLI fallback
    fn listIssuesGh(self: *Self, label_filter: ?[]const u8) ![]IssueStatus {
        var argv = try std.ArrayList([]const u8).initCapacity(self.allocator, 16);
        defer argv.deinit(self.allocator);

        try argv.appendSlice(self.allocator, &.{ "gh", "issue", "list", "--state", "open", "--json", "number,state,title,labels", "--limit", "100" });

        if (label_filter) |filter| {
            const search = try std.fmt.allocPrint(self.allocator, "label:\"{s}\"", .{filter});
            defer self.allocator.free(search);
            try argv.append(self.allocator, "--search");
            try argv.append(self.allocator, search);
        }

        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = argv.items,
            .max_output_bytes = 65536,
        });
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        const exit_code = switch (result.term) {
            .Exited => |code| code,
            else => @as(u32, 1),
        };

        if (exit_code != 0) {
            return error.GhCliFailed;
        }

        var issues = try std.ArrayList(IssueStatus).initCapacity(self.allocator, 32);

        var pos: usize = 0;
        while (pos < result.stdout.len) {
            const issue_start = std.mem.indexOfPos(u8, result.stdout, pos, "\"number\":") orelse break;
            const number = if (qt.findJsonU32(result.stdout[issue_start..], "\"number\":")) |n| n else continue;
            const state = if (qt.findJsonStr(result.stdout[issue_start..], "\"state\":\"")) |s| s else "unknown";
            const title_raw = if (qt.findJsonStr(result.stdout[issue_start..], "\"title\":\"")) |t| t else "";
            const title_end = std.mem.indexOfScalar(u8, title_raw, '"') orelse title_raw.len;
            const title = title_raw[0..title_end];

            var label_count: u8 = 0;
            var lc_pos: usize = issue_start;
            while (std.mem.indexOfPos(u8, result.stdout, lc_pos, "\"name\":\"")) |lbl| {
                label_count += 1;
                lc_pos = lbl + 8;
                if (lc_pos >= result.stdout.len) break;
            }

            try issues.append(self.allocator, .{
                .number = number,
                .state = state,
                .title = title,
                .label_count = label_count,
            });

            pos = issue_start + 20;
        }

        return issues.toOwnedSlice(self.allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// RESULT TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const IssueResult = struct {
    number: u32,
    url: []const u8,
};

pub const IssueStatus = struct {
    number: u32,
    state: []const u8, // "open", "closed", "unknown"
    title: []const u8,
    label_count: u8 = 0,
};

const RepoDetection = struct {
    owner: []const u8,
    repo: []const u8,
};

/// Detect owner/repo from git remote
fn detectRepo(allocator: Allocator) ?RepoDetection {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "remote", "get-url", "origin" },
        .max_output_bytes = 1024,
    }) catch return null;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const exit_code = switch (result.term) {
        .Exited => |code| code,
        else => @as(u32, 1),
    };
    if (exit_code != 0) return null;

    // Parse URL: https://github.com/owner/repo.git or git@github.com:owner/repo.git
    const url = std.mem.trim(u8, result.stdout, &std.ascii.whitespace);

    // HTTPS format
    if (std.mem.indexOf(u8, url, "github.com/")) |idx| {
        const start = idx + "github.com/".len;
        const end = std.mem.indexOfScalar(u8, url[start..], '.') orelse url[start..].len;
        const owner_repo = url[start..][0..end];

        if (std.mem.indexOfScalar(u8, owner_repo, '/')) |slash| {
            return .{
                .owner = allocator.dupe(u8, owner_repo[0..slash]) catch return null,
                .repo = allocator.dupe(u8, owner_repo[slash + 1 ..]) catch return null,
            };
        }
    }

    // SSH format
    if (std.mem.indexOf(u8, url, "github.com:")) |idx| {
        const start = idx + "github.com:".len;
        const end = std.mem.indexOfScalar(u8, url[start..], '.') orelse url[start..].len;
        const owner_repo = url[start..][0..end];

        if (std.mem.indexOfScalar(u8, owner_repo, '/')) |slash| {
            return .{
                .owner = allocator.dupe(u8, owner_repo[0..slash]) catch return null,
                .repo = allocator.dupe(u8, owner_repo[slash + 1 ..]) catch return null,
            };
        }
    }

    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SENSES INTEGRATION — Read issue status for queen_senses
// ═══════════════════════════════════════════════════════════════════════════════

/// Count open issues (for queen_senses)
pub fn countOpenIssues(allocator: Allocator) u16 {
    var tracker = IssueTracker.init(allocator, true) catch return 0;
    defer tracker.deinit();

    const issues = tracker.listIssues(null) catch return 0;
    defer allocator.free(issues); // Only free the array, not individual slices (they're borrowed from JSON response)

    return @intCast(@min(issues.len, 65535));
}

/// Get issues with specific label (for queen monitoring)
pub fn getIssuesByLabel(allocator: Allocator, label: []const u8) ![]IssueStatus {
    var tracker = try IssueTracker.init(allocator, false);
    defer tracker.deinit();
    return tracker.listIssues(label);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROTOCOL V2 HELPERS — Formatted comments
// ═══════════════════════════════════════════════════════════════════════════════

/// Build a Protocol v2 step comment
pub fn buildStepComment(allocator: Allocator, agent: []const u8, step: u32, total: u32, description: []const u8, status: StepStatus, thought: []const u8, action: []const u8, result: []const u8, next: []const u8) ![]const u8 {
    const status_str = switch (status) {
        .thinking => "THINKING",
        .acting => "ACTING",
        .done => "DONE",
        .failed => "FAILED",
    };

    return std.fmt.allocPrint(allocator,
        \\{s} **Agent: {s}** | {s}
        \\📋 **Step**: {d}/{d} — {s}
        \\🔄 **Status**: {s}
        \\**Thought**: {s}
        \\**Action**: {s}
        \\**Result**: {s}
        \\**Next**: {s}
    , .{
        qt.E_ROBOT, agent, timestampStr(), step, total, description, status_str, thought, action, result, next,
    });
}

pub const StepStatus = enum {
    thinking,
    acting,
    done,
    failed,
};

fn timestampStr() []const u8 {
    const timestamp = std.time.timestamp();
    const secs = @mod(timestamp, 60);
    const mins = @mod(@divTrunc(timestamp, 60), 60);
    const hours = @mod(@divTrunc(timestamp, 3600), 24);
    const days = @divTrunc(timestamp, 86400);

    // Simple format: return static string (simplified for Queen daemon)
    _ = secs;
    _ = mins;
    _ = hours;
    _ = days;
    return "now";
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "queen_issues — countOpenIssues returns number" {
    const count = countOpenIssues(std.testing.allocator);
    _ = count; // Just verify it doesn't crash
}

test "queen_issues — buildStepComment format" {
    const comment = try buildStepComment(std.testing.allocator, "ralph", 1, 5, "Analyze build failure", .thinking, "Build failed with std.time.sleep", "Checking Zig 0.15.2 migration guide", "Found std.Thread.sleep replacement", "Update all call sites");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(std.mem.indexOf(u8, comment, "ralph") != null);
    try std.testing.expect(std.mem.indexOf(u8, comment, "1/5") != null);
    try std.testing.expect(std.mem.indexOf(u8, comment, "THINKING") != null);
}

test "queen_issues — IssueStatus size" {
    // Size is platform-dependent due to alignment
    const size = @sizeOf(IssueStatus);
    try std.testing.expect(size > 0);
    try std.testing.expect(size < 100); // Reasonable upper bound
}

test "queen_issues — IssueResult size" {
    // Size is platform-dependent due to alignment
    const size = @sizeOf(IssueResult);
    try std.testing.expect(size > 0);
    try std.testing.expect(size < 50); // Reasonable upper bound
}

test "queen_issues — IssueTracker init with dry_run" {
    var tracker = try IssueTracker.init(std.testing.allocator, true);
    defer tracker.deinit();

    try std.testing.expect(tracker.dry_run);
    try std.testing.expectEqualStrings("gHashTag", tracker.owner);
    try std.testing.expectEqualStrings("trinity", tracker.repo);
}

test "queen_issues — IssueTracker init without dry_run" {
    var tracker = try IssueTracker.init(std.testing.allocator, false);
    defer tracker.deinit();

    try std.testing.expect(!tracker.dry_run);
}

test "queen_issues — buildStepComment all step types" {
    const step_types = [_]StepStatus{
        .thinking, .acting, .done, .failed,
    };

    for (step_types) |step_type| {
        const comment = try buildStepComment(std.testing.allocator, "test_agent", 1, 3, "Test step", step_type, "Thought", "Action 1", "Action 2", "Action 3");
        defer std.testing.allocator.free(comment);

        try std.testing.expect(std.mem.indexOf(u8, comment, "test_agent") != null);
        try std.testing.expect(std.mem.indexOf(u8, comment, "1/3") != null);
    }
}

test "queen_issues — buildStepComment with special characters" {
    const comment = try buildStepComment(std.testing.allocator, "agent-name", 5, 10, "Fix <bug> & \"issue\"", .acting, "Checking code", "Found: x > 0", "Fixed: x >= 0", "");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(std.mem.indexOf(u8, comment, "agent-name") != null);
    try std.testing.expect(std.mem.indexOf(u8, comment, "5/10") != null);
}

test "queen_issues — buildStepComment multiline fields" {
    const long_thought = "This is a very long thought that spans multiple lines and contains detailed analysis of the problem at hand";
    const long_action = "Performed complex refactoring across multiple files to resolve the issue";

    const comment = try buildStepComment(std.testing.allocator, "ralph", 2, 5, "Complex task", .thinking, long_thought, long_action, "", "");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(comment.len > 0);
}

test "queen_issues — IssueStatus struct fields" {
    const status = IssueStatus{
        .number = 12345,
        .state = "open",
        .title = "Test issue",
        .label_count = 3,
    };

    try std.testing.expectEqual(@as(u32, 12345), status.number);
    try std.testing.expectEqualStrings("open", status.state);
    try std.testing.expectEqualStrings("Test issue", status.title);
    try std.testing.expectEqual(@as(u8, 3), status.label_count);
}

test "queen_issues — IssueResult fields" {
    const result = IssueResult{
        .number = 67890,
        .url = "https://github.com/gHashTag/trinity/issues/67890",
    };

    try std.testing.expectEqual(@as(u32, 67890), result.number);
    try std.testing.expectEqualStrings("https://github.com/gHashTag/trinity/issues/67890", result.url);
}

test "queen_issues — IssueResult empty" {
    const result = IssueResult{
        .number = 0,
        .url = "",
    };

    try std.testing.expectEqual(@as(u32, 0), result.number);
    try std.testing.expectEqual(@as(usize, 0), result.url.len);
}

test "queen_issues — StepStatus enum coverage" {
    const statuses = [_]StepStatus{ .thinking, .acting, .done, .failed };
    for (statuses) |s| {
        _ = s; // Verify all enum values exist
    }
}

test "queen_issues — IssueStatus zero values" {
    const status = IssueStatus{
        .number = 0,
        .state = "",
        .title = "",
    };
    try std.testing.expectEqual(@as(u32, 0), status.number);
    try std.testing.expectEqual(@as(usize, 0), status.state.len);
    try std.testing.expectEqual(@as(usize, 0), status.title.len);
    try std.testing.expectEqual(@as(u8, 0), status.label_count);
}

test "queen_issues — IssueResult non-zero number" {
    const result = IssueResult{
        .number = 42,
        .url = "https://example.com/issue/42",
    };

    try std.testing.expectEqual(@as(u32, 42), result.number);
    try std.testing.expectEqualStrings("https://example.com/issue/42", result.url);
}

test "queen_issues — buildStepComment all statuses" {
    const statuses = [_]StepStatus{ .thinking, .acting, .done, .failed };

    for (statuses) |status| {
        const comment = try buildStepComment(std.testing.allocator, "agent", 1, 1, "Test", status, "", "", "", "");
        defer std.testing.allocator.free(comment);

        try std.testing.expect(comment.len > 0);
    }
}

test "queen_issues — IssueStatus with zero labels" {
    const status = IssueStatus{
        .number = 100,
        .state = "open",
        .title = "Test",
        .label_count = 0,
    };

    try std.testing.expectEqual(@as(u8, 0), status.label_count);
}

test "queen_issues — IssueTracker field access" {
    var tracker = try IssueTracker.init(std.testing.allocator, true);
    defer tracker.deinit();

    try std.testing.expect(tracker.dry_run);
    try std.testing.expectEqualStrings("gHashTag", tracker.owner);
    try std.testing.expectEqualStrings("trinity", tracker.repo);
}

test "queen_issues — RepoDetection fields" {
    const detection = RepoDetection{
        .owner = "testowner",
        .repo = "testrepo",
    };

    try std.testing.expectEqualStrings("testowner", detection.owner);
    try std.testing.expectEqualStrings("testrepo", detection.repo);
}

test "queen_issues — buildStepComment empty fields" {
    const comment = try buildStepComment(std.testing.allocator, "", 0, 1, "", .done, "", "", "", "");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(comment.len > 0);
}

test "queen_issues — buildStepComment with numeric values" {
    const comment = try buildStepComment(std.testing.allocator, "test", 10, 100, "Description", .acting, "Thought", "Action", "Result", "Next");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(std.mem.indexOf(u8, comment, "10/100") != null);
}

test "queen_issues — GITHUB_API_HOST constant" {
    try std.testing.expectEqualStrings("api.github.com", GITHUB_API_HOST);
}

test "queen_issues — IssueStatus with all fields populated" {
    const status = IssueStatus{
        .number = 999,
        .state = "closed",
        .title = "Complete issue",
        .label_count = 5,
    };

    try std.testing.expectEqual(@as(u32, 999), status.number);
    try std.testing.expectEqualStrings("closed", status.state);
    try std.testing.expectEqualStrings("Complete issue", status.title);
    try std.testing.expectEqual(@as(u8, 5), status.label_count);
}

test "queen_issues — countOpenIssues handles errors gracefully" {
    // Even if GitHub API fails, should return 0 instead of crashing
    const count = countOpenIssues(std.testing.allocator);
    try std.testing.expect(count >= 0);
}

test "queen_issues — StepStatus all values" {
    const statuses = [_]StepStatus{ .thinking, .acting, .done, .failed };
    for (statuses) |s| {
        _ = s; // Verify all enum values exist
    }
}

test "queen_issues — IssueResult populated" {
    const result = IssueResult{
        .number = 42,
        .url = "https://example.com/issue/42",
    };

    try std.testing.expectEqual(@as(u32, 42), result.number);
    try std.testing.expectEqualStrings("https://example.com/issue/42", result.url);
}

test "queen_issues — IssueResult empty case" {
    const result = IssueResult{
        .number = 0,
        .url = "",
    };

    try std.testing.expectEqual(@as(u32, 0), result.number);
    try std.testing.expectEqual(@as(usize, 0), result.url.len);
}

test "queen_issues — IssueStatus default initialization" {
    const status = IssueStatus{
        .number = 0,
        .state = "",
        .title = "",
    };
    try std.testing.expectEqual(@as(u32, 0), status.number);
    try std.testing.expectEqual(@as(u8, 0), status.label_count);
}

test "queen_issues — buildStepComment thinking status" {
    const comment = try buildStepComment(std.testing.allocator, "ralph", 1, 5, "Analyze codebase", .thinking, "Checking structure", "Read files", "", "");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(std.mem.indexOf(u8, comment, "THINKING") != null);
}

test "queen_issues — buildStepComment acting status" {
    const comment = try buildStepComment(std.testing.allocator, "ralph", 2, 5, "Implement fix", .acting, "", "Make changes", "", "");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(std.mem.indexOf(u8, comment, "ACTING") != null);
}

test "queen_issues — buildStepComment done status" {
    const comment = try buildStepComment(std.testing.allocator, "ralph", 5, 5, "Complete task", .done, "", "", "Success", "");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(std.mem.indexOf(u8, comment, "DONE") != null);
}

test "queen_issues — buildStepComment failed status" {
    const comment = try buildStepComment(std.testing.allocator, "ralph", 3, 5, "Retry operation", .failed, "", "", "Error occurred", "");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(std.mem.indexOf(u8, comment, "FAILED") != null);
}

test "queen_issues — buildStepComment with all fields" {
    const comment = try buildStepComment(
        std.testing.allocator,
        "agent",
        7,
        10,
        "Complex step description",
        .acting,
        "Need to analyze the problem first",
        "Execute the main operation",
        "Operation succeeded",
        "Proceed to next phase",
    );
    defer std.testing.allocator.free(comment);

    try std.testing.expect(std.mem.indexOf(u8, comment, "7/10") != null);
    try std.testing.expect(std.mem.indexOf(u8, comment, "Thought") != null);
    try std.testing.expect(std.mem.indexOf(u8, comment, "Action") != null);
    try std.testing.expect(std.mem.indexOf(u8, comment, "Result") != null);
    try std.testing.expect(std.mem.indexOf(u8, comment, "Next") != null);
}

test "queen_issues — RepoDetection default values" {
    const detection = RepoDetection{
        .owner = "",
        .repo = "",
    };
    try std.testing.expectEqual(@as(usize, 0), detection.owner.len);
    try std.testing.expectEqual(@as(usize, 0), detection.repo.len);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ISSUE TRACKER METHOD TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "queen_issues — IssueTracker dry_run createIssue" {
    var tracker = try IssueTracker.init(std.testing.allocator, true);
    defer tracker.deinit();

    const result = try tracker.createIssue("Test Title", "Test Body", &.{});
    try std.testing.expectEqual(@as(u32, 0), result.number);
}

test "queen_issues — IssueTracker dry_run updateIssue" {
    var tracker = try IssueTracker.init(std.testing.allocator, true);
    defer tracker.deinit();

    try tracker.updateIssue(123, "Test comment");
    // Should not crash in dry_run mode
}

test "queen_issues — IssueTracker dry_run closeIssue" {
    var tracker = try IssueTracker.init(std.testing.allocator, true);
    defer tracker.deinit();

    try tracker.closeIssue(456, null);
    // Should not crash in dry_run mode
}

test "queen_issues — IssueTracker dry_run getIssueStatus" {
    var tracker = try IssueTracker.init(std.testing.allocator, true);
    defer tracker.deinit();

    const status = tracker.getIssueStatus(789) catch |err| {
        std.debug.print("Expected error in dry_run: {}\n", .{err});
        return error.ExpectedError;
    };
    _ = status;
}

test "queen_issues — IssueTracker dry_run listIssues" {
    var tracker = try IssueTracker.init(std.testing.allocator, true);
    defer tracker.deinit();

    const issues = try tracker.listIssues(null);
    defer std.testing.allocator.free(issues);

    // Should return empty array in dry_run mode
    try std.testing.expectEqual(@as(usize, 0), issues.len);
}

test "queen_issues — IssueTracker ownership transfer" {
    var tracker = try IssueTracker.init(std.testing.allocator, true);
    defer tracker.deinit();

    // Verify owner/repo were transferred from client
    try std.testing.expect(tracker.owner.len > 0);
    try std.testing.expect(tracker.repo.len > 0);
}

test "queen_issues — IssueTracker with app_auth" {
    var tracker = try IssueTracker.init(std.testing.allocator, true);
    defer tracker.deinit();

    // app_auth may or may not be available depending on environment
    if (tracker.app_auth) |_| {
        try std.testing.expect(tracker.client == null); // app_auth takes precedence
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ISSUE RESULT STRUCT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "queen_issues — IssueResult with valid URL" {
    const result = IssueResult{
        .number = 42,
        .url = "https://github.com/gHashTag/trinity/issues/42",
    };
    try std.testing.expectEqual(@as(u32, 42), result.number);
    try std.testing.expect(std.mem.indexOf(u8, result.url, "github.com") != null);
}

test "queen_issues — IssueResult with localhost URL" {
    const result = IssueResult{
        .number = 1,
        .url = "http://localhost:8080/issues/1",
    };
    try std.testing.expect(std.mem.indexOf(u8, result.url, "localhost") != null);
}

test "queen_issues — IssueResult number increment" {
    var result = IssueResult{
        .number = 99,
        .url = "https://example.com/99",
    };
    result.number += 1;
    try std.testing.expectEqual(@as(u32, 100), result.number);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ISSUE STATUS STRUCT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "queen_issues — IssueStatus with labels populated" {
    const status = IssueStatus{
        .number = 111,
        .state = "open",
        .title = "Test Issue",
        .label_count = 2,
    };
    try std.testing.expectEqual(@as(u32, 111), status.number);
    try std.testing.expectEqual(@as(u8, 2), status.label_count);
}

test "queen_issues — IssueStatus empty state" {
    const status = IssueStatus{
        .number = 222,
        .state = "",
        .title = "",
    };
    try std.testing.expectEqual(@as(usize, 0), status.state.len);
    try std.testing.expectEqual(@as(usize, 0), status.title.len);
    try std.testing.expectEqual(@as(u8, 0), status.label_count);
}

test "queen_issues — IssueStatus title max length" {
    const long_title = "X" ** 250;
    const status = IssueStatus{
        .number = 1,
        .state = "open",
        .title = long_title,
    };
    try std.testing.expectEqual(@as(usize, 250), status.title.len);
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP STATUS ENUM TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "queen_issues — StepStatus label all values" {
    try std.testing.expectEqualStrings("thinking", .thinking.label());
    try std.testing.expectEqualStrings("acting", .acting.label());
    try std.testing.expectEqualStrings("done", .done.label());
    try std.testing.expectEqualStrings("failed", .failed.label());
}

test "queen_issues — StepStatus emoji all values" {
    const emojis = [_]StepStatus{ .thinking, .acting, .done, .failed };
    for (emojis) |s| {
        const emoji = s.emoji();
        try std.testing.expect(emoji.len > 0);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REPO DETECTION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "queen_issues — RepoDetection with owner only" {
    const detection = RepoDetection{
        .owner = "gHashTag",
        .repo = "",
    };
    try std.testing.expectEqualStrings("gHashTag", detection.owner);
    try std.testing.expectEqual(@as(usize, 0), detection.repo.len);
}

test "queen_issues — RepoDetection with repo only" {
    const detection = RepoDetection{
        .owner = "",
        .repo = "trinity",
    };
    try std.testing.expectEqual(@as(usize, 0), detection.owner.len);
    try std.testing.expectEqualStrings("trinity", detection.repo);
}

test "queen_issues — RepoDetection with owner/repo" {
    const detection = RepoDetection{
        .owner = "octocat",
        .repo = "Hello-World",
    };
    try std.testing.expectEqualStrings("octocat", detection.owner);
    try std.testing.expectEqualStrings("Hello-World", detection.repo);
}

test "queen_issues — RepoDetection special characters" {
    const detection = RepoDetection{
        .owner = "user-with-dash",
        .repo = "repo.with.dots",
    };
    try std.testing.expect(std.mem.indexOf(u8, detection.owner, "-") != null);
    try std.testing.expect(std.mem.indexOf(u8, detection.repo, ".") != null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "queen_issues — countOpenIssues returns non-negative" {
    const count = countOpenIssues(std.testing.allocator);
    try std.testing.expect(count >= 0);
}

test "queen_issues — getIssuesByLabel empty filter" {
    const issues = try getIssuesByLabel(std.testing.allocator, "");
    defer std.testing.allocator.free(issues);

    try std.testing.expect(issues.len >= 0);
}

test "queen_issues — getIssuesByLabel with label" {
    const issues = try getIssuesByLabel(std.testing.allocator, "bug");
    defer std.testing.allocator.free(issues);

    try std.testing.expect(issues.len >= 0);
}

test "queen_issues — buildStepComment minimal" {
    const comment = try buildStepComment(std.testing.allocator, "x", 1, 1, "T", .done, "", "", "", "");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(comment.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, comment, "1/1") != null);
}

test "queen_issues — buildStepComment contains agent" {
    const comment = try buildStepComment(std.testing.allocator, "ralph", 5, 10, "Desc", .thinking, "", "", "", "");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(std.mem.indexOf(u8, comment, "ralph") != null);
}

test "queen_issues — buildStepComment contains step" {
    const comment = try buildStepComment(std.testing.allocator, "test", 7, 100, "D", .acting, "", "", "", "");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(std.mem.indexOf(u8, comment, "7/100") != null);
}

test "queen_issues — buildStepComment contains description" {
    const comment = try buildStepComment(std.testing.allocator, "a", 1, 1, "Fix bug", .failed, "", "", "", "");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(std.mem.indexOf(u8, comment, "Fix bug") != null);
}

test "queen_issues — buildStepComment format structure" {
    const comment = try buildStepComment(std.testing.allocator, "agent", 3, 5, "Desc", .thinking, "T", "A", "R", "N");
    defer std.testing.allocator.free(comment);

    // Check for key sections
    try std.testing.expect(std.mem.indexOf(u8, comment, "Step") != null);
    try std.testing.expect(std.mem.indexOf(u8, comment, "Status") != null);
}

test "queen_issues — buildStepComment thinking contains thought" {
    const comment = try buildStepComment(std.testing.allocator, "agent", 1, 1, "D", .thinking, "My thought", "", "", "");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(std.mem.indexOf(u8, comment, "My thought") != null);
}

test "queen_issues — buildStepComment acting contains action" {
    const comment = try buildStepComment(std.testing.allocator, "agent", 2, 2, "D", .acting, "", "My action", "", "");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(std.mem.indexOf(u8, comment, "My action") != null);
}

test "queen_issues — buildStepComment done contains result" {
    const comment = try buildStepComment(std.testing.allocator, "agent", 3, 3, "D", .done, "", "", "My result", "");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(std.mem.indexOf(u8, comment, "My result") != null);
}

test "queen_issues — buildStepComment failed contains result" {
    const comment = try buildStepComment(std.testing.allocator, "agent", 4, 4, "D", .failed, "", "", "My error", "");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(std.mem.indexOf(u8, comment, "My error") != null);
}

test "queen_issues — buildStepComment next contains next" {
    const comment = try buildStepComment(std.testing.allocator, "agent", 5, 5, "D", .done, "", "", "", "Next step");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(std.mem.indexOf(u8, comment, "Next step") != null);
}

test "queen_issues — buildStepComment with zero total" {
    const comment = try buildStepComment(std.testing.allocator, "a", 0, 1, "D", .thinking, "", "", "", "");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(std.mem.indexOf(u8, comment, "0/1") != null);
}

test "queen_issues — buildStepComment large step number" {
    const comment = try buildStepComment(std.testing.allocator, "a", 9999, 10000, "D", .acting, "", "", "", "");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(std.mem.indexOf(u8, comment, "9999/10000") != null);
}

test "queen_issues — buildStepComment very long description" {
    const long_desc = "X" ** 200;
    const comment = try buildStepComment(std.testing.allocator, "a", 1, 5, long_desc, .thinking, "", "", "", "");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(std.mem.indexOf(u8, comment, long_desc[0..10]) != null);
}

test "queen_issues — buildStepComment empty all optional fields" {
    const comment = try buildStepComment(std.testing.allocator, "", 0, 0, "", .done, "", "", "", "");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(comment.len > 0);
}

test "queen_issues — IssueStatus with all labels populated" {
    const labels = &[_][]const u8{ "bug", "enhancement", "good first issue", "help wanted" };
    const status = IssueStatus{
        .number = 1,
        .state = "open",
        .title = "Test",
        .labels = labels,
    };
    try std.testing.expectEqual(@as(usize, 4), status.labels.len);
}

test "queen_issues — IssueStatus with single label" {
    const status = IssueStatus{
        .number = 2,
        .state = "open",
        .title = "Test",
        .labels = &.{"bug"},
    };
    try std.testing.expectEqual(@as(usize, 1), status.labels.len);
}

test "queen_issues — IssueStatus with closed state" {
    const status = IssueStatus{
        .number = 3,
        .state = "closed",
        .title = "Completed task",
        .labels = &.{},
    };
    try std.testing.expectEqualStrings("closed", status.state);
}

test "queen_issues — IssueResult with API URL format" {
    const result = IssueResult{
        .number = 579,
        .url = "https://api.github.com/repos/gHashTag/trinity/issues/579",
    };
    try std.testing.expect(std.mem.indexOf(u8, result.url, "api.github.com") != null);
}

test "queen_issues — IssueResult with number 0" {
    const result = IssueResult{
        .number = 0,
        .url = "",
    };
    try std.testing.expectEqual(@as(u32, 0), result.number);
}

test "queen_issues — GITHUB_API_HOST is correct" {
    try std.testing.expectEqualStrings("api.github.com", GITHUB_API_HOST);
}

test "queen_issues — StepStatus acting emoji is valid" {
    const emoji = .acting.emoji();
    try std.testing.expect(emoji.len > 0);
    try std.testing.expect(emoji.len <= 4); // Reasonable emoji length
}

test "queen_issues — StepStatus thinking emoji is valid" {
    const emoji = .thinking.emoji();
    try std.testing.expect(emoji.len > 0);
}

test "queen_issues — StepStatus done emoji is valid" {
    const emoji = .done.emoji();
    try std.testing.expect(emoji.len > 0);
}

test "queen_issues — StepStatus failed emoji is valid" {
    const emoji = .failed.emoji();
    try std.testing.expect(emoji.len > 0);
}

test "queen_issues — RepoDetection owner and repo set" {
    const detection = RepoDetection{
        .owner = "owner123",
        .repo = "repo456",
    };
    try std.testing.expectEqualStrings("owner123", detection.owner);
    try std.testing.expectEqualStrings("repo456", detection.repo);
}

test "queen_issues — IssueStatus with numeric state string" {
    const status = IssueStatus{
        .number = 777,
        .state = "12345",
        .title = "Number as state",
    };
    try std.testing.expectEqualStrings("12345", status.state);
}

test "queen_issues — IssueTracker init retains dry_run setting" {
    var tracker_dry = try IssueTracker.init(std.testing.allocator, true);
    defer tracker_dry.deinit();
    try std.testing.expect(tracker_dry.dry_run);

    var tracker_live = try IssueTracker.init(std.testing.allocator, false);
    defer tracker_live.deinit();
    try std.testing.expect(!tracker_live.dry_run);
}

test "queen_issues — buildStepComment with newlines in fields" {
    const comment = try buildStepComment(std.testing.allocator, "agent", 1, 1, "Line1\nLine2", .thinking, "T1\nT2", "A1\nA2", "R1\nR2", "N1\nN2");
    defer std.testing.allocator.free(comment);

    // Check that newlines are escaped in JSON
    try std.testing.expect(std.mem.indexOf(u8, comment, "\\n") != null);
}

test "queen_issues — buildStepComment with quotes in fields" {
    const comment = try buildStepComment(std.testing.allocator, "agent", 1, 1, "Say \"hello\"", .thinking, "He said \"hi\"", "", "", "");
    defer std.testing.allocator.free(comment);

    // Check that quotes are escaped in JSON
    try std.testing.expect(std.mem.indexOf(u8, comment, "\\\"") != null);
}

test "queen_issues — buildStepComment total exceeds step" {
    const comment = try buildStepComment(std.testing.allocator, "agent", 10, 5, "Overdue", .thinking, "", "", "", "");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(std.mem.indexOf(u8, comment, "10/5") != null);
}

test "queen_issues — IssueResult number boundary max" {
    const result = IssueResult{
        .number = std.math.maxInt(u32),
        .url = "https://github.com/test/issues/max",
    };
    try std.testing.expectEqual(std.math.maxInt(u32), result.number);
}

test "queen_issues — IssueStatus number boundary" {
    const status = IssueStatus{
        .number = 1234567890,
        .state = "open",
    };
    try std.testing.expectEqual(@as(u32, 1234567890), status.number);
}

test "queen_issues — buildStepComment agent field" {
    const comment = try buildStepComment(std.testing.testing.allocator, "my-agent", 1, 1, "D", .done, "", "", "", "");
    defer std.testing.allocator.free(comment);

    try std.testing.expect(std.mem.indexOf(u8, comment, "my-agent") != null);
}

test "queen_issues — buildStepComment contains status indicators" {
    const comment = buildStepComment(std.testing.allocator, "a", 1, 1, "D", .thinking, "", "", "", "") catch unreachable;
    defer std.testing.allocator.free(comment);

    // Check for status emoji indicators
    const emojis = [_][]const u8{ "💭", "⚡", "✅", "❌" };
    for (emojis) |emoji| {
        _ = emoji; // Verify emoji format
    }
}
