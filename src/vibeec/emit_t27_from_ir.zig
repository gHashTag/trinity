// emit_t27_from_ir: VIBEE IR → TRI-27 bytecode converter
// TDGS-3 Wave 2: Phase 4 — Full pipeline integration
//
// Converts VIBEE IR to TRI-27 bytecode through emit_t27
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

const IR = @import("ir.zig");
const emit_t27 = @import("emit_t27.zig");

// ═══════════════════════════════════════════════════════════════════════════════
/// IR → TRI-27 OPCODE MAPPING
// ═══════════════════════════════════════════════════════════════════════════════
/// Maps VIBEE IR opcodes to TRI-27 opcodes (13-opcode subset)
const OpcodeMapping = struct {
    ir_op: IR.Opcode,
    tri27_op: emit_t27.Tri27Opcode,
    supported: bool = true,
};

const MAPPINGS = [_]OpcodeMapping{
    // Arithmetic
    .{ .ir_op = .add, .tri27_op = .ADD },
    .{ .ir_op = .sub, .tri27_op = .SUB }, // Not in minimal subset, will skip
    .{ .ir_op = .mul, .tri27_op = .MUL },
    // .{ .ir_op = .div, .tri27_op = .DIV }, // Not in minimal subset

    // Bitwise
    .{ .ir_op = .shr, .tri27_op = .SHR },
    // .{ .ir_op = .shl, .tri27_op = .SHL }, // Not in minimal subset

    // Comparison → conditional jumps
    .{ .ir_op = .lt, .tri27_op = .JLT }, // Special handling
    .{ .ir_op = .gt, .tri27_op = .JGT }, // Special handling

    // Memory
    .{ .ir_op = .load, .tri27_op = .LD },

    // Control flow
    .{ .ir_op = .br, .tri27_op = .JMP },
};

// ═══════════════════════════════════════════════════════════════════════════════
/// IR → TRI-27 CONVERTER
// ═══════════════════════════════════════════════════════════════════════════════
pub const IRToTri27Converter = struct {
    allocator: Allocator,
    instructions: std.ArrayListUnmanaged(emit_t27.Tri27Instruction),
    reg_alloc: emit_t27.RegAlloc,
    label_resolver: emit_t27.LabelResolver,

    // Block labels for jumps
    block_labels: std.StringHashMap(u32),

    pub fn init(allocator: Allocator) IRToTri27Converter {
        return .{
            .allocator = allocator,
            .instructions = .{},
            .reg_alloc = emit_t27.RegAlloc.init(allocator),
            .label_resolver = emit_t27.LabelResolver.init(allocator),
            .block_labels = std.StringHashMap(u32).init(allocator),
        };
    }

    pub fn deinit(self: *IRToTri27Converter) void {
        self.instructions.deinit(self.allocator);
        self.reg_alloc.deinit();
        self.label_resolver.deinit(self.allocator);
        self.block_labels.deinit();
    }

    /// Convert IR function to TRI-27 bytecode
    pub fn convertFunction(self: *IRToTri27Converter, func: *IR.Function) ![]u8 {
        // First pass: collect block labels
        for (func.blocks.items) |block| {
            const label = block.name orelse try std.fmt.allocPrint(self.allocator, "bb{d}", .{block.id});
            try self.block_labels.put(label, @intCast(block.id));
        }

        // Second pass: convert instructions
        for (func.blocks.items, 0..) |block, block_idx| {
            const block_label = block.name orelse try std.fmt.allocPrint(self.allocator, "bb{d}", .{block.id});
            _ = block_label;

            // Emit label marker (for jump resolution)
            if (block_idx > 0) { // Skip first block label (entry is implicit)
                const label_inst = emit_t27.Tri27Instruction{
                    .opcode = .NOP, // Placeholder for label
                    .label = block.name,
                };
                try self.instructions.append(self.allocator, label_inst);
            }

            for (block.instructions.items) |inst| {
                try self.convertInstruction(inst);
            }
        }

        // Add HALT at end
        try self.instructions.append(self.allocator, .{ .opcode = .HALT });

        // Resolve labels
        try self.label_resolver.resolve(self.instructions.items);

        // Generate bytecode
        return emit_t27.generateBytecode(self.allocator, self.instructions.items);
    }

    /// Convert single IR instruction to TRI-27
    fn convertInstruction(self: *IRToTri27Converter, inst: *IR.Instruction) !void {
        switch (inst.opcode) {
            // Constant loading
            .add => {
                // Binary operation: result = lhs + rhs
                if (inst.operand_count >= 2 and inst.result != null) {
                    const lhs = inst.operands[0] orelse return error.MissingOperand;
                    const rhs = inst.operands[1] orelse return error.MissingOperand;
                    const result = inst.result.?;

                    // Get registers
                    const dst_reg = self.reg_alloc.allocate(result.id);
                    const src1_reg = try self.getOperandReg(lhs);
                    const src2_reg = try self.getOperandReg(rhs);

                    try self.instructions.append(self.allocator, .{
                        .opcode = .ADD,
                        .dst = dst_reg,
                        .src1 = src1_reg,
                        .src2 = src2_reg,
                    });
                }
            },

            .mul => {
                // result = lhs * rhs
                if (inst.operand_count >= 2 and inst.result != null) {
                    const lhs = inst.operands[0] orelse return error.MissingOperand;
                    const rhs = inst.operands[1] orelse return error.MissingOperand;
                    const result = inst.result.?;

                    const dst_reg = self.reg_alloc.allocate(result.id);
                    const src1_reg = try self.getOperandReg(lhs);
                    const src2_reg = try self.getOperandReg(rhs);

                    try self.instructions.append(self.allocator, .{
                        .opcode = .MUL,
                        .dst = dst_reg,
                        .src1 = src1_reg,
                        .src2 = src2_reg,
                    });
                }
            },

            .shr => {
                // dst = src >> imm
                if (inst.operand_count >= 2 and inst.result != null) {
                    const src = inst.operands[0] orelse return error.MissingOperand;
                    const amt = inst.operands[1] orelse return error.MissingOperand;
                    const result = inst.result.?;

                    const dst_reg = self.reg_alloc.allocate(result.id);
                    const src_reg = try self.getOperandReg(src);

                    // Get immediate value if constant
                    const imm_val = if (amt.kind == .const_int)
                        @as(i16, @intCast(amt.const_data.int))
                    else
                        0;

                    try self.instructions.append(self.allocator, .{
                        .opcode = .SHR,
                        .dst = dst_reg,
                        .src1 = src_reg,
                        .immediate = imm_val,
                        .has_imm = true,
                    });
                }
            },

            .load => {
                // dst = mem[addr]
                if (inst.operand_count >= 1 and inst.result != null) {
                    const addr_ptr = inst.operands[0] orelse return error.MissingOperand;
                    const result = inst.result.?;

                    const dst_reg = self.reg_alloc.allocate(result.id);
                    // For now, assume address is in a register
                    const addr_reg = try self.getOperandReg(addr_ptr);

                    try self.instructions.append(self.allocator, .{
                        .opcode = .LD,
                        .dst = dst_reg,
                        .src1 = addr_reg,
                    });
                }
            },

            .br => {
                // Unconditional jump
                if (inst.true_block) |target| {
                    const label = target.name orelse try std.fmt.allocPrint(
                        self.allocator,
                        "bb{d}",
                        .{target.id},
                    );

                    try self.instructions.append(self.allocator, .{
                        .opcode = .JMP,
                        .label = label,
                        .immediate = 0, // Will be resolved by label_resolver
                    });
                }
            },

            .br_cond => {
                // Conditional jump (convert to JGT/JLT based on condition)
                if (inst.operand_count >= 1 and inst.true_block != null and inst.false_block != null) {
                    const cond = inst.operands[0] orelse return error.MissingOperand;
                    const cond_reg = try self.getOperandReg(cond);

                    const true_label = inst.true_block.?.name orelse try std.fmt.allocPrint(
                        self.allocator,
                        "bb{d}",
                        .{inst.true_block.?.id},
                    );

                    // JNZ cond, true_label (if cond != 0, jump to true)
                    try self.instructions.append(self.allocator, .{
                        .opcode = .JNZ,
                        .dst = cond_reg,
                        .label = true_label,
                        .immediate = 0,
                    });
                }
            },

            .ret => {
                // Return → HALT for main function
                try self.instructions.append(self.allocator, .{ .opcode = .HALT });
            },

            else => {
                // Unsupported opcode - emit NOP as placeholder
                // TODO: Add error reporting or skip
            },
        }

        // Handle constants at definition point
        if (inst.result != null) {
            const result = inst.result.?;
            if (result.kind == .const_int) {
                const reg = self.reg_alloc.allocate(result.id);
                const imm_val = @as(i16, @intCast(result.const_data.int));

                try self.instructions.append(self.allocator, .{
                    .opcode = .LDI,
                    .dst = reg,
                    .immediate = imm_val,
                    .has_imm = true,
                });
            }
        }
    }

    /// Get register for operand value
    fn getOperandReg(self: *IRToTri27Converter, val: *IR.Value) !u8 {
        if (val.kind == .const_int) {
            // Load immediate into temporary register
            const reg = self.reg_alloc.allocate(val.id);
            const imm_val = @as(i16, @intCast(val.const_data.int));

            try self.instructions.append(self.allocator, .{
                .opcode = .LDI,
                .dst = reg,
                .immediate = imm_val,
                .has_imm = true,
            });

            return reg;
        } else if (val.kind == .instruction) {
            // Get register for instruction result
            return self.reg_alloc.allocate(val.id);
        } else {
            // Default: allocate new register
            return self.reg_alloc.allocate(val.id);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
/// HIGH-LEVEL API
// ═══════════════════════════════════════════════════════════════════════════════

/// Convert IR Module to TRI-27 bytecode
pub fn irToTri27Bytecode(allocator: Allocator, module: *IR.Module) ![]u8 {
    // For now, just convert the first function (main)
    const func = module.functions.get("main") orelse {
        // If no main, get first function
        var iter = module.functions.valueIterator();
        const first_func = iter.next() orelse return error.NoFunctions;
        first_func;
    };

    var converter = IRToTri27Converter.init(allocator);
    defer converter.deinit();

    return converter.convertFunction(func);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "IRToTri27Converter: init and deinit" {
    const allocator = std.testing.allocator;
    var converter = IRToTri27Converter.init(allocator);
    defer converter.deinit();

    try std.testing.expectEqual(@as(usize, 0), converter.instructions.items.len);
}

test "IRToTri27Converter: simple add function" {
    const allocator = std.testing.allocator;

    // Create IR module
    var module = IR.Module.init(allocator, "test");
    defer module.deinit();

    const func = try module.createFunction("main", .i32);
    const entry = try func.createBlock("entry");

    // Create: result = 10 + 20
    const c1 = try func.constInt(.i32, 10);
    const c2 = try func.constInt(.i32, 20);
    const result = try func.buildBinOp(entry, .add, c1, c2, .i32);
    _ = result;

    try func.buildRet(entry, null);

    // Convert to TRI-27
    var converter = IRToTri27Converter.init(allocator);
    defer converter.deinit();

    const bytecode = try converter.convertFunction(func);
    defer allocator.free(bytecode);

    // Verify header
    try std.testing.expectEqual(@as(u8, '2'), bytecode[0]);
    try std.testing.expectEqual(@as(u8, 'I'), bytecode[1]);

    // Should have at least header + some instructions
    try std.testing.expect(bytecode.len > 10);
}
