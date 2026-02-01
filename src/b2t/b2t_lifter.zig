// B2T Lifter - Binary-to-Ternary Converter
// Lifts disassembled instructions to TVC IR
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const b2t_disasm = @import("b2t_disasm.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// TVC IR TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const TVCType = enum {
    void,
    trit, // Single trit: -1, 0, +1
    trit8, // 8 trits
    trit16, // 16 trits
    trit32, // 32 trits (≈ i32)
    trit64, // 64 trits (≈ i64)
    trit_ptr, // Ternary pointer
    trit_vec, // Vector of trits
};

pub const TVCOpcode = enum {
    // Ternary Logic (native 3-state operations)
    t_not, // Ternary NOT: -1→+1, 0→0, +1→-1
    t_and, // Ternary AND: min(a, b)
    t_or, // Ternary OR: max(a, b)
    t_xor, // Ternary XOR: a * b
    t_implies, // Ternary implies

    // Ternary Arithmetic
    t_add, // Ternary addition
    t_sub, // Ternary subtraction
    t_mul, // Ternary multiplication
    t_div, // Ternary division
    t_mod, // Ternary modulo
    t_neg, // Ternary negation

    // Ternary Comparison (returns trit: -1, 0, +1)
    t_cmp, // Compare: -1 if a<b, 0 if a==b, +1 if a>b
    t_eq, // Equal: 1 if equal, else 0
    t_ne, // Not equal: 1 if not equal, else 0
    t_lt, // Less than: 1 if a<b, else 0
    t_gt, // Greater than: 1 if a>b, else 0
    t_le, // Less or equal: 1 if a<=b, else 0
    t_ge, // Greater or equal: 1 if a>=b, else 0
    t_eqz, // Equal to zero: 1 if a==0, else 0

    // Memory
    t_load, // Load from ternary memory
    t_store, // Store to ternary memory
    t_alloca, // Allocate on stack

    // Control Flow
    t_call, // Call function
    t_ret, // Return
    t_br, // Unconditional branch to label
    t_br_if, // Conditional branch (if != 0)
    t_br_trit, // Ternary branch (3-way)
    t_switch, // Switch on trit value
    t_label, // Label marker (branch target)

    // Stack Operations (for WASM compatibility)
    t_push, // Push to stack
    t_pop, // Pop from stack
    t_dup, // Duplicate top
    t_drop, // Drop top

    // Constants
    t_const, // Load constant

    // Conversion
    t_binary_to_trit, // Convert binary to ternary
    t_trit_to_binary, // Convert ternary to binary

    // Local/Argument access
    t_get_local, // Get local variable/argument
    t_set_local, // Set local variable

    // Conditional
    t_select, // Select: cond ? val1 : val2

    // Native Ternary Operations
    t_tadd, // Balanced ternary add
    t_tsub, // Balanced ternary subtract
    t_tmul, // Balanced ternary multiply
    t_tdiv, // Balanced ternary divide
    t_tcmp, // Balanced ternary compare
    t_tneg, // Balanced ternary negate

    // Special
    t_nop, // No operation
    t_unreachable, // Unreachable code
};

pub const TVCValue = struct {
    id: u32,
    value_type: TVCType,
    is_const: bool,
    const_value: i64,
};

pub const TVCInstruction = struct {
    opcode: TVCOpcode,
    dest: ?u32, // Destination value ID
    operands: [4]u32, // Operand value IDs
    operand_count: u8,
    source_address: u64, // Original binary address
};

pub const TVCBlock = struct {
    id: u32,
    instructions: std.ArrayList(TVCInstruction),
    successors: std.ArrayList(u32),
    predecessors: std.ArrayList(u32),

    pub fn init(allocator: std.mem.Allocator, block_id: u32) TVCBlock {
        return TVCBlock{
            .id = block_id,
            .instructions = std.ArrayList(TVCInstruction).init(allocator),
            .successors = std.ArrayList(u32).init(allocator),
            .predecessors = std.ArrayList(u32).init(allocator),
        };
    }

    pub fn deinit(self: *TVCBlock) void {
        self.instructions.deinit();
        self.successors.deinit();
        self.predecessors.deinit();
    }
};

pub const TVCFunction = struct {
    id: u32,
    name: []const u8,
    params: std.ArrayList(TVCType),
    return_type: TVCType,
    locals: std.ArrayList(TVCType),
    blocks: std.ArrayList(TVCBlock),
    values: std.ArrayList(TVCValue),
    next_value_id: u32,

    pub fn init(allocator: std.mem.Allocator, func_id: u32) TVCFunction {
        return TVCFunction{
            .id = func_id,
            .name = "",
            .params = std.ArrayList(TVCType).init(allocator),
            .return_type = .void,
            .locals = std.ArrayList(TVCType).init(allocator),
            .blocks = std.ArrayList(TVCBlock).init(allocator),
            .values = std.ArrayList(TVCValue).init(allocator),
            .next_value_id = 0,
        };
    }

    pub fn deinit(self: *TVCFunction) void {
        self.params.deinit();
        self.locals.deinit();
        for (self.blocks.items) |*block| {
            block.deinit();
        }
        self.blocks.deinit();
        self.values.deinit();
    }

    pub fn newValue(self: *TVCFunction, value_type: TVCType) !u32 {
        const id = self.next_value_id;
        self.next_value_id += 1;
        try self.values.append(TVCValue{
            .id = id,
            .value_type = value_type,
            .is_const = false,
            .const_value = 0,
        });
        return id;
    }

    pub fn newConst(self: *TVCFunction, value_type: TVCType, value: i64) !u32 {
        const id = self.next_value_id;
        self.next_value_id += 1;
        try self.values.append(TVCValue{
            .id = id,
            .value_type = value_type,
            .is_const = true,
            .const_value = value,
        });
        return id;
    }
};

pub const TVCModule = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    functions: std.ArrayList(TVCFunction),
    globals: std.ArrayList(TVCValue),
    entry_point: ?u32,

    pub fn init(allocator: std.mem.Allocator) TVCModule {
        return TVCModule{
            .allocator = allocator,
            .name = "module",
            .functions = std.ArrayList(TVCFunction).init(allocator),
            .globals = std.ArrayList(TVCValue).init(allocator),
            .entry_point = null,
        };
    }

    pub fn deinit(self: *TVCModule) void {
        for (self.functions.items) |*func| {
            func.deinit();
        }
        self.functions.deinit();
        self.globals.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LIFTER
// ═══════════════════════════════════════════════════════════════════════════════

// Block info for control flow
pub const BlockType = enum {
    block, // br jumps to end
    loop, // br jumps to start
    if_block, // br jumps to end
};

pub const BlockInfo = struct {
    block_type: BlockType,
    start_label: u32, // Label at start (for loop)
    end_label: u32, // Label at end (for block/if)
};

pub const Lifter = struct {
    allocator: std.mem.Allocator,
    module: TVCModule,
    stack: std.ArrayList(u32), // Value stack for WASM
    block_stack: std.ArrayList(BlockInfo), // Block stack for control flow
    next_label: u32, // Next label ID

    pub fn init(allocator: std.mem.Allocator) Lifter {
        return Lifter{
            .allocator = allocator,
            .module = TVCModule.init(allocator),
            .stack = std.ArrayList(u32).init(allocator),
            .block_stack = std.ArrayList(BlockInfo).init(allocator),
            .next_label = 0,
        };
    }

    pub fn deinit(self: *Lifter) void {
        self.module.deinit();
        self.stack.deinit();
        self.block_stack.deinit();
    }

    fn newLabel(self: *Lifter) u32 {
        const label = self.next_label;
        self.next_label += 1;
        return label;
    }

    fn getBranchTarget(self: *Lifter, depth: u32) ?u32 {
        if (depth >= self.block_stack.items.len) return null;
        const idx = self.block_stack.items.len - 1 - depth;
        const block_info = self.block_stack.items[idx];
        return switch (block_info.block_type) {
            .loop => block_info.start_label, // Loop: jump to start
            .block, .if_block => block_info.end_label, // Block/if: jump to end
        };
    }

    pub fn lift(self: *Lifter, disasm: *const b2t_disasm.DisassemblyResult) !*TVCModule {
        self.module.entry_point = if (disasm.entry_point > 0) @intCast(disasm.entry_point) else null;

        for (disasm.functions.items) |wasm_func| {
            try self.liftFunction(&wasm_func);
        }

        return &self.module;
    }

    fn liftFunction(self: *Lifter, wasm_func: *const b2t_disasm.WasmFunction) !void {
        var func = TVCFunction.init(self.allocator, wasm_func.index);

        // Create entry block
        var entry_block = TVCBlock.init(self.allocator, 0);

        // Add locals
        for (wasm_func.locals.items) |local| {
            var i: u32 = 0;
            while (i < local.count) : (i += 1) {
                const local_type = wasmTypeToTVC(local.value_type);
                try func.locals.append(local_type);
            }
        }

        // Clear stack for this function
        self.stack.clearRetainingCapacity();

        // Lift each instruction
        for (wasm_func.instructions.items) |inst| {
            try self.liftInstruction(&func, &entry_block, &inst);
        }

        try func.blocks.append(entry_block);
        try self.module.functions.append(func);
    }

    fn liftInstruction(self: *Lifter, func: *TVCFunction, block: *TVCBlock, inst: *const b2t_disasm.Instruction) !void {
        switch (inst.opcode) {
            // Constants
            0x41 => { // i32.const
                const value = inst.operands[0].value;
                const val_id = try func.newConst(.trit32, value);
                try self.stack.append(val_id);

                try block.instructions.append(TVCInstruction{
                    .opcode = .t_const,
                    .dest = val_id,
                    .operands = .{ @intCast(value & 0xFFFFFFFF), 0, 0, 0 },
                    .operand_count = 1,
                    .source_address = inst.address,
                });
            },

            0x42 => { // i64.const
                const value = inst.operands[0].value;
                const val_id = try func.newConst(.trit64, value);
                try self.stack.append(val_id);

                try block.instructions.append(TVCInstruction{
                    .opcode = .t_const,
                    .dest = val_id,
                    .operands = .{ @intCast(value & 0xFFFFFFFF), @intCast((value >> 32) & 0xFFFFFFFF), 0, 0 },
                    .operand_count = 2,
                    .source_address = inst.address,
                });
            },

            // Arithmetic - Binary to Ternary conversion
            0x6A => { // i32.add → t_add
                if (self.stack.items.len >= 2) {
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    const result = try func.newValue(.trit32);
                    try self.stack.append(result);

                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_add,
                        .dest = result,
                        .operands = .{ a, b, 0, 0 },
                        .operand_count = 2,
                        .source_address = inst.address,
                    });
                }
            },

            0x6B => { // i32.sub → t_sub
                if (self.stack.items.len >= 2) {
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    const result = try func.newValue(.trit32);
                    try self.stack.append(result);

                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_sub,
                        .dest = result,
                        .operands = .{ a, b, 0, 0 },
                        .operand_count = 2,
                        .source_address = inst.address,
                    });
                }
            },

            0x6C => { // i32.mul → t_mul
                if (self.stack.items.len >= 2) {
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    const result = try func.newValue(.trit32);
                    try self.stack.append(result);

                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_mul,
                        .dest = result,
                        .operands = .{ a, b, 0, 0 },
                        .operand_count = 2,
                        .source_address = inst.address,
                    });
                }
            },

            0x6D, 0x6E => { // i32.div_s, i32.div_u → t_div
                if (self.stack.items.len >= 2) {
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    const result = try func.newValue(.trit32);
                    try self.stack.append(result);

                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_div,
                        .dest = result,
                        .operands = .{ a, b, 0, 0 },
                        .operand_count = 2,
                        .source_address = inst.address,
                    });
                }
            },

            // Logic - Binary to Ternary (KILLER OPTIMIZATION!)
            0x71 => { // i32.and → t_and (ternary MIN)
                if (self.stack.items.len >= 2) {
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    const result = try func.newValue(.trit32);
                    try self.stack.append(result);

                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_and,
                        .dest = result,
                        .operands = .{ a, b, 0, 0 },
                        .operand_count = 2,
                        .source_address = inst.address,
                    });
                }
            },

            0x72 => { // i32.or → t_or (ternary MAX)
                if (self.stack.items.len >= 2) {
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    const result = try func.newValue(.trit32);
                    try self.stack.append(result);

                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_or,
                        .dest = result,
                        .operands = .{ a, b, 0, 0 },
                        .operand_count = 2,
                        .source_address = inst.address,
                    });
                }
            },

            0x73 => { // i32.xor → t_xor (ternary MUL)
                if (self.stack.items.len >= 2) {
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    const result = try func.newValue(.trit32);
                    try self.stack.append(result);

                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_xor,
                        .dest = result,
                        .operands = .{ a, b, 0, 0 },
                        .operand_count = 2,
                        .source_address = inst.address,
                    });
                }
            },

            // Comparison - TERNARY 3-WAY COMPARISON!
            0x46 => { // i32.eq → t_eq
                if (self.stack.items.len >= 2) {
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    const result = try func.newValue(.trit); // Result is single trit!
                    try self.stack.append(result);

                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_eq,
                        .dest = result,
                        .operands = .{ a, b, 0, 0 },
                        .operand_count = 2,
                        .source_address = inst.address,
                    });
                }
            },

            0x45 => { // i32.eqz → compare with zero
                if (self.stack.items.len >= 1) {
                    const a = self.stack.pop();
                    const result = try func.newValue(.trit32);
                    try self.stack.append(result);

                    // eqz: result = (a == 0) ? 1 : 0
                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_eq,
                        .dest = result,
                        .operands = .{ a, 0, 0, 0 }, // compare with implicit 0
                        .operand_count = 1,
                        .source_address = inst.address,
                    });
                }
            },

            0x47 => { // i32.ne → not equal
                if (self.stack.items.len >= 2) {
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    const result = try func.newValue(.trit32);
                    try self.stack.append(result);

                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_cmp, // cmp returns -1, 0, +1; ne is non-zero
                        .dest = result,
                        .operands = .{ a, b, 0, 0 },
                        .operand_count = 2,
                        .source_address = inst.address,
                    });
                }
            },

            0x48, 0x49 => { // i32.lt_s, i32.lt_u → t_cmp (returns -1, 0, +1)
                if (self.stack.items.len >= 2) {
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    const result = try func.newValue(.trit32);
                    try self.stack.append(result);

                    // lt: result = (a < b) ? 1 : 0
                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_lt,
                        .dest = result,
                        .operands = .{ a, b, 0, 0 },
                        .operand_count = 2,
                        .source_address = inst.address,
                    });
                }
            },

            0x4A, 0x4B => { // i32.gt_s, i32.gt_u
                if (self.stack.items.len >= 2) {
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    const result = try func.newValue(.trit32);
                    try self.stack.append(result);

                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_gt,
                        .dest = result,
                        .operands = .{ a, b, 0, 0 },
                        .operand_count = 2,
                        .source_address = inst.address,
                    });
                }
            },

            0x4C, 0x4D => { // i32.le_s, i32.le_u
                if (self.stack.items.len >= 2) {
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    const result = try func.newValue(.trit32);
                    try self.stack.append(result);

                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_le,
                        .dest = result,
                        .operands = .{ a, b, 0, 0 },
                        .operand_count = 2,
                        .source_address = inst.address,
                    });
                }
            },

            0x4E, 0x4F => { // i32.ge_s, i32.ge_u
                if (self.stack.items.len >= 2) {
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    const result = try func.newValue(.trit32);
                    try self.stack.append(result);

                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_ge,
                        .dest = result,
                        .operands = .{ a, b, 0, 0 },
                        .operand_count = 2,
                        .source_address = inst.address,
                    });
                }
            },

            // Local access (includes function parameters)
            0x20 => { // local.get
                const local_idx: u32 = @intCast(inst.operands[0].value);
                const result = try func.newValue(.trit32);
                try self.stack.append(result);

                try block.instructions.append(TVCInstruction{
                    .opcode = .t_get_local,
                    .dest = result,
                    .operands = .{ local_idx, 0, 0, 0 },
                    .operand_count = 1,
                    .source_address = inst.address,
                });
            },

            0x21 => { // local.set
                const local_idx: u32 = @intCast(inst.operands[0].value);
                if (self.stack.items.len >= 1) {
                    const value = self.stack.pop();

                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_set_local,
                        .dest = null,
                        .operands = .{ local_idx, value, 0, 0 },
                        .operand_count = 2,
                        .source_address = inst.address,
                    });
                }
            },

            // Memory operations
            0x28 => { // i32.load
                const offset: u32 = @intCast(inst.operands[1].value);
                if (self.stack.items.len >= 1) {
                    const addr = self.stack.pop();
                    const result = try func.newValue(.trit32);
                    try self.stack.append(result);

                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_load,
                        .dest = result,
                        .operands = .{ addr, offset, 0, 0 },
                        .operand_count = 2,
                        .source_address = inst.address,
                    });
                }
            },

            0x36 => { // i32.store
                const offset: u32 = @intCast(inst.operands[1].value);
                if (self.stack.items.len >= 2) {
                    const value = self.stack.pop();
                    const addr = self.stack.pop();

                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_store,
                        .dest = null,
                        .operands = .{ addr, value, offset, 0 },
                        .operand_count = 3,
                        .source_address = inst.address,
                    });
                }
            },

            0x2C, 0x2D => { // i32.load8_s, i32.load8_u
                const offset: u32 = @intCast(inst.operands[1].value);
                if (self.stack.items.len >= 1) {
                    const addr = self.stack.pop();
                    const result = try func.newValue(.trit32);
                    try self.stack.append(result);

                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_load, // Will load byte and extend
                        .dest = result,
                        .operands = .{ addr, offset, 1, 0 }, // size=1 byte
                        .operand_count = 3,
                        .source_address = inst.address,
                    });
                }
            },

            0x3A => { // i32.store8
                const offset: u32 = @intCast(inst.operands[1].value);
                if (self.stack.items.len >= 2) {
                    const value = self.stack.pop();
                    const addr = self.stack.pop();

                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_store,
                        .dest = null,
                        .operands = .{ addr, value, offset, 1 }, // size=1 byte
                        .operand_count = 4,
                        .source_address = inst.address,
                    });
                }
            },

            // Control flow
            0x10 => { // call
                const func_idx: u32 = @intCast(inst.operands[0].value);
                const result = try func.newValue(.trit32);
                try self.stack.append(result);

                try block.instructions.append(TVCInstruction{
                    .opcode = .t_call,
                    .dest = result,
                    .operands = .{ func_idx, 0, 0, 0 },
                    .operand_count = 1,
                    .source_address = inst.address,
                });
            },

            0x0F => { // return
                var ret_val: u32 = 0;
                if (self.stack.items.len >= 1) {
                    ret_val = self.stack.pop();
                }

                try block.instructions.append(TVCInstruction{
                    .opcode = .t_ret,
                    .dest = null,
                    .operands = .{ ret_val, 0, 0, 0 },
                    .operand_count = 1,
                    .source_address = inst.address,
                });
            },

            0x0C => { // br (unconditional branch)
                const depth: u32 = @intCast(inst.operands[0].value);
                const target = self.getBranchTarget(depth) orelse 0;

                try block.instructions.append(TVCInstruction{
                    .opcode = .t_br,
                    .dest = null,
                    .operands = .{ target, 0, 0, 0 },
                    .operand_count = 1,
                    .source_address = inst.address,
                });
            },

            0x0D => { // br_if (conditional branch)
                const depth: u32 = @intCast(inst.operands[0].value);
                const target = self.getBranchTarget(depth) orelse 0;
                if (self.stack.items.len >= 1) {
                    const cond = self.stack.pop();

                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_br_if,
                        .dest = null,
                        .operands = .{ cond, target, 0, 0 },
                        .operand_count = 2,
                        .source_address = inst.address,
                    });
                }
            },

            // Stack operations
            0x1A => { // drop
                if (self.stack.items.len >= 1) {
                    _ = self.stack.pop();

                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_drop,
                        .dest = null,
                        .operands = .{ 0, 0, 0, 0 },
                        .operand_count = 0,
                        .source_address = inst.address,
                    });
                }
            },

            0x00 => { // unreachable
                try block.instructions.append(TVCInstruction{
                    .opcode = .t_unreachable,
                    .dest = null,
                    .operands = .{ 0, 0, 0, 0 },
                    .operand_count = 0,
                    .source_address = inst.address,
                });
            },

            0x01 => { // nop
                try block.instructions.append(TVCInstruction{
                    .opcode = .t_nop,
                    .dest = null,
                    .operands = .{ 0, 0, 0, 0 },
                    .operand_count = 0,
                    .source_address = inst.address,
                });
            },

            0x02 => { // block
                // Block: br jumps to end
                const start_label = self.newLabel();
                const end_label = self.newLabel();
                try self.block_stack.append(BlockInfo{
                    .block_type = .block,
                    .start_label = start_label,
                    .end_label = end_label,
                });
            },

            0x03 => { // loop
                // Loop: br jumps to start (re-execute)
                const start_label = self.newLabel();
                const end_label = self.newLabel();
                try self.block_stack.append(BlockInfo{
                    .block_type = .loop,
                    .start_label = start_label,
                    .end_label = end_label,
                });
                // Emit start label for loop
                try block.instructions.append(TVCInstruction{
                    .opcode = .t_label,
                    .dest = null,
                    .operands = .{ start_label, 0, 0, 0 },
                    .operand_count = 1,
                    .source_address = inst.address,
                });
            },

            0x04 => { // if
                // If block: br jumps to end
                const start_label = self.newLabel();
                const end_label = self.newLabel();
                try self.block_stack.append(BlockInfo{
                    .block_type = .if_block,
                    .start_label = start_label,
                    .end_label = end_label,
                });
                // Conditional - pop condition and branch to end if zero
                if (self.stack.items.len >= 1) {
                    const cond = self.stack.pop();
                    // Branch to end_label if cond == 0
                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_br_if,
                        .dest = null,
                        .operands = .{ cond, end_label, 1, 0 }, // invert=1 (branch if zero)
                        .operand_count = 3,
                        .source_address = inst.address,
                    });
                }
            },

            0x05 => { // else
                // Else: jump to end, then emit else label
                if (self.block_stack.items.len > 0) {
                    const block_info = self.block_stack.items[self.block_stack.items.len - 1];
                    // Jump over else block
                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_br,
                        .dest = null,
                        .operands = .{ block_info.end_label, 0, 0, 0 },
                        .operand_count = 1,
                        .source_address = inst.address,
                    });
                    // Emit else label (where if-false jumps to)
                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_label,
                        .dest = null,
                        .operands = .{ block_info.start_label, 0, 0, 0 },
                        .operand_count = 1,
                        .source_address = inst.address,
                    });
                }
            },

            0x0B => { // end
                // Pop block and emit end label
                if (self.block_stack.items.len > 0) {
                    const block_info = self.block_stack.pop();
                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_label,
                        .dest = null,
                        .operands = .{ block_info.end_label, 0, 0, 0 },
                        .operand_count = 1,
                        .source_address = inst.address,
                    });
                }
            },

            0x1B => { // select
                // select: [val1, val2, cond] -> val1 if cond != 0, else val2
                if (self.stack.items.len >= 3) {
                    const cond = self.stack.pop();
                    const val2 = self.stack.pop();
                    const val1 = self.stack.pop();
                    const result = try func.newValue(.trit32);
                    try self.stack.append(result);

                    // Emit: result = cond ? val1 : val2
                    try block.instructions.append(TVCInstruction{
                        .opcode = .t_select,
                        .dest = result,
                        .operands = .{ val1, val2, cond, 0 },
                        .operand_count = 3,
                        .source_address = inst.address,
                    });
                }
            },

            else => {
                // Unknown opcode - emit nop
                try block.instructions.append(TVCInstruction{
                    .opcode = .t_nop,
                    .dest = null,
                    .operands = .{ 0, 0, 0, 0 },
                    .operand_count = 0,
                    .source_address = inst.address,
                });
            },
        }
    }
};

fn wasmTypeToTVC(wasm_type: u8) TVCType {
    return switch (wasm_type) {
        0x7F => .trit32, // i32
        0x7E => .trit64, // i64
        0x7D => .trit32, // f32 (approximate)
        0x7C => .trit64, // f64 (approximate)
        else => .trit32,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "lift i32.const" {
    var lifter = Lifter.init(std.testing.allocator);
    defer lifter.deinit();

    var func = TVCFunction.init(std.testing.allocator, 0);
    defer func.deinit();

    var block = TVCBlock.init(std.testing.allocator, 0);
    defer block.deinit();

    const inst = b2t_disasm.Instruction{
        .address = 0,
        .opcode = 0x41,
        .mnemonic = "i32.const",
        .operands = .{
            b2t_disasm.Operand{ .op_type = .immediate, .value = 42, .size = 4 },
            undefined,
            undefined,
            undefined,
        },
        .operand_count = 1,
        .size = 2,
        .is_branch = false,
        .is_call = false,
        .is_return = false,
        .branch_target = null,
    };

    try lifter.liftInstruction(&func, &block, &inst);

    try std.testing.expectEqual(@as(usize, 1), block.instructions.items.len);
    try std.testing.expectEqual(TVCOpcode.t_const, block.instructions.items[0].opcode);
}

test "lift i32.add" {
    var lifter = Lifter.init(std.testing.allocator);
    defer lifter.deinit();

    // Push two values on stack
    try lifter.stack.append(0);
    try lifter.stack.append(1);

    var func = TVCFunction.init(std.testing.allocator, 0);
    defer func.deinit();

    var block = TVCBlock.init(std.testing.allocator, 0);
    defer block.deinit();

    const inst = b2t_disasm.Instruction{
        .address = 0,
        .opcode = 0x6A,
        .mnemonic = "i32.add",
        .operands = undefined,
        .operand_count = 0,
        .size = 1,
        .is_branch = false,
        .is_call = false,
        .is_return = false,
        .branch_target = null,
    };

    try lifter.liftInstruction(&func, &block, &inst);

    try std.testing.expectEqual(@as(usize, 1), block.instructions.items.len);
    try std.testing.expectEqual(TVCOpcode.t_add, block.instructions.items[0].opcode);
}
