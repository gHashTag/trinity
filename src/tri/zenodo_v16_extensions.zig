//! Zenodo V16: Extensions — Additional Scientific Features
//!
//! Extended features beyond core V16:
//! - Pareto frontier visualization (MLSys 2025 requirement)
//! - GitHub CI badge generation (NeurIPS 2025 code availability)
//! - Scaling analysis helpers (MLSys 2025 scaling plots)
//! - Embargo period support (Zenodo delayed publication)

const std = @import("std");

/// Pareto frontier point
pub const ParetoPoint = struct {
    x_value: f64,
    y_value: f64,
    model_name: []const u8,
    is_dominated: bool = false,
    is_pareto_optimal: bool = false,

    pub fn formatAsMarkdown(self: *const ParetoPoint, allocator: std.mem.Allocator) ![]u8 {
        const emoji = if (self.is_pareto_optimal) "✅" else if (self.is_dominated) "🔴" else "⚪";
        const status = if (self.is_pareto_optimal) " (Pareto Optimal)" else "";
        return std.fmt.allocPrint(allocator, "{s} {s}: ({d:.3}, {d:.3}){s}\n", .{ emoji, self.model_name, self.x_value, self.y_value, status });
    }
};

/// Pareto frontier for multi-objective optimization
pub const ParetoFrontier = struct {
    metric_x_name: []const u8,
    metric_y_name: []const u8,
    higher_x_better: bool,
    higher_y_better: bool,
    points: []const ParetoPoint,

    pub fn formatAsMarkdown(self: *const ParetoFrontier, allocator: std.mem.Allocator) ![]u8 {
        var result = try std.ArrayList(u8).initCapacity(allocator, 512);
        defer result.deinit(allocator);

        try result.appendSlice(allocator, "## Pareto Frontier Analysis\n\n");
        try result.appendSlice(allocator, "**X-Axis**: ");
        try result.appendSlice(allocator, self.metric_x_name);
        try result.appendSlice(allocator, "\n");
        try result.appendSlice(allocator, "**Y-Axis**: ");
        try result.appendSlice(allocator, self.metric_y_name);
        try result.appendSlice(allocator, "\n\n");

        var optimal_count: u32 = 0;
        for (self.points) |point| {
            if (!point.is_dominated) optimal_count += 1;
        }

        try result.appendSlice(allocator, "**Pareto Optimal Models**:\n\n");

        for (self.points) |point| {
            if (!point.is_dominated) {
                const point_md = try point.formatAsMarkdown(allocator);
                defer allocator.free(point_md);
                try result.appendSlice(allocator, point_md);
            }
        }

        const total_models = self.points.len;
        const coverage = @as(f64, @floatFromInt(optimal_count * 100)) / @as(f64, @floatFromInt(total_models));

        try result.appendSlice(allocator, "\n**Coverage**: ");
        const cov_str = try std.fmt.allocPrint(allocator, "{d:.1}% ({d}/{d} models are Pareto optimal)\n", .{ coverage, optimal_count, total_models });
        defer allocator.free(cov_str);
        try result.appendSlice(allocator, cov_str);

        return result.toOwnedSlice(allocator);
    }
};

/// GitHub CI badge generator
pub const GitHubActionsBadge = struct {
    repo_url: []const u8,
    workflow_name: []const u8 = "CI",

    pub fn init(repo_url: []const u8) GitHubActionsBadge {
        return .{
            .repo_url = repo_url,
            .workflow_name = "CI",
        };
    }

    pub fn generateBadgesMarkdown(self: *const GitHubActionsBadge, allocator: std.mem.Allocator, build_status: ?[]const u8, coverage_pct: ?f64) ![]u8 {
        var result = try std.ArrayList(u8).initCapacity(allocator, 512);
        defer result.deinit(allocator);

        try result.appendSlice(allocator, "## Code Availability\n\n");
        try result.appendSlice(allocator, "**Repository**: ");
        try result.appendSlice(allocator, self.repo_url);
        try result.appendSlice(allocator, "\n\n");

        if (build_status) |status| {
            const color = if (std.mem.eql(u8, status, "passing")) "brightgreen" else "red";
            const badge_url = try std.fmt.allocPrint(allocator, "https://img.shields.io/badge/build status-{s}-{s}", .{ status, color });
            defer allocator.free(badge_url);
            try result.appendSlice(allocator, "![Build Status](");
            try result.appendSlice(allocator, badge_url);
            try result.appendSlice(allocator, ")\n\n");
        }

        if (coverage_pct) |coverage| {
            const color_str = if (coverage >= 80.0) "brightgreen" else if (coverage >= 60.0) "yellow" else "red";
            const coverage_str = try std.fmt.allocPrint(allocator, "{d:.0}%", .{coverage});
            defer allocator.free(coverage_str);
            const badge_url = try std.fmt.allocPrint(allocator, "https://img.shields.io/badge/coverage-{s}-{s}", .{ coverage_str, color_str });
            defer allocator.free(badge_url);
            try result.appendSlice(allocator, "![Coverage](");
            try result.appendSlice(allocator, badge_url);
            try result.appendSlice(allocator, ")\n\n");
        }

        try result.appendSlice(allocator, "\n**Reproducibility**: The code is available at the repository above with full version control history.\n");

        return result.toOwnedSlice(allocator);
    }
};

/// Embargo period for delayed publication
pub const EmbargoPeriod = struct {
    start_date: []const u8,
    end_date: []const u8,
    reason: ?[]const u8 = null,

    pub fn formatAsMarkdown(self: *const EmbargoPeriod, allocator: std.mem.Allocator) ![]u8 {
        var result = try std.ArrayList(u8).initCapacity(allocator, 256);
        defer result.deinit(allocator);

        try result.appendSlice(allocator, "## Embargo Period\n\n");
        try result.appendSlice(allocator, "**Start Date**: ");
        try result.appendSlice(allocator, self.start_date);
        try result.appendSlice(allocator, "\n");

        try result.appendSlice(allocator, "**End Date**: ");
        try result.appendSlice(allocator, self.end_date);
        try result.appendSlice(allocator, "\n");

        if (self.reason) |r| {
            try result.appendSlice(allocator, "**Reason**: ");
            try result.appendSlice(allocator, r);
            try result.appendSlice(allocator, "\n");
        }

        try result.appendSlice(allocator, "**Status**: The dataset/model is under embargo. Access will be available after the end date.\n");

        return result.toOwnedSlice(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════

test "ParetoPoint formatAsMarkdown" {
    const point = ParetoPoint{
        .model_name = "ModelA",
        .x_value = 95.0,
        .y_value = 10.5,
        .is_pareto_optimal = true,
    };

    const md = try point.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "ModelA") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "Pareto Optimal") != null);
}

test "GitHubActionsBadge generateBadgesMarkdown" {
    const badge = GitHubActionsBadge.init("https://github.com/example/repo");
    const md = try badge.generateBadgesMarkdown(std.testing.allocator, "passing", 85.5);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "## Code Availability") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "img.shields.io") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "86%") != null); // 85.5 rounds to 86
}

test "EmbargoPeriod formatAsMarkdown" {
    const embargo = EmbargoPeriod{
        .start_date = "2024-01-01",
        .end_date = "2024-12-31",
        .reason = "Peer review in progress",
    };

    const md = try embargo.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "## Embargo Period") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "2024-01-01") != null);
}
