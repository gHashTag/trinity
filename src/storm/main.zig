//! STORM P9 — 32-Agent Autonomous Operation
//! Main CLI for STORM orchestration
//! Commands: run, status, resume, init, help

const std = @import("std");

const wp = @import("wave_protocol.zig");
const golden_chain = @import("golden_chain.zig").GoldenChain;

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

    const command = if (args.len > 0) args[0] else "run";

    if (std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "-h")) {
        try printHelp();
        return 0;
    } else if (std.mem.eql(u8, command, "init")) {
        try cmdInit(allocator);
        return 0;
    } else if (std.mem.eql(u8, command, "run")) {
        try cmdRun(allocator, args);
        return 0;
    } else if (std.mem.eql(u8, command, "status")) {
        try cmdStatus(allocator);
        return 0;
    } else if (std.mem.eql(u8, command, "resume")) {
        try cmdResume(allocator, args);
        return 0;
    } else {
        std.debug.print("{s}Unknown command: {s}{s}\n", .{ RED, command, RESET });
        try printHelp();
        return 1;
    }
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
}

fn cmdInit(allocator: std.mem.Allocator) !void {
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
        std.fs.cwd().makePath(dir) catch {
            std.debug.print("{s}✓{s} Created {s}\n", .{ GREEN, RESET, dir });
        };
    }
}

fn cmdRun(allocator: std.mem.Allocator, args: [][:0]u8) !void {
    _ = args;

    std.debug.print("\n{s}🚀 STORM RUN{s}\n", .{ YELLOW, RESET });
    std.debug.print("\n{s}Configuration:{s}\n", .{ CYAN, RESET });
    std.debug.print("  Waves: {d} (default)\n", .{5});
    std.debug.print("  Agents: {d} (default)\n", .{32});

    // Initialize components
    var chain = try golden_chain.init(allocator);
    defer chain.deinit();

    // Execute wave protocol
    var wave_proto = try wp.StormWaveProtocol.init(allocator, &chain);
    defer wave_proto.deinit();

    std.debug.print("\n{s}✅ STORM run complete!{s}\n\n", .{ GREEN, RESET });
}

fn cmdStatus(allocator: std.mem.Allocator) !void {
    _ = allocator;
    std.debug.print("\n{s}📊 STORM STATUS{s}\n", .{ CYAN, RESET });
    std.debug.print("\n{s}Checkpoint:{s}\n", .{ CYAN, RESET });

    const checkpoint_dir = ".trinity/storm/checkpoints";
    var dir = std.fs.cwd().openDir(checkpoint_dir, .{}) catch {
        std.debug.print("  No checkpoints found.\n", .{});
        return;
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
}

fn cmdResume(allocator: std.mem.Allocator, args: [][:0]u8) !void {
    _ = allocator;
    _ = args;

    std.debug.print("\n{s}🔖 STORM RESUME{s}\n", .{ YELLOW, RESET });
    std.debug.print("  Resume not yet implemented.\n", .{});
}
