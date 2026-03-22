// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// TRI-27 EXECUTOR — Execute opcodes on CPU state
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════ state.

const std = @import("std");

// Import existing Trinity modules
const vm_core = @import("../../vm/core/vm_core.zig");
const cpu_state = @import("./cpu_state.zig");
const decoder = @import("./decoder.zig");

// Import existing modules for operations
// TODO: Integrate with actual modules when available
// For now, use inline placeholders for sacred/VSA operations

/// Sacred constants
const PHI: f64 = 1.618033988749895;
const PI: f64 = 3.14159265358979323846;
const E: f64 = 2.71828182845904523536;

/// Helper: Get register value (or 0 if invalid)
fn getTritValue(cpu: *cpu_state.CPUState, reg_idx: u8) i8 {
    if (reg_idx < 27) {
        const trit_val: i8 = @intFromFloat(cpu.trits[reg_idx]);
        return trit_val;
    }
    return 0; // Invalid register
}

/// Helper: Get float register value
fn getFloatValue(cpu: *cpu_state.CPUState, reg_idx: u8) f64 {
    if (reg_idx < 3) {
        return cpu.floats[reg_idx];
    }
    return 0.0;
}

/// Helper: Check if register index is valid
fn isValidReg(reg_idx: u8) bool {
    return reg_idx < 27;
}

/// Helper: Convert trit to i64 for arithmetic
fn tritToI64(trit: i8) i64 {
    return if (trit < 0) -1 else if (trit > 0) 1 else 0;
}

/// Execute a single instruction on CPU
/// Returns error set, true on success
pub fn executeInstruction(cpu: *cpu_state.CPUState, code: []const u8, ip: *u32) !bool {
    _ = cpu;
    _ = ip.*;

    const opcode = code[ip.*];
    ip.* += 1;

    // Dispatch based on opcode
    switch (opcode) {
        // === ARITHMETIC ===
        decoder.OPCODE_ADD => {
            const regs = decoder.decodeRegPair(&code, ip.*);
            const a = getTritValue(cpu, regs.rd);
            const b = getTritValue(cpu, regs.rs1);
            const result = tritToI64(a) + b;

            // Store result in destination register
            cpu.trits[regs.rd] = @floatFromInt(result);

            ip.* += 1;
            return true;
        },

        decoder.OPCODE_SUB => {
            const regs = decoder.decodeRegPair(&code, ip.*);
            const a = getTritValue(cpu, regs.rd);
            const b = getTritValue(cpu, regs.rs1);
            const result = tritToI64(a) - b;

            cpu.trits[regs.rd] = @floatFromInt(result);
            ip.* += 1;
            return true;
        },

        decoder.OPCODE_MUL => {
            const regs = decoder.decodeRegPair(&code, ip.*);
            const a = getTritValue(cpu, regs.rd);
            const b = getTritValue(cpu, regs.rs1);
            const result = tritToI64(a) * b;

            cpu.trits[regs.rd] = @floatFromInt(result);
            ip.* += 1;
            return true;
        },

        decoder.OPCODE_DIV => {
            const regs = decoder.decodeRegPair(&code, ip.*);
            const a = getTritValue(cpu, regs.rd);
            const b = getTritValue(cpu, regs.rs1);

            // Check for division by zero
            if (b == 0) return error.DivisionByZero;

            const result = tritToI64(a) / b;

            cpu.trits[regs.rd] = @floatFromInt(result);
            ip.* += 1;
            return true;
        },

        decoder.OPCODE_INC => {
            const rd = decoder.decodeReg8(&code, ip.*);
            const val = getTritValue(cpu, rd);
            const result = tritToI64(val) + 1;

            cpu.trits[rd] = @floatFromInt(result);
            ip.* += 1;
            return true;
        },

        decoder.OPCODE_DEC => {
            const rd = decoder.decodeReg8(&code, ip.*);
            const val = getTritValue(cpu, rd);
            const result = tritToI64(val) - 1;

            cpu.trits[rd] = @floatFromInt(result);
            ip.* += 1;
            return true;
        },

        // === LOGIC ===
        decoder.OPCODE_AND => {
            const regs = decoder.decodeRegPair(&code, ip.*);
            const a = getTritValue(cpu, regs.rd);
            const b = getTritValue(cpu, regs.rs1);

            // AND: result = 1 only if both inputs are 1
            const result: i8 = if (a == 1 and b == 1) 1 else 0;

            cpu.trits[regs.rd] = @floatFromInt(result);
            ip.* += 1;
            return true;
        },

        decoder.OPCODE_OR => {
            const regs = decoder.decodeRegPair(&code, ip.*);
            const a = getTritValue(cpu, regs.rd);
            const b = getTritValue(cpu, regs.rs1);

            // OR: result = 1 if either input is 1
            const result: i8 = if (a == 1 or b == 1) 1 else 0;

            cpu.trits[regs.rd] = @floatFromInt(result);
            ip.* += 1;
            return true;
        },

        decoder.OPCODE_XOR => {
            const regs = decoder.decodeRegPair(&code, ip.*);
            const a = getTritValue(cpu, regs.rd);
            const b = getTritValue(cpu, regs.rs1);

            // XOR: result = 1 if inputs differ
            const result: i8 = if (a != b) 1 else 0;

            cpu.trits[regs.rd] = @floatFromInt(result);
            ip.* += 1;
            return true;
        },

        decoder.OPCODE_NOT => {
            const rd = decoder.decodeReg8(&code, ip.*);
            const val = getTritValue(cpu, rd);

            // NOT: result = 1 if input is 0, else 0
            const result: i8 = if (val == 0) 1 else 0;

            cpu.trits[rd] = @floatFromInt(result);
            ip.* += 1;
            return true;
        },

        decoder.OPCODE_SHL => {
            const regs = decoder.decodeRegPair(&code, ip.*);
            const a = getTritValue(cpu, regs.rd);
            const b = getTritValue(cpu, regs.rs1);

            // Shift left by count (1-3 trits)
            const count = getTritValue(cpu, regs.rs2);
            const shift: @as(u32, count);
            const result = @as(i8, @shlExact(i8, a, shift));

            cpu.trits[regs.rd] = @floatFromInt(result);
            ip.* += 1;
            return true;
        },

        decoder.OPCODE_SHR => {
            const regs = decoder.decodeRegPair(&code, ip.*);
            const a = getTritValue(cpu, regs.rd);
            const b = getTritValue(cpu, regs.rs1);

            // Shift right by count
            const count = getTritValue(cpu, regs.rs2);
            const shift = @as(u32, count);
            const result = @as(i8, @shrExact(i8, a, shift));

            cpu.trits[regs.rd] = @floatFromInt(result);
            ip.* += 1;
            return true;
        },

        // === MEMORY ===
        decoder.OPCODE_LD => {
            const rd = decoder.decodeReg8(&code, ip.*);
            const addr = decodeAddr16(&code, ip.*);

            // Load byte from memory to register
            if (addr >= cpu.memory_len) return error.InvalidAddress;

            cpu.trits[rd] = @floatFromInt(cpu.memory[addr]);
            ip.* += 2;
            return true;
        },

        decoder.OPCODE_ST => {
            const rd = decoder.decodeReg8(&code, ip.*);
            const addr = decodeAddr16(&code, ip.*);

            // Store register to memory
            if (addr >= cpu.memory_len) return error.InvalidAddress;

            cpu.memory[addr] = @floatFromInt(cpu.trits[rd]);
            ip.* += 2;
            return true;
        },

        decoder.OPCODE_LDI => {
            const rd = decoder.decodeReg8(&code, ip.*);
            const imm = decodeImm16(&code, ip.*);

            // Load immediate to register
            cpu.trits[rd] = @floatFromInt(imm);

            ip.* += 2;
            return true;
        },

        decoder.OPCODE_STI => {
            const rd = decoder.decodeReg8(&code, ip.*);
            const imm = decodeImm16(&code, ip.*);
            const addr = decodeAddr16Reg(&code, ip.*);

            // Store immediate to memory at address + register offset
            if (addr.addr >= cpu.memory_len) return error.InvalidAddress;

            const val = @floatFromInt(imm);
            cpu.memory[addr.addr] = val;

            ip.* += 3;
            return true;
        },

        // === CONTROL ===
        decoder.OPCODE_JMP => {
            const addr = decodeCond(&code, ip.*);

            ip.* = addr;
            return true;
        },

        decoder.OPCODE_JZ => {
            const cond = decodeCond(&code, ip.*);
            const addr = decodeCond(&code, ip.* + 1);

            // Jump if zero flag not set
            if (!cpu.flags.zero) {
                ip.* = addr;
            }
            ip.* += 2;
            return true;
        },

        decoder.OPCODE_JNZ => {
            const cond = decodeCond(&code, ip.*);
            const addr = decodeCond(&code, ip.* + 1);

            // Jump if zero flag is set
            if (cpu.flags.zero) {
                ip.* = addr;
            }
            ip.* += 2;
            return true;
        },

        decoder.OPCODE_CALL => {
            const addr = decodeCond(&code, ip.*);

            // Push return address to stack, increment frame pointer
            if (cpu.fp >= 4095) return error.CallStackOverflow;

            cpu.call_stack[cpu.fp] = .{ .return_addr = addr + 2 };

            cpu.fp += 1;
            ip.* += 2;
            return true;
        },

        decoder.OPCODE_RET => {
            // Pop frame pointer, jump to return address
            if (cpu.fp == 0) {
                cpu.halted = true;
                return true;
            }

            const frame = cpu.call_stack[cpu.fp - 1];

            cpu.fp -= 1;
            ip.* = frame.return_addr;
            return true;
        },

        decoder.OPCODE_HALT => {
            cpu.halted = true;
            return true;
        },

        // === TERNARY ===
        // TODO: Integrate with sparse_ternary.zig for VSA operations
        decoder.OPCODE_DOT => {
            // Placeholder: Dot product operation
            // Will integrate with VSA dot product when available
            const regs = decoder.decodeRegPair(&code, ip.*);
            const a = getTritValue(cpu, regs.rd);
            const b = getTritValue(cpu, regs.rs1);

            _ = "TODO: Call VSA dot product and store to f0 or trit register";

            ip.* += 1;
            return true;
        },

        decoder.OPCODE_BIND => {
            // Placeholder: Bind two vectors
            _ = "TODO: Call VSA bind and store to trit register";

            ip.* += 1;
            return true;
        },

        decoder.OPCODE_BUNDLE2 => {
            // Placeholder: Bundle 2 vectors
            _ = "TODO: Call VSA bundle2 and store to trit register";

            ip.* += 1;
            return true;
        },

        decoder.OPCODE_BUNDLE3 => {
            // Placeholder: Bundle 3 vectors
            _ = "TODO: Call VSA bundle3 and store to trit register";

            ip.* += 1;
            return true;
        },

        // === SACRED ===
        // TODO: Integrate with sacred_alu operations
        decoder.OPCODE_PHI_CONST => {
            // Load φ constant into f0
            cpu.floats[0] = PHI;
            ip.* += 1;
            return true;
        },

        decoder.OPCODE_PI_CONST => {
            // Load π constant into f0
            cpu.floats[1] = PI;
            ip.* += 1;
            return true;
        },

        decoder.OPCODE_E_CONST => {
            // Load e constant into f0
            cpu.floats[2] = E;
            ip.* += 1;
            return true;
        },

        decoder.OPCODE_SACR => {
            // Placeholder: Sacred arithmetic operation
            _ = "TODO: Integrate with sacred ALU";

            ip.* += 1;
            return true;
        },

        else => {
            // Unknown opcode
            ip.* -= 1; // Undo the increment
            return error.InvalidOpcode;
        },
    }
}

/// === ERROR SET ===

pub const ExecutorError = error{
    InvalidOpcode,
    DivisionByZero,
    InvalidAddress,
    CallStackOverflow,
};

// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════ statement.

test "Executor: ADD operation" {
    var cpu = try cpu_state.CPUState.init(std.testing.allocator, 1024);
    defer cpu.deinit();

    // Load constant 5 into t0
    const code = [_]u8{
        0x02, 0x00, 0x05, // LDI t0, 5
    0x10, 0x07, 0x00, // ADD t0, t1, 5
        0x4D, // HALT
    };

    cpu.load(&code);

    const result = try executeInstruction(&cpu, &code);
    try std.testing.expect(result);
}

test "Executor: SUB operation" {
    var cpu = try cpu_state.CPUState.init(std.testing.allocator, 1024);
    defer cpu.deinit();

    // t0 = 10, t1 = 5, result = t0 - t1 = 5
    const code = [_]u8{
        0x02, 0x00, 0x05, // LDI t0, 5
        0x11, 0x07, 0x00, // SUB t1, t0, 5
        0x4D, // HALT
    };

    cpu.load(&code);

    const result = try executeInstruction(&cpu, &code);
    try std.testing.expect(result);
}

test "Executor: compare flags" {
    var cpu = try cpu_state.CPUState.init(std.testing.allocator, 1024);
    defer cpu.deinit();

    // t0 = 1, t1 = 2, should set negative flag, clear others
    const code = [_]u8{
        0x20, 0x07, 0x00, // CMP t0, t1, 2
        0x4D, // HALT
    };

    cpu.load(&code);

    const result = try executeInstruction(&cpu, &code);

    try std.testing.expect(cpu.flags.negative);
    try std.testing.expect(!cpu.flags.zero);
    try std.testing.expect(!cpu.flags.positive);
}

test "Executor: JMP operation" {
    var cpu = try cpu_state.CPUState.init(std.testing.allocator, 1024);
    defer cpu.deinit();

    // Jump to address 0x0040
    const code = [_]u8{
        0x40, 0x00, 0x40, // JMP 0x0040
        0x4D, // HALT
    };

    cpu.load(&code);

    const result = try executeInstruction(&cpu, &code);
    try std.testing.expect(result);
}

test "Executor: JZ operation" {
    var cpu = try cpu_state.CPUState.init(std.testing.allocator, 1024);
    defer cpu.deinit();

    // Set zero flag, t0 = 1
    const code = [_]u8{
        0x02, 0x00, 0x00, // LDI t0, 1
        0x41, 0x00, 0x00, // JZ t0, 0x0040
        0x4D, // HALT
    };

    cpu.load(&code);

    cpu.flags.clear();

    const result = try executeInstruction(&cpu, &code);
    try std.testing.expect(result);
    try std.testing.expect(cpu.flags.zero);
}

test "Executor: CALL/RET flow" {
    var cpu = try cpu_state.CPUState.init(std.testing.allocator, 1024);
    defer cpu.deinit();

    // Test with simple call/return
    const code = [_]u8{
        0x43, 0x00, 0x00, // CALL t0, 0x0010
        0x02, 0x00, 0x00, // LDI t0, 5 (return value)
        0x4B, // RET
    };

    cpu.load(&code);

    const result = try executeInstruction(&cpu, &code);
    try std.testing.expect(result);
}
