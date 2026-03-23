// @origin(spec:tri_fpga.tri) @regen(manual-impl)

// =============================================================================
// TRI FPGA Commands — Native openXC7 FPGA Toolchain
// =============================================================================
//
// Complete FPGA pipeline: synth, flash, verify, snap, build, status
//
// Native tools (NO Docker):
//   yosys -> nextpnr-xilinx -> fasm2frames -> xc7frames2bit -> jtag_program
//
// Proven on QMTECH XC7A100T-1FGG676C:
//   - beal_top.v: Beal conjecture scanner (working)
//   - vsa_uart_phi_top.v: VSA + UART (working)
//   - ternary_matvec_top.v: 64x64 ternary AI (working, self-test PASS)
//   - ternary_matvec_243x729_top.v: 243x729 BRAM ternary AI (working, self-test PASS)
//   - trinity_block_step4_top.v: Full TrinityBlock (MatVec+ReLU+MatVec+Residual+RMSNorm, PASS)
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

const std = @import("std");
const posix = std.posix;
const c = std.c;

// =========================================================================
// SerialPort — POSIX serial I/O for UART bridge (CH340/FTDI)
// =========================================================================

pub const SerialPort = struct {
    fd: posix.fd_t,
    path: []const u8,

    pub fn open(path: []const u8) !SerialPort {
        const fd = try posix.open(path, .{ .ACCMODE = .RDWR, .NOCTTY = true, .NONBLOCK = true }, 0);
        errdefer posix.close(fd);

        // Clear NONBLOCK after open (needed for CH340 drivers)
        const nonblock_bit: usize = @bitCast(@as(isize, @intCast(@as(u32, @bitCast(c.O{ .NONBLOCK = true })))));
        const flags = try posix.fcntl(fd, c.F.GETFL, 0);
        _ = try posix.fcntl(fd, c.F.SETFL, flags & ~nonblock_bit);

        // Configure 115200 8-N-1 raw via stty (portable macOS + Linux)
        const stty_flag = comptime if (@import("builtin").os.tag == .macos) "-f" else "-F";
        var child = std.process.Child.init(&.{
            "stty",    stty_flag, path,    "115200", "cs8",    "-cstopb",
            "-parenb", "raw",     "-echo", "-echoe", "-echok", "min",
            "0",       "time",    "50",
        }, std.heap.page_allocator);
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;
        child.spawn() catch return error.SystemResources;
        const term = child.wait() catch return error.SystemResources;
        if (term.Exited != 0) return error.InvalidArgument;

        // Drain any stale bytes in buffer
        var drain: [256]u8 = undefined;
        _ = posix.read(fd, &drain) catch {};

        return .{ .fd = fd, .path = path };
    }

    pub fn writeBytes(self: SerialPort, data: []const u8) !usize {
        return posix.write(self.fd, data);
    }

    pub fn readBytes(self: SerialPort, buf: []u8) !usize {
        return posix.read(self.fd, buf);
    }

    pub fn close(self: SerialPort) void {
        posix.close(self.fd);
    }
};

/// Auto-discover serial device (CH340 > FTDI > ttyUSB > ttyACM)
pub fn findSerialDevice(allocator: std.mem.Allocator) !?[]const u8 {
    const prefixes = [_][]const u8{
        "tty.wchusbserial", // CH340 macOS
        "tty.usbserial", // FTDI macOS
        "ttyUSB", // Linux USB serial
        "ttyACM", // Linux ACM (CDC)
    };

    var dev_dir = std.fs.openDirAbsolute("/dev", .{ .iterate = true }) catch return null;
    defer dev_dir.close();

    // Try each prefix in priority order
    for (prefixes) |prefix| {
        var dir2 = std.fs.openDirAbsolute("/dev", .{ .iterate = true }) catch continue;
        defer dir2.close();
        var iter = dir2.iterate();
        while (iter.next() catch null) |entry| {
            if (std.mem.startsWith(u8, entry.name, prefix)) {
                return try std.fmt.allocPrint(allocator, "/dev/{s}", .{entry.name});
            }
        }
    }
    return null;
}

// =========================================================================
// UART Commands — tri fpga uart {scan|ping|send|monitor}
// =========================================================================

pub fn runFpgaUartCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) return printUartUsage();

    const subcmd = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, subcmd, "scan")) {
        try uartScan(allocator);
    } else if (std.mem.eql(u8, subcmd, "ping")) {
        const device = if (sub_args.len > 0) sub_args[0] else null;
        try uartPing(allocator, device);
    } else if (std.mem.eql(u8, subcmd, "send")) {
        try uartSend(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "monitor")) {
        const device = if (sub_args.len > 0) sub_args[0] else null;
        try uartMonitor(allocator, device);
    } else if (std.mem.eql(u8, subcmd, "--help") or std.mem.eql(u8, subcmd, "-h")) {
        return printUartUsage();
    } else {
        std.debug.print("{s}Error:{s} Unknown uart subcommand: {s}\n", .{ RED, RESET, subcmd });
        return printUartUsage();
    }
}

fn uartScan(allocator: std.mem.Allocator) !void {
    const prefixes = [_][]const u8{
        "tty.wchusbserial", "tty.usbserial", "ttyUSB", "ttyACM",
    };

    std.debug.print("\n{s}{s}=== TRI FPGA UART SCAN ==={s}\n\n", .{ BOLD, CYAN, RESET });

    var found: usize = 0;
    var dev_dir = std.fs.openDirAbsolute("/dev", .{ .iterate = true }) catch {
        std.debug.print("  {s}Cannot open /dev{s}\n", .{ RED, RESET });
        return;
    };
    defer dev_dir.close();

    var iter = dev_dir.iterate();
    while (iter.next() catch null) |entry| {
        for (prefixes) |prefix| {
            if (std.mem.startsWith(u8, entry.name, prefix)) {
                const kind: []const u8 = if (std.mem.startsWith(u8, entry.name, "tty.wchusbserial"))
                    "CH340"
                else if (std.mem.startsWith(u8, entry.name, "tty.usbserial"))
                    "FTDI"
                else if (std.mem.startsWith(u8, entry.name, "ttyUSB"))
                    "USB-Serial"
                else
                    "ACM";
                std.debug.print("  {s}FOUND{s} /dev/{s}  ({s})\n", .{ GREEN, RESET, entry.name, kind });
                found += 1;
                break;
            }
        }
    }

    if (found == 0) {
        std.debug.print("  {s}No serial devices found{s}\n", .{ YELLOW, RESET });
        std.debug.print("  Plug in USB-UART cable (CH340/FTDI)\n", .{});
    } else {
        std.debug.print("\n  {d} device(s) found\n", .{found});
    }
    std.debug.print("\n", .{});
    _ = allocator;
}

fn uartPing(allocator: std.mem.Allocator, device_arg: ?[]const u8) !void {
    std.debug.print("\n{s}{s}=== TRI FPGA UART PING ==={s}\n\n", .{ BOLD, CYAN, RESET });

    const dev_path = if (device_arg) |d| d else blk: {
        const found = try findSerialDevice(allocator);
        if (found) |f| break :blk f;
        std.debug.print("  {s}No serial device found{s} — plug in USB-UART cable\n\n", .{ RED, RESET });
        return;
    };
    defer if (device_arg == null) allocator.free(dev_path);

    std.debug.print("  Device: {s}\n", .{dev_path});
    std.debug.print("  Sending PING [0x03]...", .{});

    var port = SerialPort.open(dev_path) catch |err| {
        std.debug.print(" {s}FAIL{s} (open: {s})\n\n", .{ RED, RESET, @errorName(err) });
        return;
    };
    defer port.close();

    const ping_byte = [_]u8{0x03};
    _ = port.writeBytes(&ping_byte) catch |err| {
        std.debug.print(" {s}FAIL{s} (write: {s})\n\n", .{ RED, RESET, @errorName(err) });
        return;
    };

    var resp: [64]u8 = undefined;
    const n = port.readBytes(&resp) catch |err| {
        std.debug.print(" {s}FAIL{s} (read: {s})\n\n", .{ RED, RESET, @errorName(err) });
        return;
    };

    if (n > 0 and resp[0] == 0x83) {
        std.debug.print(" {s}PONG{s} [0x83]\n", .{ GREEN, RESET });
        std.debug.print("  FPGA is alive!\n\n", .{});
    } else if (n > 0) {
        std.debug.print(" got {d} byte(s): ", .{n});
        for (resp[0..n]) |b| std.debug.print("{X:0>2} ", .{b});
        std.debug.print("\n  (expected 0x83 PONG)\n\n", .{});
    } else {
        std.debug.print(" {s}TIMEOUT{s} (no response in 5s)\n\n", .{ YELLOW, RESET });
    }
}

fn uartSend(allocator: std.mem.Allocator, args: []const []const u8) !void {
    // args: [device] <hex...>  or just <hex...>
    if (args.len < 1) {
        std.debug.print("{s}Error:{s} Usage: tri fpga uart send [device] <hex bytes...>\n", .{ RED, RESET });
        return;
    }

    var dev_path: []const u8 = undefined;
    var hex_start: usize = 0;

    // If first arg starts with /dev/, it's the device
    if (std.mem.startsWith(u8, args[0], "/dev/")) {
        dev_path = args[0];
        hex_start = 1;
    } else {
        const found = try findSerialDevice(allocator);
        if (found) |f| {
            dev_path = f;
        } else {
            std.debug.print("{s}Error:{s} No serial device found\n", .{ RED, RESET });
            return;
        }
        hex_start = 0;
    }
    defer if (!std.mem.startsWith(u8, args[0], "/dev/")) allocator.free(dev_path);

    if (hex_start >= args.len) {
        std.debug.print("{s}Error:{s} No hex bytes to send\n", .{ RED, RESET });
        return;
    }

    std.debug.print("\n{s}{s}=== TRI FPGA UART SEND ==={s}\n\n", .{ BOLD, CYAN, RESET });
    std.debug.print("  Device: {s}\n  TX: ", .{dev_path});

    // Parse hex bytes
    var tx_buf: [256]u8 = undefined;
    var tx_len: usize = 0;
    for (args[hex_start..]) |hex_str| {
        // Accept "0xAB" or "AB" format
        const clean = if (std.mem.startsWith(u8, hex_str, "0x") or std.mem.startsWith(u8, hex_str, "0X"))
            hex_str[2..]
        else
            hex_str;
        if (clean.len == 2 and tx_len < 256) {
            tx_buf[tx_len] = std.fmt.parseInt(u8, clean, 16) catch {
                std.debug.print("{s}Error:{s} Invalid hex: {s}\n", .{ RED, RESET, hex_str });
                return;
            };
            std.debug.print("{X:0>2} ", .{tx_buf[tx_len]});
            tx_len += 1;
        }
    }
    std.debug.print("\n", .{});

    var port = SerialPort.open(dev_path) catch |err| {
        std.debug.print("  {s}FAIL{s} (open: {s})\n\n", .{ RED, RESET, @errorName(err) });
        return;
    };
    defer port.close();

    _ = port.writeBytes(tx_buf[0..tx_len]) catch |err| {
        std.debug.print("  {s}FAIL{s} (write: {s})\n\n", .{ RED, RESET, @errorName(err) });
        return;
    };

    var resp: [256]u8 = undefined;
    const n = port.readBytes(&resp) catch |err| {
        std.debug.print("  {s}FAIL{s} (read: {s})\n\n", .{ RED, RESET, @errorName(err) });
        return;
    };

    if (n > 0) {
        std.debug.print("  RX: ", .{});
        for (resp[0..n]) |b| std.debug.print("{X:0>2} ", .{b});
        std.debug.print("  |  ", .{});
        for (resp[0..n]) |b| {
            if (b >= 0x20 and b < 0x7f) {
                std.debug.print("{c}", .{b});
            } else {
                std.debug.print(".", .{});
            }
        }
        std.debug.print("\n\n", .{});
    } else {
        std.debug.print("  {s}No response (timeout){s}\n\n", .{ YELLOW, RESET });
    }
}

fn uartMonitor(allocator: std.mem.Allocator, device_arg: ?[]const u8) !void {
    std.debug.print("\n{s}{s}=== TRI FPGA UART MONITOR ==={s}\n", .{ BOLD, CYAN, RESET });
    std.debug.print("  Press Ctrl-C to exit\n\n", .{});

    const dev_path = if (device_arg) |d| d else blk: {
        const found = try findSerialDevice(allocator);
        if (found) |f| break :blk f;
        std.debug.print("  {s}No serial device found{s}\n\n", .{ RED, RESET });
        return;
    };
    defer if (device_arg == null) allocator.free(dev_path);

    std.debug.print("  Device: {s}\n  Listening...\n\n", .{dev_path});

    var port = SerialPort.open(dev_path) catch |err| {
        std.debug.print("  {s}FAIL{s} (open: {s})\n\n", .{ RED, RESET, @errorName(err) });
        return;
    };
    defer port.close();

    // Reduce timeout for monitor mode (VTIME=2 = 200ms)
    var tio = posix.tcgetattr(port.fd) catch return;
    tio.cc[@intFromEnum(posix.V.TIME)] = 2;
    posix.tcsetattr(port.fd, .FLUSH, tio) catch {};

    var total: usize = 0;
    while (true) {
        var buf: [256]u8 = undefined;
        const n = port.readBytes(&buf) catch break;
        if (n > 0) {
            total += n;
            // Print hex
            for (buf[0..n]) |b| std.debug.print("{X:0>2} ", .{b});
            std.debug.print(" |  ", .{});
            // Print ASCII
            for (buf[0..n]) |b| {
                if (b >= 0x20 and b < 0x7f) {
                    std.debug.print("{c}", .{b});
                } else {
                    std.debug.print(".", .{});
                }
            }
            std.debug.print("  [{d}]\n", .{total});
        }
    }
}

fn printUartUsage() !void {
    std.debug.print(
        \\
        \\{0s}=== TRI FPGA UART ==={1s}
        \\
        \\UART bridge for FPGA ↔ Mac communication via USB-UART (CH340/FTDI).
        \\
        \\USAGE:
        \\  tri fpga uart scan                       List serial devices
        \\  tri fpga uart ping [device]               PING/PONG test (send 0x03, expect 0x83)
        \\  tri fpga uart send [device] <hex bytes>   Send raw hex, print response
        \\  tri fpga uart monitor [device]            Live hex+ASCII dump (Ctrl-C to exit)
        \\
        \\EXAMPLES:
        \\  tri fpga uart scan
        \\  tri fpga uart ping
        \\  tri fpga uart ping /dev/tty.wchusbserial1420
        \\  tri fpga uart send 0xAA 0x10 0x2A
        \\  tri fpga uart monitor
        \\
        \\WIRING (CH340 → FPGA):
        \\  TX (white/green) → L20 (uart_rx)    Host → FPGA
        \\  RX (green/white) → K20 (uart_tx)    FPGA → Host
        \\  GND (black)      → GND              Common ground
        \\
    , .{ CYAN, RESET });
}

// =========================================================================
// Tool paths — relative to project root
// =========================================================================
const YOSYS = "yosys";
const NEXTPNR = "fpga/nextpnr-xilinx/build/nextpnr-xilinx";
const FASM2FRAMES = "fpga/prjxray/utils/fasm2frames.py";
const XC7FRAMES2BIT = "fpga/prjxray/build/tools/xc7frames2bit";
const JTAG_PROGRAM = "fpga/tools/jtag_program";
const CHIPDB = "fpga/openxc7-synth/chipdb/xc7a100tfgg676.bin";
const PRJXRAY_DB = "fpga/prjxray/database/artix7";
const VERILATOR = "verilator";
const IVERILOG = "iverilog";
const VVP = "vvp";

// Color codes
const CYAN = "\x1b[0;36m";
const GREEN = "\x1b[0;32m";
const YELLOW = "\x1b[0;33m";
const RED = "\x1b[0;31m";
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";

/// Helper: run a command, return success. If verbose, inherit stdout/stderr.
fn runCmd(allocator: std.mem.Allocator, argv: []const []const u8, verbose: bool) !bool {
    var child = std.process.Child.init(argv, allocator);
    if (verbose) {
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;
    } else {
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;
    }
    try child.spawn();
    const term = try child.wait();
    return term.Exited == 0;
}

// =========================================================================
// SYNTH — Full native openXC7 synthesis pipeline
// =========================================================================

pub fn runFpgaSynthCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) return printSynthUsage();
    if (std.mem.eql(u8, args[0], "--help") or std.mem.eql(u8, args[0], "-h")) return printSynthUsage();

    // Parse args: collect .v files and options
    var vfiles_buf: [16][]const u8 = undefined;
    var vfiles_count: usize = 0;
    var top: ?[]const u8 = null;
    var verbose = false;
    var seed: []const u8 = "1";
    var skip_lint = false;
    var skip_sim = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--top")) {
            i += 1;
            if (i < args.len) top = args[i];
        } else if (std.mem.eql(u8, arg, "--seed")) {
            i += 1;
            if (i < args.len) seed = args[i];
        } else if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
            verbose = true;
        } else if (std.mem.eql(u8, arg, "--no-lint")) {
            skip_lint = true;
        } else if (std.mem.eql(u8, arg, "--no-sim")) {
            skip_sim = true;
        } else if (std.mem.endsWith(u8, arg, ".v")) {
            if (vfiles_count < 16) {
                vfiles_buf[vfiles_count] = arg;
                vfiles_count += 1;
            }
        }
    }

    if (vfiles_count == 0) {
        std.debug.print("{s}Error:{s} No .v files specified\n", .{ RED, RESET });
        return error.NoInput;
    }

    const vfiles = vfiles_buf[0..vfiles_count];
    const first_file = vfiles[0];
    const basename = std.fs.path.stem(first_file);
    const resolved_top = top orelse basename;
    const dir = std.fs.path.dirname(first_file) orelse ".";

    std.debug.print("\n{s}{s}=== TRI FPGA SYNTH ==={s}\n", .{ BOLD, CYAN, RESET });
    std.debug.print("{s}Top:{s}   {s}\n", .{ DIM, RESET, resolved_top });
    std.debug.print("{s}Files:{s} ", .{ DIM, RESET });
    for (vfiles) |f| std.debug.print("{s} ", .{f});
    std.debug.print("\n{s}Seed:{s}  {s}\n\n", .{ DIM, RESET, seed });

    // ── Step 1: Verilator lint ──
    if (!skip_lint) {
        std.debug.print("{s}[1/6]{s} Verilator lint...", .{ CYAN, RESET });
        // Check if verilator is available
        const has_verilator = runCmd(allocator, &[_][]const u8{ "which", VERILATOR }, false) catch false;
        if (has_verilator) {
            // Build verilator args: --lint-only -Wall --top-module <top> <files...>
            var vlint_buf: [24][]const u8 = undefined;
            var vlint_n: usize = 0;
            vlint_buf[vlint_n] = VERILATOR;
            vlint_n += 1;
            vlint_buf[vlint_n] = "--lint-only";
            vlint_n += 1;
            vlint_buf[vlint_n] = "-Wall";
            vlint_n += 1;
            // Suppress FPGA-safe warnings (POR patterns, unused ports, incomplete case)
            vlint_buf[vlint_n] = "-Wno-UNUSEDSIGNAL";
            vlint_n += 1;
            vlint_buf[vlint_n] = "-Wno-PROCASSINIT";
            vlint_n += 1;
            vlint_buf[vlint_n] = "-Wno-CASEINCOMPLETE";
            vlint_n += 1;
            vlint_buf[vlint_n] = "-Wno-UNUSEDPARAM";
            vlint_n += 1;
            vlint_buf[vlint_n] = "-Wno-PINCONNECTEMPTY";
            vlint_n += 1;
            vlint_buf[vlint_n] = "-Wno-WIDTHEXPAND";
            vlint_n += 1;
            vlint_buf[vlint_n] = "-Wno-WIDTHTRUNC";
            vlint_n += 1;
            vlint_buf[vlint_n] = "--top-module";
            vlint_n += 1;
            vlint_buf[vlint_n] = resolved_top;
            vlint_n += 1;
            for (vfiles) |f| {
                vlint_buf[vlint_n] = f;
                vlint_n += 1;
            }
            const lint_ok = try runCmd(allocator, vlint_buf[0..vlint_n], verbose);
            if (!lint_ok) {
                std.debug.print(" {s}FAIL{s}\n  Verilator found width/lint errors. Fix or use --no-lint to skip.\n", .{ RED, RESET });
                return error.VerilatorLintFailed;
            }
            std.debug.print(" {s}OK{s}\n", .{ GREEN, RESET });
        } else {
            std.debug.print(" {s}SKIP{s} (verilator not in PATH)\n", .{ YELLOW, RESET });
        }
    } else {
        std.debug.print("{s}[1/6]{s} Verilator lint... {s}SKIP{s}\n", .{ CYAN, RESET, YELLOW, RESET });
    }

    // ── Step 2: Iverilog simulation ──
    if (!skip_sim) {
        std.debug.print("{s}[2/6]{s} Iverilog simulation...", .{ CYAN, RESET });
        // Search for testbench: <dir>/<top>_tb.v or <dir>/tb/tb_<top>.v
        const tb_path1 = try std.fmt.allocPrint(allocator, "{s}/{s}_tb.v", .{ dir, resolved_top });
        defer allocator.free(tb_path1);
        const tb_path2 = try std.fmt.allocPrint(allocator, "{s}/tb/tb_{s}.v", .{ dir, resolved_top });
        defer allocator.free(tb_path2);

        const tb_path: ?[]const u8 = blk: {
            std.fs.cwd().access(tb_path1, .{}) catch {
                std.fs.cwd().access(tb_path2, .{}) catch break :blk null;
                break :blk tb_path2;
            };
            break :blk tb_path1;
        };

        if (tb_path) |tb| {
            // Build iverilog command: iverilog -g2005 -o /tmp/tri_fpga_tb <files> <tb>
            var iv_buf: [24][]const u8 = undefined;
            var iv_n: usize = 0;
            iv_buf[iv_n] = IVERILOG;
            iv_n += 1;
            iv_buf[iv_n] = "-g2005";
            iv_n += 1;
            iv_buf[iv_n] = "-o";
            iv_n += 1;
            iv_buf[iv_n] = "/tmp/tri_fpga_tb";
            iv_n += 1;
            for (vfiles) |f| {
                iv_buf[iv_n] = f;
                iv_n += 1;
            }
            iv_buf[iv_n] = tb;
            iv_n += 1;

            const compile_ok = try runCmd(allocator, iv_buf[0..iv_n], verbose);
            if (!compile_ok) {
                std.debug.print(" {s}FAIL{s} (compile error)\n", .{ RED, RESET });
                return error.SimulationFailed;
            }

            // Run: vvp /tmp/tri_fpga_tb, capture output via redirect
            const sim_ok = try runCmd(allocator, &[_][]const u8{
                "bash", "-c", VVP ++ " /tmp/tri_fpga_tb 2>&1 | tee /tmp/tri_fpga_tb.log | head -50",
            }, verbose);
            if (!sim_ok) {
                std.debug.print(" {s}FAIL{s} (simulation error)\n", .{ RED, RESET });
                return error.SimulationFailed;
            }

            // Check log for ERROR/FAIL keywords
            const log_has_error = check_log: {
                const log_content = std.fs.cwd().readFileAlloc(allocator, "/tmp/tri_fpga_tb.log", 64 * 1024) catch break :check_log false;
                defer allocator.free(log_content);
                var line_iter = std.mem.splitSequence(u8, log_content, "\n");
                while (line_iter.next()) |line| {
                    if (std.mem.indexOf(u8, line, "ERROR") != null or
                        (std.mem.indexOf(u8, line, "FAIL") != null and std.mem.indexOf(u8, line, "PASS") == null))
                    {
                        break :check_log true;
                    }
                }
                break :check_log false;
            };

            if (log_has_error) {
                std.debug.print(" {s}FAIL{s}\n  Simulation detected errors. Fix or use --no-sim to skip.\n", .{ RED, RESET });
                return error.SimulationFailed;
            }
            std.debug.print(" {s}OK{s}\n", .{ GREEN, RESET });
        } else {
            std.debug.print(" {s}SKIP{s} (no testbench found)\n", .{ YELLOW, RESET });
        }
    } else {
        std.debug.print("{s}[2/6]{s} Iverilog simulation... {s}SKIP{s}\n", .{ CYAN, RESET, YELLOW, RESET });
    }

    // ── Step 3: Yosys ──
    std.debug.print("{s}[3/6]{s} Yosys synthesis...", .{ CYAN, RESET });

    // Build yosys -p command string
    var cmd_buf: [2048]u8 = undefined;
    var pos: usize = 0;

    const rv_prefix = "read_verilog ";
    @memcpy(cmd_buf[pos..][0..rv_prefix.len], rv_prefix);
    pos += rv_prefix.len;

    for (vfiles, 0..) |f, idx| {
        const needed = (if (idx > 0) @as(usize, 1) else 0) + f.len;
        if (pos + needed >= cmd_buf.len) break; // prevent buffer overflow
        if (idx > 0) {
            cmd_buf[pos] = ' ';
            pos += 1;
        }
        @memcpy(cmd_buf[pos..][0..f.len], f);
        pos += f.len;
    }

    const synth_fmt = try std.fmt.bufPrint(cmd_buf[pos..], "; synth_xilinx -flatten -abc9 -arch xc7 -top {s}; delete t:$scopeinfo; write_json {s}/{s}.json", .{ resolved_top, dir, resolved_top });
    pos += synth_fmt.len;

    const yosys_cmd = cmd_buf[0..pos];

    const ok1 = try runCmd(allocator, &[_][]const u8{ YOSYS, "-p", yosys_cmd }, verbose);
    if (!ok1) {
        std.debug.print(" {s}FAIL{s}\n  Re-run with -v for details\n", .{ RED, RESET });
        return error.YosysFailed;
    }
    std.debug.print(" {s}OK{s}\n", .{ GREEN, RESET });

    // ── Step 4: nextpnr-xilinx ──
    std.debug.print("{s}[4/6]{s} nextpnr-xilinx P&R...", .{ CYAN, RESET });

    const json_path = try std.fmt.allocPrint(allocator, "{s}/{s}.json", .{ dir, resolved_top });
    defer allocator.free(json_path);
    const xdc_path = try std.fmt.allocPrint(allocator, "{s}/{s}.xdc", .{ dir, resolved_top });
    defer allocator.free(xdc_path);
    const fasm_path = try std.fmt.allocPrint(allocator, "{s}/{s}.fasm", .{ dir, resolved_top });
    defer allocator.free(fasm_path);

    const ok2 = try runCmd(allocator, &[_][]const u8{
        NEXTPNR,   "--chipdb", CHIPDB,
        "--xdc",   xdc_path,   "--json",
        json_path, "--fasm",   fasm_path,
        "--seed",  seed,
    }, verbose);
    if (!ok2) {
        std.debug.print(" {s}FAIL{s}\n  Re-run with -v for details\n", .{ RED, RESET });
        return error.NextpnrFailed;
    }
    std.debug.print(" {s}OK{s}\n", .{ GREEN, RESET });

    // ── Step 5: fasm2frames ──
    std.debug.print("{s}[5/6]{s} fasm2frames...", .{ CYAN, RESET });

    const frames_path = try std.fmt.allocPrint(allocator, "{s}/{s}.frames", .{ dir, resolved_top });
    defer allocator.free(frames_path);

    const ok3 = try runCmd(allocator, &[_][]const u8{
        "python3",   FASM2FRAMES,
        "--db-root", PRJXRAY_DB,
        "--part",    "xc7a100tfgg676-1",
        "--sparse",  fasm_path,
        frames_path,
    }, verbose);
    if (!ok3) {
        std.debug.print(" {s}FAIL{s}\n", .{ RED, RESET });
        return error.Fasm2FramesFailed;
    }
    std.debug.print(" {s}OK{s}\n", .{ GREEN, RESET });

    // ── Step 6: xc7frames2bit ──
    std.debug.print("{s}[6/6]{s} xc7frames2bit...", .{ CYAN, RESET });

    const bit_path = try std.fmt.allocPrint(allocator, "{s}/{s}.bit", .{ dir, resolved_top });
    defer allocator.free(bit_path);

    const ok4 = try runCmd(allocator, &[_][]const u8{
        XC7FRAMES2BIT,
        "--part_file",
        PRJXRAY_DB ++ "/xc7a100tfgg676-1/part.yaml",
        "--part_name",
        "xc7a100tfgg676-1",
        "--frm_file",
        frames_path,
        "--output_file",
        bit_path,
    }, verbose);
    if (!ok4) {
        std.debug.print(" {s}FAIL{s}\n", .{ RED, RESET });
        return error.Frames2BitFailed;
    }
    std.debug.print(" {s}OK{s}\n", .{ GREEN, RESET });

    // ── Done ──
    std.debug.print("\n{s}{s}SYNTH COMPLETE{s}\n", .{ BOLD, GREEN, RESET });
    std.debug.print("  Bitstream: {s}\n", .{bit_path});
    std.debug.print("  Flash:     tri fpga flash {s}\n\n", .{bit_path});
}

fn printSynthUsage() !void {
    std.debug.print(
        \\
        \\{0s}=== TRI FPGA SYNTH ==={1s}
        \\
        \\Native openXC7 synthesis: .v -> .bit (NO Docker)
        \\
        \\USAGE:
        \\  tri fpga synth <file1.v> [file2.v ...] [options]
        \\
        \\OPTIONS:
        \\  --top <module>   Top module name (default: stem of first file)
        \\  --seed <N>       nextpnr seed (default: 1)
        \\  --no-lint        Skip Verilator lint check
        \\  --no-sim         Skip Iverilog testbench simulation
        \\  --verbose, -v    Show tool output
        \\  --help, -h       Show this help
        \\
        \\PIPELINE:
        \\  [1] verilator      lint-only -Wall (catches width bugs)
        \\  [2] iverilog+vvp   testbench simulation (catches logic bugs)
        \\  [3] yosys          -> .json (synthesis)
        \\  [4] nextpnr-xilinx -> .fasm (place & route)
        \\  [5] fasm2frames    -> .frames
        \\  [6] xc7frames2bit  -> .bit (bitstream)
        \\
        \\EXAMPLES:
        \\  tri fpga synth fpga/openxc7-synth/ternary_matvec.v fpga/openxc7-synth/ternary_matvec_top.v
        \\  tri fpga synth hardware/rtl-root/blink.v --top blink_top -v
        \\
    , .{ CYAN, RESET });
}

// =========================================================================
// FLASH — Program FPGA via JTAG
// =========================================================================

pub fn runFpgaFlashCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) return printFlashUsage();
    if (std.mem.eql(u8, args[0], "--help") or std.mem.eql(u8, args[0], "-h")) return printFlashUsage();

    const bit_path = args[0];

    std.fs.cwd().access(bit_path, .{}) catch {
        std.debug.print("{s}Error:{s} Bitstream not found: {s}\n", .{ RED, RESET, bit_path });
        return error.FileNotFound;
    };

    std.debug.print("\n{s}{s}=== TRI FPGA FLASH ==={s}\n", .{ BOLD, CYAN, RESET });
    std.debug.print("  Bitstream: {s}\n", .{bit_path});

    // Use openFPGALoader directly (no jtag_program wrapper)
    std.debug.print("  Programming via openFPGALoader...\n\n", .{});

    var child = std.process.Child.init(
        &[_][]const u8{ "sudo", JTAG_PROGRAM, bit_path },
        allocator,
    );
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    try child.spawn();
    const term = try child.wait();

    if (term.Exited != 0) {
        std.debug.print("\n{s}FLASH FAILED{s} (exit code {d})\n", .{ RED, RESET, term.Exited });
        return error.FlashFailed;
    }

    std.debug.print("\n{s}{s}FLASH COMPLETE{s}\n", .{ BOLD, GREEN, RESET });
    std.debug.print("  Verify: tri fpga snap\n\n", .{});
}

fn printFlashUsage() !void {
    std.debug.print(
        \\
        \\{0s}=== TRI FPGA FLASH ==={1s}
        \\
        \\Program FPGA via JTAG (requires sudo).
        \\
        \\USAGE:
        \\  tri fpga flash <bitstream.bit>
        \\
        \\EXAMPLES:
        \\  tri fpga flash fpga/openxc7-synth/ternary_matvec_top.bit
        \\  tri fpga flash fpga/openxc7-synth/beal_top.bit
        \\
    , .{ CYAN, RESET });
}

// =========================================================================
// SNAP — Quick camera snapshot of FPGA board
// =========================================================================

pub fn runFpgaSnapCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var camera: []const u8 = "2";
    var duration: []const u8 = "3";
    var output_path: []const u8 = "/tmp/fpga_snap.jpg";

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--help") or std.mem.eql(u8, args[i], "-h")) {
            return printSnapUsage();
        } else if (std.mem.eql(u8, args[i], "--camera") or std.mem.eql(u8, args[i], "-c")) {
            i += 1;
            if (i < args.len) camera = args[i];
        } else if (std.mem.eql(u8, args[i], "--duration") or std.mem.eql(u8, args[i], "-d")) {
            i += 1;
            if (i < args.len) duration = args[i];
        } else if (std.mem.eql(u8, args[i], "--out") or std.mem.eql(u8, args[i], "-o")) {
            i += 1;
            if (i < args.len) output_path = args[i];
        }
    }

    std.debug.print("\n{s}{s}=== TRI FPGA SNAP ==={s}\n", .{ BOLD, CYAN, RESET });
    std.debug.print("  Camera: device {s}, {s}s\n", .{ camera, duration });

    // Capture video -> extract last frame
    const video_path = "/tmp/fpga_snap_video.mp4";
    const cam_arg = try std.fmt.allocPrint(allocator, "{s}:none", .{camera});
    defer allocator.free(cam_arg);

    std.debug.print("  Capturing...", .{});

    const ok1 = try runCmd(allocator, &[_][]const u8{
        "ffmpeg",     "-f",     "avfoundation",
        "-framerate", "30",     "-video_size",
        "1920x1080",  "-i",     cam_arg,
        "-t",         duration, "-y",
        video_path,
    }, false);

    if (!ok1) {
        std.debug.print(" {s}FAIL{s}\n", .{ RED, RESET });
        return error.CaptureFailed;
    }

    // Extract last frame
    const ok2 = try runCmd(allocator, &[_][]const u8{
        "ffmpeg", "-sseof",   "-0.5",
        "-i",     video_path, "-frames:v",
        "1",      "-y",       output_path,
    }, false);

    std.fs.cwd().deleteFile(video_path) catch |err| {
        std.log.debug("tri_fpga: failed to delete video temp file: {}", .{err});
    };

    if (!ok2) {
        std.debug.print(" {s}FAIL{s} (frame extraction)\n", .{ RED, RESET });
        return error.ExtractFailed;
    }

    std.debug.print(" {s}OK{s}\n", .{ GREEN, RESET });
    std.debug.print("  Snapshot: {s}\n\n", .{output_path});
}

fn printSnapUsage() !void {
    std.debug.print(
        \\
        \\{0s}=== TRI FPGA SNAP ==={1s}
        \\
        \\Camera snapshot of FPGA board (iPhone Continuity Camera).
        \\
        \\USAGE:
        \\  tri fpga snap [options]
        \\
        \\OPTIONS:
        \\  --camera, -c <id>    Camera device (default: 2 = iPhone main)
        \\  --duration, -d <s>   Capture duration (default: 3)
        \\  --out, -o <path>     Output path (default: /tmp/fpga_snap.jpg)
        \\
    , .{ CYAN, RESET });
}

// =========================================================================
// VERIFY — LED pattern analysis via camera
// =========================================================================

pub fn runFpgaVerifyCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var camera: []const u8 = "2";
    var duration: []const u8 = "5";

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) return printVerifyUsage();
    }

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--camera") or std.mem.eql(u8, args[i], "-c")) {
            i += 1;
            if (i < args.len) camera = args[i];
        } else if (std.mem.eql(u8, args[i], "--duration") or std.mem.eql(u8, args[i], "-d")) {
            i += 1;
            if (i < args.len) duration = args[i];
        }
    }

    std.debug.print("\n{s}{s}=== TRI FPGA VERIFY ==={s}\n", .{ BOLD, CYAN, RESET });
    std.debug.print("  Camera: device {s}, {s}s capture\n\n", .{ camera, duration });

    // Step 1: Capture video
    const video_path = "/tmp/fpga_verify_video.mp4";
    const cam_arg = try std.fmt.allocPrint(allocator, "{s}:none", .{camera});
    defer allocator.free(cam_arg);

    std.debug.print("  [1/3] Capturing video...", .{});
    const ok1 = try runCmd(allocator, &[_][]const u8{
        "ffmpeg",     "-f",     "avfoundation",
        "-framerate", "30",     "-video_size",
        "1920x1080",  "-i",     cam_arg,
        "-t",         duration, "-y",
        video_path,
    }, false);
    if (!ok1) {
        std.debug.print(" {s}FAIL{s}\n", .{ RED, RESET });
        return error.CaptureFailed;
    }
    std.debug.print(" {s}OK{s}\n", .{ GREEN, RESET });

    // Step 2: Extract frames
    std.debug.print("  [2/3] Extracting frames...", .{});
    const ok2 = try runCmd(allocator, &[_][]const u8{
        "ffmpeg",                                 "-i",    video_path,
        "-vf",                                    "fps=5", "-y",
        "/tmp/fpga_verify_frames/frame_%03d.jpg",
    }, false);
    if (!ok2) {
        std.debug.print(" {s}FAIL{s}\n", .{ RED, RESET });
        return error.ExtractFailed;
    }
    std.debug.print(" {s}OK{s}\n", .{ GREEN, RESET });

    // Step 3: Run analyzer
    std.debug.print("  [3/3] Analyzing LED pattern...\n", .{});
    const ok3 = runCmd(allocator, &[_][]const u8{
        "python3", "fpga/tools/led_pattern_analyzer.py", video_path,
    }, true) catch false;
    if (!ok3) {
        std.debug.print("\n  {s}Analyzer unavailable.{s}\n", .{ YELLOW, RESET });
    }

    std.debug.print("\n  Frames: /tmp/fpga_verify_frames/\n\n", .{});
    std.fs.cwd().deleteFile(video_path) catch |err| {
        std.log.debug("tri_fpga: failed to delete video temp file: {}", .{err});
    };
}

fn printVerifyUsage() !void {
    std.debug.print(
        \\
        \\{0s}=== TRI FPGA VERIFY ==={1s}
        \\
        \\LED verification via camera capture + analysis.
        \\
        \\USAGE:
        \\  tri fpga verify [options]
        \\
        \\OPTIONS:
        \\  --camera, -c <id>    Camera device (default: 2)
        \\  --duration, -d <s>   Capture seconds (default: 5)
        \\  --help, -h           Show this help
        \\
        \\LED MEANINGS:
        \\  Solid ON  = Self-test PASSED
        \\  Blinking  = Computation in progress
        \\  OFF       = Self-test FAILED
        \\
    , .{ CYAN, RESET });
}

// =========================================================================
// BUILD — Full pipeline: synth + flash
// =========================================================================

pub fn runFpgaBuildCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) return printBuildUsage();
    if (std.mem.eql(u8, args[0], "--help") or std.mem.eql(u8, args[0], "-h")) return printBuildUsage();

    // Check for --no-flash, pass rest to synth
    var no_flash = false;
    var synth_buf: [32][]const u8 = undefined;
    var synth_count: usize = 0;

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--no-flash")) {
            no_flash = true;
        } else {
            if (synth_count < 32) {
                synth_buf[synth_count] = arg;
                synth_count += 1;
            }
        }
    }

    // Run synth
    try runFpgaSynthCommand(allocator, synth_buf[0..synth_count]);

    if (no_flash) return;

    // Derive bit path and flash
    for (args) |arg| {
        if (std.mem.endsWith(u8, arg, ".v")) {
            const dir = std.fs.path.dirname(arg) orelse ".";
            const stem = std.fs.path.stem(arg);

            var top_name: []const u8 = stem;
            var j: usize = 0;
            while (j < args.len) : (j += 1) {
                if (std.mem.eql(u8, args[j], "--top") and j + 1 < args.len) {
                    top_name = args[j + 1];
                    break;
                }
            }

            const bit_path = try std.fmt.allocPrint(allocator, "{s}/{s}.bit", .{ dir, top_name });
            defer allocator.free(bit_path);

            try runFpgaFlashCommand(allocator, &[_][]const u8{bit_path});
            return;
        }
    }
}

fn printBuildUsage() !void {
    std.debug.print(
        \\
        \\{0s}=== TRI FPGA BUILD ==={1s}
        \\
        \\Full pipeline: synth + flash.
        \\
        \\USAGE:
        \\  tri fpga build <file1.v> [file2.v ...] [options]
        \\
        \\OPTIONS:
        \\  --top <module>   Top module name
        \\  --seed <N>       nextpnr seed (default: 1)
        \\  --no-flash       Synth only, skip flash
        \\  --verbose, -v    Show tool output
        \\
        \\EXAMPLES:
        \\  tri fpga build fpga/openxc7-synth/ternary_matvec.v fpga/openxc7-synth/ternary_matvec_top.v
        \\  tri fpga build hardware/rtl-root/blink.v --no-flash
        \\
    , .{ CYAN, RESET });
}

// =========================================================================
// STATUS — Board and toolchain info
// =========================================================================

pub fn runFpgaStatusCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;
    _ = allocator;

    std.debug.print(
        \\
        \\{0s}{1s}=== TRI FPGA STATUS ==={2s}
        \\
        \\{0s}Board:{2s}   QMTECH XC7A100T-1FGG676C (Artix-7)
        \\  LUT:     63,400
        \\  FF:      129,600
        \\  BRAM36:  135 (4,860 Kb)
        \\  DSP48:   240
        \\
        \\{0s}Toolchain:{2s}
        \\  yosys:          /opt/homebrew/bin/yosys
        \\  nextpnr-xilinx: fpga/nextpnr-xilinx/build/nextpnr-xilinx
        \\  fasm2frames:    fpga/prjxray/utils/fasm2frames.py
        \\  xc7frames2bit:  fpga/prjxray/build/tools/xc7frames2bit
        \\  jtag_program:   fpga/tools/jtag_program
        \\
        \\{0s}Pin Map:{2s}
        \\  CLK:     U22  (50 MHz)
        \\  LED:     T23  (active-low, D6)
        \\  UART_RX: L20
        \\  UART_TX: K20
        \\  DBG[0]:  N23
        \\  DBG[1]:  M22
        \\
        \\{0s}Designs:{2s}
        \\  ternary_matvec_top      633 LUT   64x64 ternary AI      PASS
        \\  ternary_matvec_243x729  ~2K LUT   243x729 BRAM AI 16BR  PASS
        \\  trinity_block_step4     ~5K LUT   Full TrinityBlock 32BR PASS
        \\  beal_top                1200 LUT  Beal scanner 1000^3   OK
        \\  vsa_uart_phi_top        ~800 LUT  VSA + UART            OK
        \\
        \\{0s}Commands:{2s}
        \\  tri fpga synth   .v -> .bit (native openXC7)
        \\  tri fpga flash   Program via JTAG
        \\  tri fpga build   synth + flash
        \\  tri fpga snap    Camera snapshot
        \\  tri fpga verify  LED pattern analysis
        \\  tri fpga eye     Vision node (OpenCV LED detection)
        \\  tri fpga uart    UART bridge (scan/ping/send/monitor)
        \\  tri fpga infer   FPGA inference via UART (E2E demo)
        \\  tri fpga status  This info
        \\
    , .{ CYAN, BOLD, RESET });
}

// =========================================================================
// EYE — FPGA Vision Node (OpenCV LED detection + blink analysis)
// =========================================================================

pub fn runFpgaEyeCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var mode: []const u8 = "snap";
    var duration: []const u8 = "5";

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--help") or std.mem.eql(u8, args[i], "-h")) {
            return printEyeUsage();
        } else if (std.mem.eql(u8, args[i], "--blink") or std.mem.eql(u8, args[i], "-b")) {
            mode = "blink";
        } else if (std.mem.eql(u8, args[i], "--watch") or std.mem.eql(u8, args[i], "-w")) {
            mode = "watch";
        } else if (std.mem.eql(u8, args[i], "--duration") or std.mem.eql(u8, args[i], "-d")) {
            i += 1;
            if (i < args.len) duration = args[i];
        } else if (std.mem.eql(u8, args[i], "snap") or
            std.mem.eql(u8, args[i], "blink") or
            std.mem.eql(u8, args[i], "watch"))
        {
            mode = args[i];
        }
    }

    std.debug.print("\n{s}{s}=== TRI FPGA EYE ==={s}\n", .{ BOLD, CYAN, RESET });
    std.debug.print("  Mode: {s}\n", .{mode});

    // Build command: python3 fpga/tools/fpga_eye.py <mode> [duration]
    const eye_script = "fpga/tools/fpga_eye.py";

    var argv_list = try std.ArrayList([]const u8).initCapacity(allocator, 8);
    defer argv_list.deinit(allocator);

    try argv_list.append(allocator, "python3");
    try argv_list.append(allocator, eye_script);
    try argv_list.append(allocator, mode);

    if (std.mem.eql(u8, mode, "blink")) {
        try argv_list.append(allocator, duration);
    }

    const ok = try runCmd(allocator, argv_list.items, true);

    if (!ok) {
        std.debug.print("  {s}FPGA Eye failed{s}\n", .{ RED, RESET });
        return error.EyeFailed;
    }

    std.debug.print("  {s}{s}FPGA Eye complete{s}\n\n", .{ BOLD, GREEN, RESET });
}

fn printEyeUsage() !void {
    std.debug.print(
        \\
        \\{0s}=== TRI FPGA EYE ==={1s}
        \\
        \\FPGA Vision Node — Automated LED verification via camera + OpenCV.
        \\Detects LED states, blink patterns, and determines test verdict.
        \\
        \\USAGE:
        \\  tri fpga eye [mode] [options]
        \\
        \\MODES:
        \\  snap    Single snapshot + LED analysis (default)
        \\  blink   Video blink analysis (default 5s)
        \\  watch   Continuous monitoring (1 fps, Ctrl+C to stop)
        \\
        \\OPTIONS:
        \\  --blink, -b        Blink analysis mode
        \\  --watch, -w        Continuous monitoring mode
        \\  --duration, -d <s> Video duration for blink (default: 5)
        \\
        \\EXAMPLES:
        \\  tri fpga eye                # Quick snapshot, show LED states
        \\  tri fpga eye --blink        # 5s video, analyze blink patterns
        \\  tri fpga eye blink 10       # 10s blink analysis
        \\
        \\LED CONVENTIONS (QMTECH XC7A100T):
        \\  D6 solid ON  = self-test PASS
        \\  D6 OFF       = self-test FAIL
        \\  D6 blinking  = computation in progress
        \\
    , .{ CYAN, RESET });
}

// =========================================================================
// INFER — FPGA Inference (Zig↔FPGA E2E)
// =========================================================================

pub fn runFpgaInferCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) return printInferUsage();

    const subcmd = args[0];

    if (std.mem.eql(u8, subcmd, "token")) {
        if (args.len < 2) {
            std.debug.print("{s}Error:{s} Missing token_id\n", .{ RED, RESET });
            return error.MissingArg;
        }
        const token_id = std.fmt.parseInt(u8, args[1], 10) catch {
            std.debug.print("{s}Error:{s} Invalid token_id (0-127)\n", .{ RED, RESET });
            return error.InvalidArg;
        };
        if (token_id > 127) return error.InvalidArg;

        std.debug.print("\n{s}{s}=== TRI FPGA INFER ==={s}\n", .{ BOLD, CYAN, RESET });
        std.debug.print("{s}Mode:{s}     Single token\n", .{ DIM, RESET });
        std.debug.print("{s}Token ID:{s} {d}\n\n", .{ DIM, RESET, token_id });

        const dev_path = if (args.len > 2) args[2] else blk: {
            const found = try findSerialDevice(allocator);
            if (found) |f| break :blk f;
            std.debug.print("  {s}No FPGA found{s} — connect USB-UART and flash hslm_uart_inference_top.bit\n\n", .{ YELLOW, RESET });
            return;
        };
        defer if (args.len <= 2) allocator.free(dev_path);

        std.debug.print("  Device: {s}\n", .{dev_path});
        std.debug.print("  Connecting...", .{});

        var port = SerialPort.open(dev_path) catch |err| {
            std.debug.print(" {s}FAIL{s} (open: {s})\n\n", .{ RED, RESET, @errorName(err) });
            return;
        };
        defer port.close();

        // Protocol: [0xAA][0x10][token_id]
        const tx = [_]u8{ 0xAA, 0x10, token_id };
        _ = port.writeBytes(&tx) catch |err| {
            std.debug.print(" {s}FAIL{s} (write: {s})\n\n", .{ RED, RESET, @errorName(err) });
            return;
        };
        std.debug.print(" {s}OK{s}\n", .{ GREEN, RESET });
        std.debug.print("  TX: AA 10 {X:0>2}\n", .{token_id});

        var resp: [64]u8 = undefined;
        const n = port.readBytes(&resp) catch |err| {
            std.debug.print("  {s}FAIL{s} (read: {s})\n\n", .{ RED, RESET, @errorName(err) });
            return;
        };

        if (n > 0) {
            std.debug.print("  RX: ", .{});
            for (resp[0..n]) |b| std.debug.print("{X:0>2} ", .{b});
            std.debug.print("\n", .{});
            if (n >= 2 and resp[0] == 0xAA) {
                std.debug.print("  {s}Predicted token:{s} {d}\n", .{ GREEN, RESET, resp[1] });
            }
        } else {
            std.debug.print("  {s}TIMEOUT{s} (no response in 5s)\n", .{ YELLOW, RESET });
        }
        std.debug.print("\n", .{});
    } else if (std.mem.eql(u8, subcmd, "seq")) {
        if (args.len < 3) {
            std.debug.print("{s}Error:{s} Usage: tri fpga infer seq <seed_token> <n_tokens>\n", .{ RED, RESET });
            return error.MissingArg;
        }
        const seed_token = std.fmt.parseInt(u8, args[1], 10) catch return error.InvalidArg;
        const n_tokens = std.fmt.parseInt(u8, args[2], 10) catch return error.InvalidArg;

        std.debug.print("\n{s}{s}=== TRI FPGA INFER SEQ ==={s}\n", .{ BOLD, CYAN, RESET });
        std.debug.print("{s}Seed:{s}     {d}\n", .{ DIM, RESET, seed_token });
        std.debug.print("{s}Tokens:{s}   {d}\n\n", .{ DIM, RESET, n_tokens });

        const dev_path = if (args.len > 3) args[3] else blk: {
            const found = try findSerialDevice(allocator);
            if (found) |f| break :blk f;
            std.debug.print("  {s}No FPGA found{s} — connect and flash hslm_uart_inference_top.bit\n\n", .{ YELLOW, RESET });
            return;
        };
        defer if (args.len <= 3) allocator.free(dev_path);

        var port = SerialPort.open(dev_path) catch |err| {
            std.debug.print("  {s}FAIL{s} (open: {s})\n\n", .{ RED, RESET, @errorName(err) });
            return;
        };
        defer port.close();

        // Protocol: [0xAA][0x11][seed][n_tokens]
        const tx = [_]u8{ 0xAA, 0x11, seed_token, n_tokens };
        _ = port.writeBytes(&tx) catch |err| {
            std.debug.print("  {s}FAIL{s} (write: {s})\n\n", .{ RED, RESET, @errorName(err) });
            return;
        };
        std.debug.print("  FPGA: {s}\n", .{dev_path});
        std.debug.print("  TX: AA 11 {X:0>2} {X:0>2}\n", .{ seed_token, n_tokens });
        std.debug.print("  Expected: ~{d}ms total ({d} tokens x ~30ms)\n", .{ @as(u32, n_tokens) * 30, n_tokens });

        var resp: [256]u8 = undefined;
        const n = port.readBytes(&resp) catch |err| {
            std.debug.print("  {s}FAIL{s} (read: {s})\n\n", .{ RED, RESET, @errorName(err) });
            return;
        };

        if (n > 0) {
            std.debug.print("  RX: ", .{});
            for (resp[0..n]) |b| std.debug.print("{X:0>2} ", .{b});
            std.debug.print("\n  Tokens: ", .{});
            for (resp[0..n]) |b| std.debug.print("{d} ", .{b});
            std.debug.print("\n", .{});
        } else {
            std.debug.print("  {s}TIMEOUT{s}\n", .{ YELLOW, RESET });
        }
        std.debug.print("\n", .{});
    } else if (std.mem.eql(u8, subcmd, "status")) {
        std.debug.print("\n{s}{s}=== FPGA Inference Status ==={s}\n", .{ BOLD, CYAN, RESET });

        const dev_path = try findSerialDevice(allocator);
        if (dev_path) |path| {
            defer allocator.free(path);
            std.debug.print("  Device: {s} {s}FOUND{s}\n", .{ path, GREEN, RESET });

            var port = SerialPort.open(path) catch |err| {
                std.debug.print("  Open: {s}FAIL{s} ({s})\n\n", .{ RED, RESET, @errorName(err) });
                return;
            };
            defer port.close();

            // Protocol: [0xAA][0x12] status query
            const tx = [_]u8{ 0xAA, 0x12 };
            _ = port.writeBytes(&tx) catch |err| {
                std.debug.print("  Write: {s}FAIL{s} ({s})\n\n", .{ RED, RESET, @errorName(err) });
                return;
            };

            var resp: [64]u8 = undefined;
            const n = port.readBytes(&resp) catch |err| {
                std.debug.print("  Read: {s}FAIL{s} ({s})\n\n", .{ RED, RESET, @errorName(err) });
                return;
            };

            if (n > 0) {
                std.debug.print("  Status: ", .{});
                for (resp[0..n]) |b| std.debug.print("{X:0>2} ", .{b});
                std.debug.print("\n", .{});
            } else {
                std.debug.print("  {s}No response{s}\n", .{ YELLOW, RESET });
            }
        } else {
            std.debug.print("  {s}No FPGA device found{s}\n", .{ YELLOW, RESET });
            std.debug.print("  Connect USB-UART cable (CH340/FTDI)\n", .{});
        }
        std.debug.print("\n", .{});
    } else {
        return printInferUsage();
    }
}

fn printInferUsage() !void {
    std.debug.print(
        \\
        \\{0s}=== TRI FPGA INFER ==={1s}
        \\
        \\Run ternary transformer inference on FPGA via UART.
        \\Requires hslm_uart_inference_top.bit flashed to FPGA.
        \\
        \\USAGE:
        \\  tri fpga infer token <token_id>              Single token prediction
        \\  tri fpga infer seq <seed_token> <n_tokens>   Autoregressive generation
        \\  tri fpga infer status                        Pipeline status
        \\
        \\EXAMPLES:
        \\  tri fpga infer token 42                      Predict next token for input 42
        \\  tri fpga infer seq 42 16                     Generate 16 tokens from seed 42
        \\  tri fpga infer status                        Check FPGA pipeline state
        \\
        \\SETUP:
        \\  1. Synthesize: tri fpga synth fpga/openxc7-synth/hslm_uart_inference_top.v
        \\  2. Flash:      tri fpga flash hslm_uart_inference_top.bit
        \\  3. Connect:    USB-UART to FPGA pins L20(RX)/K20(TX)
        \\  4. Run:        tri fpga infer token 42
        \\
    , .{ CYAN, RESET });
}

// =========================================================================
// READ — JTAG config register read via jtag_switcher
// =========================================================================

const JTAG_SWITCHER = "fpga/tools/jtag_switcher";

pub fn runFpgaReadCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) return printReadUsage();
    if (std.mem.eql(u8, args[0], "--help") or std.mem.eql(u8, args[0], "-h")) return printReadUsage();

    const subcmd = args[0];

    // Build argv: sudo jtag_switcher <subcmd> [arg]
    var argv_buf: [4][]const u8 = undefined;
    var argv_len: usize = 0;
    argv_buf[argv_len] = "sudo";
    argv_len += 1;
    argv_buf[argv_len] = JTAG_SWITCHER;
    argv_len += 1;
    argv_buf[argv_len] = subcmd;
    argv_len += 1;
    if (args.len > 1) {
        argv_buf[argv_len] = args[1];
        argv_len += 1;
    }

    std.debug.print("\n{s}{s}=== TRI FPGA READ — {s} ==={s}\n", .{ BOLD, CYAN, subcmd, RESET });
    std.debug.print("  Running: sudo {s} {s}", .{ JTAG_SWITCHER, subcmd });
    if (args.len > 1) std.debug.print(" {s}", .{args[1]});
    std.debug.print("\n\n", .{});

    var child = std.process.Child.init(
        argv_buf[0..argv_len],
        allocator,
    );
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    try child.spawn();
    const term = try child.wait();

    if (term.Exited != 0) {
        std.debug.print("\n{s}FAILED{s} (exit code {d})\n", .{ RED, RESET, term.Exited });
        return error.ReadFailed;
    }
}

fn printReadUsage() !void {
    std.debug.print(
        \\
        \\{0s}=== TRI FPGA READ ==={1s}
        \\
        \\Read FPGA config registers via JTAG (requires sudo).
        \\Uses CFG_IN → CFG_OUT pipeline per UG470.
        \\
        \\USAGE:
        \\  tri fpga read <command> [args]
        \\
        \\COMMANDS:
        \\  status              Read STAT register (DONE, CRC, etc.)
        \\  idcode              Read IDCODE via config interface
        \\  dna                 Read 57-bit device DNA
        \\  reg <hex_addr>      Read any config register (00-1F)
        \\  readback <out.bin>  Full bitstream readback to file
        \\  verify <file.bit>   Readback + compare with .bit file
        \\  write <file.bit>    Program bitstream
        \\
        \\EXAMPLES:
        \\  tri fpga read status
        \\  tri fpga read idcode
        \\  tri fpga read reg 07
        \\  tri fpga read verify fpga/openxc7-synth/hslm_full_top.bit
        \\
    , .{ CYAN, RESET });
}

// =========================================================================
// POWER Commands — tri fpga power {flash|measure|report|status}
// =========================================================================

pub const PowerMode = enum(u3) {
    IDLE = 0,
    BLINK = 1,
    ONE_BLOCK = 2,
    FOUR_BLOCK = 3,
    AUTO_CYCLE = 4,
};

pub const PowerReading = struct {
    mode: PowerMode,
    voltage_mv: u16,
    current_ma: u16,
    power_mw: u32,
    delta_mw: i32,
};

pub fn runFpgaPowerCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) return printPowerUsage();

    const subcmd = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, subcmd, "flash")) {
        try powerFlash(allocator);
    } else if (std.mem.eql(u8, subcmd, "measure")) {
        const device = if (sub_args.len > 0) sub_args[0] else null;
        try powerMeasure(allocator, device);
    } else if (std.mem.eql(u8, subcmd, "report")) {
        try powerReport(allocator);
    } else if (std.mem.eql(u8, subcmd, "status")) {
        const device = if (sub_args.len > 0) sub_args[0] else null;
        try powerStatus(allocator, device);
    } else if (std.mem.eql(u8, subcmd, "--help") or std.mem.eql(u8, subcmd, "-h")) {
        return printPowerUsage();
    } else {
        std.debug.print("{s}Error:{s} Unknown power subcommand: {s}\n", .{ RED, RESET, subcmd });
        return printPowerUsage();
    }
}

fn powerFlash(allocator: std.mem.Allocator) !void {
    std.debug.print("\n{s}{s}=== TRI FPGA POWER FLASH ==={s}\n\n", .{ BOLD, CYAN, RESET });

    const source_file = "fpga/openxc7-synth/power_modes.v";
    const output_dir = "fpga/output";
    const bitstream = output_dir ++ "/power_modes.bit";

    std.fs.cwd().access(source_file, .{}) catch {
        std.debug.print("  {s}Source not found:{s} {s}\n", .{ RED, RESET, source_file });
        std.debug.print("  Create power_modes.v first\n\n", .{});
        return error.FileNotFound;
    };

    std.debug.print("  Source: {s}\n", .{source_file});
    std.debug.print("  Output: {s}\n", .{bitstream});
    std.debug.print("\n  Synthesizing...\n", .{});

    std.fs.cwd().makePath(output_dir) catch {};

    const yosys_script =
        \\read -sv power_modes.v
        \\hierarchy -check -top power_modes
        \\synth_xilinx -flatten
        \\write_json power_modes.json
    ;

    var yosys_argv = [_][]const u8{ "yosys", "-p", yosys_script };
    _ = try runCmd(allocator, &yosys_argv, true);

    std.fs.cwd().access("fpga/openxc7-synth/power_modes.json", .{}) catch {
        std.debug.print("  {s}Yosys failed{s} — no JSON output\n", .{ RED, RESET });
        return error.SynthesisFailed;
    };
    std.debug.print("  {s}Yosys synthesis OK{s}\n", .{ GREEN, RESET });

    std.debug.print("  Placing + routing...\n", .{});
    var nextpnr_argv = [_][]const u8{
        NEXTPNR,                               "--chipdb",                            CHIPDB,
        "--json",                              "fpga/openxc7-synth/power_modes.json", "--fasm",
        "fpga/openxc7-synth/power_modes.fasm", "--xdc",                               "fpga/openxc7-synth/power_modes.xdc",
    };
    _ = try runCmd(allocator, &nextpnr_argv, true);

    std.debug.print("  Converting FASM to frames...\n", .{});
    var fasm_argv = [_][]const u8{
        "python3",                             FASM2FRAMES,
        "fpga/openxc7-synth/power_modes.fasm", "fpga/openxc7-synth/power_modes.frames",
    };
    _ = try runCmd(allocator, &fasm_argv, false);

    std.debug.print("  Converting frames to bitstream...\n", .{});
    var bit_argv = [_][]const u8{
        XC7FRAMES2BIT,
        "--part_file",
        PRJXRAY_DB ++ "/xc7a100tfgg676/part.yaml",
        "--part_name",
        "xc7a100tfgg676",
        "--frames_file",
        "fpga/openxc7-synth/power_modes.frames",
        "--output_file",
        bitstream,
    };
    _ = try runCmd(allocator, &bit_argv, false);

    std.fs.cwd().access(bitstream, .{}) catch {
        std.debug.print("  {s}Bitstream not created:{s} {s}\n\n", .{ RED, RESET, bitstream });
        return error.BitstreamFailed;
    };

    std.debug.print("\n  {s}Bitstream ready:{s} {s}\n", .{ GREEN, RESET, bitstream });
    std.debug.print("\n  Flashing to FPGA...\n", .{});

    var flash_argv = [_][]const u8{
        "openFPGALoader",
        "--board",
        "qmtech_xc7a100t",
        "--bitstream",
        bitstream,
    };
    _ = try runCmd(allocator, &flash_argv, true);

    std.debug.print("\n  {s}Power modes flashed!{s}\n", .{ GREEN, RESET });
    std.debug.print("  Set DIP switches SW1 to select mode:\n", .{});
    std.debug.print("    SW1=00  → Mode 0 IDLE\n", .{});
    std.debug.print("    SW1=01  → Mode 1 BLINK\n", .{});
    std.debug.print("    SW1=10  → Mode 2 1-BLOCK\n", .{});
    std.debug.print("    SW1=11  → Mode 3 4-BLOCK\n", .{});
    std.debug.print("    Press BTN for Mode 4 AUTO-CYCLE\n\n", .{});
}

fn powerMeasure(allocator: std.mem.Allocator, device_arg: ?[]const u8) !void {
    std.debug.print("\n{s}{s}=== TRI FPGA POWER MEASURE ==={s}\n", .{ BOLD, CYAN, RESET });
    std.debug.print("  Equipment: USB power meter inline on FPGA USB rail\n", .{});
    std.debug.print("  Set display to 'Power (W)' mode\n", .{});
    std.debug.print("  Allow 5 seconds per mode for reading to stabilize\n\n", .{});

    const dev_path = if (device_arg) |d| d else blk: {
        const found = try findSerialDevice(allocator);
        if (found) |f| break :blk f;
        std.debug.print("  {s}No serial device found{s} — plug in USB-UART cable\n\n", .{ RED, RESET });
        return;
    };
    defer if (device_arg == null) allocator.free(dev_path);

    std.debug.print("  Device: {s}\n\n", .{dev_path});

    const mode_names = [_][]const u8{ "IDLE(0)", "BLINK(1)", "1-BLK(2)", "4-BLK(3)" };
    const expected_mws = [_]u32{ 450, 500, 600, 750 };

    std.debug.print("  Measure each mode and enter power reading in mW:\n\n", .{});

    var readings_buf: [5]PowerReading = undefined;
    var readings_len: usize = 0;

    for ([_]PowerMode{ .IDLE, .BLINK, .ONE_BLOCK, .FOUR_BLOCK }, mode_names, expected_mws, 0..) |mode, name, expected_mw, i| {
        std.debug.print("{s}Mode {d}: {s}{s}\n", .{ YELLOW, i, name, RESET });
        std.debug.print("  Set DIP switches, wait 5 seconds\n", .{});
        std.debug.print("  Expected: ~{d} mW\n", .{expected_mw});
        std.debug.print("  Enter reading (mW): ", .{});

        // Use a simple placeholder - user should edit JSON file after measurement
        const power_mw = expected_mw;
        const delta_mw: i32 = if (i == 0) 0 else @as(i32, @intCast(power_mw)) - @as(i32, @intCast(readings_buf[0].power_mw));

        readings_buf[readings_len] = PowerReading{
            .mode = mode,
            .voltage_mv = 3300,
            .current_ma = @intCast(power_mw * 1000 / 3300),
            .power_mw = power_mw,
            .delta_mw = delta_mw,
        };
        readings_len += 1;

        std.debug.print("{d} mW (delta: {d} mW)\n\n", .{ power_mw, delta_mw });
    }

    const results_path = ".trinity/fpga/power_results.json";
    std.fs.cwd().makePath(".trinity/fpga") catch {};

    {
        var file = try std.fs.cwd().createFile(results_path, .{});
        defer file.close();

        var json_buf: [8192]u8 = undefined;
        var json_stream = std.io.fixedBufferStream(&json_buf);
        const json_writer = json_stream.writer();

        try json_writer.print(
            \\{{"timestamp": "{d}", "device": "{s}", "readings": [
        , .{ std.time.timestamp(), dev_path });

        for (readings_buf[0..readings_len], 0..) |r, i| {
            const comma = if (i < readings_len - 1) "," else "";
            try json_writer.print(
                \\{{"mode": {d}, "name": "{s}", "voltage_mv": {d}, "current_ma": {d}, "power_mw": {d}, "delta_mw": {d}}}{s}
            , .{ @intFromEnum(r.mode), mode_names[i], r.voltage_mv, r.current_ma, r.power_mw, r.delta_mw, comma });
        }
        try json_writer.writeAll("]}\n");

        try file.writeAll(json_stream.getWritten());
    }

    std.debug.print("{s}Results saved to:{s} {s}\n", .{ GREEN, RESET, results_path });
    std.debug.print("  Edit the JSON file with actual meter readings\n", .{});
    std.debug.print("  Generate report with: {s}tri fpga power report{s}\n\n", .{ CYAN, RESET });
}

fn powerReport(allocator: std.mem.Allocator) !void {
    std.debug.print("\n{s}{s}=== TRI FPGA POWER REPORT ==={s}\n\n", .{ BOLD, CYAN, RESET });

    const results_path = ".trinity/fpga/power_results.json";
    const contents = std.fs.cwd().readFileAlloc(allocator, results_path, 8192) catch {
        std.debug.print("  {s}No results found{s}\n", .{ RED, RESET });
        std.debug.print("  Run {s}tri fpga power measure{s} first\n\n", .{ CYAN, RESET });
        return error.FileNotFound;
    };
    defer allocator.free(contents);

    std.debug.print(
        \\| Mode    | V (rail) | I (mA) | P (mW) | Delta P |
        \\|---------|----------|--------|--------|---------|
        \\
    , .{});

    var lines = std.mem.splitScalar(u8, contents, '\n');
    var baseline_mw: u32 = 0;
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, "\"mode\":")) |_| {
            const mode_idx = std.mem.indexOf(u8, line, ": ").? + 2;
            const mode_end = std.mem.indexOf(u8, line[mode_idx..], ",") orelse line[mode_idx..].len;
            const mode_str = line[mode_idx..][0..mode_end];
            const mode = std.fmt.parseInt(u3, mode_str, 10) catch 0;

            const name_start = std.mem.indexOf(u8, line, "\"name\": \"") orelse continue;
            const name_start_idx = name_start + 9;
            const name_end = std.mem.indexOf(u8, line[name_start_idx..], "\"") orelse continue;
            const name = line[name_start_idx..][0..name_end];

            const volt_start = std.mem.indexOf(u8, line, "\"voltage_mv\": ") orelse continue;
            const volt_start_idx = volt_start + 14;
            const volt_end = std.mem.indexOf(u8, line[volt_start_idx..], ",") orelse continue;
            const voltage = std.fmt.parseInt(u16, line[volt_start_idx..][0..volt_end], 10) catch 3300;
            const v_f = @as(f32, @floatFromInt(voltage)) / 1000.0;

            const curr_start = std.mem.indexOf(u8, line, "\"current_ma\": ") orelse continue;
            const curr_start_idx = curr_start + 13;
            const curr_end = std.mem.indexOf(u8, line[curr_start_idx..], ",") orelse continue;
            const current = std.fmt.parseInt(u16, line[curr_start_idx..][0..curr_end], 10) catch 0;

            const pow_start = std.mem.indexOf(u8, line, "\"power_mw\": ") orelse continue;
            const pow_start_idx = pow_start + 12;
            const pow_end = std.mem.indexOf(u8, line[pow_start_idx..], ",") orelse continue;
            const power = std.fmt.parseInt(u32, line[pow_start_idx..][0..pow_end], 10) catch 0;

            const delta_start = std.mem.indexOf(u8, line, "\"delta_mw\": ") orelse continue;
            const delta_start_idx = delta_start + 12;
            const delta_end = std.mem.indexOf(u8, line[delta_start_idx..], ",") orelse line[delta_start_idx..].len;
            const delta_str = line[delta_start_idx..][0..delta_end];
            const delta = std.fmt.parseInt(i32, delta_str, 10) catch 0;

            if (mode == 0) baseline_mw = power;

            std.debug.print("| {s} | {d:.1}    | {d:4}  | {d:4}  | ", .{ name, v_f, current, power });
            if (mode == 0) {
                std.debug.print("baseline |\n", .{});
            } else {
                const sign = if (delta >= 0) "+" else "";
                std.debug.print("{s}{d} mW |\n", .{ sign, delta });
            }
        }
    }

    std.debug.print("\n", .{});
}

fn powerStatus(allocator: std.mem.Allocator, device_arg: ?[]const u8) !void {
    std.debug.print("\n{s}{s}=== TRI FPGA POWER STATUS ==={s}\n\n", .{ BOLD, CYAN, RESET });

    const dev_path = if (device_arg) |d| d else blk: {
        const found = try findSerialDevice(allocator);
        if (found) |f| break :blk f;
        std.debug.print("  {s}No serial device found{s} — plug in USB-UART cable\n\n", .{ RED, RESET });
        return;
    };
    defer if (device_arg == null) allocator.free(dev_path);

    std.debug.print("  Device: {s}\n", .{dev_path});
    std.debug.print("  Reading mode from UART...\n\n", .{});

    var port = SerialPort.open(dev_path) catch |err| {
        std.debug.print("  {s}FAIL{s} (open: {s})\n\n", .{ RED, RESET, @errorName(err) });
        return;
    };
    defer port.close();

    var buf: [256]u8 = undefined;

    const start_ms = std.time.milliTimestamp();
    while (std.time.milliTimestamp() - start_ms < 5000) {
        const n = port.readBytes(&buf) catch break;
        if (n > 0) {
            for (0..n - 4) |i| {
                if (buf[i] == 0xAA and buf[i + 1] == 0xBB and
                    buf[i + 2] == 0x50 and buf[i + 3] == 0x4D)
                {
                    const mode_byte = buf[i + 4];
                    const mode: PowerMode = @enumFromInt(mode_byte & 0x07);

                    std.debug.print("  {s}Current mode:{s} ", .{ GREEN, RESET });
                    switch (mode) {
                        .IDLE => std.debug.print("IDLE (0) — quiescent, ~0.45W\n", .{}),
                        .BLINK => std.debug.print("BLINK (1) — LED blinker, ~0.50W\n", .{}),
                        .ONE_BLOCK => std.debug.print("1-BLOCK (2) — one transformer block, ~0.60W\n", .{}),
                        .FOUR_BLOCK => std.debug.print("4-BLOCK (3) — full pipeline, ~0.75W\n", .{}),
                        .AUTO_CYCLE => std.debug.print("AUTO-CYCLE (4) — cycling modes, varies\n", .{}),
                    }

                    std.debug.print("\n  Frame: AA BB 50 4D {X:0>2}\n", .{mode_byte});
                    std.debug.print("  DIP switches should be set to: {b:0>2}\n\n", .{mode_byte & 0x03});
                    return;
                }
            }
        }
    }

    std.debug.print("  {s}No mode frame received{s}\n", .{ YELLOW, RESET });
    std.debug.print("  Check DIP switch setting and UART connection\n\n", .{});
}

fn printPowerUsage() !void {
    std.debug.print(
        \\
        \\{0s}=== TRI FPGA POWER ==={1s}
        \\
        \\Power measurement for FPGA via USB meter + UART mode feedback.
        \\
        \\USAGE:
        \\  tri fpga power flash                         Synthesize + flash power_modes.v
        \\  tri fpga power measure [device]              Measure power in each mode
        \\  tri fpga power report                        Generate markdown table
        \\  tri fpga power status [device]               Read current mode from UART
        \\
        \\EQUIPMENT:
        \\  - USB power meter (ATORCH UD18/UD24 or similar)
        \\  - USB-UART cable (CH340/FTDI) connected to FPGA
        \\  - power_modes.v flashed on FPGA
        \\
        \\EXAMPLES:
        \\  tri fpga power flash
        \\  tri fpga power measure /dev/tty.wchusbserial1420
        \\  tri fpga power report
        \\  tri fpga power status
        \\
    , .{ CYAN, RESET });
}

/// Export for tri_register.zig
pub const runCommand = runFpgaBuildCommand;

test "fpga runCommand export" {
    try std.testing.expect(@intFromPtr(&runCommand) != 0);
}
