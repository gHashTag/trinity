//! VM Core Opcodes — Generated from specs/vm/opcodes.tri
//! φ² + 1/φ² = 3 | TRINITY
//!
//! DO NOT EDIT: This file is generated from opcodes.tri spec
//! Modify spec and regenerate: tri vibee-gen vm_opcodes

const std = @import("std");

/// ═════════════════════════════════════════════════════════════════════════
/// VM CORE OPCODES
/// ═══════════════════════════════════════════════════════════════════════
/// Core instruction set for stack-based virtual machine
/// 128 opcodes in 0x00-0x7F range
/// ══════════════════════════════════════════════════════════════════════════════
pub const Opcode = enum(u8) {
    // Control flow (0x00-0x0F)
    nop = 0x00, // No operation
    halt = 0x01, // Stop execution
    jump = 0x02, // Unconditional jump
    jz = 0x03, // Jump if zero
    jnz = 0x04, // Jump if not zero
    call = 0x05, // Call subroutine
    ret = 0x06, // Return from subroutine

    // Stack operations (0x10-0x1F)
    push = 0x10, // Push value
    pop = 0x11, // Pop value
    dup = 0x12, // Duplicate top
    swap = 0x13, // Swap top two

    // Arithmetic (0x20-0x2F)
    add = 0x20, // Addition
    sub = 0x21, // Subtraction
    mul = 0x22, // Multiplication
    div = 0x23, // Division
    mod = 0x24, // Modulo

    // Comparison (0x30-0x3F)
    eq = 0x30, // Equal
    ne = 0x31, // Not equal
    lt = 0x32, // Less than
    le = 0x33, // Less or equal
    gt = 0x34, // Greater than
    ge = 0x35, // Greater or equal

    // Logical (0x40-0x4F)
    @"and" = 0x40, // Bitwise AND
    @"or" = 0x41, // Bitwise OR
    xor = 0x42, // Bitwise XOR
    not = 0x43, // Bitwise NOT

    // Memory (0x50-0x5F)
    load = 0x50, // Load from memory
    store = 0x51, // Store to memory

    // VSA operations (0x60-0x6F)
    bind = 0x60, // VSA bind
    unbind = 0x61, // VSA unbind
    bundle = 0x62, // VSA bundle

    const Self = @This();

    /// Get human-readable opcode name
    pub fn toString(self: Opcode) []const u8 {
        return switch (self) {
            // Control flow
            .nop => "nop",
            .halt => "halt",
            .jump => "jump",
            .jz => "jz",
            .jnz => "jnz",
            .call => "call",
            .ret => "ret",

            // Stack
            .push => "push",
            .pop => "pop",
            .dup => "dup",
            .swap => "swap",

            // Arithmetic
            .add => "add",
            .sub => "sub",
            .mul => "mul",
            .div => "div",
            .mod => "mod",

            // Comparison
            .eq => "eq",
            .ne => "ne",
            .lt => "lt",
            .le => "le",
            .gt => "gt",
            .ge => "ge",

            // Logical
            .@"and" => "and",
            .@"or" => "or",
            .xor => "xor",
            .not => "not",

            // Memory
            .load => "load",
            .store => "store",

            // VSA
            .bind => "bind",
            .unbind => "unbind",
            .bundle => "bundle",
        };
    }

    /// Check if opcode is control flow instruction
    pub fn isControlFlow(self: Opcode) bool {
        return @intFromEnum(self) >= 0x00 and @intFromEnum(self) <= 0x0F;
    }

    /// Check if opcode is stack operation
    pub fn isStackOp(self: Opcode) bool {
        return @intFromEnum(self) >= 0x10 and @intFromEnum(self) <= 0x1F;
    }

    /// Check if opcode is arithmetic operation
    pub fn isArithmetic(self: Opcode) bool {
        return @intFromEnum(self) >= 0x20 and @intFromEnum(self) <= 0x2F;
    }

    /// Check if opcode is comparison operation
    pub fn isComparison(self: Opcode) bool {
        return @intFromEnum(self) >= 0x30 and @intFromEnum(self) <= 0x3F;
    }

    /// Check if opcode is logical operation
    pub fn isLogical(self: Opcode) bool {
        return @intFromEnum(self) >= 0x40 and @intFromEnum(self) <= 0x4F;
    }

    /// Check if opcode is memory operation
    pub fn isMemory(self: Opcode) bool {
        return @intFromEnum(self) >= 0x50 and @intFromEnum(self) <= 0x5F;
    }

    /// Check if opcode is VSA operation
    pub fn isVSA(self: Opcode) bool {
        return @intFromEnum(self) >= 0x60 and @intFromEnum(self) <= 0x6F;
    }
};

/// ═════════════════════════════════════════════════════════════════════════
/// INSTRUCTION STRUCT
/// ═════════════════════════════════════════════════════════════════════════
pub const Instruction = struct {
    opcode: Opcode = .nop,
    operand: i64 = 0,

    pub fn init(opcode: Opcode, operand: i64) Instruction {
        return .{ .opcode = opcode, .operand = operand };
    }

    /// Encode instruction to u64 for storage
    pub fn encode(self: Instruction) u64 {
        return (@as(u64, @intFromEnum(self.opcode)) << 56) |
            ((@as(u64, @bitCast(@as(i64, @intCast(self.operand)))) & 0x00FFFFFFFFFFFFFF));
    }

    /// Decode u64 to instruction
    pub fn decode(encoded: u64) Instruction {
        const opcode_byte = @as(u8, @intCast(encoded >> 56));
        const operand_value = @as(i64, @bitCast(encoded & 0x00FFFFFFFFFFFFFF));
        return .{
            .opcode = std.meta.intToEnum(Opcode, opcode_byte) catch .nop,
            .operand = operand_value,
        };
    }
};

/// Parse byte to Opcode (returns nop if invalid)
pub fn opcodeFromByte(byte: u8) Opcode {
    return std.meta.intToEnum(Opcode, byte) catch .nop;
}

/// Get human-readable opcode name (alias for Opcode.toString)
pub fn opcodeToString(opcode: Opcode) []const u8 {
    return opcode.toString();
}

/// ═════════════════════════════════════════════════════════════════════════
/// VM CONSTANTS
/// ══════════════════════════════════════════════════════════════════════════════
pub const MAX_STACK_DEPTH: usize = 1024;
pub const MAX_MEMORY_SIZE: usize = 65536; // 64KB

// ═════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════

test "Opcode: control flow detection" {
    try std.testing.expect(@intFromEnum(Opcode.nop) == 0x00);
    try std.testing.expect(@intFromEnum(Opcode.halt) == 0x01);
    try std.testing.expect(Opcode.jump.isControlFlow());
    try std.testing.expect(Opcode.jz.isControlFlow());
}

test "Opcode: stack operations" {
    try std.testing.expect(@intFromEnum(Opcode.push) == 0x10);
    try std.testing.expect(@intFromEnum(Opcode.pop) == 0x11);
    try std.testing.expect(Opcode.push.isStackOp());
    try std.testing.expect(Opcode.dup.isStackOp());
}

test "Opcode: arithmetic operations" {
    try std.testing.expect(@intFromEnum(Opcode.add) == 0x20);
    try std.testing.expect(@intFromEnum(Opcode.mul) == 0x22);
    try std.testing.expect(Opcode.add.isArithmetic());
    try std.testing.expect(Opcode.div.isArithmetic());
}

test "Opcode: comparison operations" {
    try std.testing.expect(@intFromEnum(Opcode.eq) == 0x30);
    try std.testing.expect(@intFromEnum(Opcode.gt) == 0x34);
    try std.testing.expect(Opcode.eq.isComparison());
    try std.testing.expect(Opcode.le.isComparison());
}

test "Opcode: logical operations" {
    try std.testing.expect(@intFromEnum(Opcode.@"and") == 0x40);
    try std.testing.expect(@intFromEnum(Opcode.xor) == 0x42);
    try std.testing.expect(Opcode.@"and".isLogical());
    try std.testing.expect(Opcode.not.isLogical());
}

test "Opcode: memory operations" {
    try std.testing.expect(@intFromEnum(Opcode.load) == 0x50);
    try std.testing.expect(@intFromEnum(Opcode.store) == 0x51);
    try std.testing.expect(Opcode.load.isMemory());
    try std.testing.expect(Opcode.store.isMemory());
}

test "Opcode: VSA operations" {
    try std.testing.expect(@intFromEnum(Opcode.bind) == 0x60);
    try std.testing.expect(@intFromEnum(Opcode.bundle) == 0x62);
    try std.testing.expect(Opcode.bind.isVSA());
    try std.testing.expect(Opcode.unbind.isVSA());
}

test "Opcode: toString" {
    try std.testing.expectEqualSlices(u8, "nop", Opcode.nop.toString());
    try std.testing.expectEqualSlices(u8, "add", Opcode.add.toString());
    try std.testing.expectEqualSlices(u8, "halt", Opcode.halt.toString());
}

test "Instruction: encode/decode" {
    const inst = Instruction.init(Opcode.add, 42);
    const encoded = inst.encode();
    const decoded = Instruction.decode(encoded);
    try std.testing.expectEqual(Opcode.add, decoded.opcode);
    try std.testing.expectEqual(@as(i64, 42), decoded.operand);
}

test "Instruction: decode invalid opcode defaults to nop" {
    const invalid: u64 = 0xFF00000000000000; // 0xFF in high byte
    const decoded = Instruction.decode(invalid);
    try std.testing.expectEqual(Opcode.nop, decoded.opcode);
}

test "Constants: VM limits" {
    try std.testing.expectEqual(@as(usize, 1024), MAX_STACK_DEPTH);
    try std.testing.expectEqual(@as(usize, 65536), MAX_MEMORY_SIZE);
}

test "opcodeFromByte: invalid defaults to nop" {
    try std.testing.expectEqual(Opcode.nop, opcodeFromByte(0xFF));
    try std.testing.expectEqual(Opcode.add, opcodeFromByte(0x20));
}
