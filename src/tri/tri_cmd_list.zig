//! TRI Commands List — P1.6: Export all commands as JSON
//! Usage: tri commands [--json]
//! Output: List of all commands with metadata
// @origin(generated) @regen(done)

const std = @import("std");
const registry = @import("registry");
const unified_output = @import("unified_output.zig");

pub fn runCommandsList(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const json_mode = args.len > 0 and std.mem.eql(u8, args[0], "--json");

    if (json_mode) {
        try exportCommandsJson(allocator);
    } else {
        try printCommandsTable(allocator);
    }
}

fn printCommandsTable(allocator: std.mem.Allocator) !void {
    const all_commands = registry.command_table_all_commands;

    // Group by namespace
    const NamespaceInner = struct {
        name: []const u8,
        commands: std.ArrayList(usize),
        count: usize,

        fn init(alloc: std.mem.Allocator, name: []const u8) !@This() {
            return .{
                .name = name,
                .commands = try std.ArrayList(usize).initCapacity(alloc, 16),
                .count = 0,
            };
        }

        fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
            self.commands.deinit(alloc);
        }
    };

    var namespaces = std.StringHashMap(NamespaceInner).init(allocator);
    defer {
        var iter = namespaces.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit(allocator);
        }
        namespaces.deinit();
    }

    // Collect commands by namespace
    for (all_commands, 0..) |cmd, idx| {
        const ns = cmd.cli_namespace.toString();
        const entry = try namespaces.getOrPut(ns);
        if (!entry.found_existing) {
            entry.value_ptr.* = try NamespaceInner.init(allocator, ns);
        }
        try entry.value_ptr.commands.append(allocator, idx);
        entry.value_ptr.count += 1;
    }

    // Print header
    std.debug.print("\n═╦═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("║ {s}TRI COMMANDS{s} — Total: {d} commands\n", .{
        "\x1b[33;1m", "\x1b[0m", all_commands.len,
    });
    std.debug.print("═╩═══════════════════════════════════════════════════════════════\n\n", .{});

    // Print by namespace
    const ns_order = [_][]const u8{ "core", "dev", "forge", "agent", "mcp", "system", "science", "math", "sacred", "benchmark", "depin" };

    for (ns_order) |ns_name| {
        if (namespaces.get(ns_name)) |ns| {
            std.debug.print("{s}{s}{s} ({d} commands):\n", .{
                "\x1b[36;1m", ns_name, "\x1b[0m", ns.count,
            });

            for (ns.commands.items) |idx| {
                const cmd = all_commands[idx];
                std.debug.print("  {s}{s}{s}", .{ "\x1b[32m", cmd.name, "\x1b[0m" });

                if (cmd.aliases.len > 0) {
                    std.debug.print(" (", .{});
                    for (cmd.aliases, 0..) |alias, i| {
                        if (i > 0) std.debug.print(", ", .{});
                        std.debug.print("{s}", .{alias});
                    }
                    std.debug.print(")", .{});
                }

                std.debug.print(": {s}\n", .{cmd.description});
            }
            std.debug.print("\n", .{});
        }
    }
}

fn exportCommandsJson(allocator: std.mem.Allocator) !void {
    const all_commands = registry.command_table_all_commands;

    // Build JSON array
    var json_buf = try std.ArrayList(u8).initCapacity(allocator, 1024 * 100);
    defer json_buf.deinit(allocator);

    try json_buf.append(allocator, '[');

    for (all_commands, 0..) |cmd, i| {
        if (i > 0) try json_buf.append(allocator, ',');

        try json_buf.append(allocator, '{');
        try json_buf.writer(allocator).print("\"name\":\"{s}\"", .{cmd.name});
        try json_buf.writer(allocator).print(",\"description\":\"{s}\"", .{cmd.description});
        try json_buf.writer(allocator).print(",\"category\":\"{s}\"", .{@tagName(cmd.category)});

        // Aliases
        try json_buf.appendSlice(allocator, ",\"aliases\":[");
        for (cmd.aliases, 0..) |alias, j| {
            if (j > 0) try json_buf.append(allocator, ',');
            try json_buf.writer(allocator).print("\"{s}\"", .{alias});
        }
        try json_buf.append(allocator, ']');

        // Namespace
        try json_buf.writer(allocator).print(",\"namespace\":\"{s}\"", .{cmd.cli_namespace.toString()});

        // Mode
        try json_buf.writer(allocator).print(",\"mode\":\"{s}\"", .{@tagName(cmd.mode)});

        // Stability
        try json_buf.writer(allocator).print(",\"stability\":\"{s}\"", .{@tagName(cmd.stability)});

        // MCP enabled
        try json_buf.writer(allocator).print(",\"mcp_enabled\":{}", .{cmd.mcp_enabled});

        try json_buf.append(allocator, '}');
    }

    try json_buf.append(allocator, ']');

    const json_slice = try json_buf.toOwnedSlice(allocator);
    defer allocator.free(json_slice);

    std.debug.print("{s}\n", .{json_slice});
}
