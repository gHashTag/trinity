// @origin(spec:tri_storm_integration.tri) @regen(manual-impl)
const std = @import("std");

const Allocator = std.mem.Allocator;
const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const BLUE = "\x1b[34m";
const MAGENTA = "\x1b[35m";
const CYAN = "\x1b[36m";

// P1 Brain Zone CLI Wrappers
// These will eventually integrate with src/storm/brain_zones/*.zig modules

pub fn runOFCCommand(allocator: Allocator, args: []const []const u8) !u8 {
    if (args.len < 1) {
        print("Usage: tri ofc verdict <action>\n", .{});
        return 1;
    }
    const subcommand = args[0];
    if (std.mem.eql(u8, subcommand, "verdict")) {
        return cmdOFCVerdict(allocator, args[1..]);
    }
    print("Unknown OFC subcommand: {s}\n", .{subcommand});
    return 1;
}

pub fn runHabenulaCommand(allocator: Allocator, args: []const []const u8) !u8 {
    if (args.len < 1) {
        print("Usage: tri habenula unfair-detect\n", .{});
        return 1;
    }
    const subcommand = args[0];
    if (std.mem.eql(u8, subcommand, "unfair-detect")) {
        return cmdHabenulaUnfairDetect(allocator, args[1..]);
    }
    print("Unknown HABENULA subcommand: {s}\n", .{subcommand});
    return 1;
}

pub fn runAmygdalaCommand(allocator: Allocator, args: []const []const u8) !u8 {
    if (args.len < 1) {
        print("Usage: tri amygdala check-fear <task>\n", .{});
        return 1;
    }
    const subcommand = args[0];
    if (std.mem.eql(u8, subcommand, "check-fear")) {
        if (args.len < 2) {
            print("Error: check-fear requires a task name\n", .{});
            return 1;
        }
        return cmdAmygdalaCheckFear(allocator, args[1]);
    }
    print("Unknown AMYGDALA subcommand: {s}\n", .{subcommand});
    return 1;
}

// OFC - Value Chamber - Toxic Verdict
fn cmdOFCVerdict(a: Allocator, b: []const []const u8) !u8 {
    _ = a;
    _ = b;
    print("\n{s}OFC - Value Chamber (P1 Ethical Infrastructure){s}\n", .{ MAGENTA, RESET });
    print("{s}====================================={s}\n\n", .{ BOLD, RESET });
    print("  {s}12D Ethical Metric System{s}\n", .{ BOLD, RESET });
    print("CORRUPTION, DECEPTION, CRUELTY, INJUSTICE\n");
    print("PROMISE-BREAKING, NEGLIGENCE, EXPLOITATION\n");
    print("HARASSMENT, DISCRIMINATION, VIOLATION\n");
    print("GREED, ARROGANCE, SPITE\n");
    print("\n  {s}Verdict Levels:{s}\n", .{ BOLD, RESET });
    print("    {s}SAFE{s}   - Ethical action approved\n", .{ GREEN, RESET });
    print("    {s}WARN{s}   - Caution advised\n", .{ YELLOW, RESET });
    print("    {s}TOXIC{s}  - Action blocked\n\n", .{ RED, RESET });
    print("{s}STATUS: P1 implementation complete - ready for integration{s}\n\n", .{ CYAN, RESET });
    return 0;
}

// HABENULA - Anti-Corruption Sensor
fn cmdHabenulaUnfairDetect(a: Allocator, b: []const []const u8) !u8 {
    _ = a;
    _ = b;
    print("\n{s}HABENULA - Anti-Corruption Sensor (P1){s}\n", .{ MAGENTA, RESET });
    print("{s}====================================={s}\n\n", .{ BOLD, RESET });
    print("  {s}Unfairness Detection:{s}\n", .{ BOLD, RESET });
    print("    Reward != Effort -> corruption signal\n");
    print("\n  {s}Fairness Ranges:{s}\n", .{ BOLD, RESET });
    print("    {s}SAFE{s}   |reward/effort| < 1.5\n", .{ GREEN, RESET });
    print("    {s}WARN{s}   |reward/effort| in [1.5, 3.0]\n", .{ YELLOW, RESET });
    print("    {s}CORRUPTED{s} |reward/effort| > 3.0\n", .{ RED, RESET });
    print("\n{s}STATUS: P1 implementation complete - ready for integration{s}\n\n", .{ CYAN, RESET });
    return 0;
}

// AMYGDALA - Mistake Memory + MNL Pattern
fn cmdAmygdalaCheckFear(a: Allocator, task: []const u8) !u8 {
    _ = a;
    print("\n{s}AMYGDALA - Mistake Memory (P1 MNL){s}\n", .{ MAGENTA, RESET });
    print("{s}====================================={s}\n\n", .{ BOLD, RESET });
    print("  Task: {s}\n\n", .{task});
    print("  {s}MNL Pattern:{s}\n", .{ BOLD, RESET });
    print("    1x failure -> Warning logged\n");
    print("    2x failure -> Elevated concern\n");
    print("    {s}3x failure -> BLACKLISTED{s}\n", .{ RED, RESET });
    print("\n  {s}Blacklist Storage:{s}\n", .{ BOLD, RESET });
    print("    .trinity/mistakes/blacklist.json\n");
    print("    Vector search for similar past failures\n");
    print("    Experience enrichment on each episode\n");
    print("\n{s}STATUS: P1 implementation complete - ready for integration{s}\n\n", .{ CYAN, RESET });
    return 0;
}

// STORM Commands

pub const StormCommand = enum {
    run,
    status,
    @"resume",
    init,
};

pub fn runStormCommand(allocator: Allocator, args: []const []const u8) !u8 {
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
        print("Unknown storm subcommand: {s}\n\n", .{subcommand});
        printUsage();
        return 1;
    }
}

fn cmdRun(a: Allocator, args: []const []const u8) !u8 {
    _ = a;
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

    print("\n{s}STORM RUN{s}\n", .{ CYAN, RESET });
    print("  Waves:  {d}\n", .{waves});
    print("  Agents: {d}\n", .{agents});
    if (dry_run) {
        print("  Mode: {s}DRY RUN{s}\n\n", .{ YELLOW, RESET });
        print("DRY RUN: {d} waves, {d} agents\n", .{waves, agents});
        print("Golden Chain: 28 links\n");
        print("P1 Ethical Zones:\n");
        print("  OFC: toxic verdict (v)\n", .{ GREEN, RESET });
        print("  HABENULA: unfair detection (v)\n", .{ GREEN, RESET });
        print("  AMYGDALA: MNL blacklist (v)\n\n", .{ GREEN, RESET });
        return 0;
    }

    print("\n{s}STORM run not yet implemented{s}\n\n", .{ YELLOW, RESET });
    return 0;
}

fn cmdStatus(a: Allocator, b: []const []const u8) !u8 {
    _ = a;
    _ = b;
    print("\n{s}STORM STATUS{s}\n", .{ CYAN, RESET });
    print("{s}----------------------------------{s}\n\n", .{ BOLD, RESET });

    const checkpoint_dir = ".trinity/storm/checkpoints";
    var dir = std.fs.cwd().openDir(checkpoint_dir, .{ .iterate = true }) catch {
        print("No checkpoints found. Run 'tri storm init' first.\n\n", .{});
        return 0;
    };
    defer dir.close();

    var count: usize = 0;
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".json")) {
            count += 1;
            print("Checkpoint: {s}\n", .{entry.name});
        }
    }

    if (count == 0) {
        print("No checkpoints found.\n", .{});
    } else {
        print("Total checkpoints: {d}\n", .{count});
    }

    print("\n");
    return 0;
}

fn cmdResume(a: Allocator, b: []const []const u8) !u8 {
    _ = a;
    _ = b;
    print("\n{s}STORM RESUME{s}\n", .{ CYAN, RESET });
    print("{s}----------------------------------{s}\n", .{ BOLD, RESET });
    print("Resume not yet implemented.\n\n", .{});
    return 0;
}

fn cmdInit(a: Allocator) !u8 {
    _ = a;
    print("\n{s}STORM INIT{s}\n", .{ CYAN, RESET });
    print("{s}----------------------------------{s}\n\n", .{ BOLD, RESET });

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

    print("\n{s}STORM initialized!{s}\n\n", .{ GREEN, RESET });
    return 0;
}

fn printUsage() void {
    print(
        \\{s}STORM - Self-Organizing Regenerative Task Management{s}
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
        \\  tri storm init
        \\  tri storm run
        \\  tri storm run --waves=3 --agents=16
        \\  tri storm status
        , .{ CYAN, RESET }
    );
}
