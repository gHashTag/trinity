// UART Test Tool — Trinity CLI
// Tests UART communication without FPGA (loopback simulation)
// Usage: tri uart-test <device> [--baud 115200] [--test-mode echo|loopback]

const std = @import("std");

const DEFAULT_BAUD: u32 = 115_200;
const BUFFER_SIZE: usize = 1024;

const TestMode = enum {
    echo, // Echo mode: receive and echo back
    loopback, // Loopback mode: TX->RX hardware loopback
};

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.heap.page_allocator.free(args);

    if (args.len < 2) {
        std.debug.print("Usage: tri uart-test <device> [options]\n", .{});
        std.debug.print("  device        - Serial device (e.g., /dev/tty.usbserial-xxx)\n", .{});
        std.debug.print("  --baud <bps> - Baud rate (default: 115200)\n", .{});
        std.debug.print("  --test-mode echo|loopback - Test mode (default: echo)\n", .{});
        std.debug.print("\nTest Modes:\n", .{});
        std.debug.print("  echo      - Send PING (0x03), wait for PONG (0x83)\n", .{});
        std.debug.print("  loopback  - Send pattern, verify hardware loopback\n", .{});
        std.process.exit(1);
    }

    var baud_rate: u32 = DEFAULT_BAUD;
    var test_mode: TestMode = .echo;
    var device_arg: ?[]const u8 = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--baud") and i + 1 < args.len) {
            baud_rate = try std.fmt.parseInt(u32, args[i + 1], 10);
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--test-mode")) {
            if (i + 1 < args.len) {
                if (std.mem.eql(u8, args[i + 1], "loopback")) {
                    test_mode = .loopback;
                } else if (std.mem.eql(u8, args[i + 1], "echo")) {
                    test_mode = .echo;
                } else {
                    std.debug.print("Unknown test mode: {s}\n", .{args[i + 1]});
                    std.process.exit(1);
                }
                i += 1;
            }
        } else {
            device_arg = args[i];
        }
    }

    if (device_arg == null) {
        std.debug.print("Error: No device specified\n", .{});
        std.process.exit(1);
    }

    const device = device_arg.?;

    std.debug.print("UART Test Tool\n", .{});
    std.debug.print("═", .{});
    std.debug.print("Device: {s}\n", .{device});
    std.debug.print("Baud: {d}\n", .{baud_rate});
    std.debug.print("Mode: {s}\n", .{switch (test_mode) {
        .echo => "Echo (PING/PONG)",
        .loopback => "Hardware Loopback",
    }});
    std.debug.print("═\n", .{});

    const fd = try std.posix.open(
        device,
        .{ .RDWR = true, .NOCTTY = true },
        0,
    );
    defer std.os.close(fd);

    try configureSerial(fd, baud_rate);

    switch (test_mode) {
        .echo => runEchoTest(fd),
        .loopback => runLoopbackTest(fd),
    }
}

fn configureSerial(fd: std.posix.fd_t, baud_rate: u32) !void {
    const baud_constant = switch (baud_rate) {
        9600 => 0xC,
        19200 => 0xB,
        38400 => 0xE,
        57600 => 0x10,
        115200 => 0x11,
        else => {
            std.debug.print("Unsupported baud rate: {d}\n", .{baud_rate});
            std.process.exit(1);
        },
    };

    var termios = try std.os.tcgetattr(fd);
    termios.c_cflag = termios.c_cflag & ~@as(u32, 0xC0C00);
    termios.c_cflag = termios.c_cflag | @as(u32, baud_constant);
    termios.c_cflag |= @as(u32, std.os.CREAD | std.os.CLOCAL);

    _ = std.os.tcsetattr(fd, .{ .v = termios, .act = .TCSANOW });

    std.debug.print("Configured: {d} baud\n", .{baud_rate});
}

fn runEchoTest(fd: std.posix.fd_t) !void {
    std.debug.print("Echo Test: PING (0x03) → PONG (0x83)\n", .{});
    std.debug.print("─", .{});

    const ping = [_]u8{0x03};
    _ = try std.os.write(fd, &ping);

    std.debug.print("Sent: PING (0x03)\n", .{});
    std.debug.print("Waiting for PONG... ", .{});

    var buffer: [BUFFER_SIZE]u8 = undefined;
    var total_read: usize = 0;
    const start_time = std.time.nanoTimestamp();

    while (total_read < 1) {
        const elapsed_ns = std.time.nanoTimestamp() - start_time;
        const elapsed_ms = @as(f64, elapsed_ns) / 1_000_000.0;

        if (elapsed_ms > 5000.0) {
            std.debug.print("\n❌ Timeout: No response in 5 seconds\n", .{});
            std.process.exit(1);
        }

        const read_result = std.os.read(fd, buffer[total_read..]);
        if (read_result > 0) {
            total_read += @as(usize, read_result);

            if (total_read == 1 and buffer[0] == 0x83) {
                const response_ns = std.time.nanoTimestamp() - start_time;
                const elapsed_us = @as(f64, response_ns) / 1000.0;

                std.debug.print("\n✅ Received PONG (0x83)\n", .{});
                std.debug.print("Round trip: {d:.3} μs\n", .{elapsed_us});

                try runMultiplePings(fd, 5);
                return;
            } else {
                std.debug.print("  Unexpected byte: 0x{X:0>2}\n", .{buffer[total_read - 1]});
            }
        }

        std.time.sleep(100_000);
    }
}

fn runMultiplePings(fd: std.posix.fd_t, count: u32) !void {
    std.debug.print("\nRunning {d} ping tests...\n", .{count});
    std.debug.print("─", .{});

    var success: u32 = 0;
    var total_us: f64 = 0.0;
    var min_us: f64 = 1_000_000.0;
    var max_us: f64 = 0.0;

    var i: u32 = 0;
    while (i < count) : (i += 1) {
        std.time.sleep(100_000);

        const ping = [_]u8{0x03};
        _ = try std.os.write(fd, &ping);

        const start_time = std.time.nanoTimestamp();
        var pong_received = false;

        var timeout: u32 = 0;
        while (!pong_received and timeout < 50) {
            var buffer: [1]u8 = undefined;
            const read_result = std.os.read(fd, &buffer);

            if (read_result > 0 and buffer[0] == 0x83) {
                pong_received = true;
                const elapsed_ns = std.time.nanoTimestamp() - start_time;
                const elapsed_us = @as(f64, elapsed_ns) / 1000.0;

                success += 1;
                total_us += elapsed_us;
                min_us = @min(min_us, elapsed_us);
                max_us = @max(max_us, elapsed_us);

                std.debug.print("  [{d}/{d}] {d:.3} μs", .{ i + 1, count, elapsed_us });
            }

            std.time.sleep(10_000);
            timeout += 1;
        }

        if (!pong_received) {
            std.debug.print("  [{d}/{d}] ❌ Timeout\n", .{ i + 1, count });
        }
    }

    std.debug.print("\nPing Statistics:\n", .{});
    std.debug.print("────────────────\n", .{});
    std.debug.print("Success rate: {d}/{d} ({d:.1}%)\n", .{
        success,                                     count,
        @as(f64, success) * 100.0 / @as(f64, count),
    });

    if (success > 0) {
        const avg_us = total_us / @as(f64, success);
        std.debug.print("Average: {d:.3} μs\n", .{avg_us});
        std.debug.print("Min: {d:.3} μs\n", .{min_us});
        std.debug.print("Max: {d:.3} μs\n", .{max_us});
    }
}

fn runLoopbackTest(fd: std.posix.fd_t) !void {
    std.debug.print("Hardware Loopback Test\n", .{});
    std.debug.print("─", .{});
    std.debug.print("Send pattern, verify RX receives same data\n", .{});

    const pattern = [_]u8{ 0xAA, 0x55, 0x00, 0xFF, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0 };

    var success: u32 = 0;
    var byte_idx: usize = 0;

    while (byte_idx < pattern.len) : (byte_idx += 1) {
        const byte = pattern[byte_idx];
        _ = try std.os.write(fd, &[_]u8{byte});

        std.debug.print("Sent: 0x{X:0>2} ", .{byte});

        var buffer: [1]u8 = undefined;
        var timeout: u32 = 0;
        var received = false;

        while (!received and timeout < 100) {
            const read_result = std.os.read(fd, &buffer);
            if (read_result > 0) {
                received = true;
                if (buffer[0] == byte) {
                    success += 1;
                    std.debug.print("✅\n", .{});
                } else {
                    std.debug.print("❌ (got 0x{X:0>2})\n", .{buffer[0]});
                }
            }

            std.time.sleep(10_000);
            timeout += 1;
        }

        if (!received) {
            std.debug.print("❌ Timeout\n", .{});
        }

        std.time.sleep(50_000);
    }

    std.debug.print("\nResult: {d}/{d} bytes matched\n", .{ success, pattern.len });
}
