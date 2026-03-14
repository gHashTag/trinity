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
    const subset = decomposeIssue("update documentation");
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
