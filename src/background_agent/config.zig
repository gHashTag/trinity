//! Background Agent Configuration
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Configuration for background-agent API
pub const Config = struct {
    // Railway's proxy reaches a container over IPv6, so a listener bound to
    // 0.0.0.0 is invisible to it: the process runs, the port is open, and every
    // request comes back 502. "::" accepts both families.
    host: []const u8 = "::",
    port: u16 = 3000,
    railwayApiToken: []const u8 = "",
    railwayProjectId: []const u8 = "",
    authSecret: []const u8 = "",
    databaseUrl: []const u8 = "",
    localMode: bool = false,
};

/// Get environment variable with error handling
fn getEnv(allocator: Allocator, key: []const u8) ![]const u8 {
    if (std.process.getEnvVarOwned(allocator, key)) |value| {
        return value;
    } else |_| {
        return error.MissingEnv;
    }
}

/// Get environment variable with default value
fn getEnvOr(allocator: Allocator, key: []const u8, default_value: []const u8) ![]const u8 {
    if (std.process.getEnvVarOwned(allocator, key)) |value| {
        return value;
    } else |_| {
        return default_value;
    }
}

/// Validate configuration at runtime
pub fn validateConfig(config: *const Config) !void {
    if (config.databaseUrl.len == 0) {
        return error.MissingEnv;
    }
    // API token and auth secret are optional for Railway health checks
    // but will be validated when used
}

/// Load configuration from environment variables
pub fn loadConfig(allocator: Allocator) !Config {
    const port_str = try getEnvOr(allocator, "PORT", "3000");
    const port = try std.fmt.parseInt(u16, port_str, 10);

    var config = Config{
        .port = port,
        .railwayApiToken = getEnvOr(allocator, "RAILWAY_API_TOKEN", "") catch "",
        .railwayProjectId = try getEnvOr(allocator, "RAILWAY_PROJECT_ID", ""),
        .authSecret = getEnvOr(allocator, "AUTH_SECRET", "") catch "",
        .databaseUrl = try getEnv(allocator, "DATABASE_URL"),
        .localMode = try isLocalMode(allocator),
    };

    try validateConfig(&config);
    return config;
}

/// Check if running in local mode
fn isLocalMode(allocator: Allocator) !bool {
    const local = try getEnvOr(allocator, "LOCAL_MODE", "false");
    if (std.mem.eql(u8, local, "true") or std.mem.eql(u8, local, "1")) {
        return true;
    }
    return false;
}

pub const Error = error{
    MissingEnv,
    InvalidPort,
};

test "config: load defaults" {
    const allocator = std.testing.allocator;
    var env = std.process.EnvMap.init(allocator);
    defer env.deinit();

    try env.put("PORT", "8080");
    try env.put("RAILWAY_API_TOKEN", "test_token");
    try env.put("RAILWAY_PROJECT_ID", "proj_123");
    try env.put("AUTH_SECRET", "secret123");
    try env.put("DATABASE_URL", "postgres://localhost/test");
    try env.put("LOCAL_MODE", "false");

    const config = try loadConfig(allocator);
    try std.testing.expect(config.port == 8080);
    try std.testing.expectEqualStrings(config.railwayApiToken, "test_token");
    try std.testing.expectEqualStrings(config.railwayProjectId, "proj_123");
    try std.testing.expectEqualStrings(config.authSecret, "secret123");
    try std.testing.expectEqualStrings(config.databaseUrl, "postgres://localhost/test");
    try std.testing.expect(config.localMode == false);
}

test "config: optional api token and auth secret" {
    const allocator = std.testing.allocator;
    var env = std.process.EnvMap.init(allocator);
    defer env.deinit();

    try env.put("PORT", "3000");
    try env.put("RAILWAY_PROJECT_ID", "proj_optional");
    try env.put("DATABASE_URL", "postgres://localhost/test");
    try env.put("LOCAL_MODE", "false");
    // RAILWAY_API_TOKEN and AUTH_SECRET are now optional

    const config = try loadConfig(allocator);
    try std.testing.expect(config.port == 3000);
    try std.testing.expectEqualStrings(config.railwayApiToken, "");
    try std.testing.expectEqualStrings(config.authSecret, "");
    try std.testing.expectEqualStrings(config.railwayProjectId, "proj_optional");
}

test "config: missing database url" {
    const allocator = std.testing.allocator;
    var env = std.process.EnvMap.init(allocator);
    defer env.deinit();

    try env.put("PORT", "3000");
    try env.put("RAILWAY_PROJECT_ID", "proj_test");
    // DATABASE_URL is still required

    try std.testing.expectError(error.MissingEnv, loadConfig(allocator));
}
