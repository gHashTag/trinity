// JIT Compiler - TIR to x86_64 Native Code
// Compiles TIR bytecode to native machine code for 10-100x speedup
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const b2t_codegen = @import("b2t_codegen.zig");
const TritOpcode = b2t_codegen.TritOpcode;

// ═══════════════════════════════════════════════════════════════════════════════
// JIT COMPILER CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const JIT_CODE_SIZE: usize = 4096; // 4KB per function
pub const JIT_MAX_FUNCTIONS: usize = 256;

// x86_64 System V AMD64 ABI:
// Arguments: rdi, rsi, rdx, rcx, r8, r9
// Return: rax
// Callee-saved: rbx, rbp, r12-r15
// Caller-saved: rax, rcx, rdx, rsi, rdi, r8-r11

// Register encoding for ModR/M
const REG_RAX: u8 = 0;
const REG_RCX: u8 = 1;
const REG_RDX: u8 = 2;
const REG_RBX: u8 = 3;
const REG_RSP: u8 = 4;
const REG_RBP: u8 = 5;
const REG_RSI: u8 = 6;
const REG_RDI: u8 = 7;

// ═══════════════════════════════════════════════════════════════════════════════
// MACHINE CODE BUFFER
// ═══════════════════════════════════════════════════════════════════════════════

pub const MachineCode = struct {
    code: []align(4096) u8,
    len: usize,
    allocator: std.mem.Allocator,
    executable: bool,

    pub fn init(allocator: std.mem.Allocator, size: usize) !MachineCode {
        // Allocate page-aligned memory for executable code
        const code = try allocator.alignedAlloc(u8, 4096, size);
        @memset(code, 0xCC); // Fill with INT3 (breakpoint) for safety

        return MachineCode{
            .code = code,
            .len = 0,
            .allocator = allocator,
            .executable = false,
        };
    }

    pub fn deinit(self: *MachineCode) void {
        if (self.executable) {
            // Make writable again before freeing
            self.makeWritable() catch {};
        }
        self.allocator.free(self.code);
    }

    /// Emit a single byte
    pub fn emit(self: *MachineCode, byte: u8) void {
        if (self.len < self.code.len) {
            self.code[self.len] = byte;
            self.len += 1;
        }
    }

    /// Emit multiple bytes
    pub fn emitBytes(self: *MachineCode, bytes: []const u8) void {
        for (bytes) |b| {
            self.emit(b);
        }
    }

    /// Emit a 32-bit immediate (little-endian)
    pub fn emitImm32(self: *MachineCode, value: i32) void {
        const bytes = std.mem.asBytes(&value);
        self.emitBytes(bytes);
    }

    /// Emit a 64-bit immediate (little-endian)
    pub fn emitImm64(self: *MachineCode, value: i64) void {
        const bytes = std.mem.asBytes(&value);
        self.emitBytes(bytes);
    }

    /// Make code executable (Linux mprotect)
    pub fn makeExecutable(self: *MachineCode) !void {
        if (self.executable) return;

        // Use raw syscall for mprotect
        const PROT_READ: usize = 0x1;
        const PROT_EXEC: usize = 0x4;

        const addr = @intFromPtr(self.code.ptr);
        const len = self.code.len;

        // syscall: mprotect(addr, len, prot)
        const result = std.os.linux.syscall3(.mprotect, addr, len, PROT_READ | PROT_EXEC);
        if (result != 0) {
            return error.MprotectFailed;
        }

        self.executable = true;
    }

    /// Make code writable again
    pub fn makeWritable(self: *MachineCode) !void {
        if (!self.executable) return;

        const PROT_READ: usize = 0x1;
        const PROT_WRITE: usize = 0x2;

        const addr = @intFromPtr(self.code.ptr);
        const len = self.code.len;

        const result = std.os.linux.syscall3(.mprotect, addr, len, PROT_READ | PROT_WRITE);
        if (result != 0) {
            return error.MprotectFailed;
        }

        self.executable = false;
    }

    /// Get function pointer to execute the code
    pub fn getFunction(self: *MachineCode, comptime T: type) T {
        return @ptrCast(self.code.ptr);
    }

    /// Reset for reuse
    pub fn reset(self: *MachineCode) void {
        self.len = 0;
        @memset(self.code, 0xCC);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// X86_64 CODE GENERATION HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

pub const X86_64 = struct {
    /// REX prefix for 64-bit operations
    pub fn rex_w() u8 {
        return 0x48; // REX.W
    }

    /// REX prefix with register extension
    pub fn rex_wr(reg: u8) u8 {
        return 0x48 | ((reg >> 3) & 1); // REX.W + REX.R if reg >= 8
    }

    /// ModR/M byte: mod=11 (register), reg, rm
    pub fn modrm_reg(reg: u8, rm: u8) u8 {
        return 0xC0 | ((reg & 7) << 3) | (rm & 7);
    }

    /// ModR/M byte: mod=00 (memory [rm]), reg
    pub fn modrm_mem(reg: u8, rm: u8) u8 {
        return 0x00 | ((reg & 7) << 3) | (rm & 7);
    }

    /// ModR/M byte: mod=01 (memory [rm + disp8]), reg
    pub fn modrm_mem_disp8(reg: u8, rm: u8) u8 {
        return 0x40 | ((reg & 7) << 3) | (rm & 7);
    }

    /// ModR/M byte: mod=10 (memory [rm + disp32]), reg
    pub fn modrm_mem_disp32(reg: u8, rm: u8) u8 {
        return 0x80 | ((reg & 7) << 3) | (rm & 7);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// JIT COMPILER
// ═══════════════════════════════════════════════════════════════════════════════

pub const JitCompiler = struct {
    code: MachineCode,
    allocator: std.mem.Allocator,
    stack_offset: i32, // Current stack offset for locals

    pub fn init(allocator: std.mem.Allocator) !JitCompiler {
        return JitCompiler{
            .code = try MachineCode.init(allocator, JIT_CODE_SIZE),
            .allocator = allocator,
            .stack_offset = 0,
        };
    }

    pub fn deinit(self: *JitCompiler) void {
        self.code.deinit();
    }

    /// Compile TIR bytecode to native x86_64
    pub fn compile(self: *JitCompiler, tir: []const u8) !void {
        self.code.reset();
        self.stack_offset = 0;

        // Function prologue
        self.emitPrologue();

        // Compile TIR instructions
        var pc: usize = 0;
        while (pc < tir.len) {
            const opcode = tir[pc];
            pc += 1;

            if (opcode == @intFromEnum(TritOpcode.T_CONST)) {
                // Push constant onto stack
                if (pc + 4 > tir.len) break;
                const value = std.mem.readInt(i32, tir[pc..][0..4], .little);
                pc += 4;
                self.emitPushConst(value);
            } else if (opcode == @intFromEnum(TritOpcode.T_ADD)) {
                self.emitAdd();
            } else if (opcode == @intFromEnum(TritOpcode.T_SUB)) {
                self.emitSub();
            } else if (opcode == @intFromEnum(TritOpcode.T_MUL)) {
                self.emitMul();
            } else if (opcode == @intFromEnum(TritOpcode.T_DIV)) {
                self.emitDiv();
            } else if (opcode == @intFromEnum(TritOpcode.T_RET)) {
                self.emitReturn();
                break;
            } else if (opcode == @intFromEnum(TritOpcode.T_LOAD)) {
                if (pc + 4 > tir.len) break;
                const idx = std.mem.readInt(u32, tir[pc..][0..4], .little);
                pc += 4;
                self.emitLoad(idx);
            } else if (opcode == @intFromEnum(TritOpcode.T_STORE)) {
                if (pc + 4 > tir.len) break;
                const idx = std.mem.readInt(u32, tir[pc..][0..4], .little);
                pc += 4;
                self.emitStore(idx);
            } else if (opcode == @intFromEnum(TritOpcode.T_NOP)) {
                // NOP - do nothing
            } else if (opcode == @intFromEnum(TritOpcode.T_HALT)) {
                self.emitReturn();
                break;
            }
        }

        // Make executable
        try self.code.makeExecutable();
    }

    /// Emit function prologue
    fn emitPrologue(self: *JitCompiler) void {
        // push rbp
        self.code.emit(0x55);
        // mov rbp, rsp
        self.code.emitBytes(&[_]u8{ 0x48, 0x89, 0xE5 });
        // sub rsp, 256 (reserve space for locals)
        self.code.emitBytes(&[_]u8{ 0x48, 0x81, 0xEC });
        self.code.emitImm32(256);
        // Save first argument (rdi) to local 0
        // mov [rbp-8], rdi
        self.code.emitBytes(&[_]u8{ 0x48, 0x89, 0x7D, 0xF8 });
    }

    /// Emit function epilogue and return
    fn emitReturn(self: *JitCompiler) void {
        // Pop result into rax
        self.emitPopRax();
        // mov rsp, rbp
        self.code.emitBytes(&[_]u8{ 0x48, 0x89, 0xEC });
        // pop rbp
        self.code.emit(0x5D);
        // ret
        self.code.emit(0xC3);
    }

    /// Push constant onto evaluation stack (using rax)
    fn emitPushConst(self: *JitCompiler, value: i32) void {
        // mov eax, imm32
        self.code.emit(0xB8);
        self.code.emitImm32(value);
        // push rax
        self.code.emit(0x50);
        self.stack_offset += 8;
    }

    /// Pop into rax
    fn emitPopRax(self: *JitCompiler) void {
        // pop rax
        self.code.emit(0x58);
        self.stack_offset -= 8;
    }

    /// Pop into rcx
    fn emitPopRcx(self: *JitCompiler) void {
        // pop rcx
        self.code.emit(0x59);
        self.stack_offset -= 8;
    }

    /// Push rax
    fn emitPushRax(self: *JitCompiler) void {
        // push rax
        self.code.emit(0x50);
        self.stack_offset += 8;
    }

    /// Add: pop two, push result
    fn emitAdd(self: *JitCompiler) void {
        // pop rcx (second operand)
        self.emitPopRcx();
        // pop rax (first operand)
        self.emitPopRax();
        // add eax, ecx
        self.code.emitBytes(&[_]u8{ 0x01, 0xC8 });
        // push rax
        self.emitPushRax();
    }

    /// Sub: pop two, push result
    fn emitSub(self: *JitCompiler) void {
        // pop rcx (second operand)
        self.emitPopRcx();
        // pop rax (first operand)
        self.emitPopRax();
        // sub eax, ecx
        self.code.emitBytes(&[_]u8{ 0x29, 0xC8 });
        // push rax
        self.emitPushRax();
    }

    /// Mul: pop two, push result
    fn emitMul(self: *JitCompiler) void {
        // pop rcx (second operand)
        self.emitPopRcx();
        // pop rax (first operand)
        self.emitPopRax();
        // imul eax, ecx
        self.code.emitBytes(&[_]u8{ 0x0F, 0xAF, 0xC1 });
        // push rax
        self.emitPushRax();
    }

    /// Div: pop two, push result
    fn emitDiv(self: *JitCompiler) void {
        // pop rcx (divisor)
        self.emitPopRcx();
        // pop rax (dividend)
        self.emitPopRax();
        // cdq (sign-extend eax into edx:eax)
        self.code.emit(0x99);
        // idiv ecx
        self.code.emitBytes(&[_]u8{ 0xF7, 0xF9 });
        // push rax (quotient)
        self.emitPushRax();
    }

    /// Load local variable onto stack
    fn emitLoad(self: *JitCompiler, idx: u32) void {
        // mov eax, [rbp - 8 - idx*8]
        const offset: i8 = @intCast(-8 - @as(i32, @intCast(idx)) * 8);
        self.code.emitBytes(&[_]u8{ 0x8B, 0x45 });
        self.code.emit(@bitCast(offset));
        // push rax
        self.emitPushRax();
    }

    /// Store top of stack to local variable
    fn emitStore(self: *JitCompiler, idx: u32) void {
        // pop rax
        self.emitPopRax();
        // mov [rbp - 8 - idx*8], eax
        const offset: i8 = @intCast(-8 - @as(i32, @intCast(idx)) * 8);
        self.code.emitBytes(&[_]u8{ 0x89, 0x45 });
        self.code.emit(@bitCast(offset));
    }

    /// Execute compiled code with argument
    pub fn execute(self: *JitCompiler, arg: i32) i32 {
        const func = self.code.getFunction(*const fn (i32) callconv(.C) i32);
        return func(arg);
    }

    /// Execute compiled code without arguments
    pub fn executeNoArgs(self: *JitCompiler) i32 {
        const func = self.code.getFunction(*const fn () callconv(.C) i32);
        return func();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "JIT compile constant" {
    var jit = try JitCompiler.init(std.testing.allocator);
    defer jit.deinit();

    // TIR: push 42, ret
    const tir = [_]u8{
        @intFromEnum(TritOpcode.T_CONST), 0x2A, 0x00, 0x00, 0x00, // push 42
        @intFromEnum(TritOpcode.T_RET),
    };

    try jit.compile(&tir);
    const result = jit.executeNoArgs();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "JIT compile add" {
    var jit = try JitCompiler.init(std.testing.allocator);
    defer jit.deinit();

    // TIR: push 10, push 32, add, ret
    const tir = [_]u8{
        @intFromEnum(TritOpcode.T_CONST), 0x0A, 0x00, 0x00, 0x00, // push 10
        @intFromEnum(TritOpcode.T_CONST), 0x20, 0x00, 0x00, 0x00, // push 32
        @intFromEnum(TritOpcode.T_ADD),
        @intFromEnum(TritOpcode.T_RET),
    };

    try jit.compile(&tir);
    const result = jit.executeNoArgs();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "JIT compile sub" {
    var jit = try JitCompiler.init(std.testing.allocator);
    defer jit.deinit();

    // TIR: push 50, push 8, sub, ret
    const tir = [_]u8{
        @intFromEnum(TritOpcode.T_CONST), 0x32, 0x00, 0x00, 0x00, // push 50
        @intFromEnum(TritOpcode.T_CONST), 0x08, 0x00, 0x00, 0x00, // push 8
        @intFromEnum(TritOpcode.T_SUB),
        @intFromEnum(TritOpcode.T_RET),
    };

    try jit.compile(&tir);
    const result = jit.executeNoArgs();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "JIT compile mul" {
    var jit = try JitCompiler.init(std.testing.allocator);
    defer jit.deinit();

    // TIR: push 6, push 7, mul, ret
    const tir = [_]u8{
        @intFromEnum(TritOpcode.T_CONST), 0x06, 0x00, 0x00, 0x00, // push 6
        @intFromEnum(TritOpcode.T_CONST), 0x07, 0x00, 0x00, 0x00, // push 7
        @intFromEnum(TritOpcode.T_MUL),
        @intFromEnum(TritOpcode.T_RET),
    };

    try jit.compile(&tir);
    const result = jit.executeNoArgs();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "JIT compile div" {
    var jit = try JitCompiler.init(std.testing.allocator);
    defer jit.deinit();

    // TIR: push 84, push 2, div, ret
    const tir = [_]u8{
        @intFromEnum(TritOpcode.T_CONST), 0x54, 0x00, 0x00, 0x00, // push 84
        @intFromEnum(TritOpcode.T_CONST), 0x02, 0x00, 0x00, 0x00, // push 2
        @intFromEnum(TritOpcode.T_DIV),
        @intFromEnum(TritOpcode.T_RET),
    };

    try jit.compile(&tir);
    const result = jit.executeNoArgs();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "JIT compile complex expression" {
    var jit = try JitCompiler.init(std.testing.allocator);
    defer jit.deinit();

    // TIR: (10 + 5) * 3 - 3 = 42
    const tir = [_]u8{
        @intFromEnum(TritOpcode.T_CONST), 0x0A, 0x00, 0x00, 0x00, // push 10
        @intFromEnum(TritOpcode.T_CONST), 0x05, 0x00, 0x00, 0x00, // push 5
        @intFromEnum(TritOpcode.T_ADD), // 15
        @intFromEnum(TritOpcode.T_CONST), 0x03, 0x00, 0x00, 0x00, // push 3
        @intFromEnum(TritOpcode.T_MUL), // 45
        @intFromEnum(TritOpcode.T_CONST), 0x03, 0x00, 0x00, 0x00, // push 3
        @intFromEnum(TritOpcode.T_SUB), // 42
        @intFromEnum(TritOpcode.T_RET),
    };

    try jit.compile(&tir);
    const result = jit.executeNoArgs();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "JIT compile load/store" {
    var jit = try JitCompiler.init(std.testing.allocator);
    defer jit.deinit();

    // TIR: load arg0, push 2, mul, ret (double the argument)
    const tir = [_]u8{
        @intFromEnum(TritOpcode.T_LOAD), 0x00, 0x00, 0x00, 0x00, // load local 0 (arg)
        @intFromEnum(TritOpcode.T_CONST), 0x02, 0x00, 0x00, 0x00, // push 2
        @intFromEnum(TritOpcode.T_MUL),
        @intFromEnum(TritOpcode.T_RET),
    };

    try jit.compile(&tir);
    const result = jit.execute(21);
    try std.testing.expectEqual(@as(i32, 42), result);
}
