// G-zone — GitHub Integration Zone
// Re-exports github_client and github_app_auth for use by queen, tri, and other zones
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// GitHub integration modules (same directory)
pub const github_client = @import("github_client.zig");
pub const github_app_auth = @import("github_app_auth.zig");
