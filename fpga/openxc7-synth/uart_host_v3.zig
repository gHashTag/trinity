// VSA FPGA UART Host v3.0
// Day 3: VSA bind + bundle operations via UART
//
// New features:
// - BIND command (0x02): Bind two vectors
// - BUNDLE command (0x03): Bundle two vectors
// - Enhanced protocol with sync byte (0xAA)
// - 16-trit vectors (4 bytes each)
// - All Day 2 commands preserved

const std = @import("std");
var prng = std.Random.DefaultPrng.init(12345);

// === COMMANDS (Day 3 Protocol) ===
const Command = enum(u8) {
    MODE = 0x01,              // MODE: 0x01 XX
    BIND = 0x02,              // BIND: 0x02 with vector data
    BUNDLE = 0x03,            // BUNDLE: 0x03 with vector data
    PING = 0xFF,              // PING command
};

const Response = enum(u8) {
    OK = 0x00,                // OK response
    PONG = 0xAA,              // PONG response
};

// === TRIT ENCODING ===
// 2 bits per trit: 00=0, 01=+1, 10=-1, 11=reserved
const Trit = enum(u2) {
    NEGATIVE = 0b10,          // -1
    ZERO = 0b00,              // 0
    POSITIVE = 0b01,          // +1
};

// Vector: 16 trits = 32 bits = 4 bytes
const VECTOR_SIZE: usize = 16;
const VECTOR_BYTES: usize = 4;

// === CONFIG ===
const UART_DEVICE = "/dev/ttyUSB0";
const BAUD_RATE = 115200;
const TIMEOUT_MS = 5000;
const SYNC_BYTE: u8 = 0xAA;

// === CRC-16-CCITT ===
fn crc16Ccitt(data: []const u8) u16 {
    var crc: u16 = 0xFFFF;
    for (data) |byte| {
        crc ^= (@as(u16, byte) << 8);
        var i: u4 = 0;
        while (i < 8) : (i += 1) {
            if (crc & 0x8000 != 0)
                crc = (crc << 1) ^ 0x1021
            else
                crc = crc << 1;
        }
    }
    return crc & 0xFFFF;
}

// === VECTORS ===
const Vector16 = [VECTOR_SIZE]Trit;

// Generate random vector
fn randomVector() Vector16 {
    var vec: Vector16 = undefined;
    for (0..VECTOR_SIZE) |i| {
        const r = prng.random().intRangeAtMost(u2, 0, 2);
        vec[i] = @enumFromInt(r);
    }
    return vec;
}

// Encode vector to bytes (16 trits × 2 bits = 32 bits = 4 bytes)
fn encodeVector(vec: Vector16) [VECTOR_BYTES]u8 {
    var bytes: [VECTOR_BYTES]u8 = undefined;
    @memset(&bytes, 0);
    for (0..VECTOR_SIZE) |i| {
        const trit_bits = @intFromEnum(vec[i]);
        const byte_idx: usize = i / 4;
        const bit_idx: u3 = @intCast((i % 4) * 2);
        bytes[byte_idx] |= @as(u8, trit_bits) << bit_idx;
    }
    return bytes;
}

// Decode bytes to vector
fn decodeVector(bytes: [VECTOR_BYTES]u8) Vector16 {
    var vec: Vector16 = undefined;
    for (0..VECTOR_SIZE) |i| {
        const byte_idx: usize = i / 4;
        const bit_idx: u3 = @intCast((i % 4) * 2);
        const trit_bits = (bytes[byte_idx] >> bit_idx) & 0x03;
        vec[i] = @enumFromInt(trit_bits);
    }
    return vec;
}

// Print vector
fn printVector(vec: Vector16) void {
    std.debug.print("[", .{});
    for (vec, 0..) |t, i| {
        const label = switch (t) {
            Trit.POSITIVE => "+",
            Trit.NEGATIVE => "-",
            Trit.ZERO => "0",
        };
        std.debug.print("{s}", .{label});
        if (i < VECTOR_SIZE - 1) std.debug.print(" ", .{});
    }
    std.debug.print("]", .{});
}

// === BIND OPERATION (software reference) ===
fn bindVectors(a: Vector16, b: Vector16) Vector16 {
    var result: Vector16 = undefined;
    for (0..VECTOR_SIZE) |i| {
        const ta = a[i];
        const tb = b[i];

        // Bind truth table:
        // -1 × -1 = +1,  -1 × 0 = 0,  -1 × +1 = -1
        //  0 × X   = 0
        // +1 × -1 = -1,  +1 × 0 = 0,  +1 × +1 = +1

        result[i] = if (ta == Trit.ZERO or tb == Trit.ZERO)
            Trit.ZERO
        else if (ta == tb)
            Trit.POSITIVE
        else
            Trit.NEGATIVE;
    }
    return result;
}

// === BUNDLE OPERATION (software reference) ===
fn bundleVectors(a: Vector16, b: Vector16) Vector16 {
    var result: Vector16 = undefined;
    for (0..VECTOR_SIZE) |i| {
        const ta = a[i];
        const tb = b[i];

        // Bundle truth table (majority of 2):
        // Both same → that value
        // One zero → other value
        // Opposing → zero

        result[i] = if (ta == Trit.NEGATIVE and tb == Trit.NEGATIVE)
            Trit.NEGATIVE
        else if (ta == Trit.POSITIVE and tb == Trit.POSITIVE)
            Trit.POSITIVE
        else if (ta == Trit.ZERO)
            tb
        else if (tb == Trit.ZERO)
            ta
        else
            Trit.ZERO; // Opposing
    }
    return result;
}

// Verify bind result
fn verifyBind(a: Vector16, b: Vector16, result: Vector16) bool {
    const expected = bindVectors(a, b);
    for (0..VECTOR_SIZE) |i| {
        if (result[i] != expected[i])
            return false;
    }
    return true;
}

// Verify bundle result
fn verifyBundle(a: Vector16, b: Vector16, result: Vector16) bool {
    const expected = bundleVectors(a, b);
    for (0..VECTOR_SIZE) |i| {
        if (result[i] != expected[i])
            return false;
    }
    return true;
}

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    if (args.len < 2) {
        printUsage(args[0]);
        return error.InvalidArgs;
    }

    const command = args[1];

    // Special case: loopback doesn't need FPGA
    if (std.mem.eql(u8, command, "loopback")) {
        try testLoopback();
        return;
    }

    // All other commands need UART device
    const port = openUart() catch |err| {
        std.log.err("Failed to open UART: {}", .{err});
        return err;
    };
    defer port.close();

    std.debug.print("╔════════════════════════════════════════╗\n", .{});
    std.debug.print("║     VSA FPGA UART Host v3.0           ║\n", .{});
    std.debug.print("╚════════════════════════════════════════╝\n", .{});
    std.debug.print("Device: {s}\n", .{UART_DEVICE});
    std.debug.print("Baud: {d}\n", .{BAUD_RATE});
    std.debug.print("════════════════════════════════════════\n\n", .{});

    // Route commands
    if (std.mem.eql(u8, command, "ping")) {
        try testPing(port);
    } else if (std.mem.eql(u8, command, "mode")) {
        const mode = if (args.len > 2) args[2] else "violation";
        try setLedMode(port, mode);
    } else if (std.mem.eql(u8, command, "led")) {
        const led_mode: u2 = if (args.len > 2)
            @as(u2, @intCast(try std.fmt.parseInt(u8, args[2], 10)))
        else
            1; // Default: VIOLATION
        try setLedModeDirect(port, led_mode);
    } else if (std.mem.eql(u8, command, "bind")) {
        try runBindTest(port);
    } else if (std.mem.eql(u8, command, "bundle")) {
        try runBundleTest(port);
    } else if (std.mem.eql(u8, command, "test")) {
        try runFullTest(port);
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
        \\Day 3 Commands:
        \\  loopback          - Test UART cable (short TX-RX, no FPGA needed)
        \\  ping              - Test FPGA connectivity (0xFF -> 0xAA PONG)
        \\  mode <type>       - Set LED mode: separable|violation|zero|negative
        \\  led <0-3>         - Direct LED: 0=separable, 1=violation, 2=zero, 3=negative
        \\  bind              - Test BIND operation (16-trit vectors)
        \\  bundle            - Test BUNDLE operation (16-trit vectors)
        \\  test              - Run full test suite
        \\
        \\Examples:
        \\  {s} loopback              # Verify cable
        \\  {s} ping                  # Test FPGA
        \\  {s} bind                  # Test VSA bind
        \\  {s} bundle                # Test VSA bundle
        \\  {s} test                  # Full test suite
        \\
    , .{prog, prog, prog, prog, prog, prog});
}

// === UART OPEN ===
fn openUart() !std.fs.File {
    return std.fs.openFileAbsolute(UART_DEVICE, .{ .mode = .read_write });
}

// === SEND PACKET ===
fn sendPacket(port: std.fs.File, cmd: Command, data: []const u8) !void {
    var buffer: [256]u8 = undefined;
    var idx: usize = 0;

    // Header
    buffer[idx] = SYNC_BYTE;
    idx += 1;

    // Command
    buffer[idx] = @intFromEnum(cmd);
    idx += 1;

    // Length (little-endian)
    const len = @as(u16, @intCast(data.len));
    buffer[idx] = @as(u8, @intCast(len & 0xFF));
    idx += 1;
    buffer[idx] = @as(u8, @intCast((len >> 8) & 0xFF));
    idx += 1;

    // Data
    @memcpy(buffer[idx..][0..data.len], data);
    idx += data.len;

    // CRC
    const crc = crc16Ccitt(buffer[0..idx]);
    buffer[idx] = @as(u8, @intCast(crc & 0xFF));
    idx += 1;
    buffer[idx] = @as(u8, @intCast((crc >> 8) & 0xFF));
    idx += 1;

    _ = try port.writeAll(buffer[0..idx]);
}

// === RECEIVE RESPONSE ===
fn recvResponse(port: std.fs.File, expected_len: usize) ![1]u8 {
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

    var result: [1]u8 = undefined;
    result[0] = buffer[0];
    return result;
}

fn recvVectorResponse(port: std.fs.File) ![5]u8 {
    var buffer: [256]u8 = undefined;
    const start_time = std.time.milliTimestamp();
    var n: usize = 0;
    const expected_len = 5; // STATUS + 4 bytes vector data

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

    var result: [5]u8 = undefined;
    @memcpy(result[0..], buffer[0..5]);
    return result;
}

// === PING TEST ===
fn testPing(port: std.fs.File) !void {
    std.debug.print("[TEST] PING\n", .{});

    _ = try sendPacket(port, Command.PING, &[_]u8{});
    std.debug.print("  Sent: PING (0xAA 0xFF 00 00 CRC)\n", .{});

    const response = try recvResponse(port, 1);

    if (response[0] == @intFromEnum(Response.PONG)) {
        std.debug.print("  Received: PONG (0xAA)\n", .{});
        std.debug.print("  ✅ PASS: FPGA communication OK\n", .{});
    } else {
        std.debug.print("  ❌ FAIL: Got 0x{X:0>2} (expected 0xAA)\n", .{response[0]});
        return error.UnexpectedResponse;
    }
}

// === MODE CONTROL ===
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
    std.debug.print("  Mode: {d}\n", .{led_mode});

    const param: [1]u8 = .{@as(u8, @intCast(led_mode))};
    _ = try sendPacket(port, Command.MODE, &param);
    std.debug.print("  Sent: 0xAA 0x01 01 00 {X:0>2} CRC\n", .{led_mode});

    const response = try recvResponse(port, 1);

    if (response[0] == @intFromEnum(Response.OK)) {
        std.debug.print("  ✅ LED mode set\n", .{});
    } else {
        std.debug.print("  ❌ FAIL: Got 0x{X:0>2}\n", .{response[0]});
        return error.UnexpectedResponse;
    }
}

// === BIND TEST ===
fn runBindTest(port: std.fs.File) !void {
    std.debug.print("[TEST] BIND OPERATION\n", .{});
    std.debug.print("════════════════════════════════════════\n", .{});

    const vec_a = randomVector();
    const vec_b = randomVector();

    std.debug.print("  Vector A: ", .{});
    printVector(vec_a);
    std.debug.print("\n", .{});

    std.debug.print("  Vector B: ", .{});
    printVector(vec_b);
    std.debug.print("\n", .{});

    const expected = bindVectors(vec_a, vec_b);
    std.debug.print("  Expected: ", .{});
    printVector(expected);
    std.debug.print("\n", .{});

    // Encode vectors
    const bytes_a = encodeVector(vec_a);
    const bytes_b = encodeVector(vec_b);

    // Build packet data (8 bytes total)
    var data: [8]u8 = undefined;
    @memcpy(data[0..4], &bytes_a);
    @memcpy(data[4..8], &bytes_b);

    // Send BIND command
    _ = try sendPacket(port, Command.BIND, &data);
    std.debug.print("  Sent: BIND command with 8 bytes data\n", .{});

    // Receive response
    const response = try recvVectorResponse(port);

    if (response[0] != @intFromEnum(Response.OK)) {
        std.debug.print("  ❌ FAIL: Status 0x{X:0>2}\n", .{response[0]});
        return error.UnexpectedResponse;
    }

    // Decode result
    const result_bytes: [4]u8 = .{ response[1], response[2], response[3], response[4] };
    const result = decodeVector(result_bytes);

    std.debug.print("  Received: ", .{});
    printVector(result);
    std.debug.print("\n", .{});

    // Verify
    if (verifyBind(vec_a, vec_b, result)) {
        std.debug.print("  ✅ PASS: BIND operation correct\n", .{});
    } else {
        std.debug.print("  ❌ FAIL: Result mismatch\n", .{});
        return error.VerificationFailed;
    }
}

// === BUNDLE TEST ===
fn runBundleTest(port: std.fs.File) !void {
    std.debug.print("[TEST] BUNDLE OPERATION\n", .{});
    std.debug.print("════════════════════════════════════════\n", .{});

    const vec_a = randomVector();
    const vec_b = randomVector();

    std.debug.print("  Vector A: ", .{});
    printVector(vec_a);
    std.debug.print("\n", .{});

    std.debug.print("  Vector B: ", .{});
    printVector(vec_b);
    std.debug.print("\n", .{});

    const expected = bundleVectors(vec_a, vec_b);
    std.debug.print("  Expected: ", .{});
    printVector(expected);
    std.debug.print("\n", .{});

    // Encode vectors
    const bytes_a = encodeVector(vec_a);
    const bytes_b = encodeVector(vec_b);

    // Build packet data
    var data: [8]u8 = undefined;
    @memcpy(data[0..4], &bytes_a);
    @memcpy(data[4..8], &bytes_b);

    // Send BUNDLE command
    _ = try sendPacket(port, Command.BUNDLE, &data);
    std.debug.print("  Sent: BUNDLE command with 8 bytes data\n", .{});

    // Receive response
    const response = try recvVectorResponse(port);

    if (response[0] != @intFromEnum(Response.OK)) {
        std.debug.print("  ❌ FAIL: Status 0x{X:0>2}\n", .{response[0]});
        return error.UnexpectedResponse;
    }

    // Decode result
    const result_bytes: [4]u8 = .{ response[1], response[2], response[3], response[4] };
    const result = decodeVector(result_bytes);

    std.debug.print("  Received: ", .{});
    printVector(result);
    std.debug.print("\n", .{});

    // Verify
    if (verifyBundle(vec_a, vec_b, result)) {
        std.debug.print("  ✅ PASS: BUNDLE operation correct\n", .{});
    } else {
        std.debug.print("  ❌ FAIL: Result mismatch\n", .{});
        return error.VerificationFailed;
    }
}

// === FULL TEST ===
fn runFullTest(port: std.fs.File) !void {
    std.debug.print("[FULL TEST SUITE]\n", .{});
    std.debug.print("════════════════════════════════════════\n", .{});

    var passed: usize = 0;
    var failed: usize = 0;

    // Test 1: PING
    std.debug.print("\n[1/5] PING-PONG\n", .{});
    if (testPing(port)) {
        passed += 1;
    } else |_| {
        failed += 1;
    }

    // Test 2: MODE
    std.debug.print("\n[2/5] MODE command\n", .{});
    if (setLedModeDirect(port, 1)) {
        passed += 1;
    } else |_| {
        failed += 1;
    }

    // Test 3-5: Multiple BIND/BUNDLE tests
    std.debug.print("\n[3/5] BIND #1\n", .{});
    if (runBindTest(port)) {
        passed += 1;
    } else |_| {
        failed += 1;
    }

    std.debug.print("\n[4/5] BUNDLE #1\n", .{});
    if (runBundleTest(port)) {
        passed += 1;
    } else |_| {
        failed += 1;
    }

    std.debug.print("\n[5/5] BIND #2 (different vectors)\n", .{});
    if (runBindTest(port)) {
        passed += 1;
    } else |_| {
        failed += 1;
    }

    // Summary
    std.debug.print("\n════════════════════════════════════════\n", .{});
    std.debug.print("SUMMARY: {d} passed, {d} failed\n", .{passed, failed});

    if (failed == 0) {
        std.debug.print("✅ ALL TESTS PASSED!\n", .{});
    } else {
        std.debug.print("❌ SOME TESTS FAILED\n", .{});
    }
}

// === LOOPBACK TEST ===
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

    std.debug.print("Sending test packet...\n", .{});

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

    std.debug.print("  Received: ", .{});
    for (buffer[0..4]) |b| {
        std.debug.print("0x{X:0>2} ", .{b});
    }
    std.debug.print("\n\n", .{});

    if (std.mem.eql(u8, buffer[0..4], &test_packet)) {
        std.debug.print("  ✅ LOOPBACK PASS\n", .{});
    } else {
        std.debug.print("  ❌ LOOPBACK FAIL\n", .{});
        return error.DataMismatch;
    }
}

// φ² + 1/φ² = 3 = TRINITY
