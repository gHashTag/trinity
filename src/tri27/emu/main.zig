// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════ functional language, no OOP constructs

const std = @import("std");

const cpu_state = @import("./cpu_state.zig");
const loader = @import("./loader.zig");
const executor = @import("./executor.zig");

/// Default memory size (4KB)
const DEFAULT_MEMORY_SIZE: usize = 4096;

/// Command: tri-emu program.tbin
/// Usage: tri-emu program.tbin
pub fn main() !void {
    // Parse command line arguments
    var args = try std.process.argsAlloc(std.heap.page_allocator);

    if (args.len < 2) {
        std.debug.print("Usage: tri-emu program.tbin\n", .{});
        std.debug.print("  TRI-27 Emulator for executing .tbin bytecode files\n\n", .{});
        return;
    }

    const filepath = args[1];

    // Initialize CPU with 4KB memory
    var cpu = try cpu_state.CPUState.init(std.heap.page_allocator, DEFAULT_MEMORY_SIZE);
    defer cpu.deinit();

    // Load .tbin file
    const file_data = try std.fs.cwd().readFileAlloc(std.heap.page_allocator, filepath, MAX_FILE_BYTES);
    defer std.heap.page_allocator.free(file_data);

    if (file_data == LoadError) |value| {
        std.debug.print("Error: {}\n", .{file_data});
        std.os.exit(1);
    }

    // Load and execute program
    try loader.load(&cpu, &file_data, &[_]f64{});

    // Execute until halt
    while (!cpu.halted) {
        try executor.executeInstruction(&cpu, &cpu.code[cpu.pc..]);
        cpu.instructions_executed += 1;
    }

    // Print execution statistics
    const time_ns = cpu.getExecutionTimeNs();
    const ips = cpu.getIPS();

    std.debug.print("\n=== TRI-27 Execution Complete ===\n", .{});
    std.debug.print("Instructions: {}\n", .{cpu.instructions_executed});
    std.debug.print("Time: {} ms ({} IPS)\n", .{ cpu.getExecutionTimeMs(), ips });
    std.debug.print("PC: 0x{X:04X}\n", .{cpu.pc});
    std.debug.print("Flags: Z={} N={} P={}\n", .{
        cpu.flags.zero, cpu.flags.negative, cpu.flags.positive,
    });

    // Print register state
    std.debug.print("\n=== Register State ===\n", .{});
    std.debug.print("Float registers: f0={d:.6} f1={d:.6} f2={d:.6}\n", .{
        cpu.floats[0], cpu.floats[1], cpu.floats[2],
    });

    // Print memory usage
    const used_memory = cpu.pc; // Approximate by code pointer
    std.debug.print("Memory: {}/{} bytes used\n", .{
        used_memory, cpu.memory_len,
    });
}

const MAX_FILE_BYTES: usize = 1024 * 1024; // 1MB max file size
