// github_poller.zig — Fetch pending GitHub Issues labeled assign:ralph
const std = @import("std");

/// Fetch pending issues from GitHub API.
/// Returns raw JSON string or null on error.
pub fn fetchPending(allocator: std.mem.Allocator, owner: []const u8, repo: []const u8, gh_token: []const u8) ?[]const u8 {
    var url_buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "https://api.github.com/repos/{s}/{s}/issues?labels=assign:ralph,status:pending&state=open&per_page=20", .{ owner, repo }) catch return null;

    var auth_buf: [300]u8 = undefined;
    const auth_val = std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{gh_token}) catch return null;

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();

    const result = client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .extra_headers = &.{
            .{ .name = "Authorization", .value = auth_val },
            .{ .name = "Accept", .value = "application/vnd.github+json" },
            .{ .name = "X-GitHub-Api-Version", .value = "2022-11-28" },
            .{ .name = "User-Agent", .value = "ralph-agent/1.0" },
        },
        .response_writer = &aw.writer,
    }) catch return null;

    if (result.status != .ok) return null;

    // Caller owns this memory (via aw's allocator)
    const body = aw.written();
    return allocator.dupe(u8, body) catch null;
}

/// Extract first issue number from GitHub API JSON response.
/// Looks for "number":N pattern in the JSON array.
pub fn extractFirstIssueNumber(json: []const u8) ?u32 {
    const needle = "\"number\":";
    const idx = std.mem.indexOf(u8, json, needle) orelse return null;
    const start = idx + needle.len;
    if (start >= json.len) return null;

    // Find end of number
    var end = start;
    while (end < json.len and json[end] >= '0' and json[end] <= '9') : (end += 1) {}
    if (end == start) return null;

    return std.fmt.parseInt(u32, json[start..end], 10) catch null;
}

/// Extract first issue title from GitHub API JSON response.
pub fn extractFirstIssueTitle(json: []const u8) ?[]const u8 {
    const needle = "\"title\":\"";
    const idx = std.mem.indexOf(u8, json, needle) orelse return null;
    const start = idx + needle.len;
    if (start >= json.len) return null;

    // Find closing quote (handle escaped quotes)
    var end = start;
    while (end < json.len) : (end += 1) {
        if (json[end] == '"' and (end == start or json[end - 1] != '\\')) break;
    }
    if (end == start) return null;
    return json[start..end];
}

test "extractFirstIssueNumber" {
    const json = "[{\"number\":42,\"title\":\"Test issue\"}]";
    try std.testing.expectEqual(@as(?u32, 42), extractFirstIssueNumber(json));
}

test "extractFirstIssueTitle" {
    const json = "[{\"number\":42,\"title\":\"Test issue\"}]";
    const title = extractFirstIssueTitle(json) orelse return error.NotFound;
    try std.testing.expectEqualStrings("Test issue", title);
}

test "extractFirstIssueNumber returns null for empty" {
    try std.testing.expectEqual(@as(?u32, null), extractFirstIssueNumber("[]"));
}
