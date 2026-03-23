//! UART Echo Test — Simple test for FPGA UART bridge
//! Sends bytes with configurable delay and expects them echoed back
//!
//! Usage:
//!     zig run uart-echo-test [--baud 115200] [--delay 200] [--timeout 2000] [--mode echo|ping-pong] [-v|--verbose]
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

// PING/PONG protocol
const PING_BYTE: u8 = 0x03;  // Request echo test
const PONG_BYTE: u8 = 0x83;  // Echo response

// Test modes
const TestMode = enum {
    echo,       // Simple byte echo
    ping_pong,  // PING/PONG protocol test
};

// Test configuration
const Config = struct {
    baud: u64,
    delay_ms: u32,
    timeout_ms: u32,
    verbose: bool,
    mode: TestMode,
};

// Parse command line arguments
fn parseArgs(stderr: std.fs.File) Config {
    var config = Config{
        .baud = DEFAULT_BAUD,
        .delay_ms = DEFAULT_DELAY_MS,
        .timeout_ms = DEFAULT_TIMEOUT_MS,
        .verbose = false,
        .mode = .echo,
    };

    var i: usize = 1;
    while (i < std.os.argv.len) : (i += 1) {
        const arg = std.os.argv[i];

        if (std.mem.eql(u8, arg, "--baud")) {
            if (i + 1 >= std.os.argv.len) {
                stderr.print("[✗] --baud requires value\n", .{}) catch {};
                std.process.exit(1);
            }
            config.baud = std.fmt.parseInt(u64, std.os.argv[i + 1], 10) catch |err| {
                stderr.print("[✗] Invalid baud value: {s}\n", .{err}) catch {};
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "--delay")) {
            if (i + 1 >= std.os.argv.len) {
                stderr.print("[✗] --delay requires value\n", .{}) catch {};
                std.process.exit(1);
            }
            config.delay_ms = std.fmt.parseInt(u32, std.os.argv[i + 1], 10) catch |err| {
                stderr.print("[✗] Invalid delay value: {s}\n", .{err}) catch {};
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "--timeout")) {
            if (i + 1 >= std.os.argv.len) {
                stderr.print("[✗] --timeout requires value\n", .{}) catch {};
                std.process.exit(1);
            }
            config.timeout_ms = std.fmt.parseInt(u32, std.os.argv[i + 1], 10) catch |err| {
                stderr.print("[✗] Invalid timeout value: {s}\n", .{err}) catch {};
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            config.verbose = true;
            if (i + 1 < std.os.argv.len) {
                i += 1; // Skip flag value
            }
        } else if (std.mem.eql(u8, arg, "--mode")) {
            const mode_arg = if (i + 1 >= std.os.argv.len) {
                stderr.print("[✗] --mode requires value\n", .{}) catch {};
                std.process.exit(1);
            };
            const mode_val = std.os.argv[i + 1];
            if (std.mem.eql(u8, mode_val, "echo")) {
                config.mode = .echo;
            } else if (std.mem.eql(u8, mode_val, "ping-pong")) {
                config.mode = .ping_pong;
            } else {
                stderr.print("[✗] Invalid mode: {s}\n", .{mode_val}) catch {};
                stderr.print(" Supported modes: echo, ping-pong\n", .{}) catch {};
                std.process.exit(1);
            }
            i += 1;
        } else if (std.mem.eql(u8, arg, "--help")) {
            printUsage(stderr);
            std.process.exit(0);
        }
    }

    return config;
}

fn printUsage(stderr: std.fs.File) void {
    stderr.print(
        \\╔══════════════════════════════════════════════════╗
        \\║           Trinity UART Echo Test v2.2                       ║
        \\║    Usage: uart-echo-test [options]                        ║
        \\╚══════════════════════════════════════════════════╝
        \\
        \\Options:
        \\  --baud <rate>     Baud rate (default: 115200)
        \\  --delay <ms>      Delay between tests in ms (default: 200)
        \\  --timeout <ms>    Read timeout in ms (default: 2000)
        \\  --mode <mode>     Test mode: echo, ping-pong
        \\  -v, --verbose     Enable verbose logging
        \\  --help            Show this help message
        \\
        \\Example (echo mode):
        \\  zig run uart-echo-test --baud 115200 --delay 100 -v
        \\
        \\Example (ping-pong mode):
        \\  zig run uart-echo-test --mode ping-pong --verbose
        , .{}) catch {};
}

pub fn main() !void {
    const stderr = std.io.getStdErr();
    const stdout = std.io.getStdOut();
    const config = parseArgs(stderr);

    if (config.verbose) {
        logConfig(stderr, config);
    }

    try stderr.writeAll(
        \\╔══════════════════════════════════════════════════════╗
        \\║           Trinity UART Echo Test v2.2                       ║
        \\║    Sends bytes with configurable delay/timeout               ║
        \\║    phi² + 1/phi² = 3 = TRINITY                        ║
        \\╚════════════════════════════════════════════════════════════╝
        \\
    ) catch |err| {
        stderr.print("[✗] Error: {s}\n", .{err});
        std.process.exit(1);
    };

    // Find FT232RL device
    stderr.print("[+] Scanning for FT232RL device...\n", .{}) catch {};
    const port = findFT232Device() catch |err| {
        stderr.print("[✗] Error scanning: {s}\n", .{err}) catch {};
        std.process.exit(1);
    };

    if (port) |p| {
        stderr.print("[+] Found FT232RL: {s}\n", .{p}) catch {};
        stderr.print("\n[!] IMPORTANT: Configure port first:\n", .{}) catch {};
        stderr.print("    stty -f {s} {d} cs8 -parenb -cstopb 1 -hupcl\n", .{p, config.baud}) catch {};
        stderr.print("\n[Press Enter when ready...]\n", .{}) catch {};

        var buf: [100]u8 = undefined;
        _ = std.io.getStdIn().read(&buf) catch |err| {
            stderr.print("[✗] Failed to read input: {s}\n", .{err}) catch {};
            std.process.exit(1);
        };
    } else {
        stderr.print("[!] FT232RL not found!\n", .{}) catch {};
        stderr.print("\nAvailable serial ports:\n", .{}) catch {};
        listSerialPorts(stderr);
        std.process.exit(1);
    }

    stderr.print("\n", .{}) catch {};
    stderr.print("╔════════════════════════════════════════════════════╗", .{}) catch {};
    stderr.print("║  Testing:                                          ║", .{}) catch {};
    stderr.print("╚══════════════════════════════════════════════════════╝", .{}) catch {};

    // PING/PONG mode
    if (config.mode == .ping_pong) {
        stderr.print("\n[*] PING/PONG mode: sending PING (0x03), expecting PONG (0x83)\n", .{}) catch {};
        const success = pingPong(stderr, stdout, port.?, config);

        stderr.print("\n", .{}) catch {};
        stderr.print("╔════════════════════════════════════════════════════════╗", .{}) catch {};
        stderr.print("║  SUMMARY                                           ║", .{}) catch {};
        stderr.print("╚════════════════════════════════════════════════════════════╝", .{}) catch {};
        if (success) {
            stderr.print("  [✓] PING/PONG TEST PASSED!\n", .{}) catch {};
        } else {
            stderr.print("  [✗] PING/PONG TEST FAILED!\n", .{}) catch {};
        }
        stderr.print("\n", .{}) catch {};
        return;
    }

    const tests = [_]TestByte{,
        .{ .data = &[_]u8{'A'}, .name = "'A'" },
        .{ .data = &[_]u8{0x55}, .name = "0x55 (alternating)" },
        .{ .data = &[_]u8{0xAA}, .name = "0xAA (alternating)" },
        .{ .data = "Hello", .name = "Hello" },
        { .data = &[_]u8{0x00}, .name = "0x00 (zero)" },
        { .data = &[_]u8{0x00}, .name = "0x00 (zero)" },
        { .data = &[_]u8{0xFF}, .name = "0xFF (all ones)" },
        { .data = &[_]u8{0xFF}, .name = "0xFF (all ones)" },
    };


    var passed: usize = 0;
    var test_idx: usize = 0;

    while (test_idx < tests.len) {
        const testCase = tests[test_idx];
        if (testEcho(stderr, stdout, port.?, testCase.data, test_idx + 1, tests.len, config)) {
            passed += 1;
        }
        std.time.sleep(config.delay_ms * 1_000_000);
        test_idx += 1;
    }

    stderr.print("\n", .{}) catch {};
    stderr.print("╔════════════════════════════════════════════════════╗", .{}) catch {};
    stderr.print("║  SUMMARY                                           ║", .{}) catch {};
    stderr.print("╚════════════════════════════════════════════════════════════╝", .{}) catch {};
    stderr.print("  Passed: {d}/{d}\n", .{passed, tests.len}) catch {};
    stderr.print("\n", .{}) catch {};
}

const TestByte = struct {
    data: []const u8,
    name: []const u8,
};

fn logConfig(stderr: std.fs.File, config: Config) void {
    stderr.print("[*] Configuration:\n", .{}) catch {};
    stderr.print("    mode: {s}\n", .{@tagName(TestMode, config.mode)}) catch {};
    stderr.print("    baud: {d}\n", .{config.baud}) catch {};
    stderr.print("    delay: {d}ms\n", .{config.delay_ms}) catch {};
    stderr.print("    timeout: {d}ms\n", .{config.timeout_ms}) catch {};
    stderr.print("    verbose: true\n", .{}) catch {};
    stderr.print("\n", .{}) catch {};
}

fn listSerialPorts(stderr: std.fs.File) void {
    const dir = std.fs.openDirAbsolute("/dev") catch |err| return;
    var iterator = dir.iterate();
    while (iterator.next()) |entry| {
        const name = entry.name;
        if (std.mem.indexOf(u8, name, "cu.usbserial") != null) {
            stderr.print("  {s}\n", .{name}) catch {};
        }
    }
}

// Configure serial port settings
fn configureSerial(stderr: std.fs.File, fd: std.posix.fd_t, baud: u64) bool {
    var termios = std.os.tcgetattr(fd) catch {
        stderr.print("[✗] tcgetattr failed\n", .{}) catch {};
        return true;
    };

    termios.c_iflag &= ~@as(u32, std.os.ICRNL | std.os.IGNCR);
    termios.c_oflag &= ~@as(u32, std.os.OPOST);
    termios.c_lflag &= ~@as(u32, std.os.ECHO | std.os.ICANON | std.os.ISIG);
    termios.c_cc[@as(usize, std.os.VMIN)] = 1;
    termios.c_cc[@as(usize, std.os.VTIME)] = 0;

    _ = std.os.tcsetattr(fd, .{ .v = termios, .act = .TCSANOW });

    // Set baud rate
    const baud_const: u32 = switch (baud) {
        9600 => std.os.B9600,
        19200 => std.os.B19200,
        38400 => std.os.B38400,
        57600 => std.os.B57600,
        115200 => std.os.B115200,
        else => {
            stderr.print("[✗] Unsupported baud rate: {d}\n", .{baud}) catch {};
            return true;
        },
    };

    var termios2 = std.os.tcgetattr(fd) catch {
        stderr.print("[✗] tcgetattr (2nd) failed\n", .{}) catch {};
        return true;
    };
    termios2.c_cflag &= ~@as(u32, std.os.CBAUD);
    termios2.c_cflag |= @as(u32, baud_const);
    termios2.c_cflag |= @as(u32, std.os.CREAD | std.os.CLOCAL);

    _ = std.os.tcsetattr(fd, .{ .v = termios2, .act = .TCSANOW });

    return false;
}

// PING/PONG test mode
fn pingPong(stderr: std.fs.File, stdout: std.fs.File, port_path: []const u8, config: Config) bool {
    var fd: std.posix.fd_t = undefined;

    // Open serial port
    const open_result = std.posix.open(port_path, std.posix.O.RDWR | std.posix.O.NOCTTY, 0);

    if (open_result) |err| {
        stderr.print("[✗] Failed to open {s}: {s}\n", .{port_path, err}) catch {};
        return false;
    }
    fd = open_result;

    // Configure serial
    if (configureSerial(stderr, fd, config.baud)) {
        std.os.close(fd);
        return false;
    }

    stderr.print("[+] Configured: {d} baud (PING/PONG mode)\n", .{config.baud}) catch {};

    if (config.verbose) {
        stderr.print("\n[*] Sending PING: 0x03\n", .{}) catch {};
    }

    // Send PING (0x03)
    const ping_data = [_]u8{PING_BYTE};
    const write_result = std.os.write(fd, &ping_data);

    if (write_result) |written| {
        if (written != ping_data.len) {
            stderr.print("[!] Only wrote {d}/{d} bytes\n", .{written, ping_data.len}) catch {};
        }
    } else |err| {
        stderr.print("[✗] Write error: {s}\n", .{err}) catch {};
        std.os.close(fd);
        return false;
    }

    // Wait for response
    if (config.verbose) {
        stderr.print("[*] Waiting for PONG response...\n", .{}) catch {};
    }

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
                stderr.print("[*] Read {d} bytes (total: {d})\n", .{n, bytes_read}) catch {};
            }
            if (bytes_read >= 1) {
                break;
            }
        } else {
            if (config.verbose) {
                stderr.print("[*] Read error, retrying...\n", .{}) catch {};
            }
        }
    }

    // Output received
    stderr.print("  [←] Received ", .{}) catch {};
    for (read_buffer[0..bytes_read]) |b| {
        stderr.print("{x:0>2}", .{b}) catch {};
    }
    stderr.print(" ({d} bytes)\n", .{bytes_read}) catch {};

    // Verify PONG response (0x83)
    if (bytes_read >= 1) {
        const response_byte = read_buffer[0];
        if (response_byte == PONG_BYTE) {
            stderr.print("  [✓] PING/PONG SUCCESS!\n", .{}) catch {};
            if (config.verbose) {
                stderr.print("  [*] FPGA responded with PONG (0x83)\n", .{}) catch {};
            }
            _ = std.os.close(fd);
            return true;
        } else {
            stderr.print("  [✗] PING/PONG FAIL!\n", .{}) catch {};
            stderr.print("  [*] Expected: 0x{x:0>2}\n", .{PONG_BYTE}) catch {};
            stderr.print("  [*] Got:      0x{x:0>2}\n", .{response_byte}) catch {};
            _ = std.os.close(fd);
            return false;
        }
    } else {
        stderr.print("  [✗] TIMEOUT - No response\n", .{}) catch {};
        _ = std.os.close(fd);
        return false;
    }
}

// Simple echo test mode
fn testEcho(stderr: std.fs.File, stdout: std.fs.File, port_path: []const u8, data: []const u8, test_num: usize, total: usize, config: Config) bool {
    var fd: std.posix.fd_t = undefined;

    // Try to open the serial port directly
    const open_result = std.posix.open(
        port_path,
        std.posix.O.RDWR | std.posix.O.NOCTTY,
        0,
    );

    if (open_result) |err| {
        stderr.print("[✗] Failed to open {s}: {s}\n", .{port_path, err}) catch {};
        return false;
    }

    fd = open_result;

    stderr.print("[+] Opened: {s}\n", .{port_path}) catch {};

    // Configure as raw terminal
    var termios = std.os.tcgetattr(fd) catch {
        stderr.print("[✗] tcgetattr failed\n", .{}) catch {};
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
    const baud_const: u32 = switch (DEFAULT_BAUD) {
        9600 => std.os.B9600,
        19200 => std.os.B19200,
        38400 => std.os.B38400,
        57600 => std.os.B57600,
        115200 => std.os.B115200,
        else => {
            stderr.print("[✗] Unsupported baud rate: {d}\n", .{DEFAULT_BAUD}) catch {};
            std.os.close(fd);
            return false;
        },
    };

    var termios2 = std.os.tcgetattr(fd) catch {
        stderr.print("[✗] tcgetattr (2nd) failed\n", .{}) catch {};
        std.os.close(fd);
        return false;
    };
    termios2.c_cflag &= ~@as(u32, std.os.CBAUD);
    termios2.c_cflag |= @as(u32, baud_const);
    termios2.c_cflag |= @as(u32, std.os.CREAD | std.os.CLOCAL);

    _ = std.os.tcsetattr(fd, .{ .v = termios2, .act = .TCSANOW });

    stderr.print("[+] Configured: {d} baud\n", .{DEFAULT_BAUD}) catch {};

    // Send test data
    stderr.print("  [→] Test {d}/{d} Sending data: ", .{test_num, total}) catch {};
    for (data) |b| {
        stderr.print("{x:0>2}", .{b}) catch {};
    }
    stderr.print(" ({d} bytes)\n", .{data.len}) catch {};

    // Write data to serial port
    const write_result = std.os.write(fd, data);
    if (write_result) |written| {
        if (written != data.len) {
            stderr.print("  [!] Only wrote {d}/{d} bytes\n", .{written, data.len}) catch {};
        }
    } else |err| {
        stderr.print("  [✗] Write error: {s}\n", .{err}) catch {};
        std.os.close(fd);
        return false;
    }

    if (config.verbose) {
        stderr.print("  [*] Waiting for echo (timeout: {d}ms)...\n", .{config.timeout_ms}) catch {};
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
                stderr.print("  [*] Read {d} bytes\n", .{n}) catch {};
            }
            if (bytes_read >= data.len) {
                break;
            }
        } else {
            if (config.verbose) {
                stderr.print("  [*] Read error, retrying...\n", .{}) catch {};
            }
        }
    }

    // Output received
    stderr.print("  [←] Received ", .{}) catch {};
    for (read_buffer[0..bytes_read]) |b| {
        stderr.print("{x:0>2}", .{b}) catch {};
    }
    stderr.print(" ({d} bytes)\n", .{bytes_read}) catch {};

    // Verify match
    if (bytes_read == data.len) {
        var match = true;
        for (0..data.len) |i| {
            if (read_buffer[i] != data[i]) {
                match = false;
                stderr.print("  [✗] Mismatch at index {d}: sent 0x{x:0>2}, got 0x{x:0>2}\n", .{i, data[i], read_buffer[i]}) catch {};
                break;
            }
        }

        if (match) {
            stderr.print("  [✓] ECHO SUCCESS!\n", .{}) catch {};
            _ = std.os.close(fd);
            return true;
        } else {
            stderr.print("  [✗] ECHO FAIL! Mismatch\n", .{}) catch {};
            _ = std.os.close(fd);
            return false;
        }
    } else {
        stderr.print("  [✗] TIMEOUT - Received {d} bytes, expected {d}\n", .{bytes_read, data.len}) catch {};
        _ = std.os.close(fd);
        return false;
    }
}

fn findFT232Device() ?[]const u8 {
    const dir = std.fs.openDirAbsolute("/dev") catch |err| return error.FileNotFound;

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
