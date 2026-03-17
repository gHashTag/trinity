// ═══════════════════════════════════════════════════════════════════════════════
// TRI CELL DISPATCH — Cell→Command Bridge
// ═══════════════════════════════════════════════════════════════════════════════
//
// Builds a command lookup table from cell.tri `contributes.tri_subcommands`.
// Allows new cells to auto-register commands without modifying main.zig.
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const cell_parser = @import("tri_cell_parser.zig");

const CACHE_PATH = ".trinity/command_cache.json";

pub const CellCommand = struct {
    cell_id: []const u8,
    cell_path: []const u8,
    command: []const u8,
    description: []const u8,
};

/// Find a cell command matching the given full command string.
/// Searches cell.tri contributes.tri_subcommands across all cells.
/// Returns null if no cell claims this command.
pub fn findCellCommand(allocator: Allocator, full_command: []const u8) ?CellCommand {
    // Try cache first
    if (loadFromCache(allocator, full_command)) |cmd| return cmd;

    // Discover all cells and build command map
    const cells = discoverCellCommands(allocator) catch return null;
    defer {
        for (cells) |c| {
            allocator.free(c.cell_id);
            allocator.free(c.cell_path);
            allocator.free(c.command);
            allocator.free(c.description);
        }
        allocator.free(cells);
    }

    // Write cache for next time
    writeCache(allocator, cells) catch {};

    // Search for match — must dupe strings since defer frees the originals
    for (cells) |cmd| {
        if (std.mem.eql(u8, cmd.command, full_command)) {
            return CellCommand{
                .cell_id = allocator.dupe(u8, cmd.cell_id) catch return null,
                .cell_path = allocator.dupe(u8, cmd.cell_path) catch return null,
                .command = allocator.dupe(u8, cmd.command) catch return null,
                .description = allocator.dupe(u8, cmd.description) catch return null,
            };
        }
    }
    return null;
}

/// List all cell-contributed commands. Caller owns returned slice.
pub fn listCellCommands(allocator: Allocator) ![]CellCommand {
    return discoverCellCommands(allocator);
}

/// Execute a cell command by running `zig-out/bin/<binary>` or falling back to
/// printing info about the cell that provides the command.
pub fn executeCellCommand(allocator: Allocator, cmd: CellCommand, args: []const []const u8) !void {
    // Extract the first word of the command as potential binary name
    var iter = std.mem.splitScalar(u8, cmd.command, ' ');
    const base_cmd = iter.next() orelse cmd.command;

    // Try to find and run the binary
    const binary_path = std.fmt.allocPrint(allocator, "zig-out/bin/{s}", .{base_cmd}) catch {
        printCellCommandInfo(cmd);
        return;
    };
    defer allocator.free(binary_path);

    // Check if binary exists
    std.fs.cwd().access(binary_path, .{}) catch {
        // No binary — try running via `tri` subcommand delegation
        printCellCommandInfo(cmd);
        return;
    };

    // Build argv: binary + remaining command parts + user args
    var argv = std.array_list.Managed([]const u8).init(allocator);
    defer argv.deinit();
    try argv.append(binary_path);

    // Add subcommand parts after the first word
    while (iter.next()) |part| {
        try argv.append(part);
    }

    // Add user args
    for (args) |arg| {
        try argv.append(arg);
    }

    var child = std.process.Child.init(argv.items, allocator);
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    try child.spawn();
    const term = try child.wait();
    if (term.Exited != 0) {
        std.process.exit(term.Exited);
    }
}

fn printCellCommandInfo(cmd: CellCommand) void {
    std.debug.print("\x1b[36m[cell-dispatch]\x1b[0m Command '{s}' provided by cell {s} ({s})\n", .{
        cmd.command, cmd.cell_id, cmd.cell_path,
    });
    if (cmd.description.len > 0) {
        std.debug.print("  {s}\n", .{cmd.description});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DISCOVERY — Walk cell.tri files, parse contributes.tri_subcommands
// ═══════════════════════════════════════════════════════════════════════════════

fn discoverCellCommands(allocator: Allocator) ![]CellCommand {
    var results = std.array_list.Managed(CellCommand).init(allocator);
    errdefer {
        for (results.items) |c| {
            allocator.free(c.cell_id);
            allocator.free(c.cell_path);
            allocator.free(c.command);
            allocator.free(c.description);
        }
        results.deinit();
    }

    const cells = try cell_parser.discoverAll(allocator);
    defer allocator.free(cells);

    for (cells) |cell| {
        const m = cell.manifest;
        if (!m.hasSubcommands()) continue;

        var iter = cell_parser.ArrayIterator.init(m.contributes_tri_subcommands);
        while (iter.next()) |cmd_str| {
            try results.append(.{
                .cell_id = allocator.dupe(u8, m.id) catch continue,
                .cell_path = allocator.dupe(u8, m.path) catch continue,
                .command = allocator.dupe(u8, cmd_str) catch continue,
                .description = allocator.dupe(u8, m.description) catch continue,
            });
        }
    }

    return results.toOwnedSlice();
}

// ═══════════════════════════════════════════════════════════════════════════════
// CACHE — .trinity/command_cache.json
// ═══════════════════════════════════════════════════════════════════════════════

fn loadFromCache(allocator: Allocator, full_command: []const u8) ?CellCommand {
    const content = std.fs.cwd().readFileAlloc(allocator, CACHE_PATH, 262144) catch return null;
    defer allocator.free(content);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, content, .{}) catch return null;
    defer parsed.deinit();

    const root = parsed.value;
    const commands_val = switch (root) {
        .object => |obj| obj.get("commands") orelse return null,
        else => return null,
    };
    const items = switch (commands_val) {
        .array => |arr| arr.items,
        else => return null,
    };

    for (items) |item| {
        const obj = switch (item) {
            .object => |o| o,
            else => continue,
        };
        const cmd = switch (obj.get("command") orelse continue) {
            .string => |s| s,
            else => continue,
        };
        if (std.mem.eql(u8, cmd, full_command)) {
            const cell_id_raw = switch (obj.get("cell_id") orelse continue) {
                .string => |s| s,
                else => continue,
            };
            const cell_path_raw = switch (obj.get("cell_path") orelse continue) {
                .string => |s| s,
                else => continue,
            };
            const desc_raw = switch (obj.get("description") orelse return null) {
                .string => |s| s,
                else => "",
            };
            // Must dupe — parsed JSON is freed by defer above
            return CellCommand{
                .cell_id = allocator.dupe(u8, cell_id_raw) catch return null,
                .cell_path = allocator.dupe(u8, cell_path_raw) catch return null,
                .command = allocator.dupe(u8, cmd) catch return null,
                .description = allocator.dupe(u8, desc_raw) catch return null,
            };
        }
    }
    return null;
}

fn writeCache(allocator: Allocator, commands: []const CellCommand) !void {
    // Ensure .trinity/ exists
    std.fs.cwd().makePath(".trinity") catch {};

    var buf = std.array_list.Managed(u8).init(allocator);
    defer buf.deinit();
    const writer = buf.writer();

    try writer.writeAll("{\"commands\":[");
    for (commands, 0..) |cmd, i| {
        if (i > 0) try writer.writeByte(',');
        try writer.writeAll("{\"command\":\"");
        try writer.writeAll(cmd.command);
        try writer.writeAll("\",\"cell_id\":\"");
        try writer.writeAll(cmd.cell_id);
        try writer.writeAll("\",\"cell_path\":\"");
        try writer.writeAll(cmd.cell_path);
        try writer.writeAll("\",\"description\":\"");
        try writer.writeAll(cmd.description);
        try writer.writeAll("\"}");
    }
    try writer.writeAll("]}");

    const file = try std.fs.cwd().createFile(CACHE_PATH, .{});
    defer file.close();
    try file.writeAll(buf.items);
}

/// Invalidate the command cache (called by `tri cell check --sync`)
pub fn invalidateCache() void {
    std.fs.cwd().deleteFile(CACHE_PATH) catch {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// MCP TOOL GENERATION — `tri cell mcp-gen`
// ═══════════════════════════════════════════════════════════════════════════════

const MCP_TOOLS_PATH = "data/cells/mcp_tools.json";

pub fn runMcpGenCommand(allocator: Allocator) !void {
    std.debug.print("\x1b[36m[mcp-gen]\x1b[0m Scanning cells for MCP tool definitions...\n", .{});

    const cwd = std.fs.cwd();
    var cells_found: usize = 0;
    var tools_generated: usize = 0;

    var buf = std.array_list.Managed(u8).init(allocator);
    defer buf.deinit();
    const writer = buf.writer();

    try writer.writeAll("{\"tools\":[");

    const cells = try cell_parser.discoverAll(allocator);
    defer allocator.free(cells);

    for (cells) |cell| {
        const m = cell.manifest;
        cells_found += 1;

        // Generate tools from contributes.commands
        if (m.hasCommands()) {
            var cmd_iter = cell_parser.ArrayIterator.init(m.contributes_commands);
            while (cmd_iter.next()) |trimmed| {
                if (tools_generated > 0) try writer.writeByte(',');
                try writer.writeAll("\n  {\"name\":\"tri_");
                for (m.id) |c| try writer.writeByte(if (c == '.') '_' else c);
                try writer.writeByte('_');
                for (trimmed) |c| try writer.writeByte(if (c == ' ' or c == '-') '_' else c);
                try writer.writeAll("\",\"description\":\"[");
                try writer.writeAll(m.id);
                try writer.writeAll("] ");
                try writeJsonEscaped(writer, m.description);
                try writer.writeAll(" — ");
                try writer.writeAll(trimmed);
                try writer.writeAll("\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"args\":{\"type\":\"string\",\"description\":\"Arguments to pass\"}}}}");
                tools_generated += 1;
            }
        }

        // Generate tools from contributes.tri_subcommands
        if (m.hasSubcommands()) {
            var cmd_iter = cell_parser.ArrayIterator.init(m.contributes_tri_subcommands);
            while (cmd_iter.next()) |trimmed| {
                if (tools_generated > 0) try writer.writeByte(',');
                try writer.writeAll("\n  {\"name\":\"tri_");
                for (trimmed) |c| try writer.writeByte(if (c == ' ' or c == '-') '_' else c);
                try writer.writeAll("\",\"description\":\"tri ");
                try writer.writeAll(trimmed);
                try writer.writeAll(" — ");
                try writeJsonEscaped(writer, m.description);
                try writer.writeAll("\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"args\":{\"type\":\"string\",\"description\":\"Arguments to pass\"}}}}");
                tools_generated += 1;
            }
        }
    }

    try writer.writeAll("\n]}");

    // Ensure data/cells/ exists
    cwd.makePath("data/cells") catch {};

    const file = try cwd.createFile(MCP_TOOLS_PATH, .{});
    defer file.close();
    try file.writeAll(buf.items);

    std.debug.print("\x1b[32m✓\x1b[0m Scanned {d} cells, generated {d} MCP tools → {s}\n", .{
        cells_found, tools_generated, MCP_TOOLS_PATH,
    });
}

fn writeJsonEscaped(writer: anytype, s: []const u8) !void {
    for (s) |c| {
        if (c == '"') {
            try writer.writeAll("\\\"");
        } else if (c == '\\') {
            try writer.writeAll("\\\\");
        } else {
            try writer.writeByte(c);
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS — parser tests now live in tri_cell_parser.zig
// ═══════════════════════════════════════════════════════════════════════════════

test "cell dispatch uses shared parser" {
    const content =
        \\[cell]
        \\id = "trinity.arena"
        \\path = "src/arena"
        \\description = "LLM battle platform"
        \\
        \\[contributes]
        \\tri_subcommands = ["arena battle", "arena leaderboard"]
    ;
    const m = cell_parser.parse(content);
    try std.testing.expectEqualStrings("trinity.arena", m.id);
    try std.testing.expect(m.hasSubcommands());

    var iter = cell_parser.ArrayIterator.init(m.contributes_tri_subcommands);
    try std.testing.expectEqualStrings("arena battle", iter.next().?);
    try std.testing.expectEqualStrings("arena leaderboard", iter.next().?);
    try std.testing.expect(iter.next() == null);
}
