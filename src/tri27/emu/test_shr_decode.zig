const std = @import("std");
const Instruction = @import("decoder.zig").Instruction;
const Opcode = @import("decoder.zig").Opcode;
const encode = @import("decoder.zig").encode;

// Inline the decode function to add debug output
fn decodeWithDebug(word: u32) Instruction {
    const opcode_val = @as(u8, @truncate(word & 0xFF));
    const opcode = std.meta.intToEnum(Opcode, opcode_val) catch Opcode.NOP;

    const dst = @as(u8, @truncate((word >> 8) & 0x1F));
    const src1 = @as(u8, @truncate((word >> 13) & 0x1F));

    // For BUNDLE3: bits 18-22 = src2, bits 23-27 = v3_reg (upper 5 bits)
    const src2_or_v3 = @as(u16, @truncate((word >> 18) & 0x3FFF));
    const src2 = @as(u8, @truncate(src2_or_v3 & 0x1F));
    const v3_reg = @as(u8, @truncate((src2_or_v3 >> 5) & 0x1F));

    // Decode 15-bit immediate (bits 31-17), sign-extend to i16
    const imm_raw = @as(u16, @truncate((word >> 17) & 0x7FFF)); // 15 bits
    const immediate: i16 = if (imm_raw & 0x4000 != 0) @as(i16, @bitCast(imm_raw | 0x8000)) else @as(i16, @intCast(imm_raw));

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

pub fn main() !void {
    const inst = Instruction{
        .opcode = .SHR,
        .dst = 0,
        .src1 = 0,
        .src2 = 0,
        .immediate = 1,
        .has_imm = true,
    };

    const word = encode(inst);

    std.debug.print("SHR instruction:\n", .{});
    std.debug.print("  Input: dst={d}, src1={d}, src2={d}, imm={d}\n", .{ inst.dst, inst.src1, inst.src2, inst.immediate });
    std.debug.print("  Encoded word: 0x{x}\n", .{word});
    std.debug.print("  Word bits 13-17: {d} (0b{b:0>5})\n", .{ @as(u5, @truncate((word >> 13) & 0x1F)), @as(u5, @truncate((word >> 13) & 0x1F)) });

    const decoded = decodeWithDebug(word);
    std.debug.print("  Decoded: dst={d}, src1={d}, src2={d}, imm={d}\n", .{ decoded.dst, decoded.src1, decoded.src2, decoded.immediate });
}
