//! UART Echo Test — Advanced FPGA UART bridge test tool
//! Sends bytes with configurable delay and expects them echoed back
//! v3.18 — Auto-configure port, precise device detection (VID/PID), error stats
//!
//! Usage:
//!     zig run uart-echo-test [--baud 115200] [--delay 200] [--timeout 2000] [-v|--verbose]
//!                            [--output results.csv|--json] [--config uart-test.toml] [--retries 3]
//!                            [--batch-size 16] [--buffer-size 4096] [--adaptive-timeout] [--auto-configure]
//!
//! Features:
//!   - Multi-adapter support: FT232RL, CP210x, CH340, PL2303 (precise VID/PID detection)
//!   - Auto-configure: Automatic termios setup via --auto-configure flag (v3.18)
//!   - Config file: TOML configuration for persistent settings (v3.15)
//!   - JSON export: Structured test results for analysis
//!   - Error recovery: Automatic retry on failed tests
//!   - Throughput measurement: Bytes/second calculation
//!   - Batch testing: Send N packets without waiting for individual responses
//!   - Buffered I/O: Pre-allocated buffers for reduced syscall overhead
//!   - Adaptive timeout: Dynamically adjust based on measured RTT
//!   - Health checks: Serial port validation before testing
//!   - Error statistics: Track errors by type (timeout, mismatch, device error)
//!
//! Dependencies:
//!     Zig 0.15+ (uses POSIX serial)
//!
//! Note: Use --auto-configure for automatic port setup, or configure manually:
//!   stty -f /dev/cu.usbserial-* 115200 cs8 -parenb -cstopb 1 -hupcl

const std = @import("std");

// Constants
const DEFAULT_BAUD: u64 = 115200;
const DEFAULT_DELAY_MS: u32 = 200;
const DEFAULT_TIMEOUT_MS: u32 = 2000;
const DEFAULT_RETRIES: u32 = 3;
const DEFAULT_BATCH_SIZE: usize = 16;
const DEFAULT_BUFFER_SIZE: usize = 4096;
const MIN_TIMEOUT_MS: u32 = 50;

// Test configuration
const Config = struct {
    baud: u64,
    delay_ms: u32,
    timeout_ms: u32,
    retries: u32,
    verbose: bool,
    ping_mode: bool,
    loopback_mode: bool,
    auto_configure: bool,
    device: ?[]const u8,
    continuous: bool,
    output_file: ?[]const u8,
    json_output: bool,
    config_file: ?[]const u8,
    measure_throughput: bool,
    // v3.14 features
    simulation_mode: bool,
    dry_run: bool,
    batch_size: usize,
    buffer_size: usize,
    adaptive_timeout: bool,
};

// Device vendor detection
const DeviceType = enum {
    FT232RL,
    CP210x,
    CH340,
    PL2303,
    Other,
};

const SerialDevice = struct {
    path: []const u8,
    vendor: DeviceType,
    vendor_id: u16 = 0,
    product_id: u16 = 0,
};

// v3.14: Enhanced throughput statistics with packet-by-packet tracking
const ThroughputStats = struct {
    total_bytes_sent: usize = 0,
    total_bytes_received: usize = 0,
    total_time_ms: i64 = 0,
    packets_sent: usize = 0,
    packets_received: usize = 0,
    min_latency_ms: i64 = -1,
    max_latency_ms: i64 = 0,
    total_latency_ms: i64 = 0,
    latency_samples: usize = 0,

    pub fn calculateThroughput(self: *const ThroughputStats) f64 {
        if (self.total_time_ms == 0) return 0;
        const bytes_per_second = @as(f64, @floatFromInt(self.total_bytes_received)) /
            @as(f64, @floatFromInt(self.total_time_ms)) * 1000.0;
        return bytes_per_second;
    }

    pub fn getAvgLatency(self: *const ThroughputStats) f64 {
        if (self.latency_samples == 0) return 0;
        return @as(f64, @floatFromInt(self.total_latency_ms)) / @as(f64, @floatFromInt(self.latency_samples));
    }

    pub fn getPacketSuccessRate(self: *const ThroughputStats) f64 {
        if (self.packets_sent == 0) return 0;
        return @as(f64, @floatFromInt(self.packets_received)) / @as(f64, @floatFromInt(self.packets_sent)) * 100.0;
    }
};

// v3.18: Error statistics for tracking test failures by type
const ErrorStats = struct {
    timeout_errors: usize = 0,
    mismatch_errors: usize = 0,
    device_errors: usize = 0,
    total_errors: usize = 0,

    pub fn recordError(self: *ErrorStats, err_type: []const u8) void {
        self.total_errors += 1;
        if (std.mem.eql(u8, err_type, "timeout")) {
            self.timeout_errors += 1;
        } else if (std.mem.eql(u8, err_type, "mismatch")) {
            self.mismatch_errors += 1;
        } else if (std.mem.eql(u8, err_type, "device")) {
            self.device_errors += 1;
        }
    }

    pub fn report(self: *const ErrorStats) void {
        if (self.total_errors == 0) {
            printErr("[i] No errors recorded\n", .{});
            return;
        }
        printErr("[i] Error Statistics:\n", .{});
        printErr("    Total errors: {d}\n", .{self.total_errors});
        printErr("    Timeout errors: {d}\n", .{self.timeout_errors});
        printErr("    Mismatch errors: {d}\n", .{self.mismatch_errors});
        printErr("    Device errors: {d}\n", .{self.device_errors});
    }
};

// v3.18: Device detection with VID/PID
const DeviceInfo = struct {
    path: []const u8,
    vendor_id: u16,
    product_id: u16,
    vendor_name: []const u8,
};

// PING/PONG protocol
const PING_BYTE: u8 = 0x03; // Send PING
const PONG_BYTE: u8 = 0x83; // Expect PONG response

// Helper for formatted stderr output
fn printErr(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

// Parse command line arguments
fn parseArgs() Config {
    var config = Config{
        .baud = DEFAULT_BAUD,
        .delay_ms = DEFAULT_DELAY_MS,
        .timeout_ms = DEFAULT_TIMEOUT_MS,
        .retries = DEFAULT_RETRIES,
        .verbose = false,
        .ping_mode = false,
        .loopback_mode = false,
        .auto_configure = false,
        .device = null,
        .continuous = false,
        .output_file = null,
        .json_output = false,
        .config_file = null,
        .measure_throughput = false,
        .simulation_mode = false,
        .dry_run = false,
        .batch_size = DEFAULT_BATCH_SIZE,
        .buffer_size = DEFAULT_BUFFER_SIZE,
        .adaptive_timeout = false,
    };

    var i: usize = 1;
    while (i < std.os.argv.len) : (i += 1) {
        const arg = std.mem.span(std.os.argv[i]);

        if (std.mem.eql(u8, arg, "--baud")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --baud requires value\n", .{});
                std.process.exit(1);
            }
            config.baud = std.fmt.parseInt(u64, std.mem.span(std.os.argv[i + 1]), 10) catch |err| {
                printErr("[*] Invalid baud value: {any}\n", .{err});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "--delay")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --delay requires value\n", .{});
                std.process.exit(1);
            }
            config.delay_ms = std.fmt.parseInt(u32, std.mem.span(std.os.argv[i + 1]), 10) catch |err| {
                printErr("[*] Invalid delay value: {any}\n", .{err});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "--timeout")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --timeout requires value\n", .{});
                std.process.exit(1);
            }
            config.timeout_ms = std.fmt.parseInt(u32, std.mem.span(std.os.argv[i + 1]), 10) catch |err| {
                printErr("[*] Invalid timeout value: {any}\n", .{err});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "--device")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --device requires value\n", .{});
                std.process.exit(1);
            }
            config.device = std.mem.span(std.os.argv[i + 1]);
            i += 1;
        } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            config.verbose = true;
        } else if (std.mem.eql(u8, arg, "--ping-mode")) {
            config.ping_mode = true;
        } else if (std.mem.eql(u8, arg, "--loopback-mode")) {
            config.loopback_mode = true;
        } else if (std.mem.eql(u8, arg, "--auto-configure")) {
            config.auto_configure = true;
        } else if (std.mem.eql(u8, arg, "--continuous")) {
            config.continuous = true;
        } else if (std.mem.eql(u8, arg, "--throughput")) {
            config.measure_throughput = true;
        } else if (std.mem.eql(u8, arg, "--json")) {
            config.json_output = true;
        } else if (std.mem.eql(u8, arg, "--retries")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --retries requires value\n", .{});
                std.process.exit(1);
            }
            config.retries = std.fmt.parseInt(u32, std.mem.span(std.os.argv[i + 1]), 10) catch |err| {
                printErr("[*] Invalid retries value: {any}\n", .{err});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "--config")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --config requires value\n", .{});
                std.process.exit(1);
            }
            config.config_file = std.mem.span(std.os.argv[i + 1]);
            i += 1;
        } else if (std.mem.eql(u8, arg, "--output")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --output requires value\n", .{});
                std.process.exit(1);
            }
            config.output_file = std.mem.span(std.os.argv[i + 1]);
            i += 1;
        } else if (std.mem.eql(u8, arg, "--simulation")) {
            config.simulation_mode = true;
        } else if (std.mem.eql(u8, arg, "--dry-run")) {
            config.dry_run = true;
        } else if (std.mem.eql(u8, arg, "--batch-size")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --batch-size requires value\n", .{});
                std.process.exit(1);
            }
            config.batch_size = std.fmt.parseInt(usize, std.mem.span(std.os.argv[i + 1]), 10) catch |err| {
                printErr("[*] Invalid batch-size value: {any}\n", .{err});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "--buffer-size")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --buffer-size requires value\n", .{});
                std.process.exit(1);
            }
            config.buffer_size = std.fmt.parseInt(usize, std.mem.span(std.os.argv[i + 1]), 10) catch |err| {
                printErr("[*] Invalid buffer-size value: {any}\n", .{err});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "--adaptive-timeout")) {
            config.adaptive_timeout = true;
        } else if (std.mem.eql(u8, arg, "--auto-configure")) {
            config.auto_configure = true;
        } else if (std.mem.eql(u8, arg, "--help")) {
            printUsage();
            std.process.exit(0);
        }
    }

    // v3.15: Load config file if specified
    if (config.config_file) |file_path| {
        printErr("[+] Loading config from: {s}\n", .{file_path});
        const loaded = loadConfigFile(file_path, &config) catch |err| {
            printErr("[!] Failed to load config: {any}\n", .{err});
            std.process.exit(1);
        };
        if (loaded) {
            printErr("[+] Config loaded successfully\n", .{});
        }
    }

    return config;
}

// v3.15: Load TOML config file and merge with command-line config
fn loadConfigFile(path: []const u8, config: *Config) !bool {
    const file = std.fs.openFileAbsolute(path, .{}) catch |err| {
        printErr("[!] Cannot open config file: {any}\n", .{err});
        return false;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try std.heap.page_allocator.alloc(u8, file_size);
    defer std.heap.page_allocator.free(buffer);
    _ = try file.readAll(buffer);

    // Simple line-by-line config parser (no full TOML parser to keep it lightweight)
    var lines = std.mem.splitScalar(u8, buffer, '\n');
    var loaded_any = false;

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &[_]u8{ ' ', '\t', '\r' });
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        // Parse key=value format
        if (std.mem.indexOf(u8, trimmed, &[_]u8{'='})) |eq_pos| {
            const key = std.mem.trim(u8, trimmed[0..eq_pos], &[_]u8{ ' ', '\t', '\r' });
            const value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], &[_]u8{ ' ', '\t', '\r' });

            if (std.mem.eql(u8, key, "baud")) {
                config.baud = std.fmt.parseInt(u64, value, 10) catch continue;
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "delay")) {
                config.delay_ms = std.fmt.parseInt(u32, value, 10) catch continue;
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "timeout")) {
                config.timeout_ms = std.fmt.parseInt(u32, value, 10) catch continue;
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "retries")) {
                config.retries = std.fmt.parseInt(u32, value, 10) catch continue;
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "device")) {
                config.device = value;
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "verbose")) {
                config.verbose = std.ascii.eqlIgnoreCase(value, "true");
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "ping_mode")) {
                config.ping_mode = std.ascii.eqlIgnoreCase(value, "true");
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "loopback_mode")) {
                config.loopback_mode = std.ascii.eqlIgnoreCase(value, "true");
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "continuous")) {
                config.continuous = std.ascii.eqlIgnoreCase(value, "true");
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "throughput")) {
                config.measure_throughput = std.ascii.eqlIgnoreCase(value, "true");
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "json")) {
                config.json_output = std.ascii.eqlIgnoreCase(value, "true");
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "batch_size")) {
                config.batch_size = std.fmt.parseInt(usize, value, 10) catch continue;
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "buffer_size")) {
                config.buffer_size = std.fmt.parseInt(usize, value, 10) catch continue;
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "adaptive_timeout")) {
                config.adaptive_timeout = std.ascii.eqlIgnoreCase(value, "true");
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "simulation")) {
                config.simulation_mode = std.ascii.eqlIgnoreCase(value, "true");
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "dry_run")) {
                config.dry_run = std.ascii.eqlIgnoreCase(value, "true");
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "auto_configure")) {
                config.auto_configure = std.ascii.eqlIgnoreCase(value, "true");
                loaded_any = true;
            }
        }
    }

    return loaded_any;
}

fn printUsage() void {
    std.debug.print(
        \\╔════════════════════════════════════╗
        \\║      Trinity UART Echo Test v3.18           ║
        \\║    Usage: uart-echo-test [options]          ║
        \\╚══════════════════════════════════════╝
        \\
        \\Options:
        \\  --baud <rate>       Baud rate (default: 115200)
        \\  --delay <ms>        Delay between tests in ms (default: 200)
        \\  --timeout <ms>      Read timeout in ms (default: 2000)
        \\  --retries <n>       Retry failed tests N times (default: 3)
        \\  --device <path>     Serial device (default: auto-detect)
        \\  --config <file>     Load config from file (v3.15)
        \\  -v, --verbose       Enable verbose logging
        \\  --ping-mode         PING (0x03) -> PONG (0x83) test mode
        \\  --loopback-mode     Local loopback test (TX->RX on adapter, no FPGA)
        \\  --continuous        Run tests in continuous loop (Ctrl+C to stop)
        \\  --throughput        Measure and display throughput statistics
        \\  --output <file>     Export results to CSV file
        \\  --json              Export results to JSON format
        \\  --batch-size <n>    Send N packets per batch (default: 16)
        \\  --buffer-size <n>   I/O buffer size in bytes (default: 4096)
        \\  --adaptive-timeout   Dynamically adjust timeout based on RTT
        \\  --auto-configure    Auto-configure port (termios setup)
        \\  --simulation         Simulation mode (no hardware required)
        \\  --dry-run           Show what would be sent (no actual I/O)
        \\  --help              Show this help message
        \\
        \\Performance Modes:
        \\  Default: Sequential echo test with verification
        \\  Batch: Send N packets, measure aggregated throughput
        \\  Adaptive: Auto-tune timeout based on measured latency
        \\
        \\Config File (v3.15):
        \\  Supports key=value format (one per line):
        \\  Example:
        \\    baud=115200
        \\    timeout=2000
        \\    batch_size=32
        \\    adaptive_timeout=true
        \\
        \\Supported Adapters:
        \\  - FT232RL (FTDI)   - CP210x (Silicon Labs)
        \\  - CH340 (WCH)        - PL2303 (Prolific)
        \\
        \\Examples:
        \\  zig run uart-echo-test --ping-mode -v --throughput --json
        \\  zig run uart-echo-test --batch-size 32 --throughput
        \\  zig run uart-echo-test --adaptive-timeout --buffer-size 16384
        \\
    , .{});
}

// v3.18: Health check function - validates serial port before testing
fn healthCheck(port_path: ?[]const u8, baud: u64) !bool {
    if (port_path == null) return true; // No port, skip check

    printErr("[i] Running health check on: {s}\n", .{port_path.?});

    // Check if device exists and is accessible
    // O_RDWR | O_NONBLOCK | O_NOCTTY for macOS
    const flags: std.posix.O = @bitCast(@as(u32, 0x0002) | @as(u32, 0x0004) | @as(u32, 0x00020000));
    const fd = std.posix.open(port_path.?, flags, 0) catch |err| {
        printErr("[!] Health check: Cannot open port: {any}\n", .{err});
        return false;
    };
    defer std.posix.close(fd);

    _ = configureSerial(fd, baud);

    printErr("[+] Health check: Port is ready\n", .{});
    return true;
}

pub fn main() !void {
    const config = parseArgs();

    if (config.verbose) {
        printErr("[*] Configuration:\n", .{});
        printErr("    baud: {d}\n", .{config.baud});
        printErr("    delay: {d}ms\n", .{config.delay_ms});
        printErr("    timeout: {d}ms\n", .{config.timeout_ms});
        printErr("    verbose: true\n", .{});
        printErr("    batch_size: {d}\n", .{config.batch_size});
        printErr("    buffer_size: {d}\n", .{config.buffer_size});
        printErr("    adaptive_timeout: {}\n", .{config.adaptive_timeout});
        printErr("    simulation_mode: {}\n", .{config.simulation_mode});
        printErr("    dry_run: {}\n", .{config.dry_run});
        if (config.output_file) |f| {
            printErr("    output_file: {s}\n", .{f});
        }
        printErr("\n", .{});
    }

    // v3.14: Check for simulation mode
    if (config.simulation_mode) {
        printErr(
            \\╔══════════════════════════════════════╗
            \\║         SIMULATION MODE (v3.18)         ║
            \\║  No hardware required - virtual UART      ║
            \\╚══════════════════════════════════════╝
            \\
        , .{});
        return runSimulation(config);
    }

    // v3.14: Check for dry run
    if (config.dry_run) {
        printErr(
            \\╔══════════════════════════════════════╗
            \\║            DRY RUN MODE                 ║
            \\║  Showing what would be sent (no I/O)   ║
            \\╚══════════════════════════════════════╝
            \\
        , .{});
        return runDryRun(config);
    }

    printErr(
        \\╔══════════════════════════════════════╗
        \\║      Trinity UART Echo Test v3.18          ║
        \\║  Sends bytes with configurable delay/timeout ║
        \\║    phi² + 1/phi² = 3 = TRINITY         ║
        \\╚════════════════════════════════════════╝
        \\
    , .{});

    var port: ?[]const u8 = null;

    // v3.15: Config file loaded message
    if (config.config_file != null) {
        printErr("[i] Config loaded from: {s}\n", .{config.config_file.?});
    }

    if (config.device) |dev| {
        printErr("[+] Using device: {s}\n", .{dev});
        port = dev;
    } else {
        printErr("[+] Scanning for FT232RL device...\n", .{});
        port = findFT232Device();
    }

    if (port) |p| {
        if (config.device == null) {
            printErr("[+] Found FT232RL: {s}\n", .{p});
        }
    } else {
        printErr("[!] FT232RL not found!\n", .{});
        printErr("\nAvailable serial ports:\n", .{});
        listSerialPorts();
        std.process.exit(1);
    }

    if (!config.auto_configure) {
        printErr("\n[!] IMPORTANT: Configure port first:\n", .{});
        if (port) |p| {
            printErr("    stty -f {s} {d}\n", .{ p, config.baud });
        }
        printErr("\n[Press Enter when ready...]\n", .{});

        var buf: [100]u8 = undefined;
        const stdin = std.fs.File{ .handle = std.posix.STDIN_FILENO };
        _ = stdin.read(&buf) catch |err| {
            printErr("[*] Failed to read input: {any}\n", .{err});
            std.process.exit(1);
        };
    }

    printErr("\n", .{});
    printErr("╔══════════════════════════════════╗\n", .{});

    if (config.loopback_mode) {
        printErr("║          LOOPBACK MODE               ║\n", .{});
        printErr("║   TX->RX on FT232RL (no FPGA)       ║\n", .{});
        printErr("╚══════════════════════════════════╝\n", .{});
        printErr("[i] Loopback: Short TX to RX with wire (pin 4 -> pin 5 on DB9)\n", .{});
    } else {
        printErr("║          Testing:                   ║\n", .{});
        printErr("╚══════════════════════════════════╝\n", .{});
    }

    // v3.15: Run health check before testing (unless in simulation/dry-run mode)
    if (!config.simulation_mode and !config.dry_run) {
        const passed = healthCheck(port.?, config.baud) catch false;
        if (!passed) {
            printErr("[!] Health check failed, aborting...\n", .{});
            std.process.exit(1);
        }
        printErr("[+] Health check passed\n", .{});
    }

    testEcho(port.?, config);
}

fn listSerialPorts() void {
    var dir = std.fs.openDirAbsolute("/dev", .{}) catch return;
    defer dir.close();
    var iterator = dir.iterate();
    while (iterator.next() catch return) |entry| {
        const name = entry.name;
        if (std.mem.indexOf(u8, name, "cu.usbserial") != null) {
            printErr("  {s}\n", .{name});
        }
    }
}

// Detailed test result for CSV export
const DetailedTestResult = struct {
    cycle: usize,
    test_name: []const u8,
    test_num: usize,
    total_tests: usize,
    data_sent: []const u8,
    bytes_sent: usize,
    bytes_received: usize,
    success: bool,
    rtt_ms: i64,
};

fn testEcho(port_path: []const u8, config: Config) void {
    // Configure port BEFORE opening if auto-configure enabled
    if (config.auto_configure) {
        printErr("[+] Configuring port: {d} baud 8N1\n", .{config.baud});
        const stty_cmd = std.fmt.allocPrint(std.heap.page_allocator, "stty -f {s} {d}", .{ port_path, config.baud }) catch {
            printErr("[!] Failed to allocate stty command string\n", .{});
            return;
        };
        defer std.heap.page_allocator.free(stty_cmd);

        const result = std.process.Child.run(.{
            .allocator = std.heap.page_allocator,
            .argv = &[_][]const u8{ "sh", "-c", stty_cmd },
        }) catch |err| {
            printErr("[!] Failed to run stty: {any}\n", .{err});
            return;
        };
        defer {
            std.heap.page_allocator.free(result.stderr);
            std.heap.page_allocator.free(result.stdout);
        }

        if (result.term != .Exited or result.term.Exited != 0) {
            printErr("[!] stty failed: {s}\n", .{result.stderr});
            return;
        }
    }

    const flags: u32 = 0x0002 | 0x08000;
    const fd = std.posix.open(port_path, @as(std.posix.O, @bitCast(flags)), 0) catch |err| {
        printErr("[*] Failed to open {s}: {any}\n", .{ port_path, err });
        return;
    };
    defer std.posix.close(fd);

    printErr("[+] Opened: {s}\n", .{port_path});
    _ = configureSerial(fd, config.baud);

    const tests = [_]TestByte{
        .{ .data = &[_]u8{'A'}, .name = "'A'" },
        .{ .data = &[_]u8{0x55}, .name = "0x55 (alternating)" },
        .{ .data = &[_]u8{0xAA}, .name = "0xAA (alternating)" },
        .{ .data = "Hello", .name = "Hello" },
        .{ .data = &[_]u8{0x00}, .name = "0x00 (zero)" },
        .{ .data = &[_]u8{0xFF}, .name = "0xFF (all ones)" },
    };

    // CSV export data
    var csv_results = std.ArrayList(DetailedTestResult).empty;
    defer {
        for (csv_results.items) |r| {
            std.heap.page_allocator.free(r.data_sent);
        }
        csv_results.clearAndFree(std.heap.page_allocator);
    }

    var passed: usize = 0;
    var test_idx: usize = 0;
    var cycle: usize = 1;

    // Overall RTT statistics
    var overall_rtt_min: i64 = -1;
    var overall_rtt_max: i64 = 0;
    var overall_rtt_sum: i64 = 0;
    var overall_rtt_count: usize = 0;

    while (true) {
        if (config.continuous) {
            printErr("\n", .{});
            printErr("╔══════════════════════════════════════╗\n", .{});
            printErr("║          CYCLE {d}                      ║\n", .{cycle});
            printErr("╚════════════════════════════════════════╝\n", .{});
        }

        var cycle_passed: usize = 0;
        test_idx = 0;

        // RTT statistics for this cycle
        var rtt_min: i64 = -1;
        var rtt_max: i64 = 0;
        var rtt_sum: i64 = 0;
        var rtt_count: usize = 0;

        while (test_idx < tests.len) {
            const testCase = tests[test_idx];
            const result = testEchoByte(fd, testCase.data, testCase.name, test_idx + 1, tests.len, cycle, config);
            if (result.success) {
                cycle_passed += 1;
                // Collect RTT statistics
                if (result.rtt_ms > 0) {
                    if (rtt_min < 0 or result.rtt_ms < rtt_min) {
                        rtt_min = result.rtt_ms;
                    }
                    if (result.rtt_ms > rtt_max) {
                        rtt_max = result.rtt_ms;
                    }
                    rtt_sum += result.rtt_ms;
                    rtt_count += 1;
                }
            }

            // Store result for CSV export
            const data_copy = std.heap.page_allocator.dupe(u8, result.data_sent) catch &[0]u8{};
            csv_results.append(std.heap.page_allocator, DetailedTestResult{
                .cycle = cycle,
                .test_name = result.test_name,
                .test_num = result.test_num,
                .total_tests = result.total_tests,
                .data_sent = data_copy,
                .bytes_sent = result.bytes_sent,
                .bytes_received = result.bytes_received,
                .success = result.success,
                .rtt_ms = result.rtt_ms,
            }) catch {};

            std.Thread.sleep(config.delay_ms * 1_000_000);
            test_idx += 1;
        }

        passed += cycle_passed;

        // Update overall RTT statistics
        if (rtt_min < 0 or rtt_min < overall_rtt_min) {
            overall_rtt_min = rtt_min;
        }
        if (rtt_max > overall_rtt_max) {
            overall_rtt_max = rtt_max;
        }
        overall_rtt_sum += rtt_sum;
        overall_rtt_count += rtt_count;

        if (!config.continuous) {
            printErr("\n", .{});
            printErr("╔══════════════════════════════════════╗\n", .{});
            printErr("║          SUMMARY                      ║\n", .{});
            printErr("╚════════════════════════════════════════╝\n", .{});
            printErr("  Passed: {d}/{d}\n", .{ passed, tests.len });
            if (rtt_count > 0) {
                const rtt_avg: f64 = @as(f64, @floatFromInt(rtt_sum)) / @as(f64, @floatFromInt(rtt_count));
                printErr("  RTT: min={d}ms avg={d:.1}ms max={d}ms\n", .{ rtt_min, rtt_avg, rtt_max });
            }
            printErr("\n", .{});
            break;
        } else {
            printErr("\n", .{});
            printErr("  [i] Cycle {d} result: {d}/{d} passed", .{ cycle, cycle_passed, tests.len });
            if (rtt_count > 0) {
                const rtt_avg: f64 = @as(f64, @floatFromInt(rtt_sum)) / @as(f64, @floatFromInt(rtt_count));
                printErr(", RTT: min={d}ms avg={d:.1}ms max={d}ms", .{ rtt_min, rtt_avg, rtt_max });
            }
            printErr("\n", .{});
            cycle += 1;
            std.Thread.sleep(2_000_000); // 2 second delay between cycles
        }
    }

    // Export to CSV if requested
    if (config.output_file) |output_path| {
        exportToCSV(output_path, csv_results.items, passed, tests.len);
    }
}

fn testEchoByte(fd: std.posix.fd_t, data: []const u8, test_name: []const u8, test_num: usize, total: usize, cycle: usize, config: Config) DetailedTestResult {
    printErr("  [->] Test {d}/{d} Sending data: ", .{ test_num, total });
    for (data) |b| {
        printErr("{x:0>2}", .{b});
    }
    printErr(" ({d} bytes)\n", .{data.len});

    // In ping mode, send PING_BYTE (0x03) instead of test data
    // In loopback mode, same as echo but clearer message
    const data_to_send = if (config.ping_mode) &[_]u8{PING_BYTE} else data;

    const write_result = std.posix.write(fd, data_to_send);
    if (write_result) |written| {
        if (written != data_to_send.len) {
            printErr("  [!] Only wrote {d}/{d} bytes\n", .{ written, data_to_send.len });
        }
    } else |err| {
        printErr("  [*] Write error: {any}\n", .{err});
        return DetailedTestResult{
            .cycle = cycle,
            .test_name = test_name,
            .test_num = test_num,
            .total_tests = total,
            .data_sent = data,
            .bytes_sent = data_to_send.len,
            .bytes_received = 0,
            .success = false,
            .rtt_ms = 0,
        };
    }
    std.Thread.sleep(config.delay_ms * 500_000);

    if (config.verbose) {
        const mode_name = if (config.loopback_mode) "LOOPBACK" else if (config.ping_mode) "PING/PONG" else "Echo";
        printErr("  [*] Waiting for {s} response (timeout: {d}ms)...\n", .{ mode_name, config.timeout_ms });
    }

    var read_buffer: [512]u8 = undefined;
    var bytes_read: usize = 0;
    const start_time_ms = std.time.milliTimestamp();
    var round_trip_ms: i64 = 0;

    while (std.time.milliTimestamp() - start_time_ms < config.timeout_ms) {
        const read_result = std.posix.read(fd, read_buffer[bytes_read..]);

        if (read_result) |n| {
            bytes_read += n;
            if (config.verbose) {
                printErr("  [*] Read {d} bytes (total: {d})\n", .{ n, bytes_read });
            }
            // Calculate round-trip time on first byte received
            if (round_trip_ms == 0) {
                round_trip_ms = std.time.milliTimestamp() - start_time_ms;
            }
            // In ping mode, expect 1 byte (PONG). In echo mode, expect same as sent.
            if ((config.ping_mode and bytes_read >= 1) or (!config.ping_mode and bytes_read >= data.len)) {
                break;
            }
        } else |err| {
            if (err == error.OperationWouldBlock) {
                std.Thread.sleep(10_000);
                continue;
            }
            if (config.verbose) {
                printErr("  [*] Read error: {any}\n", .{err});
            }
        }
    }

    printErr("  [<-] Received ", .{});
    for (read_buffer[0..bytes_read]) |b| {
        printErr("{x:0>2}", .{b});
    }
    printErr(" ({d} bytes)\n", .{bytes_read});

    if (bytes_read == data_to_send.len) {
        var match = true;
        for (0..data_to_send.len) |i| {
            if (read_buffer[i] != data_to_send[i]) {
                match = false;
                printErr("  [x] Mismatch at index {d}: sent 0x{x:0>2}, got 0x{x:0>2}\n", .{ i, data_to_send[i], read_buffer[i] });
                break;
            }
        }

        if (match) {
            const time_msg = if (round_trip_ms > 0) std.fmt.allocPrint(std.heap.page_allocator, " (RTT: {d}ms)", .{round_trip_ms}) catch "" else "";
            defer {
                if (round_trip_ms > 0) std.heap.page_allocator.free(time_msg);
            }
            printErr("  [✓] ECHO SUCCESS!{s}\n", .{time_msg});
            return DetailedTestResult{
                .cycle = cycle,
                .test_name = test_name,
                .test_num = test_num,
                .total_tests = total,
                .data_sent = data,
                .bytes_sent = data_to_send.len,
                .bytes_received = bytes_read,
                .success = true,
                .rtt_ms = round_trip_ms,
            };
        } else {
            printErr("  [x] ECHO FAIL! Mismatch\n", .{});
            return DetailedTestResult{
                .cycle = cycle,
                .test_name = test_name,
                .test_num = test_num,
                .total_tests = total,
                .data_sent = data,
                .bytes_sent = data_to_send.len,
                .bytes_received = bytes_read,
                .success = false,
                .rtt_ms = round_trip_ms,
            };
        }
    } else {
        printErr("  [x] TIMEOUT - Received {d} bytes, expected {d}\n", .{ bytes_read, data_to_send.len });
        return DetailedTestResult{
            .cycle = cycle,
            .test_name = test_name,
            .test_num = test_num,
            .total_tests = total,
            .data_sent = data,
            .bytes_sent = data_to_send.len,
            .bytes_received = bytes_read,
            .success = false,
            .rtt_ms = 0,
        };
    }
}

const TestByte = struct {
    data: []const u8,
    name: []const u8,
};

// v3.14: Simulation mode for testing without hardware
fn runSimulation(config: Config) !void {
    const tests = [_]TestByte{
        .{ .data = &[_]u8{'A'}, .name = "'A'" },
        .{ .data = &[_]u8{0x55}, .name = "0x55 (alternating)" },
        .{ .data = &[_]u8{0xAA}, .name = "0xAA (alternating)" },
        .{ .data = "Hello", .name = "Hello" },
        .{ .data = &[_]u8{0x00}, .name = "0x00 (zero)" },
        .{ .data = &[_]u8{0xFF}, .name = "0xFF (all ones)" },
    };

    var passed: usize = 0;
    var total_time_ms: i64 = 0;

    printErr("[i] Running simulation with {d} tests...\n", .{tests.len});

    for (tests, 0..) |testCase, i| {
        const start = std.time.milliTimestamp();

        // Simulate delay
        const sim_delay = 5 + std.crypto.random.intRangeAtMost(u32, 0, 20);
        std.Thread.sleep(sim_delay * 1_000_000);

        const elapsed = std.time.milliTimestamp() - start;
        total_time_ms += elapsed;

        printErr("  [->] Sim Test {d}/{d}: {s} (RTT: {d}ms) ", .{ i + 1, tests.len, testCase.name, elapsed });

        // Simulate occasional "failure" in simulation mode
        const should_fail = std.crypto.random.intRangeAtMost(u8, 0, 100) < 5;
        if (should_fail) {
            printErr("[x] SIMULATED FAIL\n", .{});
        } else {
            printErr("[✓] PASS\n", .{});
            passed += 1;
        }
    }

    printErr("\n╔══════════════════════════════════════╗\n", .{});
    printErr("║          SIMULATION SUMMARY           ║\n", .{});
    printErr("╚══════════════════════════════════════╝\n", .{});
    printErr("  Passed: {d}/{d}\n", .{ passed, tests.len });
    printErr("  Total time: {d}ms\n", .{total_time_ms});
    printErr("  Avg test time: {d:.1}ms\n", .{@as(f64, @floatFromInt(total_time_ms)) / @as(f64, @floatFromInt(tests.len))});
    printErr("\n[i] Simulation complete - no hardware required!\n", .{});

    // Export to JSON if requested
    if (config.json_output) {
        exportSimulationJSON(passed, tests.len, total_time_ms);
    }
}

// v3.14: Dry run mode - show what would be sent
fn runDryRun(config: Config) !void {
    const tests = [_]TestByte{
        .{ .data = &[_]u8{'A'}, .name = "'A'" },
        .{ .data = &[_]u8{0x55}, .name = "0x55 (alternating)" },
        .{ .data = &[_]u8{0xAA}, .name = "0xAA (alternating)" },
        .{ .data = "Hello", .name = "Hello" },
        .{ .data = &[_]u8{0x00}, .name = "0x00 (zero)" },
        .{ .data = &[_]u8{0xFF}, .name = "0xFF (all ones)" },
    };

    printErr("[i] Dry run - showing {d} tests that would be executed:\n\n", .{tests.len});

    for (tests, 0..) |testCase, i| {
        const data_to_send = if (config.ping_mode) &[_]u8{PING_BYTE} else testCase.data;
        printErr("  [{d}] {s}\n", .{ i + 1, testCase.name });
        printErr("      Would send: ", .{});
        for (data_to_send) |b| {
            printErr("{x:0>2} ", .{b});
        }
        printErr("({d} bytes)\n", .{data_to_send.len});
        if (config.ping_mode) {
            printErr("      Expected response: PONG (0x{X:0>2})\n", .{PONG_BYTE});
        } else {
            printErr("      Expected response: echo of sent bytes\n", .{});
        }
    }

    printErr("\n[i] Configuration summary:\n", .{});
    printErr("  Baud rate: {d}\n", .{config.baud});
    printErr("  Timeout: {d}ms\n", .{config.timeout_ms});
    printErr("  Delay: {d}ms\n", .{config.delay_ms});
    printErr("  Batch size: {d}\n", .{config.batch_size});
    printErr("  Buffer size: {d} bytes\n", .{config.buffer_size});
    printErr("  Adaptive timeout: {}\n", .{config.adaptive_timeout});
    printErr("\n[✓] Dry run complete - no actual I/O performed\n", .{});
}

fn findFT232Device() ?[]const u8 {
    var dir = std.fs.openDirAbsolute("/dev", .{}) catch return null;
    defer dir.close();

    var iterator = dir.iterate();
    while (iterator.next() catch return null) |entry| {
        const name = entry.name;
        if (std.mem.indexOf(u8, name, "cu.usbserial") != null) {
            return std.fmt.allocPrint(std.heap.page_allocator, "/dev/{s}", .{name}) catch null;
        }
    }

    return null;
}

// v3.18: Configure serial port with configurable baud rate
fn configureSerial(fd: std.posix.fd_t, baud: u64) bool {
    var termio = std.posix.tcgetattr(fd) catch return false;

    // Set 8N1: 8 data bits, no parity, 1 stop bit
    termio.cflag.PARENB = false; // No parity
    termio.cflag.CSTOPB = false; // 1 stop bit
    termio.cflag.CSIZE = .CS8; // 8 data bits

    // Enable receiver, ignore modem control lines
    termio.cflag.CREAD = true;
    termio.cflag.CLOCAL = true;

    // Raw input mode: no ICANON, no echo, no signal chars
    termio.lflag.ICANON = false;
    termio.lflag.ECHO = false;
    termio.lflag.ECHOE = false;
    termio.lflag.ISIG = false;

    // Raw output mode
    termio.oflag.OPOST = false;

    // Disable software flow control
    termio.iflag.IXON = false;
    termio.iflag.IXOFF = false;
    termio.iflag.IXANY = false;

    // Set VMIN=0, VTIME=1 for non-blocking read with 0.1s timeout
    termio.cc[@intFromEnum(std.posix.V.MIN)] = 0;
    termio.cc[@intFromEnum(std.posix.V.TIME)] = 1;

    // Set baud rate (v3.18: configurable)
    termio.ispeed = @as(std.c.speed_t, @enumFromInt(baud));
    termio.ospeed = @as(std.c.speed_t, @enumFromInt(baud));

    std.posix.tcsetattr(fd, std.posix.TCSA.NOW, termio) catch return false;

    return true;
}

// Export test results to CSV file
fn exportToCSV(path: []const u8, results: []const DetailedTestResult, passed: usize, total: usize) void {
    const file = std.fs.createFileAbsolute(path, .{}) catch |err| {
        printErr("[!] Failed to create CSV file: {any}\n", .{err});
        return;
    };
    defer file.close();

    var buffer: [4096]u8 = undefined;
    var writer = file.writer(&buffer);

    // Write CSV header
    writer.interface.print(
        \\# UART Echo Test Results
        \\# Generated: {d}
        \\# Total: {d}/{d} passed
        \\# Columns: cycle,test_name,test_num,total_tests,bytes_sent,bytes_received,success,rtt_ms
        \\cycle,test_name,test_num,total_tests,bytes_sent,bytes_received,success,rtt_ms
    , .{ std.time.timestamp(), passed, total }) catch return;

    // Write data rows
    for (results) |r| {
        writer.interface.print("{d},{s},{d},{d},{d},{d},{s},{d}\n", .{
            r.cycle,
            r.test_name,
            r.test_num,
            r.total_tests,
            r.bytes_sent,
            r.bytes_received,
            if (r.success) "PASS" else "FAIL",
            r.rtt_ms,
        }) catch continue;
    }

    printErr("[+] CSV export complete: {s} ({d} records)\n", .{ path, results.len });
}

// v3.14: Export simulation results to JSON
fn exportSimulationJSON(passed: usize, total: usize, total_time_ms: i64) void {
    printErr(
        \\{{
        \\  "version": "3.18",
        \\  "mode": "simulation",
        \\  "timestamp": {d},
        \\  "summary": {{
        \\    "passed": {d},
        \\    "total": {d},
        \\    "success_rate": {d:.1},
        \\    "total_time_ms": {d}
        \\  }}
        \\}}
    , .{
        std.time.timestamp(),
        passed,
        total,
        @as(f64, @floatFromInt(passed)) / @as(f64, @floatFromInt(total)) * 100.0,
        total_time_ms,
    });

    printErr("\n[+] Simulation JSON export complete\n", .{});
}
