// =============================================================================
// UART Measurement Tool — Hardware tok/s verification for HSLM FPGA
// =============================================================================
// Reads the 30-byte UART report frame from hslm_full_top and computes
// real hardware throughput.
//
// Frame format (30 bytes):
//   [0]  0xAA        sync
//   [1]  0xBB        sync
//   [2]  0xFE        frame type (autoregressive)
//   [3]  pass        self-test result (0 or 1)
//   [4]  seed        seed token (42)
//   [5]  gen_count   tokens generated
//   [6..21]          first 16 generated tokens
//   [22..25]         total_cycle_counter (MSB first)
//   [26..29]         first_token_cycles (MSB first)
//
// Usage: uart_measure [/dev/tty.usbserial-1120]
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

const std = @import("std");
const posix = std.posix;

const CLK_FREQ: u64 = 81_250_000; // 81.25 MHz MMCM output
const FRAME_LEN: usize = 30;
const EXPECTED_CYCLES_PER_TOKEN: u32 = 43_241; // from simulation
const DEVIATION_THRESHOLD: f64 = 0.05; // 5% tolerance

fn print(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

fn readU32(buf: []const u8, offset: usize) u32 {
    return @as(u32, buf[offset]) << 24 |
        @as(u32, buf[offset + 1]) << 16 |
        @as(u32, buf[offset + 2]) << 8 |
        @as(u32, buf[offset + 3]);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const args = try std.process.argsAlloc(arena.allocator());

    const port_path: [:0]const u8 = if (args.len > 1) args[1] else "/dev/tty.usbserial-1120";

    print("\n  FPGA Measurement Tool\n", .{});
    print("  =====================\n", .{});
    print("  Port: {s}\n", .{port_path});
    print("  Clock: {d} MHz\n", .{CLK_FREQ / 1_000_000});
    print("  Waiting for UART report frame...\n\n", .{});

    const fd = posix.open(port_path, .{ .ACCMODE = .RDWR, .NOCTTY = true, .NONBLOCK = true }, 0) catch |err| {
        print("  ERROR: cannot open {s}: {}\n", .{ port_path, err });
        print("  Check USB-UART adapter connection.\n", .{});
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
    tio.cc[@intFromEnum(posix.V.MIN)] = 1; // block until at least 1 byte
    tio.cc[@intFromEnum(posix.V.TIME)] = 100; // 10 sec timeout

    try posix.tcsetattr(fd, .NOW, tio);

    // Clear NONBLOCK
    const F_GETFL = 3;
    const F_SETFL = 4;
    const O_NONBLOCK: usize = 0x0004; // macOS
    const fl = try posix.fcntl(fd, F_GETFL, @as(usize, 0));
    _ = try posix.fcntl(fd, F_SETFL, fl & ~O_NONBLOCK);

    // Wait for FPGA to boot and send report
    std.Thread.sleep(200 * std.time.ns_per_ms);

    // Sync: scan for 0xAA 0xBB 0xFE
    var sync_state: u8 = 0;
    var single: [1]u8 = undefined;
    var attempts: u32 = 0;
    const max_attempts: u32 = 10_000;

    while (attempts < max_attempts) : (attempts += 1) {
        const n = posix.read(fd, &single) catch 0;
        if (n == 0) {
            print("  Timeout waiting for data. Is FPGA running?\n", .{});
            return;
        }
        const b = single[0];
        switch (sync_state) {
            0 => if (b == 0xAA) {
                sync_state = 1;
            },
            1 => if (b == 0xBB) {
                sync_state = 2;
            } else {
                sync_state = if (b == 0xAA) 1 else 0;
            },
            2 => if (b == 0xFE) {
                sync_state = 3; // found sync!
            } else {
                sync_state = if (b == 0xAA) 1 else 0;
            },
            else => break,
        }
        if (sync_state == 3) break;
    }

    if (sync_state != 3) {
        print("  ERROR: Could not find sync pattern (0xAA 0xBB 0xFE) in {d} bytes.\n", .{max_attempts});
        return;
    }

    // Read remaining frame bytes (FRAME_LEN - 3 sync bytes already consumed)
    var frame: [FRAME_LEN]u8 = undefined;
    frame[0] = 0xAA;
    frame[1] = 0xBB;
    frame[2] = 0xFE;
    var received: usize = 3;

    while (received < FRAME_LEN) {
        const n = posix.read(fd, frame[received..FRAME_LEN]) catch 0;
        if (n == 0) {
            print("  ERROR: Timeout after {d}/{d} bytes received.\n", .{ received, FRAME_LEN });
            return;
        }
        received += n;
    }

    // Parse frame
    const pass = frame[3];
    const seed = frame[4];
    const gen_count = frame[5];
    const total_cycles = readU32(&frame, 22);
    const first_tok_cycles = readU32(&frame, 26);

    // Compute throughput
    const tok_per_sec: u64 = if (total_cycles > 0)
        CLK_FREQ * @as(u64, gen_count) / @as(u64, total_cycles)
    else
        0;

    const avg_cycles_per_tok: u64 = if (gen_count > 0)
        @as(u64, total_cycles) / @as(u64, gen_count)
    else
        0;

    const us_per_tok: f64 = if (avg_cycles_per_tok > 0)
        @as(f64, @floatFromInt(avg_cycles_per_tok)) / (@as(f64, @floatFromInt(CLK_FREQ)) / 1_000_000.0)
    else
        0.0;

    // Print report
    print("  FPGA Measurement Report\n", .{});
    print("  =======================\n", .{});
    print("  Self-test:          {s}\n", .{if (pass == 1) "PASS" else "FAIL"});
    print("  Seed:               {d}\n", .{seed});
    print("  Tokens generated:   {d}\n", .{gen_count});

    print("  Token sequence:    ", .{});
    const tok_display: usize = @min(16, @as(usize, gen_count));
    for (0..tok_display) |i| {
        if (i > 0) print(" ", .{});
        print("{d}", .{frame[6 + i]});
    }
    if (gen_count > 16) print(" ... (+{d} more)", .{gen_count - 16});
    print("\n", .{});

    print("\n  === Timing ===\n", .{});
    print("  Clock:              {d}.{d:0>2} MHz\n", .{ CLK_FREQ / 1_000_000, (CLK_FREQ % 1_000_000) / 10_000 });
    print("  Total cycles:       {d}\n", .{total_cycles});
    print("  First token cycles: {d}\n", .{first_tok_cycles});
    print("  Avg cycles/token:   {d}\n", .{avg_cycles_per_tok});
    print("  Per-token latency:  {d:.1} us\n", .{us_per_tok});
    print("  Throughput:         {d} tok/s\n", .{tok_per_sec});

    // Compare with simulation
    print("\n  === Verification ===\n", .{});
    const expected_total = @as(u64, EXPECTED_CYCLES_PER_TOKEN) * @as(u64, gen_count);
    const deviation: f64 = if (expected_total > 0)
        @abs(@as(f64, @floatFromInt(total_cycles)) - @as(f64, @floatFromInt(expected_total))) / @as(f64, @floatFromInt(expected_total))
    else
        1.0;

    print("  Expected (sim):     {d} cycles/token\n", .{EXPECTED_CYCLES_PER_TOKEN});
    print("  Measured (hw):      {d} cycles/token\n", .{avg_cycles_per_tok});
    print("  Deviation:          {d:.2}%\n", .{deviation * 100.0});

    if (deviation <= DEVIATION_THRESHOLD) {
        print("  Result:             MATCH (within {d:.0}% tolerance)\n", .{DEVIATION_THRESHOLD * 100.0});
    } else {
        print("  Result:             MISMATCH (>{d:.0}% deviation — investigate)\n", .{DEVIATION_THRESHOLD * 100.0});
    }

    // Raw frame dump
    print("\n  === Raw Frame ({d} bytes) ===\n  ", .{FRAME_LEN});
    for (frame[0..FRAME_LEN]) |b| {
        print("{X:0>2} ", .{b});
    }
    print("\n", .{});

    print("\n  phi^2 + 1/phi^2 = 3 = TRINITY\n\n", .{});
}
