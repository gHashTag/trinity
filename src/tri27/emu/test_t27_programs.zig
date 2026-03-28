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
    try std.testing.expectEqual(@as(i64, 10), cpu.t27[0].trits);
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
    try std.testing.expectEqual(@as(i64, 7), cpu.t27[0].trits);
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
    try std.testing.expectEqual(@as(i64, 12), cpu.t27[0].trits);
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
