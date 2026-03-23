const std = @import("std");

const CPUState = @import("cpu_state.zig").CPUState;
const Instruction = @import("decoder.zig").Instruction;
const Opcode = @import("decoder.zig").Opcode;
const Memory = @import("tri_memory.zig").Memory;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    if (args.len < 2) {
        try printUsage();
        return error.Usage;
    }

    const tbin_path = args[1];

    // Parse options
    var options = Options{
        .verbose = false,
        .stats = false,
        .dump_memory = false,
        .dump_instructions = 0,
        .trace = false,
        .max_cycles = null,
    };

    var i: usize = 2;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
            options.verbose = true;
        } else if (std.mem.eql(u8, arg, "--stats") or std.mem.eql(u8, arg, "-s")) {
            options.stats = true;
        } else if (std.mem.eql(u8, arg, "--trace") or std.mem.eql(u8, arg, "-t")) {
            options.trace = true;
        } else if (std.mem.eql(u8, arg, "--dump-memory") or std.mem.eql(u8, arg, "-dm")) {
            options.dump_memory = true;
        } else if (std.mem.eql(u8, arg, "--dump") or std.mem.eql(u8, arg, "-d")) {
            if (i + 1 < args.len) {
                options.dump_instructions = try std.fmt.parseInt(u32, args[i + 1], 10);
                i += 1;
            }
        } else if (std.mem.eql(u8, arg, "--max-cycles") or std.mem.eql(u8, arg, "-m")) {
            if (i + 1 < args.len) {
                options.max_cycles = try std.fmt.parseInt(u32, args[i + 1], 10);
                i += 1;
            }
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            try printUsage();
            return error.Usage;
        } else {
            std.debug.print("Unknown option: {s}\n", .{arg});
            try printUsage();
            return error.Usage;
        }
    }

    // Run emulator
    const result = runEmulator(tbin_path, &options, allocator);

    if (result) |r| {
        if (options.stats) {
            try printStats(&r);
        }
    } else |err| {
        std.debug.print("Emulator error: {}\n", .{err});
        return err;
    }
}

pub const Options = struct {
    verbose: bool,
    stats: bool,
    dump_memory: bool,
    dump_instructions: u32,
    trace: bool,
    max_cycles: ?u32,
};

pub const EmulatorResult = struct {
    instructions_executed: u64,
    cycles: u64,
    exit_reason: []const u8,
    final_ip: u32,
};

/// Run TRI-27 emulator
pub fn runEmulator(tbin_path: []const u8, options: *const Options, allocator: std.mem.Allocator) !EmulatorResult {
    const decodeInstruction = @import("decoder.zig").decodeInstruction;
    const execute = @import("executor.zig").execute;
    const estimateCycles = @import("executor.zig").estimateCycles;

    // Initialize memory
    var mem = try Memory.init(allocator);
    defer mem.deinit();

    // Load program
    const Loader = @import("tri_loader.zig");
    const load_result = try Loader.loadBinary(tbin_path, &mem, allocator);

    if (options.verbose) {
        std.debug.print("Loaded: {s}\n", .{tbin_path});
        std.debug.print("  Entry point: 0x{X:0>4}\n", .{load_result.entry_point});
        std.debug.print("  Instructions: {d}\n", .{load_result.instruction_count});
        std.debug.print("  Code size: {} bytes\n", .{load_result.code_size});
    }

    // Initialize CPU with memory from cpu_state
    var cpu = try CPUState.init(allocator);
    cpu.pc = load_result.entry_point;
    cpu.sp = 19683;

    if (options.verbose) {
        std.debug.print("  SP: 0x{X:0>4}\n", .{cpu.sp});
        std.debug.print("  FP: 0x{X:0>4}\n", .{cpu.fp});
    }

    // Main execution loop
    var exit_reason: []const u8 = "normal";
    const max_cycles: u32 = if (options.max_cycles) |mc| mc else std.math.maxInt(u32);

    while (!cpu.flags.H) {
        // Check cycle limit
        if (options.max_cycles != null and cpu.instructions_executed >= max_cycles) {
            exit_reason = "cycle limit reached";
            break;
        }

        // Fetch instruction
        const ip = cpu.pc;

        // Check IP bounds (word-aligned)
        const memory_bytes = cpu.getBytesMut();
        const mem_words = memory_bytes.len / 4;
        if (ip >= mem_words) {
            exit_reason = "invalid instruction pointer";
            break;
        }

        const inst_word = try mem.readWord(ip);
        const inst = decodeInstruction(inst_word);

        if (options.trace) {
            std.debug.print("  0x{X:0>4}: {s}\n", .{ ip, @tagName(inst.opcode) });
        }

        // Execute instruction
        execute(&cpu, inst, cpu.getBytesMut()) catch |err| {
            exit_reason = @errorName(err);
            break;
        };

        // Estimate cycles for this instruction
        const cycles = estimateCycles(inst.opcode);
        cpu.cycles += cycles;

        // Dump memory if requested at this instruction
        if (options.dump_instructions > 0 and cpu.instructions_executed == options.dump_instructions) {
            try dumpMemoryState(cpu);
            exit_reason = "dump requested";
            break;
        }
    }

    return EmulatorResult{
        .instructions_executed = cpu.instructions_executed,
        .cycles = cpu.cycles,
        .exit_reason = exit_reason,
        .final_ip = cpu.pc,
    };
}

/// Print usage information
fn printUsage() !void {
    const msg = "TRI-27 Emulator — Software Emulator for TRI-27 RISC Processor\nUsage: tri-emu <file.tbin> [options]\nOptions:\n  -v, --verbose      Verbose output (load info, instruction trace)\n  -t, --trace        Trace every instruction\n  -s, --stats        Print execution statistics\n  -dm, --dump-memory Dump memory state at exit\n  -d <n>, --dump <n> Dump memory after N instructions\n  -m <n>, --max-cycles <n> Stop after N cycles\n  -h, --help         Show this help message\n\nExamples:\n  tri-emu program.tbin                    Run program to completion\n  tri-emu program.tbin -v -t            Run with verbose trace\n  tri-emu program.tbin -s                Show statistics only\n  tri-emu program.tbin -m 100000      Stop after 100K cycles\n  tri-emu program.tbin -d 50           Dump memory after 50 instrs\n\nExit codes:\n  0  - Success\n  1  - Usage error\n  2  - File not found\n  3  - Invalid .tbin file\n  4  - Emulation error\n";
    std.debug.print("{s}\n", .{msg});
}

/// Print execution statistics
fn printStats(result: *const EmulatorResult) !void {
    const ipc = if (result.cycles > 0)
        @as(f64, @floatFromInt(result.instructions_executed)) / @as(f64, @floatFromInt(result.cycles))
    else
        0.0;

    std.debug.print("Instructions: {}\n", .{result.instructions_executed});
    std.debug.print("Cycles: {}\n", .{result.cycles});
    std.debug.print("IPC: {d:.2}\n", .{ipc});
    std.debug.print("Exit reason: {s}\n", .{result.exit_reason});
    std.debug.print("Final IP: 0x{X:0>8}\n", .{result.final_ip});
}

/// Dump current memory and CPU state
fn dumpMemoryState(cpu: CPUState) !void {
    const z_flag: u8 = if (cpu.flags.Z) 1 else 0;
    const n_flag: u8 = if (cpu.flags.N) 1 else 0;
    const v_flag: u8 = if (cpu.flags.V) 1 else 0;
    const h_flag: u8 = if (cpu.flags.H) 1 else 0;

    std.debug.print("PC: 0x{X:0>8}\n", .{cpu.pc});
    std.debug.print("SP: 0x{X:0>8}\n", .{cpu.sp});
    std.debug.print("FP: 0x{X:0>8}\n", .{cpu.fp});
    std.debug.print("Flags: Z={} N={} V={} H={}\n", .{ z_flag, n_flag, v_flag, h_flag });
    std.debug.print("Instructions executed: {}\n", .{cpu.instructions_executed});
    std.debug.print("Cycles: {}\n", .{cpu.cycles});
}
