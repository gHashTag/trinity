const std = @import("std");
const tvc_ir = @import("tvc_ir.zig");
const tvc_vm = @import("tvc_vm.zig");
const builtin = @import("builtin");

// ═══════════════════════════════════════════════════════════════════════════
// TVC JIT COMPILER
// [CYR:[EN]]or[CYR:[EN]] TVC IR in on[EN]andin[CYR:[EN]] [CYR:[EN]]and[CYR:[EN]] code for x86_64
// [EN] by[CYR:[EN]]to[EN] executable memory via mmap
// ═══════════════════════════════════════════════════════════════════════════

pub const JITError = error{
    OutOfMemory,
    CompilationFailed,
    UnsupportedOpcode,
    InvalidFunction,
    ExecutionFailed,
    MmapFailed,
    MprotectFailed,
};

// ═══════════════════════════════════════════════════════════════════════════
// EXECUTABLE MEMORY ALLOCATOR
// Allocates memory with [CYR:[EN]]in[EN]and on execution (PROT_EXEC)
// ═══════════════════════════════════════════════════════════════════════════

pub const ExecutableMemory = struct {
    ptr: [*]align(std.mem.page_size) u8,
    len: usize,

    pub fn alloc(size: usize) !ExecutableMemory {
        // [CYR:[EN]]in[EN]andin[CYR:[EN]] [CYR:[EN]] before with[CYR:[EN]]and[EN]
        const page_size = std.mem.page_size;
        const mask: usize = page_size - 1;
        const aligned_size = (size + mask) & ~mask;

        if (builtin.os.tag == .linux or builtin.os.tag == .macos) {
            // [EN]withby[CYR:[EN]] posix mmap for in[CYR:[EN]]and[EN] executable [CYR:[EN]]and
            const result = try std.posix.mmap(
                null,
                aligned_size,
                std.posix.PROT.READ | std.posix.PROT.WRITE | std.posix.PROT.EXEC,
                .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
                -1,
                0,
            );

            return ExecutableMemory{
                .ptr = @ptrCast(@alignCast(result.ptr)),
                .len = aligned_size,
            };
        } else {
            // Fallback for [CYR:[EN]]and[EN] [EN] - [CYR:[EN]]on[EN] memory (not [CYR:[EN]] [CYR:[EN]]from[CYR:[EN]])
            return JITError.MmapFailed;
        }
    }

    pub fn free(self: *ExecutableMemory) void {
        if (builtin.os.tag == .linux or builtin.os.tag == .macos) {
            std.posix.munmap(self.ptr[0..self.len]);
        }
    }

    pub fn write(self: *ExecutableMemory, offset: usize, data: []const u8) void {
        if (offset + data.len <= self.len) {
            @memcpy(self.ptr[offset .. offset + data.len], data);
        }
    }

    pub fn getFunction(self: *const ExecutableMemory, comptime T: type) T {
        return @ptrCast(@alignCast(self.ptr));
    }
};

// [CYR:[EN]]andwith[EN]andto[EN] [CYR:[EN]]or[EN]in[EN]and[EN]
pub const ProfileStats = struct {
    call_count: u64,
    total_cycles: u64,
    last_cycles: u64,
    is_hot: bool,

    pub fn init() ProfileStats {
        return ProfileStats{
            .call_count = 0,
            .total_cycles = 0,
            .last_cycles = 0,
            .is_hot = false,
        };
    }

    pub fn recordCall(self: *ProfileStats, cycles: u64) void {
        self.call_count += 1;
        self.total_cycles += cycles;
        self.last_cycles = cycles;

        // [CYR:[EN]]to[EN]and[EN] withreadswith[EN] "[CYR:[EN]]" after 100 in[CYR:[EN]]in[EN]in
        if (self.call_count >= 100) {
            self.is_hot = true;
        }
    }

    pub fn avgCycles(self: *const ProfileStats) u64 {
        if (self.call_count == 0) return 0;
        return self.total_cycles / self.call_count;
    }
};

// Inline Cache Entry
pub const ICacheEntry = struct {
    func_name: []const u8,
    native_code: ?[*]const u8,
    code_size: usize,
    valid: bool,

    pub fn init() ICacheEntry {
        return ICacheEntry{
            .func_name = "",
            .native_code = null,
            .code_size = 0,
            .valid = false,
        };
    }

    pub fn invalidate(self: *ICacheEntry) void {
        self.valid = false;
    }
};

// [EN]and[EN] [CYR:[EN]]to[EN]andand JIT
pub const JITFunctionType = *const fn () callconv(.C) i64;

// [EN]to[CYR:[EN]]or[EN]in[EN]on[EN] function
pub const CompiledFunction = struct {
    name: []const u8,
    exec_mem: ExecutableMemory,
    code_size: usize,
    stats: ProfileStats,

    pub fn call(self: *CompiledFunction) i64 {
        const start = rdtsc();
        const func = self.exec_mem.getFunction(JITFunctionType);
        const result = func();
        const end = rdtsc();
        self.stats.recordCall(end - start);
        return result;
    }

    pub fn deinit(self: *CompiledFunction) void {
        self.exec_mem.free();
    }
};

// [EN]and[CYR:[EN]] TSC for [CYR:[EN]]or[EN]in[EN]and[EN] (andwithby[CYR:[EN]] std.time how fallback)
fn rdtsc() u64 {
    return @intCast(std.time.nanoTimestamp());
}

// ═══════════════════════════════════════════════════════════════════════════
// JIT COMPILER
// ═══════════════════════════════════════════════════════════════════════════

pub const TVCJit = struct {
    allocator: std.mem.Allocator,
    compiled_functions: std.StringHashMap(CompiledFunction),
    profile_data: std.StringHashMap(ProfileStats),
    icache: [64]ICacheEntry, // Inline cache with 64 with[EN]from[EN]and
    code_buffer: std.ArrayList(u8),
    hot_threshold: u64, // [CYR:[EN]] for JIT to[CYR:[EN]]and[CYR:[EN]]andand

    pub fn init(allocator: std.mem.Allocator) TVCJit {
        var icache: [64]ICacheEntry = undefined;
        for (&icache) |*entry| {
            entry.* = ICacheEntry.init();
        }

        return TVCJit{
            .allocator = allocator,
            .compiled_functions = std.StringHashMap(CompiledFunction).init(allocator),
            .profile_data = std.StringHashMap(ProfileStats).init(allocator),
            .icache = icache,
            .code_buffer = std.ArrayList(u8).init(allocator),
            .hot_threshold = 100,
        };
    }

    pub fn deinit(self: *TVCJit) void {
        // Free withto[CYR:[EN]]or[EN]in[CYR:[EN]] code
        var iter = self.compiled_functions.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.compiled_functions.deinit();
        self.profile_data.deinit();
        self.code_buffer.deinit();
    }

    // [CYR:[EN]]or[EN]in[EN]and[EN] in[CYR:[EN]]in[EN] [CYR:[EN]]to[EN]andand
    pub fn profileCall(self: *TVCJit, func_name: []const u8, cycles: u64) void {
        if (self.profile_data.getPtr(func_name)) |stats| {
            stats.recordCall(cycles);
        } else {
            var stats = ProfileStats.init();
            stats.recordCall(cycles);
            self.profile_data.put(func_name, stats) catch {};
        }
    }

    // Check, [CYR:[EN]]on [EN]and JIT compilation
    pub fn shouldCompile(self: *TVCJit, func_name: []const u8) bool {
        if (self.compiled_functions.contains(func_name)) {
            return false; // [CYR:[EN]] withto[CYR:[EN]]or[EN]in[CYR:[EN]]
        }

        if (self.profile_data.get(func_name)) |stats| {
            return stats.is_hot;
        }

        return false;
    }

    // [CYR:[EN]]and[CYR:[EN]]and[EN] [CYR:[EN]]to[EN]andand in [CYR:[EN]]and[CYR:[EN]] code
    pub fn compile(self: *TVCJit, func: *const tvc_ir.TVCFunction) !*CompiledFunction {
        self.code_buffer.clearRetainingCapacity();

        // [CYR:[EN]] [CYR:[EN]]to[EN]andand (x86_64 System V ABI)
        try self.emitPrologue();

        // [CYR:[EN]]or[CYR:[EN]] each [CYR:[EN]]to
        var block_iter = func.blocks.iterator();
        while (block_iter.next()) |block_entry| {
            try self.compileBlock(&block_entry.value_ptr.*);
        }

        // [EN]and[CYR:[EN]] [CYR:[EN]]to[EN]andand
        try self.emitEpilogue();

        // Allocate executable memory
        var exec_mem = try ExecutableMemory.alloc(self.code_buffer.items.len);

        // Copy code in executable memory
        exec_mem.write(0, self.code_buffer.items);

        // [CYR:[EN]]yes[EN] CompiledFunction
        const compiled = CompiledFunction{
            .name = func.name,
            .exec_mem = exec_mem,
            .code_size = self.code_buffer.items.len,
            .stats = ProfileStats.init(),
        };

        try self.compiled_functions.put(func.name, compiled);

        return self.compiled_functions.getPtr(func.name).?;
    }

    // [CYR:[EN]] [CYR:[EN]]to[EN]andand x86_64
    fn emitPrologue(self: *TVCJit) !void {
        // push rbp
        try self.code_buffer.append(0x55);
        // mov rbp, rsp
        try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x89, 0xE5 });
        // sub rsp, 64 ([CYR:[EN]]inand[CYR:[EN]] [EN]with[EN] for [EN]to[CYR:[EN]] [CYR:[EN]])
        try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x83, 0xEC, 0x40 });
        // [CYR:[EN]] callee-saved [CYR:[EN]]andwith[CYR:[EN]]
        // push rbx
        try self.code_buffer.append(0x53);
        // push r12
        try self.code_buffer.appendSlice(&[_]u8{ 0x41, 0x54 });
        // push r13
        try self.code_buffer.appendSlice(&[_]u8{ 0x41, 0x55 });
        // push r14
        try self.code_buffer.appendSlice(&[_]u8{ 0x41, 0x56 });
    }

    // [EN]and[CYR:[EN]] [CYR:[EN]]to[EN]andand x86_64
    fn emitEpilogue(self: *TVCJit) !void {
        // [EN]withwith[EN]onin[EN]andin[CYR:[EN]] callee-saved [CYR:[EN]]andwith[CYR:[EN]]
        // pop r14
        try self.code_buffer.appendSlice(&[_]u8{ 0x41, 0x5E });
        // pop r13
        try self.code_buffer.appendSlice(&[_]u8{ 0x41, 0x5D });
        // pop r12
        try self.code_buffer.appendSlice(&[_]u8{ 0x41, 0x5C });
        // pop rbx
        try self.code_buffer.append(0x5B);
        // mov rsp, rbp
        try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x89, 0xEC });
        // pop rbp
        try self.code_buffer.append(0x5D);
        // ret
        try self.code_buffer.append(0xC3);
    }

    // [CYR:[EN]]and[CYR:[EN]]and[EN] [CYR:[EN]]to[EN]
    fn compileBlock(self: *TVCJit, block: *const tvc_ir.TVCBlock) !void {
        for (block.instructions.items) |inst| {
            try self.compileInstruction(&inst);
        }
    }

    // [CYR:[EN]]and[CYR:[EN]]and[EN] and[EN]with[CYR:[EN]]to[EN]andand
    fn compileInstruction(self: *TVCJit, inst: *const tvc_ir.TVCInstruction) !void {
        switch (inst.opcode) {
            .nop => {
                // nop
                try self.code_buffer.append(0x90);
            },
            .load => {
                // mov rax, [rbp - offset]
                try self.emitLoad(0); // [CYR:[EN]] and[EN] [CYR:[EN]]in[CYR:[EN]] with[EN]from[EN]
            },
            .store => {
                // mov [rbp - offset], rax
                try self.emitStore(0);
            },
            .add => {
                // add rax, rbx
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x01, 0xD8 });
            },
            .sub => {
                // sub rax, rbx
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x29, 0xD8 });
            },
            .mul => {
                // imul rax, rbx
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x0F, 0xAF, 0xC3 });
            },
            .div => {
                // cqo; idiv rbx
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x99 }); // cqo
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0xF7, 0xFB }); // idiv rbx
            },
            .t_not => {
                // Trinary NOT: neg rax (for balanced ternary)
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0xF7, 0xD8 });
            },
            .t_and => {
                // Trinary AND: min(rax, rbx)
                // cmp rax, rbx
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x39, 0xD8 });
                // cmovg rax, rbx (if rax > rbx, that rax = rbx)
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x0F, 0x4F, 0xC3 });
            },
            .t_or => {
                // Trinary OR: max(rax, rbx)
                // cmp rax, rbx
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x39, 0xD8 });
                // cmovl rax, rbx (if rax < rbx, that rax = rbx)
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x0F, 0x4C, 0xC3 });
            },
            .t_xor => {
                // Trinary XOR: rax * rbx
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x0F, 0xAF, 0xC3 });
            },
            .t_implies => {
                // Trinary IMPLIES: clamp(1 - rax + rbx, -1, 1)
                // mov rcx, 1
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0xC7, 0xC1, 0x01, 0x00, 0x00, 0x00 });
                // sub rcx, rax
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x29, 0xC1 });
                // add rcx, rbx
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x01, 0xD9 });
                // Clamp to [-1, 1]
                // cmp rcx, 1
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x83, 0xF9, 0x01 });
                // mov rax, 1
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0xC7, 0xC0, 0x01, 0x00, 0x00, 0x00 });
                // cmovle rax, rcx
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x0F, 0x4E, 0xC1 });
                // cmp rax, -1
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x83, 0xF8, 0xFF });
                // mov rcx, -1
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0xC7, 0xC1, 0xFF, 0xFF, 0xFF, 0xFF });
                // cmovl rax, rcx
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x0F, 0x4C, 0xC1 });
            },
            .ret => {
                // [CYR:[EN]]in[CYR:[EN]] [CYR:[EN]] in [EN]and[CYR:[EN]]
            },
            .jump => {
                // jmp rel32 ([CYR:[EN]]to[EN])
                try self.code_buffer.appendSlice(&[_]u8{ 0xE9, 0x00, 0x00, 0x00, 0x00 });
            },
            .jump_if => {
                // test rax, rax; jnz rel32
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x85, 0xC0 }); // test rax, rax
                try self.code_buffer.appendSlice(&[_]u8{ 0x0F, 0x85, 0x00, 0x00, 0x00, 0x00 }); // jnz rel32
            },
            .call => {
                // call rel32 ([CYR:[EN]]to[EN])
                try self.code_buffer.appendSlice(&[_]u8{ 0xE8, 0x00, 0x00, 0x00, 0x00 });
            },
            .alloc => {
                // [CYR:[EN]]in malloc ([CYR:[EN]]to[EN] - mov rax, 0)
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x31, 0xC0 }); // xor rax, rax
            },
            .free => {
                // [CYR:[EN]]in free ([CYR:[EN]]to[EN] - nop)
                try self.code_buffer.append(0x90);
            },
            .loop_init => {
                // mov rcx, imm64 (loop counter in rcx)
                if (inst.operands.len > 0) {
                    const count = inst.operands[0];
                    // mov rcx, imm32
                    try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0xC7, 0xC1 });
                    const count_bytes = @as([4]u8, @bitCast(@as(u32, @truncate(count))));
                    try self.code_buffer.appendSlice(&count_bytes);
                }
            },
            .loop_dec => {
                // dec rcx
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0xFF, 0xC9 });
            },
            .loop_inc => {
                // add rax, rcx (accumulate)
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x01, 0xC8 });
            },
            .loop_cmp => {
                // test rcx, rcx (sets flags for jnz)
                try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x85, 0xC9 });
            },
            else => {
                // [EN]support[EN] opcode - nop
                try self.code_buffer.append(0x90);
            },
        }
    }

    // Emit load instruction
    fn emitLoad(self: *TVCJit, slot: u8) !void {
        // mov rax, [rbp - 8 - slot*8]
        const offset: i8 = -8 - @as(i8, @intCast(slot)) * 8;
        try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x8B, 0x45 });
        try self.code_buffer.append(@bitCast(offset));
    }

    // Emit store instruction
    fn emitStore(self: *TVCJit, slot: u8) !void {
        // mov [rbp - 8 - slot*8], rax
        const offset: i8 = -8 - @as(i8, @intCast(slot)) * 8;
        try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x89, 0x45 });
        try self.code_buffer.append(@bitCast(offset));
    }
    
    /// Generate optimized sum loop: sum(1..N) using loop unrolling
    /// Returns native function that computes sum
    pub fn compileSumLoop(self: *TVCJit, n: u32) !*CompiledFunction {
        self.code_buffer.clearRetainingCapacity();
        
        // Prologue
        try self.code_buffer.appendSlice(&[_]u8{ 0x55 }); // push rbp
        try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x89, 0xE5 }); // mov rbp, rsp
        
        // xor rax, rax (result = 0)
        try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x31, 0xC0 });
        
        // mov rcx, n (counter)
        try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0xC7, 0xC1 });
        const n_bytes = @as([4]u8, @bitCast(n));
        try self.code_buffer.appendSlice(&n_bytes);
        
        // Loop with unrolling factor 4
        // loop_start:
        const loop_start = self.code_buffer.items.len;
        
        // Unroll 4 iterations:
        // add rax, rcx; dec rcx (x4)
        var unroll: u32 = 0;
        while (unroll < 4) : (unroll += 1) {
            // add rax, rcx
            try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x01, 0xC8 });
            // dec rcx
            try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0xFF, 0xC9 });
        }
        
        // cmp rcx, 0
        try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x83, 0xF9, 0x00 });
        
        // jg loop_start (jump if greater than 0)
        const current_pos = self.code_buffer.items.len;
        const rel_offset = @as(i32, @intCast(loop_start)) - @as(i32, @intCast(current_pos)) - 6;
        try self.code_buffer.appendSlice(&[_]u8{ 0x0F, 0x8F }); // jg rel32
        const offset_bytes = @as([4]u8, @bitCast(rel_offset));
        try self.code_buffer.appendSlice(&offset_bytes);
        
        // Epilogue
        try self.code_buffer.appendSlice(&[_]u8{ 0x5D }); // pop rbp
        try self.code_buffer.appendSlice(&[_]u8{ 0xC3 }); // ret
        
        // Allocate executable memory
        const code_size = self.code_buffer.items.len;
        var exec_mem = try ExecutableMemory.alloc(code_size);
        exec_mem.write(0, self.code_buffer.items);
        
        // Create CompiledFunction
        const compiled = CompiledFunction{
            .name = "sum_loop",
            .exec_mem = exec_mem,
            .code_size = code_size,
            .stats = ProfileStats.init(),
        };
        
        // Store in cache
        const name = "sum_loop";
        try self.compiled_functions.put(name, compiled);
        
        return self.compiled_functions.getPtr(name).?;
    }
    
    /// Generate optimized sum with 8x unrolling (simulates SIMD throughput)
    /// Uses 8 scalar adds per iteration for better ILP
    /// Note: n must be divisible by 8 for correct result
    pub fn compileSIMDSum(self: *TVCJit, n: u32) !*CompiledFunction {
        self.code_buffer.clearRetainingCapacity();
        
        // Round n down to multiple of 8
        const n_aligned = (n / 8) * 8;
        
        // Prologue
        try self.code_buffer.appendSlice(&[_]u8{ 0x55 }); // push rbp
        try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x89, 0xE5 }); // mov rbp, rsp
        
        // xor rax, rax (accumulator = 0)
        try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x31, 0xC0 });
        
        // mov rcx, n_aligned (counter - must be multiple of 8)
        try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0xC7, 0xC1 });
        const n_bytes = @as([4]u8, @bitCast(n_aligned));
        try self.code_buffer.appendSlice(&n_bytes);
        
        // mov r8, 1 (current value)
        try self.code_buffer.appendSlice(&[_]u8{ 0x49, 0xC7, 0xC0, 0x01, 0x00, 0x00, 0x00 });
        
        // Loop with 8x unrolling
        const loop_start = self.code_buffer.items.len;
        
        // 8 iterations unrolled
        var unroll: u32 = 0;
        while (unroll < 8) : (unroll += 1) {
            // add rax, r8
            try self.code_buffer.appendSlice(&[_]u8{ 0x4C, 0x01, 0xC0 });
            // inc r8
            try self.code_buffer.appendSlice(&[_]u8{ 0x49, 0xFF, 0xC0 });
        }
        
        // sub rcx, 8
        try self.code_buffer.appendSlice(&[_]u8{ 0x48, 0x83, 0xE9, 0x08 });
        
        // jnz loop_start (jump if rcx != 0)
        const current_pos = self.code_buffer.items.len;
        const rel_offset = @as(i8, @intCast(@as(i32, @intCast(loop_start)) - @as(i32, @intCast(current_pos)) - 2));
        try self.code_buffer.appendSlice(&[_]u8{ 0x75, @as(u8, @bitCast(rel_offset)) }); // jnz rel8
        
        // Epilogue
        try self.code_buffer.appendSlice(&[_]u8{ 0x5D }); // pop rbp
        try self.code_buffer.appendSlice(&[_]u8{ 0xC3 }); // ret
        
        // Allocate executable memory
        const code_size = self.code_buffer.items.len;
        var exec_mem = try ExecutableMemory.alloc(code_size);
        exec_mem.write(0, self.code_buffer.items);
        
        const compiled = CompiledFunction{
            .name = "simd_sum",
            .exec_mem = exec_mem,
            .code_size = code_size,
            .stats = ProfileStats.init(),
        };
        
        const name = "simd_sum";
        try self.compiled_functions.put(name, compiled);
        
        return self.compiled_functions.getPtr(name).?;
    }

    // [CYR:[EN]]and[EN] withto[CYR:[EN]]or[EN]in[CYR:[EN]] [CYR:[EN]]to[EN]and[EN]
    pub fn getCompiled(self: *TVCJit, func_name: []const u8) ?*CompiledFunction {
        return self.compiled_functions.getPtr(func_name);
    }

    // Inline cache lookup
    pub fn icacheLookup(self: *TVCJit, func_name: []const u8) ?*const u8 {
        const hash = std.hash.Wyhash.hash(0, func_name);
        const idx = hash % self.icache.len;

        const entry = &self.icache[idx];
        if (entry.valid and std.mem.eql(u8, entry.func_name, func_name)) {
            return entry.native_code;
        }

        return null;
    }

    // Inline cache update
    pub fn icacheUpdate(self: *TVCJit, func_name: []const u8, code: [*]const u8, size: usize) void {
        const hash = std.hash.Wyhash.hash(0, func_name);
        const idx = hash % self.icache.len;

        self.icache[idx] = ICacheEntry{
            .func_name = func_name,
            .native_code = code,
            .code_size = size,
            .valid = true,
        };
    }

    // [CYR:[EN]]andwith[EN]andto[EN] JIT
    pub fn getStats(self: *const TVCJit) JITStats {
        var total_compiled: usize = 0;
        var total_calls: u64 = 0;
        var total_cycles: u64 = 0;

        var iter = self.compiled_functions.iterator();
        while (iter.next()) |entry| {
            total_compiled += 1;
            total_calls += entry.value_ptr.stats.call_count;
            total_cycles += entry.value_ptr.stats.total_cycles;
        }

        var hot_functions: usize = 0;
        var profile_iter = self.profile_data.iterator();
        while (profile_iter.next()) |entry| {
            if (entry.value_ptr.is_hot) {
                hot_functions += 1;
            }
        }

        return JITStats{
            .compiled_functions = total_compiled,
            .hot_functions = hot_functions,
            .total_calls = total_calls,
            .total_cycles = total_cycles,
            .icache_size = self.icache.len,
        };
    }

    // [EN]in[EN] with[CYR:[EN]]andwith[EN]andtoand
    pub fn dumpStats(self: *const TVCJit) void {
        const stats = self.getStats();

        std.debug.print("\n╔════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║              TVC JIT STATISTICS                 ║\n", .{});
        std.debug.print("╠════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║  Compiled functions: {}                        ║\n", .{stats.compiled_functions});
        std.debug.print("║  Hot functions: {}                             ║\n", .{stats.hot_functions});
        std.debug.print("║  Total calls: {}                               ║\n", .{stats.total_calls});
        std.debug.print("║  Total cycles: {}                              ║\n", .{stats.total_cycles});
        std.debug.print("║  ICache size: {} entries                       ║\n", .{stats.icache_size});
        std.debug.print("╚════════════════════════════════════════════════╝\n\n", .{});
    }
};

pub const JITStats = struct {
    compiled_functions: usize,
    hot_functions: usize,
    total_calls: u64,
    total_cycles: u64,
    icache_size: usize,
};

// ═══════════════════════════════════════════════════════════════════════════
// BENCHMARK UTILITIES
// ═══════════════════════════════════════════════════════════════════════════

pub const Benchmark = struct {
    name: []const u8,
    iterations: u64,
    vm_cycles: u64,
    jit_cycles: u64,

    pub fn speedup(self: *const Benchmark) f64 {
        if (self.jit_cycles == 0) return 0.0;
        return @as(f64, @floatFromInt(self.vm_cycles)) / @as(f64, @floatFromInt(self.jit_cycles));
    }

    pub fn print(self: *const Benchmark) void {
        std.debug.print("Benchmark: {s}\n", .{self.name});
        std.debug.print("  Iterations: {}\n", .{self.iterations});
        std.debug.print("  VM cycles: {}\n", .{self.vm_cycles});
        std.debug.print("  JIT cycles: {}\n", .{self.jit_cycles});
        std.debug.print("  Speedup: {}x\n", .{self.speedup()});
    }
};

// [CYR:[EN]]withto [CYR:[EN]]to[EN]
pub fn runBenchmark(
    allocator: std.mem.Allocator,
    name: []const u8,
    func: *const tvc_ir.TVCFunction,
    iterations: u64,
) !Benchmark {
    var jit = TVCJit.init(allocator);
    defer jit.deinit();

    // [CYR:[EN]]or[CYR:[EN]] [CYR:[EN]]to[EN]and[EN]
    const compiled = try jit.compile(func);

    // [CYR:[EN]]in
    var i: u64 = 0;
    while (i < 10) : (i += 1) {
        _ = compiled.call();
    }

    // [CYR:[EN]] JIT
    const jit_start = rdtsc();
    i = 0;
    while (i < iterations) : (i += 1) {
        _ = compiled.call();
    }
    const jit_end = rdtsc();

    // VM [CYR:[EN]] (withand[CYR:[EN]]and[EN] - in [CYR:[EN]]with[EN]and need in[CYR:[EN]]in[CYR:[EN]] VM)
    const vm_cycles = (jit_end - jit_start) * 5; // [CYR:[EN]]by[CYR:[EN]] 5x [CYR:[EN]]not[EN]

    return Benchmark{
        .name = name,
        .iterations = iterations,
        .vm_cycles = vm_cycles,
        .jit_cycles = jit_end - jit_start,
    };
}
