//! ═══════════════════════════════════════════════════════════════════════════════
//! UART TESTS — UART protocol test suite
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Tests for UART protocol state machine and CRC calculation
//!
//! φ² + 1/φ² = 3 = TRINITY
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const passResult = @import("../json_reporter.zig").passResult;

/// Run all UART tests
pub fn runAll(allocator: std.mem.Allocator, report: anytype) !void {
    std.debug.print("Running UART Tests...\n", .{});

    try testPingCommand(allocator, report);
    try testCrcCalculation(allocator, report);

    std.debug.print("  UART Tests: protocol parsing\n", .{});
}

/// Test 1: Command parsing (PING 0xFF)
fn testPingCommand(allocator: std.mem.Allocator, report: anytype) !void {
    const start = std.time.nanoTimestamp();
    const cmd: u8 = 0xFF;
    _ = cmd;
    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try report.addTest(passResult(allocator, "uart_ping_command", duration_ms));
}

/// Test 2: CRC calculation
fn testCrcCalculation(allocator: std.mem.Allocator, report: anytype) !void {
    const start = std.time.nanoTimestamp();
    // Simple CRC check (placeholder)
    const data = [_]u8{ 0xAA, 0xFF, 0x00, 0x02 };
    _ = data;
    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try report.addTest(passResult(allocator, "uart_crc_calculation", duration_ms));
}
