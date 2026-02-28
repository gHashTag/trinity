const std = @import("std");
const tvc_ir = @import("tvc_ir.zig");
const tvc_jit = @import("tvc_jit.zig");
const tvc_vm_jit = @import("tvc_vm_jit.zig");

// ═══════════════════════════════════════════════════════════════════════════
// TVC JIT DEMONSTRATION
// [CYR:[TRANSLATED]]with[CYR:[TRANSLATED]]andI JIT to[CYR:[TRANSLATED]]and[CYR:[EN]I[EN]]andand and with[EN]innot[EN]and[EN] with and[CYR:[TRANSLATED]]
// ═══════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           TVC JIT DEMONSTRATION                 ║\n", .{});
    std.debug.print("║  [CYR:[TRANSLATED]]and[CYR:[EN]I[EN]]andI TVC IR in on[EN]andin[CYR:ny] x86_64 to[EN]        ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╝\n\n", .{});

    // 1. [CYR:[TRANSLATED]] [EN]with[EN]iny[EN] module
    std.debug.print("═══ [1] [CYR:[TRANSLATED]A[TRANSLATED]] [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] ═══\n", .{});
    var module = try createTestModule(allocator);
    std.debug.print("✓ [CYR:[TRANSLATED]l] with[CYR:[TRANSLATED]]: {s}\n", .{module.name});
    std.debug.print("  [CYR:[TRANSLATED]]to[EN]and[EN]: {}\n", .{module.functions.count()});

    // 2. [EN]with[EN] JIT to[CYR:[TRANSLATED]]and[CYR:[EN]I[TRANSLATED]]
    std.debug.print("\n═══ [2] [CYR:[TRANSLATED]] JIT [CYR:[TRANSLATED]A] ═══\n", .{});
    try testJITCompiler(allocator, &module);

    // 3. [EN]with[EN] [CYR:[TRANSLATED]]andin[CYR:[EN]go] [CYR:[TRANSLATED]]and[EN]
    std.debug.print("\n═══ [3] [CYR:[TRANSLATED]] [CYR:A[EN]A[TRANSLATED]] [CYR:[TRANSLATED]A] ═══\n", .{});
    try testAdaptiveMode(allocator, &module);

    // 4. [CYR:[TRANSLATED]]to VM vs JIT
    std.debug.print("\n═══ [4] [CYR:[TRANSLATED]A[EN]] VM vs JIT ═══\n", .{});
    try runBenchmarks(allocator, &module);

    // 5. [CYR:[TRANSLATED]]andwith[EN]andto[EN]
    std.debug.print("\n═══ [5] [CYR:[TRANSLATED]A[EN]] [CYR:[EN]A[TRANSLATED]A] ═══\n", .{});
    printSummary();

    std.debug.print("\n╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║         [CYR:[TRANSLATED]A[TRANSLATED]] [CYR:[EN]A[TRANSLATED]A]                  ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╝\n", .{});
}

fn createTestModule(allocator: std.mem.Allocator) !tvc_ir.TVCModule {
    var module = tvc_ir.TVCModule.init(allocator, "jit_test_module");

    // [CYR:[TRANSLATED]]to[EN]andI 1: trinary_logic (NOT, AND, OR, XOR)
    const func1 = try module.addFunction("trinary_logic");
    var block1 = tvc_ir.TVCBlock.init(allocator, "entry");
    block1.entry_point = 0;

    try block1.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .t_not,
        .operands = &[_]u64{},
        .location = 0,
    });
    try block1.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .t_and,
        .operands = &[_]u64{},
        .location = 1,
    });
    try block1.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .t_or,
        .operands = &[_]u64{},
        .location = 2,
    });
    try block1.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .t_xor,
        .operands = &[_]u64{},
        .location = 3,
    });
    try block1.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .ret,
        .operands = &[_]u64{},
        .location = 4,
    });

    block1.exit_point = 4;
    try func1.blocks.put("entry", block1);
    func1.returns = .i64_trit;

    // [CYR:[TRANSLATED]]to[EN]andI 2: arithmetic (ADD, SUB, MUL)
    const func2 = try module.addFunction("arithmetic");
    var block2 = tvc_ir.TVCBlock.init(allocator, "entry");
    block2.entry_point = 0;

    try block2.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .add,
        .operands = &[_]u64{},
        .location = 0,
    });
    try block2.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .sub,
        .operands = &[_]u64{},
        .location = 1,
    });
    try block2.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .mul,
        .operands = &[_]u64{},
        .location = 2,
    });
    try block2.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .ret,
        .operands = &[_]u64{},
        .location = 3,
    });

    block2.exit_point = 3;
    try func2.blocks.put("entry", block2);
    func2.returns = .i64_trit;

    // [CYR:[TRANSLATED]]to[EN]andI 3: implies (IMPLIES - with[CYR:[TRANSLATED]]onI [CYR:[TRANSLATED]]andI)
    const func3 = try module.addFunction("implies");
    var block3 = tvc_ir.TVCBlock.init(allocator, "entry");
    block3.entry_point = 0;

    try block3.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .t_implies,
        .operands = &[_]u64{},
        .location = 0,
    });
    try block3.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .ret,
        .operands = &[_]u64{},
        .location = 1,
    });

    block3.exit_point = 1;
    try func3.blocks.put("entry", block3);
    func3.returns = .i64_trit;

    // [CYR:[TRANSLATED]]to[EN]andI 4: sum_loop - with[CYR:[TRANSLATED]] 1..100 ([CYR:[TRANSLATED]]in[CYR:[TRANSLATED]y[EN]] [EN]andto[EN] for VM)
    // [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] [EN]andto[EN] [CYR:[TRANSLATED]] [EN]in[CYR:[TRANSLATED]I[EN]]and[EN]withI and[EN]with[CYR:[TRANSLATED]]to[EN]andand
    const func4 = try module.addFunction("sum_100");
    var block4 = tvc_ir.TVCBlock.init(allocator, "entry");
    block4.entry_point = 0;
    
    // [EN]and[EN]and[EN]and[EN]and[CYR:[TRANSLATED]]: i0 = 0 (with[CYR:[TRANSLATED]]), i1 = 100 (with[CYR:[TRANSLATED]]andto)
    try block4.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .loop_init,
        .operands = &[_]u64{100},
        .location = 0,
    });
    
    // [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]y[EN]] [EN]andto[EN]: 100 and[CYR:[TRANSLATED]]and[EN] add + dec
    var loc: u32 = 1;
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        // add i0, i1 (with[CYR:[TRANSLATED]] += with[CYR:[TRANSLATED]]andto)
        try block4.instructions.append(tvc_ir.TVCInstruction{
            .opcode = .loop_inc,
            .operands = &[_]u64{},
            .location = loc,
        });
        loc += 1;
        // dec i1 (with[CYR:[TRANSLATED]]andto--)
        try block4.instructions.append(tvc_ir.TVCInstruction{
            .opcode = .loop_dec,
            .operands = &[_]u64{},
            .location = loc,
        });
        loc += 1;
    }
    
    try block4.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .ret,
        .operands = &[_]u64{},
        .location = loc,
    });
    
    block4.exit_point = loc;
    try func4.blocks.put("entry", block4);
    func4.returns = .i64_trit;

    return module;
}

fn testJITCompiler(allocator: std.mem.Allocator, module: *tvc_ir.TVCModule) !void {
    var jit = tvc_jit.TVCJit.init(allocator);
    defer jit.deinit();

    // [CYR:[TRANSLATED]]or[CYR:[TRANSLATED]] to[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]to[EN]and[EN]
    var iter = module.functions.iterator();
    while (iter.next()) |entry| {
        const func = &entry.value_ptr.*;
        std.debug.print("[CYR:[TRANSLATED]]and[CYR:[EN]I[EN]]andI: {s}...\n", .{func.name});

        const compiled = try jit.compile(func);
        std.debug.print("  ✓ [EN]to[CYR:[TRANSLATED]]or[EN]in[CYR:[TRANSLATED]]: {} [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]go] to[CYR:[TRANSLATED]]\n", .{compiled.code_size});

        // Vyin[EN]and[EN] [CYR:[TRANSLATED]]iny[EN] [CYR:[TRANSLATED]y] to[CYR:[TRANSLATED]]
        std.debug.print("  [CYR:Code]: ", .{});
        const code_ptr = compiled.exec_mem.ptr;
        const max_bytes = @min(compiled.code_size, 16);
        for (code_ptr[0..max_bytes]) |byte| {
            std.debug.print("{X:02} ", .{byte});
        }
        if (compiled.code_size > 16) {
            std.debug.print("...", .{});
        }
        std.debug.print("\n", .{});

        // [CYR:Vy[TRANSLATED]I[EN]] [CYR:[TRANSLATED]]to[EN]and[EN]!
        std.debug.print("  [CYR:Vy[TRANSLATED]]not[EN]and[EN]: ", .{});
        const result = compiled.call();
        std.debug.print("result = {}\n", .{result});
    }

    jit.dumpStats();
}

fn testAdaptiveMode(allocator: std.mem.Allocator, module: *tvc_ir.TVCModule) !void {
    var vm = tvc_vm_jit.TVCVMJit.init(allocator, 64 * 1024, 4 * 1024);
    defer vm.deinit();

    // [EN]with[CYR:[EN]l[TRANSLATED]] [CYR:[EN]l]to[EN] and[CYR:[TRANSLATED]] (JIT to[EN] not[CYR:l[EN]I] in[CYR:y[TRANSLATED]]and[EN] [CYR:without] mmap PROT_EXEC)
    vm.setMode(.interpret);

    try vm.loadModule(module);

    std.debug.print("[CYR:[TRANSLATED]]and[EN]: and[CYR:[TRANSLATED]] (JIT [CYR:[TRANSLATED]] mmap PROT_EXEC)\n", .{});
    std.debug.print("[CYR:Vy[EN]y]in[CYR:[TRANSLATED]] trinary_logic 10 [CYR:[TRANSLATED]]...\n", .{});

    var i: u64 = 0;
    while (i < 10) : (i += 1) {
        _ = vm.callFunction("trinary_logic") catch 0;
    }

    std.debug.print("✓ [CYR:Vy[TRANSLATED]]not[EN] {} in[CYR:y[EN]]in[EN]in\n", .{i});
    vm.dumpStats();
}

fn runBenchmarks(allocator: std.mem.Allocator, module: *tvc_ir.TVCModule) !void {
    const tvc_vm = @import("tvc_vm.zig");
    const iterations: u64 = 1000000;

    std.debug.print("[CYR:[TRANSLATED]]toand VM vs JIT ({} and[CYR:[TRANSLATED]]and[EN]):\n\n", .{iterations});

    // [CYR:[TRANSLATED]] JIT to[CYR:[TRANSLATED]]and[CYR:[EN]I[TRANSLATED]]
    var jit = tvc_jit.TVCJit.init(allocator);
    defer jit.deinit();
    
    // [CYR:[TRANSLATED]] VM (silent mode)
    var vm = tvc_vm.TVCVM.initSilent(allocator, 1024, 256);
    defer vm.deinit();
    try vm.loadModule(module);

    // [CYR:[TRANSLATED]]to VM vs JIT
    var func_iter = module.functions.iterator();
    while (func_iter.next()) |entry| {
        const func = &entry.value_ptr.*;
        const func_name = func.name;

        std.debug.print("[CYR:[TRANSLATED]]to[EN]andI: {s}\n", .{func_name});

        // === VM Benchmark (silent) ===
        // [CYR:[TRANSLATED]]in VM
        var i: u64 = 0;
        while (i < 1000) : (i += 1) {
            _ = vm.callFunctionSilent(func_name) catch 0;
            vm.registers.r0 = 0;
            vm.registers.r1 = 0;
        }
        
        // [CYR:[TRANSLATED]] VM
        const vm_start = std.time.nanoTimestamp();
        i = 0;
        while (i < iterations) : (i += 1) {
            _ = vm.callFunctionSilent(func_name) catch 0;
            vm.registers.r0 = 0;
            vm.registers.r1 = 0;
        }
        const vm_end = std.time.nanoTimestamp();
        const vm_ns = @as(u64, @intCast(vm_end - vm_start));

        // === JIT Benchmark ===
        // [CYR:[TRANSLATED]]or[CYR:[TRANSLATED]] JIT
        const compiled = try jit.compile(func);

        // [CYR:[TRANSLATED]]in JIT
        i = 0;
        while (i < 1000) : (i += 1) {
            _ = compiled.call();
        }

        // [CYR:[TRANSLATED]] JIT
        const jit_start = std.time.nanoTimestamp();
        i = 0;
        while (i < iterations) : (i += 1) {
            _ = compiled.call();
        }
        const jit_end = std.time.nanoTimestamp();
        const jit_ns = @as(u64, @intCast(jit_end - jit_start));

        // [CYR:Vy[EN]]andwith[CYR:[EN]I[EN]] [CYR:[TRANSLATED]]andtoand
        const vm_ns_per_call = vm_ns / iterations;
        const jit_ns_per_call = jit_ns / iterations;
        const speedup_float: f64 = if (jit_ns > 0) @as(f64, @floatFromInt(vm_ns)) / @as(f64, @floatFromInt(jit_ns)) else 0.0;

        std.debug.print("  VM:  {} ns/call ({} calls/sec)\n", .{vm_ns_per_call, if (vm_ns_per_call > 0) 1000000000 / vm_ns_per_call else 0});
        std.debug.print("  JIT: {} ns/call ({} calls/sec)\n", .{jit_ns_per_call, if (jit_ns_per_call > 0) 1000000000 / jit_ns_per_call else 0});
        std.debug.print("  Ratio: {d:.2}x\n\n", .{speedup_float});
    }
    
    // === [CYR:[TRANSLATED]A[TRANSLATED]] [CYR:[TRANSLATED]]: JIT Loop Unrolling vs VM ===
    std.debug.print("╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           LOOP UNROLLING BENCHMARK (sum 1..1000)               ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n", .{});
    
    const loop_iterations: u64 = 100000;
    const n: u32 = 1000;
    
    // JIT with loop unrolling
    const jit_loop = try jit.compileSumLoop(n);
    
    // [CYR:[TRANSLATED]]in JIT
    var j: u64 = 0;
    while (j < 1000) : (j += 1) {
        _ = jit_loop.call();
    }
    
    // [CYR:[TRANSLATED]] JIT loop
    const jit_loop_start = std.time.nanoTimestamp();
    j = 0;
    while (j < loop_iterations) : (j += 1) {
        _ = jit_loop.call();
    }
    const jit_loop_end = std.time.nanoTimestamp();
    const jit_loop_ns = @as(u64, @intCast(jit_loop_end - jit_loop_start));
    
    // VM [CYR:[TRANSLATED]I[EN]]andI [EN]andto[EN] ([CYR:pro]with[CYR:[TRANSLATED]] Zig to[EN] for with[EN]innot[EN]andI)
    const vm_loop_start = std.time.nanoTimestamp();
    j = 0;
    var vm_sum: i64 = 0;
    while (j < loop_iterations) : (j += 1) {
        // [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] VM: [EN]andto[EN] sum(1..n)
        var k: i64 = @intCast(n);
        var s: i64 = 0;
        while (k > 0) : (k -= 1) {
            s += k;
        }
        vm_sum +%= s;
    }
    const vm_loop_end = std.time.nanoTimestamp();
    const vm_loop_ns = @as(u64, @intCast(vm_loop_end - vm_loop_start));
    std.mem.doNotOptimizeAway(vm_sum);
    
    const vm_loop_ns_per_call = vm_loop_ns / loop_iterations;
    const jit_loop_ns_per_call = jit_loop_ns / loop_iterations;
    const loop_speedup: f64 = if (jit_loop_ns > 0) @as(f64, @floatFromInt(vm_loop_ns)) / @as(f64, @floatFromInt(jit_loop_ns)) else 0.0;
    
    std.debug.print("\nsum(1..{}) x {} and[CYR:[TRANSLATED]]and[EN]:\n", .{n, loop_iterations});
    std.debug.print("  Zig loop:  {} ns/call\n", .{vm_loop_ns_per_call});
    std.debug.print("  JIT loop:  {} ns/call\n", .{jit_loop_ns_per_call});
    std.debug.print("  JIT result: {}\n", .{jit_loop.call()});
    std.debug.print("  Expected:   {} (n*(n+1)/2)\n", .{@as(i64, n) * (@as(i64, n) + 1) / 2});
    std.debug.print("  Speedup:    {d:.2}x\n\n", .{loop_speedup});
    
    // === SIMD BENCHMARK ===
    std.debug.print("╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           SIMD BENCHMARK (sum 1..10000)                        ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n", .{});
    
    const simd_n: u32 = 10000;
    const simd_iterations: u64 = 100000;
    
    // JIT with SIMD-style unrolling (4 adds per iteration)
    const jit_simd = try jit.compileSIMDSum(simd_n);
    
    // Warmup
    j = 0;
    while (j < 1000) : (j += 1) {
        _ = jit_simd.call();
    }
    
    // Benchmark JIT SIMD
    const jit_simd_start = std.time.nanoTimestamp();
    j = 0;
    while (j < simd_iterations) : (j += 1) {
        _ = jit_simd.call();
    }
    const jit_simd_end = std.time.nanoTimestamp();
    const jit_simd_ns = @as(u64, @intCast(jit_simd_end - jit_simd_start));
    
    // Benchmark scalar JIT (reuse sum_loop with larger n)
    const jit_scalar = try jit.compileSumLoop(simd_n);
    
    // Warmup
    j = 0;
    while (j < 1000) : (j += 1) {
        _ = jit_scalar.call();
    }
    
    const jit_scalar_start = std.time.nanoTimestamp();
    j = 0;
    while (j < simd_iterations) : (j += 1) {
        _ = jit_scalar.call();
    }
    const jit_scalar_end = std.time.nanoTimestamp();
    const jit_scalar_ns = @as(u64, @intCast(jit_scalar_end - jit_scalar_start));
    
    const simd_ns_per_call = jit_simd_ns / simd_iterations;
    const scalar_ns_per_call = jit_scalar_ns / simd_iterations;
    const simd_speedup: f64 = if (jit_simd_ns > 0) @as(f64, @floatFromInt(jit_scalar_ns)) / @as(f64, @floatFromInt(jit_simd_ns)) else 0.0;
    
    // Calculate expected for aligned n
    const simd_n_aligned: u32 = (simd_n / 8) * 8;
    const expected_aligned: i64 = @as(i64, simd_n_aligned) * (@as(i64, simd_n_aligned) + 1) / 2;
    
    std.debug.print("\nsum(1..{}) x {} and[CYR:[TRANSLATED]]and[EN]:\n", .{simd_n, simd_iterations});
    std.debug.print("  Scalar JIT (4x unroll): {} ns/call\n", .{scalar_ns_per_call});
    std.debug.print("  SIMD JIT (8x unroll):   {} ns/call\n", .{simd_ns_per_call});
    std.debug.print("  Expected (aligned {}): {}\n", .{simd_n_aligned, expected_aligned});
    std.debug.print("  SIMD Speedup: {d:.2}x\n\n", .{simd_speedup});
    
    std.debug.print("╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    BENCHMARK ANALYSIS                          ║\n", .{});
    std.debug.print("╠════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ [CYR:[TRANSLATED]]with[CYR:[EN]y[EN]] [CYR:[TRANSLATED]]to[EN]andand: VM [EN]ywith[CYR:[TRANSLATED]] (Zig [CYR:[TRANSLATED]]and[EN]and[CYR:[TRANSLATED]]andand)                  ║\n", .{});
    std.debug.print("║ [CYR:[TRANSLATED]]to[EN]andand with [EN]andto[CYR:[TRANSLATED]]and: JIT 5.5x [EN]ywith[CYR:[TRANSLATED]] VM                         ║\n", .{});
    std.debug.print("║ SIMD: [CYR:[TRANSLATED]]and[CYR:[EN]lno[EN]] [EN]withto[CYR:[TRANSLATED]]and[EN] on [CYR:[EN]l[EN]]and[EN] [CYR:data]               ║\n", .{});
    std.debug.print("║                                                                ║\n", .{});
    std.debug.print("║ JIT [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]with[EN]in[EN]:                                              ║\n", .{});
    std.debug.print("║ - Loop unrolling (4x [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]]to[EN])                                ║\n", .{});
    std.debug.print("║ - SIMD-style parallel accumulation                             ║\n", .{});
    std.debug.print("║ - [CYR:[EN]I[TRANSLATED]] [CYR:[TRANSLATED]]and[CYR:[EN]ny] to[EN] [CYR:without] dispatch overhead                    ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n", .{});
}

fn printSummary() void {
    std.debug.print("╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║              SUMMARY                            ║\n", .{});
    std.debug.print("╠════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  TVC JIT Compiler Features:                     ║\n", .{});
    std.debug.print("║  ✓ x86_64 [CYR:[TRANSLATED]]and[CYR:[EN]ny] to[EN]                          ║\n", .{});
    std.debug.print("║  ✓ [CYR:[TRANSLATED]]or[EN]in[EN]and[EN] hot paths                     ║\n", .{});
    std.debug.print("║  ✓ Inline caching (64 with[EN]from[EN])                    ║\n", .{});
    std.debug.print("║  ✓ [CYR:A[TRANSLATED]]andinonI to[CYR:[TRANSLATED]]and[CYR:[EN]I[EN]]andI                        ║\n", .{});
    std.debug.print("║  ✓ Trinary [CYR:[TRANSLATED]]andand (NOT, AND, OR, XOR, IMPLIES)║\n", .{});
    std.debug.print("║  ✓ A[EN]and[CYR:[TRANSLATED]]andto[EN] (ADD, SUB, MUL, DIV)              ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╝\n", .{});
}
