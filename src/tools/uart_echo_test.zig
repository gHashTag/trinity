//! UART Echo Test — Simple test for FPGA UART bridge
//! Sends bytes and expects them echoed back
//!
//! Usage:
//!     zig run uart-echo-test
//!
//! Dependencies:
//!     Zig 0.15+ (uses uefi.protocol.SerialIo for POSIX serial)
//!
//! Note: Configure serial port to 115200 8N1 before running:
//!   stty -f /dev/cu.usbserial-* 115200 cs8 -parenb -cstopb 1 -hupcl

const std = @import("std");
const builtin = @import("builtin");
const uefi = @import("uefi");

// UEFI Serial Protocol for Zig 0.15
extern struct {
    reset: fn (*SerialIo) callconv(.C) uefi.Status,
    _set_attribute: fn (*SerialIo, u64, u32, u32, uefi.ParityType, u8, uefi.StopBitsType) callconv(.C) uefi.Status,
    _set_control: fn (*SerialIo, u32) callconv(.C) uefi.Status,
    _get_control: fn (*SerialIo, *u32) callconv(.C) uefi.Status,
    _write: fn (*SerialIo, [*]u8, usize) callconv(.C) uefi.Status,
    _read: fn (*SerialIo, [*]u8, usize) callconv(.C) uefi.Status,
} SerialIo;

// Constants
const DEFAULT_BAUD: u64 = 115200;
const DEFAULT_DATA_BITS: u8 = 8;
const DEFAULT_STOP_BITS: uefi.StopBitsType = .type1; // 1 stop bit

// Parity types from SerialIo
const ParityType = enum(u8) {
    .none = 0,
    .even = 1,
    .odd = 2,
};

pub fn main() !void {
    const stdout = std.io.getStdErr();

    try stdout.writeAll(
        \\╔════════════════════════════════════════════════════╗
        \\║           Trinity UART Echo Test v2.0                       ║
        \\║    UEFI SerialIo (Zig 0.15+)                          ║
        \\║    phi² + 1/phi² = 3 = TRINITY                        ║
        \\╚══════════════════════════════════════════════════╝
        \\
    );

    // Находим FT232RL устройство
    stdout.print("[+] Scanning for FT232RL device...\n") catch {};
    const port = findFT232Device() catch |err| {
        stdout.print("[✗] Error scanning: {s}\n", .{err});
        std.process.exit(1);
    };

    if (port) |p| {
        stdout.print("[+] Found FT232RL: {s}\n", .{p});
        stdout.print("\n[!] IMPORTANT: Configure port first:\n");
        stdout.print("    stty -f {s} 115200 cs8 -parenb -cstopb 1 -hupcl\n", .{p});
        stdout.print("\n[Press Enter when ready...]\n");

        // Ждем Enter
        var buf: [100]u8 = undefined;
        _ = std.io.getStdIn().read(&buf) catch |err| {
            stdout.print("[✗] Failed to read input: {s}\n", .{err});
            std.process.exit(1);
        };
    } else {
        stdout.print("[!] FT232RL not found!\n");
        stdout.print("\nAvailable serial ports:\n");
        listSerialPorts(stdout);
        std.process.exit(1);
    }

    stdout.print("\n", .{});
    stdout.print("╔══════════════════════════════════════════════╗", .{});
    stdout.print("║  Testing:                                          ║", .{});
    stdout.print("╚══════════════════════════════════════════╝", .{});

    // Тестовая последовательность
    const tests = [_]TestByte{
        .{ .data = &[_]u8{'A'}, .name = "'A'" },
        .{ .data = &[_]u8{0x55}, .name = "0x55 (alternating)" },
        .{ .data = &[_]u8{0xAA}, .name = "0xAA (alternating)" },
        .{ .data = "Hello", .name = "\"Hello\"" },
        .{ .data = &[_]u8{0x00}, .name = "0x00 (zero)" },
        .{ .data = &[_]u8{0xFF}, .name = "0xFF (all ones)" },
    };

    var passed: usize = 0;
    var test_idx: usize = 0;

    while (test_idx < tests.len) {
        const testCase = tests[test_idx];
        if (testEcho(stdout, port.?, testCase.data, test_idx + 1, tests.len)) {
            passed += 1;
        }
        std.time.sleep(200_000_000); // 200ms между тестами
        test_idx += 1;
    }

    stdout.print("\n", .{});
    stdout.print("╔════════════════════════════════════════════╗", .{});
    stdout.print("║  SUMMARY                                           ║", .{});
    stdout.print("╚══════════════════════════════════════════╝", .{});
    stdout.print("  Passed: {d}/{d}\n", .{passed, tests.len});
    stdout.print("\n", .{});
}

const TestByte = struct {
    data: []const u8,
    name: []const u8,
};

fn testEcho(stdout: std.fs.File, port_path: []const u8, data: []const u8, test_num: usize, total: usize) bool {
    // Открытие SerialIo устройства
    var device_path: [_]u8{0} ** 256 = undefined;
    var device_path_len: u32 = 0;

    // Пробуем открыть возможные порты
    const possible_ports = [_][]const u8{
        "/dev/cu.usbserial-0010",
        "/dev/cu.usbserial-0011",
        "/dev/cu.usbserial-0012",
        "/dev/cu.usbserial-0013",
        "/dev/tty.usbserial-0010",
        "/dev/tty.usbserial-0011",
        "/dev/tty.usbserial-0012",
        "/dev/tty.usbserial-0013",
    };

    for (possible_ports) |path| {
        _ = std.mem.copy(u8, &device_path, path);
        device_path_len = path.len;

        if (comptime builtin.os.tag == .macos) {
            // macOS путь
            const full_path = try std.os.realpath(path);
        } else if (comptime builtin.os.tag == .linux) {
            // Linux путь тот же
            const full_path = path;
        }
    }

    // Открытие через UEFI SerialIo
    const serial = uefi.SerialIo.open(&device_path) catch |err| {
        stdout.print("[✗] Failed to open {s}: {s}\n", .{full_path, err}) catch {};
        return false;
    };

    stdout.print("[+] Opened: {s}\n", .{full_path}) catch {};

    // Настройка параметров
    const set_attr_result = serial._set_attribute(
        serial,
        DEFAULT_BAUD,           // baud_rate
        8,                      // receiver_fifo_depth
        2000,                  // timeout (ms)
        ParityType.none,       // parity
        8,                      // data_bits
        DEFAULT_STOP_BITS,      // stop_bits
    );

    if (set_attr_result != .success) {
        stdout.print("[✗] SetAttribute failed: {s}\n", .{set_attr_result}) catch {};
        _ = serial.reset(serial);
        return false;
    }

    // Сброс контрольных сигналов (CTS/RTS)
    const set_ctrl_result = serial._set_control(serial, 0x0); // 0 = clear DTR, 2 = clear RTS
    if (set_ctrl_result != .success) {
        stdout.print("[✗] SetControl failed: {s}\n", .{set_ctrl_result}) catch {};
        _ = serial.reset(serial);
        return false;
    }

    // Отправка тестовых данных
    for (tests, 0..) |testCase, i| {
        stdout.print("  [→] Test {d}/{d} Sending {s} (0x", .{test_num, total, testCase.data}) catch {};
        for (testCase.data) |b| {
            stdout.print("{x:0>2}", .{b}) catch {};
        }
        stdout.writeAll(")\n") catch {};

        // Чтение ответа
        var read_buffer: [512]u8 = undefined;
        var bytes_read: usize = 0;
        const start_time = std.time.milliTimestamp();
        const timeout_ms = 2000;

        while (std.time.milliTimestamp() - start_time < timeout_ms) {
            const read_result = serial._read(serial, read_buffer[bytes_read..]) catch |err| {
                // Timeout - продолжаем
                continue;
            };

            bytes_read += read_result;

            if (bytes_read >= testCase.data.len) {
                break;
            }
        }

        // Вывод полученного
        stdout.print("  [←] Received ", .{}) catch {};
        for (read_buffer[0..bytes_read]) |b| {
            stdout.print("{x:0>2} ", .{b}) catch {};
        }
        stdout.writeAll("\n") catch {};

        // Проверка эхо
        if (bytes_read == testCase.data.len) {
            var match = true;
            for (0..testCase.data.len) |i| {
                if (read_buffer[i] != testCase.data[i]) {
                    match = false;
                    break;
                }
            }

            if (match) {
                stdout.print("  [✓] ECHO SUCCESS!\n") catch {};
                return true;
            } else {
                stdout.print("  [✗] ECHO FAIL! Mismatch\n") catch {};
                return false;
            }
        } else {
            stdout.print("  [✗] TIMEOUT - Received {d} bytes, expected {d}\n", .{bytes_read, testCase.data.len}) catch {};
            return false;
        }
    }
}

// Сброс устройства перед выходом
    _ = serial.reset(serial) catch {};
    _ = serial.reset(serial) catch {};
}

// Находим FT232RL устройство
fn findFT232Device() ?[]const u8 {
    if (comptime builtin.os.tag == .macos) {
        // macOS: /dev/cu.usbserial-*
        const dir = std.fs.openDirAbsolute("/dev") catch |err| return error.FileNotFound;

        var iterator = dir.iterate();
        while (iterator.next()) |entry| {
            const name = entry.name;
            if (std.mem.indexOf(u8, name, "cu.usbserial") != null) {
                const full_path = std.fmt.allocPrintZ("/dev/{s}", .{name});
                return full_path;
            }
        }
    } else if (comptime builtin.os.tag == .linux) {
        // Linux: /dev/ttyUSB* или /dev/ttyACM*
        const dir = std.fs.openDirAbsolute("/dev") catch |err| return error.FileNotFound;

        var iterator = dir.iterate();
        while (iterator.next()) |entry| {
            const name = entry.name;
            if ((std.mem.indexOf(u8, name, "ttyUSB") != null) or (std.mem.indexOf(u8, name, "ttyACM") != null)) {
                const full_path = std.fmt.allocPrintZ("/dev/{s}", .{name});
                return full_path;
            }
        }
    }

    return null;
}

fn listSerialPorts(stdout: std.fs.File) void {
    if (comptime builtin.os.tag == .macos) {
        const dir = std.fs.openDirAbsolute("/dev") catch |err| return;

        var iterator = dir.iterate();
        while (iterator.next()) |entry| {
            const name = entry.name;
            if (std.mem.indexOf(u8, name, "cu.usbserial") != null) {
                stdout.print("  {s}\n", .{name}) catch {};
            }
        }
    } else if (comptime builtin.os.tag == .linux) {
        const dir = std.fs.openDirAbsolute("/dev") catch |err| return;

        var iterator = dir.iterate();
        while (iterator.next()) |entry| {
            const name = entry.name;
            if ((std.mem.indexOf(u8, name, "ttyUSB") != null) or (std.mem.indexOf(u8, name, "ttyACM") != null)) {
                stdout.print("  {s}\n", .{name}) catch {};
            }
        }
    }
}
