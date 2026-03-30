//! Agent Gamma — Git operations, version control, GitHub issue orchestration
//!
//! Gamma (Ⲅⲅ) handles all GitHub-related operations for the Trinity grid.
//! Manages issues, comments, PRs, and repository state.
//!
//! φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

// ============================================================================
// DATA STRUCTURES
// ============================================================================

pub const IssueState = enum {
    open,
    in_progress,
    closed,
};

pub const Label = struct {
    name: []const u8,
    color: []const u8,
};

pub const GitHubIssue = struct {
    id: u64,
    title: []const u8,
    body: []const u8,
    state: IssueState,
    assignee: ?[]const u8,
    labels: [][]const u8,
    created_at: i64,
    updated_at: i64,
    html_url: []const u8,
};

pub const Comment = struct {
    id: u64,
    body: []const u8,
    created_at: i64,
    user: []const u8,
};

pub const PullRequest = struct {
    id: u64,
    number: u64,
    title: []const u8,
    state: IssueState,
    head: []const u8,
    base: []const u8,
    html_url: []const u8,
};

pub const GitHubError = error{
    AuthFailed,
    RateLimit,
    InvalidResponse,
    NetworkError,
    IssueNotFound,
};

pub const GammaAgent = struct {
    allocator: std.mem.Allocator,
    github_token: []const u8,
    repo_owner: []const u8,
    repo_name: []const u8,
    api_base: []const u8,
    user_agent: []const u8,

    /// Initialize Gamma agent with GitHub token
    pub fn init(
        allocator: std.mem.Allocator,
        github_token: []const u8,
        repo_owner: ?[]const u8,
        repo_name: ?[]const u8,
    ) GammaAgent {
        return GammaAgent{
            .allocator = allocator,
            .github_token = github_token,
            .repo_owner = repo_owner orelse "gHashTag",
            .repo_name = repo_name orelse "trinity",
            .api_base = "https://api.github.com",
            .user_agent = "Trinity-Gamma/1.0.0",
        };
    }

    /// Create GitHub issue
    pub fn createIssue(
        self: *const GammaAgent,
        title: []const u8,
        body: []const u8,
        labels: ?[][]const u8,
    ) !GitHubIssue {
        const endpoint = try std.fmt.allocPrint(
            self.allocator,
            "{s}/repos/{s}/{s}/issues",
            .{ self.api_base, self.repo_owner, self.repo_name },
        );

        const request_body = try std.fmt.allocPrint(self.allocator,
            \{{"title":"{s}","body":"{s}","labels":[{s}]}}
        , .{
            std.zig.fmtEscapes(title),
            std.zig.fmtEscapes(body),
            if (labels) |lbls| blk: {
                try std.json.stringifyAlloc(self.allocator, lbls, .{});
            } else "[]",
        });

        const response = try self.githubRequest("POST", endpoint, request_body);

        return try self.parseIssueResponse(response);
    }

    /// Comment on issue
    pub fn commentIssue(
        self: *const GammaAgent,
        issue_id: u64,
        comment: []const u8,
    ) !void {
        const endpoint = try std.fmt.allocPrint(
            self.allocator,
            "{s}/repos/{s}/{s}/issues/{d}/comments",
            .{ self.api_base, self.repo_owner, self.repo_name, issue_id },
        );

        const request_body = try std.fmt.allocPrint(self.allocator,
            \{{"body":"{s}"}}
        , .{ std.zig.fmtEscapes(comment) });

        _ = try self.githubRequest("POST", endpoint, request_body);
    }

    /// Get issue by ID
    pub fn getIssue(self: *const GammaAgent, issue_id: u64) !GitHubIssue {
        const endpoint = try std.fmt.allocPrint(
            self.allocator,
            "{s}/repos/{s}/{s}/issues/{d}",
            .{ self.api_base, self.repo_owner, self.repo_name, issue_id },
        );

        const response = try self.githubRequest("GET", endpoint, null);
        return try self.parseIssueResponse(response);
    }

    /// Update issue state
    pub fn updateIssue(
        self: *const GammaAgent,
        issue_id: u64,
        state: IssueState,
    ) !void {
        const endpoint = try std.fmt.allocPrint(
            self.allocator,
            "{s}/repos/{s}/{s}/issues/{d}",
            .{ self.api_base, self.repo_owner, self.repo_name, issue_id },
        );

        const state_str = switch (state) {
            .open => "open",
            .in_progress => "in_progress",
            .closed => "closed",
        };

        const request_body = try std.fmt.allocPrint(self.allocator,
            \{{"state":"{s}"}}
        , .{ state_str });

        _ = try self.githubRequest("PATCH", endpoint, request_body);
    }

    /// Add label to issue
    pub fn addLabel(self: *const GammaAgent, issue_id: u64, label: []const u8) !void {
        const endpoint = try std.fmt.allocPrint(
            self.allocator,
            "{s}/repos/{s}/{s}/issues/{d}/labels",
            .{ self.api_base, self.repo_owner, self.repo_name, issue_id },
        );

        const request_body = try std.fmt.allocPrint(self.allocator,
            \{{"name":"{s}"}}
        , .{ std.zig.fmtEscapes(label) });

        _ = try self.githubRequest("POST", endpoint, request_body);
    }

    /// Create pull request
    pub fn createPullRequest(
        self: *const GammaAgent,
        title: []const u8,
        head: []const u8,
        base: []const u8,
        body: []const u8,
    ) !PullRequest {
        const endpoint = try std.fmt.allocPrint(
            self.allocator,
            "{s}/repos/{s}/{s}/pulls",
            .{ self.api_base, self.repo_owner, self.repo_name },
        );

        const request_body = try std.fmt.allocPrint(self.allocator,
            \{{"title":"{s}","head":"{s}","base":"{s}","body":"{s}"}}
        , .{
            std.zig.fmtEscapes(title),
            std.zig.fmtEscapes(head),
            std.zig.fmtEscapes(base),
            std.zig.fmtEscapes(body),
        });

        const response = try self.githubRequest("POST", endpoint, request_body);
        return try self.parsePullRequestResponse(response);
    }

    /// Get list of issues
    pub fn listIssues(
        self: *const GammaAgent,
        state: ?IssueState,
        limit: usize,
    ) ![]GitHubIssue {
        var endpoint = try std.fmt.allocPrint(
            self.allocator,
            "{s}/repos/{s}/{s}/issues?state={s}&per_page={d}",
            .{
                self.api_base,
                self.repo_owner,
                self.repo_name,
                if (state) |s| @tagName(s) else "all",
                limit,
            },
        );

        const response = try self.githubRequest("GET", endpoint, null);
        return try self.parseIssuesResponse(response);
    }

    /// Get list of open pull requests
    pub fn listPullRequests(self: *const GammaAgent, state: ?IssueState) ![]PullRequest {
        var endpoint = try std.fmt.allocPrint(
            self.allocator,
            "{s}/repos/{s}/{s}/pulls?state={s}",
            .{
                self.api_base,
                self.repo_owner,
                self.repo_name,
                if (state) |s| @tagName(s) else "all",
            },
        );

        const response = try self.githubRequest("GET", endpoint, null);
        return try self.parsePullRequestsResponse(response);
    }

    // ============================================================================
    // INTERNAL: HTTP REQUEST HANDLING
    // ============================================================================

    fn githubRequest(
        self: *const GammaAgent,
        method: []const u8,
        endpoint: []const u8,
        body: ?[]const u8,
    ) ![]const u8 {
        // Parse URL to get host
        var url_iter = std.mem.splitScalar(u8, endpoint, '/');
        const protocol = url_iter.next() orelse return error.InvalidResponse;
        _ = url_iter.next() orelse return error.InvalidResponse; // empty
        const host = url_iter.next() orelse return error.InvalidResponse;
        const path_with_query = url_iter.rest();

        // Parse host:port
        var host_parts = std.mem.splitScalar(u8, host, ':');
        const host_only = host_parts.next() orelse return error.InvalidResponse;
        const port_str = host_parts.next() orelse "443";
        const port = try std.fmt.parseInt(u16, port_str, 10);

        // Connect to GitHub API
        const address = try std.net.Address.parseIp(host_only, port);
        var stream = try address.connect(.{});
        defer stream.close();

        // Construct HTTP request
        var headers = std.ArrayList([]const u8).init(self.allocator);
        defer headers.deinit();

        try headers.append("Accept: application/vnd.github.v3+json");
        try headers.append(std.fmt.allocPrint(self.allocator,
            "Authorization: Bearer {s}",
            .{ self.github_token },
        ));
        try headers.append("User-Agent: Trinity-Gamma/1.0.0");
        try headers.append("Content-Type: application/json");
        try headers.append("Host: api.github.com");

        const request_line = try std.fmt.allocPrint(self.allocator,
            "{s} {s} HTTP/1.1\r\n",
            .{ method, path_with_query },
        );

        const body_line = if (body) |b|
            try std.fmt.allocPrint(self.allocator,
                "Content-Length: {d}\r\n\r\n{s}",
                .{ b.len, b })
        else
            "\r\n";

        // Send request
        _ = try stream.writeAll(request_line);
        for (headers.items) |header| {
            _ = try stream.writeAll(header);
            _ = try stream.writeAll("\r\n");
        }
        _ = try stream.writeAll(body_line);

        // Read response
        var response_buffer = std.ArrayList(u8).init(self.allocator);
        var read_buf: [1024]u8 = undefined;
        while (true) {
            const bytes_read = stream.read(&read_buf) catch |err| {
                std.debug.print("Read error: {}\n", .{err});
                return error.NetworkError;
            };

            if (bytes_read == 0) break;
            try response_buffer.appendSlice(read_buf[0..bytes_read]);
        }

        return response_buffer.toOwnedSlice();
    }

    // ============================================================================
    // INTERNAL: JSON PARSING
    // ============================================================================

    fn parseIssueResponse(response: []const u8) !GitHubIssue {
        const json_value = try std.json.parseFromSlice(std.heap.page_allocator, response);
        defer json_value.deinit();

        if (json_value != .object) return error.InvalidResponse;

        const obj = json_value.object;
        return GitHubIssue{
            .id = try obj.get("id").?.value.integer,
            .title = try obj.get("title").?.value.string,
            .body = try obj.get("body").?.value.string,
            .state = try parseIssueState(try obj.get("state").?.value.string),
            .assignee = if (obj.get("assignee")) |a|
                if (a.* == .null) null else try a.*.object.get("login").?.value.string
            else
                null,
            .labels = try parseLabels(try obj.get("labels").?.value.array),
            .created_at = try obj.get("created_at").?.value.string,
            .updated_at = try obj.get("updated_at").?.value.string,
            .html_url = try obj.get("html_url").?.value.string,
        };
    }

    fn parseIssuesResponse(response: []const u8) ![]GitHubIssue {
        const json_value = try std.json.parseFromSlice(std.heap.page_allocator, response);
        defer json_value.deinit();

        if (json_value != .array) return error.InvalidResponse;

        const arr = json_value.array;
        var issues = try std.ArrayList(GitHubIssue).initCapacity(self.allocator, arr.items.len);

        for (arr.items) |item| {
            if (item == .object) {
                const obj = item.object;
                const issue = GitHubIssue{
                    .id = try obj.get("id").?.value.integer,
                    .title = try obj.get("title").?.value.string,
                    .body = try obj.get("body").?.value.string,
                    .state = try parseIssueState(try obj.get("state").?.value.string),
                    .assignee = if (obj.get("assignee")) |a|
                        if (a.* == .null) null else try a.*.object.get("login").?.value.string
                    else
                        null,
                    .labels = try parseLabels(try obj.get("labels").?.value.array),
                    .created_at = try obj.get("created_at").?.value.string,
                    .updated_at = try obj.get("updated_at").?.value.string,
                    .html_url = try obj.get("html_url").?.value.string,
                };
                try issues.append(issue);
            }
        }

        return issues.toOwnedSlice();
    }

    fn parsePullRequestResponse(response: []const u8) !PullRequest {
        const json_value = try std.json.parseFromSlice(std.heap.page_allocator, response);
        defer json_value.deinit();

        if (json_value != .object) return error.InvalidResponse;

        const obj = json_value.object;
        return PullRequest{
            .id = try obj.get("id").?.value.integer,
            .number = try obj.get("number").?.value.integer,
            .title = try obj.get("title").?.value.string,
            .state = try parseIssueState(try obj.get("state").?.value.string),
            .head = try obj.get("head").?.value.object.get("ref").?.value.string,
            .base = try obj.get("base").?.value.object.get("ref").?.value.string,
            .html_url = try obj.get("html_url").?.value.string,
        };
    }

    fn parsePullRequestsResponse(response: []const u8) ![]PullRequest {
        const json_value = try std.json.parseFromSlice(std.heap.page_allocator, response);
        defer json_value.deinit();

        if (json_value != .array) return error.InvalidResponse;

        const arr = json_value.array;
        var prs = try std.ArrayList(PullRequest).initCapacity(self.allocator, arr.items.len);

        for (arr.items) |item| {
            if (item == .object) {
                const obj = item.object;
                const pr = PullRequest{
                    .id = try obj.get("id").?.value.integer,
                    .number = try obj.get("number").?.value.integer,
                    .title = try obj.get("title").?.value.string,
                    .state = try parseIssueState(try obj.get("state").?.value.string),
                    .head = try obj.get("head").?.value.object.get("ref").?.value.string,
                    .base = try obj.get("base").?.value.object.get("ref").?.value.string,
                    .html_url = try obj.get("html_url").?.value.string,
                };
                try prs.append(pr);
            }
        }

        return prs.toOwnedSlice();
    }

    fn parseLabels(labels: std.json.Array) ![][]const u8 {
        var result = try std.ArrayList([]const u8).initCapacity(std.heap.page_allocator, labels.items.len);

        for (labels.items) |item| {
            if (item == .object) {
                const obj = item.object;
                const label = try obj.get("name").?.value.string;
                try result.append(label);
            }
        }

        return result.toOwnedSlice();
    }

    fn parseIssueState(state: []const u8) !IssueState {
        if (std.mem.eql(u8, state, "open")) return .open;
        if (std.mem.eql(u8, state, "in_progress") or std.mem.eql(u8, state, "in progress"))
            return .in_progress;
        if (std.mem.eql(u8, state, "closed")) return .closed;
        return error.InvalidResponse;
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "Gamma Agent — parse issue response" {
    const allocator = std.testing.allocator;
    const response =
        \\{
        \\  "id": 123,
        \\  "title": "Test Issue",
        \\  "body": "Test body",
        \\  "state": "open",
        \\  "assignee": null,
        \\  "labels": [],
        \\  "created_at": "2024-01-01T00:00:00Z",
        \\  "updated_at": "2024-01-01T00:00:00Z",
        \\  "html_url": "https://github.com/test/repo/issues/123"
        \\}
    ;

    const issue = try parseIssueResponse(response);
    try std.testing.expectEqual(@as(u64, 123), issue.id);
    try std.testing.expectEqualStrings("Test Issue", issue.title);
    try std.testing.expectEqual(.open, issue.state);
}
