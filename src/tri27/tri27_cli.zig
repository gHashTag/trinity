// @origin(spec:tri27_cli.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI-27 CLI — Command-line interface for TRI-27 operations
// ═══════════════════════════════════════════════════════════════════════════════
//
// Commands:
//   tri tri27 assemble <input.tri> -o <output.tbin>  — Compile .tri → .tbin
//   tri tri27 disassemble <input.tbin>              — Disassemble .tbin → listing
//   tri tri27 run <program.tbin>                     — Execute .tbin in VM
//   tri tri27 validate <source.tri>                   — Validate .tri specification
//   tri tri27 isa                                    — Show ISA reference
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const Decoder = @import("emu/decoder.zig");
const Opcode = Decoder.Opcode;
const Instruction = Decoder.Instruction;
const Assembler = @import("emu/tri_asm.zig");
const Executor = @import("emu/executor.zig");
const CPUState = @import("emu/cpu_state.zig");

// ANSI colors
const RESET = "\x1b[0m";
const DIM = "\x1b[1m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const MAGENTA = "\x1b[35m";

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN COMMAND DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runTri27Command(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "";

    if (std.mem.eql(u8, subcmd, "assemble") or std.mem.eql(u8, subcmd, "asm")) {
        return runAssembleCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "disassemble") or std.mem.eql(u8, subcmd, "disasm")) {
        return runDisassembleCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "run")) {
        return runRunCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "validate")) {
        return runValidateCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "isa")) {
        return runIsaCommand();
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help") or std.mem.eql(u8, subcmd, "-h")) {
        printHelp();
    } else {
        std.debug.print("{s}Unknown tri27 subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ASSEMBLE COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

fn runAssembleCommand(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("{s}Error: missing input file{s}\n", .{ RED, RESET });
        std.debug.print("  Usage: tri tri27 assemble <input.tri> -o <output.tbin>\n\n", .{});
        return;
    }

    const input_file = args[0];
    var output_file: []const u8 = "output.tbin";

    // Parse -o flag
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "-o") and i + 1 < args.len) {
            i += 1;
            output_file = args[i];
        } else {
            std.debug.print("{s}Warning: unknown flag {s}{s}\n", .{ YELLOW, args[i], RESET });
        }
    }

    // Read input
    const asm_content = std.fs.cwd().readFileAlloc(allocator, input_file, 1024 * 1024) catch |err| {
        std.debug.print("{s}Error reading {s}: {}{s}\n", .{ RED, input_file, err, RESET });
        return err;
    };
    defer allocator.free(asm_content);

    std.debug.print("{s}🔧 Assembling {s}...{s}\n", .{ CYAN, input_file, RESET });

    // Assemble
    const bytecode = Assembler.assemble(allocator, asm_content) catch |err| {
        std.debug.print("{s}Assembly failed: {}{s}\n", .{ RED, err, RESET });
        return err;
    };
    defer allocator.free(bytecode);

    // Calculate instruction count (subtract header)
    const inst_count = (bytecode.len - 10) / 4;

    std.debug.print("{s}✅ Assembled {d} instructions → {d} bytes{s}\n", .{
        GREEN, inst_count, bytecode.len, RESET,
    });

    // Write output
    {
        const file = try std.fs.cwd().createFile(output_file, .{});
        defer file.close();
        try file.writeAll(bytecode);
    }

    std.debug.print("{s}📝 Wrote: {s}{s}\n\n", .{ GREEN, output_file, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// DISASSEMBLE COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

fn runDisassembleCommand(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("{s}Error: missing input file{s}\n", .{ RED, RESET });
        std.debug.print("  Usage: tri tri27 disassemble <input.tbin>\n\n", .{});
        return;
    }

    const input_file = args[0];

    // Read .tbin file
    const bytecode = std.fs.cwd().readFileAlloc(allocator, input_file, 1024 * 1024) catch |err| {
        std.debug.print("{s}Error reading {s}: {}{s}\n", .{ RED, input_file, err, RESET });
        return err;
    };
    defer allocator.free(bytecode);

    // Check header
    if (bytecode.len < 10) {
        std.debug.print("{s}Error: file too small to be .tbin{s}\n", .{ RED, RESET });
        return error.InvalidFile;
    }

    if (bytecode[0] != 'T' or bytecode[1] != 'R' or bytecode[2] != 'I' or bytecode[3] != '2' or bytecode[4] != '7') {
        std.debug.print("{s}Error: invalid .tbin header (expected TRI27){s}\n", .{ RED, RESET });
        return error.InvalidHeader;
    }

    const version = bytecode[5];
    const section_count = bytecode[6];
    const section_type = bytecode[7];
    const code_size = std.mem.readInt(u16, bytecode[8..10], .little) catch 0;

    std.debug.print("\n{s}TRI-27 DISASSEMBLY{s}\n", .{ BOLD, RESET });
    std.debug.print("{s}File: {s}{s}\n", .{ CYAN, input_file, RESET });
    std.debug.print("Header: TRI27 v{d}, {d} sections, type={d}, size={d} bytes\n\n", .{
        version, section_count, section_type, code_size,
    });

    // Disassemble instructions
    var offset: usize = 10; // Skip header
    var addr: u32 = 0;
    while (offset + 4 <= bytecode.len) {
        offset += 4;
        addr += 1;

        const word_bytes = bytecode[offset..offset + 4];
        const word = std.mem.readInt(u32, word_bytes, .little) catch 0;

        const inst = Decoder.decode(word);
        const opcode_name = Decoder.getOpcodeName(inst.opcode);

        std.debug.print("{s}0x{X:0>4} {s}{s} ", .{ DIM, addr, MAGENTA, opcode_name, RESET });

        // Format operands based on opcode
        switch (inst.opcode) {
            .NOP, .RET, .HALT => {
                // No operands
            },

            .INC, .DEC, .NOT => {
                std.debug.print("t{d}", .{inst.dst});
            },

            .LD => {
                std.debug.print("t{d}, [t{d}]", .{ inst.dst, inst.src1 });
            },

            .ST => {
                std.debug.print("[t{d}], t{d}", .{ inst.src1, inst.dst });
            },

            .LDI, .LD_IMM => {
                std.debug.print("t{d}, {d}", .{ inst.dst, inst.immediate });
            },

            .ADD, .SUB, .MUL, .DIV, .AND, .OR, .XOR => {
                std.debug.print("t{d}, t{d}, t{d}", .{ inst.dst, inst.src1, inst.src2 });
            },

            .SHL, .SHR => {
                std.debug.print("t{d}, t{d}, t{d}", .{ inst.dst, inst.src1, inst.src2 });
            },

            .JMP => {
                std.debug.print("@{d}", .{@as(i33, inst.immediate)});
            },

            .JZ, .JNZ => {
                std.debug.print("t{d}, @{d}", .{ inst.dst, @as(i33, inst.immediate) });
            },

            .CALL => {
                std.debug.print("@{d}", .{@as(i33, inst.immediate)});
            },

            .DOT, .BIND, .BUNDLE2, .BUNDLE3 => {
                if (inst.src2 == 0) {
                    std.debug.print("t{d}, t{d}", .{ inst.dst, inst.src1 });
                } else {
                    std.debug.print("t{d}, t{d}, t{d}", .{ inst.dst, inst.src1, inst.src2 });
                }
            },

            .PHI_CONST, .PI_CONST, .E_CONST => {
                std.debug.print("t{d} ; sacred", .{ inst.dst });
            },

            .ADD3, .SUB3, .CMP3 => {
                std.debug.print("t{d}, t{d}, t{d}", .{ inst.dst, inst.src1, inst.src2 });
            },

            .SYSCALL => {
                std.debug.print("{d}", .{ inst.immediate });
            },

            else => {
                std.debug.print("???");
            },
        }

        std.debug.print("{s}\n", .{ RESET });
    }

    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// RUN COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

fn runRunCommand(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("{s}Error: missing input file{s}\n", .{ RED, RESET });
        std.debug.print("  Usage: tri tri27 run <program.tbin> [--max-steps N]\n\n", .{});
        return;
    }

    const input_file = args[0];
    var max_steps: u32 = 10000;

    // Parse flags
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--max-steps") and i + 1 < args.len) {
            i += 1;
            max_steps = std.fmt.parseInt(u32, args[i], 10) catch max_steps;
        }
    }

    // Read .tbin file
    const bytecode = std.fs.cwd().readFileAlloc(allocator, input_file, 1024 * 1024) catch |err| {
        std.debug.print("{s}Error reading {s}: {}{s}\n", .{ RED, input_file, err, RESET });
        return err;
    };
    defer allocator.free(bytecode);

    std.debug.print("{s}⚡ Running {s}...{s}\n", .{ CYAN, input_file, RESET });

    // Load program into CPU state
    var cpu = CPUState.init();
    const loaded = try cpu.loadProgram(bytecode);
    if (!loaded) {
        std.debug.print("{s}Error: failed to load program{s}\n", .{ RED, RESET });
        return error.LoadFailed;
    }

    // Execute
    const result = cpu.execute(max_steps);

    std.debug.print("\n{s}EXECUTION RESULTS{s}\n", .{ BOLD, RESET });
    std.debug.print("  Status: {s}\n", .{switch (result) {
        .Halted => "HALTED",
        .Timeout => "TIMEOUT",
        .Error => "ERROR",
    }});
    std.debug.print("  Cycles: {d}/{d}\n", .{ cpu.cycle_count, max_steps });
    std.debug.print("  PC: 0x{X:0>4}\n", .{ cpu.pc });

    // Print register dump
    std.debug.print("\n{s}REGISTERS{s}\n", .{ BOLD, RESET });
    var reg_idx: u8 = 0;
    while (reg_idx < 27) : (reg_idx += 1) {
        std.debug.print("  t{d: 6} ", .{ reg_idx, cpu.registers[reg_idx] });
        if ((reg_idx + 1) % 6 == 0) std.debug.print("\n", .{});
    }

    // Print non-zero registers only
    std.debug.print("\n{s}NON-ZERO REGISTERS{s}\n", .{ DIM, RESET });
    var nz_idx: u8 = 0;
    var non_zero: u8 = 0;
    while (nz_idx < 27) : (nz_idx += 1) {
        if (cpu.registers[nz_idx] != 0) {
            std.debug.print("  t{d}: {d:6}\n", .{ i, cpu.registers[i] });
            non_zero += 1;
        }
    }
    if (non_zero == 0) {
        std.debug.print("  (all zero)\n", .{});
    }

    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// VALIDATE COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

fn runValidateCommand(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("{s}Error: missing input file{s}\n", .{ RED, RESET });
        std.debug.print("  Usage: tri tri27 validate <source.tri>\n\n", .{});
        return;
    }

    const input_file = args[0];

    // Read source
    const asm_content = std.fs.cwd().readFileAlloc(allocator, input_file, 1024 * 1024) catch |err| {
        std.debug.print("{s}Error reading {s}: {}{s}\n", .{ RED, input_file, err, RESET });
        return err;
    };
    defer allocator.free(asm_content);

    std.debug.print("{s}🔍 Validating {s}...{s}\n", .{ CYAN, input_file, RESET });

    // Try to assemble
    const bytecode = Assembler.assemble(allocator, asm_content) catch |err| {
        std.debug.print("{s}❌ Validation FAILED: {}{s}\n\n", .{ RED, err, RESET });
        return err;
    };
    defer allocator.free(bytecode);

    std.debug.print("{s}✅ Validation PASSED{s}\n", .{ GREEN, RESET });
    std.debug.print("  Instructions: {d}\n", .{(bytecode.len - 10) / 4});
    std.debug.print("  Bytecode size: {d} bytes\n\n", .{ bytecode.len });
}

// ═══════════════════════════════════════════════════════════════════════════════
// ISA COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

fn runIsaCommand() !void {
    std.debug.print("\n{s}TRI-27 INSTRUCTION SET ARCHITECTURE{s}\n", .{ BOLD, RESET });
    std.debug.print("{s}═════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    std.debug.print("{s}ARITHMETIC (0x10-0x17){s}\n", .{ CYAN, RESET });
    std.debug.print("  ADD   dst, src1, src2   ; dst = src1 + src2\n", .{});
    std.debug.print("  SUB   dst, src1, src2   ; dst = src1 - src2\n", .{});
    std.debug.print("  MUL   dst, src1, src2   ; dst = src1 * src2\n", .{});
    std.debug.print("  DIV   dst, src1, src2   ; dst = src1 / src2\n", .{});
    std.debug.print("  INC   dst               ; dst++\n", .{});
    std.debug.print("  DEC   dst               ; dst--\n", .{});

    std.debug.print("\n{s}LOGIC (0x18-0x1D){s}\n", .{ CYAN, RESET });
    std.debug.print("  AND   dst, src1, src2   ; dst = src1 & src2\n", .{});
    std.debug.print("  OR    dst, src1, src2   ; dst = src1 | src2\n", .{});
    std.debug.print("  XOR   dst, src1, src2   ; dst = src1 ^ src2\n", .{});
    std.debug.print("  NOT   dst               ; dst = ~dst\n", .{});
    std.debug.print("  SHL   dst, src1, shift  ; dst = src1 << shift\n", .{});
    std.debug.print("  SHR   dst, src1, shift  ; dst = src1 >> shift\n", .{});

    std.debug.print("\n{s}MEMORY (0x02-0x05){s}\n", .{ CYAN, RESET });
    std.debug.print("  LD    dst, [src]        ; dst = memory[src]\n", .{});
    std.debug.print("  ST    [dst], src         ; memory[dst] = src\n", .{});
    std.debug.print("  LDI   dst, imm          ; dst = imm\n", .{});
    std.debug.print("  STI   [dst], imm        ; memory[dst] = imm\n", .{});

    std.debug.print("\n{s}CONTROL (0x40-0x4F){s}\n", .{ CYAN, RESET });
    std.debug.print("  JMP   label             ; jump to label\n", .{});
    std.debug.print("  JZ    dst, label        ; if dst == 0: jump\n", .{});
    std.debug.print("  JNZ   dst, label        ; if dst != 0: jump\n", .{});
    std.debug.print("  CALL  label             ; call subroutine\n", .{});
    std.debug.print("  RET                      ; return from call\n", .{});
    std.debug.print("  HALT                     ; stop execution\n", .{});

    std.debug.print("\n{s}TERNARY (0x60-0x6D){s}\n", .{ CYAN, RESET });
    std.debug.print("  DOT   dst, v1, v2       ; ternary dot product\n", .{});
    std.debug.print("  BIND  dst, v1, v2       ; VSA bind\n", .{});
    std.debug.print("  BUNDLE2 dst, v1, v2    ; majority vote (2)\n", .{});
    std.debug.print("  BUNDLE3 dst, v1, v2, v3 ; majority vote (3)\n", .{});

    std.debug.print("\n{s}SACRED (0x80-0x92){s}\n", .{ CYAN, RESET });
    std.debug.print("  PHI_CONST dst           ; dst = φ (golden ratio)\n", .{});
    std.debug.print("  PI_CONST  dst           ; dst = π\n", .{});
    std.debug.print("  E_CONST   dst           ; dst = e\n", .{});
    std.debug.print("  SACR  op, dst, src      ; sacred arithmetic\n", .{});

    std.debug.print("\n{s}REGISTERS{s}\n", .{ CYAN, RESET });
    std.debug.print("  t0-t26 (27 ternary registers)\n", .{});
    std.debug.print("  Also accessible as r0-r26\n", .{});
    std.debug.print("  Register 0 is accumulator-like\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELP
// ═══════════════════════════════════════════════════════════════════════════════

fn printHelp() void {
    std.debug.print("\n{s}TRI-27 — Ternary Computing ISA{s}\n", .{ BOLD, RESET });
    std.debug.print("{s}═════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    std.debug.print("{s}Commands:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}tri tri27 assemble <input.tri> -o <output.tbin>{s}  Compile .tri → .tbin\n", .{ GREEN, RESET });
    std.debug.print("  {s}tri tri27 disassemble <input.tbin>{s}              Disassemble .tbin → listing\n", .{ GREEN, RESET });
    std.debug.print("  {s}tri tri27 run <program.tbin>{s}                     Execute .tbin in VM\n", .{ GREEN, RESET });
    std.debug.print("  {s}tri tri27 validate <source.tri>{s}                   Validate .tri specification\n", .{ GREEN, RESET });
    std.debug.print("  {s}tri tri27 isa{s}                                    Show ISA reference\n\n", .{ GREEN, RESET });

    std.debug.print("{s}Examples:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri tri27 assemble prog.tri -o prog.tbin\n", .{});
    std.debug.print("  tri tri27 run prog.tbin\n", .{});
    std.debug.print("  tri tri27 disassemble prog.tbin\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "tri27_cli: decode instruction word" {
    const word: u32 = 0x10234567; // ADD with dst=1, src1=2, src2=3
    const inst = Decoder.decode(word);
    try std.testing.expectEqual(Opcode.ADD, inst.opcode);
    try std.testing.expectEqual(@as(u8, 1), inst.dst);
    try std.testing.expectEqual(@as(u8, 2), inst.src1);
    try std.testing.expectEqual(@as(u8, 3), inst.src2);
}

test "tri27_cli: runIsaCommand does not crash" {
    runIsaCommand() catch {};
}

// Main entry point for standalone tri27 executable
pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const allocator = arena_state.allocator();

    // Get command-line arguments
    var args = std.process.argsAlloc(allocator) catch |e| {
        std.debug.print("Error: failed to get args: {s}\n", .{@errorName(e)});
        return e;
    };
    defer allocator.free(args);

    if (args.len < 1) {
        printHelp();
        return;
    }

    try runTri27Command(allocator, args[1..]);
}
