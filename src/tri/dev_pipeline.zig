// @origin(spec) @regen(done)
// ═══════════════════════════════════════════════════════════════════════════════
// DEV PIPELINE — Dev-Specific Pipeline Configuration
// ═══════════════════════════════════════════════════════════════════════════════
//
// Generated from: specs/tri/dev_pipeline.tri
// Extends Golden Chain pipeline for development agent use cases.
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const LinkSubset = enum {
    full, // all 26 links
    spec_only, // links 1-6
    code_only, // links 7-11
    test_only, // links 12-15
    review_only, // links 16-18
    minimal, // links 6,7,11,17

    pub fn links(self: LinkSubset) []const u32 {
        return switch (self) {
            .full => &[_]u32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26 },
            .spec_only => &[_]u32{ 1, 2, 3, 4, 5, 6 },
            .code_only => &[_]u32{ 7, 8, 9, 10, 11 },
            .test_only => &[_]u32{ 12, 13, 14, 15 },
            .review_only => &[_]u32{ 16, 17, 18 },
            .minimal => &[_]u32{ 6, 7, 11, 17 },
        };
    }

    pub fn toString(self: LinkSubset) []const u8 {
        return switch (self) {
            .full => "full (26 links)",
            .spec_only => "spec_only (1-6)",
            .code_only => "code_only (7-11)",
            .test_only => "test_only (12-15)",
            .review_only => "review_only (16-18)",
            .minimal => "minimal (6,7,11,17)",
        };
    }
};

pub const PipelineConfig = struct {
    issue_number: u32,
    role: []const u8 = "coder",
    model: []const u8 = "claude-sonnet-4-20250514",
    subset: LinkSubset = .minimal,
    timeout_minutes: u32 = 60,
    max_retries: u32 = 3,
};

pub const DevResult = struct {
    issue_number: u32,
    links_executed: u32 = 0,
    links_passed: u32 = 0,
    links_failed: u32 = 0,
    build_success: bool = false,
    test_pass_rate: f32 = 0.0,
    time_seconds: u32 = 0,
    error_log: ?[]const u8 = null,
};

// ═══════════════════════════════════════════════════════════════════════════════
// ISSUE DECOMPOSITION
// ═══════════════════════════════════════════════════════════════════════════════

/// Determine optimal link subset based on issue title/labels
pub fn decomposeIssue(title: []const u8) LinkSubset {
    // Bug fix / compile error → minimal pipeline
    if (containsAny(title, &.{ "fix:", "fix(", "bug:", "compile error", "build error" })) {
        return .minimal;
    }
    // New feature → full pipeline
    if (containsAny(title, &.{ "feat:", "feat(", "add:", "implement", "create" })) {
        return .full;
    }
    // Refactor → code + review
    if (containsAny(title, &.{ "refactor:", "refactor(", "cleanup", "rename" })) {
        return .code_only;
    }
    // Test → test only
    if (containsAny(title, &.{ "test:", "test(", "add tests", "testing" })) {
        return .test_only;
    }
    // Docs → review only
    if (containsAny(title, &.{ "docs:", "docs(", "doc:", "README", "documentation" })) {
        return .review_only;
    }
    // Chore → minimal
    if (containsAny(title, &.{ "chore:", "chore(", "ci:", "ci(", "deps:", "bump" })) {
        return .minimal;
    }
    // Default: minimal (safest)
    return .minimal;
}

/// Model routing based on agent role
pub fn modelForRole(role: []const u8) []const u8 {
    // Creative roles → Claude Sonnet (high quality)
    if (std.mem.eql(u8, role, "planner") or std.mem.eql(u8, role, "coder")) {
        return "claude-sonnet-4-20250514";
    }
    // Mechanical roles → cheaper model
    if (std.mem.eql(u8, role, "reviewer") or std.mem.eql(u8, role, "tester")) {
        return "glm-5";
    }
    return "claude-sonnet-4-20250514";
}

fn containsAny(haystack: []const u8, needles: []const []const u8) bool {
    for (needles) |needle| {
        if (std.ascii.indexOfIgnoreCase(haystack, needle) != null) return true;
    }
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ISSUE JSON PARSING
// ═══════════════════════════════════════════════════════════════════════════════

pub const IssueInfo = struct {
    number: u32 = 0,
    title: []const u8 = "",
    labels: []const []const u8 = &.{},

    pub fn hasLabel(self: IssueInfo, target: []const u8) bool {
        for (self.labels) |label| {
            if (std.mem.eql(u8, label, target)) return true;
        }
        return false;
    }
};

/// Parse `gh issue view --json number,title,labels` output
pub fn parseIssueJson(allocator: std.mem.Allocator, json_str: []const u8) !IssueInfo {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const root = parsed.value;
    if (root != .object) return error.InvalidJson;

    var info = IssueInfo{};

    // number
    if (root.object.get("number")) |n| {
        if (n == .integer) info.number = @intCast(@as(i64, n.integer));
    }

    // title
    if (root.object.get("title")) |t| {
        if (t == .string) info.title = try allocator.dupe(u8, t.string);
    }

    // labels: [{"name": "agent:dev"}, ...]
    if (root.object.get("labels")) |labels_val| {
        if (labels_val == .array) {
            var label_list: std.ArrayList([]const u8) = .empty;
            for (labels_val.array.items) |label_obj| {
                if (label_obj == .object) {
                    if (label_obj.object.get("name")) |name_val| {
                        if (name_val == .string) {
                            try label_list.append(allocator, try allocator.dupe(u8, name_val.string));
                        }
                    }
                }
            }
            info.labels = try label_list.toOwnedSlice(allocator);
        }
    }

    return info;
}

// ═══════════════════════════════════════════════════════════════════════════════
// COST ESTIMATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Estimate cost in USD for a pipeline run
/// Pricing (per million tokens): Sonnet input=$3, output=$15; glm-5 ~$0.50/$1.50
pub fn estimateCost(model: []const u8, total_tokens: u32) f32 {
    // Assume 80% input, 20% output
    const total_f: f32 = @floatFromInt(total_tokens);
    const input_tokens = total_f * 0.8;
    const output_tokens = total_f * 0.2;

    if (std.mem.startsWith(u8, model, "claude-sonnet")) {
        // Sonnet 4: $3/M input, $15/M output
        return (input_tokens * 3.0 + output_tokens * 15.0) / 1_000_000.0;
    }
    if (std.mem.eql(u8, model, "glm-5")) {
        // glm-5 via z.ai: ~$0.50/M input, $1.50/M output
        return (input_tokens * 0.5 + output_tokens * 1.5) / 1_000_000.0;
    }
    // Default: Claude pricing
    return (input_tokens * 3.0 + output_tokens * 15.0) / 1_000_000.0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "decomposeIssue bug fix" {
    const subset = decomposeIssue("fix: compile error in vsa.zig");
    try std.testing.expectEqual(LinkSubset.minimal, subset);
}

test "decomposeIssue feature" {
    const subset = decomposeIssue("feat: add new VSA similarity metric");
    try std.testing.expectEqual(LinkSubset.full, subset);
}

test "decomposeIssue default" {
    const subset = decomposeIssue("improve performance of matmul");
    try std.testing.expectEqual(LinkSubset.minimal, subset);
}

test "modelForRole creative" {
    try std.testing.expectEqualStrings("claude-sonnet-4-20250514", modelForRole("coder"));
    try std.testing.expectEqualStrings("claude-sonnet-4-20250514", modelForRole("planner"));
}

test "modelForRole mechanical" {
    try std.testing.expectEqualStrings("glm-5", modelForRole("reviewer"));
    try std.testing.expectEqualStrings("glm-5", modelForRole("tester"));
}

test "LinkSubset.minimal has 4 links" {
    const links = LinkSubset.minimal.links();
    try std.testing.expectEqual(@as(usize, 4), links.len);
}

test "LinkSubset.full has 26 links" {
    const links = LinkSubset.full.links();
    try std.testing.expectEqual(@as(usize, 26), links.len);
}

test "decomposeIssue docs" {
    const subset = decomposeIssue("docs: update README with new commands");
    try std.testing.expectEqual(LinkSubset.review_only, subset);
}

test "decomposeIssue refactor" {
    const subset = decomposeIssue("refactor: extract common types");
    try std.testing.expectEqual(LinkSubset.code_only, subset);
}

test "decomposeIssue test" {
    const subset = decomposeIssue("test: add coverage for vsa.zig");
    try std.testing.expectEqual(LinkSubset.test_only, subset);
}

test "decomposeIssue chore" {
    const subset = decomposeIssue("chore: update dependencies");
    try std.testing.expectEqual(LinkSubset.minimal, subset);
}

test "parseIssueJson valid" {
    const json =
        \\{"number":42,"title":"fix: compile error","labels":[{"name":"agent:dev"},{"name":"bug"}]}
    ;
    const allocator = std.testing.allocator;
    const info = try parseIssueJson(allocator, json);
    defer {
        allocator.free(info.title);
        for (info.labels) |l| allocator.free(l);
        allocator.free(info.labels);
    }
    try std.testing.expectEqual(@as(u32, 42), info.number);
    try std.testing.expectEqualStrings("fix: compile error", info.title);
    try std.testing.expectEqual(@as(usize, 2), info.labels.len);
    try std.testing.expect(info.hasLabel("agent:dev"));
    try std.testing.expect(info.hasLabel("bug"));
    try std.testing.expect(!info.hasLabel("nonexistent"));
}

test "parseIssueJson empty labels" {
    const json =
        \\{"number":1,"title":"test","labels":[]}
    ;
    const allocator = std.testing.allocator;
    const info = try parseIssueJson(allocator, json);
    defer {
        allocator.free(info.title);
        allocator.free(info.labels);
    }
    try std.testing.expectEqual(@as(u32, 1), info.number);
    try std.testing.expectEqual(@as(usize, 0), info.labels.len);
}

test "estimateCost sonnet 50K tokens" {
    const cost = estimateCost("claude-sonnet-4-20250514", 50_000);
    // 40K input * $3/M + 10K output * $15/M = $0.12 + $0.15 = $0.27
    try std.testing.expect(cost > 0.25 and cost < 0.30);
}

test "estimateCost glm5 50K tokens" {
    const cost = estimateCost("glm-5", 50_000);
    // 40K input * $0.5/M + 10K output * $1.5/M = $0.02 + $0.015 = $0.035
    try std.testing.expect(cost > 0.03 and cost < 0.04);
}
