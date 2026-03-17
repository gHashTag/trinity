// ═══════════════════════════════════════════════════════════════════════════════
// TRI PLUGIN — Plugin CLI (Honeycomb v6 Cell→Plugin Bridge)
// ═══════════════════════════════════════════════════════════════════════════════
//
// `tri plugin list|info|search` — shows cells as unified plugins.
// Bridges cell.tri manifests into the plugin view.
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const cell_parser = @import("tri_cell_parser.zig");

const CellPlugin = struct {
    id: []const u8,
    name: []const u8,
    version: []const u8,
    kind: []const u8,
    status: []const u8,
    path: []const u8,
    capabilities: []const u8,
    commands: []const u8,
};

pub fn runPluginCommand(allocator: Allocator, args: []const []const u8) !void {
    const sub = if (args.len > 0) args[0] else "help";

    if (std.mem.eql(u8, sub, "list") or std.mem.eql(u8, sub, "ls")) {
        try runList(allocator, args[1..]);
    } else if (std.mem.eql(u8, sub, "info") or std.mem.eql(u8, sub, "show")) {
        try runInfo(allocator, args[1..]);
    } else if (std.mem.eql(u8, sub, "search") or std.mem.eql(u8, sub, "find")) {
        try runSearch(allocator, args[1..]);
    } else {
        printHelp();
    }
}

fn runList(allocator: Allocator, args: []const []const u8) !void {
    var kind_filter: ?[]const u8 = null;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if ((std.mem.eql(u8, args[i], "--kind") or std.mem.eql(u8, args[i], "-k")) and i + 1 < args.len) {
            i += 1;
            kind_filter = args[i];
        }
    }

    const plugins = try discoverPlugins(allocator);
    defer {
        for (plugins) |_| {} // Slices point into content — freed via arena/page allocator
        allocator.free(plugins);
    }

    std.debug.print("\n\x1b[38;2;255;215;0m🔌 TRINITY PLUGIN REGISTRY\x1b[0m\n\n", .{});
    std.debug.print("  \x1b[36m{s:<25} {s:<10} {s:<12} {s:<8} {s}\x1b[0m\n", .{ "ID", "VERSION", "KIND", "STATUS", "PATH" });
    std.debug.print("  \x1b[90m{s:->25} {s:->10} {s:->12} {s:->8} {s:->20}\x1b[0m\n", .{ "", "", "", "", "" });

    var count: usize = 0;
    for (plugins) |p| {
        if (kind_filter) |kf| {
            if (!std.mem.eql(u8, p.kind, kf)) continue;
        }
        const status_color: []const u8 = if (std.mem.eql(u8, p.status, "stable")) "\x1b[32m" else "\x1b[33m";
        std.debug.print("  {s:<25} {s:<10} {s:<12} {s}{s:<8}\x1b[0m {s}\n", .{
            p.id, p.version, p.kind, status_color, p.status, p.path,
        });
        count += 1;
    }
    std.debug.print("\n  Total: {d} plugin(s)\n\n", .{count});
}

fn runInfo(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("Usage: tri plugin info <plugin-id>\n", .{});
        return;
    }
    const target_id = args[0];

    const plugins = try discoverPlugins(allocator);
    defer allocator.free(plugins);

    for (plugins) |p| {
        if (std.mem.eql(u8, p.id, target_id)) {
            std.debug.print("\n\x1b[36m🔌 Plugin: {s}\x1b[0m\n\n", .{p.name});
            std.debug.print("  ID:           {s}\n", .{p.id});
            std.debug.print("  Version:      {s}\n", .{p.version});
            std.debug.print("  Kind:         {s}\n", .{p.kind});
            std.debug.print("  Status:       {s}\n", .{p.status});
            std.debug.print("  Path:         {s}\n", .{p.path});
            if (p.capabilities.len > 2) {
                std.debug.print("  Capabilities: {s}\n", .{p.capabilities});
            }
            if (p.commands.len > 2) {
                std.debug.print("  Commands:     {s}\n", .{p.commands});
            }
            std.debug.print("  Source:       cell.tri manifest\n\n", .{});
            return;
        }
    }
    std.debug.print("Plugin not found: {s}\n", .{target_id});
}

fn runSearch(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("Usage: tri plugin search <query>\n", .{});
        return;
    }
    const query = args[0];

    const plugins = try discoverPlugins(allocator);
    defer allocator.free(plugins);

    std.debug.print("\n\x1b[36mSearching for '{s}'...\x1b[0m\n\n", .{query});

    var count: usize = 0;
    for (plugins) |p| {
        if (std.mem.indexOf(u8, p.id, query) != null or
            std.mem.indexOf(u8, p.name, query) != null or
            std.mem.indexOf(u8, p.kind, query) != null or
            std.mem.indexOf(u8, p.capabilities, query) != null)
        {
            std.debug.print("  {s:<25} {s:<10} {s}\n", .{ p.id, p.version, p.kind });
            count += 1;
        }
    }
    if (count == 0) {
        std.debug.print("  No plugins matching '{s}'\n", .{query});
    }
    std.debug.print("\n  Found: {d} result(s)\n\n", .{count});
}

fn printHelp() void {
    std.debug.print(
        \\
        \\🔌 Trinity Plugin Manager (Honeycomb v6)
        \\φ² + 1/φ² = 3
        \\
        \\USAGE:
        \\  tri plugin <command> [options]
        \\
        \\COMMANDS:
        \\  list, ls              List all plugins (cells + builtin)
        \\  info, show <id>       Show plugin details
        \\  search, find <query>  Search plugins by name/kind/capability
        \\  help                  Show this help
        \\
        \\OPTIONS:
        \\  --kind, -k <kind>     Filter by kind (core, tool, agent, lib, frontend, codegen)
        \\
        \\EXAMPLES:
        \\  tri plugin list
        \\  tri plugin list --kind tool
        \\  tri plugin info trinity.arena
        \\  tri plugin search arena
        \\
    , .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// DISCOVERY — cell.tri → CellPlugin
// ═══════════════════════════════════════════════════════════════════════════════

fn discoverPlugins(allocator: Allocator) ![]CellPlugin {
    var results = std.array_list.Managed(CellPlugin).init(allocator);
    errdefer results.deinit();

    const cells = try cell_parser.discoverAll(allocator);
    defer allocator.free(cells);

    for (cells) |cell| {
        const m = cell.manifest;
        try results.append(.{
            .id = m.id,
            .name = m.name,
            .version = m.version,
            .kind = m.kind,
            .status = m.status,
            .path = m.path,
            .capabilities = m.capabilities,
            .commands = m.contributes_commands,
        });
    }

    return results.toOwnedSlice();
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "shared parser — cell as plugin" {
    const content =
        \\[cell]
        \\id = "trinity.arena"
        \\name = "Arena 2.0"
        \\version = "1.0.0"
        \\kind = "tool"
        \\status = "stable"
        \\path = "src/arena"
        \\capabilities = ["arena", "elo"]
        \\
        \\[contributes]
        \\commands = ["battle", "leaderboard"]
    ;
    const m = cell_parser.parse(content);
    try std.testing.expectEqualStrings("trinity.arena", m.id);
    try std.testing.expectEqualStrings("Arena 2.0", m.name);
    try std.testing.expectEqualStrings("tool", m.kind);
    try std.testing.expectEqualStrings("stable", m.status);
    try std.testing.expect(m.hasCommands());
}
