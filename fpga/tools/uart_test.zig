const std = @import("std");
const posix = std.posix;

fn print(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const args = try std.process.argsAlloc(arena.allocator());

    const port_path: [:0]const u8 = if (args.len > 1) args[1] else "/dev/tty.usbserial-1120";

    print("=== TRINITY UART TEST ===\n", .{});
    print("Port: {s}\n", .{port_path});

    const fd = posix.open(port_path, .{ .ACCMODE = .RDWR, .NOCTTY = true, .NONBLOCK = true }, 0) catch |err| {
        print("ERROR: cannot open {s}: {}\n", .{ port_path, err });
        return;
    };
    defer posix.close(fd);

    // Configure 115200 8N1
    var tio = try posix.tcgetattr(fd);
    tio.iflag = .{};
    tio.oflag = .{};
    tio.cflag = .{ .CSIZE = .CS8, .CLOCAL = true, .CREAD = true };
    tio.lflag = .{};
    tio.ispeed = .B115200;
    tio.ospeed = .B115200;
    tio.cc[@intFromEnum(posix.V.MIN)] = 0;
    tio.cc[@intFromEnum(posix.V.TIME)] = 20; // 2 sec timeout

    try posix.tcsetattr(fd, .NOW, tio);
    // Clear NONBLOCK
    const F_GETFL = 3;
    const F_SETFL = 4;
    const O_NONBLOCK: usize = 0x0004; // macOS
    const fl = try posix.fcntl(fd, F_GETFL, @as(usize, 0));
    _ = try posix.fcntl(fd, F_SETFL, fl & ~O_NONBLOCK);

    std.Thread.sleep(100 * std.time.ns_per_ms);

    // Test 1: Send 0x55
    print("\n[1] TX: 0x55\n", .{});
    _ = try posix.write(fd, &[_]u8{0x55});
    std.Thread.sleep(300 * std.time.ns_per_ms);

    var buf: [16]u8 = undefined;
    const n1 = posix.read(fd, &buf) catch 0;
    if (n1 > 0) {
        print("    RX:", .{});
        for (buf[0..n1]) |b| print(" 0x{X:0>2}", .{b});
        print("\n", .{});
    } else {
        print("    RX: nothing\n", .{});
    }

    // Test 2: PING 0x03 → expect PONG 0x83
    print("[2] TX: 0x03 (PING)\n", .{});
    _ = try posix.write(fd, &[_]u8{0x03});
    std.Thread.sleep(300 * std.time.ns_per_ms);

    const n2 = posix.read(fd, &buf) catch 0;
    if (n2 > 0) {
        print("    RX:", .{});
        for (buf[0..n2]) |b| print(" 0x{X:0>2}", .{b});
        if (buf[0] == 0x83) print(" = PONG!", .{});
        if (buf[0] == 0x03) print(" = ECHO!", .{});
        print("\n", .{});
    } else {
        print("    RX: nothing\n", .{});
    }

    // Test 3: Send "Hi"
    print("[3] TX: \"Hi\"\n", .{});
    _ = try posix.write(fd, "Hi");
    std.Thread.sleep(300 * std.time.ns_per_ms);

    const n3 = posix.read(fd, &buf) catch 0;
    if (n3 > 0) {
        print("    RX: \"{s}\"\n", .{buf[0..n3]});
    } else {
        print("    RX: nothing\n", .{});
    }

    if (n1 == 0 and n2 == 0 and n3 == 0) {
        print("\nNO DATA received. Try:\n", .{});
        print("  1. Swap green/yellow wires\n", .{});
        print("  2. Check GND connection\n", .{});
        print("  3. Try other port: ./uart_test /dev/tty.usbserial-1140\n", .{});
    }

    print("\n=== phi^2 + 1/phi^2 = 3 = TRINITY ===\n", .{});
}
