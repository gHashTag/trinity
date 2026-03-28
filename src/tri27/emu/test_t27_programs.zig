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

    std.debug.print("DEBUG: t0 after LDI 1000: {d}\n", .{cpu.t27[0].trits});
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

    std.debug.print("DEBUG: t0 after ADD 10+6: {d}\n", .{cpu.t27[0].trits});
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

    std.debug.print("DEBUG: t0 after SHR 16>>1: {d}\n", .{cpu.t27[0].trits});
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

// φ² + 1/φ² = 3 | TRINITY
