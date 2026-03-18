//! ═══════════════════════════════════════════════════════════════════════════════
//! PROTOCOL DEFINITIONS — Single Source of Truth for Trinity Protocols
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! This module provides canonical protocol definitions used throughout Trinity.
//! DO NOT duplicate these values elsewhere.
//!
//! IMPORT: const protocol = @import("common").protocol;
//! USAGE: protocol.Trit, protocol.crc16Ccitt(), etc.
//!
//! φ² + φ⁻² = 3 = TRINITY
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// ═══════════════════════════════════════════════════════════════════════════════
/// TRIT — Ternary Digit
/// ═══════════════════════════════════════════════════════════════════════════════
/// Three-valued logic: {-1, 0, +1}
///
/// Used throughout VSA, ternary computing, and consciousness models.
/// Encoded as i8 for compatibility, but values are restricted to -1, 0, +1.
pub const Trit = enum(i8) {
    /// Negative trit (-1)
    neg = -1,
    /// Zero trit (0)
    zero = 0,
    /// Positive trit (+1)
    pos = 1,

    /// Convert raw i8 to Trit (with validation)
    pub fn from(input: i8) error{InvalidTrit}!Trit {
        return switch (input) {
            -1 => .neg,
            0 => .zero,
            1 => .pos,
            else => error.InvalidTrit,
        };
    }

    /// Get numeric value as i8
    pub fn value(self: Trit) i8 {
        return @intFromEnum(self);
    }

    /// Check if trit is zero
    pub fn isZero(self: Trit) bool {
        return self == .zero;
    }

    /// Check if trit is non-zero
    pub fn isNonZero(self: Trit) bool {
        return self != .zero;
    }
};

/// Error for invalid trit values
pub const InvalidTritError = error{InvalidTrit};

/// ═══════════════════════════════════════════════════════════════════════════════
/// CRC-16/CCITT — Cyclic Redundancy Check
/// ═══════════════════════════════════════════════════════════════════════════════
/// Polynomial: 0x1021 (x^16 + x^12 + x^5 + 1)
/// Initial: 0xFFFF
/// Final XOR: 0x0000
/// Input/Output Reflected: No
///
/// Standard CRC used in UART, Modbus, and many other protocols.
///
/// Algorithm: CRC-16/CCITT (False)
/// - Width: 16 bits
/// - Poly: 0x1021
/// - Init: 0xFFFF
/// - RefIn: False
/// - RefOut: False
/// - XorOut: 0x0000
pub fn crc16Ccitt(data: []const u8) u16 {
    var crc: u16 = 0xFFFF;

    for (data) |byte| {
        crc ^= @as(u16, byte) << 8;
        var i: u4 = 0;
        while (i < 8) : (i += 1) {
            if (crc & 0x8000 != 0) {
                crc = (crc << 1) ^ 0x1021;
            } else {
                crc = crc << 1;
            }
        }
    }

    return crc;
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// UART PROTOCOL COMMANDS
/// ═══════════════════════════════════════════════════════════════════════════════
/// Command IDs for VSA FPGA communication protocol
pub const UARTCommand = enum(u8) {
    /// No operation
    nop = 0x00,
    /// Bind two vectors (associative)
    bind = 0x01,
    /// Unbind vector with key
    unbind = 0x02,
    /// Bundle 2 vectors (majority vote)
    bundle2 = 0x03,
    /// Bundle 3 vectors (majority vote)
    bundle3 = 0x04,
    /// Compute cosine similarity
    similarity = 0x05,
    /// Reserved
    reserved = 0xFF,
};

/// ═══════════════════════════════════════════════════════════════════════════════
/// PROTOCOL CONSTANTS
/// ═══════════════════════════════════════════════════════════════════════════════
/// UART sync byte for frame synchronization
pub const UART_SYNC_BYTE: u8 = 0xAA;

/// Maximum UART frame size (in bytes)
pub const UART_MAX_FRAME_SIZE: usize = 256;

/// Default UART baud rate
pub const UART_BAUD_DEFAULT: u32 = 115200;

/// Protocol version identifier
pub const PROTOCOL_VERSION: u8 = 0x01;

/// ═══════════════════════════════════════════════════════════════════════════════
/// VSA COMMAND ENCODINGS (for FPGA coprocessor)
/// ═══════════════════════════════════════════════════════════════════════════════
/// Command encoding for VSA coprocessor (3-bit command)
pub const VSACmd = enum(u3) {
    /// No operation
    nop = 0,
    /// Bind: result = vec_a × vec_b
    bind = 1,
    /// Unbind: result = vec_a × permute_inv(vec_b)
    unbind = 2,
    /// Bundle 2: result = majority(vec_a, vec_b)
    bundle2 = 3,
    /// Bundle 3: result = majority(vec_a, vec_b, vec_c)
    bundle3 = 4,
    /// Similarity: similarity_out = cosine(vec_a, vec_b)
    similarity = 5,
};

/// ═══════════════════════════════════════════════════════════════════════════════
/// TRINITY V1 PROTOCOL — FPGA UART Communication
/// ═══════════════════════════════════════════════════════════════════════════════
/// Protocol for UART communication with Trinity V1 FPGA firmware
/// Used in: fpga/openxc7-synth/uart_host_*.zig
pub const TrinityV1Command = enum(u8) {
    /// Set LED mode
    MODE = 0x01,
    /// VSA bind operation
    BIND = 0x02,
    /// VSA bundle operation
    BUNDLE = 0x03,
    /// Cosine similarity score
    SIMILARITY = 0x04,
    /// Tiny BitNet inference
    BITNET = 0x05,
    /// Connectivity test
    PING = 0xFF,
};

pub const TrinityV1Response = enum(u8) {
    /// Operation successful
    OK = 0x00,
    /// PING response
    PONG = 0xAA,
};

/// LED modes for Trinity V1 firmware
pub const LedMode = enum(u8) {
    /// Separable Bell state
    separable = 0,
    /// Bell violation (|S| > 2)
    violation = 1,
    /// Zero vector
    zero = 2,
    /// Negative vector
    negative = 3,
};

/// ═══════════════════════════════════════════════════════════════════════════════
/// PACKED TRIT ENCODING (2-bit) — FPGA Optimized
/// ═══════════════════════════════════════════════════════════════════════════════
/// 2-bit packed trit encoding for efficient FPGA storage and transmission
/// Encoded as: NEGATIVE=0b10, ZERO=0b00, POSITIVE=0b01
pub const PackedTrit = enum(u2) {
    /// Negative trit (-1) encoded as 0b10
    NEGATIVE = 0b10,
    /// Zero trit (0) encoded as 0b00
    ZERO = 0b00,
    /// Positive trit (+1) encoded as 0b01
    POSITIVE = 0b01,
};

/// Convert PackedTrit to numeric value
pub fn packedTritValue(t: PackedTrit) i2 {
    return switch (t) {
        .POSITIVE => 1,
        .NEGATIVE => -1,
        .ZERO => 0,
    };
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// TRINITY V1 PROTOCOL CONSTANTS
/// ═══════════════════════════════════════════════════════════════════════════════
pub const UART_DEVICE = "/dev/ttyUSB0";
pub const BAUD_RATE = 115200;
pub const TIMEOUT_MS = 5000;
pub const SYNC_BYTE: u8 = 0xAA;

pub const VECTOR_SIZE: usize = 16;
pub const VECTOR_BYTES: usize = 4;

/// ═══════════════════════════════════════════════════════════════════════════════
/// CONVERSION UTILITIES
/// ═══════════════════════════════════════════════════════════════════════════════
/// Convert packed trits to binary string (for debugging)
pub fn tritsToString(trits: []const Trit, allocator: std.mem.Allocator) ![]u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, trits.len * 2);
    defer result.deinit(allocator);

    for (trits) |trit| {
        const label = switch (trit) {
            .neg => "-",
            .zero => "0",
            .pos => "+",
        };
        try result.appendSlice(allocator, label);
    }

    return result.toOwnedSlice(allocator);
}

/// Parse trit from string representation
pub fn tritFromString(s: []const u8) error{InvalidTrit}!Trit {
    if (s.len != 1) return error.InvalidTrit;
    return switch (s[0]) {
        '-', 'n', 'N' => .neg,
        '0', 'o', 'O' => .zero,
        '+', 'p', 'P' => .pos,
        else => error.InvalidTrit,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Protocol: Trit validation" {
    const testing = std.testing;

    try testing.expectEqual(@as(i8, -1), Trit.neg.value());
    try testing.expectEqual(@as(i8, 0), Trit.zero.value());
    try testing.expectEqual(@as(i8, 1), Trit.pos.value());

    try testing.expectEqual(Trit.neg, try Trit.from(-1));
    try testing.expectEqual(Trit.zero, try Trit.from(0));
    try testing.expectEqual(Trit.pos, try Trit.from(1));
    try testing.expectError(error.InvalidTrit, Trit.from(2));
}

test "Protocol: Trit properties" {
    const testing = std.testing;

    try testing.expect(Trit.zero.isZero());
    try testing.expect(!Trit.neg.isZero());
    try testing.expect(!Trit.pos.isZero());

    try testing.expect(Trit.neg.isNonZero());
    try testing.expect(Trit.pos.isNonZero());
    try testing.expect(!Trit.zero.isNonZero());
}

test "Protocol: CRC16 CCITT" {
    const testing = std.testing;

    // Test vector: "123456789"
    const input = "123456789";
    const expected: u16 = 0x29B1;

    const result = crc16Ccitt(input[0..]);
    try testing.expectEqual(expected, result);
}

test "Protocol: CRC16 CCITT empty" {
    const testing = std.testing;

    const result = crc16Ccitt("");
    try testing.expectEqual(@as(u16, 0xFFFF), result);
}

test "Protocol: Trit string conversion" {
    const testing = std.testing;

    const trits = [_]Trit{ .neg, .zero, .pos, .neg };
    const result = try tritsToString(&trits, testing.allocator);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("-0+-", result);
}

test "Protocol: Trit from string" {
    const testing = std.testing;

    try testing.expectEqual(Trit.neg, try tritFromString("-"));
    try testing.expectEqual(Trit.zero, try tritFromString("0"));
    try testing.expectEqual(Trit.pos, try tritFromString("+"));

    try testing.expectEqual(Trit.neg, try tritFromString("n"));
    try testing.expectEqual(Trit.zero, try tritFromString("O"));
    try testing.expectEqual(Trit.pos, try tritFromString("P"));

    try testing.expectError(error.InvalidTrit, tritFromString("2"));
    try testing.expectError(error.InvalidTrit, tritFromString("x"));
}

test "Protocol: VSA Command encodings" {
    const testing = std.testing;

    try testing.expectEqual(@as(u3, 0), @intFromEnum(VSACmd.nop));
    try testing.expectEqual(@as(u3, 1), @intFromEnum(VSACmd.bind));
    try testing.expectEqual(@as(u3, 2), @intFromEnum(VSACmd.unbind));
    try testing.expectEqual(@as(u3, 3), @intFromEnum(VSACmd.bundle2));
    try testing.expectEqual(@as(u3, 4), @intFromEnum(VSACmd.bundle3));
    try testing.expectEqual(@as(u3, 5), @intFromEnum(VSACmd.similarity));
}

test "Protocol: TrinityV1 Command encodings" {
    const testing = std.testing;

    try testing.expectEqual(@as(u8, 0x01), @intFromEnum(TrinityV1Command.MODE));
    try testing.expectEqual(@as(u8, 0x02), @intFromEnum(TrinityV1Command.BIND));
    try testing.expectEqual(@as(u8, 0x03), @intFromEnum(TrinityV1Command.BUNDLE));
    try testing.expectEqual(@as(u8, 0x04), @intFromEnum(TrinityV1Command.SIMILARITY));
    try testing.expectEqual(@as(u8, 0x05), @intFromEnum(TrinityV1Command.BITNET));
    try testing.expectEqual(@as(u8, 0xFF), @intFromEnum(TrinityV1Command.PING));
}

test "Protocol: TrinityV1 Response encodings" {
    const testing = std.testing;

    try testing.expectEqual(@as(u8, 0x00), @intFromEnum(TrinityV1Response.OK));
    try testing.expectEqual(@as(u8, 0xAA), @intFromEnum(TrinityV1Response.PONG));
}

test "Protocol: LedMode encodings" {
    const testing = std.testing;

    try testing.expectEqual(@as(u8, 0), @intFromEnum(LedMode.separable));
    try testing.expectEqual(@as(u8, 1), @intFromEnum(LedMode.violation));
    try testing.expectEqual(@as(u8, 2), @intFromEnum(LedMode.zero));
    try testing.expectEqual(@as(u8, 3), @intFromEnum(LedMode.negative));
}

test "Protocol: PackedTrit encodings" {
    const testing = std.testing;

    try testing.expectEqual(@as(u2, 0b10), @intFromEnum(PackedTrit.NEGATIVE));
    try testing.expectEqual(@as(u2, 0b00), @intFromEnum(PackedTrit.ZERO));
    try testing.expectEqual(@as(u2, 0b01), @intFromEnum(PackedTrit.POSITIVE));
}

test "Protocol: PackedTrit values" {
    const testing = std.testing;

    try testing.expectEqual(@as(i2, -1), packedTritValue(PackedTrit.NEGATIVE));
    try testing.expectEqual(@as(i2, 0), packedTritValue(PackedTrit.ZERO));
    try testing.expectEqual(@as(i2, 1), packedTritValue(PackedTrit.POSITIVE));
}

test "Protocol: TrinityV1 constants" {
    const testing = std.testing;

    try testing.expectEqual(@as(usize, 16), VECTOR_SIZE);
    try testing.expectEqual(@as(usize, 4), VECTOR_BYTES);
    try testing.expectEqual(@as(u8, 0xAA), SYNC_BYTE);
    try testing.expectEqual(@as(u32, 115200), BAUD_RATE);
    try testing.expectEqual(@as(u32, 5000), TIMEOUT_MS);
}
