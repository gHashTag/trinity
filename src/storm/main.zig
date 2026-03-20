// @origin(spec:storm/main.tri) @regen(vibee)
// ════════════════════════════════════════════════════════════════════
// STORM MAIN CLI — 32-agent, 5-wave autonomous operation
// ══════════════════════════════════════════════════════════════════

//
// Commands:
//   storm init               Scaffold .trinity/storm/ structure
//   storm run                 Execute STORM with --waves=N --agents=M
//   storm status              Show checkpoint status --wave=N
//   storm resume              Continue from --checkpoint=ID

// φ² + 1/φ² = 3 = TRINITY
// ═════════════════════════════════════════════════════════════════

const std = @import("std");

const config_mod = @import("config.zig");
const golden_chain = @import("golden_chain.zig");
const phoenix_bridge = @import("phoenix_bridge.zig");

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const MAGENTA = "\x1b[35m";
const PURPLE = "\x1b[38;2;111;66;193m";

pub fn main() \!u8 {
    const gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printHelp();
        return 1;
    }

    const command = args[1];
    const command_args = args[2..];

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
