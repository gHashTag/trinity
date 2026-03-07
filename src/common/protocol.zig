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
