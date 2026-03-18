//! Production Dashboard Deployment System
//!
//! This module provides a comprehensive deployment system for the Sacred Intelligence dashboard,
//! supporting multiple deployment targets (Vercel, Netlify, built-in server), environment
//! configurations, health checks, and rollback capabilities.

const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const process = std.process;
const time = std.time;
const net = std.net;
const http = std.http;
const testing = std.testing;

pub const DeployTarget = enum {
    /// Vercel deployment
    vercel,
    /// Netlify deployment
    netlify,
    /// Built-in HTTP server
    builtin,
    /// Local development only
    local,

    pub fn toString(self: DeployTarget) []const u8 {
        return switch (self) {
            .vercel => "vercel",
            .netlify => "netlify",
            .builtin => "builtin",
            .local => "local",
        };
    }

    pub fn fromString(str: []const u8) !DeployTarget {
        if (std.mem.eql(u8, str, "vercel")) return .vercel;
        if (std.mem.eql(u8, str, "netlify")) return .netlify;
        if (std.mem.eql(u8, str, "builtin")) return .builtin;
        if (std.mem.eql(u8, str, "local")) return .local;
        return error.InvalidDeployTarget;
    }
};

pub const Environment = enum {
    /// Development environment
    dev,
    /// Staging environment
    staging,
    /// Production environment
    production,

    pub fn toString(self: Environment) []const u8 {
        return switch (self) {
            .dev => "dev",
            .staging => "staging",
            .production => "production",
        };
    }

    pub fn fromString(str: []const u8) !Environment {
        if (std.mem.eql(u8, str, "dev")) return .dev;
        if (std.mem.eql(u8, str, "staging")) return .staging;
        if (std.mem.eql(u8, str, "production")) return .production;
        return error.InvalidEnvironment;
    }

    pub fn getEnvVar(self: Environment) []const u8 {
        return switch (self) {
            .dev => "NODE_ENV=development",
            .staging => "NODE_ENV=staging",
            .production => "NODE_ENV=production",
        };
    }
};

pub const BuildResult = struct {
    success: bool,
    output_dir: []const u8,
    build_time_ms: i64,
    error_message: ?[]const u8 = null,
    output_size_bytes: ?usize = null,

    pub fn format(self: BuildResult, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        const success_str = if (self.success) "true" else "false";
        try writer.print("BuildResult{{ success={s}, output_dir='{s}', build_time_ms={d}, error='{?s}', size={d} }}", .{ success_str, self.output_dir, self.build_time_ms, self.error_message, self.output_size_bytes orelse 0 });
    }
};

pub const DeployResult = struct {
    success: bool,
    url: ?[]const u8 = null,
    deploy_time_ms: i64,
    error_message: ?[]const u8 = null,
    rollback_performed: bool = false,
    deployment_id: ?[]const u8 = null,

    pub fn format(self: DeployResult, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        const success_str = if (self.success) "true" else "false";
        const rollback_str = if (self.rollback_performed) "true" else "false";
        try writer.print("DeployResult{{ success={s}, url='{?s}', deploy_time_ms={d}, error='{?s}', rollback={s}, id='{?s}' }}", .{ success_str, self.url, self.deploy_time_ms, self.error_message, rollback_str, self.deployment_id });
    }
};

pub const HealthStatus = struct {
    healthy: bool,
    status_code: u16,
    response_time_ms: i64,
    version: ?[]const u8 = null,
    error_message: ?[]const u8 = null,

    pub fn format(self: HealthStatus, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        const healthy_str = if (self.healthy) "true" else "false";
        try writer.print("HealthStatus{{ healthy={s}, status_code={d}, response_time_ms={d}, version='{?s}', error='{?s}' }}", .{ healthy_str, self.status_code, self.response_time_ms, self.version, self.error_message });
    }
};

pub const DeployConfig = struct {
    target: DeployTarget,
    environment: Environment,
    build_command: []const u8,
    deploy_command: []const u8,
    health_check_url: []const u8,
    rollback_command: []const u8,
    project_root: []const u8,
    builtin_port: u16 = 3000,

    pub fn initDefault(allocator: mem.Allocator, target: DeployTarget, env: Environment) !DeployConfig {
        const project_root = try fs.cwd().realpathAlloc(allocator, ".");
        return DeployConfig{
            .target = target,
            .environment = env,
            .project_root = project_root,
            .build_command = try allocator.dupe(u8, "cd website && npm run build"),
            .deploy_command = try allocator.dupe(u8, switch (target) {
                .vercel => "cd website && vercel --prod",
                .netlify => "cd website && netlify deploy --prod",
                .builtin => "",
                .local => "",
            }),
            .health_check_url = try allocator.dupe(u8, switch (env) {
                .production => "https://ghashag.github.io/trinity/health",
                .staging => "https://staging.trinity.dev/health",
                .dev => "http://localhost:3000/health",
            }),
            .rollback_command = try allocator.dupe(u8, switch (target) {
                .vercel => "vercel rollback",
                .netlify => "netlify rollback",
                .builtin => "",
                .local => "",
            }),
            .builtin_port = 3000,
        };
    }

    pub fn deinit(self: *DeployConfig, allocator: mem.Allocator) void {
        allocator.free(self.project_root);
        allocator.free(self.build_command);
        allocator.free(self.deploy_command);
        allocator.free(self.health_check_url);
        allocator.free(self.rollback_command);
    }
};

/// Build the dashboard for a specific deployment target
pub fn buildDashboard(allocator: mem.Allocator, target: DeployTarget) !BuildResult {
    const start_time = time.nanoTimestamp();

    // Determine build command based on target
    const build_cmd = switch (target) {
        .builtin, .local => "cd website && npm run build",
        .vercel => "cd website && npm run build",
        .netlify => "cd website && npm run build",
    };

    // Execute build command
    const result = try executeCommand(allocator, build_cmd);

    const build_time_ms = (time.nanoTimestamp() - start_time) / 1_000_000;

    if (result.exit_code != 0) {
        return BuildResult{
            .success = false,
            .output_dir = "",
            .build_time_ms = build_time_ms,
            .error_message = try allocator.dupe(u8, result.stdout),
        };
    }

    // Calculate output directory size
    const output_dir = try fs.path.join(allocator, &[_][]const u8{ "website", "dist" });
    const size = try calculateDirectorySize(allocator, output_dir);

    return BuildResult{
        .success = true,
        .output_dir = output_dir,
        .build_time_ms = build_time_ms,
        .output_size_bytes = size,
    };
}

/// Deploy dashboard to the specified target
pub fn deployDashboard(allocator: mem.Allocator, config: DeployConfig) !DeployResult {
    const start_time = time.nanoTimestamp();

    // Step 1: Build the dashboard
    const build_result = try buildDashboard(allocator, config.target);
    if (!build_result.success) {
        return DeployResult{
            .success = false,
            .deploy_time_ms = (time.nanoTimestamp() - start_time) / 1_000_000,
            .error_message = build_result.error_message,
        };
    }

    // Step 2: Run pre-deployment health check (if applicable)
    if (config.environment != .dev) {
        const current_health = try runHealthCheck(config.health_check_url);
        if (current_health.healthy) {
            std.log.info("Current deployment is healthy, proceeding with deployment", .{});
        }
    }

    // Step 3: Deploy based on target
    const deploy_result = switch (config.target) {
        .builtin => try deployBuiltinServer(allocator, config),
        .local => DeployResult{
            .success = true,
            .url = "http://localhost:3000",
            .deploy_time_ms = (time.nanoTimestamp() - start_time) / 1_000_000,
        },
        else => try executeExternalDeploy(allocator, &config),
    };

    // Step 4: Run post-deployment health check
    if (deploy_result.success and deploy_result.url != null) {
        const health_check_url = try getHealthCheckUrl(allocator, deploy_result.url.?);
        defer allocator.free(health_check_url);

        const health = try runHealthCheck(health_check_url);
        if (!health.healthy) {
            std.log.err("Deployment failed health check, initiating rollback", .{});
            try rollbackDeployment(allocator, config);

            return DeployResult{
                .success = false,
                .deploy_time_ms = (time.nanoTimestamp() - start_time) / 1_000_000,
                .error_message = try allocator.dupe(u8, "Health check failed"),
                .rollback_performed = true,
            };
        }
    }

    return deploy_result;
}

/// Execute deployment to external platform (Vercel/Netlify)
fn executeExternalDeploy(allocator: mem.Allocator, config: *const DeployConfig) !DeployResult {
    const start_time = time.nanoTimestamp();

    const result = try executeCommand(allocator, config.deploy_command);

    const deploy_time_ms = (time.nanoTimestamp() - start_time) / 1_000_000;

    if (result.exit_code != 0) {
        return DeployResult{
            .success = false,
            .deploy_time_ms = deploy_time_ms,
            .error_message = try allocator.dupe(u8, result.stdout),
        };
    }

    // Extract deployment URL from output
    const url = try extractDeploymentUrl(allocator, result.stdout);

    return DeployResult{
        .success = true,
        .url = url,
        .deploy_time_ms = deploy_time_ms,
        .deployment_id = try extractDeploymentId(allocator, result.stdout),
    };
}

/// Deploy using built-in HTTP server
pub fn deployBuiltinServer(allocator: mem.Allocator, config: DeployConfig) !DeployResult {
    const start_time = time.nanoTimestamp();

    var server = try BuiltinServer.init(allocator, "127.0.0.1", config.builtin_port);
    defer server.deinit();

    try server.start();

    const deploy_time_ms = (time.nanoTimestamp() - start_time) / 1_000_000;

    const url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{config.builtin_port});

    return DeployResult{
        .success = true,
        .url = url,
        .deploy_time_ms = deploy_time_ms,
        .deployment_id = null,
    };
}

/// Run health check on deployed dashboard
pub fn runHealthCheck(url: []const u8) !HealthStatus {
    const start_time = time.nanoTimestamp();

    // Parse URL
    const uri = try std.Uri.parse(url);

    // Create HTTP client
    var client = http.Client{ .allocator = std.heap.page_allocator };
    defer client.deinit();

    // Create request
    var headers = http.Headers{ .allocator = std.heap.page_allocator };
    defer headers.deinit();

    try headers.append("Accept", "application/json");
    try headers.append("User-Agent", "Trinity-Deploy/1.0");

    // Execute request
    const response = blk: {
        const destination = try client.resolveDestination(uri);
        break :blk try client.open(.GET, destination, headers, .{});
    };
    defer response.deinit();

    try response.send();
    try response.wait();

    const response_time_ms = (time.nanoTimestamp() - start_time) / 1_000_000;

    // Check status code
    const status_code = response.status.code;
    const healthy = status_code >= 200 and status_code < 300;

    // Read response body
    const body = try response.reader().readAllAlloc(std.heap.page_allocator, 1024 * 1024);
    defer std.heap.page_allocator.free(body);

    // Extract version from JSON response
    const version = try extractVersionFromJson(body);

    return HealthStatus{
        .healthy = healthy,
        .status_code = status_code,
        .response_time_ms = response_time_ms,
        .version = version,
        .error_message = if (healthy) null else try std.fmt.allocPrint(std.heap.page_allocator, "HTTP {d}", .{status_code}),
    };
}

/// Rollback deployment to previous version
pub fn rollbackDeployment(allocator: mem.Allocator, config: DeployConfig) !void {
    std.log.warn("Initiating rollback for {s} deployment", .{config.target.toString()});

    const result = try executeCommand(allocator, config.rollback_command);

    if (result.exit_code != 0) {
        return error.RollbackFailed;
    }

    std.log.info("Rollback completed successfully", .{});
}

/// Configure environment variables for deployment
pub fn configureEnvironment(allocator: mem.Allocator, env: Environment) ![]const u8 {
    const config = switch (env) {
        .dev =>
        \\NODE_ENV=development
        \\VITE_API_URL=http://localhost:8080
        \\VITE_WS_URL=ws://localhost:8080
        ,
        .staging =>
        \\NODE_ENV=staging
        \\VITE_API_URL=https://staging-api.trinity.dev
        \\VITE_WS_URL=wss://staging-api.trinity.dev
        ,
        .production =>
        \\NODE_ENV=production
        \\VITE_API_URL=https://api.trinity.dev
        \\VITE_WS_URL=wss://api.trinity.dev
        ,
    };

    return try allocator.dupe(u8, config);
}

/// Built-in HTTP server for serving the dashboard
pub const BuiltinServer = struct {
    allocator: mem.Allocator,
    address: []const u8,
    port: u16,
    running: bool,
    server: ?net.Server,
    static_file_dir: []const u8,
    serve_thread: ?std.Thread = null,

    /// Initialize the built-in server
    pub fn init(allocator: mem.Allocator, address: []const u8, port: u16) !BuiltinServer {
        return BuiltinServer{
            .allocator = allocator,
            .address = try allocator.dupe(u8, address),
            .port = port,
            .running = false,
            .server = null,
            .static_file_dir = try allocator.dupe(u8, "website/dist"),
        };
    }

    /// Deinitialize the server
    pub fn deinit(self: *BuiltinServer) void {
        if (self.server) |*s| {
            s.deinit();
            self.server = null;
        }
        self.allocator.free(self.address);
        self.allocator.free(self.static_file_dir);
    }

    /// Start the server
    pub fn start(self: *BuiltinServer) !void {
        const address = try net.Address.parseIp(self.address, self.port);
        self.server = try address.listen(.{ .reuse_address = true });
        self.running = true;

        std.log.info("Server started on http://{s}:{d}", .{ self.address, self.port });

        // Serve files in background thread
        self.serve_thread = try std.Thread.spawn(.{}, struct {
            fn run(server: *BuiltinServer) !void {
                while (server.running) {
                    server.acceptAndServe() catch |err| {
                        std.log.err("Error serving connection: {}", .{err});
                    };
                }
            }
        }.run, .{self});
    }

    /// Stop the server
    pub fn stop(self: *BuiltinServer) !void {
        self.running = false;
        if (self.server) |s| {
            s.deinit();
            self.server = null;
        }
        if (self.serve_thread) |t| {
            t.join();
            self.serve_thread = null;
        }
        std.log.info("Server stopped", .{});
    }

    /// Accept and serve a single connection
    fn acceptAndServe(self: *BuiltinServer) !void {
        const server = self.server orelse return error.ServerNotRunning;
        const connection = try server.accept();
        defer connection.stream.close();

        var buffer: [4096]u8 = undefined;
        const request_data = try connection.stream.read(&buffer);

        // Parse HTTP request
        const request_str = buffer[0..request_data];
        var lines = mem.splitScalar(u8, request_str, '\n');

        // Parse request line
        const request_line = lines.first();
        var parts = mem.splitScalar(u8, request_line, ' ');
        const method = parts.first();
        _ = method; // Currently unused
        const path = parts.next() orelse "/";

        // Serve file
        self.serveFile(&connection.stream, path) catch |err| {
            std.log.err("Error serving file: {}", .{err});
            try self.serveError(&connection.stream, 500);
        };
    }

    /// Serve a static file
    fn serveFile(self: *BuiltinServer, stream: *net.Stream, path: []const u8) !void {
        // Remove query string
        const clean_path = blk: {
            if (mem.indexOfScalar(u8, path, '?')) |idx| {
                break :blk path[0..idx];
            }
            break :blk path;
        };

        // Default to index.html
        const file_path = if (mem.eql(u8, clean_path, "/"))
            "index.html"
        else if (clean_path[0] == '/')
            clean_path[1..]
        else
            clean_path;

        // Full path to file
        const full_path = try fs.path.join(self.allocator, &[_][]const u8{ self.static_file_dir, file_path });
        defer self.allocator.free(full_path);

        // Check if file exists
        const file = fs.cwd().openFile(full_path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                // Try index.html for SPA routing
                const index_path = try fs.path.join(self.allocator, &[_][]const u8{ self.static_file_dir, "index.html" });
                defer self.allocator.free(index_path);

                if (fs.cwd().openFile(index_path, .{})) |index_file| {
                    defer index_file.close();
                    const content = try index_file.reader().readAllAlloc(self.allocator, 10 * 1024 * 1024);
                    defer self.allocator.free(content);

                    try stream.writeAll("HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: ");
                    try stream.writer().print("{d}\r\n\r\n", .{content.len});
                    try stream.writeAll(content);
                    return;
                } else |_| {
                    try self.serveError(stream, 404);
                    return;
                }
            }
            return err;
        };
        defer file.close();

        const content = try file.reader().readAllAlloc(self.allocator, 10 * 1024 * 1024);
        defer self.allocator.free(content);

        // Determine content type
        const content_type = getContentType(file_path);

        // Send HTTP response
        try stream.writeAll("HTTP/1.1 200 OK\r\nContent-Type: ");
        try stream.writeAll(content_type);
        try stream.writer().print("\r\nContent-Length: {d}\r\n\r\n", .{content.len});
        try stream.writeAll(content);
    }

    /// Serve an error response
    fn serveError(self: *BuiltinServer, stream: *net.Stream, status_code: u16) !void {
        const body = try std.fmt.allocPrint(self.allocator, "Error {d}", .{status_code});
        defer self.allocator.free(body);

        try stream.writer().print("HTTP/1.1 {d} Error\r\nContent-Length: {d}\r\n\r\n{s}", .{ status_code, body.len, body });
    }
};

/// Get content type for a file
fn getContentType(path: []const u8) []const u8 {
    if (mem.endsWith(u8, path, ".html")) return "text/html";
    if (mem.endsWith(u8, path, ".js")) return "application/javascript";
    if (mem.endsWith(u8, path, ".css")) return "text/css";
    if (mem.endsWith(u8, path, ".json")) return "application/json";
    if (mem.endsWith(u8, path, ".png")) return "image/png";
    if (mem.endsWith(u8, path, ".jpg")) return "image/jpeg";
    if (mem.endsWith(u8, path, ".svg")) return "image/svg+xml";
    if (mem.endsWith(u8, path, ".woff")) return "font/woff";
    if (mem.endsWith(u8, path, ".woff2")) return "font/woff2";
    return "application/octet-stream";
}

/// Execute a shell command and capture output
fn executeCommand(allocator: mem.Allocator, command: []const u8) !struct { exit_code: u8, stdout: []const u8 } {
    var child = process.Child.init(&[_][]const u8{ "sh", "-c", command }, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    const stdout = try child.stdout.?.reader().readAllAlloc(allocator, 1024 * 1024);
    const stderr = try child.stderr.?.reader().readAllAlloc(allocator, 1024 * 1024);

    const term = try child.wait();

    // Combine stdout and stderr for error messages
    if (term.Exited != 0) {
        allocator.free(stderr);
        return .{ .exit_code = term.Exited, .stdout = stdout };
    }

    allocator.free(stderr);
    return .{ .exit_code = term.Exited, .stdout = stdout };
}

/// Extract deployment URL from command output
fn extractDeploymentUrl(allocator: mem.Allocator, output: []const u8) ![]const u8 {
    var lines = mem.splitScalar(u8, output, '\n');

    while (lines.next()) |line| {
        // Look for URLs in output
        if (mem.indexOf(u8, line, "https://")) |start| {
            if (mem.indexOfPos(u8, line, start, " ")) |end| {
                return allocator.dupe(u8, line[start..end]);
            }
            // If no space, take rest of line
            return allocator.dupe(u8, line[start..]);
        }
    }

    // Return default URL if extraction fails
    return allocator.dupe(u8, "https://ghashag.github.io/trinity/");
}

/// Extract deployment ID from command output
fn extractDeploymentId(allocator: mem.Allocator, output: []const u8) ![]const u8 {
    _ = output;
    // Platform-specific ID extraction
    return allocator.dupe(u8, "unknown");
}

/// Extract version from JSON response
fn extractVersionFromJson(body: []const u8) !?[]const u8 {
    if (mem.indexOf(u8, body, "\"version\"")) |idx| {
        // Find the colon after "version"
        const colon_idx = mem.indexOfPos(u8, body, idx, ":") orelse return null;
        // Find the opening quote of the version value
        const start = mem.indexOfPos(u8, body, colon_idx, "\"") orelse return null;
        // Find the closing quote
        const end = mem.indexOfPos(u8, body, start + 1, "\"") orelse return null;
        return body[start + 1 .. end];
    }
    return null;
}

/// Get health check URL from deployment URL
fn getHealthCheckUrl(allocator: mem.Allocator, deploy_url: []const u8) ![]const u8 {
    // Remove trailing slash and add /health
    const trimmed = if (mem.endsWith(u8, deploy_url, "/"))
        deploy_url[0 .. deploy_url.len - 1]
    else
        deploy_url;

    return std.fmt.allocPrint(allocator, "{s}/health", .{trimmed});
}

/// Calculate directory size
fn calculateDirectorySize(allocator: mem.Allocator, dir_path: []const u8) !usize {
    var dir = try fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var total_size: usize = 0;
    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind == .file) {
            const file = try dir.openFile(entry.path, .{});
            const stat = try file.stat();
            total_size += stat.size;
            file.close();
        }
    }

    return total_size;
}

// ==================== Tests ====================

test "DeployTarget toString" {
    try testing.expectEqualStrings("vercel", DeployTarget.vercel.toString());
    try testing.expectEqualStrings("netlify", DeployTarget.netlify.toString());
    try testing.expectEqualStrings("builtin", DeployTarget.builtin.toString());
    try testing.expectEqualStrings("local", DeployTarget.local.toString());
}

test "DeployTarget fromString" {
    try testing.expectEqual(DeployTarget.vercel, try DeployTarget.fromString("vercel"));
    try testing.expectEqual(DeployTarget.netlify, try DeployTarget.fromString("netlify"));
    try testing.expectEqual(DeployTarget.builtin, try DeployTarget.fromString("builtin"));
    try testing.expectEqual(DeployTarget.local, try DeployTarget.fromString("local"));

    try testing.expectError(error.InvalidDeployTarget, DeployTarget.fromString("invalid"));
}

test "Environment toString" {
    try testing.expectEqualStrings("dev", Environment.dev.toString());
    try testing.expectEqualStrings("staging", Environment.staging.toString());
    try testing.expectEqualStrings("production", Environment.production.toString());
}

test "Environment fromString" {
    try testing.expectEqual(Environment.dev, try Environment.fromString("dev"));
    try testing.expectEqual(Environment.staging, try Environment.fromString("staging"));
    try testing.expectEqual(Environment.production, try Environment.fromString("production"));

    try testing.expectError(error.InvalidEnvironment, Environment.fromString("invalid"));
}

test "Environment getEnvVar" {
    try testing.expectEqualStrings("NODE_ENV=development", Environment.dev.getEnvVar());
    try testing.expectEqualStrings("NODE_ENV=staging", Environment.staging.getEnvVar());
    try testing.expectEqualStrings("NODE_ENV=production", Environment.production.getEnvVar());
}

test "getContentType" {
    try testing.expectEqualStrings("text/html", getContentType("index.html"));
    try testing.expectEqualStrings("application/javascript", getContentType("app.js"));
    try testing.expectEqualStrings("text/css", getContentType("style.css"));
    try testing.expectEqualStrings("application/json", getContentType("data.json"));
    try testing.expectEqualStrings("image/png", getContentType("image.png"));
    try testing.expectEqualStrings("application/octet-stream", getContentType("unknown.xyz"));
}

test "extractVersionFromJson" {
    const json1 = "{\"status\":\"healthy\",\"version\":\"1.0.0\"}";
    const version1 = try extractVersionFromJson(json1);
    try testing.expect(version1 != null);
    try testing.expectEqualStrings("1.0.0", version1.?);

    const json2 = "{\"status\":\"healthy\"}";
    const version2 = try extractVersionFromJson(json2);
    try testing.expect(version2 == null);
}

test "getHealthCheckUrl" {
    const allocator = testing.allocator;

    const url1 = try getHealthCheckUrl(allocator, "https://example.com");
    defer allocator.free(url1);
    try testing.expectEqualStrings("https://example.com/health", url1);

    const url2 = try getHealthCheckUrl(allocator, "https://example.com/");
    defer allocator.free(url2);
    try testing.expectEqualStrings("https://example.com/health", url2);
}

test "DeployConfig initDefault" {
    const allocator = testing.allocator;

    var config = try DeployConfig.initDefault(allocator, .vercel, .production);
    defer config.deinit(allocator);

    try testing.expectEqual(.vercel, config.target);
    try testing.expectEqual(.production, config.environment);
    try testing.expectEqual(@as(u16, 3000), config.builtin_port);
}

test "BuiltinServer init" {
    const allocator = testing.allocator;

    var server = try BuiltinServer.init(allocator, "127.0.0.1", 8080);
    defer server.deinit();

    try testing.expectEqualStrings("127.0.0.1", server.address);
    try testing.expectEqual(@as(u16, 8080), server.port);
    try testing.expect(!server.running);
    try testing.expect(server.server == null);
}

test "configureEnvironment" {
    const allocator = testing.allocator;

    const dev_config = try configureEnvironment(allocator, .dev);
    defer allocator.free(dev_config);
    try testing.expect(mem.indexOf(u8, dev_config, "NODE_ENV=development") != null);

    const staging_config = try configureEnvironment(allocator, .staging);
    defer allocator.free(staging_config);
    try testing.expect(mem.indexOf(u8, staging_config, "NODE_ENV=staging") != null);

    const prod_config = try configureEnvironment(allocator, .production);
    defer allocator.free(prod_config);
    try testing.expect(mem.indexOf(u8, prod_config, "NODE_ENV=production") != null);
}

test "BuildResult format" {
    const result = BuildResult{
        .success = true,
        .output_dir = "/dist",
        .build_time_ms = 1000,
        .output_size_bytes = 1024,
    };

    const allocator = testing.allocator;
    const formatted = try std.fmt.allocPrint(allocator, "{any}", .{result});
    defer allocator.free(formatted);

    // Check that the output contains expected field names and values
    try testing.expect(mem.indexOf(u8, formatted, "success") != null);
    try testing.expect(mem.indexOf(u8, formatted, "true") != null);
    try testing.expect(mem.indexOf(u8, formatted, "build_time_ms") != null);
    try testing.expect(mem.indexOf(u8, formatted, "1000") != null);
}

test "DeployResult format" {
    const result = DeployResult{
        .success = true,
        .url = "https://example.com",
        .deploy_time_ms = 2000,
        .deployment_id = "deploy-123",
    };

    const allocator = testing.allocator;
    const formatted = try std.fmt.allocPrint(allocator, "{any}", .{result});
    defer allocator.free(formatted);

    // Check that the output contains expected field names and values
    try testing.expect(mem.indexOf(u8, formatted, "success") != null);
    try testing.expect(mem.indexOf(u8, formatted, "true") != null);
    try testing.expect(mem.indexOf(u8, formatted, "deploy_time_ms") != null);
    try testing.expect(mem.indexOf(u8, formatted, "2000") != null);
}

test "HealthStatus format" {
    const status = HealthStatus{
        .healthy = true,
        .status_code = 200,
        .response_time_ms = 100,
        .version = "1.0.0",
    };

    const allocator = testing.allocator;
    const formatted = try std.fmt.allocPrint(allocator, "{any}", .{status});
    defer allocator.free(formatted);

    // Check that the output contains expected field names and values
    try testing.expect(mem.indexOf(u8, formatted, "healthy") != null);
    try testing.expect(mem.indexOf(u8, formatted, "true") != null);
    try testing.expect(mem.indexOf(u8, formatted, "status_code") != null);
    try testing.expect(mem.indexOf(u8, formatted, "200") != null);
}
