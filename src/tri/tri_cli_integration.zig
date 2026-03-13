// @origin(manual) @regen(pending)
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

    // Prepare command data - aliases are static slices
    const empty_aliases: []const []const u8 = &.{};
    const rep_aliases: []const []const u8 = &.{"rep"};

    // Static array of commands to integrate
    const commands = [_]CliCommand{
        .{ .name = "mesh", .enum_name = "mesh", .aliases = empty_aliases },
        .{ .name = "wallet", .enum_name = "wallet", .aliases = empty_aliases },
        .{ .name = "reputation", .enum_name = "reputation", .aliases = rep_aliases },
        .{ .name = "hardware", .enum_name = "hardware", .aliases = empty_aliases },
    };

    // Apply patches
    var patcher = CliPatcher.init(allocator);
    defer patcher.deinit();

    try patcher.apply(&commands);

    colors.printGreen("✓ Integrated {d} CLI commands\n", .{commands.len});
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
