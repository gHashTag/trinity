// @origin(manual) @regen(manual-impl)
// RETICULAR RAPHE LOADER — Load and execute reticular_raphe.t27
//
// Loads the reticular_raphe.t27 reference implementation for
// PPL (Perplexity) rolling average with φ-decay.
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

const CPUState = @import("cpu_state.zig").CPUState;
const executor = @import("executor.zig");
const Assembler = @import("tri_asm.zig").Assembler;

/// Reticular Raphe program loader
pub const ReticularLoader = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) ReticularLoader {
        return .{ .allocator = allocator };
    }

    /// Load reticular_raphe.t27 from source file
    pub fn loadFromFile(self: *const ReticularLoader, path: []const u8) ![]u8 {
        const source = try std.fs.cwd().readFileAlloc(self.allocator, path, 10240);
        defer self.allocator.free(source);
        return self.assembleSource(source);
    }

    /// Load reticular_raphe.t27 from source string
    pub fn loadFromSource(self: *const ReticularLoader, source: []const u8) ![]u8 {
        return self.assembleSource(source);
    }

    /// Assemble TRI-27 source code to bytecode
    fn assembleSource(self: *const ReticularLoader, source: []const u8) ![]u8 {
        // Use the existing assembler
        const asm_parser = @import("asm_parser.zig");
        return asm_parser.assemble(self.allocator, source);
    }

    /// Execute reticular_raphe program with given bytecode and input PPL values
    pub fn execute(self: *const ReticularLoader, bytecode: []const u8, input_ppls: []const u16) !f64 {
        // Initialize CPU
        var cpu = try CPUState.init(self.allocator);
        defer cpu.deinit();

        // Allocate memory (4KB, 8-byte aligned for executor)
        // Using a fixed-size array on stack for proper alignment
        var memory_stack: [4096]u8 align(8) = undefined;
        @memset(&memory_stack, 0);
        var memory = memory_stack[0..];

        // Write input PPLs to memory at MEM_EVALUATIONS (offset 16)
        const mem_evaluations: u32 = 16;
        for (input_ppls, 0..) |ppl, i| {
            const addr = mem_evaluations + i * 2;
            if (addr + 2 <= memory.len) {
                memory[addr] = @as(u8, @truncate(ppl));
                memory[addr + 1] = @as(u8, @truncate(ppl >> 8));
            }
        }

        // Load bytecode into instruction memory (at beginning)
        for (bytecode, 0..) |byte, i| {
            if (i < memory.len) {
                memory[i] = byte;
            }
        }

        // Set PC to code start
        cpu.pc = 0;

        // Execute until HALT
        const decoder = @import("decoder.zig");
        while (true) {
            // Check H flag (set by HALT instruction)
            if (cpu.flags.H) break;

            // Fetch instruction (PC is word index, so multiply by 4 for byte offset)
            const mem_offset = cpu.pc * 4;
            if (mem_offset + 4 > memory.len) return error.InvalidMemory;

            const word: u32 = memory[mem_offset] |
                @as(u32, memory[mem_offset + 1]) << 8 |
                @as(u32, memory[mem_offset + 2]) << 16 |
                @as(u32, memory[mem_offset + 3]) << 24;

            const inst = decoder.decode(word);

            // Execute
            executor.execute(&cpu, inst, memory) catch |err| {
                if (err == executor.ExecError.Halted) {
                    break;
                }
                return err;
            };
        }

        // Return result from t0 (Q16 fixed-point to float)
        const result_q16 = @as(i16, @truncate(cpu.t27[0].trits & 0xFFFF));
        return @as(f64, @floatFromInt(result_q16)) / 65536.0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "reticular_loader init" {
    const allocator = std.testing.allocator;
    const loader = ReticularLoader.init(allocator);
    try std.testing.expectEqual(@as(Allocator, allocator), loader.allocator);
}

test "reticular_loader load_simple_program" {
    const allocator = std.testing.allocator;
    var loader = ReticularLoader.init(allocator);

    // Simple TRI-27 program: LDI t0, 42; HALT
    const source = "LDI t0, 42\nHALT";
    const bytecode = loader.loadFromSource(source) catch |err| {
        std.debug.print("Load error: {}\n", .{err});
        return err;
    };
    defer allocator.free(bytecode);

    // Should have some bytecode (2 instructions = 8 bytes)
    try std.testing.expect(bytecode.len > 0);
}

test "reticular_loader execute_simple" {
    const allocator = std.testing.allocator;
    var loader = ReticularLoader.init(allocator);

    // Simple program that loads immediate and halts
    const source = "LDI t0, 100\nHALT";
    const bytecode = try loader.loadFromSource(source);
    defer allocator.free(bytecode);

    // Empty input (not used by this simple program)
    const input = [_]u16{};
    const result = try loader.execute(bytecode, &input);

    // Result should be positive (100 Q16 = 100/65536 ≈ 0.0015)
    try std.testing.expect(result > 0.0);
}

test "reticular_loader load_from_source" {
    const allocator = std.testing.allocator;
    var loader = ReticularLoader.init(allocator);

    // Program with ADD instruction
    const source =
        \\LDI t0, 10
        \\LDI t1, 20
        \\ADD t2, t0, t1
        \\HALT
    ;
    const bytecode = loader.loadFromSource(source) catch |err| {
        std.debug.print("Load error: {}\n", .{err});
        return err;
    };
    defer allocator.free(bytecode);

    // Should have bytecode (4 instructions = 16 bytes)
    try std.testing.expect(bytecode.len >= 16);
}

test "reticular_loader opcodes_supported" {
    const allocator = std.testing.allocator;
    var loader = ReticularLoader.init(allocator);

    // Test all opcodes used by reticular_raphe.t27
    // Using immediate offsets instead of labels
    const source =
        \\LDI t0, 1      # LDI
        \\LDI t1, 2      # LD
        \\ADD t2, t0, t1 # ADD
        \\MUL t3, t0, t1 # MUL
        \\MOV t4, t0     # MOV
        \\SHR t5, t0     # SHR
        \\JZ t0, 10      # JZ
        \\JNZ t0, 10     # JNZ
        \\JGT t0, t1, 10 # JGT
        \\JLT t0, t1, 10 # JLT
        \\JMP 10         # JMP
        \\HALT
    ;
    const bytecode = loader.loadFromSource(source) catch |err| {
        std.debug.print("Load error: {}\n", .{err});
        return err;
    };
    defer allocator.free(bytecode);

    // Should have bytecode
    try std.testing.expect(bytecode.len > 0);
}
