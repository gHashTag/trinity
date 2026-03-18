//! MCP Registry Generator — Export Command Table to JSON
//! V = n × 3^k × π^m × φ^p × e^q | φ² + 1/φ² = 3 = TRINITY
//!
//! Generates registry.json from the unified command table.
//! This JSON is consumed by the MCP server to auto-generate tools.

const std = @import("std");
const command_def = @import("command_def.zig");
const command_table = @import("command_table.zig");

// Re-export for P1.6: Allow tri commands/mcp to access via registry module
pub const command_table_all_commands = command_table.all_commands;
pub const CommandDef = command_def.CommandDef;

/// Generate complete registry JSON from command table
pub fn generateRegistryJson(allocator: std.mem.Allocator) ![]const u8 {
    var buf = try std.ArrayList(u8).initCapacity(allocator, 4096);
    errdefer buf.deinit(allocator);

    // Get current timestamp
    const timestamp = std.time.timestamp();

    // Header
    try buf.appendSlice(allocator,
        \\{"version":"1.0.0","generated_at":"
    );

    // Format timestamp as ISO 8601
    const datetime = try formatTimestamp(allocator, timestamp);
    defer allocator.free(datetime);
    try buf.appendSlice(allocator, datetime);
    try buf.appendSlice(allocator, "\",\"commands\":[");

    // Export each command
    var first = true;
    for (command_table.all_commands) |cmd| {
        // Only export MCP-enabled commands
        if (!cmd.mcp_enabled) continue;

        if (!first) try buf.append(allocator, ',');
        first = false;

        try exportCommand(allocator, &buf, cmd);
    }

    // Footer: close commands array and root object
    try buf.appendSlice(allocator, "]}");

    return buf.toOwnedSlice(allocator);
}

/// Export a single command to JSON
fn exportCommand(allocator: std.mem.Allocator, buf: *std.ArrayList(u8), cmd: command_def.CommandDef) !void {
    try buf.appendSlice(allocator, "{");

    // Basic identity
    try buf.print(allocator, "\"name\":\"{s}\"", .{cmd.name});
    if (cmd.aliases.len > 0) {
        try buf.appendSlice(allocator, ",\"aliases\":[");
        for (cmd.aliases, 0..) |alias, i| {
            if (i > 0) try buf.append(allocator, ',');
            try buf.print(allocator, "\"{s}\"", .{alias});
        }
        try buf.append(allocator, ']');
    }

    // Description
    try buf.print(allocator, ",\"description\":\"{s}\"", .{cmd.description});

    // NEW: CLI namespace
    try buf.print(allocator, ",\"cli_namespace\":\"{s}\"", .{cmd.cli_namespace.toString()});

    // NEW: Execution mode
    try buf.print(allocator, ",\"mode\":\"{s}\"", .{cmd.mode.toString()});

    // NEW: Side effects
    try buf.appendSlice(allocator, ",\"side_effects\":[");
    for (cmd.side_effects, 0..) |effect, i| {
        if (i > 0) try buf.append(allocator, ',');
        try buf.print(allocator, "\"{s}\"", .{effect.toString()});
    }
    try buf.append(allocator, ']');

    // NEW: Stability
    try buf.print(allocator, ",\"stability\":\"{s}\"", .{cmd.stability.toString()});

    // NEW: Required artifacts
    if (cmd.required_artifacts.len > 0) {
        try buf.appendSlice(allocator, ",\"required_artifacts\":[");
        for (cmd.required_artifacts, 0..) |artifact, i| {
            if (i > 0) try buf.append(allocator, ',');
            try buf.print(allocator, "\"{s}\"", .{artifact});
        }
        try buf.append(allocator, ']');
    }

    // NEW: Job timeout
    try buf.print(allocator, ",\"job_timeout\":{d}", .{cmd.job_timeout});

    // MCP-specific
    try buf.print(allocator, ",\"mcp_enabled\":{s}", .{if (cmd.mcp_enabled) "true" else "false"});
    if (cmd.mcp_enabled) {
        const mcp_name = if (cmd.mcp_name) |n| n else cmd.name;
        try buf.print(allocator, ",\"mcp_name\":\"{s}\"", .{mcp_name});

        const mcp_display = if (cmd.mcp_display_name) |n| n else cmd.description;
        try buf.print(allocator, ",\"mcp_display_name\":\"{s}\"", .{mcp_display});
    }

    // Input parameters
    if (cmd.input_params.len > 0) {
        try buf.appendSlice(allocator, ",\"input_params\":[");
        for (cmd.input_params, 0..) |param, i| {
            if (i > 0) try buf.append(allocator, ',');
            try exportInputParam(allocator, buf, param);
        }
        try buf.append(allocator, ']');
    }

    // Category
    try buf.print(allocator, ",\"category\":\"{s}\"", .{@tagName(cmd.category)});

    // Examples
    if (cmd.examples.len > 0) {
        try buf.appendSlice(allocator, ",\"examples\":[");
        for (cmd.examples, 0..) |example, i| {
            if (i > 0) try buf.append(allocator, ',');
            try buf.print(allocator, "\"{s}\"", .{example});
        }
        try buf.append(allocator, ']');
    }

    try buf.append(allocator, '}');
}

/// Export an input parameter to JSON
fn exportInputParam(allocator: std.mem.Allocator, buf: *std.ArrayList(u8), param: command_def.InputParam) !void {
    try buf.print(allocator, "{{\"name\":\"{s}\",\"type\":\"{s}\"", .{
        param.name,
        param.param_type.toJsonSchema(),
    });

    if (param.description.len > 0) {
        try buf.print(allocator, ",\"description\":\"{s}\"", .{param.description});
    }

    if (param.required) {
        try buf.appendSlice(allocator, ",\"required\":true");
    }

    if (param.default_value) |default| {
        try buf.print(allocator, ",\"default\":\"{s}\"", .{default});
    }

    try buf.append(allocator, '}');
}

/// Format Unix timestamp as ISO 8601
fn formatTimestamp(allocator: std.mem.Allocator, timestamp: i64) ![]const u8 {
    // For simplicity, just use Unix timestamp as string
    // In the future, this can be expanded to proper ISO 8601
    return std.fmt.allocPrint(allocator, "{d}", .{timestamp});
}

// =============================================================================
// MCP TOOL SCHEMA GENERATION
// =============================================================================

/// Generate MCP tool schema for a single command
pub fn generateMcpToolSchema(allocator: std.mem.Allocator, cmd: command_def.CommandDef) ![]const u8 {
    var buf = try std.ArrayList(u8).initCapacity(allocator, 1024);
    errdefer buf.deinit(allocator);

    const tool_name = if (cmd.mcp_name) |n| n else cmd.name;

    try buf.print(allocator, "{{\"name\":\"{s}\",\"description\":\"{s}\",\"inputSchema\":{{\"type\":\"object\"", .{ tool_name, cmd.description });

    // Add input parameters as properties
    if (cmd.input_params.len > 0) {
        try buf.appendSlice(allocator, ",\"properties\":{");

        var first_param = true;
        for (cmd.input_params) |param| {
            if (!first_param) try buf.append(allocator, ',');
            first_param = false;

            try buf.print(allocator, "\"{s}\":{{\"type\":\"{s}\"", .{
                param.name,
                param.param_type.toJsonSchema(),
            });

            if (param.description.len > 0) {
                try buf.print(allocator, ",\"description\":\"{s}\"", .{param.description});
            }

            try buf.append(allocator, '}');
        }

        try buf.append(allocator, '}');

        // Add required array
        var has_required = false;
        for (cmd.input_params) |param| {
            if (param.required) {
                has_required = true;
                break;
            }
        }

        if (has_required) {
            try buf.appendSlice(allocator, ",\"required\":[");
            var first_req = true;
            for (cmd.input_params) |param| {
                if (param.required) {
                    if (!first_req) try buf.append(allocator, ',');
                    first_req = false;
                    try buf.print(allocator, "\"{s}\"", .{param.name});
                }
            }
            try buf.append(allocator, ']');
        }
    }

    try buf.appendSlice(allocator, "}}");

    return buf.toOwnedSlice(allocator);
}

/// Generate all MCP tool schemas as a JSON array
pub fn generateAllMcpSchemas(allocator: std.mem.Allocator) ![]const u8 {
    var buf = try std.ArrayList(u8).initCapacity(allocator, 8192);
    errdefer buf.deinit(allocator);

    try buf.appendSlice(allocator, "{\"tools\":[");

    var first = true;
    for (command_table.all_commands) |cmd| {
        if (!cmd.mcp_enabled) continue;

        if (!first) try buf.append(allocator, ',');
        first = false;

        const schema = try generateMcpToolSchema(allocator, cmd);
        defer allocator.free(schema);
        try buf.appendSlice(allocator, schema);
    }

    try buf.appendSlice(allocator, "]}");

    return buf.toOwnedSlice(allocator);
}

// =============================================================================
// COMMAND LINE INTERFACE
// =============================================================================

/// Export registry to file (typically .trinity/registry.json)
pub fn exportRegistry(allocator: std.mem.Allocator, path: []const u8) !void {
    const json = try generateRegistryJson(allocator);
    defer allocator.free(json);

    const dir = std.fs.path.dirname(path) orelse ".";
    std.fs.cwd().makePath(dir) catch |err| {
        std.log.err("Failed to create directory: {}", .{err});
        return err;
    };

    try std.fs.cwd().writeFile(.{ .sub_path = path, .data = json });
    std.log.info("Exported registry to {s} ({d} bytes)", .{ path, json.len });
}

/// Export MCP schemas to file
pub fn exportMcpSchemas(allocator: std.mem.Allocator, path: []const u8) !void {
    const json = try generateAllMcpSchemas(allocator);
    defer allocator.free(json);

    const dir = std.fs.path.dirname(path) orelse ".";
    std.fs.cwd().makePath(dir) catch |err| {
        std.log.err("Failed to create directory: {}", .{err});
        return err;
    };

    try std.fs.cwd().writeFile(.{ .sub_path = path, .data = json });
    std.log.info("Exported MCP schemas to {s} ({d} bytes)", .{ path, json.len });
}

// =============================================================================
// STATISTICS
// =============================================================================

pub const RegistryStats = struct {
    total_commands: usize,
    mcp_enabled: usize,
    by_mode: struct { sync: usize, job: usize, stream: usize },
    by_stability: struct { stable: usize, experimental: usize, dangerous: usize },
    by_namespace: struct { core: usize, dev: usize, forge: usize, agent: usize, mcp: usize, system: usize },
};

/// Calculate registry statistics
pub fn calculateStats() RegistryStats {
    var stats: RegistryStats = undefined;
    stats.total_commands = command_table.all_commands.len;
    stats.mcp_enabled = 0;
    stats.by_mode = .{ .sync = 0, .job = 0, .stream = 0 };
    stats.by_stability = .{ .stable = 0, .experimental = 0, .dangerous = 0 };
    stats.by_namespace = .{ .core = 0, .dev = 0, .forge = 0, .agent = 0, .mcp = 0, .system = 0 };

    for (command_table.all_commands) |cmd| {
        if (cmd.mcp_enabled) stats.mcp_enabled += 1;

        switch (cmd.mode) {
            .sync => stats.by_mode.sync += 1,
            .job => stats.by_mode.job += 1,
            .stream => stats.by_mode.stream += 1,
        }

        switch (cmd.stability) {
            .stable => stats.by_stability.stable += 1,
            .experimental => stats.by_stability.experimental += 1,
            .dangerous => stats.by_stability.dangerous += 1,
        }

        switch (cmd.cli_namespace) {
            .core => stats.by_namespace.core += 1,
            .dev => stats.by_namespace.dev += 1,
            .forge => stats.by_namespace.forge += 1,
            .agent => stats.by_namespace.agent += 1,
            .mcp => stats.by_namespace.mcp += 1,
            .system => stats.by_namespace.system += 1,
        }
    }

    return stats;
}

// =============================================================================
// TESTS
// =============================================================================

test "generateRegistryJson produces valid JSON" {
    const allocator = std.testing.allocator;
    const json = try generateRegistryJson(allocator);
    defer allocator.free(json);

    try std.testing.expect(json.len > 0);
    try std.testing.expect(std.mem.startsWith(u8, json, "{\"version\":"));
    try std.testing.expect(std.mem.endsWith(u8, json, "}"));
}

test "generateMcpToolSchema includes required fields" {
    const allocator = std.testing.allocator;

    // Test with a command that has input params
    const cmd = command_def.CommandDef{
        .name = "test",
        .description = "Test command",
        .category = .dev,
        .mcp_enabled = true,
        .mcp_name = "tri_test",
        .input_params = &.{
            .{ .name = "n", .param_type = .integer, .description = "Number", .required = true },
        },
    };

    const schema = try generateMcpToolSchema(allocator, cmd);
    defer allocator.free(schema);

    try std.testing.expect(std.mem.indexOf(u8, schema, "\"name\":\"tri_test\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, schema, "\"inputSchema\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, schema, "\"required\"") != null);
}

test "calculateStats counts correctly" {
    const stats = calculateStats();

    try std.testing.expect(stats.total_commands > 0);
    try std.testing.expect(stats.mcp_enabled <= stats.total_commands);
    try std.testing.expect(stats.by_mode.sync + stats.by_mode.job + stats.by_mode.stream == stats.total_commands);
}
