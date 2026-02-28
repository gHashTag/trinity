const std = @import("std");
const tvc_ir = @import("tvc_ir.zig");
const tvc_vm = @import("tvc_vm.zig");
const tvc_jit = @import("tvc_jit.zig");

// ═══════════════════════════════════════════════════════════════════════════
// TVC VM WITH JIT SUPPORT
// Ain[CYR:[TRANSLATED]]and[EN]withtoand to[CYR:[TRANSLATED]]or[CYR:[TRANSLATED]] [CYR:go[EN]I[EN]]and[EN] [CYR:[TRANSLATED]]to[EN]andand in [CYR:[TRANSLATED]]and[CYR:[EN]ny] to[EN]
// ═══════════════════════════════════════════════════════════════════════════

pub const ExecutionMode = enum {
    interpret, // [EN]with[CYR:[TRANSLATED]] and[CYR:[TRANSLATED]]and[EN]in[CYR:ate]
    jit,       // [EN]with[CYR:[TRANSLATED]] JIT to[CYR:[TRANSLATED]]or[EN]in[CYR:ate]
    adaptive,  // [CYR:A[TRANSLATED]]andin[EN]: and[CYR:[TRANSLATED]]and[EN]in[CYR:ate], [EN]from[EN] JIT for [CYR:go[EN]I[EN]]and[EN]
};

pub const TVCVMJit = struct {
    vm: tvc_vm.TVCVM,
    jit: tvc_jit.TVCJit,
    mode: ExecutionMode,
    call_counts: std.StringHashMap(u64),
    jit_threshold: u64,
    total_interpreted: u64,
    total_jit: u64,

    pub fn init(allocator: std.mem.Allocator, heap_size: usize, stack_size: usize) TVCVMJit {
        return TVCVMJit{
            .vm = tvc_vm.TVCVM.init(allocator, heap_size, stack_size),
            .jit = tvc_jit.TVCJit.init(allocator),
            .mode = .adaptive,
            .call_counts = std.StringHashMap(u64).init(allocator),
            .jit_threshold = 100, // [CYR:[TRANSLATED]]or[EN]in[CYR:ate] [EN]with[EN] 100 in[CYR:y[EN]]in[EN]in
            .total_interpreted = 0,
            .total_jit = 0,
        };
    }

    pub fn deinit(self: *TVCVMJit) void {
        self.vm.deinit();
        self.jit.deinit();
        self.call_counts.deinit();
    }

    pub fn setMode(self: *TVCVMJit, mode: ExecutionMode) void {
        self.mode = mode;
    }

    pub fn loadModule(self: *TVCVMJit, module: *const tvc_ir.TVCModule) !void {
        try self.vm.loadModule(module);
    }

    // [CYR:Vy[EN]]in [CYR:[TRANSLATED]]to[EN]andand with [EN]in[CYR:[TRANSLATED]]and[EN]withtoand[EN] in[CYR:y[TRANSLATED]] [CYR:[TRANSLATED]]and[EN]
    pub fn callFunction(self: *TVCVMJit, func_name: []const u8) !i64 {
        // [EN]in[EN]and[EN]andin[CYR:[TRANSLATED]] with[CYR:[TRANSLATED]]andto in[CYR:y[EN]]in[EN]in
        const count = (self.call_counts.get(func_name) orelse 0) + 1;
        try self.call_counts.put(func_name, count);

        switch (self.mode) {
            .interpret => {
                return self.executeInterpreted(func_name);
            },
            .jit => {
                return self.executeJIT(func_name);
            },
            .adaptive => {
                // [CYR:[TRANSLATED]]in[CYR:[EN]I[EN]], [EN]with[EN] [EN]and [CYR:[TRANSLATED]] withto[CYR:[TRANSLATED]]or[EN]in[EN]onI in[EN]withandI
                if (self.jit.getCompiled(func_name)) |compiled| {
                    self.total_jit += 1;
                    return compiled.call();
                }

                // [CYR:[TRANSLATED]]in[CYR:[EN]I[EN]], [EN]with[EN]and[CYR:[TRANSLATED]] [EN]and [CYR:[TRANSLATED]] for JIT
                if (count >= self.jit_threshold) {
                    // [CYR:[EN]y[TRANSLATED]]withI withto[CYR:[TRANSLATED]]or[EN]in[CYR:ate]
                    if (self.vm.getFunction(func_name)) |func| {
                        if (self.jit.compile(func)) |compiled| {
                            std.debug.print("[JIT] Compiled function: {s} (after {} calls)\n", .{ func_name, count });
                            self.total_jit += 1;
                            return compiled.call();
                        } else |_| {
                            // Error to[CYR:[TRANSLATED]]and[CYR:[EN]I[EN]]andand - [CYR:pro[TRANSLATED]] and[CYR:[TRANSLATED]]and[EN]in[CYR:ate]
                        }
                    }
                }

                // [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]
                return self.executeInterpreted(func_name);
            },
        }
    }

    fn executeInterpreted(self: *TVCVMJit, func_name: []const u8) !i64 {
        self.total_interpreted += 1;
        try self.vm.callFunction(func_name);
        // [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] [EN]on[CYR:[TRANSLATED]]and[EN] and[EN] [CYR:[TRANSLATED]]andwith[CYR:[TRANSLATED]] r0
        return @as(i64, self.vm.registers.r0);
    }

    fn executeJIT(self: *TVCVMJit, func_name: []const u8) !i64 {
        // [CYR:[TRANSLATED]]in[CYR:[EN]I[EN]] to[EN]
        if (self.jit.getCompiled(func_name)) |compiled| {
            self.total_jit += 1;
            return compiled.call();
        }

        // [CYR:[TRANSLATED]]or[CYR:[TRANSLATED]]
        if (self.vm.getFunction(func_name)) |func| {
            const compiled = try self.jit.compile(func);
            self.total_jit += 1;
            return compiled.call();
        }

        return error.InvalidFunction;
    }

    // [EN]and[CYR:[TRANSLATED]]and[CYR:[EN]l]onI JIT to[CYR:[TRANSLATED]]and[CYR:[EN]I[EN]]andI [CYR:[TRANSLATED]]to[EN]andand
    pub fn forceCompile(self: *TVCVMJit, func_name: []const u8) !void {
        if (self.vm.getFunction(func_name)) |func| {
            _ = try self.jit.compile(func);
            std.debug.print("[JIT] Force compiled: {s}\n", .{func_name});
        }
    }

    // [CYR:[TRANSLATED]]andwith[EN]andto[EN]
    pub fn getStats(self: *const TVCVMJit) VMJitStats {
        const jit_stats = self.jit.getStats();
        return VMJitStats{
            .mode = self.mode,
            .total_interpreted = self.total_interpreted,
            .total_jit = self.total_jit,
            .compiled_functions = jit_stats.compiled_functions,
            .hot_functions = jit_stats.hot_functions,
            .jit_threshold = self.jit_threshold,
        };
    }

    pub fn dumpStats(self: *const TVCVMJit) void {
        const stats = self.getStats();

        std.debug.print("\n╔════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           TVC VM+JIT STATISTICS                 ║\n", .{});
        std.debug.print("╠════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║  Mode: {s}                                     ║\n", .{@tagName(stats.mode)});
        std.debug.print("║  JIT threshold: {} calls                       ║\n", .{stats.jit_threshold});
        std.debug.print("║  Interpreted calls: {}                         ║\n", .{stats.total_interpreted});
        std.debug.print("║  JIT calls: {}                                 ║\n", .{stats.total_jit});
        std.debug.print("║  Compiled functions: {}                        ║\n", .{stats.compiled_functions});
        std.debug.print("║  Hot functions: {}                             ║\n", .{stats.hot_functions});

        if (stats.total_interpreted + stats.total_jit > 0) {
            const jit_ratio = @as(f64, @floatFromInt(stats.total_jit)) /
                @as(f64, @floatFromInt(stats.total_interpreted + stats.total_jit)) * 100.0;
            std.debug.print("║  JIT ratio: {}%                                ║\n", .{@as(u64, @intFromFloat(jit_ratio))});
        }

        std.debug.print("╚════════════════════════════════════════════════╝\n\n", .{});
    }
};

pub const VMJitStats = struct {
    mode: ExecutionMode,
    total_interpreted: u64,
    total_jit: u64,
    compiled_functions: usize,
    hot_functions: usize,
    jit_threshold: u64,
};

// ═══════════════════════════════════════════════════════════════════════════
// BENCHMARK: VM vs JIT
// ═══════════════════════════════════════════════════════════════════════════

pub fn benchmarkVMvsJIT(
    allocator: std.mem.Allocator,
    module: *const tvc_ir.TVCModule,
    func_name: []const u8,
    iterations: u64,
) !BenchmarkResult {
    // [CYR:[TRANSLATED]] [EN]in[EN] VM: [CYR:[TRANSLATED]] for and[CYR:[TRANSLATED]]andand, [CYR:[TRANSLATED]] for JIT
    var vm_only = TVCVMJit.init(allocator, 64 * 1024, 4 * 1024);
    defer vm_only.deinit();
    vm_only.setMode(.interpret);
    try vm_only.loadModule(module);

    var vm_jit = TVCVMJit.init(allocator, 64 * 1024, 4 * 1024);
    defer vm_jit.deinit();
    vm_jit.setMode(.jit);
    try vm_jit.loadModule(module);

    // [CYR:[TRANSLATED]]in
    var i: u64 = 0;
    while (i < 10) : (i += 1) {
        _ = vm_only.callFunction(func_name) catch 0;
        _ = vm_jit.callFunction(func_name) catch 0;
    }

    // [CYR:[TRANSLATED]] and[CYR:[TRANSLATED]]
    const vm_start = std.time.nanoTimestamp();
    i = 0;
    while (i < iterations) : (i += 1) {
        _ = vm_only.callFunction(func_name) catch 0;
    }
    const vm_end = std.time.nanoTimestamp();

    // [CYR:[TRANSLATED]] JIT
    const jit_start = std.time.nanoTimestamp();
    i = 0;
    while (i < iterations) : (i += 1) {
        _ = vm_jit.callFunction(func_name) catch 0;
    }
    const jit_end = std.time.nanoTimestamp();

    const vm_ns = @as(u64, @intCast(vm_end - vm_start));
    const jit_ns = @as(u64, @intCast(jit_end - jit_start));

    return BenchmarkResult{
        .func_name = func_name,
        .iterations = iterations,
        .vm_ns = vm_ns,
        .jit_ns = jit_ns,
        .speedup = if (jit_ns > 0) @as(f64, @floatFromInt(vm_ns)) / @as(f64, @floatFromInt(jit_ns)) else 0.0,
    };
}

pub const BenchmarkResult = struct {
    func_name: []const u8,
    iterations: u64,
    vm_ns: u64,
    jit_ns: u64,
    speedup: f64,

    pub fn print(self: *const BenchmarkResult) void {
        std.debug.print("\n╔════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║              BENCHMARK RESULT                   ║\n", .{});
        std.debug.print("╠════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║  Function: {s}                                 ║\n", .{self.func_name});
        std.debug.print("║  Iterations: {}                                ║\n", .{self.iterations});
        std.debug.print("║  VM time: {} ns                                ║\n", .{self.vm_ns});
        std.debug.print("║  JIT time: {} ns                               ║\n", .{self.jit_ns});
        std.debug.print("║  Speedup: {}x                                  ║\n", .{@as(u64, @intFromFloat(self.speedup))});
        std.debug.print("╚════════════════════════════════════════════════╝\n\n", .{});
    }
};
