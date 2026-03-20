//! JTAG Flasher — ESP32 XVC Bridge Client
//! Pure Zig TCP client for ESP32-based JTAG bridge (avoids libusb issues)

const std = @import("std");

const Config = struct {
    host: []const u8 = "esp32-xvc.local",
    port: u16 = 80,
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    if (args.len < 2) {
        std.debug.print(
            \\Usage: jtag_flasher_esp32 <bitstream.bit> [--host=HOST] [--phi]
            \\
            \\Flash bitstream to FPGA via ESP32 XVC Bridge.
            \\
            \\Options:
            \\  --host=HOST    ESP32 hostname (default: esp32-xvc.local)
            \\  --phi          Use phi-blink preset (~24 Hz)
            \\
        , .{});
        std.process.exit(1);
    }

    var config = Config{};
    const bitstream: []const u8 = args[1];
    var use_phi = false;

    // Parse args
    for (args[2..]) |arg| {
        if (std.mem.startsWith(u8, arg, "--host=")) {
            config.host = arg["--host=".len..];
        } else if (std.mem.eql(u8, arg, "--phi")) {
            use_phi = true;
        }
    }

    std.debug.print("═════════════════════════════════════\n", .{});
    std.debug.print(" JTAG FLASHER — ESP32 XVC Bridge\n", .{});
    std.debug.print(" Host: {s}:{d}\n", .{config.host, config.port});
    std.debug.print(" Bitstream: {s}\n", .{bitstream});
    if (use_phi) std.debug.print(" Mode: PHI-BLINK (~24 Hz)\n", .{});
    std.debug.print("═══════════════════════════════════════\n\n", .{});

    // 1. Check ESP32 status
    std.debug.print("[1/3] Checking ESP32 status...\n", .{});

    const address = try std.net.Address.parseIp4(config.host, config.port);
    var status_socket = try std.net.tcpConnectToAddress(address);
    defer status_socket.close();

    try status_socket.writeAll("STATUS\n");
    var status_buf: [512]u8 = undefined;
    const status_len = try status_socket.read(&status_buf);
    const status = status_buf[0..status_len];

    if (std.mem.indexOf(u8, status, "READY") == null) {
        std.debug.print("✗ ESP32 not ready: {s}\n", .{status});
        return error.Esp32NotReady;
    }
    std.debug.print("✓ ESP32: READY\n", .{});

    // 2. Connect and send flash command
    std.debug.print("[2/3] Sending flash command...\n", .{});

    var flash_socket = try std.net.tcpConnectToAddress(address);
    defer flash_socket.close();

    // Build command manually
    var cmd_buf: [512]u8 = undefined;
    const cmd = if (use_phi)
        try std.fmt.bufPrintZ(&cmd_buf, "FLASH PHI {s}\n", .{bitstream})
    else
        try std.fmt.bufPrintZ(&cmd_buf, "FLASH {s}\n", .{bitstream});

    try flash_socket.writeAll(cmd);
    std.debug.print("✓ Command sent\n", .{});

    // 3. Read response
    std.debug.print("[3/3] Waiting for completion...\n", .{});

    const response_len = try flash_socket.read(&status_buf);
    const response = status_buf[0..response_len];

    if (std.mem.indexOf(u8, response, "OK") != null) {
        std.debug.print("\n✅ FLASH COMPLETE\n", .{});
    } else if (std.mem.indexOf(u8, response, "BUSY") != null) {
        std.debug.print("\n⚠ FLASH BUSY (another operation)\n", .{});
    } else {
        std.debug.print("\n✗ FLASH FAILED: {s}\n", .{response});
        return error.FlashFailed;
    }

    std.debug.print("═══════════════════════════════════════\n", .{});
}
