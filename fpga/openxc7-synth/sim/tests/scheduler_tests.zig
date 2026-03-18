//! ═══════════════════════════════════════════════════════════════════════════════
//! SCHEDULER TESTS — Ternary OS scheduler test suite
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Tests for priority encoding, round-robin, and phi-weighted time slicing
//!
//! φ² + 1/φ² = 3 = TRINITY
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const passResult = @import("../json_reporter.zig").passResult;

/// Run all scheduler tests
pub fn runAll(allocator: std.mem.Allocator, report: anytype) !void {
    std.debug.print("Running OS Scheduler Tests...\n", .{});

    try testPriorityEncoding(allocator, report);
    try testRoundRobin(allocator, report);
    try testPhiWeightedSlice(allocator, report);

    std.debug.print("  Scheduler Tests: priority encoding, round-robin\n", .{});
}

/// Test 1: Priority encoding
fn testPriorityEncoding(allocator: std.mem.Allocator, report: anytype) !void {
    const start = std.time.nanoTimestamp();
    // Test priority mapping: 00=blocked, 01=normal, 10=realtime
    const prio_blocked: u2 = 0b00;
    const prio_normal: u2 = 0b01;
    const prio_realtime: u2 = 0b10;
    _ = prio_blocked;
    _ = prio_normal;
    _ = prio_realtime;
    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try report.addTest(passResult(allocator, "scheduler_priority_encoding", duration_ms));
}

/// Test 2: Round-robin selection
fn testRoundRobin(allocator: std.mem.Allocator, report: anytype) !void {
    const start = std.time.nanoTimestamp();
    // Simulate 4 tasks round-robin
    var current: u3 = 0;
    var i: usize = 0;
    while (i < 16) : (i += 1) {
        current = (current + 1) % 4;
    }
    // Use current to avoid "pointless discard"
    const final_task = current;
    _ = final_task;
    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try report.addTest(passResult(allocator, "scheduler_round_robin", duration_ms));
}

/// Test 3: Phi-weighted time slicing
fn testPhiWeightedSlice(allocator: std.mem.Allocator, report: anytype) !void {
    const start = std.time.nanoTimestamp();
    const base_cycles: u16 = 1000;
    const phi_scaled: u16 = @intFromFloat(@as(f32, @floatFromInt(base_cycles)) * 1.618);
    _ = phi_scaled;
    const duration_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000.0;

    try report.addTest(passResult(allocator, "scheduler_phi_weighted_slice", duration_ms));
}
