// VSA FPGA UART Test Program
// Week 4: Host-side test for VSA FPGA accelerator
//
// This program communicates with the VSA FPGA via UART to test
// bind, bundle, and similarity operations.

const std = @import("std");

const Command = enum(u8) {
    BIND = 0x01,
    BUNDLE = 0x02,
    SIMILARITY = 0x03,
    PING = 0xFF,
};

const Response = enum(u8) {
    OK = 0x00,
    ERROR = 0x01,
    BUSY = 0x02,
    PONG = 0xFF,
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Parse command line args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print(
            \\Usage: {s} <command> [options]
            \\Commands:
            \\  ping              - Test FPGA connectivity
            \\  bind <dim>        - Test bind operation (default: 256)
            \\  bundle <dim>      - Test bundle operation (default: 256)
            \\  similarity <dim>  - Test similarity operation (default: 256)
            \\  benchmark <dim>   - Run full benchmark (default: 256)
            \\
            \\Device: /dev/ttyUSB0 (default)
            \\Baud: 115200
            \\
        , .{args[0]});
        return error.InvalidArgs;
    }

    const device = "/dev/ttyUSB0";
    const command = args[1];
    const dim: usize = if (args.len > 2) try std.fmt.parseInt(usize, args[2], 10) else 256;

    // Open serial port
    const port = std.fs.openFileAbsolute(device, .{
        .mode = .read_write,
    }) catch |err| {
        std.log.err("Failed to open {s}: {}", .{device, err});
        std.log.err("Connect FPGA and ensure device exists", .{});
        return err;
    };
    defer port.close();

    std.debug.print("VSA FPGA Test Program\n", .{});
    std.debug.print("Device: {s}\n", .{device});
    std.debug.print("Dimension: {d}\n", .{dim});
    std.debug.print("═══════════════════════\n\n", .{});

    if (std.mem.eql(u8, command, "ping")) {
        try testPing(port, dim);
    } else if (std.mem.eql(u8, command, "bind")) {
        try testBind(port, allocator, dim);
    } else if (std.mem.eql(u8, command, "bundle")) {
        try testBundle(port, allocator, dim);
    } else if (std.mem.eql(u8, command, "similarity")) {
        try testSimilarity(port, allocator, dim);
    } else if (std.mem.eql(u8, command, "benchmark")) {
        try runBenchmark(port, allocator, dim);
    } else {
        std.log.err("Unknown command: {s}", .{command});
    }
}

fn testPing(port: std.fs.File, dim: usize) !void {
    _ = dim;
    std.debug.print("[TEST] PING\n", .{});

    // Send PING command
    var packet: [4]u8 = undefined;
    packet[0] = @intFromEnum(Command.PING);
    packet[1] = 0; // LEN_H
    packet[2] = 0; // LEN_L
    packet[3] = packet[0] ^ packet[1] ^ packet[2]; // CRC

    _ = try port.writeAll(&packet);

    // Wait for PONG response
    var response: [1]u8 = undefined;
    const n = try port.readAll(&response);
    if (n == 1 and response[0] == @intFromEnum(Response.PONG)) {
        std.debug.print("  PASS: FPGA responded with PONG\n", .{});
    } else {
        std.debug.print("  FAIL: Expected PONG (0xFF), got 0x{X:0>2}\n", .{response[0]});
    }
}

fn testBind(port: std.fs.File, allocator: std.mem.Allocator, dim: usize) !void {
    std.debug.print("[TEST] BIND ({d} dimensions)\n", .{dim});

    // Create test vectors (all +1)
    const bytes_per_vector = (dim * 2 + 7) / 8;
    const data_len = bytes_per_vector * 2;
    const buffer = try allocator.alloc(u8, data_len);
    defer allocator.free(buffer);

    // Fill with +1 trits (0b01 = 0x55 pattern)
    @memset(buffer, 0x55);

    // Send BIND command
    try sendCommand(port, Command.BIND, buffer);

    // Receive result
    const result = try recvResponse(port, bytes_per_vector, allocator);
    defer allocator.free(result);

    // Verify: (+1) * (+1) = +1
    var errors: usize = 0;
    for (result) |b| {
        if (b != 0x55) errors += 1;
    }

    if (errors == 0) {
        std.debug.print("  PASS: All trits = +1\n", .{});
    } else {
        std.debug.print("  FAIL: {d} bytes incorrect\n", .{errors});
    }
}

fn testBundle(port: std.fs.File, allocator: std.mem.Allocator, dim: usize) !void {
    std.debug.print("[TEST] BUNDLE ({d} dimensions)\n", .{dim});

    const bytes_per_vector = (dim * 2 + 7) / 8;
    const data_len = bytes_per_vector * 2;
    const buffer = try allocator.alloc(u8, data_len);
    defer allocator.free(buffer);

    // Test: majority(+1, +1) = +1
    @memset(buffer, 0x55);

    try sendCommand(port, Command.BUNDLE, buffer);
    const result = try recvResponse(port, bytes_per_vector, allocator);
    defer allocator.free(result);

    var errors: usize = 0;
    for (result) |b| {
        if (b != 0x55) errors += 1;
    }

    if (errors == 0) {
        std.debug.print("  PASS: majority(+1, +1) = +1\n", .{});
    } else {
        std.debug.print("  FAIL: {d} bytes incorrect\n", .{errors});
    }
}

fn testSimilarity(port: std.fs.File, allocator: std.mem.Allocator, dim: usize) !void {
    std.debug.print("[TEST] SIMILARITY ({d} dimensions)\n", .{dim});

    const bytes_per_vector = (dim * 2 + 7) / 8;
    const data_len = bytes_per_vector * 2;
    const buffer = try allocator.alloc(u8, data_len);
    defer allocator.free(buffer);

    // Test: all (+1) * (+1) = +256
    @memset(buffer, 0x55);

    try sendCommand(port, Command.SIMILARITY, buffer);
    const result = try recvResponse(port, 3, allocator); // status + dot LSB + dot MSB
    defer allocator.free(result);

    if (result[0] == @intFromEnum(Response.OK)) {
        const dot_lsb = result[1];
        const dot_msb = result[2] & 0x07;
        const dot_value: i11 = @bitCast(@as(u11, @intCast(dot_msb)) << 8 | dot_lsb);

        std.debug.print("  Dot product: {d}\n", .{dot_value});
        if (dot_value == @as(i11, @intCast(dim))) {
            std.debug.print("  PASS: Maximum similarity\n", .{});
        } else {
            std.debug.print("  FAIL: Expected {d}, got {d}\n", .{ dim, dot_value });
        }
    } else {
        std.debug.print("  FAIL: FPGA returned error\n", .{});
    }
}

fn runBenchmark(port: std.fs.File, allocator: std.mem.Allocator, dim: usize) !void {
    std.debug.print("[BENCHMARK] {d} dimensions\n", .{dim});
    std.debug.print("═══════════════════════════════════\n", .{});

    const bytes_per_vector = (dim * 2 + 7) / 8;
    const data_len = bytes_per_vector * 2;
    const buffer = try allocator.alloc(u8, data_len);
    defer allocator.free(buffer);

    @memset(buffer, 0x55);

    // Benchmark BIND
    var timer = try std.time.Timer.start();
    try sendCommand(port, Command.BIND, buffer);
    _ = try recvResponse(port, bytes_per_vector, allocator);
    const bind_time_ns = timer.lap();

    // Benchmark BUNDLE
    timer.reset();
    try sendCommand(port, Command.BUNDLE, buffer);
    _ = try recvResponse(port, bytes_per_vector, allocator);
    const bundle_time_ns = timer.lap();

    // Benchmark SIMILARITY
    timer.reset();
    try sendCommand(port, Command.SIMILARITY, buffer);
    _ = try recvResponse(port, 3, allocator);
    const similarity_time_ns = timer.lap();

    std.debug.print("BIND latency:       {d} ns ({d:.1} MHz equivalent)\n", .{
        bind_time_ns,
        1_000_000_000.0 / @as(f64, @floatFromInt(bind_time_ns)),
    });
    std.debug.print("BUNDLE latency:     {d} ns\n", .{bundle_time_ns});
    std.debug.print("SIMILARITY latency: {d} ns\n", .{similarity_time_ns});

    // Estimate ops/sec (excluding UART overhead)
    std.debug.print("\nEstimated FPGA ops/sec:\n", .{});
    std.debug.print("  BIND:       {d:.0} M ops/s\n", .{1_000_000_000.0 / @as(f64, @floatFromInt(bind_time_ns)) / 1_000_000.0});
    std.debug.print("  BUNDLE:     {d:.0} M ops/s\n", .{1_000_000_000.0 / @as(f64, @floatFromInt(bundle_time_ns)) / 1_000_000.0});
    std.debug.print("  SIMILARITY: {d:.0} M ops/s\n", .{1_000_000_000.0 / @as(f64, @floatFromInt(similarity_time_ns)) / 1_000_000.0});
}

fn sendCommand(port: std.fs.File, cmd: Command, data: []const u8) !void {
    var buffer: [1024]u8 = undefined;
    buffer[0] = @intFromEnum(cmd);
    buffer[1] = @intCast((data.len >> 8) & 0xFF);
    buffer[2] = @intCast(data.len & 0xFF);

    @memcpy(buffer[3..][0..data.len], data);

    // Simple XOR checksum
    var checksum: u8 = 0;
    for (buffer[0 .. data.len + 3]) |b| checksum ^= b;
    buffer[data.len + 3] = checksum;

    _ = try port.writeAll(buffer[0 .. data.len + 4]);
}

fn recvResponse(port: std.fs.File, expected_len: usize, allocator: std.mem.Allocator) ![]u8 {
    _ = expected_len;
    var buffer: [1024]u8 = undefined;

    // Read status + length
    const n = try port.readAll(buffer[0..2]);
    if (n < 2) return error.ShortRead;

    const status = buffer[0];
    const len = buffer[1];

    if (status == @intFromEnum(Response.ERROR)) {
        return error.FPGAError;
    }

    if (len > 0) {
        const n2 = try port.readAll(buffer[2 .. 2 + len]);
        if (n2 < len) return error.ShortRead;
    }

    // Allocate and return data
    const result = try allocator.alloc(u8, len + 2);
    @memcpy(result, buffer[0 .. len + 2]);
    return result;
}

// φ² + 1/φ² = 3 = TRINITY
