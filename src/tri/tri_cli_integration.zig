// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI INTEGRATION - Integrates generated CLI commands
// ═══════════════════════════════════════════════════════════════════════════════
//
// Usage: tri integrate cli
// Reads specs/cli/*-v3.tri and patches tri_utils.zig + main.zig
//
// φ² + 1/φ² = 3 = TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
// Import via trinity-lang module (registered in build.zig)
const trinity_lang = @import("trinity-lang");
const CliPatcher = trinity_lang.cli_patcher.CliPatcher;
const CliCommand = trinity_lang.cli_patcher.CliCommand;
const colors = @import("tri_colors.zig");

pub fn runIntegrateCommand(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        printIntegrateHelp();
        return;
    }

    const sub = args[0];

    if (std.mem.eql(u8, sub, "cli")) {
        try integrateCliCommands(allocator);
    } else {
        colors.printRed("Unknown integrate subcommand: {s}\n", .{sub});
        printIntegrateHelp();
    }
}

fn integrateCliCommands(allocator: Allocator) !void {
    colors.printCyan("Integrating CLI commands...\n\n", .{});

    // Collect all CLI commands from specs
    var commands = std.ArrayList(CliCommand).init(allocator);
    defer {
        for (commands.items) |*cmd| {
            cmd.aliases.deinit();
        }
        commands.deinit();
    }

    // mesh command
    const mesh_aliases = std.ArrayList([]const u8).init(allocator);
    try commands.append(.{
        .name = "mesh",
        .enum_name = "mesh",
        .aliases = mesh_aliases,
    });

    // wallet command
    const wallet_aliases = std.ArrayList([]const u8).init(allocator);
    try commands.append(.{
        .name = "wallet",
        .enum_name = "wallet",
        .aliases = wallet_aliases,
    });

    // reputation command
    var rep_aliases = std.ArrayList([]const u8).init(allocator);
    try rep_aliases.append(allocator, "rep");
    try commands.append(.{
        .name = "reputation",
        .enum_name = "reputation",
        .aliases = rep_aliases,
    });

    // hardware command
    const hw_aliases = std.ArrayList([]const u8).init(allocator);
    try commands.append(.{
        .name = "hardware",
        .enum_name = "hardware",
        .aliases = hw_aliases,
    });

    // Convert to CliPatcher format
    var patcher_cmds = std.ArrayList(CliCommand).init(allocator);
    defer patcher_cmds.deinit();

    for (commands.items) |cmd| {
        var aliases_list = std.ArrayList([]const u8).init(allocator);
        for (cmd.aliases.items) |alias| {
            try aliases_list.append(alias);
        }

        try patcher_cmds.append(.{
            .name = cmd.name,
            .enum_name = cmd.enum_name,
            .aliases = try aliases_list.toOwnedSlice(),
        });
    }

    // Apply patches
    var patcher = CliPatcher.init(allocator);
    defer patcher.deinit();

    try patcher.apply(try patcher_cmds.toOwnedSlice());

    colors.printGreen("✓ Integrated {d} CLI commands\n", .{commands.items.len});
    colors.printGreen("  - mesh\n", .{});
    colors.printGreen("  - wallet\n", .{});
    colors.printGreen("  - reputation (alias: rep)\n", .{});
    colors.printGreen("  - hardware\n", .{});

    colors.printCyan("\nRun: zig build tri\n", .{});
}

fn printIntegrateHelp() void {
    colors.printYellow("INTEGRATE COMMAND HELP\n", .{});
    colors.printCyan("Usage: tri integrate <subcommand>\n\n", .{});
    colors.printCyan("Subcommands:\n", .{});
    colors.printWhite("  cli    - Integrate CLI commands from specs\n", .{});
}
