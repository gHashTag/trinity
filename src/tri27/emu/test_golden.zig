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
