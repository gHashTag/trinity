// TRI‑27 CLI — Command-line interface for TRI‑27 operations
// Fixed: All print() calls now have proper format specifiers

const std = @import("std");
const Allocator = std.mem.Allocator;

const Decoder = @import("emu/decoder.zig");
const Opcode = Decoder.Opcode;
const Instruction = Decoder.Instruction;
const Assembler = @import("emu/tri_asm.zig");
const Executor = @import("emu/executor.zig");
const CPUState = @import("emu/cpu_state.zig");
const tri27_experience = @import("tri27_experience");

const print = std.debug.print;

const DIM = "\x1b[1m";
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";

// ════════════════════════════════════════════════════════
pub fn runTri27Command(allocator: Allocator, all_args: []const []const u8) !void {
    const subcmd = if (all_args.len > 0) all_args[0] else "";

    if (std.mem.eql(u8, subcmd, "assemble") or std.mem.eql(u8, subcmd, "asm")) {
        return runAssembleCommand(allocator, all_args);
    } else if (std.mem.eql(u8, subcmd, "disassemble") or std.mem.eql(u8, subcmd, "disasm")) {
        return runDisassembleCommand(allocator, all_args[1..]);
    } else if (std.mem.eql(u8, subcmd, "run")) {
        return runRunCommand(allocator, all_args[1..]);
    } else if (std.mem.eql(u8, subcmd, "validate")) {
        return runValidateCommand(allocator, all_args[1..]);
    }
    } else if (std.mem.eql(u8, subcmd, "validate")) {
        return runValidateCommand(allocator, all_args[1..]);
    } else if (std.mem.eql(u8, subcmd, "experience") or std.mem.eql(u8, subcmd, "exp")) {
        return runExperienceCommand(allocator, all_args[1..]);
    } else if (std.mem.eql(u8, subcmd, "isa")) {
        return runIsaCommand();
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help") or std.mem.eql(u8, subcmd, "-h")) {
        printHelp();
    } else {
        print("{s}Unknown tri27 subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printHelp();
    }
}
