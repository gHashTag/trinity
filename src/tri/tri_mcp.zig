// @origin(spec:tri_mcp.tri) @regen(manual-impl)
//! TRI MCP Commands — P1.6: MCP management commands
//! Usage: tri mcp export [output.json]
//!        tri mcp doctor
//!        tri mcp tools

const std = @import("std");
const registry = @import("registry");
const unified_output = @import("unified_output.zig");

pub fn runMcpCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        return showMcpHelp(allocator);
    }

    const subcommand = args[0];
    const sub_args = args[1..];

    if (std.mem.eql(u8, subcommand, "export")) {
        try runExportCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "doctor")) {
        try runDoctorCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "tools")) {
        try runToolsCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "help")) {
        return showMcpHelp(allocator);
    } else {
        var output = try unified_output.UnifiedOutput.init(allocator, "mcp", .agent);
        defer output.deinit();
        output.setStatus(.denied);
        try output.setSummary("Unknown MCP subcommand");
        try output.addError("UNKNOWN_SUBCOMMAND", "Use: tri mcp export|doctor|tools|help");
        try output.print();
    }
}

fn runExportCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const output_path = if (args.len > 0)
        args[0]
    else
        "-"; // stdout

    if (std.mem.eql(u8, output_path, "-")) {
        // Export to stdout - generate schemas directly
        const json = try registry.generateAllMcpSchemas(allocator);
        defer allocator.free(json);
        std.debug.print("{s}\n", .{json});
    } else {
        // Export to file
        try registry.exportMcpSchemas(allocator, output_path);

        var output = try unified_output.UnifiedOutput.init(allocator, "mcp-export", .agent);
        defer output.deinit();
        output.setStatus(.success);
        try output.setSummary(try std.fmt.allocPrint(allocator, "Exported MCP schemas to {s}", .{output_path}));
        try output.print();
    }
}

fn runDoctorCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;

    var output = try unified_output.UnifiedOutput.init(allocator, "mcp-doctor", .agent);
    defer output.deinit();

    var issues = try std.ArrayList([]const u8).initCapacity(allocator, 8);
    defer {
        for (issues.items) |msg| allocator.free(msg);
        issues.deinit(allocator);
    }

    var warnings = try std.ArrayList([]const u8).initCapacity(allocator, 8);
    defer {
        for (warnings.items) |msg| allocator.free(msg);
        warnings.deinit(allocator);
    }

    // CHECK 1: registry.json exists
    const registry_path = ".trinity/registry.json";
    std.fs.cwd().access(registry_path, .{}) catch {
        try issues.append(allocator, "REGISTRY_NOT_FOUND: Run 'zig build export-registry' first");
    };

    // CHECK 2: Validate registry JSON
    if (issues.items.len == 0) {
        const registry_content_result = std.fs.cwd().readFileAlloc(allocator, registry_path, 1024 * 1024);
        if (registry_content_result) |content| {
            defer allocator.free(content);

            const parsed = std.json.parseFromSlice(std.json.Value, allocator, content, .{ .allocate = .alloc_always }) catch |err| {
                try issues.append(allocator, try std.fmt.allocPrint(allocator, "REGISTRY_JSON_INVALID: {}", .{err}));
                return;
            };
            _ = parsed;
        } else |err| {
            try issues.append(allocator, try std.fmt.allocPrint(allocator, "REGISTRY_READ_ERROR: {}", .{err}));
        }
    }

    // CHECK 3: mcp_schemas.json exists
    const schemas_path = ".trinity/mcp_schemas.json";
    const schemas_exist = blk: {
        if (std.fs.cwd().access(schemas_path, .{})) |_| {
            break :blk true;
        } else |_| {
            break :blk false;
        }
    };

    if (!schemas_exist) {
        try warnings.append(allocator, "MCP_SCHEMAS_NOT_FOUND: Run 'tri mcp export' to generate");
    }

    // CHECK 4: Validate schemas JSON if exists
    if (schemas_exist) {
        const schemas_content_result = std.fs.cwd().readFileAlloc(allocator, schemas_path, 1024 * 1024);
        if (schemas_content_result) |content| {
            defer allocator.free(content);

            const parsed = std.json.parseFromSlice(std.json.Value, allocator, content, .{ .allocate = .alloc_always }) catch |err| {
                try warnings.append(allocator, try std.fmt.allocPrint(allocator, "SCHEMAS_JSON_INVALID: {}", .{err}));
                return;
            };
            _ = parsed;
        } else |err| {
            try warnings.append(allocator, try std.fmt.allocPrint(allocator, "SCHEMAS_READ_ERROR: {}", .{err}));
        }
    }

    // CHECK 5: Count MCP-enabled commands
    var mcp_count: usize = 0;
    var mcp_with_names: usize = 0;
    for (registry.command_table_all_commands) |cmd| {
        if (cmd.mcp_enabled) {
            mcp_count += 1;
            if (cmd.mcp_name != null) mcp_with_names += 1;
        }
    }

    if (mcp_count == 0) {
        try warnings.append(allocator, "NO_MCP_COMMANDS: No commands have mcp_enabled=true");
    }

    // CHECK 6: Schema drift detection
    if (schemas_exist and issues.items.len == 0) {
        // Compare command count
        const schemas_content = std.fs.cwd().readFileAlloc(allocator, schemas_path, 1024 * 1024) catch "";
        defer allocator.free(schemas_content);

        const parsed = std.json.parseFromSlice(std.json.Value, allocator, schemas_content, .{ .allocate = .alloc_always }) catch null;
        if (parsed) |p| {
            if (p.value.object.get("tools")) |tools| {
                if (tools.array.items.len != mcp_count) {
                    try warnings.append(allocator, try std.fmt.allocPrint(allocator, "SCHEMA_DRIFT: MCP schemas has {} tools but registry has {}", .{ tools.array.items.len, mcp_count }));
                }
            }
        }
    }

    // Build result
    if (issues.items.len > 0) {
        output.setStatus(.failure);
        try output.setSummary("MCP system has errors");
        for (issues.items) |msg| {
            try output.addError("MCP_CHECK_FAILED", msg);
        }
    } else if (warnings.items.len > 0) {
        output.setStatus(.partial);
        try output.setSummary("MCP system has warnings");
        for (warnings.items) |msg| {
            try output.addWarning("MCP_WARNING", msg);
        }
    } else {
        output.setStatus(.success);
        try output.setSummary("MCP system healthy");
    }

    // Add metrics
    try output.addMetric("registry_valid", if (issues.items.len == 0) @as(i32, 1) else 0);
    try output.addMetric("schemas_available", if (schemas_exist) @as(i32, 1) else 0);
    try output.addMetric("mcp_enabled_count", mcp_count);
    try output.addMetric("mcp_with_names", mcp_with_names);
    try output.addMetric("total_commands", registry.command_table_all_commands.len);
    try output.addMetric("warnings", warnings.items.len);
    try output.addMetric("errors", issues.items.len);

    try output.print();
}

fn runToolsCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;

    var output = try unified_output.UnifiedOutput.init(allocator, "mcp-tools", .agent);
    defer output.deinit();

    try output.setSummary("MCP-enabled tools");

    // List all MCP-enabled tools
    var tools_list = try std.ArrayList([]const u8).initCapacity(allocator, 32);
    defer {
        for (tools_list.items) |tool| allocator.free(tool);
        tools_list.deinit(allocator);
    }

    for (registry.command_table_all_commands) |cmd| {
        if (cmd.mcp_enabled) {
            try tools_list.append(allocator, try std.fmt.allocPrint(allocator, "{s}: {s}", .{ cmd.mcp_name.?, cmd.description }));
        }
    }

    try output.print();
}

fn showMcpHelp(allocator: std.mem.Allocator) !void {
    _ = allocator;
    std.debug.print(
        \\TRI MCP Commands — Manage MCP server integration
        \\
        \\Usage:
        \\  tri mcp export [output.json]    Export MCP tool schemas
        \\  tri mcp doctor                   Run MCP health checks
        \\  tri mcp tools                    List MCP-enabled tools
        \\  tri mcp help                     Show this help
        \\
        \\Examples:
        \\  tri mcp export schemas.json     Export to file
        \\  tri mcp export                  Export to stdout
        \\  tri mcp doctor                   Check MCP system
        \\
    , .{});
}

test "mcp help callable" {
    showMcpHelp(std.testing.allocator);
}
