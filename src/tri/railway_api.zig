// @origin(spec:railway_api.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// RAILWAY API — GraphQL Client for Railway.app
// ═══════════════════════════════════════════════════════════════════════════════
//
// Native GraphQL client for backboard.railway.com/graphql/v2
// Zero dependency on `railway` CLI binary.
//
// Auth: RAILWAY_API_TOKEN env var (Personal Token)
// Project: .railway.json or RAILWAY_PROJECT_ID env
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const RAILWAY_GQL_HOST = "backboard.railway.com";
const RAILWAY_GQL_PATH = "/graphql/v2";

const RESET = "\x1b[0m";
const RED = "\x1b[31m";

pub const RailwayApiError = error{
    MissingToken,
    MissingProjectId,
    InvalidUrl,
    ConnectionFailed,
    RequestFailed,
    ApiError,
    NotAuthorized,
    Timeout,
    OutOfMemory,
    InvalidJson,
};

pub const RailwayApi = struct {
    allocator: Allocator,
    token: []const u8,
    project_id: []const u8,
    environment_id: []const u8,

    const Self = @This();

    /// Initialize from environment variables and .railway.json
    pub fn init(allocator: Allocator) RailwayApiError!RailwayApi {
        return initWithSuffix(allocator, "");
    }

    /// Initialize from suffixed environment variables (multi-account support).
    /// suffix="" reads RAILWAY_API_TOKEN, RAILWAY_PROJECT_ID, RAILWAY_ENVIRONMENT_ID
    /// suffix="_2" reads RAILWAY_API_TOKEN_2, RAILWAY_PROJECT_ID_2, RAILWAY_ENVIRONMENT_ID_2
    pub fn initWithSuffix(allocator: Allocator, suffix: []const u8) RailwayApiError!RailwayApi {
        var token_name: [64]u8 = undefined;
        const token_key = buildEnvKey(&token_name, "RAILWAY_API_TOKEN", suffix);
        const token = std.process.getEnvVarOwned(allocator, token_key) catch
            return error.MissingToken;

        var proj_name: [64]u8 = undefined;
        const proj_key = buildEnvKey(&proj_name, "RAILWAY_PROJECT_ID", suffix);
        const project_id = std.process.getEnvVarOwned(allocator, proj_key) catch blk: {
            if (suffix.len == 0) {
                break :blk readProjectIdFromFile(allocator) catch return error.MissingProjectId;
            }
            return error.MissingProjectId;
        };

        var env_name: [64]u8 = undefined;
        const env_key = buildEnvKey(&env_name, "RAILWAY_ENVIRONMENT_ID", suffix);
        const environment_id = std.process.getEnvVarOwned(allocator, env_key) catch
            allocator.dupe(u8, "") catch return error.OutOfMemory;

        return .{
            .allocator = allocator,
            .token = token,
            .project_id = project_id,
            .environment_id = environment_id,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.token);
        self.allocator.free(self.project_id);
        self.allocator.free(self.environment_id);
    }

    /// Execute a GraphQL query/mutation against Railway API.
    /// The gql string is JSON-escaped automatically.
    pub fn query(self: *Self, gql: []const u8, variables_json: ?[]const u8) RailwayApiError![]const u8 {
        // JSON-escape the GraphQL query (handle newlines, quotes, backslashes)
        const escaped_gql = jsonEscapeAlloc(self.allocator, gql) catch return error.OutOfMemory;
        defer self.allocator.free(escaped_gql);

        const body = if (variables_json) |vars|
            std.fmt.allocPrint(self.allocator, "{{\"query\":\"{s}\",\"variables\":{s}}}", .{
                escaped_gql, vars,
            }) catch return error.OutOfMemory
        else
            std.fmt.allocPrint(self.allocator, "{{\"query\":\"{s}\"}}", .{
                escaped_gql,
            }) catch return error.OutOfMemory;
        defer self.allocator.free(body);

        return self.httpPost(body);
    }

    /// List all services in the project.
    pub fn getServices(self: *Self) RailwayApiError![]const u8 {
        const gql = "query($projectId: String!) { project(id: $projectId) { services { edges { node { id name updatedAt } } } } }";
        const vars = std.fmt.allocPrint(self.allocator, "{{\"projectId\":\"{s}\"}}", .{self.project_id}) catch
            return error.OutOfMemory;
        defer self.allocator.free(vars);
        return self.query(gql, vars);
    }

    /// Get latest deployments for a service.
    pub fn getDeployments(self: *Self, service_id: []const u8) RailwayApiError![]const u8 {
        const gql = "query($projectId: String!, $serviceId: String!) { deployments(input: { projectId: $projectId, serviceId: $serviceId }, first: 5) { edges { node { id status createdAt } } } }";
        const vars = std.fmt.allocPrint(self.allocator, "{{\"projectId\":\"{s}\",\"serviceId\":\"{s}\"}}", .{
            self.project_id, service_id,
        }) catch return error.OutOfMemory;
        defer self.allocator.free(vars);
        return self.query(gql, vars);
    }

    /// Get environment variables for a service.
    pub fn getVariables(self: *Self, service_id: []const u8, environment_id: []const u8) RailwayApiError![]const u8 {
        const gql = "query($projectId: String!, $serviceId: String!, $environmentId: String!) { variables(projectId: $projectId, serviceId: $serviceId, environmentId: $environmentId) }";
        const vars = std.fmt.allocPrint(self.allocator, "{{\"projectId\":\"{s}\",\"serviceId\":\"{s}\",\"environmentId\":\"{s}\"}}", .{
            self.project_id, service_id, environment_id,
        }) catch return error.OutOfMemory;
        defer self.allocator.free(vars);
        return self.query(gql, vars);
    }

    /// Upsert an environment variable.
    pub fn upsertVariable(self: *Self, service_id: []const u8, environment_id: []const u8, key: []const u8, value: []const u8) RailwayApiError!void {
        const gql = "mutation($input: VariableUpsertInput!) { variableUpsert(input: $input) }";
        const vars = std.fmt.allocPrint(self.allocator,
            \\{{"input":{{"projectId":"{s}","serviceId":"{s}","environmentId":"{s}","name":"{s}","value":"{s}"}}}}
        , .{
            self.project_id, service_id, environment_id, key, value,
        }) catch return error.OutOfMemory;
        defer self.allocator.free(vars);
        const resp = try self.query(gql, vars);
        self.allocator.free(resp);
    }

    /// Create a new service in the project.
    pub fn createService(self: *Self, name: []const u8) RailwayApiError![]const u8 {
        return self.createServiceWithRepo(name, "", "");
    }

    /// Create a new service with GitHub repo source attached.
    pub fn createServiceWithRepo(self: *Self, name: []const u8, repo: []const u8, branch: []const u8) RailwayApiError![]const u8 {
        const gql = "mutation($input: ServiceCreateInput!) { serviceCreate(input: $input) { id name } }";
        const vars = if (repo.len > 0 and branch.len > 0)
            std.fmt.allocPrint(self.allocator, "{{\"input\":{{\"projectId\":\"{s}\",\"name\":\"{s}\",\"source\":{{\"repo\":\"{s}\"}},\"branch\":\"{s}\"}}}}", .{
                self.project_id, name, repo, branch,
            }) catch return error.OutOfMemory
        else if (repo.len > 0)
            std.fmt.allocPrint(self.allocator, "{{\"input\":{{\"projectId\":\"{s}\",\"name\":\"{s}\",\"source\":{{\"repo\":\"{s}\"}}}}}}", .{
                self.project_id, name, repo,
            }) catch return error.OutOfMemory
        else
            std.fmt.allocPrint(self.allocator, "{{\"input\":{{\"projectId\":\"{s}\",\"name\":\"{s}\"}}}}", .{
                self.project_id, name,
            }) catch return error.OutOfMemory;
        defer self.allocator.free(vars);
        return self.query(gql, vars);
    }

    /// Update service instance region to a Metal region (e.g. "us-west4" = California Metal).
    /// Uses serviceInstanceUpdate + multiRegionConfig API.
    pub fn serviceInstanceUpdateRegion(self: *Self, service_id: []const u8, environment_id_override: []const u8, region: []const u8) RailwayApiError![]const u8 {
        const env_id = if (environment_id_override.len > 0) environment_id_override else self.environment_id;
        const gql = "mutation($serviceId: String!, $environmentId: String!, $input: ServiceInstanceUpdateInput!) { serviceInstanceUpdate(serviceId: $serviceId, environmentId: $environmentId, input: $input) }";
        const vars = std.fmt.allocPrint(self.allocator, "{{\"serviceId\":\"{s}\",\"environmentId\":\"{s}\",\"input\":{{\"multiRegionConfig\":{{\"{s}\":{{\"numReplicas\":1}}}}}}}}", .{
            service_id, env_id, region,
        }) catch return error.OutOfMemory;
        defer self.allocator.free(vars);
        return self.query(gql, vars);
    }

    /// Get service instance details (region, replicas, etc).
    pub fn getServiceInstances(self: *Self, environment_id_override: []const u8) RailwayApiError![]const u8 {
        const env_id = if (environment_id_override.len > 0) environment_id_override else self.environment_id;
        const gql = "query($environmentId: String!) { environment(id: $environmentId) { serviceInstances { edges { node { serviceName region latestDeployment { id status } } } } } }";
        const vars = std.fmt.allocPrint(self.allocator, "{{\"environmentId\":\"{s}\"}}", .{env_id}) catch
            return error.OutOfMemory;
        defer self.allocator.free(vars);
        return self.query(gql, vars);
    }

    /// Delete a service by ID.
    pub fn deleteService(self: *Self, service_id: []const u8) RailwayApiError!void {
        const gql = "mutation($id: String!) { serviceDelete(id: $id) }";
        const vars = std.fmt.allocPrint(self.allocator, "{{\"id\":\"{s}\"}}", .{service_id}) catch
            return error.OutOfMemory;
        defer self.allocator.free(vars);
        const resp = try self.query(gql, vars);
        self.allocator.free(resp);
    }

    /// Connect a service to a Docker image source.
    pub fn connectServiceSource(self: *Self, service_id: []const u8, image: []const u8) RailwayApiError!void {
        const gql = "mutation($id: String!, $input: ServiceConnectInput!) { serviceConnect(id: $id, input: $input) { id } }";
        const vars = std.fmt.allocPrint(self.allocator, "{{\"id\":\"{s}\",\"input\":{{\"source\":{{\"image\":\"{s}\"}}}}}}", .{
            service_id, image,
        }) catch return error.OutOfMemory;
        defer self.allocator.free(vars);
        const resp = try self.query(gql, vars);
        self.allocator.free(resp);
    }

    /// Connect a service to a GitHub repo source.
    pub fn connectServiceRepo(self: *Self, service_id: []const u8, repo: []const u8, branch: []const u8) RailwayApiError![]const u8 {
        _ = branch; // Railway auto-detects default branch
        const gql = "mutation($id: String!, $input: ServiceConnectInput!) { serviceConnect(id: $id, input: $input) { id } }";
        const vars = std.fmt.allocPrint(self.allocator, "{{\"id\":\"{s}\",\"input\":{{\"source\":{{\"repo\":\"{s}\"}}}}}}", .{
            service_id, repo,
        }) catch return error.OutOfMemory;
        defer self.allocator.free(vars);
        return self.query(gql, vars);
    }

    /// Redeploy a service (trigger new deployment from latest).
    pub fn redeployService(self: *Self, service_id: []const u8, environment_id: []const u8) RailwayApiError![]const u8 {
        const env_id = if (environment_id.len > 0) environment_id else self.environment_id;
        const gql = "mutation($serviceId: String!, $environmentId: String!) { serviceInstanceDeploy(serviceId: $serviceId, environmentId: $environmentId) }";
        const vars = std.fmt.allocPrint(self.allocator, "{{\"serviceId\":\"{s}\",\"environmentId\":\"{s}\"}}", .{
            service_id, env_id,
        }) catch return error.OutOfMemory;
        defer self.allocator.free(vars);
        return self.query(gql, vars);
    }

    pub fn getDeploymentLogs(self: *Self, deployment_id: []const u8, limit: u32) RailwayApiError![]const u8 {
        const gql = "query($deploymentId: String!, $limit: Int) { deploymentLogs(deploymentId: $deploymentId, limit: $limit) { timestamp message severity } }";
        const vars = std.fmt.allocPrint(self.allocator, "{{\"deploymentId\":\"{s}\",\"limit\":{d}}}", .{
            deployment_id, limit,
        }) catch return error.OutOfMemory;
        defer self.allocator.free(vars);
        return self.query(gql, vars);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Internal: HTTP transport (follows github_client.zig:283-349 pattern)
    // ═══════════════════════════════════════════════════════════════════════════

    fn httpPost(self: *Self, body: []const u8) RailwayApiError![]const u8 {
        // HTTP client with 5-second connection timeout for graceful degradation
        var client = std.http.Client{
            .allocator = self.allocator,
        };
        defer client.deinit();

        const uri_str = std.fmt.allocPrint(self.allocator, "https://{s}{s}", .{ RAILWAY_GQL_HOST, RAILWAY_GQL_PATH }) catch
            return error.OutOfMemory;
        defer self.allocator.free(uri_str);

        const uri = std.Uri.parse(uri_str) catch return error.InvalidUrl;

        var auth_buf: [512]u8 = undefined;
        const auth_val = std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{self.token}) catch
            return error.OutOfMemory;

        const extra_headers = [_]std.http.Header{
            .{ .name = "User-Agent", .value = "trinity-cli/1.0" },
            .{ .name = "Content-Type", .value = "application/json" },
            .{ .name = "Authorization", .value = auth_val },
            .{ .name = "Accept-Encoding", .value = "identity" },
        };

        var req = client.request(.POST, uri, .{
            .extra_headers = &extra_headers,
            .redirect_behavior = .unhandled,
        }) catch return error.ConnectionFailed;
        defer req.deinit();

        req.transfer_encoding = .{ .content_length = body.len };
        var body_writer = req.sendBodyUnflushed(&.{}) catch return error.RequestFailed;
        body_writer.writer.writeAll(body) catch return error.RequestFailed;
        body_writer.end() catch return error.RequestFailed;
        if (req.connection) |conn| conn.flush() catch return error.RequestFailed;

        var redirect_buf: [0]u8 = .{};
        var response = req.receiveHead(&redirect_buf) catch return error.RequestFailed;

        const status_code = @intFromEnum(response.head.status);
        if (status_code != 200) {
            // Check for auth errors specifically (401 Unauthorized, 403 Forbidden)
            if (status_code == 401 or status_code == 403) {
                return error.NotAuthorized;
            }

            // Read error body for diagnostics
            var err_buf: [8192]u8 = undefined;
            var err_reader = response.reader(&err_buf);
            const err_body = err_reader.allocRemaining(self.allocator, std.Io.Limit.limited(8192)) catch "";
            if (err_body.len > 0) {
                // Decompress if gzip
                if (err_body.len >= 2 and err_body[0] == 0x1f and err_body[1] == 0x8b) {
                    var ir: std.Io.Reader = .fixed(err_body);
                    var dbuf: [std.compress.flate.max_window_len]u8 = undefined;
                    var d: std.compress.flate.Decompress = .init(&ir, .gzip, &dbuf);
                    const dec = d.reader.allocRemaining(self.allocator, std.Io.Limit.limited(8192)) catch "";
                    if (dec.len > 0) {
                        std.debug.print("{s}Railway API error: HTTP {d}: {s}{s}\n", .{ RED, status_code, dec, RESET });
                        self.allocator.free(dec);
                    } else {
                        std.debug.print("{s}Railway API error: HTTP {d}{s}\n", .{ RED, status_code, RESET });
                    }
                } else {
                    std.debug.print("{s}Railway API error: HTTP {d}: {s}{s}\n", .{ RED, status_code, err_body, RESET });
                }
                if (err_body.len > 0) self.allocator.free(err_body);
            } else {
                std.debug.print("{s}Railway API error: HTTP {d}{s}\n", .{ RED, status_code, RESET });
            }
            return error.ApiError;
        }

        var transfer_buffer: [8192]u8 = undefined;
        var reader = response.reader(&transfer_buffer);
        const raw_body = reader.allocRemaining(self.allocator, std.Io.Limit.limited(1 * 1024 * 1024)) catch
            return error.OutOfMemory;

        // Check if response is gzip-compressed (starts with 0x1f 0x8b)
        if (raw_body.len >= 2 and raw_body[0] == 0x1f and raw_body[1] == 0x8b) {
            var input_reader: std.Io.Reader = .fixed(raw_body);
            var decompress_buffer: [std.compress.flate.max_window_len]u8 = undefined;
            var decomp: std.compress.flate.Decompress = .init(&input_reader, .gzip, &decompress_buffer);
            const decompressed = decomp.reader.allocRemaining(self.allocator, std.Io.Limit.unlimited) catch {
                // If decompress fails, return raw
                return raw_body;
            };
            self.allocator.free(raw_body);
            return decompressed;
        }

        return raw_body;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Internal: helpers
    // ═══════════════════════════════════════════════════════════════════════════

    fn buildEnvKey(buf: *[64]u8, base: []const u8, suffix: []const u8) []const u8 {
        const total = base.len + suffix.len;
        if (total > buf.len) {
            std.log.warn("railway_api: env key too long ({d} > 64): {s}+{s}", .{ total, base, suffix });
            // Truncate to base only — caller gets partial key
            const len = @min(base.len, buf.len);
            @memcpy(buf[0..len], base[0..len]);
            return buf[0..len];
        }
        @memcpy(buf[0..base.len], base);
        @memcpy(buf[base.len..total], suffix);
        return buf[0..total];
    }

    fn readProjectIdFromFile(allocator: Allocator) ![]const u8 {
        const file = std.fs.cwd().openFile(".railway.json", .{}) catch return error.MissingProjectId;
        defer file.close();
        const contents = file.readToEndAlloc(allocator, 64 * 1024) catch return error.MissingProjectId;
        defer allocator.free(contents);

        // Simple parse: find "project": "..." or "project":"..."
        const needle = "\"project\"";
        const idx = std.mem.indexOf(u8, contents, needle) orelse return error.MissingProjectId;
        const after = contents[idx + needle.len ..];
        // Skip : whitespace "
        var i: usize = 0;
        while (i < after.len and (after[i] == ':' or after[i] == ' ' or after[i] == '\t' or after[i] == '"')) : (i += 1) {}
        const start = i;
        while (i < after.len and after[i] != '"' and after[i] != ',' and after[i] != '}') : (i += 1) {}
        if (i == start) return error.MissingProjectId;
        return allocator.dupe(u8, after[start..i]);
    }
};

/// JSON-escape a string: handle \n, \r, \t, \", \\
fn jsonEscapeAlloc(allocator: Allocator, input: []const u8) ![]const u8 {
    // Count extra bytes needed
    var extra: usize = 0;
    for (input) |c| {
        switch (c) {
            '\n', '\r', '\t', '"', '\\' => extra += 1,
            else => {},
        }
    }
    if (extra == 0) return allocator.dupe(u8, input);

    const result = try allocator.alloc(u8, input.len + extra);
    var j: usize = 0;
    for (input) |c| {
        switch (c) {
            '\n' => {
                result[j] = '\\';
                result[j + 1] = 'n';
                j += 2;
            },
            '\r' => {
                result[j] = '\\';
                result[j + 1] = 'r';
                j += 2;
            },
            '\t' => {
                result[j] = '\\';
                result[j + 1] = 't';
                j += 2;
            },
            '"' => {
                result[j] = '\\';
                result[j + 1] = '"';
                j += 2;
            },
            '\\' => {
                result[j] = '\\';
                result[j + 1] = '\\';
                j += 2;
            },
            else => {
                result[j] = c;
                j += 1;
            },
        }
    }
    return result[0..j];
}

test "jsonEscapeAlloc basic" {
    const allocator = std.testing.allocator;
    const result = try jsonEscapeAlloc(allocator, "hello\nworld");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello\\nworld", result);
}

test "jsonEscapeAlloc no escape needed" {
    const allocator = std.testing.allocator;
    const result = try jsonEscapeAlloc(allocator, "simple query");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("simple query", result);
}
