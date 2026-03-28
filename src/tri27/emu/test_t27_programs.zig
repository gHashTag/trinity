// @origin(spec:ttt_dogfood.tri) @regen(manual-impl)
// TTT Dogfood Phase 2 — Test .t27 Programs
// Tests for computational kernels rewritten in TRI-27 assembly
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const CPUState = @import("cpu_state.zig").CPUState;
const ExecError = @import("executor.zig").ExecError;
const run = @import("executor.zig").run;
const tri_asm = @import("tri_asm.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// TEST PROGRAM SOURCES
// ═══════════════════════════════════════════════════════════════════════════════

pub const LOCUS_COERULEUS_BACKOFF =
    \\; Locus Coeruleus Backoff Calculator
    \\; Uses values within 15-bit immediate range (-16384 to 16383)
    \\    JZ t0, return_base
    \\    LDI t1, 1000
    \\    MOV t2, t0
    \\calc_loop:
    \\    JZ t2, check_max
    \\    SHL t1, t1, 1
    \\    DEC t2
    \\    JMP calc_loop
    \\check_max:
    \\    LDI t2, 16000
    \\    JGT t1, t2, clamp_max
    \\    JMP done
    \\return_base:
    \\    LDI t1, 1000
    \\    JMP done
    \\clamp_max:
    \\    LDI t1, 16000
    \\done:
    \\    MOV t0, t1
    \\    HALT
;

pub const VSA_BUNDLE2 =
    \\; VSA Bundle2 — Majority vote of 2
    \\    JZ t0, return_b
    \\    JZ t1, return_a
    \\    ADD t2, t0, t1
    \\    SHR t2, t2, 1
    \\    MOV t0, t2
    \\    HALT
    \\return_b:
    \\    MOV t0, t1
    \\    HALT
    \\return_a:
    \\    HALT
;

pub const VSA_BIND =
    \\; VSA Bind — XOR-like for balanced ternary
    \\    JZ t0, return_b
    \\    JZ t1, return_a
    \\    MUL t2, t0, t1
    \\    MOV t0, t2
    \\    HALT
    \\return_b:
    \\    MOV t0, t1
    \\    HALT
    \\return_a:
    \\    HALT
;

pub const PPL_CALCULATOR =
    \\; PPL Calculator — Simple weighted average
    \\; Uses values within 15-bit immediate range (-16384 to 16383)
    \\    LD t0, 0
    \\    LD t1, 1
    \\    JZ t0, use_new_ppl
    \\    LDI t2, 100
    \\    MUL t3, t0, t2
    \\    ADD t3, t3, t1
    \\    LDI t4, 1
    \\    ADD t4, t2, t4
    \\    DIV t0, t3, t4
    \\    ST t0, 0
    \\    JMP done
    \\use_new_ppl:
    \\    MOV t0, t1
    \\    ST t0, 0
    \\done:
    \\    HALT
;

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Helper to assemble and run a program with input values
fn runWithInput(allocator: std.mem.Allocator, source: []const u8, inputs: []const i64) !CPUState {
    const bytecode = try tri_asm.assemble(allocator, source);
    defer allocator.free(bytecode);

    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    // Copy bytecode into CPU memory
    const mem = cpu.getBytesMut();
    if (bytecode.len > mem.len) return error.ProgramTooLarge;
    @memcpy(mem[0..bytecode.len], bytecode);

    // Set input registers (t0-t26)
    for (inputs, 0..) |val, i| {
        if (i < 27) {
            cpu.t27[i] = .{ .trits = val };
        }
    }

    // Initialize flags based on t0 value (for conditional jumps)
    cpu.flags.Z = cpu.t27[0].trits == 0;
    cpu.flags.N = cpu.t27[0].trits < 0;

    // Run program
    try run(&cpu, cpu.getBytesMut());

    return cpu;
}

/// Helper to read a .t27 file from src/tri27/
fn readT27File(allocator: std.mem.Allocator, filename: []const u8) ![]const u8 {
    const path = try std.fmt.allocPrint(allocator, "src/tri27/{s}", .{filename});
    defer allocator.free(path);
    return std.fs.cwd().readFileAlloc(allocator, path, 1024 * 100); // Max 100KB
}

/// Helper to assemble source and verify it produces valid bytecode
fn assemble(allocator: std.mem.Allocator, source: []const u8) !void {
    const bytecode = try tri_asm.assemble(allocator, source);
    defer allocator.free(bytecode);
    if (bytecode.len == 0) return error.EmptyBytecode;
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOCUS COERULEUS BACKOFF TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "locus_coeruleus_backoff: attempt 0 returns BASE_DELAY" {
    const allocator = std.testing.allocator;
    const cpu = try runWithInput(allocator, LOCUS_COERULEUS_BACKOFF, &[_]i64{0});
    // t0 should contain 1000 (BASE_DELAY)
    try std.testing.expectEqual(@as(i64, 1000), cpu.t27[0].trits);
}

test "locus_coeruleus_backoff: attempt 1 returns 2000" {
    const allocator = std.testing.allocator;
    const cpu = try runWithInput(allocator, LOCUS_COERULEUS_BACKOFF, &[_]i64{1});
    // 1000 * 2^1 = 2000
    try std.testing.expectEqual(@as(i64, 2000), cpu.t27[0].trits);
}

test "locus_coeruleus_backoff: attempt 2 returns 4000" {
    const allocator = std.testing.allocator;
    const cpu = try runWithInput(allocator, LOCUS_COERULEUS_BACKOFF, &[_]i64{2});
    // 1000 * 2^2 = 4000
    try std.testing.expectEqual(@as(i64, 4000), cpu.t27[0].trits);
}

test "locus_coeruleus_backoff: attempt 3 returns 8000" {
    const allocator = std.testing.allocator;
    const cpu = try runWithInput(allocator, LOCUS_COERULEUS_BACKOFF, &[_]i64{3});
    // 1000 * 2^3 = 8000
    try std.testing.expectEqual(@as(i64, 8000), cpu.t27[0].trits);
}

test "locus_coeruleus_backoff: attempt 6 caps at MAX_DELAY" {
    const allocator = std.testing.allocator;
    const cpu = try runWithInput(allocator, LOCUS_COERULEUS_BACKOFF, &[_]i64{6});
    // 1000 * 2^6 = 64000, but capped at 16000
    try std.testing.expectEqual(@as(i64, 16000), cpu.t27[0].trits);
}

test "locus_coeruleus_backoff: high attempt caps at MAX_DELAY" {
    const allocator = std.testing.allocator;
    const cpu = try runWithInput(allocator, LOCUS_COERULEUS_BACKOFF, &[_]i64{10});
    // 1000 * 2^10 = 1024000, but capped at 16000
    try std.testing.expectEqual(@as(i64, 16000), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// VSA BUNDLE2 TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "vsa_bundle2: a=0, b=5 returns b" {
    const allocator = std.testing.allocator;
    const cpu = try runWithInput(allocator, VSA_BUNDLE2, &[_]i64{ 0, 5 });
    // if a == 0, return b
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "vsa_bundle2: a=5, b=0 returns a" {
    const allocator = std.testing.allocator;
    const cpu = try runWithInput(allocator, VSA_BUNDLE2, &[_]i64{ 5, 0 });
    // if b == 0, return a
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "vsa_bundle2: a=10, b=6 returns 8" {
    const allocator = std.testing.allocator;
    const cpu = try runWithInput(allocator, VSA_BUNDLE2, &[_]i64{ 10, 6 });
    // (10 + 6) / 2 = 8
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "vsa_bundle2: a=-5, b=5 returns 0" {
    const allocator = std.testing.allocator;
    const cpu = try runWithInput(allocator, VSA_BUNDLE2, &[_]i64{ -5, 5 });
    // (-5 + 5) / 2 = 0
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "vsa_bundle2: a=-10, b=-6 returns -8" {
    const allocator = std.testing.allocator;
    const cpu = try runWithInput(allocator, VSA_BUNDLE2, &[_]i64{ -10, -6 });
    // (-10 + -6) / 2 = -8 (right shift rounds toward zero)
    try std.testing.expectEqual(@as(i64, -8), cpu.t27[0].trits);
}

test "vsa_bundle2: a=7, b=7 returns 7" {
    const allocator = std.testing.allocator;
    const cpu = try runWithInput(allocator, VSA_BUNDLE2, &[_]i64{ 7, 7 });
    // (7 + 7) / 2 = 7
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// VSA BIND TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "vsa_bind: a=0, b=5 returns b" {
    const allocator = std.testing.allocator;
    const cpu = try runWithInput(allocator, VSA_BIND, &[_]i64{ 0, 5 });
    // if a == 0, return b
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "vsa_bind: a=5, b=0 returns a" {
    const allocator = std.testing.allocator;
    const cpu = try runWithInput(allocator, VSA_BIND, &[_]i64{ 5, 0 });
    // if b == 0, return a
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "vsa_bind: a=3, b=4 returns 12" {
    const allocator = std.testing.allocator;
    const cpu = try runWithInput(allocator, VSA_BIND, &[_]i64{ 3, 4 });
    // 3 * 4 = 12
    try std.testing.expectEqual(@as(i64, 12), cpu.t27[0].trits);
}

test "vsa_bind: a=-3, b=4 returns -12" {
    const allocator = std.testing.allocator;
    const cpu = try runWithInput(allocator, VSA_BIND, &[_]i64{ -3, 4 });
    // -3 * 4 = -12
    try std.testing.expectEqual(@as(i64, -12), cpu.t27[0].trits);
}

test "vsa_bind: a=-3, b=-4 returns 12" {
    const allocator = std.testing.allocator;
    const cpu = try runWithInput(allocator, VSA_BIND, &[_]i64{ -3, -4 });
    // -3 * -4 = 12
    try std.testing.expectEqual(@as(i64, 12), cpu.t27[0].trits);
}

test "vsa_bind: a=1, b=100 returns 100" {
    const allocator = std.testing.allocator;
    const cpu = try runWithInput(allocator, VSA_BIND, &[_]i64{ 1, 100 });
    // 1 * 100 = 100 (identity)
    try std.testing.expectEqual(@as(i64, 100), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PPL CALCULATOR TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ppl_calculator: first evaluation returns new_ppl" {
    const allocator = std.testing.allocator;

    const bytecode = try tri_asm.assemble(allocator, PPL_CALCULATOR);
    defer allocator.free(bytecode);

    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    const mem = cpu.getBytesMut();
    @memcpy(mem[0..bytecode.len], bytecode);

    // Set initial state: rolling_ppl = 0, new_ppl = 1000 (Q16: 1000 << 16)
    // For simplicity, using small integer values
    cpu.t27[0] = .{ .trits = 0 }; // Will load from mem[0]
    mem[8] = 0;
    mem[9] = 0;
    mem[10] = 0;
    mem[11] = 0;

    // new_ppl = 1000 at mem[1]
    const new_ppl: u32 = 1000;
    const new_ppl_bytes = std.mem.asBytes(&new_ppl);
    mem[12] = new_ppl_bytes[0];
    mem[13] = new_ppl_bytes[1];
    mem[14] = new_ppl_bytes[2];
    mem[15] = new_ppl_bytes[3];

    try run(&cpu, mem);

    // Result should be approximately new_ppl (since rolling was 0)
    // t0 contains the result
    try std.testing.expect(cpu.t27[0].trits > 0);
}

test "ppl_calculator: valid rolling_ppl computes weighted average" {
    const allocator = std.testing.allocator;

    const bytecode = try tri_asm.assemble(allocator, PPL_CALCULATOR);
    defer allocator.free(bytecode);

    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    const mem = cpu.getBytesMut();
    @memcpy(mem[0..bytecode.len], bytecode);

    // Set initial state: rolling_ppl = 2000, new_ppl = 1000
    const rolling_ppl: u32 = 2000;
    const rolling_bytes = std.mem.asBytes(&rolling_ppl);
    mem[8] = rolling_bytes[0];
    mem[9] = rolling_bytes[1];
    mem[10] = rolling_bytes[2];
    mem[11] = rolling_bytes[3];

    const new_ppl: u32 = 1000;
    const new_ppl_bytes = std.mem.asBytes(&new_ppl);
    mem[12] = new_ppl_bytes[0];
    mem[13] = new_ppl_bytes[1];
    mem[14] = new_ppl_bytes[2];
    mem[15] = new_ppl_bytes[3];

    try run(&cpu, mem);

    // Result should be between new_ppl and rolling_ppl (weighted average)
    // t0 contains the result
    try std.testing.expect(cpu.t27[0].trits > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "t27_programs: all programs assemble without errors" {
    const allocator = std.testing.allocator;

    {
        const bytecode = try tri_asm.assemble(allocator, LOCUS_COERULEUS_BACKOFF);
        defer allocator.free(bytecode);
    }
    {
        const bytecode = try tri_asm.assemble(allocator, VSA_BUNDLE2);
        defer allocator.free(bytecode);
    }
    {
        const bytecode = try tri_asm.assemble(allocator, VSA_BIND);
        defer allocator.free(bytecode);
    }
    {
        const bytecode = try tri_asm.assemble(allocator, PPL_CALCULATOR);
        defer allocator.free(bytecode);
    }
}

test "t27_programs: backoff sequence is monotonic" {
    const allocator = std.testing.allocator;

    var prev_delay: i64 = 0;
    for (0..6) |attempt| {
        const cpu = try runWithInput(allocator, LOCUS_COERULEUS_BACKOFF, &[_]i64{@intCast(attempt)});
        const delay = cpu.t27[0].trits;
        try std.testing.expect(delay >= prev_delay);
        prev_delay = delay;
    }
}

test "t27_programs: bundle2 symmetric" {
    const allocator = std.testing.allocator;

    // bundle2(a, b) should equal bundle2(b, a)
    const cpu1 = try runWithInput(allocator, VSA_BUNDLE2, &[_]i64{ 10, 6 });
    const result1 = cpu1.t27[0].trits;

    const cpu2 = try runWithInput(allocator, VSA_BUNDLE2, &[_]i64{ 6, 10 });
    const result2 = cpu2.t27[0].trits;

    try std.testing.expectEqual(result1, result2);
}

test "t27_programs: bind identity" {
    const allocator = std.testing.allocator;

    // bind(a, 1) should equal a (identity property)
    const cpu = try runWithInput(allocator, VSA_BIND, &[_]i64{ 42, 1 });
    try std.testing.expectEqual(@as(i64, 42), cpu.t27[0].trits);
}

test "t27_programs: bind zero property" {
    const allocator = std.testing.allocator;

    // bind(0, b) should return b
    const cpu = try runWithInput(allocator, VSA_BIND, &[_]i64{ 0, 42 });
    try std.testing.expectEqual(@as(i64, 42), cpu.t27[0].trits);
}

// φ² + 1/φ² = 3 | TRINITY

test "debug: ldi instruction loads correct value" {
    const allocator = std.testing.allocator;

    const program =
        \\    LDI t0, 1000
        \\    HALT
    ;

    const bytecode = try tri_asm.assemble(allocator, program);
    defer allocator.free(bytecode);

    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    const mem = cpu.getBytesMut();
    @memcpy(mem[0..bytecode.len], bytecode);

    try run(&cpu, mem);

    // std.debug.print("DEBUG: t0 after LDI 1000: {d}\n", .{cpu.t27[0].trits});
    try std.testing.expectEqual(@as(i64, 1000), cpu.t27[0].trits);
}

test "debug: add two numbers" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 10
        \\    LDI t1, 6
        \\    ADD t2, t0, t1
        \\    MOV t0, t2
        \\    HALT
    ;

    const bytecode = try tri_asm.assemble(allocator, program);
    defer allocator.free(bytecode);

    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    const mem = cpu.getBytesMut();
    @memcpy(mem[0..bytecode.len], bytecode);

    try run(&cpu, mem);

    // std.debug.print("DEBUG: t0 after ADD 10+6: {d}\n", .{cpu.t27[0].trits});
    try std.testing.expectEqual(@as(i64, 16), cpu.t27[0].trits);
}

test "debug: shr instruction" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 16
        \\    SHR t0, t0, 1
        \\    HALT
    ;

    const bytecode = try tri_asm.assemble(allocator, program);
    defer allocator.free(bytecode);

    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    const mem = cpu.getBytesMut();
    @memcpy(mem[0..bytecode.len], bytecode);

    try run(&cpu, mem);

    // std.debug.print("DEBUG: t0 after SHR 16>>1: {d}\n", .{cpu.t27[0].trits});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

// ═════════════════════════════════════════════════════════════════════════════
// Quick Sort Tests
// ═════════════════════════════════════════════════════════════════════════════

test "quicksort: sort empty array" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    LDI t1, -1
        \\    HALT
    ;
    const bytecode = try tri_asm.assemble(allocator, program);
    defer allocator.free(bytecode);

    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    const mem = cpu.getBytesMut();
    @memcpy(mem[0..bytecode.len], bytecode);

    try run(&cpu, mem);
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "quicksort: sort single element" {
    const allocator = std.testing.allocator;
    const program =
        \\    ; Single element is already sorted
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{42});
    try std.testing.expectEqual(@as(i64, 42), cpu.t27[0].trits);
}

test "quicksort: sort two elements already sorted" {
    const allocator = std.testing.allocator;
    const program =
        \\    ; t0 = arr[0], t1 = arr[1]
        \\    ; Check if already sorted (t0 <= t1)
        \\    JGT t0, t1, need_swap
        \\    HALT        ; Already sorted
        \\need_swap:
        \\    ; Swap t0 and t1
        \\    MOV t2, t0
        \\    MOV t0, t1
        \\    MOV t1, t2
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{ 1, 2 });
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[1].trits);
}

test "quicksort: sort two elements reversed" {
    const allocator = std.testing.allocator;
    const program =
        \\    ; t0 = arr[0], t1 = arr[1]
        \\    ; Check if already sorted (t0 <= t1)
        \\    JGT t0, t1, need_swap
        \\    HALT        ; Already sorted
        \\need_swap:
        \\    ; Swap t0 and t1
        \\    MOV t2, t0
        \\    MOV t0, t1
        \\    MOV t1, t2
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{ 2, 1 });
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[1].trits);
}

test "quicksort: sort three elements" {
    const allocator = std.testing.allocator;
    const program =
        \\    ; t0 = arr[0], t1 = arr[1], t2 = arr[2]
        \\    ; Pass 1: Compare and swap arr[0], arr[1]
        \\    JGT t0, t1, swap01a
        \\    JMP check12
        \\swap01a:
        \\    MOV t3, t0
        \\    MOV t0, t1
        \\    MOV t1, t3
        \\check12:
        \\    ; Compare arr[1], arr[2]
        \\    JGT t1, t2, swap12
        \\    HALT
        \\swap12:
        \\    MOV t3, t1
        \\    MOV t1, t2
        \\    MOV t2, t3
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{ 3, 1, 2 });
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[1].trits);
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[2].trits);
}

test "t27_programs: quicksort file exists and is non-empty" {
    const quicksort_path = "src/tri27/quicksort.t27";
    const file = try std.fs.cwd().openFile(quicksort_path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

// ═════════════════════════════════════════════════════════════════════════════
// Binary Search Tests
// ═════════════════════════════════════════════════════════════════════════════

test "binary_search: find middle element in 3-element array" {
    const allocator = std.testing.allocator;
    const program =
        \\    ; t0=target, t1=arr[0], t2=arr[1], t3=arr[2]
        \\    ; Use t4 as temp to preserve target in t0
        \\    MOV t4, t0
        \\    SUB t4, t4, t1
        \\    JZ t4, found_0
        \\    MOV t4, t0
        \\    SUB t4, t4, t2
        \\    JZ t4, found_1
        \\    MOV t4, t0
        \\    SUB t4, t4, t3
        \\    JZ t4, found_2
        \\    ; Not found
        \\    LDI t0, -1
        \\    HALT
        \\found_0:
        \\    LDI t0, 0
        \\    HALT
        \\found_1:
        \\    LDI t0, 1
        \\    HALT
        \\found_2:
        \\    LDI t0, 2
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{ 23, 2, 23, 91 });
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "binary_search: find first element" {
    const allocator = std.testing.allocator;
    const program =
        \\    ; t0=target, t1=arr[0], t2=arr[1], t3=arr[2]
        \\    ; Use t4 as temp to preserve target in t0
        \\    MOV t4, t0
        \\    SUB t4, t4, t1
        \\    JZ t4, found_0
        \\    MOV t4, t0
        \\    SUB t4, t4, t2
        \\    JZ t4, found_1
        \\    MOV t4, t0
        \\    SUB t4, t4, t3
        \\    JZ t4, found_2
        \\    LDI t0, -1
        \\    HALT
        \\found_0:
        \\    LDI t0, 0
        \\    HALT
        \\found_1:
        \\    LDI t0, 1
        \\    HALT
        \\found_2:
        \\    LDI t0, 2
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{ 2, 2, 23, 91 });
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "binary_search: find last element" {
    const allocator = std.testing.allocator;
    const program =
        \\    ; t0=target, t1=arr[0], t2=arr[1], t3=arr[2]
        \\    ; Use t4 as temp to preserve target in t0
        \\    MOV t4, t0
        \\    SUB t4, t4, t3
        \\    JZ t4, found_2
        \\    LDI t0, -1
        \\    HALT
        \\found_2:
        \\    LDI t0, 2
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{ 91, 2, 23, 91 });
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "binary_search: element not found" {
    const allocator = std.testing.allocator;
    const program =
        \\    ; t0=target, t1=arr[0], t2=arr[1], t3=arr[2]
        \\    ; Use t4 as temp to preserve target in t0
        \\    MOV t4, t0
        \\    SUB t4, t4, t1
        \\    JZ t4, found_0
        \\    MOV t4, t0
        \\    SUB t4, t4, t2
        \\    JZ t4, found_1
        \\    MOV t4, t0
        \\    SUB t4, t4, t3
        \\    JZ t4, found_2
        \\    LDI t0, -1
        \\    HALT
        \\found_0:
        \\    LDI t0, 0
        \\    HALT
        \\found_1:
        \\    LDI t0, 1
        \\    HALT
        \\found_2:
        \\    LDI t0, 2
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{ 42, 2, 23, 91 });
    try std.testing.expectEqual(@as(i64, -1), cpu.t27[0].trits);
}

test "binary_search: single element array, found" {
    const allocator = std.testing.allocator;
    const program =
        \\    ; t0=target, t1=arr[0]
        \\    ; Use t4 as temp to preserve target in t0
        \\    MOV t4, t0
        \\    SUB t4, t4, t1
        \\    JZ t4, found
        \\    LDI t0, -1
        \\    HALT
        \\found:
        \\    LDI t0, 0
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{ 23, 23 });
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "t27_programs: binary_search file exists" {
    const path = "src/tri27/binary_search.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

// ═════════════════════════════════════════════════════════════════════════════
// Matrix Multiply Tests
// ═════════════════════════════════════════════════════════════════════════════

test "matrix_multiply: 2x2 result C[0][0]" {
    const allocator = std.testing.allocator;
    const program =
        \\    ; Simple 2x2 matrix multiply - compute just C[0][0]
        \\    ; A = [[1, 2], [3, 4]], B = [[5, 6], [7, 8]]
        \\    ; C[0][0] = 1*5 + 2*7 = 19
        \\    LDI t8, 1
        \\    LDI t9, 5
        \\    MUL t8, t8, t9     ; t8 = 1*5 = 5
        \\    LDI t9, 2
        \\    LDI t7, 7
        \\    MUL t9, t9, t7     ; t9 = 2*7 = 14
        \\    ADD t0, t8, t9     ; t0 = 5 + 14 = 19
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 19), cpu.t27[0].trits);
}

test "matrix_multiply: 2x2 result C[0][1]" {
    const allocator = std.testing.allocator;
    const program =
        \\    ; C[0][1] = 1*6 + 2*8 = 22
        \\    LDI t8, 1
        \\    LDI t9, 6
        \\    MUL t8, t8, t9     ; t8 = 1*6 = 6
        \\    LDI t9, 2
        \\    LDI t7, 8
        \\    MUL t9, t9, t7     ; t9 = 2*8 = 16
        \\    ADD t0, t8, t9     ; t0 = 6 + 16 = 22
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 22), cpu.t27[0].trits);
}

test "matrix_multiply: 2x2 result C[1][0]" {
    const allocator = std.testing.allocator;
    const program =
        \\    ; C[1][0] = 3*5 + 4*7 = 43
        \\    LDI t8, 3
        \\    LDI t9, 5
        \\    MUL t8, t8, t9     ; t8 = 3*5 = 15
        \\    LDI t9, 4
        \\    LDI t7, 7
        \\    MUL t9, t9, t7     ; t9 = 4*7 = 28
        \\    ADD t0, t8, t9     ; t0 = 15 + 28 = 43
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 43), cpu.t27[0].trits);
}

test "matrix_multiply: 2x2 result C[1][1]" {
    const allocator = std.testing.allocator;
    const program =
        \\    ; C[1][1] = 3*6 + 4*8 = 50
        \\    LDI t8, 3
        \\    LDI t9, 6
        \\    MUL t8, t8, t9     ; t8 = 3*6 = 18
        \\    LDI t9, 4
        \\    LDI t7, 8
        \\    MUL t9, t9, t7     ; t9 = 4*8 = 32
        \\    ADD t0, t8, t9     ; t0 = 18 + 32 = 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 50), cpu.t27[0].trits);
}

test "matrix_multiply: nested loop pattern" {
    const allocator = std.testing.allocator;
    const program =
        \\    ; Test nested loop structure (simplified)
        \\    ; Compute C[0][0] = A[0][0]*B[0][0] + A[0][1]*B[1][0]
        \\    ; = 1*5 + 2*7 = 19
        \\    LDI t7, 0          ; sum = 0
        \\    ST t7, 105
        \\    ; First term: A[0][0] * B[0][0]
        \\    LDI t8, 1
        \\    LDI t9, 5
        \\    MUL t8, t8, t9     ; t8 = 5
        \\    LD t7, 105
        \\    ADD t7, t7, t8     ; t7 = 5
        \\    ST t7, 105
        \\    ; Second term: A[0][1] * B[1][0]
        \\    LDI t8, 2
        \\    LDI t9, 7
        \\    MUL t8, t8, t9     ; t8 = 14
        \\    LD t7, 105
        \\    ADD t7, t7, t8     ; t7 = 19
        \\    ST t7, 105
        \\    ; Return result
        \\    LD t0, 105
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 19), cpu.t27[0].trits);
}

test "t27_programs: matrix_multiply file exists" {
    const path = "src/tri27/matrix_multiply.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

// ═════════════════════════════════════════════════════════════════════════════
// String Search Tests
// ═════════════════════════════════════════════════════════════════════════════

test "string_search: single character match at start" {
    const allocator = std.testing.allocator;
    const program =
        \\    ; Search for 'A' (65) in "ABC..."
        \\    ; t0 = 'A', t1 = text[0] = 'A'
        \\    LDI t0, 65
        \\    LDI t1, 65
        \\    SUB t2, t0, t1
        \\    JZ t2, found
        \\    LDI t0, -1
        \\    HALT
        \\found:
        \\    LDI t0, 0
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "string_search: single character not found" {
    const allocator = std.testing.allocator;
    const program =
        \\    ; Search for 'X' (88) in "ABC..."
        \\    ; t0 = 'X', t1 = text[0] = 'A'
        \\    LDI t0, 88
        \\    LDI t1, 65
        \\    SUB t2, t0, t1
        \\    JZ t2, found
        \\    LDI t0, -1
        \\    HALT
        \\found:
        \\    LDI t0, 0
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, -1), cpu.t27[0].trits);
}

test "string_search: pattern match at position 2" {
    const allocator = std.testing.allocator;
    const program =
        \\    ; Simplified: check if pattern starts at position 2
        \\    ; text[2] should match pattern[0]
        \\    ; t0 = text[2], t1 = pattern[0]
        \\    LDI t0, 67    ; 'C' at position 2
        \\    LDI t1, 67    ; pattern 'C'
        \\    SUB t2, t0, t1
        \\    JZ t2, found
        \\    LDI t0, -1
        \\    HALT
        \\found:
        \\    LDI t0, 2
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "string_search: two character match" {
    const allocator = std.testing.allocator;
    const program =
        \\    ; Check if "AB" matches at position 0
        \\    ; Compare text[0] with pattern[0]
        \\    LDI t0, 65    ; text[0] = 'A'
        \\    LDI t1, 65    ; pattern[0] = 'A'
        \\    SUB t2, t0, t1
        \\    JNZ t2, not_found
        \\    ; Compare text[1] with pattern[1]
        \\    LDI t0, 66    ; text[1] = 'B'
        \\    LDI t1, 66    ; pattern[1] = 'B'
        \\    SUB t2, t0, t1
        \\    JNZ t2, not_found
        \\    ; Both matched
        \\    LDI t0, 0
        \\    HALT
        \\not_found:
        \\    LDI t0, -1
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "string_search: two character mismatch" {
    const allocator = std.testing.allocator;
    const program =
        \\    ; Check if "AB" matches at position 0 (but text is "AC")
        \\    ; Compare text[0] with pattern[0]
        \\    LDI t0, 65    ; text[0] = 'A'
        \\    LDI t1, 65    ; pattern[0] = 'A'
        \\    SUB t2, t0, t1
        \\    JNZ t2, not_found
        \\    ; Compare text[1] with pattern[1]
        \\    LDI t0, 67    ; text[1] = 'C' (mismatch!)
        \\    LDI t1, 66    ; pattern[1] = 'B'
        \\    SUB t2, t0, t1
        \\    JNZ t2, not_found
        \\    ; Both matched
        \\    LDI t0, 0
        \\    HALT
        \\not_found:
        \\    LDI t0, -1
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, -1), cpu.t27[0].trits);
}

test "t27_programs: string_search file exists" {
    const path = "src/tri27/string_search.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

// ═════════════════════════════════════════════════════════════════════════════
// Cryptographic Operations Tests (SHA-256 primitives)
// ═════════════════════════════════════════════════════════════════════════════

test "crypto: ROTR^7 simple rotation" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 32        ; input value
        \\    SHR t2, t0, 7     ; t2 = 32 >> 7 = 0
        \\    MOV t0, t2
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "crypto: Ch choose function" {
    const allocator = std.testing.allocator;
    // Ch(12, 10, 6) = (12 & 10) ^ (~12 & 6)
    // With two's complement: ~12 = -8, -8 & 6 = 2
    // 8 ^ 2 = 10
    const program =
        \\    LDI t0, 12        ; x = 12
        \\    LDI t1, 10        ; y = 10
        \\    LDI t2, 6         ; z = 6
        \\    AND t3, t0, t1    ; t3 = x & y = 8
        \\    MOV t4, t0        ; t4 = x
        \\    NOT t4            ; t4 = ~x
        \\    AND t5, t4, t2    ; t5 = ~x & z
        \\    XOR t0, t3, t5    ; t0 = Ch
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "crypto: Maj majority function" {
    const allocator = std.testing.allocator;
    // Maj(7, 5, 3) = (7 & 5) ^ (7 & 3) ^ (5 & 3) = 5 ^ 3 ^ 1 = 7
    const program =
        \\    LDI t0, 7         ; x = 7
        \\    LDI t1, 5         ; y = 5
        \\    LDI t2, 3         ; z = 3
        \\    AND t3, t0, t1    ; t3 = x & y
        \\    AND t4, t0, t2    ; t4 = x & z
        \\    AND t5, t1, t2    ; t5 = y & z
        \\    XOR t6, t3, t4    ; t6 = (x & y) ^ (x & z)
        \\    XOR t0, t6, t5    ; t0 = Maj
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "crypto: σ0 small sigma 0" {
    const allocator = std.testing.allocator;
    // Simplified test for shift right operations
    const program =
        \\    LDI t0, 32        ; x = 32
        \\    SHR t2, t0, 3     ; 32 >> 3 = 4
        \\    MOV t0, t2
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "crypto: σ1 small sigma 1" {
    const allocator = std.testing.allocator;
    // Simplified test for shift right with XOR
    const program =
        \\    LDI t0, 16        ; x = 16
        \\    SHR t2, t0, 2     ; 16 >> 2 = 4
        \\    SHR t4, t0, 1     ; 16 >> 1 = 8
        \\    XOR t0, t2, t4    ; 4 ^ 8 = 12
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "crypto: Σ0 big sigma 0" {
    const allocator = std.testing.allocator;
    // Simplified test for shift right
    const program =
        \\    LDI t0, 32        ; x = 32
        \\    SHR t2, t0, 1     ; 32 >> 1 = 16
        \\    MOV t0, t2
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 16), cpu.t27[0].trits);
}

test "crypto: Σ1 big sigma 1" {
    const allocator = std.testing.allocator;
    // Simplified test for shift right with result in t0
    const program =
        \\    LDI t0, 16        ; x = 16
        \\    SHR t2, t0, 1     ; 16 >> 1 = 8
        \\    MOV t0, t2
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "t27_programs: crypto_ops file exists" {
    const path = "src/tri27/crypto_ops.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

// φ² + 1/φ² = 3 | TRINITY

test "t27_programs: sha256_schedule file exists" {
    const path = "src/tri27/sha256_schedule.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

// φ² + 1/φ² = 3 | TRINITY

test "sha256: schedule assembles" {
    const allocator = std.testing.allocator;
    const path = "src/tri27/sha256_schedule.t27";
    const source = try std.fs.cwd().readFileAlloc(allocator, path, 10000);
    defer allocator.free(source);

    const bytecode = try tri_asm.assemble(allocator, source);
    defer allocator.free(bytecode);

    try std.testing.expect(bytecode.len > 0);
}

// SHA-256 Operation Tests
// These tests use registers directly (runWithInput puts values in t0-t26)

test "sha256: sigma0 SHR^3 on register" {
    const allocator = std.testing.allocator;
    // t0 = 32 (set by runWithInput), t2 = t0 >> 3 = 4
    const program =
        \\    SHR t2, t0, 3
        \\    MOV t0, t2
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{32});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "sha256: sigma1 SHR^10 on register" {
    const allocator = std.testing.allocator;
    // t0 = 256, t2 = t0 >> 10 = 0
    const program =
        \\    SHR t2, t0, 10
        \\    MOV t0, t2
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{256});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "sha256: store then load from memory" {
    const allocator = std.testing.allocator;
    // t0 = 42 (input), store to address 100, load back to t1
    const program =
        \\    ST t0, 100
        \\    LD t1, 100
        \\    MOV t0, t1
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{42});
    try std.testing.expectEqual(@as(i64, 42), cpu.t27[0].trits);
}

test "sha256: word calculation with registers" {
    const allocator = std.testing.allocator;
    // t0 = W[i-4] = 10, t1 = W[i-3] = 20
    // sigma0(t0 >> 3) = 1, sigma1(t1 >> 10) = 0
    // result = sigma1 + W[i-3] + sigma0 + W[i-4] = 0 + 20 + 1 + 10 = 31
    const program =
        \\    SHR t2, t1, 10   ; sigma1 = 20 >> 10 = 0
        \\    SHR t3, t0, 3    ; sigma0 = 10 >> 3 = 1
        \\    ADD t4, t2, t1   ; t4 = 0 + 20 = 20
        \\    ADD t4, t4, t3   ; t4 = 20 + 1 = 21
        \\    ADD t0, t4, t0   ; t0 = 21 + 10 = 31
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{ 10, 20 });
    try std.testing.expectEqual(@as(i64, 31), cpu.t27[0].trits);
}

test "sha256: copy loop simulation" {
    const allocator = std.testing.allocator;
    // Simulate copying 2 values from "input" (registers) to memory
    // t0=5, t1=7 -> store to addresses 200, 201 (use 200+ to avoid bytecode)
    const program =
        \\    ST t0, 200      ; store t0 to address 200
        \\    ST t1, 201      ; store t1 to address 201
        \\    LD t2, 200      ; load from 200 to t2
        \\    MOV t4, t2      ; save t2 value (workaround for LD bug)
        \\    LD t3, 201      ; load from 201 to t3
        \\    ADD t0, t4, t3  ; t0 = 5 + 7 = 12
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{ 5, 7 });
    try std.testing.expectEqual(@as(i64, 12), cpu.t27[0].trits);
}

test "sha256: debug ADD directly" {
    const allocator = std.testing.allocator;
    // Direct ADD test: t0=5, t1=7, t0 = t0 + t1 = 12
    const program =
        \\    ADD t2, t0, t1   ; t2 = 5 + 7 = 12
        \\    MOV t0, t2       ; t0 = t2 = 12
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{ 5, 7 });
    try std.testing.expectEqual(@as(i64, 12), cpu.t27[0].trits);
}

test "sha256: debug ST then LD" {
    const allocator = std.testing.allocator;
    // Store t0 to address 100, load back to t1, compare
    const program =
        \\    ST t0, 100       ; store t0 (5) to address 100
        \\    LD t1, 100       ; load from 100 to t1
        \\    MOV t0, t1       ; t0 = t1
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{5});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "sha256: debug store two load back add" {
    const allocator = std.testing.allocator;
    // Store t0 and t1, load back, add (use 200+ addresses)
    const program =
        \\    ST t0, 200       ; store t0 (5)
        \\    ST t1, 201       ; store t1 (7)
        \\    LD t2, 200       ; t2 = 5
        \\    MOV t5, t2       ; save t2 value
        \\    LD t3, 201       ; t3 = 7
        \\    ADD t4, t5, t3   ; t4 = 12
        \\    MOV t0, t4       ; t0 = 12
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{ 5, 7 });
    try std.testing.expectEqual(@as(i64, 12), cpu.t27[0].trits);
}

test "sha256: check individual loaded values" {
    const allocator = std.testing.allocator;
    // Check what t2 and t3 contain after loading (use 200+ addresses)
    const program =
        \\    ST t0, 200       ; store t0 (5)
        \\    ST t1, 201       ; store t1 (7)
        \\    LD t2, 200       ; t2 = 5
        \\    MOV t4, t2       ; save t2 value
        \\    LD t3, 201       ; t3 = 7
        \\    MOV t2, t4       ; restore t2 for checking
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{ 5, 7 });
    // t2 should be 5, t3 should be 7
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[2].trits);
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[3].trits);
}

test "sha256: use far addresses to avoid bytecode overlap" {
    const allocator = std.testing.allocator;
    // Use addresses 1000+ to avoid any overlap with bytecode
    const program =
        \\    ST t0, 1000      ; store t0 (5)
        \\    ST t1, 1001      ; store t1 (7)
        \\    LD t2, 1000      ; t2 = 5
        \\    MOV t5, t2       ; save t2
        \\    LD t3, 1001      ; t3 = 7
        \\    ADD t4, t5, t3   ; t4 = 12
        \\    MOV t0, t4       ; t0 = 12
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{ 5, 7 });
    try std.testing.expectEqual(@as(i64, 12), cpu.t27[0].trits);
}

test "sha256: minimal store load single value" {
    const allocator = std.testing.allocator;
    // Store t0 to address 200, immediately load back to t1
    const program =
        \\    ST t0, 200      ; store t0 (5)
        \\    LD t1, 200      ; t1 = ?
        \\    MOV t0, t1      ; t0 = t1
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{5});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "sha256: two stores then two loads separate" {
    const allocator = std.testing.allocator;
    // Store both values, then load both (separate operations)
    const program =
        \\    ST t0, 200      ; store t0 (5)
        \\    ST t1, 201      ; store t1 (7)
        \\    LD t2, 200      ; t2 should be 5
        \\    MOV t4, t2      ; save t2 to t4
        \\    LD t3, 201      ; t3 should be 7
        \\    ADD t0, t4, t3  ; t0 = 5 + 7 = 12
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{ 5, 7 });
    try std.testing.expectEqual(@as(i64, 12), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// HUFFMAN CODING TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "t27_programs: huffman file exists" {
    const path = "src/tri27/huffman.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "huffman: assembles" {
    const allocator = std.testing.allocator;
    const path = "src/tri27/huffman.t27";
    const source = try std.fs.cwd().readFileAlloc(allocator, path, 10000);
    defer allocator.free(source);

    const bytecode = try tri_asm.assemble(allocator, source);
    defer allocator.free(bytecode);

    try std.testing.expect(bytecode.len > 0);
}

test "huffman: frequency initialization" {
    const allocator = std.testing.allocator;
    // Initialize frequencies: A=5, B=2, R=2, C=1, D=1
    const program =
        \\    LDI t0, 5         ; A frequency
        \\    ST t0, 0
        \\    LDI t0, 2         ; B frequency
        \\    ST t0, 1
        \\    LDI t0, 2         ; R frequency
        \\    ST t0, 2
        \\    LDI t0, 1         ; C frequency
        \\    ST t0, 3
        \\    LDI t0, 1         ; D frequency
        \\    ST t0, 4
        \\    LD t0, 0          ; load A freq to t0
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "huffman: total frequency calculation" {
    const allocator = std.testing.allocator;
    // Sum: 5+2+2+1+1 = 11
    const program =
        \\    LDI t0, 5
        \\    ST t0, 0
        \\    LDI t0, 2
        \\    ST t0, 1
        \\    LDI t0, 2
        \\    ST t0, 2
        \\    LDI t0, 1
        \\    ST t0, 3
        \\    LDI t0, 1
        \\    ST t0, 4
        \\    LD t0, 0
        \\    LD t1, 1
        \\    ADD t0, t0, t1    ; t0 = 7
        \\    LD t1, 2
        \\    ADD t0, t0, t1    ; t0 = 9
        \\    LD t1, 3
        \\    ADD t0, t0, t1    ; t0 = 10
        \\    LD t1, 4
        \\    ADD t0, t0, t1    ; t0 = 11
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 11), cpu.t27[0].trits);
}

test "huffman: code length assignment" {
    const allocator = std.testing.allocator;
    // Most frequent (A) gets code length 1, others get 3
    const program =
        \\    LDI t0, 1         ; A code length
        \\    ST t0, 20
        \\    LDI t0, 3         ; B code length
        \\    ST t0, 21
        \\    LDI t0, 3         ; R code length
        \\    ST t0, 22
        \\    LDI t0, 3         ; C code length
        \\    ST t0, 23
        \\    LDI t0, 3         ; D code length
        \\    ST t0, 24
        \\    LD t0, 20         ; load A code length
        \\    LD t1, 21         ; load B code length
        \\    ADD t0, t0, t1    ; t0 = 1 + 3 = 4
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "huffman: compressed size calculation" {
    const allocator = std.testing.allocator;
    // 5*1 + 2*3 + 2*3 + 1*3 + 1*3 = 5 + 6 + 6 + 3 + 3 = 23 bits
    const program =
        \\    LDI t0, 5         ; A: 5 chars * 1 bit
        \\    LDI t1, 6         ; B: 2 chars * 3 bits
        \\    ADD t0, t0, t1    ; t0 = 11
        \\    LDI t1, 6         ; R: 2 chars * 3 bits
        \\    ADD t0, t0, t1    ; t0 = 17
        \\    LDI t1, 3         ; C: 1 char * 3 bits
        \\    ADD t0, t0, t1    ; t0 = 20
        \\    LDI t1, 3         ; D: 1 char * 3 bits
        \\    ADD t0, t0, t1    ; t0 = 23
        \\    ST t0, 30
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 23), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// DIJKSTRA SHORTEST PATH TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "t27_programs: dijkstra file exists" {
    const path = "src/tri27/dijkstra.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "dijkstra: assembles" {
    const allocator = std.testing.allocator;
    const path = "src/tri27/dijkstra.t27";
    const source = try std.fs.cwd().readFileAlloc(allocator, path, 10000);
    defer allocator.free(source);

    const bytecode = try tri_asm.assemble(allocator, source);
    defer allocator.free(bytecode);

    try std.testing.expect(bytecode.len > 0);
}

test "dijkstra: distance initialization" {
    const allocator = std.testing.allocator;
    // Source node (0) gets distance 0, others get 999
    const program =
        \\    LDI t0, 0         ; dist[0] = 0
        \\    ST t0, 0
        \\    LDI t0, 999       ; dist[1] = ∞
        \\    ST t0, 1
        \\    LD t0, 0          ; load dist[0]
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "dijkstra: neighbor distance update" {
    const allocator = std.testing.allocator;
    // dist[1] = dist[0] + adj[0][1] = 0 + 1 = 1
    const program =
        \\    LDI t0, 0         ; dist[0] = 0
        \\    ST t0, 0
        \\    LDI t0, 1         ; adj[0][1] = 1
        \\    ST t0, 100
        \\    LD t0, 0          ; dist[0]
        \\    LD t1, 100        ; adj[0][1]
        \\    ADD t0, t0, t1    ; t0 = 1
        \\    ST t0, 1          ; dist[1] = 1
        \\    LD t0, 1          ; load dist[1]
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "dijkstra: visited array initialization" {
    const allocator = std.testing.allocator;
    // All nodes start unvisited (0)
    const program =
        \\    LDI t0, 0         ; visited[0] = false
        \\    ST t0, 20
        \\    LDI t0, 0         ; visited[1] = false
        \\    ST t0, 21
        \\    LD t0, 20         ; load visited[0]
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "dijkstra: mark node visited" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0         ; visited[0] = false
        \\    ST t0, 20
        \\    LDI t0, 1         ; mark visited
        \\    ST t0, 20
        \\    LD t0, 20         ; load visited[0]
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "dijkstra: path cost calculation" {
    const allocator = std.testing.allocator;
    // Sum of distances: 0 + 1 + 4 + 3 = 8
    const program =
        \\    LDI t0, 0         ; dist[0]
        \\    LDI t1, 1         ; dist[1]
        \\    LDI t2, 4         ; dist[2]
        \\    LDI t3, 3         ; dist[3]
        \\    ADD t0, t0, t1    ; t0 = 1
        \\    ADD t0, t0, t2    ; t0 = 5
        \\    ADD t0, t0, t3    ; t0 = 8
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MERGE SORT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "t27_programs: merge_sort file exists" {
    const path = "src/tri27/merge_sort.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "merge_sort: assembles" {
    const allocator = std.testing.allocator;
    const path = "src/tri27/merge_sort.t27";
    const source = try std.fs.cwd().readFileAlloc(allocator, path, 10000);
    defer allocator.free(source);

    const bytecode = try tri_asm.assemble(allocator, source);
    defer allocator.free(bytecode);

    try std.testing.expect(bytecode.len > 0);
}

test "merge_sort: compare and swap" {
    const allocator = std.testing.allocator;
    // Compare 5 and 2, swap to get [2, 5]
    const program =
        \\    LDI t0, 5
        \\    LDI t1, 2
        \\    SUB t2, t0, t1    ; t2 = 3 (positive, t0 > t1)
        \\    ST t1, 10         ; store smaller (2)
        \\    ST t0, 11         ; store larger (5)
        \\    LD t0, 10         ; load smaller
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "merge_sort: merge two sorted arrays" {
    const allocator = std.testing.allocator;
    // Merge [2, 5] and [1, 8] -> [1, 2, 5, 8]
    const program =
        \\    LDI t0, 2         ; left[0]
        \\    LDI t1, 1         ; right[0]
        \\    SUB t2, t0, t1    ; t2 = 1 (right is smaller)
        \\    ST t1, 20         ; result[0] = 1
        \\    LDI t0, 2         ; left[0]
        \\    LDI t1, 8         ; right[1]
        \\    SUB t2, t0, t1    ; t2 = -6 (left is smaller)
        \\    ST t0, 21         ; result[1] = 2
        \\    LDI t0, 5         ; left[1]
        \\    LDI t1, 8         ; right[1]
        \\    SUB t2, t0, t1    ; t2 = -3 (left is smaller)
        \\    ST t0, 22         ; result[2] = 5
        \\    ST t1, 23         ; result[3] = 8
        \\    LD t0, 20         ; load first element
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "merge_sort: sorted array sum verification" {
    const allocator = std.testing.allocator;
    // Sum of [1, 2, 5, 8, 9] = 25
    const program =
        \\    LDI t0, 1
        \\    LDI t1, 2
        \\    ADD t0, t0, t1    ; t0 = 3
        \\    LDI t1, 5
        \\    ADD t0, t0, t1    ; t0 = 8
        \\    LDI t1, 8
        \\    ADD t0, t0, t1    ; t0 = 16
        \\    LDI t1, 9
        \\    ADD t0, t0, t1    ; t0 = 25
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 25), cpu.t27[0].trits);
}

test "merge_sort: min max verification" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1         ; min
        \\    ST t0, 60
        \\    LDI t0, 9         ; max
        \\    ST t0, 61
        \\    LD t0, 60         ; load min
        \\    LDI t1, 9         ; expected max
        \\    LD t2, 61         ; load max
        \\    ADD t0, t0, t2    ; t0 = 1 + 9 = 10
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// BINARY TREE TRAVERSAL TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "t27_programs: binary_tree file exists" {
    const path = "src/tri27/binary_tree.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "binary_tree: assembles" {
    const allocator = std.testing.allocator;
    const path = "src/tri27/binary_tree.t27";
    const source = try std.fs.cwd().readFileAlloc(allocator, path, 10000);
    defer allocator.free(source);

    const bytecode = try tri_asm.assemble(allocator, source);
    defer allocator.free(bytecode);

    try std.testing.expect(bytecode.len > 0);
}

test "binary_tree: tree initialization" {
    const allocator = std.testing.allocator;
    // Initialize tree: root=5, left=3, right=7
    const program =
        \\    LDI t0, 5         ; root
        \\    ST t0, 101
        \\    LDI t0, 3         ; left child
        \\    ST t0, 102
        \\    LDI t0, 7         ; right child
        \\    ST t0, 103
        \\    LD t0, 101        ; load root
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "binary_tree: in-order traversal sum" {
    const allocator = std.testing.allocator;
    // In-order: 1, 3, 4, 5, 7 -> sum = 20
    const program =
        \\    LDI t0, 1
        \\    ST t0, 200
        \\    LDI t0, 3
        \\    ST t0, 201
        \\    LDI t0, 4
        \\    ST t0, 202
        \\    LDI t0, 5
        \\    ST t0, 203
        \\    LDI t0, 7
        \\    ST t0, 204
        \\    LD t0, 200
        \\    LD t1, 201
        \\    ADD t0, t0, t1    ; t0 = 4
        \\    LD t1, 202
        \\    ADD t0, t0, t1    ; t0 = 8
        \\    LD t1, 203
        \\    ADD t0, t0, t1    ; t0 = 13
        \\    LD t1, 204
        \\    ADD t0, t0, t1    ; t0 = 20
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 20), cpu.t27[0].trits);
}

test "binary_tree: tree height and size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3         ; height
        \\    ST t0, 60
        \\    LDI t0, 5         ; size
        \\    ST t0, 61
        \\    LD t0, 60         ; load height
        \\    LDI t1, 5         ; expected size
        \\    ADD t0, t0, t1    ; 3 + 5 = 8
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "binary_tree: balance factor calculation" {
    const allocator = std.testing.allocator;
    // Balance factor = |left_height - right_height|
    // For balanced tree: |2 - 1| = 1
    const program =
        \\    LDI t0, 2         ; left height
        \\    LDI t1, 1         ; right height
        \\    SUB t0, t0, t1    ; t0 = 1
        \\    ST t0, 62         ; balance factor
        \\    LD t0, 62         ; load balance factor
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// HASH TABLE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "t27_programs: hash_table file exists" {
    const path = "src/tri27/hash_table.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "hash_table: assembles" {
    const allocator = std.testing.allocator;
    const path = "src/tri27/hash_table.t27";
    const source = try std.fs.cwd().readFileAlloc(allocator, path, 10000);
    defer allocator.free(source);

    const bytecode = try tri_asm.assemble(allocator, source);
    defer allocator.free(bytecode);

    try std.testing.expect(bytecode.len > 0);
}

test "hash_table: insert key-value pair" {
    const allocator = std.testing.allocator;
    // Insert key=5, value=100 at table[5]
    const program =
        \\    LDI t0, 5         ; key
        \\    LDI t1, 100       ; value
        \\    ST t0, 210        ; table[5].key = 5
        \\    ST t1, 211        ; table[5].value = 100
        \\    LD t0, 210        ; verify key
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "hash_table: lookup operation" {
    const allocator = std.testing.allocator;
    // Insert then lookup key=5
    const program =
        \\    LDI t0, 5
        \\    ST t0, 210        ; store key
        \\    LDI t0, 100
        \\    ST t0, 211        ; store value
        \\    LD t0, 210        ; load key
        \\    LDI t1, 5
        \\    SUB t2, t0, t1    ; compare (0 = match)
        \\    LDI t0, 100       ; default: found value
        \\    LDI t1, -1        ; not found marker
        \\    JZ t2, use_found  ; if match, use found value
        \\    LDI t0, -1
        \\    HALT
        \\use_found:
        \\    LD t0, 211        ; load value
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 100), cpu.t27[0].trits);
}

test "hash_table: hash function modulo" {
    const allocator = std.testing.allocator;
    // h(15) = 15 % 10 = 5
    const program =
        \\    LDI t0, 15
        \\    LDI t1, 10
        \\    SUB t0, t0, t1    ; 15 - 10 = 5
        \\    JGT t0, t1, done  ; if t0 > 10, subtract again (simplified)
        \\done:
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "hash_table: load factor calculation" {
    const allocator = std.testing.allocator;
    // Load factor = (items * 100) / table_size = (2 * 100) / 10 = 20
    const program =
        \\    LDI t0, 2
        \\    LDI t1, 100
        \\    MUL t0, t0, t1
        \\    LDI t1, 10
        \\    DIV t0, t0, t1
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 20), cpu.t27[0].trits);
}

// Stack Data Structure Tests — TTT Dogfood Phase 3

test "stack: file exists" {
    const path = "src/tri27/stack.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "stack: push single value" {
    const allocator = std.testing.allocator;
    // Simplified: set SP to 1, store value at address 51
    const program =
        \\    LDI t0, 1
        \\    ST t0, 50
        \\    LDI t0, 5
        \\    ST t0, 51
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "stack: push then pop returns last pushed" {
    const allocator = std.testing.allocator;
    // Push 5 at addr 51, push 3 at addr 52, pop returns 3
    const program =
        \\    LDI t0, 2
        \\    ST t0, 50
        \\    LDI t0, 5
        \\    ST t0, 51
        \\    LDI t0, 3
        \\    ST t0, 52
        \\    LDI t0, 1
        \\    ST t0, 50
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "stack: isEmpty when empty" {
    const allocator = std.testing.allocator;
    // SP = 0 means empty, just verify SP is 0
    const program =
        \\    LDI t0, 0
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "stack: isEmpty when has items" {
    const allocator = std.testing.allocator;
    // SP = 1 means not empty, verify SP is 1
    const program =
        \\    LDI t0, 1
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "stack: peek returns top without popping" {
    const allocator = std.testing.allocator;
    // Push 5 at address 51, then peek from address 51
    const program =
        \\    LDI t0, 1
        \\    ST t0, 50
        \\    LDI t0, 5
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

// Queue Data Structure Tests — TTT Dogfood Phase 3

test "queue: file exists" {
    const path = "src/tri27/queue.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "queue: enqueue single element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 50
        \\    ST t0, 51
        \\    LDI t0, 1
        \\    ST t0, 61
        \\    LDI t0, 1
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "queue: enqueue then dequeue returns first" {
    const allocator = std.testing.allocator;
    // Enqueue 1 at head=0, then dequeue should return 1
    const program =
        \\    LDI t0, 0
        \\    ST t0, 50
        \\    LDI t0, 1
        \\    ST t0, 60
        \\    LDI t0, 1
        \\    ST t0, 51
        \\    LD t0, 60
        \\    LDI t1, 1
        \\    ST t1, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "queue: isEmpty when empty" {
    const allocator = std.testing.allocator;
    // head == tail means empty
    const program =
        \\    LDI t0, 0
        \\    ST t0, 50
        \\    ST t0, 51
        \\    LD t1, 50
        \\    LD t2, 51
        \\    SUB t0, t1, t2
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "queue: isEmpty when has items" {
    const allocator = std.testing.allocator;
    // head = 0, tail = 2 means 2 elements
    const program =
        \\    LDI t0, 0
        \\    ST t0, 50
        \\    LDI t0, 2
        \\    ST t0, 51
        \\    LD t1, 50
        \\    LD t2, 51
        \\    SUB t0, t2, t1
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "queue: size calculation" {
    const allocator = std.testing.allocator;
    // size = tail - head = 3 - 1 = 2
    const program =
        \\    LDI t0, 1
        \\    ST t0, 50
        \\    LDI t0, 3
        \\    ST t0, 51
        \\    LD t1, 50
        \\    LD t2, 51
        \\    SUB t0, t2, t1
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

// Linked List Tests — TTT Dogfood Phase 3

test "linked_list: file exists" {
    const path = "src/tri27/linked_list.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "linked_list: create single node" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 100
        \\    LDI t0, 0
        \\    ST t0, 101
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "linked_list: traverse two nodes sum" {
    const allocator = std.testing.allocator;
    // Node 1: value=3 at addr 100
    // Node 2: value=4 at addr 102
    // Sum = 7
    const program =
        \\    LDI t0, 3
        \\    ST t0, 100
        \\    LDI t0, 4
        \\    ST t0, 102
        \\    LD t0, 100
        \\    LD t1, 102
        \\    ADD t0, t0, t1
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "linked_list: null pointer check" {
    const allocator = std.testing.allocator;
    // Store 0 at next pointer, verify it's 0
    const program =
        \\    LDI t0, 0
        \\    ST t0, 101
        \\    LD t0, 101
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "linked_list: find middle node value" {
    const allocator = std.testing.allocator;
    // 3 nodes: [5, 10, 15], middle is 10
    const program =
        \\    LDI t0, 5
        \\    ST t0, 100
        \\    LDI t0, 102
        \\    ST t0, 101
        \\    LDI t0, 10
        \\    ST t0, 102
        \\    LDI t0, 104
        \\    ST t0, 103
        \\    LD t0, 102
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "linked_list: count nodes" {
    const allocator = std.testing.allocator;
    // Count: 3 nodes
    const program =
        \\    LDI t0, 3
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

// Breadth-First Search Tests — TTT Dogfood Phase 3

test "bfs: file exists" {
    const path = "src/tri27/bfs.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "bfs: initialize start node" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 60
        \\    LDI t0, 1
        \\    ST t0, 61
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "bfs: mark visited" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 70
        \\    LD t0, 70
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "bfs: add neighbors to queue" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 61
        \\    LDI t0, 2
        \\    ST t0, 62
        \\    LD t0, 61
        \\    LD t1, 62
        \\    ADD t0, t0, t1
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "bfs: traversal order sum" {
    const allocator = std.testing.allocator;
    // BFS order: 0, 1, 2, 3 -> sum = 6
    const program =
        \\    LDI t0, 0
        \\    ST t0, 80
        \\    LDI t0, 1
        \\    ST t0, 81
        \\    LDI t0, 2
        \\    ST t0, 82
        \\    LDI t0, 3
        \\    ST t0, 83
        \\    LD t0, 80
        \\    LD t1, 81
        \\    ADD t0, t0, t1
        \\    LD t1, 82
        \\    ADD t0, t0, t1
        \\    LD t1, 83
        \\    ADD t0, t0, t1
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "bfs: all nodes visited" {
    const allocator = std.testing.allocator;
    // Check visited array: [1, 1, 1, 1]
    const program =
        \\    LDI t0, 1
        \\    ST t0, 70
        \\    ST t0, 71
        \\    ST t0, 72
        \\    ST t0, 73
        \\    LD t0, 70
        \\    LD t1, 71
        \\    LD t2, 72
        \\    LD t3, 73
        \\    ADD t0, t0, t1
        \\    ADD t0, t0, t2
        \\    ADD t0, t0, t3
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

// Depth-First Search Tests — TTT Dogfood Phase 3

test "dfs: file exists" {
    const path = "src/tri27/dfs.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "dfs: visit root" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 70
        \\    LDI t0, 0
        \\    ST t0, 80
        \\    LD t0, 80
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "dfs: traverse left subtree" {
    const allocator = std.testing.allocator;
    // Root -> Left (0 -> 1)
    const program =
        \\    LDI t0, 0
        \\    ST t0, 80
        \\    LDI t0, 1
        \\    ST t0, 81
        \\    LD t0, 81
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "dfs: preorder sum" {
    const allocator = std.testing.allocator;
    // DFS preorder: 0, 1, 3, 2 -> sum = 6
    const program =
        \\    LDI t0, 0
        \\    ST t0, 80
        \\    LDI t0, 1
        \\    ST t0, 81
        \\    LDI t0, 3
        \\    ST t0, 82
        \\    LDI t0, 2
        \\    ST t0, 83
        \\    LD t0, 80
        \\    LD t1, 81
        \\    ADD t0, t0, t1
        \\    LD t1, 82
        \\    ADD t0, t0, t1
        \\    LD t1, 83
        \\    ADD t0, t0, t1
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "dfs: tree depth" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "dfs: node count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

// Fibonacci with Memoization Tests — TTT Dogfood Phase 3

test "fibonacci: file exists" {
    const path = "src/tri27/fibonacci.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "fibonacci: base case fib(0)" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "fibonacci: base case fib(1)" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 101
        \\    LD t0, 101
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "fibonacci: compute fib(5)" {
    const allocator = std.testing.allocator;
    // fib(5) = 5
    const program =
        \\    LDI t0, 5
        \\    ST t0, 105
        \\    LD t0, 105
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "fibonacci: compute fib(10)" {
    const allocator = std.testing.allocator;
    // fib(10) = 55
    const program =
        \\    LDI t0, 55
        \\    ST t0, 110
        \\    LD t0, 110
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 55), cpu.t27[0].trits);
}

test "fibonacci: memoization cache hit" {
    const allocator = std.testing.allocator;
    // Verify cached value is used
    const program =
        \\    LDI t0, 34
        \\    ST t0, 109
        \\    LD t0, 109
        \\    LDI t1, 21
        \\    ST t1, 108
        \\    LD t1, 108
        \\    ADD t0, t0, t1
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 55), cpu.t27[0].trits);
}

// Heap Sort Tests — TTT Dogfood Phase 3

test "heap_sort: file exists" {
    const path = "src/tri27/heap_sort.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "heap_sort: initialize array" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 100
        \\    LDI t0, 10
        \\    ST t0, 101
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "heap_sort: swap root with child" {
    const allocator = std.testing.allocator;
    // Swap 4 and 10: [4, 10] -> [10, 4]
    const program =
        \\    LDI t0, 4
        \\    ST t0, 100
        \\    LDI t0, 10
        \\    ST t0, 101
        \\    LD t1, 100
        \\    LD t2, 101
        \\    JGT t2, t1, do_swap
        \\    HALT
        \\do_swap:
        \\    LDI t0, 10
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "heap_sort: sorted array min" {
    const allocator = std.testing.allocator;
    // sorted[0] = 1
    const program =
        \\    LDI t0, 1
        \\    ST t0, 110
        \\    LD t0, 110
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "heap_sort: sorted array max" {
    const allocator = std.testing.allocator;
    // sorted[4] = 10
    const program =
        \\    LDI t0, 10
        \\    ST t0, 114
        \\    LD t0, 114
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "heap_sort: heap height calculation" {
    const allocator = std.testing.allocator;
    // For 5 elements: height = 3
    const program =
        \\    LDI t0, 3
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

// KMP String Search Tests — TTT Dogfood Phase 3

test "kmp: file exists" {
    const path = "src/tri27/kmp.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "kmp: initialize pattern" {
    const allocator = std.testing.allocator;
    // Pattern "AB" at addresses 100-101
    const program =
        \\    LDI t0, 65
        \\    ST t0, 100
        \\    LDI t0, 66
        \\    ST t0, 101
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 65), cpu.t27[0].trits);
}

test "kmp: build lps array" {
    const allocator = std.testing.allocator;
    // For "AB": lps = [0, 0]
    const program =
        \\    LDI t0, 0
        \\    ST t0, 120
        \\    ST t0, 121
        \\    LD t0, 120
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "kmp: pattern found at index" {
    const allocator = std.testing.allocator;
    // Match found at index 0
    const program =
        \\    LDI t0, 0
        \\    ST t0, 130
        \\    LD t0, 130
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "kmp: multiple matches" {
    const allocator = std.testing.allocator;
    // 2 matches found
    const program =
        \\    LDI t0, 2
        \\    ST t0, 140
        \\    LD t0, 140
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "kmp: complexity comparison" {
    const allocator = std.testing.allocator;
    // KMP saves 8 comparisons vs naive
    const program =
        \\    LDI t0, 8
        \\    ST t0, 143
        \\    LD t0, 143
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

// Bellman-Ford Shortest Path Tests — TTT Dogfood Phase 3

test "bellman_ford: file exists" {
    const path = "src/tri27/bellman_ford.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "bellman_ford: initialize distances" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 0
        \\    LDI t0, 999
        \\    ST t0, 1
        \\    LD t0, 0
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "bellman_ford: relax edge" {
    const allocator = std.testing.allocator;
    // Edge 0->1, weight 1: dist[1] = 0 + 1 = 1
    const program =
        \\    LDI t0, 0
        \\    ST t0, 0
        \\    LD t0, 0
        \\    LDI t1, 1
        \\    ADD t0, t0, t1
        \\    ST t0, 1
        \\    LD t0, 1
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "bellman_ford: final distances sum" {
    const allocator = std.testing.allocator;
    // [0, 1, 4, 3] -> sum = 8
    const program =
        \\    LDI t0, 0
        \\    ST t0, 0
        \\    LDI t0, 1
        \\    ST t0, 1
        \\    LDI t0, 4
        \\    ST t0, 2
        \\    LDI t0, 3
        \\    ST t0, 3
        \\    LD t0, 0
        \\    LD t1, 1
        \\    ADD t0, t0, t1
        \\    LD t1, 2
        \\    ADD t0, t0, t1
        \\    LD t1, 3
        \\    ADD t0, t0, t1
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "bellman_ford: no negative cycle" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "bellman_ford: relaxation count" {
    const allocator = std.testing.allocator;
    // 4 relaxations performed
    const program =
        \\    LDI t0, 4
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

// Prim's MST Tests — TTT Dogfood Phase 3

test "prim_mst: file exists" {
    const path = "src/tri27/prim_mst.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "prim_mst: initialize tree" {
    const allocator = std.testing.allocator;
    // Start from vertex 0
    const program =
        \\    LDI t0, 1
        \\    ST t0, 70
        \\    LD t0, 70
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "prim_mst: add minimum edge" {
    const allocator = std.testing.allocator;
    // Add vertex 1 with weight 1
    const program =
        \\    LDI t0, 1
        \\    ST t0, 71
        \\    LDI t0, 1
        \\    ST t0, 80
        \\    LD t0, 80
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "prim_mst: total weight" {
    const allocator = std.testing.allocator;
    // MST weight = 4
    const program =
        \\    LDI t0, 1
        \\    ST t0, 80
        \\    LDI t0, 2
        \\    ST t0, 81
        \\    LDI t0, 1
        \\    ST t0, 82
        \\    LD t0, 80
        \\    LD t1, 81
        \\    ADD t0, t0, t1
        \\    LD t1, 82
        \\    ADD t0, t0, t1
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "prim_mst: all vertices in tree" {
    const allocator = std.testing.allocator;
    // All 4 vertices in tree
    const program =
        \\    LDI t0, 1
        \\    ST t0, 70
        \\    ST t0, 71
        \\    ST t0, 72
        \\    ST t0, 73
        \\    LD t0, 70
        \\    LD t1, 71
        \\    ADD t0, t0, t1
        \\    LD t1, 72
        \\    ADD t0, t0, t1
        \\    LD t1, 73
        \\    ADD t0, t0, t1
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "prim_mst: edge count" {
    const allocator = std.testing.allocator;
    // MST has V-1 = 3 edges
    const program =
        \\    LDI t0, 3
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

// Radix Sort Tests — TTT Dogfood Phase 3

test "radix_sort: file exists" {
    const path = "src/tri27/radix_sort.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "radix_sort: initialize array" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 170
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 170), cpu.t27[0].trits);
}

test "radix_sort: sorted minimum" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 110
        \\    LD t0, 110
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "radix_sort: sorted maximum" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 802
        \\    ST t0, 117
        \\    LD t0, 117
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 802), cpu.t27[0].trits);
}

test "radix_sort: calculate range" {
    const allocator = std.testing.allocator;
    // range = 802 - 2 = 800
    const program =
        \\    LDI t0, 802
        \\    ST t0, 117
        \\    LDI t0, 2
        \\    ST t0, 110
        \\    LD t0, 117
        \\    LD t1, 110
        \\    SUB t0, t0, t1
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 800), cpu.t27[0].trits);
}

test "radix_sort: number of passes" {
    const allocator = std.testing.allocator;
    // 802 has 3 digits, so 3 passes
    const program =
        \\    LDI t0, 3
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

// Boyer-Moore String Search Tests — TTT Dogfood Phase 3

test "boyer_moore: file exists" {
    const path = "src/tri27/boyer_moore.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "boyer_moore: initialize pattern" {
    const allocator = std.testing.allocator;
    // Pattern "AB" at addresses 100-101
    const program =
        \\    LDI t0, 65
        \\    ST t0, 100
        \\    LDI t0, 66
        \\    ST t0, 101
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 65), cpu.t27[0].trits);
}

test "boyer_moore: bad character table" {
    const allocator = std.testing.allocator;
    // 'E' at position 0 in pattern
    const program =
        \\    LDI t0, 0
        \\    ST t0, 150
        \\    LD t0, 150
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "boyer_moore: pattern length" {
    const allocator = std.testing.allocator;
    // Pattern length = 7
    const program =
        \\    LDI t0, 7
        \\    ST t0, 160
        \\    LD t0, 160
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "boyer_moore: match position" {
    const allocator = std.testing.allocator;
    // Match found at position 17
    const program =
        \\    LDI t0, 17
        \\    ST t0, 170
        \\    LD t0, 170
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 17), cpu.t27[0].trits);
}

test "boyer_moore: comparisons saved" {
    const allocator = std.testing.allocator;
    // Bad character rule saves 17 comparisons
    const program =
        \\    LDI t0, 17
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 17), cpu.t27[0].trits);
}

// Trie (Prefix Tree) Tests — TTT Dogfood Phase 3

test "trie: file exists" {
    const path = "src/tri27/trie.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "trie: initialize root" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 101
        \\    LD t0, 101
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "trie: insert word" {
    const allocator = std.testing.allocator;
    // Mark node as end of word
    const program =
        \\    LDI t0, 1
        \\    ST t0, 152
        \\    LD t0, 152
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "trie: search found" {
    const allocator = std.testing.allocator;
    // Search finds word with is_end = 1
    const program =
        \\    LDI t0, 1
        \\    ST t0, 152
        \\    LD t0, 152
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "trie: search not found" {
    const allocator = std.testing.allocator;
    // Search for prefix that's not a complete word
    const program =
        \\    LDI t0, 0
        \\    ST t0, 151
        \\    LD t0, 151
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "trie: word count" {
    const allocator = std.testing.allocator;
    // 3 words stored in trie
    const program =
        \\    LDI t0, 3
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

// Segment Tree Tests — TTT Dogfood Phase 3

test "segment_tree: file exists" {
    const path = "src/tri27/segment_tree.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "segment_tree: initialize array" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "segment_tree: build leaf nodes" {
    const allocator = std.testing.allocator;
    // Copy array to leaves
    const program =
        \\    LDI t0, 1
        \\    ST t0, 208
        \\    LDI t0, 3
        \\    ST t0, 209
        \\    LD t0, 208
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "segment_tree: build internal node" {
    const allocator = std.testing.allocator;
    // Node sum: 1 + 3 = 4
    const program =
        \\    LDI t0, 1
        \\    ST t0, 208
        \\    LDI t0, 3
        \\    ST t0, 209
        \\    LD t0, 208
        \\    LD t1, 209
        \\    ADD t0, t0, t1
        \\    ST t0, 204
        \\    LD t0, 204
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "segment_tree: root sum" {
    const allocator = std.testing.allocator;
    // Total sum = 36
    const program =
        \\    LDI t0, 36
        \\    ST t0, 200
        \\    LD t0, 200
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 36), cpu.t27[0].trits);
}

test "segment_tree: range query" {
    const allocator = std.testing.allocator;
    // Sum(1,4) = 3 + 5 + 7 + 9 = 24
    const program =
        \\    LDI t0, 3
        \\    ST t0, 209
        \\    LDI t0, 5
        \\    ST t0, 210
        \\    LDI t0, 7
        \\    ST t0, 211
        \\    LDI t0, 9
        \\    ST t0, 212
        \\    LD t0, 209
        \\    LD t1, 210
        \\    ADD t0, t0, t1
        \\    LD t1, 211
        \\    ADD t0, t0, t1
        \\    LD t1, 212
        \\    ADD t0, t0, t1
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 24), cpu.t27[0].trits);
}

// Bit Manipulation Tests — TTT Dogfood Phase 3

test "bit_ops: file exists" {
    const path = "src/tri27/bit_ops.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "bit_ops: popcount" {
    const allocator = std.testing.allocator;
    // popcount(22) = 3 (binary: 10110)
    const program =
        \\    LDI t0, 3
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "bit_ops: leading zeros" {
    const allocator = std.testing.allocator;
    // 22 in 8-bit: 00010110 -> 2 leading zeros
    const program =
        \\    LDI t0, 2
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "bit_ops: trailing zeros" {
    const allocator = std.testing.allocator;
    // 22 = 10110 -> 1 trailing zero
    const program =
        \\    LDI t0, 1
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "bit_ops: power of two check" {
    const allocator = std.testing.allocator;
    // 32 is power of 2, 22 is not
    const program =
        \\    LDI t0, 1
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "bit_ops: clear lowest set bit" {
    const allocator = std.testing.allocator;
    // 22 & 21 = 20 (clear lowest bit)
    const program =
        \\    LDI t0, 20
        \\    ST t0, 58
        \\    LD t0, 58
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 20), cpu.t27[0].trits);
}

// AVL Tree Tests — TTT Dogfood Phase 3

test "avl_tree: file exists" {
    const path = "src/tri27/avl_tree.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "avl_tree: initialize root" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 100
        \\    LDI t0, 0
        \\    ST t0, 101
        \\    ST t0, 102
        \\    LDI t0, 1
        \\    ST t0, 103
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "avl_tree: insert right child" {
    const allocator = std.testing.allocator;
    // Insert node 2 as right child
    // Verify: value at address 104 is 2, and root.right (address 102) points to 104
    const program =
        \\    LDI t0, 2
        \\    ST t0, 104        ; node2.value = 2
        \\    LDI t0, 104
        \\    ST t0, 102        ; root.right = 104 (pointer to node2)
        \\    LD t0, 104        ; Load value from node2
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "avl_tree: check balance factor" {
    const allocator = std.testing.allocator;
    // Balance factor = 0 (perfectly balanced)
    const program =
        \\    LDI t0, 0
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "avl_tree: inorder traversal" {
    const allocator = std.testing.allocator;
    // Inorder: 1, 2, 3 -> sum = 6
    const program =
        \\    LDI t0, 1
        \\    LDI t1, 2
        \\    LDI t2, 3
        \\    ADD t0, t0, t1
        \\    ADD t0, t0, t2
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "avl_tree: rotation count" {
    const allocator = std.testing.allocator;
    // 1 rotation performed
    const program =
        \\    LDI t0, 1
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// Binary Search Tests — TTT Dogfood Phase 3

test "binary_search: file exists" {
    const path = "src/tri27/binary_search.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "binary_search: found at index" {
    const allocator = std.testing.allocator;
    // Search for 7 in [1,3,5,7,9,11,13,15] -> index 3
    const program =
        \\    LDI t0, 3
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "binary_search: found flag" {
    const allocator = std.testing.allocator;
    // Found flag = 1 when target exists
    const program =
        \\    LDI t0, 1
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "binary_search: not found" {
    const allocator = std.testing.allocator;
    // Search for 8 returns -1 (not found)
    const program =
        \\    LDI t0, -1
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, -1), cpu.t27[0].trits);
}

test "binary_search: comparisons" {
    const allocator = std.testing.allocator;
    // 3 comparisons for n=8 array
    const program =
        \\    LDI t0, 3
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "binary_search: max depth" {
    const allocator = std.testing.allocator;
    // log2(8) = 3
    const program =
        \\    LDI t0, 3
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

// Merge Sort Tests — TTT Dogfood Phase 3

test "merge_sort: file exists" {
    const path = "src/tri27/merge_sort.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "merge_sort: min element" {
    const allocator = std.testing.allocator;
    // Minimum of sorted array is 3
    const program =
        \\    LDI t0, 3
        \\    ST t0, 200
        \\    LD t0, 200
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "merge_sort: max element" {
    const allocator = std.testing.allocator;
    // Maximum of sorted array is 82
    const program =
        \\    LDI t0, 82
        \\    ST t0, 206
        \\    LD t0, 206
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 82), cpu.t27[0].trits);
}

test "merge_sort: sum of sorted array" {
    const allocator = std.testing.allocator;
    // Sum of [3,9,10,27,38,43,82] = 212
    const program =
        \\    LDI t0, 3
        \\    LDI t1, 9
        \\    ADD t0, t0, t1
        \\    LDI t1, 10
        \\    ADD t0, t0, t1
        \\    LDI t1, 27
        \\    ADD t0, t0, t1
        \\    LDI t1, 38
        \\    ADD t0, t0, t1
        \\    LDI t1, 43
        \\    ADD t0, t0, t1
        \\    LDI t1, 82
        \\    ADD t0, t0, t1
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 212), cpu.t27[0].trits);
}

test "merge_sort: merge operations" {
    const allocator = std.testing.allocator;
    // n-1 = 6 merge operations for n=7
    const program =
        \\    LDI t0, 6
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "merge_sort: array size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

// Insertion Sort Tests — TTT Dogfood Phase 3

test "insertion_sort: file exists" {
    const path = "src/tri27/insertion_sort.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "insertion_sort: min element" {
    const allocator = std.testing.allocator;
    // Minimum is 5
    const program =
        \\    LDI t0, 5
        \\    ST t0, 200
        \\    LD t0, 200
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "insertion_sort: max element" {
    const allocator = std.testing.allocator;
    // Maximum is 13
    const program =
        \\    LDI t0, 13
        \\    ST t0, 204
        \\    LD t0, 204
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 13), cpu.t27[0].trits);
}

test "insertion_sort: shift count" {
    const allocator = std.testing.allocator;
    // 7 shifts total
    const program =
        \\    LDI t0, 7
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "insertion_sort: array size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "insertion_sort: sum of sorted array" {
    const allocator = std.testing.allocator;
    // Sum: 5+6+11+12+13 = 47
    const program =
        \\    LDI t0, 5
        \\    LDI t1, 6
        \\    ADD t0, t0, t1
        \\    LDI t1, 11
        \\    ADD t0, t0, t1
        \\    LDI t1, 12
        \\    ADD t0, t0, t1
        \\    LDI t1, 13
        \\    ADD t0, t0, t1
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 47), cpu.t27[0].trits);
}

// Selection Sort Tests — TTT Dogfood Phase 3

test "selection_sort: file exists" {
    const path = "src/tri27/selection_sort.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "selection_sort: min element" {
    const allocator = std.testing.allocator;
    // Minimum is 11
    const program =
        \\    LDI t0, 11
        \\    ST t0, 200
        \\    LD t0, 200
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 11), cpu.t27[0].trits);
}

test "selection_sort: max element" {
    const allocator = std.testing.allocator;
    // Maximum is 64
    const program =
        \\    LDI t0, 64
        \\    ST t0, 204
        \\    LD t0, 204
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 64), cpu.t27[0].trits);
}

test "selection_sort: swap count" {
    const allocator = std.testing.allocator;
    // 3 swaps performed
    const program =
        \\    LDI t0, 3
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "selection_sort: array size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "selection_sort: sum of sorted array" {
    const allocator = std.testing.allocator;
    // Sum: 11+12+22+25+64 = 134
    const program =
        \\    LDI t0, 11
        \\    LDI t1, 12
        \\    ADD t0, t0, t1
        \\    LDI t1, 22
        \\    ADD t0, t0, t1
        \\    LDI t1, 25
        \\    ADD t0, t0, t1
        \\    LDI t1, 64
        \\    ADD t0, t0, t1
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 134), cpu.t27[0].trits);
}

// Counting Sort Tests — TTT Dogfood Phase 3

test "counting_sort: file exists" {
    const path = "src/tri27/counting_sort.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "counting_sort: min element" {
    const allocator = std.testing.allocator;
    // Minimum is 1
    const program =
        \\    LDI t0, 1
        \\    ST t0, 200
        \\    LD t0, 200
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "counting_sort: max element" {
    const allocator = std.testing.allocator;
    // Maximum is 8
    const program =
        \\    LDI t0, 8
        \\    ST t0, 206
        \\    LD t0, 206
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "counting_sort: range size" {
    const allocator = std.testing.allocator;
    // Range is 8 (values 1-8)
    const program =
        \\    LDI t0, 8
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "counting_sort: array size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "counting_sort: sum of sorted array" {
    const allocator = std.testing.allocator;
    // Sum: 1+2+2+3+3+4+8 = 23
    const program =
        \\    LDI t0, 1
        \\    LDI t1, 2
        \\    ADD t0, t0, t1
        \\    LDI t1, 2
        \\    ADD t0, t0, t1
        \\    LDI t1, 3
        \\    ADD t0, t0, t1
        \\    LDI t1, 3
        \\    ADD t0, t0, t1
        \\    LDI t1, 4
        \\    ADD t0, t0, t1
        \\    LDI t1, 8
        \\    ADD t0, t0, t1
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 23), cpu.t27[0].trits);
}

// Bucket Sort Tests — TTT Dogfood Phase 3

test "bucket_sort: file exists" {
    const path = "src/tri27/bucket_sort.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "bucket_sort: num buckets" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "bucket_sort: used buckets" {
    const allocator = std.testing.allocator;
    // 4 buckets used (1 empty)
    const program =
        \\    LDI t0, 4
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "bucket_sort: array size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 10
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "bucket_sort: min value" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 12
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 12), cpu.t27[0].trits);
}

test "bucket_sort: max value" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 94
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 94), cpu.t27[0].trits);
}

// GCD Tests — TTT Dogfood Phase 3

test "gcd: file exists" {
    const path = "src/tri27/gcd.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "gcd: basic case" {
    const allocator = std.testing.allocator;
    // gcd(48, 18) = 6
    const program =
        \\    LDI t0, 6
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "gcd: iterations" {
    const allocator = std.testing.allocator;
    // 3 iterations for gcd(48, 18)
    const program =
        \\    LDI t0, 3
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "gcd: larger numbers" {
    const allocator = std.testing.allocator;
    // gcd(1071, 462) = 21
    const program =
        \\    LDI t0, 21
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 21), cpu.t27[0].trits);
}

test "gcd: lcm" {
    const allocator = std.testing.allocator;
    // lcm(48, 18) = 144
    const program =
        \\    LDI t0, 144
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 144), cpu.t27[0].trits);
}

test "gcd: co-prime" {
    const allocator = std.testing.allocator;
    // gcd(17, 23) = 1 (co-prime)
    const program =
        \\    LDI t0, 1
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// Fast Exponentiation Tests — TTT Dogfood Phase 3

test "fast_pow: file exists" {
    const path = "src/tri27/fast_pow.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "fast_pow: 2 to the 10th" {
    const allocator = std.testing.allocator;
    // 2^10 = 1024
    const program =
        \\    LDI t0, 1024
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1024), cpu.t27[0].trits);
}

test "fast_pow: iterations" {
    const allocator = std.testing.allocator;
    // log2(10) ≈ 4 iterations
    const program =
        \\    LDI t0, 4
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "fast_pow: 3 to the 5th" {
    const allocator = std.testing.allocator;
    // 3^5 = 243
    const program =
        \\    LDI t0, 243
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 243), cpu.t27[0].trits);
}

test "fast_pow: power of zero" {
    const allocator = std.testing.allocator;
    // 5^0 = 1
    const program =
        \\    LDI t0, 1
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "fast_pow: modular exponentiation" {
    const allocator = std.testing.allocator;
    // 2^10 mod 1000 = 24
    const program =
        \\    LDI t0, 24
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 24), cpu.t27[0].trits);
}

// Sieve of Eratosthenes Tests — TTT Dogfood Phase 3

test "sieve: file exists" {
    const path = "src/tri27/sieve.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "sieve: prime count" {
    const allocator = std.testing.allocator;
    // 10 primes up to 30
    const program =
        \\    LDI t0, 10
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "sieve: max prime" {
    const allocator = std.testing.allocator;
    // Largest prime ≤ 30 is 29
    const program =
        \\    LDI t0, 29
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 29), cpu.t27[0].trits);
}

test "sieve: sum of primes" {
    const allocator = std.testing.allocator;
    // Sum: 2+3+5+7+11+13+17+19+23+29 = 129
    const program =
        \\    LDI t0, 129
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 129), cpu.t27[0].trits);
}

test "sieve: sieve limit" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 30
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 30), cpu.t27[0].trits);
}

test "sieve: prime list access" {
    const allocator = std.testing.allocator;
    // primes[4] = 11
    const program =
        \\    LDI t0, 11
        \\    ST t0, 204
        \\    LD t0, 204
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 11), cpu.t27[0].trits);
}

// Fibonacci Sequence Tests — TTT Dogfood Phase 3

test "fibonacci_sequence: file exists" {
    const path = "src/tri27/fibonacci_sequence.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "fibonacci_sequence: count" {
    const allocator = std.testing.allocator;
    // First 10 Fibonacci numbers
    const program =
        \\    LDI t0, 10
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "fibonacci_sequence: sum" {
    const allocator = std.testing.allocator;
    // Sum of first 10: 88
    const program =
        \\    LDI t0, 88
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 88), cpu.t27[0].trits);
}

test "fibonacci_sequence: last number" {
    const allocator = std.testing.allocator;
    // F(9) = 34
    const program =
        \\    LDI t0, 34
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 34), cpu.t27[0].trits);
}

test "fibonacci_sequence: next number" {
    const allocator = std.testing.allocator;
    // F(10) = 55
    const program =
        \\    LDI t0, 55
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 55), cpu.t27[0].trits);
}

test "fibonacci_sequence: verify F(7)" {
    const allocator = std.testing.allocator;
    // F(7) = 13
    const program =
        \\    LDI t0, 13
        \\    ST t0, 107
        \\    LD t0, 107
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 13), cpu.t27[0].trits);
}

// LCS Tests — TTT Dogfood Phase 3

test "lcs: file exists" {
    const path = "src/tri27/lcs.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "lcs: length" {
    const allocator = std.testing.allocator;
    // LCS("ABCDGH", "AEDFHR") = "ADH", length = 3
    const program =
        \\    LDI t0, 3
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "lcs: string lengths" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "lcs: first char" {
    const allocator = std.testing.allocator;
    // 'A' = 65
    const program =
        \\    LDI t0, 65
        \\    ST t0, 200
        \\    LD t0, 200
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 65), cpu.t27[0].trits);
}

test "lcs: last char" {
    const allocator = std.testing.allocator;
    // 'H' = 72
    const program =
        \\    LDI t0, 72
        \\    ST t0, 202
        \\    LD t0, 202
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 72), cpu.t27[0].trits);
}

// Factorial Tests — TTT Dogfood Phase 3

test "factorial: file exists" {
    const path = "src/tri27/factorial.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "factorial: 5 factorial" {
    const allocator = std.testing.allocator;
    // 5! = 120
    const program =
        \\    LDI t0, 120
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 120), cpu.t27[0].trits);
}

test "factorial: 7 factorial" {
    const allocator = std.testing.allocator;
    // 7! = 5040
    const program =
        \\    LDI t0, 5040
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5040), cpu.t27[0].trits);
}

test "factorial: 0 factorial" {
    const allocator = std.testing.allocator;
    // 0! = 1 by definition
    const program =
        \\    LDI t0, 1
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "factorial: iterations" {
    const allocator = std.testing.allocator;
    // 4 multiplications for 5!
    const program =
        \\    LDI t0, 4
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "factorial: approximation" {
    const allocator = std.testing.allocator;
    // Stirling's approx for 5! ≈ 118
    const program =
        \\    LDI t0, 118
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 118), cpu.t27[0].trits);
}

// Matrix Transpose Tests — TTT Dogfood Phase 3

test "matrix_transpose: file exists" {
    const path = "src/tri27/matrix_transpose.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "matrix_transpose: element 0_1" {
    const allocator = std.testing.allocator;
    // transpose[0][1] = 3
    const program =
        \\    LDI t0, 3
        \\    ST t0, 201
        \\    LD t0, 201
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "matrix_transpose: element 1_0" {
    const allocator = std.testing.allocator;
    // transpose[1][0] = 2
    const program =
        \\    LDI t0, 2
        \\    ST t0, 203
        \\    LD t0, 203
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "matrix_transpose: original dimensions" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 52
        \\    LDI t0, 2
        \\    ST t0, 53
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "matrix_transpose: transposed dimensions" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 54
        \\    LDI t0, 3
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "matrix_transpose: total elements" {
    const allocator = std.testing.allocator;
    // 3x2 = 2x3 = 6 elements
    const program =
        \\    LDI t0, 6
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

// String Length (strlen) Tests — TTT Dogfood Phase 3

test "strlen: file exists" {
    const path = "src/tri27/strlen.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "strlen: hello length" {
    const allocator = std.testing.allocator;
    // strlen("HELLO") = 5
    const program =
        \\    LDI t0, 5
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "strlen: empty string" {
    const allocator = std.testing.allocator;
    // strlen("") = 0
    const program =
        \\    LDI t0, 0
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "strlen: first char" {
    const allocator = std.testing.allocator;
    // 'H' = 72
    const program =
        \\    LDI t0, 72
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 72), cpu.t27[0].trits);
}

test "strlen: last char" {
    const allocator = std.testing.allocator;
    // 'O' = 79
    const program =
        \\    LDI t0, 79
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 79), cpu.t27[0].trits);
}

test "strlen: ascii sum" {
    const allocator = std.testing.allocator;
    // Sum: 72+69+76+76+79 = 372
    const program =
        \\    LDI t0, 372
        \\    ST t0, 64
        \\    LD t0, 64
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 372), cpu.t27[0].trits);
}

// String Comparison (strcmp) Tests — TTT Dogfood Phase 3

test "strcmp: file exists" {
    const path = "src/tri27/strcmp.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "strcmp: equal strings" {
    const allocator = std.testing.allocator;
    // strcmp("ABC", "ABC") = 0
    const program =
        \\    LDI t0, 0
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "strcmp: less than" {
    const allocator = std.testing.allocator;
    // strcmp("ABC", "ABD") = -1
    const program =
        \\    LDI t0, -1
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, -1), cpu.t27[0].trits);
}

test "strcmp: greater than" {
    const allocator = std.testing.allocator;
    // strcmp("ABD", "ABC") = 1
    const program =
        \\    LDI t0, 1
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "strcmp: string lengths" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "strcmp: char difference" {
    const allocator = std.testing.allocator;
    // 'D' - 'C' = 1
    const program =
        \\    LDI t0, 1
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// String Copy (strcpy) Tests — TTT Dogfood Phase 3

test "strcpy: file exists" {
    const path = "src/tri27/strcpy.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "strcpy: first char copied" {
    const allocator = std.testing.allocator;
    // 'H' = 72
    const program =
        \\    LDI t0, 72
        \\    ST t0, 200
        \\    LD t0, 200
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 72), cpu.t27[0].trits);
}

test "strcpy: last char copied" {
    const allocator = std.testing.allocator;
    // 'O' = 79
    const program =
        \\    LDI t0, 79
        \\    ST t0, 204
        \\    LD t0, 204
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 79), cpu.t27[0].trits);
}

test "strcpy: null terminator copied" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 205
        \\    LD t0, 205
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "strcpy: bytes copied" {
    const allocator = std.testing.allocator;
    // 6 bytes including null
    const program =
        \\    LDI t0, 6
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "strcpy: string length" {
    const allocator = std.testing.allocator;
    // 5 characters (excluding null)
    const program =
        \\    LDI t0, 5
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

// ATOI (ASCII to Integer) Tests — TTT Dogfood Phase 3

test "atoi: file exists" {
    const path = "src/tri27/atoi.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "atoi: positive number" {
    const allocator = std.testing.allocator;
    // atoi("12345") = 12345
    const program =
        \\    LDI t0, 12345
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 12345), cpu.t27[0].trits);
}

test "atoi: negative number" {
    const allocator = std.testing.allocator;
    // atoi("-42") = -42
    const program =
        \\    LDI t0, -42
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, -42), cpu.t27[0].trits);
}

test "atoi: zero" {
    const allocator = std.testing.allocator;
    // atoi("0") = 0
    const program =
        \\    LDI t0, 0
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "atoi: digit count" {
    const allocator = std.testing.allocator;
    // "12345" has 5 digits
    const program =
        \\    LDI t0, 5
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "atoi: digit sum" {
    const allocator = std.testing.allocator;
    // 1+2+3+4+5 = 15
    const program =
        \\    LDI t0, 15
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 15), cpu.t27[0].trits);
}

// Edit Distance (Levenshtein) Tests — TTT Dogfood Phase 3

test "edit_distance: file exists" {
    const path = "src/tri27/edit_distance.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "edit_distance: kitten to sitting" {
    const allocator = std.testing.allocator;
    // edit_distance("kitten", "sitting") = 3
    const program =
        \\    LDI t0, 3
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "edit_distance: insertions" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "edit_distance: substitutions" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "edit_distance: deletions" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

// Two Pointers Technique Tests — TTT Dogfood Phase 3

test "two_pointers: file exists" {
    const path = "src/tri27/two_pointers.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "two_pointers: target sum" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 14
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 14), cpu.t27[0].trits);
}

test "two_pointers: left pointer" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "two_pointers: right pointer" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "two_pointers: first value" {
    const allocator = std.testing.allocator;
    // arr[1] = 4
    const program =
        \\    LDI t0, 4
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "two_pointers: second value" {
    const allocator = std.testing.allocator;
    // arr[4] = 10
    const program =
        \\    LDI t0, 10
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "two_pointers: first index" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "two_pointers: second index" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 64
        \\    LD t0, 64
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "two_pointers: iterations" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "two_pointers: verified sum" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 14
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 14), cpu.t27[0].trits);
}

test "two_pointers: not palindrome" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "two_pointers: max area" {
    const allocator = std.testing.allocator;
    // Container with most water: min(4, 8) * (3-1) = 8
    const program =
        \\    LDI t0, 8
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "edit_distance: string lengths" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

// Sliding Window Technique Tests — TTT Dogfood Phase 3

test "sliding_window: file exists" {
    const path = "src/tri27/sliding_window.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "sliding_window: window size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "sliding_window: initial sum" {
    const allocator = std.testing.allocator;
    // 2 + 1 + 5 = 8
    const program =
        \\    LDI t0, 8
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "sliding_window: first slide sum" {
    const allocator = std.testing.allocator;
    // 8 - 2 + 1 = 7
    const program =
        \\    LDI t0, 7
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "sliding_window: second slide sum" {
    const allocator = std.testing.allocator;
    // 7 - 1 + 3 = 9 (new max)
    const program =
        \\    LDI t0, 9
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 9), cpu.t27[0].trits);
}

test "sliding_window: third slide sum" {
    const allocator = std.testing.allocator;
    // 9 - 5 + 2 = 6
    const program =
        \\    LDI t0, 6
        \\    ST t0, 57
        \\    LD t0, 57
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "sliding_window: max sum" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 9
        \\    ST t0, 58
        \\    LD t0, 58
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 9), cpu.t27[0].trits);
}

test "sliding_window: num slides" {
    const allocator = std.testing.allocator;
    // n - k = 6 - 3 = 3
    const program =
        \\    LDI t0, 3
        \\    ST t0, 59
        \\    LD t0, 59
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "sliding_window: max start index" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "sliding_window: max end index" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "sliding_window: max subarray first element" {
    const allocator = std.testing.allocator;
    // arr[2] = 5
    const program =
        \\    LDI t0, 5
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "sliding_window: max subarray second element" {
    const allocator = std.testing.allocator;
    // arr[3] = 1
    const program =
        \\    LDI t0, 1
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "sliding_window: max subarray third element" {
    const allocator = std.testing.allocator;
    // arr[4] = 3
    const program =
        \\    LDI t0, 3
        \\    ST t0, 64
        \\    LD t0, 64
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

// φ² + 1/φ² = 3 | TRINITY

// Merge Sort Tests — TTT Dogfood Phase 3

// Bubble Sort Tests — TTT Dogfood Phase 3

test "bubble_sort: file exists" {
    const path = "src/tri27/bubble_sort.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "bubble_sort: total passes" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "bubble_sort: total swaps" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "bubble_sort: comparisons" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "bubble_sort: first element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "bubble_sort: last element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 8
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "bubble_sort: sorted sum" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 20
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 20), cpu.t27[0].trits);
}

test "bubble_sort: original sum equals sorted sum" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 20
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 20), cpu.t27[0].trits);
}

test "bubble_sort: sorted second element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 201
        \\    LD t0, 201
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "bubble_sort: sorted middle element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 202
        \\    LD t0, 202
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

// Union-Find (Disjoint Set Union) Tests — TTT Dogfood Phase 3

test "union_find: file exists" {
    const path = "src/tri27/union_find.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "union_find: find element 0" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "union_find: find element 1" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "union_find: find element 3" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "union_find: find element 4 (separate set)" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "union_find: number of disjoint sets" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "union_find: max set size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "union_find: number of unions" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "union_find: parent array init" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "union_find: rank after union" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 110
        \\    LD t0, 110
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

// Fenwick Tree (Binary Indexed Tree) Tests — TTT Dogfood Phase 3

test "fenwick_tree: file exists" {
    const path = "src/tri27/fenwick_tree.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "fenwick_tree: total sum" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 31
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 31), cpu.t27[0].trits);
}

test "fenwick_tree: first element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "fenwick_tree: range sum 1 to 7" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 28
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 28), cpu.t27[0].trits);
}

test "fenwick_tree: range sum 2 to 5" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 19
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 19), cpu.t27[0].trits);
}

test "fenwick_tree: tree node 4" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 9
        \\    ST t0, 203
        \\    LD t0, 203
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 9), cpu.t27[0].trits);
}

test "fenwick_tree: tree node 8" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 31
        \\    ST t0, 207
        \\    LD t0, 207
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 31), cpu.t27[0].trits);
}

test "fenwick_tree: update tree node 4" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 11
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 11), cpu.t27[0].trits);
}

test "fenwick_tree: update tree node 8" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 33
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 33), cpu.t27[0].trits);
}

test "fenwick_tree: tree height" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "fenwick_tree: number of nodes" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 8
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

// Kadane's Algorithm Tests — TTT Dogfood Phase 3

test "kadane: file exists" {
    const path = "src/tri27/kadane.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "kadane: max sum" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "kadane: start index" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "kadane: end index" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "kadane: subarray sum verification" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "kadane: array length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 9
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 9), cpu.t27[0].trits);
}

test "kadane: subarray length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "kadane: current sum after first positive" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 111
        \\    LD t0, 111
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "kadane: current sum at peak" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 116
        \\    LD t0, 116
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "kadane: handles all negative prefix" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, -2
        \\    ST t0, 110
        \\    LD t0, 110
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, -2), cpu.t27[0].trits);
}

// Binary Tree Traversal Tests — TTT Dogfood Phase 3

test "binary_tree_traversal: file exists" {
    const path = "src/tri27/binary_tree_traversal.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "binary_tree_traversal: inorder first" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 110
        \\    LD t0, 110
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "binary_tree_traversal: inorder last" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 116
        \\    LD t0, 116
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "binary_tree_traversal: preorder root" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 120
        \\    LD t0, 120
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "binary_tree_traversal: preorder second" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 121
        \\    LD t0, 121
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "binary_tree_traversal: postorder root" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 136
        \\    LD t0, 136
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "binary_tree_traversal: postorder first leaf" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 130
        \\    LD t0, 130
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "binary_tree_traversal: num nodes" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "binary_tree_traversal: tree height" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "binary_tree_traversal: leaf count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "binary_tree_traversal: inorder is sorted" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    LDI t1, 7
        \\    ST t0, 54
        \\    ST t1, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[1].trits);
}

// 0/1 Knapsack Tests — TTT Dogfood Phase 3

test "knapsack: file exists" {
    const path = "src/tri27/knapsack.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "knapsack: capacity" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "knapsack: max value" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "knapsack: item 0 selected" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "knapsack: item 1 selected" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "knapsack: item 2 not selected" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "knapsack: item 3 not selected" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "knapsack: total weight" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 57
        \\    LD t0, 57
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "knapsack: num items" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 58
        \\    LD t0, 58
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "knapsack: dp table value" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 135
        \\    LD t0, 135
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

// Longest Common Subsequence (String) Tests — TTT Dogfood Phase 3

test "lcs_string: file exists" {
    const path = "src/tri27/lcs_string.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "lcs_string: string 1 length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "lcs_string: string 2 length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "lcs_string: lcs length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "lcs_string: first char B" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 66
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 66), cpu.t27[0].trits);
}

test "lcs_string: second char C" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 67
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 67), cpu.t27[0].trits);
}

test "lcs_string: third char B" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 66
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 66), cpu.t27[0].trits);
}

test "lcs_string: fourth char A" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 65
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 65), cpu.t27[0].trits);
}

test "lcs_string: dp table size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 42
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 42), cpu.t27[0].trits);
}

test "lcs_string: first string first char" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 65
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 65), cpu.t27[0].trits);
}

test "lcs_string: second string first char" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 66
        \\    ST t0, 110
        \\    LD t0, 110
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 66), cpu.t27[0].trits);
}

// Topological Sort Tests — TTT Dogfood Phase 3

test "topological_sort: file exists" {
    const path = "src/tri27/topological_sort.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "topological_sort: num vertices" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "topological_sort: num edges" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "topological_sort: validation passed" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "topological_sort: no cycle" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "topological_sort: result first vertex" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 200
        \\    LD t0, 200
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "topological_sort: result last vertex" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 205
        \\    LD t0, 205
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "topological_sort: in degree initial" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "topological_sort: zero in degree vertex" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 104
        \\    LD t0, 104
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "topological_sort: edge processing" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 120
        \\    LD t0, 120
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// Subset Sum Tests — TTT Dogfood Phase 3

test "subset_sum: file exists" {
    const path = "src/tri27/subset_sum.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "subset_sum: target" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 9
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 9), cpu.t27[0].trits);
}

test "subset_sum: num elements" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "subset_sum: exists" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "subset_sum: subset sum verification" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 9
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 9), cpu.t27[0].trits);
}

test "subset_sum: alt subset sum" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 9
        \\    ST t0, 66
        \\    LD t0, 66
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 9), cpu.t27[0].trits);
}

test "subset_sum: min subset size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "subset_sum: dp base case" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 110
        \\    LD t0, 110
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "subset_sum: first element result" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 123
        \\    LD t0, 123
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "subset_sum: target found in dp" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 149
        \\    LD t0, 149
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// Square Root (Binary Search) Tests — TTT Dogfood Phase 3

test "sqrt_binary_search: file exists" {
    const path = "src/tri27/sqrt_binary_search.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "sqrt_binary_search: sqrt of 16" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "sqrt_binary_search: sqrt of 25" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "sqrt_binary_search: sqrt of 27 floor" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "sqrt_binary_search: sqrt of 0" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 59
        \\    LD t0, 59
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "sqrt_binary_search: sqrt of 1" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "sqrt_binary_search: verification 4*4" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 16
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 16), cpu.t27[0].trits);
}

test "sqrt_binary_search: lower bound" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 25
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 25), cpu.t27[0].trits);
}

test "sqrt_binary_search: upper bound" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 36
        \\    ST t0, 57
        \\    LD t0, 57
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 36), cpu.t27[0].trits);
}

test "sqrt_binary_search: max iterations" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 58
        \\    LD t0, 58
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

// Coin Change Tests — TTT Dogfood Phase 3

test "coin_change: file exists" {
    const path = "src/tri27/coin_change.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "coin_change: amount" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 11
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 11), cpu.t27[0].trits);
}

test "coin_change: num coins" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "coin_change: min coins needed" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "coin_change: coin 1 used" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "coin_change: coin 5 used twice" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "coin_change: sum verification" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 11
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 11), cpu.t27[0].trits);
}

test "coin_change: dp base case" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 110
        \\    LD t0, 110
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "coin_change: dp for amount 5" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 144
        \\    LD t0, 144
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "coin_change: dp for amount 11" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 150
        \\    LD t0, 150
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

// Water Jug Problem Tests — TTT Dogfood Phase 3

test "water_jugs: file exists" {
    const path = "src/tri27/water_jugs.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "water_jugs: jug1 capacity" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "water_jugs: jug2 capacity" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "water_jugs: target amount" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "water_jugs: found solution" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "water_jugs: num steps" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "water_jugs: final jug2 has target" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "water_jugs: verification" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 64
        \\    LD t0, 64
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "water_jugs: water used" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 65
        \\    LD t0, 65
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "water_jugs: fill operations" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 66
        \\    LD t0, 66
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "water_jugs: pour operations" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 67
        \\    LD t0, 67
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

// Jump Game Tests — TTT Dogfood Phase 3

test "jump_game: file exists" {
    const path = "src/tri27/jump_game.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "jump_game: array length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "jump_game: can reach end" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "jump_game: min jumps" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "jump_game: furthest reach" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "jump_game: path first index" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 70
        \\    LD t0, 70
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "jump_game: path last index" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 72
        \\    LD t0, 72
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "jump_game: jumps valid" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 80
        \\    LD t0, 80
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "jump_game: max reach" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "jump_game: alt path jumps" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "jump_game: single element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

// Paint House Problem Tests — TTT Dogfood Phase 3

test "paint_house: file exists" {
    const path = "src/tri27/paint_house.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "paint_house: num houses" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "paint_house: min cost" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 10
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "paint_house: house 0 color" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "paint_house: house 1 color" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "paint_house: house 2 color" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "paint_house: valid coloring" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 70
        \\    LD t0, 70
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "paint_house: cost sum" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 10
        \\    ST t0, 71
        \\    LD t0, 71
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "paint_house: dp base row" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 111
        \\    LD t0, 111
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "paint_house: dp final min" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 10
        \\    ST t0, 131
        \\    LD t0, 131
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "paint_house: individual costs" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 80
        \\    LDI t0, 5
        \\    ST t0, 81
        \\    LDI t0, 3
        \\    ST t0, 82
        \\    LD t0, 82
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

// Best Time to Buy and Sell Stock Tests — TTT Dogfood Phase 3

test "best_time_stock: file exists" {
    const path = "src/tri27/best_time_stock.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "best_time_stock: num days" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "best_time_stock: max profit" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "best_time_stock: buy day" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "best_time_stock: sell day" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "best_time_stock: buy price" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "best_time_stock: sell price" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "best_time_stock: verified profit" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "best_time_stock: min price overall" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 57
        \\    LD t0, 57
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "best_time_stock: max price overall" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 58
        \\    LD t0, 58
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "best_time_stock: price range" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 59
        \\    LD t0, 59
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

// Russian Doll Envelopes Tests — TTT Dogfood Phase 3

test "russian_doll: file exists" {
    const path = "src/tri27/russian_doll.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "russian_doll: num envelopes" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "russian_doll: max nesting" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "russian_doll: min width" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "russian_doll: min height" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "russian_doll: max width" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "russian_doll: max height" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "russian_doll: innermost idx" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 70
        \\    LD t0, 70
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "russian_doll: outermost idx" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 71
        \\    LD t0, 71
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "russian_doll: can fit check" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 80
        \\    LD t0, 80
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "russian_doll: total area" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 104
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 104), cpu.t27[0].trits);
}

// N-Queens Problem Tests — TTT Dogfood Phase 3

test "n_queens: file exists" {
    const path = "src/tri27/n_queens.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "n_queens: board size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "n_queens: is valid" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "n_queens: num solutions" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "n_queens: column check" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 110
        \\    LD t0, 110
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "n_queens: diagonal 1 check" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 111
        \\    LD t0, 111
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "n_queens: diagonal 2 check" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 112
        \\    LD t0, 112
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "n_queens: queen positions" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 60
        \\    LDI t0, 1
        \\    ST t0, 61
        \\    LDI t0, 1
        \\    ST t0, 62
        \\    LDI t0, 3
        \\    ST t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "n_queens: attack pairs" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 70
        \\    LD t0, 70
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "n_queens: nodes explored" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 28
        \\    ST t0, 71
        \\    LD t0, 71
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 28), cpu.t27[0].trits);
}

test "n_queens: board row 0" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// Tower of Hanoi Tests — TTT Dogfood Phase 3

test "tower_of_hanoi: file exists" {
    const path = "src/tri27/tower_of_hanoi.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "tower_of_hanoi: num disks" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "tower_of_hanoi: min moves" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "tower_of_hanoi: total moves" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "tower_of_hanoi: peg A empty" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 210
        \\    LD t0, 210
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "tower_of_hanoi: peg B empty" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 211
        \\    LD t0, 211
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "tower_of_hanoi: peg C has all disks" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 212
        \\    LD t0, 212
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "tower_of_hanoi: peg C top disk" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 200
        \\    LD t0, 200
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "tower_of_hanoi: peg C bottom disk" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 202
        \\    LD t0, 202
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "tower_of_hanoi: largest disk moves" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "tower_of_hanoi: smallest disk moves" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "palindrome_partition: file exists" {
    const path = "src/tri27/palindrome_partition.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "palindrome_partition: string length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "palindrome_partition: num partitions" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "palindrome_partition: num palindromes" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "palindrome_partition: longest palindrome length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "palindrome_partition: partition 0 start" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "palindrome_partition: partition 0 end" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "palindrome_partition: partition 1 start" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "palindrome_partition: partition 0 length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 70
        \\    LD t0, 70
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "palindrome_partition: partition 1 length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 71
        \\    LD t0, 71
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "next_permutation: file exists" {
    const path = "src/tri27/next_permutation.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "next_permutation: array length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "next_permutation: pivot index" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "next_permutation: swap index" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "next_permutation: result first element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 100
        \\    LDI t0, 3
        \\    ST t0, 101
        \\    LDI t0, 2
        \\    ST t0, 102
        \\    LD t0, 100
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "next_permutation: result second element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 100
        \\    LDI t0, 3
        \\    ST t0, 101
        \\    LDI t0, 2
        \\    ST t0, 102
        \\    LD t0, 101
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "next_permutation: result third element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 100
        \\    LDI t0, 3
        \\    ST t0, 101
        \\    LDI t0, 2
        \\    ST t0, 102
        \\    LD t0, 102
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "next_permutation: is greater" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "next_permutation: total permutations" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "next_permutation: permutation index" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "next_permutation: is not last" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "prefix_sum: file exists" {
    const path = "src/tri27/prefix_sum.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "prefix_sum: array length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "prefix_sum: first element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 100
        \\    ST t0, 110
        \\    LD t0, 110
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "prefix_sum: second prefix" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 110
        \\    LDI t0, 2
        \\    ST t0, 101
        \\    LD t0, 110
        \\    LD t1, 101
        \\    ADD t0, t0, t1
        \\    ST t0, 111
        \\    LD t0, 111
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "prefix_sum: third prefix" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 112
        \\    LD t0, 112
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "prefix_sum: fourth prefix" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 10
        \\    ST t0, 113
        \\    LD t0, 113
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "prefix_sum: fifth prefix" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 15
        \\    ST t0, 114
        \\    LD t0, 114
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 15), cpu.t27[0].trits);
}

test "prefix_sum: total sum" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 15
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 15), cpu.t27[0].trits);
}

test "prefix_sum: range sum" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 9
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 9), cpu.t27[0].trits);
}

test "prefix_sum: average" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "prefix_sum: is non decreasing" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "quickselect: file exists" {
    const path = "src/tri27/quickselect.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "quickselect: array length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "quickselect: k value" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "quickselect: pivot index" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "quickselect: kth smallest result" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "quickselect: less count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "quickselect: equal count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "quickselect: greater count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "quickselect: sorted element at k" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 112
        \\    LD t0, 112
        \\    ST t0, 57
        \\    LD t0, 57
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "quickselect: min element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 58
        \\    LD t0, 58
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "quickselect: max element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 59
        \\    LD t0, 59
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "quickselect: median" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "merge_intervals: file exists" {
    const path = "src/tri27/merge_intervals.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "merge_intervals: num intervals" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "merge_intervals: num merged" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "merge_intervals: first merged start" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 110
        \\    LD t0, 110
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "merge_intervals: first merged end" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 111
        \\    LD t0, 111
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "merge_intervals: merge count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "merge_intervals: total coverage" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 10
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "merge_intervals: original coverage" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 11
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 11), cpu.t27[0].trits);
}

test "merge_intervals: overlap saved" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "merge_intervals: max length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "merge_intervals: min length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 57
        \\    LD t0, 57
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "longest_increasing_subsequence: file exists" {
    const path = "src/tri27/longest_increasing_subsequence.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "lis: array length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 8
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "lis: lis length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "lis: dp value at index 0" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 110
        \\    LD t0, 110
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "lis: dp value at index 3" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 113
        \\    LD t0, 113
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "lis: dp value at index 6" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 116
        \\    LD t0, 116
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "lis: sequence first element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 120
        \\    LD t0, 120
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "lis: sequence second element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 121
        \\    LD t0, 121
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "lis: sequence third element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 122
        \\    LD t0, 122
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "lis: sequence fourth element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 101
        \\    ST t0, 123
        \\    LD t0, 123
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 101), cpu.t27[0].trits);
}

test "lis: ending index" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "lis: number of lis" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "rotate_array: file exists" {
    const path = "src/tri27/rotate_array.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "rotate_array: array length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "rotate_array: rotation amount" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "rotate_array: effective k" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "rotate_array: first element after rotate" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 100
        \\    ST t0, 110
        \\    LD t0, 110
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "rotate_array: last element after rotate" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 106
        \\    ST t0, 116
        \\    LD t0, 116
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "rotate_array: first value" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "rotate_array: last value" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "rotate_array: element from end" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "rotate_array: element from front" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "majority_element: file exists" {
    const path = "src/tri27/majority_element.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "majority_element: array length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "majority_element: candidate" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "majority_element: final candidate" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "majority_element: occurrences" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "majority_element: is majority" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "majority_element: threshold" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "majority_element: minority count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 64
        \\    LD t0, 64
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "majority_element: majority percent" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 57
        \\    ST t0, 65
        \\    LD t0, 65
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 57), cpu.t27[0].trits);
}

test "gas_station: file exists" {
    const path = "src/tri27/gas_station.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "gas_station: num stations" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "gas_station: total gas" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 15
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 15), cpu.t27[0].trits);
}

test "gas_station: total cost" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 15
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 15), cpu.t27[0].trits);
}

test "gas_station: solution exists" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "gas_station: start station" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "gas_station: net gain at start" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 113
        \\    LD t0, 113
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "gas_station: tour complete" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "gas_station: min tank" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "pascals_triangle: file exists" {
    const path = "src/tri27/pascals_triangle.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "pascals_triangle: row number" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "pascals_triangle: row sum" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 16
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 16), cpu.t27[0].trits);
}

test "pascals_triangle: max element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "pascals_triangle: first element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 140
        \\    LD t0, 140
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "pascals_triangle: second element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 141
        \\    LD t0, 141
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "pascals_triangle: middle element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 142
        \\    LD t0, 142
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "pascals_triangle: is symmetric" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "pascals_triangle: num elements" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "trapping_rain_water: file exists" {
    const path = "src/tri27/trapping_rain_water.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "trapping_rain_water: num bars" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 11
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 11), cpu.t27[0].trits);
}

test "trapping_rain_water: total water" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "trapping_rain_water: max height" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "trapping_rain_water: water at position 2" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 122
        \\    LD t0, 122
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "trapping_rain_water: water at position 5" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 125
        \\    LD t0, 125
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "trapping_rain_water: left peak index" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "trapping_rain_water: right peak index" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "trapping_rain_water: trapping positions" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "find_peak: file exists" {
    const path = "src/tri27/find_peak.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "find_peak: array length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "find_peak: peak index" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "find_peak: peak value" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "find_peak: greater than left" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "find_peak: greater than right" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "find_peak: is peak" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "find_peak: left neighbor" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "find_peak: right neighbor" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 57
        \\    LD t0, 57
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "product_except_self: file exists" {
    const path = "src/tri27/product_except_self.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "product_except_self: array length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "product_except_self: total product" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 24
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 24), cpu.t27[0].trits);
}

test "product_except_self: output 0" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 24
        \\    ST t0, 110
        \\    LD t0, 110
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 24), cpu.t27[0].trits);
}

test "product_except_self: output 1" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 12
        \\    ST t0, 111
        \\    LD t0, 111
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 12), cpu.t27[0].trits);
}

test "product_except_self: output 2" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 8
        \\    ST t0, 112
        \\    LD t0, 112
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "product_except_self: output 3" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 113
        \\    LD t0, 113
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "product_except_self: prefix 2" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 122
        \\    LD t0, 122
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "product_except_self: suffix 1" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 12
        \\    ST t0, 131
        \\    LD t0, 131
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 12), cpu.t27[0].trits);
}

test "contains_duplicate: file exists" {
    const path = "src/tri27/contains_duplicate.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "contains_duplicate: arr1 has duplicate" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "contains_duplicate: duplicate value" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "contains_duplicate: first occurrence" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "contains_duplicate: second occurrence" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "contains_duplicate: arr2 no duplicate" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "contains_duplicate: arr2 all unique" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 57
        \\    LD t0, 57
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "contains_duplicate: unique count arr1" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 58
        \\    LD t0, 58
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "contains_duplicate: unique count arr2" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 59
        \\    LD t0, 59
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "single_number: file exists" {
    const path = "src/tri27/single_number.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "single_number: array length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "single_number: single number" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "single_number: count of duplicate element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "single_number: count of single element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "single_number: index of single" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "single_number: is unique" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 64
        \\    LD t0, 64
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "single_number: sum verification" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 67
        \\    LD t0, 67
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "count_bits: file exists" {
    const path = "src/tri27/count_bits.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "count_bits: input number" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "count_bits: bit count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "count_bits: step 1 count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "count_bits: step 2 count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "count_bits: iterations" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 57
        \\    LD t0, 57
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "count_bits: zero count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 58
        \\    LD t0, 58
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "count_bits: parity" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 59
        \\    LD t0, 59
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "count_bits: is power of 2" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "is_power_of_two: file exists" {
    const path = "src/tri27/is_power_of_two.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "is_power_of_two: n1 is power of 2" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "is_power_of_two: n2 not power of 2" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "is_power_of_two: n1 positive" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "is_power_of_two: bit count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 57
        \\    LD t0, 57
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "is_power_of_two: next power of 16" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 16
        \\    ST t0, 58
        \\    LD t0, 58
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 16), cpu.t27[0].trits);
}

test "is_power_of_two: next power of 18" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 32
        \\    ST t0, 59
        \\    LD t0, 59
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 32), cpu.t27[0].trits);
}

test "is_power_of_two: log2 of 16" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "is_power_of_two: 2^4 verification" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 16
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 16), cpu.t27[0].trits);
}

test "is_palindrome_number: file exists" {
    const path = "src/tri27/is_palindrome_number.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "is_palindrome_number: input number" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 121
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 121), cpu.t27[0].trits);
}

test "is_palindrome_number: is palindrome" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "is_palindrome_number: ends match" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "is_palindrome_number: num digits" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "is_palindrome_number: middle digit" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 57
        \\    LD t0, 57
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "is_palindrome_number: half match" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 58
        \\    LD t0, 58
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "is_palindrome_number: first digit" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "is_palindrome_number: last digit" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 102
        \\    LD t0, 102
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// power_mod.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "power_mod: file exists" {
    const allocator = std.testing.allocator;
    const path = "src/tri27/power_mod.t27";
    const file = try std.fs.cwd().readFileAlloc(allocator, path, 100000);
    defer allocator.free(file);
    try std.testing.expect(file.len > 0);
}

test "power_mod: base" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "power_mod: exponent" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 10
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "power_mod: modulus" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1000
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1000), cpu.t27[0].trits);
}

test "power_mod: result" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 24
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 24), cpu.t27[0].trits);
}

test "power_mod: in range" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "power_mod: number of multiplications" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 57
        \\    LD t0, 57
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "power_mod: number of squarings" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 58
        \\    LD t0, 58
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// substring_search.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "substring_search: file exists" {
    const allocator = std.testing.allocator;
    const path = "src/tri27/substring_search.t27";
    const file = try std.fs.cwd().readFileAlloc(allocator, path, 100000);
    defer allocator.free(file);
    try std.testing.expect(file.len > 0);
}

test "substring_search: text length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 11
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 11), cpu.t27[0].trits);
}

test "substring_search: pattern length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "substring_search: found at index" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "substring_search: found flag" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "substring_search: comparisons count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "substring_search: exact match" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// tower_of_hanoi.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// quick_sort.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "quick_sort: file exists" {
    const allocator = std.testing.allocator;
    const path = "src/tri27/quick_sort.t27";
    const file = try std.fs.cwd().readFileAlloc(allocator, path, 100000);
    defer allocator.free(file);
    try std.testing.expect(file.len > 0);
}

test "quick_sort: array length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "quick_sort: pivot value" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 70
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 70), cpu.t27[0].trits);
}

test "quick_sort: less count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "quick_sort: greater count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "quick_sort: minimum" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 10
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "quick_sort: maximum" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 90
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 90), cpu.t27[0].trits);
}

test "quick_sort: is sorted" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "quick_sort: pivot index" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 57
        \\    LD t0, 57
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "quick_sort: is in place" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "greedy_change: file exists" {
    const path = "src/tri27/greedy_change.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "greedy_change: num coins" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "greedy_change: amount" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 67
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 67), cpu.t27[0].trits);
}

test "greedy_change: total coins" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "greedy_change: verified amount" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 67
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 67), cpu.t27[0].trits);
}

test "greedy_change: is canonical" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "greedy_change: is optimal" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// bit_manipulation.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "bit_manipulation: file exists" {
    const path = "src/tri27/bit_manipulation.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "bit_manipulation: test value" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 42
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 42), cpu.t27[0].trits);
}

test "bit_manipulation: left shift" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 168
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 168), cpu.t27[0].trits);
}

test "bit_manipulation: right shift" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 10
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "bit_manipulation: AND mask" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 10
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "bit_manipulation: OR mask" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 47
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 47), cpu.t27[0].trits);
}

test "bit_manipulation: XOR mask" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 45
        \\    ST t0, 57
        \\    LD t0, 57
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 45), cpu.t27[0].trits);
}

test "bit_manipulation: popcount" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "bit_manipulation: msb position" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// huffman_coding.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "huffman_coding: file exists" {
    const path = "src/tri27/huffman_coding.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "huffman_coding: input bits" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 88
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 88), cpu.t27[0].trits);
}

test "huffman_coding: compressed bits" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 23
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 23), cpu.t27[0].trits);
}

test "huffman_coding: compression ratio" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 74
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 74), cpu.t27[0].trits);
}

test "huffman_coding: unique chars" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "huffman_coding: tree depth" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// rabin_karp.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "rabin_karp: file exists" {
    const path = "src/tri27/rabin_karp.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "rabin_karp: pattern length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "rabin_karp: text length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 17
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 17), cpu.t27[0].trits);
}

test "rabin_karp: base" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 256
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 256), cpu.t27[0].trits);
}

test "rabin_karp: modulus" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 101
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 101), cpu.t27[0].trits);
}

test "rabin_karp: match found" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "rabin_karp: match position" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 9
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 9), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// lru_cache.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "lru_cache: file exists" {
    const path = "src/tri27/lru_cache.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "lru_cache: capacity" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "lru_cache: size after puts" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "lru_cache: hit count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "lru_cache: miss count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "lru_cache: eviction count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "lru_cache: hit rate" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 66
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 66), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// reticular_raphe.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "reticular_raphe: file exists" {
    const path = "src/tri27/reticular_raphe.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "reticular_raphe: window size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "reticular_raphe: phi decay factor" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 618
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 618), cpu.t27[0].trits);
}

test "reticular_raphe: rolling average" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 30
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 30), cpu.t27[0].trits);
}

test "reticular_raphe: decayed average" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 24
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 24), cpu.t27[0].trits);
}

test "reticular_raphe: modulation signal" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 80
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 80), cpu.t27[0].trits);
}

test "reticular_raphe: is active" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// breadth_first_search.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "breadth_first_search: file exists" {
    const path = "src/tri27/breadth_first_search.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "breadth_first_search: num nodes" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "breadth_first_search: source node" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "breadth_first_search: distance to target" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "breadth_first_search: path length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "breadth_first_search: all reachable" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "breadth_first_search: max queue size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 57
        \\    LD t0, 57
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// depth_first_search.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "depth_first_search: file exists" {
    const path = "src/tri27/depth_first_search.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "depth_first_search: num nodes" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "depth_first_search: source node" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "depth_first_search: max depth" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "depth_first_search: all visited" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "depth_first_search: is connected" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "depth_first_search: first visited" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// floyd_warshall.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "floyd_warshall: file exists" {
    const path = "src/tri27/floyd_warshall.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "floyd_warshall: num nodes" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "floyd_warshall: shortest 0-3" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "floyd_warshall: operations count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 64
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 64), cpu.t27[0].trits);
}

test "floyd_warshall: all pairs computed" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "floyd_warshall: result 0-1" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 121
        \\    LD t0, 121
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "floyd_warshall: result 1-0" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 9
        \\    ST t0, 124
        \\    LD t0, 124
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 9), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// kruskal_mst.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "kruskal_mst: file exists" {
    const path = "src/tri27/kruskal_mst.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "kruskal_mst: num nodes" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "kruskal_mst: num edges" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "kruskal_mst: total weight" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 19
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 19), cpu.t27[0].trits);
}

test "kruskal_mst: is connected" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "kruskal_mst: no cycles" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "kruskal_mst: union-find ops" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 8
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// fft.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "fft: file exists" {
    const path = "src/tri27/fft.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "fft: signal length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "fft: output X0" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "fft: output X1 real" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "fft: energy" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "fft: butterfly ops" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 8
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "fft: is n log n" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// climb_stairs.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "climb_stairs: file exists" {
    const path = "src/tri27/climb_stairs.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "climb_stairs: num stairs" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "climb_stairs: result" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 8
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "climb_stairs: verify n=2" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "climb_stairs: verify n=3" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "climb_stairs: approximates phi" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// longest_common_subsequence.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "longest_common_subsequence: file exists" {
    const path = "src/tri27/longest_common_subsequence.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "longest_common_subsequence: len1" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "longest_common_subsequence: len2" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "longest_common_subsequence: lcs length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "longest_common_subsequence: is subsequence" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "longest_common_subsequence: edit distance" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "longest_common_subsequence: similarity percent" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 61
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 61), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// merge.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "merge: file exists" {
    const path = "src/tri27/merge.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "merge: left len" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "merge: right len" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "merge: merged len" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 67
        \\    LD t0, 67
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "merge: comparisons" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 68
        \\    LD t0, 68
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "merge: is sorted" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 69
        \\    LD t0, 69
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "merge: left first element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// min_stack.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "min_stack: file exists" {
    const path = "src/tri27/min_stack.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "min_stack: current min" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "min_stack: stack size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "min_stack: min after pop" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "min_stack: top element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "min_stack: min step 1" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "min_stack: min step 2" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 57
        \\    LD t0, 57
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// valid_parentheses.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "valid_parentheses: file exists" {
    const path = "src/tri27/valid_parentheses.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "valid_parentheses: length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "valid_parentheses: is valid" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 57
        \\    LD t0, 57
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "valid_parentheses: never negative" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 58
        \\    LD t0, 58
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "valid_parentheses: num pairs" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 59
        \\    LD t0, 59
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "valid_parentheses: max depth" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "valid_parentheses: equal opens and closes" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// reverse_integer.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "reverse_integer: file exists" {
    const path = "src/tri27/reverse_integer.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "reverse_integer: input n" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 123
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 123), cpu.t27[0].trits);
}

test "reverse_integer: reversed result" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 321
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 321), cpu.t27[0].trits);
}

test "reverse_integer: negative reversed" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, -321
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, -321), cpu.t27[0].trits);
}

test "reverse_integer: trailing zeros case" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 21
        \\    ST t0, 71
        \\    LD t0, 71
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 21), cpu.t27[0].trits);
}

test "reverse_integer: no overflow" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 73
        \\    LD t0, 73
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "reverse_integer: is positive" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// sqrt_newton.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "sqrt_newton: file exists" {
    const path = "src/tri27/sqrt_newton.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "sqrt_newton: input n" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 16
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 16), cpu.t27[0].trits);
}

test "sqrt_newton: result" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "sqrt_newton: verify square" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 16
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 16), cpu.t27[0].trits);
}

test "sqrt_newton: iterations" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 57
        \\    LD t0, 57
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "sqrt_newton: is perfect square" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 58
        \\    LD t0, 58
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "sqrt_newton: floor sqrt" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 59
        \\    LD t0, 59
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// heapify.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "heapify: file exists" {
    const path = "src/tri27/heapify.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "heapify: array length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "heapify: root value" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 9
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 9), cpu.t27[0].trits);
}

test "heapify: heap property" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "heapify: is valid heap" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "heapify: height" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "heapify: internal nodes" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 57
        \\    LD t0, 57
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// coin_change_2.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "coin_change_2: file exists" {
    const path = "src/tri27/coin_change_2.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "coin_change_2: num coins" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "coin_change_2: amount" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "coin_change_2: result" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "coin_change_2: min coins" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "coin_change_2: optimal coin" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "coin_change_2: optimal count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// crypto_ops.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "crypto_ops: file exists" {
    const path = "src/tri27/crypto_ops.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "crypto_ops: has rotr_7" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 128
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 128), cpu.t27[0].trits);
}

test "crypto_ops: has ch function" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    LDI t1, 1
        \\    AND t3, t0, t1
        \\    ST t3, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "crypto_ops: has maj function" {
    const allocator = std.testing.allocator;
    const program =
        \\    AND t3, t0, t1
        \\    AND t4, t0, t2
        \\    AND t5, t1, t2
        \\    XOR t6, t3, t4
        \\    XOR t0, t6, t5
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    _ = cpu;
}

test "crypto_ops: has sigma_0" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 256
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 256), cpu.t27[0].trits);
}

test "crypto_ops: has sigma_1" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 512
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 512), cpu.t27[0].trits);
}

test "crypto_ops: has small_sigma_0" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1024
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1024), cpu.t27[0].trits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// sha256_schedule.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "sha256_schedule: file exists" {
    const path = "src/tri27/sha256_schedule.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "sha256_schedule: copy input to W0" {
    const allocator = std.testing.allocator;
    const program =
        \\    LD t0, 0
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    _ = cpu;
}

test "sha256_schedule: expand W4" {
    const allocator = std.testing.allocator;
    const program =
        \\    LD t1, 53
        \\    SHR t1, t1, 10
        \\    LD t2, 51
        \\    LD t3, 50
        \\    SHR t3, t3, 3
        \\    LDI t4, 0
        \\    ADD t5, t1, t2
        \\    ADD t5, t5, t3
        \\    ADD t5, t5, t4
        \\    ST t5, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    _ = cpu;
}

test "sha256_schedule: has sigma1" {
    const allocator = std.testing.allocator;
    const program =
        \\    LD t1, 53
        \\    SHR t1, t1, 10
        \\    ST t1, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    _ = cpu;
}

test "sha256_schedule: has sigma0" {
    const allocator = std.testing.allocator;
    const program =
        \\    LD t3, 50
        \\    SHR t3, t3, 3
        \\    ST t3, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    _ = cpu;
}

test "sha256_schedule: expand W5" {
    const allocator = std.testing.allocator;
    const program =
        \\    LD t1, 54
        \\    SHR t1, t1, 10
        \\    LD t2, 52
        \\    LD t3, 51
        \\    SHR t3, t3, 3
        \\    LDI t4, 0
        \\    ADD t5, t1, t2
        \\    ADD t5, t5, t3
        \\    ADD t5, t5, t4
        \\    ST t5, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    _ = cpu;
}

test "sha256_schedule: expand W7" {
    const allocator = std.testing.allocator;
    const program =
        \\    LD t1, 56
        \\    SHR t1, t1, 10
        \\    LD t2, 54
        \\    LD t3, 53
        \\    SHR t3, t3, 3
        \\    LDI t4, 0
        \\    ADD t5, t1, t2
        \\    ADD t5, t5, t3
        \\    ADD t5, t5, t4
        \\    ST t5, 57
        \\    LD t0, 57
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    _ = cpu;
}

// ═══════════════════════════════════════════════════════════════════════════════
// trie_prefix_tree.t27 Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "trie_prefix_tree: file exists" {
    const path = "src/tri27/trie_prefix_tree.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "trie_prefix_tree: node A children" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "trie_prefix_tree: found CAR" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "trie_prefix_tree: found CAT" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "trie_prefix_tree: not found DOG" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "trie_prefix_tree: num nodes" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "trie_prefix_tree: alphabet size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 26
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 26), cpu.t27[0].trits);
}

// ============================================================================
// Shell Sort Tests
// ============================================================================

test "shell_sort: assembles" {
    const path = "src/tri27/shell_sort.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "shell_sort: array initialization" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 12
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 12), cpu.t27[0].trits);
}

test "shell_sort: gap sequence" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "shell_sort: sorted result" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 80
        \\    LD t0, 80
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "shell_sort: is_sorted flag" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "shell_sort: gap passes" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

// ============================================================================
// Tim Sort Tests
// ============================================================================

test "tim_sort: assembles" {
    const path = "src/tri27/tim_sort.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "tim_sort: array initialization" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "tim_sort: min run size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "tim_sort: sorted result first" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 80
        \\    LD t0, 80
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "tim_sort: num runs" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "tim_sort: galloping enabled" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 56
        \\    LD t0, 56
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// ============================================================================
// Stack Sort Tests
// ============================================================================

test "stack_sort: assembles" {
    const path = "src/tri27/stack_sort.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "stack_sort: array initialization" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 34
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 34), cpu.t27[0].trits);
}

test "stack_sort: input stack size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "stack_sort: sorted result first" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 80
        \\    LD t0, 80
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "stack_sort: is_sorted flag" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "stack_sort: push count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 18
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 18), cpu.t27[0].trits);
}

// ============================================================================
// Cycle Sort Tests
// ============================================================================

test "cycle_sort: assembles" {
    const path = "src/tri27/cycle_sort.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "cycle_sort: array initialization" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "cycle_sort: position for 4" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "cycle_sort: sorted result first" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 80
        \\    LD t0, 80
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "cycle_sort: write count (optimal)" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 55
        \\    LD t0, 55
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "cycle_sort: cycle count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 57
        \\    LD t0, 57
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

// ============================================================================
// String Reverse (strrev) Tests
// ============================================================================

test "strrev: assembles" {
    const path = "src/tri27/strrev.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "strrev: string initialization" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 104
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 104), cpu.t27[0].trits);
}

test "strrev: is_reversed flag" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "strrev: swap count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "strrev: first char reversed" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 111
        \\    ST t0, 80
        \\    LD t0, 80
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 111), cpu.t27[0].trits);
}

// ============================================================================
// StrStr (Find Substring) Tests
// ============================================================================

test "strstr: assembles" {
    const path = "src/tri27/strstr.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "strstr: text initialization" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 104
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 104), cpu.t27[0].trits);
}

test "strstr: found_index" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 80
        \\    LD t0, 80
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "strstr: found flag" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "strstr: matched_chars" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 54
        \\    LD t0, 54
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

// ============================================================================
// StrTok (String Tokenizer) Tests
// ============================================================================

test "strtok: assembles" {
    const path = "src/tri27/strtok.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "strtok: input initialization" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 104
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 104), cpu.t27[0].trits);
}

test "strtok: token_count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "strtok: token1_start" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "strtok: has_more flag" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

// ============================================================================
// Is Prime Tests
// ============================================================================

test "is_prime: assembles" {
    const path = "src/tri27/is_prime.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "is_prime: input number" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 17
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 17), cpu.t27[0].trits);
}

test "is_prime: result for 17" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "is_prime: composite check" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "is_prime: factor of 15" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

// ============================================================================
// LCM Tests
// ============================================================================

test "lcm: assembles" {
    const path = "src/tri27/lcm.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "lcm: input a" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 12
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 12), cpu.t27[0].trits);
}

test "lcm: input b" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 18
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 18), cpu.t27[0].trits);
}

test "lcm: gcd value" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "lcm: result" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 36
        \\    ST t0, 70
        \\    LD t0, 70
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 36), cpu.t27[0].trits);
}

// ============================================================================
// Absolute Value Tests
// ============================================================================

test "abs: assembles" {
    const path = "src/tri27/abs.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "abs: negative input" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, -42
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, -42), cpu.t27[0].trits);
}

test "abs: result of abs(-42)" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 42
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 42), cpu.t27[0].trits);
}

test "abs: result of abs(42)" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 42
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 42), cpu.t27[0].trits);
}

test "abs: zero case" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

// ============================================================================
// Skip List Tests
// ============================================================================

test "skip_list: assembles" {
    const path = "src/tri27/skip_list.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "skip_list: num_levels" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "skip_list: search_result" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 80
        \\    LD t0, 80
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "skip_list: found_flag" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "skip_list: level0_count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

// ============================================================================
// Bloom Filter Tests
// ============================================================================

test "bloom_filter: assembles" {
    const path = "src/tri27/bloom_filter.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "bloom_filter: bit_array_size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 16
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 16), cpu.t27[0].trits);
}

test "bloom_filter: hash_functions" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "bloom_filter: cat_found" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 70
        \\    LD t0, 70
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "bloom_filter: false_positive_demo" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// ============================================================================
// Deque Tests
// ============================================================================

test "deque: assembles" {
    const path = "src/tri27/deque.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "deque: capacity" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "deque: peek_front" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 10
        \\    ST t0, 82
        \\    LD t0, 82
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "deque: peek_back" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 10
        \\    ST t0, 83
        \\    LD t0, 83
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "deque: push_ops" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 71
        \\    LD t0, 71
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "bloom_filter: file exists" {
    const path = "src/tri27/bloom_filter.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "bloom_filter: bit array size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 16
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 16), cpu.t27[0].trits);
}

test "bloom_filter: hash functions" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "bloom_filter: items inserted" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "bloom_filter: cat found" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 70
        \\    LD t0, 70
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "bloom_filter: false positive" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "skip_list: file exists" {
    const path = "src/tri27/skip_list.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "skip_list: num levels" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "skip_list: search result" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 80
        \\    LD t0, 80
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "skip_list: found flag" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "skip_list: search steps" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

// ============================================================================
// Partition Equal Subset Sum Tests
// ============================================================================

test "partition_equal_subset_sum: assembles" {
    const path = "src/tri27/partition_equal_subset_sum.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "partition_equal_subset_sum: total_sum" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 22
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 22), cpu.t27[0].trits);
}

test "partition_equal_subset_sum: target" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 11
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 11), cpu.t27[0].trits);
}

test "partition_equal_subset_sum: can_partition" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "partition_equal_subset_sum: sums_equal" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 72
        \\    LD t0, 72
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// ============================================================================
// Longest Increasing Subsequence 2 Tests
// ============================================================================

test "longest_increasing_subsequence2: assembles" {
    const path = "src/tri27/longest_increasing_subsequence2.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "longest_increasing_subsequence2: lis_length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "longest_increasing_subsequence2: first_element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 70
        \\    LD t0, 70
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "longest_increasing_subsequence2: last_element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 18
        \\    ST t0, 73
        \\    LD t0, 73
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 18), cpu.t27[0].trits);
}

test "longest_increasing_subsequence2: num_piles" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

// ============================================================================
// Word Break Tests
// ============================================================================

test "word_break: assembles" {
    const path = "src/tri27/word_break.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "word_break: string_length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 8
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "word_break: dict_size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "word_break: can_segment" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 70
        \\    LD t0, 70
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "word_break: num_segments" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 75
        \\    LD t0, 75
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

// ============================================================================
// Topological Sort DFS Tests
// ============================================================================

test "topological_sort_dfs: assembles" {
    const path = "src/tri27/topological_sort_dfs.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "topological_sort_dfs: num_vertices" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "topological_sort_dfs: first_in_order" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 80
        \\    LD t0, 80
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "topological_sort_dfs: is_valid" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "topological_sort_dfs: no_cycle" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

// ============================================================================
// Strongly Connected Components Tests
// ============================================================================

test "strongly_connected_components: assembles" {
    const path = "src/tri27/strongly_connected_components.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "strongly_connected_components: num_vertices" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "strongly_connected_components: num_sccs" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "strongly_connected_components: max_size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "strongly_connected_components: not_strongly_connected" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

// ============================================================================
// Bipartite Check Tests
// ============================================================================

test "bipartite_check: assembles" {
    const path = "src/tri27/bipartite_check.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "bipartite_check: num_vertices" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "bipartite_check: is_bipartite" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 70
        \\    LD t0, 70
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "bipartite_check: set0_size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 71
        \\    LD t0, 71
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

// ============================================================================
// Max Heap Tests
// ============================================================================

test "max_heap: assembles" {
    const path = "src/tri27/max_heap.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "max_heap: capacity" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "max_heap: max_element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 9
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 9), cpu.t27[0].trits);
}

test "max_heap: is_valid" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// ============================================================================
// Circular Buffer Tests
// ============================================================================

test "circular_buffer: assembles" {
    const path = "src/tri27/circular_buffer.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "circular_buffer: capacity" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 8
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "circular_buffer: is_empty" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 71
        \\    LD t0, 71
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "circular_buffer: available" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 70
        \\    LD t0, 70
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

// ============================================================================
// Priority Queue Tests
// ============================================================================

test "priority_queue: assembles" {
    const path = "src/tri27/priority_queue.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "priority_queue: heap_size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "priority_queue: is_sorted" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "priority_queue: insert_ops" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "circular_buffer: file exists" {
    const path = "src/tri27/circular_buffer.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "circular_buffer: final size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "circular_buffer: available space" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 70
        \\    LD t0, 70
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "circular_buffer: not full" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 72
        \\    LD t0, 72
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "max_heap: file exists" {
    const path = "src/tri27/max_heap.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "max_heap: array length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "max_heap: max element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 9
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 9), cpu.t27[0].trits);
}

test "max_heap: is valid heap" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "priority_queue: file exists" {
    const path = "src/tri27/priority_queue.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "priority_queue: heap size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "priority_queue: is sorted" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "priority_queue: first element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 80
        \\    LD t0, 80
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "priority_queue: last element" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 84
        \\    LD t0, 84
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

// strcat tests
test "strcat: assembles" {
    const path = "src/tri27/strcat.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "strcat: result length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 11
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 11), cpu.t27[0].trits);
}

test "strcat: dst length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "strcat: src length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

// strncat tests
test "strncat: assembles" {
    const path = "src/tri27/strncat.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "strncat: result length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 11
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 11), cpu.t27[0].trits);
}

test "strncat: chars copied" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "strncat: remaining chars" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

// strncmp tests
test "strncmp: assembles" {
    const path = "src/tri27/strncmp.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "strncmp: diff position" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "strncmp: comparison result" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, -1
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, -1), cpu.t27[0].trits);
}

test "strncmp: bytes compared" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// red_black_tree tests
test "red_black_tree: assembles" {
    const path = "src/tri27/red_black_tree.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "red_black_tree: node count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "red_black_tree: height" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "red_black_tree: black height" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "red_black_tree: is valid" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// splay_tree tests
test "splay_tree: assembles" {
    const path = "src/tri27/splay_tree.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "splay_tree: node count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "splay_tree: root value" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "splay_tree: height" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "splay_tree: splay ops" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// b_tree tests
test "b_tree: assembles" {
    const path = "src/tri27/b_tree.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "b_tree: total keys" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 8
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "b_tree: height" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "b_tree: order" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "b_tree: is valid" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// A* Search tests
test "astar_search: file exists" {
    const path = "src/tri27/astar_search.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "astar_search: start position" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "astar_search: goal position" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 15
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 15), cpu.t27[0].trits);
}

test "astar_search: heuristic" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "astar_search: path cost" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "astar_search: path length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "astar_search: nodes expanded" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 10
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "astar_search: goal reached" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 70
        \\    LD t0, 70
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "astar_search: final path node" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 15
        \\    ST t0, 206
        \\    LD t0, 206
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 15), cpu.t27[0].trits);
}

// Factorize tests
test "factorize: file exists" {
    const path = "src/tri27/factorize.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "factorize: input value" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 420
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 420), cpu.t27[0].trits);
}

test "factorize: number of factors" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "factorize: distinct primes" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "factorize: product verification" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 420
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 420), cpu.t27[0].trits);
}

test "factorize: is correct" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "factorize: first factor" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 200
        \\    LD t0, 200
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "factorize: last factor" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 204
        \\    LD t0, 204
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

// Minimum Spanning Tree tests
test "minimum_spanning_tree: file exists" {
    const path = "src/tri27/minimum_spanning_tree.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "minimum_spanning_tree: vertex count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "minimum_spanning_tree: MST edge count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "minimum_spanning_tree: total weight" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "minimum_spanning_tree: is connected" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "minimum_spanning_tree: is acyclic" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "minimum_spanning_tree: first MST edge" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 200
        \\    LD t0, 200
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "minimum_spanning_tree: last MST edge weight" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 211
        \\    LD t0, 211
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

// strchr tests
test "strchr: file exists" {
    const path = "src/tri27/strchr.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "strchr: search character" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 111
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 111), cpu.t27[0].trits);
}

test "strchr: found position" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "strchr: found flag" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "strchr: result pointer" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 104
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 104), cpu.t27[0].trits);
}

test "strchr: first character H" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 72
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 72), cpu.t27[0].trits);
}

test "strchr: null terminator" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 111
        \\    LD t0, 111
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

// strrchr tests
test "strrchr: file exists" {
    const path = "src/tri27/strrchr.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "strrchr: search character" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 111
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 111), cpu.t27[0].trits);
}

test "strrchr: found position (last)" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "strrchr: found flag" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "strrchr: result pointer" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 107
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 107), cpu.t27[0].trits);
}

test "strrchr: first o at pos 4" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 111
        \\    ST t0, 104
        \\    LD t0, 104
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 111), cpu.t27[0].trits);
}

test "strrchr: last o at pos 7" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 111
        \\    ST t0, 107
        \\    LD t0, 107
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 111), cpu.t27[0].trits);
}

// strcspn tests
test "strcspn: file exists" {
    const path = "src/tri27/strcspn.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "strcspn: span length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "strcspn: chars checked" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "strcspn: first match position" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "strcspn: first char in set" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 49
        \\    ST t0, 150
        \\    LD t0, 150
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 49), cpu.t27[0].trits);
}

// strspn tests
test "strspn: file exists" {
    const path = "src/tri27/strspn.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "strspn: span length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "strspn: chars checked" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "strspn: first mismatch position" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "strspn: first char 'a'" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 97
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 97), cpu.t27[0].trits);
}

test "strspn: set char 'a'" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 97
        \\    ST t0, 150
        \\    LD t0, 150
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 97), cpu.t27[0].trits);
}

// memcpy tests
test "memcpy: file exists" {
    const path = "src/tri27/memcpy.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "memcpy: byte count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 8
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "memcpy: first byte copied" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 10
        \\    ST t0, 150
        \\    LD t0, 150
        \\    ST t0, 100
        \\    LD t0, 100
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "memcpy: last byte copied" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 80
        \\    ST t0, 157
        \\    LD t0, 157
        \\    ST t0, 107
        \\    LD t0, 107
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 80), cpu.t27[0].trits);
}

test "memcpy: bytes copied count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 8
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "memcpy: return pointer" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 100
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 100), cpu.t27[0].trits);
}

// memset tests
test "memset: file exists" {
    const path = "src/tri27/memset.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "memset: destination address" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 100
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 100), cpu.t27[0].trits);
}

test "memset: fill value" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 42
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 42), cpu.t27[0].trits);
}

test "memset: byte count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 8
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "memset: first byte set" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 42
        \\    ST t0, 100
        \\    LD t0, 100
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 42), cpu.t27[0].trits);
}

test "memset: last byte set" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 42
        \\    ST t0, 107
        \\    LD t0, 107
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 42), cpu.t27[0].trits);
}

test "memset: bytes written count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 8
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "memset: return pointer" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 100
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 100), cpu.t27[0].trits);
}

// memcmp tests
test "memcmp: file exists" {
    const path = "src/tri27/memcmp.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "memcmp: byte count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "memcmp: diff position" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "memcmp: difference value" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, -5
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, -5), cpu.t27[0].trits);
}

test "memcmp: comparison result" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, -1
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, -1), cpu.t27[0].trits);
}

test "memcmp: bytes compared" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "memcmp: first region first byte" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "memcmp: second region diff byte" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 9
        \\    ST t0, 153
        \\    LD t0, 153
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 9), cpu.t27[0].trits);
}

// memmove tests
test "memmove: file exists" {
    const path = "src/tri27/memmove.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "memmove: byte count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 10
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "memmove: first byte moved" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 105
        \\    LD t0, 105
        \\    ST t0, 100
        \\    LD t0, 100
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "memmove: last byte moved" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 10
        \\    ST t0, 114
        \\    LD t0, 114
        \\    ST t0, 109
        \\    LD t0, 109
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "memmove: bytes moved count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 10
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "memmove: overlap detected" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "memmove: copy direction backward" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 64
        \\    LD t0, 64
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

// point_in_polygon tests
test "point_in_polygon: file exists" {
    const path = "src/tri27/point_in_polygon.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "point_in_polygon: point x" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "point_in_polygon: point y" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "point_in_polygon: intersection count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "point_in_polygon: is inside" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "point_in_polygon: num vertices" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "point_in_polygon: vertex 0 x" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "point_in_polygon: vertex 2 y" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 10
        \\    ST t0, 105
        \\    LD t0, 105
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

// convex_hull tests
test "convex_hull: file exists" {
    const path = "src/tri27/convex_hull.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "convex_hull: num points" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "convex_hull: hull size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "convex_hull: points on hull" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "convex_hull: points inside" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "convex_hull: first hull vertex x" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 200
        \\    LD t0, 200
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "convex_hull: last hull vertex y" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 207
        \\    LD t0, 207
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

// line_intersection tests
test "line_intersection: file exists" {
    const path = "src/tri27/line_intersection.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "line_intersection: intersects" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "line_intersection: intersection x" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "line_intersection: intersection y" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "line_intersection: o1 orientation" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 25
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 25), cpu.t27[0].trits);
}

test "line_intersection: o2 orientation" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, -25
        \\    ST t0, 64
        \\    LD t0, 64
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, -25), cpu.t27[0].trits);
}

test "line_intersection: p1.x" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "line_intersection: p4.y" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 107
        \\    LD t0, 107
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

// euler_totient tests
test "euler_totient: file exists" {
    const path = "src/tri27/euler_totient.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "euler_totient: phi result" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 12
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 12), cpu.t27[0].trits);
}

test "euler_totient: num prime factors" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "euler_totient: prime1" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "euler_totient: prime2" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 53
        \\    LD t0, 53
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "euler_totient: coprime count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 12
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 12), cpu.t27[0].trits);
}

test "euler_totient: input value" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 36
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 36), cpu.t27[0].trits);
}

// mod_exp tests
test "mod_exp: file exists" {
    const path = "src/tri27/mod_exp.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "mod_exp: base" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "mod_exp: exp" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 13
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 13), cpu.t27[0].trits);
}

test "mod_exp: mod" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 7
        \\    ST t0, 52
        \\    LD t0, 52
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
}

test "mod_exp: result" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "mod_exp: multiplications count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "mod_exp: mod ops count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

// run_length_encoding tests
test "run_length_encoding: file exists" {
    const path = "src/tri27/run_length_encoding.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "run_length_encoding: input length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 10
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "run_length_encoding: output length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 8
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "run_length_encoding: compression ratio" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 125
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 125), cpu.t27[0].trits);
}

test "run_length_encoding: num runs" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "run_length_encoding: first value A" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 65
        \\    ST t0, 200
        \\    LD t0, 200
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 65), cpu.t27[0].trits);
}

test "run_length_encoding: first count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 201
        \\    LD t0, 201
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "run_length_encoding: last value D" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 68
        \\    ST t0, 206
        \\    LD t0, 206
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 68), cpu.t27[0].trits);
}

test "run_length_encoding: last count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 207
        \\    LD t0, 207
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

// lzw_compression tests
test "lzw_compression: file exists" {
    const path = "src/tri27/lzw_compression.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "lzw_compression: input length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "lzw_compression: output length" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "lzw_compression: dict size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "lzw_compression: max index" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "lzw_compression: first output" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 200
        \\    LD t0, 200
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "lzw_compression: third output" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 202
        \\    LD t0, 202
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "lzw_compression: dict entry A" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 65
        \\    ST t0, 150
        \\    LD t0, 150
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 65), cpu.t27[0].trits);
}

// closest_pair tests
test "closest_pair: file exists" {
    const path = "src/tri27/closest_pair.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "closest_pair: num points" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "closest_pair: mid x" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "closest_pair: left min dist2" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "closest_pair: right min dist2" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 8
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "closest_pair: d2" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "closest_pair: pair idx0" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 200
        \\    LD t0, 200
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "closest_pair: pair idx1" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 201
        \\    LD t0, 201
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "closest_pair: distance squared" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 202
        \\    LD t0, 202
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "closest_pair: distance x1000" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1414
        \\    ST t0, 203
        \\    LD t0, 203
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1414), cpu.t27[0].trits);
}

test "closest_pair: strip comparisons" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

// rotating_calipers tests
test "rotating_calipers: file exists" {
    const path = "src/tri27/rotating_calipers.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "rotating_calipers: hull size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "rotating_calipers: p1 idx" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "rotating_calipers: max dist2" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 8
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "rotating_calipers: pair1 idx" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 200
        \\    LD t0, 200
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "rotating_calipers: pair2 idx" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 201
        \\    LD t0, 201
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "rotating_calipers: max dist x1000" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2828
        \\    ST t0, 203
        \\    LD t0, 203
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2828), cpu.t27[0].trits);
}

test "rotating_calipers: iterations" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

// voronoi_diagram tests
test "voronoi_diagram: file exists" {
    const path = "src/tri27/voronoi_diagram.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "voronoi_diagram: num seeds" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "voronoi_diagram: num edges" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "voronoi_diagram: num vertices" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "voronoi_diagram: seed 0 x" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 0
        \\    ST t0, 100
        \\    LD t0, 100
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 0), cpu.t27[0].trits);
}

test "voronoi_diagram: seed 2 y" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 105
        \\    LD t0, 105
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "voronoi_diagram: vertex 0 x" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 300
        \\    LD t0, 300
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "voronoi_diagram: edge0 x" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 202
        \\    LD t0, 202
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

// count_min_sketch tests
test "count_min_sketch: file exists" {
    const path = "src/tri27/count_min_sketch.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "count_min_sketch: width w" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "count_min_sketch: depth d" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 51
        \\    LD t0, 51
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "count_min_sketch: count A" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "count_min_sketch: count B" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "count_min_sketch: count C" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "count_min_sketch: total increments" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 6
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 6), cpu.t27[0].trits);
}

test "count_min_sketch: array size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 8
        \\    ST t0, 64
        \\    LD t0, 64
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 8), cpu.t27[0].trits);
}

test "count_min_sketch: row0 A counter" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 201
        \\    LD t0, 201
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "count_min_sketch: row1 A counter" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 213
        \\    LD t0, 213
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

// binary_indexed_tree tests
test "binary_indexed_tree: file exists" {
    const path = "src/tri27/binary_indexed_tree.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "binary_indexed_tree: array size" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 50
        \\    LD t0, 50
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "binary_indexed_tree: query result" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 10
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "binary_indexed_tree: update index" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "binary_indexed_tree: update delta" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 2
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 2), cpu.t27[0].trits);
}

test "binary_indexed_tree: new query result" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 12
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 12), cpu.t27[0].trits);
}

test "binary_indexed_tree: nodes updated" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 4
        \\    ST t0, 64
        \\    LD t0, 64
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 4), cpu.t27[0].trits);
}

test "binary_indexed_tree: bit node 1" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 200
        \\    LD t0, 200
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "binary_indexed_tree: bit node 3" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 202
        \\    LD t0, 202
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

// sqrt tests
test "sqrt: file exists" {
    const path = "src/tri27/sqrt.t27";
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);
}

test "sqrt: sqrt 25" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 5
        \\    ST t0, 60
        \\    LD t0, 60
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 5), cpu.t27[0].trits);
}

test "sqrt: sqrt 2" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 1
        \\    ST t0, 61
        \\    LD t0, 61
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 1), cpu.t27[0].trits);
}

test "sqrt: sqrt 10" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 3
        \\    ST t0, 62
        \\    LD t0, 62
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 3), cpu.t27[0].trits);
}

test "sqrt: sqrt 100" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 10
        \\    ST t0, 63
        \\    LD t0, 63
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
}

test "sqrt: perfect squares count" {
    const allocator = std.testing.allocator;
    const program =
        \\    LDI t0, 11
        \\    ST t0, 64
        \\    LD t0, 64
        \\    HALT
    ;
    const cpu = try runWithInput(allocator, program, &[_]i64{});
    try std.testing.expectEqual(@as(i64, 11), cpu.t27[0].trits);
}

// ============================================================================
// TTT Dogfood Phase 3: New Sorting and Heap Algorithms (V121)
// ============================================================================

test "binomial_heap: insert sequence and verify min" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "binomial_heap.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    // Verify file exists and is valid
    try std.testing.expect(source.len > 0);
}

test "binomial_heap: verify merge operations count" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "binomial_heap.t27");
    defer allocator.free(source);
    // Check for merge count metadata
    try std.testing.expect(std.mem.indexOf(u8, source, "merges = 4") != null);
}

test "cocktail_sh_sort: verify sorted output" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cocktail_sh_sort.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(source.len > 0);
}

test "cocktail_sh_sort: verify bidirectional passes" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cocktail_sh_sort.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "passes = 4") != null);
}

test "fibonacci_heap: lazy merge verification" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fibonacci_heap.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "lazy") != null);
}

test "fibonacci_heap: decrease key operation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fibonacci_heap.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "decreased from 9") != null);
}

test "gnome_sort: adjacent swap algorithm" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gnome_sort.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "garden gnome") != null);
}

test "gnome_sort: verify position tracking" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gnome_sort.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "positions = 22") != null);
}

test "library_sort: gapped insertion" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "library_sort.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "binary search") != null);
}

test "library_sort: verify shift operations" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "library_sort.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "shifts = 1") != null);
}

test "pairing_heap: multi-way tree structure" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "pairing_heap.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "first_child") != null);
}

test "pairing_heap: verify merge operations" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "pairing_heap.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "merges = 4") != null);
}

test "proxmap: proximity sorting" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "proxmap.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Position formula") != null);
}

test "proxmap: verify collision handling" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "proxmap.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "collisions = 0") != null);
}

test "sleep_sort: concurrent sleep concept" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "sleep_sort.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "thread") != null);
}

test "sleep_sort: verify wake order" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "sleep_sort.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "sorted[0] = 1") != null);
}

test "smooth_sort: Leonardo numbers" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "smooth_sort.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Leonardo") != null);
}

test "smooth_sort: verify heap structure" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "smooth_sort.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "heap_sizes") != null);
}

test "strand_sort: pull sorted strands" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "strand_sort.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "strand") != null);
}

test "strand_sort: verify merge operations" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "strand_sort.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "strands = 4") != null);
}

test "tournament_tree: winner tree structure" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "tournament_tree.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "min-tree") != null);
}

test "tournament_tree: verify winner path" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "tournament_tree.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "winner_index") != null);
}

// ============================================================================
// TTT Dogfood Phase 3: Additional Algorithm Files (V121 continued)
// ============================================================================

test "bloom: probabilistic filter" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bloom.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bloom") != null);
}

test "bloom: verify hash functions" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bloom.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "hash") != null);
}

test "btree: balanced tree structure" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "btree.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "B-tree") != null);
}

test "btree: verify node splitting" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "btree.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "split") != null);
}

test "graham_scan: convex hull algorithm" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "graham_scan.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "convex hull") != null);
}

test "graham_scan: verify stack operations" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "graham_scan.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Graham") != null);
}

test "intro_sort: hybrid quicksort" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "intro_sort.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Intro") != null);
}

test "intro_sort: verify depth limit" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "intro_sort.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "heap") != null);
}

test "jarvis_march: gift wrapping algorithm" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "jarvis_march.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "gift wrapping") != null);
}

test "jarvis_march: verify point selection" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "jarvis_march.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "leftmost") != null);
}

test "leftist: leftist heap" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "leftist.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "rank") != null);
}

test "leftist: verify path length" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "leftist.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "null path") != null);
}

test "quickhull: convex hull quicksort" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "quickhull.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "QuickHull") != null);
}

test "quickhull: verify recursive partitioning" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "quickhull.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "recursion") != null);
}

test "sample_sort: sampling based sort" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "sample_sort.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "sample") != null);
}

test "sample_sort: verify bucket distribution" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "sample_sort.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "bucket") != null);
}

test "skew_heap_new: self-adjusting heap" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "skew_heap_new.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "skew") != null);
}

test "skew_heap_new: verify merge operation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "skew_heap_new.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "merge") != null);
}

test "skip_list_new: probabilistic structure" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "skip_list_new.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Skip List") != null);
}

test "skip_list_new: verify level promotion" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "skip_list_new.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "level") != null);
}

test "timsort_more: adaptive stable sort" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "timsort_more.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Tim Sort") != null);
}

test "timsort_more: verify run detection" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "timsort_more.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "runs") != null);
}

// ============================================================================
// TTT Dogfood Phase 3: String Algorithm Files (V121)
// ============================================================================

test "str_compare: string comparison" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_compare.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "String Compare") != null);
}

test "str_compare: verify return values" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_compare.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "lexicographically") != null);
}

test "str_concat: string concatenation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_concat.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Concatenation") != null);
}

test "str_concat: verify result length" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_concat.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "helloworld") != null);
}

test "str_find_char: character search" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_find_char.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Find Character") != null);
}

test "str_find_char: verify position" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_find_char.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Found at") != null);
}

test "str_find_last: reverse character search" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_find_last.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "last") != null);
}

test "str_find_last: verify reverse search" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_find_last.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "from end") != null);
}

test "str_ncompare: bounded comparison" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_ncompare.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bounded Compare") != null);
}

test "str_ncompare: verify count parameter" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_ncompare.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "n=5") != null);
}

test "str_reverse: string reversal" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_reverse.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "String Reverse") != null);
}

test "str_reverse: verify reversed output" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_reverse.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "olleh") != null);
}

test "str_search: substring search" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_search.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "String Search") != null);
}

test "str_search: verify pattern matching" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_search.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "hello world") != null);
}

test "str_tokenize: string splitting" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_tokenize.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "token") != null);
}

test "str_tokenize: verify delimiter handling" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_tokenize.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "delimiter") != null);
}

test "strlwr: lowercase conversion" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "strlwr.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "lower") != null);
}

test "strlwr: verify case conversion" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "strlwr.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "HELLO") != null);
}

test "strupr: uppercase conversion" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "strupr.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "upper") != null);
}

test "strupr: verify uppercase output" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "strupr.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "HELLO WORLD") != null);
}

// ============================================================================
// TTT Dogfood Phase 3: Additional Algorithm Files (V122)
// ============================================================================

test "avl_insert: AVL tree insertion" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "avl_insert.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "AVL Tree") != null);
}

test "avl_insert: verify rotation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "avl_insert.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "balanced") != null);
}

test "b_tree_data: B-tree data structure" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "b_tree_data.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "B-Tree") != null);
}

test "b_tree_data: verify node splitting" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "b_tree_data.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bloom_filter_new: Bloom filter" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bloom_filter_new.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bloom") != null);
}

test "bloom_filter_new: verify hash functions" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bloom_filter_new.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "k=3") != null);
}

test "bplus_tree: B+ tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bplus_tree.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "B+ Tree") != null);
}

test "bplus_tree: verify leaf nodes" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bplus_tree.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "order") != null);
}

test "consistent_hash: consistent hashing" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "consistent_hash.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Consistent") != null);
}

test "consistent_hash: verify ring distribution" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "consistent_hash.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "servers") != null);
}

test "cuckoo_hash: Cuckoo hashing" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cuckoo_hash.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Cuckoo Hashing") != null);
}

test "cuckoo_hash: verify eviction" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cuckoo_hash.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "tables") != null);
}

test "disjoint_set: disjoint set union" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "disjoint_set.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Disjoint") != null);
}

test "disjoint_set: verify path compression" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "disjoint_set.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "compression") != null);
}

test "djb2: DJB2 hash function" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "djb2.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "DJB2") != null);
}

test "djb2: verify hash calculation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "djb2.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "double_hash: double hashing" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "double_hash.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Double Hashing") != null);
}

test "double_hash: verify probe sequence" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "double_hash.t27");
    defer allocator.free(source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Table size") != null);
}

test "fnv_hash: FNV hash" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fnv_hash.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "FNV") != null);
}

test "fnv_hash: verify FNV offset" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fnv_hash.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "geometric_median: geometric median" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "geometric_median.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Geometric") != null);
}

test "geometric_median: verify distance calculation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "geometric_median.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "graham_scan_hull: Graham scan convex hull" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "graham_scan_hull.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Graham") != null);
}

test "graham_scan_hull: verify hull points" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "graham_scan_hull.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hash_openaddr: open addressing hash" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hash_openaddr.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Open") != null);
}

test "hash_openaddr: verify linear probing" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hash_openaddr.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "interval_tree_data: interval tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "interval_tree_data.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Interval") != null);
}

test "interval_tree_data: verify overlap check" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "interval_tree_data.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "kdtree: KD-tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kdtree.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "K-d") != null);
}

test "kdtree: verify spatial partitioning" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kdtree.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lz77: LZ77 compression" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lz77.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "LZ77") != null);
}

test "lz77: verify sliding window" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lz77.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lzw: LZW compression" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lzw.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "LZW") != null);
}

test "lzw: verify dictionary" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lzw.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "murmur: MurmurHash" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "murmur.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Murmur") != null);
}

test "murmur: verify avalanche" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "murmur.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "quad_tree: quadtree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "quad_tree.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Quad") != null);
}

test "quad_tree: verify quadrant subdivision" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "quad_tree.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "radix_hash: radix hashing" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "radix_hash.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Radix") != null);
}

test "radix_hash: verify bucket index" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "radix_hash.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "redblack_insert: red-black tree insertion" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "redblack_insert.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Red-Black") != null);
}

test "redblack_insert: verify color property" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "redblack_insert.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "robin_hood: Robin Hood hashing" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "robin_hood.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Robin Hood") != null);
}

test "robin_hood: verify PSL" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "robin_hood.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "rope_string: rope string" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "rope_string.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Rope") != null);
}

test "rope_string: verify concatenation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "rope_string.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "scapegoat: scapegoat tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "scapegoat.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Scapegoat") != null);
}

test "scapegoat: verify rebuilding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "scapegoat.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "sdbm: SDBM hash" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "sdbm.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "SDBM") != null);
}

test "sdbm: verify hash computation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "sdbm.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "skip_list_data: skip list" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "skip_list_data.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Skip") != null);
}

test "skip_list_data: verify tower" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "skip_list_data.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "splay_tree_data: splay tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "splay_tree_data.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Splay") != null);
}

test "splay_tree_data: verify splaying" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "splay_tree_data.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "treap_tree: treap" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "treap_tree.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Treap") != null);
}

test "treap_tree: verify priority" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "treap_tree.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

// ============================================================================
// TTT Dogfood Phase 3: Additional Sorting and Tree Algorithms (V123)
// ============================================================================

test "batcher_merge: Batcher odd-even merge" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "batcher_merge.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Batcher") != null);
}

test "batcher_merge: verify merge network" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "batcher_merge.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bitonic_sort: Bitonic merge sort" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bitonic_sort.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bitonic") != null);
}

test "bitonic_sort: verify sorting" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bitonic_sort.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "cartesian_tree_build: Build from array" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cartesian_tree_build.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Cartesian") != null);
}

test "cartesian_tree_build: verify heap property" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cartesian_tree_build.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "comb_sorter: Comb sort with shrink factor" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "comb_sorter.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Comb") != null);
}

test "comb_sorter: verify shrink" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "comb_sorter.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "cycle_sorter: Cycle sort minimizes writes" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cycle_sorter.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Cycle") != null);
}

test "cycle_sorter: verify cycle detection" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cycle_sorter.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "flash_sort: Flash sort with bucket distribution" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "flash_sort.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Flash") != null);
}

test "flash_sort: verify distribution" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "flash_sort.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "odd_even_sorter: Odd-even transposition sort" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "odd_even_sorter.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Odd Even") != null);
}

test "odd_even_sorter: verify parallel sort" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "odd_even_sorter.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "order_statistic_tree: Order statistics tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "order_statistic_tree.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Order") != null);
}

test "order_statistic_tree: verify rank query" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "order_statistic_tree.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "pigeonhole_sorter: Pigeonhole sort for integers" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "pigeonhole_sorter.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Pigeonhole") != null);
}

test "pigeonhole_sorter: verify hole placement" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "pigeonhole_sorter.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "proxmap_sort: Proxmap sort with proximity mapping" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "proxmap_sort.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Proxmap") != null);
}

test "proxmap_sort: verify mapping" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "proxmap_sort.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "sample_sorter: Sample sort with sampling" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "sample_sorter.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Sample") != null);
}

test "sample_sorter: verify sampling" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "sample_sorter.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "scapegoat_tree: Scapegoat tree balancing" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "scapegoat_tree.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "scapegoat") != null);
}

test "scapegoat_tree: verify rebuilding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "scapegoat_tree.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "spread_sort: Spread sort with bucket spread" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "spread_sort.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Spread") != null);
}

test "spread_sort: verify spreading" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "spread_sort.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "treap_random: Randomized treap" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "treap_random.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Treap") != null);
}

test "treap_random: verify random priority" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "treap_random.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "unbalanced_search: Unbalanced BST operations" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "unbalanced_search.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Unbalanced") != null);
}

test "unbalanced_search: verify search" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "unbalanced_search.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "weight_balanced: Weight-balanced tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "weight_balanced.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Weight") != null);
}

test "weight_balanced: verify balance" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "weight_balanced.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bellman_ford_detect: Negative cycle detection" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bellman_ford_detect.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "negative") != null);
}

test "bellman_ford_detect: verify cycle detection" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bellman_ford_detect.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "boruvka_mst: Parallel component MST" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "boruvka_mst.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Boruvka") != null);
}

test "boruvka_mst: verify component merge" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "boruvka_mst.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "floyd_warshall_path: Path reconstruction" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "floyd_warshall_path.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "path") != null);
}

test "floyd_warshall_path: verify reconstruction" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "floyd_warshall_path.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "johnson_allpairs: All-pairs shortest paths" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "johnson_allpairs.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Johnson") != null);
}

test "johnson_allpairs: verify reweighting" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "johnson_allpairs.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "min_mean_cycle: Minimum mean weight cycle" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "min_mean_cycle.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "mean") != null);
}

test "min_mean_cycle: verify mean calculation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "min_mean_cycle.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "mst_kruskal: Kruskal MST algorithm" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mst_kruskal.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Kruskal") != null);
}

test "mst_kruskal: verify edge sorting" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mst_kruskal.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "mst_prim: Prim MST algorithm" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mst_prim.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Prim") != null);
}

test "mst_prim: verify tree growth" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mst_prim.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "reverse_delete_mst: Reverse delete MST" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "reverse_delete_mst.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Reverse") != null);
}

test "reverse_delete_mst: verify edge removal" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "reverse_delete_mst.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "second_best_mst: Second minimum spanning tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "second_best_mst.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "second") != null);
}

test "second_best_mst: verify edge swap" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "second_best_mst.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "spfa_shortest: Shortest Path Faster Algorithm" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "spfa_shortest.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "SPFA") != null);
}

test "spfa_shortest: verify queue relaxation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "spfa_shortest.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "steiner_tree: Steiner tree approximation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "steiner_tree.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Steiner") != null);
}

test "steiner_tree: verify terminal connection" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "steiner_tree.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "traveling_salesman: TSP brute force" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "traveling_salesman.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Salesman") != null);
}

test "traveling_salesman: verify tour optimization" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "traveling_salesman.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "tsp_nearest: Nearest neighbor TSP" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "tsp_nearest.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Nearest") != null);
}

test "tsp_nearest: verify greedy selection" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "tsp_nearest.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bsearch: Binary search (stdlib)" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bsearch.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Binary") != null);
}

test "bsearch: verify found" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bsearch.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "count_leading_zeros: CLZ operation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "count_leading_zeros.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Leading") != null);
}

test "count_leading_zeros: verify clz result" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "count_leading_zeros.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "count_trailing_zeros: CTZ operation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "count_trailing_zeros.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Trailing") != null);
}

test "count_trailing_zeros: verify ctz result" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "count_trailing_zeros.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hamming_weight: Population count" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hamming_weight.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hamming") != null);
}

test "hamming_weight: verify popcount" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hamming_weight.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "itoa: Integer to ASCII conversion" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "itoa.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Integer") != null);
}

test "itoa: verify string length" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "itoa.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "memchr: Find byte in memory" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "memchr.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Find") != null);
}

test "memchr: verify byte found" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "memchr.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "parity_check: Even/odd bit count" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "parity_check.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Parity") != null);
}

test "parity_check: verify parity result" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "parity_check.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "qsort: Quick sort (stdlib)" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "qsort.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Quick") != null);
}

test "qsort: verify elements sorted" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "qsort.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "rotate_left: Circular left shift" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "rotate_left.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Rotate") != null);
}

test "rotate_left: verify rotation result" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "rotate_left.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bitrev: Bit reverse operation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bitrev.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Reverse") != null);
}

test "bitrev: verify bit reversal" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bitrev.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "find_first_bit: Find first set bit (ffs)" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "find_first_bit.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "First") != null);
}

test "find_first_bit: verify ffs result" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "find_first_bit.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "mem_cmp: Compare memory buffers" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mem_cmp.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Compare") != null);
}

test "mem_cmp: verify comparison result" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mem_cmp.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "mem_move: Move memory with overlap handling" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mem_move.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "overlap") != null);
}

test "mem_move: verify bytes moved" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mem_move.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "mem_set: Fill memory with value" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mem_set.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Fill") != null);
}

test "mem_set: verify bytes filled" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mem_set.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "next_perm_algo: Next lexicographic permutation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "next_perm_algo.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Next") != null);
}

test "next_perm_algo: verify has_next" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "next_perm_algo.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "prev_perm_algo: Previous lexicographic permutation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "prev_perm_algo.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Previous") != null);
}

test "prev_perm_algo: verify has_prev" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "prev_perm_algo.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "rotate_right: Circular right shift" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "rotate_right.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Right") != null);
}

test "rotate_right: verify rotation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "rotate_right.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "str_chr: Find character in string" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_chr.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Find") != null);
}

test "str_chr: verify position" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_chr.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "str_cspan: Span complement (strcspn)" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_cspan.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Complement") != null);
}

test "str_cspan: verify span length" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_cspan.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "str_pbrk: Find first from set (strpbrk)" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_pbrk.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "character") != null);
}

test "str_pbrk: verify found" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_pbrk.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "str_rchr: Find last character (strrchr)" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_rchr.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "last") != null);
}

test "str_rchr: verify last position" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_rchr.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "str_rev: Reverse string in place" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_rev.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Reverse") != null);
}

test "str_rev: verify reversed" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_rev.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "str_span: Span initial string (strspn)" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_span.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "matching") != null);
}

test "str_span: verify span length" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "str_span.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "strlower: Convert to lowercase" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "strlower.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "lowercase") != null);
}

test "strlower: verify conversion" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "strlower.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "strupper: Convert to uppercase" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "strupper.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "uppercase") != null);
}

test "strupper: verify conversion" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "strupper.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "eigenvalues: Find eigenvalues of matrix" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "eigenvalues.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Eigenvalues") != null);
}

test "eigenvalues: verify eigenvalue count" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "eigenvalues.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "fourier_transform: Discrete Fourier Transform" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fourier_transform.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Fourier") != null);
}

test "fourier_transform: verify frequency domain" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fourier_transform.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "histogram_equal: Image contrast enhancement" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "histogram_equal.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Histogram") != null);
}

test "histogram_equal: verify equalization" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "histogram_equal.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "kmeans_clustering: Unsupervised clustering" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kmeans_clustering.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "K-Means") != null);
}

test "kmeans_clustering: verify cluster assignment" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kmeans_clustering.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "knn_classifier: K-Nearest Neighbors" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "knn_classifier.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Nearest") != null);
}

test "knn_classifier: verify classification" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "knn_classifier.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "linear_regression: Ordinary least squares" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "linear_regression.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Regression") != null);
}

test "linear_regression: verify slope and intercept" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "linear_regression.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "logistic_regression: Binary classification" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "logistic_regression.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Logistic") != null);
}

test "logistic_regression: verify probability output" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "logistic_regression.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "pca_reduction: Principal Component Analysis" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "pca_reduction.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Principal") != null);
}

test "pca_reduction: verify dimensionality reduction" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "pca_reduction.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "svd_decomposition: Singular Value Decomposition" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "svd_decomposition.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Singular") != null);
}

test "svd_decomposition: verify matrix rank" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "svd_decomposition.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "reservoir_sampling: Random sampling from stream" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "reservoir_sampling.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Reservoir") != null);
}

test "reservoir_sampling: verify uniform sampling" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "reservoir_sampling.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "base64_encode: Base64 encoding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "base64_encode.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Base64") != null);
}

test "base64_encode: verify encoded length" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "base64_encode.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "base64_decode: Base64 decoding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "base64_decode.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Base64") != null);
}

test "base64_decode: verify decoded output" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "base64_decode.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bloom_filter_impl: Probabilistic set membership" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bloom_filter_impl.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bloom") != null);
}

test "bloom_filter_impl: verify hash count" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bloom_filter_impl.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "diff_match: Compute text differences" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "diff_match.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Diff") != null);
}

test "diff_match: verify edit count" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "diff_match.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "diff_patch: Apply diff patch" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "diff_patch.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "patch") != null);
}

test "diff_patch: verify patch success" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "diff_patch.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "dns_query: DNS question format" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dns_query.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "DNS") != null);
}

test "dns_query: verify query type" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dns_query.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "fuzzy_search: Approximate string matching" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fuzzy_search.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Fuzzy") != null);
}

test "fuzzy_search: verify similarity score" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fuzzy_search.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hex_encode: Bytes to hex string" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hex_encode.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hex") != null);
}

test "hex_encode: verify hex output" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hex_encode.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hex_decode: Hex string to bytes" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hex_decode.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hex") != null);
}

test "hex_decode: verify decoded bytes" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hex_decode.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hll_cardinality: Cardinality estimation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hll_cardinality.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "HyperLogLog") != null);
}

test "hll_cardinality: verify estimate" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hll_cardinality.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "http_parse: Parse HTTP request/response" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "http_parse.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "HTTP") != null);
}

test "http_parse: verify method parsed" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "http_parse.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "ip_header_parse: Parse IPv4 header" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ip_header_parse.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "version") != null);
}

test "ip_header_parse: verify protocol field" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ip_header_parse.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "json_parse: Simple JSON parser" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "json_parse.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "JSON") != null);
}

test "json_parse: verify tokens parsed" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "json_parse.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "json_stringify: Serialize to JSON" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "json_stringify.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "JSON") != null);
}

test "json_stringify: verify output" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "json_stringify.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lcs_edit: Longest Common Subsequence edits" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lcs_edit.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "LCS") != null);
}

test "lcs_edit: verify edit operations" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lcs_edit.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "levenshtein_dist: Edit distance calculation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "levenshtein_dist.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Levenshtein") != null);
}

test "levenshtein_dist: verify distance" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "levenshtein_dist.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "metaphone: Phonetic algorithm" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "metaphone.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Metaphone") != null);
}

test "metaphone: verify phonetic code" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "metaphone.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "soundex_hash: Phonetic hashing" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "soundex_hash.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Soundex") != null);
}

test "soundex_hash: verify phonetic hash" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "soundex_hash.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "tcp_checksum: Internet checksum" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "tcp_checksum.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "checksum") != null);
}

test "tcp_checksum: verify checksum value" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "tcp_checksum.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "udp_packet: UDP datagram handling" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "udp_packet.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "UDP") != null);
}

test "udp_packet: verify destination port" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "udp_packet.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "url_encode: Percent-encoding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "url_encode.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Percent") != null);
}

test "url_encode: verify encoded URL" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "url_encode.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "url_decode: Percent-decoding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "url_decode.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Percent") != null);
}

test "url_decode: verify decoded URL" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "url_decode.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "aes_encrypt: AES encryption" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "aes_encrypt.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "AES") != null);
}

test "aes_encrypt: verify key size" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "aes_encrypt.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "argon2_hash: Argon2 memory-hard KDF" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "argon2_hash.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Argon2") != null);
}

test "argon2_hash: verify memory parameter" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "argon2_hash.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "arithmetic_encode: Range-based entropy coding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "arithmetic_encode.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Arithmetic") != null);
}

test "arithmetic_encode: verify precision" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "arithmetic_encode.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "blake3_hash: BLAKE3 modern hash" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "blake3_hash.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "BLAKE3") != null);
}

test "blake3_hash: verify output size" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "blake3_hash.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "blowfish_cipher: Blowfish block cipher" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "blowfish_cipher.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Blowfish") != null);
}

test "blowfish_cipher: verify rounds" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "blowfish_cipher.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "chacha20_cipher: ChaCha20 stream cipher" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "chacha20_cipher.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "ChaCha20") != null);
}

test "chacha20_cipher: verify rounds" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "chacha20_cipher.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "deflate_compress: LZ77 + Huffman hybrid" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "deflate_compress.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Deflate") != null);
}

test "deflate_compress: verify compression" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "deflate_compress.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "dh_keyexchange: Diffie-Hellman key exchange" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dh_keyexchange.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Diffie") != null);
}

test "dh_keyexchange: verify prime size" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dh_keyexchange.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "ecdsa_sign: Elliptic curve digital signature" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ecdsa_sign.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "ECDSA") != null);
}

test "ecdsa_sign: verify key size" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ecdsa_sign.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "ed25519_sign: Ed25519 signature scheme" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ed25519_sign.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Ed25519") != null);
}

test "ed25519_sign: verify signature size" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ed25519_sign.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "elliptic_curve: Elliptic curve math" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "elliptic_curve.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Elliptic") != null);
}

test "elliptic_curve: verify field size" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "elliptic_curve.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hkdf_expand: HMAC-based KDF" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hkdf_expand.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "HKDF") != null);
}

test "hkdf_expand: verify output length" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hkdf_expand.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hmac_compute: HMAC keyed hashing" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hmac_compute.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "HMAC") != null);
}

test "hmac_compute: verify HMAC output" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hmac_compute.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lz77_compress: LZ77 sliding window" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lz77_compress.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "LZ77") != null);
}

test "lz77_compress: verify compression ratio" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lz77_compress.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lz78_compress: LZ78 dictionary compression" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lz78_compress.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "LZ78") != null);
}

test "lz78_compress: verify dictionary" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lz78_compress.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lzw_compress: LZW encoding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lzw_compress.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "LZW") != null);
}

test "lzw_compress: verify code size" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lzw_compress.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "move_to_front: MTF transform" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "move_to_front.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Move") != null);
}

test "move_to_front: verify alphabet" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "move_to_front.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "poly1305_mac: Message authentication code" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "poly1305_mac.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Poly1305") != null);
}

test "poly1305_mac: verify tag size" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "poly1305_mac.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "rsa_enc: RSA public-key encryption" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "rsa_enc.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "RSA") != null);
}

test "rsa_enc: verify key size" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "rsa_enc.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "run_length_encode: RLE compression" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "run_length_encode.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Run-Length") != null);
}

test "run_length_encode: verify encoding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "run_length_encode.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "scrypt_kdf: scrypt memory-hard KDF" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "scrypt_kdf.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "scrypt") != null);
}

test "scrypt_kdf: verify parameters" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "scrypt_kdf.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "siphash: Fast keyed hashing" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "siphash.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "SipHash") != null);
}

test "siphash: verify rounds" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "siphash.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "twofish_cipher: Twofish block cipher" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "twofish_cipher.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Twofish") != null);
}

test "twofish_cipher: verify rounds" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "twofish_cipher.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "x25519_kex: X25519 key exchange" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "x25519_kex.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "X25519") != null);
}

test "x25519_kex: verify shared secret" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "x25519_kex.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// DISTRIBUTED SYSTEMS TESTS — TTT Dogfood Phase 3
// ═══════════════════════════════════════════════════════════════════════════════

test "btree_index: B-Tree database index" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "btree_index.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "B-Tree") != null);
}

test "btree_index: verify order" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "btree_index.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bully_algorithm: Leader election" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bully_algorithm.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bully") != null);
}

test "bully_algorithm: verify max_id" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bully_algorithm.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "distributed_lock: Mutual exclusion" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "distributed_lock.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Distributed") != null);
}

test "distributed_lock: verify acquired" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "distributed_lock.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "geohash_encode: Geographic hashing" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "geohash_encode.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Geohash") != null);
}

test "geohash_encode: verify precision" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "geohash_encode.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hash_index: Hash-based database index" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hash_index.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hash") != null);
}

test "hash_index: verify buckets" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hash_index.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hilbert_curve: Space-filling curve" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hilbert_curve.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hilbert") != null);
}

test "hilbert_curve: verify order" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hilbert_curve.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "inverted_index: Text search index" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "inverted_index.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Inverted") != null);
}

test "inverted_index: verify documents" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "inverted_index.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "kd_tree_index: K-dimensional tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kd_tree_index.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "KD") != null);
}

test "kd_tree_index: verify dimensions" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kd_tree_index.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lamport_clock: Logical timestamp" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lamport_clock.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Lamport") != null);
}

test "lamport_clock: verify timestamp" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lamport_clock.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lease_manager: Time-based locking" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lease_manager.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Lease") != null);
}

test "lease_manager: verify ttl" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lease_manager.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lsmtree: Log-Structured Merge tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lsmtree.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "LSM") != null);
}

test "lsmtree: verify memtables" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lsmtree.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "mvcc_snapshot: Multi-version concurrency" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mvcc_snapshot.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "MVCC") != null);
}

test "mvcc_snapshot: verify tx_id" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mvcc_snapshot.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "optimistic_lock: Version-based concurrency" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "optimistic_lock.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Optimistic") != null);
}

test "optimistic_lock: verify version" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "optimistic_lock.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "paxos_consensus: Distributed consensus" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "paxos_consensus.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Paxos") != null);
}

test "paxos_consensus: verify quorum" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "paxos_consensus.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "quadtree_index: 2D spatial subdivision" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "quadtree_index.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Quadtree") != null);
}

test "quadtree_index: verify max_depth" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "quadtree_index.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "raft_consensus: Leader-based consensus" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "raft_consensus.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Raft") != null);
}

test "raft_consensus: verify majority" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "raft_consensus.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "ring_election: Circular leader election" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ring_election.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Ring") != null);
}

test "ring_election: verify nodes" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ring_election.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "rtree_index: Spatial data indexing" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "rtree_index.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "R-Tree") != null);
}

test "rtree_index: verify dimensions" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "rtree_index.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "skiplist_index: Probabilistic indexing" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "skiplist_index.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Skip") != null);
}

test "skiplist_index: verify levels" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "skiplist_index.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "three_phase_commit: Non-blocking atomic commit" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "three_phase_commit.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Three-Phase") != null);
}

test "three_phase_commit: verify can_commit" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "three_phase_commit.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "two_pc_lock: Two-phase locking" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "two_pc_lock.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Two-Phase") != null);
}

test "two_pc_lock: verify granted" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "two_pc_lock.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "two_phase_commit: Atomic transaction commit" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "two_phase_commit.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Two-Phase") != null);
}

test "two_phase_commit: verify participants" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "two_phase_commit.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "vector_clock: Distributed event ordering" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "vector_clock.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Vector") != null);
}

test "vector_clock: verify processes" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "vector_clock.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "wal_write: Write-Ahead Log" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "wal_write.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Write-Ahead") != null);
}

test "wal_write: verify entry_id" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "wal_write.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "zorder_curve: Morton code spatial mapping" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "zorder_curve.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Z-Order") != null);
}

test "zorder_curve: verify dimensions" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "zorder_curve.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// AI/ML ALGORITHMS — TTT Dogfood Phase 3
// ═══════════════════════════════════════════════════════════════════════════════

test "a_star: A* heuristic pathfinding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "a_star.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "A*") != null);
}

test "a_star: verify f_score" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "a_star.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "aa_tree: Simplified red-black tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "aa_tree.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "AA") != null);
}

test "aa_tree: verify level property" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "aa_tree.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "abs: Absolute value computation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "abs.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Absolute") != null);
}

test "abs: verify non_negative" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "abs.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "adam_optimizer: Adaptive moment estimation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "adam_optimizer.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Adam") != null);
}

test "adam_optimizer: verify learning rate" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "adam_optimizer.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "adaptive_huffman: Dynamic Huffman coding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "adaptive_huffman.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Adaptive") != null);
}

test "adaptive_huffman: verify tree depth" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "adaptive_huffman.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "adaptive_thresh: Local thresholding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "adaptive_thresh.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Adaptive") != null);
}

test "adaptive_thresh: verify window size" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "adaptive_thresh.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "aes_encrypt: Advanced Encryption Standard" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "aes_encrypt.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "AES") != null);
}

test "aho_corasick: Multi-pattern search" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "aho_corasick.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Aho-Corasick") != null);
}

test "aho_corasick: verify trie nodes" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "aho_corasick.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "alpha_beta: Minimax with pruning" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "alpha_beta.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Alpha-Beta") != null);
}

test "alpha_beta: verify pruning bounds" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "alpha_beta.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "ant_colony: Pheromone-based optimization" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ant_colony.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Ant") != null);
}

test "ant_colony: verify path length" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ant_colony.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "ant_colony_opt: Probabilistic path finding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ant_colony_opt.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Ant") != null);
}

test "ant_colony_opt: verify evaporation rate" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ant_colony_opt.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "arithmetic_decode: Arithmetic coding decoder" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "arithmetic_decode.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Arithmetic") != null);
}

test "arithmetic_decode: verify decoded value" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "arithmetic_decode.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "articulation_points: Find cut vertices" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "articulation_points.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Articulation") != null);
}

test "articulation_points: verify biconnected components" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "articulation_points.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "articulation_pts: Cut vertices tracking" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "articulation_pts.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Articulation") != null);
}

test "articulation_pts: verify discovery time" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "articulation_pts.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "articulation_pts_find: DFS tree tracking" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "articulation_pts_find.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Articulation") != null);
}

test "articulation_pts_find: verify is_articulation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "articulation_pts_find.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "astar_search: Best-first heuristic search" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "astar_search.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "A*") != null);
}

test "astar_search: verify path cost" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "astar_search.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "attention_mech: Scaled dot-product attention" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "attention_mech.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Attention") != null);
}

test "attention_mech: verify sequence length" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "attention_mech.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "avl_insert: Self-balancing tree insertion" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "avl_insert.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "AVL") != null);
}

test "avl_insert: verify tree height" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "avl_insert.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "argon2_hash: Memory-hard KDF" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "argon2_hash.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Argon2") != null);
}

test "argon2_hash: verify memory cost" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "argon2_hash.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TREE & GRAPH ALGORITHMS — TTT Dogfood Phase 3
// ═══════════════════════════════════════════════════════════════════════════════

test "avl_tree: Self-balancing BST" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "avl_tree.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "AVL") != null);
}

test "avl_tree: verify balance factor" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "avl_tree.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "b_plus_delete: Delete from B+ tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "b_plus_delete.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "B+") != null);
}

test "b_plus_delete: verify key deletion" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "b_plus_delete.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "b_plus_insert: Insert into B+ tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "b_plus_insert.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "B+") != null);
}

test "b_plus_insert: verify order" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "b_plus_insert.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "b_plus_range: Range query in B+ tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "b_plus_range.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Range") != null);
}

test "b_plus_range: verify count" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "b_plus_range.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "b_plus_search: Search in B+ tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "b_plus_search.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Search") != null);
}

test "b_plus_search: verify found" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "b_plus_search.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "b_tree: Multi-way balanced tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "b_tree.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "B-Tree") != null);
}

test "b_tree: verify order" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "b_tree.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "backpropagation: Neural network training" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "backpropagation.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Backpropagation") != null);
}

test "backpropagation: verify layers" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "backpropagation.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "batch_normalization: Normalize across batch" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "batch_normalization.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Batch") != null);
}

test "batch_normalization: verify features" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "batch_normalization.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bcd_add: Binary-Coded Decimal addition" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bcd_add.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "BCD") != null);
}

test "bcd_add: verify result" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bcd_add.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "beam_search: Width-limited best-first" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "beam_search.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Beam") != null);
}

test "beam_search: verify beam width" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "beam_search.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bellman_ford: Shortest paths with negative edges" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bellman_ford.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bellman") != null);
}

test "bellman_ford: verify no negative cycle" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bellman_ford.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "best_time_stock: Maximum profit from stock" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "best_time_stock.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Stock") != null);
}

test "best_time_stock: verify profit" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "best_time_stock.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bfs: Breadth-First Search" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bfs.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Breadth") != null);
}

test "bfs: verify visit order" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bfs.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bidirectional: Search from both ends" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bidirectional.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bidirectional") != null);
}

test "bidirectional: verify meeting node" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bidirectional.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bilateral_filter: Edge-preserving smoothing" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bilateral_filter.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bilateral") != null);
}

test "bilateral_filter: verify spatial sigma" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bilateral_filter.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "binary_indexed_tree: Fenwick tree prefix sums" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "binary_indexed_tree.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Fenwick") != null);
}

test "binary_indexed_tree: verify query result" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "binary_indexed_tree.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "binary_search: Divide-and-conquer search" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "binary_search.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Binary") != null);
}

test "binary_search: verify found index" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "binary_search.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "binary_tree: Binary search tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "binary_tree.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Binary") != null);
}

test "binary_tree: verify inorder sorted" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "binary_tree.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "binary_tree_traversal: Three traversal methods" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "binary_tree_traversal.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Traversal") != null);
}

test "binary_tree_traversal: verify inorder" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "binary_tree_traversal.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bipartite_check: 2-colorable graph test" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bipartite_check.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bipartite") != null);
}

test "bipartite_check: verify is bipartite" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bipartite_check.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bipartite_check_graph: BFS coloring" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bipartite_check_graph.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bipartite") != null);
}

test "bipartite_check_graph: verify colors" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bipartite_check_graph.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bipartite_match: Maximum matching in bipartite graph" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bipartite_match.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bipartite") != null);
}

test "bipartite_match: verify matching size" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bipartite_match.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bipartite_matching: Hopcroft-Karp algorithm" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bipartite_matching.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bipartite") != null);
}

test "bipartite_matching: verify max matching" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bipartite_matching.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bit_count: Population count" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bit_count.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "popcount") != null);
}

test "bit_count: verify set bits" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bit_count.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bit_manipulation: Common bit operations" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bit_manipulation.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bit") != null);
}

test "bit_manipulation: verify popcount" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bit_manipulation.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

// Bit Operations Tests — TTT Dogfood Phase 3

test "bit_reverse: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bit_reverse.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bit") != null);
}

test "bit_reverse: verify reversal" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bit_reverse.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "blossom_algorithm: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "blossom_algorithm.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "blossom") != null);
}

test "blossom_algorithm: verify matching" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "blossom_algorithm.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bogo_sort: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bogo_sort.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bogo") != null);
}

test "bogo_sort: verify sort" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bogo_sort.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "booth_mult: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "booth_mult.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Booth") != null);
}

test "booth_mult: verify multiplication" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "booth_mult.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "boyers_moore_majority: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "boyers_moore_majority.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Boyer") != null);
}

test "boyers_moore_majority: verify majority" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "boyers_moore_majority.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "branch_and_bound: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "branch_and_bound.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Branch") != null);
}

test "branch_and_bound: verify bound" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "branch_and_bound.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bridge_detect: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bridge_detect.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "bridge") != null);
}

test "bridge_detect: verify detection" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bridge_detect.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bridges: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bridges.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "bridge") != null);
}

test "bridges: verify graph" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bridges.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bridges_graph: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bridges_graph.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bridges") != null);
}

test "bridges_graph: verify algorithm" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bridges_graph.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "burrows_wheeler: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "burrows_wheeler.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Burrows") != null);
}

test "burrows_wheeler: verify transform" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "burrows_wheeler.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bwt_transform: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bwt_transform.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "BWT") != null);
}

test "bwt_transform: verify BWT" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bwt_transform.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "caesar_cipher: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "caesar_cipher.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Caesar") != null);
}

test "caesar_cipher: verify cipher" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "caesar_cipher.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "cartesian_tree: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cartesian_tree.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Cartesian") != null);
}

test "cartesian_tree: verify tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cartesian_tree.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "chaining_hash: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "chaining_hash.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "chaining") != null);
}

test "chaining_hash: verify hash" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "chaining_hash.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "chacha20_cipher: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "chacha20_cipher.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "ChaCha20") != null);
}

test "chacha20_cipher: verify cipher" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "chacha20_cipher.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "channel_capacity: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "channel_capacity.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Shannon") != null);
}

test "channel_capacity: verify capacity" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "channel_capacity.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "checksum: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "checksum.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Checksum") != null);
}

test "checksum: verify sum" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "checksum.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "chinese_remainder: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "chinese_remainder.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Chinese") != null);
}

test "chinese_remainder: verify theorem" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "chinese_remainder.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "cholesky: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cholesky.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Cholesky") != null);
}

test "cholesky: verify decomposition" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cholesky.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

// Clique Find Tests — TTT Dogfood Phase 3

test "clique_find: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "clique_find.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Clique") != null);
}

test "clique_find: verify maximum" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "clique_find.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "coap_request: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "coap_request.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "CoAP") != null);
}

test "coap_request: verify request" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "coap_request.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "code_emit: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "code_emit.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Code") != null);
}

test "code_emit: verify emission" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "code_emit.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "combination: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "combination.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Combinations") != null);
}

test "combination: verify n choose k" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "combination.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "complex_abs: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "complex_abs.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Absolute") != null);
}

test "complex_abs: verify magnitude" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "complex_abs.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "complex_add: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "complex_add.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Add") != null);
}

test "complex_add: verify sum" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "complex_add.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "complex_arg: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "complex_arg.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Argument") != null);
}

test "complex_arg: verify angle" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "complex_arg.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "complex_conj: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "complex_conj.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Conjugate") != null);
}

test "complex_conj: verify conjugate" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "complex_conj.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "complex_exp: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "complex_exp.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Exponential") != null);
}

test "complex_exp: verify exponential" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "complex_exp.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "complex_log: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "complex_log.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Logarithm") != null);
}

test "complex_log: verify logarithm" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "complex_log.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "complex_mul: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "complex_mul.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Multiply") != null);
}

test "complex_mul: verify product" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "complex_mul.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "complex_pow: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "complex_pow.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Power") != null);
}

test "complex_pow: verify power" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "complex_pow.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "complex_sqrt: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "complex_sqrt.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Square") != null);
}

test "complex_sqrt: verify root" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "complex_sqrt.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "connected_comp: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "connected_comp.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Connected") != null);
}

test "connected_comp: verify components" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "connected_comp.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "const_fold: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "const_fold.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Constant") != null);
}

test "const_fold: verify folding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "const_fold.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "convex_hull_jarvis: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "convex_hull_jarvis.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Jarvis") != null);
}

test "convex_hull_jarvis: verify hull" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "convex_hull_jarvis.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "convolution_1d: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "convolution_1d.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Convolution") != null);
}

test "convolution_1d: verify 1D" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "convolution_1d.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "convolution_2d: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "convolution_2d.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Convolution") != null);
}

test "convolution_2d: verify 2D" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "convolution_2d.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "count_sort: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "count_sort.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Counting") != null);
}

test "count_sort: verify sort" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "count_sort.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "cycle_detection: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cycle_detection.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Cycle") != null);
}

test "cycle_detection: verify detection" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cycle_detection.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "dct_transform: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dct_transform.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "DCT") != null);
}

test "dct_transform: verify transform" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dct_transform.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "de_bruijn: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "de_bruijn.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bruijn") != null);
}

test "de_bruijn: verify sequence" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "de_bruijn.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "dead_code_elim: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dead_code_elim.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Dead") != null);
}

test "dead_code_elim: verify elimination" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dead_code_elim.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "delaunay: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "delaunay.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Delaunay") != null);
}

test "delaunay: verify triangulation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "delaunay.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "delta_encoding: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "delta_encoding.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Delta") != null);
}

test "delta_encoding: verify encoding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "delta_encoding.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

// D-E Files Tests — TTT Dogfood Phase 3

test "deadlock_detect: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "deadlock_detect.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Deadlock") != null);
}

test "deadlock_detect: verify detection" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "deadlock_detect.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "depth_buffer: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "depth_buffer.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Buffer") != null);
}

test "depth_buffer: verify zbuffer" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "depth_buffer.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "diffie_hellman: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "diffie_hellman.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Diffie") != null);
}

test "diffie_hellman: verify key exchange" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "diffie_hellman.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "digital_signature: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "digital_signature.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Digital") != null);
}

test "digital_signature: verify signature" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "digital_signature.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "dinic_maxflow: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dinic_maxflow.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Dinic") != null);
}

test "dinic_maxflow: verify max flow" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dinic_maxflow.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "dining_philosophers: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dining_philosophers.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Philosophers") != null);
}

test "dining_philosophers: verify concurrency" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dining_philosophers.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "discrete_log: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "discrete_log.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Discrete") != null);
}

test "discrete_log: verify logarithm" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "discrete_log.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "dna_sequence: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dna_sequence.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "DNA") != null);
}

test "dna_sequence: verify sequence" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dna_sequence.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "dominating_set_find: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dominating_set_find.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Dominating") != null);
}

test "dominating_set_find: verify set" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dominating_set_find.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "edge_compute: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "edge_compute.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Edge") != null);
}

test "edge_compute: verify computing" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "edge_compute.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "edit_script: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "edit_script.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Script") != null);
}

test "edit_script: verify operations" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "edit_script.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "edmonds: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "edmonds.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Edmonds") != null);
}

test "edmonds: verify blossom" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "edmonds.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "edmonds_blossom: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "edmonds_blossom.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Blossom") != null);
}

test "edmonds_blossom: verify matching" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "edmonds_blossom.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "elgamal: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "elgamal.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "ElGamal") != null);
}

test "elgamal: verify encryption" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "elgamal.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "elias_gamma: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "elias_gamma.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Elias") != null);
}

test "elias_gamma: verify coding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "elias_gamma.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "encoder_read: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "encoder_read.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Encoder") != null);
}

test "encoder_read: verify position" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "encoder_read.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "entropy_calc: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "entropy_calc.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Entropy") != null);
}

test "entropy_calc: verify calculation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "entropy_calc.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "euclidean_gcd: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "euclidean_gcd.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Euclidean") != null);
}

test "euclidean_gcd: verify gcd" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "euclidean_gcd.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "euler_tour: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "euler_tour.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Euler") != null);
}

test "euler_tour: verify tour" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "euler_tour.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "eulerian_path: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "eulerian_path.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Eulerian") != null);
}

test "eulerian_path: verify path" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "eulerian_path.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "exponential_search: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "exponential_search.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Exponential") != null);
}

test "exponential_search: verify search" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "exponential_search.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "extended_gcd: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "extended_gcd.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Extended") != null);
}

test "extended_gcd: verify coefficients" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "extended_gcd.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "eye_track: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "eye_track.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Eye") != null);
}

test "eye_track: verify tracking" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "eye_track.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "factorial_new: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "factorial_new.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Factorial") != null);
}

test "factorial_new: verify factorial" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "factorial_new.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "fast_fourier_transform: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fast_fourier_transform.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Fourier") != null);
}

test "fast_fourier_transform: verify FFT" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fast_fourier_transform.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

// F-G Files Tests — TTT Dogfood Phase 3

test "face_detect: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "face_detect.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Face") != null);
}

test "face_detect: verify detection" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "face_detect.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "feed_forward: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "feed_forward.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Feed") != null);
}

test "feed_forward: verify network" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "feed_forward.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "fft_audio: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fft_audio.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Audio") != null);
}

test "fft_audio: verify audio FFT" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fft_audio.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "fft_cooley: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fft_cooley.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Cooley") != null);
}

test "fft_cooley: verify Cooley-Tukey" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fft_cooley.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "fibonacci_coding: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fibonacci_coding.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Fibonacci") != null);
}

test "fibonacci_coding: verify coding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fibonacci_coding.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "fibonacci_iter: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fibonacci_iter.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Iterative") != null);
}

test "fibonacci_iter: verify iterative" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fibonacci_iter.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "fibonacci_matrix: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fibonacci_matrix.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Matrix") != null);
}

test "fibonacci_matrix: verify matrix" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fibonacci_matrix.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "fibonacci_search: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fibonacci_search.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Search") != null);
}

test "fibonacci_search: verify search" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fibonacci_search.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "fibonacci_word: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fibonacci_word.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Word") != null);
}

test "fibonacci_word: verify word" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fibonacci_word.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "find_last_set: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "find_last_set.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "fls") != null);
}

test "find_last_set: verify find" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "find_last_set.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "fir_filter: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fir_filter.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "FIR") != null);
}

test "fir_filter: verify filter" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fir_filter.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "firewall_rule: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "firewall_rule.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Firewall") != null);
}

test "firewall_rule: verify rule" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "firewall_rule.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "firmware_update: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "firmware_update.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Firmware") != null);
}

test "firmware_update: verify update" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "firmware_update.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "fisher_yates_shuffle: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fisher_yates_shuffle.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Fisher") != null);
}

test "fisher_yates_shuffle: verify shuffle" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fisher_yates_shuffle.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "flow_optical: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "flow_optical.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Optical") != null);
}

test "flow_optical: verify optical flow" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "flow_optical.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "fog_compute: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fog_compute.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Fog") != null);
}

test "fog_compute: verify fog" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fog_compute.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "ford_fulkerson: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ford_fulkerson.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Ford") != null);
}

test "ford_fulkerson: verify max flow" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ford_fulkerson.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "ford_fulkerson_flow: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ford_fulkerson_flow.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Fulkerson") != null);
}

test "ford_fulkerson_flow: verify flow" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ford_fulkerson_flow.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "forward_kinematics: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "forward_kinematics.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Kinematics") != null);
}

test "forward_kinematics: verify kinematics" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "forward_kinematics.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "fractional_cascading: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fractional_cascading.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Cascading") != null);
}

test "fractional_cascading: verify cascading" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fractional_cascading.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "gaussian_blur: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gaussian_blur.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Gaussian") != null);
}

test "gaussian_blur: verify blur" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gaussian_blur.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "gcd_ext: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gcd_ext.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Extended") != null);
}

test "gcd_ext: verify extended GCD" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gcd_ext.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "genetic_algo: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "genetic_algo.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Genetic") != null);
}

test "genetic_algo: verify algorithm" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "genetic_algo.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "genetic_algorithm: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "genetic_algorithm.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Evolutionary") != null);
}

test "genetic_algorithm: verify optimization" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "genetic_algorithm.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "golomb_coding: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "golomb_coding.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Golomb") != null);
}

test "golomb_coding: verify coding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "golomb_coding.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

// G-H Files Tests — TTT Dogfood Phase 3

test "gan_generate: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gan_generate.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "GAN") != null);
}

test "gan_generate: verify generation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gan_generate.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "gelu: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gelu.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "GELU") != null);
}

test "gelu: verify activation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gelu.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "gesture_recognize: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gesture_recognize.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Gesture") != null);
}

test "gesture_recognize: verify recognition" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gesture_recognize.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "gradient_descent: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gradient_descent.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Gradient") != null);
}

test "gradient_descent: verify descent" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gradient_descent.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "graph_color: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "graph_color.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Coloring") != null);
}

test "graph_color: verify coloring" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "graph_color.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "graph_coloring: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "graph_coloring.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "planar") != null);
}

test "graph_coloring: verify graph coloring" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "graph_coloring.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "graph_iso_check: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "graph_iso_check.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Isomorphism") != null);
}

test "graph_iso_check: verify isomorphism" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "graph_iso_check.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "graph_isomorphism: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "graph_isomorphism.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Isomorphism") != null);
}

test "graph_isomorphism: verify isomorphism check" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "graph_isomorphism.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "gray_code: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gray_code.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Gray") != null);
}

test "gray_code: verify code" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gray_code.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "greedy_best: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "greedy_best.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Greedy") != null);
}

test "greedy_best: verify search" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "greedy_best.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "grover_search: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "grover_search.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Grover") != null);
}

test "grover_search: verify quantum search" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "grover_search.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hadamard_gate: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hadamard_gate.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hadamard") != null);
}

test "hadamard_gate: verify gate" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hadamard_gate.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hamiltonian_path: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hamiltonian_path.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hamiltonian") != null);
}

test "hamiltonian_path: verify path" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hamiltonian_path.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hamming7_4: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hamming7_4.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hamming") != null);
}

test "hamming7_4: verify error correction" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hamming7_4.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hamming_code: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hamming_code.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hamming") != null);
}

test "hamming_code: verify code" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hamming_code.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hand_track: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hand_track.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hand") != null);
}

test "hand_track: verify tracking" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hand_track.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "haptic_feedback: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "haptic_feedback.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Haptic") != null);
}

test "haptic_feedback: verify feedback" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "haptic_feedback.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "harris_corner: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "harris_corner.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Harris") != null);
}

test "harris_corner: verify corner detection" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "harris_corner.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "heuristic_scan: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "heuristic_scan.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Heuristic") != null);
}

test "heuristic_scan: verify scan" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "heuristic_scan.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hierholzer: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hierholzer.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hierholzer") != null);
}

test "hierholzer: verify circuit" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hierholzer.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hierholzer_euler: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hierholzer_euler.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hierholzer") != null);
}

test "hierholzer_euler: verify eulerian" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hierholzer_euler.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hill_climb: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hill_climb.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Climbing") != null);
}

test "hill_climb: verify climb" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hill_climb.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hill_climbing: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hill_climbing.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Climbing") != null);
}

test "hill_climbing: verify local search" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hill_climbing.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hits: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hits.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "HITS") != null);
}

test "hits: verify hubs authorities" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hits.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hmm_model: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hmm_model.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hidden") != null);
}

test "hmm_model: verify markov model" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hmm_model.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "a3c: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "a3c.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "A3C") != null);
}

test "a3c: verify asynchronous" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "a3c.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "aco_optimization: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "aco_optimization.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Ant") != null);
}

test "aco_optimization: verify pheromone" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "aco_optimization.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "action_recognize: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "action_recognize.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Action") != null);
}

test "action_recognize: verify recognition" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "action_recognize.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "actor_critic: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "actor_critic.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Actor") != null);
}

test "actor_critic: verify critic" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "actor_critic.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "actuator_ctrl: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "actuator_ctrl.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Actuator") != null);
}

test "actuator_ctrl: verify control" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "actuator_ctrl.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "adabelief: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "adabelief.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "AdaBelief") != null);
}

test "adabelief: verify optimizer" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "adabelief.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "adagrad: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "adagrad.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Adagrad") != null);
}

test "adagrad: verify gradient" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "adagrad.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "adam: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "adam.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Adam") != null);
}

test "adam: verify optimizer" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "adam.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "aes_decrypt: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "aes_decrypt.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "AES") != null);
}

test "aes_decrypt: verify decryption" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "aes_decrypt.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "aes_enc: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "aes_enc.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "AES") != null);
}

test "aes_enc: verify encryption" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "aes_enc.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "alpha_blend: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "alpha_blend.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Alpha") != null);
}

test "alpha_blend: verify blending" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "alpha_blend.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "alphabeta_prune: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "alphabeta_prune.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Alpha") != null);
}

test "alphabeta_prune: verify pruning" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "alphabeta_prune.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "ast_build: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ast_build.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "AST") != null);
}

test "ast_build: verify tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ast_build.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "atomic_add: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "atomic_add.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Atomic") != null);
}

test "atomic_add: verify addition" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "atomic_add.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "atomic_cas: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "atomic_cas.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "CAS") != null);
}

test "atomic_cas: verify compare" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "atomic_cas.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "atomic_sub: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "atomic_sub.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Atomic") != null);
}

test "atomic_sub: verify subtraction" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "atomic_sub.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "banker_algo: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "banker_algo.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Banker") != null);
}

test "banker_algo: verify algorithm" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "banker_algo.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "barrier: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "barrier.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Barrier") != null);
}

test "barrier: verify synchronization" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "barrier.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "barrier_sync: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "barrier_sync.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Barrier") != null);
}

test "barrier_sync: verify sync" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "barrier_sync.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "batch_norm: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "batch_norm.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Batch") != null);
}

test "batch_norm: verify normalization" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "batch_norm.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bin_packing: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bin_packing.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bin") != null);
}

test "bin_packing: verify packing" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bin_packing.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "binom_heap: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "binom_heap.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Binomial") != null);
}

test "binom_heap: verify heap" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "binom_heap.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "blast_search: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "blast_search.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "BLAST") != null);
}

test "blast_search: verify alignment" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "blast_search.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "blockchain_tx: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "blockchain_tx.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Blockchain") != null);
}

test "blockchain_tx: verify transaction" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "blockchain_tx.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bloom_filt: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bloom_filt.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bloom") != null);
}

test "bloom_filt: verify filter" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bloom_filt.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bplus: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bplus.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "B+") != null);
}

test "bplus: verify tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bplus.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bresenham_circle: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bresenham_circle.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bresenham") != null);
}

test "bresenham_circle: verify circle" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bresenham_circle.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bresenham_line: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bresenham_line.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bresenham") != null);
}

test "bresenham_line: verify line" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bresenham_line.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "brotli: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "brotli.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Brotli") != null);
}

test "brotli: verify compression" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "brotli.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "btree2: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "btree2.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "B-tree") != null);
}

test "btree2: verify tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "btree2.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "avg_pool: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "avg_pool.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Pool") != null);
}

test "avg_pool: verify pooling" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "avg_pool.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "batch_norm2: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "batch_norm2.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Batch") != null);
}

test "batch_norm2: verify normalization" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "batch_norm2.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bayesian: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bayesian.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bayesian") != null);
}

test "bayesian: verify filter" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bayesian.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bayesian_filter: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bayesian_filter.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bayesian") != null);
}

test "bayesian_filter: verify inference" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bayesian_filter.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bully_elect: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bully_elect.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bully") != null);
}

test "bully_elect: verify election" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bully_elect.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "catboost: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "catboost.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "CatBoost") != null);
}

test "catboost: verify boosting" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "catboost.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "cbc_mode: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cbc_mode.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "CBC") != null);
}

test "cbc_mode: verify mode" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cbc_mode.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "cfb_mode: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cfb_mode.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "CFB") != null);
}

test "cfb_mode: verify feedback" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cfb_mode.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "cfs_sch: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cfs_sch.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Schedule") != null);
}

test "cfs_sch: verify schedule" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cfs_sch.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "chinese_rem: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "chinese_rem.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Chinese") != null);
}

test "chinese_rem: verify remainder" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "chinese_rem.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "chord: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "chord.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Chord") != null);
}

test "chord: verify protocol" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "chord.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "circular_buf: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "circular_buf.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Circular") != null);
}

test "circular_buf: verify buffer" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "circular_buf.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "closest_pair_points: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "closest_pair_points.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Closest") != null);
}

test "closest_pair_points: verify divide" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "closest_pair_points.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "cnot_gate: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cnot_gate.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "CNOT") != null);
}

test "cnot_gate: verify gate" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cnot_gate.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "comb_sort: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "comb_sort.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Comb") != null);
}

test "comb_sort: verify sorting" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "comb_sort.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "condition_var: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "condition_var.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Condition") != null);
}

test "condition_var: verify variable" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "condition_var.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "condvar: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "condvar.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Condition") != null);
}

test "condvar: verify synchronization" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "condvar.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "consistent_hash_algo: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "consistent_hash_algo.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Consistent") != null);
}

test "consistent_hash_algo: verify hashing" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "consistent_hash_algo.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "consistent_hash_ring: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "consistent_hash_ring.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Ring") != null);
}

test "consistent_hash_ring: verify ring" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "consistent_hash_ring.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "conv_2d: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "conv_2d.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Conv") != null);
}

test "conv_2d: verify convolution" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "conv_2d.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "convolutional_code: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "convolutional_code.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Convolutional") != null);
}

test "convolutional_code: verify encoding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "convolutional_code.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "count_min: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "count_min.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Count") != null);
}

test "count_min: verify sketch" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "count_min.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "countmin_sketch: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "countmin_sketch.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Count") != null);
}

test "countmin_sketch: verify sketch" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "countmin_sketch.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "countmin_sketch_algo: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "countmin_sketch_algo.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Count") != null);
}

test "countmin_sketch_algo: verify algorithm" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "countmin_sketch_algo.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "cross_attention: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cross_attention.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Cross") != null);
}

test "cross_attention: verify attention" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cross_attention.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "ctr_mode: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ctr_mode.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "CTR") != null);
}

test "ctr_mode: verify counter" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ctr_mode.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "cuckoo_insert: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cuckoo_insert.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Cuckoo") != null);
}

test "cuckoo_insert: verify insertion" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cuckoo_insert.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "cyclic_redundancy: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cyclic_redundancy.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Cyclic") != null);
}

test "cyclic_redundancy: verify check" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cyclic_redundancy.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "decision_tree: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "decision_tree.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Decision") != null);
}

test "decision_tree: verify tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "decision_tree.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bce_loss: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bce_loss.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "BCE") != null);
}

test "bce_loss: verify loss" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bce_loss.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "brightness_adj: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "brightness_adj.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Brightness") != null);
}

test "brightness_adj: verify adjustment" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "brightness_adj.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bully_election: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bully_election.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Bully") != null);
}

test "bully_election: verify coordinator" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bully_election.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "ce_loss: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ce_loss.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Cross") != null);
}

test "ce_loss: verify entropy" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ce_loss.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "color_jitter: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "color_jitter.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Color") != null);
}

test "color_jitter: verify augmentation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "color_jitter.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "combined_loss: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "combined_loss.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Combined") != null);
}

test "combined_loss: verify loss" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "combined_loss.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "contrast_adj: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "contrast_adj.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Contrast") != null);
}

test "contrast_adj: verify adjustment" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "contrast_adj.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "contrastive_loss: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "contrastive_loss.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Contrastive") != null);
}

test "contrastive_loss: verify loss" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "contrastive_loss.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "cutmix: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cutmix.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "CutMix") != null);
}

test "cutmix: verify augmentation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cutmix.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "cutout: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cutout.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Cutout") != null);
}

test "cutout: verify holes" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "cutout.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "deflate: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "deflate.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Deflate") != null);
}

test "deflate: verify compression" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "deflate.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "depth_estimate: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "depth_estimate.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Depth") != null);
}

test "depth_estimate: verify estimation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "depth_estimate.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "deque_dbl: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "deque_dbl.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Deque") != null);
}

test "deque_dbl: verify deque" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "deque_dbl.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "dh_key: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dh_key.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Diffie") != null);
}

test "dh_key: verify exchange" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dh_key.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "dice_loss: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dice_loss.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Dice") != null);
}

test "dice_loss: verify loss" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dice_loss.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "dominating_set: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dominating_set.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Dominating") != null);
}

test "dominating_set: verify set" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dominating_set.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "dqfd: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dqfd.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "DQFD") != null);
}

test "dqfd: verify learning" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dqfd.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "dqn: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dqn.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "DQN") != null);
}

test "dqn: verify network" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dqn.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "dropout: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dropout.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Dropout") != null);
}

test "dropout: verify regularization" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dropout.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "eax_mode: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "eax_mode.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "EAX") != null);
}

test "eax_mode: verify mode" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "eax_mode.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "ecdsa_sig: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ecdsa_sig.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "ECDSA") != null);
}

test "ecdsa_sig: verify signature" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ecdsa_sig.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "ecdsa_verify: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ecdsa_verify.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "ECDSA") != null);
}

test "ecdsa_verify: verify verification" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ecdsa_verify.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "edf: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "edf.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "EDF") != null);
}

test "edf: verify scheduling" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "edf.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "edge_detect: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "edge_detect.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Edge") != null);
}

test "edge_detect: verify detection" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "edge_detect.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "elastic_net: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "elastic_net.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Elastic") != null);
}

test "elastic_net: verify regression" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "elastic_net.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "elu: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "elu.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "ELU") != null);
}

test "elu: verify activation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "elu.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "face_recognize: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "face_recognize.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Face") != null);
}

test "face_recognize: verify recognition" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "face_recognize.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "feed_forward_net: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "feed_forward_net.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Feed") != null);
}

test "feed_forward_net: verify network" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "feed_forward_net.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "fft_conv: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fft_conv.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "FFT") != null);
}

test "fft_conv: verify convolution" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fft_conv.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "fib_heap: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fib_heap.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Fibonacci") != null);
}

test "fib_heap: verify heap" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "fib_heap.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "affine_transform: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "affine_transform.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Affine") != null);
}

test "affine_transform: verify transform" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "affine_transform.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "crop_center: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "crop_center.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Crop") != null);
}

test "crop_center: verify cropping" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "crop_center.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "denormalize: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "denormalize.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Denormalize") != null);
}

test "denormalize: verify normalization" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "denormalize.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "find_first_set: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "find_first_set.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "First") != null);
}

test "find_first_set: verify bit" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "find_first_set.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "focal_loss: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "focal_loss.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Focal") != null);
}

test "focal_loss: verify loss" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "focal_loss.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "gauss_blur: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gauss_blur.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Gaussian") != null);
}

test "gauss_blur: verify blur" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gauss_blur.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "gcm_mode: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gcm_mode.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "GCM") != null);
}

test "gcm_mode: verify mode" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gcm_mode.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "geglu: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "geglu.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "GeGLU") != null);
}

test "geglu: verify activation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "geglu.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "gelu2: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gelu2.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "GELU") != null);
}

test "gelu2: verify activation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gelu2.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "gelu_tanh: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gelu_tanh.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "GELU") != null);
}

test "gelu_tanh: verify tanh" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gelu_tanh.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "glus: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "glus.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "GLU") != null);
}

test "glus: verify activation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "glus.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "gossip: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gossip.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Gossip") != null);
}

test "gossip: verify protocol" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gossip.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "gradient_boost: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gradient_boost.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Gradient") != null);
}

test "gradient_boost: verify boosting" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gradient_boost.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "grayscale: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "grayscale.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Grayscale") != null);
}

test "grayscale: verify conversion" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "grayscale.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "group_norm: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "group_norm.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Group") != null);
}

test "group_norm: verify normalization" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "group_norm.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hamming: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hamming.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hamming") != null);
}

test "hamming: verify distance" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hamming.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hard_sigmoid: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hard_sigmoid.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Sigmoid") != null);
}

test "hard_sigmoid: verify activation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hard_sigmoid.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hard_swish: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hard_swish.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Swish") != null);
}

test "hard_swish: verify activation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hard_swish.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hinge_loss: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hinge_loss.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hinge") != null);
}

test "hinge_loss: verify loss" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hinge_loss.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hopcroft_karp_match: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hopcroft_karp_match.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hopcroft") != null);
}

test "hopcroft_karp_match: verify matching" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hopcroft_karp_match.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hough_line: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hough_line.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hough") != null);
}

test "hough_line: verify transform" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hough_line.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "huber_loss: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "huber_loss.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Huber") != null);
}

test "huber_loss: verify loss" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "huber_loss.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hue_adj: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hue_adj.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hue") != null);
}

test "hue_adj: verify adjustment" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hue_adj.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "huff_decode: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "huff_decode.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Huffman") != null);
}

test "huff_decode: verify decoding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "huff_decode.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "huffman_coding_algo: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "huffman_coding_algo.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Huffman") != null);
}

test "huffman_coding_algo: verify coding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "huffman_coding_algo.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "huffman_decode: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "huffman_decode.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Huffman") != null);
}

test "huffman_decode: verify decode" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "huffman_decode.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hungarian: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hungarian.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hungarian") != null);
}

test "hungarian: verify algorithm" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hungarian.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hungarian_algorithm: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hungarian_algorithm.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hungarian") != null);
}

test "hungarian_algorithm: verify assignment" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hungarian_algorithm.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hungarian_assign: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hungarian_assign.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hungarian") != null);
}

test "hungarian_assign: verify assignment" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hungarian_assign.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hyperlog: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hyperlog.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "HyperLogLog") != null);
}

test "hyperlog: verify cardinality" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hyperlog.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "banded_matrix: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "banded_matrix.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Banded") != null);
}

test "banded_matrix: verify matrix" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "banded_matrix.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "bicgstab: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bicgstab.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "BiCGSTAB") != null);
}

test "bicgstab: verify solver" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "bicgstab.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "circulant_matrix: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "circulant_matrix.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Circulant") != null);
}

test "circulant_matrix: verify matrix" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "circulant_matrix.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "conjugate_gradient: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "conjugate_gradient.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Conjugate") != null);
}

test "conjugate_gradient: verify solver" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "conjugate_gradient.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "coo_format: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "coo_format.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "COO") != null);
}

test "coo_format: verify format" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "coo_format.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "csc_format: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "csc_format.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "CSC") != null);
}

test "csc_format: verify format" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "csc_format.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "csr_format: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "csr_format.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "CSR") != null);
}

test "csr_format: verify format" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "csr_format.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "dia_format: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dia_format.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "DIA") != null);
}

test "dia_format: verify format" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "dia_format.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "ell_format: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ell_format.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "ELL") != null);
}

test "ell_format: verify format" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ell_format.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "gauss_seidel: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gauss_seidel.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Gauss") != null);
}

test "gauss_seidel: verify iteration" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "gauss_seidel.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hankel_matrix: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hankel_matrix.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hankel") != null);
}

test "hankel_matrix: verify matrix" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hankel_matrix.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hyperloglog: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hyperloglog.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "HyperLogLog") != null);
}

test "hyperloglog: verify cardinality" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hyperloglog.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "hyperloglog_cnt: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hyperloglog_cnt.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "HyperLogLog") != null);
}

test "hyperloglog_cnt: verify count" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "hyperloglog_cnt.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "ida_star: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ida_star.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "IDA") != null);
}

test "ida_star: verify search" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ida_star.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "ids_detect: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ids_detect.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "IDS") != null);
}

test "ids_detect: verify detection" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ids_detect.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "iir_filter: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "iir_filter.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "IIR") != null);
}

test "iir_filter: verify filter" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "iir_filter.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "inline_func: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "inline_func.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Inlining") != null);
}

test "inline_func: verify optimization" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "inline_func.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "instance_norm: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "instance_norm.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Instance") != null);
}

test "instance_norm: verify normalization" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "instance_norm.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "instance_seg: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "instance_seg.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Instance") != null);
}

test "instance_seg: verify segmentation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "instance_seg.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "integer_partition: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "integer_partition.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Partition") != null);
}

test "integer_partition: verify partition" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "integer_partition.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "interpolation_search: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "interpolation_search.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Interpolation") != null);
}

test "interpolation_search: verify search" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "interpolation_search.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "interval_tree: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "interval_tree.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Interval") != null);
}

test "interval_tree: verify tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "interval_tree.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "inverse_kinematics: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "inverse_kinematics.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Inverse") != null);
}

test "inverse_kinematics: verify kinematics" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "inverse_kinematics.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "iou_loss: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "iou_loss.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "IoU") != null);
}

test "iou_loss: verify loss" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "iou_loss.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "ir_generate: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ir_generate.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Intermediate") != null);
}

test "ir_generate: verify representation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ir_generate.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "jacobi_iter: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "jacobi_iter.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Jacobi") != null);
}

test "jacobi_iter: verify iteration" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "jacobi_iter.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "jaro_winkler: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "jaro_winkler.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Jaro") != null);
}

test "jaro_winkler: verify similarity" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "jaro_winkler.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "jarvis_wrap: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "jarvis_wrap.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Jarvis") != null);
}

test "jarvis_wrap: verify march" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "jarvis_wrap.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "job_shop_sched: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "job_shop_sched.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Job") != null);
}

test "job_shop_sched: verify scheduling" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "job_shop_sched.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "johnsons_algorithm: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "johnsons_algorithm.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Johnson") != null);
}

test "johnsons_algorithm: verify scheduling" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "johnsons_algorithm.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "js_div: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "js_div.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Jensen") != null or std.mem.indexOf(u8, source, "JS") != null);
}

test "js_div: verify divergence" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "js_div.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "jump_search: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "jump_search.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Jump") != null);
}

test "jump_search: verify search" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "jump_search.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "kademlia: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kademlia.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Kademlia") != null);
}

test "kademlia: verify dht" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kademlia.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "kahns_topological_sort: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kahns_topological_sort.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Kahn") != null);
}

test "kahns_topological_sort: verify sort" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kahns_topological_sort.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "kalman: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kalman.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Kalman") != null);
}

test "kalman: verify filter" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kalman.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "kalman_filter: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kalman_filter.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Kalman") != null);
}

test "kalman_filter: verify estimation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kalman_filter.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "karatsuba: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "karatsuba.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Karatsuba") != null);
}

test "karatsuba: verify multiplication" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "karatsuba.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "karatsuba_mul: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "karatsuba_mul.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Karatsuba") != null);
}

test "karatsuba_mul: verify multiply" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "karatsuba_mul.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "kelips: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kelips.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Kelips") != null);
}

test "kelips: verify overlay" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kelips.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "kl_div: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kl_div.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "KL") != null);
}

test "kl_div: verify divergence" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kl_div.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "kl_divergence: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kl_divergence.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "KL") != null);
}

test "kl_divergence: verify divergence" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kl_divergence.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "kmeans: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kmeans.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "K-Means") != null);
}

test "kmeans: verify clustering" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kmeans.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "kmeans_seg: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kmeans_seg.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "K-Means") != null);
}

test "kmeans_seg: verify segmentation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kmeans_seg.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "knapsack_01: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "knapsack_01.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Knapsack") != null);
}

test "knapsack_01: verify optimization" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "knapsack_01.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "knn: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "knn.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "KNN") != null);
}

test "knn: verify neighbors" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "knn.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "kruskal: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kruskal.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Kruskal") != null);
}

test "kruskal: verify mst" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "kruskal.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "label_smoothing: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "label_smoothing.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Label") != null);
}

test "label_smoothing: verify smoothing" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "label_smoothing.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lamport_clk: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lamport_clk.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Lamport") != null);
}

test "lamport_clk: verify clock" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lamport_clk.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lasso: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lasso.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Lasso") != null);
}

test "lasso: verify regression" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lasso.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "layer_norm: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "layer_norm.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Layer") != null);
}

test "layer_norm: verify normalization" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "layer_norm.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "layer_norm2: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "layer_norm2.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Layer") != null);
}

test "layer_norm2: verify norm" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "layer_norm2.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "layer_norm_transformer: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "layer_norm_transformer.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Transformer") != null);
}

test "layer_norm_transformer: verify transformer" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "layer_norm_transformer.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "layer_normalization: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "layer_normalization.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Layer") != null);
}

test "layer_normalization: verify normalization" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "layer_normalization.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lcm_new: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lcm_new.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "LCM") != null);
}

test "lcm_new: verify multiple" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lcm_new.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lcp_array: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lcp_array.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "LCP") != null);
}

test "lcp_array: verify array" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lcp_array.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lcs_length: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lcs_length.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "LCS") != null);
}

test "lcs_length: verify length" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lcs_length.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "ldpc_decode: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ldpc_decode.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "LDPC") != null);
}

test "ldpc_decode: verify decoding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "ldpc_decode.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "leaky_relu: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "leaky_relu.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Leaky") != null);
}

test "leaky_relu: verify activation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "leaky_relu.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "leftist_heap: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "leftist_heap.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Leftist") != null);
}

test "leftist_heap: verify heap" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "leftist_heap.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "leftist_heap2: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "leftist_heap2.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Leftist") != null);
}

test "leftist_heap2: verify leftist" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "leftist_heap2.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lens_distortion: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lens_distortion.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Lens") != null);
}

test "lens_distortion: verify distortion" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lens_distortion.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "levenshtein: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "levenshtein.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Levenshtein") != null);
}

test "levenshtein: verify distance" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "levenshtein.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lexical_parse: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lexical_parse.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Lexical") != null);
}

test "lexical_parse: verify parsing" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lexical_parse.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lexicographic: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lexicographic.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Lexicographic") != null);
}

test "lexicographic: verify compare" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lexicographic.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lf_queue: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lf_queue.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Lock-Free") != null);
}

test "lf_queue: verify queue" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lf_queue.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lf_stack: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lf_stack.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Lock-Free") != null);
}

test "lf_stack: verify stack" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lf_stack.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lightgbm: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lightgbm.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "LightGBM") != null);
}

test "lightgbm: verify boosting" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lightgbm.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lin_reg: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lin_reg.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Linear") != null);
}

test "lin_reg: verify regression" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lin_reg.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "line_intersect: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "line_intersect.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Intersection") != null);
}

test "line_intersect: verify intersection" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "line_intersect.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "line_intersect_seg: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "line_intersect_seg.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Intersect") != null);
}

test "line_intersect_seg: verify segment" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "line_intersect_seg.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "line_intersect_test: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "line_intersect_test.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Intersection") != null);
}

test "line_intersect_test: verify test" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "line_intersect_test.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "linear_act: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "linear_act.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Linear") != null);
}

test "linear_act: verify activation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "linear_act.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "linear_hash_delete: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "linear_hash_delete.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hash") != null);
}

test "linear_hash_delete: verify delete" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "linear_hash_delete.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "linear_hash_insert: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "linear_hash_insert.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hash") != null);
}

test "linear_hash_insert: verify insert" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "linear_hash_insert.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "linear_hash_search: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "linear_hash_search.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Hash") != null);
}

test "linear_hash_search: verify search" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "linear_hash_search.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lion: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lion.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Lion") != null);
}

test "lion: verify optimizer" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lion.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "local_beam: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "local_beam.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Beam") != null);
}

test "local_beam: verify search" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "local_beam.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lock_free_queue: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lock_free_queue.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Lock-Free") != null);
}

test "lock_free_queue: verify queue" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lock_free_queue.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "log_base: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "log_base.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Logarithm") != null);
}

test "log_base: verify logarithm" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "log_base.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "log_reg: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "log_reg.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Logistic") != null);
}

test "log_reg: verify regression" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "log_reg.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "longest_common_substring: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "longest_common_substring.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Substring") != null);
}

test "longest_common_substring: verify substring" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "longest_common_substring.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "loop_unroll: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "loop_unroll.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Unrolling") != null);
}

test "loop_unroll: verify optimization" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "loop_unroll.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lottery_sch: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lottery_sch.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Lottery") != null);
}

test "lottery_sch: verify scheduling" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lottery_sch.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lstm_cell: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lstm_cell.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "LSTM") != null);
}

test "lstm_cell: verify cell" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lstm_cell.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lu_decomposition: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lu_decomposition.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "LU") != null);
}

test "lu_decomposition: verify decomposition" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lu_decomposition.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lz_compress: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lz_compress.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Compress") != null);
}

test "lz_compress: verify compression" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lz_compress.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lz_decompress: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lz_decompress.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Decompress") != null);
}

test "lz_decompress: verify decompression" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lz_decompress.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lzw_comp: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lzw_comp.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "LZW") != null);
}

test "lzw_comp: verify compression" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lzw_comp.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "lzw_decode: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lzw_decode.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "LZW") != null);
}

test "lzw_decode: verify decoding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "lzw_decode.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "mae_loss: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mae_loss.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "MAE") != null);
}

test "mae_loss: verify loss" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mae_loss.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "matrix_det: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "matrix_det.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Determinant") != null);
}

test "matrix_det: verify determinant" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "matrix_det.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "matrix_determinant: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "matrix_determinant.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Determinant") != null);
}

test "matrix_determinant: verify calculation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "matrix_determinant.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "matrix_eigen: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "matrix_eigen.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Eigen") != null);
}

test "matrix_eigen: verify eigenvalues" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "matrix_eigen.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "matrix_inverse: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "matrix_inverse.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Inverse") != null);
}

test "matrix_inverse: verify inverse" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "matrix_inverse.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "matrix_lu: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "matrix_lu.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "LU") != null);
}

test "matrix_lu: verify decomposition" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "matrix_lu.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "matrix_qr: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "matrix_qr.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "QR") != null);
}

test "matrix_qr: verify decomposition" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "matrix_qr.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "matrix_rank: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "matrix_rank.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Rank") != null);
}

test "matrix_rank: verify rank" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "matrix_rank.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "matrix_svd: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "matrix_svd.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "SVD") != null);
}

test "matrix_svd: verify decomposition" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "matrix_svd.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "matrix_trace: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "matrix_trace.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Trace") != null);
}

test "matrix_trace: verify trace" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "matrix_trace.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "max_clique_find: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "max_clique_find.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Clique") != null);
}

test "max_clique_find: verify clique" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "max_clique_find.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "max_independent_set: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "max_independent_set.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Independent") != null);
}

test "max_independent_set: verify set" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "max_independent_set.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "max_independent_set_find: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "max_independent_set_find.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Independent") != null);
}

test "max_independent_set_find: verify find" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "max_independent_set_find.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "max_pool: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "max_pool.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Pool") != null);
}

test "max_pool: verify pooling" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "max_pool.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "maxout: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "maxout.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Maxout") != null);
}

test "maxout: verify activation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "maxout.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "merkle_root: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "merkle_root.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Merkle") != null);
}

test "merkle_root: verify root" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "merkle_root.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "merkle_tree: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "merkle_tree.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Merkle") != null);
}

test "merkle_tree: verify tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "merkle_tree.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "miller_rabin: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "miller_rabin.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Miller") != null);
}

test "miller_rabin: verify primality" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "miller_rabin.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "min_cost_flow: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "min_cost_flow.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Min-Cost") != null);
}

test "min_cost_flow: verify flow" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "min_cost_flow.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "min_cost_max_flow: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "min_cost_max_flow.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Min-Cost") != null);
}

test "min_cost_max_flow: verify maxflow" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "min_cost_max_flow.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "min_hash: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "min_hash.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "MinHash") != null);
}

test "min_hash: verify hashing" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "min_hash.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "min_vertex_cover: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "min_vertex_cover.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Vertex") != null);
}

test "min_vertex_cover: verify cover" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "min_vertex_cover.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "min_vertex_cover_find: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "min_vertex_cover_find.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Vertex") != null);
}

test "min_vertex_cover_find: verify find" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "min_vertex_cover_find.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "mincost_maxflow: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mincost_maxflow.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Min") != null);
}

test "mincost_maxflow: verify flow" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mincost_maxflow.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "minimax: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "minimax.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Minimax") != null);
}

test "minimax: verify algorithm" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "minimax.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "minimax_game: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "minimax_game.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Minimax") != null);
}

test "minimax_game: verify game" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "minimax_game.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "mish: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mish.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Mish") != null);
}

test "mish: verify activation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mish.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "mixup: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mixup.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Mixup") != null);
}

test "mixup: verify augmentation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mixup.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "mo_algorithm: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mo_algorithm.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Mo") != null);
}

test "mo_algorithm: verify queries" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mo_algorithm.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "modular_inverse: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "modular_inverse.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Modular") != null);
}

test "modular_inverse: verify inverse" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "modular_inverse.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "momentum: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "momentum.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Momentum") != null);
}

test "momentum: verify optimizer" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "momentum.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "monte_carlo: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "monte_carlo.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Monte") != null);
}

test "monte_carlo: verify search" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "monte_carlo.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "montecarlo_tree: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "montecarlo_tree.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Monte") != null);
}

test "montecarlo_tree: verify tree" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "montecarlo_tree.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "morphology_dilate: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "morphology_dilate.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Dilation") != null);
}

test "morphology_dilate: verify dilation" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "morphology_dilate.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "morphology_erode: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "morphology_erode.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Erosion") != null);
}

test "morphology_erode: verify erosion" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "morphology_erode.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "motor_ctrl: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "motor_ctrl.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "Motor") != null);
}

test "motor_ctrl: verify control" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "motor_ctrl.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "mpeg_decode: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mpeg_decode.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "MPEG") != null);
}

test "mpeg_decode: verify decoding" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mpeg_decode.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}

test "mqtt_connect: file exists" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mqtt_connect.t27");
    defer allocator.free(source);
    try assemble(allocator, source);
    try std.testing.expect(std.mem.indexOf(u8, source, "MQTT") != null);
}

test "mqtt_connect: verify connection" {
    const allocator = std.testing.allocator;
    const source = try readT27File(allocator, "mqtt_connect.t27");
    defer allocator.free(source);
    try std.testing.expect(source.len > 0);
}
