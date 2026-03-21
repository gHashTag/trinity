//! STORM P9 — 32-Agent Autonomous Operation
//! Main CLI for STORM orchestration
//! Commands: run, status, resume, init, help

const std = @import("std");

const wp = @import("wave_protocol.zig");
const gc = @import("golden_chain.zig");
const ct = @import("cost_tracker.zig");
const mr = @import("model_roulette.zig");
const pb = @import("phoenix_bridge.zig");
const ee = @import("experience_engine.zig");

const CYAN = "\x1b[36m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";
const RESET = "\x1b[0m";

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

    if (std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "-h")) {
        try printHelp();
        return 0;
    }

    if (std.mem.eql(u8, command, "init")) {
        return try cmdInit(allocator);
    } else if (std.mem.eql(u8, command, "run")) {
        return try cmdRun(allocator, args);
    } else if (std.mem.eql(u8, command, "status")) {
        return try cmdStatus(allocator);
    } else if (std.mem.eql(u8, command, "resume")) {
        return try cmdResume(allocator, args);
    } else {
        std.debug.print("{s}Unknown command: {s}{s}\n", .{ RED, command, RESET });
        try printHelp();
        return 1;
    }
}

fn cmdInit(allocator: std.mem.Allocator) !u8 {
    _ = allocator;
    std.debug.print("\n{s}🌪️ STORM INIT{s}\n", .{ CYAN, RESET });

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
                std.debug.print("{s}Failed to create {s}: {}{s}\n", .{ RED, dir, err, RESET });
                return 1;
            }
        };
        std.debug.print("{s}✓{s} Created {s}\n", .{ GREEN, RESET, dir });
    }

    return 0;
}

fn cmdRun(allocator: std.mem.Allocator, args: [][:0]u8) !u8 {
    std.debug.print("\n{s}🚀 STORM RUN{s}\n", .{ YELLOW, RESET });

    const task = if (args.len > 2)
        try std.fmt.allocPrint(allocator, "STORM autonomous operation: {s}", .{args[2]})
    else
        "STORM autonomous operation";

    // Initialize components
    var chain = try gc.GoldenChain.init(allocator);
    defer chain.deinit();

    var wave_proto = try wp.StormWaveProtocol.init(allocator, &chain);
    defer wave_proto.deinit();

    var cost_tracker = try ct.CostTracker.init(allocator);
    defer cost_tracker.deinit();

    var model_roulette = try mr.ModelRoulette.init(allocator, null);
    defer model_roulette.deinit();

    std.debug.print("\n{s}Configuration:{s}\n", .{ CYAN, RESET });
    std.debug.print("  Task: {s}\n", .{task});
    std.debug.print("  Waves: {d} (default)\n", .{5});
    std.debug.print("  Agents: {d} (default)\n", .{32});
    std.debug.print("  Config: .trinity/storm/config.json\n", .{});

    // TODO: Load config from config.json if provided

    const result = try wave_proto.runAll(task);
    std.debug.print("\n{s}Result: {d}{s}\n\n", .{ CYAN, result, RESET });

    if (result == 0) {
        std.debug.print("\n{s}✅ STORM run complete!{s}\n\n", .{ GREEN, RESET });
    } else {
        std.debug.print("\n{s}❌ STORM run failed with code {d}{s}\n", .{ RED, result, RESET });
    }

    return result;
}

fn cmdStatus(allocator: std.mem.Allocator) !u8 {
    _ = allocator;

    std.debug.print("\n{s}📊 STORM STATUS{s}\n", .{ CYAN, RESET });
    std.debug.print("\n{s}Checkpoint:{s}\n", .{ CYAN, RESET });

    const checkpoint_dir = ".trinity/storm/checkpoints";
    var dir = std.fs.cwd().openDir(checkpoint_dir, .{ .iterate = true }) catch {
        std.debug.print("{s}No checkpoints found. Run 'storm init' first.{s}\n", .{ RED, RESET });
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

    std.debug.print("\n", .{});
    return 0;
}

fn cmdResume(allocator: std.mem.Allocator, args: [][:0]u8) !u8 {
    _ = allocator;

    if (args.len < 3) {
        std.debug.print("{s}Error: resume requires checkpoint ID{s}\n", .{ RED, RESET });
        std.debug.print(" Usage: storm resume <checkpoint_id>\n", .{});
        return 1;
    }

    const checkpoint_id = args[2];
    std.debug.print("  Resuming from checkpoint: {s}\n", .{checkpoint_id});

    // TODO: Implement resumeFromCheckpoint with experience loading
    std.debug.print("  {s}Resume not yet implemented.{s}\n", .{ YELLOW, RESET });
    return 0;
}

fn printHelp() !void {
    std.debug.print("\n{s}STORM P9 — 32-Agent Autonomous Operation{s}\n", .{ CYAN, RESET });
    std.debug.print("Usage: storm <command> [options]\n\n", .{});
    std.debug.print("Commands:\n", .{});
    std.debug.print("  {s}init{s}               — Scaffold .trinity/storm/ structure\n", .{ CYAN, RESET });
    std.debug.print("  {s}run{s}                — Execute STORM operation\n", .{ CYAN, RESET });
    std.debug.print("  {s}status{s}             — Show checkpoint status\n", .{ CYAN, RESET });
    std.debug.print("  {s}resume{s}            — Continue from checkpoint\n", .{ CYAN, RESET });
    std.debug.print("  {s}help{s}               — Show this help\n", .{ CYAN, RESET });
    std.debug.print("\n", .{});
    std.debug.print("Options:\n", .{});
    std.debug.print("  --waves <N>         — Number of waves (default: 5)\n", .{});
    std.debug.print("  --agents <M>        — Number of agents (default: 32)\n", .{});
    std.debug.print("  --config <PATH>     — Config file path\n", .{});
    std.debug.print("  --dry-run          — Simulate without executing commands\n", .{});
    std.debug.print("  --task <DESC>      — Custom task description\n", .{});
    std.debug.print("\nExamples:\n", .{});
    std.debug.print("  storm init                              — Initialize STORM\n", .{});
    std.debug.print("  storm run                               — Run with defaults\n", .{});
    std.debug.print("  storm run --waves=3 --agents=16        — Custom wave count\n", .{});
    std.debug.print("  storm status                            — Show checkpoint status\n", .{});
    std.debug.print("  storm resume checkpoint_1234567890     — Resume from checkpoint\n", .{});
    std.debug.print("\n", .{});
}
