// @origin(spec:tri27_golden_test.tri) @regen(manual-impl)
// TRI-27 GOLDEN TEST — End-to-end .tasm → .tbin → emu execution
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const testing = std.testing;

const asm_parser = @import("asm_parser.zig");
const executor = @import("executor.zig");
const CPUState = @import("cpu_state.zig").CPUState;

test "golden: load_imm, add, halt" {
    const allocator = testing.allocator;

    // .tasm source
    const asm_source =
        \\load_imm r0, 10
        \\load_imm r1, 20
        \\add r2, r0, r1
        \\halt
    ;

    // Assemble to .tbin
    const bytecode = try asm_parser.assemble(allocator, asm_source);
    defer allocator.free(bytecode);

    // Execute
    var cpu = try executor.CPUState.init(allocator);
    defer cpu.deinit();

    const executed = try cpu.execute(bytecode);
    try testing.expect(executed);

    // Verify: r2 should be 30 (10 + 20)
    const r2_value = try cpu.readRegister(2);
    try testing.expectEqual(@as(i32, 30), r2_value);
}

test "golden: load_imm, store, load" {
    const allocator = testing.allocator;

    const asm_source =
        \\load_imm r0, 42
        \\store r0, 0x100
        \\load r1, 0x100
        \\halt
    ;

    const bytecode = try asm_parser.assemble(allocator, asm_source);
    defer allocator.free(bytecode);

    var cpu = try executor.CPUState.init(allocator);
    defer cpu.deinit();

    const executed = try cpu.execute(bytecode);
    try testing.expect(executed);

    // r1 should contain 42 (loaded from memory)
    const r1_value = try cpu.readRegister(1);
    try testing.expectEqual(@as(i32, 42), r1_value);

    // Memory at 0x100 should contain 42
    const mem_value = try cpu.readMemory(0x100);
    try testing.expectEqual(@as(i32, 42), mem_value);
}

test "golden: all R-type instructions" {
    const allocator = testing.allocator;

    const asm_source =
        \\load_imm r0, 15
        \\load_imm r1, 5
        \\add r2, r0, r1
        \\sub r3, r0, r1
        \\mul r4, r2, r1
        \\halt
    ;

    const bytecode = try asm_parser.assemble(allocator, asm_source);
    defer allocator.free(bytecode);

    var cpu = try executor.CPUState.init(allocator);
    defer cpu.deinit();

    _ = try cpu.execute(bytecode);

    try testing.expectEqual(@as(i32, 20), try cpu.readRegister(2)); // 15 + 5
    try testing.expectEqual(@as(i32, 10), try cpu.readRegister(3)); // 15 - 5
    try testing.expectEqual(@as(i32, 100), try cpu.readRegister(4)); // 20 * 5
}

test "golden: comments and multi-line" {
    const allocator = testing.allocator;

    const asm_source =
        \\; This is a comment
        \\load_imm r0, 7  ; inline comment
        \\# Another comment style
        \\add r1, r0, r0
        \\halt
    ;

    const bytecode = try asm_parser.assemble(allocator, asm_source);
    defer allocator.free(bytecode);

    var cpu = try executor.CPUState.init(allocator);
    defer cpu.deinit();

    _ = try cpu.execute(bytecode);

    try testing.expectEqual(@as(i32, 14), try cpu.readRegister(1)); // 7 + 7
}
