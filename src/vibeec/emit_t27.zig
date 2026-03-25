// emit_t27: TRI-27 Code Generator from VIBEE IR
// TDGS-3 Wave 2: Code Generation
//
// Generates .t27 bytecode from VIBEE IR for TRI-27 ISA
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;
const IR = @import("ir.zig");

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

/// ═══════════════════════════════════════════════════════════════════════════════
/// LABEL TABLE
/// ═══════════════════════════════════════════════════════════════════════════════
const LabelTable = std.StringHashMap(u32);

/// ═══════════════════════════════════════════════════════════════════════════════
/// CODE GENERATOR
/// ═══════════════════════════════════════════════════════════════════════════════
pub const CodeGenerator = struct {
    allocator: Allocator,
    instructions: std.ArrayListUnmanaged(Tri27Instruction),
    labels: LabelTable,
    next_reg: u8 = 0,

    /// Map VIBEE IR opcode to TRI-27 opcode
    fn mapOpcode(ir_opcode: IR.Opcode) Tri27Opcode {
        return switch (ir_opcode) {
            // Arithmetic
            .add => .ADD,
            .sub => .SUB,
            .mul => .MUL,
            .div => .DIV,
            .neg => .NOP, // TODO: neg = SUB 0, src

            // Bitwise
            .band => .AND,
            .bor => .OR,
            .bxor => .XOR,
            .bnot => .NOT,
            .shl => .SHL,
            .shr => .SHR,

            // Memory
            .load => .LD,
            .store => .ST,

            // Control flow
            .br => .JMP,
            .br_cond => .JZ, // Default to JZ, will be resolved later
            .ret => .RET,

            // Type conversion (no direct TRI-27 equivalent, treat as MOV)
            .trunc, .zext, .sext => .MOV,

            else => .NOP, // Unsupported opcodes become NOP
        };
    }

    /// Allocate a virtual register (t0..t26)
    fn allocReg(self: *CodeGenerator) u8 {
        const reg = self.next_reg;
        if (reg < 27) {
            self.next_reg = reg + 1;
            return reg;
        }
        // TODO: Implement register spilling for >27 registers
        return 0; // For now, wrap around
    }

    /// Emit a single TRI-27 instruction
    fn emit(self: *CodeGenerator, inst: Tri27Instruction) !void {
        try self.instructions.append(self.allocator, inst);
    }

    /// Convert VIBEE IR instruction to TRI-27 instruction(s)
    fn convertIR(self: *CodeGenerator, ir_inst: IR.Instruction) !void {
        const tri_opcode = mapOpcode(ir_inst.opcode);

        // Get operands
        const dst_reg = if (ir_inst.result != null)
            @as(u8, 0) // TODO: Map IR value to register
        else
            0;

        const src1_reg = if (ir_inst.operand_count >= 1 and ir_inst.operands[0] != null)
            @as(u8, 1) // TODO: Map IR value to register
        else
            0;

        const src2_reg = if (ir_inst.operand_count >= 2 and ir_inst.operands[1] != null)
            @as(u8, 2) // TODO: Map IR value to register
        else
            0;

        // Handle special cases
        switch (ir_inst.opcode) {
            .br => {
                // Unconditional branch
                const offset: i16 = 0; // TODO: Resolve label
                try self.emit(.{
                    .opcode = .JMP,
                    .dst = 0,
                    .immediate = offset,
                    .has_imm = true,
                });
            },
            .ret => {
                try self.emit(.{ .opcode = .HALT });
            },
            .add, .sub, .mul => {
                try self.emit(.{
                    .opcode = tri_opcode,
                    .dst = dst_reg,
                    .src1 = src1_reg,
                    .src2 = src2_reg,
                });
            },
            .load => {
                try self.emit(.{
                    .opcode = .LD,
                    .dst = dst_reg,
                    .src1 = src1_reg, // Address register
                });
            },
            else => {
                // Default: emit with mapped opcode
                try self.emit(.{
                    .opcode = tri_opcode,
                    .dst = dst_reg,
                    .src1 = src1_reg,
                    .src2 = src2_reg,
                });
            },
        }
    }

    /// Generate bytecode from VIBEE IR
    pub fn generate(allocator: Allocator, ir_instructions: []const IR.Instruction) ![]u8 {
        var gen = CodeGenerator{
            .allocator = allocator,
            .instructions = .{},
            .labels = LabelTable.init(allocator),
        };
        defer gen.instructions.deinit(allocator);
        defer gen.labels.deinit();

        // First pass: convert IR to TRI-27 instructions
        for (ir_instructions, 0..) |ir_inst, i| {
            try gen.convertIR(ir_inst);
            _ = i;
        }

        // Add HALT at end if not present
        if (gen.instructions.items.len > 0) {
            const last = gen.instructions.items[gen.instructions.items.len - 1];
            if (last.opcode != .HALT and last.opcode != .RET) {
                try gen.emit(.{ .opcode = .HALT });
            }
        }

        // Second pass: resolve labels and encode to binary
        const code_size = gen.instructions.items.len * 4;
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
        for (gen.instructions.items) |inst| {
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
};

/// ═══════════════════════════════════════════════════════════════════════════════
/// PUBLIC API
/// ═══════════════════════════════════════════════════════════════════════════════
/// Emit .t27 bytecode from VIBEE IR
pub fn emitT27(allocator: Allocator, ir: []const IR.Instruction) ![]u8 {
    return CodeGenerator.generate(allocator, ir);
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
    // src2 in immediate upper bits (bits 11-15 of 15-bit immediate)
    const imm_raw = @as(u16, @truncate((word >> 17) & 0x7FFF));
    try std.testing.expectEqual(@as(u16, (2 << 11) | 5), imm_raw);
}

test "emit_t27: bytecode header" {
    const allocator = std.testing.allocator;
    const ir = [_]IR.Instruction{
        IR.Instruction.init(0, .ret),
    };

    const bytecode = try emitT27(allocator, &ir);
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
    const ir = [_]IR.Instruction{
        IR.Instruction.init(0, .add),
    };

    const bytecode = try emitT27(allocator, &ir);
    defer allocator.free(bytecode);

    // Should have at least header + one instruction
    try std.testing.expect(bytecode.len >= 16); // 10 bytes header + 4 bytes instruction
}
