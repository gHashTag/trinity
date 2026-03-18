// @origin(manual) @regen(pending)
// Trinity Release — tri release create/deploy/verify
// Migrated from scripts/final_release.sh, deploy-gh-pages.sh, deploy-flyio.sh, verify-deploy.sh
//
// GitHub Release creation, GH Pages deploy, Fly.io deploy, health verification

const std = @import("std");

pub const ReleaseConfig = struct {
    version: []const u8 = "1.0.0",
    title: []const u8 = "TRINITY OS",
    draft: bool = false,
    prerelease: bool = false,
};

pub const DeployTarget = enum {
    gh_pages,
    flyio,
    railway,

    pub fn toString(self: DeployTarget) []const u8 {
        return switch (self) {
            .gh_pages => "GitHub Pages",
            .flyio => "Fly.io",
            .railway => "Railway",
        };
    }
};

pub const HealthCheck = struct {
    endpoint: []const u8,
    expected_status: u16 = 200,
    timeout_ms: u64 = 5000,
};

pub const DeployVerification = struct {
    website_dir_exists: bool = false,
    docs_dir_exists: bool = false,
    index_html_exists: bool = false,
    gh_pages_branch_exists: bool = false,
    last_deploy_date: ?[]const u8 = null,
};

/// Check if required build artifacts exist for deploy
pub fn verifyBuildArtifacts(target: DeployTarget) DeployVerification {
    var result = DeployVerification{};

    switch (target) {
        .gh_pages => {
            result.website_dir_exists = dirExists("website/dist");
            result.docs_dir_exists = dirExists("docs/build");
            result.index_html_exists = fileExists("website/dist/index.html");
        },
        .flyio => {
            result.index_html_exists = fileExists("zig-out/bin/tri");
        },
        .railway => {
            result.index_html_exists = fileExists("Dockerfile.hslm-train");
        },
    }

    return result;
}

/// Health check endpoints for deployed services
pub const HEALTH_CHECKS = [_]HealthCheck{
    .{ .endpoint = "/health" },
    .{ .endpoint = "/api/health" },
};

/// Format GitHub release tag
pub fn formatTag(buf: []u8, version: []const u8) ![]const u8 {
    return std.fmt.bufPrint(buf, "v{s}", .{version});
}

fn dirExists(path: []const u8) bool {
    const stat = std.fs.cwd().statFile(path) catch return false;
    return stat.kind == .directory;
}

fn fileExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

test "deploy target names" {
    try std.testing.expectEqualStrings("GitHub Pages", DeployTarget.gh_pages.toString());
    try std.testing.expectEqualStrings("Fly.io", DeployTarget.flyio.toString());
    try std.testing.expectEqualStrings("Railway", DeployTarget.railway.toString());
}

test "format tag" {
    var buf: [64]u8 = undefined;
    const tag = try formatTag(&buf, "1.0.0");
    try std.testing.expectEqualStrings("v1.0.0", tag);
}

test "default config" {
    const config = ReleaseConfig{};
    try std.testing.expectEqualStrings("1.0.0", config.version);
    try std.testing.expect(!config.draft);
}
