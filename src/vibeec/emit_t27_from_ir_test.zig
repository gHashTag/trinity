// emit_t27_from_ir test: VIBEE IR → TRI-27 bytecode converter
// TDGS-3 Wave 2: Phase 4 — Full pipeline integration
//
// Simplified tests that don't depend on full IR.zig (which has Zig 0.15 compatibility issues)
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

const emit_t27 = @import("emit_t27.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// MINIMAL IR STUB FOR TESTING
// ═══════════════════════════════════════════════════════════════════════════════

const MinimalIR = struct {
    opcode: enum {
        LDI,
        ADD,
        MUL,
        SHR,
        LD,
        JGT,
        JLT,
        JZ,
        JNZ,
        JMP,
        HALT,
    },
    dst: u8 = 0,
    src1: u8 = 0,
    src2: u8 = 0,
    immediate: i16 = 0,
    label: ?[]const u8 = null,
};

// ═══════════════════════════════════════════════════════════════════════════════
// MINIMAL IR → TRI-27 CONVERTER (simplified)
// ═══════════════════════════════════════════════════════════════════════════════

const MinimalIRToTri27 = struct {
    allocator: Allocator,
    instructions: std.ArrayListUnmanaged(emit_t27.Tri27Instruction),
    reg_alloc: emit_t27.RegAlloc,
    label_resolver: emit_t27.LabelResolver,
    next_value_id: u32 = 0,

    pub fn init(allocator: Allocator) MinimalIRToTri27 {
        return .{
            .allocator = allocator,
            .instructions = .{},
            .reg_alloc = emit_t27.RegAlloc.init(allocator),
            .label_resolver = emit_t27.LabelResolver.init(allocator),
        };
    }

    pub fn deinit(self: *MinimalIRToTri27) void {
        self.instructions.deinit(self.allocator);
        self.reg_alloc.deinit();
        self.label_resolver.deinit(self.allocator);
    }

    pub fn convertProgram(self: *MinimalIRToTri27, program: []const MinimalIR) ![]u8 {
        for (program) |inst| {
            try self.convertInstruction(inst);
        }

        // Resolve labels
        try self.label_resolver.resolve(self.instructions.items);

        // Generate bytecode
        return emit_t27.generateBytecode(self.allocator, self.instructions.items);
    }

    fn convertInstruction(self: *MinimalIRToTri27, ir_inst: MinimalIR) !void {
        const tri_op: emit_t27.Tri27Opcode = switch (ir_inst.opcode) {
            .LDI => .LDI,
            .ADD => .ADD,
            .MUL => .MUL,
            .SHR => .SHR,
            .LD => .LD,
            .JGT => .JGT,
            .JLT => .JLT,
            .JZ => .JZ,
            .JNZ => .JNZ,
            .JMP => .JMP,
            .HALT => .HALT,
        };

        const tri_inst = emit_t27.Tri27Instruction{
            .opcode = tri_op,
            .dst = ir_inst.dst,
            .src1 = ir_inst.src1,
            .src2 = ir_inst.src2,
            .immediate = ir_inst.immediate,
            .has_imm = ir_inst.immediate != 0,
            .label = ir_inst.label,
        };

        try self.instructions.append(self.allocator, tri_inst);
        self.next_value_id += 1;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "MinimalIRToTri27: simple LDI + HALT program" {
    const allocator = std.testing.allocator;

    const program = [_]MinimalIR{
        .{ .opcode = .LDI, .dst = 0, .immediate = 42 },
        .{ .opcode = .HALT },
    };

    var converter = MinimalIRToTri27.init(allocator);
    defer converter.deinit();

    const bytecode = try converter.convertProgram(&program);
    defer allocator.free(bytecode);

    // Verify header
    try std.testing.expectEqual(@as(u8, '2'), bytecode[0]);
    try std.testing.expectEqual(@as(u8, 'I'), bytecode[1]);
    try std.testing.expectEqual(@as(u8, 'R'), bytecode[2]);
    try std.testing.expectEqual(@as(u8, 'T'), bytecode[3]);

    // Verify size: header (10) + 2 instructions (8) = 18
    try std.testing.expectEqual(@as(usize, 18), bytecode.len);

    // Verify first instruction is LDI
    const first_word = @as(u32, bytecode[10]) | @as(u32, bytecode[11]) << 8 |
        @as(u32, bytecode[12]) << 16 | @as(u32, bytecode[13]) << 24;
    try std.testing.expectEqual(@as(u8, 0x04), @as(u8, @truncate(first_word & 0xFF))); // LDI
}

test "MinimalIRToTri27: ADD program with labels" {
    const allocator = std.testing.allocator;

    const program = [_]MinimalIR{
        .{ .opcode = .LDI, .dst = 0, .immediate = 10 },
        .{ .opcode = .LDI, .dst = 1, .immediate = 20 },
        .{ .opcode = .ADD, .dst = 2, .src1 = 0, .src2 = 1 },
        .{ .opcode = .HALT },
    };

    var converter = MinimalIRToTri27.init(allocator);
    defer converter.deinit();

    const bytecode = try converter.convertProgram(&program);
    defer allocator.free(bytecode);

    // Should have header + 4 instructions = 10 + 16 = 26 bytes
    try std.testing.expectEqual(@as(usize, 26), bytecode.len);

    // Verify ADD instruction (third instruction at offset 10 + 2*4 = 18)
    const add_word = @as(u32, bytecode[18]) | @as(u32, bytecode[19]) << 8 |
        @as(u32, bytecode[20]) << 16 | @as(u32, bytecode[21]) << 24;
    try std.testing.expectEqual(@as(u8, 0x10), @as(u8, @truncate(add_word & 0xFF))); // ADD
}

test "MinimalIRToTri27: conditional jump (JNZ)" {
    const allocator = std.testing.allocator;

    const program = [_]MinimalIR{
        .{ .opcode = .LDI, .dst = 0, .immediate = 1 },
        .{ .opcode = .JNZ, .dst = 0, .label = "skip" },
        .{ .opcode = .LDI, .dst = 1, .immediate = 99 },
        .{ .opcode = .JMP, .label = "end" },
        // "skip" label here
        .{ .opcode = .LDI, .dst = 2, .immediate = 42 },
        // "end" label here
        .{ .opcode = .HALT },
    };

    var converter = MinimalIRToTri27.init(allocator);
    defer converter.deinit();

    const bytecode = try converter.convertProgram(&program);
    defer allocator.free(bytecode);

    // Verify JNZ instruction (second instruction at offset 14)
    const jnz_word = @as(u32, bytecode[14]) | @as(u32, bytecode[15]) << 8 |
        @as(u32, bytecode[16]) << 16 | @as(u32, bytecode[17]) << 24;
    try std.testing.expectEqual(@as(u8, 0x42), @as(u8, @truncate(jnz_word & 0xFF))); // JNZ
}

test "MinimalIRToTri27: reticular_raphe subset via minimal IR" {
    const allocator = std.testing.allocator;

    // Mimic reticular_raphe initialization
    const program = [_]MinimalIR{
        .{ .opcode = .LDI, .dst = 0, .immediate = 16 }, // t0 = MEM_EVALUATIONS
        .{ .opcode = .LDI, .dst = 5, .immediate = 0 }, // t5 = index = 0
        .{ .opcode = .LDI, .dst = 1, .immediate = 0 }, // t1 = current_ppl = 0
        .{ .opcode = .LDI, .dst = 2, .immediate = 0 }, // t2 = weight_sum = 0
        .{ .opcode = .LDI, .dst = 3, .immediate = 0 }, // t3 = weighted_sum = 0
        .{ .opcode = .LDI, .dst = 4, .immediate = 0 }, // t4 = rolling_ppl = 0
        .{ .opcode = .LDI, .dst = 6, .immediate = 20 }, // t6 = WINDOW_SIZE
        .{ .opcode = .JLT, .dst = 5, .src2 = 6, .immediate = 1, .label = "loop_end" },
        .{ .opcode = .HALT },
    };

    var converter = MinimalIRToTri27.init(allocator);
    defer converter.deinit();

    const bytecode = try converter.convertProgram(&program);
    defer allocator.free(bytecode);

    // Verify all LDI instructions (opcodes 0x04)
    var ldi_count: usize = 0;
    for (0..7) |i| {
        const offset = 10 + i * 4;
        const word = @as(u32, bytecode[offset]) | @as(u32, bytecode[offset + 1]) << 8 |
            @as(u32, bytecode[offset + 2]) << 16 | @as(u32, bytecode[offset + 3]) << 24;
        if (@as(u8, @truncate(word & 0xFF)) == 0x04) ldi_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 7), ldi_count);

    // Verify JLT instruction
    const jlt_word = @as(u32, bytecode[38]) | @as(u32, bytecode[39]) << 8 |
        @as(u32, bytecode[40]) << 16 | @as(u32, bytecode[41]) << 24;
    try std.testing.expectEqual(@as(u8, 0x45), @as(u8, @truncate(jlt_word & 0xFF))); // JLT
}
