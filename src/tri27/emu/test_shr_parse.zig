const std = @import("std");
const Instruction = @import("decoder.zig").Instruction;
const Opcode = @import("decoder.zig").Opcode;
const encode = @import("decoder.zig").encode;
const decode = @import("decoder.zig").decode;

fn parseRegister(str: []const u8) !u8 {
    const trimmed = std.mem.trim(u8, str, " \t");
    if (std.mem.eql(u8, trimmed, "t0")) return 0;
    if (std.mem.eql(u8, trimmed, "t1")) return 1;
    if (std.mem.eql(u8, trimmed, "t2")) return 2;
    return error.InvalidRegister;
}

fn assembleLine(line: []const u8) !Instruction {
    var it = std.mem.splitScalar(u8, line, ' ');
    _ = std.mem.trim(u8, it.first(), " \t"); // op (unused)
    const rest = std.mem.trim(u8, it.rest(), " \t");

    var it2 = std.mem.splitScalar(u8, rest, ',');
    const dst_str = std.mem.trim(u8, it2.first(), " \t");
    const src1_str = std.mem.trim(u8, it2.rest(), " \t");

    const comma_idx = std.mem.indexOfScalar(u8, src1_str, ',') orelse return error.InvalidSyntax;
    const shift_str = std.mem.trim(u8, src1_str[comma_idx + 1 ..], " \t");
    const src1_str_trimmed = std.mem.trim(u8, src1_str[0..comma_idx], " \t");

    const dst = try parseRegister(dst_str);
    const src1 = try parseRegister(src1_str_trimmed);
    const shift = try std.fmt.parseInt(i16, shift_str, 10);

    return Instruction{
        .opcode = .SHR,
        .dst = dst,
        .src1 = src1,
        .immediate = shift,
        .has_imm = true,
    };
}

pub fn main() !void {
    const line = "SHR t0, t0, 1";
    const inst = try assembleLine(line);

    std.debug.print("SHR t0, t0, 1:\n", .{});
    std.debug.print("  dst={d}\n", .{inst.dst});
    std.debug.print("  src1={d}\n", .{inst.src1});
    std.debug.print("  immediate={d}\n", .{inst.immediate});

    const word = encode(inst);
    const decoded = decode(word);

    std.debug.print("After encode/decode:\n", .{});
    std.debug.print("  dst={d}\n", .{decoded.dst});
    std.debug.print("  src1={d}\n", .{decoded.src1});
    std.debug.print("  immediate={d}\n", .{decoded.immediate});
}
