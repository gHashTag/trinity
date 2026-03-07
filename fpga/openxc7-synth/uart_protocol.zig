//! ═══════════════════════════════════════════════════════════════════════════════
//! UART PROTOCOL — Shared definitions for FPGA UART communication
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Common protocol definitions used across uart_host modules.
//! Eliminates duplication between uart_host_v5.zig, uart_host_v6.zig, etc.
//!
//! φ² + 1/φ² = 3 = TRINITY
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// ═══════════════════════════════════════════════════════════════════════════════
/// TRINITY V1 COMMAND PROTOCOL
/// ═══════════════════════════════════════════════════════════════════════════════
pub const Command = enum(u8) {
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

pub const Response = enum(u8) {
    /// Operation successful
    OK = 0x00,
    /// PING response
    PONG = 0xAA,
};

/// ═══════════════════════════════════════════════════════════════════════════════
/// TRIT ENCODING (2-bit packed)
/// ═══════════════════════════════════════════════════════════════════════════════
pub const Trit = enum(u2) {
    /// Negative trit (-1)
    NEGATIVE = 0b10,
    /// Zero trit (0)
    ZERO = 0b00,
    /// Positive trit (+1)
    POSITIVE = 0b01,
};

/// Convert Trit to numeric value
pub fn tritValue(t: Trit) i2 {
    return switch (t) {
        .POSITIVE => 1,
        .NEGATIVE => -1,
        .ZERO => 0,
    };
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// PROTOCOL CONSTANTS
/// ═══════════════════════════════════════════════════════════════════════════════
pub const UART_DEVICE = "/dev/ttyUSB0";
pub const BAUD_RATE = 115200;
pub const TIMEOUT_MS = 5000;
pub const SYNC_BYTE: u8 = 0xAA;

pub const VECTOR_SIZE: usize = 16;
pub const VECTOR_BYTES: usize = 4;

/// ═══════════════════════════════════════════════════════════════════════════════
/// CRC-16/CCITT
/// ═══════════════════════════════════════════════════════════════════════════════
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
    return crc & 0xFFFF;
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// LED MODES
/// ═══════════════════════════════════════════════════════════════════════════════
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
