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

        // Try GITHUB_TOKEN then GH_TOKEN
        const token = std.process.getEnvVarOwned(allocator, "GITHUB_TOKEN") catch
            std.process.getEnvVarOwned(allocator, "GH_TOKEN") catch
            null;

        const owner_repo = try detectOwnerRepo(allocator);

        const mode: Mode = if (token != null) .native_http else .gh_cli;

        return Self{
            .allocator = allocator,
            .token = token,
            .owner = owner_repo.owner,
            .repo = owner_repo.repo,
            .mode = mode,
        };
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

    /// Get issue info
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
                return parseIssueInfo(response);
            },
            .gh_cli => {
                const num_str = try std.fmt.allocPrint(self.allocator, "{d}", .{number});
                defer self.allocator.free(num_str);
                const result = try self.ghCliRun(&.{ "gh", "issue", "view", num_str, "--json", "number,title,state,body,labels" });
                defer self.allocator.free(result);
                return parseIssueInfo(result);
            },
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Internal: HTTP transport
    // ═══════════════════════════════════════════════════════════════════════════

    fn httpRequest(self: *Self, method_str: []const u8, path: []const u8, body: ?[]const u8) ![]const u8 {
        const method: std.http.Method = if (std.mem.eql(u8, method_str, "GET"))
            .GET
        else if (std.mem.eql(u8, method_str, "POST"))
            .POST
        else if (std.mem.eql(u8, method_str, "PATCH"))
            .PATCH
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
            .{ .name = "Accept", .value = "application/vnd.github+json" },
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
        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = argv,
            .max_output_bytes = 1024 * 1024,
        });
        defer self.allocator.free(result.stderr);

        if (result.term.Exited != 0) {
            std.debug.print("\x1b[38;2;255;85;85mgh CLI failed (exit {d})\x1b[0m\n", .{result.term.Exited});
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

    if (result.term.Exited != 0) return error.GitRemoteFailed;

    const url = std.mem.trimRight(u8, result.stdout, "\n\r ");
    return parseGitRemoteUrl(url);
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

fn buildCreateIssueJson(buf: []u8, title: []const u8, body: ?[]const u8, labels: []const []const u8) ![]const u8 {
    var escape_title_buf: [1024]u8 = undefined;
    const escaped_title = escapeJson(title, &escape_title_buf);

    var pos: usize = 0;

    // Start JSON
    const start = "{\"title\":\"";
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
        @memcpy(buf[pos .. pos + labels_prefix.len], labels_prefix);
        pos += labels_prefix.len;
        for (labels, 0..) |label, i| {
            if (i > 0) {
                buf[pos] = ',';
                pos += 1;
            }
            buf[pos] = '"';
            pos += 1;
            var escape_label_buf: [256]u8 = undefined;
            const escaped_label = escapeJson(label, &escape_label_buf);
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
fn extractJsonString(json: []const u8, key: []const u8) ?[]const u8 {
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
