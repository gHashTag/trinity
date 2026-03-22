// @origin(spec:tri27_isa.zig) @regen(manual-impl)
// TRI‑27 EMULATOR — Main CLI Entry Point
//
// Command-line interface for tri-emu:
//   tri-emu <file.tbin> [options]
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

const Memory = @import("tri_memory.zig").Memory;
const CPUState = @import("cpu_state.zig").CPUState;

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

/// Run the TRI-27 emulator
pub fn runEmulator(tbin_path: []const u8, options: *const Options, allocator: std.mem.Allocator) !EmulatorResult {
    const Instruction = @import("decoder.zig").Instruction;

    // Initialize memory
    var mem = try Memory.init(allocator);
    defer mem.deinit(allocator);

    // Load program
    const Loader = @import("tri_loader.zig");
    const load_result = try Loader.load(tbin_path, allocator, &mem);

    if (options.verbose) {
        std.debug.print("Loaded: {s}\n", .{tbin_path});
        std.debug.print("  Entry point: 0x{X:0>4}\n", .{load_result.entry_point});
        std.debug.print("  Instructions: {d}\n", .{load_result.instruction_count});
        std.debug.print("  Code size: {} bytes\n", .{load_result.code_size});
    }

    // Initialize CPU
    var cpu = CPUState.init(allocator);
    cpu.ip = load_result.entry_point;
    cpu.sp = 19683;

    if (options.verbose) {
        std.debug.print("  SP: 0x{X:0>4}\n", .{cpu.sp});
        std.debug.print("  FP: 0x{X:0>4}\n", .{cpu.fp});
    }

    // Main execution loop
    var exit_reason: []const u8 = "normal";
    const max_cycles: u32 = if (options.max_cycles) |mc| mc else @as(u32, std.math.maxInt(u32));

    while (!cpu.flags.H) {
        // Check cycle limit
        if (options.max_cycles != null and cpu.cycles >= max_cycles) {
            exit_reason = "cycle limit reached";
            break;
        }

        // Fetch instruction
        const ip = cpu.ip;

        // Check IP bounds
        const mem_words = mem.data.len / @sizeOf(u32);
        if (ip >= mem_words) {
            exit_reason = "invalid instruction pointer";
            break;
        }

        const inst_word = try mem.readWord(ip);
        const inst = Instruction.decode(inst_word);

        if (options.trace) {
            std.debug.print("  0x{X:0>4}: {s}\n", .{ ip, inst.opcode });
        }

        // Execute instruction
        execute(&cpu, &inst, mem.data) catch |err| {
            exit_reason = @errorName(err);
            break;
        };

        // Estimate cycles for this instruction
        const cycles = @import("tri_exec.zig").estimateCycles(inst.opcode);
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
        .final_ip = cpu.ip,
    };
}

/// Execute instruction (re-export from tri_exec.zig)
const execute = @import("tri_exec.zig").execute;

/// Print usage information
fn printUsage() !void {
    const stdout_file = std.fs.File.stdout();
    var write_buf: [4096]u8 = undefined;
    const stdout = stdout_file.writer(&write_buf);

    const msg =
        \\TRI-27 Emulator — Software Emulator for TRI-27 RISC Processor
        \\
        \\Usage: tri-emu <file.tbin> [options]
        \\
        \\Options:
        \\  -v, --verbose      Verbose output (load info, instruction trace)
        \\  -t, --trace        Trace every instruction
        \\  -s, --stats        Print execution statistics
        \\  -dm, --dump-memory Dump memory state at exit
        \\  -d <n>, --dump <n> Dump memory after N instructions
        \\  -m <n>, --max-cycles <n> Stop after N cycles
        \\  -h, --help         Show this help message
        \\
        \\Examples:
        \\  tri-emu program.tbin                    Run program to completion
        \\  tri-emu program.tbin -v -t            Run with verbose trace
        \\  tri-emu program.tbin -s                Show statistics only
        \\  tri-emu program.tbin -m 100000      Stop after 100K cycles
        \\  tri-emu program.tbin -d 50           Dump memory after 50 instrs
        \\
        \\Exit codes:
        \\  0  - Success
        \\  1  - Usage error
        \\  2  - File not found
        \\  3  - Invalid .tbin file
        \\  4  - Emulation error
        \\
    ;
    try stdout.writeAll(msg);
    try stdout.flush();
}

/// Print execution statistics
fn printStats(result: *const EmulatorResult) !void {
    const stdout_file = std.fs.File.stdout();
    var write_buf: [8192]u8 = undefined;
    const stdout = stdout_file.writer(&write_buf);

    const ipc = if (result.cycles > 0)
        @as(f64, @floatFromInt(result.instructions_executed)) / @as(f64, @floatFromInt(result.cycles))
    else
        0.0;

    const msg = try std.fmt.allocPrint(std.heap.page_allocator,
        \\n
        ╔══════════════════════════════════════════════════════════╗
        ║  TRI-27 EMULATOR — EXECUTION STATISTICS                              ║
        ╠══════════════════════════════════════════════════════╣
        ║                                                                  ║
        ║  Instructions executed:  {:>15}                                ║
        ║  Cycles completed:      {:>15}                                ║
        ║  Instructions/cycle:    {:>15.2}                             ║
        ║  Exit reason:          {:>15s}                                ║
        ║  Final IP:           0x{X:0>10}                                ║
        ║                                                                  ║
        ╚══════════════════════════════════════════════════════════════╝
    , .{result.instructions_executed, result.cycles, ipc, result.exit_reason, result.final_ip});
    defer std.heap.page_allocator.free(msg);

    try stdout.writeAll(msg);
    try stdout.flush();
}

/// Dump current memory and CPU state
fn dumpMemoryState(cpu: CPUState) !void {
    const stdout_file = std.fs.File.stdout();
    var write_buf: [8192]u8 = undefined;
    const stdout = stdout_file.writer(&write_buf);

    var msg_list = std.ArrayList(u8).init(std.heap.page_allocator);
    defer msg_list.deinit();

    const writer = msg_list.writer();

    try writer.writeAll(
        \\n╔════════════════════════════════════════════════════════════════╗
        ║  TRI-27 CPU STATE — DUMP                                               ║
        ╠══════════════════════════════════════════════════════════╣
        ║  Registers:                                                       ║
    );

    // Print ternary registers (8 per line)
    try writer.writeAll("║  t0-t7:  ");
    for (0..8) |i| {
        const val = cpu.trits[i];
        try writer.print("t{d}={d:>3} ", .{ i, val });
    }
    try writer.writeAll("               ║\n");

    try writer.writeAll("║  t8-t15: ");
    for (8..16) |i| {
        const val = cpu.trits[i];
        try writer.print("t{d}={d:>3} ", .{ i, val });
    }
    try writer.writeAll("               ║\n");

    try writer.writeAll(
        \\║                                                                  ║
        \\║  Special registers:                                              ║
    );

    try writer.print("║    PC = 0x{X:0>8}    SP = 0x{X:0>8}    FP = 0x{X:0>8}    ║\n", .{ cpu.pc, cpu.sp, cpu.fp });
    try writer.writeAll("║                                                                  ║\n");
    try writer.writeAll("║  Flags: zero={} negative={} positive={}                                 ║\n", .{
        if (cpu.flags.zero) 1 else 0,
        if (cpu.flags.negative) 1 else 0,
        if (cpu.flags.positive) 1 else 0,
    });
    try writer.writeAll("║                                                                  ║\n");
    try writer.writeAll("║  Metrics:                                                        ║\n");
    try writer.writeAll("║  Instructions: {}    Cycles: {}                         ║\n", .{
        cpu.instructions_executed,
        cpu.cycles,
    });
    try writer.writeAll("╚════════════════════════════════════════════════════════╝\n");

    try stdout.writeAll(msg_list.items);
    try stdout.flush();
}
