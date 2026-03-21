
const std = @import("std");
const wp = @import("wave_protocol.zig");
const gc = @import("golden_chain.zig");

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const PURPLE = "\x1b[38;2;111;66;193m";

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printHelp();
        return 1;
    }

    const command = args[1];
    var command_args_buf: [10][]const u8 = undefined;
    var command_args_len: usize = 0;
    if (args.len >= 3) {
        const slice = args[2..];
        command_args_len = slice.len;
        for (slice, 0..) |arg, i| {
            command_args_buf[i] = arg;
        }
    }
    const command_args = command_args_buf[0..command_args_len];

    const is_help = std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "-h");

    if (std.mem.eql(u8, command, "init")) {
        return try cmdInit(allocator);
    } else if (std.mem.eql(u8, command, "run")) {
        return try cmdRun(allocator, command_args);
    } else if (std.mem.eql(u8, command, "status")) {
        return try cmdStatus(allocator, command_args);
    } else if (std.mem.eql(u8, command, "resume")) {
        return try cmdResume(allocator, command_args);
    } else if (is_help) {
        try printHelp();
        return 0;
    } else {
        std.debug.print("{s}Unknown command: {s}{s}\n", .{ RED, command, RESET });
        try printHelp();
        return 1;
    }
}

fn cmdInit(allocator: std.mem.Allocator) !u8 {
    std.debug.print("\n{s}🌪️  STORM INIT{s}\n", .{ CYAN, RESET });

    const dirs = [_][]const u8{
        ".trinity/storm",
        ".trinity/storm/checkpoints",
        ".trinity/phoenix/checkpoints",
        ".trinity/mistakes",
        ".trinity/experience",
        ".trinity/experience/episodes",
    };

    for (dirs) |dir| {
        std.fs.cwd().makePath(dir) catch |err| {
            if (err != error.PathAlreadyExists) {
                std.debug.print("  {s}Failed to create {s}: {}{s}\n", .{ RED, dir, err, RESET });
                return 1;
            }
        };
        std.debug.print("  {GREEN}✓{s} Created {s}\n", .{ GREEN, RESET, dir });
    }

    std.debug.print("\n{s}✅ STORM initialized!{s}\n\n", .{ GREEN, RESET });
    std.debug.print("Next steps:\n", .{});
    std.debug.print("  {CYAN}storm run{s}            — Execute STORM (28 links)\n", .{ CYAN, RESET });
    std.debug.print("  {CYAN}storm run --waves=3{s}  — Custom wave count\n", .{ CYAN, RESET });
    std.debug.print("  {CYAN}storm status{s}         — Show checkpoint status\n\n", .{ CYAN, RESET });

    return 0;
}

fn cmdRun(allocator: std.mem.Allocator, args: [][]const u8) !u8 {
    std.debug.print("\n{s}🌪️  STORM RUN{s}\n", .{ CYAN, RESET });

    var waves: u4 = 5;
    var dry_run: bool = false;
    var task: []const u8 = "STORM autonomous operation";

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--waves") and i + 1 < args.len) {
            i += 1;
            waves = try std.fmt.parseInt(u4, args[i], 10);
        } else if (std.mem.eql(u8, args[i], "--dry-run")) {
            dry_run = true;
        } else if (std.mem.eql(u8, args[i], "--task") and i + 1 < args.len) {
            i += 1;
            task = args[i];
        }
    }

    std.debug.print("Configuration:\n", .{});
    std.debug.print("  Waves:   {d}\n", .{waves});
    std.debug.print("  Dry run: {s}\n", .{dry_run});
    std.debug.print("  Task:    {s}\n\n", .{task});

    if (dry_run) {
        std.debug.print("{YELLOW}⚠️  Dry run mode: not executing actual commands{s}\n\n", .{ YELLOW, RESET });
    }

    // Initialize Golden Chain
    var chain = try gc.GoldenChain.init(allocator);
    defer chain.deinit();

    // Run the chain
    std.debug.print("{s}🚀 Starting Golden Chain (28 links)...{s}\n\n", .{ PURPLE, RESET });
    const result = try chain.run(task);

    if (result == 0) {
        std.debug.print("\n{s}✅ STORM run complete!{s}\n\n", .{ GREEN, RESET });
    } else {
        std.debug.print("\n{s}❌ STORM run failed with code {d}{s}\n\n", .{ RED, result, RESET });
    }

    return result;
}

fn cmdStatus(allocator: std.mem.Allocator, args: [][]const u8) !u8 {
    _ = args;

    std.debug.print("\n{s}🌪️  STORM STATUS{s}\n", .{ CYAN, RESET });

    const checkpoint_dir = ".trinity/storm/checkpoints";
    var dir = std.fs.cwd().openDir(checkpoint_dir, .{ .iterate = true }) catch {
        std.debug.print("  No checkpoints found. Run 'storm init' first.\n\n", .{});
        return 0;
    };
    defer dir.close();

    var count: usize = 0;
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".json")) {
            count += 1;
            std.debug.print("  Checkpoint: {s}\n", .{entry.name});
        }
    }

    if (count == 0) {
        std.debug.print("  No checkpoints found.\n", .{});
    } else {
        std.debug.print("  Total checkpoints: {d}\n", .{count});
    }

    _ = allocator;
    std.debug.print("\n", .{});
    return 0;
}

fn cmdResume(allocator: std.mem.Allocator, args: [][]const u8) !u8 {
    _ = allocator;

    std.debug.print("\n{s}🌪️  STORM RESUME{s}\n", .{ CYAN, RESET });

    if (args.len < 1) {
        std.debug.print("  {RED}Error: resume requires checkpoint ID{s}\n", .{ RED, RESET });
        std.debug.print("  Usage: storm resume <checkpoint_id>\n\n", .{});
        return 1;
    }

    const checkpoint_id = args[0];
    std.debug.print("  Resuming from checkpoint: {s}\n", .{checkpoint_id});

    var chain = try gc.GoldenChain.init(allocator);
    defer chain.deinit();

    const result = try chain.resumeFromCheckpoint(checkpoint_id, "STORM resume operation");

    if (result == 0) {
        std.debug.print("\n{s}✅ STORM resume complete!{s}\n\n", .{ GREEN, RESET });
    } else {
        std.debug.print("\n{s}❌ STORM resume failed with code {d}{s}\n\n", .{ RED, result, RESET });
    }

    return result;
}

fn printHelp() !void {
    std.debug.print("\n{s}STORM — 32-agent, 5-wave autonomous operation{s}\n", .{ BOLD, RESET });
    std.debug.print("Usage: storm <command> [options]\n\n", .{});
    std.debug.print("Commands:\n", .{});
    std.debug.print("  {CYAN}init{s}               — Scaffold .trinity/storm/ structure\n", .{ CYAN, RESET });
    std.debug.print("  {CYAN}run{s}                — Execute STORM operation\n", .{ CYAN, RESET });
    std.debug.print("  {CYAN}status{s}             — Show checkpoint status\n", .{ CYAN, RESET });
    std.debug.print("  {CYAN}resume{s}             — Continue from checkpoint\n", .{ CYAN, RESET });
    std.debug.print("  {CYAN}help{s}               — Show this help\n\n", .{ CYAN, RESET });
    std.debug.print("Options:\n", .{});
    std.debug.print("  {YELLOW}--waves <N>{s}         — Number of waves (default: 5)\n", .{ YELLOW, RESET });
    std.debug.print("  {YELLOW}--dry-run{s}          — Simulate without executing commands\n", .{ YELLOW, RESET });
    std.debug.print("  {YELLOW}--task <s>{s}         — Custom task description\n", .{ YELLOW, RESET, "..." });
    std.debug.print("\nExamples:\n", .{});
    std.debug.print("  {DIM}storm init{s}                              — Initialize STORM\n", .{ DIM, RESET });
    std.debug.print("  {DIM}storm run{s}                               — Run with defaults\n", .{ DIM, RESET });
    std.debug.print("  {DIM}storm run --waves=3{s}                  — Custom wave count\n", .{ DIM, RESET });
    std.debug.print("  {DIM}storm run --dry-run{s}                   — Simulation mode\n", .{ DIM, RESET });
    std.debug.print("  {DIM}storm status{s}                            — Show checkpoint status\n", .{ DIM, RESET });
    std.debug.print("  {DIM}storm resume checkpoint_1234567890{s}    — Resume from checkpoint\n", .{ DIM, RESET });
    std.debug.print("\n", .{});
}
