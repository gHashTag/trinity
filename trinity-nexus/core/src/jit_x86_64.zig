// Trinity JIT Compiler - x86-64 Backend
// Compiles VSA operations to native x86-64 machine code
//
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3

const std = @import("std");
const builtin = @import("builtin");

// ═══════════════════════════════════════════════════════════════════════════════
// X86-64 JIT COMPILER
// ═══════════════════════════════════════════════════════════════════════════════

/// Check if we're on x86-64
pub const is_x86_64 = builtin.cpu.arch == .x86_64;

/// X86-64 JIT Compiler
pub const X86_64JitCompiler = struct {
    code: std.ArrayListUnmanaged(u8),
    allocator: std.mem.Allocator,
    exec_mem: ?[]align(std.heap.page_size_min) u8 = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .code = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.code.deinit(self.allocator);
        if (self.exec_mem) |mem| {
            std.posix.munmap(mem);
        }
    }

    pub fn reset(self: *Self) void {
        self.code.clearRetainingCapacity();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // X86-64 INSTRUCTION ENCODING HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Emit raw bytes
    fn emit(self: *Self, bytes: []const u8) !void {
        try self.code.appendSlice(self.allocator, bytes);
    }

    /// Emit single byte
    fn emit1(self: *Self, b: u8) !void {
        try self.code.append(self.allocator, b);
    }

    /// Emit 32-bit immediate (little-endian)
    fn emitImm32(self: *Self, imm: i32) !void {
        try self.code.appendSlice(self.allocator, std.mem.asBytes(&imm));
    }

    /// Emit 64-bit immediate (little-endian)
    fn emitImm64(self: *Self, imm: i64) !void {
        try self.code.appendSlice(self.allocator, std.mem.asBytes(&imm));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // X86-64 INSTRUCTION ENCODING
    // ═══════════════════════════════════════════════════════════════════════════

    /// push rbp
    fn pushRbp(self: *Self) !void {
        try self.emit1(0x55);
    }

    /// pop rbp
    fn popRbp(self: *Self) !void {
        try self.emit1(0x5D);
    }

    /// mov rbp, rsp
    fn movRbpRsp(self: *Self) !void {
        try self.emit(&[_]u8{ 0x48, 0x89, 0xE5 });
    }

    /// mov rsp, rbp
    fn movRspRbp(self: *Self) !void {
        try self.emit(&[_]u8{ 0x48, 0x89, 0xEC });
    }

    /// ret
    fn ret(self: *Self) !void {
        try self.emit1(0xC3);
    }

    /// xor eax, eax (zero rax)
    fn xorEaxEax(self: *Self) !void {
        try self.emit(&[_]u8{ 0x31, 0xC0 });
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // VSA OPERATION COMPILATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Compile dot product (returns i64 in rax)
    /// x86-64 System V ABI: rdi = first arg, rsi = second arg, rax = return
    pub fn compileDotProduct(self: *Self, dimension: usize) !void {
        self.reset();

        // Function prologue
        try self.pushRbp();
        try self.movRbpRsp();

        // Save callee-saved registers
        try self.emit(&[_]u8{0x53}); // push rbx
        try self.emit(&[_]u8{ 0x41, 0x54 }); // push r12
        try self.emit(&[_]u8{ 0x41, 0x55 }); // push r13
        try self.emit(&[_]u8{ 0x41, 0x56 }); // push r14

        // r12 = a pointer (from rdi)
        try self.emit(&[_]u8{ 0x49, 0x89, 0xFC }); // mov r12, rdi

        // r13 = b pointer (from rsi)
        try self.emit(&[_]u8{ 0x49, 0x89, 0xF5 }); // mov r13, rsi

        // r14 = accumulator (0)
        try self.emit(&[_]u8{ 0x4D, 0x31, 0xF6 }); // xor r14, r14

        // rbx = loop counter (0)
        try self.xorEaxEax();
        try self.emit(&[_]u8{ 0x48, 0x89, 0xC3 }); // mov rbx, rax

        const loop_start = self.code.items.len;

        // Compare rbx with dimension
        try self.emit(&[_]u8{ 0x48, 0x81, 0xFB }); // cmp rbx, imm32
        try self.emitImm32(@intCast(dimension));

        // jge loop_end
        try self.emit(&[_]u8{ 0x0F, 0x8D }); // jge rel32
        const jge_offset = self.code.items.len;
        try self.emitImm32(0); // placeholder

        // Load a[rbx] into eax (sign-extended)
        try self.emit(&[_]u8{ 0x41, 0x0F, 0xBE, 0x04, 0x1C }); // movsx eax, byte [r12 + rbx]

        // Load b[rbx] into ecx (sign-extended)
        try self.emit(&[_]u8{ 0x41, 0x0F, 0xBE, 0x4C, 0x1D, 0x00 }); // movsx ecx, byte [r13 + rbx]

        // imul eax, ecx
        try self.emit(&[_]u8{ 0x0F, 0xAF, 0xC1 }); // imul eax, ecx

        // Sign-extend eax to rax
        try self.emit(&[_]u8{ 0x48, 0x98 }); // cdqe

        // Add to accumulator: r14 += rax
        try self.emit(&[_]u8{ 0x49, 0x01, 0xC6 }); // add r14, rax

        // Increment counter
        try self.emit(&[_]u8{ 0x48, 0xFF, 0xC3 }); // inc rbx

        // Jump back to loop start
        try self.emit(&[_]u8{0xE9}); // jmp rel32
        const loop_back_offset: i32 = @intCast(@as(i64, @intCast(loop_start)) - @as(i64, @intCast(self.code.items.len + 4)));
        try self.emitImm32(loop_back_offset);

        // Patch jge offset
        const loop_end = self.code.items.len;
        const jge_rel: i32 = @intCast(@as(i64, @intCast(loop_end)) - @as(i64, @intCast(jge_offset + 4)));
        @memcpy(self.code.items[jge_offset..][0..4], std.mem.asBytes(&jge_rel));

        // Move result to rax
        try self.emit(&[_]u8{ 0x4C, 0x89, 0xF0 }); // mov rax, r14

        // Restore callee-saved registers
        try self.emit(&[_]u8{ 0x41, 0x5E }); // pop r14
        try self.emit(&[_]u8{ 0x41, 0x5D }); // pop r13
        try self.emit(&[_]u8{ 0x41, 0x5C }); // pop r12
        try self.emit(&[_]u8{0x5B}); // pop rbx

        // Function epilogue
        try self.movRspRbp();
        try self.popRbp();
        try self.ret();
    }

    /// Compile bind operation (element-wise multiply for ternary)
    pub fn compileBindDirect(self: *Self, dimension: usize) !void {
        self.reset();

        // Function prologue
        try self.pushRbp();
        try self.movRbpRsp();

        // Save callee-saved registers
        try self.emit(&[_]u8{0x53}); // push rbx
        try self.emit(&[_]u8{ 0x41, 0x54 }); // push r12
        try self.emit(&[_]u8{ 0x41, 0x55 }); // push r13

        // r12 = a pointer
        try self.emit(&[_]u8{ 0x49, 0x89, 0xFC }); // mov r12, rdi

        // r13 = b pointer
        try self.emit(&[_]u8{ 0x49, 0x89, 0xF5 }); // mov r13, rsi

        // rbx = loop counter (0)
        try self.xorEaxEax();
        try self.emit(&[_]u8{ 0x48, 0x89, 0xC3 }); // mov rbx, rax

        const loop_start = self.code.items.len;

        // Compare rbx with dimension
        try self.emit(&[_]u8{ 0x48, 0x81, 0xFB }); // cmp rbx, imm32
        try self.emitImm32(@intCast(dimension));

        // jge loop_end
        try self.emit(&[_]u8{ 0x0F, 0x8D }); // jge rel32
        const jge_offset = self.code.items.len;
        try self.emitImm32(0); // placeholder

        // Load a[rbx] into al
        try self.emit(&[_]u8{ 0x41, 0x8A, 0x04, 0x1C }); // mov al, [r12 + rbx]

        // Load b[rbx] into cl
        try self.emit(&[_]u8{ 0x41, 0x8A, 0x4C, 0x1D, 0x00 }); // mov cl, [r13 + rbx]

        // imul al, cl (signed multiply)
        try self.emit(&[_]u8{ 0xF6, 0xE9 }); // imul cl

        // Store result back to a[rbx]
        try self.emit(&[_]u8{ 0x41, 0x88, 0x04, 0x1C }); // mov [r12 + rbx], al

        // Increment counter
        try self.emit(&[_]u8{ 0x48, 0xFF, 0xC3 }); // inc rbx

        // Jump back to loop start
        try self.emit(&[_]u8{0xE9}); // jmp rel32
        const loop_back_offset: i32 = @intCast(@as(i64, @intCast(loop_start)) - @as(i64, @intCast(self.code.items.len + 4)));
        try self.emitImm32(loop_back_offset);

        // Patch jge offset
        const loop_end = self.code.items.len;
        const jge_rel: i32 = @intCast(@as(i64, @intCast(loop_end)) - @as(i64, @intCast(jge_offset + 4)));
        @memcpy(self.code.items[jge_offset..][0..4], std.mem.asBytes(&jge_rel));

        // Restore callee-saved registers
        try self.emit(&[_]u8{ 0x41, 0x5D }); // pop r13
        try self.emit(&[_]u8{ 0x41, 0x5C }); // pop r12
        try self.emit(&[_]u8{0x5B}); // pop rbx

        // Function epilogue
        try self.movRspRbp();
        try self.popRbp();
        try self.ret();
    }

    /// Compile bundle operation (element-wise sum with threshold)
    pub fn compileBundleDirect(self: *Self, dimension: usize) !void {
        self.reset();

        // Function prologue
        try self.pushRbp();
        try self.movRbpRsp();

        // Save callee-saved registers
        try self.emit(&[_]u8{0x53}); // push rbx
        try self.emit(&[_]u8{ 0x41, 0x54 }); // push r12
        try self.emit(&[_]u8{ 0x41, 0x55 }); // push r13

        // r12 = a pointer, r13 = b pointer
        try self.emit(&[_]u8{ 0x49, 0x89, 0xFC }); // mov r12, rdi
        try self.emit(&[_]u8{ 0x49, 0x89, 0xF5 }); // mov r13, rsi

        // rbx = loop counter (0)
        try self.xorEaxEax();
        try self.emit(&[_]u8{ 0x48, 0x89, 0xC3 }); // mov rbx, rax

        const loop_start = self.code.items.len;

        // Compare rbx with dimension
        try self.emit(&[_]u8{ 0x48, 0x81, 0xFB }); // cmp rbx, imm32
        try self.emitImm32(@intCast(dimension));

        // jge loop_end
        try self.emit(&[_]u8{ 0x0F, 0x8D }); // jge rel32
        const jge_offset = self.code.items.len;
        try self.emitImm32(0); // placeholder

        // Load a[rbx] into eax (sign-extended)
        try self.emit(&[_]u8{ 0x41, 0x0F, 0xBE, 0x04, 0x1C }); // movsx eax, byte [r12 + rbx]

        // Load b[rbx] into ecx (sign-extended)
        try self.emit(&[_]u8{ 0x41, 0x0F, 0xBE, 0x4C, 0x1D, 0x00 }); // movsx ecx, byte [r13 + rbx]

        // Add eax, ecx
        try self.emit(&[_]u8{ 0x01, 0xC8 }); // add eax, ecx

        // Threshold: if sum > 0 -> 1, if sum < 0 -> -1, else 0
        // cmp eax, 0
        try self.emit(&[_]u8{ 0x83, 0xF8, 0x00 }); // cmp eax, 0

        // setg dl (set dl = 1 if eax > 0)
        try self.emit(&[_]u8{ 0x0F, 0x9F, 0xC2 }); // setg dl

        // setl al (set al = 1 if eax < 0)
        try self.emit(&[_]u8{ 0x0F, 0x9C, 0xC0 }); // setl al

        // Result = dl - al (1 if positive, -1 if negative, 0 if zero)
        try self.emit(&[_]u8{ 0x28, 0xC2 }); // sub dl, al

        // Store result back to a[rbx]
        try self.emit(&[_]u8{ 0x41, 0x88, 0x14, 0x1C }); // mov [r12 + rbx], dl

        // Increment counter
        try self.emit(&[_]u8{ 0x48, 0xFF, 0xC3 }); // inc rbx

        // Jump back to loop start
        try self.emit(&[_]u8{0xE9}); // jmp rel32
        const loop_back_offset: i32 = @intCast(@as(i64, @intCast(loop_start)) - @as(i64, @intCast(self.code.items.len + 4)));
        try self.emitImm32(loop_back_offset);

        // Patch jge offset
        const loop_end = self.code.items.len;
        const jge_rel: i32 = @intCast(@as(i64, @intCast(loop_end)) - @as(i64, @intCast(jge_offset + 4)));
        @memcpy(self.code.items[jge_offset..][0..4], std.mem.asBytes(&jge_rel));

        // Restore callee-saved registers
        try self.emit(&[_]u8{ 0x41, 0x5D }); // pop r13
        try self.emit(&[_]u8{ 0x41, 0x5C }); // pop r12
        try self.emit(&[_]u8{0x5B}); // pop rbx

        // Function epilogue
        try self.movRspRbp();
        try self.popRbp();
        try self.ret();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // EXECUTION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Make code executable and return function pointer
    pub fn finalize(self: *Self) !*const fn (*anyopaque, *anyopaque) callconv(.c) i64 {
        const code_size = self.code.items.len;
        if (code_size == 0) return error.EmptyCode;

        // Use system page size for compatibility
        const page_size: usize = std.heap.page_size_min;
        const alloc_size = std.mem.alignForward(usize, code_size, page_size);

        // mmap with PROT_READ | PROT_WRITE first
        const mem = try std.posix.mmap(
            null,
            alloc_size,
            std.posix.PROT.READ | std.posix.PROT.WRITE,
            .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
            -1,
            0,
        );

        // Copy code
        @memcpy(mem[0..code_size], self.code.items);

        // Change to PROT_READ | PROT_EXEC
        try std.posix.mprotect(mem, std.posix.PROT.READ | std.posix.PROT.EXEC);

        self.exec_mem = mem;

        return @ptrCast(mem.ptr);
    }

    /// Get code size
    pub fn codeSize(self: *const Self) usize {
        return self.code.items.len;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "x86-64 JIT compiler init and deinit" {
    var compiler = X86_64JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    try std.testing.expect(compiler.codeSize() == 0);
}

test "x86-64 JIT dot product compilation" {
    if (!is_x86_64) {
        return; // Skip on non-x86-64
    }

    var compiler = X86_64JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const dim = 8;
    try compiler.compileDotProduct(dim);

    try std.testing.expect(compiler.codeSize() > 0);
}

test "x86-64 JIT dot product execution" {
    if (!is_x86_64) {
        return; // Skip on non-x86-64
    }

    var compiler = X86_64JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const dim = 8;
    try compiler.compileDotProduct(dim);

    const func = try compiler.finalize();

    // Create test data
    var a = [dim]i8{ 1, -1, 1, 0, 1, -1, 0, 1 };
    var b = [dim]i8{ 1, 1, -1, 1, 1, 1, 1, -1 };

    // Expected: 1*1 + (-1)*1 + 1*(-1) + 0*1 + 1*1 + (-1)*1 + 0*1 + 1*(-1)
    //         = 1 - 1 - 1 + 0 + 1 - 1 + 0 - 1 = -2
    const expected: i64 = -2;

    const result = func(@ptrCast(&a), @ptrCast(&b));
    try std.testing.expectEqual(expected, result);
}

test "x86-64 JIT bind compilation" {
    if (!is_x86_64) {
        return;
    }

    var compiler = X86_64JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const dim = 8;
    try compiler.compileBindDirect(dim);

    try std.testing.expect(compiler.codeSize() > 0);
}

test "x86-64 JIT large dimension" {
    if (!is_x86_64) {
        return;
    }

    var compiler = X86_64JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const dim = 1000;
    try compiler.compileDotProduct(dim);

    const func = try compiler.finalize();

    var a: [dim]i8 = undefined;
    var b: [dim]i8 = undefined;
    var expected: i64 = 0;

    for (0..dim) |i| {
        const val_a: i8 = @intCast(@as(i32, @intCast(i % 3)) - 1);
        const val_b: i8 = @intCast(@as(i32, @intCast((i + 1) % 3)) - 1);
        a[i] = val_a;
        b[i] = val_b;
        expected += @as(i64, val_a) * @as(i64, val_b);
    }

    const result = func(@ptrCast(&a), @ptrCast(&b));
    try std.testing.expectEqual(expected, result);
}
