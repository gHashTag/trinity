// @origin(spec:tri_storm_integration.tri) @regen(manual-impl)
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

// P1: Import real brain zone implementations
const ofc_module = @import("src/storm/brain_zones/ofc.zig");
const habenula_module = @import("src/storm/brain_zones/habenula.zig");
const amygdala_module = @import("src/storm/brain_zones/amygdala.zig");

pub fn runOFCCommand(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    const action = if (args.len >= 1) args[0] else "verdict";
    return ofc_module.OFC.cmdVerdict(allocator, action);
}

pub fn runHabenulaCommand(allocator: std.mem.Allocator, args: []const u8) !u8 {
    return habenula_module.unfairDetect(allocator);
}

pub fn runAmygdalaCommand(allocator: std.mem.Allocator, args: []const u8) !u8 {
    if (args.len < 2) {
        std.debug.print("Usage: tri amygdala check_fear \"task description\"\n", .{});
        return 1;
    }
    const task = if (args.len >= 1) args[1] else "";

    return amygdala_module.checkFear(allocator, task);
}

fn cmdRun(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    var waves: u4 = 5;
    var agents: u8 = 32;
    var dry_run: bool = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.startsWith(u8, arg, "--")) {
            const eq_sign = std.mem.indexOfScalar(u8, arg, '=');
            if (eq_sign != null) {
                if (std.mem.startsWith(u8, arg, "--waves=")) {
                    waves = try std.fmt.parseInt(u4, arg[eq_sign.? + 1 ..], 10);
                } else if (std.mem.startsWith(u8, arg, "--agents=")) {
                    agents = try std.fmt.parseInt(u8, arg[eq_sign.? + 1 ..], 10);
                } else if (std.mem.startsWith(u8, arg, "--config=")) {
                    _ = arg[eq_sign.? + 1 ..];
                }
            } else if (std.mem.eql(u8, arg, "--dry-run")) {
                dry_run = true;
            }
        }
    }

    std.debug.print("\n🌪️  STORM RUN\n", .{});
    std.debug.print("  Waves:  {d}\n", .{waves});
    std.debug.print("  Agents: {d}\n", .{agents});
    if (dry_run) {
        std.debug.print("  Mode: DRY RUN\n\n", .{});
        std.debug.print("DRY RUN: {d} waves, {d} agents\n", .{waves, agents});
        std.debug.print("Golden Chain: 28 links\n", .{});
        std.debug.print("P1 Ethical Zones:\n", .{});
        std.debug.print("  - OFC: toxic verdict\n", .{});
        std.debug.print("  - HABENULA: unfair detection\n", .{});
        std.debug.print("  - AMYGDALA: MNL blacklist\n\n", .{});
        return 0;
    }

    std.debug.print("\n⚠️  STORM run not yet implemented\n\n", .{});
    return 0;
}

fn cmdStatus(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    _ = args;
    _ = allocator;

    std.debug.print("\n🌪️  STORM STATUS\n─────────────────────────\n", .{});

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

    std.debug.print("\n🌪️  STORM RESUME─────────────────────────\n", .{});
    std.debug.print("Resume not yet implemented.\n\n", .{});
    return 0;
}

fn cmdInit(allocator: std.mem.Allocator) !u8 {
    _ = allocator;

    std.debug.print("\n🌪️  STORM INIT─────────────────────────\n", .{});

    const dirs = [_][]const u8{
        ".trinity/storm",
        ".trinity/storm/checkpoints",
        ".trinity/mistakes",
        ".trinity/experience",
        ".trinity/phoenix",
        ".trinity/phoenix/checkpoints",
    };

    for (dirs) |dir_path| {
        std.fs.cwd().makePath(dir_path) catch {};
    }

    std.debug.print("\n✅ STORM initialized!\n\n", .{});
    return 0;
}

fn printUsage() void {
    std.debug.print(
        \\🌪️  STORM — Self-Organizing Regenerative Task Management\\
        \\Usage: tri storm <subcommand> [options]\\
        \\Subcommands:\\
        \\  run        Execute STORM operation\\
        \\  status     Show checkpoint status\\
        \\  resume     Continue from checkpoint\\
        \\  init       Initialize STORM structure\\
        \\Options:\\
        \\  --waves N         Number of waves (default: 5)\\
        \\  --agents M        Number of agents (default: 32)\\
        \\  --config PATH     Config file path\\
        \\  --dry-run         Simulation only\\
        \\Examples:\\
        \\  tri storm init                              — Initialize STORM\\
        \\  tri storm run                               — Run with defaults\\
        \\  tri storm run --waves=3 --agents=16        — Custom configuration\\
        \\  tri storm status                            — Show checkpoint status\\
        , .{}
    );
}
