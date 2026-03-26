// DOGFOOD-1: tri dogfood-check CLI Command
// Enforcement: Zig is now TTT only (Temple/Tool/Transport)
//
// Usage:
//   tri dogfood-check scan    — List all .zig files in protected zones
//   tri dogfood-check verify  — Check .t27 equivalents exist
//   tri dogfood-check status   — Show conversion progress
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

const dogfood_guard = @import("dogfood_guard.zig");
const DogfoodSet = dogfood_guard.DogfoodSet;
const DogfoodError = dogfood_guard.DogfoodError;

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";

pub fn runDogfoodCheckCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "status";

    if (std.mem.eql(u8, subcmd, "scan")) {
        try runScan(allocator);
    } else if (std.mem.eql(u8, subcmd, "verify")) {
        try runVerify(allocator);
    } else if (std.mem.eql(u8, subcmd, "status")) {
        try runStatus(allocator);
    } else if (std.mem.eql(u8, subcmd, "help")) {
        printHelp();
    } else {
        std.debug.print("{s}Unknown subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printHelp();
        return error.UnknownSubcommand;
    }
}

fn runScan(allocator: Allocator) !void {
    std.debug.print("\n{s}🐕 DOGFOOD SCAN{s}\n", .{ BOLD, RESET });
    std.debug.print("{s}══════════════{s}\n\n", .{ CYAN, RESET });

    var dogfood = try DogfoodSet.init(allocator);
    defer dogfood.deinit();
    try dogfood.scan();

    std.debug.print("{s}Protected zones: src/queen/, src/brain/, src/hslm/{s}\n\n", .{ YELLOW, RESET });

    // Scan for .zig files in protected zones
    var violations: usize = 0;

    const zones = [_][]const u8{ "src/queen/", "src/brain/", "src/hslm/" };
    for (zones) |zone| {
        var dir = std.fs.cwd().openDir(zone, .{ .iterate = true }) catch |err| {
            if (err == error.FileNotFound) continue;
            return err;
        };
        defer dir.close();

        var walker = try dir.walk(allocator);
        defer walker.deinit();

        while (try walker.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.path, ".zig")) continue;

            // Skip shell wrappers (allowed)
            if (std.mem.endsWith(u8, entry.path, "_shell.zig")) continue;

            // Check if .t27 equivalent exists
            const full_path = try std.fs.path.join(allocator, &[_][]const u8{ zone, entry.path });
            defer allocator.free(full_path);

            const t27_path = getT27PathFor(full_path);
            var has_t27 = false;
            if (std.fs.cwd().openFile(t27_path, .{})) |file| {
                file.close();
                has_t27 = true;
            } else |_| {}

            if (!has_t27) {
                std.debug.print("  {s}✗{s} {s}\n", .{ RED, RESET, full_path });
                violations += 1;
            } else {
                std.debug.print("  {s}✓{s} {s} (has .t27)\n", .{ GREEN, RESET, full_path });
            }
        }
    }

    if (violations == 0) {
        std.debug.print("\n{s}✅ No violations!{s}\n", .{ GREEN, RESET });
    } else {
        std.debug.print("\n{s}❌ {d} violation(s) found{s}\n", .{ RED, violations, RESET });
    }
}

fn runVerify(allocator: Allocator) !void {
    std.debug.print("\n{s}🐕 DOGFOOD VERIFY{s}\n", .{ BOLD, RESET });
    std.debug.print("{s}════════════════{s}\n\n", .{ CYAN, RESET });

    var dogfood = try DogfoodSet.init(allocator);
    defer dogfood.deinit();
    try dogfood.scan();

    // Get staged files
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "diff", "--cached", "--name-only" },
    });

    const staged_files = std.mem.trim(u8, result.stdout, &std.ascii.whitespace);
    if (staged_files.len == 0) {
        std.debug.print("No staged files.\n", .{});
        return;
    }

    // Check violations directly without storing file list
    var iter = std.mem.splitScalar(u8, staged_files, '\n');
    var violation_count: usize = 0;

    while (iter.next()) |file_path| {
        const trimmed = std.mem.trimRight(u8, file_path, "\r\n");
        if (trimmed.len == 0) continue;

        // Check this single file
        var file_array: [1][]const u8 = .{trimmed};
        const violations = try dogfood.checkNewZig(file_array[0..]);
        defer {
            for (violations) |v| {
                allocator.free(v.path);
                allocator.free(v.reason);
            }
            allocator.free(violations);
        }

        if (violations.len > 0) {
            violation_count += violations.len;
            for (violations) |v| {
                std.debug.print("  {s}: {s}{s}\n", .{ RED, v.path, RESET });
                std.debug.print("    {s}\n", .{v.reason});
            }
        }
    }

    if (violation_count == 0) {
        std.debug.print("{s}✅ All staged files pass dogfood check!{s}\n", .{ GREEN, RESET });
        return;
    } else {
        std.debug.print("\n{s}❌ DOGFOOD VIOLATION: {d} file(s){s}\n", .{ RED, violation_count, RESET });
        return DogfoodError.DogfoodViolation;
    }
}

fn runStatus(allocator: Allocator) !void {
    var dogfood = try DogfoodSet.init(allocator);
    defer dogfood.deinit();
    try dogfood.scan();
    dogfood.report();
}

fn printHelp() void {
    std.debug.print("\n{s}tri dogfood-check{s} — DOGFOOD-1 Enforcement\n", .{ BOLD, RESET });
    std.debug.print("\n", .{});
    std.debug.print("Subcommands:\n", .{});
    std.debug.print("  {s}scan{s}   List all .zig files in protected zones\n", .{ CYAN, RESET });
    std.debug.print("  {s}verify{s} Check .t27 equivalents exist for staged files\n", .{ CYAN, RESET });
    std.debug.print("  {s}status{s}  Show conversion progress\n", .{ CYAN, RESET });
    std.debug.print("  {s}help{s}   Show this help message\n", .{ CYAN, RESET });
    std.debug.print("\n", .{});
    std.debug.print("Protected zones: src/queen/, src/brain/, src/hslm/\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Law: Zig is now TTT only (Temple/Tool/Transport).\n", .{});
    std.debug.print("     New business logic MUST be written in .t27 or .tri.\n", .{});
    std.debug.print("\n", .{});
}

fn getT27PathFor(zig_path: []const u8) []const u8 {
    if (std.mem.endsWith(u8, zig_path, "queen_vmpfc.zig")) {
        return "src/tri27/queen_vmpfc.t27";
    } else if (std.mem.endsWith(u8, zig_path, "reticular_raphe.zig")) {
        return "src/tri27/reticular_raphe.t27";
    } else if (std.mem.endsWith(u8, zig_path, "phoenix_medulla.zig")) {
        return "src/tri27/phoenix_medulla.t27";
    }
    return zig_path;
}
