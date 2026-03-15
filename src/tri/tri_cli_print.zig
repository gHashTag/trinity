// @origin(spec:tri_zenodo.tri) @regen(manual-impl)

const std = @import("std");
const print = std.debug.print;

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const GOLDEN = "\x1b[38;5;220m";

pub fn printBanner() void {
    print("\n{s}╔═════════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    print("{s}║  TRINITY — Pure Zig Autonomous Agent Swarm                              ║\n", .{ RESET });
    print("{s}║  0 TypeScript • 0 Python • 0 Bash                                   ║\n", .{ RESET });
    print("{s}║  https://github.com/gHashTag/trinity                              ║\n", .{ CYAN, RESET });
    print("{s}╚═══════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });
}

pub fn printHelp() void {
    print("\n{s}TRINITY CLI{s}\n", .{ BOLD, RESET });
    print("{s}Available commands:{s}\n", .{ GREEN, RESET });
    print("  {s}tri{s} - Core tri command system\n", .{ CYAN, RESET });
    print("\nSee {s}tri --help{s} for full command list\n", .{ YELLOW, RESET });
}

pub fn printVersion() void {
    print("{s}Trinity v0.0.0-swe{s}\n", .{ GREEN, RESET });
}

pub fn printInfo() void {
    printBanner();
    print("{s}Trinity: Pure Zig Autonomous Agent Swarm{s}\n", .{ RESET });
    print("{s}Language: Zig 0.15.2 (std only){s}\n", .{ YELLOW, RESET });
    print("{s}Repository: https://github.com/gHashTag/trinity{s}\n", .{ CYAN, RESET });
}

pub fn printPrompt() void {
    print("{s}tri{s}> ", .{ CYAN, RESET });
}

pub fn printREPLHelp() void {
    print("\n{s}REPL Commands:{s}\n", .{ GREEN, RESET });
    print("  :help   — Show this help\n");
    print("  :exit   — Exit REPL\n");
    print("  :clear  — Clear screen\n");
}

pub fn printStats() void {
    print("\n{s}Trinity Stats{s}\n", .{ BOLD, RESET });
    print("  See: {s}tri faculty{s} for agent stats\n", .{ YELLOW, RESET });
}

pub fn printCommandHelp(command: []const u8) void {
    print("\n{s}Help for: {s}{s}\n", .{ CYAN, command, RESET });
    print("  {s}tri --help{s} — Show all commands\n", .{ YELLOW, RESET });
}

pub fn printIntelligenceHelp() void {
    print("\n{s}Intelligence Commands:{s}\n", .{ GREEN, RESET });
    print("  See: {s}tri --help{s} for agent commands\n", .{ YELLOW, RESET });
}

test "print functions are callable" {
    printBanner();
    printHelp();
    printVersion();
    printInfo();
    printPrompt();
    printREPLHelp();
    printStats();
    printCommandHelp("test");
    printIntelligenceHelp();
}
