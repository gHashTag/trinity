// ═════════════════════════════════════════════════════════════════════════
// TRI-27 DECODER — Opcode Decode for 27 Ternary Opcodes
// ═══════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// ═══════════════════════════════════════════════════════════════════════════
// TRI-27 OPCODES
// ═══════════════════════════════════════════════════════════════════════════════════════
/// Architecture: 27 trinary registers + 3 float registers
/// Opcodes (0x00-0x1B total)
/// === ARITHMETIC (0x10-0x13) ===
pub const OPCODE_NOP: u8 = 0x00;
pub const OPCODE_ADD: u8 = 0x10;
pub const OPCODE_SUB: u8 = 0x11;
pub const OPCODE_MUL: u8 = 0x12;
pub const OPCODE_DIV: u8 = 0x13;
pub const OPCODE_INC: u8 = 0x14;
pub const OPCODE_DEC: u8 = 0x15;

/// === LOGIC (0x18-0x1D) ===
pub const OPCODE_AND: u8 = 0x18;
pub const OPCODE_OR: u8 = 0x19;
pub const OPCODE_XOR: u8 = 0x1A;
pub const OPCODE_NOT: u8 = 0x1B;
pub const OPCODE_SHL: u8 = 0x1C;
pub const OPCODE_SHR: u8 = 0x1D;

/// === MEMORY (0x02-0x05) ===
pub const OPCODE_LD: u8 = 0x02; // Load from memory/register
pub const OPCODE_ST: u8 = 0x03; // Store to memory
pub const OPCODE_LDI: u8 = 0x04; // Load immediate
pub const OPCODE_STI: u8 = 0x05; // Store immediate

/// === CONTROL (0x40-0x4F) ===
pub const OPCODE_JMP: u8 = 0x40;
pub const OPCODE_JZ: u8 = 0x41;
pub const OPCODE_JNZ: u8 = 0x42;
pub const OPCODE_CALL: u8 = 0x43;
pub const OPCODE_RET: u8 = 0x4B;
pub const OPCODE_HALT: u8 = 0x4D;

/// === TERNARY (0x60-0x6D) ===
pub const OPCODE_DOT: u8 = 0x60; // Dot product (VSA/TF3)
pub const OPCODE_BIND: u8 = 0x61; // Bind two vectors
pub const OPCODE_BUNDLE2: u8 = 0x62; // Bundle 2 vectors
pub const OPCODE_BUNDLE3: u8 = 0x63; // Bundle 3 vectors

/// === SACRED (0x80-0x92) ===
pub const OPCODE_PHI_CONST: u8 = 0x80; // Load φ constant
pub const OPCODE_PI_CONST: u8 = 0x81; // Load π constant
pub const OPCODE_E_CONST: u8 = 0x82; // Load e constant
pub const OPCODE_SACR: u8 = 0x83; // Sacred arithmetic operation

/// Opcode names for debugging
pub const opcodeNames: [27][]const u8 = [27]u8{
    "NOP",      "ADD",     "SUB",  "MUL",  "DIV",     "INC",     "DEC",
    "AND",      "OR",      "XOR",  "NOT",  "SHL",     "SHR",     "LD",
    "ST",       "LDI",     "STI",  "JMP",  "JZ",      "JNZ",     "CALL",
    "RET",      "HALT",    "DOT",  "BIND", "BUNDLE2", "BUNDLE3", "PHI_CONST",
    "PI_CONST", "E_CONST", "SACR",
};

/// Get opcode name for debugging
pub fn getOpcodeName(opcode: u8) []const u8 {
    if (opcode < opcodeNames.len) {
        return opcodeNames[opcode];
    }
    return "<unknown>";
}

/// TRI-27 Instruction Format
/// RRR: rd, rs1, rs2 (3-bit each, up to 27 registers)
/// RI:  rd, imm16 (8-bit rd, 16-bit immediate)
/// RRI: rd, rs, imm16 (8-bit rd, 8-bit rs, 16-bit imm)
/// JMP: cond, addr16 (4-bit cond, 16-bit target)
/// CALL/RET: addr16 (16-bit target)
/// SACRED: imm16 (16-bit sacred constant)
pub const Instruction = struct {
    /// Operation code
    opcode: u8,

    /// Destination register (0-26)
    rd: u8,

    /// Source register 1 (0-26)
    rs1: u8,

    /// Source register 2 (0-26)
    rs2: u8,

    /// Immediate value (16-bit signed)
    imm16: i16,

    /// Condition code (for branches)
    cond: u8,
};

/// Decode register encoding (3 bits: 5 values)
/// For most RRR/RRI opcodes: reg field contains destination + 2 sources
pub const RegDecode = packed struct {
    rd: u8 = 0, // Destination register (t0-t26)
    rs1: u8 = 0, // Source register 1
    rs2: u8 = 0, // Source register 2
};

/// Decode immediate value (16-bit signed)
/// For RI/RII opcodes
pub fn decodeImm16(code: []const u8, ip: *u32) u16 {
    const lo = code[ip.*];
    const hi = code[ip.* + 1];
    return (@as(u16, hi) << 8) | @as(u16, lo);
}

/// Decode single register (3 bits: 8 values)
/// For R/R/RR opcodes with single register operand
pub fn decodeReg8(code: []const u8, ip: *u32) u8 {
    return code[ip.*] & 0x07;
}

/// Decode register pair (6 bits: dest + src)
/// For RR opcodes
pub fn decodeRegPair(code: []const u8, ip: *u32) RegDecode {
    const byte = code[ip.*];
    return RegDecode{
        .rd = byte & 0x07,
        .rs1 = (byte >> 3) & 0x07,
        .rs2 = (byte >> 0) & 0x07,
    };
}

/// Memory address (16-bit)
pub fn decodeAddr16(code: []const u8, ip: *u32) u16 {
    const lo = code[ip.*];
    const hi = code[ip.* + 1];
    return (@as(u16, hi) << 8) | @as(u16, lo);
}

/// Memory address (16-bit) + register offset
const Addr16Reg = struct { addr: u16, reg: u8 };

pub fn decodeAddr16Reg(code: []const u8, ip: *u32) Addr16Reg {
    const addr = decodeAddr16(code, ip);
    const reg = decodeReg8(code, ip);
    return .{ .addr = addr, .reg = reg };
}

/// Condition code (4 bits: branch target)
pub fn decodeCond(code: []const u8, ip: *u32) u16 {
    const lo = code[ip.*];
    const hi = code[ip.* + 1];
    return (@as(u16, hi) << 8) | @as(u16, lo);
}

test "decoder: opcodeNames coverage" {
    try std.testing.expectEqual(@as(usize, 27), opcodeNames.len);
}

test "decoder: decodeReg8" {
    const code = [_]u8{ 0x20, 0x07 };
    const rd = decodeReg8(&code, 0);
    try std.testing.expectEqual(@as(u8, 2), rd);
}

test "decoder: decodeRegPair" {
    const code = [_]u8{ 0x01, 0x07 };
    const pair = decodeRegPair(&code, 0);
    try std.testing.expectEqual(@as(u8, 0), pair.rd);
    try std.testing.expectEqual(@as(u8, 1), pair.rs1);
    try std.testing.expectEqual(@as(u8, 2), pair.rs2);
}

/// Wrapper for external decode calls
pub fn decodeInstruction(word: u32) Instruction {
    return decode(word);
}

test "decoder: decodeImm16" {
    const code = [_]u8{ 0x02, 0x80, 0x00 };
    const imm = decodeImm16(&code, 0);
    try std.testing.expectEqual(@as(u16, 32768), imm);
}

test "decoder: decodeAddr16" {
    const code = [_]u8{ 0x40, 0x80, 0x40, 0x10 };
    const addr = decodeAddr16(&code, 0);
    try std.testing.expectEqual(@as(u16, 0x1000), addr);
}

test "decoder: decodeCond" {
    const code = [_]u8{ 0x40, 0x00, 0x00 };
    const cond = decodeCond(&code, 0);
    try std.testing.expectEqual(@as(u16, 0), cond);
}

test "decoder: getOpcodeName" {
    try std.testing.expectEqualStrings("NOP", getOpcodeName(OPCODE_NOP));
    try std.testing.expectEqualStrings("ADD", getOpcodeName(OPCODE_ADD));
    try std.testing.expectEqualStrings("DOT", getOpcodeName(OPCODE_DOT));
    try std.testing.expectEqualStrings("UNKNOWN", getOpcodeName(255));
}

/// Decode register from 3-bit field (bits 8-10)
fn decodeRd(word: u32) u8 {
    return @as(u8, (word >> 8) & 0x1F); // 5 bits for 27 registers
}

/// Decode register from 3-bit field (bits 11-13)
fn decodeRs1(word: u32) u8 {
    return @as(u8, (word >> 11) & 0x1F);
}

/// Decode register from 3-bit field (bits 14-16)
fn decodeRs2(word: u32) u8 {
    return @as(u8, (word >> 14) & 0x1F);
}

/// Decode 16-bit immediate (bits 16-31)
fn decodeImm16FromWord(word: u32) i16 {
    return @as(i16, @truncate((word >> 16) & 0xFFFF));
}

/// Decode 32-bit instruction word into Instruction struct
pub fn decode(word: u32) Instruction {
    const opcode = @as(u8, word & 0xFF);

    // For most instructions: decode register fields
    const rd = decodeRd(word);
    const rs1 = decodeRs1(word);
    const rs2 = decodeRs2(word);
    const imm16 = decodeImm16FromWord(word);

    return Instruction{
        .opcode = opcode,
        .rd = rd,
        .rs1 = rs1,
        .rs2 = rs2,
        .imm16 = imm16,
        .cond = 0,
    };
}

/// Encode Instruction to 32-bit word
pub fn encode(inst: Instruction) u32 {
    var word: u32 = 0;
    word |= inst.opcode;
    word |= @as(u32, inst.rd) << 8;
    word |= @as(u32, inst.rs1) << 11;
    word |= @as(u32, inst.rs2) << 14;
    word |= @as(u32, @as(u16, @bitCast(inst.imm16))) << 16;
    return word;
}

test "CPUState compatibility" {
    const code = [_]u8{ 0x02, 0x03, 0x00, 0x07 }; // LD R0, ST R1, NOP

    // Verify instruction encoding matches CPUState.tbits array
    // LD: 0x02 + rd(3 bits) → t0
    const rd = decodeReg8(&code, 0);
    try std.testing.expectEqual(@as(u8, 0), rd); // Should decode to 0

    // ST: 0x03 + rd(3 bits) → t1
    const rd2 = decodeReg8(&code, 2);
    try std.testing.expectEqual(@as(u8, 1), rd2); // Should decode to 1

    // NOP: 0x00 (no operands)
    try std.testing.expectEqual(@as(u8, 0), decodeReg8(&code, 0));
}

test "CPUState with 27 registers" {
    const code = [_]u8{ 0x02, 0x07, 0x00, 0x27 }; // LD t0, ST t26, NOP

    const rd = decodeReg8(&code, 0);
    try std.testing.expectEqual(@as(u8, 0), rd); // t0

    const rd2 = decodeReg8(&code, 2);
    try std.testing.expectEqual(@as(u8, 26), rd2); // t26 (26 = 0x1A, but & 0x07 = 26)
}
