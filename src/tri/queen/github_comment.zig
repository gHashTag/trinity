// Queen GitHub Comment Integration
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

const GITHUB_TOKEN = std.posix.getenv("GITHUB_TOKEN") orelse "";
const REPO = "gHashTag/trinity";
const DEFAULT_HEADERS = "Accept: application/vnd.github.v3+json";
const ISSUE_COMMENT_API = "repos/{s}/issues/{s}/comments";

/// Comment data structure
pub const CommentData = struct {
    issue_number: u64,
    body: []const u8,
};

/// Create comment on GitHub issue
pub fn createIssueComment(allocator: Allocator, data: CommentData) !void {
    if (GITHUB_TOKEN.len == 0) return;

    const url = try std.fmt.allocPrint(
        allocator,
        "https://api.github.com/{s}/{s}/{s}",
        .{ REPO, data.issue_number, ISSUE_COMMENT_API },
    );

    const body_json = try std.json.stringifyAlloc(
        allocator,
        .{ .body = data.body },
        .{ .whitespace = .minified },
    );
    defer allocator.free(body_json);

    var headers = std.ArrayList([]const u8).init(allocator);
    defer headers.deinit(allocator);
    try headers.appendSlice(allocator, &[_][]const u8{
        "Authorization: token " ++ GITHUB_TOKEN,
        "Content-Type: application/json",
    });

    // Create HTTP client
    var client = std.http.Client{
        .allocator = allocator,
    };
    defer client.deinit();

    const response = try client.request(.{
        .url = url,
        .method = .POST,
        .headers = headers.items,
        .body = body_json,
        .max_redirects = 5,
    });

    defer response.body.deinit();

    if (response.status != .created) {
        const error_body = try response.body.reader.readAllAlloc(allocator, 1024) catch "";
        defer allocator.free(error_body);

        std.debug.print("\x1b[31mFailed to create comment: {d}\x1b[0m\n", .{response.status});
        if (error_body.len > 0) {
            std.debug.print("Response: {s}\n", .{error_body});
        }
        return;
    }

    std.debug.print("\x1b[32m✅ Comment created on issue #{d}\x1b[0m\n", .{data.issue_number});
}

/// Format Lotus Cycle progress comment
pub fn formatLotusProgressComment(allocator: Allocator, issue_number: u64, title: []const u8, sections: []const []const u8) ![]const u8 {
    var comment = try std.ArrayList(u8).init(allocator);
    defer comment.deinit(allocator);

    // Header
    try comment.appendSlice(allocator, "## {s} Lotus Cycle Progress Update#{d}\n\n", .{title});

    // Add sections
    for (sections) |section| {
        try comment.appendSlice(allocator, section);
        try comment.appendSlice(allocator, "\n");
    }

    try comment.toOwnedSlice(allocator);
}

/// Create section header
pub fn sectionHeader(allocator: Allocator, emoji: []const u8, title: []const u8) ![]const u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, emoji.len + title.len + 5);
    defer result.deinit(allocator);

    try result.appendSlice(allocator, emoji);
    try result.appendSlice(allocator, " ");
    try result.appendSlice(allocator, title);
    try result.appendSlice(allocator, "\n");

    return try result.toOwnedSlice(allocator);
}

test "github_comment: formatLotusProgressComment" {
    const allocator = std.testing.allocator;
    const title = "Test Update";
    const sections = &[_][]const u8{
        "### 📊 Metrics",
        "Build: ✅, Tests: ✅",
    };

    const result = try formatLotusProgressComment(allocator, 123, title, sections);
    defer allocator.free(result);

    try std.testing.expect(result.len > 0);
}
