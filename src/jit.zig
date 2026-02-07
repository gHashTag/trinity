// Trinity JIT Compiler
// Compiles VSA operations to native x86-64 machine code
//
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3

const std = @import("std");
const hybrid = @import("hybrid.zig");
const vsa = @import("vsa.zig");

const HybridBigInt = hybrid.HybridBigInt;
const Trit = hybrid.Trit;

// ═══════════════════════════════════════════════════════════════════════════════
// JIT COMPILER
// ═══════════════════════════════════════════════════════════════════════════════

/// JIT-compiled function type for VSA operations
/// Takes two vector pointers and returns result in first pointer
pub const JitVsaFn = *const fn (*HybridBigInt, *HybridBigInt) void;

/// JIT-compiled similarity function
/// Takes two vector pointers and returns f64 similarity
pub const JitSimilarityFn = *const fn (*HybridBigInt, *HybridBigInt) f64;

/// JIT Compiler for VSA operations
pub const JitCompiler = struct {
    /// Code buffer for generated machine code
    code: std.ArrayListUnmanaged(u8) = .{},
    /// Allocator
    allocator: std.mem.Allocator,
    /// Executable memory (mmap'd)
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

    /// Reset code buffer for new compilation
    pub fn reset(self: *Self) void {
        self.code.clearRetainingCapacity();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // X86-64 CODE GENERATION HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Emit raw bytes
    fn emit(self: *Self, bytes: []const u8) !void {
        try self.code.appendSlice(self.allocator, bytes);
    }

    /// Emit single byte
    fn emit1(self: *Self, b: u8) !void {
        try self.code.append(self.allocator, b);
    }

    /// Emit 32-bit immediate
    fn emitImm32(self: *Self, imm: i32) !void {
        const bytes = std.mem.asBytes(&imm);
        try self.code.appendSlice(self.allocator, bytes);
    }

    /// Emit 64-bit immediate
    fn emitImm64(self: *Self, imm: i64) !void {
        const bytes = std.mem.asBytes(&imm);
        try self.code.appendSlice(self.allocator, bytes);
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

    /// mov rax, imm64
    fn movRaxImm64(self: *Self, imm: i64) !void {
        try self.emit(&[_]u8{ 0x48, 0xB8 });
        try self.emitImm64(imm);
    }

    /// mov rdi, rax (first arg = rax)
    fn movRdiRax(self: *Self) !void {
        try self.emit(&[_]u8{ 0x48, 0x89, 0xC7 });
    }

    /// mov rsi, rax (second arg = rax)
    fn movRsiRax(self: *Self) !void {
        try self.emit(&[_]u8{ 0x48, 0x89, 0xC6 });
    }

    /// call rax
    fn callRax(self: *Self) !void {
        try self.emit(&[_]u8{ 0xFF, 0xD0 });
    }

    /// xor eax, eax (zero rax)
    fn xorEaxEax(self: *Self) !void {
        try self.emit(&[_]u8{ 0x31, 0xC0 });
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // VSA OPERATION COMPILATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Compile bind operation
    /// Generates code that calls vsa.bind and stores result
    pub fn compileBind(self: *Self) !void {
        self.reset();

        // Function prologue
        try self.pushRbp();
        try self.movRbpRsp();

        // Arguments are in rdi (a) and rsi (b)
        // We need to call vsa.bind(a, b) and copy result to a

        // For now, generate a simple wrapper that calls the Zig function
        // This is a trampoline approach - not true JIT but demonstrates the pattern

        // Load address of vsa.bind into rax
        const bind_addr = @intFromPtr(&vsa.bind);
        try self.movRaxImm64(@intCast(bind_addr));

        // Call the function (args already in rdi, rsi)
        try self.callRax();

        // Result is in rax (HybridBigInt returned by value - actually on stack)
        // For simplicity, we'll use a different approach

        // Function epilogue
        try self.movRspRbp();
        try self.popRbp();
        try self.ret();
    }

    /// Compile a simple loop that processes vectors element by element
    /// This is actual JIT - generates native code for the operation
    pub fn compileBindDirect(self: *Self, dimension: usize) !void {
        self.reset();

        // This generates actual x86-64 code for:
        // for (i = 0; i < dimension; i++) {
        //     result[i] = a[i] * b[i];
        // }

        // Function prologue
        try self.pushRbp();
        try self.movRbpRsp();

        // Save callee-saved registers
        try self.emit(&[_]u8{ 0x53 }); // push rbx
        try self.emit(&[_]u8{ 0x41, 0x54 }); // push r12
        try self.emit(&[_]u8{ 0x41, 0x55 }); // push r13

        // rdi = pointer to a.unpacked_cache
        // rsi = pointer to b.unpacked_cache
        // We'll store result back to a

        // r12 = a pointer
        try self.emit(&[_]u8{ 0x49, 0x89, 0xFC }); // mov r12, rdi

        // r13 = b pointer
        try self.emit(&[_]u8{ 0x49, 0x89, 0xF5 }); // mov r13, rsi

        // rbx = loop counter (0)
        try self.xorEaxEax();
        try self.emit(&[_]u8{ 0x48, 0x89, 0xC3 }); // mov rbx, rax

        // Loop start label (we'll patch this)
        const loop_start = self.code.items.len;

        // Compare rbx with dimension
        try self.emit(&[_]u8{ 0x48, 0x81, 0xFB }); // cmp rbx, imm32
        try self.emitImm32(@intCast(dimension));

        // jge loop_end (jump if rbx >= dimension)
        try self.emit(&[_]u8{ 0x0F, 0x8D }); // jge rel32
        const jge_offset = self.code.items.len;
        try self.emitImm32(0); // placeholder, will patch

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
        try self.emit(&[_]u8{ 0xE9 }); // jmp rel32
        const loop_back_offset: i32 = @intCast(@as(i64, @intCast(loop_start)) - @as(i64, @intCast(self.code.items.len + 4)));
        try self.emitImm32(loop_back_offset);

        // Loop end - patch the jge offset
        const loop_end = self.code.items.len;
        const jge_rel: i32 = @intCast(@as(i64, @intCast(loop_end)) - @as(i64, @intCast(jge_offset + 4)));
        @memcpy(self.code.items[jge_offset..][0..4], std.mem.asBytes(&jge_rel));

        // Restore callee-saved registers
        try self.emit(&[_]u8{ 0x41, 0x5D }); // pop r13
        try self.emit(&[_]u8{ 0x41, 0x5C }); // pop r12
        try self.emit(&[_]u8{ 0x5B }); // pop rbx

        // Function epilogue
        try self.movRspRbp();
        try self.popRbp();
        try self.ret();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // EXECUTION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Make code executable and return function pointer
    pub fn finalize(self: *Self) !*const fn (*anyopaque, *anyopaque) void {
        const code_size = self.code.items.len;
        if (code_size == 0) return error.EmptyCode;

        // Allocate executable memory
        const page_size = std.heap.page_size_min;
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

    /// Dump generated code (for debugging)
    pub fn dumpCode(self: *const Self, writer: anytype) !void {
        try writer.print("Generated code ({d} bytes):\n", .{self.code.items.len});
        for (self.code.items, 0..) |byte, i| {
            if (i % 16 == 0) {
                try writer.print("\n{x:0>4}: ", .{i});
            }
            try writer.print("{x:0>2} ", .{byte});
        }
        try writer.print("\n", .{});
    }

    /// Compile bundle operation (element-wise sum with threshold)
    pub fn compileBundleDirect(self: *Self, dimension: usize) !void {
        self.reset();

        // Function prologue
        try self.pushRbp();
        try self.movRbpRsp();

        // Save callee-saved registers
        try self.emit(&[_]u8{ 0x53 }); // push rbx
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

        // Load a[rbx] into al (sign-extended to eax)
        try self.emit(&[_]u8{ 0x41, 0x0F, 0xBE, 0x04, 0x1C }); // movsx eax, byte [r12 + rbx]

        // Load b[rbx] into cl (sign-extended to ecx)
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
        try self.emit(&[_]u8{ 0xE9 }); // jmp rel32
        const loop_back_offset: i32 = @intCast(@as(i64, @intCast(loop_start)) - @as(i64, @intCast(self.code.items.len + 4)));
        try self.emitImm32(loop_back_offset);

        // Patch jge offset
        const loop_end = self.code.items.len;
        const jge_rel: i32 = @intCast(@as(i64, @intCast(loop_end)) - @as(i64, @intCast(jge_offset + 4)));
        @memcpy(self.code.items[jge_offset..][0..4], std.mem.asBytes(&jge_rel));

        // Restore callee-saved registers
        try self.emit(&[_]u8{ 0x41, 0x5D }); // pop r13
        try self.emit(&[_]u8{ 0x41, 0x5C }); // pop r12
        try self.emit(&[_]u8{ 0x5B }); // pop rbx

        // Function epilogue
        try self.movRspRbp();
        try self.popRbp();
        try self.ret();
    }

    /// Compile dot product (returns i64 in rax)
    pub fn compileDotProduct(self: *Self, dimension: usize) !void {
        self.reset();

        // Function prologue
        try self.pushRbp();
        try self.movRbpRsp();

        // Save callee-saved registers
        try self.emit(&[_]u8{ 0x53 }); // push rbx
        try self.emit(&[_]u8{ 0x41, 0x54 }); // push r12
        try self.emit(&[_]u8{ 0x41, 0x55 }); // push r13
        try self.emit(&[_]u8{ 0x41, 0x56 }); // push r14

        // r12 = a pointer, r13 = b pointer
        try self.emit(&[_]u8{ 0x49, 0x89, 0xFC }); // mov r12, rdi
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

        // Add to accumulator
        try self.emit(&[_]u8{ 0x49, 0x01, 0xC6 }); // add r14, rax

        // Increment counter
        try self.emit(&[_]u8{ 0x48, 0xFF, 0xC3 }); // inc rbx

        // Jump back to loop start
        try self.emit(&[_]u8{ 0xE9 }); // jmp rel32
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
        try self.emit(&[_]u8{ 0x5B }); // pop rbx

        // Function epilogue
        try self.movRspRbp();
        try self.popRbp();
        try self.ret();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// JIT CACHE
// ═══════════════════════════════════════════════════════════════════════════════

/// Cache for JIT-compiled functions
pub const JitCache = struct {
    /// Cached bind functions by dimension
    bind_cache: std.AutoHashMap(usize, *const fn (*anyopaque, *anyopaque) void),
    /// Compiler instance
    compiler: JitCompiler,
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .bind_cache = std.AutoHashMap(usize, *const fn (*anyopaque, *anyopaque) void).init(allocator),
            .compiler = JitCompiler.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.bind_cache.deinit();
        self.compiler.deinit();
    }

    /// Get or compile bind function for dimension
    pub fn getBind(self: *Self, dimension: usize) !*const fn (*anyopaque, *anyopaque) void {
        if (self.bind_cache.get(dimension)) |func| {
            return func;
        }

        // Compile new function
        try self.compiler.compileBindDirect(dimension);
        const func = try self.compiler.finalize();

        try self.bind_cache.put(dimension, func);
        return func;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HIGH-LEVEL JIT API
// ═══════════════════════════════════════════════════════════════════════════════

/// JIT-accelerated bind operation
pub fn jitBind(cache: *JitCache, a: *HybridBigInt, b: *HybridBigInt) !void {
    a.ensureUnpacked();
    b.ensureUnpacked();

    const dimension = @max(a.trit_len, b.trit_len);
    const func = try cache.getBind(dimension);

    // Call JIT-compiled function
    func(@ptrCast(&a.unpacked_cache), @ptrCast(&b.unpacked_cache));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "JitCompiler basic code generation" {
    var compiler = JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    // Generate simple return function
    try compiler.pushRbp();
    try compiler.movRbpRsp();
    try compiler.xorEaxEax(); // return 0
    try compiler.movRspRbp();
    try compiler.popRbp();
    try compiler.ret();

    try std.testing.expect(compiler.codeSize() > 0);
}

test "JitCompiler bind code generation" {
    var compiler = JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    try compiler.compileBindDirect(256);

    try std.testing.expect(compiler.codeSize() > 0);

    // Dump for inspection
    // try compiler.dumpCode(std.io.getStdErr().writer());
}

test "JitCompiler finalize and execute" {
    // Skip on non-x86 architectures (this test executes x86-64 machine code)
    const builtin = @import("builtin");
    if (builtin.cpu.arch != .x86_64) {
        return error.SkipZigTest;
    }

    var compiler = JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    // Generate code that does nothing (just returns)
    try compiler.pushRbp();
    try compiler.movRbpRsp();
    try compiler.movRspRbp();
    try compiler.popRbp();
    try compiler.ret();

    const func = try compiler.finalize();

    // Call the function - should not crash
    var dummy1: [256]u8 = undefined;
    var dummy2: [256]u8 = undefined;
    func(&dummy1, &dummy2);
}

test "JitCompiler bind correctness" {
    // Skip on non-x86 architectures (this test executes x86-64 machine code)
    const builtin = @import("builtin");
    if (builtin.cpu.arch != .x86_64) {
        return error.SkipZigTest;
    }

    var compiler = JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const dim = 16;
    try compiler.compileBindDirect(dim);
    const func = try compiler.finalize();

    // Create test data
    var a: [dim]i8 = undefined;
    var b: [dim]i8 = undefined;
    var expected: [dim]i8 = undefined;

    for (0..dim) |i| {
        a[i] = if (i % 3 == 0) 1 else if (i % 3 == 1) -1 else 0;
        b[i] = if (i % 2 == 0) 1 else -1;
        expected[i] = a[i] * b[i];
    }

    // Call JIT function
    func(&a, &b);

    // Verify results (a should now contain a*b)
    for (0..dim) |i| {
        try std.testing.expectEqual(expected[i], a[i]);
    }
}

test "JitCompiler bundle correctness" {
    // Skip on non-x86 architectures (this test executes x86-64 machine code)
    const builtin = @import("builtin");
    if (builtin.cpu.arch != .x86_64) {
        return error.SkipZigTest;
    }

    var compiler = JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const dim = 16;
    try compiler.compileBundleDirect(dim);
    const func = try compiler.finalize();

    // Create test data
    var a: [dim]i8 = undefined;
    var b: [dim]i8 = undefined;

    for (0..dim) |i| {
        a[i] = if (i % 3 == 0) 1 else if (i % 3 == 1) -1 else 0;
        b[i] = if (i % 2 == 0) 1 else -1;
    }

    // Call JIT function
    func(&a, &b);

    // Verify results
    // a[0]: 1 + 1 = 2 -> 1
    try std.testing.expectEqual(@as(i8, 1), a[0]);
    // a[1]: -1 + -1 = -2 -> -1
    try std.testing.expectEqual(@as(i8, -1), a[1]);
    // a[2]: 0 + 1 = 1 -> 1
    try std.testing.expectEqual(@as(i8, 1), a[2]);
    // a[3]: 1 + -1 = 0 -> 0
    try std.testing.expectEqual(@as(i8, 0), a[3]);
}

test "JitCompiler dot product correctness" {
    // Skip on non-x86 architectures (this test executes x86-64 machine code)
    const builtin = @import("builtin");
    if (builtin.cpu.arch != .x86_64) {
        return error.SkipZigTest;
    }

    var compiler = JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const dim = 8;
    try compiler.compileDotProduct(dim);

    // Get function pointer with correct signature
    const code_size = compiler.code.items.len;
    const page_size = std.heap.page_size_min;
    const alloc_size = std.mem.alignForward(usize, code_size, page_size);

    const mem = try std.posix.mmap(
        null,
        alloc_size,
        std.posix.PROT.READ | std.posix.PROT.WRITE,
        .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
        -1,
        0,
    );
    defer std.posix.munmap(mem);

    @memcpy(mem[0..code_size], compiler.code.items);
    try std.posix.mprotect(mem, std.posix.PROT.READ | std.posix.PROT.EXEC);

    const func: *const fn (*const [dim]i8, *const [dim]i8) callconv(.c) i64 = @ptrCast(mem.ptr);

    // Create test data
    const a = [dim]i8{ 1, -1, 1, 0, 1, -1, 0, 1 };
    const b = [dim]i8{ 1, 1, -1, 1, 1, 1, 1, -1 };

    // Expected: 1*1 + (-1)*1 + 1*(-1) + 0*1 + 1*1 + (-1)*1 + 0*1 + 1*(-1)
    //         = 1 - 1 - 1 + 0 + 1 - 1 + 0 - 1 = -2
    const expected: i64 = -2;

    const result = func(&a, &b);
    try std.testing.expectEqual(expected, result);
}
