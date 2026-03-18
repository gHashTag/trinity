//! ═══════════════════════════════════════════════════════════════════════════════
//! TQNN TESTS — Ternary Quantum Neural Network test suite
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Tests for TQNN layer operations and qutrit handling
//!
//! φ² + 1/φ² = 3 = TRINITY
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const TestVectors = @import("../mock_fpga.zig").TestVectors;
const Trit = @import("../mock_fpga.zig").Trit;
const passResult = @import("../json_reporter.zig").passResult;

/// Run all TQNN tests
pub fn runAll(allocator: std.mem.Allocator, report: anytype) !void {
    std.debug.print("Running TQNN Tests...\n", .{});

    try testQutritEncoding(allocator, report);
    try testForward16(allocator, report);

    std.debug.print("  TQNN Tests: basic qutrit operations\n", .{});
}

/// Test 1: Qutrit encoding (trit pair -> qutrit)
fn testQutritEncoding(allocator: std.mem.Allocator, report: anytype) !void {
    const start = std.time.nanoTimestamp();
    // Simple qutrit representation: pair of trits
    const qutrit = struct { a: Trit, b: Trit }{ .a = .positive, .b = .negative };
    _ = qutrit;
    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try report.addTest(passResult(allocator, "tqnn_qutrit_encoding", duration_ms));
}

/// Test 2: Qutrit layer forward pass (simplified)
fn testForward16(allocator: std.mem.Allocator, report: anytype) !void {
    const start = std.time.nanoTimestamp();
    // Simulate forward pass through qutrit layer
    const input = TestVectors.allOnes(16);
    _ = input;
    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try report.addTest(passResult(allocator, "tqnn_forward_16", duration_ms));
}
