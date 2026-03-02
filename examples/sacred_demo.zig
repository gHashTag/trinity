// Sacred Opcodes Demo - KOSCHEI AWAKENS v7.0
const std = @import("std");
const vm_mod = @import("src/vm.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     KOSCHEI AWAKENS v7.0 — SACRED OPCODES DEMO                ║\n", .{});
    std.debug.print("║     φ² + 1/φ² = 3 = TRINITY                                   ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n\n", .{});

    var sacred_vm = vm_mod.VSAVM.init(allocator);
    defer sacred_vm.deinit();

    // Test 1: φ constant
    try sacred_vm.loadPhi();
    std.debug.print("✓ PHI_CONST: f0 = {d:.15} (expected: 1.618033988749895)\n", .{sacred_vm.registers.f0});

    // Test 2: φ^10
    sacred_vm.registers.s0 = 10;
    try sacred_vm.phiPow();
    std.debug.print("✓ PHI_POW(10): f0 = {d:.6} (expected: 122.991...)\n", .{sacred_vm.registers.f0});

    // Test 3: Fibonacci F(10)
    sacred_vm.registers.s0 = 10;
    try sacred_vm.fib();
    std.debug.print("✓ FIB(10): s0 = {d} (expected: 55)\n", .{sacred_vm.registers.s0});

    // Test 4: Sacred Identity
    try sacred_vm.verifySacredIdentity();
    std.debug.print("✓ SACRED_IDENTITY: cc_zero={}, f0={d:.15} (φ²+1/φ²=3)\n", .{ sacred_vm.registers.cc_zero, sacred_vm.registers.f0 });

    // Test 5: Physics constants
    try sacred_vm.execSacredOpcode(.light_speed, .{});
    std.debug.print("✓ LIGHT_SPEED: f0 = {d:.0} m/s\n", .{sacred_vm.registers.f0});

    try sacred_vm.execSacredOpcode(.hbar, .{});
    std.debug.print("✓ HBAR: f0 = {e} J·s\n", .{sacred_vm.registers.f0});

    // Test 6: Ideal Gas Law
    sacred_vm.registers.f0 = 0; // P (solve for P)
    sacred_vm.registers.f1 = 22.4; // V = 22.4 L
    sacred_vm.registers.f2 = 1.0; // n = 1 mol
    sacred_vm.registers.f3 = 273.15; // T = 273.15 K (STP)
    try sacred_vm.execSacredOpcode(.ideal_gas, .{});
    std.debug.print("✓ IDEAL_GAS: P = {d:.3} kPa (PV=nRT, n=1mol, V=22.4L, T=273.15K)\n", .{sacred_vm.registers.f0 / 1000 });

    // Sacred context stats
    std.debug.print("\n", .{});
    std.debug.print("╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    SACRED CONTEXT STATS                      ║\n", .{});
    std.debug.print("╠════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  Cycle Count: {}                                           ║\n", .{sacred_vm.sacred_ctx.cycle_count});
    if (sacred_vm.sacred_ctx.last_sacred_op) |op| {
        std.debug.print("║  Last Opcode: {s}                                          ║\n", .{@tagName(op)});
    } else {
        std.debug.print("║  Last Opcode: (none)                                       ║\n", .{});
    }
    std.debug.print("║  VM Cycles: {}                                              ║\n", .{sacred_vm.cycle_count});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n\n", .{});
}
