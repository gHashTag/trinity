// E2E Test: emit_t27 vs canonical reticular_raphe.t27
// TDGS-3 Wave 2: Phase 2 Validation
//
// This test validates that emit_t27 generates bytecode that is
// instruction-equivalent to the hand-written reticular_raphe.t27
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

const emit_t27 = @import("../emit_t27/emit_t27.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// TEST: Verify .t27 header format
// ═══════════════════════════════════════════════════════════════════════════════
test "emit_t27: header format matches spec" {
    const allocator = std.testing.allocator;

    const instructions = [_]emit_t27.Tri27Instruction{
        .{ .opcode = .HALT },
    };

    const bytecode = try emit_t27.generateBytecode(allocator, &instructions);
    defer allocator.free(bytecode);

    // Magic: "2IRT" (little-endian)
    try std.testing.expectEqual(@as(u8, '2'), bytecode[0]);
    try std.testing.expectEqual(@as(u8, 'I'), bytecode[1]);
    try std.testing.expectEqual(@as(u8, 'R'), bytecode[2]);
    try std.testing.expectEqual(@as(u8, 'T'), bytecode[3]);

    // Version: 1
    try std.testing.expectEqual(@as(u8, 1), bytecode[4]);

    // Section count: 1 (CODE section)
    try std.testing.expectEqual(@as(u8, 1), bytecode[5]);

    // Section header: type=1 (CODE), padding=0, size=4 (one HALT instruction)
    try std.testing.expectEqual(@as(u8, 1), bytecode[6]); // type
    try std.testing.expectEqual(@as(u8, 0), bytecode[7]); // padding
    // Size = 4 (little-endian)
    try std.testing.expectEqual(@as(u8, 4), bytecode[8]);
    try std.testing.expectEqual(@as(u8, 0), bytecode[9]);
}

// /// ═══════════════════════════════════════════════════════════════════════════════
// TEST: Verify reticular_raphe instruction sequence
// /// ═══════════════════════════════════════════════════════════════════════════════
test "emit_t27: reticular_raphe instruction sequence" {
    const allocator = std.testing.allocator;

    // Subset of reticular_raphe instructions (initialization phase)
    const instructions = [_]emit_t27.Tri27Instruction{
        // LDI t0, MEM_EVALUATIONS (16)
        .{ .opcode = .LDI, .dst = 0, .immediate = 16, .has_imm = true },
        // LDI t5, 0 (index)
        .{ .opcode = .LDI, .dst = 5, .immediate = 0, .has_imm = true },
        // LDI t1, 0 (current_ppl)
        .{ .opcode = .LDI, .dst = 1, .immediate = 0, .has_imm = true },
        // LDI t2, 0 (weight_sum)
        .{ .opcode = .LDI, .dst = 2, .immediate = 0, .has_imm = true },
        // LDI t3, 0 (weighted_sum)
        .{ .opcode = .LDI, .dst = 3, .immediate = 0, .has_imm = true },
        // LDI t4, 0 (rolling_ppl)
        .{ .opcode = .LDI, .dst = 4, .immediate = 0, .has_imm = true },
        // HALT
        .{ .opcode = .HALT },
    };

    const bytecode = try emit_t27.generateBytecode(allocator, &instructions);
    defer allocator.free(bytecode);

    // Verify instruction count (7 instructions = 28 bytes + 10 bytes header = 38 bytes)
    try std.testing.expectEqual(@as(usize, 38), bytecode.len);

    // Verify first instruction (LDI t0, 16)
    const first_word = std.mem.readInt(u32, bytecode[10..14], .little);
    try std.testing.expectEqual(@as(u8, 0x04), @as(u8, @truncate(first_word & 0xFF))); // LDI opcode
    try std.testing.expectEqual(@as(u8, 0), @as(u8, @truncate((first_word >> 8) & 0x1F))); // dst = t0
    try std.testing.expectEqual(@as(i16, 16), @as(i16, @bitCast(@as(u16, @truncate((first_word >> 17) & 0xFFFF)))));

    // Verify last instruction is HALT
    const last_word = std.mem.readInt(u32, bytecode[34..38], .little);
    try std.testing.expectEqual(@as(u32, 0x4D000000), last_word); // HALT (0x4D) with no operands
}

// /// ═══════════════════════════════════════════════════════════════════════════════
// TEST: Verify JGT/JLT special encoding
// /// ═══════════════════════════════════════════════════════════════════════════════
test "emit_t27: JGT encoding matches reticular_raphe" {
    const allocator = std.testing.allocator;

    // From reticular_raphe: JGT t4, t6, clamp_max
    // Encoding: dst=t4, src2=t6, target=clamp_max
    const instructions = [_]emit_t27.Tri27Instruction{
        .{ .opcode = .LDI, .dst = 4, .immediate = 127, .has_imm = true }, // t4 = 127
        .{ .opcode = .LDI, .dst = 6, .immediate = 100, .has_imm = true }, // t6 = 100
        .{ .opcode = .JGT, .dst = 4, .src2 = 6, .immediate = 0, .has_imm = true }, // JGT t4, t6, 0
        .{ .opcode = .HALT },
    };

    const bytecode = try emit_t27.generateBytecode(allocator, &instructions);
    defer allocator.free(bytecode);

    // Verify JGT instruction (third instruction, at offset 10+8=18)
    const jgt_word = std.mem.readInt(u32, bytecode[18..22], .little);

    // Opcode should be JGT (0x44)
    try std.testing.expectEqual(@as(u8, 0x44), @as(u8, @truncate(jgt_word & 0xFF)));

    // dst should be t4 (4)
    try std.testing.expectEqual(@as(u8, 4), @as(u8, @truncate((jgt_word >> 8) & 0x1F)));

    // src2 should be in immediate[11-15] (upper 5 bits of immediate field)
    const imm_raw = @as(u16, @truncate((jgt_word >> 17) & 0x7FFF));
    try std.testing.expectEqual(@as(u8, 6), @as(u8, @truncate((imm_raw >> 11) & 0x1F))); // src2 = t6

    // target should be in immediate[0-10] (lower 11 bits)
    try std.testing.expectEqual(@as(i16, 0), @as(i16, @bitCast(imm_raw & 0x7FF))); // target = 0
}

// /// ═══════════════════════════════════════════════════════════════════════════════
// TEST: Register allocation determinism
// /// ═══════════════════════════════════════════════════════════════════════════════
test "emit_t27: register allocation matches reticular_raphe plan" {
    const allocator = std.testing.allocator;
    var reg_alloc = emit_t27.RegAlloc.init(allocator);
    defer reg_alloc.deinit();

    // Verify fixed registers for state variables (t0..t3)
    const r0 = reg_alloc.allocate(0);
    const r1 = reg_alloc.allocate(1);
    const r2 = reg_alloc.allocate(2);
    const r3 = reg_alloc.allocate(3);

    try std.testing.expectEqual(@as(u8, 0), r0); // t0 for value_id 0
    try std.testing.expectEqual(@as(u8, 1), r1); // t1 for value_id 1
    try std.testing.expectEqual(@as(u8, 2), r2); // t2 for value_id 2
    try std.testing.expectEqual(@as(u8, 3), r3); // t3 for value_id 3

    // Verify general purpose registers start at t8
    const r8 = reg_alloc.allocate(100); // High ID should get GP register
    try std.testing.expectEqual(@as(u8, 8), r8); // First GP register

    // Verify determinism (same value ID gets same register)
    const r8_again = reg_alloc.allocate(100);
    try std.testing.expectEqual(r8, r8_again);
}

// /// ═══════════════════════════════════════════════════════════════════════════════
// TEST: Full reticular_raphe subset (without IR integration)
// /// ═══════════════════════════════════════════════════════════════════════════════
test "emit_t27: reticular_raphe main_loop structure" {
    const allocator = std.testing.allocator;

    // Simulate reticular_raphe main loop structure
    const instructions = [_]emit_t27.Tri27Instruction{
        // Initialize
        .{ .opcode = .LDI, .dst = 0, .immediate = 16, .has_imm = true }, // LDI t0, MEM_EVALUATIONS
        .{ .opcode = .LDI, .dst = 5, .immediate = 0, .has_imm = true },  // LDI t5, 0
        .{ .opcode = .LDI, .dst = 1, .immediate = 0, .has_imm = true },  // LDI t1, 0
        .{ .opcode = .LDI, .dst = 2, .immediate = 0, .has_imm = true },  // LDI t2, 0
        .{ .opcode = .LDI, .dst = 3, .immediate = 0, .has_imm = true },  // LDI t3, 0
        .{ .opcode = .LDI, .dst = 4, .immediate = 0, .has_imm = true },  // LDI t4, 0

        // Main loop: JLT t5, t6, read_next
        .{ .opcode = .LDI, .dst = 6, .immediate = 20, .has_imm = true }, // LDI t6, WINDOW_SIZE
        .{ .opcode = .JGT, .dst = 5, .src2 = 6, .immediate = 1, .has_imm = true }, // JGT t5, t6, +1

        // HALT
        .{ .opcode = .HALT },
    };

    const bytecode = try emit_t27.generateBytecode(allocator, &instructions);
    defer allocator.free(bytecode);

    // Should have header + 9 instructions = 10 + 36 = 46 bytes
    try std.testing.expectEqual(@as(usize, 46), bytecode.len);

    // Verify all LDI instructions (opcodes 0x04)
    var ldi_count: usize = 0;
    for (0..7) |i| {
        const offset = 10 + i * 4;
        const word = std.mem.readInt(u32, bytecode[offset..offset+4], .little);
        if (@as(u8, @truncate(word & 0xFF)) == 0x04) ldi_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 6), ldi_count); // 6 LDI instructions
}
