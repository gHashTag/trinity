//! ═══════════════════════════════════════════════════════════════════════════════
//! UART HOST v6.0 (REFACTORED) — TRINITY V1
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Refactored version using shared modules:
//! - uart_protocol.zig: Protocol definitions, Trit, CRC
//! - uart_vectors.zig: VSA vector operations
//!
//! This file contains ONLY UART communication logic and command routing.
//!
//! φ² + 1/φ² = 3 = TRINITY
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Import from common protocol SSOT
const protocol = @import("../../src/common/protocol.zig");
const vectors = @import("uart_vectors.zig");

// Re-export commonly used items for backward compatibility
pub const Command = protocol.TrinityV1Command;
pub const Response = protocol.TrinityV1Response;
pub const LedMode = protocol.LedMode;
pub const UART_DEVICE = protocol.UART_DEVICE;
pub const BAUD_RATE = protocol.BAUD_RATE;
pub const TIMEOUT_MS = protocol.TIMEOUT_MS;
pub const SYNC_BYTE = protocol.SYNC_BYTE;
pub const VECTOR_SIZE = protocol.VECTOR_SIZE;
pub const VECTOR_BYTES = protocol.VECTOR_BYTES;
pub const crc16Ccitt = protocol.crc16Ccitt;

// Convenience aliases
pub const randomVector = vectors.randomVector;
pub const allOnesVector = vectors.allOnesVector;
pub const allZerosVector = vectors.allZerosVector;
pub const alternatingVector = vectors.alternatingVector;
pub const encodeVector = vectors.encodeVector;
pub const decodeVector = vectors.decodeVector;
pub const printVector = vectors.printVector;
pub const similarityVectors = vectors.similarityVectors;
pub const bindVectors = vectors.bindVectors;
pub const bundleVectors = vectors.bundleVectors;

/// ═══════════════════════════════════════════════════════════════════════════════
/// MAIN ENTRY POINT
/// ═══════════════════════════════════════════════════════════════════════════════
pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    if (args.len < 2) {
        printUsage(args[0]);
        return error.InvalidArgs;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "loopback")) {
        try testLoopback();
        return;
    }

    const port = openUart() catch |err| {
        std.log.err("Failed to open UART: {}", .{err});
        return err;
    };
    defer port.close();

    std.debug.print("╔════════════════════════════════════════╗\n", .{});
    std.debug.print("║     TRINITY V1 — UART Host v6.0       ║\n", .{});
    std.debug.print("║     φ² + 1/φ² = 3                     ║\n", .{});
    std.debug.print("╚════════════════════════════════════════╝\n", .{});
    std.debug.print("Device: {s}\n", .{UART_DEVICE});
    std.debug.print("Baud: {d}\n", .{BAUD_RATE});
    std.debug.print("════════════════════════════════════════\n\n", .{});

    // Route commands
    if (std.mem.eql(u8, command, "ping")) {
        _ = try testPing(port);
    } else if (std.mem.eql(u8, command, "mode")) {
        const mode = if (args.len > 2) args[2] else "violation";
        try setLedMode(port, mode);
    } else if (std.mem.eql(u8, command, "bind")) {
        _ = try runBindTest(port);
    } else if (std.mem.eql(u8, command, "bundle")) {
        _ = try runBundleTest(port);
    } else if (std.mem.eql(u8, command, "similarity")) {
        _ = try runSimilarityTest(port);
    } else if (std.mem.eql(u8, command, "benchmark")) {
        _ = try runBenchmark(port);
    } else if (std.mem.eql(u8, command, "test")) {
        _ = try runFullTest(port);
    } else {
        std.log.err("Unknown command: {s}", .{command});
        printUsage(args[0]);
    }
}

fn printUsage(prog: []const u8) void {
    std.debug.print(
        \\
        \\Usage: {s} <command> [options]
        \\
        \\Trinity V1 Commands:
        \\  loopback          - Test UART cable (short TX-RX, no FPGA needed)
        \\  ping              - Test FPGA connectivity (0xFF -> 0xAA PONG)
        \\  mode <type>       - Set LED mode: separable|violation|zero|negative
        \\  bind              - Test BIND operation (16-trit vectors)
        \\  bundle            - Test BUNDLE operation (16-trit vectors)
        \\  similarity        - Test SIMILARITY (cosine score 0-255)
        \\  benchmark         - Run full benchmark with timing
        \\  test              - Run full test suite
        \\
        \\Examples:
        \\  {s} loopback        # Verify cable
        \\  {s} ping            # Test FPGA
        \\  {s} benchmark       # Full benchmark
        \\
    , .{prog, prog, prog, prog});
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// UART COMMUNICATION
/// ═══════════════════════════════════════════════════════════════════════════════
fn openUart() !std.fs.File {
    return std.fs.openFileAbsolute(UART_DEVICE, .{ .mode = .read_write });
}

/// Send packet to FPGA
fn sendPacket(port: std.fs.File, cmd: Command, data: []const u8) !void {
    var buffer: [256]u8 = undefined;
    var idx: usize = 0;

    buffer[idx] = SYNC_BYTE;
    idx += 1;
    buffer[idx] = @intFromEnum(cmd);
    idx += 1;

    const len = @as(u8, @intCast(data.len));
    buffer[idx] = len;
    idx += 1;

    @memcpy(buffer[idx..][0..data.len], data);
    idx += data.len;

    const crc = protocol.crc16Ccitt(buffer[0..idx]);
    buffer[idx] = @as(u8, @truncate(crc >> 8));
    idx += 1;
    buffer[idx] = @as(u8, @truncate(crc & 0xFF));
    idx += 1;

    _ = try port.writeAll(buffer[0..idx]);
    std.debug.print("[TX] CMD={X:0>2} LEN={d} CRC={X:0>4}\n", .{@intFromEnum(cmd), len, crc});
}

/// Receive response from FPGA
fn recvResponse(port: std.fs.File, expected_bytes: usize) ![256]u8 {
    var buffer: [256]u8 = undefined;

    const start_time = std.time.milliTimestamp();
    var n: usize = 0;
    while (n < expected_bytes) {
        const elapsed = std.time.milliTimestamp() - start_time;
        if (elapsed > TIMEOUT_MS) {
            std.debug.print("[RX] TIMEOUT after {d}ms\n", .{elapsed});
            return error.Timeout;
        }

        const chunk = try port.read(buffer[n..]);
        if (chunk == 0) continue;
        n += chunk;
    }

    std.debug.print("[RX] {d} bytes: {any}\n", .{n, buffer[0..n]});
    return buffer;
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// TEST FUNCTIONS
/// ═══════════════════════════════════════════════════════════════════════════════
fn testPing(port: std.fs.File) !bool {
    std.debug.print("[PING TEST]\n", .{});
    std.debug.print("════════════════════════════════════════\n", .{});

    _ = try sendPacket(port, .PING, &[_]u8{});
    const response = try recvResponse(port, 1);

    if (response[0] == @intFromEnum(Response.PONG)) {
        std.debug.print("✅ PONG received\n\n", .{});
        return true;
    } else {
        std.debug.print("❌ Unexpected response: 0x{X:0>2}\n\n", .{response[0]});
        return false;
    }
}

fn runBindTest(port: std.fs.File) !bool {
    std.debug.print("[BIND TEST]\n", .{});
    std.debug.print("════════════════════════════════════════\n", .{});

    const vec_a = vectors.randomVector();
    const vec_b = vectors.randomVector();
    const expected = vectors.bindVectors(vec_a, vec_b);

    std.debug.print("Vector A: ", .{});
    vectors.printVector(vec_a);
    std.debug.print("\nVector B: ", .{});
    vectors.printVector(vec_b);
    std.debug.print("\n", .{});

    const data_a = vectors.encodeVector(vec_a);
    const data_b = vectors.encodeVector(vec_b);

    var payload: [8]u8 = undefined;
    @memcpy(payload[0..4], &data_a);
    @memcpy(payload[4..8], &data_b);

    _ = try sendPacket(port, .BIND, &payload);
    const response = try recvResponse(port, 4);

    const result = vectors.decodeVector(response[0..4].*);

    std.debug.print("Expected: ", .{});
    vectors.printVector(expected);
    std.debug.print("\nResult:   ", .{});
    vectors.printVector(result);
    std.debug.print("\n", .{});

    if (std.mem.eql(protocol.Trit, &expected, &result)) {
        std.debug.print("✅ BIND test PASSED\n\n", .{});
        return true;
    } else {
        std.debug.print("❌ BIND test FAILED\n\n", .{});
        return false;
    }
}

fn runBundleTest(port: std.fs.File) !bool {
    std.debug.print("[BUNDLE TEST]\n", .{});
    std.debug.print("════════════════════════════════════════\n", .{});

    const vec_a = vectors.allOnesVector();
    const vec_b = vectors.allZerosVector();
    const expected = vectors.bundleVectors(vec_a, vec_b);

    std.debug.print("Vector A (all +): ", .{});
    vectors.printVector(vec_a);
    std.debug.print("\nVector B (all 0): ", .{});
    vectors.printVector(vec_b);
    std.debug.print("\n", .{});

    const data_a = vectors.encodeVector(vec_a);
    const data_b = vectors.encodeVector(vec_b);

    var payload: [8]u8 = undefined;
    @memcpy(payload[0..4], &data_a);
    @memcpy(payload[4..8], &data_b);

    _ = try sendPacket(port, .BUNDLE, &payload);
    const response = try recvResponse(port, 4);

    const result = vectors.decodeVector(response[0..4].*);

    std.debug.print("Expected: ", .{});
    vectors.printVector(expected);
    std.debug.print("\nResult:   ", .{});
    vectors.printVector(result);
    std.debug.print("\n", .{});

    if (std.mem.eql(protocol.Trit, &expected, &result)) {
        std.debug.print("✅ BUNDLE test PASSED\n\n", .{});
        return true;
    } else {
        std.debug.print("❌ BUNDLE test FAILED\n\n", .{});
        return false;
    }
}

fn runSimilarityTest(port: std.fs.File) !bool {
    std.debug.print("[SIMILARITY TEST]\n", .{});
    std.debug.print("════════════════════════════════════════\n", .{});

    const vec_a = vectors.allOnesVector();
    const vec_b = vectors.randomVector();

    std.debug.print("Vector A (all +): ", .{});
    vectors.printVector(vec_a);
    std.debug.print("\nVector B: ", .{});
    vectors.printVector(vec_b);
    std.debug.print("\n", .{});

    const data_a = vectors.encodeVector(vec_a);
    const data_b = vectors.encodeVector(vec_b);

    var payload: [8]u8 = undefined;
    @memcpy(payload[0..4], &data_a);
    @memcpy(payload[4..8], &data_b);

    _ = try sendPacket(port, .SIMILARITY, &payload);
    const response = try recvResponse(port, 1);

    const fpga_score = response[0];
    const sw_score = vectors.similarityVectors(vec_a, vec_b);

    std.debug.print("FPGA similarity: {d}/255\n", .{fpga_score});
    std.debug.print("SW similarity:   {d}/255\n", .{sw_score});

    const diff = if (fpga_score > sw_score) fpga_score - sw_score else sw_score - fpga_score;
    if (diff <= 5) {  // Allow small difference due to encoding
        std.debug.print("✅ SIMILARITY test PASSED (diff={d})\n\n", .{diff});
        return true;
    } else {
        std.debug.print("❌ SIMILARITY test FAILED (diff={d})\n\n", .{diff});
        return false;
    }
}

fn runBenchmark(port: std.fs.File) !bool {
    std.debug.print("[BENCHMARK]\n", .{});
    std.debug.print("════════════════════════════════════════\n", .{});

    const iterations: usize = 100;
    const start = std.time.nanoTimestamp();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const vec_a = vectors.randomVector();
        const vec_b = vectors.randomVector();
        const data_a = vectors.encodeVector(vec_a);
        const data_b = vectors.encodeVector(vec_b);

        var payload: [8]u8 = undefined;
        @memcpy(payload[0..4], &data_a);
        @memcpy(payload[4..8], &data_b);

        _ = try sendPacket(port, .BUNDLE, &payload);
        _ = try recvResponse(port, 4);
    }

    const elapsed_ns = std.time.nanoTimestamp() - start;
    const elapsed_ms = @as(f64, @floatFromInt(@divTrunc(elapsed_ns, 1_000_000)));
    const avg_us = elapsed_ms / @as(f64, @floatFromInt(iterations));

    std.debug.print("  Total: {d:.2} ms\n", .{elapsed_ms});
    std.debug.print("  Average: {d:.2} us/op\n", .{avg_us});
    std.debug.print("  Throughput: {d:.1} ops/sec\n\n", .{1_000_000.0 / avg_us});
    std.debug.print("✅ BENCHMARK COMPLETE\n", .{});

    return true;
}

fn runFullTest(port: std.fs.File) !bool {
    std.debug.print("[FULL TEST SUITE]\n", .{});
    std.debug.print("════════════════════════════════════════\n", .{});

    var passed: usize = 0;
    var failed: usize = 0;

    const TestFn = *const fn (std.fs.File) anyerror!bool;
    const tests = [_]struct { name: []const u8, func: TestFn }{
        .{ .name = "PING", .func = testPing },
        .{ .name = "BIND", .func = runBindTest },
        .{ .name = "BUNDLE", .func = runBundleTest },
        .{ .name = "SIMILARITY", .func = runSimilarityTest },
        .{ .name = "BENCHMARK", .func = runBenchmark },
    };

    for (tests) |t| {
        std.debug.print("\n[{s}]\n", .{t.name});
        if (t.func(port)) |result| {
            if (result) passed += 1 else failed += 1;
        } else |err| {
            std.debug.print("Error: {}\n", .{err});
            failed += 1;
        }
    }

    std.debug.print("\n════════════════════════════════════════\n", .{});
    std.debug.print("SUMMARY: {d} passed, {d} failed\n", .{passed, failed});

    if (failed == 0) {
        std.debug.print("✅ ALL TESTS PASSED!\n", .{});
        return true;
    } else {
        std.debug.print("❌ SOME TESTS FAILED\n", .{});
        return false;
    }
}

fn testLoopback() !void {
    std.debug.print("[LOOPBACK TEST]\n", .{});
    std.debug.print("════════════════════════════════════════\n", .{});
    std.debug.print("Requires: TX-RX shorted on USB-UART adapter\n\n", .{});

    const port = std.fs.openFileAbsolute(UART_DEVICE, .{
        .mode = .read_write,
    }) catch |err| {
        std.log.err("Failed to open {s}: {}", .{UART_DEVICE, err});
        return err;
    };
    defer port.close();

    const test_packet = [_]u8{ SYNC_BYTE, 0x55, 0xFF, 0x00 };
    _ = try port.writeAll(&test_packet);
    std.debug.print("  Sent: 0xAA 0x55 0xFF 0x00\n", .{});

    var buffer: [16]u8 = undefined;
    const start_time = std.time.milliTimestamp();
    var n: usize = 0;

    while (n < 4) {
        const elapsed = std.time.milliTimestamp() - start_time;
        if (elapsed > TIMEOUT_MS) {
            std.debug.print("  ❌ TIMEOUT\n", .{});
            return error.Timeout;
        }
        const chunk = try port.read(buffer[n..]);
        if (chunk == 0) continue;
        n += chunk;
    }

    std.debug.print("  Received: {any}\n", .{buffer[0..4]});

    if (std.mem.eql(u8, &test_packet, buffer[0..4])) {
        std.debug.print("  ✅ LOOPBACK PASSED\n", .{});
    } else {
        std.debug.print("  ❌ LOOPBACK FAILED\n", .{});
    }
}

fn setLedMode(port: std.fs.File, mode_str: []const u8) !void {
    const mode = if (std.mem.eql(u8, mode_str, "separable"))
        protocol.LedMode.separable
    else if (std.mem.eql(u8, mode_str, "violation"))
        protocol.LedMode.violation
    else if (std.mem.eql(u8, mode_str, "zero"))
        protocol.LedMode.zero
    else if (std.mem.eql(u8, mode_str, "negative"))
        protocol.LedMode.negative
    else
        protocol.LedMode.violation;

    std.debug.print("[SET MODE] {s}\n", .{@tagName(mode)});
    const data = [_]u8{@intFromEnum(mode)};
    _ = try sendPacket(port, .MODE, &data);
    _ = try recvResponse(port, 1);
}
