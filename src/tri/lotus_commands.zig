// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - Queen Lotus Cycle Commands
// ═══════════════════════════════════════════════════════════════════════════════════════════
//
// φ² + 1/φ² = 3 = TRINITY
//
// Runs the Queen Lotus Cycle autonomous improvement loop
// Routes to lotus-cycle binary via zig build or direct execution
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("tri_colors.zig");
const utils = @import("tri_utils.zig");

const RESET = colors.RESET;
const BOLD = colors.BOLD;
const GREEN = colors.GREEN;
const RED = colors.RED;
const YELLOW = colors.YELLOW;
const CYAN = colors.CYAN;

/// Paths for lotus-cycle binary
const LOTUS_BINARY = "./zig-out/bin/lotus-cycle";
const LOTUS_BUILD_STEP = "lotus-cycle";

/// Run lotus-cycle via build system (for consistency)
fn runViaBuild(allocator: std.mem.Allocator, args: []const u8) !void {
    var argv = try std.ArrayList([]const u8).initCapacity(allocator, args.len + 2);
    defer argv.deinit(allocator);

    try argv.appendSlice(allocator, &[_][]const u8{LOTUS_BUILD_STEP});
    try argv.appendSlice(allocator, args);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv.items,
    });

    const exit_code = result.term.Exited orelse 1;
    if (exit_code != 0) {
        const stderr = result.stderr.?;
        if (stderr.len > 0) {
            std.debug.print("{s}{s}{s}\n", .{ RED, stderr, RESET });
        }
    }

    return;
}

/// Run lotus-cycle binary directly (faster if already built)
fn runDirect(allocator: std.mem.Allocator, args: []const u8) !void {
    const binary_path = LOTUS_BINARY;

    // Check if binary exists
    std.fs.cwd().access(binary_path, .{}) catch {
        // Binary not found, try building first
        std.debug.print("{s}Building lotus-cycle...{s}\n", .{ YELLOW, RESET });
        _ = try std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "zig", "build", "lotus-cycle" },
        });
        return runDirect(allocator, args);
    };

    var argv = try std.ArrayList([]const u8).initCapacity(allocator, args.len + 1);
    defer argv.deinit(allocator);

    try argv.append(allocator, binary_path);
    try argv.appendSlice(allocator, args);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv.items,
        .cwd = std.fs.cwd(),
    });

    const exit_code = result.term.Exited orelse 1;
    if (exit_code != 0) {
        const stderr = result.stderr.?;
        if (stderr.len > 0) {
            std.debug.print("{s}{s}{s}\n", .{ RED, stderr, RESET });
        }
    }

    return;
}

/// Show lotus-cycle help
pub fn showLotusHelp() void {
    std.debug.print(
        \\{s}═════════════════════════════════════════════════════════════{s}
        \\{s}Queen Lotus Cycle — Autonomous Improvement Loop{s}
        \\{s}═════════════════════════════════════════════════════════════{s}
        \\
        \\{s}Usage:{s} tri lotus-cycle <command> [args...]
        \\
        \\{s}Commands:{s}
        \\  {s}run{s}     Run one complete Lotus Cycle
        \\  {s}stats{s}   Show episode statistics
        \\  {s}health{s}   Check Lotus Cycle health
        \\  {s}test{s}    Run Lotus Cycle tests
        \\
        \\{s}Examples:{s}
        \\  tri lotus-cycle run              # Full cycle
        \\  tri lotus-cycle stats            # Statistics
        \\  tri lotus-cycle health           # Health check
        \\
        \\{s}Or use binary directly:{s}
        \\  zig-out/bin/lotus-cycle run
        \\
        \\{s}φ² + 1/φ² = 3 = TRINITY{s}
        \\
    , .{ BOLD, RESET, BOLD, RESET, CYAN, RESET, GREEN, RESET, GREEN, RESET, YELLOW, RESET, YELLOW, RESET, DIM, RESET, DIM, RESET });
}
