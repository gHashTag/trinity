// emit_t27: TRI-27 Code Generator - Standalone Tests
// Tests that don't depend on the full VIBEE IR
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

/// ═══════════════════════════════════════════════════════════════════════════════
/// TRI-27 OPCODE ENUM (from decoder.zig)
/// ═══════════════════════════════════════════════════════════════════════════════
pub const Tri27Opcode = enum(u8) {
    // === ARITHMETIC ===
    NOP = 0x00,
    ADD = 0x10,
    SUB = 0x11,
    MUL = 0x12,
    DIV = 0x13,
    INC = 0x14,
    DEC = 0x15,

    // === LOGIC ===
    AND = 0x18,
    OR = 0x19,
    XOR = 0x1A,
    NOT = 0x1B,
    SHL = 0x1C,
    SHR = 0x1D,
    MOV = 0x1E,

    // === MEMORY ===
    LD = 0x02,
    ST = 0x03,
    LDI = 0x04,
    STI = 0x05,
    STF = 0x07,

    // === CONTROL ===
    JMP = 0x40,
    JZ = 0x41,
    JNZ = 0x42,
    CALL = 0x43,
    JGT = 0x44,
    JLT = 0x45,
    RET = 0x4B,
    HALT = 0x4D,
};

/// ═══════════════════════════════════════════════════════════════════════════════
/// TRI-27 INSTRUCTION STRUCT
/// ═══════════════════════════════════════════════════════════════════════════════
pub const Tri27Instruction = struct {
    opcode: Tri27Opcode,
    dst: u8 = 0,
    src1: u8 = 0,
    src2: u8 = 0,
    immediate: i16 = 0,
    has_imm: bool = false,
};

/// Encode TRI-27 instruction to 32-bit word
pub fn encodeTri27Instruction(inst: Tri27Instruction) u32 {
    var word: u32 = @intFromEnum(inst.opcode);
    word |= @as(u32, inst.dst) << 8;
    word |= @as(u32, inst.src1) << 13;

    // Special encoding for JGT/JLT: src2 goes in immediate[11-15], target in immediate[0-10]
    if (inst.opcode == .JGT or inst.opcode == .JLT) {
        // Pack src2 into upper 5 bits of immediate, target into lower 11 bits
        const imm_packed = (@as(u16, @intCast(inst.src2)) << 11) |
            @as(u16, @bitCast(@as(i16, @intCast(inst.immediate))));
        word |= @as(u32, imm_packed) << 17;
    } else {
        // Standard encoding: src2 in bits 18-22, immediate in bits 17-31
        word |= @as(u32, inst.src2) << 18;
        const imm_u16: u16 = @bitCast(inst.immediate);
        word |= @as(u32, imm_u16) << 17;
    }

    return word;
}

/// Generate minimal .t27 bytecode from instructions
pub fn generateBytecode(allocator: Allocator, instructions: []const Tri27Instruction) ![]u8 {
    const code_size = instructions.len * 4;
    const header_size = 6 + 4; // magic(4) + version(1) + section_count(1) + section_header(4)
    const total_size = header_size + code_size;

    var bytecode = try allocator.alloc(u8, total_size);
    errdefer allocator.free(bytecode);
    @memset(bytecode, 0);

    // Write header: "2IRT" magic (little-endian)
    bytecode[0] = '2';
    bytecode[1] = 'I';
    bytecode[2] = 'R';
    bytecode[3] = 'T';

    // Version
    bytecode[4] = 1;

    // Section count
    bytecode[5] = 1;

    // Section header: type(1) = CODE section
    var offset: usize = 6;
    bytecode[offset] = 1; // Section type: CODE
    bytecode[offset + 1] = 0; // Padding
    // Size (little-endian)
    const size_u16: u16 = @intCast(code_size);
    bytecode[offset + 2] = @as(u8, @truncate(size_u16));
    bytecode[offset + 3] = @as(u8, @truncate(size_u16 >> 8));
    offset += 4;

    // Encode instructions
    for (instructions) |inst| {
        const word = encodeTri27Instruction(inst);
        // Write little-endian
        bytecode[offset + 0] = @as(u8, @truncate(word));
        bytecode[offset + 1] = @as(u8, @truncate(word >> 8));
        bytecode[offset + 2] = @as(u8, @truncate(word >> 16));
        bytecode[offset + 3] = @as(u8, @truncate(word >> 24));
        offset += 4;
    }

    return bytecode;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════
test "emit_t27: encode NOP" {
    const inst = Tri27Instruction{
        .opcode = .NOP,
    };
    const word = encodeTri27Instruction(inst);
    try std.testing.expectEqual(@as(u32, 0x00000000), word);
}

test "emit_t27: encode LDI" {
    const inst = Tri27Instruction{
        .opcode = .LDI,
        .dst = 5,
        .immediate = 42,
        .has_imm = true,
    };
    const word = encodeTri27Instruction(inst);
    try std.testing.expectEqual(@as(u8, 0x04), @as(u8, @truncate(word & 0xFF)));
    try std.testing.expectEqual(@as(u8, 5), @as(u8, @truncate((word >> 8) & 0x1F)));
}

test "emit_t27: encode ADD" {
    const inst = Tri27Instruction{
        .opcode = .ADD,
        .dst = 1,
        .src1 = 2,
        .src2 = 3,
    };
    const word = encodeTri27Instruction(inst);
    try std.testing.expectEqual(@as(u8, 0x10), @as(u8, @truncate(word & 0xFF)));
    try std.testing.expectEqual(@as(u8, 1), @as(u8, @truncate((word >> 8) & 0x1F)));
    try std.testing.expectEqual(@as(u8, 2), @as(u8, @truncate((word >> 13) & 0x1F)));
    try std.testing.expectEqual(@as(u8, 3), @as(u8, @truncate((word >> 18) & 0x1F)));
}

test "emit_t27: encode JGT" {
    const inst = Tri27Instruction{
        .opcode = .JGT,
        .dst = 1, // src1
        .src2 = 2,
        .immediate = 5, // jump target
        .has_imm = true,
    };
    const word = encodeTri27Instruction(inst);
    try std.testing.expectEqual(@as(u8, 0x44), @as(u8, @truncate(word & 0xFF)));
    // dst = src1 = 1
    try std.testing.expectEqual(@as(u8, 1), @as(u8, @truncate((word >> 8) & 0x1F)));
    // src2 in bits 18-22
    try std.testing.expectEqual(@as(u8, 2), @as(u8, @truncate((word >> 18) & 0x1F)));
    // immediate in bits 17-31 (lower 11 bits = target)
    const imm_raw = @as(u16, @truncate((word >> 17) & 0x7FFF));
    // imm_raw = (src2 << 11) | target
    try std.testing.expectEqual(@as(u16, (2 << 11) | 5), imm_raw);
}

test "emit_t27: bytecode header" {
    const allocator = std.testing.allocator;
    const instructions = [_]Tri27Instruction{
        .{ .opcode = .HALT },
    };

    const bytecode = try generateBytecode(allocator, &instructions);
    defer allocator.free(bytecode);

    // Check magic
    try std.testing.expectEqual(@as(u8, '2'), bytecode[0]);
    try std.testing.expectEqual(@as(u8, 'I'), bytecode[1]);
    try std.testing.expectEqual(@as(u8, 'R'), bytecode[2]);
    try std.testing.expectEqual(@as(u8, 'T'), bytecode[3]);

    // Check version
    try std.testing.expectEqual(@as(u8, 1), bytecode[4]);

    // Check section count
    try std.testing.expectEqual(@as(u8, 1), bytecode[5]);
}

test "emit_t27: simple program" {
    const allocator = std.testing.allocator;
    const instructions = [_]Tri27Instruction{
        .{ .opcode = .LDI, .dst = 0, .immediate = 10, .has_imm = true },
        .{ .opcode = .LDI, .dst = 1, .immediate = 20, .has_imm = true },
        .{ .opcode = .ADD, .dst = 2, .src1 = 0, .src2 = 1 },
        .{ .opcode = .HALT },
    };

    const bytecode = try generateBytecode(allocator, &instructions);
    defer allocator.free(bytecode);

    // Should have at least header + 4 instructions
    try std.testing.expect(bytecode.len >= 26); // 10 bytes header + 16 bytes instructions
}

test "emit_t27: reticular_raphe subset" {
    const allocator = std.testing.allocator;
    // Simulate a subset of reticular_raphe instructions
    const instructions = [_]Tri27Instruction{
        .{ .opcode = .LDI, .dst = 0, .immediate = 16, .has_imm = true }, // LDI t0, MEM_EVALUATIONS
        .{ .opcode = .LDI, .dst = 5, .immediate = 0, .has_imm = true }, // LDI t5, 0 (index)
        .{ .opcode = .LDI, .dst = 1, .immediate = 0, .has_imm = true }, // LDI t1, 0
        .{ .opcode = .LDI, .dst = 2, .immediate = 0, .has_imm = true }, // LDI t2, 0
        .{ .opcode = .LDI, .dst = 3, .immediate = 0, .has_imm = true }, // LDI t3, 0
        .{ .opcode = .LDI, .dst = 4, .immediate = 0, .has_imm = true }, // LDI t4, 0
        .{ .opcode = .HALT },
    };

    const bytecode = try generateBytecode(allocator, &instructions);
    defer allocator.free(bytecode);

    // Verify the first instruction (LDI t0, 16)
    const first_word = std.mem.readInt(u32, bytecode[10..14], .little);
    try std.testing.expectEqual(@as(u8, 0x04), @as(u8, @truncate(first_word & 0xFF))); // LDI opcode
    try std.testing.expectEqual(@as(u8, 0), @as(u8, @truncate((first_word >> 8) & 0x1F))); // dst = t0
}
