//! UART Echo Test — Simple test for FPGA UART bridge
//! Sends bytes with configurable delay and expects them echoed back
//!
//! Usage:
//!     zig run uart-echo-test [--baud 115200] [--delay 200] [--timeout 2000] [-v|--verbose]
//!
//! Dependencies:
//!     Zig 0.15+ (uses POSIX serial)
//!
//! Note: Configure serial port to 115200 8N1 before running:
//!   stty -f /dev/cu.usbserial-* 115200 cs8 -parenb -cstopb 1 -hupcl

const std = @import("std");

// Constants
const DEFAULT_BAUD: u64 = 115200;
const DEFAULT_DATA_BITS: u8 = 8;
const DEFAULT_STOP_BITS: u8 = 1;
const DEFAULT_DELAY_MS: u32 = 200; // Delay between tests
const DEFAULT_TIMEOUT_MS: u32 = 2000; // Read timeout

// Test configuration
const Config = struct {
    baud: u64,
    delay_ms: u32,
    timeout_ms: u32,
    verbose: bool,
};

// Helper for formatted stderr output
fn printErr(comptime fmt: []const u8, args: anytype) void {
    var buffer: [1024]u8 = undefined;
    const stderr = std.fs.File{ .handle = std.posix.STDERR_FILENO };
    var writer = stderr.writer(&buffer);
    writer.interface.print(fmt, args) catch {};
}

// Helper for formatted stdout output
fn printOut(comptime fmt: []const u8, args: anytype) void {
    var buffer: [1024]u8 = undefined;
    const stdout = std.fs.File{ .handle = std.posix.STDOUT_FILENO };
    var writer = stdout.writer(&buffer);
    writer.interface.print(fmt, args) catch {};
}

// Parse command line arguments
fn parseArgs() Config {
    var config = Config{
        .baud = DEFAULT_BAUD,
        .delay_ms = DEFAULT_DELAY_MS,
        .timeout_ms = DEFAULT_TIMEOUT_MS,
        .verbose = false,
    };

    var i: usize = 1;
    while (i < std.posix.argv.len) : (i += 1) {
        const arg = std.mem.span(std.os.argv[i]);

        if (std.mem.eql(u8, arg, "--baud")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --baud requires value\n", .{});
                std.process.exit(1);
            }
            config.baud = std.fmt.parseInt(u64, std.mem.span(std.os.argv[i + 1]), 10) catch |err| {
                printErr("[*] Invalid baud value: {any}\n", .{err});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "--delay")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --delay requires value\n", .{});
                std.process.exit(1);
            }
            config.delay_ms = std.fmt.parseInt(u32, std.mem.span(std.os.argv[i + 1]), 10) catch |err| {
                printErr("[*] Invalid delay value: {any}\n", .{err});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "--timeout")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --timeout requires value\n", .{});
                std.process.exit(1);
            }
            config.timeout_ms = std.fmt.parseInt(u32, std.mem.span(std.os.argv[i + 1]), 10) catch |err| {
                printErr("[*] Invalid timeout value: {any}\n", .{err});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            config.verbose = true;
            if (i + 1 < std.os.argv.len) {
                i += 1; // Skip next arg
            }
        } else if (std.mem.eql(u8, arg, "--help")) {
            printUsage();
            std.process.exit(0);
        }
    }

    return config;
}

fn printUsage() void {
    var buffer: [1024]u8 = undefined;
    const stderr = std.fs.File{ .handle = std.posix.STDERR_FILENO };
    var writer = stderr.writer(&buffer);
    writer.interface.print(
        \\╔═════════════════════════════════════════════════════
        \\║           Trinity UART Echo Test v2.5                       ║
        \\║    Usage: uart-echo-test [options]                        ║
        \\╚══════════════════════════════════════════════════╝
        \\
        \\Options:
        \\  --baud <rate>     Baud rate (default: 115200)
        \\  --delay <ms>      Delay between tests in ms (default: 200)
        \\  --timeout <ms>    Read timeout in ms (default: 2000)
        \\  -v, --verbose     Enable verbose logging
        \\  --help            Show this help message
        \\
        \\Example:
        \\  zig run uart-echo-test --baud 115200 --delay 100 -v
        \\
    , .{}) catch {};
}

pub fn main() !void {
    const config = parseArgs();

    if (config.verbose) {
        printErr("[*] Configuration:\n", .{});
        printErr("    baud: {d}\n", .{config.baud});
        printErr("    delay: {d}ms\n", .{config.delay_ms});
        printErr("    timeout: {d}ms\n", .{config.timeout_ms});
        printErr("    verbose: true\n", .{});
        printErr("\n", .{});
    }

    printErr(
        \\╔══════════════════════════════════════════════════╗
        \\║           Trinity UART Echo Test v2.5                       ║
        \\║    Sends bytes with configurable delay/timeout               ║
        \\║    phi² + 1/phi² = 3 = TRINITY                        ║
        \\╚═══════════════════════════════════════════════════╝
        \\
    ) catch |err| {
        printErr("[*] Error: {any}\n", .{err});
        std.process.exit(1);
    };

    // Find FT232RL device
    printErr("[+] Scanning for FT232RL device...\n", .{});
    const port = findFT232Device();

    if (port) |p| {
        printErr("[+] Found FT232RL: {s}\n", .{p});
        printErr("\n[!] IMPORTANT: Configure port first:\n", .{});
        printErr("    stty -f {s} {d} cs8 -parenb -cstopb 1 -hupcl\n", .{ p, config.baud });
        printErr("\n[Press Enter when ready...]\n", .{});

        var buf: [100]u8 = undefined;
        const stdin = std.fs.File{ .handle = std.posix.STDIN_FILENO };
        _ = stdin.read(&buf) catch |err| {
            printErr("[*] Failed to read input: {any}\n", .{err});
            std.process.exit(1);
        };
    } else {
        printErr("[!] FT232RL not found!\n", .{});
        printErr("\nAvailable serial ports:\n", .{});
        listSerialPorts();
        std.process.exit(1);
    }

    printErr("\n", .{});
    printErr("╔════════════════════════════════════════╗", .{});
    printErr("║  Testing:                                          ║", .{});
    printErr("╚══════════════════════════════════════════════╝", .{});

    // Simple echo test mode
    testEcho(port.?, config);
}

// List available serial ports
fn listSerialPorts() void {
    const dir = std.fs.openDirAbsolute("/dev", .{}) catch return;
    defer dir.close();
    var iterator = dir.iterate();
    while (iterator.next() catch |err| {
        _ = err;
        break;
    }) |entry| {
        const name = entry.basename;
        if (std.mem.indexOf(u8, name, "cu.usbserial") != null) {
            printErr("  {s}\n", .{name});
        }
    }
}

// Configure serial port settings
fn configureSerial(fd: std.posix.fd_t, baud: u64) bool {
    var termios = std.posix.tcgetattr(fd) catch {
        printErr("[*] tcgetattr failed\n", .{});
        return true;
    };

    termios.c_iflag &= ~@as(u32, std.posix.ICRNL | std.posix.IGNCR);
    termios.c_oflag &= ~@as(u32, std.posix.OPOST);
    termios.c_lflag &= ~@as(u32, std.posix.ECHO | std.posix.ICANON | std.posix.ISIG);
    termios.c_cc[@as(usize, std.posix.VMIN)] = 1;
    termios.c_cc[@as(usize, std.posix.VTIME)] = 0;

    _ = std.posix.tcsetattr(fd, .{ .v = termios, .act = .TCSANOW });

    // Set baud rate
    const baud_const: u32 = switch (baud) {
        9600 => std.posix.B9600,
        19200 => std.posix.B19200,
        38400 => std.posix.B38400,
        57600 => std.posix.B57600,
        115200 => std.posix.B115200,
        else => {
            printErr("[*] Unsupported baud rate: {d}\n", .{baud});
            return true;
        },
    };

    var termios2 = std.posix.tcgetattr(fd) catch {
        printErr("[*] tcgetattr (2nd) failed\n", .{});
        return true;
    };
    termios2.c_cflag &= ~@as(u32, std.posix.CBAUD);
    termios2.c_cflag |= @as(u32, baud_const);
    termios2.c_cflag |= @as(u32, std.posix.CREAD | std.posix.CLOCAL);

    _ = std.posix.tcsetattr(fd, .{ .v = termios2, .act = .TCSANOW });

    return false;
}

// Simple echo test mode
fn testEcho(port_path: []const u8, config: Config) void {
    var fd: std.posix.fd_t = undefined;

    // Try to open serial port directly
    const flags: u32 = 0o2 | 0x800; // RDWR | NOCTTY
    const o_flags: std.posix.O = @as(std.posix.O, @bitCast(flags));
    const open_result = std.posix.open(port_path, o_flags, 0);

    if (open_result) |fd_value| {
        fd = fd_value;
    } else |err| {
        printErr("[*] Failed to open {s}: {any}\n", .{ port_path, err });
        return;
    }

    printErr("[+] Opened: {s}\n", .{port_path});

    // Configure as raw terminal
    var termios = std.posix.tcgetattr(fd) catch {
        printErr("[*] tcgetattr failed\n", .{});
        std.posix.close(fd);
        return;
    };

    termios.c_iflag &= ~@as(u32, std.posix.ICRNL | std.posix.IGNCR);
    termios.c_oflag &= ~@as(u32, std.posix.OPOST);
    termios.c_lflag &= ~@as(u32, std.posix.ECHO | std.posix.ICANON | std.posix.ISIG);
    termios.c_cc[@as(usize, std.posix.VMIN)] = 1;
    termios.c_cc[@as(usize, std.posix.VTIME)] = 0;

    _ = std.posix.tcsetattr(fd, .{ .v = termios, .act = .TCSANOW });

    // Set baud rate
    const baud_const: u32 = switch (DEFAULT_BAUD) {
        9600 => std.posix.B9600,
        19200 => std.posix.B19200,
        38400 => std.posix.B38400,
        57600 => std.posix.B57600,
        115200 => std.posix.B115200,
        else => {
            printErr("[*] Unsupported baud rate: {d}\n", .{DEFAULT_BAUD});
            std.posix.close(fd);
            return;
        },
    };

    var termios2 = std.posix.tcgetattr(fd) catch {
        printErr("[*] tcgetattr (2nd) failed\n", .{});
        std.posix.close(fd);
        return;
    };
    termios2.c_cflag &= ~@as(u32, std.posix.CBAUD);
    termios2.c_cflag |= @as(u32, baud_const);
    termios2.c_cflag |= @as(u32, std.posix.CREAD | std.posix.CLOCAL);

    _ = std.posix.tcsetattr(fd, .{ .v = termios2, .act = .TCSANOW });

    printErr("[+] Configured: {d} baud\n", .{DEFAULT_BAUD});

    // Send test data
    const tests = [_]TestByte{
        .{ .data = &[_]u8{'A'}, .name = "'A'" },
        .{ .data = &[_]u8{0x55}, .name = "0x55 (alternating)" },
        .{ .data = &[_]u8{0xAA}, .name = "0xAA (alternating)" },
        .{ .data = "Hello", .name = "Hello" },
        .{ .data = &[_]u8{0x00}, .name = "0x00 (zero)" },
        .{ .data = &[_]u8{0xFF}, .name = "0xFF (all ones)" },
    };

    var passed: usize = 0;
    var test_idx: usize = 0;

    while (test_idx < tests.len) {
        const testCase = tests[test_idx];
        if (testEchoByte(fd, testCase.data, test_idx + 1, tests.len, config)) {
            passed += 1;
        }
        std.Thread.sleep(config.delay_ms * 1_000_000);
        test_idx += 1;
    }

    printErr("\n", .{});
    printErr("╔════════════════════════════════════════╗", .{});
    printErr("║  SUMMARY                                           ║", .{});
    printErr("╚══════════════════════════════════════════════╝", .{});
    printErr("  Passed: {d}/{d}\n", .{ passed, tests.len });
    printErr("\n", .{});

    _ = std.posix.close(fd);
}

// Test single byte
fn testEchoByte(fd: std.posix.fd_t, data: []const u8, test_num: usize, total: usize, config: Config) bool {
    printErr("  [→] Test {d}/{d} Sending data: ", .{ test_num, total });
    for (data) |b| {
        printErr("{x:0>2}", .{b});
    }
    printErr(" ({d} bytes)\n", .{data.len});

    // Write data to serial port
    const write_result = std.posix.write(fd, data);
    if (write_result) |written| {
        if (written != data.len) {
            printErr("  [!] Only wrote {d}/{d} bytes\n", .{ written, data.len });
        }
    } else |err| {
        printErr("  [*] Write error: {any}\n", .{err});
        std.posix.close(fd);
        return false;
    }
    std.Thread.sleep(config.delay_ms * 500_000); // Small delay after write

    if (config.verbose) {
        printErr("  [*] Waiting for echo (timeout: {d}ms)...\n", .{config.timeout_ms});
    }

    // Read response
    var read_buffer: [512]u8 = undefined;
    var bytes_read: usize = 0;
    const start_time = std.time.milliTimestamp();

    while (std.time.milliTimestamp() - start_time < config.timeout_ms) {
        const read_result = std.posix.read(fd, read_buffer[bytes_read..]);

        if (read_result == error.OperationWouldBlock) {
            std.Thread.sleep(10_000);
            continue;
        } else if (read_result) |n| {
            bytes_read += n;
            if (config.verbose) {
                printErr("  [*] Read {d} bytes (total: {d})\n", .{ n, bytes_read });
            }
            if (bytes_read >= data.len) {
                break;
            }
        } else {
            if (config.verbose) {
                printErr("  [*] Read error, retrying...\n", .{});
            }
        }
    }

    // Output received
    printErr("  [←] Received ", .{});
    for (read_buffer[0..bytes_read]) |b| {
        printErr("{x:0>2}", .{b});
    }
    printErr(" ({d} bytes)\n", .{bytes_read});

    // Verify match
    if (bytes_read == data.len) {
        var match = true;
        for (0..data.len) |i| {
            if (read_buffer[i] != data[i]) {
                match = false;
                printErr("  [✗] Mismatch at index {d}: sent 0x{x:0>2}, got 0x{x:0>2}\n", .{ i, data[i], read_buffer[i] });
                break;
            }
        }

        if (match) {
            printErr("  [✓] ECHO SUCCESS!\n", .{});
            return true;
        } else {
            printErr("  [✗] ECHO FAIL! Mismatch\n", .{});
            return false;
        }
    } else {
        printErr("  [✗] TIMEOUT - Received {d} bytes, expected {d}\n", .{ bytes_read, data.len });
    }
}

const TestByte = struct {
    data: []const u8,
    name: []const u8,
};

// Find FT232 device
fn findFT232Device() ?[]const u8 {
    const dir = std.fs.openDirAbsolute("/dev", .{}) catch return null;
    defer dir.close();

    var iterator = dir.iterate();
    while (iterator.next() catch |err| {
        _ = err;
        break;
    }) |entry| {
        const name = entry.basename;
        if (std.mem.indexOf(u8, name, "cu.usbserial") != null) {
            return std.fmt.allocPrintZ(std.heap.page_allocator, "/dev/{s}", .{name}) catch null;
        }
    }

    return null;
}
