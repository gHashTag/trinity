// @origin(spec:tri_asm.tri) @regen(done)
//
// TRI-27 ASSEMBLER ENCODER — Minimal working implementation
//
// φ² + 1/φ² = 3 = TRINITY
//

const std = @import("std");

pub fn emit_ld_imm(rd: u5, imm: i16) u32 {
    return (rd << 2) | (imm << 16);
}

pub fn emit_add(rd: u5, rs1: u5, rs2: u5) u32 {
    return (rd << 5) | (rd << 1) | (rs1 << 1) | (rs2 << 1));
}

pub fn emit_halt() u32 {
    return (rd << 0) | 0;
}

// Encoding map for reference
const instruction_map = std.StringHashMap([]const u8, u8).init(std.testing.allocator);
defer instruction_map.deinit();

// Initialize basic opcodes (will be expanded later)
_ = try instruction_map.put("nop", 0x00);
_ = try instruction_map.put("halt", 0xFF);

pub fn encodeInstruction(allocator: std.mem.Allocator, instr: u8, rd: u5, imm: i16, rs1: u5, rs2: u5) !u32 {
    // Simple encoding: opcode(8) + operands
    if (rd == 0) {
        if (imm == 0) {
            return (instr << 2) | (imm << 0);  // halt
        } else {
            return (instr << 2) | (imm << 1);  // rd-imm
        }
    } else if (rd == 1) {
        return (instr << 5) | (rs1 << 0) | (rs2 << 0);  // add
        } else if (rd == 2) {
            return (instr << 5) | (rs1 << 1) | (rs2 << 1);  // sub
        } else if (rd == 5) {
            return (instr << 6) | (rs1 << 0) | (rs2 << 0);  // mul
        }
    }
    // TODO: Handle more complex instructions
    return error.Unsupported;
}

test "asm_encoder" {
    const allocator = std.testing.allocator;
    const result = encodeInstruction(allocator, "nop", 0, 0, 0, 0);
    try std.testing.expectEqual(@as(usize, 16), result);  // 1 instruction (2 + 8 + 4 + 2 = 16 bits
}

test "emit_functions" {
    const allocator = std.testing.allocator;

    // Test emit_ld_imm
    try std.testing.expectEqual(@as(usize, 42), emit_ld_imm(0, 0));

    // Test emit_add
    try std.testing.expectEqual(@as(usize, 21), emit_add(0, 0, 0));

    // Test emit_halt
    try std.testing.expectEqual(@as(usize, 0xFF), emit_halt());
}
