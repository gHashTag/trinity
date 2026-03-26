// @origin(spec:tri27_cli_simple.tri) @regen(manual-impl)
// TRI‑27 Simple CLI — Command-line interface for TRI‑27 operations
// Uses existing modules directly (tri‑asm, tri‑emu) to avoid duplication
// ══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const Decoder = @import("emu/decoder.zig");
const Opcode = Decoder.Opcode;
const Instruction = Decoder.Instruction;
const Assembler = @import("tri_asm.zig");
const tri_emu = @import("tri_emu.zig");
const CPUState = @import("cpu_state.zig");

pub fn runSimpleTri27(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        printUsage();
        return;
    }

    const subcmd = args[0];

    // Delegate to existing tools
    if (std.mem.eql(u8, subcmd, "assemble") or std.mem.eql(u8, subcmd, "asm")) {
        runAssemble(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "run")) {
        runVm(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "disasm")) {
        runDisasm(allocator, args[1..]);
    } else {
        std.debug.print("Unknown command: {s}\n", .{subcmd});
        printUsage();
    }
}

fn runAssemble(allocator: Allocator, args: []const []const u8) !void {
    const input_file = args[0];
    const asm_content = try std.fs.cwd().readFileAlloc(allocator, input_file, 4096) catch |e| {
        std.debug.print("Error reading {s}: {s}\n", .{ input_file, e });
        return;
    };
    defer allocator.free(asm_content);

    const bytecode = Assembler.assemble(allocator, asm_content);
    try file.writeAll(bytecode);
    std.debug.print("Assembled {d} instructions\n", .{bytecode.len / 4});
    std.debug.print("Wrote to: {s}\n", .{input_file});
}

fn runVm(allocator: Allocator, args: []const []const u8) !void {
    const tbin_file = args[0];
    const tbin_content = try std.fs.cwd().readFileAlloc(allocator, tbin_file, 1024 * 1024) catch |e| {
        std.debug.print("Error reading {s}: {s}\n", .{ tbin_file, e });
        return;
    };
    defer allocator.free(tbin_content);

    var cpu = tri_emu.init();
    defer cpu.deinit();

    const loaded = cpu.loadProgram(tbin_content);
    if (!loaded) {
        std.debug.print("Error: failed to load program\n");
        return;
    }

    const result = cpu.execute(1000);
    std.debug.print("Execution result: {}\n", .{result});
    std.debug.print("PC: 0x{X:0>4}\n", .{cpu.pc});

    cpu.dumpRegisters();
}

fn runDisasm(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("Usage: disasm <input.tbin>\n");
        return;
    }

    const input_file = args[0];
    const tbin_content = try std.fs.cwd().readFileAlloc(allocator, input_file, 1024 * 1024) catch |e| {
        std.debug.print("Error reading {s}: {}\n", .{ input_file, e });
        return;
    };
    defer allocator.free(tbin_content);

    // Check for TRI-2 magic header
    if (tbin_content.len < 4) {
        std.debug.print("Error: file too small\n");
        return;
    }

    const magic = std.mem.readInt(u32, tbin_content[0..4], .little);
    if (magic != 0x54524932) { // "TRI2"
        std.debug.print("Error: invalid TRI-2 magic (0x{X:0>8})\n", .{magic});
        return;
    }

    // Parse header (simplified - just get code start)
    var offset: usize = 4;
    const code_start = offset + 16; // Skip header

    // Decode and print each instruction
    std.debug.print("; TRI-27 Disassembly: {s}\n", .{input_file});
    std.debug.print("; {d} bytes total\n", .{tbin_content.len});

    var pc: u32 = 0;
    while (code_start + pc * 4 + 4 <= tbin_content.len) {
        const word_bytes = tbin_content[code_start + pc * 4 .. code_start + pc * 4 + 4];
        const word = std.mem.readInt(u32, word_bytes, .little);

        const inst = Decoder.decode(word) catch |err| {
            std.debug.print("0x{X:0>4}: 0x{X:0>8} ; DECODE ERROR: {}\n", .{ pc, word, err });
            pc += 1;
            continue;
        };

        // Format instruction
        var buf: [128]u8 = undefined;
        const formatted = Decoder.formatInstructionShort(inst, &buf);

        std.debug.print("0x{X:0>4}: 0x{X:0>8}    {s}\n", .{ pc, word, formatted });
        pc += 1;

        // Stop at HALT
        if (inst.opcode == .HALT) break;
    }

    std.debug.print("; End of disassembly\n");
}

fn printUsage() void {
    std.debug.print("tri27_simple: TRI‑27 Simple CLI\n");
    std.debug.print("\nCommands:\n");
    std.debug.print("  assemble <input.tri> [-o <output.tbin>]   Assemble .tri to .tbin\n");
    std.debug.print(" run <input.tbin>            Execute .tbin in VM\n");
    std.debug.print(" disasm <input.tbin>           Disassemble .tbin\n");
}
