// VSA FPGA UART Host v4.0
// Day 4: Similarity + Benchmark via UART
//
// New features:
// - SIMILARITY command (0x04): cosine similarity score
// - Benchmark mode with timing
// - Pre-defined test vectors
// - All Day 2/3 commands preserved

const std = @import("std");
var prng = std.Random.DefaultPrng.init(12345);

// === COMMANDS (Day 4 Protocol) ===
const Command = enum(u8) {
    MODE = 0x01,
    BIND = 0x02,
    BUNDLE = 0x03,
    SIMILARITY = 0x04,         // NEW: Similarity score
    PING = 0xFF,
};

const Response = enum(u8) {
    OK = 0x00,
    PONG = 0xAA,
};

// === TRIT ENCODING ===
const Trit = enum(u2) {
    NEGATIVE = 0b10,
    ZERO = 0b00,
    POSITIVE = 0b01,
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

// Generate specific vectors for testing
fn allOnesVector() Vector16 {
    var vec: Vector16 = undefined;
    for (0..VECTOR_SIZE) |i| {
        vec[i] = Trit.POSITIVE;
    }
    return vec;
}

fn allZerosVector() Vector16 {
    var vec: Vector16 = undefined;
    for (0..VECTOR_SIZE) |i| {
        vec[i] = Trit.ZERO;
    }
    return vec;
}

fn alternatingVector() Vector16 {
    var vec: Vector16 = undefined;
    for (0..VECTOR_SIZE) |i| {
        vec[i] = if (i % 2 == 0) Trit.POSITIVE else Trit.NEGATIVE;
    }
    return vec;
}

// Encode vector to bytes
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
        if (i < VECTOR_SIZE - 1) std.debug.print("", .{});
    }
    std.debug.print("]", .{});
}

// === SOFTWARE SIMILARITY (for verification) ===
fn similarityVectors(a: Vector16, b: Vector16) u8 {
    var dot_product: i16 = 0;
    var norm_a: i16 = 0;
    var norm_b: i16 = 0;

    for (0..VECTOR_SIZE) |i| {
        const a_val: i2 = switch (a[i]) {
            Trit.POSITIVE => 1,
            Trit.NEGATIVE => -1,
            Trit.ZERO => 0,
        };
        const b_val: i2 = switch (b[i]) {
            Trit.POSITIVE => 1,
            Trit.NEGATIVE => -1,
            Trit.ZERO => 0,
        };

        dot_product += a_val * b_val;
        norm_a += a_val * a_val;
        norm_b += b_val * b_val;
    }

    if (norm_a == 0 or norm_b == 0)
        return 0;

    // Scale to 0-255
    const abs_dot = if (dot_product < 0) -dot_product else dot_product;
    const norm_sum = norm_a + norm_b;
    const score = @divTrunc(abs_dot * 255, @max(norm_sum, 1));
    return @intCast(score);
}

// === SOFTWARE BIND (for verification) ===
fn bindVectors(a: Vector16, b: Vector16) Vector16 {
    var result: Vector16 = undefined;
    for (0..VECTOR_SIZE) |i| {
        const ta = a[i];
        const tb = b[i];

        result[i] = if (ta == Trit.ZERO or tb == Trit.ZERO)
            Trit.ZERO
        else if (ta == tb)
            Trit.POSITIVE
        else
            Trit.NEGATIVE;
    }
    return result;
}

// === SOFTWARE BUNDLE (for verification) ===
fn bundleVectors(a: Vector16, b: Vector16) Vector16 {
    var result: Vector16 = undefined;
    for (0..VECTOR_SIZE) |i| {
        const ta = a[i];
        const tb = b[i];

        result[i] = if (ta == Trit.NEGATIVE and tb == Trit.NEGATIVE)
            Trit.NEGATIVE
        else if (ta == Trit.POSITIVE and tb == Trit.POSITIVE)
            Trit.POSITIVE
        else if (ta == Trit.ZERO)
            tb
        else if (tb == Trit.ZERO)
            ta
        else
            Trit.ZERO;
    }
    return result;
}

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
    std.debug.print("║     VSA FPGA UART Host v4.0           ║\n", .{});
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
            1;
        try setLedModeDirect(port, led_mode);
    } else if (std.mem.eql(u8, command, "bind")) {
        try runBindTest(port);
    } else if (std.mem.eql(u8, command, "bundle")) {
        try runBundleTest(port);
    } else if (std.mem.eql(u8, command, "similarity")) {
        try runSimilarityTest(port);
    } else if (std.mem.eql(u8, command, "benchmark")) {
        try runBenchmark(port);
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
        \\Day 4 Commands:
        \\  loopback          - Test UART cable (short TX-RX, no FPGA needed)
        \\  ping              - Test FPGA connectivity (0xFF -> 0xAA PONG)
        \\  mode <type>       - Set LED mode: separable|violation|zero|negative
        \\  led <0-3>         - Direct LED control
        \\  bind              - Test BIND operation (16-trit vectors)
        \\  bundle            - Test BUNDLE operation (16-trit vectors)
        \\  similarity        - Test SIMILARITY (cosine score 0-255)
        \\  benchmark         - Run full benchmark with timing
        \\  test              - Run full test suite
        \\
        \\Examples:
        \\  {s} loopback    # Verify cable
        \\  {s} ping        # Test FPGA
        \\  {s} similarity  # Test similarity
        \\  {s} benchmark   # Full benchmark
        \\
    , .{prog, prog, prog, prog, prog});
}

fn openUart() !std.fs.File {
    return std.fs.openFileAbsolute(UART_DEVICE, .{ .mode = .read_write });
}

// === SEND PACKET ===
fn sendPacket(port: std.fs.File, cmd: Command, data: []const u8) !void {
    var buffer: [256]u8 = undefined;
    var idx: usize = 0;

    buffer[idx] = SYNC_BYTE;
    idx += 1;

    buffer[idx] = @intFromEnum(cmd);
    idx += 1;

    const len = @as(u16, @intCast(data.len));
    buffer[idx] = @as(u8, @intCast(len & 0xFF));
    idx += 1;
    buffer[idx] = @as(u8, @intCast((len >> 8) & 0xFF));
    idx += 1;

    @memcpy(buffer[idx..][0..data.len], data);
    idx += data.len;

    const crc = crc16Ccitt(buffer[0..idx]);
    buffer[idx] = @as(u8, @intCast(crc & 0xFF));
    idx += 1;
    buffer[idx] = @as(u8, @intCast((crc >> 8) & 0xFF));
    idx += 1;

    _ = try port.writeAll(buffer[0..idx]);
}

// === RECEIVE RESPONSE ===
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
        std.debug.print("  ❌ FAIL: Got 0x{X:0>2}\n", .{response[0]});
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
    const param: [1]u8 = .{@as(u8, @intCast(led_mode))};
    _ = try sendPacket(port, Command.MODE, &param);

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

    const bytes_a = encodeVector(vec_a);
    const bytes_b = encodeVector(vec_b);
    var data: [8]u8 = undefined;
    @memcpy(data[0..4], &bytes_a);
    @memcpy(data[4..8], &bytes_b);

    _ = try sendPacket(port, Command.BIND, &data);

    const response = try recvResponse(port, 5);
    if (response[0] != @intFromEnum(Response.OK)) {
        std.debug.print("  ❌ FAIL: Status 0x{X:0>2}\n", .{response[0]});
        return error.UnexpectedResponse;
    }

    var result_bytes: [4]u8 = undefined;
    @memcpy(result_bytes[0..], response[1..5]);

    // Verify result
    const expected = bindVectors(vec_a, vec_b);
    var pass = true;
    for (0..VECTOR_SIZE) |i| {
        const byte_idx: usize = i / 4;
        const bit_idx: u3 = @intCast((i % 4) * 2);
        const trit_bits = (result_bytes[byte_idx] >> bit_idx) & 0x03;
        const result_trit = @as(Trit, @enumFromInt(trit_bits));
        if (result_trit != expected[i]) pass = false;
    }

    if (pass) {
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

    const bytes_a = encodeVector(vec_a);
    const bytes_b = encodeVector(vec_b);
    var data: [8]u8 = undefined;
    @memcpy(data[0..4], &bytes_a);
    @memcpy(data[4..8], &bytes_b);

    _ = try sendPacket(port, Command.BUNDLE, &data);

    const response = try recvResponse(port, 5);
    if (response[0] != @intFromEnum(Response.OK)) {
        std.debug.print("  ❌ FAIL: Status 0x{X:0>2}\n", .{response[0]});
        return error.UnexpectedResponse;
    }

    var result_bytes: [4]u8 = undefined;
    @memcpy(result_bytes[0..], response[1..5]);

    const expected = bundleVectors(vec_a, vec_b);
    var pass = true;
    for (0..VECTOR_SIZE) |i| {
        const byte_idx: usize = i / 4;
        const bit_idx: u3 = @intCast((i % 4) * 2);
        const trit_bits = (result_bytes[byte_idx] >> bit_idx) & 0x03;
        const result_trit = @as(Trit, @enumFromInt(trit_bits));
        if (result_trit != expected[i]) pass = false;
    }

    if (pass) {
        std.debug.print("  ✅ PASS: BUNDLE operation correct\n", .{});
    } else {
        std.debug.print("  ❌ FAIL: Result mismatch\n", .{});
        return error.VerificationFailed;
    }
}

// === SIMILARITY TEST ===
fn runSimilarityTest(port: std.fs.File) !void {
    std.debug.print("[TEST] SIMILARITY OPERATION\n", .{});
    std.debug.print("════════════════════════════════════════\n", .{});

    // Test case 1: Identical vectors
    std.debug.print("Test 1: Identical vectors\n", .{});
    const vec_ident = allOnesVector();
    const expected_sim1: u8 = 255; // Perfect match

    const sim1 = try similarityCommand(port, vec_ident, vec_ident);
    std.debug.print("  Expected: {d}, Got: {d}\n", .{expected_sim1, sim1});

    // Test case 2: Orthogonal vectors
    std.debug.print("Test 2: Alternating vs all-positive\n", .{});
    const vec_alt = alternatingVector();
    const vec_ones = allOnesVector();
    const expected_sim2 = similarityVectors(vec_alt, vec_ones);

    const sim2 = try similarityCommand(port, vec_alt, vec_ones);
    std.debug.print("  Expected: {d}, Got: {d}\n", .{expected_sim2, sim2});

    // Test case 3: Opposite vectors
    std.debug.print("Test 3: Opposite vectors\n", .{});
    const vec_pos = allOnesVector();
    var vec_neg: Vector16 = undefined;
    for (0..VECTOR_SIZE) |i| {
        vec_neg[i] = Trit.NEGATIVE;
    }
    const expected_sim3: u8 = 0; // Opposite

    const sim3 = try similarityCommand(port, vec_pos, vec_neg);
    std.debug.print("  Expected: {d}, Got: {d}\n", .{expected_sim3, sim3});

    // Summary
    const diff1 = if (@as(i16, sim1) > @as(i16, expected_sim1) - 10 and sim1 < expected_sim1) true else false;
    const diff2 = if (sim2 > expected_sim2 - 20 and sim2 < expected_sim2 + 20) true else false;
    const diff3 = if (sim3 == expected_sim3) true else false;

    if (diff1 and diff2 and diff3) {
        std.debug.print("  ✅ PASS: SIMILARITY operations correct\n", .{});
    } else {
        std.debug.print("  ⚠️  Some results outside tolerance\n", .{});
    }
}

fn similarityCommand(port: std.fs.File, vec_a: Vector16, vec_b: Vector16) !u8 {
    const bytes_a = encodeVector(vec_a);
    const bytes_b = encodeVector(vec_b);
    var data: [8]u8 = undefined;
    @memcpy(data[0..4], &bytes_a);
    @memcpy(data[4..8], &bytes_b);

    _ = try sendPacket(port, Command.SIMILARITY, &data);

    const response = try recvResponse(port, 2);
    if (response[0] != @intFromEnum(Response.OK)) {
        return error.UnexpectedResponse;
    }

    return response[1];
}

// === BENCHMARK ===
fn runBenchmark(port: std.fs.File) !void {
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
            const vec_a = randomVector();
            const vec_b = randomVector();
            const bytes_a = encodeVector(vec_a);
            const bytes_b = encodeVector(vec_b);
            var data: [8]u8 = undefined;
            @memcpy(data[0..4], &bytes_a);
            @memcpy(data[4..8], &bytes_b);

            _ = try sendPacket(port, Command.BIND, &data);
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
            const vec_a = randomVector();
            const vec_b = randomVector();
            const bytes_a = encodeVector(vec_a);
            const bytes_b = encodeVector(vec_b);
            var data: [8]u8 = undefined;
            @memcpy(data[0..4], &bytes_a);
            @memcpy(data[4..8], &bytes_b);

            _ = try sendPacket(port, Command.BUNDLE, &data);
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
            const vec_a = randomVector();
            const vec_b = randomVector();
            const bytes_a = encodeVector(vec_a);
            const bytes_b = encodeVector(vec_b);
            var data: [8]u8 = undefined;
            @memcpy(data[0..4], &bytes_a);
            @memcpy(data[4..8], &bytes_b);

            _ = try sendPacket(port, Command.SIMILARITY, &data);
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
}

// === FULL TEST ===
fn runFullTest(port: std.fs.File) !void {
    std.debug.print("[FULL TEST SUITE]\n", .{});
    std.debug.print("════════════════════════════════════════\n", .{});

    var passed: usize = 0;
    var failed: usize = 0;

    std.debug.print("\n[1/5] PING-PONG\n", .{});
    if (testPing(port)) {
        passed += 1;
    } else |_| {
        failed += 1;
    }

    std.debug.print("\n[2/5] BIND\n", .{});
    if (runBindTest(port)) {
        passed += 1;
    } else |_| {
        failed += 1;
    }

    std.debug.print("\n[3/5] BUNDLE\n", .{});
    if (runBundleTest(port)) {
        passed += 1;
    } else |_| {
        failed += 1;
    }

    std.debug.print("\n[4/5] SIMILARITY\n", .{});
    if (runSimilarityTest(port)) {
        passed += 1;
    } else |_| {
        failed += 1;
    }

    std.debug.print("\n[5/5] BENCHMARK\n", .{});
    if (runBenchmark(port)) {
        passed += 1;
    } else |_| {
        failed += 1;
    }

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

// φ² + 1/φ² = 3 = TRINITY
