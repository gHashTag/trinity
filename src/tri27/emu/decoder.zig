// @origin(spec:tri27_isa.zig) @regen(manual-impl)
// TRI-27 DECODER — Unified Instruction Format for TRI-27 ISA
// ═════════════════════════════════════════════════════════════════════════════
// This is the SINGLE SOURCE OF TRUTH for Instruction encoding/decoding.
// Both executor.zig and tri_emu_main.zig MUST use this definition.
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// The field table (which opcodes carry an immediate, which a src2, where
// BUNDLE3 keeps its third register) is not written here. It is the T736 table
// of gHashTag/t27 specs/isa/ternary_encoding.t27 (t27a_imm_form,
// t27a_src2_form, t27a_src1, t27a_src2, t27a_imm, t27a_encode), and
// tri27_encoding.zig is that spec's `t27c gen` output, byte for byte, never
// hand-edited. Recorded at the vendoring (gHashTag/t27#6507, gHashTag/t27#6789):
//   spec sha256        5e2c265a0972189ccf887d523abb86c13f9fa7ae6a1f35a59c20f1a1fc4796cd
//   generated sha256   da08bb8d44888dd747b11de4476d75395921f3fbc11754acb9532a218ffa3fad
//   (= gen_hash_zig of t27 .trinity/seals/isa_Tri27Encoding.json)
// To move it, regenerate from t27 (`t27c gen specs/isa/ternary_encoding.t27`)
// and replace the file; do not edit a field position in this one.
const fields = @import("tri27_encoding.zig");

/// ═══════════════════════════════════════════════════════════════════════════════
// TRI-27 OPCODE ENUM
// ═══════════════════════════════════════════════════════════════════════════════════
pub const Opcode = enum(u8) {
    // === ARITHMETIC (0x10-0x17) ===
    NOP = 0x00,
    MOV = 0x0F, // Move register to register
    ADD = 0x10,
    SUB = 0x11,
    MUL = 0x12,
    DIV = 0x13,
    INC = 0x14,
    DEC = 0x15,
    EXP = 0x16, // e^x (transcendental)
    SIN = 0x17, // sin(x) (transcendental)

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
    JGT = 0x44, // Jump if Greater Than
    JLT = 0x45, // Jump if Less Than
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

    // === STRING I/O (0x20-0x22) ===
    STR_LOAD = 0x20, // Load string literal
    STR_CONCAT = 0x21, // Concatenate strings
    STR_PRINT = 0x22, // Print string

    // === FILE I/O (0x23-0x25) ===
    FILE_READ = 0x23, // Read file to string
    FILE_WRITE = 0x24, // Write string to file
    FILE_EXISTS = 0x25, // Check file exists

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
/// Word format (the T736 table, see `fields` above):
///   [7:0]   = opcode (8 bits)
///   [12:8]  = dst (5 bits)
///   Immediate form (t27a_imm_form, SACR included):
///     [16:13] = src1 (4 bits)
///     [31:17] = immediate (15 bits, two's complement)
///   Three-operand form (t27a_src2_form: ADD..XOR, DOT, BIND, BUNDLE2, BUNDLE3):
///     [17:13] = src1 (5 bits)
///     [22:18] = src2 (5 bits)
///     [27:23] = third register of BUNDLE3, carried in `cond`
///   Every other opcode: [17:13] = src1 (5 bits)
/// An undefined opcode byte still decodes as NOP, as before.
pub fn decode(word: u32) Instruction {
    const opcode_val = @as(u8, @truncate(word & 0xFF));
    const opcode = std.meta.intToEnum(Opcode, opcode_val) catch Opcode.NOP;
    const op: u32 = @intFromEnum(opcode);

    return Instruction{
        .opcode = opcode,
        .dst = @truncate((word >> @intCast(fields.DST_SHIFT)) & fields.REG_MASK),
        .src1 = @truncate(fields.t27a_src1(word, op)),
        .src2 = @truncate(fields.t27a_src2(word, op)),
        // 15-bit two's complement, so always within i16.
        .immediate = @intCast(fields.t27a_imm(word, op)),
        .has_imm = fields.t27a_imm_form(op),
        .cond = if (opcode == .BUNDLE3) @truncate((word >> @intCast(fields.V3_SHIFT)) & fields.REG_MASK) else 0,
    };
}

/// Wrapper for external decode calls (backward compatibility)
pub fn decodeInstruction(word: u32) Instruction {
    return decode(word);
}

/// Encode Instruction to 32-bit word: `t27a_encode` of the T736 table. The
/// immediate is clamped to [-16384, 16383]; the third register of BUNDLE3 is
/// `cond`, as `decode` returns it.
pub fn encode(inst: Instruction) u32 {
    return fields.t27a_encode(
        @intFromEnum(inst.opcode),
        inst.dst,
        inst.src1,
        inst.src2,
        inst.cond,
        inst.immediate,
    );
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
    } else if (inst.opcode == .NOT or inst.opcode == .EXP or inst.opcode == .SIN) {
        // Unary NOT, EXP, SIN (transcendental)
        try writer.print(", t{d}", .{inst.src1});
    } else if (inst.opcode == .MOV) {
        // MOV is two-operand (dst, src1)
        try writer.print(", t{d}", .{inst.src1});
    } else if (inst.opcode == .STR_PRINT) {
        // STR_PRINT: dst, src1 (string address - unary)
        try writer.print(", t{d}", .{inst.src1});
    } else if (inst.opcode == .FILE_WRITE) {
        // FILE_WRITE: src1, src2 (path + data addresses, no dst)
        try writer.print("t{d}, t{d}", .{ inst.src1, inst.src2 });
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
        } else if (inst.opcode == .JGT or inst.opcode == .JLT) {
            // JGT/JLT: dst, src1 already printed, add offset
            try writer.print(", {d}", .{inst.immediate});
        } else if (inst.opcode == .STR_CONCAT) {
            // STR_CONCAT: dst, src1, src2 (three operands)
            try writer.print(", t{d}, t{d}", .{ inst.src1, inst.src2 });
        } else if (inst.opcode == .FILE_READ or inst.opcode == .FILE_EXISTS) {
            // FILE_READ/FILE_EXISTS: dst, src1 (two operands)
            try writer.print(", t{d}", .{inst.src1});
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

test "encoder: LDI roundtrip with 15-bit immediate" {
    const inst = Instruction{
        .opcode = .LDI,
        .dst = 2,
        .immediate = 42, // Positive value within 15-bit range
        .has_imm = true,
    };
    const word = encode(inst);
    const decoded = decode(word);
    try std.testing.expectEqual(Opcode.LDI, decoded.opcode);
    try std.testing.expectEqual(@as(u8, 2), decoded.dst);
    try std.testing.expectEqual(@as(i16, 42), decoded.immediate);
    try std.testing.expect(decoded.has_imm);
}

test "encoder: LDI roundtrip with negative 15-bit immediate" {
    const inst = Instruction{
        .opcode = .LDI,
        .dst = 3,
        .immediate = -1000, // Negative value within 15-bit range (-16384 to 16383)
        .has_imm = true,
    };
    const word = encode(inst);
    const decoded = decode(word);
    try std.testing.expectEqual(Opcode.LDI, decoded.opcode);
    try std.testing.expectEqual(@as(u8, 3), decoded.dst);
    try std.testing.expectEqual(@as(i16, -1000), decoded.immediate);
    try std.testing.expect(decoded.has_imm);
}

test "encoder: LDI roundtrip with positive 15-bit immediate" {
    const inst = Instruction{
        .opcode = .LDI,
        .dst = 5,
        .immediate = 1000, // Positive value within 15-bit range
        .has_imm = true,
    };
    const word = encode(inst);
    const decoded = decode(word);
    try std.testing.expectEqual(Opcode.LDI, decoded.opcode);
    try std.testing.expectEqual(@as(u8, 5), decoded.dst);
    try std.testing.expectEqual(@as(i16, 1000), decoded.immediate);
    try std.testing.expect(decoded.has_imm);
}

test "encoder: SACR roundtrip with every sacred operation mode" {
    // The decoder must read the SACR mode from the immediate field, and the
    // encoder must write it there; otherwise every decoded SACR runs mode 1.
    for ([_]i16{ 1, 2, 3, 4 }) |mode| {
        const inst = Instruction{
            .opcode = .SACR,
            .dst = 4,
            .src1 = 1,
            .immediate = mode,
            .has_imm = true,
        };
        const word = encode(inst);
        const decoded = decode(word);
        try std.testing.expectEqual(Opcode.SACR, decoded.opcode);
        try std.testing.expectEqual(@as(u8, 4), decoded.dst);
        try std.testing.expectEqual(@as(u8, 1), decoded.src1);
        try std.testing.expectEqual(mode, decoded.immediate);
        try std.testing.expect(decoded.has_imm);
    }
}

test "decoder: getOpcodeName" {
    try std.testing.expectEqualStrings("NOP", getOpcodeName(Opcode.NOP));
    try std.testing.expectEqualStrings("ADD", getOpcodeName(Opcode.ADD));
    try std.testing.expectEqualStrings("HALT", getOpcodeName(Opcode.HALT));
}

test "decoder: DOT, BIND and BUNDLE2 keep src2 (T736)" {
    // Before the T736 table these three read src2 as 0 and wrote none, while
    // the executor reads inst.src2 for all of them.
    for ([_]Opcode{ .DOT, .BIND, .BUNDLE2 }) |op| {
        const inst = Instruction{ .opcode = op, .dst = 3, .src1 = 17, .src2 = 29 };
        const decoded = decode(encode(inst));
        try std.testing.expectEqual(op, decoded.opcode);
        try std.testing.expectEqual(@as(u8, 3), decoded.dst);
        try std.testing.expectEqual(@as(u8, 17), decoded.src1);
        try std.testing.expectEqual(@as(u8, 29), decoded.src2);
        try std.testing.expect(!decoded.has_imm);
    }
}

test "decoder: BUNDLE3 keeps its third register (T736)" {
    const inst = Instruction{ .opcode = .BUNDLE3, .dst = 3, .src1 = 1, .src2 = 2, .cond = 31 };
    const decoded = decode(encode(inst));
    try std.testing.expectEqual(@as(u8, 1), decoded.src1);
    try std.testing.expectEqual(@as(u8, 2), decoded.src2);
    try std.testing.expectEqual(@as(u8, 31), decoded.cond);
}

test "decoder: the words gHashTag/t27 specs/isa/t27a.t27 pins" {
    // Same words `t27c asm` writes for the same text (gHashTag/t27#6507).
    const Pin = struct { word: u32, inst: Instruction };
    const pins = [_]Pin{
        .{ .word = 533264, .inst = .{ .opcode = .ADD, .dst = 3, .src1 = 1, .src2 = 2 } },
        .{ .word = 4294312708, .inst = .{ .opcode = .LDI, .dst = 3, .src1 = 0, .immediate = -5, .has_imm = true } },
        .{ .word = 8975, .inst = .{ .opcode = .MOV, .dst = 3, .src1 = 1 } },
        .{ .word = 926276, .inst = .{ .opcode = .JGT, .dst = 2, .src1 = 1, .immediate = 7, .has_imm = true } },
        .{ .word = 34087779, .inst = .{ .opcode = .BUNDLE3, .dst = 3, .src1 = 1, .src2 = 2, .cond = 4 } },
        .{ .word = 0, .inst = .{ .opcode = .NOP } },
    };
    for (pins) |p| {
        try std.testing.expectEqual(p.word, encode(p.inst));
        try std.testing.expectEqual(p.inst, decode(p.word));
    }
}
