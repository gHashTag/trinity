const std = @import("std");
const Instruction = @import("decoder.zig").Instruction;
const Opcode = @import("decoder.zig").Opcode;
const encode = @import("decoder.zig").encode;
const decode = @import("decoder.zig").decode;

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
    std.debug.print("  dst={d}, src1={d}, src2={d}, imm={d}\n", .{ inst.dst, inst.src1, inst.src2, inst.immediate });
    std.debug.print("  Encoded word: 0x{x:0>8} (binary: 0b{b:0>32})\n", .{ word, word });

    const decoded = decode(word);
    std.debug.print("  Decoded: dst={d}, src1={d}, src2={d}, imm={d}\n", .{ decoded.dst, decoded.src1, decoded.src2, decoded.immediate });

    // Manual decode
    std.debug.print("\nManual decode:\n", .{});
    const opcode_val: u8 = @truncate(word & 0xFF);
    std.debug.print("  opcode (bits 0-7): {d} (0b{b:0>8})\n", .{ opcode_val, opcode_val });
    const dst_dec: u8 = @truncate((word >> 8) & 0x1F);
    std.debug.print("  dst (bits 8-12): {d} (0b{b:0>5})\n", .{ dst_dec, dst_dec });
    const src1_dec: u8 = @truncate((word >> 13) & 0x1F);
    std.debug.print("  src1 (bits 13-17): {d} (0b{b:0>5})\n", .{ src1_dec, src1_dec });
}
