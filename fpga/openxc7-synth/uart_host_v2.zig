// VSA FPGA UART Host v2.0
// Week 5: Enhanced UART with loopback test + quantum mode control
//
// New features:
// - Loopback test (TX-RX short) for cable verification
// - Quantum mode commands
// - Timeout handling
// - Better error reporting

const std = @import("std");

// === COMMANDS (Day 2 Protocol) ===
const Command = enum(u8) {
    MODE = 0x01,              // Unified MODE: 0x01 XX where XX = LED mode
    PING = 0xFF,              // PING command
};

const Response = enum(u8) {
    OK = 0x00,                // OK response for MODE commands
    PONG = 0xAA,              // PONG response for PING
};

// LED Modes (Day 2: 4 modes with distinct patterns)
const LedMode = enum(u2) {
    SEPARABLE = 0b00,         // Clean periodic blink (~1.5 Hz)
    VIOLATION = 0b01,         // Chaotic/irregular (LFSR-driven)
    ZERO = 0b10,              // Slow/constant (~0.75 Hz)
    NEGATIVE = 0b11,          // Fast blink (~3 Hz)
};

// === CONFIG ===
const UART_DEVICE = "/dev/ttyUSB0";
const BAUD_RATE = 115200;
const TIMEOUT_MS = 5000; // 5 second timeout

pub fn main() !void {
    // Parse command line args (no allocator needed for Day 2)
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
        std.log.err("\nTIP: For loopback test, run: {s} loopback", .{args[0]});
        return err;
    };
    defer port.close();

    std.debug.print("╔════════════════════════════════════════╗\n", .{});
    std.debug.print("║     VSA FPGA UART Host v2.0           ║\n", .{});
    std.debug.print("╚════════════════════════════════════════╝\n", .{});
    std.debug.print("Device: {s}\n", .{UART_DEVICE});
    std.debug.print("Baud: {d}\n", .{BAUD_RATE});
    std.debug.print("════════════════════════════════════════\n\n", .{});

    // Route commands (Day 2: PING + MODE only)
    if (std.mem.eql(u8, command, "ping")) {
        try testPing(port);
    } else if (std.mem.eql(u8, command, "mode")) {
        // mode <type> where type = separable|violation|zero|negative
        const mode_str = if (args.len > 2) args[2] else "violation";
        try setLedMode(port, mode_str);
    } else if (std.mem.eql(u8, command, "led")) {
        // led <0-3> where 0=separable, 1=violation, 2=zero, 3=negative
        const led_mode: u2 = if (args.len > 2)
            @as(u2, @intCast(try std.fmt.parseInt(u8, args[2], 10)))
        else
            @intFromEnum(LedMode.VIOLATION);
        try setLedModeDirect(port, led_mode);
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
        \\Day 2 Commands:
        \\  loopback          - Test UART cable (short TX-RX, no FPGA needed)
        \\  ping              - Test FPGA connectivity (0xFF -> 0xAA PONG)
        \\  mode <type>       - Set LED mode: separable|violation|zero|negative
        \\  led <0-3>         - Direct LED: 0=separable, 1=violation, 2=zero, 3=negative
        \\
        \\LED Modes (Day 2):
        \\  0 / separable     - Clean periodic blink (~1.5 Hz)
        \\  1 / violation     - Chaotic/irregular (LFSR-driven)
        \\  2 / zero          - Slow/constant (~0.75 Hz)
        \\  3 / negative      - Fast blink (~3 Hz)
        \\
        \\Examples:
        \\  {s} loopback              # Verify cable
        \\  {s} ping                  # Test FPGA
        \\  {s} mode violation        # Set chaotic LED
        \\  {s} led 0                 # Separable mode
        \\  {s} led 3                 # Fast blink
        \\
    , .{prog, prog, prog, prog, prog, prog});
}

// === LOOPBACK TEST (no FPGA needed) ===
fn testLoopback() !void {
    std.debug.print("[LOOPBACK TEST]\n", .{});
    std.debug.print("════════════════════════════════════════\n", .{});
    std.debug.print("Requires: TX-RX shorted on USB-UART adapter\n\n", .{});

    const port = std.fs.openFileAbsolute(UART_DEVICE, .{
        .mode = .read_write,
    }) catch |err| {
        std.log.err("Failed to open {s}: {}", .{UART_DEVICE, err});
        std.log.err("\nConnect USB-UART adapter with TX-RX shorted!", .{});
        return err;
    };
    defer port.close();

    // Note: On macOS, configure with: stty -f /dev/ttyUSB0 115200 cs8 -cstopb -parenb
    // For this test, we assume the port is at default baud rate

    std.debug.print("Sending test packet...\n", .{});

    // Send magic bytes
    const test_packet = [_]u8{ 0xAA, 0x55, 0xFF, 0x00 };
    _ = try port.writeAll(&test_packet);

    std.debug.print("  Sent: 0xAA 0x55 0xFF 0x00\n", .{});

    // Try to read back
    var buffer: [16]u8 = undefined;
    const start_time = std.time.milliTimestamp();
    var n: usize = 0;

    // Read with timeout
    while (n < 4) {
        const elapsed = std.time.milliTimestamp() - start_time;
        if (elapsed > TIMEOUT_MS) {
            std.debug.print("\n  ❌ TIMEOUT: No data received\n", .{});
            std.debug.print("\nTroubleshooting:\n", .{});
            std.debug.print("  1. Check TX-RX are shorted\n", .{});
            std.debug.print("  2. Verify device: {s}\n", .{UART_DEVICE});
            std.debug.print("  3. Check permissions: ls -l {s}\n", .{UART_DEVICE});
            return error.Timeout;
        }

        const chunk = try port.read(buffer[n..]);
        if (chunk == 0) {
            std.posix.nanosleep(0, 10_000_000); // 10ms
            continue;
        }
        n += chunk;
    }

    std.debug.print("  Received: ", .{});
    for (buffer[0..4]) |b| {
        std.debug.print("0x{X:0>2} ", .{b});
    }
    std.debug.print("\n\n", .{});

    // Verify
    if (std.mem.eql(u8, buffer[0..4], &test_packet)) {
        std.debug.print("  ✅ LOOPBACK PASS: UART cable working!\n", .{});
    } else {
        std.debug.print("  ❌ LOOPBACK FAIL: Data mismatch\n", .{});
        return error.DataMismatch;
    }
}

// === UART OPEN ===
fn openUart() !std.fs.File {
    return std.fs.openFileAbsolute(UART_DEVICE, .{
        .mode = .read_write,
    });
}

// === PING TEST (Day 2: 0xFF -> 0xAA PONG) ===
fn testPing(port: std.fs.File) !void {
    std.debug.print("[TEST] PING\n", .{});

    // Day 2: Simple single-byte PING
    const ping_byte: u8 = @intFromEnum(Command.PING); // 0xFF
    _ = try port.writeAll(&[_]u8{ping_byte});
    std.debug.print("  Sent: PING (0xFF)\n", .{});

    // Wait for PONG response (0xAA)
    const start_time = std.time.milliTimestamp();
    var n: usize = 0;
    var response_byte: u8 = undefined;

    // Read with timeout
    while (n == 0) {
        const elapsed = std.time.milliTimestamp() - start_time;
        if (elapsed > TIMEOUT_MS) {
            std.debug.print("  ❌ FAIL: Timeout\n", .{});
            return error.Timeout;
        }
        var buf: [1]u8 = undefined;
        n = try port.read(&buf);
        if (n > 0) {
            response_byte = buf[0];
        } else {
            std.posix.nanosleep(0, 10_000_000); // 10ms
        }
    }

    const expected_pong: u8 = @intFromEnum(Response.PONG); // 0xAA
    if (response_byte == expected_pong) {
        std.debug.print("  Received: PONG (0x{X:0>2})\n", .{response_byte});
        std.debug.print("  ✅ PASS: FPGA communication OK\n", .{});
    } else {
        std.debug.print("  ❌ FAIL: Got 0x{X:0>2} (expected 0xAA)\n", .{response_byte});
        return error.UnexpectedResponse;
    }
}

// === MODE CONTROL (Day 2: Unified 0x01 XX command) ===

// Parse mode string to LedMode enum
fn parseLedMode(mode_str: []const u8) !LedMode {
    if (std.mem.eql(u8, mode_str, "separable")) return LedMode.SEPARABLE;
    if (std.mem.eql(u8, mode_str, "violation")) return LedMode.VIOLATION;
    if (std.mem.eql(u8, mode_str, "zero")) return LedMode.ZERO;
    if (std.mem.eql(u8, mode_str, "negative")) return LedMode.NEGATIVE;
    return error.UnknownMode;
}

// Get mode description string
fn modeDescription(mode: LedMode) []const u8 {
    return switch (mode) {
        LedMode.SEPARABLE => "SEPARABLE - Clean periodic blink (~1.5 Hz)",
        LedMode.VIOLATION => "VIOLATION - Chaotic/irregular (LFSR)",
        LedMode.ZERO => "ZERO - Slow/constant (~0.75 Hz)",
        LedMode.NEGATIVE => "NEGATIVE - Fast blink (~3 Hz)",
    };
}

// Set LED mode by name (mode <separable|violation|zero|negative>)
fn setLedMode(port: std.fs.File, mode_str: []const u8) !void {
    const mode = try parseLedMode(mode_str);
    try setLedModeDirect(port, @intFromEnum(mode));
}

// Set LED mode by direct value (led <0-3>)
fn setLedModeDirect(port: std.fs.File, led_mode: u2) !void {
    const mode: LedMode = @enumFromInt(led_mode);

    std.debug.print("[COMMAND] SET LED MODE\n", .{});
    std.debug.print("  Mode: {s}\n", .{modeDescription(mode)});

    // Day 2 protocol: Send MODE command (0x01) followed by parameter byte
    const cmd_packet = [_]u8{
        @intFromEnum(Command.MODE),  // 0x01
        @intFromEnum(mode),          // LED mode (0-3)
    };

    _ = try port.writeAll(&cmd_packet);
    std.debug.print("  Sent: 0x01 0x{X:0>2}\n", .{@intFromEnum(mode)});

    // Wait for OK response (0x00)
    const start_time = std.time.milliTimestamp();
    var n: usize = 0;
    var response_byte: u8 = undefined;

    while (n == 0) {
        const elapsed = std.time.milliTimestamp() - start_time;
        if (elapsed > TIMEOUT_MS) {
            std.debug.print("  ❌ FAIL: Timeout\n", .{});
            return error.Timeout;
        }
        var buf: [1]u8 = undefined;
        n = try port.read(&buf);
        if (n > 0) {
            response_byte = buf[0];
        } else {
            std.posix.nanosleep(0, 10_000_000); // 10ms
        }
    }

    const expected_ok: u8 = @intFromEnum(Response.OK); // 0x00
    if (response_byte == expected_ok) {
        std.debug.print("  Received: OK (0x00)\n", .{});
        std.debug.print("  ✅ LED mode set successfully\n", .{});
    } else {
        std.debug.print("  ❌ FAIL: Got 0x{X:0>2} (expected 0x00)\n", .{response_byte});
        return error.UnexpectedResponse;
    }
}


// φ² + 1/φ² = 3 = TRINITY

