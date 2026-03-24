// @origin(spec:tri27_isa.zig) @regen(manual-impl)
// TRI-27 DECODER — Unified Instruction Format for TRI-27 ISA
// ═════════════════════════════════════════════════════════════════════════════
// This is the SINGLE SOURCE OF TRUTH for Instruction encoding/decoding.
// Both executor.zig and tri_emu_main.zig MUST use this definition.
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

/// ═══════════════════════════════════════════════════════════════════════════════
// TRI-27 OPCODE ENUM
// ═══════════════════════════════════════════════════════════════════════════════════
pub const Opcode = enum(u8) {
    // === ARITHMETIC (0x10-0x17) ===
    NOP = 0x00,
    ADD = 0x10,
    SUB = 0x11,
    MUL = 0x12,
    DIV = 0x13,
    INC = 0x14,
    DEC = 0x15,

    // === LOGIC (0x18-0x1D) ===
    AND = 0x18,
    OR = 0x19,
    XOR = 0x1A,
    NOT = 0x1B,
    SHL = 0x1C,
    SHR = 0x1D,

    // === MEMORY (0x02-0x05) ===
    LD = 0x02,
    ST = 0x03,
    LDI = 0x04, // Load immediate
    STI = 0x05, // Store immediate

    // === CONTROL (0x40-0x4F) ===
    JMP = 0x40,
    JZ = 0x41,
    JNZ = 0x42,
    CALL = 0x43,
    RET = 0x4B,
    HALT = 0x4D,

    // === TERNARY (0x60-0x6D) ===
    DOT = 0x60, // Dot product (VSA/TF3)
    BIND = 0x61, // Bind two vectors
    BUNDLE2 = 0x62, // Bundle 2 vectors
    BUNDLE3 = 0x63, // Bundle 3 vectors

    // === SACRED (0x80-0x92) ===
    PHI_CONST = 0x80,
    PI_CONST = 0x81,
    E_CONST = 0x82,
    SACR = 0x83, // Sacred arithmetic operation

    // === EXECUTOR EXTENSIONS ===
    LD_IMM = 0x84, // Load immediate (executor compatibility)
    ADD3 = 0x85, // Ternary add (executor)
    SUB3 = 0x86, // Ternary sub (executor)
    CMP3 = 0x87, // Ternary compare (executor)
    SYSCALL = 0x88, // System call (executor)
};

/// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED INSTRUCTION STRUCT
// ═══════════════════════════════════════════════════════════════════════════════════
/// Single canonical Instruction format for TRI-27.
/// Field names chosen for compatibility with executor.zig:
///   - dst (not rd) : destination register
///   - src1, src2   : source registers
///   - immediate    : signed 16-bit immediate value
///   - has_imm      : whether instruction uses immediate
pub const Instruction = struct {
    /// Operation code (enum for type safety)
    opcode: Opcode,

    /// Destination register (0-26)
    dst: u8 = 0,

    /// Source register 1 (0-26)
    src1: u8 = 0,

    /// Source register 2 (0-26)
    src2: u8 = 0,

    /// Immediate value (16-bit signed)
    immediate: i16 = 0,

    /// Has immediate flag
    has_imm: bool = false,

    /// Condition code (for branches) - unused in most instructions
    cond: u8 = 0,
};

/// ═══════════════════════════════════════════════════════════════════════════════
// DECODER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════════
/// Decode 32-bit instruction word into Instruction struct
/// Word format:
///   [7:0]   = opcode (8 bits)
///   [12:8]  = dst (5 bits)
///   [17:13] = src1 (5 bits)
///   [22:18] = src2 (5 bits) OR v3_reg (for BUNDLE3)
///   [31:17] = immediate (16 bits, signed) OR v3_reg (for BUNDLE3)
pub fn decode(word: u32) Instruction {
    const opcode_val = @as(u8, @truncate(word & 0xFF));
    const opcode = std.meta.intToEnum(Opcode, opcode_val) catch Opcode.NOP;

    const dst = @as(u8, @truncate((word >> 8) & 0x1F));
    const src1 = @as(u8, @truncate((word >> 13) & 0x1F));

    // For BUNDLE3: bits 18-22 = src2, bits 23-27 = v3_reg (upper 5 bits)
    const src2_or_v3 = @as(u16, @truncate((word >> 18) & 0x3FFF));
    const src2 = @as(u8, @truncate(src2_or_v3 & 0x1F));
    const v3_reg = @as(u8, @truncate((src2_or_v3 >> 5) & 0x1F));

    // Decode 16-bit immediate (bits 31-17), sign-extend properly
    const imm_raw = @as(u16, @truncate((word >> 17) & 0xFFFF));
    const immediate: i16 = @bitCast(imm_raw);

    // Determine if instruction has immediate
    const has_imm = switch (opcode) {
        .LDI, .STI, .LD_IMM, .PHI_CONST, .PI_CONST, .E_CONST, .JMP, .JZ, .JNZ, .CALL, .RET, .BUNDLE3 => true,
        else => false,
    };

    return Instruction{
        .opcode = opcode,
        .dst = dst,
        .src1 = src1,
        .src2 = src2,
        .immediate = immediate,
        .has_imm = has_imm,
        .cond = if (opcode == .BUNDLE3) v3_reg else 0,
    };
}

/// Wrapper for external decode calls (backward compatibility)
pub fn decodeInstruction(word: u32) Instruction {
    return decode(word);
}

/// Encode Instruction to 32-bit word
pub fn encode(inst: Instruction) u32 {
    var word: u32 = @intFromEnum(inst.opcode);
    word |= @as(u32, inst.dst) << 8;
    word |= @as(u32, inst.src1) << 13;
    word |= @as(u32, inst.src2) << 18;

    // Encode 16-bit immediate (bits 31-17)
    const imm_bits: u16 = @bitCast(inst.immediate);
    word |= @as(u32, imm_bits) << 17;

    return word;
}

/// Get opcode name for debugging
pub fn getOpcodeName(opcode: Opcode) []const u8 {
    return @tagName(opcode);
}

/// Format instruction as assembly string
pub fn formatInstruction(inst: Instruction, writer: anytype) !void {
    try writer.print("{s} ", .{getOpcodeName(inst.opcode)});

    // Format destination
    try writer.print("t{d}", .{inst.dst});

    // Format based on opcode type
    if (inst.has_imm) {
        // Immediate instruction
        try writer.print(", {d}", .{inst.immediate});
    } else if (inst.opcode == .NOT) {
        // Unary NOT
        try writer.print(", t{d}", .{inst.src1});
    } else if (inst.opcode == .HALT or inst.opcode == .NOP or inst.opcode == .RET) {
        // No operands
    } else if (inst.opcode == .BUNDLE3) {
        // BUNDLE3 has three operands
        try writer.print(", t{d}, t{d}, t{d}", .{ inst.src1, inst.src2, inst.cond });
    } else {
        // Two-operand instruction
        try writer.print(", t{d}", .{inst.src1});
        if (inst.opcode == .CALL) {
            // CALL uses immediate (relative offset)
            try writer.print(", +{d}", .{inst.immediate});
        } else if (inst.opcode == .JMP or inst.opcode == .JZ or inst.opcode == .JNZ) {
            // Branches use immediate (offset)
            try writer.print(", {d}", .{inst.immediate});
        } else {
            try writer.print(", t{d}", .{inst.src2});
        }
    }
}

/// Get short format string for disassembly output
pub fn formatInstructionShort(inst: Instruction, buffer: []u8) []const u8 {
    var fbs = std.io.fixedBufferStream(buffer);
    formatInstruction(inst, fbs.writer()) catch return buffer;
    return fbs.getWritten();
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ════════════════════════════════════════════════════════════════════════════════════════

test "decoder: decode NOP" {
    const nop_word: u32 = 0x00000000;
    const inst = decode(nop_word);
    try std.testing.expectEqual(Opcode.NOP, inst.opcode);
    try std.testing.expectEqual(@as(u8, 0), inst.dst);
    try std.testing.expectEqual(@as(u8, 0), inst.src1);
    try std.testing.expectEqual(@as(u8, 0), inst.src2);
    try std.testing.expectEqual(@as(i16, 0), inst.immediate);
    try std.testing.expect(!inst.has_imm);
}

test "decoder: encode roundtrip ADD" {
    const inst = Instruction{
        .opcode = .ADD,
        .dst = 5,
        .src1 = 3,
        .src2 = 7,
    };
    const word = encode(inst);
    const decoded = decode(word);
    try std.testing.expectEqual(Opcode.ADD, decoded.opcode);
    try std.testing.expectEqual(@as(u8, 5), decoded.dst);
    try std.testing.expectEqual(@as(u8, 3), decoded.src1);
    try std.testing.expectEqual(@as(u8, 7), decoded.src2);
}

test "encoder_simple: LDI encodes correctly" {
    const inst = Instruction{
        .opcode = .LDI,
        .dst = 2,
        .immediate = -42,
        .has_imm = true,
    };
    const word = encode(inst);
    const decoded = decode(word);
    try std.testing.expectEqual(Opcode.LDI, decoded.opcode);
    try std.testing.expectEqual(@as(u8, 2), decoded.dst);
    try std.testing.expectEqual(@as(i16, -42), decoded.immediate);
    try std.testing.expect(decoded.has_imm);
}

test "decoder: getOpcodeName" {
    try std.testing.expectEqualStrings("NOP", getOpcodeName(Opcode.NOP));
    try std.testing.expectEqualStrings("ADD", getOpcodeName(Opcode.ADD));
    try std.testing.expectEqualStrings("HALT", getOpcodeName(Opcode.HALT));
}
