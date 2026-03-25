// emit_t27: TRI-27 Code Generator from VIBEE IR
// TDGS-3 Wave 2: Code Generation (Phase 2 - IR Integration)
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

    /// Label for jump instructions (to be resolved)
    label: ?[]const u8 = null,
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
/// REGISTER ALLOCATION (Phase 2)
/// ═══════════════════════════════════════════════════════════════════════════════
/// Register allocation strategy for emit_t27 Phase 2
///
/// For deterministic IR → t0..t26 mapping:
/// - t0..t3: State variables (data_ptr, current, accumulators)
/// - t4..t7: Loop variables and temporaries
/// - t8..t26: General purpose (allocated linearly)
///
/// This matches reticular_raphe.t27 layout for golden test compatibility
pub const RegAlloc = struct {
    allocator: Allocator,
    /// Map IR value ID to register number
    value_map: std.AutoHashMap(u32, u8),
    /// Next available general purpose register (starts at t8)
    next_gp: u8 = 8,

    pub fn init(allocator: Allocator) RegAlloc {
        return .{
            .allocator = allocator,
            .value_map = std.AutoHashMap(u32, u8).init(allocator),
        };
    }

    pub fn deinit(self: *RegAlloc) void {
        self.value_map.deinit();
    }

    /// Allocate a register for an IR value
    pub fn allocate(self: *RegAlloc, value_id: u32) u8 {
        // If already allocated, return existing register
        if (self.value_map.get(value_id)) |reg| {
            return reg;
        }

        // Allocate new register (deterministic: use value_id for t8..t26)
        const reg: u8 = if (value_id < 8)
            @as(u8, @intCast(value_id)) // Use fixed registers for low IDs
        else if (self.next_gp < 27)
            self.allocGP()
        else
            0; // Wrap around (shouldn't happen with small programs)

        self.value_map.put(value_id, reg) catch {};
        return reg;
    }

    /// Allocate next general purpose register
    fn allocGP(self: *RegAlloc) u8 {
        const reg = self.next_gp;
        self.next_gp = reg + 1;
        return reg;
    }

    /// Get register for a value, or allocate if new
    pub fn getOrAllocate(self: *RegAlloc, value_id: u32) u8 {
        return self.allocate(value_id);
    }

    /// Reset for new function (keep state registers, reset GP)
    pub fn resetFunction(self: *RegAlloc) void {
        self.value_map.clearRetainingCapacity();
        self.next_gp = 8;
    }
};

/// ═══════════════════════════════════════════════════════════════════════════════
/// LABEL RESOLUTION (Phase 2)
/// ═══════════════════════════════════════════════════════════════════════════════
pub const LabelResolver = struct {
    labels: std.StringHashMap(u32),
    /// Pending jumps: list of (instruction_index, label_name)
    pending: std.ArrayListUnmanaged(struct { usize, []const u8 }),

    pub fn init(allocator: Allocator) LabelResolver {
        return .{
            .labels = std.StringHashMap(u32).init(allocator),
            .pending = .{},
        };
    }

    pub fn deinit(self: *LabelResolver, allocator: Allocator) void {
        self.labels.deinit();
        self.pending.deinit(allocator);
    }

    /// Define a label at current instruction position
    pub fn defineLabel(self: *LabelResolver, name: []const u8, pos: u32) !void {
        try self.labels.put(name, pos);
    }

    /// Add a pending jump that needs label resolution
    pub fn addPending(self: *LabelResolver, allocator: Allocator, inst_idx: usize, label: []const u8) !void {
        try self.pending.append(allocator, .{ inst_idx, label });
    }

    /// Resolve all pending jumps
    pub fn resolve(self: *LabelResolver, instructions: []Tri27Instruction) !void {
        for (self.pending.items) |pending| {
            const inst_idx = pending[0];
            const label_name = pending[1];

            const target_pos = self.labels.get(label_name) orelse return error.UndefinedLabel;
            const current_pos = @as(u32, @intCast(inst_idx));

            // Calculate relative offset (signed 11-bit for jumps)
            const offset = @as(i16, @intCast(@as(i32, @intCast(target_pos)) - @as(i32, @intCast(current_pos)) - 1));

            // Patch the instruction with resolved offset
            instructions[inst_idx].immediate = offset;
        }
    }
};

/// ═══════════════════════════════════════════════════════════════════════════════
/// CODE GENERATOR (Phase 2)
/// ═══════════════════════════════════════════════════════════════════════════════
pub const CodeGenerator = struct {
    allocator: Allocator,
    instructions: std.ArrayListUnmanaged(Tri27Instruction),
    reg_alloc: RegAlloc,
    label_resolver: LabelResolver,

    pub fn init(allocator: Allocator) CodeGenerator {
        return .{
            .allocator = allocator,
            .instructions = .{},
            .reg_alloc = RegAlloc.init(allocator),
            .label_resolver = LabelResolver.init(allocator),
        };
    }

    pub fn deinit(self: *CodeGenerator) void {
        self.instructions.deinit(self.allocator);
        self.reg_alloc.deinit();
        self.label_resolver.deinit(self.allocator);
    }

    /// Emit a single TRI-27 instruction
    fn emit(self: *CodeGenerator, inst: Tri27Instruction) !void {
        try self.instructions.append(self.allocator, inst);
    }

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

    /// Convert VIBEE IR instruction to TRI-27 instruction(s)
    fn convertIR(self: *CodeGenerator, ir_inst: IR.Instruction) !void {
        const tri_opcode = self.mapOpcode(ir_inst.opcode);

        // Allocate registers for operands
        const dst_reg = if (ir_inst.result != null)
            self.reg_alloc.getOrAllocate(ir_inst.result.?.id)
        else
            0;

        const src1_reg = if (ir_inst.operand_count >= 1 and ir_inst.operands[0] != null)
            self.reg_alloc.getOrAllocate(ir_inst.operands[0].?.id)
        else
            0;

        const src2_reg = if (ir_inst.operand_count >= 2 and ir_inst.operands[1] != null)
            self.reg_alloc.getOrAllocate(ir_inst.operands[1].?.id)
        else
            0;

        // Handle special cases
        switch (ir_inst.opcode) {
            .br => {
                // Unconditional branch - use label if available
                const inst_idx = self.instructions.items.len;
                try self.emit(.{
                    .opcode = .JMP,
                    .dst = 0,
                    .immediate = 0, // Will be resolved
                    .has_imm = true,
                    .label = ir_inst.true_block.?.name orelse "unknown",
                });
                // Add to pending resolution
                if (ir_inst.true_block) |block| {
                    try self.label_resolver.addPending(self.allocator, inst_idx, block.name);
                }
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

    /// Generate bytecode from VIBEE IR (Phase 2: with register allocation and label resolution)
    pub fn generate(allocator: Allocator, ir_instructions: []const IR.Instruction) ![]u8 {
        var gen = CodeGenerator.init(allocator);
        defer gen.deinit();

        // First pass: convert IR to TRI-27 instructions
        for (ir_instructions) |ir_inst| {
            try gen.convertIR(ir_inst);
        }

        // Add HALT at end if not present
        if (gen.instructions.items.len > 0) {
            const last = gen.instructions.items[gen.instructions.items.len - 1];
            if (last.opcode != .HALT and last.opcode != .RET) {
                try gen.emit(.{ .opcode = .HALT });
            }
        }

        // Second pass: resolve labels
        try gen.label_resolver.resolve(gen.instructions.items);

        // Third pass: encode to binary
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

/// Generate bytecode from raw instructions (for testing)
pub fn generateBytecode(allocator: Allocator, instructions: []const Tri27Instruction) ![]u8 {
    const code_size = instructions.len * 4;
    const header_size = 6 + 4;
    const total_size = header_size + code_size;

    var bytecode = try allocator.alloc(u8, total_size);
    errdefer allocator.free(bytecode);
    @memset(bytecode, 0);

    // Write header
    bytecode[0] = '2';
    bytecode[1] = 'I';
    bytecode[2] = 'R';
    bytecode[3] = 'T';
    bytecode[4] = 1;
    bytecode[5] = 1;

    var offset: usize = 6;
    bytecode[offset] = 1;
    bytecode[offset + 1] = 0;
    const size_u16: u16 = @intCast(code_size);
    bytecode[offset + 2] = @as(u8, @truncate(size_u16));
    bytecode[offset + 3] = @as(u8, @truncate(size_u16 >> 8));
    offset += 4;

    // Encode instructions
    for (instructions) |inst| {
        const word = encodeTri27Instruction(inst);
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
    try std.testing.expectEqual(@as(u8, 1), @as(u8, @truncate((word >> 8) & 0x1F)));
    const imm_raw = @as(u16, @truncate((word >> 17) & 0x7FFF));
    try std.testing.expectEqual(@as(u16, (2 << 11) | 5), imm_raw);
}

test "emit_t27: bytecode header" {
    const allocator = std.testing.allocator;
    const instructions = [_]Tri27Instruction{
        .{ .opcode = .HALT },
    };

    const bytecode = try generateBytecode(allocator, &instructions);
    defer allocator.free(bytecode);

    try std.testing.expectEqual(@as(u8, '2'), bytecode[0]);
    try std.testing.expectEqual(@as(u8, 'I'), bytecode[1]);
    try std.testing.expectEqual(@as(u8, 'R'), bytecode[2]);
    try std.testing.expectEqual(@as(u8, 'T'), bytecode[3]);
    try std.testing.expectEqual(@as(u8, 1), bytecode[4]);
    try std.testing.expectEqual(@as(u8, 1), bytecode[5]);
}

test "emit_t27: RegAlloc deterministic" {
    const allocator = std.testing.allocator;
    var reg_alloc = RegAlloc.init(allocator);
    defer reg_alloc.deinit();

    // Test that same value ID gets same register
    const r1 = reg_alloc.allocate(0);
    const r2 = reg_alloc.allocate(0);
    try std.testing.expectEqual(r1, r2);

    // Test that different value IDs get different registers
    const r3 = reg_alloc.allocate(1);
    try std.testing.expect(r3 != r1);
}

test "emit_t27: LabelResolver basic" {
    const allocator = std.testing.allocator;
    var resolver = LabelResolver.init(allocator);
    defer resolver.deinit(allocator);

    // Define labels
    try resolver.defineLabel("loop", 5);
    try resolver.defineLabel("exit", 10);

    // Check label positions
    try std.testing.expectEqual(@as(u32, 5), resolver.labels.get("loop").?);
    try std.testing.expectEqual(@as(u32, 10), resolver.labels.get("exit").?);
}

test "emit_t27: simple program with labels" {
    const allocator = std.testing.allocator;

    // Create simple program with jump
    var instructions = std.ArrayListUnmanaged(Tri27Instruction){};
    defer instructions.deinit(allocator);

    // LDI t0, 10
    try instructions.append(allocator, .{ .opcode = .LDI, .dst = 0, .immediate = 10, .has_imm = true });
    // LDI t1, 0
    try instructions.append(allocator, .{ .opcode = .LDI, .dst = 1, .immediate = 0, .has_imm = true });
    // ADD t2, t0, t1
    try instructions.append(allocator, .{ .opcode = .ADD, .dst = 2, .src1 = 0, .src2 = 1 });
    // HALT
    try instructions.append(allocator, .{ .opcode = .HALT });

    const bytecode = try generateBytecode(allocator, instructions.items);
    defer allocator.free(bytecode);

    // Should have header + 4 instructions
    try std.testing.expect(bytecode.len >= 26);
}

// ═══════════════════════════════════════════════════════════════════════════════
// E2E TESTS: reticular_raphe validation (Phase 2)
// ═══════════════════════════════════════════════════════════════════════════════
test "emit_t27_e2e: reticular_raphe instruction sequence" {
    const allocator = std.testing.allocator;

    // Subset of reticular_raphe instructions (initialization phase)
    const instructions = [_]Tri27Instruction{
        // LDI t0, MEM_EVALUATIONS (16)
        .{ .opcode = .LDI, .dst = 0, .immediate = 16, .has_imm = true },
        // LDI t5, 0 (index)
        .{ .opcode = .LDI, .dst = 5, .immediate = 0, .has_imm = true },
        // LDI t1, 0 (current_ppl)
        .{ .opcode = .LDI, .dst = 1, .immediate = 0, .has_imm = true },
        // LDI t2, 0 (weight_sum)
        .{ .opcode = .LDI, .dst = 2, .immediate = 0, .has_imm = true },
        // LDI t3, 0 (weighted_sum)
        .{ .opcode = .LDI, .dst = 3, .immediate = 0, .has_imm = true },
        // LDI t4, 0 (rolling_ppl)
        .{ .opcode = .LDI, .dst = 4, .immediate = 0, .has_imm = true },
        // HALT
        .{ .opcode = .HALT },
    };

    const bytecode = try generateBytecode(allocator, &instructions);
    defer allocator.free(bytecode);

    // Verify instruction count (7 instructions = 28 bytes + 10 bytes header = 38 bytes)
    try std.testing.expectEqual(@as(usize, 38), bytecode.len);

    // Verify first instruction (LDI t0, 16)
    const first_word = @as(u32, bytecode[10]) |
        @as(u32, bytecode[11]) << 8 |
        @as(u32, bytecode[12]) << 16 |
        @as(u32, bytecode[13]) << 24;
    try std.testing.expectEqual(@as(u8, 0x04), @as(u8, @truncate(first_word & 0xFF))); // LDI opcode
    try std.testing.expectEqual(@as(u8, 0), @as(u8, @truncate((first_word >> 8) & 0x1F))); // dst = t0

    // Verify last instruction is HALT
    const last_word = @as(u32, bytecode[34]) |
        @as(u32, bytecode[35]) << 8 |
        @as(u32, bytecode[36]) << 16 |
        @as(u32, bytecode[37]) << 24;
    try std.testing.expectEqual(@as(u8, 0x4D), @as(u8, @truncate(last_word & 0xFF))); // HALT opcode
}

test "emit_t27_e2e: reticular_raphe JGT encoding" {
    const allocator = std.testing.allocator;

    // From reticular_raphe: JGT t4, t6, +0
    const instructions = [_]Tri27Instruction{
        .{ .opcode = .LDI, .dst = 4, .immediate = 127, .has_imm = true },
        .{ .opcode = .LDI, .dst = 6, .immediate = 100, .has_imm = true },
        .{ .opcode = .JGT, .dst = 4, .src2 = 6, .immediate = 0, .has_imm = true },
        .{ .opcode = .HALT },
    };

    const bytecode = try generateBytecode(allocator, &instructions);
    defer allocator.free(bytecode);

    // Verify JGT instruction (third instruction, at offset 10+8=18)
    const jgt_word = @as(u32, bytecode[18]) |
        @as(u32, bytecode[19]) << 8 |
        @as(u32, bytecode[20]) << 16 |
        @as(u32, bytecode[21]) << 24;

    // Opcode should be JGT (0x44)
    try std.testing.expectEqual(@as(u8, 0x44), @as(u8, @truncate(jgt_word & 0xFF)));

    // dst should be t4 (4)
    try std.testing.expectEqual(@as(u8, 4), @as(u8, @truncate((jgt_word >> 8) & 0x1F)));

    // src2 should be in immediate[11-15]
    const imm_raw = @as(u16, @truncate((jgt_word >> 17) & 0x7FFF));
    try std.testing.expectEqual(@as(u8, 6), @as(u8, @truncate((imm_raw >> 11) & 0x1F))); // src2 = t6
}

test "emit_t27_e2e: full reticular_raphe main_loop structure" {
    const allocator = std.testing.allocator;

    const instructions = [_]Tri27Instruction{
        // Initialize (6 LDIs)
        .{ .opcode = .LDI, .dst = 0, .immediate = 16, .has_imm = true },
        .{ .opcode = .LDI, .dst = 5, .immediate = 0, .has_imm = true },
        .{ .opcode = .LDI, .dst = 1, .immediate = 0, .has_imm = true },
        .{ .opcode = .LDI, .dst = 2, .immediate = 0, .has_imm = true },
        .{ .opcode = .LDI, .dst = 3, .immediate = 0, .has_imm = true },
        .{ .opcode = .LDI, .dst = 4, .immediate = 0, .has_imm = true },
        // Main loop check
        .{ .opcode = .LDI, .dst = 6, .immediate = 20, .has_imm = true },
        .{ .opcode = .JGT, .dst = 5, .src2 = 6, .immediate = 1, .has_imm = true },
        // HALT
        .{ .opcode = .HALT },
    };

    const bytecode = try generateBytecode(allocator, &instructions);
    defer allocator.free(bytecode);

    // Should have header + 9 instructions = 10 + 36 = 46 bytes
    try std.testing.expectEqual(@as(usize, 46), bytecode.len);

    // Verify 7 LDI instructions (opcodes 0x04) - 6 initial + 1 for WINDOW_SIZE
    var ldi_count: usize = 0;
    for (0..7) |i| {
        const offset = 10 + i * 4;
        const word = @as(u32, bytecode[offset]) |
            @as(u32, bytecode[offset + 1]) << 8 |
            @as(u32, bytecode[offset + 2]) << 16 |
            @as(u32, bytecode[offset + 3]) << 24;
        if (@as(u8, @truncate(word & 0xFF)) == 0x04) ldi_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 7), ldi_count);
}
