// @origin(manual) @regen(manual-impl)
// PHOENIX MEDULLA WRAPPER — Sleep Phase Detection
//
// Shell wrapper for phoenix_medulla.t27 TRI-27 module.
// Loads and executes the assembly program for detecting
// sleep phase based on arousal and activity levels.
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

const emu = @import("emu");
const CPUState = emu.cpu_state.CPUState;
const executor = emu.executor;
const decoder = emu.decoder;
const asm_parser = emu.asm_parser;

/// Sleep phase classification
pub const SleepPhase = enum(u2) {
    awake = 0,
    light_sleep = 1,
    deep_sleep = 2,
    rem = 3,
};

/// Phoenix Medulla program wrapper
pub const PhoenixMedulla = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) PhoenixMedulla {
        return .{ .allocator = allocator };
    }

    /// Load phoenix_medulla.t27 from source file
    pub fn loadFromFile(self: *const PhoenixMedulla, path: []const u8) ![]u8 {
        const source = try std.fs.cwd().readFileAlloc(self.allocator, path, 10240);
        defer self.allocator.free(source);
        return self.assembleSource(source);
    }

    /// Assemble TRI-27 source code to bytecode
    fn assembleSource(self: *const PhoenixMedulla, source: []const u8) ![]u8 {
        return asm_parser.assemble(self.allocator, source);
    }

    /// Execute phoenix_medulla program with given arousal and activity
    /// Returns detected sleep phase
    pub fn execute(self: *const PhoenixMedulla, bytecode: []const u8, arousal: f64, activity: f64) !SleepPhase {
        var cpu = try CPUState.init(self.allocator);
        defer cpu.deinit();

        // Allocate memory (4KB, 8-byte aligned)
        var memory_stack: [4096]u8 align(8) = undefined;
        @memset(&memory_stack, 0);
        var memory = memory_stack[0..];

        // Write arousal (Q16) at MEM_AROUSAL (offset 0)
        const arousal_q16 = @as(u16, @intFromFloat(@max(0, @min(1.0, arousal)) * 65536.0));
        memory[0] = @as(u8, @truncate(arousal_q16));
        memory[1] = @as(u8, @truncate(arousal_q16 >> 8));

        // Write activity (Q16) at MEM_ACTIVITY (offset 4)
        const activity_q16 = @as(u16, @intFromFloat(@max(0, @min(1.0, activity)) * 65536.0));
        memory[4] = @as(u8, @truncate(activity_q16));
        memory[5] = @as(u8, @truncate(activity_q16 >> 8));

        // Initialize phase history (all AWAKE = 0)
        const mem_history = 8;
        @memset(memory[mem_history..][0..10], 0);

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

        // Return phase from t0
        const result_raw = cpu.t27[0].trits;
        const phase_val = @as(u2, @truncate(@as(u64, @bitCast(result_raw)) & 0x3));
        return @as(SleepPhase, @enumFromInt(phase_val));
    }

    /// Convenience function: detect sleep phase from arousal and activity
    pub fn detectPhase(self: *const PhoenixMedulla, arousal: f64, activity: f64, source: []const u8) !SleepPhase {
        const bytecode = try self.assembleSource(source);
        defer self.allocator.free(bytecode);

        return try self.execute(bytecode, arousal, activity);
    }

    /// Get sleep phase name
    pub fn phaseName(phase: SleepPhase) []const u8 {
        return switch (phase) {
            .awake => "AWAKE",
            .light_sleep => "LIGHT_SLEEP",
            .deep_sleep => "DEEP_SLEEP",
            .rem => "REM",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "phoenix_medulla_wrapper init" {
    const allocator = std.testing.allocator;
    const wrapper = PhoenixMedulla.init(allocator);
    try std.testing.expectEqual(@as(Allocator, allocator), wrapper.allocator);
}

test "phoenix_medulla_wrapper phase_names" {
    try std.testing.expectEqualStrings("AWAKE", PhoenixMedulla.phaseName(.awake));
    try std.testing.expectEqualStrings("LIGHT_SLEEP", PhoenixMedulla.phaseName(.light_sleep));
    try std.testing.expectEqualStrings("DEEP_SLEEP", PhoenixMedulla.phaseName(.deep_sleep));
    try std.testing.expectEqualStrings("REM", PhoenixMedulla.phaseName(.rem));
}

test "phoenix_medulla_wrapper execute" {
    const allocator = std.testing.allocator;
    var wrapper = PhoenixMedulla.init(allocator);

    // Simple program: return AWAKE (0)
    const source = "LDI t0, 0\nHALT";
    const bytecode = try wrapper.assembleSource(source);
    defer allocator.free(bytecode);

    const phase = try wrapper.execute(bytecode, 0.9, 0.6);
    try std.testing.expectEqual(SleepPhase.awake, phase);
}
