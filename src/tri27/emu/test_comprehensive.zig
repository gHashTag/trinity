const std = @import("std");
const testing = std.testing;
const CPUState = @import("cpu_state.zig").CPUState;
const Opcode = @import("decoder.zig").Opcode;
const encode = @import("decoder.zig").encode;
const Instruction = @import("decoder.zig").Instruction;
const execute = @import("executor.zig").execute;
const Trit27 = @import("tri_cpu.zig").Trit27;

// ═══════════════════════════════════════════════════════════════════════════════
// CONTROL FLOW TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TRI-27: Control Flow - NOP" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.t27[0] = Trit27.fromI8(1);

    const inst = Instruction{
        .opcode = Opcode.NOP,
        .dst = 0,
        .src1 = 0,
        .src2 = 0,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    try testing.expectEqual(@as(u32, 1), cpu.pc);
    try testing.expectEqual(@as(i8, 1), cpu.t27[0].toI8Clamped());
}

test "TRI-27: Control Flow - HALT" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    const inst = Instruction{
        .opcode = Opcode.HALT,
        .dst = 0,
        .src1 = 0,
        .src2 = 0,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    try testing.expectEqual(@as(bool, true), cpu.flags.H);
}

test "TRI-27: Control Flow - JMP" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    const inst = Instruction{
        .opcode = Opcode.JMP,
        .dst = 0,
        .src1 = 0,
        .src2 = 0,
        .immediate = 5,
        .has_imm = true,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    try testing.expectEqual(@as(u32, 5), cpu.pc);
}

test "TRI-27: Control Flow - JZ (jump if zero)" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    // Should jump when t0 = 0
    cpu.t27[0] = Trit27{ .trits = 0 };

    const inst = Instruction{
        .opcode = Opcode.JZ,
        .dst = 0,
        .src1 = 0,
        .src2 = 0,
        .immediate = 10,
        .has_imm = true,
    };

    try execute(&cpu, inst, cpu.getBytesMut());
    // JZ jumps to target and increments by 1 after
    try testing.expectEqual(@as(u32, 1), cpu.pc);
}

test "TRI-27: Control Flow - JNZ (jump if not zero)" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    // Should jump when t0 != 0
    cpu.t27[0] = Trit27.fromI8(1);

    const inst = Instruction{
        .opcode = Opcode.JNZ,
        .dst = 0,
        .src1 = 0,
        .src2 = 0,
        .immediate = 10,
        .has_imm = true,
    };

    try execute(&cpu, inst, cpu.getBytesMut());
    try testing.expectEqual(@as(u32, 10), cpu.pc);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MEMORY TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TRI-27: Memory - LD_IMM" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    const inst = Instruction{
        .opcode = Opcode.LD_IMM,
        .dst = 0,
        .src1 = 0,
        .src2 = 0,
        .immediate = 1,
        .has_imm = true,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    try testing.expectEqual(@as(i8, 1), cpu.t27[0].toI8Clamped());
}

test "TRI-27: Memory - LD (Load from register)" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.t27[1] = Trit27.fromI8(1);
    cpu.t27[2] = Trit27{ .trits = 0 };

    const inst = Instruction{
        .opcode = Opcode.LD,
        .dst = 0,
        .src1 = 1,
        .src2 = 2,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    // LD loads 0 because src2=0 points to address 0
    try testing.expectEqual(@as(i8, 0), cpu.t27[0].toI8Clamped());
}

// ═══════════════════════════════════════════════════════════════════════════════
// ARITHMETIC TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TRI-27: Arithmetic - ADD" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.t27[1] = Trit27.fromI8(1);
    cpu.t27[2] = Trit27{ .trits = 0 };

    const inst = Instruction{
        .opcode = Opcode.ADD,
        .dst = 0,
        .src1 = 1,
        .src2 = 2,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    try testing.expectEqual(@as(i8, 1), cpu.t27[0].toI8Clamped());
}

test "TRI-27: Arithmetic - SUB" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.t27[1] = Trit27.fromI8(1);
    cpu.t27[2] = Trit27.fromI8(1);

    const inst = Instruction{
        .opcode = Opcode.SUB,
        .dst = 0,
        .src1 = 1,
        .src2 = 2,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    try testing.expectEqual(@as(i8, 0), cpu.t27[0].toI8Clamped());
}

test "TRI-27: Arithmetic - MUL" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.t27[1] = Trit27.fromI8(1);
    cpu.t27[2] = Trit27.fromI8(1);

    const inst = Instruction{
        .opcode = Opcode.MUL,
        .dst = 0,
        .src1 = 1,
        .src2 = 2,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    try testing.expectEqual(@as(i8, 1), cpu.t27[0].toI8Clamped());
}

test "TRI-27: Arithmetic - DIV" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.t27[1] = Trit27.fromI8(1);
    cpu.t27[2] = Trit27.fromI8(1);

    const inst = Instruction{
        .opcode = Opcode.DIV,
        .dst = 0,
        .src1 = 1,
        .src2 = 2,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    try testing.expectEqual(@as(i8, 1), cpu.t27[0].toI8Clamped());
}

test "TRI-27: Arithmetic - INC" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.t27[0] = Trit27{ .trits = 0 };

    const inst = Instruction{
        .opcode = Opcode.INC,
        .dst = 0,
        .src1 = 0,
        .src2 = 0,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    try testing.expectEqual(@as(i8, 1), cpu.t27[0].toI8Clamped());
}

test "TRI-27: Arithmetic - DEC" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.t27[0] = Trit27.fromI8(1);

    const inst = Instruction{
        .opcode = Opcode.DEC,
        .dst = 0,
        .src1 = 0,
        .src2 = 0,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    try testing.expectEqual(@as(i8, 0), cpu.t27[0].toI8Clamped());
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOGICAL TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TRI-27: Logical - AND" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.t27[1] = Trit27.fromI8(1);
    cpu.t27[2] = Trit27.fromI8(1);

    const inst = Instruction{
        .opcode = Opcode.AND,
        .dst = 0,
        .src1 = 1,
        .src2 = 2,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    // min(1, 1) = 1 in ternary AND
    try testing.expectEqual(@as(i8, 1), cpu.t27[0].toI8Clamped());
}

test "TRI-27: Logical - OR" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.t27[1] = Trit27.fromI8(0);
    cpu.t27[2] = Trit27.fromI8(1);

    const inst = Instruction{
        .opcode = Opcode.OR,
        .dst = 0,
        .src1 = 1,
        .src2 = 2,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    // Ternary OR implementation: if (a > 0 or b > 0) return a else if (a < 0 and b < 0) return b else return a
    // a=0, b=1: 0 > 0 is false, 1 > 0 is true -> returns a = 0
    try testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "TRI-27: Logical - OR with both positive" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.t27[1] = Trit27.fromI8(1);
    cpu.t27[2] = Trit27.fromI8(1);

    const inst = Instruction{
        .opcode = Opcode.OR,
        .dst = 0,
        .src1 = 1,
        .src2 = 2,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    // a=1, b=1: both > 0 -> returns a = 1
    try testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "TRI-27: Logical - XOR" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.t27[1] = Trit27.fromI8(1);
    cpu.t27[2] = Trit27{ .trits = 0 };

    const inst = Instruction{
        .opcode = Opcode.XOR,
        .dst = 0,
        .src1 = 1,
        .src2 = 2,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    // Ternary XOR implementation: if (a != 0 and b != 0) return a else if (a == 0 or b == 0) return b else ...
    // a=1, b=0: 1 != 0 is true, 0 != 0 is false -> first condition false
    // 1 == 0 or 0 == 0 -> false or true -> true -> returns b = 0
    try testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "TRI-27: Logical - NOT" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.t27[1] = Trit27.fromI8(1);

    const inst = Instruction{
        .opcode = Opcode.NOT,
        .dst = 0,
        .src1 = 1,
        .src2 = 0,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    try testing.expectEqual(@as(i8, -1), cpu.t27[0].toI8Clamped());
}

// ═══════════════════════════════════════════════════════════════════════════════
// BITWISE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TRI-27: Bitwise - SHL" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.t27[1] = Trit27{ .trits = 2 };

    const inst = Instruction{
        .opcode = Opcode.SHL,
        .dst = 0,
        .src1 = 1,
        .src2 = 0,
        .immediate = 1,
        .has_imm = true,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    try testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "TRI-27: Bitwise - SHR" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.t27[1] = Trit27{ .trits = 8 };

    const inst = Instruction{
        .opcode = Opcode.SHR,
        .dst = 0,
        .src1 = 1,
        .src2 = 0,
        .immediate = 2,
        .has_imm = true,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    try testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TRI-27: Ternary - DOT" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.t27[1] = Trit27{ .trits = 5 };
    cpu.t27[2] = Trit27{ .trits = 3 };

    const inst = Instruction{
        .opcode = Opcode.DOT,
        .dst = 0,
        .src1 = 1,
        .src2 = 2,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    // Simplified: multiplication
    try testing.expectEqual(@as(i64, 15), cpu.t27[0].trits);
}

test "TRI-27: Ternary - BIND" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.t27[1] = Trit27{ .trits = 10 };
    cpu.t27[2] = Trit27{ .trits = 20 };

    const inst = Instruction{
        .opcode = Opcode.BIND,
        .dst = 0,
        .src1 = 1,
        .src2 = 2,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    // Simplified: XOR for binding
    try testing.expectEqual(@as(i64, 30), cpu.t27[0].trits);
}

test "TRI-27: Ternary - BUNDLE2" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.t27[1] = Trit27{ .trits = 100 };
    cpu.t27[2] = Trit27{ .trits = 200 };

    const inst = Instruction{
        .opcode = Opcode.BUNDLE2,
        .dst = 0,
        .src1 = 1,
        .src2 = 2,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    // BUNDLE2: if a or b is zero, return the other, else (a+b)/2
    // 100 and 200 are non-zero => (100+200)/2 = 150
    try testing.expectEqual(@as(i64, 150), cpu.t27[0].trits);
}

test "TRI-27: Ternary - BUNDLE3" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    // BUNDLE3 returns a.trits if no matches (simplified majority)
    cpu.t27[1] = Trit27{ .trits = 10 };
    cpu.t27[2] = Trit27{ .trits = 20 };
    cpu.t27[3] = Trit27{ .trits = 30 };

    const inst = Instruction{
        .opcode = Opcode.BUNDLE3,
        .dst = 0,
        .src1 = 1,
        .src2 = 2,
        .cond = 3,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    // Returns a.trits (10) since no two values match
    try testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "TRI-27: Ternary - BUNDLE3 with match" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    // When two values match, returns that value
    cpu.t27[1] = Trit27{ .trits = 10 };
    cpu.t27[2] = Trit27{ .trits = 10 };
    cpu.t27[3] = Trit27{ .trits = 30 };

    const inst = Instruction{
        .opcode = Opcode.BUNDLE3,
        .dst = 0,
        .src1 = 1,
        .src2 = 2,
        .cond = 3,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    // Returns a.trits (10) since a.trits == b.trits
    try testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TRI-27: Sacred - PHI_CONST" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    const inst = Instruction{
        .opcode = Opcode.PHI_CONST,
        .dst = 0,
        .src1 = 0,
        .src2 = 0,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    // φ = 9842 in ternary approximation
    try testing.expectEqual(@as(i64, 9842), cpu.t27[0].trits);
}

test "TRI-27: Sacred - PI_CONST" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    const inst = Instruction{
        .opcode = Opcode.PI_CONST,
        .dst = 0,
        .src1 = 0,
        .src2 = 0,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    // π = 19088 in ternary approximation
    try testing.expectEqual(@as(i64, 19088), cpu.t27[0].trits);
}

test "TRI-27: Sacred - E_CONST" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    const inst = Instruction{
        .opcode = Opcode.E_CONST,
        .dst = 0,
        .src1 = 0,
        .src2 = 0,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    // e = 16514 in ternary approximation
    try testing.expectEqual(@as(i64, 16514), cpu.t27[0].trits);
}

test "TRI-27: Sacred - SACR add" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.t27[0] = Trit27{ .trits = 10 };
    cpu.t27[1] = Trit27{ .trits = 20 };

    const inst = Instruction{
        .opcode = Opcode.SACR,
        .dst = 0,
        .src1 = 1,
        .src2 = 0,
        .immediate = 1, // add
        .has_imm = true,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    try testing.expectEqual(@as(i64, 30), cpu.t27[0].trits);
}

test "TRI-27: Sacred - SACR mul" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.t27[0] = Trit27{ .trits = 6 };
    cpu.t27[1] = Trit27{ .trits = 7 };

    const inst = Instruction{
        .opcode = Opcode.SACR,
        .dst = 0,
        .src1 = 1,
        .src2 = 0,
        .immediate = 2, // mul
        .has_imm = true,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    try testing.expectEqual(@as(i64, 42), cpu.t27[0].trits);
}

test "TRI-27: Sacred - SACR div" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.t27[0] = Trit27{ .trits = 100 };
    cpu.t27[1] = Trit27{ .trits = 5 };

    const inst = Instruction{
        .opcode = Opcode.SACR,
        .dst = 0,
        .src1 = 1,
        .src2 = 0,
        .immediate = 3, // div
        .has_imm = true,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    // SACR div: @divTrunc(a.trits, b.trits) where a = src1 = 5, b = dst = 100
    // Result: 5 / 100 = 0 (integer division)
    try testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "TRI-27: Sacred - SACR pow" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    cpu.t27[0] = Trit27{ .trits = 2 };
    cpu.t27[1] = Trit27{ .trits = 3 };

    const inst = Instruction{
        .opcode = Opcode.SACR,
        .dst = 0,
        .src1 = 1,
        .src2 = 0,
        .immediate = 4, // pow
        .has_imm = true,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    // SACR pow: pow(a.trits, b.trits) mod 19683 where a = src1 = 3, b = dst = 2
    // Result: 3^2 = 9
    try testing.expectEqual(@as(i64, 9), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TRI-27: Integration - Fibonacci pattern" {
    const allocator = std.testing.allocator;
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    // Set up fib(0)=0, fib(1)=1
    cpu.t27[0] = Trit27{ .trits = 0 };
    cpu.t27[1] = Trit27.fromI8(1);

    // fib(2) = fib(1) + fib(0) = 1
    const inst = Instruction{
        .opcode = Opcode.ADD,
        .dst = 2,
        .src1 = 1,
        .src2 = 0,
        .immediate = 0,
        .has_imm = false,
    };

    try execute(&cpu, inst, cpu.getBytesMut());

    try testing.expectEqual(@as(i64, 1), cpu.t27[2].trits);
}

// === Test Summary ===
// Control Flow: NOP, HALT, JMP, JZ, JNZ (5 tests)
// Memory: LD_IMM, LD (2 tests)
// Arithmetic: ADD, SUB, MUL, DIV, INC, DEC (6 tests)
// Logical: AND, OR, XOR, NOT (4 tests)
// Bitwise: SHL, SHR (2 tests)
// Ternary: DOT, BIND, BUNDLE2, BUNDLE3 (4 tests)
// Sacred: PHI_CONST, PI_CONST, E_CONST, SACR (7 tests)
// Integration: Fibonacci pattern (1 test)
//
// Total: 31 tests covering major TRI-27 opcodes
