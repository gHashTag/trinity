// B2T VM - Ternary Virtual Machine
// Executes .trit bytecode files
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const b2t_codegen = @import("b2t_codegen.zig");
const trit = @import("trit.zig");
const tekum = @import("tekum.zig");

pub const TritOpcode = b2t_codegen.TritOpcode;
pub const Trit27 = trit.Trit27;
pub const Tekum27 = tekum.Tekum27;
pub const TRIT_MAGIC = b2t_codegen.TRIT_MAGIC;

// VM Configuration
pub const NUM_REGISTERS: usize = 27; // 3³
pub const NUM_LOCALS: usize = 256; // Max locals per function
pub const STACK_SIZE: usize = 16384; // 16K slots
pub const MEMORY_SIZE: usize = 1048576; // 1MB

pub const VMError = error{
    InvalidMagic,
    InvalidOpcode,
    StackOverflow,
    StackUnderflow,
    InvalidRegister,
    InvalidAddress,
    DivisionByZero,
    InvalidFunction,
    OutOfBounds,
    Halted,
};

pub const CallFrame = struct {
    return_pc: usize,
    saved_fp: usize,
    saved_locals: [NUM_LOCALS]i32, // Save caller's locals
};

pub const VM = struct {
    // Registers
    registers: [NUM_REGISTERS]i32,
    pc: usize, // Program counter
    sp: usize, // Stack pointer
    fp: usize, // Frame pointer
    flags: i8, // Comparison flag: -1, 0, +1

    // Memory
    stack: [STACK_SIZE]i32,
    locals: [NUM_LOCALS]i32, // Local variables (includes args)
    memory: []u8,

    // Call stack
    call_stack: std.ArrayList(CallFrame),

    // Program
    code: []const u8,
    entry_point: u32,
    num_functions: u32,
    func_table_offset: usize,

    // State
    halted: bool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*VM {
        const vm = try allocator.create(VM);
        vm.* = VM{
            .registers = [_]i32{0} ** NUM_REGISTERS,
            .pc = 0,
            .sp = STACK_SIZE,
            .fp = STACK_SIZE,
            .flags = 0,
            .stack = [_]i32{0} ** STACK_SIZE,
            .locals = [_]i32{0} ** NUM_LOCALS,
            .memory = try allocator.alloc(u8, MEMORY_SIZE),
            .call_stack = std.ArrayList(CallFrame).init(allocator),
            .code = &[_]u8{},
            .entry_point = 0,
            .num_functions = 0,
            .func_table_offset = 24,
            .halted = false,
            .allocator = allocator,
        };
        @memset(vm.memory, 0);
        return vm;
    }

    pub fn deinit(self: *VM) void {
        self.call_stack.deinit();
        self.allocator.free(self.memory);
        self.allocator.destroy(self);
    }

    pub fn load(self: *VM, data: []const u8) !void {
        if (data.len < 24) return VMError.OutOfBounds;

        const magic = std.mem.readInt(u32, data[0..4], .little);
        if (magic != TRIT_MAGIC) return VMError.InvalidMagic;

        self.entry_point = std.mem.readInt(u32, data[12..16], .little);
        self.num_functions = std.mem.readInt(u32, data[16..20], .little);
        self.code = data;

        // Set PC to first function code (after header + func table)
        self.func_table_offset = 24;
        const code_start = self.func_table_offset + self.num_functions * 12;
        self.pc = if (self.entry_point < self.num_functions)
            self.getFunctionOffset(self.entry_point) orelse code_start
        else
            code_start;
    }

    pub fn loadFile(self: *VM, path: []const u8) !void {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const stat = try file.stat();
        const data = try self.allocator.alloc(u8, stat.size);
        _ = try file.readAll(data);

        try self.load(data);
    }

    fn getFunctionOffset(self: *VM, func_idx: u32) ?usize {
        if (func_idx >= self.num_functions) return null;
        const entry = self.func_table_offset + func_idx * 12;
        if (entry + 4 > self.code.len) return null;
        return std.mem.readInt(u32, self.code[entry..][0..4], .little);
    }

    pub fn run(self: *VM) !i32 {
        while (!self.halted) {
            try self.step();
        }
        return self.registers[0];
    }

    pub fn runWithLimit(self: *VM, max_steps: usize) !i32 {
        var steps: usize = 0;
        while (!self.halted and steps < max_steps) {
            try self.step();
            steps += 1;
        }
        return self.registers[0];
    }

    pub fn reset(self: *VM) void {
        self.registers = [_]i32{0} ** NUM_REGISTERS;
        self.locals = [_]i32{0} ** NUM_LOCALS;
        self.pc = 0;
        self.sp = STACK_SIZE;
        self.fp = STACK_SIZE;
        self.flags = 0;
        self.halted = false;
        self.call_stack.clearRetainingCapacity();
    }

    pub fn step(self: *VM) !void {
        if (self.halted) return VMError.Halted;
        if (self.pc >= self.code.len) {
            self.halted = true;
            return;
        }

        const opcode = self.code[self.pc];
        self.pc += 1;

        try self.execute(opcode);
    }

    fn execute(self: *VM, opcode_byte: u8) !void {
        if (opcode_byte == @intFromEnum(TritOpcode.T_NOP)) {
            // No operation
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_HALT)) {
            self.halted = true;
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_CONST)) {
            const dest = try self.readU32();
            const value = try self.readI32();
            try self.setReg(dest, value);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_ADD)) {
            const dest = try self.readU32();
            const op1 = try self.readU32();
            const op2 = try self.readU32();
            const a = try self.getReg(op1);
            const b = try self.getReg(op2);
            try self.setReg(dest, a +% b);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_SUB)) {
            const dest = try self.readU32();
            const op1 = try self.readU32();
            const op2 = try self.readU32();
            const a = try self.getReg(op1);
            const b = try self.getReg(op2);
            try self.setReg(dest, a -% b);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_MUL)) {
            const dest = try self.readU32();
            const op1 = try self.readU32();
            const op2 = try self.readU32();
            const a = try self.getReg(op1);
            const b = try self.getReg(op2);
            try self.setReg(dest, a *% b);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_DIV)) {
            const dest = try self.readU32();
            const op1 = try self.readU32();
            const op2 = try self.readU32();
            const a = try self.getReg(op1);
            const b = try self.getReg(op2);
            if (b == 0) return VMError.DivisionByZero;
            try self.setReg(dest, @divTrunc(a, b));
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_CMP)) {
            const dest = try self.readU32();
            const op1 = try self.readU32();
            const op2 = try self.readU32();
            const a = try self.getReg(op1);
            const b = try self.getReg(op2);
            const result: i32 = if (a < b) -1 else if (a > b) @as(i32, 1) else 0;
            try self.setReg(dest, result);
            self.flags = @intCast(result);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_EQ)) {
            const dest = try self.readU32();
            const op1 = try self.readU32();
            const op2 = try self.readU32();
            const a = try self.getReg(op1);
            const b = try self.getReg(op2);
            try self.setReg(dest, if (a == b) @as(i32, 1) else 0);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_NE)) {
            const dest = try self.readU32();
            const op1 = try self.readU32();
            const op2 = try self.readU32();
            const a = try self.getReg(op1);
            const b = try self.getReg(op2);
            try self.setReg(dest, if (a != b) @as(i32, 1) else 0);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_LT)) {
            const dest = try self.readU32();
            const op1 = try self.readU32();
            const op2 = try self.readU32();
            const a = try self.getReg(op1);
            const b = try self.getReg(op2);
            try self.setReg(dest, if (a < b) @as(i32, 1) else 0);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_GT)) {
            const dest = try self.readU32();
            const op1 = try self.readU32();
            const op2 = try self.readU32();
            const a = try self.getReg(op1);
            const b = try self.getReg(op2);
            try self.setReg(dest, if (a > b) @as(i32, 1) else 0);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_LE)) {
            const dest = try self.readU32();
            const op1 = try self.readU32();
            const op2 = try self.readU32();
            const a = try self.getReg(op1);
            const b = try self.getReg(op2);
            try self.setReg(dest, if (a <= b) @as(i32, 1) else 0);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_GE)) {
            const dest = try self.readU32();
            const op1 = try self.readU32();
            const op2 = try self.readU32();
            const a = try self.getReg(op1);
            const b = try self.getReg(op2);
            try self.setReg(dest, if (a >= b) @as(i32, 1) else 0);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_EQZ)) {
            const dest = try self.readU32();
            const op1 = try self.readU32();
            const a = try self.getReg(op1);
            try self.setReg(dest, if (a == 0) @as(i32, 1) else 0);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_SELECT)) {
            const dest = try self.readU32();
            const val1_reg = try self.readU32();
            const val2_reg = try self.readU32();
            const cond_reg = try self.readU32();
            const val1 = try self.getReg(val1_reg);
            const val2 = try self.getReg(val2_reg);
            const cond = try self.getReg(cond_reg);
            // select: cond != 0 ? val1 : val2
            try self.setReg(dest, if (cond != 0) val1 else val2);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_GET_LOCAL)) {
            const dest = try self.readU32();
            const local_idx = try self.readU32();
            const value = self.getLocal(local_idx);
            try self.setReg(dest, value);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_SET_LOCAL)) {
            const local_idx = try self.readU32();
            const val_reg = try self.readU32();
            const value = try self.getReg(val_reg);
            self.setLocal(local_idx, value);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_LOAD)) {
            const dest = try self.readU32();
            const addr_reg = try self.readU32();
            const offset = try self.readU32();
            const base_addr = try self.getReg(addr_reg);
            const effective_addr: u32 = @intCast(@as(u32, @bitCast(base_addr)) +% offset);
            const value = try self.loadMem(effective_addr);
            try self.setReg(dest, value);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_STORE)) {
            const addr_reg = try self.readU32();
            const val_reg = try self.readU32();
            const offset = try self.readU32();
            const base_addr = try self.getReg(addr_reg);
            const value = try self.getReg(val_reg);
            const effective_addr: u32 = @intCast(@as(u32, @bitCast(base_addr)) +% offset);
            try self.storeMem(effective_addr, value);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_PUSH)) {
            const reg = try self.readU32();
            const value = try self.getReg(reg);
            try self.push(value);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_POP)) {
            const dest = try self.readU32();
            const value = try self.pop();
            try self.setReg(dest, value);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_CALL)) {
            const dest = try self.readU32();
            const func_idx = try self.readU32();
            _ = dest; // Return value stored in v0
            // Save current state including locals
            try self.call_stack.append(CallFrame{
                .return_pc = self.pc,
                .saved_fp = self.fp,
                .saved_locals = self.locals,
            });
            // Clear locals for new function (args passed via registers)
            self.locals = [_]i32{0} ** NUM_LOCALS;
            // Jump to function
            if (self.getFunctionOffset(func_idx)) |offset| {
                self.pc = offset;
            } else {
                return VMError.InvalidFunction;
            }
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_RET)) {
            const ret_reg = try self.readU32();
            self.registers[0] = try self.getReg(ret_reg);
            // Return from call
            if (self.call_stack.items.len > 0) {
                const frame = self.call_stack.pop();
                self.pc = frame.return_pc;
                self.fp = frame.saved_fp;
                self.locals = frame.saved_locals; // Restore caller's locals
            } else {
                self.halted = true;
            }
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_BR)) {
            const target = try self.readU32();
            self.pc = target;
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_BR_IF)) {
            const cond_reg = try self.readU32();
            const target = try self.readU32();
            const cond = try self.getReg(cond_reg);
            // Branch if condition is non-zero
            if (cond != 0) {
                self.pc = target;
            }
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_BR_TRIT)) {
            const cond_reg = try self.readU32();
            const target = try self.readU32();
            const cond = try self.getReg(cond_reg);
            // 3-way branch based on trit value
            if (cond != 0) {
                self.pc = target;
            }
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_LABEL)) {
            // Label is just a marker, no operation
            _ = try self.readU32(); // label ID (ignored at runtime)
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_DROP)) {
            // Drop top of stack
            _ = try self.pop();
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_AND)) {
            const dest = try self.readU32();
            const op1 = try self.readU32();
            const op2 = try self.readU32();
            const a = try self.getReg(op1);
            const b = try self.getReg(op2);
            try self.setReg(dest, a & b);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_OR)) {
            const dest = try self.readU32();
            const op1 = try self.readU32();
            const op2 = try self.readU32();
            const a = try self.getReg(op1);
            const b = try self.getReg(op2);
            try self.setReg(dest, a | b);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_XOR)) {
            const dest = try self.readU32();
            const op1 = try self.readU32();
            const op2 = try self.readU32();
            const a = try self.getReg(op1);
            const b = try self.getReg(op2);
            try self.setReg(dest, a ^ b);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_TADD)) {
            // Native balanced ternary addition
            const dest = try self.readU32();
            const op1 = try self.readU32();
            const op2 = try self.readU32();
            const a = Trit27.fromInt(try self.getReg(op1));
            const b = Trit27.fromInt(try self.getReg(op2));
            const result = Trit27.add(a, b);
            try self.setReg(dest, @intCast(result.toInt()));
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_TSUB)) {
            // Native balanced ternary subtraction
            const dest = try self.readU32();
            const op1 = try self.readU32();
            const op2 = try self.readU32();
            const a = Trit27.fromInt(try self.getReg(op1));
            const b = Trit27.fromInt(try self.getReg(op2));
            const result = Trit27.sub(a, b);
            try self.setReg(dest, @intCast(result.toInt()));
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_TMUL)) {
            // Native balanced ternary multiplication
            const dest = try self.readU32();
            const op1 = try self.readU32();
            const op2 = try self.readU32();
            const a = Trit27.fromInt(try self.getReg(op1));
            const b = Trit27.fromInt(try self.getReg(op2));
            const result = Trit27.mul(a, b);
            try self.setReg(dest, @intCast(result.toInt()));
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_TDIV)) {
            // Native balanced ternary division
            const dest = try self.readU32();
            const op1 = try self.readU32();
            const op2 = try self.readU32();
            const a = Trit27.fromInt(try self.getReg(op1));
            const b = Trit27.fromInt(try self.getReg(op2));
            const result = Trit27.div(a, b);
            try self.setReg(dest, @intCast(result.toInt()));
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_TCMP)) {
            // Native balanced ternary comparison (returns trit: -1, 0, +1)
            const dest = try self.readU32();
            const op1 = try self.readU32();
            const op2 = try self.readU32();
            const a = Trit27.fromInt(try self.getReg(op1));
            const b = Trit27.fromInt(try self.getReg(op2));
            const result = Trit27.cmp(a, b);
            try self.setReg(dest, result.toInt());
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_TNEG)) {
            // Native balanced ternary negation
            const dest = try self.readU32();
            const op1 = try self.readU32();
            const a = Trit27.fromInt(try self.getReg(op1));
            const result = a.neg();
            try self.setReg(dest, @intCast(result.toInt()));
        }
        // ═══════════════════════════════════════════════════════════════════
        // TEKUM FLOATING-POINT OPERATIONS
        // ═══════════════════════════════════════════════════════════════════
        else if (opcode_byte == @intFromEnum(TritOpcode.T_FADD)) {
            // Tekum floating-point add: pop two, push result
            const b_bits = try self.pop();
            const a_bits = try self.pop();
            const a = Tekum27.fromFloat(@as(f64, @floatFromInt(a_bits)));
            const b = Tekum27.fromFloat(@as(f64, @floatFromInt(b_bits)));
            const result = a.add(b);
            try self.push(@intFromFloat(result.toFloat()));
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_FSUB)) {
            // Tekum floating-point subtract
            const b_bits = try self.pop();
            const a_bits = try self.pop();
            const a = Tekum27.fromFloat(@as(f64, @floatFromInt(a_bits)));
            const b = Tekum27.fromFloat(@as(f64, @floatFromInt(b_bits)));
            const result = a.sub(b);
            try self.push(@intFromFloat(result.toFloat()));
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_FMUL)) {
            // Tekum floating-point multiply
            const b_bits = try self.pop();
            const a_bits = try self.pop();
            const a = Tekum27.fromFloat(@as(f64, @floatFromInt(a_bits)));
            const b = Tekum27.fromFloat(@as(f64, @floatFromInt(b_bits)));
            const result = a.mul(b);
            try self.push(@intFromFloat(result.toFloat()));
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_FDIV)) {
            // Tekum floating-point divide
            const b_bits = try self.pop();
            const a_bits = try self.pop();
            const a = Tekum27.fromFloat(@as(f64, @floatFromInt(a_bits)));
            const b = Tekum27.fromFloat(@as(f64, @floatFromInt(b_bits)));
            const result = a.div(b);
            try self.push(@intFromFloat(result.toFloat()));
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_FNEG)) {
            // Tekum floating-point negate
            const a_bits = try self.pop();
            const a = Tekum27.fromFloat(@as(f64, @floatFromInt(a_bits)));
            const result = a.neg();
            try self.push(@intFromFloat(result.toFloat()));
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_FABS)) {
            // Tekum floating-point absolute value
            const a_bits = try self.pop();
            const a = Tekum27.fromFloat(@as(f64, @floatFromInt(a_bits)));
            const result = a.abs();
            try self.push(@intFromFloat(result.toFloat()));
        }
        // ═══════════════════════════════════════════════════════════════════
        // WASM-COMPATIBLE MEMORY OPERATIONS
        // ═══════════════════════════════════════════════════════════════════
        else if (opcode_byte == @intFromEnum(TritOpcode.T_I32_LOAD)) {
            // WASM i32.load: pop address, push value
            const offset = try self.readU32();
            const base_addr = try self.pop();
            const effective_addr: u32 = @intCast(@as(u32, @bitCast(base_addr)) +% offset);
            const value = try self.loadMem(effective_addr);
            try self.push(value);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_I32_STORE)) {
            // WASM i32.store: pop value, pop address
            const offset = try self.readU32();
            const value = try self.pop();
            const base_addr = try self.pop();
            const effective_addr: u32 = @intCast(@as(u32, @bitCast(base_addr)) +% offset);
            try self.storeMem(effective_addr, value);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_I32_LOAD8_S)) {
            // WASM i32.load8_s: load signed byte
            const offset = try self.readU32();
            const base_addr = try self.pop();
            const effective_addr: u32 = @intCast(@as(u32, @bitCast(base_addr)) +% offset);
            if (effective_addr >= MEMORY_SIZE) return VMError.InvalidAddress;
            const byte_val: i8 = @bitCast(self.memory[effective_addr]);
            try self.push(@as(i32, byte_val));
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_I32_LOAD8_U)) {
            // WASM i32.load8_u: load unsigned byte
            const offset = try self.readU32();
            const base_addr = try self.pop();
            const effective_addr: u32 = @intCast(@as(u32, @bitCast(base_addr)) +% offset);
            if (effective_addr >= MEMORY_SIZE) return VMError.InvalidAddress;
            try self.push(@as(i32, self.memory[effective_addr]));
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_I32_LOAD16_S)) {
            // WASM i32.load16_s: load signed 16-bit
            const offset = try self.readU32();
            const base_addr = try self.pop();
            const effective_addr: u32 = @intCast(@as(u32, @bitCast(base_addr)) +% offset);
            if (effective_addr + 2 > MEMORY_SIZE) return VMError.InvalidAddress;
            const val: i16 = std.mem.readInt(i16, self.memory[effective_addr..][0..2], .little);
            try self.push(@as(i32, val));
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_I32_LOAD16_U)) {
            // WASM i32.load16_u: load unsigned 16-bit
            const offset = try self.readU32();
            const base_addr = try self.pop();
            const effective_addr: u32 = @intCast(@as(u32, @bitCast(base_addr)) +% offset);
            if (effective_addr + 2 > MEMORY_SIZE) return VMError.InvalidAddress;
            const val: u16 = std.mem.readInt(u16, self.memory[effective_addr..][0..2], .little);
            try self.push(@as(i32, val));
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_I32_STORE8)) {
            // WASM i32.store8: store byte
            const offset = try self.readU32();
            const value = try self.pop();
            const base_addr = try self.pop();
            const effective_addr: u32 = @intCast(@as(u32, @bitCast(base_addr)) +% offset);
            if (effective_addr >= MEMORY_SIZE) return VMError.InvalidAddress;
            self.memory[effective_addr] = @truncate(@as(u32, @bitCast(value)));
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_I32_STORE16)) {
            // WASM i32.store16: store 16-bit
            const offset = try self.readU32();
            const value = try self.pop();
            const base_addr = try self.pop();
            const effective_addr: u32 = @intCast(@as(u32, @bitCast(base_addr)) +% offset);
            if (effective_addr + 2 > MEMORY_SIZE) return VMError.InvalidAddress;
            std.mem.writeInt(u16, self.memory[effective_addr..][0..2], @truncate(@as(u32, @bitCast(value))), .little);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_MEMORY_SIZE)) {
            // WASM memory.size: push current memory size in pages (64KB each)
            const pages: i32 = @intCast(MEMORY_SIZE / 65536);
            try self.push(pages);
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_MEMORY_GROW)) {
            // WASM memory.grow: try to grow memory (returns -1 if failed, old size if success)
            const delta = try self.pop();
            _ = delta;
            // Fixed memory size - always fail
            try self.push(-1);
        }
        // ═══════════════════════════════════════════════════════════════════
        // WASM FUNCTION CALLS
        // ═══════════════════════════════════════════════════════════════════
        else if (opcode_byte == @intFromEnum(TritOpcode.T_CALL_INDIRECT)) {
            // WASM call_indirect: pop table index, call function at that index
            const type_idx = try self.readU32(); // Type index (for validation)
            const table_idx = try self.readU32(); // Table index
            const func_idx = try self.pop(); // Function index from stack

            _ = type_idx;
            _ = table_idx;

            // Get function from table
            if (func_idx < 0 or @as(u32, @intCast(func_idx)) >= self.num_functions) {
                return VMError.InvalidFunction;
            }

            // Save current state
            try self.call_stack.append(CallFrame{
                .return_pc = self.pc,
                .saved_fp = self.fp,
                .saved_locals = self.locals,
            });

            // Jump to function
            const func_offset = self.getFunctionOffset(@intCast(func_idx)) orelse return VMError.InvalidFunction;
            self.pc = func_offset;
            self.fp = self.sp;
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_TABLE_GET)) {
            // WASM table.get: get function reference from table
            const table_idx = try self.readU32();
            const elem_idx = try self.pop();

            _ = table_idx;

            // Simple implementation: table is just function indices
            // In a full implementation, this would access a table structure
            if (elem_idx < 0 or @as(u32, @intCast(elem_idx)) >= self.num_functions) {
                try self.push(0); // null reference
            } else {
                try self.push(elem_idx); // function index as reference
            }
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_TABLE_SET)) {
            // WASM table.set: set function reference in table
            const table_idx = try self.readU32();
            const value = try self.pop(); // function reference
            const elem_idx = try self.pop(); // element index

            _ = table_idx;
            _ = value;
            _ = elem_idx;
            // No-op for now (would need mutable table)
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_TABLE_SIZE)) {
            // WASM table.size: get table size
            const table_idx = try self.readU32();
            _ = table_idx;
            try self.push(@intCast(self.num_functions));
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_TABLE_GROW)) {
            // WASM table.grow: try to grow table (returns -1 if failed)
            const table_idx = try self.readU32();
            const init_val = try self.pop();
            const delta = try self.pop();

            _ = table_idx;
            _ = init_val;
            _ = delta;
            // Fixed table size - always fail
            try self.push(-1);
        } else {
            return VMError.InvalidOpcode;
        }
    }

    // Helper functions
    fn readU32(self: *VM) !u32 {
        if (self.pc + 4 > self.code.len) return VMError.OutOfBounds;
        const value = std.mem.readInt(u32, self.code[self.pc..][0..4], .little);
        self.pc += 4;
        return value;
    }

    fn readI32(self: *VM) !i32 {
        if (self.pc + 4 > self.code.len) return VMError.OutOfBounds;
        const value = std.mem.readInt(i32, self.code[self.pc..][0..4], .little);
        self.pc += 4;
        return value;
    }

    fn getReg(self: *VM, idx: u32) !i32 {
        if (idx >= NUM_REGISTERS) return VMError.InvalidRegister;
        return self.registers[idx];
    }

    fn setReg(self: *VM, idx: u32, value: i32) !void {
        if (idx >= NUM_REGISTERS) return VMError.InvalidRegister;
        self.registers[idx] = value;
    }

    fn push(self: *VM, value: i32) !void {
        if (self.sp == 0) return VMError.StackOverflow;
        self.sp -= 1;
        self.stack[self.sp] = value;
    }

    fn pop(self: *VM) !i32 {
        if (self.sp >= STACK_SIZE) return VMError.StackUnderflow;
        const value = self.stack[self.sp];
        self.sp += 1;
        return value;
    }

    fn loadMem(self: *VM, addr: u32) !i32 {
        if (addr + 4 > MEMORY_SIZE) return VMError.InvalidAddress;
        return std.mem.readInt(i32, self.memory[addr..][0..4], .little);
    }

    fn storeMem(self: *VM, addr: u32, value: i32) !void {
        if (addr + 4 > MEMORY_SIZE) return VMError.InvalidAddress;
        std.mem.writeInt(i32, self.memory[addr..][0..4], value, .little);
    }

    fn getLocal(self: *VM, idx: u32) i32 {
        if (idx >= NUM_LOCALS) return 0;
        return self.locals[idx];
    }

    fn setLocal(self: *VM, idx: u32, value: i32) void {
        if (idx < NUM_LOCALS) {
            self.locals[idx] = value;
        }
    }

    // Set function arguments (locals 0, 1, 2, ...)
    pub fn setArgs(self: *VM, args: []const i32) void {
        for (args, 0..) |arg, i| {
            if (i < NUM_LOCALS) {
                self.locals[i] = arg;
            }
        }
    }
};

// Tests
test "VM init and deinit" {
    const vm = try VM.init(std.testing.allocator);
    defer vm.deinit();
    try std.testing.expectEqual(@as(usize, STACK_SIZE), vm.sp);
    try std.testing.expect(!vm.halted);
}

test "VM execute T_CONST" {
    const vm = try VM.init(std.testing.allocator);
    defer vm.deinit();

    // Build minimal .trit: header + T_CONST v0 = 42 + T_RET v0
    var code: [50]u8 = undefined;
    // Header
    std.mem.writeInt(u32, code[0..4], TRIT_MAGIC, .little);
    std.mem.writeInt(u32, code[4..8], 1, .little); // version
    std.mem.writeInt(u32, code[8..12], 0, .little); // flags
    std.mem.writeInt(u32, code[12..16], 0, .little); // entry
    std.mem.writeInt(u32, code[16..20], 0, .little); // num funcs
    std.mem.writeInt(u32, code[20..24], 0, .little); // num globals
    // T_CONST v0 = 42
    code[24] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[25..29], 0, .little); // dest = v0
    std.mem.writeInt(i32, code[29..33], 42, .little); // value = 42
    // T_RET v0
    code[33] = @intFromEnum(TritOpcode.T_RET);
    std.mem.writeInt(u32, code[34..38], 0, .little); // ret v0

    try vm.load(code[0..38]);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "VM execute T_ADD" {
    const vm = try VM.init(std.testing.allocator);
    defer vm.deinit();

    var code: [70]u8 = undefined;
    // Header
    std.mem.writeInt(u32, code[0..4], TRIT_MAGIC, .little);
    std.mem.writeInt(u32, code[4..8], 1, .little);
    std.mem.writeInt(u32, code[8..12], 0, .little);
    std.mem.writeInt(u32, code[12..16], 0, .little);
    std.mem.writeInt(u32, code[16..20], 0, .little);
    std.mem.writeInt(u32, code[20..24], 0, .little);
    // T_CONST v1 = 10
    code[24] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[25..29], 1, .little);
    std.mem.writeInt(i32, code[29..33], 10, .little);
    // T_CONST v2 = 32
    code[33] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[34..38], 2, .little);
    std.mem.writeInt(i32, code[38..42], 32, .little);
    // T_ADD v0 = v1 + v2
    code[42] = @intFromEnum(TritOpcode.T_ADD);
    std.mem.writeInt(u32, code[43..47], 0, .little);
    std.mem.writeInt(u32, code[47..51], 1, .little);
    std.mem.writeInt(u32, code[51..55], 2, .little);
    // T_RET v0
    code[55] = @intFromEnum(TritOpcode.T_RET);
    std.mem.writeInt(u32, code[56..60], 0, .little);

    try vm.load(code[0..60]);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "VM execute T_SUB" {
    const vm = try VM.init(std.testing.allocator);
    defer vm.deinit();

    var code: [70]u8 = undefined;
    std.mem.writeInt(u32, code[0..4], TRIT_MAGIC, .little);
    std.mem.writeInt(u32, code[4..8], 1, .little);
    std.mem.writeInt(u32, code[8..12], 0, .little);
    std.mem.writeInt(u32, code[12..16], 0, .little);
    std.mem.writeInt(u32, code[16..20], 0, .little);
    std.mem.writeInt(u32, code[20..24], 0, .little);
    // T_CONST v1 = 100
    code[24] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[25..29], 1, .little);
    std.mem.writeInt(i32, code[29..33], 100, .little);
    // T_CONST v2 = 58
    code[33] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[34..38], 2, .little);
    std.mem.writeInt(i32, code[38..42], 58, .little);
    // T_SUB v0 = v1 - v2
    code[42] = @intFromEnum(TritOpcode.T_SUB);
    std.mem.writeInt(u32, code[43..47], 0, .little);
    std.mem.writeInt(u32, code[47..51], 1, .little);
    std.mem.writeInt(u32, code[51..55], 2, .little);
    // T_RET v0
    code[55] = @intFromEnum(TritOpcode.T_RET);
    std.mem.writeInt(u32, code[56..60], 0, .little);

    try vm.load(code[0..60]);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "VM execute T_MUL" {
    const vm = try VM.init(std.testing.allocator);
    defer vm.deinit();

    var code: [70]u8 = undefined;
    std.mem.writeInt(u32, code[0..4], TRIT_MAGIC, .little);
    std.mem.writeInt(u32, code[4..8], 1, .little);
    std.mem.writeInt(u32, code[8..12], 0, .little);
    std.mem.writeInt(u32, code[12..16], 0, .little);
    std.mem.writeInt(u32, code[16..20], 0, .little);
    std.mem.writeInt(u32, code[20..24], 0, .little);
    // T_CONST v1 = 6
    code[24] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[25..29], 1, .little);
    std.mem.writeInt(i32, code[29..33], 6, .little);
    // T_CONST v2 = 7
    code[33] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[34..38], 2, .little);
    std.mem.writeInt(i32, code[38..42], 7, .little);
    // T_MUL v0 = v1 * v2
    code[42] = @intFromEnum(TritOpcode.T_MUL);
    std.mem.writeInt(u32, code[43..47], 0, .little);
    std.mem.writeInt(u32, code[47..51], 1, .little);
    std.mem.writeInt(u32, code[51..55], 2, .little);
    // T_RET v0
    code[55] = @intFromEnum(TritOpcode.T_RET);
    std.mem.writeInt(u32, code[56..60], 0, .little);

    try vm.load(code[0..60]);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "VM execute T_DIV" {
    const vm = try VM.init(std.testing.allocator);
    defer vm.deinit();

    var code: [70]u8 = undefined;
    std.mem.writeInt(u32, code[0..4], TRIT_MAGIC, .little);
    std.mem.writeInt(u32, code[4..8], 1, .little);
    std.mem.writeInt(u32, code[8..12], 0, .little);
    std.mem.writeInt(u32, code[12..16], 0, .little);
    std.mem.writeInt(u32, code[16..20], 0, .little);
    std.mem.writeInt(u32, code[20..24], 0, .little);
    // T_CONST v1 = 126
    code[24] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[25..29], 1, .little);
    std.mem.writeInt(i32, code[29..33], 126, .little);
    // T_CONST v2 = 3
    code[33] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[34..38], 2, .little);
    std.mem.writeInt(i32, code[38..42], 3, .little);
    // T_DIV v0 = v1 / v2
    code[42] = @intFromEnum(TritOpcode.T_DIV);
    std.mem.writeInt(u32, code[43..47], 0, .little);
    std.mem.writeInt(u32, code[47..51], 1, .little);
    std.mem.writeInt(u32, code[51..55], 2, .little);
    // T_RET v0
    code[55] = @intFromEnum(TritOpcode.T_RET);
    std.mem.writeInt(u32, code[56..60], 0, .little);

    try vm.load(code[0..60]);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "VM execute T_LOAD and T_STORE" {
    const vm = try VM.init(std.testing.allocator);
    defer vm.deinit();

    var code: [90]u8 = undefined;
    std.mem.writeInt(u32, code[0..4], TRIT_MAGIC, .little);
    std.mem.writeInt(u32, code[4..8], 1, .little);
    std.mem.writeInt(u32, code[8..12], 0, .little);
    std.mem.writeInt(u32, code[12..16], 0, .little);
    std.mem.writeInt(u32, code[16..20], 0, .little);
    std.mem.writeInt(u32, code[20..24], 0, .little);
    // T_CONST v1 = 42 (value to store)
    code[24] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[25..29], 1, .little);
    std.mem.writeInt(i32, code[29..33], 42, .little);
    // T_CONST v2 = 100 (base address)
    code[33] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[34..38], 2, .little);
    std.mem.writeInt(i32, code[38..42], 100, .little);
    // T_STORE [v2+0] = v1 (store 42 at address 100)
    code[42] = @intFromEnum(TritOpcode.T_STORE);
    std.mem.writeInt(u32, code[43..47], 2, .little); // addr reg
    std.mem.writeInt(u32, code[47..51], 1, .little); // value reg
    std.mem.writeInt(u32, code[51..55], 0, .little); // offset = 0
    // T_LOAD v0 = [v2+0] (load from address 100)
    code[55] = @intFromEnum(TritOpcode.T_LOAD);
    std.mem.writeInt(u32, code[56..60], 0, .little); // dest
    std.mem.writeInt(u32, code[60..64], 2, .little); // addr reg
    std.mem.writeInt(u32, code[64..68], 0, .little); // offset = 0
    // T_RET v0
    code[68] = @intFromEnum(TritOpcode.T_RET);
    std.mem.writeInt(u32, code[69..73], 0, .little);

    try vm.load(code[0..73]);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "VM execute T_CMP" {
    const vm = try VM.init(std.testing.allocator);
    defer vm.deinit();

    var code: [80]u8 = undefined;
    std.mem.writeInt(u32, code[0..4], TRIT_MAGIC, .little);
    std.mem.writeInt(u32, code[4..8], 1, .little);
    std.mem.writeInt(u32, code[8..12], 0, .little);
    std.mem.writeInt(u32, code[12..16], 0, .little);
    std.mem.writeInt(u32, code[16..20], 0, .little);
    std.mem.writeInt(u32, code[20..24], 0, .little);
    // T_CONST v1 = 10
    code[24] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[25..29], 1, .little);
    std.mem.writeInt(i32, code[29..33], 10, .little);
    // T_CONST v2 = 5
    code[33] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[34..38], 2, .little);
    std.mem.writeInt(i32, code[38..42], 5, .little);
    // T_CMP v0 = cmp(v1, v2) -> 1 (10 > 5)
    code[42] = @intFromEnum(TritOpcode.T_CMP);
    std.mem.writeInt(u32, code[43..47], 0, .little);
    std.mem.writeInt(u32, code[47..51], 1, .little);
    std.mem.writeInt(u32, code[51..55], 2, .little);
    // T_RET v0
    code[55] = @intFromEnum(TritOpcode.T_RET);
    std.mem.writeInt(u32, code[56..60], 0, .little);

    try vm.load(code[0..60]);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i32, 1), result); // 10 > 5 = +1
}

test "VM execute complex expression" {
    // Compute: (3 + 4) * 6 = 42
    const vm = try VM.init(std.testing.allocator);
    defer vm.deinit();

    var code: [100]u8 = undefined;
    std.mem.writeInt(u32, code[0..4], TRIT_MAGIC, .little);
    std.mem.writeInt(u32, code[4..8], 1, .little);
    std.mem.writeInt(u32, code[8..12], 0, .little);
    std.mem.writeInt(u32, code[12..16], 0, .little);
    std.mem.writeInt(u32, code[16..20], 0, .little);
    std.mem.writeInt(u32, code[20..24], 0, .little);
    // T_CONST v1 = 3
    code[24] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[25..29], 1, .little);
    std.mem.writeInt(i32, code[29..33], 3, .little);
    // T_CONST v2 = 4
    code[33] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[34..38], 2, .little);
    std.mem.writeInt(i32, code[38..42], 4, .little);
    // T_ADD v3 = v1 + v2 (= 7)
    code[42] = @intFromEnum(TritOpcode.T_ADD);
    std.mem.writeInt(u32, code[43..47], 3, .little);
    std.mem.writeInt(u32, code[47..51], 1, .little);
    std.mem.writeInt(u32, code[51..55], 2, .little);
    // T_CONST v4 = 6
    code[55] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[56..60], 4, .little);
    std.mem.writeInt(i32, code[60..64], 6, .little);
    // T_MUL v0 = v3 * v4 (= 42)
    code[64] = @intFromEnum(TritOpcode.T_MUL);
    std.mem.writeInt(u32, code[65..69], 0, .little);
    std.mem.writeInt(u32, code[69..73], 3, .little);
    std.mem.writeInt(u32, code[73..77], 4, .little);
    // T_RET v0
    code[77] = @intFromEnum(TritOpcode.T_RET);
    std.mem.writeInt(u32, code[78..82], 0, .little);

    try vm.load(code[0..82]);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "VM execute with arguments via locals" {
    // Simulate add(3, 4) = 7 using T_GET_LOCAL
    const vm = try VM.init(std.testing.allocator);
    defer vm.deinit();

    var code: [80]u8 = undefined;
    std.mem.writeInt(u32, code[0..4], TRIT_MAGIC, .little);
    std.mem.writeInt(u32, code[4..8], 1, .little);
    std.mem.writeInt(u32, code[8..12], 0, .little);
    std.mem.writeInt(u32, code[12..16], 0, .little);
    std.mem.writeInt(u32, code[16..20], 0, .little);
    std.mem.writeInt(u32, code[20..24], 0, .little);
    // T_GET_LOCAL v1 = local[0] (arg 0)
    code[24] = @intFromEnum(TritOpcode.T_GET_LOCAL);
    std.mem.writeInt(u32, code[25..29], 1, .little); // dest = v1
    std.mem.writeInt(u32, code[29..33], 0, .little); // local idx = 0
    // T_GET_LOCAL v2 = local[1] (arg 1)
    code[33] = @intFromEnum(TritOpcode.T_GET_LOCAL);
    std.mem.writeInt(u32, code[34..38], 2, .little); // dest = v2
    std.mem.writeInt(u32, code[38..42], 1, .little); // local idx = 1
    // T_ADD v0 = v1 + v2
    code[42] = @intFromEnum(TritOpcode.T_ADD);
    std.mem.writeInt(u32, code[43..47], 0, .little);
    std.mem.writeInt(u32, code[47..51], 1, .little);
    std.mem.writeInt(u32, code[51..55], 2, .little);
    // T_RET v0
    code[55] = @intFromEnum(TritOpcode.T_RET);
    std.mem.writeInt(u32, code[56..60], 0, .little);

    try vm.load(code[0..60]);
    // Set arguments: add(3, 4)
    vm.setArgs(&[_]i32{ 3, 4 });
    const result = try vm.run();
    try std.testing.expectEqual(@as(i32, 7), result);
}

test "VM execute T_TADD (native ternary add)" {
    const vm = try VM.init(std.testing.allocator);
    defer vm.deinit();

    var code: [70]u8 = undefined;
    std.mem.writeInt(u32, code[0..4], TRIT_MAGIC, .little);
    std.mem.writeInt(u32, code[4..8], 1, .little);
    std.mem.writeInt(u32, code[8..12], 0, .little);
    std.mem.writeInt(u32, code[12..16], 0, .little);
    std.mem.writeInt(u32, code[16..20], 0, .little);
    std.mem.writeInt(u32, code[20..24], 0, .little);
    // T_CONST v1 = 3
    code[24] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[25..29], 1, .little);
    std.mem.writeInt(i32, code[29..33], 3, .little);
    // T_CONST v2 = 4
    code[33] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[34..38], 2, .little);
    std.mem.writeInt(i32, code[38..42], 4, .little);
    // T_TADD v0 = v1 + v2 (native ternary)
    code[42] = @intFromEnum(TritOpcode.T_TADD);
    std.mem.writeInt(u32, code[43..47], 0, .little);
    std.mem.writeInt(u32, code[47..51], 1, .little);
    std.mem.writeInt(u32, code[51..55], 2, .little);
    // T_RET v0
    code[55] = @intFromEnum(TritOpcode.T_RET);
    std.mem.writeInt(u32, code[56..60], 0, .little);

    try vm.load(code[0..60]);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i32, 7), result);
}

test "VM execute T_TMUL (native ternary mul)" {
    const vm = try VM.init(std.testing.allocator);
    defer vm.deinit();

    var code: [70]u8 = undefined;
    std.mem.writeInt(u32, code[0..4], TRIT_MAGIC, .little);
    std.mem.writeInt(u32, code[4..8], 1, .little);
    std.mem.writeInt(u32, code[8..12], 0, .little);
    std.mem.writeInt(u32, code[12..16], 0, .little);
    std.mem.writeInt(u32, code[16..20], 0, .little);
    std.mem.writeInt(u32, code[20..24], 0, .little);
    // T_CONST v1 = 6
    code[24] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[25..29], 1, .little);
    std.mem.writeInt(i32, code[29..33], 6, .little);
    // T_CONST v2 = 7
    code[33] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[34..38], 2, .little);
    std.mem.writeInt(i32, code[38..42], 7, .little);
    // T_TMUL v0 = v1 * v2 (native ternary)
    code[42] = @intFromEnum(TritOpcode.T_TMUL);
    std.mem.writeInt(u32, code[43..47], 0, .little);
    std.mem.writeInt(u32, code[47..51], 1, .little);
    std.mem.writeInt(u32, code[51..55], 2, .little);
    // T_RET v0
    code[55] = @intFromEnum(TritOpcode.T_RET);
    std.mem.writeInt(u32, code[56..60], 0, .little);

    try vm.load(code[0..60]);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "VM execute T_TCMP (native ternary compare)" {
    const vm = try VM.init(std.testing.allocator);
    defer vm.deinit();

    var code: [70]u8 = undefined;
    std.mem.writeInt(u32, code[0..4], TRIT_MAGIC, .little);
    std.mem.writeInt(u32, code[4..8], 1, .little);
    std.mem.writeInt(u32, code[8..12], 0, .little);
    std.mem.writeInt(u32, code[12..16], 0, .little);
    std.mem.writeInt(u32, code[16..20], 0, .little);
    std.mem.writeInt(u32, code[20..24], 0, .little);
    // T_CONST v1 = 10
    code[24] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[25..29], 1, .little);
    std.mem.writeInt(i32, code[29..33], 10, .little);
    // T_CONST v2 = 5
    code[33] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[34..38], 2, .little);
    std.mem.writeInt(i32, code[38..42], 5, .little);
    // T_TCMP v0 = cmp(v1, v2) -> +1 (10 > 5)
    code[42] = @intFromEnum(TritOpcode.T_TCMP);
    std.mem.writeInt(u32, code[43..47], 0, .little);
    std.mem.writeInt(u32, code[47..51], 1, .little);
    std.mem.writeInt(u32, code[51..55], 2, .little);
    // T_RET v0
    code[55] = @intFromEnum(TritOpcode.T_RET);
    std.mem.writeInt(u32, code[56..60], 0, .little);

    try vm.load(code[0..60]);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i32, 1), result); // +1 = greater
}

test "VM execute T_TNEG (native ternary negate)" {
    const vm = try VM.init(std.testing.allocator);
    defer vm.deinit();

    var code: [60]u8 = undefined;
    std.mem.writeInt(u32, code[0..4], TRIT_MAGIC, .little);
    std.mem.writeInt(u32, code[4..8], 1, .little);
    std.mem.writeInt(u32, code[8..12], 0, .little);
    std.mem.writeInt(u32, code[12..16], 0, .little);
    std.mem.writeInt(u32, code[16..20], 0, .little);
    std.mem.writeInt(u32, code[20..24], 0, .little);
    // T_CONST v1 = 42
    code[24] = @intFromEnum(TritOpcode.T_CONST);
    std.mem.writeInt(u32, code[25..29], 1, .little);
    std.mem.writeInt(i32, code[29..33], 42, .little);
    // T_TNEG v0 = -v1
    code[33] = @intFromEnum(TritOpcode.T_TNEG);
    std.mem.writeInt(u32, code[34..38], 0, .little);
    std.mem.writeInt(u32, code[38..42], 1, .little);
    // T_RET v0
    code[42] = @intFromEnum(TritOpcode.T_RET);
    std.mem.writeInt(u32, code[43..47], 0, .little);

    try vm.load(code[0..47]);
    const result = try vm.run();
    try std.testing.expectEqual(@as(i32, -42), result);
}
