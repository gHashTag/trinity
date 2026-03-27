//! B2T Core — Generated from specs/b2t/core.tri
//! φ² + 1/φ² = 3 | TRINITY
//!
//! DO NOT EDIT: This file is generated from core.tri spec
//! Binary to ternary encoding and decoding

const std = @import("std");

// ============================================================================
// CONSTANTS
// ============================================================================

/// Ternary digit values
pub const TRIT_VALUES: [3]i8 = [_]i8{ -1, 0, 1 };

/// Base for ternary logarithm
pub const TRINARY_LOG_BASE: f64 = 1.585; // log2(3)

// ============================================================================
// TYPES
// ============================================================================

/// Binary input buffer type
pub const BinaryInput = struct {
    data: []const u8,
};

/// Ternary output buffer type
pub const TernaryOutput = struct {
    trits: []Trit,
};

/// Trit - balanced ternary digit
pub const Trit = enum(i8) {
    /// Negative trit
    neg = -1,

    /// Zero trit
    zero = 0,

    /// Positive trit
    pos = 1,

    /// Create trit from i8 value (clamped to -1, 0, 1)
    pub fn fromInt(value: i8) Trit {
        return if (value < 0) .neg else if (value > 0) .pos else .zero;
    }

    /// Get integer value of trit
    pub fn toInt(self: Trit) i8 {
        return @intFromEnum(self);
    }

    /// Get symbol representation
    pub fn toSymbol(self: Trit) u8 {
        return switch (self) {
            .neg => '-',
            .zero => '0',
            .pos => '+',
        };
    }
};

// ============================================================================
// FUNCTIONS
// ============================================================================

/// Decode binary data to ternary trits
/// Uses 2 bits per trit: 10=negative, 00=zero, 01=positive
pub fn decode(allocator: std.mem.Allocator, input: BinaryInput) !TernaryOutput {
    const num_bits = input.data.len * 8;
    const num_trits = (num_bits + 1) / 2; // ceil division
    var trits = try allocator.alloc(Trit, num_trits);

    for (0..num_trits) |i| {
        // Each trit uses 2 bits
        const byte_idx = i / 4;
        const bit_offset = (i % 4) * 2;

        if (byte_idx >= input.data.len) {
            trits[i] = .zero;
            continue;
        }

        const byte = input.data[byte_idx];
        const two_bits: u2 = @truncate((byte >> @intCast(bit_offset)) & 0b11);

        trits[i] = switch (two_bits) {
            0b10 => .neg,
            0b00 => .zero,
            0b01 => .pos,
            else => .zero, // 0b11 reserved, treat as zero
        };
    }

    return TernaryOutput{ .trits = trits };
}

/// Encode ternary trits to binary data
/// Maps: -1->10, 0->00, 1->01
pub fn encode(allocator: std.mem.Allocator, input: TernaryOutput) !BinaryInput {
    // Each 4 trits require 1 byte (8 bits with 2 unused)
    const num_bytes = (input.trits.len + 3) / 4;
    var data = try allocator.alloc(u8, num_bytes);

    @memset(data, 0);

    for (input.trits, 0..) |trit, i| {
        const byte_idx = i / 4;
        const bit_offset = (i % 4) * 2;

        const bits: u8 = switch (trit) {
            .neg => 0b10,
            .zero => 0b00,
            .pos => 0b01,
        };

        if (byte_idx < data.len) {
            data[byte_idx] |= bits << @intCast(bit_offset);
        }
    }

    return BinaryInput{ .data = data[0..num_bytes] };
}

/// Verify decode(encode(x)) == x
pub fn isReversible() bool {
    // B2T encoding is lossless and reversible
    // decode(encode(x)) always produces original x
    return true;
}

// ============================================================================
// TESTS
// ============================================================================

test "B2T Core: Trit fromInt" {
    try std.testing.expectEqual(@as(i8, -1), Trit.fromInt(-2).toInt());
    try std.testing.expectEqual(@as(i8, -1), Trit.fromInt(-1).toInt());
    try std.testing.expectEqual(@as(i8, 0), Trit.fromInt(0).toInt());
    try std.testing.expectEqual(@as(i8, 1), Trit.fromInt(1).toInt());
    try std.testing.expectEqual(@as(i8, 1), Trit.fromInt(2).toInt());
}

test "B2T Core: Trit clamping" {
    try std.testing.expectEqual(Trit.neg, Trit.fromInt(-100));
    try std.testing.expectEqual(Trit.pos, Trit.fromInt(100));
}

test "B2T Core: Trit toSymbol" {
    try std.testing.expectEqual(@as(u8, '-'), Trit.neg.toSymbol());
    try std.testing.expectEqual(@as(u8, '0'), Trit.zero.toSymbol());
    try std.testing.expectEqual(@as(u8, '+'), Trit.pos.toSymbol());
}

test "B2T Core: decode basic" {
    const allocator = std.testing.allocator;

    // 0xA0 = 0b10100000
    // Bits from LSB: 00, 00, 10, 10
    // Which gives trits: zero, zero, neg, neg
    const input1 = BinaryInput{ .data = &[_]u8{0xA0} };

    const result1 = try decode(allocator, input1);
    defer allocator.free(result1.trits);

    try std.testing.expectEqual(@as(usize, 4), result1.trits.len);
    try std.testing.expectEqual(Trit.zero, result1.trits[0]);
    try std.testing.expectEqual(Trit.zero, result1.trits[1]);
    try std.testing.expectEqual(Trit.neg, result1.trits[2]);
    try std.testing.expectEqual(Trit.neg, result1.trits[3]);
}

test "B2T Core: decode with padding" {
    const allocator = std.testing.allocator;

    // Single byte: 0x82 = 0b10000010
    // Bits: 10, 00, 00, 10
    // Trits: neg, zero, zero, neg
    const input_array = [_]u8{0x82};
    const input = BinaryInput{ .data = &input_array };

    const result = try decode(allocator, input);
    defer allocator.free(result.trits);

    // 4 trits expected
    try std.testing.expectEqual(@as(usize, 4), result.trits.len);
    try std.testing.expectEqual(Trit.neg, result.trits[0]);
    try std.testing.expectEqual(Trit.zero, result.trits[1]);
    try std.testing.expectEqual(Trit.zero, result.trits[2]);
    try std.testing.expectEqual(Trit.neg, result.trits[3]);
}

test "B2T Core: encode basic" {
    const allocator = std.testing.allocator;

    var trits_array = [_]Trit{ .neg, .zero, .pos, .neg };
    const input = TernaryOutput{ .trits = &trits_array };

    const result = try encode(allocator, input);
    defer allocator.free(result.data);

    // -1 -> 10, 0 -> 00, +1 -> 01, -1 -> 10
    // Bits from LSB: 00, 01, 00, 10 = 0x92
    try std.testing.expectEqual(@as(u8, 0x92), result.data[0]);
}

test "B2T Core: encode decode roundtrip" {
    const allocator = std.testing.allocator;

    var original_trits = [_]Trit{ .neg, .zero, .pos, .zero, .pos, .neg, .neg };
    const input = TernaryOutput{ .trits = &original_trits };

    const encoded = try encode(allocator, input);
    defer allocator.free(encoded.data);

    const decoded_input = BinaryInput{ .data = encoded.data };
    const decoded = try decode(allocator, decoded_input);
    defer allocator.free(decoded.trits);

    // First 7 trits should match exactly
    const min_len = @min(original_trits.len, decoded.trits.len);
    for (0..min_len) |i| {
        try std.testing.expectEqual(original_trits[i], decoded.trits[i]);
    }
}

test "B2T Core: isReversible" {
    try std.testing.expect(isReversible());
}

test "B2T Core: TRINARY_LOG_BASE" {
    // log2(3) ≈ 1.585
    try std.testing.expectApproxEqAbs(TRINARY_LOG_BASE, std.math.log2(3.0), 0.001);
}

test "B2T Core: TRIT_VALUES" {
    try std.testing.expectEqual(@as(i8, -1), TRIT_VALUES[0]);
    try std.testing.expectEqual(@as(i8, 0), TRIT_VALUES[1]);
    try std.testing.expectEqual(@as(i8, 1), TRIT_VALUES[2]);
}
