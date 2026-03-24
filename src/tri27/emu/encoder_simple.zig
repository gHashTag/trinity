// @origin(spec:tri27_isa.zig) @regen(manual-impl)
// TRI-27 SIMPLE ENCODER — Minimal encoding functions for .tbin bytecode
//
// Instruction format (32-bit):
//   [7:0]   = opcode (8 bits)
//   [12:8]  = dst (rd) - 5 bits
//   [17:13] = src1 (rs1) - 5 bits
//   [22:18] = src2 (rs2) - 5 bits
//   [31:16] = immediate (16 bits, signed)
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

/// ═══════════════════════════════════════════════════════════════════════════════
// OPCODE DEFINITIONS (matching decoder.zig)
/// ═══════════════════════════════════════════════════════════════════════════════
pub const Opcode = enum(u8) {
    NOP = 0x00,
    LD = 0x02,
    ST = 0x03,
    LDI = 0x04,
    STI = 0x05,
    ADD = 0x10,
    SUB = 0x11,
    MUL = 0x12,
    DIV = 0x13,
    INC = 0x14,
    DEC = 0x15,
    AND = 0x18,
    OR = 0x19,
    XOR = 0x1A,
    NOT = 0x1B,
    SHL = 0x1C,
    SHR = 0x1D,
    JMP = 0x40,
    JZ = 0x41,
    JNZ = 0x42,
    CALL = 0x43,
    RET = 0x4B,
    HALT = 0x4D,
    DOT = 0x60,
    BIND = 0x61,
    BUNDLE2 = 0x62,
    BUNDLE3 = 0x63,
    PHI_CONST = 0x80,
    PI_CONST = 0x81,
    E_CONST = 0x82,
    SACR = 0x83,
    LD_IMM = 0x84,
    ADD3 = 0x85,
    SUB3 = 0x86,
    CMP3 = 0x87,
    SYSCALL = 0x88,
    _,
};

/// ═══════════════════════════════════════════════════════════════════════════════
// ENCODING FUNCTIONS
/// ═══════════════════════════════════════════════════════════════════════════════
/// Encode NOP (No Operation)
/// Format: opcode only
pub fn encode_nop(rd: u5) u32 {
    _ = rd; // Destination register ignored for NOP, but allowed for encoding
    return @intFromEnum(Opcode.NOP);
}

/// Encode ADD (Add registers)
/// Format: opcode | (dst << 8) | (src1 << 13) | (src2 << 18)
pub fn encode_add(dst: u5, src1: u5, src2: u5) u32 {
    var word: u32 = @intFromEnum(Opcode.ADD);
    word |= @as(u32, dst) << 8;
    word |= @as(u32, src1) << 13;
    word |= @as(u32, src2) << 18;
    return word;
}

/// Encode SUB (Subtract registers)
/// Format: opcode | (dst << 8) | (src1 << 13) | (src2 << 18)
pub fn encode_sub(dst: u5, src1: u5, src2: u5) u32 {
    var word: u32 = @intFromEnum(Opcode.SUB);
    word |= @as(u32, dst) << 8;
    word |= @as(u32, src1) << 13;
    word |= @as(u32, src2) << 18;
    return word;
}

/// Encode MUL (Multiply registers)
/// Format: opcode | (dst << 8) | (src1 << 13) | (src2 << 18)
pub fn encode_mul(dst: u5, src1: u5, src2: u5) u32 {
    var word: u32 = @intFromEnum(Opcode.MUL);
    word |= @as(u32, dst) << 8;
    word |= @as(u32, src1) << 13;
    word |= @as(u32, src2) << 18;
    return word;
}

/// Encode TMUL (Ternary Multiply) — ternary × ternary = tritwise product
/// Uses DOT opcode for VSA/TF3 compatibility
/// Format: opcode | (dst << 8) | (src1 << 11) | (src2 << 14)
pub fn encode_tmul(dst: u5, src1: u5, src2: u5) u32 {
    var word: u32 = @intFromEnum(Opcode.DOT);
    word |= @as(u32, dst) << 8;
    word |= @as(u32, src1) << 13;
    word |= @as(u32, src2) << 18;
    return word;
}

/// Encode LOAD_IMM (Load Immediate)
/// Format: opcode | (dst << 8) | (imm16 << 16)
/// Immediate is sign-extended to 32 bits at decode time
pub fn encode_load_imm(dst: u5, imm: i16) u32 {
    var word: u32 = @intFromEnum(Opcode.LD_IMM);
    word |= @as(u32, dst) << 8;
    const imm_u16: u16 = @bitCast(imm);
    word |= @as(u32, imm_u16) << 16;
    return word;
}

/// Encode LDI (Load Immediate alternate)
/// Format: opcode | (dst << 8) | (imm16 << 16)
/// Immediate is 16-bit signed
pub fn encode_ldi(dst: u5, imm: i16) u32 {
    var word: u32 = @intFromEnum(Opcode.LDI);
    word |= @as(u32, dst) << 8;
    const imm_u16: u16 = @bitCast(imm);
    const imm_u32: u32 = imm_u16;
    word |= imm_u32 << 16;
    return word;
}

/// Encode STORE (Store register to memory address)
/// Format: opcode | (dst << 8) | (addr << 16)
/// Note: dst contains source register, addr is 16-bit memory address
pub fn encode_store(src: u5, addr: u16) u32 {
    var word: u32 = @intFromEnum(Opcode.ST);
    word |= @as(u32, src) << 8;
    word |= @as(u32, addr) << 16;
    return word;
}

/// Encode STI (Store Immediate to memory address)
/// Format: opcode | (imm16 << 8) | (addr << 24)
/// Immediate value stored directly to address
pub fn encode_sti(imm: i16, addr: u8) u32 {
    var word: u32 = @intFromEnum(Opcode.STI);
    const imm_u16: u16 = @bitCast(imm);
    const imm_u32: u32 = imm_u16;
    word |= imm_u32 << 8;
    word |= @as(u32, addr) << 24;
    return word;
}

/// Encode LOAD_MEM (Load from memory address to register)
/// Format: opcode | (dst << 8) | (addr << 16)
pub fn encode_load_mem(dst: u5, addr: u16) u32 {
    var word: u32 = @intFromEnum(Opcode.LD);
    word |= @as(u32, dst) << 8;
    word |= @as(u32, addr) << 16;
    return word;
}

/// Encode JMP (Unconditional Jump)
/// Format: opcode | (imm16 << 8)
/// Jumps to immediate address (PC = imm)
pub fn encode_jmp(imm: i16) u32 {
    var word: u32 = @intFromEnum(Opcode.JMP);
    const imm_u16: u16 = @bitCast(imm);
    word |= @as(u32, imm_u16) << 8;
    return word;
}

/// Encode JZ (Jump if Zero)
/// Format: opcode | (rd << 8) | (imm16 << 16)
/// Jumps if register rd == 0
pub fn encode_jz(rd: u5, imm: i16) u32 {
    var word: u32 = @intFromEnum(Opcode.JZ);
    word |= @as(u32, rd) << 8;
    const imm_u16: u16 = @bitCast(imm);
    word |= @as(u32, imm_u16) << 16;
    return word;
}

/// Encode JNZ (Jump if Not Zero)
/// Format: opcode | (rd << 8) | (imm16 << 16)
/// Jumps if register rd != 0
pub fn encode_jnz(rd: u5, imm: i16) u32 {
    var word: u32 = @intFromEnum(Opcode.JNZ);
    word |= @as(u32, rd) << 8;
    const imm_u16: u16 = @bitCast(imm);
    word |= @as(u32, imm_u16) << 16;
    return word;
}

/// Encode CALL (Call subroutine)
/// Format: opcode | (imm16 << 8)
/// Pushes PC+1 to stack, jumps to immediate address
pub fn encode_call(imm: i16) u32 {
    var word: u32 = @intFromEnum(Opcode.CALL);
    const imm_u16: u16 = @bitCast(imm);
    word |= @as(u32, imm_u16) << 8;
    return word;
}

/// Encode RET (Return from subroutine)
/// Format: opcode only
/// Pops return address from stack
pub fn encode_ret() u32 {
    return @intFromEnum(Opcode.RET);
}

/// Encode HALT (Stop execution)
/// Format: opcode only
pub fn encode_halt() u32 {
    return @intFromEnum(Opcode.HALT);
}

/// Encode AND (Bitwise AND)
/// Format: opcode | (dst << 8) | (src1 << 11) | (src2 << 14)
pub fn encode_and(dst: u5, src1: u5, src2: u5) u32 {
    var word: u32 = @intFromEnum(Opcode.AND);
    word |= @as(u32, dst) << 8;
    word |= @as(u32, src1) << 13;
    word |= @as(u32, src2) << 18;
    return word;
}

/// Encode OR (Bitwise OR)
/// Format: opcode | (dst << 8) | (src1 << 11) | (src2 << 14)
pub fn encode_or(dst: u5, src1: u5, src2: u5) u32 {
    var word: u32 = @intFromEnum(Opcode.OR);
    word |= @as(u32, dst) << 8;
    word |= @as(u32, src1) << 13;
    word |= @as(u32, src2) << 18;
    return word;
}

/// Encode XOR (Bitwise XOR)
/// Format: opcode | (dst << 8) | (src1 << 11) | (src2 << 14)
pub fn encode_xor(dst: u5, src1: u5, src2: u5) u32 {
    var word: u32 = @intFromEnum(Opcode.XOR);
    word |= @as(u32, dst) << 8;
    word |= @as(u32, src1) << 13;
    word |= @as(u32, src2) << 18;
    return word;
}

/// Encode NOT (Bitwise NOT)
/// Format: opcode | (dst << 8)
pub fn encode_not(dst: u5) u32 {
    var word: u32 = @intFromEnum(Opcode.NOT);
    word |= @as(u32, dst) << 8;
    return word;
}

/// Encode SHL (Shift Left)
/// Format: opcode | (dst << 8) | (shift_amt << 13)
pub fn encode_shl(dst: u5, shift_amt: u5) u32 {
    var word: u32 = @intFromEnum(Opcode.SHL);
    word |= @as(u32, dst) << 8;
    word |= @as(u32, shift_amt) << 13;
    return word;
}

/// Encode SHR (Shift Right)
/// Format: opcode | (dst << 8) | (shift_amt << 13)
pub fn encode_shr(dst: u5, shift_amt: u5) u32 {
    var word: u32 = @intFromEnum(Opcode.SHR);
    word |= @as(u32, dst) << 8;
    word |= @as(u32, shift_amt) << 13;
    return word;
}

/// Encode DIV (Divide)
/// Format: opcode | (dst << 8) | (src1 << 11) | (src2 << 14)
pub fn encode_div(dst: u5, src1: u5, src2: u5) u32 {
    var word: u32 = @intFromEnum(Opcode.DIV);
    word |= @as(u32, dst) << 8;
    word |= @as(u32, src1) << 13;
    word |= @as(u32, src2) << 18;
    return word;
}

/// Encode INC (Increment)
/// Format: opcode | (dst << 8)
pub fn encode_inc(dst: u5) u32 {
    var word: u32 = @intFromEnum(Opcode.INC);
    word |= @as(u32, dst) << 8;
    return word;
}

/// Encode DEC (Decrement)
/// Format: opcode | (dst << 8)
pub fn encode_dec(dst: u5) u32 {
    var word: u32 = @intFromEnum(Opcode.DEC);
    word |= @as(u32, dst) << 8;
    return word;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════
test "encode_nop" {
    const encoded = encode_nop(0);
    try std.testing.expectEqual(@as(u32, 0x00), encoded);
}

test "encode_nop_with_rd" {
    const encoded = encode_nop(5); // rd is ignored for NOP
    try std.testing.expectEqual(@as(u32, 0x00), encoded);
}

test "encode_add_basic" {
    const encoded = encode_add(0, 0, 0);
    try std.testing.expectEqual(@as(u32, 0x10), encoded); // ADD opcode = 0x10
}

test "encode_add_with_registers" {
    // dst=1, src1=2, src2=3
    const encoded = encode_add(1, 2, 3);
    const expected: u32 = 0x10 | (1 << 8) | (2 << 13) | (3 << 18);
    try std.testing.expectEqual(expected, encoded);
}

test "encode_add_max_registers" {
    // All registers at max (31 = 0x1F)
    const encoded = encode_add(31, 31, 31);
    const expected: u32 = 0x10 | (31 << 8) | (31 << 13) | (31 << 18);
    try std.testing.expectEqual(expected, encoded);
}

test "encode_sub_basic" {
    const encoded = encode_sub(0, 0, 0);
    try std.testing.expectEqual(@as(u32, 0x11), encoded); // SUB opcode = 0x11
}

test "encode_sub_with_registers" {
    const encoded = encode_sub(5, 3, 1);
    const expected: u32 = 0x11 | (5 << 8) | (3 << 13) | (1 << 18);
    try std.testing.expectEqual(expected, encoded);
}

test "encode_mul_basic" {
    const encoded = encode_mul(0, 0, 0);
    try std.testing.expectEqual(@as(u32, 0x12), encoded); // MUL opcode = 0x12
}

test "encode_mul_with_registers" {
    const encoded = encode_mul(2, 4, 6);
    const expected: u32 = 0x12 | (2 << 8) | (4 << 13) | (6 << 18);
    try std.testing.expectEqual(expected, encoded);
}

test "encode_tmul_basic" {
    const encoded = encode_tmul(0, 0, 0);
    try std.testing.expectEqual(@as(u32, 0x60), encoded); // DOT opcode = 0x60
}

test "encode_tmul_with_registers" {
    const encoded = encode_tmul(7, 11, 13);
    const expected: u32 = 0x60 | (7 << 8) | (11 << 13) | (13 << 18);
    try std.testing.expectEqual(expected, encoded);
}

test "encode_load_imm_zero" {
    const encoded = encode_load_imm(0, 0);
    try std.testing.expectEqual(@as(u32, 0x84), encoded); // LD_IMM opcode = 0x84
}

test "encode_load_imm_positive" {
    const encoded = encode_load_imm(5, 42);
    const expected: u32 = 0x84 | (5 << 8) | (42 << 16);
    try std.testing.expectEqual(expected, encoded);
}

test "encode_load_imm_negative" {
    const encoded = encode_load_imm(3, -1);
    // -1 as i16 = 0xFFFF, but we only store lower 16 bits
    const expected: u32 = 0x84 | (3 << 8) | (0xFFFF << 16);
    try std.testing.expectEqual(expected, encoded);
}

test "encode_load_imm_max_positive" {
    const encoded = encode_load_imm(10, 32767); // i16 max
    const expected: u32 = 0x84 | (10 << 8) | (32767 << 16);
    try std.testing.expectEqual(expected, encoded);
}

test "encode_load_imm_min_negative" {
    const encoded = encode_load_imm(15, -32768); // i16 min
    const imm_u16: u16 = @bitCast(@as(i16, -32768));
    const expected: u32 = 0x84 | (15 << 8) | (@as(u32, imm_u16) << 16);
    try std.testing.expectEqual(expected, encoded);
}

test "encode_ldi_zero" {
    const encoded = encode_ldi(0, 0);
    try std.testing.expectEqual(@as(u32, 0x04), encoded); // LDI opcode = 0x04
}

test "encode_ldi_with_value" {
    const encoded = encode_ldi(7, -99);
    const imm_u16: u16 = @bitCast(@as(i16, -99));
    const expected: u32 = 0x04 | (7 << 8) | (@as(u32, imm_u16) << 16);
    try std.testing.expectEqual(expected, encoded);
}

test "encode_store_basic" {
    const encoded = encode_store(0, 0);
    try std.testing.expectEqual(@as(u32, 0x03), encoded); // ST opcode = 0x03
}

test "encode_store_with_address" {
    const encoded = encode_store(5, 0x1000);
    const expected: u32 = 0x03 | (5 << 8) | (0x1000 << 16);
    try std.testing.expectEqual(expected, encoded);
}

test "encode_jmp_basic" {
    const encoded = encode_jmp(100);
    try std.testing.expectEqual(@as(u32, 0x40 | (100 << 8)), encoded); // JMP opcode = 0x40
}

test "encode_jmp_negative" {
    const encoded = encode_jmp(-50);
    const imm_u16: u16 = @bitCast(@as(i16, -50));
    const expected: u32 = 0x40 | (@as(u32, imm_u16) << 8);
    try std.testing.expectEqual(expected, encoded);
}

test "encode_jz_basic" {
    const encoded = encode_jz(0, 10);
    const expected: u32 = 0x41 | (10 << 16); // JZ opcode = 0x41, rd=0, imm=10 at bit 16
    try std.testing.expectEqual(expected, encoded);
}

test "encode_jnz_basic" {
    const encoded = encode_jnz(5, 20);
    try std.testing.expectEqual(@as(u32, 0x42 | (5 << 8) | (20 << 16)), encoded); // JNZ opcode = 0x42
}

test "encode_call_basic" {
    const encoded = encode_call(100);
    try std.testing.expectEqual(@as(u32, 0x43 | (100 << 8)), encoded); // CALL opcode = 0x43
}

test "encode_ret" {
    const encoded = encode_ret();
    try std.testing.expectEqual(@as(u32, 0x4B), encoded); // RET opcode = 0x4B
}

test "encode_store_max_address" {
    const encoded = encode_store(10, 0xFFFF);
    const expected: u32 = 0x03 | (10 << 8) | (0xFFFF << 16);
    try std.testing.expectEqual(expected, encoded);
}

test "encode_sti_basic" {
    const encoded = encode_sti(0, 0);
    try std.testing.expectEqual(@as(u32, 0x05), encoded); // STI opcode = 0x05
}

test "encode_sti_with_values" {
    const encoded = encode_sti(42, 0x08);
    const imm_u16: u16 = @bitCast(@as(i16, 42));
    const expected: u32 = 0x05 | (@as(u32, imm_u16) << 8) | (@as(u32, 0x08) << 24);
    try std.testing.expectEqual(expected, encoded);
}

test "encode_sti_negative" {
    const encoded = encode_sti(-55, 0x34);
    const imm_u16: u16 = @bitCast(@as(i16, -55));
    const expected: u32 = 0x05 | (@as(u32, imm_u16) << 8) | (@as(u32, 0x34) << 24);
    try std.testing.expectEqual(expected, encoded);
}

test "encode_load_mem_basic" {
    const encoded = encode_load_mem(0, 0);
    try std.testing.expectEqual(@as(u32, 0x02), encoded); // LD opcode = 0x02
}

test "encode_load_mem_with_address" {
    const encoded = encode_load_mem(3, 0x0200);
    const expected: u32 = 0x02 | (3 << 8) | (0x0200 << 16);
    try std.testing.expectEqual(expected, encoded);
}

test "encode_load_mem_max_address" {
    const encoded = encode_load_mem(25, 0xFFFF);
    const expected: u32 = 0x02 | (25 << 8) | (0xFFFF << 16);
    try std.testing.expectEqual(expected, encoded);
}

test "encode_halt" {
    const encoded = encode_halt();
    try std.testing.expectEqual(@as(u32, 0x4D), encoded); // HALT opcode = 0x4D
}

test "encoder_produces_correct_opcodes" {
    try std.testing.expectEqual(@as(u8, 0x00), @intFromEnum(Opcode.NOP));
    try std.testing.expectEqual(@as(u8, 0x10), @intFromEnum(Opcode.ADD));
    try std.testing.expectEqual(@as(u8, 0x11), @intFromEnum(Opcode.SUB));
    try std.testing.expectEqual(@as(u8, 0x12), @intFromEnum(Opcode.MUL));
    try std.testing.expectEqual(@as(u8, 0x60), @intFromEnum(Opcode.DOT));
    try std.testing.expectEqual(@as(u8, 0x84), @intFromEnum(Opcode.LD_IMM));
    try std.testing.expectEqual(@as(u8, 0x02), @intFromEnum(Opcode.LD));
    try std.testing.expectEqual(@as(u8, 0x03), @intFromEnum(Opcode.ST));
    try std.testing.expectEqual(@as(u8, 0x4D), @intFromEnum(Opcode.HALT));
}
