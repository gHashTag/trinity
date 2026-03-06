// =============================================================================
// API METADATA GENERATOR — From Unified Command Table
// =============================================================================
//
// Generates API endpoint metadata from command_table.zig.
// Replaces the hand-written command list in unified_server.zig.
//
// =============================================================================

const std = @import("std");
const def = @import("command_def.zig");
const table = @import("command_table.zig");

/// API command metadata (compatible with unified_server.zig expectations)
pub const ApiCommandMeta = struct {
    name: []const u8,
    description: []const u8,
    category: def.CommandCategory,
    protocols: []const def.ApiProtocol,
    rate_limit: ?u32,
    auth_required: bool,
    input_params: []const def.InputParam,
};

/// Get all API-enabled commands as ApiCommandMeta slice
pub fn getApiCommands(allocator: std.mem.Allocator) ![]const ApiCommandMeta {
    const count = table.countApiEndpoints();
    const result = try allocator.alloc(ApiCommandMeta, count);
    var idx: usize = 0;
    for (&table.all_commands) |*cmd| {
        if (cmd.api_enabled) {
            result[idx] = .{
                .name = cmd.name,
                .description = cmd.description,
                .category = cmd.category,
                .protocols = cmd.api_protocols,
                .rate_limit = cmd.api_rate_limit,
                .auth_required = cmd.api_auth_required,
                .input_params = cmd.input_params,
            };
            idx += 1;
        }
    }
    return result;
}

/// Count API-enabled commands
pub fn countEndpoints() usize {
    return table.countApiEndpoints();
}

/// Check if a command name is exposed via API
pub fn isApiEnabled(name: []const u8) bool {
    const cmd = table.findByName(name);
    if (cmd) |c| return c.api_enabled;
    return false;
}

/// Check if a command supports a specific protocol
pub fn supportsProtocol(name: []const u8, protocol: def.ApiProtocol) bool {
    const cmd = table.findByName(name);
    if (cmd) |c| {
        if (!c.api_enabled) return false;
        for (c.api_protocols) |p| {
            if (p == protocol) return true;
        }
    }
    return false;
}

/// Generate OpenAPI 3.0 JSON for all API-enabled commands
pub fn generateOpenApiSpec(allocator: std.mem.Allocator) ![]const u8 {
    var buf = try std.ArrayList(u8).initCapacity(allocator, 8192);
    errdefer buf.deinit(allocator);

    try buf.appendSlice(allocator,
        \\{"openapi":"3.0.0","info":{"title":"Trinity API","version":"1.0.0",
    );
    try buf.appendSlice(allocator,
        \\"description":"Unified TRI CLI API"},"paths":{
    );

    var first = true;
    for (&table.all_commands) |*cmd| {
        if (!cmd.api_enabled) continue;

        // Check if REST is supported
        var has_rest = false;
        for (cmd.api_protocols) |p| {
            if (p == .REST) { has_rest = true; break; }
        }
        if (!has_rest) continue;

        if (!first) try buf.append(allocator, ',');
        first = false;

        // Path: /api/{command_name}
        try buf.appendSlice(allocator, "\"/api/");
        try buf.appendSlice(allocator, cmd.name);
        try buf.appendSlice(allocator, "\":{\"get\":{\"summary\":\"");
        try appendEscaped(&buf, allocator, cmd.description);
        try buf.appendSlice(allocator, "\",\"tags\":[\"");
        try buf.appendSlice(allocator, cmd.category.displayName());
        try buf.appendSlice(allocator, "\"]");

        // Parameters from input_params
        if (cmd.input_params.len > 0) {
            try buf.appendSlice(allocator, ",\"parameters\":[");
            var first_param = true;
            for (cmd.input_params) |param| {
                if (!first_param) try buf.append(allocator, ',');
                first_param = false;
                try buf.appendSlice(allocator, "{\"name\":\"");
                try buf.appendSlice(allocator, param.name);
                try buf.appendSlice(allocator, "\",\"in\":\"query\",\"schema\":{\"type\":\"");
                try buf.appendSlice(allocator, param.param_type.toJsonSchema());
                try buf.appendSlice(allocator, "\"}");
                if (param.required) {
                    try buf.appendSlice(allocator, ",\"required\":true");
                }
                try buf.append(allocator, '}');
            }
            try buf.append(allocator, ']');
        }

        // Security
        if (cmd.api_auth_required) {
            try buf.appendSlice(allocator, ",\"security\":[{\"bearerAuth\":[]}]");
        }

        try buf.appendSlice(allocator, "}}");
    }

    try buf.appendSlice(allocator, "}}");

    return buf.toOwnedSlice(allocator);
}

// =============================================================================
// INTERNAL HELPERS
// =============================================================================

fn appendEscaped(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '"' => try buf.appendSlice(allocator, "\\\""),
            '\\' => try buf.appendSlice(allocator, "\\\\"),
            '\n' => try buf.appendSlice(allocator, "\\n"),
            else => try buf.append(allocator, c),
        }
    }
}

// =============================================================================
// TESTS
// =============================================================================

test "getApiCommands returns API-enabled commands" {
    const allocator = std.testing.allocator;
    const cmds = try getApiCommands(allocator);
    defer allocator.free(cmds);

    try std.testing.expect(cmds.len > 50);
    try std.testing.expect(cmds.len == countEndpoints());

    // Check that "bio" is in the list (it has api_enabled = true)
    var found_bio = false;
    for (cmds) |cmd| {
        if (std.mem.eql(u8, cmd.name, "bio")) {
            found_bio = true;
            break;
        }
    }
    try std.testing.expect(found_bio);
}

test "isApiEnabled works" {
    try std.testing.expect(isApiEnabled("bio"));
    try std.testing.expect(isApiEnabled("phi"));
    try std.testing.expect(!isApiEnabled("clean")); // clean has no api_enabled
}

test "supportsProtocol works" {
    try std.testing.expect(supportsProtocol("phi", .REST));
    try std.testing.expect(supportsProtocol("phi", .GRAPHQL));
    try std.testing.expect(!supportsProtocol("clean", .REST));
}

test "generateOpenApiSpec produces valid JSON" {
    const allocator = std.testing.allocator;
    const spec = try generateOpenApiSpec(allocator);
    defer allocator.free(spec);

    try std.testing.expect(std.mem.startsWith(u8, spec, "{\"openapi\":\"3.0.0\""));
    try std.testing.expect(std.mem.indexOf(u8, spec, "/api/bio") != null);
    try std.testing.expect(std.mem.indexOf(u8, spec, "/api/phi") != null);
}
