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
    OutOfMemory,
    InvalidJson,
};

pub const RailwayApi = struct {
    allocator: Allocator,
    token: []const u8,
    project_id: []const u8,

    const Self = @This();

    /// Initialize from environment variables and .railway.json
    pub fn init(allocator: Allocator) RailwayApiError!RailwayApi {
        const token = std.process.getEnvVarOwned(allocator, "RAILWAY_API_TOKEN") catch
            return error.MissingToken;

        const project_id = std.process.getEnvVarOwned(allocator, "RAILWAY_PROJECT_ID") catch blk: {
            break :blk readProjectIdFromFile(allocator) catch return error.MissingProjectId;
        };

        return .{
            .allocator = allocator,
            .token = token,
            .project_id = project_id,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.token);
        self.allocator.free(self.project_id);
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
    pub fn upsertVariable(self: *Self, service_id: []const u8, environment_id: []const u8, key: []const u8, value: []const u8) RailwayApiError![]const u8 {
        const gql = "mutation($input: VariableUpsertInput!) { variableUpsert(input: $input) }";
        const vars = std.fmt.allocPrint(self.allocator,
            \\{{"input":{{"projectId":"{s}","serviceId":"{s}","environmentId":"{s}","name":"{s}","value":"{s}"}}}}
        , .{
            self.project_id, service_id, environment_id, key, value,
        }) catch return error.OutOfMemory;
        defer self.allocator.free(vars);
        return self.query(gql, vars);
    }

    /// Redeploy a service (trigger new deployment from latest).
    pub fn redeployService(self: *Self, service_id: []const u8, environment_id: []const u8) RailwayApiError![]const u8 {
        const gql = "mutation($serviceId: String!, $environmentId: String!) { serviceRedeploy(serviceId: $serviceId, environmentId: $environmentId) }";
        const vars = std.fmt.allocPrint(self.allocator, "{{\"serviceId\":\"{s}\",\"environmentId\":\"{s}\"}}", .{
            service_id, environment_id,
        }) catch return error.OutOfMemory;
        defer self.allocator.free(vars);
        return self.query(gql, vars);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Internal: HTTP transport (follows github_client.zig:283-349 pattern)
    // ═══════════════════════════════════════════════════════════════════════════

    fn httpPost(self: *Self, body: []const u8) RailwayApiError![]const u8 {
        var client = std.http.Client{ .allocator = self.allocator };
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
            std.debug.print("{s}Railway API error: HTTP {d}{s}\n", .{ RED, status_code, RESET });
            return error.ApiError;
        }

        var transfer_buffer: [8192]u8 = undefined;
        var reader = response.reader(&transfer_buffer);
        const response_body = reader.allocRemaining(self.allocator, std.Io.Limit.limited(1 * 1024 * 1024)) catch
            return error.OutOfMemory;

        return response_body;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Internal: helpers
    // ═══════════════════════════════════════════════════════════════════════════

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
