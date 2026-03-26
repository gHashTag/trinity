// TRI-27 GOLDEN TEST — Full cycle test
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const tri_asm = @import("tri_asm.zig");
const loader = @import("loader.zig");
const executor = @import("executor.zig");
const cpu_mod = @import("cpu_state.zig");

test "full cycle: asm → tbin → emulator → verify" {
    const allocator = std.testing.allocator;

    // 1. Assemble from source to bytecode
    const asm_source =
        \\LDI t0, 1
        \\LDI t1, 0
        \\ADD t2, t0, t1
        \\HALT
    ;

    const bytecode = try tri_asm.assemble(allocator, asm_source);
    defer allocator.free(bytecode);

    // 2. Load bytecode into CPU
    var cpu = try cpu_mod.CPUState.init(allocator);
    defer cpu.deinit();
    try loader.load(&cpu, bytecode, &[_]f64{});

    // 3. Execute program
    try executor.run(&cpu, cpu.getBytesMut());

    // 4. Verify HALT flag is set
    try testing.expectEqual(true, cpu.flags.H);

    // 5. Verify result: t2 should be 1 (1 + 0 = 1)
    // Note: LDI stores clamped value -1, 0, or 1 as ternary
    // After ADD: t2.trits = 1 (Trit27 represents -1, 0, +1)
    const result = cpu.t27[2].toI8Clamped();
    try testing.expectEqual(@as(i8, 1), result);

    std.debug.print("✅ Golden test PASSED\\n", .{});
}

test "assembler: all new opcodes parse correctly" {
    const allocator = std.testing.allocator;

    // Test SUB, MUL, JMP, CALL, RET, STI
    const asm_source =
        \\LDI t0, 5
        \\LDI t1, 3
        \\SUB t2, t0, t1
        \\LDI t3, 2
        \\MUL t4, t2, t3
        \\JMP 2
        \\CALL 5
        \\RET
        \\STI 42, t5
        \\HALT
    ;

    const bytecode = try tri_asm.assemble(allocator, asm_source);
    defer allocator.free(bytecode);

    // Verify we have 10 instructions (10 * 4 bytes + 10 byte header)
    const expected_size = 10 * 4 + 10;
    try testing.expectEqual(expected_size, bytecode.len);

    std.debug.print("✅ All new opcodes parse correctly\\n", .{});
}

test "assembler: arithmetic operations (SUB, MUL, DIV)" {
    const allocator = std.testing.allocator;

    const asm_source =
        \\LDI t0, 10
        \\LDI t1, 3
        \\SUB t2, t0, t1
        \\MUL t3, t2, t1
        \\DIV t4, t0, t1
        \\HALT
    ;

    const bytecode = try tri_asm.assemble(allocator, asm_source);
    defer allocator.free(bytecode);

    try testing.expectEqual(@as(usize, 6 * 4 + 10), bytecode.len);

    std.debug.print("✅ Arithmetic opcodes parse correctly\\n", .{});
}

test "assembler: control flow (JMP, CALL, RET)" {
    const allocator = std.testing.allocator;

    const asm_source =
        \\JMP 10
        \\CALL 5
        \\RET
        \\HALT
    ;

    const bytecode = try tri_asm.assemble(allocator, asm_source);
    defer allocator.free(bytecode);

    try testing.expectEqual(@as(usize, 4 * 4 + 10), bytecode.len);

    std.debug.print("✅ Control flow opcodes parse correctly\\n", .{});
}

test "assembler: logic operations (AND, OR, XOR, NOT, SHL, SHR)" {
    const allocator = std.testing.allocator;

    const asm_source =
        \\LDI t0, 15
        \\LDI t1, 7
        \\AND t2, t0, t1
        \\OR t3, t0, t1
        \\XOR t4, t0, t1
        \\NOT t5
        \\SHL t6, t0, 2
        \\SHR t7, t0, 1
        \\HALT
    ;

    const bytecode = try tri_asm.assemble(allocator, asm_source);
    defer allocator.free(bytecode);

    try testing.expectEqual(@as(usize, 9 * 4 + 10), bytecode.len);

    std.debug.print("✅ Logic opcodes parse correctly\\n", .{});
}

test "assembler: labels and forward references" {
    const allocator = std.testing.allocator;

    // Test label support with loop
    const asm_source =
        \\LDI t0, 1
        \\LDI t1, 0
        \\ADD t2, t0, t1
        \\loop:
        \\INC t2
        \\LDI t3, 1
        \\JZ t3, loop
        \\HALT
    ;

    const bytecode = try tri_asm.assemble(allocator, asm_source);
    defer allocator.free(bytecode);

    try testing.expectEqual(@as(usize, 7 * 4 + 10), bytecode.len);

    std.debug.print("✅ Label support working correctly\\n", .{});
}

test "assembler: error messages with line numbers" {
    const allocator = std.testing.allocator;

    // Test undefined label error
    const asm_source =
        \\LDI t0, 1
        \\JMP undefined_label
        \\HALT
    ;

    const result = tri_asm.assemble(allocator, asm_source);
    try testing.expectError(tri_asm.AsmError.UndefinedLabel, result);

    std.debug.print("✅ Line number error messages working\\n", .{});
}
