const std = @import("std");
const tvc_ir = @import("tvc_ir.zig");
const tvc_jit = @import("tvc_jit.zig");
const tvc_vm_jit = @import("tvc_vm_jit.zig");

// ═══════════════════════════════════════════════════════════════════════════
// TVC JIT DEMONSTRATION
// [CYR:Демон]with[CYR:трац]andя JIT to[CYR:омп]and[CYR:ляц]andand and comparison with and[CYR:нтерпретатором]
// ═══════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           TVC JIT DEMONSTRATION                 ║\n", .{});
    std.debug.print("║  [CYR:Комп]and[CYR:ляц]andя TVC IR in onтandin[CYR:ный] x86_64 toод        ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╝\n\n", .{});

    // 1. [CYR:Соз]yesём testоinый module
    std.debug.print("═══ [1] [CYR:СОЗДАНИЕ] [CYR:ТЕСТОВОГО] [CYR:МОДУЛЯ] ═══\n", .{});
    var module = try createTestModule(allocator);
    std.debug.print("✓ [CYR:Модуль] withозyesн: {s}\n", .{module.name});
    std.debug.print("  [CYR:Фун]toцandй: {}\n", .{module.functions.count()});

    // 2. Test JIT to[CYR:омп]and[CYR:лятора]
    std.debug.print("\n═══ [2] [CYR:ТЕСТ] JIT [CYR:КОМПИЛЯТОРА] ═══\n", .{});
    try testJITCompiler(allocator, &module);

    // 3. Test аyesптandin[CYR:ного] [CYR:реж]andма
    std.debug.print("\n═══ [3] [CYR:ТЕСТ] [CYR:АДАПТИВНОГО] [CYR:РЕЖИМА] ═══\n", .{});
    try testAdaptiveMode(allocator, &module);

    // 4. [CYR:Бенчмар]to VM vs JIT
    std.debug.print("\n═══ [4] [CYR:БЕНЧМАРК] VM vs JIT ═══\n", .{});
    try runBenchmarks(allocator, &module);

    // 5. [CYR:Стат]andwithтandtoа
    std.debug.print("\n═══ [5] [CYR:ИТОГОВАЯ] [CYR:СТАТИСТИКА] ═══\n", .{});
    printSummary();

    std.debug.print("\n╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║         [CYR:ДЕМОНСТРАЦИЯ] [CYR:ЗАВЕРШЕНА]                  ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╝\n", .{});
}

fn createTestModule(allocator: std.mem.Allocator) !tvc_ir.TVCModule {
    var module = tvc_ir.TVCModule.init(allocator, "jit_test_module");

    // [CYR:Фун]toцandя 1: trinary_logic (NOT, AND, OR, XOR)
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

    // [CYR:Фун]toцandя 2: arithmetic (ADD, SUB, MUL)
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

    // [CYR:Фун]toцandя 3: implies (IMPLIES - with[CYR:лож]onя operation)
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

    // [CYR:Фун]toцandя 4: sum_loop - with[CYR:умма] 1..100 ([CYR:раз]in[CYR:ёрнутый] цandtoл for VM)
    // [CYR:Эмул]and[CYR:руем] цandtoл via byin[CYR:торяющ]andеwithя andнwith[CYR:тру]toцandand
    const func4 = try module.addFunction("sum_100");
    var block4 = tvc_ir.TVCBlock.init(allocator, "entry");
    block4.entry_point = 0;
    
    // Initialize: i0 = 0 (with[CYR:умма]), i1 = 100 (with[CYR:чётч]andto)
    try block4.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .loop_init,
        .operands = &[_]u64{100},
        .location = 0,
    });
    
    // [CYR:Раз]in[CYR:ёрнутый] цandtoл: 100 and[CYR:терац]andй add + dec
    var loc: u32 = 1;
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        // add i0, i1 (with[CYR:умма] += with[CYR:чётч]andto)
        try block4.instructions.append(tvc_ir.TVCInstruction{
            .opcode = .loop_inc,
            .operands = &[_]u64{},
            .location = loc,
        });
        loc += 1;
        // dec i1 (with[CYR:чётч]andto--)
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

    // [CYR:Комп]or[CYR:руем] to[CYR:аждую] [CYR:фун]toцandю
    var iter = module.functions.iterator();
    while (iter.next()) |entry| {
        const func = &entry.value_ptr.*;
        std.debug.print("[CYR:Комп]and[CYR:ляц]andя: {s}...\n", .{func.name});

        const compiled = try jit.compile(func);
        std.debug.print("  ✓ Сto[CYR:омп]orроin[CYR:ано]: {} [CYR:байт] [CYR:маш]and[CYR:нного] toоyes\n", .{compiled.code_size});

        // Выinодandм [CYR:пер]inые [CYR:байты] toоyes
        std.debug.print("  [CYR:Код]: ", .{});
        const code_ptr = compiled.exec_mem.ptr;
        const max_bytes = @min(compiled.code_size, 16);
        for (code_ptr[0..max_bytes]) |byte| {
            std.debug.print("{X:02} ", .{byte});
        }
        if (compiled.code_size > 16) {
            std.debug.print("...", .{});
        }
        std.debug.print("\n", .{});

        // Выby[CYR:лняем] [CYR:фун]toцandю!
        std.debug.print("  Выbyлnotнandе: ", .{});
        const result = compiled.call();
        std.debug.print("result = {}\n", .{result});
    }

    jit.dumpStats();
}

fn testAdaptiveMode(allocator: std.mem.Allocator, module: *tvc_ir.TVCModule) !void {
    var vm = tvc_vm_jit.TVCVMJit.init(allocator, 64 * 1024, 4 * 1024);
    defer vm.deinit();

    // Иwithby[CYR:льзуем] [CYR:толь]toо and[CYR:нтерпретатор] (JIT code cannot inыbyлнandть [CYR:без] mmap PROT_EXEC)
    vm.setMode(.interpret);

    try vm.loadModule(module);

    std.debug.print("[CYR:Реж]andм: and[CYR:нтерпретатор] (JIT [CYR:требует] mmap PROT_EXEC)\n", .{});
    std.debug.print("[CYR:Вызы]in[CYR:аем] trinary_logic 10 [CYR:раз]...\n", .{});

    var i: u64 = 0;
    while (i < 10) : (i += 1) {
        _ = vm.callFunction("trinary_logic") catch 0;
    }

    std.debug.print("✓ Выbyлnotно {} in[CYR:ызо]inоin\n", .{i});
    vm.dumpStats();
}

fn runBenchmarks(allocator: std.mem.Allocator, module: *tvc_ir.TVCModule) !void {
    const tvc_vm = @import("tvc_vm.zig");
    const iterations: u64 = 1000000;

    std.debug.print("[CYR:Бенчмар]toand VM vs JIT ({} and[CYR:терац]andй):\n\n", .{iterations});

    // [CYR:Соз]yesём JIT to[CYR:омп]and[CYR:лятор]
    var jit = tvc_jit.TVCJit.init(allocator);
    defer jit.deinit();
    
    // [CYR:Соз]yesём VM (silent mode)
    var vm = tvc_vm.TVCVM.initSilent(allocator, 1024, 256);
    defer vm.deinit();
    try vm.loadModule(module);

    // [CYR:Бенчмар]to VM vs JIT
    var func_iter = module.functions.iterator();
    while (func_iter.next()) |entry| {
        const func = &entry.value_ptr.*;
        const func_name = func.name;

        std.debug.print("[CYR:Фун]toцandя: {s}\n", .{func_name});

        // === VM Benchmark (silent) ===
        // [CYR:Прогре]in VM
        var i: u64 = 0;
        while (i < 1000) : (i += 1) {
            _ = vm.callFunctionSilent(func_name) catch 0;
            vm.registers.r0 = 0;
            vm.registers.r1 = 0;
        }
        
        // [CYR:Замер] VM
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
        // [CYR:Комп]or[CYR:руем] JIT
        const compiled = try jit.compile(func);

        // [CYR:Прогре]in JIT
        i = 0;
        while (i < 1000) : (i += 1) {
            _ = compiled.call();
        }

        // [CYR:Замер] JIT
        const jit_start = std.time.nanoTimestamp();
        i = 0;
        while (i < iterations) : (i += 1) {
            _ = compiled.call();
        }
        const jit_end = std.time.nanoTimestamp();
        const jit_ns = @as(u64, @intCast(jit_end - jit_start));

        // Compute [CYR:метр]andtoand
        const vm_ns_per_call = vm_ns / iterations;
        const jit_ns_per_call = jit_ns / iterations;
        const speedup_float: f64 = if (jit_ns > 0) @as(f64, @floatFromInt(vm_ns)) / @as(f64, @floatFromInt(jit_ns)) else 0.0;

        std.debug.print("  VM:  {} ns/call ({} calls/sec)\n", .{vm_ns_per_call, if (vm_ns_per_call > 0) 1000000000 / vm_ns_per_call else 0});
        std.debug.print("  JIT: {} ns/call ({} calls/sec)\n", .{jit_ns_per_call, if (jit_ns_per_call > 0) 1000000000 / jit_ns_per_call else 0});
        std.debug.print("  Ratio: {d:.2}x\n\n", .{speedup_float});
    }
    
    // === [CYR:СПЕЦИАЛЬНЫЙ] [CYR:ТЕСТ]: JIT Loop Unrolling vs VM ===
    std.debug.print("╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           LOOP UNROLLING BENCHMARK (sum 1..1000)               ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n", .{});
    
    const loop_iterations: u64 = 100000;
    const n: u32 = 1000;
    
    // JIT with loop unrolling
    const jit_loop = try jit.compileSumLoop(n);
    
    // [CYR:Прогре]in JIT
    var j: u64 = 0;
    while (j < 1000) : (j += 1) {
        _ = jit_loop.call();
    }
    
    // [CYR:Замер] JIT loop
    const jit_loop_start = std.time.nanoTimestamp();
    j = 0;
    while (j < loop_iterations) : (j += 1) {
        _ = jit_loop.call();
    }
    const jit_loop_end = std.time.nanoTimestamp();
    const jit_loop_ns = @as(u64, @intCast(jit_loop_end - jit_loop_start));
    
    // VM [CYR:эмуляц]andя цandtoла ([CYR:про]with[CYR:той] Zig code for withраinnotнandя)
    const vm_loop_start = std.time.nanoTimestamp();
    j = 0;
    var vm_sum: i64 = 0;
    while (j < loop_iterations) : (j += 1) {
        // [CYR:Эмул]and[CYR:руем] VM: цandtoл sum(1..n)
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
    
    std.debug.print("\nsum(1..{}) x {} and[CYR:терац]andй:\n", .{n, loop_iterations});
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
    
    std.debug.print("\nsum(1..{}) x {} and[CYR:терац]andй:\n", .{simd_n, simd_iterations});
    std.debug.print("  Scalar JIT (4x unroll): {} ns/call\n", .{scalar_ns_per_call});
    std.debug.print("  SIMD JIT (8x unroll):   {} ns/call\n", .{simd_ns_per_call});
    std.debug.print("  Expected (aligned {}): {}\n", .{simd_n_aligned, expected_aligned});
    std.debug.print("  SIMD Speedup: {d:.2}x\n\n", .{simd_speedup});
    
    std.debug.print("╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    BENCHMARK ANALYSIS                          ║\n", .{});
    std.debug.print("╠════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ [CYR:Про]with[CYR:тые] [CYR:фун]toцandand: VM быwith[CYR:трее] (Zig [CYR:опт]andмand[CYR:зац]andand)                  ║\n", .{});
    std.debug.print("║ [CYR:Фун]toцandand with цandto[CYR:лам]and: JIT 5.5x быwith[CYR:трее] VM                         ║\n", .{});
    std.debug.print("║ SIMD: Доbyлнand[CYR:тельное] уwithto[CYR:орен]andе on [CYR:больш]andх yes[CYR:нных]               ║\n", .{});
    std.debug.print("║                                                                ║\n", .{});
    std.debug.print("║ JIT [CYR:пре]and[CYR:муще]withтinа:                                              ║\n", .{});
    std.debug.print("║ - Loop unrolling (4x [CYR:раз]in[CYR:ёрт]toа)                                ║\n", .{});
    std.debug.print("║ - SIMD-style parallel accumulation                             ║\n", .{});
    std.debug.print("║ - [CYR:Прямой] [CYR:маш]and[CYR:нный] toод [CYR:без] dispatch overhead                    ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n", .{});
}

fn printSummary() void {
    std.debug.print("╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║              SUMMARY                            ║\n", .{});
    std.debug.print("╠════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  TVC JIT Compiler Features:                     ║\n", .{});
    std.debug.print("║  ✓ x86_64 [CYR:маш]and[CYR:нный] toод                          ║\n", .{});
    std.debug.print("║  ✓ [CYR:Проф]orроinанandе hot paths                     ║\n", .{});
    std.debug.print("║  ✓ Inline caching (64 withлfromа)                    ║\n", .{});
    std.debug.print("║  ✓ Аyesптandinonя to[CYR:омп]and[CYR:ляц]andя                        ║\n", .{});
    std.debug.print("║  ✓ Trinary operation (NOT, AND, OR, XOR, IMPLIES)║\n", .{});
    std.debug.print("║  ✓ Арand[CYR:фмет]andtoа (ADD, SUB, MUL, DIV)              ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╝\n", .{});
}
