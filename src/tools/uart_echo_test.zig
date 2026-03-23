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
const DEFAULT_DELAY_MS: u32 = 200; // Delay between tests
const DEFAULT_TIMEOUT_MS: u32 = 2000; // Read timeout

// PING/PONG protocol
const PING_BYTE: u8 = 0x03; // Request echo test
const PONG_BYTE: u8 = 0x83; // Echo response

// Test modes
const TestMode = enum {
    echo, // Simple byte echo
    ping_pong, // PING/PONG protocol test
};

// Test configuration
const Config = struct {
    baud: u64,
    delay_ms: u32,
    timeout_ms: u32,
    verbose: bool,
    mode: TestMode,
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
        .mode = .echo,
    };

    var i: usize = 1;
    while (i < std.os.argv.len) : (i += 1) {
        const arg = std.mem.span(std.os.argv[i]);

        if (std.mem.eql(u8, arg, "--baud")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[✗] --baud requires value\n", .{});
                std.process.exit(1);
            }
            config.baud = std.fmt.parseInt(u64, std.mem.span(std.os.argv[i + 1]), 10) catch |err| {
                printErr("[✗] Invalid baud value: {s}\n", .{err});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "--delay")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[✗] --delay requires value\n", .{});
                std.process.exit(1);
            }
            config.delay_ms = std.fmt.parseInt(u32, std.mem.span(std.os.argv[i + 1]), 10) catch |err| {
                printErr("[✗] Invalid delay value: {s}\n", .{err});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "--timeout")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[✗] --timeout requires value\n", .{});
                std.process.exit(1);
            }
            config.timeout_ms = std.fmt.parseInt(u32, std.mem.span(std.os.argv[i + 1]), 10) catch |err| {
                printErr("[✗] Invalid timeout value: {s}\n", .{err});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            config.verbose = true;
            if (i + 1 < std.os.argv.len) {
                i += 1; // Skip flag value
            }
        } else if (std.mem.eql(u8, arg, "--mode")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[✗] --mode requires value\n", .{});
                std.process.exit(1);
            }
            const mode_val = std.mem.span(std.os.argv[i + 1]);
            if (std.mem.eql(u8, mode_val, "echo")) {
                config.mode = .echo;
            } else if (std.mem.eql(u8, mode_val, "ping-pong")) {
                config.mode = .ping_pong;
            } else {
                printErr("[✗] Invalid mode: {s}\n", .{mode_val});
                printErr(" Supported modes: echo, ping-pong\n", .{});
                std.process.exit(1);
            }
            i += 1;
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
        \\╔══════════════════════════════════════════════════════╗
        \\║           Trinity UART Echo Test v2.3                       ║
        \\║    Usage: uart-echo-test [options]                        ║
        \\╚══════════════════════════════════════════════════════╝
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
        \\
    , .{}) catch {};
}

pub fn main() !void {
    const config = parseArgs();

    if (config.verbose) {
        logConfig(config);
    }

    printErr(
        \\╔══════════════════════════════════════════════════════╗
        \\║           Trinity UART Echo Test v2.3                       ║
        \\║    Sends bytes with configurable delay/timeout               ║
        \\║    phi² + 1/phi² = 3 = TRINITY                        ║
        \\╚════════════════════════════════════════════════════════════╝
        \\
    , .{});

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
            printErr("[✗] Failed to read input: {any}\n", .{err});
            std.process.exit(1);
        };
    } else {
        printErr("[!] FT232RL not found!\n", .{});
        printErr("\nAvailable serial ports:\n", .{});
        listSerialPorts();
        std.process.exit(1);
    }

    printErr("\n", .{});
    printErr("╔══════════════════════════════════════════════════════╗", .{});
    printErr("║  Testing:                                          ║", .{});
    printErr("╚══════════════════════════════════════════════════════╝", .{});

    // PING/PONG mode
    if (config.mode == .ping_pong) {
        printErr("\n[*] PING/PONG mode: sending PING (0x03), expecting PONG (0x83)\n", .{});
        const success = pingPong(port.?, config);

        printErr("\n", .{});
        printErr("╔════════════════════════════════════════════════════════╗", .{});
        printErr("║  SUMMARY                                           ║", .{});
        printErr("╚════════════════════════════════════════════════════════════╝", .{});
        if (success) {
            printErr("  [✓] PING/PONG TEST PASSED!\n", .{});
        } else {
            printErr("  [✗] PING/PONG TEST FAILED!\n", .{});
        }
        printErr("\n", .{});
        return;
    }

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
        if (testEcho(port.?, testCase.data, test_idx + 1, tests.len, config)) {
            passed += 1;
        }
        std.Thread.sleep(config.delay_ms * 1_000_000);
        test_idx += 1;
    }

    printErr("\n", .{});
    printErr("╔══════════════════════════════════════════════════════╗", .{});
    printErr("║  SUMMARY                                           ║", .{});
    printErr("╚════════════════════════════════════════════════════════════╝", .{});
    printErr("  Passed: {d}/{d}\n", .{ passed, tests.len });
    printErr("\n", .{});
}

const TestByte = struct {
    data: []const u8,
    name: []const u8,
};

// Open flags for POSIX (Zig 0.15 compatibility)
const O_RDONLY: u32 = 0o0;
const O_WRONLY: u32 = 0o1;
const O_RDWR: u32 = 0o2;
const O_NOCTTY: u32 = 0x800;

// Combine flags with proper casting
fn combineFlags(flags: []const u32) u32 {
    var result: u32 = 0;
    for (flags) |f| {
        result |= f;
    }
    return result;
}

fn logConfig(config: Config) void {
    printErr("[*] Configuration:\n", .{});
    printErr("    mode: {s}\n", .{@tagName(config.mode)});
    printErr("    baud: {d}\n", .{config.baud});
    printErr("    delay: {d}ms\n", .{config.delay_ms});
    printErr("    timeout: {d}ms\n", .{config.timeout_ms});
    printErr("    verbose: true\n", .{});
    printErr("\n", .{});
}

fn listSerialPorts() void {
    const dir = std.fs.openDirAbsolute("/dev", .{}) catch return;
    var iterator = dir.iterate();
    while (iterator.next()) |entry| {
        const name = entry.basename;;
        if (std.mem.indexOf(u8, name, "cu.usbserial") != null) {
            printErr("  {s}\n", .{name});
        }
    } else |err| {
        _ = err catch {};
    }
}

// Configure serial port settings
fn configureSerial(fd: std.posix.fd_t, baud: u64) bool {
    var termios = std.os.tcgetattr(fd) catch {
        printErr("[✗] tcgetattr failed\n", .{});
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
            printErr("[✗] Unsupported baud rate: {d}\n", .{baud});
            return true;
        },
    };

    var termios2 = std.os.tcgetattr(fd) catch {
        printErr("[✗] tcgetattr (2nd) failed\n", .{});
        return true;
    };
    termios2.c_cflag &= ~@as(u32, std.os.CBAUD);
    termios2.c_cflag |= @as(u32, baud_const);
    termios2.c_cflag |= @as(u32, std.os.CREAD | std.os.CLOCAL);

    _ = std.os.tcsetattr(fd, .{ .v = termios2, .act = .TCSANOW });

    return false;
}

// PING/PONG test mode
fn pingPong(port_path: []const u8, config: Config) bool {
    var fd: std.posix.fd_t = undefined;

    // Open serial port
    const flags = O_RDWR | O_NOCTTY;
    const o_flags: std.posix.O = @as(std.posix.O, @bitCast(flags));
    const open_result = std.posix.open(port_path, o_flags, 0);

    if (open_result) |fd_value| {
        fd = fd_value;
    } else |err| {
        printErr("[✗] Failed to open {s}: {s}\n", .{ port_path, err });
        return false;
    }

    // Configure serial
    if (configureSerial(fd, config.baud)) {
        std.os.close(fd);
        return false;
    }

    printErr("[+] Configured: {d} baud (PING/PONG mode)\n", .{config.baud});

    if (config.verbose) {
        printErr("\n[*] Sending PING: 0x03\n", .{});
    }

    // Send PING (0x03)
    const ping_data = [_]u8{PING_BYTE};
    const write_result = std.os.write(fd, &ping_data);

    if (write_result) |written| {
        if (written != ping_data.len) {
            printErr("[!] Only wrote {d}/{d} bytes\n", .{ written, ping_data.len });
        }
    } else |err| {
        printErr("[✗] Write error: {s}\n", .{err});
        std.os.close(fd);
        return false;
    }

    // Wait for response
    if (config.verbose) {
        printErr("[*] Waiting for PONG response...\n", .{});
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
                printErr("[*] Read {d} bytes (total: {d})\n", .{ n, bytes_read });
            }
            if (bytes_read >= 1) {
                break;
            }
        } else {
            if (config.verbose) {
                printErr("[*] Read error, retrying...\n", .{});
            }
        }
    }

    // Output received
    printErr("  [←] Received ", .{});
    for (read_buffer[0..bytes_read]) |b| {
        printErr("{x:0>2}", .{b});
    }
    printErr(" ({d} bytes)\n", .{bytes_read});

    // Verify PONG response (0x83)
    if (bytes_read >= 1) {
        const response_byte = read_buffer[0];
        if (response_byte == PONG_BYTE) {
            printErr("  [✓] PING/PONG SUCCESS!\n", .{});
            if (config.verbose) {
                printErr("  [*] FPGA responded with PONG (0x83)\n", .{});
            }
            _ = std.os.close(fd);
            return true;
        } else {
            printErr("  [✗] PING/PONG FAIL!\n", .{});
            printErr("  [*] Expected: 0x{x:0>2}\n", .{PONG_BYTE});
            printErr("  [*] Got:      0x{x:0>2}\n", .{response_byte});
            _ = std.os.close(fd);
            return false;
        }
    } else {
        printErr("  [✗] TIMEOUT - No response\n", .{});
        _ = std.os.close(fd);
        return false;
    }
}

// Simple echo test mode
fn testEcho(port_path: []const u8, data: []const u8, test_num: usize, total: usize, config: Config) bool {
    var fd: std.posix.fd_t = undefined;

    // Try to open serial port directly
    const flags = O_RDWR | O_NOCTTY;
    const o_flags: std.posix.O = @as(std.posix.O, @bitCast(flags));
    const open_result = std.posix.open(port_path, o_flags, 0);

    if (open_result) |fd_value| {
        fd = fd_value;
    } else |err| {
        printErr("[✗] Failed to open {s}: {s}\n", .{ port_path, err });
        return false;
    }

    printErr("[+] Opened: {s}\n", .{port_path});

    // Configure as raw terminal
    var termios = std.os.tcgetattr(fd) catch {
        printErr("[✗] tcgetattr failed\n", .{});
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
            printErr("[✗] Unsupported baud rate: {d}\n", .{DEFAULT_BAUD});
            std.os.close(fd);
            return false;
        },
    };

    var termios2 = std.os.tcgetattr(fd) catch {
        printErr("[✗] tcgetattr (2nd) failed\n", .{});
        std.os.close(fd);
        return false;
    };
    termios2.c_cflag &= ~@as(u32, std.os.CBAUD);
    termios2.c_cflag |= @as(u32, baud_const);
    termios2.c_cflag |= @as(u32, std.os.CREAD | std.os.CLOCAL);

    _ = std.os.tcsetattr(fd, .{ .v = termios2, .act = .TCSANOW });

    printErr("[+] Configured: {d} baud\n", .{DEFAULT_BAUD});

    // Send test data
    printErr("  [→] Test {d}/{d} Sending data: ", .{ test_num, total });
    for (data) |b| {
        printErr("{x:0>2}", .{b});
    }
    printErr(" ({d} bytes)\n", .{data.len});

    // Write data to serial port
    const write_result = std.os.write(fd, data);
    if (write_result) |written| {
        if (written != data.len) {
            printErr("  [!] Only wrote {d}/{d} bytes\n", .{ written, data.len });
        }
    } else |err| {
        printErr("  [✗] Write error: {s}\n", .{err});
        std.os.close(fd);
        return false;
    }

    if (config.verbose) {
        printErr("  [*] Waiting for echo (timeout: {d}ms)...\n", .{config.timeout_ms});
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
                printErr("  [*] Read {d} bytes\n", .{n});
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
            _ = std.os.close(fd);
            return true;
        } else {
            printErr("  [✗] ECHO FAIL! Mismatch\n", .{});
            _ = std.os.close(fd);
            return false;
        }
    } else {
        printErr("  [✗] TIMEOUT - Received {d} bytes, expected {d}\n", .{ bytes_read, data.len });
        _ = std.os.close(fd);
        return false;
    }
}

fn findFT232Device() ?[]const u8 {
    const dir = std.fs.openDirAbsolute("/dev", .{}) catch return null;

    var iterator = dir.iterate();
    while (iterator.next()) |entry| {
        const name = entry.basename;;
        if (std.mem.indexOf(u8, name, "cu.usbserial") != null) {
            var fba = std.heap.FixedBufferAllocator.init(&std.heap.page_allocator);
            const full_path = std.fmt.allocPrintZ(fba.allocator(), "/dev/{s}", .{name}) catch return null;
            return full_path;
        }
    } else |err| {
        _ = err catch {};
    }

    return null;
}
