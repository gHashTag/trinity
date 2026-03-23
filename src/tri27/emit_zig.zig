// @origin(spec:tri27_backend.tri) @regen(manual-impl)
// TRI‑27 Zig Backend — Generate Zig code from TRI‑27 AST
// ══════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const Decoder = @import("emu/decoder.zig");
const Opcode = Decoder.Opcode;
const Instruction = Decoder.Instruction;

const print = std.debug.print;

// ════════════════════════════════════════════════════════

pub const GeneratorError = error{
    UnexpectedOpcode,
    MissingOperand,
    InvalidRegister,
};

// ═════════════════════════════════════════════════════════════════════════

pub fn generateZigFromBytes(allocator: Allocator, bytecode: []const u8) ![]const u8 {
    if (bytecode.len % 4 != 0) {
        print("Error: bytecode must be multiple of 4 bytes\n");
        return error.InvalidInstruction;
    }

    var generated = std.ArrayList(u8).init(allocator);
    defer generated.deinit();

    var pc: usize = 0;
    while (pc < bytecode.len) : (pc += 4) {
        const instruction_bytes = bytecode[pc .. pc + 4];
        const instr = try decodeInstruction(instruction_bytes) catch |err| {
            print("Error decoding instruction at offset {d}: {s}\n", .{ pc, err });
            return error.InvalidInstruction;
        };

        const mnemonic = opcodeToMnemonic(instr.opcode);
        const operands = operandsToString(instr);
        const comment = getComment(instr);

        try generated.writer().print("{s}    {X:0>4} {s} {s}{s}\n", .{
            pc,
            if (comment.len > 0) comment else "",
            mnemonic,
            operands,
        });
    }

    return generated.toOwnedSlice();
}

fn decodeInstruction(bytes: []const u8) Decoder.Instruction {
    const decoder = Decoder.Decoder{};
    var reader = Decoder.ByteReader.init(bytes);

    return decoder.decode(&reader) catch |err| {
        return error.InvalidInstruction;
    };
}

fn opcodeToMnemonic(op: Opcode) []const u8 {
    return switch (op) {
        .LDI_src1 => "LDI",
        .LDI_src2 => "LDI",
        .LDI_dst1 => "LDI",
        .LDI_dst2 => "LDI",
        .LDI_dst3 => "LDI",
        .LDR_src2 => "LDR",
        .LDR_dst3 => "LDR",
        .MOV => "MOV",
        .ST_R0_src => "ST",
        .LD_src => "LD",
        .ST_src => "ST",
        .LDI_dst => "LDI",
        .SAI_dst => "SAI",
        .SAI_dst_src => "SAI",
        .JUMP => "JUMP",
        .CALL => "CALL",
        .RET => "RET",
        .HALT => "HALT",
        .NOP => "NOP",
        .LDTI_src => "LDTI",
        .STO_LO => "STO",
        .PUSH => "PUSH",
        .POP_R1 => "POP",
        .JZ => "JZ",
        .JZ_INC => "JZ_INC",
        else => "UNK",
    };
}

fn operandsToString(instr: Instruction) []const u8 {
    var operands = std.ArrayList(u8).init(std.heap.page_allocator);
    defer operands.deinit();

    if (instr.has_src1) {
        operands.writer().print("r{d}", .{instr.src1}) catch |e| _ = {};
    }
    if (instr.has_src2) {
        operands.writer().print(", r{d}", .{instr.src2}) catch |e| _ = {};
    }
    if (instr.has_src3) {
        operands.writer().print(", r{d}", .{instr.src3}) catch |e| _ = {};
    }
    if (instr.has_dst1) {
        operands.writer().print(", r{d}", .{instr.dst1}) catch |e| _ = {};
    }
    if (instr.has_dst2) {
        operands.writer().print(", r{d}", .{instr.dst2}) catch |e| _ = {};
    }
    if (instr.has_dst3) {
        operands.writer().print(", r{d}", .{instr.dst3}) catch |e| _ = {};
    }

    return operands.toOwnedSlice();
}

fn getComment(instr: Instruction) []const u8 {
    return switch (instr.opcode) {
        .LDI_src1, .LDI_src2, .LDI_src3, .LDI_dst1, .LDI_dst2, .LDI_dst3, .LDR_src2, .LDR_dst3, .LDTI_src, .SAI_dst, .SAI_dst_src, .JUMP, .CALL, .RET => {
            // Control flow - show target
            return "";
        },
        .HALT, .NOP => {
            // System ops
            return "";
        },
        .MOV, .ST_R0_src, .LD_src, .ST_src => {
            // Register/memory ops
            return "";
        },
        .LDI_dst, .LDTI_src, .STO_LO, .PUSH, .POP_R1, .JZ, .JZ_INC => {
            // Stack/flag ops
            return "";
        },
        .SAI_dst_src => {
            // Memory indirect
            return "";
        },
        else => {
            // Data movement
            const src = if (instr.has_src1) instr.src1 else "";
            const dst = if (instr.has_dst1) instr.dst1 else "";
            if (src.len > 0 and dst.len > 0) {
                return std.fmt.allocPrint(allocator, "  // {s} ← {s}", .{ dst, src });
            } else {
                return "";
            }
        },
    };
}
