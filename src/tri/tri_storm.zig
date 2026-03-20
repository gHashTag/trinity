// @origin(spec:tri_storm_integration.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI STORM — STORM Subcommand Handler
// ═══════════════════════════════════════════════════════════════════════════════
//
// Usage: tri storm <subcommand> [options]
// Subcommands: run, status, resume, init
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const StormCommand = enum {
    run,
    status,
    @"resume",
    init,
};

pub fn runStormCommand(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    if (args.len < 1) {
        printUsage();
        return 1;
    }

    const subcommand = args[0];
    const command_args = args[1..];

    if (std.mem.eql(u8, subcommand, "run")) {
        return try cmdRun(allocator, command_args);
    } else if (std.mem.eql(u8, subcommand, "status")) {
        return try cmdStatus(allocator, command_args);
    } else if (std.mem.eql(u8, subcommand, "resume")) {
        return try cmdResume(allocator, command_args);
    } else if (std.mem.eql(u8, subcommand, "init")) {
        return try cmdInit(allocator);
    } else if (std.mem.eql(u8, subcommand, "--help") or std.mem.eql(u8, subcommand, "-h")) {
        printUsage();
        return 0;
    } else {
        std.debug.print("Unknown storm subcommand: {s}\n\n", .{subcommand});
        printUsage();
        return 1;
    }
}

fn cmdRun(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    // Parse --waves=N, --agents=M, --config=PATH
    var waves: u4 = 5;
    var agents: u8 = 32;
    var config_path: []const u8 = ".trinity/storm/config.json";
    var dry_run: bool = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        // Check for --flag=value format (e.g., --waves=5)
        if (std.mem.startsWith(u8, arg, "--")) {
            const eq_sign = std.mem.indexOfScalar(u8, arg, '=');
            if (eq_sign != null) {
                if (std.mem.startsWith(u8, arg, "--waves=")) {
                    waves = try std.fmt.parseInt(u4, arg[eq_sign.? + 1 ..], 10);
                } else if (std.mem.startsWith(u8, arg, "--agents=")) {
                    agents = try std.fmt.parseInt(u8, arg[eq_sign.? + 1 ..], 10);
                } else if (std.mem.startsWith(u8, arg, "--config=")) {
                    config_path = arg[eq_sign.? + 1 ..];
                } else if (std.mem.eql(u8, arg, "--dry-run")) {
                    dry_run = true;
                }
            }
        }
    }

    std.debug.print("\n🌪️  STORM RUN\n", .{});
    std.debug.print("  Waves:  {d}\n", .{waves});
    std.debug.print("  Agents: {d}\n", .{agents});
    std.debug.print("  Config: {s}\n", .{config_path});
    if (dry_run) {
        std.debug.print("  Mode: DRY RUN\n", .{});
    }
    std.debug.print("\n", .{});

    if (dry_run) {
        std.debug.print("DRY RUN: Would execute {d} waves with {d} agents\n", .{ waves, agents });
        std.debug.print("Golden Chain: 28 links\n", .{});
        std.debug.print("P1 Ethical Zones:\n", .{});
        std.debug.print("  - OFC (Values Chamber): toxic verdict\n", .{});
        std.debug.print("  - HABENULA (Anti-corruption sensor): unfair reward detection\n", .{});
        std.debug.print("  - AMYGDALA (Error Guardian): MNL blacklist enforcement\n\n", .{});
        return 0;
    }

    // TODO: Load config, initialize Golden Chain, execute STORM operation
    _ = allocator;

    std.debug.print("\n⚠️  STORM run not yet fully implemented\n", .{});
    std.debug.print("Run with --dry-run to see what would happen\n\n", .{});
    return 0;
}

fn cmdStatus(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    _ = args;
    _ = allocator;

    std.debug.print("\n🌪️  STORM STATUS\n", .{});
    std.debug.print("─────────────────────────\n", .{});

    const checkpoint_dir = ".trinity/storm/checkpoints";
    var dir = std.fs.cwd().openDir(checkpoint_dir, .{ .iterate = true }) catch {
        std.debug.print("No checkpoints found. Run 'tri storm init' first.\n\n", .{});
        return 0;
    };

    var count: usize = 0;
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".json")) {
            count += 1;
            std.debug.print("Checkpoint: {s}\n", .{entry.name});
        }
    }

    if (count == 0) {
        std.debug.print("No checkpoints found.\n", .{});
    } else {
        std.debug.print("Total checkpoints: {d}\n", .{count});
    }

    std.debug.print("\n", .{});
    dir.close();
    return 0;
}

fn cmdResume(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    _ = allocator;

    var checkpoint_id: ?[]const u8 = null;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--checkpoint") and i + 1 < args.len) {
            i += 1;
            checkpoint_id = args[i];
        }
    }

    std.debug.print("\n🌪️  STORM RESUME\n", .{});
    std.debug.print("─────────────────────────\n", .{});

    if (checkpoint_id) |id| {
        std.debug.print("Resuming from checkpoint: {s}\n", .{id});
    } else {
        std.debug.print("Resuming from latest checkpoint\n", .{});
    }

    std.debug.print("Resume not yet implemented.\n\n", .{});
    return 0;
}

fn cmdInit(allocator: std.mem.Allocator) !u8 {
    _ = allocator;

    std.debug.print("\n🌪️  STORM INIT\n", .{});
    std.debug.print("─────────────────────────\n", .{});

    const dirs = [_][]const u8{
        ".trinity/storm",
        ".trinity/storm/checkpoints",
        ".trinity/mistakes",
        ".trinity/experience",
        ".trinity/phoenix",
        ".trinity/phoenix/checkpoints",
    };

    for (dirs) |dir_path| {
        std.fs.cwd().makePath(dir_path) catch |err| {
            if (err != error.PathAlreadyExists) {
                std.debug.print("Failed to create {s}: {}\n", .{ dir_path, err });
                return 1;
            }
        };
        std.debug.print("Created {s}\n", .{dir_path});
    }

    std.debug.print("\n✅ STORM initialized!\n\n", .{});
    std.debug.print("Next steps:\n", .{});
    std.debug.print("  tri storm run            — Execute STORM\n", .{});
    std.debug.print("  tri storm run --waves=3  — Custom wave count\n", .{});
    std.debug.print("  tri storm status         — Show checkpoint status\n\n", .{});

    return 0;
}

fn printUsage() void {
    std.debug.print(
        \\
        \\🌪️  STORM — Self-Organizing Regenerative Task Management
        \\
        \\Usage: tri storm <subcommand> [options]
        \\
        \\Subcommands:
        \\  run        Execute STORM operation
        \\  status     Show checkpoint status
        \\  resume     Continue from checkpoint
        \\  init       Initialize STORM structure
        \\
        \\Options:
        \\  --waves N         Number of waves (default: 5)
        \\  --agents M        Number of agents (default: 32)
        \\  --config PATH     Config file path
        \\  --dry-run         Simulation only
        \\  --checkpoint ID   Resume from specific checkpoint
        \\
        \\Examples:
        \\  tri storm init                              — Initialize STORM
        \\  tri storm run                               — Run with defaults
        \\  tri storm run --waves=3 --agents=16        — Custom configuration
        \\  tri storm status                            — Show checkpoint status
        \\
    , .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// BRAIN ZONE COMMANDS (P1 Ethical Infrastructure)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runOFCCommand(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    _ = allocator;

    // Usage: tri ofc verdict --toxic "action description"
    if (args.len < 1) {
        std.debug.print("Usage: tri ofc verdict --toxic \"action description\"\n", .{});
        return 1;
    }

    const subcommand = args[0];
    if (std.mem.eql(u8, subcommand, "verdict")) {
        // Parse --toxic flag and action
        var action: []const u8 = "";
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            if (args[i][0] != '-') {
                action = args[i];
            }
        }

        if (action.len == 0) {
            std.debug.print("Usage: tri ofc verdict --toxic \"action description\"\n", .{});
            return 1;
        }

        std.debug.print("\n🧠 OFC — Values Chamber\n", .{});
        std.debug.print("─────────────────────────\n", .{});
        std.debug.print("  Action: {s}\n", .{action});
        std.debug.print("  Mode: toxic verdict\n", .{});
        std.debug.print("\n⚠️  OFC verdict not yet fully implemented\n", .{});
        std.debug.print("TODO: 12D ethical metric system\n\n", .{});

        return 0;
    }

    std.debug.print("Unknown ofc subcommand: {s}\n", .{subcommand});
    return 1;
}

pub fn runHabenulaCommand(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    _ = allocator;

    if (args.len < 1) {
        std.debug.print("Usage: tri habenula unfair_detect\n", .{});
        return 1;
    }

    const subcommand = args[0];
    if (std.mem.eql(u8, subcommand, "unfair_detect")) {
        std.debug.print("\n🧠 HABENULA — Anti-corruption sensor\n", .{});
        std.debug.print("───────────────────────────────────\n\n", .{});

        // TODO: Implement unfair detection logic
        std.debug.print("⚠️  Habenula unfair_detect not yet implemented\n", .{});
        std.debug.print("TODO: reward/effort ratio analysis\n\n", .{});

        return 0;
    }

    std.debug.print("Unknown habenula subcommand: {s}\n", .{subcommand});
    return 1;
}

pub fn runAmygdalaCommand(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    _ = allocator;

    if (args.len < 1) {
        std.debug.print("Usage: tri amygdala check_fear \"task description\"\n", .{});
        return 1;
    }

    const subcommand = args[0];
    if (std.mem.eql(u8, subcommand, "check_fear")) {
        if (args.len < 2) {
            std.debug.print("Usage: tri amygdala check_fear \"task description\"\n", .{});
            return 1;
        }

        const task = args[1];

        std.debug.print("\n🧠 AMYGDALA — Error Guardian\n", .{});
        std.debug.print("────────────────────────────\n", .{});
        std.debug.print("  Task: {s}\n", .{task});
        std.debug.print("  Fear level: checking...\n", .{});
        std.debug.print("\n⚠️  Amygdala check_fear not yet fully implemented\n", .{});
        std.debug.print("TODO: MNL pattern (3x failed = blacklist)\n\n", .{});

        return 0;
    }

    if (std.mem.eql(u8, subcommand, "list")) {
        std.debug.print("\n🧠 AMYGDALA — Blacklist\n", .{});
        std.debug.print("──────────────────────\n\n", .{});
        std.debug.print("(List not yet implemented)\n\n", .{});
        return 0;
    }

    std.debug.print("Unknown amygdala subcommand: {s}\n", .{subcommand});
    return 1;
}
