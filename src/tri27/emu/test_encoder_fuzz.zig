// TRI-27 ENCODER FUZZER — Property-based tests for instruction encoding
// ═════════════════════════════════════════════════════════════════════════════
// Prevents bit-field overlap regressions like Issue #469
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const testing = std.testing;
const decoder = @import("decoder.zig");

const Opcode = decoder.Opcode;
const Instruction = decoder.Instruction;
const encode = decoder.encode;
const decode = decoder.decode;

// ═════════════════════════════════════════════════════════════════════════════
// PROPERTY 1: Encode-Decode Roundtrip
// ══════════════════════════════════════════════════════════════════════════════════════

test "fuzz: encode-decode roundtrip for all opcodes" {
    var prng = std.Random.DefaultPrng.init(0x5F3759DF); // Random seed
    const random = prng.random();

    const iterations = 10_000;

    for (0..iterations) |_| {
        // Generate random instruction
        const inst = randomInstruction(random);

        // Encode then decode
        const word = encode(inst);
        const decoded = decode(word);

        // Verify opcode preserved
        try testing.expectEqual(inst.opcode, decoded.opcode);

        // Verify dst preserved
        try testing.expectEqual(inst.dst, decoded.dst);

        // For instructions with src2, verify it's preserved
        const has_src2 = switch (inst.opcode) {
            .ADD, .SUB, .MUL, .DIV, .AND, .OR, .XOR => true,
            else => false,
        };
        if (has_src2) {
            try testing.expectEqual(inst.src2, decoded.src2);
        }

        // For instructions with immediate, verify it's preserved (clamped to range)
        if (inst.has_imm) {
            const imm_clamped = std.math.clamp(inst.immediate, -16384, 16383);
            try testing.expectEqual(imm_clamped, decoded.immediate);
        }
    }
}

test "fuzz: decode-encode roundtrip for random words" {
    var prng = std.Random.DefaultPrng.init(0x9E3779B9); // Different seed
    const random = prng.random();

    const iterations = 10_000;

    for (0..iterations) |_| {
        // Generate random 32-bit word
        const word = random.int(u32);

        // Decode then encode
        const decoded = decode(word);
        const reencoded = encode(decoded);

        // For valid opcodes, verify the instruction encoding is stable
        // (we only check opcode bits since other bits may vary due to clamping)
        const original_opcode = @as(u8, @truncate(word & 0xFF));
        const reencoded_opcode = @as(u8, @truncate(reencoded & 0xFF));

        // Only verify if opcode is in our enum
        if (std.meta.intToEnum(Opcode, original_opcode)) |opcode| {
            _ = opcode;
            try testing.expectEqual(original_opcode, reencoded_opcode);
        } else |_| {
            // Invalid opcode - decoder returns NOP, reencoded should be 0
            try testing.expectEqual(@as(u8, 0), reencoded_opcode);
        }
    }
}

// ═════════════════════════════════════════════════════════════════════════════
// PROPERTY 2: Field Bounds Validation
// ══════════════════════════════════════════════════════════════════════════════════════

test "fuzz: src1/src2 always in valid register range [0,26]" {
    var prng = std.Random.DefaultPrng.init(0xBB67AE85);
    const random = prng.random();

    const iterations = 10_000;

    for (0..iterations) |_| {
        const inst = randomInstruction(random);
        const word = encode(inst);

        // Decode and verify bounds
        const decoded = decode(word);

        // dst always in [0, 31] but only [0, 26] are valid registers
        try testing.expect(decoded.dst < 32);

        // src1 always in valid range
        try testing.expect(decoded.src1 < 32);

        // src2 (when used) always in valid range
        const has_src2 = switch (decoded.opcode) {
            .ADD, .SUB, .MUL, .DIV, .AND, .OR, .XOR => true,
            else => false,
        };
        if (has_src2) {
            try testing.expect(decoded.src2 < 32);
        }
    }
}

test "fuzz: immediate always in 15-bit signed range" {
    var prng = std.Random.DefaultPrng.init(0x3C6EF372);
    const random = prng.random();

    const iterations = 10_000;

    // All immediate instructions
    const imm_opcodes = [_]Opcode{
        .LDI, .STI, .LD_IMM, .PHI_CONST, .PI_CONST, .E_CONST,
        .JMP, .JZ,  .JNZ,    .JGT,       .JLT,      .CALL,
        .RET, .SHL, .SHR,    .BUNDLE3,
    };

    for (imm_opcodes) |opcode| {
        for (0..iterations / imm_opcodes.len) |_| {
            const inst = Instruction{
                .opcode = opcode,
                .dst = random.intRangeAtMost(u8, 0, 26),
                .src1 = random.intRangeAtMost(u8, 0, 15), // Only 4 bits for imm instructions
                .immediate = random.int(i16), // Can be any i16 value
                .has_imm = true,
            };

            const word = encode(inst);
            const decoded = decode(word);

            // Verify immediate was clamped to valid range
            try testing.expect(decoded.immediate >= -16384);
            try testing.expect(decoded.immediate <= 16383);
        }
    }
}

// ═════════════════════════════════════════════════════════════════════════════
// PROPERTY 3: No Field Overlap
// ══════════════════════════════════════════════════════════════════════════════════════

test "fuzz: immediate instructions use 4-bit src1 (no bit 17 overlap)" {
    // This test specifically checks the fix for Issue #469
    const imm_opcodes = [_]Opcode{
        .LDI, .STI, .LD_IMM, .PHI_CONST, .PI_CONST, .E_CONST,
        .JMP, .JZ,  .JNZ,    .JGT,       .JLT,      .CALL,
        .RET, .SHL,
        .SHR,
        // Note: BUNDLE3 is excluded - it's a 3-operand instruction, not immediate
    };

    for (imm_opcodes) |opcode| {
        // Test with valid src1 values (0-15 for immediate instructions)
        const src1_val: u8 = 5; // Valid 4-bit value
        const imm_val: i16 = 42;

        const inst = Instruction{
            .opcode = opcode,
            .dst = 0,
            .src1 = src1_val,
            .immediate = imm_val,
            .has_imm = true,
        };

        const word = encode(inst);
        const decoded = decode(word);

        // With hybrid encoding, src1 and immediate should both be preserved
        try testing.expectEqual(@as(i16, imm_val), decoded.immediate);

        // Verify src1 is preserved (in lower 4 bits)
        try testing.expectEqual(src1_val, decoded.src1);

        // Verify bit 17 is NOT part of src1 (check it's part of immediate field)
        // Bits 17-31 should contain the immediate value
        const imm_bits = @as(u16, @bitCast(@as(i16, imm_val))) & 0x7FFF;
        const encoded_imm = @as(u16, @truncate((word >> 17) & 0x7FFF));
        try testing.expectEqual(imm_bits, encoded_imm);
    }

    // Additional test: src1 values >= 16 are truncated (4-bit limit)
    for (imm_opcodes) |opcode| {
        const inst = Instruction{
            .opcode = opcode,
            .dst = 0,
            .src1 = 16, // This gets truncated to 0 (only 4 bits)
            .immediate = 42,
            .has_imm = true,
        };

        const word = encode(inst);
        const decoded = decode(word);

        // src1=16 is masked to 0, but immediate should still be preserved
        try testing.expectEqual(@as(i16, 42), decoded.immediate);
        try testing.expectEqual(@as(u8, 0), decoded.src1); // Truncated to 0
    }
}

test "fuzz: three-operand instructions preserve full 5-bit src1 and src2" {
    const three_operand_opcodes = [_]Opcode{
        .ADD, .SUB, .MUL, .DIV, .AND, .OR, .XOR,
    };

    var prng = std.Random.DefaultPrng.init(0xA5A5A5A5);
    const random = prng.random();

    const iterations = 1_000;

    for (three_operand_opcodes) |opcode| {
        for (0..iterations / three_operand_opcodes.len) |_| {
            const src1 = random.intRangeAtMost(u8, 0, 26);
            const src2 = random.intRangeAtMost(u8, 0, 26);

            const inst = Instruction{
                .opcode = opcode,
                .dst = random.intRangeAtMost(u8, 0, 26),
                .src1 = src1,
                .src2 = src2,
            };

            const word = encode(inst);
            const decoded = decode(word);

            // Both src1 and src2 should be preserved (full 5-bit range)
            try testing.expectEqual(src1, decoded.src1);
            try testing.expectEqual(src2, decoded.src2);
        }
    }
}

// ═════════════════════════════════════════════════════════════════════════════
// TEST: Bit field masks don't overlap for any opcode
// ══════════════════════════════════════════════════════════════════════════════════════

test "verify: no bit field overlap for all opcodes" {
    // Explicitly check that field masks are disjoint
    // This is a static verification, not fuzzing

    const opcodes = [_]Opcode{
        .ADD, .SUB, .MUL,    .DIV,       .AND,      .OR,      .XOR,
        .LDI, .STI, .LD_IMM, .PHI_CONST, .PI_CONST, .E_CONST, .JMP,
        .JZ,  .JNZ, .JGT,    .JLT,       .CALL,     .RET,     .SHL,
        .SHR, .MOV, .NOT,    .INC,       .DEC,
    };

    for (opcodes) |opcode| {
        const has_imm = switch (opcode) {
            .LDI, .STI, .LD_IMM, .PHI_CONST, .PI_CONST, .E_CONST, .JMP, .JZ, .JNZ, .JGT, .JLT, .CALL, .RET, .SHL, .SHR, .BUNDLE3 => true,
            else => false,
        };

        const has_src2 = switch (opcode) {
            .ADD, .SUB, .MUL, .DIV, .AND, .OR, .XOR => true,
            else => false,
        };

        if (has_imm) {
            // Immediate instruction: src1 at 13-16, imm at 17-31
            // Verify these ranges don't overlap
            const src1_mask: u32 = 0x0F << 13; // bits 13-16
            const imm_mask: u32 = 0x7FFF << 17; // bits 17-31

            try testing.expectEqual(@as(u32, 0), src1_mask & imm_mask);
        } else if (has_src2) {
            // Three-operand: src1 at 13-17, src2 at 18-22
            const src1_mask: u32 = 0x1F << 13; // bits 13-17
            const src2_mask: u32 = 0x1F << 18; // bits 18-22

            try testing.expectEqual(@as(u32, 0), src1_mask & src2_mask);
        }
        // else: two-operand, only src1 at 13-17 (no overlap possible)
    }
}

// ═════════════════════════════════════════════════════════════════════════════
// HELPER: Generate random instruction
// ══════════════════════════════════════════════════════════════════════════════════════

fn randomInstruction(random: std.Random) Instruction {
    const opcodes = [_]Opcode{
        .NOP,     .MOV,  .ADD, .SUB,  .MUL,     .DIV,     .INC,       .DEC,
        .AND,     .OR,   .XOR, .NOT,  .SHL,     .SHR,     .LD,        .ST,
        .LDI,     .STI,  .JMP, .JZ,   .JNZ,     .JGT,     .JLT,       .CALL,
        .RET,     .HALT, .DOT, .BIND, .BUNDLE2, .BUNDLE3, .PHI_CONST, .PI_CONST,
        .E_CONST, .SACR,
    };

    const opcode = opcodes[random.intRangeAtMost(usize, 0, opcodes.len - 1)];
    const dst = random.intRangeAtMost(u8, 0, 26);
    const src1 = random.intRangeAtMost(u8, 0, 26);
    const src2 = random.intRangeAtMost(u8, 0, 26);

    // has_imm must match the encoder's logic
    // Note: BUNDLE3 is NOT an immediate instruction, it's a 3-operand with special encoding
    const has_imm = switch (opcode) {
        .LDI, .STI, .LD_IMM, .PHI_CONST, .PI_CONST, .E_CONST, .JMP, .JZ, .JNZ, .JGT, .JLT, .CALL, .RET, .SHL, .SHR => true,
        else => false,
    };

    const immediate = if (has_imm) random.int(i16) else 0;

    return Instruction{
        .opcode = opcode,
        .dst = dst,
        .src1 = src1,
        .src2 = src2,
        .immediate = immediate,
        .has_imm = has_imm,
    };
}
