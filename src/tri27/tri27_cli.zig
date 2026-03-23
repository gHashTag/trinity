// TRI‑27 CLI — Command-line interface for TRI‑27 operations
// ═══════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const Decoder = @import("emu/decoder.zig");
const Opcode = Decoder.Opcode;
const Instruction = Decoder.Instruction;
const Assembler = @import("emu/tri_asm.zig");
const Executor = @import("emu/executor.zig");
const CPUState = @import("emu/cpu_state.zig").CPUState;
const tri27_experience = @import("tri27_experience.zig");
const tri27_experience_jsonl = @import("tri27_experience_jsonl.zig");

const print = std.debug.print;

// ════════════════════════════════════════════════════════
const DIM = "\x1b[2m";
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";

// ═══════════════════════════════════════════════════════════════════════

pub fn runTri27Command(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "";

    if (std.mem.eql(u8, subcmd, "assemble") or std.mem.eql(u8, subcmd, "asm")) {
        return runAssembleCommand(allocator, args);
    } else if (std.mem.eql(u8, subcmd, "disassemble") or std.mem.eql(u8, subcmd, "disasm")) {
        return runDisassembleCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "run")) {
        return runRunCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "validate")) {
        return runValidateCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "experience") or std.mem.eql(u8, subcmd, "exp")) {
        return runExperienceCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "isa")) {
        return runIsaCommand();
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help") or std.mem.eql(u8, subcmd, "-h")) {
        printHelp();
    } else {
        print("{s}Unknown tri27 subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printHelp();
    }
}

fn runAssembleCommand(allocator: Allocator, all_args: []const []const u8) !void {
    if (all_args.len < 1) {
        print("  Usage: tri tri27 assemble <input.tri> -o <output.tbin>\n\n", .{});
        return;
    }

    const input_file = all_args[0];
    var output_file: []const u8 = "output.tbin";

    var i: usize = 1;
    while (i < all_args.len) : (i += 1) {
        if (std.mem.eql(u8, all_args[i], "-o")) {
            i += 1;
            if (i < all_args.len) {
                output_file = all_args[i];
            }
        }
    }

    const asm_content = std.fs.cwd().readFileAlloc(allocator, input_file, 4096) catch |e| {
        print("Error reading {s}: {}\n", .{ input_file, e });
        return error.ReadFileFailed;
    };
    defer allocator.free(asm_content);

    const bytecode = try Assembler.assemble(allocator, asm_content);
    const file = try std.fs.cwd().createFile(output_file, .{});
    defer file.close();
    try file.writeAll(bytecode);
    allocator.free(bytecode);

    // Save episode to Episode/JSONL
    try tri27_experience_jsonl.saveTri27Episode(
        allocator,
        .assemble,
        input_file,
        output_file,
        .success,
        0,
        @intCast(bytecode.len / 4),
        "",
    );

    print("{s}✅ Assembled {d} instructions{s}\n", .{ GREEN, bytecode.len / 4, RESET });
    print("{s}Wrote to: {s}{s}\n", .{ GREEN, output_file, RESET });
}

fn runDisassembleCommand(allocator: Allocator, all_args: []const []const u8) !void {
    if (all_args.len < 1) {
        print("{s}Error: missing input file{s}\n", .{ RED, RESET });
        print("  Usage: tri tri27 disassemble <input.tbin>\n\n", .{});
        return;
    }

    const input_file = all_args[0];
    const tbin_content = std.fs.cwd().readFileAlloc(allocator, input_file, 1024 * 1024) catch |e| {
        print("Error reading {s}: {}\n", .{ input_file, e });
        return error.ReadFileFailed;
    };
    defer allocator.free(tbin_content);

    print("{s}Disassembling {s} ({d} bytes){s}\n", .{ CYAN, input_file, tbin_content.len, RESET });
    print("{s}TODO: implement disassembly{s}\n", .{ YELLOW, RESET });
}

fn runRunCommand(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        print("{s}Error: missing input file{s}\n", .{ RED, RESET });
        print("  Usage: tri tri27 run <program.tbin>\n\n", .{});
        return;
    }

    const input_file = args[0];
    const tbin_content = std.fs.cwd().readFileAlloc(allocator, input_file, 1024 * 1024) catch |e| {
        print("Error reading {s}: {}\n", .{ input_file, e });
        return error.ReadFileFailed;
    };
    defer allocator.free(tbin_content);

    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    // Load program into CPU memory
    const cpu_memory = cpu.getBytesMut();
    const copy_len = @min(tbin_content.len, cpu_memory.len);
    @memcpy(cpu_memory[0..copy_len], tbin_content[0..copy_len]);

    // Execute program
    Executor.run(&cpu, cpu_memory) catch |err| {
        std.debug.print("Execution error: {}\n", .{err});
        return err;
    };

    print("{s}Execution result: HALTED{s}\n", .{ BOLD, RESET });
    print("{s}PC: 0x{X:0>4}{s}\n", .{ BOLD, cpu.pc, RESET });
    print("{s}Instructions executed: {d}{s}\n", .{ BOLD, cpu.instructions_executed, RESET });
    print("{s}Cycles: {d}{s}\n", .{ BOLD, cpu.cycles, RESET });

    // Save episode to Episode/JSONL
    try tri27_experience_jsonl.saveTri27Episode(
        allocator,
        .run,
        input_file,
        "",
        .success,
        @intCast(cpu.cycles),
        @intCast(cpu.instructions_executed),
        "",
    );
}

fn runValidateCommand(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        print("{s}Error: missing input file{s}\n", .{ RED, RESET });
        print("  Usage: tri tri27 validate <source.tri>\n\n", .{});
        return;
    }

    const input_file = args[0];
    const tri_content = std.fs.cwd().readFileAlloc(allocator, input_file, 4096) catch |e| {
        print("Error reading {s}: {}\n", .{ input_file, e });
        return error.ReadFileFailed;
    };
    defer allocator.free(tri_content);

    print("{s}Validation not yet implemented{s}\n", .{ YELLOW, RESET });

    // Save episode to Episode/JSONL
    try tri27_experience_jsonl.saveTri27Episode(
        allocator,
        .validate,
        input_file,
        "",
        .success,
        0,
        0,
        "",
    );
}

fn runIsaCommand() !void {
    print("\n{s}TRI-27 INSTRUCTION SET ARCHITECTURE{s}\n", .{ BOLD, RESET });
    print("{s}═══════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    print("{s}ARITHMETIC (0x60-0x17){s}\n", .{ CYAN, RESET });
    print("  ADD   dst, src1, src2   ; dst = src1 + src2\n", .{});
    print("  SUB   dst, src1, src2   ; dst = src1 - src2\n", .{});
    print("  MUL   dst, src1, src2   ; dst = src1 * src2\n", .{});
    print("  DIV   dst, src1, src2   ; dst = src1 / src2\n", .{});
    print("  INC   dst               ; dst++\n", .{});
    print("  DEC   dst               ; dst--\n", .{});

    print("\n{s}LOGIC (0x18-0x1D){s}\n", .{ CYAN, RESET });
    print("  AND   dst, src1, src2   ; dst = src1 & src2\n", .{});
    print("  OR    dst, src1, src2   ; dst = src1 | src2\n", .{});
    print("  XOR   dst, src1, src2   ; dst = src1 ^ src2\n", .{});
    print("  NOT   dst               ; dst = ~dst\n", .{});
    print("  SHL   dst, src1, shift  ; dst = src1 << shift\n", .{});
    print("  SHR   dst, src1, shift  ; dst = src1 >> shift\n", .{});

    print("\n{s}TERNARY (0x60-0x6D){s}\n", .{ CYAN, RESET });
    print("  DOT   dst, v1, v2       ; ternary dot product\n", .{});
    print("  BIND  dst, v1, v2       ; VSA bind\n", .{});
    print("  BUNDLE2 dst, v1, v2    ; majority vote (2)\n", .{});
    print("  BUNDLE3 dst, v1, v2, v3 ; majority vote (3)\n", .{});

    print("\n{s}SACRED (0x80-0x92){s}\n", .{ CYAN, RESET });
    print("  PHI_CONST dst           ; dst = φ (golden ratio)\n", .{});
    print("  PI_CONST  dst           ; dst = π\n", .{});
    print("  E_CONST   dst           ; dst = e\n", .{});
    print("  SACR  op, dst, src      ; sacred arithmetic\n", .{});

    print("\n{s}REGISTERS{s}\n", .{ CYAN, RESET });
    print("  t0-t26 (27 ternary registers)\n", .{});
    print("  Also accessible as r0-r26\n", .{});
    print("  Register 0 is accumulator-like\n\n", .{});
}

fn runExperienceCommand(_: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        print("{s}Error: missing subcommand{s}\n", .{ RED, RESET });
        print("  experience init                    Initialize experience log\n", .{});
        print("  experience log <file> [ASM|DISASM|RUN|VAL]  Log operation\n", .{});
        print("  experience status                  Show event history\n", .{});
        print("  experience record <issue>          Record episode from last event\n", .{});
        return;
    }

    const subcmd = args[0];

    if (std.mem.eql(u8, subcmd, "init")) {
        tri27_experience.initEventLog();
        print("{s}TRI-27 experience log initialized{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, subcmd, "log")) {
        const input_file = if (args.len > 1) args[1] else "";
        const operation_str = if (args.len > 2) args[2] else "RUN";

        var event = tri27_experience.Tri27Event{
            .timestamp = 0,
            .operation = .assemble,
            .input_file = [_]u8{0} ** 256,
            .output_file = [_]u8{0} ** 256,
            .status = .queued,
            .cycles = 0,
            .instructions = 0,
            .error_msg = [_]u8{0} ** 512,
            .has_error = false,
        };
        event.timestamp = std.time.timestamp();
        event.operation = tri27_experience.parseOperation(operation_str);

        var i: usize = 0;
        const copy_len = @min(255, input_file.len);
        while (i < copy_len) : (i += 1) {
            event.input_file[i] = input_file[i];
        }
        if (copy_len < 255) {
            event.input_file[copy_len] = 0;
        }

        event.status = tri27_experience.Tri27Status.success;
        tri27_experience.logEvent(event);

        print("{s}Logged: {s} {s} → {s}\n", .{ GREEN, event.operation.toStr(), input_file, RESET });
    } else if (std.mem.eql(u8, subcmd, "status")) {
        try tri27_experience.runStatus();
    } else if (std.mem.eql(u8, subcmd, "record")) {
        if (args.len < 2) {
            print("{s}Error: missing issue number{s}\n", .{ RED, RESET });
            return;
        }

        const issue_str = args[1];
        const issue_num = try std.fmt.parseInt(u32, issue_str, 10);

        const event_opt = tri27_experience.getLastEvent();
        const event = if (event_opt) |ev| ev else {
            print("{s}No events to record. Use 'log' first.{s}\n", .{ YELLOW, RESET });
            return;
        };

        try tri27_experience.recordEpisodeFromEvent(event.*, issue_num);
        print("{s}Episode #{d} recorded for issue #{d}{s}\n", .{ GREEN, event.timestamp, issue_num, RESET });
    } else {
        print("{s}Unknown experience subcommand: {s}\n", .{ RED, subcmd });
    }
}

fn printHelp() void {
    print("\n{s}TRI-27 — Ternary Computing ISA{s}\n", .{ BOLD, RESET });
    print("{s}═════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    print("{s}Commands:{s}\n", .{ CYAN, RESET });
    print("  {s}tri tri27 assemble <input.tri> -o <output.tbin>{s}  Compile .tri → .tbin\n", .{ GREEN, RESET });
    print("  {s}tri tri27 disassemble <input.tbin>{s}              Disassemble .tbin → listing\n", .{ GREEN, RESET });
    print("  {s}tri tri27 run <program.tbin>{s}                     Execute .tbin in VM\n", .{ GREEN, RESET });
    print("  {s}tri tri27 validate <source.tri>{s}                   Validate .tri specification\n", .{ GREEN, RESET });
    print("  {s}tri tri27 experience init{s}                        Initialize experience log\n", .{ GREEN, RESET });
    print("  {s}tri tri27 experience log <file> [ASM|DISASM|RUN|VAL]{s}  Log operation\n", .{ GREEN, RESET });
    print("  {s}tri tri27 experience status{s}                       Show event history\n", .{ GREEN, RESET });
    print("  {s}tri tri27 experience record <issue>{s}             Record episode from last event\n", .{ GREEN, RESET });
    print("  {s}tri tri27 isa{s}                                    Show ISA reference\n", .{ GREEN, RESET });

    print("\n{s}Examples:{s}\n", .{ BOLD, RESET });
    print("  tri27 assemble prog.tri -o prog.tbin\n", .{});
    print("  tri27 run prog.tbin\n", .{});
    print("  tri27 disassemble prog.tbin\n", .{});
}

pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const allocator = arena_state.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    if (args.len < 2) {
        printHelp();
        return;
    }

    try runTri27Command(allocator, args[2..]);
}
