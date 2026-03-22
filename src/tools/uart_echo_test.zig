//! UART Echo Test — Simple test for FPGA UART bridge
//! Sends bytes and expects them echoed back
//!
//! Usage:
//!     zig run uart-echo-test
//!
//! NOTE: Configure serial port to 115200 8N1 before running:
//!   stty -f /dev/cu.usbserial-* 115200 cs8 -parenb -cstopb 1 -hupcl

const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    stdout.print("╔════════════════════════════════════════════════════════╗\n", .{});
    stdout.print("║           Trinity UART Echo Test v1.0                       ║\n", .{});
    stdout.print("║    phi² + 1/phi² = 3 = TRINITY                        ║\n", .{});
    stdout.print("╚════════════════════════════════════════════════════════╝\n", .{});
    stdout.print("\n", .{});

    // Находим FT232RL устройство
    stdout.print("[+] Scanning for FT232RL device...\n", .{});
    const port = findFT232Device() catch |err| {
        stdout.print("[✗] Error scanning: {s}\n", .{err});
        std.process.exit(1);
    };

    if (port) |p| {
        stdout.print("[+] Found FT232RL: {s}\n", .{p});
        stdout.print("\n[!] IMPORTANT: Configure port first:\n", .{});
        stdout.print("    stty -f {s} 115200 cs8 -parenb -cstopb 1 -hupcl\n", .{p});
        stdout.print("\n[Press Enter when ready...]\n", .{});

        // Ждем Enter
        var buf: [100]u8 = undefined;
        _ = std.io.getStdIn().read(buf[0..]) catch |err| {
            stdout.print("[✗] Failed to read input: {s}\n", .{err});
            std.process.exit(1);
        };
    } else {
        stdout.print("[!] FT232RL not found!\n", .{});
        stdout.print("\nAvailable serial ports:\n", .{});
        listSerialPorts();
        std.process.exit(1);
    }

    stdout.print("\n", .{});
    stdout.print("╔════════════════════════════════════════════════════════╗\n", .{});
    stdout.print("║  Testing:                                                     ║\n", .{});
    stdout.print("╚════════════════════════════════════════════════════════╝\n", .{});

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

    for (tests, 0..) |test, i| {
        const result = testEcho(port.?, test.data, i + 1, tests.len);
        if (result) {
            passed += 1;
        }
        std.time.sleep(200_000_000); // 200ms между тестами
    }

    stdout.print("\n", .{});
    stdout.print("╔════════════════════════════════════════════════════════╗\n", .{});
    stdout.print("║  SUMMARY                                                       ║\n", .{});
    stdout.print("╚════════════════════════════════════════════════════════╝\n", .{});
    stdout.print("  Passed: {d}/{d}\n", .{passed, tests.len});
    stdout.print("\n", .{});
}

const TestByte = struct {
    data: []const u8,
    name: []const u8,
};

fn testEcho(port_path: []const u8, data: []const u8, test_num: usize, total: usize) bool {
    const stdout = std.io.getStdOut().writer();

    // Открываем порт
    const fd = std.os.open(
        port_path,
        .{ .mode = .read_write },
    ) catch |err| {
        stdout.print("[✗] Failed to open port: {s}\n", .{err});
        return false;
    };

    // Flush
    _ = std.os.fsync(fd, .{ .sync = .Data }) catch {};

    // Чистим буфер чтения
    var read_buffer: [4096]u8 = undefined;
    _ = std.os.read(fd, read_buffer[0..]) catch {};

    // Отправка
    stdout.print("  [→] Test {d}/{d} Sending {s} (0x", .{test_num, total, data});
    for (data) |b| {
        stdout.print("{x:0>2}", .{b});
    }
    stdout.print(")\n", .{});

    const write_result = std.os.write(fd, data) catch |err| {
        stdout.print("[✗] Write error: {s}\n", .{err});
        std.os.close(fd);
        return false;
    };

    // Чтение с таймаутом (2 секунды)
    const start_time = std.time.milliTimestamp();
    const timeout_ms = 2000;
    var bytes_read: usize = 0;
    var received: [256]u8 = undefined;

    while (std.time.milliTimestamp() - start_time < timeout_ms) {
        const read_result = std.os.read(fd, received[bytes_read..]) catch |err| {
            // EAGAIN — норма для неблокирующего чтения
            continue;
        };

        bytes_read += read_result;

        if (bytes_read >= data.len) {
            break;
        }
    }

    std.os.close(fd);

    // Вывод полученного
    stdout.print("  [←] Received ", .{});
    for (received[0..bytes_read]) |b| {
        stdout.print("{x:0>2} ", .{b});
    }
    stdout.print("\n", .{});

    // Проверка эхо
    if (bytes_read == data.len) {
        var match = true;
        for (0..data.len) |i| {
            if (received[i] != data[i]) {
                match = false;
                break;
            }
        }

        if (match) {
            stdout.print("  [✓] ECHO SUCCESS!\n", .{});
            return true;
        } else {
            stdout.print("  [✗] ECHO FAIL! Mismatch\n", .{});
            return false;
        }
    } else {
        stdout.print("  [✗] TIMEOUT - Received {d} bytes, expected {d}\n", .{bytes_read, data.len});
        return false;
    }
}

// Находим FT232RL устройство в /dev/ или /dev/cu.*
fn findFT232Device() ?[]const u8 {
    const stdout = std.io.getStdOut().writer();

    if (builtin.os.tag == .macos) {
        // macOS: /dev/cu.usbserial-*
        const dir = std.fs.openDirAbsolute("/dev") catch |err| return error.FileNotFound;

        var iterator = dir.iterate();
        while (iterator.next() catch |err| break) |entry| {
            const name = entry.name;
            if (std.mem.indexOf(u8, name, "cu.usbserial")) |_| {
                const full_path = std.fmt.allocPrintZ("/dev/{s}", .{name});
                return full_path;
            }
        }
    } else if (builtin.os.tag == .linux) {
        // Linux: /dev/ttyUSB* или /dev/ttyACM*
        const dir = std.fs.openDirAbsolute("/dev") catch |err| return error.FileNotFound;

        var iterator = dir.iterate();
        while (iterator.next() catch |err| break) |entry| {
            const name = entry.name;
            if (std.mem.indexOf(u8, name, "ttyUSB") |_| std.mem.indexOf(u8, name, "ttyACM")) |_| {
                const full_path = std.fmt.allocPrintZ("/dev/{s}", .{name});
                return full_path;
            }
        }
    }

    return null;
}

fn listSerialPorts() void {
    const stdout = std.io.getStdOut().writer();

    if (builtin.os.tag == .macos) {
        const dir = std.fs.openDirAbsolute("/dev") catch |err| return;

        var iterator = dir.iterate();
        while (iterator.next() catch |err| break) |entry| {
            const name = entry.name;
            if (std.mem.indexOf(u8, name, "cu.usbserial")) |_| {
                stdout.print("  {s}\n", .{name});
            }
        }
    } else if (builtin.os.tag == .linux) {
        const dir = std.fs.openDirAbsolute("/dev") catch |err| return;

        var iterator = dir.iterate();
        while (iterator.next() catch |err| break) |entry| {
            const name = entry.name;
            if (std.mem.indexOf(u8, name, "ttyUSB") |_| std.mem.indexOf(u8, name, "ttyACM")) |_| {
                stdout.print("  {s}\n", .{name});
            }
        }
    }
}
