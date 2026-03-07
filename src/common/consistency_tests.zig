//! ═══════════════════════════════════════════════════════════════════════════════
//! CONSISTENCY TESTS — Cross-module validation
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Validates consistency between:
//! - Sacred constants across modules
//! - Protocol definitions (protocol.zig vs hardware)
//! - CRC implementation correctness
//!
//! φ² + φ⁻² = 3 = TRINITY
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const constants = @import("constants.zig");
const protocol = @import("protocol.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS VALIDATION
// ═══════════════════════════════════════════════════════════════════════════════

test "Consistency: PHI identity φ² + φ⁻² = 3" {
    const testing = std.testing;

    // TRINITY should be exactly 3.0
    try testing.expectEqual(@as(f64, 3.0), constants.TRINITY);

    // Verify individual components
    try testing.expectApproxEqAbs(constants.PHI_SQ, constants.PHI * constants.PHI, 1e-15);
    try testing.expectApproxEqAbs(constants.PHI_INV_SQ, 1.0 / (constants.PHI * constants.PHI), 1e-15);

    // Verify the identity holds
    const identity = constants.PHI_SQ + constants.PHI_INV_SQ;
    try testing.expectApproxEqAbs(identity, 3.0, 1e-15);
}

test "Consistency: GAMMA = φ⁻³" {
    const testing = std.testing;

    const expected_gamma = 1.0 / (constants.PHI * constants.PHI * constants.PHI);
    try testing.expectApproxEqAbs(constants.GAMMA, expected_gamma, 1e-15);
}

test "Consistency: Consciousness thresholds" {
    const testing = std.testing;

    // IMMORTAL threshold should be exactly φ⁻¹
    try testing.expectEqual(constants.CONSCIOUSNESS_IMMORTAL, constants.PHI_INV);

    // MORTAL should be below immortality threshold
    try testing.expect(constants.CONSCIOUSNESS_MORTAL < constants.PHI_INV);

    // TRANSCENDENT should be maximum (1.0)
    try testing.expectEqual(constants.CONSCIOUSNESS_TRANSCENDENT, 1.0);
}

test "Consistency: VSA dimensions are φ-powered" {
    const testing = std.testing;

    // VSA_DIM_DEFAULT should be φ² × 1000 (approximately)
    const expected_default = @as(usize, @intFromFloat(1000 * constants.PHI * constants.PHI));
    try testing.expectEqual(constants.VSA_DIM_DEFAULT, expected_default);

    // VSA_DIM_PHI should be φ × 1000 (approximately)
    const expected_phi = @as(usize, @intFromFloat(1000 * constants.PHI));
    try testing.expectEqual(constants.VSA_DIM_PHI, expected_phi);

    // Both should be above minimum
    try testing.expect(constants.VSA_DIM_DEFAULT >= constants.VSA_DIM_MIN);
    try testing.expect(constants.VSA_DIM_PHI >= constants.VSA_DIM_MIN);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROTOCOL CONSISTENCY TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Consistency: Trit enum values match standard" {
    const testing = std.testing;

    // Trit should have exactly 3 values: -1, 0, +1
    try testing.expectEqual(@as(i8, -1), protocol.Trit.neg.value());
    try testing.expectEqual(@as(i8, 0), protocol.Trit.zero.value());
    try testing.expectEqual(@as(i8, 1), protocol.Trit.pos.value());
}

test "Consistency: VSA command encodings match hardware" {
    const testing = std.testing;

    // VSACmd encoding should match vsa_coprocessor.v
    // CMD_NOP = 0, CMD_BIND = 1, CMD_UNBIND = 2, etc.
    try testing.expectEqual(@as(u3, 0), @intFromEnum(protocol.VSACmd.nop));
    try testing.expectEqual(@as(u3, 1), @intFromEnum(protocol.VSACmd.bind));
    try testing.expectEqual(@as(u3, 2), @intFromEnum(protocol.VSACmd.unbind));
    try testing.expectEqual(@as(u3, 3), @intFromEnum(protocol.VSACmd.bundle2));
    try testing.expectEqual(@as(u3, 4), @intFromEnum(protocol.VSACmd.bundle3));
    try testing.expectEqual(@as(u3, 5), @intFromEnum(protocol.VSACmd.similarity));
}

test "Consistency: UART command IDs" {
    const testing = std.testing;

    // UARTCommand should have correct IDs
    try testing.expectEqual(@as(u8, 0x00), @intFromEnum(protocol.UARTCommand.nop));
    try testing.expectEqual(@as(u8, 0x01), @intFromEnum(protocol.UARTCommand.bind));
    try testing.expectEqual(@as(u8, 0x02), @intFromEnum(protocol.UARTCommand.unbind));
    try testing.expectEqual(@as(u8, 0x03), @intFromEnum(protocol.UARTCommand.bundle2));
    try testing.expectEqual(@as(u8, 0x04), @intFromEnum(protocol.UARTCommand.bundle3));
    try testing.expectEqual(@as(u8, 0x05), @intFromEnum(protocol.UARTCommand.similarity));
}

test "Consistency: UART protocol constants" {
    const testing = std.testing;

    // Verify standard protocol values
    try testing.expectEqual(@as(u8, 0xAA), protocol.UART_SYNC_BYTE);
    try testing.expectEqual(@as(usize, 256), protocol.UART_MAX_FRAME_SIZE);
    try testing.expectEqual(@as(u32, 115200), protocol.UART_BAUD_DEFAULT);
    try testing.expectEqual(@as(u8, 0x01), protocol.PROTOCOL_VERSION);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CRC VALIDATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Consistency: CRC16 CCITT standard test vectors" {
    const testing = std.testing;

    // Standard test vector from CRC-16/CCITT specification
    const input = "123456789";
    const expected: u16 = 0x29B1;

    const result = protocol.crc16Ccitt(input);
    try testing.expectEqual(expected, result);
}

test "Consistency: CRC16 CCITT empty input" {
    const testing = std.testing;

    // Empty input should return initial value
    const result = protocol.crc16Ccitt("");
    try testing.expectEqual(@as(u16, 0xFFFF), result);
}

test "Consistency: CRC16 CCITT single byte" {
    const testing = std.testing;

    // Test single byte
    const input = "\x00";
    const result = protocol.crc16Ccitt(input);
    // Expected: 0xFFFF ^ (0x00 << 8) = 0x00FF, then CRC process
    // This is just to verify the function runs without error
    try testing.expect(result != 0xFFFF);
}

test "Consistency: CRC16 CCITT all zeros" {
    const testing = std.testing;

    // All zeros should produce known result
    const input = "\x00\x00\x00\x00";
    const result = protocol.crc16Ccitt(input);
    try testing.expect(result != 0xFFFF);
}

test "Consistency: CRC16 CCITT all ones" {
    const testing = std.testing;

    // All ones should produce known result
    const input = "\xFF\xFF\xFF\xFF";
    const result = protocol.crc16Ccitt(input);
    try testing.expect(result != 0xFFFF);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CROSS-MODULE CONSISTENCY TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Consistency: Protocol commands match UART commands" {
    const testing = std.testing;

    // VSACmd and UARTCommand should have consistent numeric values
    try testing.expectEqual(@intFromEnum(protocol.VSACmd.nop), @intFromEnum(protocol.UARTCommand.nop));
    try testing.expectEqual(@intFromEnum(protocol.VSACmd.bind), @intFromEnum(protocol.UARTCommand.bind));
    try testing.expectEqual(@intFromEnum(protocol.VSACmd.unbind), @intFromEnum(protocol.UARTCommand.unbind));
    try testing.expectEqual(@intFromEnum(protocol.VSACmd.bundle2), @intFromEnum(protocol.UARTCommand.bundle2));
    try testing.expectEqual(@intFromEnum(protocol.VSACmd.bundle3), @intFromEnum(protocol.UARTCommand.bundle3));
    try testing.expectEqual(@intFromEnum(protocol.VSACmd.similarity), @intFromEnum(protocol.UARTCommand.similarity));
}

test "Consistency: TRINITY identity across contexts" {
    const testing = std.testing;

    // Verify TRINITY identity holds in multiple ways
    // Method 1: Direct from constants
    try testing.expectEqual(@as(f64, 3.0), constants.TRINITY);

    // Method 2: Computed from PHI
    const computed = constants.PHI * constants.PHI + 1.0 / (constants.PHI * constants.PHI);
    try testing.expectApproxEqAbs(constants.TRINITY, computed, 1e-15);

    // Method 3: Via PHI_SQ and PHI_INV_SQ
    const via_squares = constants.PHI_SQ + constants.PHI_INV_SQ;
    try testing.expectApproxEqAbs(constants.TRINITY, via_squares, 1e-15);
}

test "Consistency: VSA dimension calculation consistency" {
    const testing = std.testing;

    // VSA_DIM_DEFAULT should be consistently computed
    const direct = @as(usize, @intFromFloat(1000 * constants.PHI * constants.PHI));
    try testing.expectEqual(constants.VSA_DIM_DEFAULT, direct);

    // Should match named constant
    try testing.expectEqual(constants.VSA_DIM_DEFAULT, 2618);
}
