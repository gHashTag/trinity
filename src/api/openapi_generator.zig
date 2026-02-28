// ═══════════════════════════════════════════════════════════════════════════════
// OPENAPI GENERATOR — Auto-generate OpenAPI 3.0 from .tri specs
// Parses VIBEE specifications and generates OpenAPI JSON
// φ² + 1/φ² = 3 = TRINITY | Golden Chain #102
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// OPENAPI 3.0 STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

pub const OpenApiSpec = struct {
    openapi: []const u8 = "3.0.0",
    info: Info,
    servers: []Server,
    paths: std.StringHashMap(PathItem),
    components: Components,

    pub const Info = struct {
        title: []const u8,
        version: []const u8,
        description: []const u8,
    };

    pub const Server = struct {
        url: []const u8,
        description: []const u8,
    };

    pub const PathItem = struct {
        get: ?Operation = null,
        post: ?Operation = null,
        put: ?Operation = null,
        delete: ?Operation = null,
    };

    pub const Operation = struct {
        summary: []const u8,
        description: []const u8,
        operationId: []const u8,
        responses: std.StringHashMap(Response),
        parameters: ?[]Parameter = null,
        request_body: ?RequestBody = null,
    };

    pub const Response = struct {
        description: []const u8,
        content: std.StringHashMap(MediaType),
    };

    pub const MediaType = struct {
        schema: Schema,
    };

    pub const RequestBody = struct {
        description: []const u8,
        content: std.StringHashMap(MediaType),
        required: bool,
    };

    pub const Parameter = struct {
        name: []const u8,
        in: []const u8, // "query", "header", "path", "cookie"
        description: []const u8,
        required: bool,
        schema: Schema,
    };

    pub const Schema = struct {
        type: []const u8, // "string", "number", "boolean", "array", "object"
        description: ?[]const u8 = null,
        properties: ?std.StringHashMap(Schema) = null,
        items: ?*Schema = null,
        enum_values: ?[]const []const u8 = null,
    };

    pub const Components = struct {
        schemas: std.StringHashMap(Schema),
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const OpenApiGenerator = struct {
    allocator: std.mem.Allocator,
    spec: OpenApiSpec,

    pub fn init(allocator: std.mem.Allocator) OpenApiGenerator {
        var servers = [_]OpenApiSpec.Server{
            .{
                .url = "http://localhost:8080",
                .description = "TRINITY Unified API Server",
            },
        };

        return OpenApiGenerator{
            .allocator = allocator,
            .spec = .{
                .info = .{
                    .title = "TRINITY Unified API",
                    .version = "1.0.0",
                    .description = "All 130+ TRI CLI commands accessible via REST, GraphQL, gRPC, and WebSocket",
                },
                .servers = &servers,
                .paths = std.StringHashMap(OpenApiSpec.PathItem).init(allocator),
                .components = .{
                    .schemas = std.StringHashMap(OpenApiSpec.Schema).init(allocator),
                },
            },
        };
    }

    pub fn deinit(self: *OpenApiGenerator) void {
        var path_iter = self.spec.paths.iterator();
        while (path_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.spec.paths.deinit();
        self.spec.components.schemas.deinit();
    }

    // Add a command endpoint from .tri spec
    pub fn addCommandEndpoint(
        self: *OpenApiGenerator,
        command_name: []const u8,
        description: []const u8,
        category: []const u8,
    ) !void {
        _ = category;
        const path_name = try std.fmt.allocPrint(self.allocator, "/api/{s}", .{command_name});
        errdefer self.allocator.free(path_name);

        // Create GET endpoint for command info
        var get_op = OpenApiSpec.Operation{
            .summary = try std.fmt.allocPrint(self.allocator, "Get {s} command info", .{command_name}),
            .description = description,
            .operationId = try std.fmt.allocPrint(self.allocator, "get{s}", .{command_name}),
            .responses = std.StringHashMap(OpenApiSpec.Response).init(self.allocator),
            .parameters = null,
            .request_body = null,
        };

        // Add 200 response
        var content = std.StringHashMap(OpenApiSpec.MediaType).init(self.allocator);
        try content.put("application/json", .{
            .schema = .{
                .type = "object",
                .description = null,
                .properties = null,
                .items = null,
                .enum_values = null,
            },
        });

        var responses = std.StringHashMap(OpenApiSpec.Response).init(self.allocator);
        try responses.put("200", .{
            .description = "Success",
            .content = content,
        });

        get_op.responses = responses;

        // Add to paths
        try self.spec.paths.put(path_name, .{
            .get = get_op,
            .post = null,
            .put = null,
            .delete = null,
        });

        // Also add /api/execute for command execution
        if (std.mem.eql(u8, command_name, "chat")) {
            const execute_path = "/api/execute";
            var post_op = OpenApiSpec.Operation{
                .summary = "Execute TRI command",
                .description = "Execute any TRI CLI command via REST API",
                .operationId = "executeCommand",
                .responses = std.StringHashMap(OpenApiSpec.Response).init(self.allocator),
                .parameters = null,
                .request_body = null,
            };

            var exec_content = std.StringHashMap(OpenApiSpec.MediaType).init(self.allocator);
            try exec_content.put("application/json", .{
                .schema = .{
                    .type = "object",
                    .description = null,
                    .properties = null,
                    .items = null,
                    .enum_values = null,
                },
            });

            var exec_responses = std.StringHashMap(OpenApiSpec.Response).init(self.allocator);
            try exec_responses.put("200", .{
                .description = "Command executed successfully",
                .content = exec_content,
            });

            post_op.responses = exec_responses;

            try self.spec.paths.put(
                try self.allocator.dupe(u8, execute_path),
                .{
                    .get = null,
                    .post = post_op,
                    .put = null,
                    .delete = null,
                },
            );
        }
    }

    // Generate JSON output
    pub fn toJson(self: *const OpenApiGenerator) ![]const u8 {
        var buffer = std.ArrayList(u8).initCapacity(self.allocator, 8192) catch return error.OutOfMemory;
        errdefer buffer.deinit(self.allocator);

        try buffer.appendSlice(self.allocator, "{\n");
        try buffer.appendSlice(self.allocator, "  \"openapi\": \"3.0.0\",\n");
        try buffer.appendSlice(self.allocator, "  \"info\": {\n");
        try buffer.appendSlice(self.allocator, "    \"title\": \"TRINITY Unified API\",\n");
        try buffer.appendSlice(self.allocator, "    \"version\": \"1.0.0\",\n");
        try buffer.appendSlice(self.allocator, "    \"description\": \"All 130+ TRI CLI commands accessible via REST, GraphQL, gRPC, and WebSocket\"\n");
        try buffer.appendSlice(self.allocator, "  },\n");
        try buffer.appendSlice(self.allocator, "  \"servers\": [\n");
        try buffer.appendSlice(self.allocator, "    {\n");
        try buffer.appendSlice(self.allocator, "      \"url\": \"http://localhost:8080\",\n");
        try buffer.appendSlice(self.allocator, "      \"description\": \"TRINITY Unified API Server\"\n");
        try buffer.appendSlice(self.allocator, "    }\n");
        try buffer.appendSlice(self.allocator, "  ],\n");
        try buffer.appendSlice(self.allocator, "  \"paths\": {\n");

        var path_iter = self.spec.paths.iterator();
        var first = true;
        while (path_iter.next()) |entry| {
            if (!first) try buffer.appendSlice(self.allocator, ",\n");
            first = false;

            try buffer.appendSlice(self.allocator, "    \"");
            try buffer.appendSlice(self.allocator, entry.key_ptr.*);
            try buffer.appendSlice(self.allocator, "\": {\n");

            if (entry.value_ptr.get) |get_op| {
                try buffer.appendSlice(self.allocator, "      \"get\": {\n");
                try buffer.appendSlice(self.allocator, "        \"summary\": \"");
                try buffer.appendSlice(self.allocator, get_op.summary);
                try buffer.appendSlice(self.allocator, "\",\n");
                try buffer.appendSlice(self.allocator, "        \"operationId\": \"");
                try buffer.appendSlice(self.allocator, get_op.operationId);
                try buffer.appendSlice(self.allocator, "\",\n");
                try buffer.appendSlice(self.allocator, "        \"responses\": {\n");
                try buffer.appendSlice(self.allocator, "          \"200\": {\n");
                try buffer.appendSlice(self.allocator, "            \"description\": \"Success\"\n");
                try buffer.appendSlice(self.allocator, "          }\n");
                try buffer.appendSlice(self.allocator, "        }\n");
                try buffer.appendSlice(self.allocator, "      }\n");
            }

            try buffer.appendSlice(self.allocator, "    }");
        }

        try buffer.appendSlice(self.allocator, "\n  }\n");
        try buffer.appendSlice(self.allocator, "}\n");

        return buffer.toOwnedSlice(self.allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "OpenApiGenerator: init" {
    var gen = OpenApiGenerator.init(std.testing.allocator);
    defer gen.deinit();

    try std.testing.expectEqualSlices(u8, "3.0.0", gen.spec.openapi);
    try std.testing.expectEqualSlices(u8, "TRINITY Unified API", gen.spec.info.title);
}

test "OpenApiGenerator: add endpoint" {
    var gen = OpenApiGenerator.init(std.testing.allocator);
    defer gen.deinit();

    try gen.addCommandEndpoint("chat", "Interactive chat with AI", "CORE");

    try std.testing.expect(gen.spec.paths.count() >= 1);
}

test "OpenApiGenerator: toJson" {
    var gen = OpenApiGenerator.init(std.testing.allocator);
    defer gen.deinit();

    try gen.addCommandEndpoint("status", "Get system status", "CORE");

    const json = try gen.toJson();
    defer std.testing.allocator.free(json);

    try std.testing.expect(json.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "openapi") != null);
}
