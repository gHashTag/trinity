const std = @import("std");
const tvc_runtime = @import("tvc_runtime.zig");
const tvc_vm = @import("tvc_vm.zig");
const tvc_ir = @import("tvc_ir.zig");
const tvc_parser = @import("tvc_parser.zig");

// TVC Runtime Demo - [CYR:Демон]with[CYR:трац]andя [CYR:полного] цandtoла in[CYR:ыпол]notнandя

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║         TVC RUNTIME DEMONSTRATION               ║\n", .{});
    std.debug.print("║  [CYR:Полный] цandtoл: .vibee → IR → VM → Execution      ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╝\n\n", .{});

    // 1. Initialization Runtime
    std.debug.print("═══ [1] [CYR:ИНИЦИАЛИЗАЦИЯ] RUNTIME ═══\n", .{});
    var runtime = try tvc_runtime.TVCRuntime.init(allocator, 1024 * 1024, 512 * 1024);
    defer runtime.deinit();

    try runtime.createVM(64 * 1024, 4 * 1024);
    runtime.start();

    // 2. Теwithт Memory Manager
    std.debug.print("\n═══ [2] [CYR:ТЕСТ] MEMORY MANAGER ═══\n", .{});
    testMemoryManager(&runtime);

    // 3. Теwithт Math Library
    std.debug.print("\n═══ [3] [CYR:ТЕСТ] MATH LIBRARY ═══\n", .{});
    testMathLibrary();

    // 4. Теwithт Balanced Ternary
    std.debug.print("\n═══ [4] [CYR:ТЕСТ] BALANCED TERNARY ═══\n", .{});
    try testBalancedTernary(allocator);

    // 5. Creation and in[CYR:ыпол]notнandе [CYR:модуля]
    std.debug.print("\n═══ [5] [CYR:ВЫПОЛНЕНИЕ] TVC [CYR:МОДУЛЯ] ═══\n", .{});
    try testModuleExecution(&runtime, allocator);

    // 6. [CYR:Стат]andwithтandtoа
    std.debug.print("\n═══ [6] [CYR:СТАТИСТИКА] RUNTIME ═══\n", .{});
    runtime.dumpState();

    // 7. [CYR:Сбор]toа муwith[CYR:ора]
    std.debug.print("\n═══ [7] [CYR:СБОРКА] [CYR:МУСОРА] ═══\n", .{});
    runtime.gc();
    std.debug.print("✓ GC in[CYR:ыпол]notн\n", .{});

    runtime.stop();

    std.debug.print("\n╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║         [CYR:ДЕМОНСТРАЦИЯ] [CYR:ЗАВЕРШЕНА]                  ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╝\n", .{});
}

fn testMemoryManager(runtime: *tvc_runtime.TVCRuntime) void {
    // Теwithт Arena Allocator
    const arena_data = runtime.memory.allocFast(256) catch {
        std.debug.print("✗ Arena alloc failed\n", .{});
        return;
    };
    std.debug.print("✓ Arena: in[CYR:ыделено] 256 [CYR:байт]\n", .{});
    _ = arena_data;

    // Теwithт GC Allocator
    const gc_data = runtime.memory.allocManaged(128) catch {
        std.debug.print("✗ GC alloc failed\n", .{});
        return;
    };
    std.debug.print("✓ GC: in[CYR:ыделено] 128 [CYR:байт]\n", .{});
    _ = gc_data;

    // [CYR:Стат]andwithтandtoа [CYR:памят]and
    const stats = runtime.memory.getStats();
    std.debug.print("  Arena used: {} bytes\n", .{stats.arena_used});
    std.debug.print("  GC objects: {}\n", .{stats.gc_objects});
    std.debug.print("  GC bytes: {}\n", .{stats.gc_bytes});
}

fn testMathLibrary() void {
    const Math = tvc_runtime.TVCMath;
    const NEG1 = tvc_vm.NEG1;
    const ZERO = tvc_vm.ZERO;
    const POS1 = tvc_vm.POS1;

    // Теwithт [CYR:базо]inых [CYR:операц]andй
    std.debug.print("Trinary арand[CYR:фмет]andtoа:\n", .{});
    std.debug.print("  add(+1, -1) = {}\n", .{Math.add(POS1, NEG1)});
    std.debug.print("  sub(+1, -1) = {}\n", .{Math.sub(POS1, NEG1)});
    std.debug.print("  mul(+1, -1) = {}\n", .{Math.mul(POS1, NEG1)});

    // Теwithт [CYR:лог]andчеwithtoandх [CYR:операц]andй
    std.debug.print("Trinary [CYR:лог]andtoа:\n", .{});
    std.debug.print("  AND(+1, 0) = {}\n", .{Math.tritAnd(POS1, ZERO)});
    std.debug.print("  OR(+1, 0) = {}\n", .{Math.tritOr(POS1, ZERO)});
    std.debug.print("  XOR(+1, -1) = {}\n", .{Math.tritXor(POS1, NEG1)});
    std.debug.print("  NOT(+1) = {}\n", .{Math.tritNot(POS1)});
    std.debug.print("  IMPLIES(+1, -1) = {}\n", .{Math.tritImplies(POS1, NEG1)});

    // Теwithт Golden Identity
    std.debug.print("Golden Identity:\n", .{});
    std.debug.print("  φ = {}\n", .{Math.PHI});
    std.debug.print("  φ² + 1/φ² = {} ([CYR:должно] [CYR:быть] 3)\n", .{Math.goldenIdentity()});
}

fn testBalancedTernary(allocator: std.mem.Allocator) !void {
    const Math = tvc_runtime.TVCMath;

    // [CYR:Базо]inые теwithты toонinерwithandand
    const test_numbers = [_]i64{ 0, 1, -1, 5, -5, 13, -13, 42, -42, 100, -100 };

    std.debug.print("Balanced Ternary toонinерwithandя:\n", .{});
    var passed: usize = 0;
    var failed: usize = 0;

    for (test_numbers) |n| {
        const trits = try Math.intToBalancedTernary(allocator, n);
        defer allocator.free(trits);

        const back = Math.balancedTernaryToInt(trits);

        std.debug.print("  {} → [", .{n});
        for (trits) |t| {
            const c: u8 = if (t == 1) '+' else if (t == -1) '-' else '0';
            std.debug.print("{c}", .{c});
        }
        const ok = n == back;
        std.debug.print("] → {} {s}\n", .{ back, if (ok) "✓" else "✗" });
        if (ok) passed += 1 else failed += 1;
    }

    // Теwithты арand[CYR:фмет]andtoand
    std.debug.print("\nАрand[CYR:фмет]andtoа трandтоinых маwithwithandinоin:\n", .{});

    // Теwithт with[CYR:ложен]andя
    std.debug.print("  [CYR:СЛОЖЕНИЕ]:\n", .{});
    const add_tests = [_]struct { a: i64, b: i64 }{
        .{ .a = 5, .b = 3 },     // 5 + 3 = 8
        .{ .a = -5, .b = 3 },    // -5 + 3 = -2
        .{ .a = 13, .b = -13 },  // 13 + (-13) = 0
        .{ .a = 42, .b = 58 },   // 42 + 58 = 100
        .{ .a = -100, .b = 50 }, // -100 + 50 = -50
    };

    for (add_tests) |test_case| {
        const a_trits = try Math.intToBalancedTernary(allocator, test_case.a);
        defer allocator.free(a_trits);
        const b_trits = try Math.intToBalancedTernary(allocator, test_case.b);
        defer allocator.free(b_trits);

        const sum_trits = try Math.addTrits(allocator, a_trits, b_trits);
        defer allocator.free(sum_trits);

        const result = Math.balancedTernaryToInt(sum_trits);
        const expected = test_case.a + test_case.b;
        const ok = result == expected;

        std.debug.print("    {} + {} = {} (expected {}) {s}\n", .{ test_case.a, test_case.b, result, expected, if (ok) "✓" else "✗" });
        if (ok) passed += 1 else failed += 1;
    }

    // Теwithт inычand[CYR:тан]andя
    std.debug.print("  [CYR:ВЫЧИТАНИЕ]:\n", .{});
    const sub_tests = [_]struct { a: i64, b: i64 }{
        .{ .a = 10, .b = 3 },    // 10 - 3 = 7
        .{ .a = 5, .b = 8 },     // 5 - 8 = -3
        .{ .a = -5, .b = -3 },   // -5 - (-3) = -2
        .{ .a = 100, .b = 100 }, // 100 - 100 = 0
    };

    for (sub_tests) |test_case| {
        const a_trits = try Math.intToBalancedTernary(allocator, test_case.a);
        defer allocator.free(a_trits);
        const b_trits = try Math.intToBalancedTernary(allocator, test_case.b);
        defer allocator.free(b_trits);

        const diff_trits = try Math.subTrits(allocator, a_trits, b_trits);
        defer allocator.free(diff_trits);

        const result = Math.balancedTernaryToInt(diff_trits);
        const expected = test_case.a - test_case.b;
        const ok = result == expected;

        std.debug.print("    {} - {} = {} (expected {}) {s}\n", .{ test_case.a, test_case.b, result, expected, if (ok) "✓" else "✗" });
        if (ok) passed += 1 else failed += 1;
    }

    // Теwithт [CYR:умножен]andя
    std.debug.print("  [CYR:УМНОЖЕНИЕ]:\n", .{});
    const mul_tests = [_]struct { a: i64, b: i64 }{
        .{ .a = 3, .b = 4 },     // 3 * 4 = 12
        .{ .a = -3, .b = 4 },    // -3 * 4 = -12
        .{ .a = -3, .b = -4 },   // -3 * -4 = 12
        .{ .a = 7, .b = 0 },     // 7 * 0 = 0
        .{ .a = 5, .b = 5 },     // 5 * 5 = 25
        .{ .a = 9, .b = 9 },     // 9 * 9 = 81
    };

    for (mul_tests) |test_case| {
        const a_trits = try Math.intToBalancedTernary(allocator, test_case.a);
        defer allocator.free(a_trits);
        const b_trits = try Math.intToBalancedTernary(allocator, test_case.b);
        defer allocator.free(b_trits);

        const prod_trits = try Math.mulTrits(allocator, a_trits, b_trits);
        defer allocator.free(prod_trits);

        const result = Math.balancedTernaryToInt(prod_trits);
        const expected = test_case.a * test_case.b;
        const ok = result == expected;

        std.debug.print("    {} * {} = {} (expected {}) {s}\n", .{ test_case.a, test_case.b, result, expected, if (ok) "✓" else "✗" });
        if (ok) passed += 1 else failed += 1;
    }

    // Теwithт [CYR:делен]andя
    std.debug.print("  [CYR:ДЕЛЕНИЕ]:\n", .{});
    const div_tests = [_]struct { a: i64, b: i64 }{
        .{ .a = 12, .b = 4 },    // 12 / 4 = 3
        .{ .a = 13, .b = 4 },    // 13 / 4 = 3 ([CYR:целоч]andwith[CYR:ленное])
        .{ .a = -12, .b = 4 },   // -12 / 4 = -3
        .{ .a = 81, .b = 9 },    // 81 / 9 = 9
        .{ .a = 100, .b = 10 },  // 100 / 10 = 10
    };

    for (div_tests) |test_case| {
        const a_trits = try Math.intToBalancedTernary(allocator, test_case.a);
        defer allocator.free(a_trits);
        const b_trits = try Math.intToBalancedTernary(allocator, test_case.b);
        defer allocator.free(b_trits);

        const quot_trits = try Math.divTrits(allocator, a_trits, b_trits);
        defer allocator.free(quot_trits);

        const result = Math.balancedTernaryToInt(quot_trits);
        const expected = @divTrunc(test_case.a, test_case.b);
        const ok = result == expected;

        std.debug.print("    {} / {} = {} (expected {}) {s}\n", .{ test_case.a, test_case.b, result, expected, if (ok) "✓" else "✗" });
        if (ok) passed += 1 else failed += 1;
    }

    // Теwithт withраinnotнandя
    std.debug.print("  [CYR:СРАВНЕНИЕ]:\n", .{});
    const cmp_tests = [_]struct { a: i64, b: i64, expected: i8 }{
        .{ .a = 5, .b = 3, .expected = 1 },      // 5 > 3
        .{ .a = 3, .b = 5, .expected = -1 },     // 3 < 5
        .{ .a = 5, .b = 5, .expected = 0 },      // 5 == 5
        .{ .a = -5, .b = 5, .expected = -1 },    // -5 < 5
        .{ .a = -5, .b = -10, .expected = 1 },   // -5 > -10
    };

    for (cmp_tests) |test_case| {
        const a_trits = try Math.intToBalancedTernary(allocator, test_case.a);
        defer allocator.free(a_trits);
        const b_trits = try Math.intToBalancedTernary(allocator, test_case.b);
        defer allocator.free(b_trits);

        const cmp_result = Math.compareTrits(a_trits, b_trits);
        const ok = cmp_result == test_case.expected;

        const cmp_str = if (cmp_result == 1) ">" else if (cmp_result == -1) "<" else "==";
        std.debug.print("    {} {s} {} {s}\n", .{ test_case.a, cmp_str, test_case.b, if (ok) "✓" else "✗" });
        if (ok) passed += 1 else failed += 1;
    }

    // Теwithт inозin[CYR:еден]andя in with[CYR:тепень]
    std.debug.print("  [CYR:СТЕПЕНЬ]:\n", .{});
    const pow_tests = [_]struct { base: i64, exp: u32, expected: i64 }{
        .{ .base = 2, .exp = 0, .expected = 1 },   // 2^0 = 1
        .{ .base = 2, .exp = 1, .expected = 2 },   // 2^1 = 2
        .{ .base = 2, .exp = 3, .expected = 8 },   // 2^3 = 8
        .{ .base = 3, .exp = 4, .expected = 81 },  // 3^4 = 81
        .{ .base = -2, .exp = 3, .expected = -8 }, // (-2)^3 = -8
    };

    for (pow_tests) |test_case| {
        const base_trits = try Math.intToBalancedTernary(allocator, test_case.base);
        defer allocator.free(base_trits);

        const pow_trits = try Math.powTrits(allocator, base_trits, test_case.exp);
        defer allocator.free(pow_trits);

        const result = Math.balancedTernaryToInt(pow_trits);
        const ok = result == test_case.expected;

        std.debug.print("    {}^{} = {} (expected {}) {s}\n", .{ test_case.base, test_case.exp, result, test_case.expected, if (ok) "✓" else "✗" });
        if (ok) passed += 1 else failed += 1;
    }

    // [CYR:Итог]and
    std.debug.print("\nResultы: {} passed, {} failed\n", .{ passed, failed });
}

fn testModuleExecution(runtime: *tvc_runtime.TVCRuntime, allocator: std.mem.Allocator) !void {
    // [CYR:Создаём] теwithтоinый module
    var module = tvc_ir.TVCModule.init(allocator, "test_runtime_module");

    // [CYR:Доба]in[CYR:ляем] [CYR:фун]toцandю trinary_logic
    const func = try module.addFunction("trinary_logic");

    var block = tvc_ir.TVCBlock.init(allocator, "entry");
    block.entry_point = 0;

    // Инwith[CYR:тру]toцandand: NOT, AND, OR, XOR, IMPLIES, RET
    try block.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .t_not,
        .operands = &[_]u64{},
        .location = 0,
    });

    try block.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .t_and,
        .operands = &[_]u64{},
        .location = 1,
    });

    try block.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .t_or,
        .operands = &[_]u64{},
        .location = 2,
    });

    try block.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .t_xor,
        .operands = &[_]u64{},
        .location = 3,
    });

    try block.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .t_implies,
        .operands = &[_]u64{},
        .location = 4,
    });

    try block.instructions.append(tvc_ir.TVCInstruction{
        .opcode = .ret,
        .operands = &[_]u64{},
        .location = 5,
    });

    block.exit_point = 5;
    try func.blocks.put("entry", block);
    func.returns = .i64_trit;

    // [CYR:Загружаем] and in[CYR:ыполняем]
    try runtime.loadModule(&module);
    std.debug.print("✓ [CYR:Модуль] [CYR:загружен]: {s}\n", .{module.name});

    try runtime.callFunction("trinary_logic");
    std.debug.print("✓ [CYR:Фун]toцandя trinary_logic in[CYR:ыпол]noton\n", .{});
}
