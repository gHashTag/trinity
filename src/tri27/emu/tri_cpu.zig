// @origin(spec:tri27_isa.zig) @regen(manual-impl)
// TRI‑27 CPU STATE — Ternary RISC Processor State
//
// Target: Software emulator (tri-emu) + Hardware (tri-hw, later)
// Goal: ~500M ops/sec on Mac/Linux/Windows, 50MIPS on FPGA
//
// φ² + 1/φ² = 3 | TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════════
// REGISTER FILE
// t27[16] — 16 тернарных регистров (27 тритов каждый)
// f[8]     — 8 GF16 регистров для floating-point операций
// v[16]    — 16 векторных регистров (16×GF16)
// ip        — Instruction pointer (32-bit)
// sp        — Stack pointer (32-bit)
// flags     — Z (zero), N (negative), V (overflow), H (halted)
// ═════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════
// TRI‑27 TERNARY TYPE — 27-trit balanced ternary integer
// ═════════════════════════════════════════════════════════════════════════════════════════════════════
/// Packed 27-trit ternary value (signed: [-1, 0, +1])
/// Each trit uses 2 bits: 00=0, 01=+1, 11=-1, 10 is unused
/// Value range: -(3^27-1) to (3^27-1) = ~3.6M distinct values
pub const Trit27 = extern struct {
    /// 27 trits packed into one i64 (using 2 bits per trit)
    trits: i64,

    /// Create ZERO (all trits = 0)
    pub const ZERO: Trit27 = .{ .trits = 0 };

    /// Create from signed i8 (-1, 0, +1)
    /// Trits stored in bits 7-2 (MSB)
    pub fn fromI8(val: i8) Trit27 {
        std.debug.assert(val >= -1 and val <= 1, "Trit27: i8 must be -1, 0, or +1");

        // Pack into i64 (each trit: 2 bits, MSB first)
        var result: i64 = 0;
        for (0..27) |i| {
            const trit = if (val < 0) @as(u8, -1) else if (val > 0) @as(u8, 1) else @as(u8, 0);
            result |= @as(i64, trit) << (i * 2);
        }
        return .{ .trits = result };
    }

    /// Create from i64 packed value
    pub fn fromI64(packed: i64) Trit27 {
        // Unpack from i64 to trits
        var result: i8 = 0;
        for (0..27) |i| {
            const trit_bits = (packed >> @as(u5, i * 2)) & 0b11;
            const trit: switch (trit_bits) {
                0b00 => 0,
                0b01 => 1,
                0b10 => @as(i8, -1),
                0b11 => unreachable, // reserved
                else => 0,
            };
            result = @as(i8, (result * 3) + trit);
        }
        return .{ .trits = result };
    }

    /// Negate all 27 trits (unary minus)
    pub fn negate(self: Trit27) Trit27 {
        const all_negated = (self.trits ^ @bitCast(@as(i64, @max(i64))));

        // XOR with all-ones to flip bits (0 → 1, 1 → 0)
        // Note: -1 in 2-bit encoding becomes 0b11 (reserved), so we use 0b10
        const negated = all_negated;
        return .{ .trits = negated };
    }

    /// Add two Trit27 values with sign extension handling
    /// Returns true if overflow occurred (value outside [-3^27+1, 3^27-1])
    pub fn add(a: Trit27, b: Trit27) struct { result: Trit27, overflow: bool } {
        var result: i64 = a.trits + b.trits;

        // Handle overflow at each trit position (3-state addition)
        var overflow: bool = false;
        for (0..27) |i| {
            const a_trit = (a.trits >> @as(u5, i * 2)) & 0b11;
            const b_trit = (b.trits >> @as(u5, i * 2)) & 0b11;
            const sum: u2 = a_trit + b_trit;

            // 3-state addition with carry
            // 0+0=0, 0+1=1, 1+0=1, 1+1=2(=1 with overflow)
            const sum_trit = switch (sum) {
                0 => 0,
                1 => 1,
                2 => @as(u8, -1),
                else => 0b10, // overflow, result trit = 0b00=0
            };

            if (sum_trit == 0b10) overflow = true;

            const result_trit = sum_trit & 0b11;
            result |= @as(i64, result_trit) << @as(u5, i * 2);
        }

        return .{ .result = .{ .trits = result }, .overflow = overflow };
    }

    /// Subtract b from a (a - b)
    pub fn sub(a: Trit27, b: Trit27) Trit27 {
        var result: i64 = a.trits - b.trits;

        // Handle underflow at each trit position (3-state subtraction)
        for (0..27) |i| {
            const a_trit = (a.trits >> @as(u5, i * 2)) & 0b11;
            const b_trit = (b.trits >> @as(u5, i * 2)) & 0b11;
            const diff: u2 = a_trit - b_trit;

            // 3-state subtraction with borrow
            const diff_trit = switch (diff) {
                0 => 0,
                1 => 1,
                2 => @as(u8, -1),
                else => 0b10, // underflow, result trit = 0b01=-1
            };

            result |= @as(i64, diff_trit) << @as(u5, i * 2);
        }

        return .{ .trits = result };
    }

    /// Compare two Trit27 values (less than, equal, greater than)
    pub fn cmp(a: Trit27, b: Trit27) struct { lt: bool, eq: bool, gt: bool } {
        const diff = a.trits -% b.trits;
        if (diff < 0) return .{ .lt = true, .eq = false, .gt = false };
        if (diff > 0) return .{ .lt = false, .eq = false, .gt = true };
        return .{ .lt = false, .eq = true, .gt = false };
    }

    /// Convert to i8 (clamped to valid Trit27 range)
    pub fn toI8Clamped(self: Trit27) i8 {
        return @max(-1, @min(1, self.toI8ClampedUnchecked()));
    }

    /// Convert to i8 (unchecked - assumes valid value)
    pub fn toI8ClampedUnchecked(self: Trit27) i8 {
        // Unpack and check sign
        var result: i8 = 0;
        const sign_bit = (self.trits >> 53) & 1; // MSB of trit 27

        if (sign_bit == 1) {
            // Negative: need to find position of -1 and return negative value
            // For simplicity, just negate -1 → +1, then count
            for (0..27) |i| {
                const trit = (self.trits >> @as(u5, i * 2)) & 0b11;
                result = @as(i8, (result * 3) + @as(i8, trit));
            }
        } else if (sign_bit == 0) {
            // Non-negative: count +1s
            for (0..27) |i| {
                const trit = (self.trits >> @as(u5, i * 2)) & 0b11;
                result = @as(i8, (result * 3) + @as(i8, trit));
            }
        } else {
            // Positive
            for (0..27) |i| {
                const trit = (self.trits >> @as(u5, i * 2)) & 0b11;
                result = @as(i8, (result * 3) + @as(i8, trit));
            }
        }

        return @min(@as(i8, 1), result);
    }

    test "Trit27 ZERO is all zeros" {
        const zero = Trit27.ZERO;
        try std.testing.expectEqual(@as(i64, 0), zero.trits);
        try std.testing.expectEqual(@as(i64, 0), zero.toI8ClampedUnchecked());
    }

    test "Trit27 fromI8 roundtrip" {
        const test_vals = [_]i8{ -1, 0, 1 };
        for (test_vals) |val| {
            const trit = Trit27.fromI8(val);
            const back = trit.toI8ClampedUnchecked();
            try std.testing.expectEqual(val, back);
        }
    }

    test "Trit27 negate flips signs" {
        const positive = Trit27.fromI64(@as(i64, 0x1));
        const negated = positive.negate();

        // All positive trits should become -1 (except 0b10 which stays 0)
        for (0..26) |i| {
            const original = (positive.trits >> @as(u5, i * 2)) & 0b11;
            const flipped = (negated.trits >> @as(u5, i * 2)) & 0b11;
            const expected = switch (original) {
                0b00 => 0b10, // 0 becomes reserved on neg
                0b01 => 0b10,
                0b10 => 0b01, // +1 becomes -1
                0b11 => 0b01, // -1 becomes +1
                else => 0b10,
            };
            try std.testing.expectEqual(expected, flipped);
        }

        // Original bit 27 (MSB) should remain 0 (ZERO trit)
        const msb_original = (positive.trits >> 53) & 1;
        const msb_flipped = (negated.trits >> 53) & 1;
        try std.testing.expectEqual(msb_original, msb_flipped);
    }
}

test "Trit27 add basic" {
    const a = Trit27.fromI8(1);  // +1
    const b = Trit27.fromI8(1);  // +1
    const result = Trit27.add(a, b);

    // 1 + 1 should overflow: max value is +1, 1+1=2 (overflow)
    try std.testing.expect(result.result.toI8ClampedUnchecked() == 1);
    try std.testing.expect(result.overflow);
}

test "Trit27 add no overflow" {
    const a = Trit27.fromI8(1);
    const b = Trit27.fromI8(-1); // -1
    const result = Trit27.add(a, b);

    // 1 + (-1) = 0 (no overflow)
    try std.testing.expectEqual(@as(i8, 0), result.result.toI8ClampedUnchecked());
    try std.testing.expect(!result.overflow);
}

test "Trit27 add mixed" {
    const a = Trit27.fromI8(1);
    const b = Trit27.fromI8(0); // 0
    const result = Trit27.add(a, b);

    // 1 + 0 = 1 (no overflow)
    try std.testing.expectEqual(@as(i8, 1), result.result.toI8ClampedUnchecked());
    try std.testing.expect(!result.overflow);
}

test "Trit27 sub" {
    const a = Trit27.fromI8(0);
    const b = Trit27.fromI8(1);
    const result = Trit27.sub(a, b);

    // 0 - 1 = -1
    try std.testing.expectEqual(@as(i8, -1), result.toI8ClampedUnchecked());
}

test "Trit27 cmp" {
    const a = Trit27.fromI8(1);
    const b = Trit27.fromI8(0);
    const result = Trit27.cmp(a, b);

    try std.testing.expectEqual(true, result.gt);  // 1 > 0
    try std.testing.expectEqual(false, result.lt);
    try std.testing.expectEqual(false, result.eq);
}

test "Trit27 toI8Clamped" {
    const max_pos = Trit27.fromI64(@as(i64, @max(i64)));
    const one = Trit27.fromI8(1);
    const minus_one = Trit27.fromI8(-1);
    const zero = Trit27.ZERO;

    try std.testing.expectEqual(@as(i8, 1), max_pos.toI8Clamped());
    try std.testing.expectEqual(@as(i8, 1), one.toI8Clamped());
    try std.testing.expectEqual(@as(i8, -1), minus_one.toI8Clamped());
    try std.testing.expectEqual(@as(i8, 0), zero.toI8Clamped());
}
}

test "Trit27 toI8ClampedUnchecked" {
    const max_pos = Trit27.fromI64(@as(i64, @max(i64)));
    const one = Trit27.fromI8(1);
    const minus_one = Trit27.fromI8(-1);
    const zero = Trit27.ZERO;

    try std.testing.expectEqual(@as(i8, 1), max_pos.toI8ClampedUnchecked());
    try std.testing.expectEqual(@as(i8, 1), one.toI8ClampedUnchecked());
    try std.testing.expectEqual(@as(i8, -1), minus_one.toI8ClampedUnchecked());
    try std.testing.expectEqual(@as(i8, 0), zero.toI8ClampedUnchecked());
}
test "Trit27 overflow detection" {
    // Create max value (all +1 except MSB)
    var max_trits: i64 = 0;
    for (0..26) |i| {
        max_trits |= @as(i64, 0b01) << @as(u5, i * 2);
    }
    max_trits |= @as(i64, 0b10) << @as(u5, 26 * 2);

    const max_val = Trit27{ .trits = max_trits };

    // Adding any non-zero to max should overflow
    const one = Trit27.fromI8(1);
    const result = Trit27.add(max_val, one);

    try std.testing.expect(result.overflow);
}

test "Trit27 range check" {
    // Test minimum and maximum representable values
    // Minimum: all trits = 0b11 except LSB (reserved)
    // Maximum: all trits = 0b01 except MSB

    // Create minimum (all 0 except LSB becomes -1)
    var min_trits: i64 = 0;
    for (0..26) |i| {
        min_trits |= @as(i64, 0b01) << @as(u5, i * 2);
    }
    // MSB bit 27 should stay 0
    min_trits &= ~@as(i64, 0b11) << @as(u5, 26 * 2);

    const min_val = Trit27{ .trits = min_trits };

    try std.testing.expectEqual(@as(i64, -1), min_val.toI8ClampedUnchecked());
    try std.testing.expectEqual(@as(i64, 1), Trit27.fromI64(@as(i64, 1)).toI8ClampedUnchecked());
}

test "Trit27 sign bit handling" {
    // Test that sign bit (bit 53) correctly indicates positive/negative
    const negative = Trit27.fromI8(-1);
    const positive = Trit27.fromI8(1);
    const zero = Trit27.ZERO;

    try std.testing.expectEqual(@as(i8, 1), (negative.trits >> 53) & 1);
    try std.testing.expectEqual(@as(i8, 0), (positive.trits >> 53) & 0);
    try std.testing.expectEqual(@as(i8, 0), (zero.trits >> 53) & 0);
}
}

test "Trit27 bit 27 is reserved" {
    // Bit 27 (MSB) should not be used in normal operations
    const test_vals = [_]Trit27{ .trits = 0x3FFF }};
    for (test_vals) |*val| {
        const i8 = val.toI8Clamped();
        try std.testing.expectEqual(@as(i8, 1), i8);
    }

test "Trit27 count trits" {
    // Verify that we have exactly 27 trits (54 bits used)
    const all_ones = Trit27.fromI64(@as(i64, @max(i64)));
    const count = blk: {
        var c: u32 = 0;
        for (0..26) |i| {
            if ((all_ones.trits >> @as(u5, i * 2)) & 0b11 != 0) c += 1;
        }
        return c;
    };
    try std.testing.expectEqual(@as(u32, 27), count(all_ones));
}

test "Trit27 packing consistency" {
    // Test that fromI8 → fromI64 roundtrip is consistent
    const test_vals = [_]i8{ -1, -1, 0, 0, 1, 1, -1, -1, 0, 0, 1, 1, -1, -1, 0, 0 };
    for (test_vals) |val| {
        const trit = Trit27.fromI8(val);
        const packed = trit.toI64ClampedUnchecked();
        const unpacked = Trit27.fromI64(packed);
        try std.testing.expectEqual(trit.trits, unpacked.trits);
    }
}
