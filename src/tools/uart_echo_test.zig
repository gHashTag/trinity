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
const DEFAULT_DELAY_MS: u32 = 200;  // Delay between tests
const DEFAULT_TIMEOUT_MS: u32 = 2000;  // Read timeout

// Test configuration
const Config = struct {
    baud: u64,
    delay_ms: u32,
    timeout_ms: u32,
    verbose: bool,
};

// Parse command line arguments
fn parseArgs(stdout: std.fs.File) Config {
    var config = Config{
        .baud = DEFAULT_BAUD,
        .delay_ms = DEFAULT_DELAY_MS,
        .timeout_ms = DEFAULT_TIMEOUT_MS,
        .verbose = false,
    };

    var i: usize = 1;
    while (i < std.os.argv.len) : (i += 1) {
        const arg = std.os.argv[i];

        if (std.mem.eql(u8, arg, "--baud")) {
            if (i + 1 >= std.os.argv.len) {
                stdout.print("[✗] --baud requires value\n", .{}) catch {};
                std.process.exit(1);
            }
            config.baud = std.fmt.parseInt(u64, std.os.argv[i + 1], 10) catch |err| {
                stdout.print("[✗] Invalid baud value: {s}\n", .{err}) catch {};
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "--delay")) {
            if (i + 1 >= std.os.argv.len) {
                stdout.print("[✗] --delay requires value\n", .{}) catch {};
                std.process.exit(1);
            }
            config.delay_ms = std.fmt.parseInt(u32, std.os.argv[i + 1], 10) catch |err| {
                stdout.print("[✗] Invalid delay value: {s}\n", .{err}) catch {};
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "--timeout")) {
            if (i + 1 >= std.os.argv.len) {
                stdout.print("[✗] --timeout requires value\n", .{}) catch {};
                std.process.exit(1);
            }
            config.timeout_ms = std.fmt.parseInt(u32, std.os.argv[i + 1], 10) catch |err| {
                stdout.print("[✗] Invalid timeout value: {s}\n", .{err}) catch {};
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            config.verbose = true;
        } else if (std.mem.eql(u8, arg, "--help")) {
            printUsage(stdout);
            std.process.exit(0);
        }
    }

    return config;
}

fn printUsage(stdout: std.fs.File) void {
    stdout.print(
        \\╔══════════════════════════════════════════════════════╗
        \\║           Trinity UART Echo Test v2.1                       ║
        \\║    Usage: uart-echo-test [options]                        ║
        \\╚══════════════════════════════════════════════════════╝
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
    const stderr = std.io.getStdErr().writer();
    const config = parseArgs(stderr);

    if (config.verbose) {
        logConfig(stderr, config);
    }

    try stderr.writeAll(

    if (config.verbose) {
        logConfig(stdout, config);
    }

    try stdout.writeAll(
        \\╔══════════════════════════════════════════════════════╗
        \\║           Trinity UART Echo Test v2.1                       ║
        \\║    Sends bytes with configurable delay/timeout               ║
        \\║    phi² + 1/phi² = 3 = TRINITY                        ║
        \\╚══════════════════════════════════════════════════════╝
        \\
    );

    // Find FT232RL device
    stdout.print("[+] Scanning for FT232RL device...\n", .{}) catch {};
    const port = findFT232Device() catch |err| {
        stdout.print("[✗] Error scanning: {s}\n", .{err}) catch {};
        std.process.exit(1);
    };

    if (port) |p| {
        stdout.print("[+] Found FT232RL: {s}\n", .{p}) catch {};
        stdout.print("\n[!] IMPORTANT: Configure port first:\n", .{}) catch {};
        stdout.print("    stty -f {s} {d} cs8 -parenb -cstopb 1 -hupcl\n", .{p, config.baud}) catch {};
        stdout.print("\n[Press Enter when ready...]\n", .{}) catch {};

        var buf: [100]u8 = undefined;
        _ = std.io.getStdIn().read(&buf) catch |err| {
            stdout.print("[✗] Failed to read input: {s}\n", .{err}) catch {};
            std.process.exit(1);
        };
    } else {
        stdout.print("[!] FT232RL not found!\n", .{}) catch {};
        stdout.print("\nAvailable serial ports:\n", .{}) catch {};
        listSerialPorts(stdout);
        std.process.exit(1);
    }

    stdout.print("\n", .{}) catch {};
    stdout.print("╔══════════════════════════════════════════════════╗", .{}) catch {};
    stdout.print("║  Testing:                                          ║", .{}) catch {};
    stdout.print("╚════════════════════════════════════════════════╝", .{}) catch {};

    const tests = [_]TestByte{
        .{ .data = &[_]u8{'A'}, .name = "'A'" },
        .{ .data = &[_]u8{0x55}, .name = "0x55 (alternating)" },
        .{ .data = &[_]u8{0xAA}, .name = "0xAA (alternating)" },
        .{ .data = &[_]u8{0x00}, .name = "0x00 (zero)" },
        .{ .data = "Hello", .name = "\"Hello\"" },
        .{ .data = &[_]u8{0xFF}, .name = "0xFF (all ones)" },
    };

    var passed: usize = 0;
    var test_idx: usize = 0;

    while (test_idx < tests.len) {
        const testCase = tests[test_idx];
        if (testEcho(stdout, port.?, testCase.data, test_idx + 1, tests.len, config)) {
            passed += 1;
        }
        std.time.sleep(config.delay_ms * 1_000_000);
        test_idx += 1;
    }

    stdout.print("\n", .{}) catch {};
    stdout.print("╔════════════════════════════════════════════╗", .{}) catch {};
    stdout.print("║  SUMMARY                                           ║", .{}) catch {};
    stdout.print("╚══════════════════════════════════════════╝", .{}) catch {};
    stdout.print("  Passed: {d}/{d}\n", .{passed, tests.len}) catch {};
    stdout.print("\n", .{}) catch {};
}

const TestByte = struct {
    data: []const u8,
    name: []const u8,
};

fn logConfig(stdout: std.fs.File, config: Config) void {
    stdout.print("[*] Configuration:\n", .{}) catch {};
    stdout.print("    baud: {d}\n", .{config.baud}) catch {};
    stdout.print("    delay: {d}ms\n", .{config.delay_ms}) catch {};
    stdout.print("    timeout: {d}ms\n", .{config.timeout_ms}) catch {};
    stdout.print("    verbose: true\n", .{}) catch {};
    stdout.print("\n", .{}) catch {};
}

fn testEcho(stdout: std.fs.File, port_path: []const u8, data: []const u8, test_num: usize, total: usize, config: Config) bool {
    var fd: std.posix.fd_t = undefined;

    // Try to open the serial port directly
    const open_result = std.posix.open(
        port_path,
        std.posix.O.RDWR | std.posix.O.NOCTTY,
        0,
    );

    if (open_result) |err| {
        stdout.print("[✗] Failed to open {s}: {s}\n", .{port_path, err}) catch {};
        return false;
    }

    fd = open_result;

    stdout.print("[+] Opened: {s}\n", .{port_path}) catch {};

    // Configure as raw terminal
    var termios = std.os.tcgetattr(fd) catch {
        stdout.print("[✗] tcgetattr failed\n", .{}) catch {};
        std.os.close(fd);
        return false;
    };

    termios.c_iflag &= ~@as(u32, std.os.ICRNL | std.os.IGNCR);
    termios.c_oflag &= ~@as(u32, std.os.OPOST);
    termios.c_lflag &= ~@as(u32, std.os.ECHO | std.os.ICANON | std.os.ISIG);
    termios.c_cc[@as(usize, std.os.VMIN)] = 1;
    termios.c_cc[@as(usize, std.os.VTIME)] = 0;

    _ = std.os.tcsetattr(fd, .{ .v = termios, .act = .TCSANOW });

    // Set baud rate
    const baud_const: u32 = switch (config.baud) {
        9600 => std.os.B9600,
        19200 => std.os.B19200,
        38400 => std.os.B38400,
        57600 => std.os.B57600,
        115200 => std.os.B115200,
        else => {
            stdout.print("[✗] Unsupported baud rate: {d}\n", .{config.baud}) catch {};
            std.os.close(fd);
            return false;
        },
    };

    var termios2 = std.os.tcgetattr(fd) catch {
        stdout.print("[✗] tcgetattr (2nd) failed\n", .{}) catch {};
        std.os.close(fd);
        return false;
    };
    termios2.c_cflag &= ~@as(u32, std.os.CBAUD);
    termios2.c_cflag |= @as(u32, baud_const);
    termios2.c_cflag |= @as(u32, std.os.CREAD | std.os.CLOCAL);

    _ = std.os.tcsetattr(fd, .{ .v = termios2, .act = .TCSANOW });

    stdout.print("[+] Configured: {d} baud\n", .{config.baud}) catch {};

    // Send test data
    stdout.print("  [→] Test {d}/{d} Sending data: ", .{test_num, total}) catch {};
    for (data) |b| {
        stdout.print("{x:0>2}", .{b}) catch {};
    }
    stdout.print(" ({d} bytes)\n", .{data.len}) catch {};

    // Write data to serial port
    const write_result = std.os.write(fd, data);
    if (write_result) |written| {
        if (written != data.len) {
            stdout.print("  [!] Only wrote {d}/{d} bytes\n", .{written, data.len}) catch {};
        }
    } else |err| {
        stdout.print("  [✗] Write error: {s}\n", .{err}) catch {};
        std.os.close(fd);
        return false;
    }

    if (config.verbose) {
        stdout.print("  [*] Waiting for echo (timeout: {d}ms)...\n", .{config.timeout_ms}) catch {};
    }

    // Read response
    var read_buffer: [512]u8 = undefined;
    var bytes_read: usize = 0;
    const start_time = std.time.milliTimestamp();

    while (std.time.milliTimestamp() - start_time < config.timeout_ms) {
        const read_result = std.os.read(fd, read_buffer[bytes_read..]);

        if (read_result == error.OperationWouldBlock) {
            std.time.sleep(10_000);
            continue;
        } else if (read_result) |n| {
            bytes_read += n;
            if (config.verbose) {
                stdout.print("  [*] Read {d} bytes\n", .{n}) catch {};
            }
            if (bytes_read >= data.len) {
                break;
            }
        } else {
            // Error - continue trying
            if (config.verbose) {
                stdout.print("  [*] Read error, retrying...\n", .{}) catch {};
            }
        }
    }

    // Output received
    stdout.print("  [←] Received ", .{}) catch {};
    for (read_buffer[0..bytes_read]) |b| {
        stdout.print("{x:0>2}", .{b}) catch {};
    }
    stdout.print(" ({d} bytes)\n", .{bytes_read}) catch {};

    // Verify match
    if (bytes_read == data.len) {
        var match = true;
        for (0..data.len) |i| {
            if (read_buffer[i] != data[i]) {
                match = false;
                stdout.print("  [✗] Mismatch at index {d}: sent 0x{x:0>2}, got 0x{x:0>2}\n", .{i, data[i], read_buffer[i]}) catch {};
                break;
            }
        }

        if (match) {
            stdout.print("  [✓] ECHO SUCCESS!\n", .{}) catch {};
            _ = std.os.close(fd);
            return true;
        } else {
            stdout.print("  [✗] ECHO FAIL! Mismatch\n", .{}) catch {};
            _ = std.os.close(fd);
            return false;
        }
    } else {
        stdout.print("  [✗] TIMEOUT - Received {d} bytes, expected {d}\n", .{bytes_read, data.len}) catch {};
        _ = std.os.close(fd);
        return false;
    }
}

fn findFT232Device() ?[]const u8 {
    const dir = std.fs.openDirAbsolute("/dev") catch return null;

    var iterator = dir.iterate();
    while (iterator.next()) |entry| {
        const name = entry.name;
        if (std.mem.indexOf(u8, name, "cu.usbserial") != null) {
            const full_path = std.fmt.allocPrintZ("/dev/{s}", .{name}) catch return null;
            return full_path;
        }
    }

    return null;
}

fn listSerialPorts(stdout: anytype) void {
    const dir = std.fs.openDirAbsolute("/dev") catch return;

    var iterator = dir.iterate();
    while (iterator.next()) |entry| {
        const name = entry.name;
        if (std.mem.indexOf(u8, name, "cu.usbserial") != null) {
            stdout.print("  {s}\n", .{name}) catch {};
        }
    }
}
