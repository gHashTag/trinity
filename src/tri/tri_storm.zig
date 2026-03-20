// @origin(spec:tri_storm_integration.tri) @regen(manual-impl)
const std = @import("std");

// TODO: P1: Import real brain zone implementations via module names
// These modules will be implemented as separate files in the future
// const ofc_module = @import("storm_ofc");
// const habenula_module = @import("storm_habenula");
// const amygdala_module = @import("storm_amygdala");

// Temporary stub implementations until storm modules are created

const OFCStub = struct {
    pub fn cmdVerdict(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
        _ = allocator;
        _ = args;
        std.debug.print("🧠 OFC Verdict: toxic verdict analysis (STUB)\n", .{});
        return 0;
    }
};

const HabenulaStub = struct {
    pub fn cmdUnfairDetect(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
        _ = allocator;
        _ = args;
        std.debug.print("🧠 Habenula: unfair detection (STUB)\n", .{});
        return 0;
    }
};

const AmygdalaStub = struct {
    pub const Amygdala = struct {
        allocator: std.mem.Allocator,
    };

    pub fn cmdCheckFear(amygdala: *const AmygdalaStub.Amygdala, task: []const u8) !void {
        _ = amygdala;
        std.debug.print("🧠 Amygdala: checking fear level for '{s}' (STUB)\n", .{task});
    }
};

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

pub fn runOFCCommand(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    if (args.len < 1) {
        std.debug.print("Usage: tri ofc verdict <action>\n", .{});
        return 1;
    }
    const subcommand = args[0];
    if (std.mem.eql(u8, subcommand, "verdict")) {
        return try OFCStub.cmdVerdict(allocator, args[1..]);
    }
    std.debug.print("Unknown OFC subcommand: {s}\n", .{subcommand});
    return 1;
}

pub fn runHabenulaCommand(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    if (args.len < 1) {
        std.debug.print("Usage: tri habenula unfair-detect\n", .{});
        return 1;
    }
    const subcommand = args[0];
    if (std.mem.eql(u8, subcommand, "unfair-detect")) {
        return try HabenulaStub.cmdUnfairDetect(allocator, args[1..]);
    }
    std.debug.print("Unknown HABENULA subcommand: {s}\n", .{subcommand});
    return 1;
}

pub fn runAmygdalaCommand(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    if (args.len < 1) {
        std.debug.print("Usage: tri amygdala check-fear <task>\n", .{});
        return 1;
    }
    const subcommand = args[0];
    if (std.mem.eql(u8, subcommand, "check-fear")) {
        if (args.len < 2) {
            std.debug.print("Error: check-fear requires a task name\n", .{});
            return 1;
        }
        var amg = AmygdalaStub.Amygdala{ .allocator = allocator };
        try AmygdalaStub.cmdCheckFear(&amg, args[1]);
        return 0;
    }
    std.debug.print("Unknown AMYGDALA subcommand: {s}\n", .{subcommand});
    return 1;
}

fn cmdRun(_allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    _ = _allocator;

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

fn cmdStatus(_allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    _ = args;
    _ = _allocator;

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

fn cmdResume(_allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    _ = args;
    _ = _allocator;

    std.debug.print("\n🌪️  STORM RESUME─────────────────────────\n", .{});
    std.debug.print("Resume not yet implemented.\n\n", .{});
    return 0;
}

fn cmdInit(_allocator: std.mem.Allocator) !u8 {
    _ = _allocator;

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
        \\🌪️  STORM — Self-Organizing Regenerative Task Management
        \\Usage: tri storm <subcommand> [options]
        \\Subcommands:
        \\  run        Execute STORM operation
        \\  status     Show checkpoint status
        \\  resume     Continue from checkpoint
        \\  init       Initialize STORM structure
        \\Options:
        \\  --waves N         Number of waves (default:5)
        \\  --agents M        Number of agents (default: 32)
        \\  --config PATH     Config file path
        \\  --dry-run         Simulation only
        \\Examples:
        \\  tri storm init                              — Initialize STORM
        \\  tri storm run                               — Run with defaults
        \\  tri storm run --waves=3 --agents=16        — Custom configuration
        \\  tri storm status                            — Show checkpoint status
        , .{}
    );
}
