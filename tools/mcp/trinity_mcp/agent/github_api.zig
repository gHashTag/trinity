// github_api.zig — GitHub REST API client for agent entrypoint
// Replaces gh CLI dependency. Uses std.http.Client only.
const std = @import("std");

pub const Issue = struct {
    number: u32,
    title: []const u8,
    body: []const u8,
    labels: []const u8,
    raw_json: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Issue) void {
        self.allocator.free(self.raw_json);
    }
};

pub const PR = struct {
    number: u32,
    url: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *PR) void {
        self.allocator.free(self.url);
    }
};

pub const GitHubConfig = struct {
    token: []const u8,
    owner: []const u8,
    repo: []const u8,
};

/// Read a single issue by number.
pub fn readIssue(allocator: std.mem.Allocator, config: GitHubConfig, issue_number: u32) !Issue {
    var url_buf: [512]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buf, "https://api.github.com/repos/{s}/{s}/issues/{d}", .{
        config.owner, config.repo, issue_number,
    });

    const body = try githubGet(allocator, config.token, url);

    // Extract title
    const title = extractJsonString(body, "title") orelse "untitled";
    const issue_body = extractJsonString(body, "body") orelse "";

    return .{
        .number = issue_number,
        .title = title,
        .body = issue_body,
        .labels = "",
        .raw_json = body,
        .allocator = allocator,
    };
}

/// Post a comment on an issue.
pub fn commentOnIssue(allocator: std.mem.Allocator, config: GitHubConfig, issue_number: u32, body_text: []const u8) void {
    var url_buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "https://api.github.com/repos/{s}/{s}/issues/{d}/comments", .{
        config.owner, config.repo, issue_number,
    }) catch return;

    // Build JSON payload with escaped body
    var payload_buf: [8192]u8 = undefined;
    var pi: usize = 0;

    const prefix = "{\"body\":\"";
    @memcpy(payload_buf[pi..][0..prefix.len], prefix);
    pi += prefix.len;

    pi = jsonEscapeInto(&payload_buf, pi, body_text);

    const suffix = "\"}";
    if (pi + suffix.len <= payload_buf.len) {
        @memcpy(payload_buf[pi..][0..suffix.len], suffix);
        pi += suffix.len;
    }

    const resp = githubPost(allocator, config.token, url, payload_buf[0..pi]) catch |err| {
        std.debug.print("[github] comment failed: {s}\n", .{@errorName(err)});
        return;
    };
    allocator.free(resp);
}

/// Create a pull request. Returns PR struct with number and URL.
pub fn createPR(
    allocator: std.mem.Allocator,
    config: GitHubConfig,
    head_branch: []const u8,
    title: []const u8,
    body_text: []const u8,
) !PR {
    var url_buf: [512]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buf, "https://api.github.com/repos/{s}/{s}/pulls", .{
        config.owner, config.repo,
    });

    // Build JSON payload
    var payload_buf: [8192]u8 = undefined;
    var pi: usize = 0;

    const p1 = "{\"title\":\"";
    @memcpy(payload_buf[pi..][0..p1.len], p1);
    pi += p1.len;
    pi = jsonEscapeInto(&payload_buf, pi, title);

    const p2 = "\",\"head\":\"";
    @memcpy(payload_buf[pi..][0..p2.len], p2);
    pi += p2.len;
    pi = jsonEscapeInto(&payload_buf, pi, head_branch);

    const p3 = "\",\"base\":\"main\",\"body\":\"";
    @memcpy(payload_buf[pi..][0..p3.len], p3);
    pi += p3.len;
    pi = jsonEscapeInto(&payload_buf, pi, body_text);

    const p4 = "\"}";
    @memcpy(payload_buf[pi..][0..p4.len], p4);
    pi += p4.len;

    const resp = try githubPost(allocator, config.token, url, payload_buf[0..pi]);

    // Extract PR number and html_url
    const pr_number = extractJsonNumber(resp, "number") orelse 0;
    const html_url = extractJsonString(resp, "html_url") orelse "";

    const url_dupe = try allocator.dupe(u8, html_url);
    allocator.free(resp);

    return .{
        .number = pr_number,
        .url = url_dupe,
        .allocator = allocator,
    };
}

/// Close an issue.
pub fn closeIssue(allocator: std.mem.Allocator, config: GitHubConfig, issue_number: u32) void {
    var url_buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "https://api.github.com/repos/{s}/{s}/issues/{d}", .{
        config.owner, config.repo, issue_number,
    }) catch return;

    const payload = "{\"state\":\"closed\"}";
    // PATCH request — use POST with method override not available, use raw
    const resp = githubPost(allocator, config.token, url, payload) catch |err| {
        std.debug.print("[github] close issue failed: {s}\n", .{@errorName(err)});
        return;
    };
    allocator.free(resp);
}

// ── HTTP helpers ──

fn githubGet(allocator: std.mem.Allocator, token: []const u8, url: []const u8) ![]const u8 {
    var auth_buf: [300]u8 = undefined;
    const auth_val = try std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{token});

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();

    const result = try client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .extra_headers = &.{
            .{ .name = "Authorization", .value = auth_val },
            .{ .name = "Accept", .value = "application/vnd.github+json" },
            .{ .name = "X-GitHub-Api-Version", .value = "2022-11-28" },
            .{ .name = "User-Agent", .value = "trinity-agent/1.0" },
        },
        .response_writer = &aw.writer,
    });

    if (result.status != .ok) {
        return error.GitHubApiError;
    }

    const body = aw.written();
    return try allocator.dupe(u8, body);
}

fn githubPost(allocator: std.mem.Allocator, token: []const u8, url: []const u8, payload: []const u8) ![]const u8 {
    var auth_buf: [300]u8 = undefined;
    const auth_val = try std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{token});

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();

    const result = try client.fetch(.{
        .location = .{ .url = url },
        .method = .POST,
        .payload = payload,
        .extra_headers = &.{
            .{ .name = "Authorization", .value = auth_val },
            .{ .name = "Accept", .value = "application/vnd.github+json" },
            .{ .name = "Content-Type", .value = "application/json" },
            .{ .name = "X-GitHub-Api-Version", .value = "2022-11-28" },
            .{ .name = "User-Agent", .value = "trinity-agent/1.0" },
        },
        .response_writer = &aw.writer,
    });

    if (result.status != .ok and result.status != .created) {
        return error.GitHubApiError;
    }

    const body = aw.written();
    return try allocator.dupe(u8, body);
}

// ── JSON extraction (no allocations, returns slices into input) ──

fn extractJsonString(json: []const u8, key: []const u8) ?[]const u8 {
    // Find "key":"value"
    var search_buf: [128]u8 = undefined;
    const needle = std.fmt.bufPrint(&search_buf, "\"{s}\":\"", .{key}) catch return null;

    const idx = std.mem.indexOf(u8, json, needle) orelse return null;
    const start = idx + needle.len;
    if (start >= json.len) return null;

    var end = start;
    while (end < json.len) : (end += 1) {
        if (json[end] == '"' and (end == start or json[end - 1] != '\\')) break;
    }
    if (end == start) return null;
    return json[start..end];
}

fn extractJsonNumber(json: []const u8, key: []const u8) ?u32 {
    var search_buf: [128]u8 = undefined;
    const needle = std.fmt.bufPrint(&search_buf, "\"{s}\":", .{key}) catch return null;

    const idx = std.mem.indexOf(u8, json, needle) orelse return null;
    const start = idx + needle.len;
    if (start >= json.len) return null;

    // Skip whitespace
    var s = start;
    while (s < json.len and (json[s] == ' ' or json[s] == '\t')) : (s += 1) {}

    var end = s;
    while (end < json.len and json[end] >= '0' and json[end] <= '9') : (end += 1) {}
    if (end == s) return null;
    return std.fmt.parseInt(u32, json[s..end], 10) catch null;
}

fn jsonEscapeInto(buf: []u8, start: usize, text: []const u8) usize {
    var i = start;
    for (text) |c| {
        if (i + 2 >= buf.len - 4) break;
        switch (c) {
            '"' => {
                buf[i] = '\\';
                buf[i + 1] = '"';
                i += 2;
            },
            '\\' => {
                buf[i] = '\\';
                buf[i + 1] = '\\';
                i += 2;
            },
            '\n' => {
                buf[i] = '\\';
                buf[i + 1] = 'n';
                i += 2;
            },
            '\r' => {
                buf[i] = '\\';
                buf[i + 1] = 'r';
                i += 2;
            },
            else => {
                buf[i] = c;
                i += 1;
            },
        }
    }
    return i;
}

test "extractJsonString" {
    const json = "{\"title\":\"Fix the bug\",\"number\":42}";
    const title = extractJsonString(json, "title") orelse return error.NotFound;
    try std.testing.expectEqualStrings("Fix the bug", title);
}

test "extractJsonNumber" {
    const json = "{\"title\":\"Fix\",\"number\":42}";
    try std.testing.expectEqual(@as(?u32, 42), extractJsonNumber(json, "number"));
}

test "jsonEscapeInto" {
    var buf: [64]u8 = undefined;
    const end = jsonEscapeInto(&buf, 0, "hello \"world\"\nbye");
    try std.testing.expectEqualStrings("hello \\\"world\\\"\\nbye", buf[0..end]);
}
