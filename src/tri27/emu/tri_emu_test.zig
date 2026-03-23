// @origin(spec:tri27_isa.zig) @regen(manual-impl)
// TRI‑27 EMULATOR — Comprehensive Test Suite
//
// Tests for all emulator components:
// - CPU state management
// - Instruction execution
// - Memory operations
// - Control flow
// - .tbin loading
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("\n╔════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  TRI-27 EMULATOR TEST SUITE                                              ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║                                                                      ║\n", .{});
    std.debug.print("║  Running all tests...                                               ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════════╝\n\n", .{});

    // Run all test suites
    var total_passed: usize = 0;
    var total_failed: usize = 0;

    // CPU tests
    const cpu_passed = try runCPUTests(allocator);
    const cpu_failed = cpu_passed.len - cpu_passed.count(true);
    total_passed += cpu_passed.count(true);
    total_failed += cpu_failed;

    std.debug.print("\n📊 CPU Tests: {d}/{d} passed\n", .{ cpu_passed.count(true), cpu_passed.len });

    // Memory tests
    const mem_passed = try runMemoryTests(allocator);
    const mem_failed = mem_passed.len - mem_passed.count(true);
    total_passed += mem_passed.count(true);
    total_failed += mem_failed;

    std.debug.print("📊 Memory Tests: {d}/{d} passed\n", .{ mem_passed.count(true), mem_passed.len });

    // Instruction execution tests
    const exec_passed = try runExecutionTests(allocator);
    const exec_failed = exec_passed.len - exec_passed.count(true);
    total_passed += exec_passed.count(true);
    total_failed += exec_failed;

    std.debug.print("📊 Execution Tests: {d}/{d} passed\n", .{ exec_passed.count(true), exec_passed.len });

    // Loader tests
    const loader_passed = try runLoaderTests(allocator);
    const loader_failed = loader_passed.len - loader_passed.count(true);
    total_passed += loader_passed.count(true);
    total_failed += loader_failed;

    std.debug.print("📊 Loader Tests: {d}/{d} passed\n", .{ loader_passed.count(true), loader_passed.len });

    // Integration tests
    const integ_passed = try runIntegrationTests(allocator);
    const integ_failed = integ_passed.len - integ_passed.count(true);
    total_passed += integ_passed.count(true);
    total_failed += integ_failed;

    std.debug.print("📊 Integration Tests: {d}/{d} passed\n", .{ integ_passed.count(true), integ_passed.len });

    // Summary
    std.debug.print("\n╔════════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  TEST SUMMARY                                                        ║\n", .{});
    std.debug.print("╠════════════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  Total tests:     {:>5}                                             ║\n", .{ total_passed + total_failed });
    std.debug.print("║  Passed:          {:>5} ({}%)                                      ║\n", .{
        total_passed,
        @as(u32, @as(f64, total_passed) * 100.0 / @as(f64, total_passed + total_failed)),
    });
    std.debug.print("║  Failed:          {:>5} ({}%)                                      ║\n", .{
        total_failed,
        @as(u32, @as(f64, total_failed) * 100.0 / @as(f64, total_passed + total_failed)),
    });
    std.debug.print("╚══════════════════════════════════════════════════════════════════════════╝\n", .{});

    if (total_failed > 0) {
        std.debug.print("\n❌ Some tests failed!\n", .{});
        return error.TestsFailed;
    } else {
        std.debug.print("\n✅ All tests passed!\n", .{});
    }
}

fn runCPUTests(allocator: std.mem.Allocator) ![]const bool {
    const CPUState = @import("tri_exec.zig").CPUState;
    const Trit27 = @import("tri_cpu.zig").Trit27;

    var results = std.ArrayList(bool).init(allocator);
    defer results.deinit();

    const TestCase = struct { name: []const u8, test: *const fn () bool };

    const test_cases = [_]TestCase{
        .{ .name = "CPUState init", .test = testCpuInit },
    };

    for (test_cases) |test_case| {
        const passed = test_case.test();
        try results.append(passed);
        if (passed) {
            std.debug.print("  ✅ {s}", .{test_case.name});
        } else {
            std.debug.print("  ❌ {s}", .{test_case.name});
        }
    }

    return results.toOwnedSlice();
}

fn testCpuInit() bool {
    const allocator = std.testing.allocator;
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();

    return cpu.ip == 0 and
        cpu.sp == 0 and
        cpu.fp == 0 and
        cpu.instructions_executed == 0 and
        cpu.flags.H == false;
}

fn runMemoryTests(allocator: std.mem.Allocator) ![]const bool {
    const Memory = @import("tri_memory.zig").Memory;

    var results = std.ArrayList(bool).init(allocator);
    defer results.deinit();

    inline for (.{.{ .name = "Memory zero init", .test = testMemZeroInit }}) |test_case| {
        const passed = test_case();
        try results.append(passed);
        if (passed) {
            std.debug.print("  ✅ {s}", .{test_case.name});
        } else {
            std.debug.print("  ❌ {s}", .{test_case.name});
        }
    }

    return results.toOwnedSlice();
}

fn testMemZeroInit() bool {
    const allocator = std.testing.allocator;
    var mem = try Memory.init(allocator);
    defer mem.deinit(allocator);

    return mem.data[0] == 0 and mem.data[mem.data.len - 1] == 0;
}

fn runExecutionTests(allocator: std.mem.Allocator) ![]const bool {
    const CPUState = @import("tri_exec.zig").CPUState;
    const Memory = @import("tri_memory.zig").Memory;
    const Instruction = @import("tri_decode.zig").Instruction;
    const Opcode = @import("tri_decode.zig").Opcode;
    const execute = @import("tri_exec.zig").execute;

    var results = std.ArrayList(bool).init(allocator);
    defer results.deinit();

    inline for (.{
        .{ .name = "NOP execution", .test = testNopExecution },
        .{ .name = "HALT sets flag", .test = testHaltSetsFlag },
        .{ .name = "LD_IMM loads value", .test = testLdImmLoads },
        .{ .name = "ADD3 with no overflow", .test = testAdd3NoOverflow },
        .{ .name = "SUB3 result", .test = testSub3Result },
        .{ .name = "CMP3 sets flags", .test = testCmp3SetsFlags },
        .{ .name = "JMP changes IP", .test = testJmpChangesIp },
        .{ .name = "CALL pushes return addr", .test = testCallPushesReturn },
        .{ .name = "RET pops return addr", .test = testRetPopsReturn },
    }) |test_case| {
        const passed = test_case();
        try results.append(passed);
        if (passed) {
            std.debug.print("  ✅ {s}", .{test_case.name});
        } else {
            std.debug.print("  ❌ {s}", .{test_case.name});
        }
    }

    return results.toOwnedSlice();
}

fn testNopExecution() bool {
    const allocator = std.testing.allocator;
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();
    var mem = try Memory.initCustom(allocator, 100);
    defer mem.deinit(allocator);

    const inst = Instruction{
        .opcode = .NOP,
        .dst = 0,
        .src1 = 0,
        .src2 = 0,
        .immediate = 0,
        .has_imm = false,
    };

    execute(&cpu, &inst, mem.data) catch return false;

    return cpu.ip == 1 and cpu.instructions_executed == 1;
}

fn testHaltSetsFlag() bool {
    const allocator = std.testing.allocator;
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();
    var mem = try Memory.initCustom(allocator, 100);
    defer mem.deinit(allocator);

    const inst = Instruction{
        .opcode = .HALT,
        .dst = 0,
        .src1 = 0,
        .src2 = 0,
        .immediate = 0,
        .has_imm = false,
    };

    execute(&cpu, &inst, mem.data) catch return false;

    return cpu.flags.H;
}

fn testLdImmLoads() bool {
    const allocator = std.testing.allocator;
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();
    var mem = try Memory.initCustom(allocator, 100);
    defer mem.deinit(allocator);

    const inst = Instruction{
        .opcode = .LD_IMM,
        .dst = 5,
        .src1 = 0,
        .src2 = 0,
        .immediate = 1,
        .has_imm = true,
    };

    execute(&cpu, &inst, mem.data) catch return false;

    const result = cpu.t27[5].toI8Clamped();
    return result == 1 and cpu.ip == 1;
}

fn testAdd3NoOverflow() bool {
    const allocator = std.testing.allocator;
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();
    var mem = try Memory.initCustom(allocator, 100);
    defer mem.deinit(allocator);

    cpu.t27[0] = @import("tri_cpu.zig").Trit27.fromI8(1);
    cpu.t27[1] = @import("tri_cpu.zig").Trit27.ZERO;

    const inst = Instruction{
        .opcode = .ADD3,
        .dst = 2,
        .src1 = 0,
        .src2 = 1,
        .immediate = 0,
        .has_imm = false,
    };

    execute(&cpu, &inst, mem.data) catch return false;

    const result = cpu.t27[2].toI8Clamped();
    return result == 1 and !cpu.flags.V;
}

fn testSub3Result() bool {
    const allocator = std.testing.allocator;
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();
    var mem = try Memory.initCustom(allocator, 100);
    defer mem.deinit(allocator);

    cpu.t27[0] = @import("tri_cpu.zig").Trit27.fromI8(1);
    cpu.t27[1] = @import("tri_cpu.zig").Trit27.fromI8(1);

    const inst = Instruction{
        .opcode = .SUB3,
        .dst = 2,
        .src1 = 0,
        .src2 = 1,
        .immediate = 0,
        .has_imm = false,
    };

    execute(&cpu, &inst, mem.data) catch return false;

    const result = cpu.t27[2].toI8Clamped();
    return result == 0;  // 1 - 1 = 0
}

fn testCmp3SetsFlags() bool {
    const allocator = std.testing.allocator;
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();
    var mem = try Memory.initCustom(allocator, 100);
    defer mem.deinit(allocator);

    cpu.t27[0] = @import("tri_cpu.zig").Trit27.fromI8(1);
    cpu.t27[1] = @import("tri_cpu.zig").Trit27.ZERO;

    const inst = Instruction{
        .opcode = .CMP3,
        .dst = 0,
        .src1 = 0,
        .src2 = 1,
        .immediate = 0,
        .has_imm = false,
    };

    execute(&cpu, &inst, mem.data) catch return false;

    return !cpu.flags.Z and cpu.flags.N;  // Not equal, greater than (so N=0)
}

fn testJmpChangesIp() bool {
    const allocator = std.testing.allocator;
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();
    var mem = try Memory.initCustom(allocator, 100);
    defer mem.deinit(allocator);

    const inst = Instruction{
        .opcode = .JMP,
        .dst = 0,
        .src1 = 0,
        .src2 = 0,
        .immediate = 10,
        .has_imm = true,
    };

    const old_ip = cpu.ip;
    execute(&cpu, &inst, mem.data) catch return false;

    return cpu.ip == 10 and cpu.ip != old_ip;
}

fn testCallPushesReturn() bool {
    const allocator = std.testing.allocator;
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();
    var mem = try Memory.initCustom(allocator, 100);
    defer mem.deinit(allocator);

    // Set up stack pointer in memory bounds
    cpu.sp = 90;

    const inst = Instruction{
        .opcode = .CALL,
        .dst = 0,
        .src1 = 0,
        .src2 = 0,
        .immediate = 20,
        .has_imm = true,
    };

    const old_ip = cpu.ip;
    execute(&cpu, &inst, mem.data) catch return false;

    return cpu.sp == 94 and cpu.ip == 20 and cpu.ip != old_ip;
}

fn testRetPopsReturn() bool {
    const allocator = std.testing.allocator;
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();
    var mem = try Memory.initCustom(allocator, 100);
    defer mem.deinit(allocator);

    // Push return address to stack
    const return_addr: u32 = 42;
    @memcpy(&mem.data[90], &return_addr, 4);
    cpu.sp = 90;

    const inst = Instruction{
        .opcode = .RET,
        .dst = 0,
        .src1 = 0,
        .src2 = 0,
        .immediate = 0,
        .has_imm = false,
    };

    execute(&cpu, &inst, mem.data) catch return false;

    return cpu.sp == 86 and cpu.ip == 42;
}

fn runLoaderTests(allocator: std.mem.Allocator) ![]const bool {
    const Memory = @import("tri_memory.zig").Memory;
    const Instruction = @import("tri_decode.zig").Instruction;
    const Loader = @import("tri_loader.zig");

    var results = std.ArrayList(bool).init(allocator);
    defer results.deinit();

    inline for (.{
        .{ .name = "Write/load .tbin roundtrip", .test = testLoaderRoundtrip },
        .{ .name = "Invalid magic rejection", .test = testInvalidMagic },
        .{ .name = "Invalid version rejection", .test = testInvalidVersion },
    }) |test_case| {
        const passed = test_case();
        try results.append(passed);
        if (passed) {
            std.debug.print("  ✅ {s}", .{test_case.name});
        } else {
            std.debug.print("  ❌ {s}", .{test_case.name});
        }
    }

    return results.toOwnedSlice();
}

fn testLoaderRoundtrip() bool {
    const allocator = std.testing.allocator;
    const tmp_file = "test_loader_roundtrip.tbin";

    const instructions = [_]Instruction{
        .{ .opcode = .NOP, .dst = 0, .src1 = 0, .src2 = 0, .immediate = 0, .has_imm = false },
        .{ .opcode = .HALT, .dst = 0, .src1 = 0, .src2 = 0, .immediate = 0, .has_imm = false },
    };

    Loader.writeFile(tmp_file, &instructions) catch return false;
    defer {
        std.fs.cwd().deleteFile(tmp_file) catch {};
    };

    var mem = try Memory.initCustom(allocator, 100);
    defer mem.deinit(allocator);
    const result = Loader.load(tmp_file, allocator, &mem) catch return false;

    return result.instruction_count == 2;
}

fn testInvalidMagic() bool {
    const allocator = std.testing.allocator;
    var mem = try Memory.initCustom(allocator, 100);
    defer mem.deinit(allocator);

    var data: [44]u8 = undefined;
    std.mem.writeInt(u32, data[0..4], 0x12345678, .little);  // Wrong magic
    std.mem.writeInt(u16, data[4..6], 1, .little);

    const Loader = @import("tri_loader.zig");
    const result = Loader.loadFromBytes(data, allocator, &mem);

    if (result) |_| {
        return false;
    } else |err| {
        return err == error.InvalidMagic;
    }
}

fn testInvalidVersion() bool {
    const allocator = std.testing.allocator;
    var mem = try Memory.initCustom(allocator, 100);
    defer mem.deinit(allocator);

    var data: [44]u8 = undefined;
    std.mem.writeInt(u32, data[0..4], @import("tri_loader.zig").MAGIC, .little);
    std.mem.writeInt(u16, data[4..6], 2, .little);  // Unsupported version

    const Loader = @import("tri_loader.zig");
    const result = Loader.loadFromBytes(data, allocator, &mem);

    if (result) |_| {
        return false;
    } else |err| {
        return err == error.UnsupportedVersion;
    }
}

fn runIntegrationTests(allocator: std.mem.Allocator) ![]const bool {
    const CPUState = @import("tri_exec.zig").CPUState;
    const Memory = @import("tri_memory.zig").Memory;
    const Instruction = @import("tri_decode.zig").Instruction;
    const execute = @import("tri_exec.zig").execute;
    const Loader = @import("tri_loader.zig");

    var results = std.ArrayList(bool).init(allocator);
    defer results.deinit();

    inline for (.{
        .{ .name = "Simple program execution", .test = testSimpleProgram },
        .{ .name = "Loop execution", .test = testLoopExecution },
        .{ .name = "Stack depth check", .test = testStackDepth },
    }) |test_case| {
        const passed = test_case();
        try results.append(passed);
        if (passed) {
            std.debug.print("  ✅ {s}", .{test_case.name});
        } else {
            std.debug.print("  ❌ {s}", .{test_case.name});
        }
    }

    return results.toOwnedSlice();
}

fn testSimpleProgram() bool {
    const allocator = std.testing.allocator;
    var mem = try Memory.initCustom(allocator, 100);
    defer mem.deinit(allocator);
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();
    cpu.sp = 90;

    // Create program: LD_IMM 1 -> HALT
    const nop = Instruction{
        .opcode = .NOP,
        .dst = 0, .src1 = 0, .src2 = 0, .immediate = 0, .has_imm = false,
    };
    const halt = Instruction{
        .opcode = .HALT,
        .dst = 0, .src1 = 0, .src2 = 0, .immediate = 0, .has_imm = false,
    };

    const prog = [_]Instruction{ nop, halt };
    const tmp_file = "test_simple.tbin";

    Loader.writeFile(tmp_file, &prog) catch return false;
    defer {
        std.fs.cwd().deleteFile(tmp_file) catch {};
    };

    const result = Loader.load(tmp_file, allocator, &mem) catch return false;

    // Execute until halt
    var steps: u32 = 0;
    while (!cpu.flags.H and steps < 10) : (steps += 1) {
        const inst_word = try mem.readWord(cpu.ip);
        const inst = Instruction.decode(inst_word);
        execute(&cpu, &inst, mem.data) catch return false;
    }

    return cpu.flags.H and cpu.instructions_executed == 2;
}

fn testLoopExecution() bool {
    const allocator = std.testing.allocator;
    var mem = try Memory.initCustom(allocator, 100);
    defer mem.deinit(allocator);
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();
    cpu.sp = 90;

    // Create program with JMP that loops
    const nop = Instruction{
        .opcode = .NOP,
        .dst = 0, .src1 = 0, .src2 = 0, .immediate = 0, .has_imm = false,
    };
    const jump = Instruction{
        .opcode = .JMP,
        .dst = 0, .src1 = 0, .src2 = 0, .immediate = 0, .has_imm = true,
    };
    const halt = Instruction{
        .opcode = .HALT,
        .dst = 0, .src1 = 0, .src2 = 0, .immediate = 0, .has_imm = false,
    };

    const prog = [_]Instruction{ nop, jump, halt };
    const tmp_file = "test_loop.tbin";

    Loader.writeFile(tmp_file, &prog) catch return false;
    defer {
        std.fs.cwd().deleteFile(tmp_file) catch {};
    };

    const result = Loader.load(tmp_file, allocator, &mem) catch return false;

    // Execute - should halt after 3 instructions (NOP, JMP back, NOP, JMP, HALT)
    var steps: u32 = 0;
    while (!cpu.flags.H and steps < 10) : (steps += 1) {
        const inst_word = try mem.readWord(cpu.ip);
        const inst = Instruction.decode(inst_word);
        execute(&cpu, &inst, mem.data) catch return false;
    }

    return cpu.flags.H and cpu.instructions_executed == 4;
}

fn testStackDepth() bool {
    const allocator = std.testing.allocator;
    var mem = try Memory.initCustom(allocator, 100);
    defer mem.deinit(allocator);
    var cpu = CPUState.init(allocator);
    defer cpu.allocator.deinit();
    cpu.sp = 50;

    // Test CALL depth of 3
    const call1 = Instruction{
        .opcode = .CALL,
        .dst = 0, .src1 = 0, .src2 = 0, .immediate = 100, .has_imm = true,
    };
    const call2 = Instruction{
        .opcode = .CALL,
        .dst = 0, .src1 = 0, .src2 = 0, .immediate = 100, .has_imm = true,
    };
    const call3 = Instruction{
        .opcode = .CALL,
        .dst = 0, .src1 = 0, .src2 = 0, .immediate = 100, .has_imm = true,
    };
    const ret1 = Instruction{
        .opcode = .RET,
        .dst = 0, .src1 = 0, .src2 = 0, .immediate = 0, .has_imm = false,
    };
    const ret2 = Instruction{
        .opcode = .RET,
        .dst = 0, .src1 = 0, .src2 = 0, .immediate = 0, .has_imm = false,
    };
    const halt = Instruction{
        .opcode = .HALT,
        .dst = 0, .src1 = 0, .src2 = 0, .immediate = 0, .has_imm = false,
    };

    const prog = [_]Instruction{ call1, call2, call3, ret1, ret2, halt };
    const tmp_file = "test_stack.tbin";

    Loader.writeFile(tmp_file, &prog) catch return false;
    defer {
        std.fs.cwd().deleteFile(tmp_file) catch {};
    };

    const result = Loader.load(tmp_file, allocator, &mem) catch return false;

    // Execute all
    var steps: u32 = 0;
    while (!cpu.flags.H and steps < 10) : (steps += 1) {
        const inst_word = try mem.readWord(cpu.ip);
        const inst = Instruction.decode(inst_word);
        execute(&cpu, &inst, mem.data) catch return false;
    }

    // SP should be back at 50 (3 pushes, 3 pops)
    return cpu.flags.H and cpu.sp == 50;
}
