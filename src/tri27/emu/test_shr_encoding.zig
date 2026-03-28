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
        .immediate = 1,
        .has_imm = true,
    };

    const word = encode(inst);
    const decoded = decode(word);

    std.debug.print("Original immediate: {d}\n", .{inst.immediate});
    std.debug.print("Encoded word: 0x{x:0>8}\n", .{word});
    std.debug.print("Decoded immediate: {d}\n", .{decoded.immediate});
    std.debug.print("Decoded opcode: {s}\n", .{@tagName(decoded.opcode)});
}
