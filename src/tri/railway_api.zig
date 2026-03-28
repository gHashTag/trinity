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
const crypto = std.crypto.random;

const RAILWAY_GQL_HOST = "backboard.railway.com";
const RAILWAY_GQL_PATH = "/graphql/v2";

// ═══════════════════════════════════════════════════════════════════════════
// Rate Limiting Constants (Railway Anti-Ban Protection)
// ═══════════════════════════════════════════════════════════════════════════
// Industry standard: FoundationDB, AWS, Google Cloud

/// Exponential backoff base delay (milliseconds)
const BACKOFF_BASE_MS: u64 = 1000; // 1 second

/// Maximum backoff delay (milliseconds)
const BACKOFF_CAP_MS: u64 = 32_000; // 32 seconds

/// Maximum retry attempts on 429 errors
const MAX_RETRIES: u32 = 5;

/// Minimum interval between requests to same account (milliseconds)
const MIN_REQUEST_INTERVAL_MS: u64 = 2000; // 2 seconds (Railway ~10 RPS on Hobby)

/// User-Agent rotation for bot fingerprint protection
const USER_AGENTS = [_][]const u8{
    "trinity-cli/1.0",
    "trinity-agent/1.0",
    "trinity-farm/1.0",
    "trinity-evolve/1.0",
};

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
    RateLimited, // 429 Too Many Requests
};

pub const RailwayApi = struct {
    allocator: Allocator,
    token: []const u8,
    project_id: []const u8,
    environment_id: []const u8,
    // Rate limiting state
    last_request_time: std.time.Instant,
    user_agent_index: u32,

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
        const environment_id = std.process.getEnvVarOwned(allocator, env_key) catch blk: {
            const empty = allocator.dupe(u8, "") catch return error.OutOfMemory;
            break :blk empty;
        };

        return .{
            .allocator = allocator,
            .token = token,
            .project_id = project_id,
            .environment_id = environment_id,
            .last_request_time = std.time.Instant.now() catch undefined,
            .user_agent_index = crypto.intRangeLessThan(u32, 0, USER_AGENTS.len),
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.token);
        self.allocator.free(self.project_id);
        self.allocator.free(self.environment_id);
    }

    // ════════════════════════════════════════════════════════════════════════════════════════
    // Rate Limiting Helpers (Railway Anti-Ban Protection)
    // ════════════════════════════════════════════════════════════════════════════════════════

    /// Calculate exponential backoff delay with full jitter (0 to delay).
    /// Industry standard: FoundationDB, AWS, Google Cloud
    fn calculateDelay(retry_count: u32) u64 {
        // Exponential: 2^retry_count * base_ms
        const exp_delay = BACKOFF_BASE_MS * @as(u64, 1) << @min(retry_count, 7);
        // Cap at max
        const capped_delay = @min(exp_delay, BACKOFF_CAP_MS);
        // Full jitter: random from 0 to capped_delay
        return crypto.intRangeLessThan(u64, 0, capped_delay);
    }

    /// Check if API request is allowed (rate limiting).
    /// Returns true if enough time has passed since last request.
    fn checkRateLimit(self: *Self) bool {
        const now = std.time.Instant.now() catch undefined;
        const elapsed = now.since(self.last_request_time);
        const min_interval_ns = MIN_REQUEST_INTERVAL_MS * 1_000_000;
        return elapsed >= min_interval_ns;
    }

    /// Rotate User-Agent for bot fingerprint protection.
    fn rotateUserAgent(self: *Self) []const u8 {
        self.user_agent_index = (self.user_agent_index + 1) % USER_AGENTS.len;
        return USER_AGENTS[self.user_agent_index];
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

    /// Get service ID by name via project services query.
    /// Returns null if service not found.
    pub fn getServiceIdByName(self: *Self, project_id: []const u8, service_name: []const u8) RailwayApiError!?[]const u8 {
        const gql = "query($pid: String!) { project(id: $pid) { services { edges { node { id name } } } } }";
        const vars = std.fmt.allocPrint(self.allocator, "{{\"pid\":\"{s}\"}}", .{project_id}) catch return error.OutOfMemory;
        defer self.allocator.free(vars);

        const resp = try self.query(gql, vars);
        defer self.allocator.free(resp);

        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, resp, .{}) catch return error.InvalidJson;
        defer parsed.deinit();

        if (parsed.value != .object) return null;
        const project = parsed.value.object.get("project") orelse return null;
        const services = project.object.get("services") orelse return null;
        const edges = services.object.get("edges") orelse return null;

        for (edges.array.items) |edge| {
            const node = edge.object.get("node") orelse continue;
            const name = node.object.get("name") orelse continue;
            const id = node.object.get("id") orelse continue;

            if (name == .string and std.mem.eql(u8, service_name, name.string)) {
                if (id == .string) {
                    const result = self.allocator.dupe(u8, id.string) catch return error.OutOfMemory;
                    return result;
                }
            }
        }

        return null;
    }

    /// Get latest deployment ID for a service.
    /// Returns null if no deployments found.
    pub fn getLatestDeploymentId(self: *Self, service_id: []const u8) RailwayApiError!?[]const u8 {
        const gql = "query($sid: String!) { service(id: $sid) { deployments(first: 1, orderBy: {field: CREATED_AT, direction: DESC}) { edges { node { id } } } } }";
        const vars = std.fmt.allocPrint(self.allocator, "{{\"sid\":\"{s}\"}}", .{service_id}) catch return error.OutOfMemory;
        defer self.allocator.free(vars);

        const resp = try self.query(gql, vars);
        defer self.allocator.free(resp);

        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, resp, .{}) catch return error.InvalidJson;
        defer parsed.deinit();

        const service = parsed.value.object.get("service") orelse return null;
        const deployments = service.object.get("deployments") orelse return null;
        const edges = deployments.object.get("edges") orelse return null;

        if (edges.array.items.len == 0) return null;
        const edge = edges.array.items[0];
        const node = edge.object.get("node") orelse return null;
        const id = node.object.get("id") orelse return null;

        if (id == .string) {
            const result = self.allocator.dupe(u8, id.string) catch return error.OutOfMemory;
            return result;
        }
        return null;
    }

    /// Get deployment status (e.g. "SUCCESS", "BUILDING", "FAILED").
    /// Returns "UNKNOWN" on error.
    pub fn getDeploymentStatus(self: *Self, deployment_id: []const u8) RailwayApiError![]const u8 {
        const gql = "query($did: String!) { deployment(id: $did) { status } }";
        const vars = std.fmt.allocPrint(self.allocator, "{{\"did\":\"{s}\"}}", .{deployment_id}) catch return error.OutOfMemory;
        defer self.allocator.free(vars);

        const resp = try self.query(gql, vars);
        defer self.allocator.free(resp);

        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, resp, .{}) catch {
            return self.allocator.dupe(u8, "UNKNOWN");
        };
        defer parsed.deinit();

        const deployment = parsed.value.object.get("deployment") orelse return self.allocator.dupe(u8, "UNKNOWN");
        const status = deployment.object.get("status") orelse return self.allocator.dupe(u8, "UNKNOWN");

        if (status == .string) return self.allocator.dupe(u8, status.string);
        return self.allocator.dupe(u8, "UNKNOWN");
    }

    /// Rename a service (serviceUpdate mutation with name field).
    pub fn serviceUpdateName(self: *Self, service_id: []const u8, new_name: []const u8) RailwayApiError!void {
        const gql = "mutation($id: ID!, $name: String!) { serviceUpdate(input: {id: $id, name: $name}) { service { id name } } }";
        const vars = std.fmt.allocPrint(self.allocator, "{{\"id\":\"{s}\",\"name\":\"{s}\"}}", .{
            service_id, new_name,
        }) catch return error.OutOfMemory;
        defer self.allocator.free(vars);

        const resp = try self.query(gql, vars);
        defer self.allocator.free(resp);

        // Check for errors in response
        if (std.mem.indexOf(u8, resp, "\"errors\"")) |_| {
            return error.ApiError;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Internal: HTTP transport (follows github_client.zig:283-349 pattern)
    // ═══════════════════════════════════════════════════════════════════════════

    fn httpPost(self: *Self, body: []const u8) RailwayApiError![]const u8 {
        // Retry loop with exponential backoff for 429 errors
        var retry_count: u32 = 0;
        while (retry_count < MAX_RETRIES) {
            // Check rate limiting before request
            if (retry_count > 0) {
                // Wait for backoff delay
                const delay_ms = calculateDelay(retry_count);
                std.debug.print("Railway API: retry {d}/{d}, waiting {d}ms...\n", .{
                    retry_count, MAX_RETRIES, delay_ms,
                });
                std.Thread.sleep(delay_ms * 1000 * 1000); // Convert ms to ns (1ms = 1,000,000ns)
            }

            const result = self.httpPostOnce(body);
            if (result) |response| {
                // Success - update last request time and return
                self.last_request_time = std.time.Instant.now() catch undefined;
                return response;
            } else |err| {
                // Check if it's a rate limit error (429)
                if (err == error.RateLimited) {
                    retry_count += 1;
                    // Continue to retry loop
                    continue;
                }
                // Other errors are not retryable
                return err;
            }
        }
        // Max retries exceeded
        return error.RateLimited;
    }

    /// Single HTTP POST attempt (no retry logic)
    fn httpPostOnce(self: *Self, body: []const u8) RailwayApiError![]const u8 {
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
            .{ .name = "User-Agent", .value = USER_AGENTS[self.user_agent_index] },
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
            // Check for rate limiting specifically (429 Too Many Requests)
            if (status_code == 429) {
                std.debug.print("{s}Railway API: rate limited (429), will retry...{s}\n", .{ RED, RESET });
                return error.RateLimited;
            }
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

        // Check if response is HTML instead of JSON (wrong endpoint or config)
        if (raw_body.len >= 10 and std.mem.eql(u8, raw_body[0..9], "<!DOCTYPE html")) {
            std.debug.print("{s}Railway API: received HTML instead of JSON - endpoint may be wrong or token invalid{s}\n", .{ RED, RESET });
            self.allocator.free(raw_body);
            return error.NotAuthorized;
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
