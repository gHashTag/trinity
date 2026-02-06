// B2T Disassembler - Binary-to-Ternary Converter
// Disassembles WASM, x86_64, ARM64 instructions
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const b2t_loader = @import("b2t_loader.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const OperandType = enum {
    register,
    immediate,
    memory,
    local,
    global,
    label,
    block,
    func_idx,
    type_idx,
};

pub const Operand = struct {
    op_type: OperandType,
    value: i64,
    size: u8,
};

pub const Instruction = struct {
    address: u64,
    opcode: u8,
    mnemonic: []const u8,
    operands: [4]Operand,
    operand_count: u8,
    size: u8,
    is_branch: bool,
    is_call: bool,
    is_return: bool,
    branch_target: ?u64,
};

pub const BasicBlock = struct {
    start_address: u64,
    end_address: u64,
    instructions: std.ArrayListUnmanaged(Instruction),
    successors: std.ArrayListUnmanaged(u64),
    predecessors: std.ArrayListUnmanaged(u64),

    pub fn init(start: u64) BasicBlock {
        return BasicBlock{
            .start_address = start,
            .end_address = start,
            .instructions = .{},
            .successors = .{},
            .predecessors = .{},
        };
    }

    pub fn deinit(self: *BasicBlock, allocator: std.mem.Allocator) void {
        self.instructions.deinit(allocator);
        self.successors.deinit(allocator);
        self.predecessors.deinit(allocator);
    }
};

pub const WasmFunction = struct {
    index: u32,
    type_index: u32,
    locals: std.ArrayListUnmanaged(WasmLocal),
    code: []const u8,
    instructions: std.ArrayListUnmanaged(Instruction),

    pub fn init(idx: u32, type_idx: u32) WasmFunction {
        return WasmFunction{
            .index = idx,
            .type_index = type_idx,
            .locals = .{},
            .code = &[_]u8{},
            .instructions = .{},
        };
    }

    pub fn deinit(self: *WasmFunction, allocator: std.mem.Allocator) void {
        self.locals.deinit(allocator);
        self.instructions.deinit(allocator);
    }
};

pub const WasmLocal = struct {
    count: u32,
    value_type: u8,
};

pub const DisassemblyResult = struct {
    allocator: std.mem.Allocator,
    architecture: b2t_loader.Architecture,
    functions: std.ArrayListUnmanaged(WasmFunction),
    entry_point: u64,

    pub fn init(allocator: std.mem.Allocator) DisassemblyResult {
        return DisassemblyResult{
            .allocator = allocator,
            .architecture = .unknown,
            .functions = .{},
            .entry_point = 0,
        };
    }

    pub fn deinit(self: *DisassemblyResult) void {
        for (self.functions.items) |*func| {
            func.deinit(self.allocator);
        }
        self.functions.deinit(self.allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// WASM OPCODES
// ═══════════════════════════════════════════════════════════════════════════════

pub const WasmOpcode = enum(u8) {
    // Control
    @"unreachable" = 0x00,
    nop = 0x01,
    block = 0x02,
    loop = 0x03,
    if_ = 0x04,
    else_ = 0x05,
    end = 0x0B,
    br = 0x0C,
    br_if = 0x0D,
    br_table = 0x0E,
    return_ = 0x0F,
    call = 0x10,
    call_indirect = 0x11,

    // Parametric
    drop = 0x1A,
    select = 0x1B,

    // Variable
    local_get = 0x20,
    local_set = 0x21,
    local_tee = 0x22,
    global_get = 0x23,
    global_set = 0x24,

    // Memory
    i32_load = 0x28,
    i64_load = 0x29,
    f32_load = 0x2A,
    f64_load = 0x2B,
    i32_load8_s = 0x2C,
    i32_load8_u = 0x2D,
    i32_load16_s = 0x2E,
    i32_load16_u = 0x2F,
    i32_store = 0x36,
    i64_store = 0x37,
    f32_store = 0x38,
    f64_store = 0x39,
    i32_store8 = 0x3A,
    i32_store16 = 0x3B,

    // Constants
    i32_const = 0x41,
    i64_const = 0x42,
    f32_const = 0x43,
    f64_const = 0x44,

    // Comparison
    i32_eqz = 0x45,
    i32_eq = 0x46,
    i32_ne = 0x47,
    i32_lt_s = 0x48,
    i32_lt_u = 0x49,
    i32_gt_s = 0x4A,
    i32_gt_u = 0x4B,
    i32_le_s = 0x4C,
    i32_le_u = 0x4D,
    i32_ge_s = 0x4E,
    i32_ge_u = 0x4F,

    // Arithmetic
    i32_clz = 0x67,
    i32_ctz = 0x68,
    i32_popcnt = 0x69,
    i32_add = 0x6A,
    i32_sub = 0x6B,
    i32_mul = 0x6C,
    i32_div_s = 0x6D,
    i32_div_u = 0x6E,
    i32_rem_s = 0x6F,
    i32_rem_u = 0x70,
    i32_and = 0x71,
    i32_or = 0x72,
    i32_xor = 0x73,
    i32_shl = 0x74,
    i32_shr_s = 0x75,
    i32_shr_u = 0x76,
    i32_rotl = 0x77,
    i32_rotr = 0x78,

    // i64 operations
    i64_add = 0x7C,
    i64_sub = 0x7D,
    i64_mul = 0x7E,

    _,
};

// ═══════════════════════════════════════════════════════════════════════════════
// DISASSEMBLER
// ═══════════════════════════════════════════════════════════════════════════════

pub fn disassemble(allocator: std.mem.Allocator, binary: *const b2t_loader.LoadedBinary) !DisassemblyResult {
    return switch (binary.architecture) {
        .wasm => disassembleWasm(allocator, binary),
        .x86_64 => disassembleX86_64(allocator, binary),
        else => error.UnsupportedArchitecture,
    };
}

pub fn disassembleWasm(allocator: std.mem.Allocator, binary: *const b2t_loader.LoadedBinary) !DisassemblyResult {
    var result = DisassemblyResult.init(allocator);
    result.architecture = .wasm;
    result.entry_point = binary.entry_point;

    // Find code section
    var code_section: ?b2t_loader.Section = null;
    var func_section: ?b2t_loader.Section = null;

    for (binary.sections.items) |section| {
        if (std.mem.eql(u8, section.name, "code")) {
            code_section = section;
        } else if (std.mem.eql(u8, section.name, "function")) {
            func_section = section;
        }
    }

    if (code_section == null) {
        return result; // No code to disassemble
    }

    // Parse function types from function section
    var func_types = std.ArrayListUnmanaged(u32){};
    defer func_types.deinit(allocator);

    if (func_section) |fs| {
        var offset: usize = 0;
        const num_funcs = readLeb128u32(fs.raw_data, &offset);
        var i: u32 = 0;
        while (i < num_funcs) : (i += 1) {
            const type_idx = readLeb128u32(fs.raw_data, &offset);
            try func_types.append(allocator, type_idx);
        }
    }

    // Parse code section
    const code_data = code_section.?.raw_data;
    var offset: usize = 0;

    // Number of functions
    const num_functions = readLeb128u32(code_data, &offset);

    var func_idx: u32 = 0;
    while (func_idx < num_functions) : (func_idx += 1) {
        // Function body size
        const body_size = readLeb128u32(code_data, &offset);
        const body_end = offset + body_size;

        // Get type index
        const type_idx = if (func_idx < func_types.items.len) func_types.items[func_idx] else 0;

        var func = WasmFunction.init(func_idx, type_idx);

        // Parse locals
        const num_local_entries = readLeb128u32(code_data, &offset);
        var local_idx: u32 = 0;
        while (local_idx < num_local_entries) : (local_idx += 1) {
            const count = readLeb128u32(code_data, &offset);
            const value_type = code_data[offset];
            offset += 1;
            try func.locals.append(allocator, WasmLocal{ .count = count, .value_type = value_type });
        }

        // Store code bytes
        func.code = code_data[offset..body_end];

        // Disassemble instructions
        while (offset < body_end) {
            const inst_start = offset;
            var local_offset: usize = 0;
            const remaining = code_data[offset..body_end];
            if (remaining.len == 0) break;

            const inst = disassembleWasmInstruction(remaining, &local_offset) catch break;
            var instruction = inst;
            instruction.address = inst_start;
            try func.instructions.append(allocator, instruction);
            offset += local_offset;
        }

        try result.functions.append(allocator, func);
    }

    return result;
}

fn disassembleWasmInstruction(code: []const u8, offset: *usize) !Instruction {
    if (offset.* >= code.len) {
        return error.TruncatedInstruction;
    }

    const opcode = code[offset.*];
    offset.* += 1;

    var inst = Instruction{
        .address = 0,
        .opcode = opcode,
        .mnemonic = getWasmMnemonic(opcode),
        .operands = undefined,
        .operand_count = 0,
        .size = 1,
        .is_branch = false,
        .is_call = false,
        .is_return = false,
        .branch_target = null,
    };

    // Parse operands based on opcode
    switch (opcode) {
        // Control with block type
        0x02, 0x03, 0x04 => { // block, loop, if
            const block_type = code[offset.*];
            offset.* += 1;
            inst.operands[0] = Operand{ .op_type = .block, .value = block_type, .size = 1 };
            inst.operand_count = 1;
            inst.size = 2;
            inst.is_branch = true;
        },

        // Branch
        0x0C, 0x0D => { // br, br_if
            const label_idx = readLeb128u32(code, offset);
            inst.operands[0] = Operand{ .op_type = .label, .value = label_idx, .size = 4 };
            inst.operand_count = 1;
            inst.is_branch = true;
        },

        // Return
        0x0F => {
            inst.is_return = true;
        },

        // Call
        0x10 => {
            const func_idx = readLeb128u32(code, offset);
            inst.operands[0] = Operand{ .op_type = .func_idx, .value = func_idx, .size = 4 };
            inst.operand_count = 1;
            inst.is_call = true;
        },

        // Local/Global access
        0x20, 0x21, 0x22 => { // local.get, local.set, local.tee
            const local_idx = readLeb128u32(code, offset);
            inst.operands[0] = Operand{ .op_type = .local, .value = local_idx, .size = 4 };
            inst.operand_count = 1;
        },

        0x23, 0x24 => { // global.get, global.set
            const global_idx = readLeb128u32(code, offset);
            inst.operands[0] = Operand{ .op_type = .global, .value = global_idx, .size = 4 };
            inst.operand_count = 1;
        },

        // Memory operations
        0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B => {
            const align_val = readLeb128u32(code, offset);
            const mem_offset = readLeb128u32(code, offset);
            inst.operands[0] = Operand{ .op_type = .immediate, .value = align_val, .size = 4 };
            inst.operands[1] = Operand{ .op_type = .memory, .value = @intCast(mem_offset), .size = 4 };
            inst.operand_count = 2;
        },

        // Constants
        0x41 => { // i32.const
            const value = readLeb128i32(code, offset);
            inst.operands[0] = Operand{ .op_type = .immediate, .value = value, .size = 4 };
            inst.operand_count = 1;
        },

        0x42 => { // i64.const
            const value = readLeb128i64(code, offset);
            inst.operands[0] = Operand{ .op_type = .immediate, .value = value, .size = 8 };
            inst.operand_count = 1;
        },

        else => {
            // No operands for most arithmetic/comparison ops
        },
    }

    return inst;
}

fn getWasmMnemonic(opcode: u8) []const u8 {
    return switch (opcode) {
        0x00 => "unreachable",
        0x01 => "nop",
        0x02 => "block",
        0x03 => "loop",
        0x04 => "if",
        0x05 => "else",
        0x0B => "end",
        0x0C => "br",
        0x0D => "br_if",
        0x0E => "br_table",
        0x0F => "return",
        0x10 => "call",
        0x11 => "call_indirect",
        0x1A => "drop",
        0x1B => "select",
        0x20 => "local.get",
        0x21 => "local.set",
        0x22 => "local.tee",
        0x23 => "global.get",
        0x24 => "global.set",
        0x28 => "i32.load",
        0x29 => "i64.load",
        0x36 => "i32.store",
        0x37 => "i64.store",
        0x41 => "i32.const",
        0x42 => "i64.const",
        0x45 => "i32.eqz",
        0x46 => "i32.eq",
        0x47 => "i32.ne",
        0x48 => "i32.lt_s",
        0x49 => "i32.lt_u",
        0x4A => "i32.gt_s",
        0x4B => "i32.gt_u",
        0x6A => "i32.add",
        0x6B => "i32.sub",
        0x6C => "i32.mul",
        0x6D => "i32.div_s",
        0x6E => "i32.div_u",
        0x71 => "i32.and",
        0x72 => "i32.or",
        0x73 => "i32.xor",
        0x74 => "i32.shl",
        0x75 => "i32.shr_s",
        0x76 => "i32.shr_u",
        0x7C => "i64.add",
        0x7D => "i64.sub",
        0x7E => "i64.mul",
        else => "unknown",
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// X86_64 DISASSEMBLER
// ═══════════════════════════════════════════════════════════════════════════════

// x86_64 register names
const X86_REG_NAMES = [_][]const u8{
    "rax", "rcx", "rdx", "rbx", "rsp", "rbp", "rsi", "rdi",
    "r8",  "r9",  "r10", "r11", "r12", "r13", "r14", "r15",
};

const X86_REG_NAMES_32 = [_][]const u8{
    "eax", "ecx", "edx",  "ebx",  "esp",  "ebp",  "esi",  "edi",
    "r8d", "r9d", "r10d", "r11d", "r12d", "r13d", "r14d", "r15d",
};

pub fn disassembleX86_64(allocator: std.mem.Allocator, binary: *const b2t_loader.LoadedBinary) !DisassemblyResult {
    var result = DisassemblyResult.init(allocator);
    result.architecture = .x86_64;
    result.entry_point = binary.entry_point;

    // Find executable sections
    for (binary.sections.items) |section| {
        if (section.is_executable and section.raw_data.len > 0) {
            // Create a pseudo-function for each code section
            var func = WasmFunction.init(@intCast(result.functions.items.len), 0);
            func.code = section.raw_data;

            // Disassemble the section
            var offset: usize = 0;
            while (offset < section.raw_data.len) {
                var local_offset: usize = 0;
                const remaining = section.raw_data[offset..];
                if (remaining.len == 0) break;

                const inst = disassembleX86Instruction(remaining, &local_offset) catch break;
                var instruction = inst;
                instruction.address = section.virtual_address + offset;
                try func.instructions.append(allocator, instruction);
                offset += local_offset;
                if (local_offset == 0) break; // Prevent infinite loop
            }

            try result.functions.append(allocator, func);
        }
    }

    return result;
}

fn disassembleX86Instruction(code: []const u8, offset: *usize) !Instruction {
    if (code.len == 0) return error.TruncatedInstruction;

    var inst = Instruction{
        .address = 0,
        .opcode = code[0],
        .mnemonic = "unknown",
        .operands = undefined,
        .operand_count = 0,
        .size = 1,
        .is_branch = false,
        .is_call = false,
        .is_return = false,
        .branch_target = null,
    };

    var pos: usize = 0;

    // Check for REX prefix (0x40-0x4F) - skip it for now
    if (code[pos] >= 0x40 and code[pos] <= 0x4F) {
        pos += 1;
        if (pos >= code.len) return error.TruncatedInstruction;
    }

    const opcode = code[pos];
    inst.opcode = opcode;
    pos += 1;

    // Decode based on opcode
    switch (opcode) {
        // NOP
        0x90 => {
            inst.mnemonic = "nop";
            inst.size = @intCast(pos);
        },

        // RET
        0xC3 => {
            inst.mnemonic = "ret";
            inst.is_return = true;
            inst.size = @intCast(pos);
        },

        // MOV r32, imm32 (0xB8 + rd)
        0xB8, 0xB9, 0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF => {
            const reg_idx = opcode - 0xB8;
            if (pos + 4 > code.len) return error.TruncatedInstruction;
            const imm = std.mem.readInt(u32, code[pos..][0..4], .little);
            pos += 4;

            inst.mnemonic = "mov";
            inst.operands[0] = Operand{ .op_type = .register, .value = reg_idx, .size = 4 };
            inst.operands[1] = Operand{ .op_type = .immediate, .value = imm, .size = 4 };
            inst.operand_count = 2;
            inst.size = @intCast(pos);
        },

        // PUSH r64 (0x50 + rd)
        0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57 => {
            const reg_idx = opcode - 0x50;
            inst.mnemonic = "push";
            inst.operands[0] = Operand{ .op_type = .register, .value = reg_idx, .size = 8 };
            inst.operand_count = 1;
            inst.size = @intCast(pos);
        },

        // POP r64 (0x58 + rd)
        0x58, 0x59, 0x5A, 0x5B, 0x5C, 0x5D, 0x5E, 0x5F => {
            const reg_idx = opcode - 0x58;
            inst.mnemonic = "pop";
            inst.operands[0] = Operand{ .op_type = .register, .value = reg_idx, .size = 8 };
            inst.operand_count = 1;
            inst.size = @intCast(pos);
        },

        // ADD/OR/ADC/SBB/AND/SUB/XOR/CMP r/m, imm8 (0x83)
        0x83 => {
            if (pos >= code.len) return error.TruncatedInstruction;
            const modrm = code[pos];
            pos += 1;
            const reg_field = (modrm >> 3) & 0x07;
            const rm = modrm & 0x07;

            if (pos >= code.len) return error.TruncatedInstruction;
            const imm8: i8 = @bitCast(code[pos]);
            pos += 1;

            inst.mnemonic = switch (reg_field) {
                0 => "add",
                1 => "or",
                4 => "and",
                5 => "sub",
                6 => "xor",
                7 => "cmp",
                else => "unknown",
            };
            inst.operands[0] = Operand{ .op_type = .register, .value = rm, .size = 4 };
            inst.operands[1] = Operand{ .op_type = .immediate, .value = imm8, .size = 1 };
            inst.operand_count = 2;
            inst.size = @intCast(pos);
        },

        // ADD r/m, r (0x01)
        0x01 => {
            if (pos >= code.len) return error.TruncatedInstruction;
            const modrm = code[pos];
            pos += 1;
            const reg = (modrm >> 3) & 0x07;
            const rm = modrm & 0x07;

            inst.mnemonic = "add";
            inst.operands[0] = Operand{ .op_type = .register, .value = rm, .size = 4 };
            inst.operands[1] = Operand{ .op_type = .register, .value = reg, .size = 4 };
            inst.operand_count = 2;
            inst.size = @intCast(pos);
        },

        // SUB r/m, r (0x29)
        0x29 => {
            if (pos >= code.len) return error.TruncatedInstruction;
            const modrm = code[pos];
            pos += 1;
            const reg = (modrm >> 3) & 0x07;
            const rm = modrm & 0x07;

            inst.mnemonic = "sub";
            inst.operands[0] = Operand{ .op_type = .register, .value = rm, .size = 4 };
            inst.operands[1] = Operand{ .op_type = .register, .value = reg, .size = 4 };
            inst.operand_count = 2;
            inst.size = @intCast(pos);
        },

        // IMUL r, r/m (0x0F 0xAF)
        0x0F => {
            if (pos >= code.len) return error.TruncatedInstruction;
            const opcode2 = code[pos];
            pos += 1;

            switch (opcode2) {
                0xAF => {
                    if (pos >= code.len) return error.TruncatedInstruction;
                    const modrm = code[pos];
                    pos += 1;
                    const reg = (modrm >> 3) & 0x07;
                    const rm = modrm & 0x07;

                    inst.mnemonic = "imul";
                    inst.operands[0] = Operand{ .op_type = .register, .value = reg, .size = 4 };
                    inst.operands[1] = Operand{ .op_type = .register, .value = rm, .size = 4 };
                    inst.operand_count = 2;
                },
                // JCC near (0x80-0x8F)
                0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x8B, 0x8C, 0x8D, 0x8E, 0x8F => {
                    if (pos + 4 > code.len) return error.TruncatedInstruction;
                    const rel32: i32 = @bitCast(std.mem.readInt(u32, code[pos..][0..4], .little));
                    pos += 4;

                    inst.mnemonic = switch (opcode2) {
                        0x84 => "je",
                        0x85 => "jne",
                        0x8C => "jl",
                        0x8D => "jge",
                        0x8E => "jle",
                        0x8F => "jg",
                        else => "jcc",
                    };
                    inst.operands[0] = Operand{ .op_type = .immediate, .value = rel32, .size = 4 };
                    inst.operand_count = 1;
                    inst.is_branch = true;
                },
                else => {
                    inst.mnemonic = "unknown_0f";
                },
            }
            inst.size = @intCast(pos);
        },

        // CALL rel32 (0xE8)
        0xE8 => {
            if (pos + 4 > code.len) return error.TruncatedInstruction;
            const rel32: i32 = @bitCast(std.mem.readInt(u32, code[pos..][0..4], .little));
            pos += 4;

            inst.mnemonic = "call";
            inst.operands[0] = Operand{ .op_type = .immediate, .value = rel32, .size = 4 };
            inst.operand_count = 1;
            inst.is_call = true;
            inst.size = @intCast(pos);
        },

        // JMP rel32 (0xE9)
        0xE9 => {
            if (pos + 4 > code.len) return error.TruncatedInstruction;
            const rel32: i32 = @bitCast(std.mem.readInt(u32, code[pos..][0..4], .little));
            pos += 4;

            inst.mnemonic = "jmp";
            inst.operands[0] = Operand{ .op_type = .immediate, .value = rel32, .size = 4 };
            inst.operand_count = 1;
            inst.is_branch = true;
            inst.size = @intCast(pos);
        },

        // JMP rel8 (0xEB)
        0xEB => {
            if (pos >= code.len) return error.TruncatedInstruction;
            const rel8: i8 = @bitCast(code[pos]);
            pos += 1;

            inst.mnemonic = "jmp";
            inst.operands[0] = Operand{ .op_type = .immediate, .value = rel8, .size = 1 };
            inst.operand_count = 1;
            inst.is_branch = true;
            inst.size = @intCast(pos);
        },

        // Jcc rel8 (0x70-0x7F)
        0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x7B, 0x7C, 0x7D, 0x7E, 0x7F => {
            if (pos >= code.len) return error.TruncatedInstruction;
            const rel8: i8 = @bitCast(code[pos]);
            pos += 1;

            inst.mnemonic = switch (opcode) {
                0x74 => "je",
                0x75 => "jne",
                0x7C => "jl",
                0x7D => "jge",
                0x7E => "jle",
                0x7F => "jg",
                else => "jcc",
            };
            inst.operands[0] = Operand{ .op_type = .immediate, .value = rel8, .size = 1 };
            inst.operand_count = 1;
            inst.is_branch = true;
            inst.size = @intCast(pos);
        },

        // XOR r, r/m (0x33)
        0x33 => {
            if (pos >= code.len) return error.TruncatedInstruction;
            const modrm = code[pos];
            pos += 1;
            const reg = (modrm >> 3) & 0x07;
            const rm = modrm & 0x07;

            inst.mnemonic = "xor";
            inst.operands[0] = Operand{ .op_type = .register, .value = reg, .size = 4 };
            inst.operands[1] = Operand{ .op_type = .register, .value = rm, .size = 4 };
            inst.operand_count = 2;
            inst.size = @intCast(pos);
        },

        // INT3 (0xCC)
        0xCC => {
            inst.mnemonic = "int3";
            inst.size = @intCast(pos);
        },

        // SYSCALL (0x0F 0x05) - handled in 0x0F case above
        // For now, treat unknown as single byte
        else => {
            inst.mnemonic = "db";
            inst.operands[0] = Operand{ .op_type = .immediate, .value = opcode, .size = 1 };
            inst.operand_count = 1;
            inst.size = @intCast(pos);
        },
    }

    offset.* = pos;
    return inst;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn readLeb128u32(data: []const u8, offset: *usize) u32 {
    var result: u32 = 0;
    var shift: u8 = 0;

    while (offset.* < data.len) {
        const byte = data[offset.*];
        offset.* += 1;
        result |= @as(u32, byte & 0x7F) << @intCast(shift);
        if ((byte & 0x80) == 0) break;
        shift += 7;
    }

    return result;
}

fn readLeb128i32(data: []const u8, offset: *usize) i32 {
    var result: i32 = 0;
    var shift: u8 = 0;
    var byte: u8 = 0;

    while (offset.* < data.len) {
        byte = data[offset.*];
        offset.* += 1;
        result |= @as(i32, @intCast(byte & 0x7F)) << @intCast(shift);
        shift += 7;
        if ((byte & 0x80) == 0) break;
    }

    // Sign extend
    if (shift < 32 and (byte & 0x40) != 0) {
        result |= @as(i32, -1) << @intCast(shift);
    }

    return result;
}

fn readLeb128i64(data: []const u8, offset: *usize) i64 {
    var result: i64 = 0;
    var shift: u8 = 0;
    var byte: u8 = 0;

    while (offset.* < data.len) {
        byte = data[offset.*];
        offset.* += 1;
        result |= @as(i64, @intCast(byte & 0x7F)) << @intCast(shift);
        shift += 7;
        if ((byte & 0x80) == 0) break;
    }

    // Sign extend
    if (shift < 64 and (byte & 0x40) != 0) {
        result |= @as(i64, -1) << @intCast(shift);
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "disassemble i32.const" {
    const code = [_]u8{ 0x41, 0x2A }; // i32.const 42
    var offset: usize = 0;
    const inst = try disassembleWasmInstruction(&code, &offset);

    try std.testing.expectEqualStrings("i32.const", inst.mnemonic);
    try std.testing.expectEqual(@as(u8, 1), inst.operand_count);
    try std.testing.expectEqual(@as(i64, 42), inst.operands[0].value);
}

test "disassemble i32.add" {
    const code = [_]u8{0x6A}; // i32.add
    var offset: usize = 0;
    const inst = try disassembleWasmInstruction(&code, &offset);

    try std.testing.expectEqualStrings("i32.add", inst.mnemonic);
    try std.testing.expectEqual(@as(u8, 0), inst.operand_count);
}

test "disassemble call" {
    const code = [_]u8{ 0x10, 0x05 }; // call 5
    var offset: usize = 0;
    const inst = try disassembleWasmInstruction(&code, &offset);

    try std.testing.expectEqualStrings("call", inst.mnemonic);
    try std.testing.expect(inst.is_call);
    try std.testing.expectEqual(@as(i64, 5), inst.operands[0].value);
}

// x86_64 disassembler tests
test "x86_64 disassemble nop" {
    const code = [_]u8{0x90}; // nop
    var offset: usize = 0;
    const inst = try disassembleX86Instruction(&code, &offset);

    try std.testing.expectEqualStrings("nop", inst.mnemonic);
    try std.testing.expectEqual(@as(u8, 1), inst.size);
}

test "x86_64 disassemble ret" {
    const code = [_]u8{0xC3}; // ret
    var offset: usize = 0;
    const inst = try disassembleX86Instruction(&code, &offset);

    try std.testing.expectEqualStrings("ret", inst.mnemonic);
    try std.testing.expect(inst.is_return);
}

test "x86_64 disassemble mov eax, imm32" {
    const code = [_]u8{ 0xB8, 0x01, 0x00, 0x00, 0x00 }; // mov eax, 1
    var offset: usize = 0;
    const inst = try disassembleX86Instruction(&code, &offset);

    try std.testing.expectEqualStrings("mov", inst.mnemonic);
    try std.testing.expectEqual(@as(u8, 2), inst.operand_count);
    try std.testing.expectEqual(@as(i64, 0), inst.operands[0].value); // eax = reg 0
    try std.testing.expectEqual(@as(i64, 1), inst.operands[1].value); // imm = 1
}

test "x86_64 disassemble push rbp" {
    const code = [_]u8{0x55}; // push rbp
    var offset: usize = 0;
    const inst = try disassembleX86Instruction(&code, &offset);

    try std.testing.expectEqualStrings("push", inst.mnemonic);
    try std.testing.expectEqual(@as(i64, 5), inst.operands[0].value); // rbp = reg 5
}

test "x86_64 disassemble jmp rel8" {
    const code = [_]u8{ 0xEB, 0x10 }; // jmp +16
    var offset: usize = 0;
    const inst = try disassembleX86Instruction(&code, &offset);

    try std.testing.expectEqualStrings("jmp", inst.mnemonic);
    try std.testing.expect(inst.is_branch);
    try std.testing.expectEqual(@as(i64, 16), inst.operands[0].value);
}

test "x86_64 disassemble call rel32" {
    const code = [_]u8{ 0xE8, 0x00, 0x01, 0x00, 0x00 }; // call +256
    var offset: usize = 0;
    const inst = try disassembleX86Instruction(&code, &offset);

    try std.testing.expectEqualStrings("call", inst.mnemonic);
    try std.testing.expect(inst.is_call);
    try std.testing.expectEqual(@as(i64, 256), inst.operands[0].value);
}
