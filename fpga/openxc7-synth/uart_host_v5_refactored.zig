//! ═══════════════════════════════════════════════════════════════════════════════
//! UART HOST v5.0 (REFACTORED) — TRINITY V1
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Refactored version using shared modules:
//! - uart_protocol.zig: Protocol definitions, Trit, CRC
//! - uart_vectors.zig: VSA vector operations
//!
//! This file contains ONLY UART communication logic and command routing.
//! V5-specific: BITNET command, 2-byte length field, different CRC order.
//!
//! φ² + 1/φ² = 3 = TRINITY
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Import shared modules
const protocol = @import("uart_protocol.zig");
const vectors = @import("uart_vectors.zig");

// Re-export commonly used items for backward compatibility
pub const Command = protocol.Command;
pub const Response = protocol.Response;
pub const Trit = protocol.Trit;
pub const Vector16 = vectors.Vector16;
pub const UART_DEVICE = protocol.UART_DEVICE;
pub const BAUD_RATE = protocol.BAUD_RATE;
pub const TIMEOUT_MS = protocol.TIMEOUT_MS;
pub const SYNC_BYTE = protocol.SYNC_BYTE;
pub const VECTOR_SIZE = protocol.VECTOR_SIZE;
pub const VECTOR_BYTES = protocol.VECTOR_BYTES;

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
    std.debug.print("║     TRINITY V1 — UART Host v5.0       ║\n", .{});
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
    } else if (std.mem.eql(u8, command, "led")) {
        const led_mode: u2 = if (args.len > 2)
            @as(u2, @intCast(try std.fmt.parseInt(u8, args[2], 10)))
        else
            1;
        try setLedModeDirect(port, led_mode);
    } else if (std.mem.eql(u8, command, "bind")) {
        _ = try runBindTest(port);
    } else if (std.mem.eql(u8, command, "bundle")) {
        _ = try runBundleTest(port);
    } else if (std.mem.eql(u8, command, "similarity")) {
        _ = try runSimilarityTest(port);
    } else if (std.mem.eql(u8, command, "run-model")) {
        const prompt_id: u8 = if (args.len > 2)
            @intCast(try std.fmt.parseInt(u8, args[2], 10))
        else
            42; // default "answer" prompt
        const token = try runModel(port, prompt_id);
        std.debug.print("Token: {c} (0x{X:0>2})\n", .{@as(u8, token), token});
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
        \\  run-model <id>    - Run BitNet inference (prompt_id -> token)
        \\  benchmark         - Run full benchmark with timing
        \\  test              - Run full test suite
        \\
        \\Examples:
        \\  {s} loopback        # Verify cable
        \\  {s} ping            # Test FPGA
        \\  {s} run-model 42    # Run inference (returns '!')
        \\  {s} benchmark       # Full benchmark
        \\
    , .{prog, prog, prog, prog, prog});
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// UART COMMUNICATION
/// ═══════════════════════════════════════════════════════════════════════════════
fn openUart() !std.fs.File {
    return std.fs.openFileAbsolute(UART_DEVICE, .{ .mode = .read_write });
}

/// Send packet to FPGA (v5 format: 2-byte length, CRC in little-endian order)
fn sendPacket(port: std.fs.File, cmd: Command, data: []const u8) !void {
    var buffer: [256]u8 = undefined;
    var idx: usize = 0;

    buffer[idx] = SYNC_BYTE;
    idx += 1;

    buffer[idx] = @intFromEnum(cmd);
    idx += 1;

    // V5 uses 2-byte length field (little-endian)
    const len = @as(u16, @intCast(data.len));
    buffer[idx] = @as(u8, @intCast(len & 0xFF));
    idx += 1;
    buffer[idx] = @as(u8, @intCast((len >> 8) & 0xFF));
    idx += 1;

    @memcpy(buffer[idx..][0..data.len], data);
    idx += data.len;

    const crc = protocol.crc16Ccitt(buffer[0..idx]);
    // V5 uses little-endian CRC byte order
    buffer[idx] = @as(u8, @truncate(crc & 0xFF));
    idx += 1;
    buffer[idx] = @as(u8, @truncate(crc >> 8));
    idx += 1;

    _ = try port.writeAll(buffer[0..idx]);
}

/// Receive response from FPGA (v5 format: status byte + data)
fn recvResponse(port: std.fs.File, expected_len: usize) ![]u8 {
    var buffer: [256]u8 = undefined;
    const start_time = std.time.milliTimestamp();
    var n: usize = 0;

    while (n < expected_len) {
        const elapsed = std.time.milliTimestamp() - start_time;
        if (elapsed > TIMEOUT_MS) {
            std.debug.print("  ❌ TIMEOUT\n", .{});
            return error.Timeout;
        }

        var chunk_buf: [1]u8 = undefined;
        const chunk = try port.read(&chunk_buf);
        if (chunk == 0) {
            std.posix.nanosleep(0, 10_000_000);
            continue;
        }
        buffer[n] = chunk_buf[0];
        n += 1;
    }

    const result = try std.heap.page_allocator.alloc(u8, expected_len);
    @memcpy(result, buffer[0..expected_len]);
    return result;
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// TEST FUNCTIONS
/// ═══════════════════════════════════════════════════════════════════════════════
fn testPing(port: std.fs.File) !bool {
    std.debug.print("[TEST] PING\n", .{});

    _ = try sendPacket(port, .PING, &[_]u8{});
    std.debug.print("  Sent: PING (0xAA 0xFF 00 00 CRC)\n", .{});

    const response = try recvResponse(port, 1);

    if (response[0] == @intFromEnum(Response.PONG)) {
        std.debug.print("  Received: PONG (0xAA)\n", .{});
        std.debug.print("  ✅ PASS: FPGA communication OK\n", .{});
        return true;
    } else {
        std.debug.print("  ❌ FAIL: Got 0x{X:0>2}\n", .{response[0]});
        return false;
    }
}

/// MODE CONTROL
fn parseLedMode(mode_str: []const u8) !u2 {
    if (std.mem.eql(u8, mode_str, "separable")) return 0;
    if (std.mem.eql(u8, mode_str, "violation")) return 1;
    if (std.mem.eql(u8, mode_str, "zero")) return 2;
    if (std.mem.eql(u8, mode_str, "negative")) return 3;
    return error.UnknownMode;
}

fn setLedMode(port: std.fs.File, mode_str: []const u8) !void {
    const mode_val = try parseLedMode(mode_str);
    try setLedModeDirect(port, mode_val);
}

fn setLedModeDirect(port: std.fs.File, led_mode: u2) !void {
    std.debug.print("[COMMAND] SET LED MODE\n", .{});
    const param: [1]u8 = .{@as(u8, @intCast(led_mode))};
    _ = try sendPacket(port, .MODE, &param);

    const response = try recvResponse(port, 1);
    if (response[0] == @intFromEnum(Response.OK)) {
        std.debug.print("  ✅ LED mode set\n", .{});
    } else {
        std.debug.print("  ❌ FAIL: Got 0x{X:0>2}\n", .{response[0]});
        return error.UnexpectedResponse;
    }
}

/// BIND TEST
fn runBindTest(port: std.fs.File) !bool {
    std.debug.print("[TEST] BIND OPERATION\n", .{});
    std.debug.print("════════════════════════════════════════\n", .{});

    const vec_a = vectors.randomVector();
    const vec_b = vectors.randomVector();

    std.debug.print("  Vector A: ", .{});
    vectors.printVector(vec_a);
    std.debug.print("\n", .{});

    const bytes_a = vectors.encodeVector(vec_a);
    const bytes_b = vectors.encodeVector(vec_b);
    var data: [8]u8 = undefined;
    @memcpy(data[0..4], &bytes_a);
    @memcpy(data[4..8], &bytes_b);

    _ = try sendPacket(port, .BIND, &data);

    const response = try recvResponse(port, 5);
    if (response[0] != @intFromEnum(Response.OK)) {
        std.debug.print("  ❌ FAIL: Status 0x{X:0>2}\n", .{response[0]});
        return false;
    }

    var result_bytes: [4]u8 = undefined;
    @memcpy(result_bytes[0..], response[1..5]);

    // Verify result
    const expected = vectors.bindVectors(vec_a, vec_b);
    const result = vectors.decodeVector(result_bytes);

    std.debug.print("  Expected: ", .{});
    vectors.printVector(expected);
    std.debug.print("\n  Result:   ", .{});
    vectors.printVector(result);
    std.debug.print("\n", .{});

    if (std.mem.eql(protocol.Trit, &expected, &result)) {
        std.debug.print("  ✅ PASS: BIND operation correct\n", .{});
        return true;
    } else {
        std.debug.print("  ❌ FAIL: Result mismatch\n", .{});
        return false;
    }
}

/// BUNDLE TEST
fn runBundleTest(port: std.fs.File) !bool {
    std.debug.print("[TEST] BUNDLE OPERATION\n", .{});
    std.debug.print("════════════════════════════════════════\n", .{});

    const vec_a = vectors.randomVector();
    const vec_b = vectors.randomVector();

    const bytes_a = vectors.encodeVector(vec_a);
    const bytes_b = vectors.encodeVector(vec_b);
    var data: [8]u8 = undefined;
    @memcpy(data[0..4], &bytes_a);
    @memcpy(data[4..8], &bytes_b);

    _ = try sendPacket(port, .BUNDLE, &data);

    const response = try recvResponse(port, 5);
    if (response[0] != @intFromEnum(Response.OK)) {
        std.debug.print("  ❌ FAIL: Status 0x{X:0>2}\n", .{response[0]});
        return false;
    }

    var result_bytes: [4]u8 = undefined;
    @memcpy(result_bytes[0..], response[1..5]);

    const expected = vectors.bundleVectors(vec_a, vec_b);
    const result = vectors.decodeVector(result_bytes);

    std.debug.print("  Expected: ", .{});
    vectors.printVector(expected);
    std.debug.print("\n  Result:   ", .{});
    vectors.printVector(result);
    std.debug.print("\n", .{});

    if (std.mem.eql(protocol.Trit, &expected, &result)) {
        std.debug.print("  ✅ PASS: BUNDLE operation correct\n", .{});
        return true;
    } else {
        std.debug.print("  ❌ FAIL: Result mismatch\n", .{});
        return false;
    }
}

/// SIMILARITY TEST
fn runSimilarityTest(port: std.fs.File) !bool {
    std.debug.print("[TEST] SIMILARITY OPERATION\n", .{});
    std.debug.print("════════════════════════════════════════\n", .{});

    // Test case 1: Identical vectors
    std.debug.print("Test 1: Identical vectors\n", .{});
    const vec_ident = vectors.allOnesVector();
    const expected_sim1: u8 = 255; // Perfect match

    const sim1 = try similarityCommand(port, vec_ident, vec_ident);
    std.debug.print("  Expected: {d}, Got: {d}\n", .{expected_sim1, sim1});

    // Test case 2: Orthogonal vectors
    std.debug.print("Test 2: Alternating vs all-positive\n", .{});
    const vec_alt = vectors.alternatingVector();
    const vec_ones = vectors.allOnesVector();
    const expected_sim2 = vectors.similarityVectors(vec_alt, vec_ones);

    const sim2 = try similarityCommand(port, vec_alt, vec_ones);
    std.debug.print("  Expected: {d}, Got: {d}\n", .{expected_sim2, sim2});

    // Test case 3: Opposite vectors
    std.debug.print("Test 3: Opposite vectors\n", .{});
    const vec_pos = vectors.allOnesVector();
    var vec_neg: Vector16 = undefined;
    for (0..VECTOR_SIZE) |i| {
        vec_neg[i] = .NEGATIVE;
    }
    const expected_sim3: u8 = 0; // Opposite

    const sim3 = try similarityCommand(port, vec_pos, vec_neg);
    std.debug.print("  Expected: {d}, Got: {d}\n", .{expected_sim3, sim3});

    // Summary
    const diff1 = sim1 > (expected_sim1 - 10) and sim1 <= expected_sim1;
    const diff2 = sim2 > (expected_sim2 - 20) and sim2 < (expected_sim2 + 20);
    const diff3 = sim3 == expected_sim3;

    if (diff1 and diff2 and diff3) {
        std.debug.print("  ✅ PASS: SIMILARITY operations correct\n", .{});
        return true;
    } else {
        std.debug.print("  ⚠️  Some results outside tolerance\n", .{});
        return false;
    }
}

fn similarityCommand(port: std.fs.File, vec_a: Vector16, vec_b: Vector16) !u8 {
    const bytes_a = vectors.encodeVector(vec_a);
    const bytes_b = vectors.encodeVector(vec_b);
    var data: [8]u8 = undefined;
    @memcpy(data[0..4], &bytes_a);
    @memcpy(data[4..8], &bytes_b);

    _ = try sendPacket(port, .SIMILARITY, &data);

    const response = try recvResponse(port, 2);
    if (response[0] != @intFromEnum(Response.OK)) {
        return error.UnexpectedResponse;
    }

    return response[1];
}

/// BITNET INFERENCE
fn runModel(port: std.fs.File, prompt_id: u8) !u8 {
    const data = [_]u8{prompt_id};

    _ = try sendPacket(port, .BITNET, &data);

    // Wait for token (1 byte response + status byte)
    const response = try recvResponse(port, 2);
    if (response[0] != @intFromEnum(Response.OK)) {
        return error.UnexpectedResponse;
    }

    return response[1];
}

/// BENCHMARK
fn runBenchmark(port: std.fs.File) !bool {
    std.debug.print("╔════════════════════════════════════════╗\n", .{});
    std.debug.print("║        VSA UART BENCHMARK               ║\n", .{});
    std.debug.print("╚════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    const iterations = 100;

    // Benchmark BIND
    {
        std.debug.print("Benchmarking BIND ({d} iterations)...\n", .{iterations});
        const start = std.time.nanoTimestamp();

        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            const vec_a = vectors.randomVector();
            const vec_b = vectors.randomVector();
            const bytes_a = vectors.encodeVector(vec_a);
            const bytes_b = vectors.encodeVector(vec_b);
            var data: [8]u8 = undefined;
            @memcpy(data[0..4], &bytes_a);
            @memcpy(data[4..8], &bytes_b);

            _ = try sendPacket(port, .BIND, &data);
            const response = try recvResponse(port, 5);
            _ = response;
        }

        const elapsed_ns = std.time.nanoTimestamp() - start;
        const elapsed_ms = @as(f64, @floatFromInt(@divTrunc(elapsed_ns, 1_000_000)));
        const avg_us = elapsed_ms / @as(f64, @floatFromInt(iterations));

        std.debug.print("  Total: {d:.2} ms\n", .{elapsed_ms});
        std.debug.print("  Average: {d:.2} us/op\n", .{avg_us});
        std.debug.print("  Throughput: {d:.1} ops/sec\n\n", .{1_000_000.0 / avg_us});
    }

    // Benchmark BUNDLE
    {
        std.debug.print("Benchmarking BUNDLE ({d} iterations)...\n", .{iterations});
        const start = std.time.nanoTimestamp();

        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            const vec_a = vectors.randomVector();
            const vec_b = vectors.randomVector();
            const bytes_a = vectors.encodeVector(vec_a);
            const bytes_b = vectors.encodeVector(vec_b);
            var data: [8]u8 = undefined;
            @memcpy(data[0..4], &bytes_a);
            @memcpy(data[4..8], &bytes_b);

            _ = try sendPacket(port, .BUNDLE, &data);
            const response = try recvResponse(port, 5);
            _ = response;
        }

        const elapsed_ns = std.time.nanoTimestamp() - start;
        const elapsed_ms = @as(f64, @floatFromInt(@divTrunc(elapsed_ns, 1_000_000)));
        const avg_us = elapsed_ms / @as(f64, @floatFromInt(iterations));

        std.debug.print("  Total: {d:.2} ms\n", .{elapsed_ms});
        std.debug.print("  Average: {d:.2} us/op\n", .{avg_us});
        std.debug.print("  Throughput: {d:.1} ops/sec\n\n", .{1_000_000.0 / avg_us});
    }

    // Benchmark SIMILARITY
    {
        std.debug.print("Benchmarking SIMILARITY ({d} iterations)...\n", .{iterations});
        const start = std.time.nanoTimestamp();

        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            const vec_a = vectors.randomVector();
            const vec_b = vectors.randomVector();
            const bytes_a = vectors.encodeVector(vec_a);
            const bytes_b = vectors.encodeVector(vec_b);
            var data: [8]u8 = undefined;
            @memcpy(data[0..4], &bytes_a);
            @memcpy(data[4..8], &bytes_b);

            _ = try sendPacket(port, .SIMILARITY, &data);
            const response = try recvResponse(port, 2);
            _ = response;
        }

        const elapsed_ns = std.time.nanoTimestamp() - start;
        const elapsed_ms = @as(f64, @floatFromInt(@divTrunc(elapsed_ns, 1_000_000)));
        const avg_us = elapsed_ms / @as(f64, @floatFromInt(iterations));

        std.debug.print("  Total: {d:.2} ms\n", .{elapsed_ms});
        std.debug.print("  Average: {d:.2} us/op\n", .{avg_us});
        std.debug.print("  Throughput: {d:.1} ops/sec\n\n", .{1_000_000.0 / avg_us});
    }

    std.debug.print("════════════════════════════════════════\n", .{});
    std.debug.print("✅ BENCHMARK COMPLETE\n", .{});
    return true;
}

/// FULL TEST
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

/// LOOPBACK TEST
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

    const test_packet = [_]u8{ 0xAA, 0x55, 0xFF, 0x00 };
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
        if (chunk == 0) {
            std.posix.nanosleep(0, 10_000_000);
            continue;
        }
        n += chunk;
    }

    if (std.mem.eql(u8, buffer[0..4], &test_packet)) {
        std.debug.print("  ✅ LOOPBACK PASS\n", .{});
    } else {
        std.debug.print("  ❌ LOOPBACK FAIL\n", .{});
        return error.DataMismatch;
    }
}
