// =============================================================================
// DOCUMENTATION GENERATOR — From Unified Command Table
// =============================================================================
//
// Generates markdown documentation from command_table.zig.
// Single source of truth for CLI reference, MCP tool docs, and API docs.
//
// Usage: tri docs-gen [output_path]
//   Default output: docs/command_registry.md
//
// φ² + 1/φ² = 3 = TRINITY
// =============================================================================

const std = @import("std");
const def = @import("command_def.zig");
const table = @import("command_table.zig");

/// Generate full CLI command reference in Markdown
pub fn generateCliReference(allocator: std.mem.Allocator) ![]const u8 {
    var buf = try std.ArrayList(u8).initCapacity(allocator, 16384);
    errdefer buf.deinit(allocator);

    try buf.appendSlice(allocator, "# TRI Command Reference\n\n");
    try buf.appendSlice(allocator, "Total commands: ");
    try appendNumber(&buf, allocator, table.all_commands.len);
    try buf.appendSlice(allocator, "\n\n");

    // Iterate categories in display order
    const categories = [_]def.CommandCategory{
        .ai, .dev, .git, .math, .science, .sacred, .system, .demo, .benchmark, .advanced, .depin,
    };

    for (categories) |cat| {
        var count: usize = 0;
        for (table.all_commands) |cmd| {
            if (cmd.category == cat) count += 1;
        }
        if (count == 0) continue;

        try buf.appendSlice(allocator, "## ");
        try buf.appendSlice(allocator, cat.icon());
        try buf.appendSlice(allocator, " ");
        try buf.appendSlice(allocator, cat.displayName());
        try buf.appendSlice(allocator, " (");
        try appendNumber(&buf, allocator, count);
        try buf.appendSlice(allocator, ")\n\n");
        try buf.appendSlice(allocator, "| Command | Description | MCP | API |\n");
        try buf.appendSlice(allocator, "|---------|-------------|-----|-----|\n");

        for (table.all_commands) |cmd| {
            if (cmd.category != cat) continue;

            try buf.appendSlice(allocator, "| `");
            try buf.appendSlice(allocator, cmd.name);
            try buf.appendSlice(allocator, "`");

            // Aliases
            if (cmd.aliases.len > 0) {
                try buf.appendSlice(allocator, " (");
                for (cmd.aliases, 0..) |alias, i| {
                    if (i > 0) try buf.appendSlice(allocator, ", ");
                    try buf.appendSlice(allocator, alias);
                }
                try buf.appendSlice(allocator, ")");
            }

            try buf.appendSlice(allocator, " | ");
            try buf.appendSlice(allocator, cmd.description);
            try buf.appendSlice(allocator, " | ");
            try buf.appendSlice(allocator, if (cmd.mcp_enabled) "Y" else "-");
            try buf.appendSlice(allocator, " | ");
            try buf.appendSlice(allocator, if (cmd.api_enabled) "Y" else "-");
            try buf.appendSlice(allocator, " |\n");
        }

        try buf.append(allocator, '\n');
    }

    return buf.toOwnedSlice(allocator);
}

/// Generate MCP tool reference in Markdown
pub fn generateMcpReference(allocator: std.mem.Allocator) ![]const u8 {
    var buf = try std.ArrayList(u8).initCapacity(allocator, 8192);
    errdefer buf.deinit(allocator);

    try buf.appendSlice(allocator, "# MCP Tool Reference\n\n");
    try buf.appendSlice(allocator, "Tools exposed via Model Context Protocol.\n\n");
    try buf.appendSlice(allocator, "Total tools: ");
    try appendNumber(&buf, allocator, table.countMcpTools());
    try buf.appendSlice(allocator, "\n\n");

    try buf.appendSlice(allocator, "| Tool Name | Display Name | Description | Parameters |\n");
    try buf.appendSlice(allocator, "|-----------|--------------|-------------|------------|\n");

    for (&table.all_commands) |*cmd| {
        if (!cmd.mcp_enabled) continue;

        try buf.appendSlice(allocator, "| `");
        try buf.appendSlice(allocator, cmd.getMcpToolName());
        try buf.appendSlice(allocator, "` | ");
        try buf.appendSlice(allocator, cmd.getMcpDisplayName());
        try buf.appendSlice(allocator, " | ");
        try buf.appendSlice(allocator, cmd.description);
        try buf.appendSlice(allocator, " | ");

        if (cmd.input_params.len == 0) {
            try buf.appendSlice(allocator, "none");
        } else {
            for (cmd.input_params, 0..) |param, i| {
                if (i > 0) try buf.appendSlice(allocator, ", ");
                try buf.appendSlice(allocator, "`");
                try buf.appendSlice(allocator, param.name);
                try buf.appendSlice(allocator, "`");
                if (param.required) try buf.appendSlice(allocator, "*");
            }
        }

        try buf.appendSlice(allocator, " |\n");
    }

    return buf.toOwnedSlice(allocator);
}

/// Generate API endpoint reference in Markdown
pub fn generateApiReference(allocator: std.mem.Allocator) ![]const u8 {
    var buf = try std.ArrayList(u8).initCapacity(allocator, 8192);
    errdefer buf.deinit(allocator);

    try buf.appendSlice(allocator, "# API Endpoint Reference\n\n");
    try buf.appendSlice(allocator, "Total endpoints: ");
    try appendNumber(&buf, allocator, table.countApiEndpoints());
    try buf.appendSlice(allocator, "\n\n");

    try buf.appendSlice(allocator, "| Endpoint | Description | Protocols | Auth | Rate Limit |\n");
    try buf.appendSlice(allocator, "|----------|-------------|-----------|------|------------|\n");

    for (&table.all_commands) |*cmd| {
        if (!cmd.api_enabled) continue;

        try buf.appendSlice(allocator, "| `/api/");
        try buf.appendSlice(allocator, cmd.name);
        try buf.appendSlice(allocator, "` | ");
        try buf.appendSlice(allocator, cmd.description);
        try buf.appendSlice(allocator, " | ");

        for (cmd.api_protocols, 0..) |proto, i| {
            if (i > 0) try buf.appendSlice(allocator, ", ");
            try buf.appendSlice(allocator, proto.toString());
        }

        try buf.appendSlice(allocator, " | ");
        try buf.appendSlice(allocator, if (cmd.api_auth_required) "Yes" else "No");
        try buf.appendSlice(allocator, " | ");

        if (cmd.api_rate_limit) |limit| {
            try appendNumber(&buf, allocator, limit);
            try buf.appendSlice(allocator, "/min");
        } else {
            try buf.appendSlice(allocator, "-");
        }

        try buf.appendSlice(allocator, " |\n");
    }

    return buf.toOwnedSlice(allocator);
}

/// Generate summary stats
pub fn generateSummary(allocator: std.mem.Allocator) ![]const u8 {
    var buf = try std.ArrayList(u8).initCapacity(allocator, 1024);
    errdefer buf.deinit(allocator);

    try buf.appendSlice(allocator, "# Trinity Command Registry Summary\n\n");
    try buf.appendSlice(allocator, "| Interface | Commands |\n");
    try buf.appendSlice(allocator, "|-----------|----------|\n");
    try buf.appendSlice(allocator, "| CLI | ");
    try appendNumber(&buf, allocator, table.all_commands.len);
    try buf.appendSlice(allocator, " |\n| MCP Tools | ");
    try appendNumber(&buf, allocator, table.countMcpTools());
    try buf.appendSlice(allocator, " |\n| API Endpoints | ");
    try appendNumber(&buf, allocator, table.countApiEndpoints());
    try buf.appendSlice(allocator, " |\n");

    return buf.toOwnedSlice(allocator);
}

// =============================================================================
// INTERNAL HELPERS
// =============================================================================

fn appendNumber(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, n: usize) !void {
    const s = try std.fmt.allocPrint(allocator, "{d}", .{n});
    defer allocator.free(s);
    try buf.appendSlice(allocator, s);
}

// =============================================================================
// CLI COMMAND WRAPPER
// =============================================================================

/// CLI entry point: tri docs-gen [output_path]
pub fn runDocsGenCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const output_path = if (args.len > 0) args[0] else "docs/command_registry.md";

    // Ensure output directory exists
    const out_dir = std.fs.path.dirname(output_path) orelse ".";
    try std.fs.cwd().makePath(out_dir);

    // Generate combined documentation
    const content = try generateFullReference(allocator);
    defer allocator.free(content);

    // Write to file
    const file = try std.fs.cwd().createFile(output_path, .{ .read = true });
    defer file.close();
    try file.writeAll(content);

    std.debug.print("Generated {s} with {d} commands\n", .{ output_path, table.all_commands.len });
}

/// Generate full combined reference (CLI + MCP + API)
fn generateFullReference(allocator: std.mem.Allocator) ![]const u8 {
    var buf = try std.ArrayList(u8).initCapacity(allocator, 32768);
    errdefer buf.deinit(allocator);

    // Header
    try buf.appendSlice(allocator,
        \\# TRI Command Reference
        \\
        \\> Auto-generated from `src/registry/command_table.zig` by `tri docs-gen`
        \\> **DO NOT EDIT MANUALLY** — Regenerate with: `tri docs-gen`
        \\
        \\φ² + 1/φ² = 3 | TRINITY Unified Command Registry v10.2
        \\
        \\---
        \\
        \\## Summary
        \\
        \\| Interface | Commands |
        \\|-----------|----------|
        \\| CLI |
    );
    try appendNumber(&buf, allocator, table.all_commands.len);
    try buf.appendSlice(allocator, " |\n| MCP Tools | ");
    try appendNumber(&buf, allocator, table.countMcpTools());
    try buf.appendSlice(allocator, " |\n| API Endpoints | ");
    try appendNumber(&buf, allocator, table.countApiEndpoints());
    try buf.appendSlice(allocator, " |\n\n---\n\n");

    // CLI Reference
    const cli_md = try generateCliReference(allocator);
    defer allocator.free(cli_md);
    try buf.appendSlice(allocator, cli_md);

    // MCP Reference
    const mcp_md = try generateMcpReference(allocator);
    defer allocator.free(mcp_md);
    try buf.appendSlice(allocator, "\n---\n\n");
    try buf.appendSlice(allocator, mcp_md);

    // API Reference
    const api_md = try generateApiReference(allocator);
    defer allocator.free(api_md);
    try buf.appendSlice(allocator, "\n---\n\n");
    try buf.appendSlice(allocator, api_md);

    return buf.toOwnedSlice(allocator);
}

// =============================================================================
// TESTS
// =============================================================================

test "generateCliReference produces markdown" {
    const allocator = std.testing.allocator;
    const md = try generateCliReference(allocator);
    defer allocator.free(md);

    try std.testing.expect(std.mem.startsWith(u8, md, "# TRI Command Reference"));
    try std.testing.expect(std.mem.indexOf(u8, md, "| Command |") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "`bio`") != null);
}

test "generateMcpReference lists tools" {
    const allocator = std.testing.allocator;
    const md = try generateMcpReference(allocator);
    defer allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "tri_phi") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "Tool Name") != null);
}

test "generateApiReference lists endpoints" {
    const allocator = std.testing.allocator;
    const md = try generateApiReference(allocator);
    defer allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "/api/bio") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "Protocols") != null);
}

test "generateSummary shows counts" {
    const allocator = std.testing.allocator;
    const md = try generateSummary(allocator);
    defer allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "CLI") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "MCP") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "API") != null);
}
