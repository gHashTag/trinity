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

        // Fallback to regular client
        client = try github_client.GitHubClient.init(allocator, dry_run);

        // Detect owner/repo from git remote
        var owner: []const u8 = "gHashTag";
        var repo: []const u8 = "trinity";

        if (detectRepo(allocator)) |detected| {
            owner = detected.owner;
            repo = detected.repo;
        }

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
        // client is a value type, no deinit needed
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

        _ = try std.fmt.bufPrint(body_buf[0..], "{\"body\":\"", .{});
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

        @memcpy(body_buf[body_len..][0..3], "\"}");
        body_len += 3;

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
        var issues = std.ArrayList(IssueStatus).init(self.allocator, 0);

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

            try issues.append(.{
                .number = number,
                .state = state,
                .title = title,
                .label_count = label_count,
            });

            pos = issue_start + 20;
        }

        return issues.toOwnedSlice();
    }

    /// List issues using gh CLI fallback
    fn listIssuesGh(self: *Self, label_filter: ?[]const u8) ![]IssueStatus {
        var argv = std.ArrayList([]const u8).init(self.allocator, 0);
        defer argv.deinit();

        try argv.appendSlice(self.allocator, &.{ "gh", "issue", "list", "--state", "open", "--json", "number,state,title,labels", "--limit", "100" });

        if (label_filter) |filter| {
            const search = try std.fmt.allocPrint(self.allocator, "label:\"{s}\"", .{filter});
            defer self.allocator.free(search);
            try argv.append("--search");
            try argv.append(search);
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

        var issues = std.ArrayList(IssueStatus).init(self.allocator);

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

            try issues.append(.{
                .number = number,
                .state = state,
                .title = title,
                .label_count = label_count,
            });

            pos = issue_start + 20;
        }

        return issues.toOwnedSlice();
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
    defer {
        for (issues) |i| {
            allocator.free(i.title);
        }
        allocator.free(issues);
    }

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
    try std.testing.expectEqual(@as(usize, 2 + 8 + 8 + 1), @sizeOf(IssueStatus));
}

test "queen_issues — IssueResult size" {
    try std.testing.expectEqual(@as(usize, 4 + 8), @sizeOf(IssueResult));
}
