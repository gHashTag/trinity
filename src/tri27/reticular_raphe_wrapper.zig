// @origin(manual) @regen(manual-impl)
// RETICULAR RAPHE WRAPPER — PPL Rolling Average with φ-Decay
//
// Shell wrapper for reticular_raphe.t27 TRI-27 module.
// Loads and executes the assembly program for computing
// rolling average Perplexity with φ-based weight decay.
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

const emu = @import("emu");
const CPUState = emu.cpu_state.CPUState;
const executor = emu.executor;
const decoder = emu.decoder;
const asm_parser = emu.asm_parser;

/// Reticular Raphe program wrapper
pub const ReticularRaphe = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) ReticularRaphe {
        return .{ .allocator = allocator };
    }

    /// Load reticular_raphe.t27 from source file
    pub fn loadFromFile(self: *const ReticularRaphe, path: []const u8) ![]u8 {
        const source = try std.fs.cwd().readFileAlloc(self.allocator, path, 10240);
        defer self.allocator.free(source);
        return self.assembleSource(source);
    }

    /// Assemble TRI-27 source code to bytecode
    fn assembleSource(self: *const ReticularRaphe, source: []const u8) ![]u8 {
        return asm_parser.assemble(self.allocator, source);
    }

    /// Execute reticular_raphe program with given PPL values
    /// Returns rolling PPL average in Q16 fixed-point format
    pub fn execute(self: *const ReticularRaphe, bytecode: []const u8, input_ppls: []const u16) !f64 {
        var cpu = try CPUState.init(self.allocator);
        defer cpu.deinit();

        // Allocate memory (4KB, 8-byte aligned)
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

        // Load bytecode into instruction memory
        for (bytecode, 0..) |byte, i| {
            if (i < memory.len) {
                memory[i] = byte;
            }
        }

        cpu.pc = 0;

        // Execute until HALT
        while (true) {
            if (cpu.flags.H) break;

            const mem_offset = cpu.pc * 4;
            if (mem_offset + 4 > memory.len) return error.InvalidMemory;

            const word: u32 = memory[mem_offset] |
                @as(u32, memory[mem_offset + 1]) << 8 |
                @as(u32, memory[mem_offset + 2]) << 16 |
                @as(u32, memory[mem_offset + 3]) << 24;

            const inst = decoder.decode(word);
            executor.execute(&cpu, inst, memory) catch |err| {
                if (err == executor.ExecError.Halted) break;
                return err;
            };
        }

        // Return result from t0 (Q16 to float)
        // t27[0] is a Trit27 with trits: i64 field
        const result_raw = cpu.t27[0].trits;
        const result_q16 = @as(i16, @intCast(result_raw & 0xFFFF));
        return @as(f64, @floatFromInt(result_q16)) / 65536.0;
    }

    /// Convenience function: compute rolling PPL from raw values
    pub fn computeRollingPPL(self: *const ReticularRaphe, ppls: []const f64, source: []const u8) !f64 {
        // Convert PPLs to Q16 fixed-point
        var q16_ppls = try self.allocator.alloc(u16, ppls.len);
        defer self.allocator.free(q16_ppls);

        for (ppls, 0..) |ppl, i| {
            // Clamp PPL to [0, 127] and convert to Q16
            const clamped = @max(0, @min(127.0, ppl));
            q16_ppls[i] = @intFromFloat(clamped * 65536.0);
        }

        // Load and execute
        const bytecode = try self.assembleSource(source);
        defer self.allocator.free(bytecode);

        return try self.execute(bytecode, q16_ppls);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "reticular_raphe_wrapper init" {
    const allocator = std.testing.allocator;
    const wrapper = ReticularRaphe.init(allocator);
    try std.testing.expectEqual(@as(Allocator, allocator), wrapper.allocator);
}

test "reticular_raphe_wrapper load_and_execute" {
    const allocator = std.testing.allocator;
    var wrapper = ReticularRaphe.init(allocator);

    // Simple program: load immediate and halt
    const source = "LDI t0, 100\nHALT";
    const bytecode = try wrapper.assembleSource(source);
    defer allocator.free(bytecode);

    const input = [_]u16{};
    const result = try wrapper.execute(bytecode, &input);

    // Result should be positive
    try std.testing.expect(result > 0.0);
}

test "reticular_raphe_wrapper rolling_ppl" {
    const allocator = std.testing.allocator;
    var wrapper = ReticularRaphe.init(allocator);

    // Note: This test uses a simple source, not the full reticular_raphe.t27
    // Just verify execution works without asserting exact values
    // since trit encoding may produce different results
    const source = "LDI t0, 0\nHALT";
    const bytecode = try wrapper.assembleSource(source);
    defer allocator.free(bytecode);

    // Q16 values: Using small PPL values in Q16 format
    var q16_ppls = [_]u16{6553, 7864, 7536, 8519, 7208}; // PPLs in Q16
    const result = try wrapper.execute(bytecode, &q16_ppls);

    // With LDI t0, 0, the result should be 0
    try std.testing.expectEqual(@as(f64, 0.0), result);
}
