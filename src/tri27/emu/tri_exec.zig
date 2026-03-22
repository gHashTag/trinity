// @origin(spec:tri27_isa.zig) @regen(manual-impl)
// TRI‑27 EXECUTOR — Instruction Execution Engine
//
// Executes decoded opcodes on TRI-27 CPU state.
// Reuses Trinity modules: sparse_ternary (DOT), f16_utils (FADD/FMUL), sacred_alu
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Trit27 = @import("tri_cpu.zig").Trit27;
const Opcode = @import("decoder.zig").Opcode;
const Instruction = @import("decoder.zig").Instruction;

// ═════════════════════════════════════════════════════════════════════════════════════════
// CPU FLAGS — Zero, Negative, Overflow, Halted
// ═════════════════════════════════════════════════════════════════════════════════════════════════════
pub const Flags = packed struct {
    Z: bool = false, // Zero result flag
    N: bool = false, // Negative result flag
    V: bool = false, // Overflow flag
    H: bool = false, // Halted flag
    _: u4 = 0, // Reserved bits
};

// ═══════════════════════════════════════════════════════════════════════════
// CPU STATE — TRI-27 Processor State
// ═══════════════════════════════════════════════════════════════════════════════════════
pub const CPUState = struct {
    // Register file
    t27: [27]Trit27, // 27 ternary registers (27 trits each)
    f: [8]u16, // 8 GF16 registers for floating-point
    v: [16][16]u16, // 16 vector registers (16×GF16)

    // Special purpose registers
    ip: u32 = 0, // Instruction pointer
    sp: u32 = 0, // Stack pointer
    fp: u32 = 0, // Frame pointer

    // Status flags
    flags: Flags = .{},

    // Allocator for dynamic operations (if needed)
    allocator: std.mem.Allocator,

    // Metrics
    instructions_executed: u64 = 0,
    cycles: u64 = 0,

    /// Create initial CPU state with all registers zeroed
    pub fn init(allocator: std.mem.Allocator) CPUState {
        var state = CPUState{
            .t27 = undefined,
            .f = undefined,
            .v = undefined,
            .allocator = allocator,
        };

        // Zero initialize arrays
        for (0..27) |i| {
            state.t27[i] = Trit27{ .trits = 0 };
        }
        for (0..8) |i| {
            state.f[i] = 0;
        }
        for (0..16) |i| {
            for (0..16) |j| {
                state.v[i][j] = 0;
            }
        }

        return state;
    }

    /// Get ternary register value
    pub fn getT27(self: *CPUState, reg: u5) Trit27 {
        std.debug.assert(reg < 27, "Invalid ternary register index");
        return self.t27[reg];
    }

    /// Set ternary register value
    pub fn setT27(self: *CPUState, reg: u5, value: Trit27) void {
        std.debug.assert(reg < 27, "Invalid ternary register index");
        self.t27[reg] = value;
    }

    /// Get GF16 register value
    pub fn getF16(self: *CPUState, reg: u4) u16 {
        std.debug.assert(reg < 8, "Invalid GF16 register index");
        return self.f[reg];
    }

    /// Set GF16 register value
    pub fn setF16(self: *CPUState, reg: u4, value: u16) void {
        std.debug.assert(reg < 8, "Invalid GF16 register index");
        self.f[reg] = value;
    }

    /// Get vector register value
    pub fn getVec(self: *CPUState, reg: u4) []const u16 {
        std.debug.assert(reg < 16, "Invalid vector register index");
        return &self.v[reg];
    }

    /// Set vector register value
    pub fn setVec(self: *CPUState, reg: u4, value: []const u16) void {
        std.debug.assert(reg < 16, "Invalid vector register index");
        std.debug.assert(value.len == 16, "Vector must be 16 GF16 elements");
        @memcpy(&self.v[reg][0], value.ptr);
    }

    /// Update flags based on Trit27 result
    pub fn updateFlagsT27(self: *CPUState, result: Trit27) void {
        const is_zero = result.trits == 0;
        const is_neg = (result.trits >> 53) & 1 == 1;
        self.flags.Z = is_zero;
        self.flags.N = is_neg;
    }

    /// Update flags based on comparison result
    pub fn updateFlagsCmp(self: *CPUState, lt: bool, eq: bool) void {
        self.flags.Z = eq;
        self.flags.N = lt; // Less than implies negative in signed comparison
    }

    /// Update overflow flag
    pub fn setOverflow(self: *CPUState, value: bool) void {
        self.flags.V = value;
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// EXECUTION CONTEXT — Holds execution context and error info
// ═══════════════════════════════════════════════════════════════════════════════════════
pub const ExecError = error{
    InvalidRegister,
    InvalidMemory,
    DivisionByZero,
    StackOverflow,
    StackUnderflow,
    InvalidOpcode,
    Halted,
};

// ═══════════════════════════════════════════════════════════════════════════
// EXECUTE — Execute a single instruction
// ═══════════════════════════════════════════════════════════════════════════════════════
pub fn execute(cpu: *CPUState, inst: Instruction, memory: []u8) ExecError!void {
    // Increment IP before execution (unless this is a control flow instruction)
    cpu.instructions_executed += 1;

    switch (inst.opcode) {
        // ═══════════════════════════════════════════════════════════════════════════
        // NO-OPERATION INSTRUCTIONS
        // ═══════════════════════════════════════════════════════════════════════════════════════
        .NOP => {
            // Do nothing, just advance IP
            cpu.ip += 1;
        },

        // ═══════════════════════════════════════════════════════════════════════════
        // LOAD/STORE INSTRUCTIONS
        // ═══════════════════════════════════════════════════════════════════════════════════════
        .LD_IMM => {
            const value = inst.immediate;
            // Pack immediate into Trit27 (sign-extended)
            const clamped = std.math.clamp(value, @as(i32, -1), @as(i32, 1));
            const trit_value = Trit27.fromI8(@as(i8, clamped));
            cpu.setT27(inst.dst, trit_value);
            cpu.updateFlagsT27(trit_value);
            cpu.ip += 1;
        },

        .ST => {
            // Store ternary register to memory
            // Format: [op:5][dst:4][addr:4][unused:19]
            const addr = inst.immediate; // Address in immediate field
            const value = cpu.getT27(inst.dst);

            // Memory word is 32 bits (fits 2 Trit27s)
            // For simplicity, store trits as packed i64
            const word_index = addr * 4;
            if (word_index + @sizeOf(i64) > memory.len) {
                return ExecError.InvalidMemory;
            }

            @memcpy(memory[word_index..][0..@sizeOf(i64)], std.mem.asBytes(&value.trits));
            cpu.ip += 1;
        },

        // ═══════════════════════════════════════════════════════════════════════════
        // ARITHMETIC INSTRUCTIONS — Ternary
        // ═══════════════════════════════════════════════════════════════════════════════════════
        .ADD3 => {
            const a = cpu.getT27(inst.src1);
            const b = cpu.getT27(inst.src2);

            const result = Trit27.add(a, b);
            cpu.setT27(inst.dst, result.result);
            cpu.updateFlagsT27(result.result);
            cpu.setOverflow(result.overflow);
            cpu.ip += 1;
        },

        .SUB3 => {
            const a = cpu.getT27(inst.src1);
            const b = cpu.getT27(inst.src2);

            const result = Trit27.sub(a, b);
            cpu.setT27(inst.dst, result);
            cpu.updateFlagsT27(result);
            cpu.ip += 1;
        },

        // ═══════════════════════════════════════════════════════════════════════════
        // COMPARISON INSTRUCTION
        // ═══════════════════════════════════════════════════════════════════════════════════════
        .CMP3 => {
            const a = cpu.getT27(inst.src1);
            const b = cpu.getT27(inst.src2);

            const result = Trit27.cmp(a, b);
            cpu.updateFlagsCmp(result.lt, result.eq);
            cpu.ip += 1;
        },

        // ═══════════════════════════════════════════════════════════════════════════
        // CONTROL FLOW INSTRUCTIONS
        // ═══════════════════════════════════════════════════════════════════════════════════════
        .JMP => {
            // Unconditional jump to immediate address
            const target = @as(u32, @abs(inst.immediate));
            cpu.ip = target;
        },

        .CALL => {
            // Push return address to stack, then jump
            const target = @as(u32, @abs(inst.immediate));

            if (cpu.sp + 4 > memory.len) {
                return ExecError.StackOverflow;
            }

            // Push old IP to stack
            const sp_ptr = memory[cpu.sp..];
            @memcpy(sp_ptr[0..4], std.mem.asBytes(&cpu.ip));
            cpu.sp += 4;

            cpu.ip = target;
        },

        .RET => {
            // Pop return address from stack
            if (cpu.sp < 4) {
                return ExecError.StackUnderflow;
            }

            cpu.sp -= 4;
            const sp_ptr = memory[cpu.sp..];
            @memcpy(&cpu.ip[0..4], std.mem.asBytes(sp_ptr));
        },

        // ═══════════════════════════════════════════════════════════════════════════
        // SYSTEM INSTRUCTIONS
        // ═══════════════════════════════════════════════════════════════════════════════════════
        .HALT => {
            cpu.flags.H = true;
            // Don't advance IP
        },

        .SYSCALL => {
            // System call - handled by emulator layer
            // syscall number in src1, arguments in other fields
            const syscall_num = inst.src1;
            _ = syscall_num; // Placeholder - actual handling in emulator layer

            // For now, just advance IP
            // Real implementation will delegate to syscall handler
            cpu.ip += 1;
        },
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// CYCLE ESTIMATE — Estimate cycles for an instruction
// ═══════════════════════════════════════════════════════════════════════════════════════
pub fn estimateCycles(opcode: Opcode) u64 {
    return switch (opcode) {
        .NOP => 1,
        .LD_IMM => 1,
        .ST => 2, // Memory write
        .ADD3 => 2, // Ternary addition
        .SUB3 => 2, // Ternary subtraction
        .CMP3 => 2, // Comparison
        .JMP => 1,
        .CALL => 3, // Stack push + jump
        .RET => 3, // Stack pop + jump
        .HALT => 1,
        .SYSCALL => 10, // System call (variable)
    };
}

// ═══════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════════════
test "CPUState init zeros all registers" {
    const allocator = std.testing.allocator;
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();

    try std.testing.expectEqual(@as(u32, 0), cpu.ip);
    try std.testing.expectEqual(@as(u32, 0), cpu.sp);
    try std.testing.expectEqual(@as(u32, 0), cpu.fp);
    try std.testing.expectEqual(@as(u64, 0), cpu.instructions_executed);

    // All ternary registers should be zero
    for (0..16) |i| {
        try std.testing.expectEqual(@as(i64, 0), cpu.t27[i].trits);
    }
}

test "CPUState get/set ternary registers" {
    const allocator = std.testing.allocator;
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();

    const value = Trit27.fromI8(1);
    cpu.setT27(5, value);
    const retrieved = cpu.getT27(5);

    try std.testing.expectEqual(value.trits, retrieved.trits);
}

test "CPUState get/set GF16 registers" {
    const allocator = std.testing.allocator;
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();

    cpu.setF16(3, 0xABCD);
    const retrieved = cpu.getF16(3);

    try std.testing.expectEqual(@as(u16, 0xABCD), retrieved);
}

test "CPUState get/set vector registers" {
    const allocator = std.testing.allocator;
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();

    const vec = [_]u16{0} * 16;
    vec[5] = 0x1234;
    cpu.setVec(7, &vec);
    const retrieved = cpu.getVec(7);

    try std.testing.expectEqual(@as(u16, 0x1234), retrieved[5]);
}

test "CPUState updateFlagsT27" {
    const allocator = std.testing.allocator;
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();

    // Zero value
    cpu.updateFlagsT27(Trit27.ZERO);
    try std.testing.expect(cpu.flags.Z);
    try std.testing.expect(!cpu.flags.N);

    // Positive value
    const pos = Trit27.fromI8(1);
    cpu.updateFlagsT27(pos);
    try std.testing.expect(!cpu.flags.Z);
    try std.testing.expect(!cpu.flags.N);

    // Negative value
    const neg = Trit27.fromI8(-1);
    cpu.updateFlagsT27(neg);
    try std.testing.expect(!cpu.flags.Z);
    try std.testing.expect(cpu.flags.N);
}

test "execute NOP" {
    const allocator = std.testing.allocator;
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();

    var memory = [_]u8{0} ** 1024;
    const inst = Instruction{
        .opcode = .NOP,
        .dst = 0,
        .src1 = 0,
        .src2 = 0,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, &memory);

    try std.testing.expectEqual(@as(u32, 1), cpu.ip);
    try std.testing.expectEqual(@as(u64, 1), cpu.instructions_executed);
}

test "execute LD_IMM" {
    const allocator = std.testing.allocator;
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();

    var memory = [_]u8{0} ** 1024;
    const inst = Instruction{
        .opcode = .LD_IMM,
        .dst = 3,
        .src1 = 0,
        .src2 = 0,
        .immediate = 1,
        .has_imm = true,
    };

    try execute(&cpu, inst, &memory);

    const result = cpu.getT27(3);
    try std.testing.expectEqual(@as(i8, 1), result.toI8Clamped());
    try std.testing.expectEqual(@as(u32, 1), cpu.ip);
}

test "execute HALT" {
    const allocator = std.testing.allocator;
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();

    var memory = [_]u8{0} ** 1024;
    const inst = Instruction{
        .opcode = .HALT,
        .dst = 0,
        .src1 = 0,
        .src2 = 0,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, &memory);

    try std.testing.expect(cpu.flags.H);
    try std.testing.expectEqual(@as(u32, 0), cpu.ip); // IP not advanced
}

test "execute ADD3" {
    const allocator = std.testing.allocator;
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();

    var memory = [_]u8{0} ** 1024;

    // Set up registers: t0 = 1, t1 = 0
    cpu.setT27(0, Trit27.fromI8(1));
    cpu.setT27(1, Trit27.ZERO);

    const inst = Instruction{
        .opcode = .ADD3,
        .dst = 2,
        .src1 = 0,
        .src2 = 1,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, &memory);

    const result = cpu.getT27(2);
    try std.testing.expectEqual(@as(i8, 1), result.toI8Clamped()); // 1 + 0 = 1
    try std.testing.expectEqual(@as(u32, 1), cpu.ip);
}

test "execute SUB3" {
    const allocator = std.testing.allocator;
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();

    var memory = [_]u8{0} ** 1024;

    // Set up registers: t0 = 1, t1 = 1
    cpu.setT27(0, Trit27.fromI8(1));
    cpu.setT27(1, Trit27.fromI8(1));

    const inst = Instruction{
        .opcode = .SUB3,
        .dst = 2,
        .src1 = 0,
        .src2 = 1,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, &memory);

    const result = cpu.getT27(2);
    try std.testing.expectEqual(@as(i8, 0), result.toI8Clamped()); // 1 - 1 = 0
}

test "execute CMP3" {
    const allocator = std.testing.allocator;
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();

    var memory = [_]u8{0} ** 1024;

    // Set up registers: t0 = 1, t1 = 0
    cpu.setT27(0, Trit27.fromI8(1));
    cpu.setT27(1, Trit27.ZERO);

    const inst = Instruction{
        .opcode = .CMP3,
        .dst = 0,
        .src1 = 0,
        .src2 = 1,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, &memory);

    try std.testing.expect(cpu.flags.N); // 1 > 0, so not less than
    try std.testing.expect(!cpu.flags.Z); // Not equal
}

test "estimateCycles" {
    try std.testing.expectEqual(@as(u64, 1), estimateCycles(.NOP));
    try std.testing.expectEqual(@as(u64, 1), estimateCycles(.LD_IMM));
    try std.testing.expectEqual(@as(u64, 2), estimateCycles(.ADD3));
    try std.testing.expectEqual(@as(u64, 3), estimateCycles(.CALL));
    try std.testing.expectEqual(@as(u64, 10), estimateCycles(.SYSCALL));
}
