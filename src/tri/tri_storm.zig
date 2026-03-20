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

const storm_config = @import("../storm/config.zig");
const golden_chain = @import("../storm/golden_chain.zig");
const phoenix_bridge = @import("../storm/phoenix_bridge.zig");
const ofc = @import("../storm/brain_zones/ofc.zig");
const habenula = @import("../storm/brain_zones/habenula.zig");
const amygdala = @import("../storm/brain_zones/amygdala.zig");

pub const StormCommand = enum {
    run,
    status,
    resume,
    init,
};

pub fn runStormCommand(allocator: std.mem.Allocator, args: [][]const u8) !u8 {
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

fn cmdRun(allocator: std.mem.Allocator, args: [][]const u8) !u8 {
    // Parse --waves=N, --agents=M, --config=PATH
    var waves: u4 = 5;
    var agents: u8 = 32;
    var config_path: []const u8 = ".trinity/storm/config.json";
    var dry_run: bool = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--waves") and i + 1 < args.len) {
            i += 1;
            waves = try std.fmt.parseInt(u4, args[i], 10);
        } else if (std.mem.eql(u8, args[i], "--agents") and i + 1 < args.len) {
            i += 1;
            agents = try std.fmt.parseInt(u8, args[i], 10);
        } else if (std.mem.eql(u8, args[i], "--config") and i + 1 < args.len) {
            i += 1;
            config_path = args[i];
        } else if (std.mem.eql(u8, args[i], "--dry-run")) {
            dry_run = true;
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
        std.debug.print("  - OFC (Палата ценностей): toxic verdict\n", .{});
        std.debug.print("  - HABENULA (Антикоррупция): unfair reward detection\n", .{});
        std.debug.print("  - AMYGDALA (Страж ошибок): MNL blacklist enforcement\n\n", .{});
        return 0;
    }

    // Load config
    var config = try storm_config.StormConfig.load(allocator, config_path);
    config.waves = waves;
    config.agents = agents;

    // Initialize Golden Chain
    var chain = try golden_chain.GoldenChain.init(allocator, config.checkpoint_dir);
    defer chain.deinit();

    // Execute STORM operation
    const result = try chain.run("STORM operation");

    if (result.success) {
        std.debug.print("\n✅ STORM run complete!\n", .{});
        return 0;
    } else {
        std.debug.print("\n❌ STORM run failed: {s}\n", .{result.error_msg orelse "unknown error"});
        return 1;
    }
}

fn cmdStatus(allocator: std.mem.Allocator, args: [][]const u8) !u8 {
    _ = args;
    _ = allocator;

    std.debug.print("\n🌪️  STORM STATUS\n", .{});
    std.debug.print("─────────────────────────\n", .{});

    const checkpoint_dir = ".trinity/storm/checkpoints";
    const dir = std.fs.cwd().openDir(checkpoint_dir, .{ .iterate = true }) catch {
        std.debug.print("No checkpoints found. Run 'tri storm init' first.\n\n", .{});
        return 0;
    };
    defer dir.close();

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
    return 0;
}

fn cmdResume(allocator: std.mem.Allocator, args: [][]const u8) !u8 {
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

    for (dirs) |dir| {
        std.fs.cwd().makePath(dir) catch |err| {
            if (err != error.PathAlreadyExists) {
                std.debug.print("Failed to create {s}: {}\n", .{ dir, err });
                return 1;
            }
        };
        std.debug.print("Created {s}\n", .{dir});
    }

    // Create default config
    var config = try storm_config.StormConfig.load(allocator, ".trinity/storm/config.json");
    try config.save(allocator);

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

pub fn runOFCCommand(allocator: std.mem.Allocator, args: [][]const u8) !u8 {
    // Usage: tri ofc verdict --toxic "action description"
    _ = allocator;

    if (args.len < 1) {
        std.debug.print("Usage: tri ofc verdict --toxic \"action description\"\n", .{});
        return 1;
    }

    const subcommand = args[0];
    if (std.mem.eql(u8, subcommand, "verdict")) {
        // Parse --toxic flag and action
        var has_toxic: bool = false;
        var action: []const u8 = "";
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--toxic")) {
                has_toxic = true;
            } else if (args[i][0] != '-') {
                action = args[i];
            }
        }

        if (action.len == 0) {
            std.debug.print("Usage: tri ofc verdict --toxic \"action description\"\n", .{});
            return 1;
        }

        var ofc_instance = ofc.OFC{
            .allocator = allocator,
        };

        const ctx = ofc.Context{
            .timestamp = std.time.timestamp(),
            .task = action,
        };
        const act = ofc.Action{
            .description = action,
        };

        const result = try ofc_instance.verdict(ctx, act);

        const emoji = switch (result.verdict) {
            .safe => "✅",
            .warn => "⚠️ ",
            .toxic => "🚫",
        };
        const color = switch (result.verdict) {
            .safe => "\x1b[32m",
            .warn => "\x1b[33m",
            .toxic => "\x1b[31m",
        };
        const reset = "\x1b[0m";

        std.debug.print("{s}{s} OFC Verdict: {s}{s}\n", .{ color, emoji, @tagName(result.verdict), reset });
        std.debug.print("  Average: {d:.3}\n", .{result.average});
        std.debug.print("  Reason: {s}\n", .{result.reason});

        return if (result.verdict == .toxic) 1 else 0;
    }

    std.debug.print("Unknown ofc subcommand: {s}\n", .{subcommand});
    return 1;
}

pub fn runHabenulaCommand(allocator: std.mem.Allocator, args: [][]const u8) !u8 {
    // Usage: tri habenula unfair_detect
    _ = allocator;

    if (args.len < 1) {
        std.debug.print("Usage: tri habenula unfair_detect\n", .{});
        return 1;
    }

    const subcommand = args[0];
    if (std.mem.eql(u8, subcommand, "unfair_detect")) {
        var hb = habenula.Habenula{
            .allocator = allocator,
        };

        std.debug.print("\n🧠 HABENULA — Антикоррупционный датчик\n", .{});
        std.debug.print("────────────────────────────────────────\n\n", .{});

        const scenarios = [_]struct {
            reward: habenula.Reward,
            effort: habenula.Effort,
            desc: []const u8,
        }{
            .{ .reward = .{ .amount = 100 }, .effort = .{ .hours = 10 }, .desc = "Normal: 10h → 100 reward (ratio 1.0)" },
            .{ .reward = .{ .amount = 200 }, .effort = .{ .hours = 10 }, .desc = "Suspicious: 10h → 200 reward (ratio 2.0)" },
            .{ .reward = .{ .amount = 500 }, .effort = .{ .hours = 5 }, .desc = "Corrupted: 5h → 500 reward (ratio 10.0)" },
        };

        for (scenarios) |sc| {
            const fairness = try hb.unfairDetect(sc.reward, sc.effort);
            const emoji = switch (fairness) {
                .fair => "⚖️ ",
                .suspicious => "🔍",
                .corrupted => "🚨",
            };
            std.debug.print("  {s} {s}\n", .{ emoji, sc.desc });
        }

        std.debug.print("\n", .{});
        return 0;
    }

    std.debug.print("Unknown habenula subcommand: {s}\n", .{subcommand});
    return 1;
}

pub fn runAmygdalaCommand(allocator: std.mem.Allocator, args: [][]const u8) !u8 {
    // Usage: tri amygdala check_fear "task description"
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
        var amg = amygdala.Amygdala{
            .allocator = allocator,
        };

        try amg.cmdCheckFear(task);
        return 0;
    }

    if (std.mem.eql(u8, subcommand, "list")) {
        std.debug.print("\n🧠 AMYGDALA — Blacklist\n", .{});
        std.debug.print("────────────────────────\n\n", .{});
        // TODO: List blacklisted tasks
        std.debug.print("(List not yet implemented)\n\n", .{});
        return 0;
    }

    std.debug.print("Unknown amygdala subcommand: {s}\n", .{subcommand});
    return 1;
}
