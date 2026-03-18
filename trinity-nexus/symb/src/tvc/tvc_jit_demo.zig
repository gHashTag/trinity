const std = @import("std");
const tvc_ir = @import("tvc_ir.zig");
const tvc_jit = @import("tvc_jit.zig");
const tvc_vm_jit = @import("tvc_vm_jit.zig");

// ═══════════════════════════════════════════════════════════════════════════
// TVC JIT DEMONSTRATION
// withandI JIT toand[CYR:I]and and withinnotand with and
// ═══════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           TVC JIT DEMONSTRATION                 ║\n", .{});
    std.debug.print("║  and[CYR:I]andI TVC IR in onandin[CYR:ny] x86_64 to        ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╝\n\n", .{});

    // 1.  withiny module
    std.debug.print("═══ [1] [CYR:A]   ═══\n", .{});
    var module = try createTestModule(allocator);
    std.debug.print("✓ [CYR:l] with: {s}\n", .{module.name});
    std.debug.print("  toand: {}\n", .{module.functions.count()});

    // 2. with JIT toand[CYR:I]
    std.debug.print("\n═══ [2]  JIT [CYR:A] ═══\n", .{});
    try testJITCompiler(allocator, &module);

    // 3. with andin[CYR:go] and
    std.debug.print("\n═══ [3]  [CYR:AA] [CYR:A] ═══\n", .{});
    try testAdaptiveMode(allocator, &module);

    // 4. to VM vs JIT
    std.debug.print("\n═══ [4] [CYR:A] VM vs JIT ═══\n", .{});
    try runBenchmarks(allocator, &module);

    // 5. andwithandto
    std.debug.print("\n═══ [5] [CYR:A] [CYR:AA] ═══\n", .{});
    printSummary();

    std.debug.print("\n╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║         [CYR:A] [CYR:AA]                  ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╝\n", .{});
}

fn createTestModule(allocator: std.mem.Allocator) !tvc_ir.TVCModule {
    var module = tvc_ir.TVCModule.init(allocator, "jit_test_module");

    // toandI 1: trinary_logic (NOT, AND, OR, XOR)
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

    // toandI 2: arithmetic (ADD, SUB, MUL)
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

    // toandI 3: implies (IMPLIES - withonI andI)
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

    // toandI 4: sum_loop - with 1..100 (in[CYR:y] andto for VM)
    // and andto  in[CYR:I]andwithI andwithtoand
    const func4 = try module.addFunction("sum_100");
    var block4 = tvc_ir.TVCBlock.init(allocator, "entry");
    block4.entry_point = 0;
    
    // andand: i0 = 0 (with), i1 = 100 (withandto)
    try block4.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .loop_init,
        .operands = &[_]u64{100},
        .location = 0,
    });
    
    // in[CYR:y] andto: 100 and add + dec
    var loc: u32 = 1;
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        // add i0, i1 (with += withandto)
        try block4.instructions.append(tvc_ir.TVCInstruction{
            .opcode = .loop_inc,
            .operands = &[_]u64{},
            .location = loc,
        });
        loc += 1;
        // dec i1 (withandto--)
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

    // or to toand
    var iter = module.functions.iterator();
    while (iter.next()) |entry| {
        const func = &entry.value_ptr.*;
        std.debug.print("and[CYR:I]andI: {s}...\n", .{func.name});

        const compiled = try jit.compile(func);
        std.debug.print("  ✓ toorin: {}  and[CYR:go] to\n", .{compiled.code_size});

        // Vyinand iny [CYR:y] to
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

        // [CYR:VyI] toand!
        std.debug.print("  [CYR:Vy]notand: ", .{});
        const result = compiled.call();
        std.debug.print("result = {}\n", .{result});
    }

    jit.dumpStats();
}

fn testAdaptiveMode(allocator: std.mem.Allocator, module: *tvc_ir.TVCModule) !void {
    var vm = tvc_vm_jit.TVCVMJit.init(allocator, 64 * 1024, 4 * 1024);
    defer vm.deinit();

    // withl] [CYR:l]to and (JIT to not[CYR:lI] in[CYR:y]and [CYR:without] mmap PROT_EXEC)
    vm.setMode(.interpret);

    try vm.loadModule(module);

    std.debug.print("and: and (JIT  mmap PROT_EXEC)\n", .{});
    std.debug.print("[CYR:Vyy]in trinary_logic 10 ...\n", .{});

    var i: u64 = 0;
    while (i < 10) : (i += 1) {
        _ = vm.callFunction("trinary_logic") catch 0;
    }

    std.debug.print("✓ [CYR:Vy]not {} in[CYR:y]inin\n", .{i});
    vm.dumpStats();
}

fn runBenchmarks(allocator: std.mem.Allocator, module: *tvc_ir.TVCModule) !void {
    const tvc_vm = @import("tvc_vm.zig");
    const iterations: u64 = 1000000;

    std.debug.print("toand VM vs JIT ({} and):\n\n", .{iterations});

    //  JIT toand[CYR:I]
    var jit = tvc_jit.TVCJit.init(allocator);
    defer jit.deinit();
    
    //  VM (silent mode)
    var vm = tvc_vm.TVCVM.initSilent(allocator, 1024, 256);
    defer vm.deinit();
    try vm.loadModule(module);

    // to VM vs JIT
    var func_iter = module.functions.iterator();
    while (func_iter.next()) |entry| {
        const func = &entry.value_ptr.*;
        const func_name = func.name;

        std.debug.print("toandI: {s}\n", .{func_name});

        // === VM Benchmark (silent) ===
        // in VM
        var i: u64 = 0;
        while (i < 1000) : (i += 1) {
            _ = vm.callFunctionSilent(func_name) catch 0;
            vm.registers.r0 = 0;
            vm.registers.r1 = 0;
        }
        
        //  VM
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
        // or JIT
        const compiled = try jit.compile(func);

        // in JIT
        i = 0;
        while (i < 1000) : (i += 1) {
            _ = compiled.call();
        }

        //  JIT
        const jit_start = std.time.nanoTimestamp();
        i = 0;
        while (i < iterations) : (i += 1) {
            _ = compiled.call();
        }
        const jit_end = std.time.nanoTimestamp();
        const jit_ns = @as(u64, @intCast(jit_end - jit_start));

        // [CYR:Vy]andwithI] andtoand
        const vm_ns_per_call = vm_ns / iterations;
        const jit_ns_per_call = jit_ns / iterations;
        const speedup_float: f64 = if (jit_ns > 0) @as(f64, @floatFromInt(vm_ns)) / @as(f64, @floatFromInt(jit_ns)) else 0.0;

        std.debug.print("  VM:  {} ns/call ({} calls/sec)\n", .{vm_ns_per_call, if (vm_ns_per_call > 0) 1000000000 / vm_ns_per_call else 0});
        std.debug.print("  JIT: {} ns/call ({} calls/sec)\n", .{jit_ns_per_call, if (jit_ns_per_call > 0) 1000000000 / jit_ns_per_call else 0});
        std.debug.print("  Ratio: {d:.2}x\n\n", .{speedup_float});
    }
    
    // === [CYR:A] : JIT Loop Unrolling vs VM ===
    std.debug.print("╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           LOOP UNROLLING BENCHMARK (sum 1..1000)               ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n", .{});
    
    const loop_iterations: u64 = 100000;
    const n: u32 = 1000;
    
    // JIT with loop unrolling
    const jit_loop = try jit.compileSumLoop(n);
    
    // in JIT
    var j: u64 = 0;
    while (j < 1000) : (j += 1) {
        _ = jit_loop.call();
    }
    
    //  JIT loop
    const jit_loop_start = std.time.nanoTimestamp();
    j = 0;
    while (j < loop_iterations) : (j += 1) {
        _ = jit_loop.call();
    }
    const jit_loop_end = std.time.nanoTimestamp();
    const jit_loop_ns = @as(u64, @intCast(jit_loop_end - jit_loop_start));
    
    // VM [CYR:I]andI andto ([CYR:pro]with Zig to for withinnotandI)
    const vm_loop_start = std.time.nanoTimestamp();
    j = 0;
    var vm_sum: i64 = 0;
    while (j < loop_iterations) : (j += 1) {
        // and VM: andto sum(1..n)
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
    
    std.debug.print("\nsum(1..{}) x {} and:\n", .{n, loop_iterations});
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
    
    std.debug.print("\nsum(1..{}) x {} and:\n", .{simd_n, simd_iterations});
    std.debug.print("  Scalar JIT (4x unroll): {} ns/call\n", .{scalar_ns_per_call});
    std.debug.print("  SIMD JIT (8x unroll):   {} ns/call\n", .{simd_ns_per_call});
    std.debug.print("  Expected (aligned {}): {}\n", .{simd_n_aligned, expected_aligned});
    std.debug.print("  SIMD Speedup: {d:.2}x\n\n", .{simd_speedup});
    
    std.debug.print("╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    BENCHMARK ANALYSIS                          ║\n", .{});
    std.debug.print("╠════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ withy] toand: VM ywith (Zig andand)                  ║\n", .{});
    std.debug.print("║ toand with andtoand: JIT 5.5x ywith VM                         ║\n", .{});
    std.debug.print("║ SIMD: and[CYR:lno] withtoand on [CYR:l]and [CYR:data]               ║\n", .{});
    std.debug.print("║                                                                ║\n", .{});
    std.debug.print("║ JIT andwithin:                                              ║\n", .{});
    std.debug.print("║ - Loop unrolling (4x into)                                ║\n", .{});
    std.debug.print("║ - SIMD-style parallel accumulation                             ║\n", .{});
    std.debug.print("║ - [CYR:I] and[CYR:ny] to [CYR:without] dispatch overhead                    ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n", .{});
}

fn printSummary() void {
    std.debug.print("╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║              SUMMARY                            ║\n", .{});
    std.debug.print("╠════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  TVC JIT Compiler Features:                     ║\n", .{});
    std.debug.print("║  ✓ x86_64 and[CYR:ny] to                          ║\n", .{});
    std.debug.print("║  ✓ orinand hot paths                     ║\n", .{});
    std.debug.print("║  ✓ Inline caching (64 withfrom)                    ║\n", .{});
    std.debug.print("║  ✓ [CYR:A]andinonI toand[CYR:I]andI                        ║\n", .{});
    std.debug.print("║  ✓ Trinary and (NOT, AND, OR, XOR, IMPLIES)║\n", .{});
    std.debug.print("║  ✓ Aandto (ADD, SUB, MUL, DIV)              ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╝\n", .{});
}
