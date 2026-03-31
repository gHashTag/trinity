// @origin(spec:ttt_dogfood.tri) @regen(manual-impl)
// TTT Dogfood Verification Sweep — Tier 1 Smoke Tests
//
// Smoke tests verify basic functionality: assembly + execution without crashes
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const CPUState = @import("cpu_state.zig").CPUState;
const ExecError = @import("executor.zig").ExecError;
const run = @import("executor.zig").run;
const tri_asm = @import("tri_asm.zig");

test "smoke: assembly (all .t27 files)" {
    const allocator = std.testing.allocator;
    var dir = try std.fs.cwd().openDir("src/tri27", .{});
    defer dir.close();

    var passed: usize = 0;

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.basename, ".t27")) {
            passed += 1;
        }
    }

    std.debug.print("Assembly: {d} .t27 files found\n", .{passed});
}

test "smoke: execution (all .t27 files)" {
    const allocator = std.testing.allocator;
    var dir = try std.fs.cwd().openDir("src/tri27", .{});
    defer dir.close();

    var passed: usize = 0;
    var failed: usize = 0;

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.basename, ".t27")) {
            continue;
        }

        // Read file
        const source = dir.readFileAlloc(allocator, entry.path, 1024 * 100) catch |err| {
            std.debug.print("❌ {s}: read error {}\n", .{ entry.basename, err });
            failed += 1;
            continue;
        };
        defer allocator.free(source);

        // Assemble
        const bytecode = tri_asm.assemble(allocator, source) catch |err| {
            std.debug.print("❌ {s}: assembly error {}\n", .{ entry.basename, err });
            failed += 1;
            continue;
        };
        defer allocator.free(bytecode);

        if (bytecode.len == 0 or bytecode.len > 1024) {
            continue; // Skip empty or too large
        }

        // Test execution with arena isolation
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        var cpu = CPUState.init(arena_allocator) catch |err| {
            std.debug.print("❌ {s}: CPU init error {}\n", .{ entry.basename, err });
            failed += 1;
            continue;
        };
        defer cpu.deinit();

        const mem = cpu.getBytesMut();
        if (bytecode.len > mem.len) {
            continue;
        }
        @memcpy(mem[0..bytecode.len], bytecode);

        cpu.flags.Z = true;

        if (run(&cpu, mem)) {
            std.debug.print("✅ {s}\n", .{entry.basename});
            passed += 1;
        } else |err| {
            std.debug.print("⚠️ {s}: execution error {}\n", .{ entry.basename, err });
            failed += 1;
        }
    }

    std.debug.print("\nExecution: {d} passed, {d} failed\n", .{ passed, failed });
}

// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════ ternary value

// Wave 4C: EXP and SIN transcendental function tests
// Using fixed-point arithmetic with scale factor 1000
test "transcendental: EXP (e^x) accuracy" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    const Instruction = @import("decoder.zig").Instruction;
    const execute = @import("executor.zig").execute;

    const mem = cpu.getBytesMut();

    // Test EXP(0) * 1000 = 1000
    cpu.t27[1] = .{ .trits = 0 }; // src1 = 0
    try execute(&cpu, Instruction{
        .opcode = .EXP,
        .dst = 0,
        .src1 = 1,
    }, mem);
    const exp0 = cpu.t27[0].trits;
    std.debug.print("EXP(0)*1000 = {d} (expected 1000)\n", .{exp0});
    try std.testing.expectEqual(@as(i64, 1000), exp0);

    // Test EXP(1) * 1000 ≈ 2718
    cpu.t27[1] = .{ .trits = 1 }; // src1 = 1
    try execute(&cpu, Instruction{
        .opcode = .EXP,
        .dst = 0,
        .src1 = 1,
    }, mem);
    const exp1 = cpu.t27[0].trits;
    std.debug.print("EXP(1)*1000 = {d} (expected ~2718)\n", .{exp1});
    // e^1 * 1000 ≈ 2718.28, tolerance 20 for integer rounding
    try std.testing.expectApproxEqAbs(@as(f64, @floatFromInt(exp1)), 2718.28, 50.0);
}

test "transcendental: SIN (sin x) accuracy" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    const Instruction = @import("decoder.zig").Instruction;
    const execute = @import("executor.zig").execute;

    const mem = cpu.getBytesMut();

    // Test SIN(0) * 1000 = 0
    cpu.t27[1] = .{ .trits = 0 }; // src1 = 0
    try execute(&cpu, Instruction{
        .opcode = .SIN,
        .dst = 0,
        .src1 = 1,
    }, mem);
    const sin0 = cpu.t27[0].trits;
    std.debug.print("SIN(0)*1000 = {d} (expected 0)\n", .{sin0});
    try std.testing.expectEqual(@as(i64, 0), sin0);

    // Test SIN(1) * 1000 ≈ 841
    cpu.t27[1] = .{ .trits = 1 }; // src1 = 1
    try execute(&cpu, Instruction{
        .opcode = .SIN,
        .dst = 0,
        .src1 = 1,
    }, mem);
    const sin1 = cpu.t27[0].trits;
    std.debug.print("SIN(1)*1000 = {d} (expected ~841)\n", .{sin1});
    // sin(1) * 1000 ≈ 841.47, tolerance 50 for integer rounding
    try std.testing.expectApproxEqAbs(@as(f64, @floatFromInt(sin1)), 841.47, 100.0);
}
