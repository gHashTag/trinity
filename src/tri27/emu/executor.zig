// @origin(spec:tri27_isa.zig) @regen(manual-impl)
// TRI‑27 EXECUTOR — Instruction Execution Engine
//
// Executes decoded opcodes on TRI-27 CPU state.
// Reuses Trinity modules: sparse_ternary (DOT), f16_utils (FADD/FMUL), sacred_alu
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

const CPUState = @import("cpu_state.zig").CPUState;
const Instruction = @import("decoder.zig").Instruction;
const Opcode = @import("decoder.zig").Opcode;
const Trit27 = @import("tri_cpu.zig").Trit27;

// ═══════════════════════════════════════════════════════════════════════
// EXECUTION ERROR TYPE
// ═════════════════════════════════════════════════════════════════════
pub const ExecError = error{
    InvalidRegister,
    InvalidMemory,
    DivisionByZero,
    StackOverflow,
    StackUnderflow,
    InvalidOpcode,
    Halted,
};

// ═════════════════════════════════════════════════════════════════
// EXECUTE — Execute a single instruction
// ═══════════════════════════════════════════════════════════════════════
pub fn execute(cpu: *CPUState, inst: Instruction, memory: []align(8) u8) ExecError!void {
    // Increment IP before execution (unless this is a control flow instruction)
    cpu.instructions_executed += 1;

    switch (inst.opcode) {
        // ═══════════════════════════════════════════════════════════════════
        // NO-OPERATION INSTRUCTIONS
        // ═══════════════════════════════════════════════════════════════════════════════
        .NOP => {
            // Do nothing, just advance IP
            cpu.pc += 1;
        },

        // ═════════════════════════════════════════════════════════════════
        // LOAD/STORE INSTRUCTIONS
        // ═══════════════════════════════════════════════════════════════════════════════
        .LDI => {
            // LDI dst, imm - Load full i16 immediate value into register
            const value = inst.immediate;
            const trit_value = Trit27{ .trits = value };
            cpu.t27[inst.dst] = trit_value;
            // Update flags based on result
            cpu.flags.Z = value == 0;
            cpu.flags.N = value < 0;
            cpu.pc += 1;
        },

        .LD_IMM => {
            const value = inst.immediate;
            // Pack immediate into Trit27 (sign-extended)
            const clamped = std.math.clamp(value, @as(i16, -1), @as(i16, 1));
            const trit_value = Trit27.fromI8(@intCast(clamped));
            cpu.t27[inst.dst] = trit_value;
            // Update flags based on ternary result
            cpu.flags.Z = trit_value.trits == 0;
            cpu.flags.N = trit_value.trits < 0;
            cpu.pc += 1;
        },

        .ST => {
            // Store ternary register to memory
            const addr = @as(usize, @abs(inst.immediate));
            const value = cpu.t27[inst.dst];

            // Memory word is 32 bits (fits 2 Trit27s)
            const word_index = addr * 4;
            if (word_index + @sizeOf(u64) > memory.len) {
                return ExecError.InvalidMemory;
            }

            // Pack Trit27 into 64-bit word for storage
            const packed_word: u64 = @bitCast(value.trits);
            // Manual word write (little-endian)
            const base = word_index;
            memory[base] = @as(u8, @truncate(packed_word));
            memory[base + 1] = @as(u8, @truncate(packed_word >> 8));
            memory[base + 2] = @as(u8, @truncate(packed_word >> 16));
            memory[base + 3] = @as(u8, @truncate(packed_word >> 24));

            cpu.pc += 1;
        },

        .LD => {
            // Load from memory to register
            const addr = @as(usize, @abs(inst.immediate));
            const byte_addr = addr * 4;

            if (byte_addr + 4 > memory.len) {
                return ExecError.InvalidMemory;
            }

            // Read 4 bytes as little-endian word
            const word: u32 = memory[byte_addr] |
                @as(u32, memory[byte_addr + 1]) << 8 |
                @as(u32, memory[byte_addr + 2]) << 16 |
                @as(u32, memory[byte_addr + 3]) << 24;

            // Convert word to Trit27 (sign-extend 32-bit to 64-bit)
            const signed_word: i32 = @bitCast(word);
            const trit_value = Trit27{ .trits = @as(i64, signed_word) };
            cpu.t27[inst.dst] = trit_value;

            // Update flags
            cpu.flags.Z = trit_value.trits == 0;
            cpu.flags.N = trit_value.trits < 0;
            cpu.pc += 1;
        },

        // ═════════════════════════════════════════════════════════
        // MOVE INSTRUCTION
        // ═══════════════════════════════════════════════════════════════════════
        .MOV => {
            // Move: dst = src1 (copy register value)
            const value = cpu.t27[inst.src1];
            cpu.t27[inst.dst] = value;
            // Update flags
            cpu.flags.Z = value.trits == 0;
            cpu.flags.N = value.trits < 0;
            cpu.pc += 1;
        },

        // ARITHMETIC INSTRUCTIONS — Ternary
        // ═══════════════════════════════════════════════════════════════════════
        .ADD => {
            const a = cpu.t27[inst.src1];
            const b = cpu.t27[inst.src2];

            // Regular integer addition
            const sum = a.trits + b.trits;
            const trit_value = Trit27{ .trits = sum };

            cpu.t27[inst.dst] = trit_value;
            // Update flags
            cpu.flags.Z = sum == 0;
            cpu.flags.N = sum < 0;
            cpu.pc += 1;
        },

        .SUB => {
            const a = cpu.t27[inst.src1];
            const b = cpu.t27[inst.src2];

            // Regular integer subtraction
            const result = a.trits - b.trits;
            const trit_value = Trit27{ .trits = result };

            cpu.t27[inst.dst] = trit_value;
            // Update flags
            cpu.flags.Z = result == 0;
            cpu.flags.N = result < 0;
            cpu.pc += 1;
        },

        .DIV => {
            const a = cpu.t27[inst.src1];
            const b = cpu.t27[inst.src2];

            // Ternary division
            if (b.trits == 0) return ExecError.DivisionByZero;

            const result = @divTrunc(a.trits, b.trits);
            const trit_value = Trit27{ .trits = result };

            cpu.t27[inst.dst] = trit_value;
            // Update flags
            cpu.flags.Z = result == 0;
            cpu.flags.N = result < 0;
            cpu.pc += 1;
        },

        .INC => {
            const dst_value = cpu.t27[inst.dst];

            // Regular integer increment
            const result = dst_value.trits + 1;
            const trit_value = Trit27{ .trits = result };

            cpu.t27[inst.dst] = trit_value;
            // Update flags
            cpu.flags.Z = result == 0;
            cpu.flags.N = result < 0;
            cpu.pc += 1;
        },

        .DEC => {
            const dst_value = cpu.t27[inst.dst];

            // Regular integer decrement
            const result = dst_value.trits - 1;
            const trit_value = Trit27{ .trits = result };

            cpu.t27[inst.dst] = trit_value;
            // Update flags
            cpu.flags.Z = result == 0;
            cpu.flags.N = result < 0;
            cpu.pc += 1;
        },

        // ═══════════════════════════════════════════════════════
        // LOGIC INSTRUCTIONS — Bitwise on Trit27 trit values
        // ═════════════════════════════════════════════════════════════
        .AND => {
            const a = cpu.t27[inst.src1];
            const b = cpu.t27[inst.src2];

            // Ternary bitwise AND (min of two values)
            const result = if (a.trits < 0 and b.trits < 0) a.trits else if (a.trits > 0 and b.trits > 0) a.trits else 0;
            const trit_value = Trit27{ .trits = result };

            cpu.t27[inst.dst] = trit_value;
            cpu.flags.Z = result == 0;
            cpu.flags.N = result < 0;
            cpu.pc += 1;
        },

        .OR => {
            const a = cpu.t27[inst.src1];
            const b = cpu.t27[inst.src2];

            // Ternary bitwise OR (max of two values)
            const result = if (a.trits > 0 or b.trits > 0) a.trits else if (a.trits < 0 and b.trits < 0) b.trits else a.trits;
            const trit_value = Trit27{ .trits = result };

            cpu.t27[inst.dst] = trit_value;
            cpu.flags.Z = result == 0;
            cpu.flags.N = result < 0;
            cpu.pc += 1;
        },

        .XOR => {
            const a = cpu.t27[inst.src1];
            const b = cpu.t27[inst.src2];

            // Ternary bitwise XOR
            const result = if (a.trits != 0 and b.trits != 0) a.trits else if (a.trits == 0 or b.trits == 0) b.trits else if (a.trits < 0 and b.trits < 0) a.trits else b.trits;
            const trit_value = Trit27{ .trits = result };

            cpu.t27[inst.dst] = trit_value;
            cpu.flags.Z = result == 0;
            cpu.flags.N = result < 0;
            cpu.pc += 1;
        },

        .NOT => {
            const a = cpu.t27[inst.src1];

            // Ternary bitwise NOT (negate)
            const result = -a.trits;
            const trit_value = Trit27{ .trits = result };

            cpu.t27[inst.dst] = trit_value;
            cpu.flags.Z = result == 0;
            cpu.flags.N = result < 0;
            cpu.pc += 1;
        },

        .SHL => {
            const a = cpu.t27[inst.src1];

            // Shift left by immediate amount (regular integer shift)
            const shift = @abs(inst.immediate);
            const result = a.trits << @intCast(shift);
            const trit_value = Trit27{ .trits = result };

            cpu.t27[inst.dst] = trit_value;
            cpu.flags.Z = result == 0;
            cpu.flags.N = result < 0;
            cpu.pc += 1;
        },

        .SHR => {
            const a = cpu.t27[inst.src1];

            // Shift right by immediate amount (regular integer shift)
            const shift = @abs(inst.immediate);
            const result = a.trits >> @intCast(shift);
            const trit_value = Trit27{ .trits = result };

            cpu.t27[inst.dst] = trit_value;
            cpu.flags.Z = result == 0;
            cpu.flags.N = result < 0;
            cpu.pc += 1;
        },

        .MUL => {
            const a = cpu.t27[inst.src1];
            const b = cpu.t27[inst.src2];

            // Regular integer multiplication
            const result = a.trits * b.trits;
            const trit_value = Trit27{ .trits = result };

            cpu.t27[inst.dst] = trit_value;
            // Update flags
            cpu.flags.Z = result == 0;
            cpu.flags.N = result < 0;
            cpu.pc += 1;
        },

        // ═══════════════════════════════════════════════════════════════
        // TERNARY INSTRUCTIONS — VSA-style operations on ternary values
        // ═══════════════════════════════════════════════════════════════════════════════
        .DOT => {
            const a = cpu.t27[inst.src1];
            const b = cpu.t27[inst.src2];
            const result = @mod(a.trits * b.trits, 19683);
            const trit_value = Trit27{ .trits = result };
            cpu.t27[inst.dst] = trit_value;
            cpu.flags.Z = result == 0;
            cpu.flags.N = result < 0;
            cpu.pc += 1;
        },

        .BIND => {
            const a = cpu.t27[inst.src1];
            const b = cpu.t27[inst.src2];
            const result = if (a.trits == 0) b.trits else if (b.trits == 0) a.trits else @mod(a.trits + b.trits, 19683);
            const trit_value = Trit27{ .trits = result };
            cpu.t27[inst.dst] = trit_value;
            cpu.flags.Z = result == 0;
            cpu.flags.N = result < 0;
            cpu.pc += 1;
        },

        .BUNDLE2 => {
            const a = cpu.t27[inst.src1];
            const b = cpu.t27[inst.src2];
            const result = if (a.trits == 0) b.trits else if (b.trits == 0) a.trits else @divTrunc(a.trits + b.trits, 2);
            const trit_value = Trit27{ .trits = result };
            cpu.t27[inst.dst] = trit_value;
            cpu.flags.Z = result == 0;
            cpu.flags.N = result < 0;
            cpu.pc += 1;
        },

        .BUNDLE3 => {
            const a = cpu.t27[inst.src1];
            const b = cpu.t27[inst.src2];
            const c = cpu.t27[inst.cond]; // v3 from cond field
            const result = blk: {
                if (a.trits == b.trits) break :blk a.trits;
                if (a.trits == c.trits) break :blk a.trits;
                if (b.trits == c.trits) break :blk b.trits;
                break :blk a.trits;
            };
            const trit_value = Trit27{ .trits = result };
            cpu.t27[inst.dst] = trit_value;
            cpu.flags.Z = result == 0;
            cpu.flags.N = result < 0;
            cpu.pc += 1;
        },

        // ═══════════════════════════════════════════════════════════════
        // SACRED INSTRUCTIONS — Load sacred constants and operations
        // ═══════════════════════════════════════════════════════════════════════════════
        .PHI_CONST => {
            const phi_trits: i64 = 9842; // phi * 6075 ≈ 9842
            const trit_value = Trit27{ .trits = phi_trits };
            cpu.t27[inst.dst] = trit_value;
            cpu.flags.Z = false;
            cpu.flags.N = false;
            cpu.pc += 1;
        },

        .PI_CONST => {
            const pi_trits: i64 = 19088; // pi * 6075 ≈ 19088
            const trit_value = Trit27{ .trits = pi_trits };
            cpu.t27[inst.dst] = trit_value;
            cpu.flags.Z = false;
            cpu.flags.N = false;
            cpu.pc += 1;
        },

        .E_CONST => {
            const e_trits: i64 = 16514; // e * 6075 ≈ 16514
            const trit_value = Trit27{ .trits = e_trits };
            cpu.t27[inst.dst] = trit_value;
            cpu.flags.Z = false;
            cpu.flags.N = false;
            cpu.pc += 1;
        },

        .SACR => {
            const a = cpu.t27[inst.src1];
            const b = cpu.t27[inst.dst]; // dst is also operand
            const sacrop = inst.immediate;
            const result = switch (sacrop) {
                1 => @mod(a.trits + b.trits, 19683), // SACR ADD
                2 => @mod(a.trits * b.trits, 19683), // SACR MUL
                3 => if (b.trits == 0) return ExecError.DivisionByZero else @divTrunc(a.trits, b.trits), // SACR DIV
                4 => @mod(std.math.pow(i64, @as(i64, a.trits), @as(i64, b.trits)), 19683), // SACR POW
                else => @mod(a.trits + b.trits, 19683),
            };
            const trit_value = Trit27{ .trits = result };
            cpu.t27[inst.dst] = trit_value;
            cpu.flags.Z = result == 0;
            cpu.flags.N = result < 0;
            cpu.pc += 1;
        },

        // ═══════════════════════════════════════════════════════════════
        // CONTROL FLOW INSTRUCTIONS
        // ═══════════════════════════════════════════════════════════════════════════════
        // CONTROL FLOW INSTRUCTIONS
        // ═══════════════════════════════════════════════════════════════════
        .JMP => {
            // Unconditional jump to immediate address
            const target = @as(u32, @abs(inst.immediate));
            cpu.pc = target;
        },

        .JZ => {
            // Jump if dst register is zero (JZ dst, offset)
            const reg = cpu.t27[inst.dst];
            const target = @as(u32, @abs(inst.immediate));
            if (reg.trits == 0) {
                cpu.pc = target;
            } else {
                cpu.pc += 1;
            }
        },

        .JNZ => {
            // Jump if dst register is not zero (JNZ dst, offset)
            const reg = cpu.t27[inst.dst];
            const target = @as(u32, @abs(inst.immediate));
            if (reg.trits != 0) {
                cpu.pc = target;
            } else {
                cpu.pc += 1;
            }
        },

        .JGT => {
            // Jump if Greater Than (dst > src1)
            const a = cpu.t27[inst.dst];
            const b = cpu.t27[inst.src1];
            const target = @as(u32, @abs(inst.immediate));
            if (a.trits > b.trits) {
                cpu.pc = target;
            } else {
                cpu.pc += 1;
            }
        },

        .JLT => {
            // Jump if Less Than (dst < src1)
            const a = cpu.t27[inst.dst];
            const b = cpu.t27[inst.src1];
            const target = @as(u32, @abs(inst.immediate));
            if (a.trits < b.trits) {
                cpu.pc = target;
            } else {
                cpu.pc += 1;
            }
        },

        .CALL => {
            // Push return address to stack, then jump
            const target = @as(u32, @abs(inst.immediate));

            if (cpu.sp + 4 > cpu.memory_len) {
                return ExecError.StackOverflow;
            }

            // Push old IP to stack (word-aligned)
            const ip_bytes = std.mem.asBytes(&cpu.pc);
            memory[cpu.sp] = ip_bytes[0];
            memory[cpu.sp + 1] = ip_bytes[1];
            memory[cpu.sp + 2] = ip_bytes[2];
            memory[cpu.sp + 3] = ip_bytes[3];
            cpu.sp += 4;

            cpu.pc = target;
        },

        .RET => {
            // Pop return address from stack
            if (cpu.sp < 4) {
                return ExecError.StackUnderflow;
            }

            cpu.sp -= 4;

            const ip_bytes = [4]u8{
                memory[cpu.sp],
                memory[cpu.sp + 1],
                memory[cpu.sp + 2],
                memory[cpu.sp + 3],
            };
            cpu.pc = std.mem.readInt(u32, &ip_bytes, .little);
        },

        // ═════════════════════════════════════════════════════════════
        // SYSTEM INSTRUCTIONS
        // ═══════════════════════════════════════════════════════════════════
        .HALT => {
            cpu.flags.H = true;
            // Don't advance IP
        },

        .SYSCALL => {
            // System call - handled by emulator layer
            // For now, just advance IP
            // Real implementation will delegate to syscall handler
            cpu.pc += 1;
        },

        // ═══════════════════════════════════════════════════════════════════
        // ALIAS OPCODES (executor compatibility)
        // ═════════════════════════════════════════════════════════════════════════════════
        .STI => {
            // Store immediate to memory
            const value = inst.immediate;
            const addr = @as(usize, @abs(value));

            if (addr + 4 > cpu.memory_len) {
                return ExecError.InvalidMemory;
            }

            // Pack as word and store
            const word: u32 = @bitCast(@as(i32, std.math.clamp(value, -1, 1)));
            const word_bytes = std.mem.asBytes(&word);
            memory[addr] = word_bytes[0];
            memory[addr + 1] = word_bytes[1];
            memory[addr + 2] = word_bytes[2];
            memory[addr + 3] = word_bytes[3];

            cpu.pc += 1;
        },

        else => {
            return ExecError.InvalidOpcode;
        },
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// CYCLE ESTIMATE — Estimate cycles for an instruction
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
pub fn estimateCycles(opcode: Opcode) u64 {
    return switch (opcode) {
        .NOP => 1,
        .LD_IMM, .LDI, .LD => 1,
        .ST, .STI => 2, // Memory write
        .ADD, .SUB => 2, // Ternary arithmetic
        .JMP, .JZ, .JNZ, .JGT, .JLT => 1, // Control flow
        .CALL => 3, // Stack push + jump
        .RET => 3, // Stack pop + jump
        .HALT => 1,
        .SYSCALL => 10, // System call (variable)
        else => 1,
    };
}

// ═════════════════════════════════════════════════════════════════════════════════════════════
// RUN — Execute program until HALT or error
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
pub fn run(cpu: *CPUState, memory: []align(8) u8) ExecError!void {
    const decodeInstruction = @import("./decoder.zig").decodeInstruction;

    while (!cpu.flags.H) {
        // Fetch instruction word from memory
        const byte_addr = cpu.pc * 4;
        if (byte_addr + 4 > memory.len) return ExecError.InvalidMemory;

        const inst_word: u32 = memory[byte_addr] |
            @as(u32, memory[byte_addr + 1]) << 8 |
            @as(u32, memory[byte_addr + 2]) << 16 |
            @as(u32, memory[byte_addr + 3]) << 24;

        // Decode and execute
        const inst = decodeInstruction(inst_word);
        // std.debug.print("PC={d}: byte_addr={d}, word=0x{x:0>8}, bytes={x:0>2} {x:0>2} {x:0>2} {x:0>2}, opcode={s}\n", .{ cpu.pc, byte_addr, inst_word, memory[byte_addr], memory[byte_addr + 1], memory[byte_addr + 2], memory[byte_addr + 3], @tagName(inst.opcode) });
        try execute(cpu, inst, memory);
    }
}

// ═════════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════

test "CPUState init zeros all registers" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    try std.testing.expectEqual(@as(u32, 3), cpu.pc); // PC starts at 3 (skip 12-byte header)
    try std.testing.expectEqual(@as(u32, 0), cpu.sp);
    try std.testing.expectEqual(@as(u32, 0), cpu.fp);
    try std.testing.expectEqual(@as(usize, 0), cpu.instructions_executed);
    try std.testing.expectEqual(@as(usize, 0), cpu.cycles);

    // All ternary registers should be zero (Trit27.trits = 0)
    for (0..27) |i| {
        try std.testing.expectEqual(@as(i64, 0), cpu.t27[i].trits);
    }
}

test "execute NOP" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();
    cpu.pc = 0; // Reset PC for test

    const inst = Instruction{
        .opcode = .NOP,
        .dst = 0,
        .src1 = 0,
        .src2 = 0,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    try std.testing.expectEqual(@as(u32, 1), cpu.pc);
    try std.testing.expectEqual(@as(usize, 1), cpu.instructions_executed);
}

test "execute LD_IMM" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();
    cpu.pc = 0; // Reset PC for test

    const inst = Instruction{
        .opcode = .LD_IMM,
        .dst = 3,
        .immediate = 1,
        .has_imm = true,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    const result = cpu.t27[3];
    try std.testing.expectEqual(@as(i8, 1), result.toI8Clamped());
    try std.testing.expectEqual(@as(u32, 1), cpu.pc);
}

test "execute ADD" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();
    cpu.pc = 0; // Reset PC for test

    // Set up registers: t0 = 1, t1 = 0
    cpu.t27[0] = Trit27.fromI8(1);
    cpu.t27[1] = Trit27{ .trits = 0 };

    const inst = Instruction{
        .opcode = .ADD,
        .dst = 2,
        .src1 = 0,
        .src2 = 1,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    const result = cpu.t27[2];
    try std.testing.expectEqual(@as(i8, 1), result.toI8Clamped()); // 1 + 0 = 1
    try std.testing.expectEqual(@as(u32, 1), cpu.pc);
}

test "execute SUB" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.pc = 0; // Reset PC for test

    // Set up registers: t0 = 1, t1 = 1
    cpu.t27[0] = Trit27.fromI8(1);
    cpu.t27[1] = Trit27.fromI8(1);

    const inst = Instruction{
        .opcode = .SUB,
        .dst = 2,
        .src1 = 0,
        .src2 = 1,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    const result = cpu.t27[2];
    try std.testing.expectEqual(@as(i8, 0), result.toI8Clamped()); // 1 - 1 = 0
    try std.testing.expectEqual(@as(u32, 1), cpu.pc);
}

test "execute JMP" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();
    cpu.pc = 0; // Reset PC for test

    const inst = Instruction{
        .opcode = .JMP,
        .immediate = 100,
        .has_imm = true,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    try std.testing.expectEqual(@as(u32, 100), cpu.pc);
}

test "execute HALT" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();
    cpu.pc = 0; // Reset PC for test

    const inst = Instruction{
        .opcode = .HALT,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    try std.testing.expect(cpu.flags.H);
    try std.testing.expectEqual(@as(u32, 0), cpu.pc); // IP not advanced
}

test "estimateCycles" {
    try std.testing.expectEqual(@as(u64, 1), estimateCycles(.NOP));
    try std.testing.expectEqual(@as(u64, 1), estimateCycles(.LD_IMM));
    try std.testing.expectEqual(@as(u64, 2), estimateCycles(.ADD));
    try std.testing.expectEqual(@as(u64, 3), estimateCycles(.CALL));
    try std.testing.expectEqual(@as(u64, 10), estimateCycles(.SYSCALL));
}
