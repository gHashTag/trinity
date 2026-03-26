// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// L0: TEMPLE (Sacred Core)
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub fn main() !void {
    // Temple L0 always runs from repo root

    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("L0 Temple: sacred core initialized\n", .{});
        std.debug.print("Usage: temple_exe <command> [args...]\n", .{});
        std.debug.print("\nL0 Temple Commands:\n", .{});
        std.debug.print("  status    — Show Temple is active\n", .{});
        std.debug.print("  help      — Show this help\n", .{});
        return;
    }

    const cmd = args[1];

    // Only core commands available in L0
    if (std.mem.eql(u8, cmd, "status")) {
        std.debug.print("L0 Temple: sacred core is active\n", .{});
        std.debug.print("Repository: {s}\n", .{std.fs.cwd().realpathAlloc(allocator, ".") catch "unknown"});
    } else if (std.mem.eql(u8, cmd, "help")) {
        printHelp();
    } else {
        std.debug.print("[L0 TEMPLE] Unknown command: {s}\n", .{cmd});
        std.debug.print("Available: status, help\n", .{});
        return error.UnknownCommand;
    }
}

fn printHelp() void {
    std.debug.print("\nL0 TEMPLE — Sacred Core\n", .{});
    std.debug.print("═══════════════════════\n", .{});
    std.debug.print("\nThis is a minimal Trinity core that always compiles.\n", .{});
    std.debug.print("\nCommands:\n", .{});
    std.debug.print("  status    Show Temple is active\n", .{});
    std.debug.print("  help      Show this help\n", .{});
    std.debug.print("\n", .{});
}

pub const TempleError = error{
    UnknownCommand,
};
