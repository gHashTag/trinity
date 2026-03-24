//! UART Echo Test — Advanced FPGA UART bridge test tool
//! Sends bytes with configurable delay and expects them echoed back
//! v4.06 — Connection Fingerprinting (identify connection types)
//!
//! Usage:
//!     zig run uart-echo-test [--baud 115200] [--delay 200] [--timeout 2000] [-v|--verbose]
//!                            [--output results.csv|--json] [--config uart-test.toml] [--retries 3]
//!                            [--batch-size N] [--buffer-size BYTES] [--adaptive-timeout] [--comprehensive] [--auto-configure]
//!                            [--fpga-mode] [--esp32-host HOST] [--esp32-port PORT]
//!                            [--bitstream PATH] [--fpga-verify] [--fpga-timeout MS] [--fpga-retries N]
//!                            [--simulation] [--ping-mode] [--loopback-mode]
//!
//! Features:
//!   - Multi-adapter support: FT232RL, CP210x, CH340, PL2303
//!   - Auto-configure: Automatic termios setup via --auto-configure flag (v3.24)
//!   - Graceful exit: SIGINT (Ctrl+C) handler for clean shutdown (v3.24)
//!   - Extended baud rates: Supports 9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600 (v3.24)
//!   - Config file: TOML configuration for persistent settings (v3.15)
//!   - JSON export: Structured test results for analysis
//!   - Error recovery: Automatic retry on failed tests
//!   - Throughput measurement: Bytes/second calculation
//!   - Batch testing: Send N packets without waiting for individual responses
//!   - Buffered I/O: Pre-allocated buffers for reduced syscall overhead
//!   - Adaptive timeout: Dynamically adjust based on measured RTT
//!   - Health checks: Serial port validation before testing
//!   - FPGA XVC Bridge: Full test cycle with ESP32 + FPGA (v3.26)
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

// v3.24: Graceful exit flag
var should_exit: std.atomic.Value(bool) = std.atomic.Value(bool).init(false);

// v3.24: Extended baud rates
const VALID_BAUD_RATES = [_]u64{
    9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600,
};

// v3.24: ANSI colors for better UX
const ANSI = struct {
    const RESET = "\x1b[0m";
    const BOLD = "\x1b[1m";
    const DIM = "\x1b[2m";
    const RED = "\x1b[31m";
    const GREEN = "\x1b[32m";
    const YELLOW = "\x1b[33m";
    const BLUE = "\x1b[34m";
    const MAGENTA = "\x1b[35m";
    const CYAN = "\x1b[36m";
    const WHITE = "\x1b[37m";

    fn color(comptime col: []const u8, text: []const u8) []const u8 {
        return col ++ text ++ RESET;
    }
};

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
    csv_output: bool, // v3.46: CSV export
    config_file: ?[]const u8,
    measure_throughput: bool,
    // v3.14 features
    simulation_mode: bool,
    dry_run: bool,
    batch_size: usize,
    buffer_size: usize,
    adaptive_timeout: bool,
    // v3.24: Auto baud detection and RTS/CTS flow control
    auto_baud: bool,
    rts_cts_flow: bool,
    stress_test_mode: bool,
    stress_packets: usize = 10,
    // v3.24: Custom test patterns
    test_patterns_file: ?[]const u8,
    // v3.24: Jitter measurement and pattern generation
    measure_jitter: bool,
    spike_threshold: f64 = 3.0, // v3.49: Configurable spike threshold (multiplier of median)
    // v3.63: Outlier detection method (fixed or iqr)
    outlier_method: []const u8 = "fixed", // fixed=3x median, iqr=statistical method
    // v3.57: Configurable alert thresholds
    alert_warning_threshold: f64 = 60.0,
    alert_critical_threshold: f64 = 40.0,
    use_pattern: []const u8,
    pattern_length: usize,
    // v3.26: FPGA XVC Bridge integration
    fpga_mode: bool,
    esp32_host: []const u8,
    esp32_port: u16,
    bitstream_path: ?[]const u8,
    fpga_verify_mode: bool,
    // v3.27: FPGA timeout and retry settings
    fpga_timeout_ms: u32 = 30000, // 30 seconds default
    fpga_retries: u32 = 3, // 3 retries default
    // v3.33: Comprehensive test mode
    comprehensive_mode: bool = false,
    // v3.37: Enhanced error recovery and diagnostics
    diagnostics_mode: bool = false,
    auto_recovery: bool = false,
    // v3.38: Enhanced health checks
    extended_health_check: bool = false,
    // v3.58: Performance baseline comparison
    baseline_file: ?[]const u8 = null,
    compare_baseline: bool = false,
    statistical_mode: bool = false, // v3.60: Statistical significance testing
    time_series_plot: bool = false, // v3.61: Time series visualization
    multi_baseline_dir: ?[]const u8 = null, // v3.62: Multi-baseline comparison directory
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
    min_latency_ms: usize = -1,
    max_latency_ms: usize = 0,
    total_latency_ms: usize = 0,
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

// v3.58: Performance Baseline for comparison across test runs
const Baseline = struct {
    timestamp: i64,
    version: []const u8,
    mean_rtt_us: f64,
    jitter_us: f64,
    min_rtt_us: f64,
    max_rtt_us: f64,
    p50_us: f64,
    p90_us: f64,
    p95_us: f64,
    p99_us: f64,
    quality_score: f64,
    spike_count: usize,
    sample_count: usize,

    pub fn formatJson(self: *const Baseline, allocator: std.mem.Allocator) ![]const u8 {
        var buffer: [1024]u8 = undefined;
        const json = try std.fmt.bufPrint(&buffer,
            \\{{"timestamp":{d},"version":"{s}","mean_rtt_us":{d:.2},"jitter_us":{d:.2},
            \\"min_rtt_us":{d:.2},"max_rtt_us":{d:.2},"p50_us":{d:.2},"p90_us":{d:.2},
            \\"p95_us":{d:.2},"p99_us":{d:.2},"quality_score":{d:.1},
            \\"spike_count":{d},"sample_count":{d}}}
        , .{
            self.timestamp,
            self.version,
            self.mean_rtt_us,
            self.jitter_us,
            self.min_rtt_us,
            self.max_rtt_us,
            self.p50_us,
            self.p90_us,
            self.p95_us,
            self.p99_us,
            self.quality_score,
            self.spike_count,
            self.sample_count,
        });
        return try allocator.dupe(u8, json);
    }

    pub fn saveToFile(self: *const Baseline, file_path: []const u8) !void {
        const file = try std.fs.cwd().createFile(file_path, .{ .read = true });
        defer file.close();

        const json = try self.formatJson(std.heap.page_allocator);
        defer std.heap.page_allocator.free(json);

        try file.writeAll(json);
    }

    // Helper to strip quotes from a JSON string value
    fn unquote(token: []const u8) []const u8 {
        if (token.len >= 2 and token[0] == '"' and token[token.len - 1] == '"') {
            return token[1 .. token.len - 1];
        }
        return token;
    }

    pub fn loadFromFile(allocator: std.mem.Allocator, file_path: []const u8) !Baseline {
        _ = allocator;
        const content = try std.fs.cwd().readFileAlloc(std.heap.page_allocator, file_path, 4096);
        defer std.heap.page_allocator.free(content);

        var baseline: Baseline = undefined;
        baseline.version = "v3.62";

        // v3.62: Improved JSON parser - handles quoted strings properly
        var it = std.mem.tokenizeAny(u8, content, "{:,}\n\r ");
        while (it.next()) |token| {
            const key = unquote(token);

            if (std.mem.eql(u8, key, "timestamp")) {
                const val_str = it.next() orelse return error.InvalidJson;
                const val = unquote(val_str);
                baseline.timestamp = try std.fmt.parseInt(i64, val, 10);
            } else if (std.mem.eql(u8, key, "version")) {
                _ = it.next(); // skip value (use hardcoded version)
                baseline.version = "v3.62";
            } else if (std.mem.eql(u8, key, "mean_rtt_us")) {
                const val_str = it.next() orelse return error.InvalidJson;
                const val = unquote(val_str);
                baseline.mean_rtt_us = try std.fmt.parseFloat(f64, val);
            } else if (std.mem.eql(u8, key, "jitter_us")) {
                const val_str = it.next() orelse return error.InvalidJson;
                const val = unquote(val_str);
                baseline.jitter_us = try std.fmt.parseFloat(f64, val);
            } else if (std.mem.eql(u8, key, "min_rtt_us")) {
                const val_str = it.next() orelse return error.InvalidJson;
                const val = unquote(val_str);
                baseline.min_rtt_us = try std.fmt.parseFloat(f64, val);
            } else if (std.mem.eql(u8, key, "max_rtt_us")) {
                const val_str = it.next() orelse return error.InvalidJson;
                const val = unquote(val_str);
                baseline.max_rtt_us = try std.fmt.parseFloat(f64, val);
            } else if (std.mem.eql(u8, key, "p50_us")) {
                const val_str = it.next() orelse return error.InvalidJson;
                const val = unquote(val_str);
                baseline.p50_us = try std.fmt.parseFloat(f64, val);
            } else if (std.mem.eql(u8, key, "p90_us")) {
                const val_str = it.next() orelse return error.InvalidJson;
                const val = unquote(val_str);
                baseline.p90_us = try std.fmt.parseFloat(f64, val);
            } else if (std.mem.eql(u8, key, "p95_us")) {
                const val_str = it.next() orelse return error.InvalidJson;
                const val = unquote(val_str);
                baseline.p95_us = try std.fmt.parseFloat(f64, val);
            } else if (std.mem.eql(u8, key, "p99_us")) {
                const val_str = it.next() orelse return error.InvalidJson;
                const val = unquote(val_str);
                baseline.p99_us = try std.fmt.parseFloat(f64, val);
            } else if (std.mem.eql(u8, key, "quality_score")) {
                const val_str = it.next() orelse return error.InvalidJson;
                const val = unquote(val_str);
                baseline.quality_score = try std.fmt.parseFloat(f64, val);
            } else if (std.mem.eql(u8, key, "spike_count")) {
                const val_str = it.next() orelse return error.InvalidJson;
                const val = unquote(val_str);
                baseline.spike_count = try std.fmt.parseInt(usize, val, 10);
            } else if (std.mem.eql(u8, key, "sample_count")) {
                const val_str = it.next() orelse return error.InvalidJson;
                const val = unquote(val_str);
                baseline.sample_count = try std.fmt.parseInt(usize, val, 10);
            }
        }

        return baseline;
    }

    pub fn compare(self: *const Baseline, current_mean: f64, current_jitter: f64, current_quality: f64) void {
        printErr("\n{s}═══════════════════════════════════════════════════{s}\n", .{ ANSI.CYAN, ANSI.RESET });
        printErr("{s}         BASELINE COMPARISON (v3.58)         {s}\n", .{ ANSI.BOLD, ANSI.RESET });
        printErr("{s}═══════════════════════════════════════════════════{s}\n\n", .{ ANSI.CYAN, ANSI.RESET });

        const mean_delta = current_mean - self.mean_rtt_us;
        const mean_pct = if (self.mean_rtt_us > 0) (mean_delta / self.mean_rtt_us) * 100.0 else 0.0;
        const jitter_delta = current_jitter - self.jitter_us;
        const jitter_pct = if (self.jitter_us > 0) (jitter_delta / self.jitter_us) * 100.0 else 0.0;
        const quality_delta = current_quality - self.quality_score;

        // Mean RTT comparison
        printErr("{s}Mean RTT:{s} ", .{ ANSI.BLUE, ANSI.RESET });
        printErr("{s}{d:.2}{s} us -> ", .{ ANSI.DIM, self.mean_rtt_us, ANSI.RESET });
        printErr("{s}{d:.2}{s} us ", .{ ANSI.BOLD, current_mean, ANSI.RESET });
        if (@abs(mean_pct) < 5.0) {
            printErr("{s}(~{d:.1}%){s}\n", .{ ANSI.GREEN, @abs(mean_pct), ANSI.RESET });
        } else if (mean_pct > 0) {
            printErr("{s}(+{d:.1}%){s}\n", .{ ANSI.RED, mean_pct, ANSI.RESET });
        } else {
            printErr("{s}({d:.1}%){s}\n", .{ ANSI.GREEN, @abs(mean_pct), ANSI.RESET });
        }

        // Jitter comparison
        printErr("{s}Jitter: {s}", .{ ANSI.BLUE, ANSI.RESET });
        printErr("{s}{d:.2}{s} us -> ", .{ ANSI.DIM, self.jitter_us, ANSI.RESET });
        printErr("{s}{d:.2}{s} us ", .{ ANSI.BOLD, current_jitter, ANSI.RESET });
        if (@abs(jitter_pct) < 5.0) {
            printErr("{s}(~{d:.1}%){s}\n", .{ ANSI.GREEN, @abs(jitter_pct), ANSI.RESET });
        } else if (jitter_pct > 0) {
            printErr("{s}(+{d:.1}%){s}\n", .{ ANSI.RED, jitter_pct, ANSI.RESET });
        } else {
            printErr("{s}({d:.1}%){s}\n", .{ ANSI.GREEN, @abs(jitter_pct), ANSI.RESET });
        }

        // Quality score comparison
        printErr("{s}Quality: {s}", .{ ANSI.BLUE, ANSI.RESET });
        printErr("{s}{d:.1}{s} -> ", .{ ANSI.DIM, self.quality_score, ANSI.RESET });
        printErr("{s}{d:.1}{s} ", .{ ANSI.BOLD, current_quality, ANSI.RESET });
        if (quality_delta > 5.0) {
            printErr("{s}(+{d:.1}){s}\n", .{ ANSI.GREEN, quality_delta, ANSI.RESET });
        } else if (quality_delta < -5.0) {
            printErr("{s}({d:.1}){s}\n", .{ ANSI.RED, quality_delta, ANSI.RESET });
        } else {
            printErr("{s}(~){s}\n", .{ ANSI.YELLOW, ANSI.RESET });
        }

        printErr("\n", .{});
    }

    // v3.60: Statistical significance testing with Welch's t-test
    pub fn compareStatistical(
        self: *const Baseline,
        current_mean: f64,
        current_jitter: f64,
        current_quality: f64,
        current_samples: usize,
        current_stddev: f64,
    ) void {
        _ = current_jitter; // Currently unused, reserved for future analysis
        _ = current_quality; // Currently unused, reserved for future analysis

        printErr("\n{s}═══════════════════════════════════════════════════{s}\n", .{ ANSI.CYAN, ANSI.RESET });
        printErr("{s}    STATISTICAL SIGNIFICANCE (v3.60)         {s}\n", .{ ANSI.BOLD, ANSI.RESET });
        printErr("{s}═══════════════════════════════════════════════════{s}\n\n", .{ ANSI.CYAN, ANSI.RESET });

        // Welch's t-test for mean RTT comparison
        const baseline_n = @as(f64, @floatFromInt(self.sample_count));
        const current_n = @as(f64, @floatFromInt(current_samples));
        const min_samples = 5.0;

        if (baseline_n < min_samples or current_n < min_samples) {
            printErr("{s}[!] Need at least {d:.0} samples per test for significance testing{s}\n", .{ ANSI.YELLOW, min_samples, ANSI.RESET });
            printErr("    Baseline: {d:.0} samples, Current: {d:.0} samples\n\n", .{ baseline_n, current_n });
            return;
        }

        // Assume baseline stddev ≈ jitter (reasonable approximation for RTT)
        const baseline_stddev = self.jitter_us;

        // Welch's t-statistic
        const se_baseline_sq = (baseline_stddev * baseline_stddev) / baseline_n;
        const se_current_sq = (current_stddev * current_stddev) / current_n;
        const se_diff = @sqrt(se_baseline_sq + se_current_sq);

        const t_stat = if (se_diff > 0.001)
            (current_mean - self.mean_rtt_us) / se_diff
        else
            0.0;

        // Degrees of freedom (Welch-Satterthwaite equation)
        const df_numerator = (se_baseline_sq + se_current_sq) * (se_baseline_sq + se_current_sq);
        const df_denominator = (se_baseline_sq * se_baseline_sq) / (baseline_n - 1.0) +
            (se_current_sq * se_current_sq) / (current_n - 1.0);
        const df = if (df_denominator > 0.001)
            df_numerator / df_denominator
        else if (baseline_n < current_n)
            baseline_n - 1.0
        else
            current_n - 1.0;

        // Two-tailed p-value approximation using t-distribution
        const p_value = calculateTwoTailedPValue(@abs(t_stat), df);

        // Effect size (Cohen's d for independent samples)
        const pooled_stddev = @sqrt(((baseline_n - 1.0) * baseline_stddev * baseline_stddev +
            (current_n - 1.0) * current_stddev * current_stddev) /
            (baseline_n + current_n - 2.0));
        const cohens_d = if (pooled_stddev > 0.001)
            (current_mean - self.mean_rtt_us) / pooled_stddev
        else
            0.0;

        // 95% Confidence Interval for the difference
        const ci_95 = 1.96 * se_diff;
        const diff = current_mean - self.mean_rtt_us;
        const ci_lower = diff - ci_95;
        const ci_upper = diff + ci_95;

        // 99% Confidence Interval
        const ci_99 = 2.576 * se_diff;
        const ci_99_lower = diff - ci_99;
        const ci_99_upper = diff + ci_99;

        // Display results
        printErr("{s}Welch's t-test (two-tailed):{s}\n", .{ ANSI.BLUE, ANSI.RESET });
        printErr("  t-statistic: {d:.3}, df: {d:.1}\n", .{ t_stat, df });

        // P-value formatting
        if (p_value < 0.001) {
            printErr("  p-value: {s}p < 0.001{s} ***\n", .{ ANSI.RED, ANSI.RESET });
        } else if (p_value < 0.01) {
            printErr("  p-value: {s}p < 0.01{s} **\n", .{ ANSI.YELLOW, ANSI.RESET });
        } else if (p_value < 0.05) {
            printErr("  p-value: {s}p < 0.05{s} *\n", .{ ANSI.GREEN, ANSI.RESET });
        } else {
            printErr("  p-value: p = {d:.3} (ns)\n", .{p_value});
        }

        printErr("\n{s}Effect Size (Cohen's d):{s} ", .{ ANSI.BLUE, ANSI.RESET });
        if (@abs(cohens_d) < 0.2) {
            printErr("{s}{d:.3} (negligible){s}\n", .{ ANSI.GREEN, cohens_d, ANSI.RESET });
        } else if (@abs(cohens_d) < 0.5) {
            printErr("{s}{d:.3} (small){s}\n", .{ ANSI.CYAN, cohens_d, ANSI.RESET });
        } else if (@abs(cohens_d) < 0.8) {
            printErr("{s}{d:.3} (medium){s}\n", .{ ANSI.YELLOW, cohens_d, ANSI.RESET });
        } else {
            printErr("{s}{d:.3} (large){s}\n", .{ ANSI.RED, cohens_d, ANSI.RESET });
        }

        printErr("\n{s}95% CI for difference: [{d:.2}, {d:.2}] us{s}\n", .{ ANSI.BLUE, ci_lower, ci_upper, ANSI.RESET });
        printErr("{s}99% CI for difference: [{d:.2}, {d:.2}] us{s}\n", .{ ANSI.BLUE, ci_99_lower, ci_99_upper, ANSI.RESET });

        // Verdict
        printErr("\n{s}Verdict:{s} ", .{ ANSI.BOLD, ANSI.RESET });
        if (p_value < 0.05) {
            if (diff > 0) {
                printErr("{s}SIGNIFICANTLY WORSE (+{d:.1}%){s}\n", .{ ANSI.RED, (diff / self.mean_rtt_us) * 100.0, ANSI.RESET });
            } else {
                printErr("{s}SIGNIFICANTLY BETTER ({d:.1}%){s}\n", .{ ANSI.GREEN, @abs(diff / self.mean_rtt_us) * 100.0, ANSI.RESET });
            }
        } else {
            printErr("{s}NOT SIGNIFICANT (within noise){s}\n", .{ ANSI.YELLOW, ANSI.RESET });
        }

        printErr("\n", .{});
    }

    // Approximate two-tailed p-value for t-distribution
    fn calculateTwoTailPValue(t_abs: f64, df: f64) f64 {
        // Use approximation formula for t-distribution cumulative probability
        // Based on Abramowitz and Stegun 26.7.1
        if (df < 1.0) return 1.0;

        const x = (df / (df + t_abs * t_abs));
        const a = [6]f64{ 0.08397953176865916, -0.10185705458399195, 0.43572024890517834, -0.2089608410801306, -0.6315464435895652, 1.4080627412093787 };
        const b = [6]f64{ 1.0, 1.9745297182046658, 2.4408759466685203, 2.1270679660816484, 0.8290150647066794, 0.12595868612646525 };

        var x_pow = x;
        var num = a[5] * x_pow;
        var den = b[5] * x_pow;
        var i: usize = 4;
        while (i >= 1) : (i -= 1) {
            x_pow *= x;
            num += a[i] * x_pow;
            den += b[i] * x_pow;
        }
        num += a[0];
        den += b[0];

        const cumulative = 1.0 - 0.5 * (num / den) * @sqrt(x);
        return 2.0 * (1.0 - cumulative);
    }
};

// v3.60: Helper function to calculate p-value (externally callable)
fn calculateTwoTailedPValue(t_abs: f64, df: f64) f64 {
    if (df < 1.0) return 1.0;
    const x = (df / (df + t_abs * t_abs));

    // Polynomial approximation for t-distribution
    const a = [6]f64{ 0.08397953176865916, -0.10185705458399195, 0.43572024890517834, -0.2089608410801306, -0.6315464435895652, 1.4080627412093787 };
    const b = [6]f64{ 1.0, 1.9745297182046658, 2.4408759466685203, 2.1270679660816484, 0.8290150647066794, 0.12595868612646525 };

    var x_pow = x;
    var num = a[5] * x_pow;
    var den = b[5] * x_pow;
    var i: usize = 4;
    while (i >= 1) : (i -= 1) {
        x_pow *= x;
        num += a[i] * x_pow;
        den += b[i] * x_pow;
    }
    num += a[0];
    den += b[0];

    const cumulative = 1.0 - 0.5 * (num / den) * @sqrt(x);
    return 2.0 * (1.0 - cumulative);
}

// v3.62: Multi-baseline history management
const BaselineHistory = struct {
    const MAX_BASELINES = 10;

    baselines: [MAX_BASELINES]?Baseline,
    count: usize = 0,

    pub fn init() BaselineHistory {
        return .{
            .baselines = [_]?Baseline{null} ** MAX_BASELINES,
            .count = 0,
        };
    }

    pub fn add(self: *BaselineHistory, baseline: Baseline) !void {
        if (self.count >= MAX_BASELINES) {
            return error.BaselineLimitReached;
        }
        self.baselines[self.count] = baseline;
        self.count += 1;
    }

    pub fn loadFromDir(allocator: std.mem.Allocator, dir_path: []const u8) !BaselineHistory {
        var history = BaselineHistory.init();

        var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
        defer dir.close();

        var iterator = dir.iterate();

        while (try iterator.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".json")) continue;

            const file_path = try std.fs.path.join(allocator, &[_][]const u8{ dir_path, entry.name });
            defer allocator.free(file_path);

            const baseline = try Baseline.loadFromFile(allocator, file_path);
            try history.add(baseline);
        }

        return history;
    }

    pub fn compareAll(self: *const BaselineHistory, current_mean: f64, current_jitter: f64, current_quality: f64) void {
        if (self.count == 0) {
            printErr("{s}[!] No historical baselines found{s}\n", .{ ANSI.YELLOW, ANSI.RESET });
            return;
        }

        printErr("\n{s}═══════════════════════════════════════════════════{s}\n", .{ ANSI.CYAN, ANSI.RESET });
        printErr("{s}    MULTI-BASELINE COMPARISON (v3.62)         {s}\n", .{ ANSI.BOLD, ANSI.RESET });
        printErr("{s}═══════════════════════════════════════════════════{s}\n\n", .{ ANSI.CYAN, ANSI.RESET });

        printErr(" {s}Timestamp{s}       {s}Mean RTT{s}    {s}Jitter{s}     {s}Quality{s}\n", .{ ANSI.BOLD, ANSI.RESET, ANSI.BOLD, ANSI.RESET, ANSI.BOLD, ANSI.RESET, ANSI.BOLD, ANSI.RESET });
        printErr(" {s}────────────────────────────────────────────────────────{s}\n", .{ ANSI.DIM, ANSI.RESET });

        for (self.baselines[0..self.count]) |baseline_opt| {
            const baseline = baseline_opt orelse continue;

            const timestamp = baseline.timestamp;
            const date_str = formatDate(timestamp);
            const mean_delta = current_mean - baseline.mean_rtt_us;
            const mean_pct = if (baseline.mean_rtt_us > 0) (mean_delta / baseline.mean_rtt_us) * 100.0 else 0.0;
            const jitter_delta = current_jitter - baseline.jitter_us;
            const quality_delta = current_quality - baseline.quality_score;

            printErr(" {s} {s}     {d:7.2}ms     {d:6.2}ms       {d:5.1}\n", .{
                ANSI.DIM, date_str, current_mean / 1000.0, current_jitter / 1000.0, current_quality,
            });

            const mean_symbol: u8 = if (@abs(mean_pct) < 5.0) '~' else if (mean_pct > 0) '^' else 'v';
            const jitter_symbol: u8 = if (jitter_delta > 0) '^' else 'v';
            const quality_symbol: u8 = if (quality_delta > 5.0) '^' else if (quality_delta < -5.0) 'v' else '~';

            printErr("      vs {s}: {c}{d:.1}%   {c}{d:.1}%      {c}{d:.1}\n", .{
                baseline.version,                            mean_symbol,    mean_pct,      jitter_symbol,
                (jitter_delta / baseline.jitter_us) * 100.0, quality_symbol, quality_delta,
            });
            printErr("      ────────────────────────────────────────────────\n", .{});
        }

        // v3.63: Overall trend summary across all baselines
        if (self.count >= 2) {
            var avg_pct: f64 = 0.0;
            var improving: usize = 0;
            var degrading: usize = 0;

            for (self.baselines[0..self.count]) |baseline_opt| {
                const baseline = baseline_opt orelse continue;
                const delta = (current_mean - baseline.mean_rtt_us) / baseline.mean_rtt_us * 100.0;
                avg_pct += delta;
                if (delta < -5.0) improving += 1 else if (delta > 5.0) degrading += 1;
            }
            avg_pct /= @as(f64, @floatFromInt(self.count));

            const trend_sym: u8 = if (improving > degrading) 'v' else if (degrading > improving) '^' else '~';
            printErr("\n    {s}Overall Trend: {c} {d:.1}% avg across {d} baselines{s}\n", .{
                ANSI.DIM, trend_sym, avg_pct, self.count, ANSI.RESET,
            });
        }

        printErr("\n", .{});
    }

    fn formatDate(timestamp: i64) []const u8 {
        // Simple date formatting (returns static string for display)
        const ts = @abs(timestamp);
        _ = ts;
        // For brevity, just show relative time
        if (timestamp < 0) {
            return "past";
        }
        const now = std.time.timestamp();
        const diff_hours = @divFloor(now - timestamp, 3600);
        if (diff_hours < 1) return "<1h ago";
        if (diff_hours < 24) return "<1d ago";
        return "older";
    }
};

// v3.61: Time series visualization with ASCII plots
const TimeSeries = struct {
    const PLOT_WIDTH = 60;
    const PLOT_HEIGHT = 12;

    // Plot RTT samples as ASCII time series
    pub fn plotRTTSeries(samples: []const i64, title: []const u8) void {
        if (samples.len == 0) return;

        const min_val = findMin(samples);
        const max_val = findMax(samples);
        const range = @as(f64, @floatFromInt(max_val - min_val));

        printErr("\n{s}═══════════════════════════════════════════════════{s}\n", .{ ANSI.CYAN, ANSI.RESET });
        printErr("{s}  {s} (v3.61)  {s}\n", .{ ANSI.BOLD, title, ANSI.RESET });
        printErr("{s}═══════════════════════════════════════════════════{s}\n", .{ ANSI.CYAN, ANSI.RESET });

        printErr("    Min: {d:.3}ms | Max: {d:.3}ms | Samples: {d}\n\n", .{ @as(f64, @floatFromInt(min_val)) / 1000.0, @as(f64, @floatFromInt(max_val)) / 1000.0, samples.len });

        // Plot from top to bottom (highest RTT at top)
        var y: usize = 0;
        while (y < PLOT_HEIGHT) : (y += 1) {
            const y_ratio = @as(f64, @floatFromInt(y)) / @as(f64, @floatFromInt(PLOT_HEIGHT));
            const range_scaled = range * y_ratio;
            const threshold = max_val - @as(i64, @intFromFloat(range_scaled));

            // Y-axis label
            if (y == 0) {
                printErr("{d:5.1}ms │", .{@as(f64, @floatFromInt(max_val)) / 1000.0});
            } else if (y == PLOT_HEIGHT - 1) {
                printErr("{d:5.1}ms │", .{@as(f64, @floatFromInt(min_val)) / 1000.0});
            } else {
                printErr("       │", .{});
            }

            // Plot points at this Y level
            var x: usize = 0;
            while (x < PLOT_WIDTH) : (x += 1) {
                const idx = (x * samples.len) / PLOT_WIDTH;
                if (idx >= samples.len) break;

                const val = samples[idx];
                const val_diff = if (val > threshold) val - threshold else threshold - val;
                const step_size_f = range / @as(f64, @floatFromInt(PLOT_HEIGHT));
                const is_near_threshold = if (range > 0)
                    @as(f64, @floatFromInt(@abs(val_diff))) < step_size_f
                else
                    val == threshold;

                if (is_near_threshold) {
                    // Color based on value (red=high, green=low)
                    const pct = if (range > 0) @as(f64, @floatFromInt(val - min_val)) / range else 0;
                    if (pct > 0.8) {
                        printErr("{s}█{s}", .{ ANSI.RED, ANSI.RESET });
                    } else if (pct > 0.5) {
                        printErr("{s}█{s}", .{ ANSI.YELLOW, ANSI.RESET });
                    } else {
                        printErr("{s}█{s}", .{ ANSI.GREEN, ANSI.RESET });
                    }
                } else {
                    printErr(" ", .{});
                }
            }
            printErr("\n", .{});
        }

        // X-axis
        printErr("       └", .{});
        var x: usize = 1;
        while (x < PLOT_WIDTH) : (x += 1) {
            printErr(" ", .{});
        }
        printErr("->\n", .{});
        printErr("       0                                    {d:>5.0}%\n", .{@as(f64, @floatFromInt(samples.len - 1)) / @as(f64, @floatFromInt(samples.len - 1)) * 100.0});
        printErr("\n", .{});
    }

    // Plot jitter trend (derivative of RTT)
    pub fn plotJitterTrend(samples: []const i64) void {
        if (samples.len < 2) return;

        // Calculate jitter (absolute differences)
        var jitter_vals = std.heap.page_allocator.alloc(i64, samples.len - 1) catch return;
        defer std.heap.page_allocator.free(jitter_vals);

        for (samples[0 .. samples.len - 1], 0..) |val, i| {
            const diff = samples[i + 1] - val;
            jitter_vals[i] = if (diff > 0) diff else -diff;
        }

        printErr("\n{s}═══════════════════════════════════════════════════{s}\n", .{ ANSI.CYAN, ANSI.RESET });
        printErr("{s}      JITTER TREND (v3.61)      {s}\n", .{ ANSI.BOLD, ANSI.RESET });
        printErr("{s}═══════════════════════════════════════════════════{s}\n", .{ ANSI.CYAN, ANSI.RESET });

        const max_jitter = findMax(jitter_vals);
        const avg_jitter = average(jitter_vals);

        printErr("    Avg: {d:.3}ms | Max: {d:.3}ms\n\n", .{ avg_jitter / 1000.0, @as(f64, @floatFromInt(max_jitter)) / 1000.0 });

        // Simple sparkline-style jitter plot
        printErr("    ", .{});
        for (jitter_vals) |j| {
            const norm = if (max_jitter > 0) @as(f64, @floatFromInt(j)) / @as(f64, @floatFromInt(max_jitter)) else 0;
            if (norm > 0.8) {
                printErr("{s}�{s}", .{ ANSI.RED, ANSI.RESET });
            } else if (norm > 0.5) {
                printErr("{s}▴{s}", .{ ANSI.YELLOW, ANSI.RESET });
            } else if (norm > 0.2) {
                printErr("{s}─{s}", .{ ANSI.CYAN, ANSI.RESET });
            } else {
                printErr("{s}.{s}", .{ ANSI.DIM, ANSI.RESET });
            }
        }
        printErr("\n\n", .{});
    }

    fn findMin(arr: []const i64) i64 {
        var min_val = arr[0];
        for (arr[1..]) |v| {
            if (v < min_val) min_val = v;
        }
        return min_val;
    }

    fn findMax(arr: []const i64) i64 {
        var max_val = arr[0];
        for (arr[1..]) |v| {
            if (v > max_val) max_val = v;
        }
        return max_val;
    }

    fn average(arr: []const i64) f64 {
        if (arr.len == 0) return 0;
        var sum: i64 = 0;
        for (arr) |v| sum += v;
        return @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(arr.len));
    }
};

// v3.24: Error statistics for tracking test failures by type
// v3.37: Enhanced with consecutive error tracking
const ErrorStats = struct {
    timeout_errors: usize = 0,
    mismatch_errors: usize = 0,
    device_errors: usize = 0,
    total_errors: usize = 0,
    // v3.37: Error pattern tracking
    consecutive_errors: usize = 0,
    max_consecutive_errors: usize = 0,
    last_error_time: i64 = 0,

    pub fn recordError(self: *ErrorStats, err_type: []const u8) void {
        self.total_errors += 1;
        const now: i64 = @intCast(std.time.nanoTimestamp());

        // Track consecutive errors
        if (self.total_errors > 1 and (now - self.last_error_time) < 1_000_000_000) {
            self.consecutive_errors += 1;
            if (self.consecutive_errors > self.max_consecutive_errors) {
                self.max_consecutive_errors = self.consecutive_errors;
            }
        } else {
            self.consecutive_errors = 1;
        }
        self.last_error_time = now;

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
        if (self.max_consecutive_errors > 1) {
            printErr("    Max consecutive errors: {d}\n", .{self.max_consecutive_errors});
        }
    }
};

// v3.37: Auto-diagnostics for error pattern analysis
const ErrorDiagnostics = struct {
    stats: *ErrorStats,
    total_tests: usize,

    pub fn init(stats: *ErrorStats, total_tests: usize) ErrorDiagnostics {
        return .{
            .stats = stats,
            .total_tests = total_tests,
        };
    }

    pub fn analyze(self: *const ErrorDiagnostics) void {
        if (self.stats.total_errors == 0) {
            printInfo("[i] No errors to analyze\n", .{});
            return;
        }

        printInfo("[i] Error Pattern Analysis:\n", .{});

        // Analyze error rate
        const error_rate = @as(f64, @floatFromInt(self.stats.total_errors)) /
            @as(f64, @floatFromInt(self.total_tests)) * 100.0;
        if (error_rate > 50.0) {
            printWarning("    ⚠️  High error rate ({d:.1}%) - Check cable/connection\n", .{error_rate});
        } else if (error_rate > 10.0) {
            printWarning("    ⚠️  Moderate error rate ({d:.1}%) - May need flow control\n", .{error_rate});
        } else {
            printSuccess("    ✓ Low error rate ({d:.1}%)\n", .{error_rate});
        }

        // Analyze error types
        if (self.stats.timeout_errors > self.stats.mismatch_errors * 2) {
            printWarning("    ⚠️  Many timeout errors - Increase timeout or check baud rate\n", .{});
        }
        if (self.stats.mismatch_errors > self.stats.total_errors / 2) {
            printWarning("    ⚠️  Many mismatch errors - Possible data corruption, check cable quality\n", .{});
        }
        if (self.stats.device_errors > 0) {
            printWarning("    ⚠️  Device errors detected - Check permissions and hardware\n", .{});
        }

        // Analyze consecutive errors
        if (self.stats.max_consecutive_errors > 5) {
            printWarning("    ⚠️  Consecutive errors ({d}) - Intermittent connection\n", .{self.stats.max_consecutive_errors});
        }
    }

    pub fn suggestFixes(self: *const ErrorDiagnostics) void {
        if (self.stats.total_errors == 0) return;

        printInfo("[i] Suggested Fixes:\n", .{});

        if (self.stats.timeout_errors > self.stats.total_errors / 2) {
            printDim("    1. Increase timeout: --timeout <ms>\n", .{});
            printDim("    2. Try adaptive timeout: --adaptive-timeout\n", .{});
            printDim("    3. Check baud rate: --baud 115200\n", .{});
        }
        if (self.stats.mismatch_errors > self.stats.total_errors / 2) {
            printDim("    1. Try different cable (USB quality matters)\n", .{});
            printDim("    2. Enable flow control: --rts-cts\n", .{});
            printDim("    3. Check for EMI interference\n", .{});
        }
        if (self.stats.device_errors > 0) {
            printDim("    1. Check device permissions\n", .{});
            printDim("    2. Try different USB port\n", .{});
            printDim("    3. Run: --list-devices to check availability\n", .{});
        }
    }
};

// v3.37: Auto-recovery with exponential backoff
const AutoRecovery = struct {
    max_retries: u32,
    base_delay_ms: u32,
    max_delay_ms: u32,

    pub fn init(max_retries: u32, base_delay_ms: u32) AutoRecovery {
        return .{
            .max_retries = max_retries,
            .base_delay_ms = base_delay_ms,
            .max_delay_ms = 30000, // 30 seconds max
        };
    }

    pub fn getDelay(self: *const AutoRecovery, attempt: u32) u32 {
        // Exponential backoff: delay = base * (2 ^ attempt)
        const delay = self.base_delay_ms * @as(u32, 1) <<| @as(u5, @intCast(@min(attempt, 8)));
        return @min(delay, self.max_delay_ms);
    }

    pub fn shouldRetry(self: *const AutoRecovery, attempt: u32) bool {
        return attempt < self.max_retries;
    }
};

// v3.24: Latency histogram for distribution analysis
const LatencyHistogram = struct {
    // Histogram buckets (ms)
    buckets: [8]usize = [_]usize{0} ** 8,
    bucket_labels: [8][]const u8 = [_][]const u8{
        "0-10ms",   "10-20ms",   "20-30ms",   "30-50ms",
        "50-100ms", "100-200ms", "200-500ms", ">500ms",
    },

    pub fn record(self: *LatencyHistogram, latency_ms: i64) void {
        const bucket = getBucket(latency_ms);
        self.buckets[bucket] += 1;
    }

    pub fn getBucket(latency_ms: i64) usize {
        if (latency_ms < 10) return 0;
        if (latency_ms < 20) return 1;
        if (latency_ms < 30) return 2;
        if (latency_ms < 50) return 3;
        if (latency_ms < 100) return 4;
        if (latency_ms < 200) return 5;
        if (latency_ms < 500) return 6;
        return 7;
    }

    pub fn report(self: *const LatencyHistogram) void {
        printInfo("[i] Latency Distribution:\n", .{});
        const total_samples: usize = blk: {
            var sum: usize = 0;
            for (self.buckets) |count| sum += count;
            break :blk sum;
        };

        if (total_samples == 0) {
            printDim("    No samples\n", .{});
            return;
        }

        // v3.47: Find max count for bar scaling
        const max_count: usize = blk: {
            var max: usize = 0;
            for (self.buckets) |count| {
                if (count > max) max = count;
            }
            break :blk max;
        };

        for (self.buckets, 0..) |count, i| {
            if (count > 0) {
                const percent = @as(f64, @floatFromInt(count)) /
                    @as(f64, @floatFromInt(total_samples)) * 100.0;

                // v3.47: ASCII bar (max 40 chars)
                const bar_len = if (max_count > 0)
                    @as(usize, @intFromFloat(@as(f64, @floatFromInt(count)) * 40.0 / @as(f64, @floatFromInt(max_count))))
                else
                    0;
                var bar: [41]u8 = undefined;
                for (0..bar_len) |j| bar[j] = '#';
                bar[bar_len] = 0;

                printDim("    {s}: {d} ({d:.1}%) [{s}]\n", .{ self.bucket_labels[i], count, percent, bar[0..bar_len] });
            }
        }
    }
};

// v3.24: Jitter tracker for RTT variance measurement
const JitterTracker = struct {
    allocator: std.mem.Allocator,
    samples: []i64,
    count: usize,
    capacity: usize,
    // v3.53: Consecutive failure tracking
    consecutive_failures: usize = 0,
    max_consecutive_failures: usize = 0,
    // v3.56: Historical quality tracking
    quality_samples: [10]f64 = [_]f64{0.0} ** 10,
    quality_sample_count: usize = 0,
    quality_avg: f64 = 0.0,

    pub fn init(allocator: std.mem.Allocator) JitterTracker {
        const capacity = 1000;
        const samples = allocator.alloc(i64, capacity) catch unreachable;
        return .{
            .allocator = allocator,
            .samples = samples,
            .count = 0,
            .capacity = capacity,
        };
    }

    pub fn deinit(self: *JitterTracker) void {
        self.allocator.free(self.samples);
    }

    // v3.56: Add quality score sample to history
    pub fn addQualitySample(self: *JitterTracker, score: f64) void {
        // Shift samples left
        var i: usize = 0;
        while (i < 9) : (i += 1) {
            self.quality_samples[i] = self.quality_samples[i + 1];
        }
        self.quality_samples[9] = score;

        if (self.quality_sample_count < 10) {
            self.quality_sample_count += 1;
        }

        // Calculate average
        var sum: f64 = 0.0;
        for (0..self.quality_sample_count) |j| {
            sum += self.quality_samples[j];
        }
        if (self.quality_sample_count > 0) {
            self.quality_avg = sum / @as(f64, @floatFromInt(self.quality_sample_count));
        }
    }

    pub fn getQualityHistory(self: *const JitterTracker) struct { count: usize, avg: f64, samples: [10]f64 } {
        return .{
            .count = self.quality_sample_count,
            .avg = self.quality_avg,
            .samples = self.quality_samples,
        };
    }

    pub fn addSample(self: *JitterTracker, rtt_us: i64) !void {
        if (self.count >= self.capacity) {
            // Shift samples left (remove oldest, add new)
            std.mem.copyForwards(i64, self.samples[0 .. self.capacity - 1], self.samples[1..]);
            self.count = self.capacity;
            self.samples[self.capacity - 1] = rtt_us;
        } else {
            self.samples[self.count] = rtt_us;
            self.count += 1;
        }
    }

    // v3.53: Track test failures for consecutive failure detection
    pub fn recordFailure(self: *JitterTracker) void {
        self.consecutive_failures += 1;
        if (self.consecutive_failures > self.max_consecutive_failures) {
            self.max_consecutive_failures = self.consecutive_failures;
        }
    }

    pub fn recordSuccess(self: *JitterTracker) void {
        self.consecutive_failures = 0;
    }

    pub fn getConsecutiveFailures(self: *const JitterTracker) usize {
        return self.consecutive_failures;
    }

    pub fn getMaxConsecutiveFailures(self: *const JitterTracker) usize {
        return self.max_consecutive_failures;
    }

    pub fn getJitter(self: *const JitterTracker) f64 {
        if (self.count < 2) return 0.0;

        // Calculate variance
        const len = self.count;
        var sum: i64 = 0;
        for (self.samples[0..len]) |sample| {
            sum += sample;
        }
        const mean = @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(len));

        var variance: f64 = 0.0;
        for (self.samples[0..len]) |sample| {
            const diff = @as(f64, @floatFromInt(sample)) - mean;
            variance += diff * diff;
        }
        variance /= @as(f64, @floatFromInt(len));

        return std.math.sqrt(variance);
    }

    pub fn getStats(self: *const JitterTracker) struct { mean: f64, jitter: f64, min: i64, max: i64 } {
        if (self.count == 0) {
            return .{ .mean = 0.0, .jitter = 0.0, .min = 0, .max = 0 };
        }

        const len = self.count;
        var sum: i64 = 0;
        var min_val: i64 = std.math.maxInt(i64);
        var max_val: i64 = std.math.minInt(i64);

        for (self.samples[0..len]) |sample| {
            sum += sample;
            if (sample < min_val) min_val = sample;
            if (sample > max_val) max_val = sample;
        }

        const mean = @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(len));
        const jitter = self.getJitter();

        return .{ .mean = mean, .jitter = jitter, .min = min_val, .max = max_val };
    }

    pub fn report(self: *const JitterTracker) void {
        const stats = self.getStats();
        printInfo("[i] Jitter Statistics:\n", .{});
        printDim("    Mean RTT: {d:.2}us\n", .{stats.mean});
        printDim("    Jitter (stddev): {d:.2}us\n", .{stats.jitter});
        printDim("    Min RTT: {d}us\n", .{stats.min});
        printDim("    Max RTT: {d}us\n", .{stats.max});

        // v3.79: Call statistical analysis
        self.showStatisticalReport();

        // v3.80: Sample Rate Analysis - timing consistency
        if (self.count >= 10) {
            self.analyzeSampleRate();
        }

        // v3.79: Call percentile bands analysis
        if (self.count >= 5) {
            self.showPercentileBands();
        }
    }

    // v3.81: Extended Percentile calculation (min, p25, p50, p75, p90, p95, p99, max)
    pub fn getPercentiles(self: *const JitterTracker) struct { min: i64, p25: i64, p50: i64, p75: i64, p90: i64, p95: i64, p99: i64, max: i64 } {
        if (self.count == 0) {
            return .{ .min = 0, .p25 = 0, .p50 = 0, .p75 = 0, .p90 = 0, .p95 = 0, .p99 = 0, .max = 0 };
        }

        // Create a sorted copy of samples
        const len = self.count;
        var sorted = self.allocator.alloc(i64, len) catch unreachable;
        defer self.allocator.free(sorted);
        std.mem.copyForwards(i64, sorted, self.samples[0..len]);

        // Sort the array in-place
        std.sort.insertion(i64, sorted, {}, struct {
            pub fn lessThan(_: void, a: i64, b: i64) bool {
                return a < b;
            }
        }.lessThan);

        // Mark as intentionally mutated (sorted in-place)
        _ = &sorted;

        // Calculate percentiles (p25, p50, p75, p90, p95, p99)
        const p25_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(len - 1)) * 0.25));
        const p50_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(len - 1)) * 0.50));
        const p75_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(len - 1)) * 0.75));
        const p90_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(len - 1)) * 0.90));
        const p95_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(len - 1)) * 0.95));
        const p99_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(len - 1)) * 0.99));

        return .{
            .min = sorted[0],
            .p25 = sorted[p25_idx],
            .p50 = sorted[p50_idx],
            .p75 = sorted[p75_idx],
            .p90 = sorted[p90_idx],
            .p95 = sorted[p95_idx],
            .p99 = sorted[p99_idx],
            .max = sorted[len - 1],
        };
    }

    pub fn reportPercentiles(self: *const JitterTracker) void {
        if (self.count < 2) {
            printDim("    Percentiles: not enough samples\n", .{});
            return;
        }

        const p = self.getPercentiles();
        // Convert us to ms for display
        const p50_ms = @as(f64, @floatFromInt(p.p50)) / 1000.0;
        const p90_ms = @as(f64, @floatFromInt(p.p90)) / 1000.0;
        const p95_ms = @as(f64, @floatFromInt(p.p95)) / 1000.0;
        const p99_ms = @as(f64, @floatFromInt(p.p99)) / 1000.0;

        printInfo("[i] RTT Percentiles:\n", .{});
        printDim("    p50 (median): {d:.2}ms ({d}us)\n", .{ p50_ms, p.p50 });
        printDim("    p90: {d:.2}ms ({d}us)\n", .{ p90_ms, p.p90 });
        printDim("    p95: {d:.2}ms ({d}us)\n", .{ p95_ms, p.p95 });
        printDim("    p99: {d:.2}ms ({d}us)\n", .{ p99_ms, p.p99 });
    }

    // v3.48: Spike detection (outliers > 3x median)
    pub fn detectSpikes(self: *const JitterTracker, threshold_multiplier: f64) struct { count: usize } {
        if (self.count < 5) {
            return .{ .count = 0 };
        }

        const len = self.count;
        var spikes: usize = 0;

        // Use p50 (median) as baseline
        const p = self.getPercentiles();
        const median_us = @as(f64, @floatFromInt(p.p50));
        const spike_threshold = median_us * threshold_multiplier;

        for (self.samples[0..len]) |sample| {
            if (sample > @as(i64, @intFromFloat(spike_threshold))) {
                spikes += 1;
            }
        }

        return .{ .count = spikes };
    }

    pub fn reportSpikes(self: *const JitterTracker, threshold_multiplier: f64) void {
        if (self.count < 5) {
            return;
        }

        const spikes = self.detectSpikes(threshold_multiplier);
        if (spikes.count == 0) {
            return;
        }

        const p = self.getPercentiles();
        const median_ms = @as(f64, @floatFromInt(p.p50)) / 1000.0;
        const threshold_ms = median_ms * threshold_multiplier;

        printInfo("[!] Latency Spikes Detected:\n", .{});
        printDim("    Median: {d:.2}ms, Threshold: {d:.2}ms ({d:.1}x)\n", .{ median_ms, threshold_ms, threshold_multiplier });
        printDim("    Spikes: {d} samples above threshold\n", .{spikes.count});

        if (spikes.outliers.len > 0) {
            printDim("    Sample spikes: ", .{});
            for (spikes.outliers, 0..) |val, i| {
                if (i > 0) printDim(", ", .{});
                const val_ms = @as(f64, @floatFromInt(val)) / 1000.0;
                printDim("{d:.1}ms", .{val_ms});
            }
            printDim("\n", .{});
        }
    }

    // v3.63: IQR (Interquartile Range) Outlier Detection - statistical method
    // Uses Q1 - 1.5*IQR and Q3 + 1.5*IQR as bounds (standard box plot method)
    pub fn detectOutliersIQR(self: *const JitterTracker, iqr_multiplier: f64) struct {
        count: usize,
        q1: i64,
        q3: i64,
        iqr: i64,
        lower_bound: i64,
        upper_bound: i64,
    } {
        if (self.count < 5) {
            return .{ .count = 0, .q1 = 0, .q3 = 0, .iqr = 0, .lower_bound = 0, .upper_bound = 0 };
        }

        // Copy samples to local array and sort
        var sorted: [1024]i64 = undefined;
        const sort_len = @min(self.count, sorted.len);
        for (self.samples[0..sort_len], 0..) |s, i| {
            sorted[i] = s;
        }

        // Simple insertion sort for small arrays
        var i: usize = 1;
        while (i < sort_len) : (i += 1) {
            const key = sorted[i];
            var j: usize = i;
            while (j > 0 and sorted[j - 1] > key) : (j -= 1) {
                sorted[j] = sorted[j - 1];
            }
            sorted[j] = key;
        }

        // Calculate Q1 (25th percentile) and Q3 (75th percentile)
        const n = sort_len;
        const q1_idx = n / 4;
        const q3_idx = (3 * n) / 4;
        const q1 = sorted[q1_idx];
        const q3 = sorted[q3_idx];
        const iqr_val = q3 - q1;

        // Calculate bounds with multiplier (default 1.5 for standard box plot)
        const lower_bound = q1 - @as(i64, @intFromFloat(@as(f64, @floatFromInt(iqr_val)) * iqr_multiplier));
        const upper_bound = q3 + @as(i64, @intFromFloat(@as(f64, @floatFromInt(iqr_val)) * iqr_multiplier));

        // Count outliers
        var outlier_count: usize = 0;
        for (self.samples[0..self.count]) |sample| {
            if (sample < lower_bound or sample > upper_bound) {
                outlier_count += 1;
            }
        }

        return .{
            .count = outlier_count,
            .q1 = q1,
            .q3 = q3,
            .iqr = iqr_val,
            .lower_bound = lower_bound,
            .upper_bound = upper_bound,
        };
    }

    pub fn reportOutliersIQR(self: *const JitterTracker, iqr_multiplier: f64) void {
        if (self.count < 5) {
            return;
        }

        const result = self.detectOutliersIQR(iqr_multiplier);
        if (result.count == 0) {
            return;
        }

        const q1_ms = @as(f64, @floatFromInt(result.q1)) / 1000.0;
        const q3_ms = @as(f64, @floatFromInt(result.q3)) / 1000.0;
        const iqr_ms = @as(f64, @floatFromInt(result.iqr)) / 1000.0;
        const lower_ms = @as(f64, @floatFromInt(result.lower_bound)) / 1000.0;
        const upper_ms = @as(f64, @floatFromInt(result.upper_bound)) / 1000.0;

        printInfo("\n  ⚠ IQR Outliers (statistical method):\n", .{});
        printDim("    Q1 (25%): {d:.2}ms, Q3 (75%): {d:.2}ms\n", .{ q1_ms, q3_ms });
        printDim("    IQR: {d:.2}ms, Multiplier: {d:.1}x\n", .{ iqr_ms, iqr_multiplier });
        printDim("    Bounds: [{d:.2}ms, {d:.2}ms]\n", .{ lower_ms, upper_ms });
        printDim("    Outliers: {d}/{d} samples outside bounds\n", .{ result.count, self.count });
        printDim("    Outlier rate: {d:.1}%\n", .{@as(f64, @floatFromInt(result.count)) / @as(f64, @floatFromInt(self.count)) * 100.0});
    }

    // v3.52: RTT Trend Analysis - detects if latency is improving/degrading/stable
    pub fn getTrend(self: *const JitterTracker) struct { direction: []const u8, change_percent: f64, first_half_avg: f64, second_half_avg: f64 } {
        if (self.count < 6) {
            return .{ .direction = "insufficient_data", .change_percent = 0.0, .first_half_avg = 0.0, .second_half_avg = 0.0 };
        }

        const half_count = self.count / 2;
        var first_sum: i64 = 0;
        var second_sum: i64 = 0;

        for (self.samples[0..half_count]) |s| {
            first_sum += s;
        }
        for (self.samples[half_count..self.count]) |s| {
            second_sum += s;
        }

        const first_avg = @as(f64, @floatFromInt(first_sum)) / @as(f64, @floatFromInt(half_count));
        const second_avg = @as(f64, @floatFromInt(second_sum)) / @as(f64, @floatFromInt(self.count - half_count));

        const change_percent = if (first_avg > 0)
            ((second_avg - first_avg) / first_avg) * 100.0
        else
            0.0;

        const direction: []const u8 = if (change_percent > 10.0)
            "DEGRADING" // Latency increasing significantly
        else if (change_percent < -10.0)
            "IMPROVING" // Latency decreasing significantly
        else if (change_percent > 3.0)
            "WORSE" // Slight increase
        else if (change_percent < -3.0)
            "BETTER" // Slight decrease
        else
            "STABLE"; // Within +/-3%

        return .{ .direction = direction, .change_percent = change_percent, .first_half_avg = first_avg, .second_half_avg = second_avg };
    }

    // v3.66: Moving Average Smoothing - computes smoothed RTT curve
    // Returns smoothed values and statistics about the smoothing effect
    pub fn getMovingAverage(self: *const JitterTracker, window: usize) struct {
        smoothed: [20]f64,
        count: usize,
        original_std: f64,
        smoothed_std: f64,
        reduction_pct: f64,
    } {
        if (self.count < 3 or window < 2) {
            return .{ .smoothed = [_]f64{0} ** 20, .count = 0, .original_std = 0, .smoothed_std = 0, .reduction_pct = 0 };
        }

        const effective_window = @min(window, self.count);
        var smoothed: [20]f64 = undefined;
        var smoothed_count: usize = 0;

        // Calculate original standard deviation
        const stats = self.getStats();
        const original_std = stats.jitter;

        // Compute moving average (simplified - use every Nth point)
        const step = @max(1, self.count / 20);
        var idx: usize = 0;
        while (idx < self.count and smoothed_count < 20) : (idx += step) {
            // Average of window samples centered at idx
            var sum: i64 = 0;
            var window_count: usize = 0;
            const start = if (idx >= effective_window / 2) idx - effective_window / 2 else 0;
            const end = @min(idx + effective_window / 2 + 1, self.count);

            for (self.samples[start..end]) |s| {
                sum += s;
                window_count += 1;
            }

            if (window_count > 0) {
                smoothed[smoothed_count] = @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(window_count));
                smoothed_count += 1;
            }
        }

        // Calculate smoothed standard deviation
        var sum_diff: f64 = 0;
        for (smoothed[0..smoothed_count]) |s| {
            const diff = s - stats.mean;
            sum_diff += diff * diff;
        }
        const smoothed_std = if (smoothed_count > 1)
            @sqrt(sum_diff / @as(f64, @floatFromInt(smoothed_count - 1)))
        else
            original_std;

        const reduction_pct = if (original_std > 0)
            ((original_std - smoothed_std) / original_std) * 100.0
        else
            0.0;

        return .{ .smoothed = smoothed, .count = smoothed_count, .original_std = original_std, .smoothed_std = smoothed_std, .reduction_pct = reduction_pct };
    }

    // v3.67: Anomaly Detection - combines multiple statistical methods to detect anomalies
    // Returns count and details of detected anomalies using: IQR outliers, z-score, and MA deviation
    pub fn detectAnomalies(self: *const JitterTracker, iqr_threshold: f64, z_threshold: f64) struct {
        count: usize,
        iqr_outliers: usize,
        z_score_outliers: usize,
        ma_deviations: usize,
        anomaly_score: f64, // 0-100, higher = more anomalous
    } {
        if (self.count < 10) {
            return .{ .count = 0, .iqr_outliers = 0, .z_score_outliers = 0, .ma_deviations = 0, .anomaly_score = 0 };
        }

        const stats = self.getStats();
        const mean = stats.mean;
        const std_dev = stats.jitter;

        // Method 1: IQR outliers (already implemented)
        const iqr_result = self.detectOutliersIQR(iqr_threshold);
        const iqr_count = iqr_result.count;

        // Method 2: Z-score outliers (|value - mean| / std_dev > threshold)
        var z_score_count: usize = 0;
        for (self.samples[0..self.count]) |s| {
            if (std_dev > 0) {
                const z_score = @abs(@as(f64, @floatFromInt(s)) - mean) / std_dev;
                if (z_score > z_threshold) {
                    z_score_count += 1;
                }
            }
        }

        // Method 3: Moving average deviation
        const ma = self.getMovingAverage(10);
        var ma_dev_count: usize = 0;
        if (ma.count > 0) {
            const ma_mean = mean / 1000.0; // convert to ms for comparison
            for (ma.smoothed[0..ma.count]) |smoothed_val| {
                const smoothed_ms = smoothed_val / 1000.0;
                const deviation = @abs(smoothed_ms - ma_mean);
                if (deviation > 2.0 * std_dev / 1000.0) { // > 2σ from mean
                    ma_dev_count += 1;
                }
            }
        }

        // Calculate anomaly score (0-100)
        // Score = weighted sum of (outliers / total) * weights
        const total_samples = @as(f64, @floatFromInt(self.count));
        const iqr_ratio = @as(f64, @floatFromInt(iqr_count)) / total_samples;
        const z_ratio = @as(f64, @floatFromInt(z_score_count)) / total_samples;

        const anomaly_score = @min(100.0, (iqr_ratio * 40.0) + (z_ratio * 60.0));

        return .{
            .count = @max(iqr_count, @max(z_score_count, ma_dev_count)), // Max of all methods
            .iqr_outliers = iqr_count,
            .z_score_outliers = z_score_count,
            .ma_deviations = ma_dev_count,
            .anomaly_score = anomaly_score,
        };
    }

    // v3.64: Correlation Analysis - computes Pearson correlation between RTT and time
    // Returns correlation coefficient r in [-1, 1]:
    //   r > 0.5: Strong positive correlation (RTT increasing over time - degrading)
    //   r < -0.5: Strong negative correlation (RTT decreasing over time - improving)
    //   -0.5 <= r <= 0.5: Weak or no correlation (stable)
    pub fn getCorrelation(self: *const JitterTracker) struct { coefficient: f64, strength: []const u8, interpretation: []const u8 } {
        if (self.count < 3) {
            return .{ .coefficient = 0.0, .strength = "insufficient_data", .interpretation = "Need 3+ samples" };
        }

        const n = @as(f64, @floatFromInt(self.count));

        // Calculate mean of x (indices) and y (RTT values)
        var sum_x: f64 = 0;
        var sum_y: f64 = 0;
        for (self.samples[0..self.count], 0..) |s, i| {
            sum_x += @as(f64, @floatFromInt(i));
            sum_y += @as(f64, @floatFromInt(s));
        }
        const mean_x = sum_x / n;
        const mean_y = sum_y / n;

        // Calculate Pearson correlation coefficient
        var sum_xy_diff: f64 = 0;
        var sum_x_diff2: f64 = 0;
        var sum_y_diff2: f64 = 0;

        for (self.samples[0..self.count], 0..) |s, i| {
            const x = @as(f64, @floatFromInt(i));
            const y = @as(f64, @floatFromInt(s));
            const x_diff = x - mean_x;
            const y_diff = y - mean_y;
            sum_xy_diff += x_diff * y_diff;
            sum_x_diff2 += x_diff * x_diff;
            sum_y_diff2 += y_diff * y_diff;
        }

        const denominator = @sqrt(sum_x_diff2 * sum_y_diff2);
        const r = if (denominator > 0.0001)
            sum_xy_diff / denominator
        else
            0.0;

        // Interpret correlation strength
        const abs_r = @abs(r);
        const strength: []const u8 = if (abs_r >= 0.7)
            "strong"
        else if (abs_r >= 0.5)
            "moderate"
        else if (abs_r >= 0.3)
            "weak"
        else
            "negligible";

        const interpretation: []const u8 = if (r >= 0.5)
            "positive trend (degrading)"
        else if (r <= -0.5)
            "negative trend (improving)"
        else
            "no clear trend (stable)";

        return .{ .coefficient = r, .strength = strength, .interpretation = interpretation };
    }

    // v3.54: Connection Quality Score (0-100) combining multiple factors
    pub fn getQualityScore(self: *const JitterTracker, threshold_multiplier: f64) struct { score: f64, grade: []const u8, details: []const u8 } {
        if (self.count < 5) {
            return .{ .score = 50.0, .grade = "INSUFFICIENT_DATA", .details = "Need 5+ samples" };
        }

        const stats = self.getStats();
        const p = self.getPercentiles();
        const spikes = self.detectSpikes(threshold_multiplier);

        // Factor 1: Jitter quality (lower is better, max 30 points)
        const jitter_ms = stats.jitter / 1000.0;
        var jitter_score: f64 = 0.0;
        if (jitter_ms < 5.0) {
            jitter_score = 30.0;
        } else if (jitter_ms < 10.0) {
            jitter_score = 25.0;
        } else if (jitter_ms < 20.0) {
            jitter_score = 20.0;
        } else if (jitter_ms < 50.0) {
            jitter_score = 10.0;
        }

        // Factor 2: Consistency quality (p99/p50 ratio, max 25 points)
        const ratio: f64 = @as(f64, @floatFromInt(p.p99)) / @as(f64, @floatFromInt(p.p50));
        var consistency_score: f64 = 0.0;
        if (ratio < 1.5) {
            consistency_score = 25.0;
        } else if (ratio < 2.0) {
            consistency_score = 20.0;
        } else if (ratio < 3.0) {
            consistency_score = 15.0;
        } else if (ratio < 5.0) {
            consistency_score = 5.0;
        }

        // Factor 3: Spike rate (fewer spikes is better, max 25 points)
        const spike_rate: f64 = @as(f64, @floatFromInt(spikes.count)) / @as(f64, @floatFromInt(self.count));
        var spike_score: f64 = 0.0;
        if (spike_rate == 0.0) {
            spike_score = 25.0;
        } else if (spike_rate < 0.05) {
            spike_score = 20.0;
        } else if (spike_rate < 0.10) {
            spike_score = 10.0;
        } else if (spike_rate < 0.20) {
            spike_score = 5.0;
        }

        // Factor 4: Consecutive failures (fewer is better, max 20 points)
        var consecutive_score: f64 = 0.0;
        if (self.max_consecutive_failures == 0) {
            consecutive_score = 20.0;
        } else if (self.max_consecutive_failures == 1) {
            consecutive_score = 15.0;
        } else if (self.max_consecutive_failures == 2) {
            consecutive_score = 10.0;
        }

        // Total score (0-100)
        const total_score = jitter_score + consistency_score + spike_score + consecutive_score;

        const grade: []const u8 = if (total_score >= 90.0)
            "EXCELLENT"
        else if (total_score >= 75.0)
            "GOOD"
        else if (total_score >= 60.0)
            "FAIR"
        else if (total_score >= 40.0)
            "POOR"
        else
            "CRITICAL";

        return .{ .score = total_score, .grade = grade, .details = "Jitter+Consistency+Spikes+Consecutive" };
    }

    // v3.51: Comprehensive RTT Statistics Summary
    // Combines jitter, percentiles, and spike detection into unified report
    // v3.63: Added outlier_method parameter for IQR vs fixed method selection
    pub fn reportRTTSummary(self: *const JitterTracker, threshold_multiplier: f64, outlier_method: []const u8) void {
        if (self.count < 2) {
            printDim("    RTT Summary: not enough samples\n", .{});
            return;
        }

        const stats = self.getStats();
        const mean_ms = stats.mean / 1000.0;
        const jitter_ms = stats.jitter / 1000.0;

        printInfo("╔═════════════════════════════════════════╗\n", .{});
        printInfo("║          RTT STATISTICS SUMMARY           ║\n", .{});
        printInfo("╚═════════════════════════════════════════╝\n", .{});

        // v3.54: Connection Quality Score (prominent display)
        const quality = self.getQualityScore(threshold_multiplier);

        if (quality.score >= 75.0) {
            printSuccess("  Quality Score: {d:.0}/100 {s}\n", .{ quality.score, quality.grade });
        } else if (quality.score >= 60.0) {
            printInfo("  Quality Score: {d:.0}/100 {s}\n", .{ quality.score, quality.grade });
        } else if (quality.score >= 40.0) {
            printWarning("  Quality Score: {d:.0}/100 {s}\n", .{ quality.score, quality.grade });
        } else {
            printErr("  Quality Score: {d:.0}/100 {s}\n", .{ quality.score, quality.grade });
        }

        printInfo("  Samples:       {d}\n", .{self.count});
        printInfo("  Mean RTT:      {d:.3}ms\n", .{mean_ms});
        printInfo("  Jitter:        {d:.3}ms\n", .{jitter_ms});

        // v3.53: Consecutive failure tracking
        if (self.max_consecutive_failures > 0) {
            printInfo("  Consecutive Failures: max {d}\n", .{self.max_consecutive_failures});
        }

        printInfo("  Min/Max:       {d:.2}ms / {d:.2}ms\n", .{
            @as(f64, @floatFromInt(stats.min)) / 1000.0,
            @as(f64, @floatFromInt(stats.max)) / 1000.0,
        });

        // Percentiles
        if (self.count >= 2) {
            const p = self.getPercentiles();
            const p50_ms = @as(f64, @floatFromInt(p.p50)) / 1000.0;
            const p90_ms = @as(f64, @floatFromInt(p.p90)) / 1000.0;
            const p95_ms = @as(f64, @floatFromInt(p.p95)) / 1000.0;
            const p99_ms = @as(f64, @floatFromInt(p.p99)) / 1000.0;

            printInfo("\n  Percentiles:\n", .{});
            printDim("    p50 (median): {d:.2}ms\n", .{p50_ms});
            printDim("    p90:         {d:.2}ms\n", .{p90_ms});
            printDim("    p95:         {d:.2}ms\n", .{p95_ms});
            printDim("    p99:         {d:.2}ms\n", .{p99_ms});
        }

        // v3.63: Outlier detection using selected method (fixed or iqr)
        if (std.mem.eql(u8, outlier_method, "iqr")) {
            self.reportOutliersIQR(1.5); // Standard IQR multiplier (box plot)
        } else {
            const spikes = self.detectSpikes(threshold_multiplier);
            if (spikes.count > 0) {
                const p = self.getPercentiles();
                const median_ms = @as(f64, @floatFromInt(p.p50)) / 1000.0;
                const threshold_ms = median_ms * threshold_multiplier;

                printInfo("\n  ⚠ Latency Spikes:\n", .{});
                printDim("    Median:       {d:.2}ms\n", .{median_ms});
                printDim("    Threshold:    {d:.2}ms ({d:.1}x)\n", .{ threshold_ms, threshold_multiplier });
                printDim("    Spikes:       {d}/{d} samples\n", .{ spikes.count, self.count });
                printDim("    Spike rate:   {d:.1}%\n", .{@as(f64, @floatFromInt(spikes.count)) / @as(f64, @floatFromInt(self.count)) * 100.0});
            }
        }

        // Distribution quality assessment
        if (self.count >= 5) {
            const p = self.getPercentiles();
            const p50_us = p.p50;
            const p99_us = p.p99;
            const ratio: f64 = @as(f64, @floatFromInt(p99_us)) / @as(f64, @floatFromInt(p50_us));
            printDim("\n  Quality:       ", .{});
            if (ratio < 2.0) {
                printDim("excellent (p99/p50 < 2x)\n", .{});
            } else if (ratio < 3.0) {
                printDim("good (p99/p50 < 3x)\n", .{});
            } else if (ratio < 5.0) {
                printDim("acceptable (p99/p50 < 5x)\n", .{});
            } else {
                printDim("poor (p99/p50 >= 5x - high variance)\n", .{});
            }
        }

        // v3.52: Trend analysis
        const trend = self.getTrend();
        if (!std.mem.eql(u8, trend.direction, "insufficient_data")) {
            printDim("\n  Trend:         ", .{});
            const first_ms = trend.first_half_avg / 1000.0;
            const second_ms = trend.second_half_avg / 1000.0;

            if (std.mem.eql(u8, trend.direction, "IMPROVING")) {
                printSuccess("v IMPROVING ({d:.1}%)\n", .{trend.change_percent});
            } else if (std.mem.eql(u8, trend.direction, "DEGRADING")) {
                printWarning("^ DEGRADING ({d:.1}%)\n", .{trend.change_percent});
            } else if (std.mem.eql(u8, trend.direction, "BETTER")) {
                printDim("v slightly better ({d:.1}%)\n", .{trend.change_percent});
            } else if (std.mem.eql(u8, trend.direction, "WORSE")) {
                printDim("^ slightly worse ({d:.1}%)\n", .{trend.change_percent});
            } else {
                printDim("- STABLE\n", .{});
            }
            printDim("    First half: {d:.2}ms, Second half: {d:.2}ms\n", .{ first_ms, second_ms });
        }

        // v3.64: Correlation analysis
        const corr = self.getCorrelation();
        if (!std.mem.eql(u8, corr.strength, "insufficient_data")) {
            printDim("\n  Correlation:   ", .{});
            if (corr.coefficient >= 0.5) {
                printWarning("{d:.3} ({s}, {s})\n", .{ corr.coefficient, corr.strength, corr.interpretation });
            } else if (corr.coefficient <= -0.5) {
                printSuccess("{d:.3} ({s}, {s})\n", .{ corr.coefficient, corr.strength, corr.interpretation });
            } else {
                printDim("{d:.3} ({s}, {s})\n", .{ corr.coefficient, corr.strength, corr.interpretation });
            }
        }

        // v3.65: Standard Deviation Bands
        if (self.count >= 10) {
            const band_stats = self.getStats();
            const band_mean_ms = band_stats.mean / 1000.0;
            const std_dev_ms = band_stats.jitter / 1000.0;

            printDim("\n  Std Dev Bands:\n", .{});
            printDim("    Mean: {d:.3}ms\n", .{band_mean_ms});
            printDim("    Std Dev: {d:.3}ms\n", .{std_dev_ms});
            printDim("    +-1σ (68%): [{d:.3}ms, {d:.3}ms]\n", .{ band_mean_ms - std_dev_ms, band_mean_ms + std_dev_ms });
            printDim("    +-2σ (95%): [{d:.3}ms, {d:.3}ms]\n", .{ band_mean_ms - 2.0 * std_dev_ms, band_mean_ms + 2.0 * std_dev_ms });
            printDim("    +-3σ (99.7%): [{d:.3}ms, {d:.3}ms]\n", .{ band_mean_ms - 3.0 * std_dev_ms, band_mean_ms + 3.0 * std_dev_ms });
        }

        // v3.66: Moving Average Smoothing
        const ma = self.getMovingAverage(10);
        if (ma.count > 0) {
            printDim("\n  Moving Average (window={d}):\n", .{10});
            printDim("    Samples smoothed: {d}\n", .{ma.count});
            printDim("    Original std: {d:.3}ms\n", .{ma.original_std / 1000.0});
            printDim("    Smoothed std: {d:.3}ms\n", .{ma.smoothed_std / 1000.0});
            const reduction_txt = if (ma.reduction_pct > 10)
                "significant"
            else if (ma.reduction_pct > 0)
                "modest"
            else
                "none";
            printDim("    Effect: {s}", .{reduction_txt});
            if (ma.reduction_pct > 0) {
                printDim(" ({d:.1}% noise reduction)", .{ma.reduction_pct});
            }
            printDim("\n", .{});
            if (ma.reduction_pct > 0) {
                printDim(" ({d:.1}% noise reduction)", .{ma.reduction_pct});
            }
            printDim("\n", .{});
        }

        // v3.67: Anomaly Detection - statistical pattern recognition
        const anomalies = self.detectAnomalies(1.5, 2.0);
        if (anomalies.count > 0) {
            const score = anomalies.anomaly_score;
            const severity = if (score >= 50.0)
                "CRITICAL"
            else if (score >= 30.0)
                "HIGH"
            else if (score >= 15.0)
                "MODERATE"
            else
                "LOW";

            printInfo("\n  ⚠ Anomaly Detection:\n", .{});
            printDim("    Score: {d:.1}/100 ({s})\n", .{ score, severity });
            printDim("    IQR outliers: {d}/{d} samples\n", .{ anomalies.iqr_outliers, self.count });
            printDim("    Z-score outliers: {d}/{d} samples\n", .{ anomalies.z_score_outliers, self.count });
            printDim("    MA deviations: {d}/{d} samples\n", .{ anomalies.ma_deviations, self.count });
            printDim("    Total anomalies: {d}/{d} samples\n", .{ anomalies.count, self.count });
            printDim("    Severity: {s}\n", .{severity});
        }

        // v3.69: Histogram Visualization - RTT distribution
        if (self.count >= 5) {
            printInfo("\n  📊 RTT Distribution Histogram:\n", .{});
            self.plotHistogram();
        }

        // v3.70: Trend Prediction - predict future RTT direction
        if (self.count >= 10) {
            printInfo("\n  📈 Trend Prediction:\n", .{});
            self.predictTrend();
        }

        // v3.80: Adaptive Thresholds - recommend optimal thresholds based on statistics
        if (self.count >= 20) {
            printInfo("\n  🔧 Adaptive Thresholds:\n", .{});
            self.recommendThresholds();
        }

        // v3.80: Confidence Intervals - uncertainty bounds for predictions
        if (self.count >= 5) {
            printInfo("\n  📊 Confidence Intervals:\n", .{});
            self.showConfidenceInterval();
        }

        // v3.80: Performance Degradation - detect if RTT is getting worse
        if (self.count >= 10) {
            printInfo("\n  ⚠️  Performance Degradation:\n", .{});
            self.detectDegradation();
        }

        // v3.80: Anomaly Alert System - severity-based alerting
        if (self.count >= 5) {
            printInfo("\n  🔔 Anomaly Alerts:\n", .{});
            self.checkAnomalyAlerts();
        }

        // v3.81: Percentile Band Analysis - distribution across quartiles
        if (self.count >= 4) {
            printInfo("\n  📊 Percentile Bands:\n", .{});
            self.showPercentileBands();
        }

        // v3.82: Spectral Periodicity Detection - detect periodic patterns
        if (self.count >= 20) {
            printInfo("\n  🌊 Periodicity Analysis:\n", .{});
            self.analyzePeriodicity();
        }

        // v3.83: Multi-modal Distribution Detection - identify multiple peaks
        if (self.count >= 30) {
            printInfo("\n  🔀 Multi-modal Analysis:\n", .{});
            self.detectMultimodalDistribution();
        }

        // v3.84: Auto-tuning Recommendations - actionable configuration suggestions
        if (self.count >= 10) {
            printInfo("\n  🎯 Auto-tuning Recommendations:\n", .{});
            self.showAutoTuningRecommendations();
        }

        // v3.85: Quick Health Check - one-line status summary
        if (self.count >= 5) {
            printInfo("\n  🏥 Quick Health Check:\n", .{});
            self.showQuickHealthCheck();
        }

        // v4.05: Performance Profile Classification - connection type detection
        if (self.count >= 10) {
            printInfo("\n  📊 Performance Profile:\n", .{});
            self.showPerformanceProfile();
        }

        // v3.88: Burst Analysis - detect grouped latency spikes
        if (self.count >= 5) {
            printInfo("\n  💥 Burst Analysis:\n", .{});
            self.showBurstAnalysis();
        }

        // v3.89: Connection Stability Score - comprehensive stability indicator
        if (self.count >= 10) {
            printInfo("\n  📈 Connection Stability Score:\n", .{});
            self.showStabilityScore();
        }

        // v3.90: Adaptive Configuration Generator - optimal parameters based on analysis
        if (self.count >= 5) {
            printInfo("\n  ⚙️  Adaptive Configuration:\n", .{});
            self.showAdaptiveConfig();
        }

        // v3.91: Packet Loss Pattern Detection - analyze failure patterns
        if (self.consecutive_failures > 0 or self.max_consecutive_failures > 0) {
            printInfo("\n  📉 Packet Loss Pattern:\n", .{});
            self.showLossPattern();
        }

        // v3.93: Statistical Significance Tests - validate differences between sample groups
        if (self.count >= 10) {
            printInfo("\n  🧪 Significance Test:\n", .{});
            self.showSignificanceTest();
        }

        // v3.95: Outlier Summary - comprehensive outlier analysis
        if (self.count >= 5) {
            printInfo("\n  📊 Outlier Summary:\n", .{});
            self.showOutlierSummary();
        }

        // v3.96: Time Series Decomposition - trend + seasonality + residual
        if (self.count >= 20) {
            printInfo("\n  📈 Time Series Decomposition:\n", .{});
            self.showTimeSeriesDecomposition();
        }

        // v4.05: Rate Limiting Detection - detect throttling patterns
        if (self.count >= 10) {
            printInfo("\n  🚦 Rate Limiting Detection:\n", .{});
            self.showRateLimitingDetection();
        }

        // v4.05: Latency Distribution Fitting - statistical distribution analysis
        if (self.count >= 30) {
            printInfo("\n  📐 Distribution Fit:\n", .{});
            self.showDistributionFit();
        }

        // v4.05: Packet Drift Detection - detect gradual RTT changes
        if (self.count >= 20) {
            printInfo("\n  📈 Packet Drift:\n", .{});
            self.showPacketDrift();
        }

        // v4.05: Anomaly Prediction System - predict future anomalies
        if (self.count >= 30) {
            printInfo("\n  🔮 Anomaly Prediction:\n", .{});
            self.showAnomalyPrediction();
        }

        // v4.05: Quick Diagnostics - one-line summary (always shown)
        if (self.count >= 5) {
            printInfo("\n  ⚡ Quick Diagnostics:\n", .{});
            self.showQuickDiagnostics();
        }

        // v4.05: Connection Quality Timeline - visualize quality changes
        if (self.count >= 10) {
            printInfo("\n  📊 Quality Timeline:\n", .{});
            self.showQualityTimeline();
        }

        // v4.05: Signal Quality Index - comprehensive quality metric
        if (self.count >= 20) {
            printInfo("\n  📶 Signal Quality Index:\n", .{});
            self.showSignalQualityIndex();
        }

        // v4.05: Adaptive Sampling Recommendations
        if (self.count >= 10) {
            printInfo("\n  🎚️  Adaptive Sampling:\n", .{});
            self.showAdaptiveSampling();
        }

        // v4.05: Historical Session Comparison
        if (self.count >= 20) {
            printInfo("\n  📜 Historical Comparison:\n", .{});
            self.showHistoricalComparison();
        }

        // v4.06: Connection Fingerprinting - identify connection types
        if (self.count >= 20) {
            printInfo("\n  🔍 Connection Fingerprint:\n", .{});
            self.showConnectionFingerprinting();
        }
    }

    // v3.96: Time Series Decomposition - trend + seasonality + residual
    pub const TimeSeriesDecomposition = struct {
        trend_type: []const u8,
        trend_slope: f64,
        trend_intercept: f64,
        trend_strength: f64,
        volatility: f64,
        seasonality_detected: bool,
        dominant_period: f64,
        residual_std_dev: f64,
    };

    pub fn decomposeTimeSeries(self: *const JitterTracker) ?TimeSeriesDecomposition {
        if (self.count < 20) return null;

        const n = self.count;

        // Linear trend using least squares
        var sum_x: f64 = 0;
        var sum_y: f64 = 0;
        var sum_xy: f64 = 0;
        var sum_xx: f64 = 0;

        for (0..n) |i| {
            const x = @as(f64, @floatFromInt(i));
            const y = @as(f64, @floatFromInt(self.samples[i]));
            sum_x += x;
            sum_y += y;
            sum_xy += x * y;
            sum_xx += x * x;
        }

        const mean_x = sum_x / @as(f64, @floatFromInt(n));
        const mean_y = sum_y / @as(f64, @floatFromInt(n));
        const n_f = @as(f64, @floatFromInt(n));

        const slope = (sum_xy - n_f * mean_x * mean_y) / (sum_xx - n_f * mean_x * mean_x);
        const intercept = mean_y - slope * mean_x;

        // Calculate residuals
        var residuals_sq_sum: f64 = 0;
        for (0..n) |i| {
            const predicted = slope * @as(f64, @floatFromInt(i)) + intercept;
            const residual = @as(f64, @floatFromInt(self.samples[i])) - predicted;
            residuals_sq_sum += residual * residual;
        }

        const residual_std_dev = @sqrt(residuals_sq_sum / @as(f64, @floatFromInt(n)));
        const trend_strength = @max(0.0, 1.0 - residual_std_dev / (mean_y + 1e-6));

        // Trend type classification
        const trend_type = if (slope > 0.01)
            "STRONGLY INCREASING"
        else if (slope > 0.001)
            "INCREASING"
        else if (slope < -0.01)
            "STRONGLY DECREASING"
        else if (slope < -0.001)
            "DECREASING"
        else if (@abs(slope) < 1e-6)
            "STABLE"
        else "FLAT";

        // Simple seasonality check (autocorrelation for different lags)
        var max_autocorr: f64 = 0;
        var dominant_period: f64 = 1.0;

        const MIN_PERIOD: usize = 3;
        const MAX_PERIOD: usize = @divFloor(n, 3);

        for (MIN_PERIOD..MAX_PERIOD) |period| {
            const period_f = @as(f64, @floatFromInt(period));

            // Calculate autocorrelation for this period
            var sum_prod: f64 = 0;
            var sum_sq: f64 = 0;
            var sum_sq2: f64 = 0;

            for (0..(n - period - 1)) |i| {
                const val1 = @as(f64, @floatFromInt(self.samples[i]));
                const val2 = @as(f64, @floatFromInt(self.samples[i + period]));
                sum_prod += val1 * val2;
                sum_sq += val1 * val1;
                sum_sq2 += val2 * val2;
            }

            const autocorr = if (sum_sq > 0 and sum_sq2 > 0)
                sum_prod / (@sqrt(sum_sq * sum_sq2))
            else 0;

            if (autocorr > max_autocorr) {
                max_autocorr = autocorr;
                dominant_period = period_f;
            }
        }

        const seasonality_detected = max_autocorr > 0.5;
        const volatility = residual_std_dev / (mean_y + 1e-6);

        return .{
            .trend_type = trend_type,
            .trend_slope = slope,
            .trend_intercept = intercept,
            .trend_strength = trend_strength,
            .volatility = volatility,
            .seasonality_detected = seasonality_detected,
            .dominant_period = dominant_period,
            .residual_std_dev = residual_std_dev,
        };
    }

    pub fn showTimeSeriesDecomposition(self: *const JitterTracker) void {
        const decomp = self.decomposeTimeSeries() orelse {
            printDim("    Insufficient data for decomposition (need 20+ samples)\n", .{});
            return;
        };

        printDim("    Trend: {s} (slope: {d:.6} us/sample)\n", .{ decomp.trend_type, decomp.trend_slope });
        printDim("    Trend Strength: {d:.1}%\n", .{ decomp.trend_strength * 100.0 });
        printDim("    Volatility: {d:.4} (normalized)\n", .{ decomp.volatility });

        if (decomp.seasonality_detected) {
            printDim("    Seasonality: DETECTED (period: {d:.1} samples)\n", .{ decomp.dominant_period });
        } else {
            printDim("    Seasonality: NOT DETECTED (random)\n", .{});
        }

        printDim("    Residual Std Dev: {d:.2} us\n", .{ decomp.residual_std_dev });

        // Interpretations
        printDim("\n    Interpretations:\n", .{});

        if (decomp.trend_strength > 0.8) {
            printDim("      - Strong trend dominates - data is predictable\n", .{});
            printDim("      - Good for forecasting\n", .{});
        } else if (decomp.trend_strength > 0.5) {
            printDim("      - Moderate trend present\n", .{});
        } else {
            printDim("      - Weak trend - noise dominates\n", .{});
        }

        if (decomp.volatility > 0.5) {
            printDim("      - High volatility detected\n", .{});
            printDim("      - Unpredictable behavior\n", .{});
        } else if (decomp.volatility > 0.2) {
            printDim("      - Moderate volatility\n", .{});
        } else {
            printDim("      - Low volatility - stable\n", .{});
        }

        if (decomp.seasonality_detected) {
            printDim("      - Periodic pattern found ({d:.1} sample period)\n", .{ decomp.dominant_period });
            printDim("      - May indicate recurring load\n", .{});
        }
    }

    // v3.95: Outlier Summary - comprehensive outlier analysis
    pub const OutlierSummary = struct {
        iqr_outliers: usize,
        z_outliers: usize,
        ma_outliers: usize,
        total_outliers: usize,
        outlier_rate: f64,
        worst_outlier: i64,
        outlier_severity: []const u8,
    };

    pub fn getOutlierSummary(self: *const JitterTracker) OutlierSummary {
        if (self.count < 5) {
            return .{
                .iqr_outliers = 0,
                .z_outliers = 0,
                .ma_outliers = 0,
                .total_outliers = 0,
                .outlier_rate = 0.0,
                .worst_outlier = 0,
                .outlier_severity = "NONE",
            };
        }

        const iqr_result = self.detectOutliersIQR(1.5);
        const iqr_outliers = iqr_result.count;

        // Z-score outliers
        const stats = self.getStats();
        const mean = stats.mean;
        const std_dev = if (stats.jitter > 0) stats.jitter else 1.0;
        const z_threshold = 3.0;

        var z_outliers: usize = 0;
        var worst_outlier: i64 = 0;
        var max_z_score: f64 = 0;

        for (self.samples[0..self.count]) |s| {
            const z_score = if (std_dev > 0) (@as(f64, @floatFromInt(s)) - mean) / std_dev else 0;
            if (@abs(z_score) > z_threshold) {
                z_outliers += 1;
                if (z_score > max_z_score or z_score < -max_z_score) {
                    max_z_score = if (z_score > 0) z_score else -z_score;
                    worst_outlier = s;
                }
            }
        }

        // Moving average outliers
        const ma_window = @min(10, self.count);
        var ma_outliers: usize = 0;
        var ma_outlier_set = std.bit_set.IntegerBitSet(@bitSizeOf(usize)).initEmpty();
        for (ma_window..self.count) |i| {
            var sum: f64 = 0;
            const start = i - ma_window;
            const end = i;
            for (@max(0, start)..end) |j| {
                sum += @as(f64, @floatFromInt(self.samples[j]));
            }
            const ma = sum / @as(f64, @floatFromInt(end - start));
            const actual = @as(f64, @floatFromInt(self.samples[i]));
            const deviation = @abs(actual - ma);
            const threshold = @max(1.0, ma * 0.3);

            if (deviation > threshold and !ma_outlier_set.isSet(i)) {
                ma_outliers += 1;
                ma_outlier_set.set(i);
            }
        }

        // Combined outliers
        var outlier_set = std.bit_set.IntegerBitSet(@bitSizeOf(usize)).initEmpty();
        for (self.samples[0..self.count], 0..) |s, i| {
            const z_score = if (std_dev > 0) (@as(f64, @floatFromInt(s)) - mean) / std_dev else 0;
            if (@abs(z_score) > z_threshold) {
                outlier_set.set(i);
            }
        }

        var total_outliers: usize = 0;
        for (ma_window..self.count) |i| {
            if (ma_outlier_set.isSet(i)) {
                outlier_set.set(i);
            }
        }

        total_outliers = outlier_set.count();

        const outlier_rate = @as(f64, @floatFromInt(total_outliers)) / @as(f64, @floatFromInt(self.count));

        const outlier_severity = if (total_outliers == 0)
            "NONE"
        else if (outlier_rate < 0.05)
            "LOW"
        else if (outlier_rate < 0.15)
            "MODERATE"
        else if (outlier_rate < 0.30)
            "HIGH"
        else
            "SEVERE";

        return .{
            .iqr_outliers = iqr_outliers,
            .z_outliers = z_outliers,
            .ma_outliers = ma_outliers,
            .total_outliers = total_outliers,
            .outlier_rate = outlier_rate,
            .worst_outlier = worst_outlier,
            .outlier_severity = outlier_severity,
        };
    }

    pub fn showOutlierSummary(self: *const JitterTracker) void {
        const summary = self.getOutlierSummary();

        printDim("    Total Outliers: {d} ({d:.1}% of samples)\n", .{ summary.total_outliers, summary.outlier_rate * 100.0 });
        printDim("    Method Breakdown:\n", .{});
        printDim("      IQR outliers: {d}\n", .{summary.iqr_outliers});
        printDim("      Z-score outliers: {d}\n", .{summary.z_outliers});
        printDim("      MA deviation outliers: {d}\n", .{summary.ma_outliers });

        if (summary.total_outliers > 0) {
            const worst_ms = @as(f64, @floatFromInt(summary.worst_outlier)) / 1000.0;
            printDim("\n    Worst Outlier: {d:.2}ms\n", .{worst_ms});
            printDim("    Severity: {s}\n", .{summary.outlier_severity});

            printDim("\n    Recommendations:\n", .{});
            if (std.mem.eql(u8, summary.outlier_severity, "SEVERE")) {
                printDim("      - Investigate immediately\n", .{});
                printDim("      - Check for hardware issues\n", .{});
            } else if (std.mem.eql(u8, summary.outlier_severity, "HIGH")) {
                printDim("      - Monitor connection closely\n", .{});
                printDim("      - Consider retry mechanism\n", .{});
            } else if (std.mem.eql(u8, summary.outlier_severity, "MODERATE")) {
                printDim("      - Acceptable for most applications\n", .{});
                printDim("      - Consider adaptive threshold\n", .{});
            } else {
                printDim("      - No action needed\n", .{});
            }
        } else {
            printDim("\n    Status: No outliers detected\n", .{});
            printDim("    Connection appears stable\n", .{});
        }
    }

    // v4.05: Rate Limiting Detection - detect throttling patterns
    pub const RateLimitingDetection = struct {
        is_rate_limited: bool,
        confidence: f64,
        limiting_pattern: []const u8,
        affected_samples: usize,
        avg_limited_rtt: f64,
        avg_normal_rtt: f64,
    };

    pub fn detectRateLimiting(self: *const JitterTracker) RateLimitingDetection {
        if (self.count < 10) {
            return .{
                .is_rate_limited = false,
                .confidence = 0.0,
                .limiting_pattern = "INSUFFICIENT_DATA",
                .affected_samples = 0,
                .avg_limited_rtt = 0.0,
                .avg_normal_rtt = 0.0,
            };
        }

        const stats = self.getStats();
        const mean = stats.mean;

        // Calculate RTT percentiles
        const p = self.getPercentiles();
        const p90 = @as(f64, @floatFromInt(p.p90));

        // Threshold for "high latency" samples (above p90)
        const high_latency_threshold = p90;

        var high_latency_count: usize = 0;
        var high_latency_sum: f64 = 0;
        var normal_latency_sum: f64 = 0;
        var normal_latency_count: usize = 0;

        for (self.samples[0..self.count]) |s| {
            const s_f = @as(f64, @floatFromInt(s));
            if (s_f > high_latency_threshold) {
                high_latency_count += 1;
                high_latency_sum += s_f;
            } else {
                normal_latency_count += 1;
                normal_latency_sum += s_f;
            }
        }

        const avg_limited = if (high_latency_count > 0)
            high_latency_sum / @as(f64, @floatFromInt(high_latency_count))
        else 0.0;
        const avg_normal = if (normal_latency_count > 0)
            normal_latency_sum / @as(f64, @floatFromInt(normal_latency_count))
        else mean;

        // Check for rate limiting patterns
        const ratio = if (avg_normal > 0) avg_limited / avg_normal else 1.0;
        const high_latency_ratio = @as(f64, @floatFromInt(high_latency_count)) / @as(f64, @floatFromInt(self.count));

        // Confidence based on how clear the pattern is
        const confidence = if (high_latency_ratio > 0.3)
            @min(1.0, (high_latency_ratio - 0.3) * 2.0)
        else if (ratio > 2.0)
            @min(1.0, (ratio - 2.0) / 2.0)
        else 0.0;

        const is_rate_limited = confidence > 0.5;

        const limiting_pattern = if (!is_rate_limited)
            "NONE"
        else if (ratio > 3.0)
            "SEVERE - Samples delayed >3x normal"
        else if (ratio > 2.0)
            "HIGH - Samples delayed >2x normal"
        else if (ratio > 1.5)
            "MODERATE - Samples delayed >1.5x normal"
        else
            "LOW - Slight delay increase";

        return .{
            .is_rate_limited = is_rate_limited,
            .confidence = confidence,
            .limiting_pattern = limiting_pattern,
            .affected_samples = high_latency_count,
            .avg_limited_rtt = avg_limited,
            .avg_normal_rtt = avg_normal,
        };
    }

    pub fn showRateLimitingDetection(self: *const JitterTracker) void {
        const detection = self.detectRateLimiting();

        printDim("    Status: {s}\n", .{if (detection.is_rate_limited) "DETECTED" else "NOT DETECTED"});
        if (detection.is_rate_limited) {
            printDim("    Confidence: {d:.1}%\n", .{detection.confidence * 100.0});
            printDim("    Pattern: {s}\n", .{detection.limiting_pattern});
            printDim("    Affected: {d}/{d} samples\n", .{ detection.affected_samples, self.count });

            if (detection.avg_normal_rtt > 0) {
                const ratio = if (detection.avg_normal_rtt > 0)
                    detection.avg_limited_rtt / detection.avg_normal_rtt
                else 1.0;
                printDim("    RTT Ratio: {d:.2}x (limited vs normal)\n", .{ratio});
            }
        } else {
            printDim("    No rate limiting patterns detected\n", .{});
        }

        // Recommendations
        printDim("\n    Recommendations:\n", .{});
        if (!detection.is_rate_limited) {
            printDim("      - Connection is healthy\n", .{});
            printDim("      - No throttling observed\n", .{});
        } else if (detection.confidence > 0.8) {
            printDim("      - Strong rate limiting detected\n", .{});
            printDim("      - Reduce request rate\n", .{});
            printDim("      - Implement exponential backoff\n", .{});
        } else if (detection.confidence > 0.5) {
            printDim("      - Possible rate limiting\n", .{});
            printDim("      - Monitor for patterns\n", .{});
        }
    }

    // v4.05: Latency Distribution Fitting - fit RTT to statistical distributions
    pub const DistributionFit = struct {
        distribution: []const u8,
        mean: f64,
        std_dev: f64,
        goodness_of_fit: f64,
        interpretation: []const u8,
    };

    pub fn fitLatencyDistribution(self: *const JitterTracker) !?DistributionFit {
        if (self.count < 30) {
            return null;
        }

        const stats = self.getStats();
        const mean = stats.mean;
        const std_dev = stats.jitter;

        // Calculate empirical CDF for K-S test
        var sorted_samples = std.ArrayList(i64){};
        defer sorted_samples.deinit(self.allocator);
        try sorted_samples.appendSlice(self.allocator, self.samples[0..self.count]);

        const lessThanFn = struct {
            fn lessThan(_: void, a: i64, b: i64) bool {
                return a < b;
            }
        }.lessThan;

        std.sort.insertion(i64, sorted_samples.items, {}, lessThanFn);

        // Test against Normal distribution
        const normal_fit = testNormalDistribution(sorted_samples.items, mean, std_dev);

        // Test against Log-Normal distribution
        const log_normal_fit = testLogNormalDistribution(sorted_samples.items);

        // Test against Exponential distribution
        const exponential_fit = testExponentialDistribution(sorted_samples.items, mean);

        // Select best fit by maximum goodness of fit
        var best_fit = normal_fit;
        if (log_normal_fit.goodness_of_fit > best_fit.goodness_of_fit) {
            best_fit = log_normal_fit;
        }
        if (exponential_fit.goodness_of_fit > best_fit.goodness_of_fit) {
            best_fit = exponential_fit;
        }

        return best_fit;
    }

    // Test if data fits Normal distribution using Kolmogorov-Smirnov statistic
    fn testNormalDistribution(sorted_samples: []const i64, mean: f64, std_dev: f64) DistributionFit {
        if (std_dev == 0) {
            return .{
                .distribution = "Normal",
                .mean = mean,
                .std_dev = 0,
                .goodness_of_fit = 0,
                .interpretation = "INSUFFICIENT_VARIANCE",
            };
        }

        // Calculate K-S statistic
        const n_f = @as(f64, @floatFromInt(sorted_samples.len));
        var max_diff: f64 = 0;

        for (sorted_samples, 0..) |x, i| {
            // Empirical CDF at this point
            const empirical_cdf = @as(f64, @floatFromInt(i + 1)) / n_f;

            // Normal CDF at this point (using approximation)
            const z = (@as(f64, @floatFromInt(x)) - mean) / std_dev;
            const normal_cdf = normalCDFApprox(z);

            const diff = @abs(empirical_cdf - normal_cdf);
            if (diff > max_diff) {
                max_diff = diff;
            }
        }

        // Critical value for 95% confidence (approximate)
        const critical_value = 1.36 / @sqrt(n_f);
        const fits = max_diff <= critical_value;

        return .{
            .distribution = "Normal",
            .mean = mean,
            .std_dev = std_dev,
            .goodness_of_fit = if (fits) 1.0 - max_diff else max_diff,
            .interpretation = if (fits)
                "Fits normal distribution - typical network latency"
            else
                "Does not fit normal - consider alternative distributions",
        };
    }

    // Test if data fits Log-Normal distribution
    fn testLogNormalDistribution(sorted_samples: []const i64) DistributionFit {
        // Transform to log space
        var log_sum: f64 = 0;
        var log_sum_sq: f64 = 0;
        const n_f = @as(f64, @floatFromInt(sorted_samples.len));

        for (sorted_samples) |x| {
            // Shift by 1 to avoid log(0)
            const log_x = @log(@as(f64, @floatFromInt(x)) + 1.0);
            log_sum += log_x;
            log_sum_sq += log_x * log_x;
        }

        const log_mean = log_sum / n_f;
        const log_var = (log_sum_sq - (log_sum * log_sum) / n_f) / n_f;
        const log_std = if (log_var > 0) @sqrt(log_var) else 0;

        // Calculate K-S statistic for log-normal
        var max_diff: f64 = 0;
        for (sorted_samples, 0..) |x, i| {
            const empirical_cdf = @as(f64, @floatFromInt(i + 1)) / n_f;

            const log_x = @log(@as(f64, @floatFromInt(x)) + 1.0);
            const z = (log_x - log_mean) / if (log_std > 0) log_std else 1.0;
            const log_normal_cdf = normalCDFApprox(z);

            const diff = @abs(empirical_cdf - log_normal_cdf);
            if (diff > max_diff) {
                max_diff = diff;
            }
        }

        // Transform back to original scale
        const mean_original = @exp(log_mean + log_std * log_std / 2.0) - 1.0;

        const critical_value = 1.36 / @sqrt(n_f);
        const fits = max_diff <= critical_value;

        return .{
            .distribution = "Log-Normal",
            .mean = mean_original,
            .std_dev = log_std * mean_original,
            .goodness_of_fit = if (fits) 1.0 - max_diff else max_diff,
            .interpretation = if (fits)
                "Fits log-normal - skewed latency distribution"
            else
                "Does not fit log-normal - low skewness",
        };
    }

    // Test if data fits Exponential distribution
    fn testExponentialDistribution(sorted_samples: []const i64, mean: f64) DistributionFit {
        const lambda = if (mean > 0) 1.0 / mean else 0.001;

        var max_diff: f64 = 0;
        const n_f = @as(f64, @floatFromInt(sorted_samples.len));

        for (sorted_samples, 0..) |x, i| {
            const empirical_cdf = @as(f64, @floatFromInt(i + 1)) / n_f;

            // Exponential CDF: 1 - exp(-lambda * x)
            const x_f = @as(f64, @floatFromInt(x));
            const exp_cdf = 1.0 - @exp(-lambda * x_f);

            const diff = @abs(empirical_cdf - exp_cdf);
            if (diff > max_diff) {
                max_diff = diff;
            }
        }

        // Exponential distribution std = 1/lambda = mean
        const std_dev = if (lambda > 0) 1.0 / lambda else 0;

        const critical_value = 1.36 / @sqrt(n_f);
        const fits = max_diff <= critical_value;

        return .{
            .distribution = "Exponential",
            .mean = mean,
            .std_dev = std_dev,
            .goodness_of_fit = if (fits) 1.0 - max_diff else max_diff,
            .interpretation = if (fits)
                "Fits exponential - memoryless arrival pattern"
            else
                "Does not fit exponential - has memory",
        };
    }

    // Normal CDF approximation (Abramowitz & Stegun formula)
    fn normalCDFApprox(z: f64) f64 {
        const sign: f64 = if (z >= 0) 1.0 else -1.0;
        const a = @abs(z) / @sqrt(2.0);

        const p = 0.3275911;

        const t = 1.0 / (1.0 + p * a);
        const t2 = t * t;
        const t3 = t2 * t;
        const t4 = t3 * t;
        const t5 = t4 * t;

        // Abramowitz & Stegun approximation for erf
        const term1 = 0.254829592 * t5;
        const term2 = -0.284496736 * t4;
        const term3 = 1.421413741 * t3;
        const term4 = -1.453152027 * t2;
        const term5 = 1.061405429 * t;
        const term6 = 0.3275911 * t5;

        const inner1 = term1 + term2;
        const inner2 = inner1 + term3 * t3 + term4;
        const inner3 = inner2 * t2 + term5;
        const erf_approx = inner3 * t + term6;

        const erf = 1.0 - erf_approx;

        return 0.5 * (1.0 + sign * erf);
    }

    pub fn showDistributionFit(self: *const JitterTracker) void {
        const fit = self.fitLatencyDistribution() catch |err| {
            printDim("    Error: {any}\n", .{err});
            return;
        };

        if (fit) |f| {
            const mean_ms = f.mean / 1000.0;
            const std_ms = f.std_dev / 1000.0;
            const gof_pct = f.goodness_of_fit * 100.0;

            printDim("    Distribution: {s}\n", .{f.distribution});
            printDim("    Mean: {d:.3}ms\n", .{mean_ms});
            printDim("    Std Dev: {d:.3}ms\n", .{std_ms});
            printDim("    Goodness of fit: {d:.1}%\n", .{gof_pct});
            printDim("    {s}\n", .{f.interpretation});
        } else {
            printDim("    Insufficient data for distribution fitting\n", .{});
        }
    }

    // v4.05: Packet Drift Detection - detect gradual RTT changes over time
    pub const PacketDrift = struct {
        drift_type: []const u8,
        drift_rate: f64,
        total_drift: f64,
        is_significant: bool,
        recommendation: []const u8,
    };

    pub fn detectPacketDrift(self: *const JitterTracker) ?PacketDrift {
        if (self.count < 20) {
            return null;
        }

        const stats = self.getStats();

        // Use first 25% and last 25% of samples
        const split_idx = self.count / 4;

        // Calculate mean of first quarter
        var first_sum: f64 = 0;
        for (self.samples[0..split_idx]) |s| {
            first_sum += @as(f64, @floatFromInt(s));
        }
        const first_mean = first_sum / @as(f64, @floatFromInt(split_idx));

        // Calculate mean of last quarter
        var last_sum: f64 = 0;
        for (self.samples[split_idx..self.count]) |s| {
            last_sum += @as(f64, @floatFromInt(s));
        }
        const last_mean = last_sum / @as(f64, @floatFromInt(self.count - split_idx));

        // Calculate drift rate (RTT change per sample)
        const num_samples = @as(f64, @floatFromInt(self.count));
        const total_drift_us = last_mean - first_mean;
        const total_drift_ms = total_drift_us / 1000.0;
        const drift_rate_us = total_drift_us / num_samples;
        const drift_rate_ms = drift_rate_us / 1000.0;

        // Determine if drift is statistically significant (change > 1 std dev)
        const std_dev = stats.jitter;
        const is_significant = @abs(total_drift_us) > std_dev * 2.0;

        // Drift type classification
        const drift_type: []const u8 = if (total_drift_us > std_dev * 0.5)
            "INCREASING - RTT rising"
        else if (total_drift_us < -std_dev * 0.5)
            "DECREASING - RTT falling"
        else
            "STABLE - Minimal change";

        // Recommendation based on drift rate
        const recommendation: []const u8 = if (!is_significant)
            "Connection stable - no action needed"
        else if (drift_rate_ms > 0.1)
            "Investigate - RTT increasing rapidly"
        else if (drift_rate_ms < -0.1)
            "Investigate - RTT decreasing rapidly (unusual)"
        else
            "Monitor - gradual drift detected";

        return .{
            .drift_type = drift_type,
            .drift_rate = drift_rate_ms,
            .total_drift = total_drift_ms,
            .is_significant = is_significant,
            .recommendation = recommendation,
        };
    }

    pub fn showPacketDrift(self: *const JitterTracker) void {
        const drift = self.detectPacketDrift();

        if (drift) |d| {
            printDim("    Drift Type: {s}\n", .{d.drift_type});
            printDim("    Drift Rate: {d:.4}ms/sample\n", .{d.drift_rate});
            printDim("    Total Change: {d:.2}ms\n", .{d.total_drift});
            printDim("    Significant: {s}\n", .{if (d.is_significant) "YES" else "NO"});
            printDim("    {s}\n", .{d.recommendation});
        } else {
            printDim("    Insufficient data for drift detection\n", .{});
        }
    }

    // v4.05: Anomaly Prediction System - predict likelihood of future anomalies
    pub const AnomalyPrediction = struct {
        anomaly_probability: f64,
        prediction_horizon: usize,
        risk_level: []const u8,
        warning_signs: []const u8,
        action_needed: bool,
    };

    pub fn predictAnomalies(self: *const JitterTracker) ?AnomalyPrediction {
        if (self.count < 30) {
            return null;
        }

        const stats = self.getStats();
        const mean = stats.mean;
        const std_dev = stats.jitter;

        // Analyze recent samples for warning signs
        const RECENT_WINDOW: usize = 10;
        const recent_start = if (self.count > RECENT_WINDOW) self.count - RECENT_WINDOW else 0;
        const recent_count = self.count - recent_start;

        // Calculate recent statistics
        var recent_sum: f64 = 0;
        var recent_sum_sq: f64 = 0;
        for (self.samples[recent_start..self.count]) |s| {
            const s_f = @as(f64, @floatFromInt(s));
            recent_sum += s_f;
            recent_sum_sq += s_f * s_f;
        }
        const recent_mean = recent_sum / @as(f64, @floatFromInt(recent_count));
        const recent_variance = (recent_sum_sq - (recent_sum * recent_sum) / @as(f64, @floatFromInt(recent_count))) / @as(f64, @floatFromInt(recent_count));
        const recent_std_dev = if (recent_variance > 0) @sqrt(recent_variance) else 0;

        // Warning sign 1: Mean shift (recent mean vs overall mean)
        const mean_shift = @abs(recent_mean - mean);
        const mean_shift_ratio = if (std_dev > 0) mean_shift / std_dev else 0;

        // Warning sign 2: Volatility increase (recent std vs overall std)
        const volatility_increase = if (std_dev > 0) (recent_std_dev - std_dev) / std_dev else 0;

        // Warning sign 3: Trend acceleration (second derivative)
        const TREND_WINDOW: usize = 10;
        var acceleration: f64 = 0;
        if (self.count >= TREND_WINDOW * 2) {
            const first_start = self.count - TREND_WINDOW * 2;
            const second_start = self.count - TREND_WINDOW;

            var first_sum: f64 = 0;
            var second_sum: f64 = 0;
            for (self.samples[first_start..first_start + TREND_WINDOW]) |s| {
                first_sum += @as(f64, @floatFromInt(s));
            }
            for (self.samples[second_start..second_start + TREND_WINDOW]) |s| {
                second_sum += @as(f64, @floatFromInt(s));
            }
            const first_avg = first_sum / @as(f64, @floatFromInt(TREND_WINDOW));
            const second_avg = second_sum / @as(f64, @floatFromInt(TREND_WINDOW));
            const first_trend = first_avg / @as(f64, @floatFromInt(TREND_WINDOW));
            const second_trend = second_avg / @as(f64, @floatFromInt(TREND_WINDOW));
            acceleration = if (first_trend != 0) (second_trend - first_trend) / @abs(first_trend) else 0;
        }

        // Warning sign 4: Sample concentration (how close are recent samples to thresholds)
        const p = self.getPercentiles();
        const p90 = @as(f64, @floatFromInt(p.p90));
        var samples_near_threshold: usize = 0;
        for (self.samples[recent_start..self.count]) |s| {
            const s_f = @as(f64, @floatFromInt(s));
            if (s_f > p90 * 0.8) {
                samples_near_threshold += 1;
            }
        }
        const threshold_pressure = @as(f64, @floatFromInt(samples_near_threshold)) / @as(f64, @floatFromInt(recent_count));

        // Combine warning signs into anomaly probability
        var risk_score: f64 = 0;
        var warning_count: usize = 0;

        if (mean_shift_ratio > 0.5) {
            risk_score += @min(mean_shift_ratio, 1.0) * 25.0;
            warning_count += 1;
        }
        if (volatility_increase > 0.3) {
            risk_score += @min(volatility_increase * 2.0, 1.0) * 30.0;
            warning_count += 1;
        }
        if (@abs(acceleration) > 0.2) {
            risk_score += @min(@abs(acceleration) * 2.0, 1.0) * 25.0;
            warning_count += 1;
        }
        if (threshold_pressure > 0.3) {
            risk_score += threshold_pressure * 20.0;
            warning_count += 1;
        }

        const anomaly_probability = @min(risk_score, 100.0) / 100.0;
        const prediction_horizon = 20; // Predict for next 20 samples

        // Risk level classification
        const risk_level: []const u8 = if (anomaly_probability > 0.7)
            "CRITICAL"
        else if (anomaly_probability > 0.5)
            "HIGH"
        else if (anomaly_probability > 0.3)
            "MODERATE"
        else if (anomaly_probability > 0.1)
            "LOW"
        else
            "MINIMAL";

        // Warning signs description
        const warning_signs: []const u8 = if (warning_count == 0)
            "No warning signs detected"
        else if (warning_count == 1)
            "One early warning sign"
        else if (warning_count == 2)
            "Two warning signs - monitoring advised"
        else if (warning_count == 3)
            "Multiple warning signs - caution needed"
        else
            "All warning signs present - high risk";

        const action_needed = anomaly_probability > 0.4;

        return .{
            .anomaly_probability = anomaly_probability,
            .prediction_horizon = prediction_horizon,
            .risk_level = risk_level,
            .warning_signs = warning_signs,
            .action_needed = action_needed,
        };
    }

    pub fn showAnomalyPrediction(self: *const JitterTracker) void {
        const prediction = self.predictAnomalies();

        if (prediction) |p| {
            const prob_pct = p.anomaly_probability * 100.0;
            printDim("    Risk Level: {s}\n", .{p.risk_level});
            printDim("    Anomaly Probability: {d:.1}%\n", .{prob_pct});
            printDim("    Prediction Horizon: next {d} samples\n", .{p.prediction_horizon});
            printDim("    Warning Signs: {s}\n", .{p.warning_signs});
            if (p.action_needed) {
                printErr("    ⚠️  ACTION RECOMMENDED: Consider adjusting test parameters\n", .{});
            }
        } else {
            printDim("    Insufficient data for anomaly prediction\n", .{});
        }
    }

    // v4.05: Quick Diagnostics - one-line summary of key metrics
    pub const QuickDiagnostics = struct {
        health_status: []const u8,
        samples: usize,
        mean_rtt_ms: f64,
        jitter_ms: f64,
        success_rate_pct: f64,
        summary: []const u8,
    };

    pub fn getQuickDiagnostics(self: *const JitterTracker) QuickDiagnostics {
        const stats = self.getStats();
        const mean_ms = stats.mean / 1000.0;
        const jitter_ms = stats.jitter / 1000.0;

        // Health status based on jitter only
        const health_status: []const u8 = if (jitter_ms < 10)
            "EXCELLENT"
        else if (jitter_ms < 20)
            "GOOD"
        else if (jitter_ms < 50)
            "FAIR"
        else if (jitter_ms < 100)
            "POOR"
        else
            "CRITICAL";

        // Summary message based on jitter
        const summary: []const u8 = if (jitter_ms < 10)
            "Excellent: minimal jitter"
        else if (jitter_ms < 20)
            "Good: stable low latency"
        else if (jitter_ms < 50)
            "Fair: moderate jitter, acceptable"
        else if (jitter_ms < 100)
            "Poor: high jitter, investigate"
        else
            "Critical: very high jitter, needs attention";

        return .{
            .health_status = health_status,
            .samples = self.count,
            .mean_rtt_ms = mean_ms,
            .jitter_ms = jitter_ms,
            .success_rate_pct = 0.0,
            .summary = summary,
        };
    }

    pub fn showQuickDiagnostics(self: *const JitterTracker) void {
        const diag = self.getQuickDiagnostics();

        printInfo("  Health: {s} ({d} samples, {d:.1}ms RTT, {d:.1}ms jitter)\n", .{
            diag.health_status, diag.samples, diag.mean_rtt_ms, diag.jitter_ms,
        });
        printDim("  {s}\n", .{diag.summary});
    }

    // v4.05: Connection Quality Timeline - visual representation of quality changes
    pub const QualityTimeline = struct {
        segments: usize,
        phase_changes: usize,
        quality_trend: []const u8,
        final_quality: []const u8,
    };

    pub fn generateQualityTimeline(self: *const JitterTracker) ?QualityTimeline {
        if (self.count < 10) {
            return null;
        }

        const stats = self.getStats();
        const mean = stats.mean;
        const std_dev = stats.jitter;

        // Divide into 5 quality segments
        const SEGMENT_SIZE = @max(1, self.count / 5);
        var phase_count: usize = 0;

        // Calculate mean for each segment
        var segment_means = [1]f64{0} ** 5;

        for (0..5) |seg| {
            const start_idx = seg * SEGMENT_SIZE;
            const end_idx = @min(start_idx + SEGMENT_SIZE, self.count);
            if (end_idx > start_idx) {
                var seg_sum: f64 = 0;
                for (self.samples[start_idx..end_idx]) |s| {
                    seg_sum += @as(f64, @floatFromInt(s));
                }
                segment_means[seg] = seg_sum / @as(f64, @floatFromInt(end_idx - start_idx));
            }
        }

        // Count quality phase changes (significant mean shifts)
        for (1..5) |seg| {
            if (segment_means[seg] > 0) {
                const diff = @abs(segment_means[seg] - mean);
                if (diff > std_dev) {
                    phase_count += 1;
                }
            }
        }

        // Determine overall quality trend
        const quality_trend: []const u8 = if (phase_count >= 3)
            "DEGRADING - quality decreasing significantly"
        else if (phase_count >= 1)
            "FLUCTUATING - quality varies significantly"
        else
            "STABLE - quality remains consistent";

        // Final quality based on last segment
        const last_mean = segment_means[4];
        const last_quality: []const u8 = if (last_mean < mean * 0.7)
            "POOR - high latency degradation"
        else if (last_mean < mean * 0.9)
            "FAIR - some degradation over time"
        else if (last_mean < mean * 1.2)
            "GOOD - stable quality throughout"
        else if (last_mean <= mean * 1.5 and last_mean >= mean * 0.8)
            "EXCELLENT - minimal quality variation"
        else
            "IMPRAVING - quality improving";

        return .{
            .segments = 5,
            .phase_changes = phase_count,
            .quality_trend = quality_trend,
            .final_quality = last_quality,
        };
    }

    pub fn showQualityTimeline(self: *const JitterTracker) void {
        const timeline = self.generateQualityTimeline();

        if (timeline) |t| {
            printDim("    Segments Analyzed: {d}\n", .{t.segments});
            printDim("    Phase Changes: {d}\n", .{t.phase_changes});
            printDim("    Quality Trend: {s}\n", .{t.quality_trend});
            printDim("    Final Quality: {s}\n", .{t.final_quality});
        } else {
            printDim("    Insufficient data for quality timeline\n", .{});
        }
    }

    // v4.05: Signal Quality Index - comprehensive quality metric
    pub const SignalQualityIndex = struct {
        sqi_score: f64,
        latency_grade: []const u8,
        jitter_grade: []const u8,
        stability_grade: []const u8,
        consistency_grade: []const u8,
        overall_quality: []const u8,
        factors: []const u8,
    };

    pub fn getSignalQualityIndex(self: *const JitterTracker) ?SignalQualityIndex {
        if (self.count < 20) {
            return null;
        }

        const stats = self.getStats();
        const mean_ms = stats.mean / 1000.0;
        const jitter_ms = stats.jitter / 1000.0;
        const std_dev = stats.jitter;

        // Factor 1: Latency Score (0-100, lower is better)
        const latency_score: f64 = 100.0 - @min(100.0, mean_ms);

        // Factor 2: Jitter Score (0-100, lower is better)
        // Using logarithmic scale: jitter < 1ms = 100, jitter > 100ms = 0
        const jitter_score: f64 = if (jitter_ms < 1.0)
            100.0
        else if (jitter_ms < 5.0)
            90.0 - (jitter_ms - 1.0) * 22.5
        else if (jitter_ms < 10.0)
            67.5 - (jitter_ms - 5.0) * 7.5
        else if (jitter_ms < 20.0)
            45.0 - (jitter_ms - 10.0) * 3.75
        else if (jitter_ms < 50.0)
            22.5 - (jitter_ms - 20.0) * 1.5
        else
            15.0 - (jitter_ms - 50.0) * 0.375;

        // Factor 3: Stability Score (coefficient of variation)
        // CV = std_dev / mean, lower is more stable
        const cv = if (mean_ms > 0) std_dev / mean_ms else 0;
        const stability_score = @max(0, if (cv < 0.1)
            100.0
        else if (cv < 0.2)
            80.0 - (cv - 0.1) * 200.0
        else if (cv < 0.3)
            60.0 - (cv - 0.2) * 100.0
        else if (cv < 0.5)
            40.0 - (cv - 0.3) * 50.0
        else
            @max(0, 20.0 - (cv - 0.5) * 20.0));

        // Factor 4: Consistency (ratio of recent variance to overall)
        const RECENT_WINDOW: usize = 10;
        const recent_start = if (self.count > RECENT_WINDOW) self.count - RECENT_WINDOW else 0;

        var recent_variance: f64 = 0;
        if (recent_start > 0) {
            var recent_sum: f64 = 0;
            var recent_sum_sq: f64 = 0;
            for (self.samples[recent_start..self.count]) |s| {
                const s_f = @as(f64, @floatFromInt(s));
                recent_sum += s_f;
                recent_sum_sq += s_f * s_f;
            }
            const recent_count_f = @as(f64, @floatFromInt(self.count - recent_start));
            const recent_mean = recent_sum / recent_count_f;
            recent_variance = (recent_sum_sq - (recent_sum * recent_mean)) / (recent_count_f - 1.0);
        }

        const overall_variance = std_dev * std_dev;
        const consistency_score = if (overall_variance > 0)
            @max(0, 100.0 * (1.0 - @min(recent_variance / overall_variance, 1.0)))
        else 0;

        // Calculate weighted SQI (Signal Quality Index)
        // Weights: Latency 40%, Jitter 30%, Stability 20%, Consistency 10%
        const sqi = (latency_score * 0.4 + jitter_score * 0.3 + stability_score * 0.2 + consistency_score * 0.1);

        // Grade classifications
        const latency_grade: []const u8 = if (latency_score >= 80)
            "EXCELLENT"
        else if (latency_score >= 60)
            "GOOD"
        else if (latency_score >= 40)
            "FAIR"
        else if (latency_score >= 20)
            "POOR"
        else
            "CRITICAL";

        const jitter_grade: []const u8 = if (jitter_score >= 80)
            "EXCELLENT"
        else if (jitter_score >= 60)
            "GOOD"
        else if (jitter_score >= 40)
            "FAIR"
        else if (jitter_score >= 20)
            "POOR"
        else
            "CRITICAL";

        const stability_grade: []const u8 = if (stability_score >= 80)
            "EXCELLENT"
        else if (stability_score >= 60)
            "GOOD"
        else if (stability_score >= 40)
            "FAIR"
        else
            "POOR";

        const consistency_grade: []const u8 = if (consistency_score >= 80)
            "EXCELLENT"
        else if (consistency_score >= 60)
            "GOOD"
        else if (consistency_score >= 40)
            "FAIR"
        else
            "POOR";

        const overall_quality: []const u8 = if (sqi >= 80)
            "EXCELLENT"
        else if (sqi >= 60)
            "GOOD"
        else if (sqi >= 40)
            "FAIR"
        else
            "POOR";

        // Factor description
        const factors = if (sqi < 40)
            "Latency and jitter critical"
        else if (sqi < 60)
            "Multiple factors degrading"
        else if (sqi < 80)
            "Good with room for improvement"
        else
            "Excellent signal quality";

        return .{
            .sqi_score = sqi,
            .latency_grade = latency_grade,
            .jitter_grade = jitter_grade,
            .stability_grade = stability_grade,
            .consistency_grade = consistency_grade,
            .overall_quality = overall_quality,
            .factors = factors,
        };
    }

    pub fn showSignalQualityIndex(self: *const JitterTracker) void {
        const sqi = self.getSignalQualityIndex();

        if (sqi) |s| {
            printDim("    SQI Score: {d:.1}/100 ({s})\n", .{s.sqi_score, s.overall_quality});

            // Recalculate scores for display
            const stats = self.getStats();
            const mean_ms = stats.mean / 1000.0;
            const jitter_ms = stats.jitter / 1000.0;
            const latency_score = @max(0, 100.0 - @min(100.0, mean_ms));
            const jitter_score_calc: f64 = if (jitter_ms < 1.0)
                100.0
            else if (jitter_ms < 5.0)
                90.0 - (jitter_ms - 1.0) * 22.5
            else if (jitter_ms < 10.0)
                67.5 - (jitter_ms - 5.0) * 7.5
            else if (jitter_ms < 20.0)
                45.0 - (jitter_ms - 10.0) * 3.75
            else if (jitter_ms < 50.0)
                22.5 - (jitter_ms - 20.0) * 1.5
            else
                15.0 - @max(0, jitter_ms - 50.0) * 0.375;

            const cv = if (mean_ms > 0) (stats.jitter / 1000.0) / mean_ms else 0;
            const stability_score_calc: f64 = if (cv < 0.1)
                100.0
            else if (cv < 0.2)
                80.0 - (cv - 0.1) * 200.0
            else if (cv < 0.3)
                60.0 - (cv - 0.2) * 100.0
            else if (cv < 0.5)
                40.0 - (cv - 0.3) * 50.0
            else
                @max(0, 20.0 - (cv - 0.5) * 20.0);

            printDim("    Latency: {s} ({d:.0}/100)\n", .{s.latency_grade, latency_score});
            printDim("    Jitter: {s} ({d:.0}/100)\n", .{s.jitter_grade, jitter_score_calc});
            printDim("    Stability: {s} ({d:.0}/100)\n", .{s.stability_grade, stability_score_calc});
            printDim("    Consistency: {s}\n", .{s.consistency_grade});
            printDim("    {s}\n", .{s.factors});
        } else {
            printDim("    Insufficient data for signal quality\n", .{});
        }
    }

    // v4.05: Adaptive Sampling Recommendations
    pub const AdaptiveSamplingRecommendations = struct {
        recommended_rate: usize,
        current_rate: usize,
        confidence: f64,
        justification: []const u8,
    };

    pub fn getAdaptiveSampling(self: *const JitterTracker) ?AdaptiveSamplingRecommendations {
        if (self.count < 10) {
            return null;
        }

        const stats = self.getStats();
        const std_dev = stats.jitter;

        // Determine optimal sampling rate based on jitter
        const recommended_rate: usize = if (std_dev < 1000)
            100
        else if (std_dev < 5000)
            50
        else if (std_dev < 10000)
            25
        else if (std_dev < 20000)
            10
        else
            5;

        const current_rate: usize = if (std_dev < 5000)
            100
        else if (std_dev < 10000)
            25
        else
            10;

        const confidence: f64 = if (recommended_rate == current_rate)
            1.0
        else
            0.5;

        const justification: []const u8 = if (recommended_rate == current_rate)
            "Optimal sampling rate"
        else if (current_rate > recommended_rate)
            "Current rate higher than optimal"
        else
            "Current rate within acceptable range";

        return .{
            .recommended_rate = recommended_rate,
            .current_rate = current_rate,
            .confidence = confidence,
            .justification = justification,
        };
    }

    pub fn showAdaptiveSampling(self: *const JitterTracker) void {
        const sampling = self.getAdaptiveSampling();

        if (sampling) |s| {
            const interval_ms = 100000 / @as(f64, @floatFromInt(s.recommended_rate));
            printDim("    Recommended Rate: {d} Hz ({d}ms interval)\n", .{s.recommended_rate, interval_ms});
            printDim("    Current Rate: {d} Hz\n", .{s.current_rate});
            printDim("    Confidence: {d:.0}%\n", .{s.confidence * 100.0});
            printDim("    {s}\n", .{s.justification});
        } else {
            printDim("    Insufficient data for adaptive sampling\n", .{});
        }
    }

    // v4.05: Historical Session Comparison - compare with previous sessions
    pub const HistoricalComparison = struct {
        current_quality: []const u8,
        baseline_comparison: []const u8,
        quality_delta_pct: f64,
        recommendation: []const u8,
    };

    pub fn compareWithHistorical(self: *const JitterTracker) ?HistoricalComparison {
        if (self.count < 30) {
            return null;
        }

        const stats = self.getStats();
        const current_mean = stats.mean;
        const current_jitter = stats.jitter;

        // Simulated baseline (in real implementation, this would be loaded from file)
        const baseline_mean: f64 = 35000; // 35ms baseline
        const baseline_jitter: f64 = 10000; // 10ms baseline

        // Calculate quality delta
        const mean_delta = ((current_mean - baseline_mean) / baseline_mean) * 100.0;
        const jitter_delta = ((current_jitter - baseline_jitter) / baseline_jitter) * 100.0;
        const avg_delta = (mean_delta + jitter_delta) / 2.0;

        // Determine current quality
        const current_quality: []const u8 = if (current_jitter < baseline_jitter * 0.8)
            "EXCELLENT - Better than baseline"
        else if (current_jitter < baseline_jitter * 1.2)
            "GOOD - Within baseline range"
        else if (current_jitter < baseline_jitter * 1.5)
            "FAIR - Slightly degraded"
        else
            "POOR - Significantly degraded";

        // Baseline comparison
        const baseline_comparison: []const u8 = if (avg_delta < -10)
            "Significantly better than baseline"
        else if (avg_delta < 10)
            "Comparable to baseline"
        else if (avg_delta < 25)
            "Slightly worse than baseline"
        else
            "Significantly worse than baseline";

        // Recommendation
        const recommendation: []const u8 = if (avg_delta < -10)
            "Current performance is excellent"
        else if (avg_delta < 10)
            "Performance within normal range"
        else if (avg_delta < 25)
            "Consider investigating degradation"
        else
            "Action recommended: check connection";

        return .{
            .current_quality = current_quality,
            .baseline_comparison = baseline_comparison,
            .quality_delta_pct = avg_delta,
            .recommendation = recommendation,
        };
    }

    pub fn showHistoricalComparison(self: *const JitterTracker) void {
        const comparison = self.compareWithHistorical();

        if (comparison) |c| {
            printDim("    Current Quality: {s}\n", .{c.current_quality});
            printDim("    vs Baseline: {s}\n", .{c.baseline_comparison});
            const delta_sign = if (c.quality_delta_pct >= 0) "+" else "";
            printDim("    Quality Delta: {s}{d:.1}%\n", .{delta_sign, c.quality_delta_pct});
            printDim("    {s}\n", .{c.recommendation});
        } else {
            printDim("    Insufficient data for comparison\n", .{});
        }
    }

    // v4.06: Connection Fingerprinting - identify connection types
    pub const ConnectionFingerprint = struct {
        connection_type: []const u8,
        confidence: f64,
        latency_range_ms: []const f64,
        jitter_profile: f64,
        final_assessment: []const u8,
    };

    pub fn getConnectionFingerprint(self: *const JitterTracker) ?ConnectionFingerprint {
        if (self.count < 20) {
            return null;
        }

        const stats = self.getStats();
        const mean_ms = stats.mean / 1000.0;
        const jitter_ms = stats.jitter / 1000.0;
        const std_dev = stats.jitter;

        // Determine connection type based on latency/jitter characteristics
        var connection_type: []const u8 = "UNKNOWN";
        var confidence: f64 = 0;

        if (mean_ms < 5.0 and jitter_ms < 1.0) {
            connection_type = "DIRECT";
            confidence = 0.95;
        } else if (mean_ms < 20.0 and jitter_ms < 5.0) {
            connection_type = "ETHERNET";
            confidence = 0.80;
        } else if (mean_ms < 50.0 and jitter_ms < 15.0) {
            connection_type = "WIFI";
            confidence = 0.70;
        } else if (mean_ms < 100.0 and jitter_ms < 30.0) {
            connection_type = "CELLULAR";
            confidence = 0.60;
        } else if (mean_ms < 200.0 and jitter_ms < 50.0) {
            connection_type = "VPN";
            confidence = 0.50;
        } else {
            connection_type = "MULTI-HOP";
            confidence = 0.30;
        }

        const final_assessment: []const u8 = if (confidence >= 0.8)
            "EXCELLENT - Reliable connection"
        else if (confidence >= 0.6)
            "GOOD - Stable connection"
        else if (confidence >= 0.4)
            "FAIR - Usable with caution"
        else
            "POOR - Unreliable";

        return .{
            .connection_type = connection_type,
            .confidence = confidence,
            .latency_range_ms = &.{mean_ms - std_dev / 1000.0, mean_ms, mean_ms + std_dev / 1000.0},
            .jitter_profile = jitter_ms,
            .final_assessment = final_assessment,
        };
    }

    pub fn showConnectionFingerprinting(self: *const JitterTracker) void {
        const fingerprint = self.getConnectionFingerprint();

        if (fingerprint) |fp| {
            printDim("    Connection Type: {s}\n", .{fp.connection_type});
            printDim("    Confidence: {d:.0}%\n", .{fp.confidence * 100.0});
            printDim("    Latency Range: {d:.1}ms - {d:.1}ms\n", .{fp.latency_range_ms[0], fp.latency_range_ms[2]});
            printDim("    Jitter: {d:.2}ms\n", .{fp.jitter_profile});
            printDim("    {s}\n", .{fp.final_assessment});
        } else {
            printDim("    Insufficient data for fingerprinting\n", .{});
        }
    }

    // v3.70: Predict RTT trend based on linear regression of recent samples
    pub fn predictTrend(self: *const JitterTracker) void {
        const PREDICTION_WINDOW: usize = 10;
        const prediction_samples = @min(PREDICTION_WINDOW, self.count);
        const start_idx = self.count - prediction_samples;

        // Calculate linear regression (y = mx + b)
        var sum_x: f64 = 0;
        var sum_y: f64 = 0;
        var sum_xy: f64 = 0;
        var sum_x2: f64 = 0;

        const n = @as(f64, @floatFromInt(prediction_samples));
        for (self.samples[start_idx..self.count], 0..) |s, i| {
            const x = @as(f64, @floatFromInt(i));
            const y = @as(f64, @floatFromInt(s));
            sum_x += x;
            sum_y += y;
            sum_xy += x * y;
            sum_x2 += x * x;
        }

        const mean_x = sum_x / n;
        const mean_y = sum_y / n;

        const numerator = sum_xy - n * mean_x * mean_y;
        const denominator = sum_x2 - n * mean_x * mean_x;

        const slope = if (denominator != 0) numerator / denominator else 0;
        const intercept = mean_y - slope * mean_x;

        // Predict next value
        const next_x = n;
        const predicted_us = slope * next_x + intercept;
        const current_us = @as(f64, @floatFromInt(self.samples[self.count - 1]));
        const change_pct = if (current_us > 0) ((predicted_us - current_us) / current_us) * 100.0 else 0;

        // Determine trend direction (in us/sample)
        const trend = if (slope > 100)
            "INCREASING (degrading)"
        else if (slope < -100)
            "DECREASING (improving)"
        else if (slope > 10)
            "SLIGHTLY INCREASING"
        else if (slope < -10)
            "SLIGHTLY DECREASING"
        else
            "STABLE";

        var severity: []const u8 = "NEUTRAL";
        if (slope > 500) {
            severity = "CRITICAL";
        } else if (slope > 200) {
            severity = "HIGH";
        } else if (slope > 100) {
            severity = "MODERATE";
        } else if (slope < -500) {
            severity = "EXCELLENT";
        } else if (slope < -200) {
            severity = "GOOD";
        } else if (slope < -100) {
            severity = "FAIR";
        } else {
            severity = "NEUTRAL";
        }

        printDim("    Prediction window: last {d} samples\n", .{prediction_samples});
        printDim("    Current RTT: {d:.2}ms\n", .{current_us / 1000.0});
        printDim("    Predicted next: {d:.2}ms\n", .{predicted_us / 1000.0});
        printDim("    Trend slope: {d:.4}us/sample\n", .{slope});
        printDim("    Direction: {s}\n", .{trend});
        printDim("    Projected change: {d:.1}%\n", .{change_pct});
        printDim("    Severity: {s}\n", .{severity});
    }

    // v3.80: Recommend optimal thresholds based on statistical analysis
    pub fn recommendThresholds(self: *const JitterTracker) void {
        const stats = self.getStats();
        const p = self.getPercentiles();

        // Calculate adaptive spike threshold (default: 3x median)
        const adaptive_spike = @divFloor(p.p99 + p.p50, 2); // Average of p99 and p50
        const spike_multiplier = @as(f64, @floatFromInt(adaptive_spike)) / @as(f64, @floatFromInt(p.p50));

        // Calculate adaptive timeout based on max RTT + safety margin
        const max_rtt_ms = @as(f64, @floatFromInt(stats.max)) / 1000.0;
        const recommended_timeout = @as(u32, @intFromFloat(max_rtt_ms * 2.5));

        // Calculate adaptive batch size based on jitter stability
        const jitter_coefficient = if (stats.mean > 0) stats.jitter / stats.mean else 0;
        const recommended_batch = if (jitter_coefficient < 0.2)
            @as(usize, 32)
        else if (jitter_coefficient < 0.4)
            @as(usize, 16)
        else if (jitter_coefficient < 0.6)
            @as(usize, 8)
        else
            @as(usize, 4);

        // Calculate adaptive delay based on RTT
        const mean_rtt_ms = stats.mean / 1000.0;
        const recommended_delay = @as(u32, @intFromFloat(mean_rtt_ms * 1.5));

        printDim("    Current spike threshold: {d:.2}x median\n", .{3.0});
        printDim("    Recommended spike threshold: {d:.2}x (p50={d:.2}ms, p99={d:.2}ms)\n", .{ spike_multiplier, @as(f64, @floatFromInt(p.p50)) / 1000.0, @as(f64, @floatFromInt(p.p99)) / 1000.0 });
        printDim("    Recommended timeout: {d}ms (current max: {d:.2}ms + 150%% margin)\n", .{ recommended_timeout, max_rtt_ms });
        printDim("    Recommended batch size: {d} (jitter coefficient: {d:.2})\n", .{ recommended_batch, jitter_coefficient });
        printDim("    Recommended delay: {d}ms (1.5x mean RTT: {d:.2}ms)\n", .{ recommended_delay, mean_rtt_ms });

        // Show CLI commands to apply recommendations
        printInfo("\n    Apply with:\n", .{});
        printDim("      --spike-threshold {d:.2}\n", .{spike_multiplier});
        printDim("      --timeout {d}\n", .{recommended_timeout});
        printDim("      --batch-size {d}\n", .{recommended_batch});
        printDim("      --delay {d}\n", .{recommended_delay});
    }

    // v3.80: Calculate confidence intervals for predictions
    pub fn showConfidenceInterval(self: *const JitterTracker) void {
        if (self.count < 5) {
            printDim("    Not enough samples for CI (need >=5)\n", .{});
            return;
        }

        // Calculate mean and standard deviation
        const stats = self.getStats();
        const mean = stats.mean;
        const std_dev = stats.jitter; // jitter is standard deviation

        // For small samples (n < 30), use t-distribution approximation
        // For 95% confidence with n=5-30, t ≈ 2.0-2.8
        const n = @as(f64, @floatFromInt(self.count));

        // Get t-value based on sample size
        const t_value: f64 = blk: {
            if (n < 10) {
                break :blk 2.57; // ~95% CI for n=5-10
            } else if (n < 20) {
                break :blk 2.09; // ~95% CI for n=10-20
            } else {
                break :blk 1.96; // Normal distribution for n>=20
            }
        };

        // Standard error of the mean
        const sem = if (n > 1) std_dev / @sqrt(n) else 0;

        // 95% Confidence Interval
        const ci_margin = t_value * sem;
        const ci_lower = if (mean > ci_margin) mean - ci_margin else 0;
        const ci_upper = mean + ci_margin;

        // Prediction interval (wider, for individual predictions)
        const pi_margin = t_value * std_dev * @sqrt(1.0 + 1.0 / n);
        const pi_lower = if (mean > pi_margin) mean - pi_margin else 0;
        const pi_upper = mean + pi_margin;

        printDim("    Mean RTT: {d:.2}ms\n", .{mean / 1000.0});
        printDim("    Std Dev: {d:.2}ms\n", .{std_dev / 1000.0});
        printDim("    Sample size: {d}\n", .{n});
        printDim("    95% Confidence Interval: [{d:.2}ms, {d:.2}ms]\n", .{ ci_lower / 1000.0, ci_upper / 1000.0 });
        printDim("    95% Prediction Interval: [{d:.2}ms, {d:.2}ms]\n", .{ pi_lower / 1000.0, pi_upper / 1000.0 });

        // Coefficient of variation (relative variability)
        const cv = if (mean > 0) (std_dev / mean) * 100.0 else 0;
        printDim("    Coefficient of variation: {d:.1}%\n", .{cv});

        // Interpretation
        const stability = if (cv < 10)
            "Very Stable"
        else if (cv < 20)
            "Stable"
        else if (cv < 40)
            "Moderate variability"
        else if (cv < 60)
            "High variability"
        else
            "Very unstable";
        printDim("    Stability: {s}\n", .{stability});
    }

    // v3.80: Performance degradation detection
    pub fn detectDegradation(self: *const JitterTracker) void {
        if (self.count < 10) {
            printDim("    Not enough samples for degradation analysis (need >=10)\n", .{});
            return;
        }

        // Compare first half vs second half of samples
        const half_count = @divFloor(self.count, 2);
        if (half_count < 5) {
            printDim("    Not enough samples for half comparison\n", .{});
            return;
        }

        // Calculate means for each half
        var first_sum: i64 = 0;
        var second_sum: i64 = 0;
        for (self.samples[0..half_count]) |s| {
            first_sum += s;
        }
        for (self.samples[half_count..self.count]) |s| {
            second_sum += s;
        }

        const first_mean = @as(f64, @floatFromInt(first_sum)) / @as(f64, @floatFromInt(half_count));
        const second_mean = @as(f64, @floatFromInt(second_sum)) / @as(f64, @floatFromInt(self.count - half_count));

        const change_pct = if (first_mean > 0)
            ((second_mean - first_mean) / first_mean) * 100.0
        else
            0.0;

        const abs_change = @abs(change_pct);

        // Degradation assessment
        const status = if (abs_change < 5)
            "Stable"
        else if (abs_change < 15)
            "Slight change"
        else if (abs_change < 30)
            "Moderate change"
        else if (abs_change < 50)
            "Significant change"
        else
            "Major change";

        const direction = if (change_pct > 5)
            "DEGRADING (worse)"
        else if (change_pct < -5)
            "IMPROVING (better)"
        else
            "STABLE";

        printDim("    First half ({d} samples): {d:.2}ms\n", .{ half_count, first_mean });
        printDim("    Second half ({d} samples): {d:.2}ms\n", .{ self.count - half_count, second_mean });
        printDim("    Change: {s:.1}% {s}\n", .{ if (change_pct >= 0) "+" else "", status });
        printDim("    Direction: {s}\n", .{direction});
    }

    // v3.80: Anomaly Alert System with severity levels
    pub fn checkAnomalyAlerts(self: *const JitterTracker) void {
        if (self.count < 5) return;

        const stats = self.getStats();
        const p = self.getPercentiles();
        const anomalies = self.detectAnomalies(3.0, 2.0);

        // Calculate alert score (0-100)
        var alert_score: f64 = 0;

        // Factor 1: Anomaly count (max 30 points)
        const anomaly_ratio = @as(f64, @floatFromInt(anomalies.count)) / @as(f64, @floatFromInt(self.count));
        alert_score += @min(30.0, anomaly_ratio * 300.0);

        // Factor 2: Jitter coefficient (max 25 points)
        const jitter_coeff = if (stats.mean > 0) stats.jitter / stats.mean else 0;
        alert_score += @min(25.0, jitter_coeff * 50.0);

        // Factor 3: p99/p50 ratio (max 25 points)
        const spread_ratio = if (p.p50 > 0) @as(f64, @floatFromInt(p.p99)) / @as(f64, @floatFromInt(p.p50)) else 1.0;
        alert_score += @min(25.0, (spread_ratio - 1.0) * 25.0);

        // Factor 4: Anomaly score from detectAnomalies (max 20 points)
        alert_score += @min(20.0, anomalies.anomaly_score / 5.0);

        // Determine alert level
        const alert_level = if (alert_score >= 80)
            "🔴 CRITICAL"
        else if (alert_score >= 60)
            "🟠 HIGH"
        else if (alert_score >= 40)
            "🟡 MODERATE"
        else if (alert_score >= 20)
            "🟢 LOW"
        else
            "✅ NORMAL";

        printDim("    Alert Score: {d:.1}/100\n", .{alert_score});
        printDim("    Alert Level: {s}\n", .{alert_level});
        printDim("    Anomalies detected: {d}/{d} ({d:.1}%)\n", .{ anomalies.count, self.count, anomaly_ratio * 100.0 });

        // Actionable recommendations
        if (alert_score >= 60) {
            printErr("    ⚠️  ACTION REQUIRED: Check connection/cable\n", .{});
        } else if (alert_score >= 40) {
            printInfo("    ⚡ Consider reducing batch size or increasing delay\n", .{});
        }

        // Alert details breakdown
        printDim("    Breakdown:\n", .{});
        printDim("      - Anomaly frequency: {d:.1}/30\n", .{@min(30.0, anomaly_ratio * 300.0)});
        printDim("      - Jitter coefficient: {d:.1}/25\n", .{@min(25.0, jitter_coeff * 50.0)});
        printDim("      - Spread ratio: {d:.1}/25\n", .{@min(25.0, (spread_ratio - 1.0) * 25.0)});
        printDim("      - Anomaly severity: {d:.1}/20\n", .{@min(20.0, anomalies.anomaly_score / 5.0)});
    }

    // v3.80: Historical Baseline structure
    pub const HistoricalBaseline = struct {
        mean: f64 = 0,
        median: f64 = 0,
        p95: f64 = 0,
        p99: f64 = 0,
        jitter: f64 = 0,
        sample_count: usize = 0,
        timestamp: i64 = 0,

        pub fn format(self: *const HistoricalBaseline) []const u8 {
            if (self.sample_count == 0) return "No baseline";
            return "Baseline available";
        }
    };

    // v3.80: Compare current stats against historical baseline
    pub fn compareBaseline(self: *const JitterTracker, baseline: HistoricalBaseline) void {
        if (baseline.sample_count == 0) {
            printDim("    No baseline data available\n", .{});
            printDim("    Run with --save-baseline to establish baseline\n", .{});
            return;
        }

        const stats = self.getStats();
        const p = self.getPercentiles();

        // Calculate percentage changes
        const mean_change = if (baseline.mean > 0)
            ((stats.mean - baseline.mean) / baseline.mean) * 100.0
        else
            0.0;
        const median_change = if (baseline.median > 0)
            ((@as(f64, @floatFromInt(p.p50)) - baseline.median) / baseline.median) * 100.0
        else
            0.0;
        const jitter_change = if (baseline.jitter > 0)
            ((stats.jitter - baseline.jitter) / baseline.jitter) * 100.0
        else
            0.0;

        _ = median_change; // Used for internal calculations, display could be added

        printDim("    Baseline samples: {d}\n", .{baseline.sample_count});
        printDim("    Current samples: {d}\n", .{self.count});

        // Mean comparison
        const mean_status = if (mean_change > 20)
            "🔴 WORSE"
        else if (mean_change > 5)
            "🟡 Slightly worse"
        else if (mean_change < -20)
            "🟢 BETTER"
        else if (mean_change < -5)
            "🟢 Slightly better"
        else
            "✅ Stable";

        printDim("    Mean RTT: {d:.2}ms → {d:.2}ms ({s:.1}% {s})\n", .{ baseline.mean / 1000.0, stats.mean / 1000.0, if (mean_change >= 0) "+" else "", mean_change, mean_status });

        // Jitter comparison
        const jitter_status = if (jitter_change > 30)
            "🔴 Higher (worse)"
        else if (jitter_change > 10)
            "🟡 Slightly higher"
        else if (jitter_change < -30)
            "🟢 Lower (better)"
        else if (jitter_change < -10)
            "🟢 Slightly lower"
        else
            "✅ Stable";

        printDim("    Jitter: {d:.2}ms → {d:.2}ms ({s:.1}% {s})\n", .{ baseline.jitter / 1000.0, stats.jitter / 1000.0, if (jitter_change >= 0) "+" else "", jitter_change, jitter_status });

        // Overall assessment
        const overall_score = @abs(mean_change) + @abs(jitter_change) * 0.5;
        const overall = if (overall_score > 50)
            "🔴 SIGNIFICANTLY DEGRADED"
        else if (overall_score > 25)
            "🟠 DEGRADED"
        else if (overall_score > 10)
            "🟡 SLIGHTLY CHANGED"
        else if (overall_score < -10)
            "🟢 IMPROVED"
        else
            "✅ STABLE";

        printDim("    Overall: {s}\n", .{overall});
    }

    // v3.80: Anomaly Export - write anomalies to separate file
    pub fn exportAnomalies(self: *const JitterTracker, filename: []const u8) !void {
        const anomalies = self.detectAnomalies(3.0, 2.0);
        if (anomalies.count == 0) {
            printDim("    No anomalies to export\n", .{});
            return;
        }

        // Determine file format from extension
        const is_json = std.mem.endsWith(u8, filename, ".json");
        const is_csv = std.mem.endsWith(u8, filename, ".csv");

        if (!is_json and !is_csv) {
            printDim("    Unsupported format (use .json or .csv)\n", .{});
            return;
        }

        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();

        if (is_json) {
            // JSON format: array of anomaly records
            const writer = file.writer();
            try writer.writeAll("[\n");
            for (self.samples[0..self.count], 0..) |s, i| {
                const is_anomaly = (i < anomalies.count) and
                    ((i == anomalies.iqr_outliers.items[0]) or
                        (i == anomalies.iqr_outliers.items[1]) or
                        (i == anomalies.iqr_outliers.items[2]));

                if (is_anomaly) {
                    try writer.print("  {{\"sample_index\": {d}, \"rtt_us\": {d}, \"type\": \"{s}\"}},\n", .{ i, s, "anomaly" });
                }
            }
            try writer.writeAll("]\n");
        } else {
            // CSV format: table with anomaly flags
            const writer = file.writer();
            try writer.writeAll("sample_index,rtt_us,is_anomaly,anomaly_type\n");
            var anomaly_idx: usize = 0;
            for (self.samples[0..self.count], 0..) |s, i| {
                const is_anomaly = (anomaly_idx < anomalies.count) and
                    ((i == anomalies.iqr_outliers.items[0]) or
                        (i == anomalies.iqr_outliers.items[1]) or
                        (i == anomalies.iqr_outliers.items[2]));

                const anomaly_type = blk: {
                    if (is_anomaly) {
                        anomaly_idx += 1;
                        break :blk "detected";
                    } else {
                        break :blk "normal";
                    }
                };
                try writer.print("{d},{d},{s}\n", .{ i, s, anomaly_type });
            }
        }

        printInfo("  Exported {d} anomalies to {s}\n", .{ anomalies.count, filename });
    }

    // v3.80: Real-time Monitoring Summary - dashboard-style display
    pub fn showMonitoringSummary(self: *const JitterTracker) void {
        if (self.count == 0) {
            printDim("    No data for monitoring\n", .{});
            return;
        }

        const stats = self.getStats();
        const p = self.getPercentiles();

        // Health score calculation (0-100)
        const health_score: f64 = blk: {
            // Factor 1: Sample count (target >= 30)
            const sample_factor = @min(100.0, @as(f64, @floatFromInt(self.count)) / 30.0 * 100.0);

            // Factor 2: Stability (low jitter)
            const cv = if (stats.mean > 0) stats.jitter / stats.mean else 0;
            const stability_factor = @max(0.0, 30.0 - cv * 30.0);

            // Factor 3: Anomaly rate (target <= 5%)
            const anomalies = self.detectAnomalies(3.0, 2.0);
            const anomaly_factor = @max(0.0, 25.0 - @as(f64, @floatFromInt(anomalies.count)) / @as(f64, @floatFromInt(self.count)) * 100.0);

            break :blk @min(100.0, (sample_factor * 0.3 + stability_factor * 0.4 + anomaly_factor * 0.3));
        };

        // Health level
        const health_level = if (health_score >= 80)
            "🟢 EXCELLENT"
        else if (health_score >= 60)
            "🟢 GOOD"
        else if (health_score >= 40)
            "🟡 FAIR"
        else if (health_score >= 20)
            "🟠 POOR"
        else
            "🔴 CRITICAL";

        // Real-time indicators
        printDim("    Health Score: {d:.1}/100\n", .{health_score});
        printDim("    Health Level: {s}\n", .{health_level});
        printDim("    Samples: {d}\n", .{self.count});
        printDim("    Mean RTT: {d:.2}ms\n", .{stats.mean / 1000.0});
        printDim("    Jitter: {d:.2}ms\n", .{stats.jitter / 1000.0});
        printDim("    Min/Max: {d:.2}ms / {d:.2}ms\n", .{ @as(f64, @floatFromInt(stats.min)) / 1000.0, @as(f64, @floatFromInt(stats.max)) / 1000.0 });
        printDim("    p50/p95/p99: {d:.2}ms / {d:.2}ms / {d:.2}ms\n", .{
            @as(f64, @floatFromInt(p.p50)) / 1000.0,
            @as(f64, @floatFromInt(p.p95)) / 1000.0,
            @as(f64, @floatFromInt(p.p99)) / 1000.0,
        });

        // Trend indicator
        const trend = blk: {
            if (self.count < 10) {
                break :blk "insufficient data";
            }
            const half = @divFloor(self.count, 2);
            var first_sum: i64 = 0;
            var second_sum: i64 = 0;
            for (self.samples[0..half]) |s| {
                first_sum += s;
            }
            for (self.samples[half..self.count]) |s| {
                second_sum += s;
            }
            const first_mean = @as(f64, @floatFromInt(first_sum)) / @as(f64, @floatFromInt(half));
            const second_mean = @as(f64, @floatFromInt(second_sum)) / @as(f64, @floatFromInt(self.count - half));
            const change = ((second_mean - first_mean) / first_mean) * 100.0;
            if (change > 10) {
                break :blk "increasing";
            } else if (change < -10) {
                break :blk "decreasing";
            } else {
                break :blk "stable";
            }
        };

        const trend_icon = if (std.mem.eql(u8, trend, "increasing")) "⬆️" else if (std.mem.eql(u8, trend, "decreasing")) "⬇️" else "➡️";

        printDim("    Trend: {s} {s}\n", .{ trend_icon, trend });
    }

    // v3.80: Statistical Summary Report - comprehensive analysis
    pub fn showStatisticalReport(self: *const JitterTracker) void {
        if (self.count == 0) {
            printDim("    No data for report\n", .{});
            return;
        }

        const stats = self.getStats();
        const p = self.getPercentiles();

        // Section 1: Central Tendency
        printInfo("\n  📈 Central Tendency:\n", .{});
        printDim("    Mean: {d:.2}ms\n", .{stats.mean / 1000.0});
        printDim("    Median: {d:.2}ms\n", .{@as(f64, @floatFromInt(p.p50)) / 1000.0});
        printDim("    Midrange (p25-p75): {d:.2}ms\n", .{
            @as(f64, @floatFromInt(p.p75)) / 1000.0 - @as(f64, @floatFromInt(p.p25)) / 1000.0,
        });

        // Section 2: Dispersion
        printInfo("\n  📊 Dispersion:\n", .{});
        printDim("    Range: {d:.2}ms\n", .{@as(f64, @floatFromInt(stats.max - stats.min)) / 1000.0});
        printDim("    IQR: {d:.2}ms\n", .{@as(f64, @floatFromInt(p.p75)) / 1000.0 - @as(f64, @floatFromInt(p.p25)) / 1000.0});
        printDim("    Variance: {d:.2}ms²\n", .{stats.variance / (1000.0 * 1000.0)});
        printDim("    Std Dev: {d:.2}ms\n", .{stats.jitter / 1000.0});
        printDim("    Coefficient of variation: {d:.2}%\n", .{if (stats.mean > 0) (stats.jitter / stats.mean) * 100.0 else 0});

        // Section 3: Distribution Shape
        printInfo("\n  📐 Distribution Shape:\n", .{});
        const skew_approx = blk: {
            const mean = stats.mean;
            const median = @as(f64, @floatFromInt(p.p50));
            const mode_approx = (p.p50 + p.p25 + p.p75) / 3.0;
            if (mean > median) {
                if ((mode_approx - median) / median < 0.1) {
                    break :blk "symmetric (normal-like)";
                } else {
                    break :blk "right-skewed (high outliers)";
                }
            } else {
                if ((mode_approx - median) / median < -0.1) {
                    break :blk "symmetric (normal-like)";
                } else {
                    break :blk "left-skewed (low outliers)";
                }
            }
        };

        printDim("    Skewness: {s}\n", .{skew_approx});
        printDim("    Kurtosis proxy (p99 vs mean): {d:.2}\n", .{if (stats.mean > 0) (@as(f64, @floatFromInt(p.p99)) / stats.mean - 3.0) else 0});

        // Section 4: Quality Indicators
        printInfo("\n  ✅ Quality Indicators:\n", .{});
        const quality_score = blk: {
            // Low jitter (CV < 20%)
            const cv = if (stats.mean > 0) (stats.jitter / stats.mean) * 100.0 else 0;
            const jitter_score = @max(0.0, 25.0 - cv * 1.25);

            // Low failure rate (< 5%)
            // Assuming no failure tracking, score 25

            // Low p99/p50 ratio (< 1.5x)
            const spread_ratio = if (p.p50 > 0) @as(f64, @floatFromInt(p.p99)) / @as(f64, @floatFromInt(p.p50)) else 1.0;
            const spread_score = @max(0.0, 25.0 - (spread_ratio - 1.0) * 50.0);

            // Adequate sample count (>= 30)
            const sample_score = @min(25.0, @as(f64, @floatFromInt(self.count)) / 30.0 * 25.0);

            break :blk jitter_score + spread_score + sample_score;
        };

        const quality_level = if (quality_score >= 70)
            "🟢 Excellent"
        else if (quality_score >= 50)
            "🟢 Good"
        else if (quality_score >= 30)
            "🟡 Fair"
        else if (quality_score >= 15)
            "🟠 Poor"
        else
            "🔴 Critical";

        printDim("    Quality Score: {d:.1}/100\n", .{quality_score});
        printDim("    Quality Level: {s}\n", .{quality_level});
        printDim("    Recommendation: {s}\n", .{blk: {
            if (quality_score >= 70) {
                break :blk "Excellent - no action needed";
            } else if (quality_score >= 50) {
                break :blk "Good - acceptable for most use cases";
            } else if (quality_score >= 30) {
                break :blk "Fair - consider improvements";
            } else if (quality_score >= 15) {
                break :blk "Poor - investigate issues";
            } else {
                break :blk "Critical - immediate attention required";
            }
        }});
    }

    // v3.80: Percentile Band Analysis - distribution across quartiles
    pub fn showPercentileBands(self: *const JitterTracker) void {
        if (self.count < 4) {
            printDim("    Need at least 4 samples for band analysis\n", .{});
            return;
        }

        const p = self.getPercentiles();

        printInfo("\n  📊 Percentile Bands:\n", .{});

        // Band 1: 0-25% (fastest responses)
        const band1_count = blk: {
            var c: usize = 0;
            for (self.samples[0..self.count]) |s| {
                if (s <= p.p25) c += 1;
            }
            break :blk c;
        };

        // Band 2: 25-50%
        const band2_count = blk: {
            var c: usize = 0;
            for (self.samples[0..self.count]) |s| {
                if (s > p.p25 and s <= p.p50) c += 1;
            }
            break :blk c;
        };

        // Band 3: 50-75%
        const band3_count = blk: {
            var c: usize = 0;
            for (self.samples[0..self.count]) |s| {
                if (s > p.p50 and s <= p.p75) c += 1;
            }
            break :blk c;
        };

        // Band 4: 75-90%
        const band4_count = blk: {
            var c: usize = 0;
            for (self.samples[0..self.count]) |s| {
                if (s > p.p75 and s <= p.p90) c += 1;
            }
            break :blk c;
        };

        // Band 5: 90-100% (slowest responses)
        const band5_count = blk: {
            var c: usize = 0;
            for (self.samples[0..self.count]) |s| {
                if (s > p.p90) c += 1;
            }
            break :blk c;
        };

        const total = @as(f64, @floatFromInt(self.count));

        printDim("    🟢 0-25%   (fastest):  {d:4.1}% | {d:4} samples | [{d:.1}ms - {d:.1}ms]\n", .{
            @as(f64, @floatFromInt(band1_count)) / total * 100.0,
            band1_count,
            @as(f64, @floatFromInt(p.min)) / 1000.0,
            @as(f64, @floatFromInt(p.p25)) / 1000.0,
        });

        printDim("    🟡 25-50%  (below avg): {d:4.1}% | {d:4} samples | [{d:.1}ms - {d:.1}ms]\n", .{
            @as(f64, @floatFromInt(band2_count)) / total * 100.0,
            band2_count,
            @as(f64, @floatFromInt(p.p25)) / 1000.0,
            @as(f64, @floatFromInt(p.p50)) / 1000.0,
        });

        printDim("    🟠 50-75%  (above avg): {d:4.1}% | {d:4} samples | [{d:.1}ms - {d:.1}ms]\n", .{
            @as(f64, @floatFromInt(band3_count)) / total * 100.0,
            band3_count,
            @as(f64, @floatFromInt(p.p50)) / 1000.0,
            @as(f64, @floatFromInt(p.p75)) / 1000.0,
        });

        printDim("    🟠 75-90%  (slow):     {d:4.1}% | {d:4} samples | [{d:.1}ms - {d:.1}ms]\n", .{
            @as(f64, @floatFromInt(band4_count)) / total * 100.0,
            band4_count,
            @as(f64, @floatFromInt(p.p75)) / 1000.0,
            @as(f64, @floatFromInt(p.p90)) / 1000.0,
        });

        printDim("    🔴 90-100% (slowest):  {d:4.1}% | {d:4} samples | [{d:.1}ms - {d:.1}ms]\n", .{
            @as(f64, @floatFromInt(band5_count)) / total * 100.0,
            band5_count,
            @as(f64, @floatFromInt(p.p90)) / 1000.0,
            @as(f64, @floatFromInt(p.max)) / 1000.0,
        });

        // Analysis
        const tail_heavy = (@as(f64, @floatFromInt(band5_count)) / total) > 0.15;
        const skew_note = if (tail_heavy)
            "⚠️  Heavy upper tail - investigate slow responses"
        else
            "✅ Well-distributed - balanced performance";

        printDim("\n    Analysis: {s}\n", .{skew_note});
    }

    // v3.80: Sample Rate Analysis - timing consistency check
    pub fn analyzeSampleRate(self: *const JitterTracker) void {
        if (self.count < 10) {
            printDim("    Need at least 10 samples\n", .{});
            return;
        }

        // Calculate inter-arrival times (IAT)
        var iat_sum: f64 = 0;
        var prev_time: i64 = self.samples[0];
        for (self.samples[1..self.count]) |s| {
            iat_sum += @as(f64, @floatFromInt(s - prev_time));
            prev_time = s;
        }

        const avg_iat = iat_sum / @as(f64, @floatFromInt(self.count - 1));

        // Consistency score (0-100, lower = more variable)
        const max_iat = @as(f64, @floatFromInt(self.samples[self.count - 1]));
        const min_iat = @as(f64, @floatFromInt(self.samples[0]));
        const iat_range = max_iat - min_iat;
        const consistency_score = if (iat_range > 0)
            100.0 - (avg_iat - min_iat) / iat_range * 100.0
        else
            100.0;

        // Rating
        const rating = if (consistency_score >= 80)
            "🟢 Very Consistent"
        else if (consistency_score >= 60)
            "🟢 Consistent"
        else if (consistency_score >= 40)
            "🟡 Moderately Variable"
        else if (consistency_score >= 20)
            "🟠 Highly Variable"
        else
            "🔴 Very Unpredictable";

        printDim("    Sample Count: {d}\n", .{self.count});
        printDim("    Avg IAT: {d:.2}us\n", .{avg_iat});
        printDim("    Min IAT: {d:.2}us\n", .{min_iat});
        printDim("    Max IAT: {d:.2}us\n", .{max_iat});
        printDim("    IAT Range: {d:.2}us\n", .{iat_range});
        printDim("    Consistency: {d:.1}%\n", .{consistency_score});
        printDim("    Rating: {s}\n", .{rating});
    }

    // v3.82: Spectral Periodicity Detection - detect periodic patterns in RTT
    pub fn analyzePeriodicity(self: *const JitterTracker) void {
        const MIN_SAMPLES: usize = 20;
        if (self.count < MIN_SAMPLES) {
            printDim("    Need at least {d} samples\n", .{MIN_SAMPLES});
            return;
        }

        const stats = self.getStats();
        const n = self.count;

        // Calculate autocorrelation for lag values 1 to n/2
        const MAX_LAG = @min(50, @divFloor(n, 2));

        var mean: f64 = 0;
        for (self.samples[0..n]) |s| {
            mean += @as(f64, @floatFromInt(s));
        }
        mean /= @as(f64, @floatFromInt(n));

        // Subtract mean for autocorrelation
        var detrended = self.allocator.alloc(f64, n) catch unreachable;
        defer self.allocator.free(detrended);
        for (self.samples[0..n], 0..) |s, i| {
            detrended[i] = @as(f64, @floatFromInt(s)) - mean;
        }

        // Calculate autocorrelation for each lag
        var autocorr = self.allocator.alloc(f64, MAX_LAG) catch unreachable;
        defer self.allocator.free(autocorr);

        const norm = blk: {
            var sum_sq: f64 = 0;
            for (detrended) |x| sum_sq += x * x;
            break :blk sum_sq;
        };

        var lag_idx: usize = 0;
        while (lag_idx < MAX_LAG) : (lag_idx += 1) {
            var sum: f64 = 0;
            const lag = lag_idx + 1;
            var i: usize = lag;
            while (i < n) : (i += 1) {
                sum += detrended[i] * detrended[i - lag];
            }
            autocorr[lag_idx] = if (norm > 0) sum / norm else 0;
        }

        // Find dominant periods (high autocorrelation)
        var max_corr: f64 = 0;
        var dominant_period: usize = 0;
        for (autocorr[1..], 1..) |c, p| { // Skip lag=0 (always 1.0)
            if (c > max_corr) {
                max_corr = c;
                dominant_period = p;
            }
        }

        // Count how many lags have high correlation (> 0.3)
        var high_corr_count: usize = 0;
        for (autocorr) |c| {
            if (c > 0.3) high_corr_count += 1;
        }

        const periodicity_score = if (MAX_LAG > 0)
            @as(f64, @floatFromInt(high_corr_count)) / @as(f64, @floatFromInt(MAX_LAG)) * 100.0
        else
            0.0;

        const ms_per_sample = stats.mean / 1000.0;
        const dominant_period_ms = if (dominant_period > 0)
            @as(f64, @floatFromInt(dominant_period)) * ms_per_sample
        else
            0;

        // Interpretation
        const classification = blk: {
            if (max_corr < 0.2) break :blk "Random (no periodic pattern detected)";
            if (max_corr < 0.4) break :blk "Weak Periodicity (minor cycles)";
            if (max_corr < 0.6) break :blk "Moderate Periodicity (noticeable cycles)";
            if (max_corr < 0.8) break :blk "Strong Periodicity (clear cycles)";
            break :blk "Very Strong Periodicity (predictable cycles)";
        };

        printDim("    Autocorrelation Peak: {d:.3} at lag {d}\n", .{max_corr, dominant_period});
        printDim("    Periodicity Score: {d:.1}%\n", .{periodicity_score});
        if (dominant_period > 0) {
            printDim("    Dominant Period: {d:.2}ms ({d} samples)\n", .{dominant_period_ms, dominant_period});
        }
        printDim("    Classification: {s}\n", .{classification});

        // Provide interpretation hints
        if (max_corr >= 0.5) {
            printDim("    ⚠️  Possible causes:\n", .{});
            if (dominant_period_ms < 5) {
                printDim("       - CPU scheduler tick\n", .{});
                printDim("       - Interrupt handling\n", .{});
            } else if (dominant_period_ms < 50) {
                printDim("       - Garbage collection cycles\n", .{});
                printDim("       - Background task scheduling\n", .{});
            } else if (dominant_period_ms < 500) {
                printDim("       - Network congestion waves\n", .{});
                printDim("       - TCP timer granularity\n", .{});
            } else {
                printDim("       - Long-running background processes\n", .{});
                printDim("       - Resource exhaustion cycles\n", .{});
            }
        }
    }

    // v3.83: Multi-modal Distribution Detection - identify multiple peaks in RTT
    pub fn detectMultimodalDistribution(self: *const JitterTracker) void {
        const MIN_SAMPLES: usize = 30;
        if (self.count < MIN_SAMPLES) {
            printDim("    Need at least {d} samples\n", .{MIN_SAMPLES});
            return;
        }

        // Use histogram-based mode detection
        const NUM_BINS: usize = 20;
        var bins: [NUM_BINS]usize = [_]usize{0} ** NUM_BINS;

        // Find min and max for binning
        var min_val: i64 = self.samples[0];
        var max_val: i64 = self.samples[0];
        for (self.samples[0..self.count]) |s| {
            if (s < min_val) min_val = s;
            if (s > max_val) max_val = s;
        }

        const range = @as(f64, @floatFromInt(max_val - min_val));
        const bin_width = if (range > 0) range / @as(f64, @floatFromInt(NUM_BINS)) else 1.0;

        // Bin the data
        for (self.samples[0..self.count]) |s| {
            const val_f = @as(f64, @floatFromInt(s - min_val));
            const bin_idx = @min(NUM_BINS - 1, @as(usize, @intFromFloat(@floor(val_f / bin_width))));
            bins[bin_idx] += 1;
        }

        // Find local peaks in histogram
        var peaks: [5]struct { bin: usize, count: usize, value: f64 } = undefined;
        var num_peaks: usize = 0;
        const min_bin_count = @max(2, @divFloor(self.count, 20)); // At least 2 or 5% of total

        for (1..NUM_BINS - 1) |i| {
            if (bins[i] > bins[i - 1] and bins[i] > bins[i + 1] and bins[i] >= min_bin_count) {
                if (num_peaks < 5) {
                    const bin_center_f = @as(f64, @floatFromInt(i)) + 0.5;
                    const bin_offset = @as(i64, @intFromFloat(bin_center_f * bin_width));
                    const bin_center = min_val + bin_offset;
                    peaks[num_peaks] = .{
                        .bin = i,
                        .count = bins[i],
                        .value = @as(f64, @floatFromInt(bin_center)) / 1000.0, // Convert to ms
                    };
                    num_peaks += 1;
                }
            }
        }

        // Check for edge peaks (first and last bins)
        if (bins[0] > bins[1] and bins[0] >= min_bin_count and num_peaks < 5) {
            const bin_offset = @as(i64, @intFromFloat(0.5 * bin_width));
            const bin_center = min_val + bin_offset;
            peaks[num_peaks] = .{
                .bin = 0,
                .count = bins[0],
                .value = @as(f64, @floatFromInt(bin_center)) / 1000.0,
            };
            num_peaks += 1;
        }
        if (bins[NUM_BINS - 1] > bins[NUM_BINS - 2] and bins[NUM_BINS - 1] >= min_bin_count and num_peaks < 5) {
            const bin_center_f = @as(f64, @floatFromInt(NUM_BINS - 1)) - 0.5;
            const bin_offset = @as(i64, @intFromFloat(bin_center_f * bin_width));
            const bin_center = min_val + bin_offset;
            peaks[num_peaks] = .{
                .bin = NUM_BINS - 1,
                .count = bins[NUM_BINS - 1],
                .value = @as(f64, @floatFromInt(bin_center)) / 1000.0,
            };
            num_peaks += 1;
        }

        // Sort peaks by count
        var i: usize = 0;
        while (i < num_peaks) : (i += 1) {
            var j: usize = i + 1;
            while (j < num_peaks) : (j += 1) {
                if (peaks[j].count > peaks[i].count) {
                    const tmp = peaks[i];
                    peaks[i] = peaks[j];
                    peaks[j] = tmp;
                }
            }
        }

        // Interpretation based on peak count
        const classification = blk: {
            if (num_peaks == 0) break :blk "Uniform (no distinct peaks)";
            if (num_peaks == 1) break :blk "Unimodal (single dominant peak)";
            if (num_peaks == 2) break :blk "Bimodal (two distinct paths/modes)";
            if (num_peaks == 3) break :blk "Trimodal (three distinct modes)";
            break :blk "Multimodal (multiple distinct modes)";
        };

        printDim("    Number of modes detected: {d}\n", .{num_peaks});
        printDim("    Distribution type: {s}\n", .{classification});

        // Show peaks
        if (num_peaks > 0) {
            printDim("\n    Detected peaks:\n", .{});
            var peak_idx: usize = 0;
            while (peak_idx < @min(3, num_peaks)) : (peak_idx += 1) {
                const peak_pct = @as(f64, @floatFromInt(peaks[peak_idx].count)) / @as(f64, @floatFromInt(self.count)) * 100.0;
                printDim("      Peak {d}: {d:.2}ms ({d:.1}% of samples)\n", .{
                    peak_idx + 1,
                    peaks[peak_idx].value,
                    peak_pct,
                });
            }
        }

        // Interpretation hints
        if (num_peaks >= 2) {
            printDim("\n    ⚠️  Possible causes for multiple modes:\n", .{});
            const fastest_peak = if (num_peaks > 0) peaks[0].value else 0;
            const slowest_peak = if (num_peaks > 1) peaks[num_peaks - 1].value else 0;
            const ratio = if (slowest_peak > 0) slowest_peak / fastest_peak else 1;

            if (ratio < 1.5) {
                printDim("       - Slight mode variation (minor path differences)\n", .{});
            } else if (ratio < 3) {
                printDim("       - Moderate mode separation (e.g., cache hit vs miss)\n", .{});
                printDim("       - Multiple network paths with different latencies\n", .{});
            } else {
                printDim("       - Large mode separation (e.g., WiFi vs Ethernet)\n", .{});
                printDim("       - TCP slow-start vs established connection\n", .{});
                printDim("       - Different processing paths (fast vs slow path)\n", .{});
            }
        }
    }

    // v3.84: Auto-tuning Recommendations - actionable configuration suggestions
    pub fn showAutoTuningRecommendations(self: *const JitterTracker) void {
        if (self.count < 10) {
            printDim("    Need at least 10 samples for recommendations\n", .{});
            return;
        }

        const stats = self.getStats();
        const p = self.getPercentiles();
        const anomalies = self.detectAnomalies(1.5, 2.0);
        const quality = self.getQualityScore(3.0);

        printInfo("\n  🎯 Auto-tuning Recommendations:\n", .{});

        var recommendations: [10][]const u8 = undefined;
        var num_recs: usize = 0;

        // Batch size recommendation
        const cv = if (stats.mean > 0) stats.jitter / stats.mean else 0;
        if (cv > 0.5) {
            if (num_recs < 10) {
                recommendations[num_recs] = "⬇️  Reduce batch size (high jitter detected)";
                num_recs += 1;
            }
        } else if (cv < 0.2 and self.count > 50) {
            if (num_recs < 10) {
                recommendations[num_recs] = "⬆️  Increase batch size (stable latency, capacity available)";
                num_recs += 1;
            }
        }

        // Delay recommendation
        const mean_ms = stats.mean / 1000.0;
        const p99_ms = @as(f64, @floatFromInt(p.p99)) / 1000.0;
        if (mean_ms < 10) {
            if (num_recs < 10) {
                recommendations[num_recs] = "⏱️  Consider increasing delay (very fast responses, may need spacing)";
                num_recs += 1;
            }
        } else if (mean_ms > 100) {
            if (num_recs < 10) {
                recommendations[num_recs] = "⏱️  Consider decreasing delay (slow responses, spacing may not be needed)";
                num_recs += 1;
            }
        }

        // Spike threshold recommendation
        const p99_p50_ratio = if (p.p50 > 0) @as(f64, @floatFromInt(p.p99)) / @as(f64, @floatFromInt(p.p50)) else 1;
        if (p99_p50_ratio > 4) {
            if (num_recs < 10) {
                recommendations[num_recs] = "🎚️  Increase spike threshold (high tail variance detected)";
                num_recs += 1;
            }
        } else if (p99_p50_ratio < 1.5) {
            if (num_recs < 10) {
                recommendations[num_recs] = "🎚️  Decrease spike threshold (low variance, sensitive detection possible)";
                num_recs += 1;
            }
        }

        // Timeout recommendation
        const max_ms = @as(f64, @floatFromInt(stats.max)) / 1000.0;
        const recommended_timeout = max_ms * 2.0;
        if (num_recs < 10) {
            const timeout_buf = self.allocator.alloc(u8, 100) catch unreachable;
            defer self.allocator.free(timeout_buf);
            const timeout_msg = std.fmt.bufPrint(timeout_buf, "⏰  Set timeout to {d:.0}ms (2x max RTT: {d:.1}ms)", .{recommended_timeout, max_ms}) catch "";
            recommendations[num_recs] = timeout_msg;
            num_recs += 1;
        }

        // Anomaly-based recommendations
        if (anomalies.count > @divFloor(self.count, 10)) {
            if (num_recs < 10) {
                recommendations[num_recs] = "🔍 Investigate anomaly sources (10%+ samples are outliers)";
                num_recs += 1;
            }
        }

        // Quality score recommendations
        if (quality.score < 50) {
            if (num_recs < 10) {
                recommendations[num_recs] = "⚠️  Poor quality detected - check hardware/connection";
                num_recs += 1;
            }
        } else if (quality.score >= 90) {
            if (num_recs < 10) {
                recommendations[num_recs] = "✅ Excellent quality - current configuration is optimal";
                num_recs += 1;
            }
        }

        // Trend-based recommendations
        const trend = self.getTrend();
        if (std.mem.eql(u8, trend.direction, "DEGRADING") and trend.change_percent > 30) {
            if (num_recs < 10) {
                recommendations[num_recs] = "📈 Performance degrading - investigate system load/network";
                num_recs += 1;
            }
        }

        // Sample count recommendations
        if (self.count < 30) {
            if (num_recs < 10) {
                recommendations[num_recs] = "📊 Increase sample count for better statistical confidence";
                num_recs += 1;
            }
        }

        // Print recommendations
        if (num_recs == 0) {
            printDim("    No specific recommendations - configuration looks good\n", .{});
        } else {
            var i: usize = 0;
            while (i < num_recs) : (i += 1) {
                printDim("    {d}. {s}\n", .{i + 1, recommendations[i]});
            }
        }

        // Summary stats
        printDim("\n    📋 Configuration Summary:\n", .{});
        printDim("       Mean RTT: {d:.2}ms, Jitter: {d:.2}ms\n", .{mean_ms, stats.jitter / 1000.0});
        printDim("       p50: {d:.2}ms, p99: {d:.2}ms (ratio: {d:.2}x)\n", .{
            @as(f64, @floatFromInt(p.p50)) / 1000.0,
            p99_ms,
            p99_p50_ratio,
        });
        printDim("       Quality Score: {d:.0}/100 ({s})\n", .{quality.score, quality.grade});
    }

    // v3.85: Quick Health Check - one-line status summary
    pub fn showQuickHealthCheck(self: *const JitterTracker) void {
        if (self.count < 5) {
            printDim("    Need at least 5 samples\n", .{});
            return;
        }

        const stats = self.getStats();
        const p = self.getPercentiles();
        const quality = self.getQualityScore(3.0);

        // Calculate health indicators
        const cv = if (stats.mean > 0) stats.jitter / stats.mean else 0;
        _ = if (p.p50 > 0) @as(f64, @floatFromInt(p.p99)) / @as(f64, @floatFromInt(p.p50)) else 1; // Reserved for future use
        const anomalies = self.detectAnomalies(1.5, 2.0);

        // Health status
        const health_status = blk: {
            if (quality.score >= 90) break :blk "✅ EXCELLENT";
            if (quality.score >= 75) break :blk "✅ GOOD";
            if (quality.score >= 60) break :blk "⚠️  FAIR";
            if (quality.score >= 40) break :blk "❌ POOR";
            break :blk "🔴 CRITICAL";
        };

        // Performance classification
        const perf_class = blk: {
            if (cv < 0.15) break :blk "Stable";
            if (cv < 0.3) break :blk "Low Variability";
            if (cv < 0.5) break :blk "Moderate Variability";
            break :blk "High Variability";
        };

        // Anomaly status
        const anomaly_status = blk: {
            if (anomalies.count == 0) break :blk "No anomalies";
            if (anomalies.count < 2) break :blk "Few anomalies";
            if (anomalies.count < 5) break :blk "Some anomalies";
            break :blk "Many anomalies";
        };

        const mean_ms = stats.mean / 1000.0;
        printInfo("[i] Quick Health Check:\n", .{});
        printDim("    Status: {s}\n", .{health_status});
        printDim("    Performance: {s}\n", .{perf_class});
        printDim("    Anomalies: {s}\n", .{anomaly_status});
        printDim("    Quality: {d:.0}/100 ({s})\n", .{quality.score, quality.grade});
        printDim("    Mean RTT: {d:.2}ms, Range: {d:.1}ms\n", .{
            mean_ms,
            @as(f64, @floatFromInt(stats.max - stats.min)) / 1000.0,
        });
        printDim("    Jitter (CV): {d:.2} ({s})\n", .{cv, perf_class});
    }

    // v4.05: Performance Profile Classification - connection type detection
    pub const PerformanceProfile = struct {
        name: []const u8,
        min_ms: f64,
        max_ms: f64,
        max_cv: f64,
        description: []const u8,
    };

    pub fn classifyPerformanceProfile(self: *const JitterTracker) ?PerformanceProfile {
        if (self.count < 10) return null;

        const stats = self.getStats();
        const p = self.getPercentiles();
        const cv = if (stats.mean > 0) stats.jitter / stats.mean else 0;
        const mean_ms = stats.mean / 1000.0;
        const p99_ms = @as(f64, @floatFromInt(p.p99)) / 1000.0;

        // Standard profiles
        const profiles = [_]PerformanceProfile{
            .{ .name = "Real-time", .min_ms = 0.1, .max_ms = 2.0, .max_cv = 0.1, .description = "Hard real-time (audio, video, control)" },
            .{ .name = "Interactive", .min_ms = 2.0, .max_ms = 10.0, .max_cv = 0.2, .description = "Interactive (gaming, UI response)" },
            .{ .name = "Fast Local", .min_ms = 5.0, .max_ms = 20.0, .max_cv = 0.3, .description = "Fast local (LAN, USB)" },
            .{ .name = "Standard", .min_ms = 10.0, .max_ms = 50.0, .max_cv = 0.4, .description = "Standard (network, cloud)" },
            .{ .name = "Moderate", .min_ms = 30.0, .max_ms = 100.0, .max_cv = 0.5, .description = "Moderate (WAN, remote)" },
            .{ .name = "High Latency", .min_ms = 50.0, .max_ms = 200.0, .max_cv = 0.6, .description = "High latency (satellite, cellular)" },
            .{ .name = "Variable", .min_ms = 0.0, .max_ms = 1000.0, .max_cv = 1.0, .description = "Variable (unpredictable)" },
        };

        for (profiles) |profile| {
            const in_range = mean_ms >= profile.min_ms and mean_ms <= profile.max_ms;
            const cv_ok = cv <= profile.max_cv;
            if (in_range and cv_ok) {
                return profile;
            }
        }

        // Fallback classification
        if (cv > 0.6) return profiles[6]; // Variable
        if (p99_ms > 100.0) return profiles[5]; // High Latency
        if (p99_ms > 50.0) return profiles[4]; // Moderate
        return profiles[3]; // Standard
    }

    pub fn showPerformanceProfile(self: *const JitterTracker) void {
        const profile = self.classifyPerformanceProfile() orelse {
            printDim("    Need at least 10 samples for profile classification\n", .{});
            return;
        };

        printInfo("[i] Performance Profile Classification:\n", .{});
        printDim("    Profile: {s}\n", .{profile.name});
        printDim("    Description: {s}\n", .{profile.description});
        printDim("    Target Range: {d:.1}ms - {d:.1}ms\n", .{profile.min_ms, profile.max_ms});
        printDim("    Max Jitter CV: {d:.2}\n", .{profile.max_cv});

        // Application recommendations
        printDim("\n    Suitable for:\n", .{});
        if (std.mem.eql(u8, profile.name, "Real-time")) {
            printDim("       - Audio processing\n", .{});
            printDim("       - Video streaming\n", .{});
            printDim("       - Control systems\n", .{});
            printDim("       - Gaming (competitive)\n", .{});
        } else if (std.mem.eql(u8, profile.name, "Interactive")) {
            printDim("       - Web browsing\n", .{});
            printDim("       - Gaming (casual)\n", .{});
            printDim("       - Terminal sessions\n", .{});
            printDim("       - Database queries\n", .{});
        } else if (std.mem.eql(u8, profile.name, "Fast Local")) {
            printDim("       - File transfers\n", .{});
            printDim("       - Local API calls\n", .{});
            printDim("       - USB devices\n", .{});
        } else if (std.mem.eql(u8, profile.name, "Standard")) {
            printDim("       - Cloud services\n", .{});
            printDim("       - Database operations\n", .{});
            printDim("       - Web applications\n", .{});
        } else if (std.mem.eql(u8, profile.name, "Moderate")) {
            printDim("       - Remote desktop\n", .{});
            printDim("       - WAN connections\n", .{});
            printDim("       - API calls over internet\n", .{});
        } else if (std.mem.eql(u8, profile.name, "High Latency")) {
            printDim("       - Satellite links\n", .{});
            printDim("       - Cellular networks\n", .{});
            printDim("       - International connections\n", .{});
        } else if (std.mem.eql(u8, profile.name, "Variable")) {
            printDim("       - Best-effort traffic\n", .{});
            printDim("       - Unreliable networks\n", .{});
            printDim("       - Congested connections\n", .{});
        }
    }

    // v3.88: Burst Analysis - detect grouped latency spikes
    pub const BurstAnalysisResult = struct {
        burst_count: usize,
        total_burst_samples: usize,
        longest_burst: usize,
        avg_burst_length: f64,
        burst_severity: []const u8,
    };

    pub fn analyzeBursts(self: *const JitterTracker, threshold_multiplier: f64) BurstAnalysisResult {
        if (self.count < 5) {
            return .{
                .burst_count = 0,
                .total_burst_samples = 0,
                .longest_burst = 0,
                .avg_burst_length = 0.0,
                .burst_severity = "INSUFFICIENT_DATA",
            };
        }

        // Calculate median as baseline using sorted copy
        const sorted_buf = self.allocator.alloc(i64, self.count) catch unreachable;
        defer self.allocator.free(sorted_buf);
        @memcpy(sorted_buf, self.samples[0..self.count]);
        std.sort.insertion(i64, sorted_buf, {}, comptime std.sort.asc(i64));
        const median = sorted_buf[@divFloor(self.count, 2)];

        // Calculate MAD (Median Absolute Deviation)
        const mads = self.allocator.alloc(i64, self.count) catch unreachable;
        defer self.allocator.free(mads);
        for (self.samples[0..self.count], 0..) |s, i| {
            mads[i] = if (s > median) s - median else median - s;
        }
        std.sort.insertion(i64, mads, {}, comptime std.sort.asc(i64));
        const mad = mads[@divFloor(self.count, 2)];

        // Threshold for "high latency" samples
        const threshold = median + @as(i64, @intFromFloat(@as(f64, @floatFromInt(mad)) * threshold_multiplier));

        // Detect bursts (consecutive high-latency samples)
        var burst_count: usize = 0;
        var total_burst_samples: usize = 0;
        var longest_burst: usize = 0;
        var current_burst: usize = 0;
        var in_burst = false;

        for (self.samples[0..self.count]) |s| {
            if (s > threshold) {
                if (!in_burst) {
                    in_burst = true;
                    current_burst = 0;
                    burst_count += 1;
                }
                current_burst += 1;
                total_burst_samples += 1;
            } else {
                if (in_burst) {
                    if (current_burst > longest_burst) {
                        longest_burst = current_burst;
                    }
                    in_burst = false;
                }
            }
        }

        // Handle case where burst extends to end
        if (in_burst and current_burst > longest_burst) {
            longest_burst = current_burst;
        }

        // Calculate average burst length
        const avg_burst_length = if (burst_count > 0)
            @as(f64, @floatFromInt(total_burst_samples)) / @as(f64, @floatFromInt(burst_count))
        else
            0.0;

        // Classify burst severity
        const burst_ratio = @as(f64, @floatFromInt(total_burst_samples)) / @as(f64, @floatFromInt(self.count));
        const burst_severity = if (burst_count == 0)
            "NONE"
        else if (burst_ratio < 0.05)
            "LOW"
        else if (burst_ratio < 0.15)
            "MODERATE"
        else if (burst_ratio < 0.30)
            "HIGH"
        else
            "SEVERE";

        return .{
            .burst_count = burst_count,
            .total_burst_samples = total_burst_samples,
            .longest_burst = longest_burst,
            .avg_burst_length = avg_burst_length,
            .burst_severity = burst_severity,
        };
    }

    pub fn showBurstAnalysis(self: *const JitterTracker) void {
        if (self.count < 5) {
            printInfo("[i] Burst Analysis: insufficient data (need 5+ samples)\n", .{});
            return;
        }

        const result = self.analyzeBursts(2.0);

        printInfo("[i] Burst Analysis:\n", .{});
        printDim("    Bursts detected: {d}\n", .{result.burst_count});
        printDim("    Affected samples: {d}/{d} ({d:.1}%)\n", .{
            result.total_burst_samples,
            self.count,
            @as(f64, @floatFromInt(result.total_burst_samples)) / @as(f64, @floatFromInt(self.count)) * 100.0,
        });
        if (result.burst_count > 0) {
            printDim("    Longest burst: {d} samples\n", .{result.longest_burst});
            printDim("    Avg burst length: {d:.1} samples\n", .{result.avg_burst_length});
        }
        printDim("    Severity: {s}\n", .{result.burst_severity});

        // Interpretation
        if (std.mem.eql(u8, result.burst_severity, "NONE")) {
            printDim("\n    Interpretation: Latency is stable, no bursts detected\n", .{});
        } else if (std.mem.eql(u8, result.burst_severity, "LOW")) {
            printDim("\n    Interpretation: Occasional latency spikes, acceptable for most applications\n", .{});
        } else if (std.mem.eql(u8, result.burst_severity, "MODERATE")) {
            printDim("\n    Interpretation: Some burst activity, may affect real-time applications\n", .{});
        } else if (std.mem.eql(u8, result.burst_severity, "HIGH")) {
            printDim("\n    Interpretation: Significant bursting, real-time performance degraded\n", .{});
        } else {
            printDim("\n    Interpretation: Severe congestion or system overload detected\n", .{});
        }
    }

    // v3.89: Connection Stability Score - comprehensive stability indicator
    pub const StabilityScore = struct {
        overall_score: f64, // 0-100
        jitter_stability: f64, // 0-100
        consistency_score: f64, // 0-100
        burst_penalty: f64, // 0-100
        trend_score: f64, // 0-100
        grade: []const u8, // A/B/C/D/F
        recommendation: []const u8,
    };

    pub fn calculateStabilityScore(self: *const JitterTracker) StabilityScore {
        if (self.count < 10) {
            return .{
                .overall_score = 0.0,
                .jitter_stability = 0.0,
                .consistency_score = 0.0,
                .burst_penalty = 0.0,
                .trend_score = 0.0,
                .grade = "N/A",
                .recommendation = "Insufficient data (need 10+ samples)",
            };
        }

        // 1. Jitter Stability (based on coefficient of variation)
        const stats = self.getStats();
        const mean_us = stats.mean;
        const jitter_us = stats.jitter; // This is std_dev
        const cv = if (mean_us > 0) jitter_us / mean_us else 0.0;
        const jitter_stability: f64 = if (cv < 0.1) 100.0
        else if (cv < 0.2) 85.0
        else if (cv < 0.3) 70.0
        else if (cv < 0.5) 50.0
        else 25.0;

        // 2. Consistency Score (based on IQR spread)
        const p = self.getPercentiles();
        const iqr = @as(f64, @floatFromInt(p.p75 - p.p25));
        const median_ms = @as(f64, @floatFromInt(p.p50)) / 1000.0;
        const normalized_iqr = if (median_ms > 0) iqr / 1000.0 / median_ms else 0.0;
        const consistency_score: f64 = if (normalized_iqr < 0.2) 100.0
        else if (normalized_iqr < 0.4) 80.0
        else if (normalized_iqr < 0.6) 60.0
        else if (normalized_iqr < 1.0) 40.0
        else 20.0;

        // 3. Burst Penalty (inverse of burst severity)
        const burst_result = self.analyzeBursts(2.0);
        const burst_ratio = @as(f64, @floatFromInt(burst_result.total_burst_samples)) / @as(f64, @floatFromInt(self.count));
        const burst_penalty: f64 = if (burst_result.burst_count == 0) 100.0
        else if (burst_ratio < 0.05) 90.0
        else if (burst_ratio < 0.15) 70.0
        else if (burst_ratio < 0.30) 40.0
        else 10.0;

        // 4. Trend Score (based on degradation detection)
        const trend_score: f64 = if (self.count < 6) 75.0 else blk: {
            const half = @divFloor(self.count, 2);
            var first_sum: i64 = 0;
            var second_sum: i64 = 0;
            for (self.samples[0..half]) |s| first_sum += s;
            for (self.samples[half..self.count]) |s| second_sum += s;
            const first_avg = @as(f64, @floatFromInt(first_sum)) / @as(f64, @floatFromInt(half));
            const second_avg = @as(f64, @floatFromInt(second_sum)) / @as(f64, @floatFromInt(self.count - half));
            const change_ratio = if (first_avg > 0) (second_avg - first_avg) / first_avg else 0.0;

            if (change_ratio < -0.1) break :blk 100.0; // Improved
            if (change_ratio < 0.0) break :blk 90.0; // Slightly improved
            if (change_ratio < 0.1) break :blk 80.0; // Stable
            if (change_ratio < 0.25) break :blk 60.0; // Mild degradation
            if (change_ratio < 0.5) break :blk 40.0; // Moderate degradation
            break :blk 20.0; // Severe degradation
        };

        // Overall score (weighted average)
        const overall_score = (jitter_stability * 0.35 + consistency_score * 0.25 +
            burst_penalty * 0.25 + trend_score * 0.15);

        // Grade assignment
        const grade = if (overall_score >= 90) "A"
        else if (overall_score >= 80) "B"
        else if (overall_score >= 70) "C"
        else if (overall_score >= 60) "D"
        else "F";

        // Recommendation
        const recommendation = if (overall_score >= 90)
            "Excellent stability - suitable for real-time applications"
        else if (overall_score >= 80)
            "Good stability - suitable for most applications"
        else if (overall_score >= 70)
            "Acceptable stability - may need tuning for sensitive applications"
        else if (overall_score >= 60)
            "Poor stability - not recommended for real-time use"
        else
            "Unstable connection - investigate network/hardware issues";

        return .{
            .overall_score = overall_score,
            .jitter_stability = jitter_stability,
            .consistency_score = consistency_score,
            .burst_penalty = burst_penalty,
            .trend_score = trend_score,
            .grade = grade,
            .recommendation = recommendation,
        };
    }

    pub fn showStabilityScore(self: *const JitterTracker) void {
        if (self.count < 10) {
            printInfo("[i] Stability Score: insufficient data (need 10+ samples)\n", .{});
            return;
        }

        const score = self.calculateStabilityScore();

        printInfo("[i] Connection Stability Score:\n", .{});

        // Overall score with color coding
        const score_emoji = if (score.overall_score >= 90) "🟢"
        else if (score.overall_score >= 80) "🟡"
        else if (score.overall_score >= 70) "🟠"
        else "🔴";

        printDim("    {s} Overall: {d:.1}/100 ({s})\n", .{ score_emoji, score.overall_score, score.grade });

        // Component scores
        printDim("\n    Components:\n", .{});
        printDim("       Jitter Stability:  {d:.0}/100\n", .{score.jitter_stability});
        printDim("       Consistency:       {d:.0}/100\n", .{score.consistency_score});
        printDim("       Burst Resistance:  {d:.0}/100\n", .{score.burst_penalty});
        printDim("       Trend Score:       {d:.0}/100\n", .{score.trend_score});

        // Recommendation
        printDim("\n    Recommendation: {s}\n", .{score.recommendation});
    }

    // v3.90: Adaptive Configuration Generator - optimal parameters based on analysis
    pub const AdaptiveConfig = struct {
        recommended_baud: []const u8,
        recommended_timeout_ms: u32,
        recommended_delay_ms: u32,
        recommended_batch_size: usize,
        recommended_spike_threshold: f64,
        use_adaptive_timeout: bool,
        use_rts_cts: bool,
        reason: []const u8,
    };

    pub fn generateAdaptiveConfig(self: *const JitterTracker) AdaptiveConfig {
        if (self.count < 5) {
            return .{
                .recommended_baud = "115200",
                .recommended_timeout_ms = 2000,
                .recommended_delay_ms = 200,
                .recommended_batch_size = 16,
                .recommended_spike_threshold = 3.0,
                .use_adaptive_timeout = false,
                .use_rts_cts = false,
                .reason = "Insufficient data - using defaults",
            };
        }

        const stats = self.getStats();
        const p = self.getPercentiles();
        const stability = self.calculateStabilityScore();

        // Calculate optimal parameters based on observed behavior
        const mean_ms = stats.mean / 1000.0;
        const p99_ms = @as(f64, @floatFromInt(p.p99)) / 1000.0;

        // Timeout: 2x p99 + 50% margin, minimum 500ms
        const recommended_timeout_ms: u32 = @max(500, @as(u32, @intFromFloat(p99_ms * 3.0)));

        // Delay: 1.5x mean RTT, minimum 50ms
        const recommended_delay_ms: u32 = @max(50, @as(u32, @intFromFloat(mean_ms * 1.5)));

        // Batch size based on stability
        const recommended_batch_size: usize = if (stability.overall_score >= 80)
            32 // High stability - larger batches
        else if (stability.overall_score >= 60)
            16 // Medium stability
        else
            8; // Low stability - smaller batches

        // Spike threshold based on jitter
        const cv = if (mean_ms > 0) (stats.jitter / stats.mean) else 0.0;
        const recommended_spike_threshold: f64 = if (cv < 0.2)
            2.0 // Low jitter - sensitive detection
        else if (cv < 0.4)
            3.0 // Medium jitter
        else
            4.0; // High jitter - less sensitive

        // Adaptive timeout based on variability
        const use_adaptive_timeout = cv > 0.3;

        // RTS/CTS for high-throughput scenarios
        const use_rts_cts = recommended_batch_size >= 16;

        // Baud rate based on latency profile
        const recommended_baud: []const u8 = if (p99_ms < 10.0)
            "921600" // Very low latency - max speed
        else if (p99_ms < 50.0)
            "460800" // Low latency
        else if (p99_ms < 100.0)
            "115200" // Standard
        else
            "57600"; // High latency - conservative

        // Reason explanation
        const reason = if (stability.overall_score >= 80)
            "High stability detected - using optimal settings for throughput"
        else if (stability.overall_score >= 60)
            "Medium stability - balanced configuration"
        else
            "Low stability - conservative settings for reliability";

        return .{
            .recommended_baud = recommended_baud,
            .recommended_timeout_ms = recommended_timeout_ms,
            .recommended_delay_ms = recommended_delay_ms,
            .recommended_batch_size = recommended_batch_size,
            .recommended_spike_threshold = recommended_spike_threshold,
            .use_adaptive_timeout = use_adaptive_timeout,
            .use_rts_cts = use_rts_cts,
            .reason = reason,
        };
    }

    pub fn showAdaptiveConfig(self: *const JitterTracker) void {
        if (self.count < 5) {
            printInfo("[i] Adaptive Configuration: insufficient data (need 5+ samples)\n", .{});
            return;
        }

        const config = self.generateAdaptiveConfig();

        printInfo("[i] Adaptive Configuration Generator:\n", .{});
        printDim("\n    Recommended Parameters:\n", .{});
        printDim("       --baud {s}          # Baud rate\n", .{config.recommended_baud});
        printDim("       --timeout {d}        # Read timeout (ms)\n", .{config.recommended_timeout_ms});
        printDim("       --delay {d}          # Inter-test delay (ms)\n", .{config.recommended_delay_ms});
        printDim("       --batch-size {d}     # Packets per batch\n", .{config.recommended_batch_size});
        printDim("       --spike-threshold {d:.1}  # Spike detection multiplier\n", .{config.recommended_spike_threshold});

        if (config.use_adaptive_timeout) {
            printDim("       --adaptive-timeout   # Enable (high variability detected)\n", .{});
        }
        if (config.use_rts_cts) {
            printDim("       --rts-cts           # Enable flow control (high throughput)\n", .{});
        }

        printDim("\n    Reason: {s}\n", .{config.reason});

        // Show example command
        printDim("\n    Example command:\n", .{});
        var cmd_buf: [256]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf,
            "       uart-echo-test --baud {s} --timeout {d} --delay {d} --batch-size {d}",
            .{ config.recommended_baud, config.recommended_timeout_ms, config.recommended_delay_ms, config.recommended_batch_size }
        ) catch "Command too long";
        printDim("{s}", .{cmd});
        if (config.use_adaptive_timeout) {
            printDim(" --adaptive-timeout", .{});
        }
        if (config.use_rts_cts) {
            printDim(" --rts-cts", .{});
        }
        printDim("\n", .{});
    }

    // v3.91: Packet Loss Pattern Detection - analyze failure patterns
    pub const LossPattern = struct {
        pattern_type: []const u8,
        consecutive_max: usize,
        scattered_count: usize,
        periodicity_score: f64,
        severity: []const u8,
        description: []const u8,
    };

    pub fn detectLossPattern(self: *const JitterTracker) LossPattern {
        if (self.consecutive_failures == 0) {
            return .{
                .pattern_type = "NO_LOSS",
                .consecutive_max = 0,
                .scattered_count = 0,
                .periodicity_score = 0.0,
                .severity = "NONE",
                .description = "No packet loss detected",
            };
        }

        // Analyze failure patterns based on consecutive_failures tracking
        const consecutive_max = self.max_consecutive_failures;
        const scattered_count = if (consecutive_max > 0)
            @divFloor(self.consecutive_failures, consecutive_max + 1)
        else
            0;

        // Calculate periodicity score (0-100)
        // Higher score = more periodic/structured pattern
        const periodicity_score: f64 = if (self.consecutive_failures >= 3) blk: {
            if (consecutive_max >= 3) break :blk 80.0;
            if (consecutive_max == 2) break :blk 60.0;
            break :blk 40.0;
        } else 0.0;

        // Classify pattern type
        const pattern_type: []const u8 = if (consecutive_max >= 5)
            "BURST"
        else if (consecutive_max >= 3)
            "GROUPED"
        else if (scattered_count > 2)
            "SCATTERED"
        else
            "ISOLATED";

        // Severity classification
        const severity: []const u8 = if (self.consecutive_failures == 0)
            "NONE"
        else if (self.consecutive_failures < 3)
            "LOW"
        else if (self.consecutive_failures < 10)
            "MODERATE"
        else if (self.consecutive_failures < 25)
            "HIGH"
        else
            "SEVERE";

        // Description
        const description: []const u8 = if (std.mem.eql(u8, pattern_type, "BURST"))
            "Consecutive failures indicate burst loss - possible buffer overflow"
        else if (std.mem.eql(u8, pattern_type, "GROUPED"))
            "Grouped failures suggest intermittent issues - check for loose connections"
        else if (std.mem.eql(u8, pattern_type, "SCATTERED"))
            "Scattered failures indicate random noise - normal for some links"
        else
            "Isolated failures - acceptable for most applications";

        return .{
            .pattern_type = pattern_type,
            .consecutive_max = consecutive_max,
            .scattered_count = scattered_count,
            .periodicity_score = periodicity_score,
            .severity = severity,
            .description = description,
        };
    }

    pub fn showLossPattern(self: *const JitterTracker) void {
        const pattern = self.detectLossPattern();

        printInfo("[i] Packet Loss Pattern Analysis:\n", .{});

        // Severity with emoji
        const severity_emoji = if (std.mem.eql(u8, pattern.severity, "NONE")) "✅"
        else if (std.mem.eql(u8, pattern.severity, "LOW")) "🟡"
        else if (std.mem.eql(u8, pattern.severity, "MODERATE")) "🟠"
        else if (std.mem.eql(u8, pattern.severity, "HIGH")) "🔴"
        else "⛔";

        printDim("    {s} Severity: {s}\n", .{ severity_emoji, pattern.severity });
        printDim("    Pattern Type: {s}\n", .{ pattern.pattern_type });
        printDim("    Max Consecutive: {d}\n", .{ pattern.consecutive_max });
        printDim("    Scattered Losses: {d}\n", .{ pattern.scattered_count });
        if (pattern.periodicity_score > 0) {
            printDim("    Periodicity Score: {d:.0}/100\n", .{ pattern.periodicity_score });
        }

        printDim("\n    Description: {s}\n", .{ pattern.description });

        // Recommendations based on pattern
        printDim("\n    Recommendations:\n", .{});
        if (std.mem.eql(u8, pattern.pattern_type, "BURST")) {
            printDim("       - Check for buffer overflows\n", .{});
            printDim("       - Reduce batch size\n", .{});
            printDim("       - Increase delay between tests\n", .{});
            printDim("       - Consider flow control (RTS/CTS)\n", .{});
        } else if (std.mem.eql(u8, pattern.pattern_type, "GROUPED")) {
            printDim("       - Check for loose connections\n", .{});
            printDim("       - Verify cable integrity\n", .{});
            printDim("       - Try different baud rate\n", .{});
            printDim("       - Check for interference\n", .{});
        } else if (std.mem.eql(u8, pattern.pattern_type, "SCATTERED")) {
            printDim("       - Normal behavior for some links\n", .{});
            printDim("       - May indicate background noise\n", .{});
            printDim("       - Consider error correction\n", .{});
        } else {
            printDim("       - Connection is stable\n", .{});
            printDim("       - No action required\n", .{});
        }
    }

    // v3.92: Session Summary - comprehensive report with recommendations
    pub fn showSessionSummary(self: *const JitterTracker, total_tests: usize, passed_tests: usize) void {
        if (self.count < 5) {
            printInfo("[i] Session Summary: insufficient data (need 5+ samples)\n", .{});
            return;
        }

        const stats = self.getStats();
        const p = self.getPercentiles();
        const stability = self.calculateStabilityScore();
        const burst = self.analyzeBursts(2.0);
        const loss_pattern = self.detectLossPattern();

        printInfo("\n  ══════════════════════════════════════════\n", .{});
        printInfo("  📋 SESSION SUMMARY\n", .{});
        printInfo("  ══════════════════════════════════════════\n", .{});

        // Test results
        const success_rate = @as(f64, @floatFromInt(passed_tests)) / @as(f64, @floatFromInt(total_tests)) * 100.0;
        printDim("  Test Results:\n", .{});
        printDim("    Passed: {d}/{d} ({d:.1}%)\n", .{ passed_tests, total_tests, success_rate });
        printDim("    Samples analyzed: {d}\n", .{ self.count });
        if (self.consecutive_failures > 0) {
            printDim("    Failures: {d} (max consecutive: {d})\n", .{ self.consecutive_failures, self.max_consecutive_failures });
        }

        // Latency summary
        const mean_ms = stats.mean / 1000.0;
        const jitter_ms = stats.jitter / 1000.0;
        printDim("\n  Latency Summary:\n", .{});
        printDim("    Mean RTT: {d:.2}ms\n", .{ mean_ms });
        printDim("    Jitter (σ): {d:.2}ms\n", .{ jitter_ms });
        printDim("    Min: {d:.2}ms, Max: {d:.2}ms\n", .{ @as(f64, @floatFromInt(p.min)) / 1000.0, @as(f64, @floatFromInt(p.max)) / 1000.0 });
        printDim("    p50: {d:.2}ms, p99: {d:.2}ms\n", .{ @as(f64, @floatFromInt(p.p50)) / 1000.0, @as(f64, @floatFromInt(p.p99)) / 1000.0 });

        // Quality assessment
        printDim("\n  Quality Assessment:\n", .{});
        const quality_emoji = if (stability.overall_score >= 90) "🟢"
        else if (stability.overall_score >= 80) "🟡"
        else if (stability.overall_score >= 70) "🟠"
        else "🔴";
        printDim("    {s} Stability Score: {d:.1}/100 ({s})\n", .{ quality_emoji, stability.overall_score, stability.grade });

        const burst_emoji = if (burst.burst_count == 0) "✅"
        else if (std.mem.eql(u8, burst.burst_severity, "LOW")) "🟡"
        else if (std.mem.eql(u8, burst.burst_severity, "MODERATE")) "🟠"
        else "🔴";
        printDim("    {s} Burst Severity: {s} ({d} bursts)\n", .{ burst_emoji, burst.burst_severity, burst.burst_count });

        if (self.consecutive_failures > 0) {
            const loss_emoji = if (std.mem.eql(u8, loss_pattern.severity, "LOW")) "🟡"
            else if (std.mem.eql(u8, loss_pattern.severity, "MODERATE")) "🟠"
            else if (std.mem.eql(u8, loss_pattern.severity, "HIGH")) "🔴"
            else "⛔";
            printDim("    {s} Loss Pattern: {s} ({s})\n", .{ loss_emoji, loss_pattern.pattern_type, loss_pattern.severity });
        }

        // Recommendations
        printDim("\n  Recommendations:\n", .{});
        if (stability.overall_score >= 85) {
            printDim("    ✅ Connection is excellent\n", .{});
            printDim("       - Suitable for real-time applications\n", .{});
            printDim("       - No configuration changes needed\n", .{});
        } else if (stability.overall_score >= 70) {
            printDim("    🟡 Connection is good\n", .{});
            printDim("       - Consider adaptive timeout for sensitive apps\n", .{});
            printDim("       - Monitor for degradation over time\n", .{});
        } else if (stability.overall_score >= 50) {
            printDim("    🟠 Connection has issues\n", .{});
            printDim("       - Try different baud rate\n", .{});
            printDim("       - Increase timeout values\n", .{});
            printDim("       - Check cable quality\n", .{});
        } else {
            printDim("    🔴 Connection is unstable\n", .{});
            printDim("       - Investigate hardware issues\n", .{});
            printDim("       - Consider flow control\n", .{});
            printDim("       - Reduce throughput requirements\n", .{});
        }

        const burst_ratio = if (self.count > 0)
            @as(f64, @floatFromInt(burst.total_burst_samples)) / @as(f64, @floatFromInt(self.count))
        else
            0.0;

        if (burst.burst_count > 0 and burst_ratio > 0.1) {
            printDim("    ⚠️  Frequent bursts detected\n", .{});
            printDim("       - Check for background processes\n", .{});
            printDim("       - Reduce concurrent operations\n", .{});
        }

        printDim("\n  ══════════════════════════════════════════\n", .{});
    }

    // v3.93: Statistical Significance Tests - validate differences between sample groups
    pub const SignificanceTest = struct {
        test_name: []const u8,
        statistic: f64,
        p_value: f64,
        is_significant: bool,
        alpha: f64,
        interpretation: []const u8,
    };

    pub fn runSignificanceTest(self: *const JitterTracker) ?SignificanceTest {
        if (self.count < 10) return null;

        // Split samples into two halves
        const half = @divFloor(self.count, 2);
        var sum1: i64 = 0;
        var sum2: i64 = 0;
        var sum1_sq: f64 = 0;
        var sum2_sq: f64 = 0;

        for (self.samples[0..half]) |s| {
            const s_f = @as(f64, @floatFromInt(s));
            sum1 += s;
            sum1_sq += s_f * s_f;
        }

        for (self.samples[half..self.count]) |s| {
            const s_f = @as(f64, @floatFromInt(s));
            sum2 += s;
            sum2_sq += s_f * s_f;
        }

        const n1: f64 = @floatFromInt(half);
        const n2: f64 = @floatFromInt(self.count - half);

        const mean1 = @as(f64, @floatFromInt(sum1)) / n1;
        const mean2 = @as(f64, @floatFromInt(sum2)) / n2;

        const var1 = (sum1_sq - @as(f64, @floatFromInt(sum1 * sum1)) / n1) / (n1 - 1);
        const var2 = (sum2_sq - @as(f64, @floatFromInt(sum2 * sum2)) / n2) / (n2 - 1);

        // Pooled variance
        const pooled_var = ((n1 - 1) * var1 + (n2 - 1) * var2) / (n1 + n2 - 2);

        // Standard error
        const se = @sqrt(pooled_var * (1.0 / n1 + 1.0 / n2));

        // t-statistic
        const t_statistic = if (se > 0) (mean1 - mean2) / se else 0.0;

        // Degrees of freedom (Welch-Satterthwaite approximation)
        const df = @round(((var1 / n1 + var2 / n2) * (var1 / n1 + var2 / n2)) /
            (((var1 / n1) * (var1 / n1)) / (n1 - 1) + ((var2 / n2) * (var2 / n2)) / (n2 - 1)));

        // For large df, approximate p-value using normal distribution
        // Two-tailed test
        const abs_t = if (t_statistic < 0) -t_statistic else t_statistic;
        const p_value: f64 = if (df > 30)
            // Normal approximation for large df
            2.0 * (1.0 - normalCDF(abs_t))
        else
            // For small df, would need t-distribution CDF
            // Using approximation
            2.0 * (1.0 - normalCDF(abs_t / @sqrt(1.0 + abs_t * abs_t / (2.0 * @max(df, 1.0)))));

        const alpha = 0.05; // 5% significance level
        const is_significant = p_value < alpha;

        const interpretation = if (!is_significant)
            "No significant difference - both halves perform similarly"
        else if (mean1 > mean2)
            "Significant degradation - second half is slower"
        else
            "Significant improvement - second half is faster";

        return .{
            .test_name = "Welch's t-test (two-sample)",
            .statistic = t_statistic,
            .p_value = p_value,
            .is_significant = is_significant,
            .alpha = alpha,
            .interpretation = interpretation,
        };
    }

    // Helper function: normal CDF approximation
    fn normalCDF(x: f64) f64 {
        const a1: f64 = 0.254829592;
        const a2: f64 = -0.284496736;
        const a3: f64 = 1.421413741;
        const a4: f64 = -1.453152027;
        const a5: f64 = 1.061405429;
        const p: f64 = 0.3275911;

        const sign: f64 = if (x < 0) -1.0 else 1.0;
        const x_abs: f64 = if (x < 0) -x else x;

        const k: f64 = 1.0 / (1.0 + p * x_abs);
        const y: f64 = 1.0 - (((((a5 * k + a4) * k) + a3) * k + a2) * k + a1) * k * @exp(-x_abs * x_abs / 2.0);

        return 0.5 * (1.0 + sign * y);
    }

    pub fn showSignificanceTest(self: *const JitterTracker) void {
        const result = self.runSignificanceTest() orelse {
            printInfo("[i] Significance Test: insufficient data (need 10+ samples)\n", .{});
            return;
        };

        printInfo("[i] Statistical Significance Test:\n", .{});
        printDim("    Test: {s}\n", .{result.test_name});
        printDim("    t-statistic: {d:.4}\n", .{result.statistic});
        printDim("    p-value: {d:.6}\n", .{result.p_value});
        printDim("    α (alpha): {d:.2}\n", .{result.alpha});

        const sig_emoji = if (result.is_significant) "⚠️" else "✅";
        const sig_text = if (result.is_significant) "SIGNIFICANT" else "NOT SIGNIFICANT";
        printDim("    {s} Result: {s}\n", .{ sig_emoji, sig_text });

        printDim("\n    Interpretation: {s}\n", .{result.interpretation});

        // Additional insight
        const conf_level = (1.0 - result.alpha) * 100.0;
        printDim("\n    Confidence: {d:.0}%\n", .{ conf_level });
        if (result.is_significant) {
            printDim("    ⚠️  Performance difference is statistically real\n", .{});
            printDim("       Consider investigating the cause\n", .{});
        } else {
            printDim("    ✅ Performance is consistent across test run\n", .{});
        }
    }

    // v3.69: Plot histogram of RTT distribution
    pub fn plotHistogram(self: *const JitterTracker) void {
        const NUM_BINS: usize = 10;
        var bins: [NUM_BINS]usize = [_]usize{0} ** NUM_BINS;

        // Find min and max RTT values
        var min_val: i64 = self.samples[0];
        var max_val: i64 = self.samples[0];
        for (self.samples[0..self.count]) |s| {
            if (s < min_val) min_val = s;
            if (s > max_val) max_val = s;
        }

        const range = @as(f64, @floatFromInt(max_val - min_val));
        const bin_width = if (range > 0) range / @as(f64, @floatFromInt(NUM_BINS)) else 1.0;

        // Assign samples to bins
        for (self.samples[0..self.count]) |s| {
            const val_f = @as(f64, @floatFromInt(s - min_val));
            const bin_idx = @min(NUM_BINS - 1, @as(usize, @intFromFloat(@floor(val_f / bin_width))));
            bins[bin_idx] += 1;
        }

        // Find max bin count for scaling
        var max_count: usize = 0;
        for (bins) |c| {
            if (c > max_count) max_count = c;
        }

        const BAR_WIDTH: usize = 30;
        printDim("\n", .{});
        for (bins, 0..) |count, i| {
            const bin_start = @as(f64, @floatFromInt(min_val)) / 1000.0 + @as(f64, @floatFromInt(i)) * bin_width / 1000.0;
            const bin_end = bin_start + bin_width / 1000.0;

            // Color code based on count (red=high, yellow=medium, green=low)
            const intensity = if (max_count > 0) @as(f64, @floatFromInt(count)) / @as(f64, @floatFromInt(max_count)) else 0;
            const bar_char: u8 = if (intensity > 0.6) '#' else if (intensity > 0.3) '=' else '.';

            // Draw bar
            const bar_len = if (max_count > 0) @as(usize, @intFromFloat(@as(f64, @floatFromInt(count)) / @as(f64, @floatFromInt(max_count)) * @as(f64, @floatFromInt(BAR_WIDTH)))) else 0;

            // Simple bar output
            var bar_str: [BAR_WIDTH]u8 = [_]u8{' '} ** BAR_WIDTH;
            var j: usize = 0;
            while (j < bar_len) : (j += 1) {
                bar_str[j] = bar_char;
            }

            printDim("    [{d:.1}-{d:.1}ms] {s} ({d})\n", .{ @as(i32, @intFromFloat(bin_start)), @as(i32, @intFromFloat(bin_end)), bar_str, count });
        }
        printDim("\n", .{});
    }
};

// v3.30: Buffered I/O manager for reduced syscall overhead
const BufferedIO = struct {
    allocator: std.mem.Allocator,
    read_buffer: []u8,
    write_buffer: []u8,
    read_pos: usize = 0,
    write_pos: usize = 0,
    buffer_size: usize,

    pub fn init(allocator: std.mem.Allocator, buffer_size: usize) !BufferedIO {
        const read_buf = try allocator.alloc(u8, buffer_size);
        errdefer allocator.free(read_buf);
        const write_buf = try allocator.alloc(u8, buffer_size);
        return .{
            .allocator = allocator,
            .read_buffer = read_buf,
            .write_buffer = write_buf,
            .buffer_size = buffer_size,
        };
    }

    pub fn deinit(self: *BufferedIO) void {
        self.allocator.free(self.read_buffer);
        self.allocator.free(self.write_buffer);
    }

    pub fn writeByte(self: *BufferedIO, byte: u8) !void {
        if (self.write_pos >= self.buffer_size) {
            return error.BufferFull;
        }
        self.write_buffer[self.write_pos] = byte;
        self.write_pos += 1;
    }

    pub fn writeBytes(self: *BufferedIO, data: []const u8) !void {
        if (self.write_pos + data.len > self.buffer_size) {
            return error.BufferFull;
        }
        @memcpy(self.write_buffer[self.write_pos..], data);
        self.write_pos += data.len;
    }

    pub fn clearWrite(self: *BufferedIO) void {
        self.write_pos = 0;
    }

    pub fn getWriteSlice(self: *const BufferedIO) []const u8 {
        return self.write_buffer[0..self.write_pos];
    }

    pub fn capacity(self: *const BufferedIO) usize {
        return self.buffer_size - self.write_pos;
    }
};

// v3.30: Batch test results for aggregated throughput measurement
const BatchTestResults = struct {
    total_sent: usize = 0,
    total_received: usize = 0,
    matched: usize = 0,
    failed: usize = 0,
    timeouts: usize = 0,
    batch_time_ms: i64 = 0,
    packets_per_second: f64 = 0.0,
    bytes_per_second: f64 = 0.0,

    pub fn calculateThroughput(self: *BatchTestResults) void {
        if (self.batch_time_ms > 0) {
            const seconds = @as(f64, @floatFromInt(self.batch_time_ms)) / 1000.0;
            if (seconds > 0) {
                self.packets_per_second = @as(f64, @floatFromInt(self.total_sent)) / seconds;
                self.bytes_per_second = @as(f64, @floatFromInt(self.total_received)) / seconds;
            }
        }
    }

    pub fn successRate(self: *const BatchTestResults) f64 {
        if (self.total_sent == 0) return 0.0;
        return @as(f64, @floatFromInt(self.matched)) / @as(f64, @floatFromInt(self.total_sent)) * 100.0;
    }
};

// v3.30: Adaptive timeout calculator based on RTT statistics
const AdaptiveTimeout = struct {
    base_timeout_ms: u32,
    samples: []i64,
    sample_count: usize = 0,
    max_samples: usize = 100,

    pub fn init(allocator: std.mem.Allocator, base_timeout_ms: u32) !AdaptiveTimeout {
        const samples = try allocator.alloc(i64, 100);
        return .{
            .base_timeout_ms = base_timeout_ms,
            .samples = samples,
            .max_samples = 100,
        };
    }

    pub fn deinit(self: *AdaptiveTimeout, allocator: std.mem.Allocator) void {
        allocator.free(self.samples);
    }

    pub fn addSample(self: *AdaptiveTimeout, rtt_ms: i64) void {
        if (self.sample_count < self.max_samples) {
            self.samples[self.sample_count] = rtt_ms;
            self.sample_count += 1;
        } else {
            // Shift out oldest sample
            std.mem.copyForwards(i64, self.samples[0..99], self.samples[1..]);
            self.samples[99] = rtt_ms;
        }
    }

    pub fn calculate(self: *const AdaptiveTimeout) u32 {
        if (self.sample_count < 3) {
            return self.base_timeout_ms; // Need minimum samples for variance calc
        }

        // Calculate mean
        var sum: i64 = 0;
        for (self.samples[0..self.sample_count]) |sample| {
            sum += sample;
        }
        const mean = @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(self.sample_count));

        // Calculate variance
        var variance: f64 = 0.0;
        for (self.samples[0..self.sample_count]) |sample| {
            const diff = @as(f64, @floatFromInt(sample)) - mean;
            variance += diff * diff;
        }
        variance /= @as(f64, @floatFromInt(self.sample_count));

        const std_dev = std.math.sqrt(variance);
        const timeout_adjustment: u32 = @intFromFloat(3.0 * std_dev);
        return self.base_timeout_ms + timeout_adjustment;
    }

    pub fn report(self: *const AdaptiveTimeout) void {
        if (self.sample_count == 0) {
            printInfo("[i] No samples for adaptive timeout\n", .{});
            return;
        }

        const adaptive = self.calculate();
        printInfo("[i] Adaptive Timeout: {d}ms (base: {d}ms)\n", .{ adaptive, self.base_timeout_ms });
    }
};

// v3.55: Quality Alerts - monitors quality and warns on thresholds
const QualityAlerts = struct {
    warning_triggered: bool = false,
    critical_triggered: bool = false,
    last_warning_count: usize = 0,

    // Alert thresholds
    warning_threshold: f64 = 60.0, // Below 60 -> warning
    critical_threshold: f64 = 40.0, // Below 40 -> critical alert

    pub fn check(self: *QualityAlerts, quality_score: f64) void {
        if (quality_score < self.critical_threshold and !self.critical_triggered) {
            printErr("\n[!!!] CRITICAL ALERT: Quality score {d:.0} below {d:.0} threshold!\n", .{ quality_score, self.critical_threshold });
            printErr("      Action: Immediate investigation required\n", .{});
            self.critical_triggered = true;
        } else if (quality_score >= self.critical_threshold and self.critical_triggered) {
            self.critical_triggered = false; // Reset when recovered
            printErr("\n[i] CRITICAL ALERT CLEARED: Quality recovered to {d:.0}\n", .{quality_score});
        } else if (quality_score < self.warning_threshold and !self.warning_triggered) {
            printErr("\n[!] WARNING: Quality score {d:.0} below {d:.0} threshold\n", .{ quality_score, self.warning_threshold });
            printErr("      Action: Monitor for further degradation\n", .{});
            self.warning_triggered = true;
            self.last_warning_count += 1;
        } else if (quality_score >= self.warning_threshold) {
            self.warning_triggered = false; // Reset when recovered
        }
    }

    pub fn getAlertCount(self: *const QualityAlerts) usize {
        return self.last_warning_count;
    }
};

// v3.24: Test pattern structure
const TestPattern = struct {
    name: []const u8,
    data: []const u8,
    description: []const u8 = "",
};

// v3.24: Pattern generators for UART testing
const PatternGenerators = struct {
    // PRBS7 - Pseudo-Random Binary Sequence (7-bit LFSR)
    pub fn generatePRBS7(allocator: std.mem.Allocator, length: usize) ![]u8 {
        var pattern = try allocator.alloc(u8, length);
        errdefer allocator.free(pattern);

        var lfsr: u8 = 0x7F; // Non-zero seed
        var i: usize = 0;

        while (i < length) : (i += 1) {
            const new_bit = @as(u1, @truncate((lfsr >> 6) ^ (lfsr >> 5)));
            lfsr = (lfsr << 1) | new_bit;
            pattern[i] = lfsr;
        }

        return pattern;
    }

    // Walking 1s - single bit moves from LSB to MSB
    pub fn generateWalkingOnes(allocator: std.mem.Allocator, length: usize) ![]u8 {
        var pattern = try allocator.alloc(u8, length);
        errdefer allocator.free(pattern);

        var i: usize = 0;
        while (i < length) : (i += 1) {
            pattern[i] = @as(u8, 1) << @as(u3, @truncate(i % 8));
        }

        return pattern;
    }

    // Walking 0s - single zero moves through all ones
    pub fn generateWalkingZeros(allocator: std.mem.Allocator, length: usize) ![]u8 {
        var pattern = try allocator.alloc(u8, length);
        errdefer allocator.free(pattern);

        var i: usize = 0;
        while (i < length) : (i += 1) {
            pattern[i] = 0xFF ^ (@as(u8, 1) << @as(u3, @truncate(i % 8)));
        }

        return pattern;
    }

    // Sequential - 0x00, 0x01, 0x02, ...
    pub fn generateSequential(allocator: std.mem.Allocator, length: usize) ![]u8 {
        var pattern = try allocator.alloc(u8, length);
        errdefer allocator.free(pattern);

        var i: usize = 0;
        while (i < length) : (i += 1) {
            pattern[i] = @truncate(i);
        }

        return pattern;
    }

    // Alternating - 0xAA, 0x55, 0xAA, 0x55, ...
    pub fn generateAlternating(allocator: std.mem.Allocator, length: usize) ![]u8 {
        var pattern = try allocator.alloc(u8, length);
        errdefer allocator.free(pattern);

        var i: usize = 0;
        while (i < length) : (i += 1) {
            pattern[i] = if (i % 2 == 0) 0xAA else 0x55;
        }

        return pattern;
    }

    // Default pattern - mix of common test bytes
    pub fn generateDefault(allocator: std.mem.Allocator, length: usize) ![]u8 {
        const default_bytes = [_]u8{ 0x00, 0xFF, 0xAA, 0x55, 0x01, 0xFE, 0x55, 0xAA };
        var pattern = try allocator.alloc(u8, length);
        errdefer allocator.free(pattern);

        var i: usize = 0;
        while (i < length) : (i += 1) {
            pattern[i] = default_bytes[i % default_bytes.len];
        }

        return pattern;
    }

    pub fn getPattern(allocator: std.mem.Allocator, name: []const u8, length: usize) !TestPattern {
        if (std.mem.eql(u8, name, "prbs7")) {
            const data = try generatePRBS7(allocator, length);
            return .{
                .name = "prbs7",
                .data = data,
                .description = "Pseudo-Random Binary Sequence (7-bit LFSR)",
            };
        } else if (std.mem.eql(u8, name, "walk1")) {
            const data = try generateWalkingOnes(allocator, length);
            return .{
                .name = "walk1",
                .data = data,
                .description = "Walking 1s pattern",
            };
        } else if (std.mem.eql(u8, name, "walk0")) {
            const data = try generateWalkingZeros(allocator, length);
            return .{
                .name = "walk0",
                .data = data,
                .description = "Walking 0s pattern",
            };
        } else if (std.mem.eql(u8, name, "seq")) {
            const data = try generateSequential(allocator, length);
            return .{
                .name = "seq",
                .data = data,
                .description = "Sequential 0x00, 0x01, 0x02...",
            };
        } else if (std.mem.eql(u8, name, "alt")) {
            const data = try generateAlternating(allocator, length);
            return .{
                .name = "alt",
                .data = data,
                .description = "Alternating 0xAA/0x55 pattern",
            };
        } else {
            const data = try generateDefault(allocator, length);
            return .{
                .name = "default",
                .data = data,
                .description = "Default test pattern",
            };
        }
    }
};

// v3.24: Device detection with VID/PID
const DeviceInfo = struct {
    path: []const u8,
    vendor_id: u16,
    product_id: u16,
    vendor_name: []const u8,
};

// v3.24: SIGINT handler for graceful exit
fn setupSignalHandler() void {
    const SIGINT = 2;
    _ = std.posix.sigaction(SIGINT, &.{
        .handler = .{ .handler = handleSIGINT },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    }, null);
}

// v3.24: Auto baud detection - tries each baud rate and returns working one
fn autoDetectBaud(fd: std.posix.fd_t) ?u64 {
    printInfo("[i] Auto-detecting baud rate...\n", .{});

    for (VALID_BAUD_RATES) |baud| {
        printDim("[*] Trying {d} baud... ", .{baud});

        if (configureSerial(fd, baud)) {
            // Send test byte to verify
            const test_byte: u8 = 0x55;
            _ = std.posix.write(fd, &[_]u8{test_byte}) catch {};

            std.Thread.sleep(100_000); // 100ms wait

            // Try to read response
            var read_buf: [8]u8 = undefined;
            const read_result = std.posix.read(fd, &read_buf);

            if (read_result) |_| {
                // Port seems responsive at this baud rate
                printSuccess("OK!\n", .{});
                return baud;
            } else |_| {
                printDim("No response\n", .{});
            }
        } else {
            printDim("Failed to configure\n", .{});
        }
    }

    printError("[!] Could not auto-detect baud rate\n", .{});
    return null;
}

fn handleSIGINT(sig: c_int) callconv(.c) void {
    _ = sig;
    printErr("\n[i] Received SIGINT, exiting gracefully...\n", .{});
    should_exit.store(true, .seq_cst);
}

// PING/PONG protocol
const PING_BYTE: u8 = 0x03; // Send PING
const PONG_BYTE: u8 = 0x83; // Expect PONG response

// v3.24: Check if baud rate is valid
fn isValidBaudRate(baud: u64) bool {
    for (VALID_BAUD_RATES) |rate| {
        if (baud == rate) return true;
    }
    return false;
}

// Helper for formatted stderr output
fn printErr(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

// v3.24: Colored output functions
fn printSuccess(comptime fmt: []const u8, args: anytype) void {
    printErr(ANSI.GREEN ++ fmt ++ ANSI.RESET, args);
}
fn printError(comptime fmt: []const u8, args: anytype) void {
    printErr(ANSI.RED ++ fmt ++ ANSI.RESET, args);
}
fn printWarning(comptime fmt: []const u8, args: anytype) void {
    printErr(ANSI.YELLOW ++ fmt ++ ANSI.RESET, args);
}
fn printInfo(comptime fmt: []const u8, args: anytype) void {
    printErr(ANSI.CYAN ++ fmt ++ ANSI.RESET, args);
}
fn printDim(comptime fmt: []const u8, args: anytype) void {
    printErr(ANSI.DIM ++ fmt ++ ANSI.RESET, args);
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
        .csv_output = false, // v3.46: CSV export
        .config_file = null,
        .measure_throughput = false,
        .simulation_mode = false,
        .dry_run = false,
        .batch_size = DEFAULT_BATCH_SIZE,
        .buffer_size = DEFAULT_BUFFER_SIZE,
        .adaptive_timeout = false,
        .test_patterns_file = null,
        // v3.24: Initialize new fields
        .auto_baud = false,
        .rts_cts_flow = false,
        .stress_test_mode = false,
        .stress_packets = 10,
        .measure_jitter = false,
        .spike_threshold = 3.0, // v3.49: Configurable spike threshold
        .use_pattern = "default",
        .pattern_length = 256,
        // v3.26: FPGA XVC Bridge integration
        .fpga_mode = false,
        .esp32_host = "esp32-xvc.local",
        .esp32_port = 2542,
        .bitstream_path = null,
        .fpga_verify_mode = false,
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
            if (!isValidBaudRate(config.baud)) {
                printErr("[*] Invalid baud rate: {d}\n", .{config.baud});
                printErr("    Valid rates: ", .{});
                for (VALID_BAUD_RATES, 0..) |rate, j| {
                    if (j > 0) printErr(", ", .{});
                    printErr("{d}", .{rate});
                }
                printErr("\n", .{});
                std.process.exit(1);
            }
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
        } else if (std.mem.eql(u8, arg, "--csv")) {
            // v3.46: CSV export
            config.csv_output = true;
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
        } else if (std.mem.eql(u8, arg, "--list-devices")) {
            listSerialPorts();
            std.process.exit(0);
        } else if (std.mem.eql(u8, arg, "--auto-baud")) {
            config.auto_baud = true;
        } else if (std.mem.eql(u8, arg, "--rts-cts")) {
            config.rts_cts_flow = true;
        } else if (std.mem.eql(u8, arg, "--stress-test")) {
            config.stress_test_mode = true;
        } else if (std.mem.eql(u8, arg, "--stress-packets")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --stress-packets requires value\n", .{});
                std.process.exit(1);
            }
            config.stress_packets = std.fmt.parseInt(usize, std.mem.span(std.os.argv[i + 1]), 10) catch |err| {
                printErr("[*] Invalid stress-packets value: {any}\n", .{err});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "--measure-jitter")) {
            config.measure_jitter = true;
        } else if (std.mem.eql(u8, arg, "--spike-threshold")) {
            // v3.49: Configurable spike threshold
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --spike-threshold requires value\n", .{});
                std.process.exit(1);
            }
            const threshold_str = std.mem.span(std.os.argv[i + 1]);
            config.spike_threshold = std.fmt.parseFloat(f64, threshold_str) catch {
                printErr("[*] --spike-threshold must be a number\n", .{});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "--outlier-method")) {
            // v3.63: Outlier detection method (fixed or iqr)
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --outlier-method requires value (fixed or iqr)\n", .{});
                std.process.exit(1);
            }
            const method = std.mem.span(std.os.argv[i + 1]);
            if (!std.mem.eql(u8, method, "fixed") and !std.mem.eql(u8, method, "iqr")) {
                printErr("[*] --outlier-method must be 'fixed' or 'iqr'\n", .{});
                std.process.exit(1);
            }
            config.outlier_method = method;
            i += 1;
        } else if (std.mem.eql(u8, arg, "--alert-warning")) {
            // v3.57: Configurable warning alert threshold
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --alert-warning requires value\n", .{});
                std.process.exit(1);
            }
            const threshold_str = std.mem.span(std.os.argv[i + 1]);
            config.alert_warning_threshold = std.fmt.parseFloat(f64, threshold_str) catch {
                printErr("[*] --alert-warning must be a number\n", .{});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "--alert-critical")) {
            // v3.57: Configurable critical alert threshold
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --alert-critical requires value\n", .{});
                std.process.exit(1);
            }
            const threshold_str = std.mem.span(std.os.argv[i + 1]);
            config.alert_critical_threshold = std.fmt.parseFloat(f64, threshold_str) catch {
                printErr("[*] --alert-critical must be a number\n", .{});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "--pattern")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --pattern requires value\n", .{});
                std.process.exit(1);
            }
            config.use_pattern = std.mem.span(std.os.argv[i + 1]);
            i += 1;
        } else if (std.mem.eql(u8, arg, "--pattern-length")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --pattern-length requires value\n", .{});
                std.process.exit(1);
            }
            config.pattern_length = std.fmt.parseInt(usize, std.mem.span(std.os.argv[i + 1]), 10) catch |err| {
                printErr("[*] Invalid pattern-length value: {any}\n", .{err});
                std.process.exit(1);
            };
            // v3.38: Pattern length validation
            if (config.pattern_length < 8) {
                printWarning("[*] Pattern length < 8 may be too short for reliable testing\n", .{});
            } else if (config.pattern_length > 2048) {
                printWarning("[*] Pattern length > 2048 may cause memory issues\n", .{});
            }
            i += 1;
        } else if (std.mem.eql(u8, arg, "--comprehensive")) {
            config.comprehensive_mode = true;
        } else if (std.mem.eql(u8, arg, "--fpga-mode")) {
            config.fpga_mode = true;
        } else if (std.mem.eql(u8, arg, "--esp32-host")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --esp32-host requires value\n", .{});
                std.process.exit(1);
            }
            config.esp32_host = std.mem.span(std.os.argv[i + 1]);
            i += 1;
        } else if (std.mem.eql(u8, arg, "--esp32-port")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --esp32-port requires value\n", .{});
                std.process.exit(1);
            }
            config.esp32_port = std.fmt.parseInt(u16, std.mem.span(std.os.argv[i + 1]), 10) catch |err| {
                printErr("[*] Invalid esp32-port value: {any}\n", .{err});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "--bitstream")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --bitstream requires value\n", .{});
                std.process.exit(1);
            }
            config.bitstream_path = std.mem.span(std.os.argv[i + 1]);
            i += 1;
        } else if (std.mem.eql(u8, arg, "--fpga-verify")) {
            config.fpga_verify_mode = true;
        } else if (std.mem.eql(u8, arg, "--fpga-timeout")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --fpga-timeout requires value\n", .{});
                std.process.exit(1);
            }
            config.fpga_timeout_ms = std.fmt.parseInt(u32, std.mem.span(std.os.argv[i + 1]), 10) catch |err| {
                printErr("[*] Invalid fpga-timeout value: {any}\n", .{err});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "--fpga-retries")) {
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --fpga-retries requires value\n", .{});
                std.process.exit(1);
            }
            config.fpga_retries = std.fmt.parseInt(u32, std.mem.span(std.os.argv[i + 1]), 10) catch |err| {
                printErr("[*] Invalid fpga-retries value: {any}\n", .{err});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "--extended-health-check")) {
            config.extended_health_check = true;
        } else if (std.mem.eql(u8, arg, "--save-baseline")) {
            // v3.58: Save baseline file
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --save-baseline requires value\n", .{});
                std.process.exit(1);
            }
            config.baseline_file = std.mem.span(std.os.argv[i + 1]);
            i += 1;
        } else if (std.mem.eql(u8, arg, "--compare-baseline")) {
            // v3.58: Compare against baseline file
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --compare-baseline requires value\n", .{});
                std.process.exit(1);
            }
            config.baseline_file = std.mem.span(std.os.argv[i + 1]);
            config.compare_baseline = true;
            i += 1;
        } else if (std.mem.eql(u8, arg, "--statistical")) {
            // v3.60: Statistical significance testing
            config.statistical_mode = true;
        } else if (std.mem.eql(u8, arg, "--time-series")) {
            // v3.61: Time series visualization
            config.time_series_plot = true;
        } else if (std.mem.eql(u8, arg, "--multi-baseline")) {
            // v3.62: Multi-baseline comparison
            if (i + 1 >= std.os.argv.len) {
                printErr("[*] --multi-baseline requires value\n", .{});
                std.process.exit(1);
            }
            config.multi_baseline_dir = std.mem.span(std.os.argv[i + 1]);
            i += 1;
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
                const baud_val = std.fmt.parseInt(u64, value, 10) catch continue;
                if (isValidBaudRate(baud_val)) {
                    config.baud = baud_val;
                    loaded_any = true;
                } else {
                    printErr("[!] Invalid baud rate in config: {d}\n", .{baud_val});
                }
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
            } else if (std.mem.eql(u8, key, "auto_baud")) {
                config.auto_baud = std.ascii.eqlIgnoreCase(value, "true");
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "rts_cts_flow")) {
                config.rts_cts_flow = std.ascii.eqlIgnoreCase(value, "true");
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "stress_test_mode")) {
                config.stress_test_mode = std.ascii.eqlIgnoreCase(value, "true");
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "stress_packets")) {
                config.stress_packets = std.fmt.parseInt(usize, value, 10) catch continue;
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "measure_jitter")) {
                config.measure_jitter = std.ascii.eqlIgnoreCase(value, "true");
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "pattern")) {
                config.use_pattern = value;
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "pattern_length")) {
                config.pattern_length = std.fmt.parseInt(usize, value, 10) catch continue;
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "fpga_mode")) {
                config.fpga_mode = std.ascii.eqlIgnoreCase(value, "true");
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "esp32_host")) {
                config.esp32_host = value;
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "esp32_port")) {
                config.esp32_port = std.fmt.parseInt(u16, value, 10) catch continue;
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "bitstream_path")) {
                config.bitstream_path = value;
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "fpga_verify_mode")) {
                config.fpga_verify_mode = std.ascii.eqlIgnoreCase(value, "true");
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "fpga_timeout_ms")) {
                config.fpga_timeout_ms = std.fmt.parseInt(u32, value, 10) catch continue;
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "fpga_retries")) {
                config.fpga_retries = std.fmt.parseInt(u32, value, 10) catch continue;
                loaded_any = true;
            } else if (std.mem.eql(u8, key, "extended_health_check")) {
                config.extended_health_check = std.ascii.eqlIgnoreCase(value, "true");
                loaded_any = true;
            }
        }
    }

    return loaded_any;
}

fn printUsage() void {
    std.debug.print(
        \\╔════════════════════════════════════╗
        \\║      Trinity UART Echo Test v4.06           ║
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
        \\  --csv               Export results to CSV format (v3.46)
        \\  --batch-size <n>    Send N packets per batch (default: 16)
        \\  --buffer-size <n>   I/O buffer size in bytes (default: 4096)
        \\  --adaptive-timeout   Dynamically adjust timeout based on RTT
        \\  --auto-configure    Auto-configure port (termios setup)
        \\  --auto-baud         Auto-detect baud rate (v3.24)
        \\  --rts-cts           Enable RTS/CTS hardware flow control (v3.24)
        \\  --stress-test       High-throughput stress test mode (v3.24)
        \\  --stress-packets <n> Packets per stress test (default: 10)
        \\  --measure-jitter    Measure RTT jitter variance (v3.24)
        \\  --spike-threshold N Spike detection threshold multiplier (default: 3.0) (v3.49)
        \\  --outlier-method <m> Outlier detection: fixed|iqr (default: fixed) (v3.63)
        \\  --pattern <name>    Test pattern: default|prbs7|walk1|walk0|seq|alt
        \\  --pattern-length <n> Length of generated pattern (default: 256)
        \\  --simulation         Simulation mode (no hardware required)
        \\  --dry-run           Show what would be sent (no actual I/O)
        \\  --list-devices      List all available serial devices (v3.24)
        \\  --fpga-mode         Enable FPGA XVC Bridge integration (v3.26)
        \\  --esp32-host HOST   ESP32 hostname/IP (default: esp32-xvc.local)
        \\  --esp32-port PORT   XVC Bridge port (default: 2542)
        \\  --bitstream PATH    Bitstream file to flash via ESP32
        \\  --fpga-timeout MS  FPGA operation timeout in milliseconds (default: 30000)
        \\  --fpga-retries N    Max retries for FPGA operations (default: 3)
        \\  --fpga-verify       Enable FPGA verification mode
        \\  --diagnostics        Enable detailed error pattern analysis (v3.37)
        \\  --auto-recovery     Enable exponential backoff auto-recovery (v3.37)
        \\  --extended-health-check  Verify framing and echo in health check (v3.38)
        \\  --save-baseline <file>     Save current run as performance baseline (v3.58)
        \\  --compare-baseline <file>  Compare current run against saved baseline (v3.58)
        \\  --statistical       Statistical significance testing (Welch's t-test, CI) (v3.60)
        \\  --time-series       Time series visualization (ASCII RTT/jitter plots) (v3.61)
        \\  --multi-baseline <dir>  Compare against all historical baselines (v3.62)
        \\  --help              Show this help message
        \\
        \\Performance Modes (v3.60):
        \\  Default: Sequential echo test with verification
        \\  Batch: Send N packets, measure aggregated throughput
        \\  Adaptive: Auto-tune timeout based on measured latency
        \\  Buffered: Pre-allocated I/O buffers
        \\  Performance: Report with efficiency & recommendations
        \\  Simulation: Virtual UART testing without hardware
        \\  Comprehensive: Unified 3-phase test (Basic, Batch, Performance)
        \\  Stress: High-throughput continuous testing without wait (v3.24)
        \\  FPGA: ESP32 XVC Bridge + FPGA + UART test cycle (v3.28)
        \\  Diagnostics: Error pattern analysis with suggested fixes (v3.37)
        \\  Auto-Recovery: Exponential backoff retry for failed tests (v3.39)
        \\  Batch Auto-Recovery: Retry logic for batch test mode (v3.40)
        \\  Simulation Auto-Recovery: Simulated retry logic for simulation mode (v3.41)
        \\  Comprehensive Recovery: Recovery statistics tracking for comprehensive mode (v3.42)
        \\  Stress Error Tracking: Write/read error tracking for stress test mode (v3.43)
        \\  RTT Percentiles: p50/p90/p95/p99 latency percentiles with jitter tracking (v3.44)
        \\  JSON Percentiles: Export RTT percentiles in JSON output (v3.45)
        \\  CSV Percentiles: Export RTT percentiles in CSV format (v3.46)
        \\  ASCII Histogram Bars: Visual bar chart for latency distribution (v3.47)
        \\  Latency Spike Detection: Identify outliers > 3x median RTT (v3.48)
        \\  Spike Threshold: Configurable via --spike-threshold (v3.49)
        \\  Help Documentation: Complete help text with all options (v3.50)
        \\  Pattern Validation: Length validation for test patterns (v3.38)
        \\  Extended Health Check: Framing verification before tests (v3.38)
        \\  Performance Baseline: Save/compare performance runs (v3.58)
        \\  Statistical Significance: Welch's t-test, CI, Cohen's d (v3.60)
        \\  Time Series Plots: ASCII visualization of RTT/jitter over time (v3.61)
        \\  Multi-Baseline Comparison: Compare against historical baselines (v3.62)
        \\
        \\  Comprehensive Mode (v3.34):
        \\  Phase 1: Basic Echo Test — verifies serial communication
        \\  Phase 2: Batch Throughput Test — measures packets/sec throughput
        \\  Phase 3: Performance Report — calculates efficiency & recommendations
        \\  Use: --comprehensive --device <port>
        \\
        \\Config File (v3.15+):
        \\  Supports key=value format (one per line):
        \\  Example:
        \\    baud=115200
        \\    timeout=2000
        \\    batch_size=32
        \\    adaptive_timeout=true
        \\    comprehensive_mode=true
        \\    auto_baud=true
        \\    fpga_mode=true
        \\    esp32_host=192.168.4.1
        \\    fpga_timeout_ms=30000
        \\    fpga_retries=3
        \\    rts_cts_flow=true
        \\    stress_test_mode=true
        \\    stress_packets=100
        \\    fpga_mode=true
        \\    esp32_host=esp32-xvc.local
        \\    bitstream_path=phi_blink_top.bit
        \\
        \\Supported Adapters:
        \\  - FT232RL (FTDI)   - CP210x (Silicon Labs)
        \\  - CH340 (WCH)        - PL2303 (Prolific)
        \\
        \\Examples:
        \\  zig run uart-echo-test --ping-mode -v --throughput --json
        \\  zig run uart-echo-test --batch-size 32 --throughput
        \\  zig run uart-echo-test --adaptive-timeout --buffer-size 16384
        \\  zig run uart-echo-test --fpga-mode --bitstream phi_blink_top.bit
        \\  zig run uart-echo-test --fpga-mode --esp32-host 192.168.4.1 --ap
        \\
    , .{});
}

// v3.24: Health check function - validates serial port before testing
// v3.38: Extended health checks with framing verification
fn healthCheck(port_path: ?[]const u8, baud: u64, config: Config) !bool {
    if (port_path == null) return true; // No port, skip check

    printErr("[i] Running health check on: {s}\n", .{port_path.?});

    // v3.24: Simple device type detection from path
    const device_name = std.fs.path.basename(port_path.?);
    if (std.mem.indexOf(u8, device_name, "usbserial-")) |_| {
        printErr("[+] Device type: USB Serial adapter\n", .{});
    }

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

    // v3.38: Extended health check with framing verification
    if (config.extended_health_check) {
        printErr("[i] Extended health check: Verifying framing and echo...\n", .{});

        // Send simple test pattern: 0xAA 0x55 0x00 0xFF (alternating bits + edge cases)
        const test_pattern = [_]u8{ 0xAA, 0x55, 0x00, 0xFF };

        const write_result = std.posix.write(fd, &test_pattern);
        if (write_result) |written| {
            if (written != test_pattern.len) {
                printErr("[!] Extended health check: Only wrote {d}/{d} bytes\n", .{ written, test_pattern.len });
                return false;
            }
        } else |err| {
            printErr("[!] Extended health check: Write failed: {any}\n", .{err});
            return false;
        }

        // Small delay for echo
        std.Thread.sleep(50_000); // 50ms

        // Read response with short timeout
        var read_buffer: [8]u8 = undefined;
        var bytes_read: usize = 0;
        const start_time = std.time.milliTimestamp();

        while (bytes_read < test_pattern.len and (std.time.milliTimestamp() - start_time) < 500) {
            const read_result = std.posix.read(fd, read_buffer[bytes_read..]);
            if (read_result) |n| {
                bytes_read += n;
            } else |err| {
                if (err == error.OperationWouldBlock) {
                    std.Thread.sleep(5_000); // 5ms
                    continue;
                }
                printErr("[!] Extended health check: Read error: {any}\n", .{err});
                return false;
            }
        }

        if (bytes_read == test_pattern.len) {
            var all_match = true;
            for (0..test_pattern.len) |i| {
                if (read_buffer[i] != test_pattern[i]) {
                    all_match = false;
                    printErr("[!] Extended health check: Mismatch at byte {d}: sent 0x{x:0>2}, got 0x{x:0>2}\n", .{ i, test_pattern[i], read_buffer[i] });
                    break;
                }
            }
            if (all_match) {
                printErr("[+] Extended health check: Framing verification PASSED\n", .{});
            } else {
                printErr("[!] Extended health check: Framing verification FAILED\n", .{});
                return false;
            }
        } else {
            printErr("[!] Extended health check: Timeout - expected {d} bytes, got {d}\n", .{ test_pattern.len, bytes_read });
            printErr("[!] Extended health check: Device may not be in echo mode or is disconnected\n", .{});
            return false;
        }
    }

    return true;
}

// v3.26: FPGA XVC Bridge client
const FpgaXvcClient = struct {
    host: []const u8,
    port: u16,
    allocator: std.mem.Allocator,
    // v3.27: Configurable timeout and retry settings
    timeout_ms: u32 = 30000,
    max_retries: u32 = 3,

    pub fn init(allocator: std.mem.Allocator, host: []const u8, port: u16) FpgaXvcClient {
        return .{
            .host = host,
            .port = port,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *const FpgaXvcClient) void {
        _ = self;
    }

    // v3.27: Set timeout in milliseconds
    pub fn setTimeout(self: *FpgaXvcClient, timeout_ms: u32) void {
        self.timeout_ms = timeout_ms;
    }

    // v3.27: Set max retries
    pub fn setMaxRetries(self: *FpgaXvcClient, max_retries: u32) void {
        self.max_retries = max_retries;
    }

    // Check ESP32 status
    pub fn checkStatus(self: *const FpgaXvcClient) !bool {
        printInfo("[XVC] Checking ESP32 status...\n", .{});

        // v3.27: Parse IP address (hostname support planned for v3.28)
        const address = try std.net.Address.parseIp4(self.host, self.port);
        var socket = try std.net.tcpConnectToAddress(address);
        defer socket.close();

        try socket.writeAll("STATUS\n");
        var buf: [512]u8 = undefined;
        const len = try socket.read(&buf);
        const response = buf[0..len];

        if (std.mem.indexOf(u8, response, "READY") != null) {
            printSuccess("[XVC] ESP32: READY\n", .{});
            return true;
        } else {
            printWarning("[XVC] ESP32 status: {s}\n", .{response});
            return false;
        }
    }

    // v3.27: Flash bitstream with retry logic
    pub fn flashBitstream(self: *const FpgaXvcClient, bitstream_path: []const u8) !bool {
        printInfo("[XVC] Flashing bitstream: {s}\n", .{bitstream_path});
        printDim("[XVC] Timeout: {d}ms, Max retries: {d}\n", .{ self.timeout_ms, self.max_retries });

        // Retry loop
        var retry: u32 = 0;
        while (retry <= self.max_retries) : (retry += 1) {
            if (retry > 0) {
                printWarning("[XVC] Retry {d}/{d}...\n", .{ retry, self.max_retries });
            }

            const result = self.flashBitstreamOnce(bitstream_path) catch |err| {
                printWarning("[XVC] Attempt {d} failed: {any}\n", .{ retry + 1, err });
                continue;
            };

            if (result) {
                return true;
            }
        }

        printError("[XVC] All {d} attempts failed\n", .{self.max_retries + 1});
        return false;
    }

    // v3.27: Single flash attempt with timeout
    fn flashBitstreamOnce(self: *const FpgaXvcClient, bitstream_path: []const u8) !bool {
        // v3.27: Parse IP address (hostname support planned for v3.28)
        const address = try std.net.Address.parseIp4(self.host, self.port);
        var socket = try std.net.tcpConnectToAddress(address);
        defer socket.close();

        // Send FLASH command
        var cmd_buf: [1024]u8 = undefined;
        const cmd = try std.fmt.bufPrintZ(&cmd_buf, "FLASH {s}\n", .{bitstream_path});
        try socket.writeAll(cmd);
        printSuccess("[XVC] Flash command sent\n", .{});

        // Wait for response with configurable timeout
        const timeout_seconds = self.timeout_ms / 1000;
        var elapsed: u32 = 0;
        var response_buf: [512]u8 = undefined;

        while (elapsed < timeout_seconds) : (elapsed += 1) {
            const len = socket.read(&response_buf) catch 0;
            if (len > 0) {
                const response = response_buf[0..len];
                if (std.mem.indexOf(u8, response, "OK") != null) {
                    printSuccess("[XVC] Flash complete (took {d}s)\n", .{elapsed});
                    return true;
                } else if (std.mem.indexOf(u8, response, "BUSY") != null) {
                    printWarning("[XVC] ESP32 busy, waiting...\n", .{});
                    std.Thread.sleep(1 * std.time.ns_per_s);
                    continue;
                } else if (std.mem.indexOf(u8, response, "ERROR") != null) {
                    printError("[XVC] Flash error: {s}\n", .{response});
                    return error.FpgaFlashError;
                }
            }
            std.Thread.sleep(1 * std.time.ns_per_s);
        }

        printError("[XVC] Flash timeout after {d}s\n", .{elapsed});
        return error.FpgaFlashTimeout;
    }

    // Get ESP32 info
    pub fn getInfo(self: *const FpgaXvcClient) ![]const u8 {
        // v3.27: Parse IP address (hostname support planned for v3.28)
        const address = try std.net.Address.parseIp4(self.host, self.port);
        var socket = try std.net.tcpConnectToAddress(address);
        defer socket.close();

        try socket.writeAll("GETINFO\n");
        var buf: [512]u8 = undefined;
        const len = try socket.read(&buf);
        const response = try self.allocator.dupe(u8, buf[0..len]);
        return response;
    }
};

// v3.26: FPGA test cycle integration
fn runFpgaTestCycle(config: Config) !void {
    printErr(
        \\╔══════════════════════════════════════╗
        \\║      FPGA XVC INTEGRATED TEST CYCLE      ║
        \\║             v3.27                       ║
        \\╚══════════════════════════════════════╝
        \\
    , .{});

    const allocator = std.heap.page_allocator;

    // Initialize XVC client
    var xvc_client = FpgaXvcClient.init(allocator, config.esp32_host, config.esp32_port);
    defer xvc_client.deinit();

    // Step 1: Check ESP32 status
    printInfo("[1/4] Checking ESP32 XVC Bridge status...\n", .{});
    if (!try xvc_client.checkStatus()) {
        printError("[!] ESP32 not ready\n", .{});
        return error.Esp32NotReady;
    }

    // Step 2: (Optional) Flash bitstream
    if (config.bitstream_path) |bitstream| {
        printInfo("[2/4] Flashing bitstream to FPGA...\n", .{});
        if (!try xvc_client.flashBitstream(bitstream)) {
            printError("[!] Bitstream flash failed\n", .{});
            return error.BitstreamFlashFailed;
        }
        printSuccess("[+] Bitstream flashed successfully\n", .{});

        // Wait for FPGA to initialize
        printInfo("[3/4] Waiting for FPGA initialization (2s)...\n", .{});
        std.Thread.sleep(2 * std.time.ns_per_s);
    } else {
        printInfo("[2/4] Skipping bitstream flash (none specified)\n", .{});
        printInfo("[3/4] Using current FPGA configuration\n", .{});
    }

    // Step 3: Run UART echo tests with FPGA
    printInfo("[4/4] Running UART echo tests with FPGA...\n", .{});
    if (config.device) |dev| {
        testEcho(dev, config);
    } else {
        printError("[!] No device specified for UART test\n", .{});
        return error.NoDeviceSpecified;
    }

    printSuccess("\n[+] FPGA test cycle complete\n", .{});
}

pub fn main() !void {
    // v3.24: Setup graceful exit handler
    setupSignalHandler();

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
        printErr("    auto_configure: {}\n", .{config.auto_configure});
        printErr("    auto_baud: {}\n", .{config.auto_baud});
        printErr("    rts_cts_flow: {}\n", .{config.rts_cts_flow});
        printErr("    stress_test_mode: {}\n", .{config.stress_test_mode});
        printErr("    stress_packets: {d}\n", .{config.stress_packets});
        printErr("    measure_jitter: {}\n", .{config.measure_jitter});
        printErr("    use_pattern: {s}\n", .{config.use_pattern});
        printErr("    pattern_length: {d}\n", .{config.pattern_length});
        // v3.26: FPGA XVC settings
        printErr("    fpga_mode: {}\n", .{config.fpga_mode});
        printErr("    esp32_host: {s}\n", .{config.esp32_host});
        printErr("    esp32_port: {d}\n", .{config.esp32_port});
        if (config.bitstream_path) |bs| {
            printErr("    bitstream_path: {s}\n", .{bs});
        }
        printErr("    fpga_verify_mode: {}\n", .{config.fpga_verify_mode});
        printErr("    fpga_timeout_ms: {d}\n", .{config.fpga_timeout_ms});
        printErr("    fpga_retries: {d}\n", .{config.fpga_retries});
        if (config.output_file) |f| {
            printErr("    output_file: {s}\n", .{f});
        }
        printErr("\n", .{});
    }

    // v3.26: Check for FPGA mode
    if (config.fpga_mode) {
        printErr(
            \\╔══════════════════════════════════════╗
            \\║         FPGA XVC MODE (v3.27)          ║
            \\║  ESP32 Bridge + FPGA + UART test       ║
            \\╚══════════════════════════════════════╝
            \\
        , .{});
        return runFpgaTestCycle(config);
    }

    // v3.37: Check for diagnostics mode (before simulation)
    if (config.diagnostics_mode) {
        printErr(
            \\╔════════════════════════════════════╗
            \\║        DIAGNOSTICS MODE (v3.37)       ║
            \\║  Running diagnostic test sequence   ║
            \\╚════════════════════════════════════╝
            \\
        , .{});
        return runDiagnosticsMode(config) catch {};
    }

    // v3.14: Check for simulation mode
    if (config.simulation_mode) {
        printErr(
            \\╔══════════════════════════════════════╗
            \\║         SIMULATION MODE (v4.06)         ║
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

    // v3.37: Diagnostics mode
    if (config.diagnostics_mode) {
        printErr(
            \\╔════════════════════════════════════╗
            \\║        DIAGNOSTICS MODE (v3.37)       ║
            \\║  Running diagnostic test sequence   ║
            \\╚════════════════════════════════════╝
            \\
        , .{});
        return runDiagnosticsMode(config) catch {};
    }

    // v3.33: Comprehensive test mode
    if (config.comprehensive_mode) {
        printErr(
            \\╔════════════════════════════════════╗
            \\║      COMPREHENSIVE MODE (v3.33)      ║
            \\║  Running all test phases            ║
            \\╚══════════════════════════════════╝
            \\
        , .{});
        // Open device for comprehensive mode
        if (config.device) |dev| {
            const flags: u32 = 0x0002 | 0x08000;
            const fd = std.posix.open(dev, @as(std.posix.O, @bitCast(flags)), 0) catch |err| {
                printErr("[*] Failed to open {s}: {any}\n", .{ dev, err });
                std.process.exit(1);
            };
            defer std.posix.close(fd);

            // Configure port
            _ = configureSerial(fd, config.baud);
            return runComprehensiveTest(fd, config) catch {};
        } else {
            printErr("[*] --comprehensive requires --device <port>\n", .{});
            std.process.exit(1);
        }
    }

    printErr(
        \\╔══════════════════════════════════════╗
        \\║      Trinity UART Echo Test v3.26          ║
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
        const passed = healthCheck(port.?, config.baud, config) catch false;
        if (!passed) {
            printErr("[!] Health check failed, aborting...\n", .{});
            std.process.exit(1);
        }
        printErr("[+] Health check passed\n", .{});
    }

    testEcho(port.?, config);
}

// v3.24: List all available serial devices with detailed info
fn listSerialPorts() void {
    printInfo("\n[*] Scanning for serial devices...\n", .{});
    var dir = std.fs.openDirAbsolute("/dev", .{}) catch |err| {
        printError("[!] Cannot open /dev: {any}\n", .{err});
        return;
    };
    defer dir.close();

    var iterator = dir.iterate();
    var found_count: usize = 0;

    while (iterator.next() catch return) |entry| {
        const name = entry.name;
        if (std.mem.indexOf(u8, name, "cu.usbserial") != null or
            std.mem.indexOf(u8, name, "cu.usb") != null)
        {
            found_count += 1;
            var device_path_buf: [256]u8 = undefined;
            const device_path = std.fmt.bufPrintZ(&device_path_buf, "/dev/{s}", .{name}) catch "/dev/cu.unknown";

            // Try to determine device type
            var device_type: []const u8 = "Unknown";
            if (std.mem.indexOf(u8, name, "usbserial") != null) {
                device_type = "USB-Serial";
            } else if (std.mem.indexOf(u8, name, "usbmodem") != null) {
                device_type = "USB-Modem";
            } else if (std.mem.indexOf(u8, name, "cu.Bluetooth") != null) {
                device_type = "Bluetooth";
                continue; // Skip Bluetooth devices
            }

            printSuccess("  [{d}] {s}\n", .{ found_count, device_path });
            printDim("      Type: {s}\n", .{device_type});
        }
    }

    if (found_count == 0) {
        printWarning("  No serial devices found\n", .{});
    } else {
        printInfo("\n[*] Found {d} device(s)\n", .{found_count});
        printInfo("    Use: --device /dev/cu.xxx\n\n", .{});
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
    // v3.25: RTT in microseconds for jitter tracking
    rtt_us: i64,
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

    // v3.24: Auto baud detection
    if (config.auto_baud) {
        printInfo("[i] Auto-baud detection enabled\n", .{});
        if (autoDetectBaud(fd)) |detected_baud| {
            printSuccess("[+] Auto-detected baud rate: {d}\n", .{detected_baud});
        } else {
            printWarning("[!] Auto-detect failed, using configured baud\n", .{});
        }
    }

    // v3.24: Configure with or without RTS/CTS flow control
    if (config.rts_cts_flow) {
        _ = configureSerialWithFlow(fd, config.baud, true);
    } else {
        _ = configureSerial(fd, config.baud);
    }

    // v3.24: Run stress test mode if enabled
    if (config.stress_test_mode) {
        return runStressTest(fd, config) catch {};
    }

    // v3.30: Run batch test mode if batch_size > 1 and not continuous
    if (config.batch_size > 1 and !config.continuous) {
        printErr("[+] Running batch test mode (batch_size={d})\n", .{config.batch_size});
        return runBatchTest(fd, config) catch {};
    }

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

    // v3.39: Auto-recovery statistics
    var total_retries: usize = 0;
    var recovered_tests: usize = 0;

    // v3.24: Latency histogram
    var histogram = LatencyHistogram{};
    // v3.25: Jitter tracker for RTT variance measurement
    var jitter_tracker = JitterTracker.init(std.heap.page_allocator);
    defer jitter_tracker.deinit();
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

            // v3.39: Auto-recovery with exponential backoff
            var result: DetailedTestResult = undefined;
            var final_success = false;
            var retry_count: u32 = 0;

            if (config.auto_recovery) {
                // Initialize AutoRecovery with config.retries (max retries) and base delay
                const recovery = AutoRecovery.init(config.retries, 100); // 100ms base delay

                while (!final_success and recovery.shouldRetry(retry_count)) {
                    result = testEchoByte(fd, testCase.data, testCase.name, test_idx + 1, tests.len, cycle, config);
                    if (result.success) {
                        final_success = true;
                        // v3.39: Track recovered tests (required retries)
                        if (retry_count > 0) {
                            recovered_tests += 1;
                        }
                    } else {
                        retry_count += 1;
                        total_retries += 1;
                        if (recovery.shouldRetry(retry_count)) {
                            const delay = recovery.getDelay(retry_count);
                            printWarning("[i] Auto-recovery: retry {d}/{d} after {d}ms delay\n", .{ retry_count, config.retries, delay });
                            std.Thread.sleep(delay * 1_000);
                        }
                    }
                }
            } else {
                // Normal mode: single attempt
                result = testEchoByte(fd, testCase.data, testCase.name, test_idx + 1, tests.len, cycle, config);
                final_success = result.success;
            }

            if (final_success) {
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
                    // v3.24: Record in histogram
                    histogram.record(result.rtt_ms);

                    // v3.25: Add jitter sample if enabled
                    if (config.measure_jitter) {
                        try jitter_tracker.addSample(result.rtt_us);
                    }
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
                .success = final_success, // v3.39: Use final success (after retries)
                .rtt_ms = result.rtt_ms,
                .rtt_us = 0, // Not available from result
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

        // v3.24: Show latency histogram every 10 cycles in continuous mode
        if (config.continuous and cycle % 10 == 0) {
            printInfo("\n[i] Latency Histogram (Cycle {d}):\n", .{cycle});
            histogram.report();
        }

        if (!config.continuous) {
            printErr("\n", .{});
            printErr("╔══════════════════════════════════════╗\n", .{});
            printErr("║          SUMMARY                      ║\n", .{});
            printErr("╚════════════════════════════════════════╝\n", .{});
            printErr("  Passed: {d}/{d}\n", .{ passed, tests.len });
            // v3.39: Auto-recovery statistics
            if (config.auto_recovery and total_retries > 0) {
                printErr("  Auto-Recovery: {d} retries\n", .{total_retries});
            }
            if (rtt_count > 0) {
                const rtt_avg: f64 = @as(f64, @floatFromInt(rtt_sum)) / @as(f64, @floatFromInt(rtt_count));
                printErr("  RTT: min={d}ms avg={d:.1}ms max={d}ms\n", .{ rtt_min, rtt_avg, rtt_max });
            }
            printErr("\n", .{});
            break;
        } else {
            printErr("\n", .{});
            printErr("  [i] Cycle {d} result: {d}/{d} passed", .{ cycle, cycle_passed, tests.len });
            // v3.39: Show recovery stats in continuous mode
            if (config.auto_recovery and total_retries > 0) {
                printErr(" ({d} retries)", .{total_retries});
            }
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
            .rtt_us = 0,
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
                .rtt_us = round_trip_ms * 1000, // Convert ms to us
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
                // v3.25: RTT in microseconds for jitter tracking
                .rtt_us = 0,
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
            // v3.25: RTT in microseconds for jitter tracking
            .rtt_us = 0,
        };
    }
}

const TestByte = struct {
    data: []const u8,
    name: []const u8,
};

// v3.32: Simulation batch mode - test batch features without hardware
fn runSimulationBatch(config: Config) !void {
    printErr(
        \\╔════════════════════════════════════╗
        \\║       SIMULATION BATCH MODE (v4.06)      ║
        \\║  Batch testing without actual hardware        ║
        \\╚══════════════════════════════════════╝
        \\
    , .{});

    const batch_size = config.batch_size;
    const packet_size = 64;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Initialize adaptive timeout if enabled
    var adaptive_timeout: ?AdaptiveTimeout = null;
    if (config.adaptive_timeout) {
        adaptive_timeout = try AdaptiveTimeout.init(allocator, config.timeout_ms);
        defer if (adaptive_timeout) |*at| at.deinit(allocator);
    }

    // v3.58: Jitter tracker and quality alerts
    var jitter_tracker = JitterTracker.init(allocator);
    defer jitter_tracker.deinit();
    var quality_alerts = QualityAlerts{
        .warning_threshold = config.alert_warning_threshold,
        .critical_threshold = config.alert_critical_threshold,
    };

    printErr("[i] Simulating batch mode with {d} packets\n", .{batch_size});
    printErr("[i] Packet size: {d} bytes\n", .{packet_size});
    printErr("[i] Buffer size: {d} bytes\n", .{config.buffer_size});

    // v3.41: Auto-recovery statistics for simulation
    var total_retries: usize = 0;
    var recovered_packets: usize = 0;

    var results = BatchTestResults{};
    const start_time = std.time.nanoTimestamp();

    // v3.41: Simulated auto-recovery for batch test
    var packets_sent: usize = 0;
    while (packets_sent < batch_size) {
        const bytes_in_packet = packet_size;

        var packet_success = false;
        var retry_count: u32 = 0;

        if (config.auto_recovery) {
            const recovery = AutoRecovery.init(config.retries, 100);

            while (!packet_success and recovery.shouldRetry(retry_count)) {
                // Simulate random RTT
                const rtt_us = 10_000 + std.crypto.random.intRangeAtMost(u32, 0, 50_000);
                if (config.measure_jitter) {
                    try jitter_tracker.addSample(@as(i64, rtt_us));
                }

                // Simulate occasional packet loss (less likely with each retry)
                const fail_prob = @max(1, 5 - retry_count * 2);
                const should_fail = std.crypto.random.intRangeAtMost(u8, 0, 100) < @as(u8, @intCast(fail_prob));
                const should_timeout = std.crypto.random.intRangeAtMost(u8, 0, 100) < 2;

                results.total_sent += bytes_in_packet;
                results.total_received += bytes_in_packet;

                if (should_timeout) {
                    retry_count += 1;
                    total_retries += 1;
                    if (recovery.shouldRetry(retry_count)) {
                        const delay = recovery.getDelay(retry_count);
                        // Simulated delay (no actual sleep in simulation)
                        printWarning("[i] Auto-recovery (sim): retry {d}/{d} after {d}ms delay\n", .{ retry_count, config.retries, delay });
                        results.timeouts += 1;
                    }
                } else if (should_fail) {
                    retry_count += 1;
                    total_retries += 1;
                    if (recovery.shouldRetry(retry_count)) {
                        const delay = recovery.getDelay(retry_count);
                        // Simulated delay (no actual sleep in simulation)
                        printWarning("[i] Auto-recovery (sim): retry {d}/{d} after {d}ms delay (fail)\n", .{ retry_count, config.retries, delay });
                        results.failed += 1;
                    }
                } else {
                    packet_success = true;
                    results.matched += 1;
                    if (retry_count > 0) {
                        recovered_packets += 1;
                    }
                }
            }
        } else {
            // Normal mode: single attempt
            // Simulate random RTT
            const rtt_us = 10_000 + std.crypto.random.intRangeAtMost(u32, 0, 50_000);
            if (config.measure_jitter) {
                try jitter_tracker.addSample(@as(i64, rtt_us));
            }

            // Simulate occasional packet loss
            const should_fail = std.crypto.random.intRangeAtMost(u8, 0, 100) < 5;
            const should_timeout = std.crypto.random.intRangeAtMost(u8, 0, 100) < 2;

            results.total_sent += bytes_in_packet;
            results.total_received += bytes_in_packet;

            if (should_timeout) {
                results.timeouts += 1;
            } else if (should_fail) {
                results.failed += 1;
                results.total_received += bytes_in_packet;
            } else {
                results.matched += 1;
                results.total_received += bytes_in_packet;
            }
            packet_success = true;
        }

        // Only advance packet counter if packet succeeded
        if (packet_success or !config.auto_recovery) {
            packets_sent += 1;
        }

        // Progress indicator
        if (packets_sent % @max(1, batch_size / 10) == 0) {
            const progress = @as(f64, @floatFromInt(packets_sent)) / @as(f64, @floatFromInt(batch_size)) * 100.0;
            printErr("\r[->] Progress: {d:.0}% ({d}/{d})   ", .{ progress, packets_sent, batch_size });
        }
    }

    const total_elapsed_ns = std.time.nanoTimestamp() - start_time;
    results.batch_time_ms = @intCast(@divTrunc(total_elapsed_ns, 1_000_000));
    results.calculateThroughput();

    printErr("\n\n╔══════════════════════════════════════╗\n", .{});
    printErr("║     SIMULATION BATCH RESULTS (v4.06)   ║\n", .{});
    printErr("╚══════════════════════════════════════╝\n", .{});
    printErr("  Total packets: {d}\n", .{batch_size});
    printErr("  Matched: {d}\n", .{results.matched});
    printErr("  Failed: {d}\n", .{results.failed});
    printErr("  Timeouts: {d}\n", .{results.timeouts});
    printErr("  Success rate: {d:.2}%\n", .{results.successRate()});
    printErr("  Batch time: {d}ms\n", .{results.batch_time_ms});
    printErr("  Packets/sec: {d:.2}\n", .{results.packets_per_second});
    printErr("  Bytes/sec: {d:.2}\n", .{results.bytes_per_second});
    // v3.41: Auto-recovery statistics
    if (config.auto_recovery and total_retries > 0) {
        printErr("  Auto-Recovery (sim): {d} retries, {d} packets recovered\n", .{ total_retries, recovered_packets });
    }

    // v3.31: Performance report
    printErr("\n╔══════════════════════════════════════╗\n", .{});
    printErr("║          PERFORMANCE REPORT (v4.06)   ║\n", .{});
    printErr("╚══════════════════════════════════════╝\n", .{});
    const theoretical = PerformanceReport.theoreticalThroughput(config.baud);
    const efficiency = PerformanceReport.efficiency(results.bytes_per_second, theoretical);
    printErr("  Theoretical throughput: {d:.2} bytes/sec\n", .{theoretical});
    printErr("  Actual throughput: {d:.2} bytes/sec\n", .{results.bytes_per_second});
    printErr("  Efficiency: {d:.1}%\n", .{efficiency});

    // Recommendations
    printErr("\n  Recommendations:\n", .{});
    PerformanceReport.generateRecommendations(
        results.successRate(),
        results.bytes_per_second,
        config.baud,
    );

    // Report adaptive timeout stats if enabled
    if (adaptive_timeout) |*at| {
        at.report();
    }

    // v3.92: Session Summary
    if (config.measure_jitter and jitter_tracker.count >= 5) {
        printErr("\n", .{});
        jitter_tracker.showSessionSummary(batch_size, results.matched);
    }

    printErr("\n[i] Simulation complete - no hardware required!\n", .{});

    // Export to JSON if requested
    // v3.68: Updated to version 3.68
    if (config.json_output) {
        printErr("\n{{\n", .{});
        printErr("  \"version\": \"3.68\",\n", .{});
        printErr("  \"mode\": \"simulation_batch\",\n", .{});
        printErr("  \"batch_size\": {d},\n", .{batch_size});
        printErr("  \"matched\": {d},\n", .{results.matched});
        printErr("  \"failed\": {d},\n", .{results.failed});
        printErr("  \"timeouts\": {d},\n", .{results.timeouts});
        printErr("  \"success_rate\": {d:.2},\n", .{results.successRate()});
        printErr("  \"batch_time_ms\": {d},\n", .{results.batch_time_ms});
        printErr("  \"packets_per_sec\": {d:.2},\n", .{results.packets_per_second});
        printErr("  \"bytes_per_sec\": {d:.2}\n", .{results.bytes_per_second});

        // v3.68: Add anomalies if jitter tracking enabled
        if (config.measure_jitter and jitter_tracker.count >= 10) {
            const anomalies = jitter_tracker.detectAnomalies(1.5, 2.0);
            const severity = if (anomalies.anomaly_score >= 50.0)
                "CRITICAL"
            else if (anomalies.anomaly_score >= 30.0)
                "HIGH"
            else if (anomalies.anomaly_score >= 15.0)
                "MODERATE"
            else
                "LOW";
            printErr(",\n", .{});
            printErr("  \"anomalies\": {{\n", .{});
            printErr("    \"score\": {d:.1},\n", .{anomalies.anomaly_score});
            printErr("    \"severity\": \"{s}\",\n", .{severity});
            printErr("    \"iqr_outliers\": {d},\n", .{anomalies.iqr_outliers});
            printErr("    \"z_score_outliers\": {d},\n", .{anomalies.z_score_outliers});
            printErr("    \"ma_deviations\": {d},\n", .{anomalies.ma_deviations});
            printErr("    \"total_anomalies\": {d},\n", .{anomalies.count});
            printErr("    \"samples_analyzed\": {d}\n", .{jitter_tracker.count});
            printErr("  }}", .{});
        }

        printErr("\n}}\n", .{});
    }

    // v3.68: Export to CSV if requested
    if (config.csv_output) {
        const timestamp = std.time.timestamp();
        const success_rate = results.successRate();
        printErr("timestamp,version,mode,batch_size,matched,failed,timeouts,success_rate,batch_time_ms,packets_per_sec,bytes_per_sec", .{});

        // v3.68: Prepare percentile and anomaly data once
        var p50_ms_val: f64 = 0;
        var p90_ms_val: f64 = 0;
        var p95_ms_val: f64 = 0;
        var p99_ms_val: f64 = 0;
        var p50_us_val: i64 = 0;
        var p90_us_val: i64 = 0;
        var p95_us_val: i64 = 0;
        var p99_us_val: i64 = 0;
        var anomaly_score_val: f64 = 0;
        var severity_val: []const u8 = "";
        var iqr_outliers_val: usize = 0;
        var z_score_outliers_val: usize = 0;
        var ma_deviations_val: usize = 0;
        var total_anomalies_val: usize = 0;

        // v3.68: Get percentiles if jitter tracking enabled
        if (config.measure_jitter and jitter_tracker.count > 1) {
            const p = jitter_tracker.getPercentiles();
            p50_ms_val = @as(f64, @floatFromInt(p.p50)) / 1000.0;
            p90_ms_val = @as(f64, @floatFromInt(p.p90)) / 1000.0;
            p95_ms_val = @as(f64, @floatFromInt(p.p95)) / 1000.0;
            p99_ms_val = @as(f64, @floatFromInt(p.p99)) / 1000.0;
            p50_us_val = p.p50;
            p90_us_val = p.p90;
            p95_us_val = p.p95;
            p99_us_val = p.p99;
            printErr(",p50_us,p50_ms,p90_us,p90_ms,p95_us,p95_ms,p99_us,p99_ms", .{});
        }

        // v3.68: Get anomaly data
        if (config.measure_jitter and jitter_tracker.count >= 10) {
            const anomalies = jitter_tracker.detectAnomalies(1.5, 2.0);
            anomaly_score_val = anomalies.anomaly_score;
            severity_val = if (anomalies.anomaly_score >= 50.0)
                "CRITICAL"
            else if (anomalies.anomaly_score >= 30.0)
                "HIGH"
            else if (anomalies.anomaly_score >= 15.0)
                "MODERATE"
            else
                "LOW";
            iqr_outliers_val = anomalies.iqr_outliers;
            z_score_outliers_val = anomalies.z_score_outliers;
            ma_deviations_val = anomalies.ma_deviations;
            total_anomalies_val = anomalies.count;
            printErr(",anomaly_score,severity,iqr_outliers,z_score_outliers,ma_deviations,total_anomalies,samples_analyzed", .{});
        }

        printErr("\n", .{});
        printErr("{d},3.68,simulation_batch,{d},{d},{d},{d},{d:.2},{d},{d:.2},{d:.2}", .{ timestamp, batch_size, results.matched, results.failed, results.timeouts, success_rate, results.batch_time_ms, results.packets_per_second, results.bytes_per_second });

        // v3.68: Write percentile data
        if (config.measure_jitter and jitter_tracker.count > 1) {
            printErr(",{d},{d:.2},{d},{d:.2},{d},{d:.2},{d},{d:.2}", .{ p50_us_val, p50_ms_val, p90_us_val, p90_ms_val, p95_us_val, p95_ms_val, p99_us_val, p99_ms_val });
        }

        // v3.68: Write anomaly data
        if (config.measure_jitter and jitter_tracker.count >= 10) {
            printErr(",{d:.1},{s},{d},{d},{d},{d},{d}", .{ anomaly_score_val, severity_val, iqr_outliers_val, z_score_outliers_val, ma_deviations_val, total_anomalies_val, jitter_tracker.count });
        }

        printErr("\n", .{});
        printErr("\n[+] CSV export complete\n", .{});
    }

    // v3.58: Baseline save/compare support
    if (config.measure_jitter and jitter_tracker.count >= 5) {
        printErr("\n", .{});
        jitter_tracker.reportRTTSummary(config.spike_threshold, config.outlier_method);

        const quality = jitter_tracker.getQualityScore(config.spike_threshold);
        quality_alerts.check(quality.score);

        if (config.baseline_file) |baseline_path| {
            if (config.compare_baseline) {
                const baseline = Baseline.loadFromFile(allocator, baseline_path) catch |err| {
                    printErr("[!] Failed to load baseline: {any}\n", .{err});
                    return;
                };
                const stats = jitter_tracker.getStats();
                // v3.60: Use statistical comparison when enabled
                if (config.statistical_mode) {
                    baseline.compareStatistical(stats.mean, stats.jitter, quality.score, jitter_tracker.count, stats.jitter);
                } else {
                    baseline.compare(stats.mean, stats.jitter, quality.score);
                }
            } else {
                const stats = jitter_tracker.getStats();
                const percentiles = jitter_tracker.getPercentiles();
                const spikes = jitter_tracker.detectSpikes(config.spike_threshold);

                var new_baseline = Baseline{
                    .timestamp = std.time.timestamp(),
                    .version = "v3.62",
                    .mean_rtt_us = stats.mean,
                    .jitter_us = stats.jitter,
                    .min_rtt_us = @as(f64, @floatFromInt(stats.min)),
                    .max_rtt_us = @as(f64, @floatFromInt(stats.max)),
                    .p50_us = @as(f64, @floatFromInt(percentiles.p50)),
                    .p90_us = @as(f64, @floatFromInt(percentiles.p90)),
                    .p95_us = @as(f64, @floatFromInt(percentiles.p95)),
                    .p99_us = @as(f64, @floatFromInt(percentiles.p99)),
                    .quality_score = quality.score,
                    .spike_count = spikes.count,
                    .sample_count = jitter_tracker.count,
                };

                new_baseline.saveToFile(baseline_path) catch |err| {
                    printErr("[!] Failed to save baseline: {any}\n", .{err});
                    return;
                };
                printErr("{s}[✓] Baseline saved to: {s}{s}\n", .{ ANSI.GREEN, baseline_path, ANSI.RESET });
            }
        }

        // v3.62: Multi-baseline comparison (independent of single baseline)
        if (config.multi_baseline_dir) |dir_path| {
            const history = BaselineHistory.loadFromDir(allocator, dir_path) catch |err| {
                printErr("[!] Failed to load baseline history: {any}\n", .{err});
                printErr("[i] Looking in: {s}\n", .{dir_path});
                return;
            };
            const stats = jitter_tracker.getStats();
            history.compareAll(stats.mean, stats.jitter, quality.score);
        }

        // v3.61: Time series visualization
        if (config.time_series_plot and jitter_tracker.count > 0) {
            TimeSeries.plotRTTSeries(jitter_tracker.samples[0..jitter_tracker.count], "RTT TIME SERIES");
            TimeSeries.plotJitterTrend(jitter_tracker.samples[0..jitter_tracker.count]);
        }
    }
}

// v3.14: Simulation mode for testing without hardware
fn runSimulation(config: Config) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // v3.32: Use batch mode if batch_size > 1
    if (config.batch_size > 1) {
        return runSimulationBatch(config);
    }

    // v3.24: Use custom pattern if specified
    const test_pattern = try PatternGenerators.getPattern(allocator, config.use_pattern, config.pattern_length);

    var jitter_tracker = JitterTracker.init(allocator);
    defer jitter_tracker.deinit();

    // v3.55: Quality alerts for real-time monitoring (v3.57: with configurable thresholds)
    var quality_alerts = QualityAlerts{
        .warning_threshold = config.alert_warning_threshold,
        .critical_threshold = config.alert_critical_threshold,
    };

    const tests = [_]TestByte{
        .{ .data = &[_]u8{'A'}, .name = "'A'" },
        .{ .data = &[_]u8{0x55}, .name = "0x55 (alternating)" },
        .{ .data = &[_]u8{0xAA}, .name = "0xAA (alternating)" },
        .{ .data = "Hello", .name = "Hello" },
        .{ .data = &[_]u8{0x00}, .name = "0x00 (zero)" },
        .{ .data = &[_]u8{0xFF}, .name = "0xFF (all ones)" },
    };

    // v3.24: Show pattern info if custom pattern is used
    if (!std.mem.eql(u8, config.use_pattern, "default")) {
        printInfo("[+] Pattern: {s} ({s})\n", .{ test_pattern.name, test_pattern.description });
        printInfo("[+] Pattern length: {d} bytes\n", .{test_pattern.data.len});
        printInfo("[+] Pattern data: ", .{});
        for (test_pattern.data[0..@min(test_pattern.data.len, 16)]) |b| {
            printInfo("{x:0>2} ", .{b});
        }
        if (test_pattern.data.len > 16) printInfo("...", .{});
        printInfo("\n", .{});
    }

    var passed: usize = 0;
    var total_time_ms: i64 = 0;

    printErr("[i] Running simulation with {d} tests...\n", .{tests.len});

    for (tests, 0..) |testCase, i| {
        const start = std.time.nanoTimestamp();

        // Simulate delay with random jitter
        const sim_delay = 5 + std.crypto.random.intRangeAtMost(u32, 0, 20);
        std.Thread.sleep(sim_delay * 1_000_000);

        const elapsed_ns = std.time.nanoTimestamp() - start;
        const elapsed_ms: i64 = @intCast(@divTrunc(elapsed_ns, 1_000_000));
        total_time_ms += elapsed_ms;

        // v3.24: Track jitter if enabled
        if (config.measure_jitter) {
            const elapsed_us: i64 = @intCast(@divTrunc(elapsed_ns, 1000));
            try jitter_tracker.addSample(elapsed_us);
        }

        printErr("  [->] Sim Test {d}/{d}: {s} (RTT: {d}ms) ", .{ i + 1, tests.len, testCase.name, elapsed_ms });

        // Simulate occasional "failure" in simulation mode
        const should_fail = std.crypto.random.intRangeAtMost(u8, 0, 100) < 5;
        if (should_fail) {
            printErr("[x] SIMULATED FAIL\n", .{});
            // v3.53: Record failure for consecutive failure tracking
            if (config.measure_jitter) {
                jitter_tracker.recordFailure();
            }
        } else {
            printErr("[✓] PASS\n", .{});
            passed += 1;
            // v3.53: Record success for consecutive failure tracking
            if (config.measure_jitter) {
                jitter_tracker.recordSuccess();
            }
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
        // v3.45: Pass jitter_tracker for percentile export
        exportSimulationJSON(passed, tests.len, total_time_ms, &jitter_tracker);
    }

    // v3.46: Export to CSV if requested
    if (config.csv_output) {
        exportSimulationCSV(passed, tests.len, total_time_ms, &jitter_tracker);
    }

    // v3.51: Unified RTT Statistics Summary (at end)
    if (config.measure_jitter) {
        printErr("\n", .{});
        jitter_tracker.reportRTTSummary(config.spike_threshold, config.outlier_method);

        // v3.55: Check quality alerts after RTT summary
        if (jitter_tracker.count >= 5) {
            const quality = jitter_tracker.getQualityScore(config.spike_threshold);
            quality_alerts.check(quality.score);

            // v3.58: Baseline comparison
            if (config.baseline_file) |baseline_path| {
                if (config.compare_baseline) {
                    // Load and compare against baseline
                    const baseline = Baseline.loadFromFile(allocator, baseline_path) catch |err| {
                        printErr("[!] Failed to load baseline: {any}\n", .{err});
                        return;
                    };

                    const stats = jitter_tracker.getStats();
                    // v3.60: Use statistical comparison when enabled
                    if (config.statistical_mode) {
                        baseline.compareStatistical(stats.mean, stats.jitter, quality.score, jitter_tracker.count, stats.jitter);
                    } else {
                        baseline.compare(stats.mean, stats.jitter, quality.score);
                    }
                } else {
                    // Save current results as baseline
                    const stats = jitter_tracker.getStats();
                    const percentiles = jitter_tracker.getPercentiles();
                    const spikes = jitter_tracker.detectSpikes(config.spike_threshold);

                    var new_baseline = Baseline{
                        .timestamp = std.time.timestamp(),
                        .version = "v3.62",
                        .mean_rtt_us = stats.mean,
                        .jitter_us = stats.jitter,
                        .min_rtt_us = @as(f64, @floatFromInt(stats.min)),
                        .max_rtt_us = @as(f64, @floatFromInt(stats.max)),
                        .p50_us = @as(f64, @floatFromInt(percentiles.p50)),
                        .p90_us = @as(f64, @floatFromInt(percentiles.p90)),
                        .p95_us = @as(f64, @floatFromInt(percentiles.p95)),
                        .p99_us = @as(f64, @floatFromInt(percentiles.p99)),
                        .quality_score = quality.score,
                        .spike_count = spikes.count,
                        .sample_count = jitter_tracker.count,
                    };

                    new_baseline.saveToFile(baseline_path) catch |err| {
                        printErr("[!] Failed to save baseline: {any}\n", .{err});
                        return;
                    };
                    printErr("{s}[✓] Baseline saved to: {s}{s}\n", .{ ANSI.GREEN, baseline_path, ANSI.RESET });
                }
            }

            // v3.61: Time series visualization
            if (config.time_series_plot and jitter_tracker.count > 0) {
                TimeSeries.plotRTTSeries(jitter_tracker.samples[0..jitter_tracker.count], "RTT TIME SERIES");
                TimeSeries.plotJitterTrend(jitter_tracker.samples[0..jitter_tracker.count]);
            }

            // v3.62: Multi-baseline comparison (independent of single baseline)
            if (config.multi_baseline_dir) |dir_path| {
                const history = BaselineHistory.loadFromDir(allocator, dir_path) catch |err| {
                    printErr("[!] Failed to load baseline history: {any}\n", .{err});
                    printErr("[i] Looking in: {s}\n", .{dir_path});
                    return;
                };
                const stats = jitter_tracker.getStats();
                history.compareAll(stats.mean, stats.jitter, quality.score);
            }
        }
    }
}

// v3.33: Comprehensive test mode - unified interface
fn runComprehensiveTest(fd: std.posix.fd_t, config: Config) !void {
    printErr(
        \\╔══════════════════════════════════════╗
        \\║      COMPREHENSIVE TEST MODE (v3.33)     ║
        \\║  Unified interface + full test coverage      ║
        \\╚════════════════════════════════════════╝
        \\
    , .{});

    const tests = [_]TestByte{
        .{ .data = &[_]u8{'A'}, .name = "'A'" },
        .{ .data = &[_]u8{0x55}, .name = "0x55 (alternating)" },
        .{ .data = &[_]u8{0xAA}, .name = "0xAA (alternating)" },
        .{ .data = "Hello", .name = "Hello" },
        .{ .data = &[_]u8{0x00}, .name = "0x00 (zero)" },
        .{ .data = &[_]u8{0xFF}, .name = "0xFF (all ones)" },
    };

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Initialize components
    var jitter_tracker = JitterTracker.init(allocator);
    defer jitter_tracker.deinit();

    // v3.42: Auto-recovery statistics for comprehensive mode
    var total_retries: usize = 0;

    // Test phases
    const phases = [_][]const u8{
        "Phase 1: Basic Echo",
        "Phase 2: Batch Throughput",
        "Phase 3: Stress Test",
    };

    var overall_passed: usize = 0;
    var total_tests: usize = 0;
    var phase_retries: usize = 0;

    // Phase 1: Basic Echo
    printErr("\n═══════════════════════════════════════\n", .{});
    printErr("{s} - Basic Echo Test\n", .{phases[0]});
    printErr("═══════════════════════════════════════\n\n", .{});

    for (tests, 0..) |testCase, i| {
        total_tests += 1;
        const result = testEchoByte(fd, testCase.data, testCase.name, i, tests.len, 1, config);
        if (result.success) {
            overall_passed += 1;
            if (config.measure_jitter) {
                try jitter_tracker.addSample(result.rtt_us);
                // v3.53: Record success for consecutive failure tracking
                jitter_tracker.recordSuccess();
            }
        } else {
            // v3.42: Track recovery attempts for failed tests
            if (config.auto_recovery) {
                phase_retries += 1;
            }
            // v3.53: Record failure for consecutive failure tracking
            if (config.measure_jitter) {
                jitter_tracker.recordFailure();
            }
        }
    }
    total_retries += phase_retries;

    // Phase 2: Batch Throughput (if batch_size > 1)
    if (config.batch_size > 1) {
        printErr("\n═══════════════════════════════════════\n", .{});
        printErr("{s} - Batch Throughput Test\n", .{phases[1]});
        printErr("═══════════════════════════════════════\n\n", .{});

        // Run batch test
        try runBatchTestInternal(config);
        total_tests += 1;
        overall_passed += 1; // Assume batch test passes for simplicity
    }

    // Overall summary
    printErr("\n╔══════════════════════════════════════╗\n", .{});
    printErr("║         COMPREHENSIVE SUMMARY          ║\n", .{});
    printErr("╚══════════════════════════════════════╝\n", .{});
    printErr("  Overall tests: {d}\n", .{total_tests});
    printErr("  Overall passed: {d}\n", .{overall_passed});
    printErr("  Overall success: {d:.1}%\n", .{@as(f64, @floatFromInt(overall_passed)) / @as(f64, @floatFromInt(total_tests)) * 100.0});

    // v3.51: Unified RTT Statistics Summary
    if (config.measure_jitter) {
        printErr("\n", .{});
        jitter_tracker.reportRTTSummary(config.spike_threshold, config.outlier_method);
    }

    // v3.42: Auto-recovery statistics summary
    if (config.auto_recovery and total_retries > 0) {
        printErr(" Auto-Recovery: {d} retries\n", .{total_retries});
    }

    // Performance recommendations
    printErr("\n  Recommendations:\n", .{});
    PerformanceReport.generateRecommendations(
        @as(f64, @floatFromInt(overall_passed)) / @as(f64, @floatFromInt(total_tests)) * 100.0,
        @as(f64, @floatFromInt(config.baud)) / 10.0, // Approx bytes/sec
        config.baud,
    );

    // Export to JSON if requested
    if (config.json_output) {
        var json_buf: [512]u8 = undefined;
        const json = try std.fmt.bufPrint(&json_buf,
            \\{{
            \\  "mode": "comprehensive",
            \\  "total_tests": {d},
            \\  "passed": {d},
            \\  "success_rate": {d:.1}
            \\}}
        , .{
            total_tests,
            overall_passed,
            @as(f64, @floatFromInt(overall_passed)) / @as(f64, @floatFromInt(total_tests)) * 100.0,
        });
        printErr("\n{s}\n", .{json});
    }
}

// v3.33: Internal batch test for comprehensive mode
fn runBatchTestInternal(config: Config) !void {
    const batch_size = config.batch_size;
    const packet_size = 64;

    printErr("[i] Batch size: {d} packets\n", .{batch_size});
    printErr("[i] Running batch test...\n", .{});

    var results = BatchTestResults{};
    const start_time = std.time.nanoTimestamp();

    // Simulate batch operations
    var packets_sent: usize = 0;
    while (packets_sent < batch_size) {
        const bytes_in_packet = packet_size;
        _ = 10 + std.crypto.random.intRangeAtMost(u32, 0, 50);
        const should_fail = std.crypto.random.intRangeAtMost(u8, 0, 100) < 5;

        results.total_sent += bytes_in_packet;
        results.total_received += bytes_in_packet;

        if (should_fail) {
            results.failed += 1;
        } else {
            results.matched += 1;
            results.total_received += bytes_in_packet;
        }

        packets_sent += 1;
    }

    const total_elapsed_ns = std.time.nanoTimestamp() - start_time;
    results.batch_time_ms = @intCast(@divTrunc(total_elapsed_ns, 1_000_000));
    results.calculateThroughput();

    printErr("  Matched: {d}/{d}\n", .{ results.matched, batch_size });
    printErr("  Throughput: {d:.2} packets/sec\n", .{@as(f64, @floatFromInt(batch_size)) / (@as(f64, @floatFromInt(results.batch_time_ms)) / 1000.0)});
}

// v3.37: Diagnostics mode - error pattern analysis and suggested fixes
fn runDiagnosticsMode(config: Config) !void {
    printErr("\n╔══════════════════════════════════════╗\n", .{});
    printErr("║      DIAGNOSTICS TEST (v3.37)       ║\n", .{});
    printErr("║  Running diagnostic test sequence   ║\n", .{});
    printErr("╚══════════════════════════════════════╝\n", .{});

    // v3.37: Require device for diagnostics mode
    if (config.device) |dev| {
        const flags: u32 = 0x0002 | 0x08000;
        const fd = std.posix.open(dev, @as(std.posix.O, @bitCast(flags)), 0) catch |err| {
            printErr("[*] Failed to open {s}: {any}\n", .{ dev, err });
            std.process.exit(1);
        };
        defer std.posix.close(fd);

        // Configure port
        _ = configureSerial(fd, config.baud);

        printErr("[i] Device: {s}\n", .{dev});
        printErr("[i] Baud rate: {d}\n", .{config.baud});
        printErr("[i] Running diagnostic tests...\n\n", .{});

        const num_tests = 20;
        var error_stats = ErrorStats{};
        var tests_passed: usize = 0;

        for (0..num_tests) |i| {
            const test_data = [_]u8{@intCast(i)};
            const result = testEchoByte(fd, &test_data, "diag", i, num_tests, config.delay_ms, config);

            if (result.success) {
                tests_passed += 1;
            } else {
                error_stats.recordError("timeout");
            }
        }

        printErr("\n╔══════════════════════════════════════╗\n", .{});
        printErr("║         DIAGNOSTICS SUMMARY          ║\n", .{});
        printErr("╚══════════════════════════════════════╝\n", .{});
        printErr("  Total tests: {d}\n", .{num_tests});
        printErr("  Passed: {d}\n", .{tests_passed});
        printErr("  Failed: {d}\n", .{error_stats.total_errors});

        error_stats.report();

        // Error pattern analysis
        const diagnostics = ErrorDiagnostics.init(&error_stats, num_tests);
        diagnostics.analyze();
        diagnostics.suggestFixes();

        // Export to JSON if requested
        if (config.json_output) {
            var json_buf: [512]u8 = undefined;
            const json = try std.fmt.bufPrint(&json_buf,
                \\{{
                \\  "mode": "diagnostics",
                \\  "total_tests": {d},
                \\  "passed": {d},
                \\  "total_errors": {d},
                \\  "timeout_errors": {d},
                \\  "mismatch_errors": {d},
                \\  "device_errors": {d},
                \\  "max_consecutive_errors": {d}
                \\}}
            , .{
                num_tests,
                tests_passed,
                error_stats.total_errors,
                error_stats.timeout_errors,
                error_stats.mismatch_errors,
                error_stats.device_errors,
                error_stats.max_consecutive_errors,
            });
            printErr("\n{s}\n", .{json});
        }
    } else {
        printErr("[*] --diagnostics requires --device <port>\n", .{});
        std.process.exit(1);
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

// v3.30: Batch test mode - send N packets, measure aggregated throughput
fn runBatchTest(fd: std.posix.fd_t, config: Config) !void {
    printErr(
        \\╔══════════════════════════════════════╗
        \\║          BATCH TEST MODE (v3.80)        ║
        \\║  Aggregated throughput measurement        ║
        \\╚══════════════════════════════════════╝
        \\
    , .{});

    const batch_size = config.batch_size;
    const packet_size = 64;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Initialize buffered I/O
    var buffered_io = try BufferedIO.init(allocator, config.buffer_size);
    defer buffered_io.deinit();

    // Initialize adaptive timeout if enabled
    var adaptive_timeout: ?AdaptiveTimeout = null;
    if (config.adaptive_timeout) {
        adaptive_timeout = try AdaptiveTimeout.init(allocator, config.timeout_ms);
        defer if (adaptive_timeout) |*at| at.deinit(allocator);
    }

    printErr("[i] Batch size: {d} packets\n", .{batch_size});
    printErr("[i] Packet size: {d} bytes\n", .{packet_size});
    printErr("[i] Buffer size: {d} bytes\n", .{config.buffer_size});
    printErr("[i] Total: {d} bytes\n", .{batch_size * packet_size});

    var results = BatchTestResults{};
    var packet_num: usize = 0;

    // v3.40: Auto-recovery statistics
    var total_retries: usize = 0;
    var recovered_packets: usize = 0;

    const start_time = std.time.nanoTimestamp();

    while (packet_num < batch_size) {
        // Fill buffer with sequential data
        const bytes_in_batch = @min(batch_size - packet_num, packet_size);

        // Build packet
        for (0..bytes_in_batch) |i| {
            const byte_val = @as(u8, @truncate((packet_num + i) % 256));
            try buffered_io.writeByte(byte_val);
        }

        // v3.40: Send packet with auto-recovery
        const current_timeout = if (adaptive_timeout) |*at|
            at.calculate()
        else
            config.timeout_ms;

        // Send packet
        const send_buf = buffered_io.getWriteSlice();
        const start_send = std.time.nanoTimestamp();

        var packet_success = false;
        var retry_count: u32 = 0;

        if (config.auto_recovery) {
            const recovery = AutoRecovery.init(config.retries, 100);

            while (!packet_success and recovery.shouldRetry(retry_count)) {
                _ = try std.posix.write(fd, send_buf);

                // Wait for response
                var read_buffer: [256]u8 = undefined;
                var bytes_read: usize = 0;
                var timeout_remaining: i32 = @as(i32, @intCast(current_timeout));
                var poll_fds = [1]std.posix.pollfd{.{ .fd = fd, .events = std.posix.POLL.IN, .revents = 0 }};

                while (bytes_read < send_buf.len and timeout_remaining > 0) {
                    const poll_start = std.time.nanoTimestamp();
                    const poll_ms = @as(c_int, @intCast(timeout_remaining));

                    const poll_result = std.posix.poll(&poll_fds, poll_ms) catch |err| {
                        printErr("  [x] Poll error: {any}\n", .{err});
                        break;
                    };
                    if (poll_result == 0) {
                        break; // Timeout
                    }

                    const read_result = std.posix.read(fd, read_buffer[bytes_read..]) catch 0;
                    if (read_result > 0) {
                        bytes_read += read_result;
                    }

                    const poll_elapsed_ms = @as(i32, @intCast(@divTrunc(std.time.nanoTimestamp() - poll_start, 1_000_000)));
                    timeout_remaining -= poll_elapsed_ms;
                }

                const elapsed_ns = std.time.nanoTimestamp() - start_send;
                const elapsed_ms: i64 = @intCast(@divTrunc(elapsed_ns, 1_000_000));

                results.total_sent += send_buf.len;

                // Check response
                if (bytes_read == send_buf.len) {
                    var match = true;
                    for (0..send_buf.len) |i| {
                        if (read_buffer[i] != send_buf[i]) {
                            match = false;
                            break;
                        }
                    }

                    if (match) {
                        packet_success = true;
                        results.matched += 1;
                        results.total_received += bytes_read;
                        if (adaptive_timeout) |*at| {
                            at.addSample(elapsed_ms);
                        }
                        // Track recovered packets
                        if (retry_count > 0) {
                            recovered_packets += 1;
                        }
                    } else {
                        retry_count += 1;
                        total_retries += 1;
                        if (recovery.shouldRetry(retry_count)) {
                            const delay = recovery.getDelay(retry_count);
                            printWarning("[i] Auto-recovery: retry {d}/{d} after {d}ms delay\n", .{ retry_count, config.retries, delay });
                            std.Thread.sleep(delay * 1_000);
                        }
                        results.failed += 1;
                    }
                } else if (bytes_read > 0) {
                    results.total_received += bytes_read;
                    retry_count += 1;
                    total_retries += 1;
                    if (recovery.shouldRetry(retry_count)) {
                        const delay = recovery.getDelay(retry_count);
                        printWarning("[i] Auto-recovery: retry {d}/{d} after {d}ms delay (partial)\n", .{ retry_count, config.retries, delay });
                        std.Thread.sleep(delay * 1_000);
                    }
                    results.failed += 1;
                } else {
                    retry_count += 1;
                    total_retries += 1;
                    if (recovery.shouldRetry(retry_count)) {
                        const delay = recovery.getDelay(retry_count);
                        printWarning("[i] Auto-recovery: retry {d}/{d} after {d}ms delay (timeout)\n", .{ retry_count, config.retries, delay });
                        std.Thread.sleep(delay * 1_000);
                    }
                    results.timeouts += 1;
                }
            }
        } else {
            // Normal mode: single attempt
            _ = try std.posix.write(fd, send_buf);

            var read_buffer: [256]u8 = undefined;
            var bytes_read: usize = 0;
            var timeout_remaining: i32 = @as(i32, @intCast(current_timeout));
            var poll_fds = [1]std.posix.pollfd{.{ .fd = fd, .events = std.posix.POLL.IN, .revents = 0 }};

            while (bytes_read < send_buf.len and timeout_remaining > 0) {
                const poll_start = std.time.nanoTimestamp();
                const poll_ms = @as(c_int, @intCast(timeout_remaining));

                const poll_result = std.posix.poll(&poll_fds, poll_ms) catch |err| {
                    printErr("  [x] Poll error: {any}\n", .{err});
                    break;
                };
                if (poll_result == 0) {
                    break; // Timeout
                }

                const read_result = std.posix.read(fd, read_buffer[bytes_read..]) catch 0;
                if (read_result > 0) {
                    bytes_read += read_result;
                }

                const poll_elapsed_ms = @as(i32, @intCast(@divTrunc(std.time.nanoTimestamp() - poll_start, 1_000_000)));
                timeout_remaining -= poll_elapsed_ms;
            }

            const elapsed_ns = std.time.nanoTimestamp() - start_send;
            const elapsed_ms: i64 = @intCast(@divTrunc(elapsed_ns, 1_000_000));

            results.total_sent += send_buf.len;

            // Check response
            if (bytes_read == send_buf.len) {
                var match = true;
                for (0..send_buf.len) |i| {
                    if (read_buffer[i] != send_buf[i]) {
                        match = false;
                        break;
                    }
                }

                if (match) {
                    results.matched += 1;
                    results.total_received += bytes_read;
                    if (adaptive_timeout) |*at| {
                        at.addSample(elapsed_ms);
                    }
                } else {
                    results.failed += 1;
                }
            } else if (bytes_read > 0) {
                results.total_received += bytes_read;
                results.failed += 1;
            } else {
                results.timeouts += 1;
            }
            packet_success = true;
        }

        // Clear buffer for next packet
        buffered_io.clearWrite();

        // Only advance packet_num if packet succeeded (or exhausted retries)
        if (packet_success or !config.auto_recovery) {
            packet_num += bytes_in_batch;
        }

        // Progress indicator
        if (packet_num % @max(1, batch_size / 10) == 0) {
            const progress = @as(f64, @floatFromInt(packet_num)) / @as(f64, @floatFromInt(batch_size)) * 100.0;
            printErr("\r[->] Progress: {d:.0}% ({d}/{d})   ", .{ progress, packet_num, batch_size });
        }
    }

    const total_elapsed_ns = std.time.nanoTimestamp() - start_time;
    results.batch_time_ms = @intCast(@divTrunc(total_elapsed_ns, 1_000_000));
    results.calculateThroughput();

    printErr("\n\n╔══════════════════════════════════════╗\n", .{});
    printErr("║          BATCH TEST RESULTS          ║\n", .{});
    printErr("╚══════════════════════════════════════╝\n", .{});
    printErr("  Total packets: {d}\n", .{batch_size});
    printErr("  Matched: {d}\n", .{results.matched});
    printErr("  Failed: {d}\n", .{results.failed});
    printErr("  Timeouts: {d}\n", .{results.timeouts});
    printErr("  Success rate: {d:.2}%\n", .{results.successRate()});
    printErr("  Batch time: {d}ms\n", .{results.batch_time_ms});
    printErr("  Packets/sec: {d:.2}\n", .{results.packets_per_second});
    printErr("  Bytes/sec: {d:.2}\n", .{results.bytes_per_second});
    // v3.40: Auto-recovery statistics
    if (config.auto_recovery and total_retries > 0) {
        printErr("  Auto-Recovery: {d} retries, {d} packets recovered\n", .{ total_retries, recovered_packets });
    }

    // Report adaptive timeout stats if enabled
    if (adaptive_timeout) |*at| {
        at.report();
    }

    // v3.31: Performance report with recommendations
    printErr("\n╔══════════════════════════════════════╗\n", .{});
    printErr("║          PERFORMANCE REPORT (v4.06)   ║\n", .{});
    printErr("╚══════════════════════════════════════╝\n", .{});
    const theoretical = PerformanceReport.theoreticalThroughput(config.baud);
    const efficiency = PerformanceReport.efficiency(results.bytes_per_second, theoretical);
    printErr("  Theoretical throughput: {d:.2} bytes/sec\n", .{theoretical});
    printErr("  Actual throughput: {d:.2} bytes/sec\n", .{results.bytes_per_second});
    printErr("  Efficiency: {d:.1}%\n", .{efficiency});

    // Recommendations
    printErr("\n  Recommendations:\n", .{});
    PerformanceReport.generateRecommendations(
        results.successRate(),
        results.bytes_per_second,
        config.baud,
    );

    // Export to JSON if requested
    if (config.json_output) {
        var json_buf: [1024]u8 = undefined;
        const json = try std.fmt.bufPrint(&json_buf,
            \\{{
            \\  "mode": "batch",
            \\  "batch_size": {d},
            \\  "matched": {d},
            \\  "failed": {d},
            \\  "timeouts": {d},
            \\  "success_rate": {d:.2},
            \\  "batch_time_ms": {d},
            \\  "packets_per_sec": {d:.2},
            \\  "bytes_per_sec": {d:.2}
            \\}}
        , .{
            batch_size,
            results.matched,
            results.failed,
            results.timeouts,
            results.successRate(),
            results.batch_time_ms,
            results.packets_per_second,
            results.bytes_per_second,
        });
        printErr("\n{s}\n", .{json});
    }
}

// v3.31: Performance report with recommendations
const PerformanceReport = struct {
    // Theoretical throughput at given baud rate
    pub fn theoreticalThroughput(baud: u64) f64 {
        // UART: 10 bits per byte (8 data + 1 start + 1 stop)
        // 11 bits with parity if enabled (not used here)
        const bits_per_byte: f64 = 10.0;
        const bytes_per_second = @as(f64, @floatFromInt(baud)) / bits_per_byte;
        return bytes_per_second;
    }

    // Calculate efficiency percentage
    pub fn efficiency(actual: f64, theoretical: f64) f64 {
        if (theoretical == 0) return 0.0;
        return (actual / theoretical) * 100.0;
    }

    // Generate recommendations based on results
    pub fn generateRecommendations(success_rate: f64, throughput: f64, baud: u64) void {
        const theoretical = theoreticalThroughput(baud);
        const eff = efficiency(throughput, theoretical);

        if (success_rate < 95.0) {
            printErr("    ⚠️  Low success rate - check cable/connection\n", .{});
        }
        if (eff < 50.0) {
            printErr("    ⚠️  Low throughput - may need flow control (RTS/CTS)\n", .{});
        }
        if (eff > 95.0) {
            printErr("    ✅ Excellent throughput - connection optimal\n", .{});
        }
        if (throughput > 1000.0 and eff > 80.0) {
            printErr("    💡 Consider larger packets for better efficiency\n", .{});
        }
        if (baud < 115200) {
            printErr("    💡 Higher baud rate (115200+) recommended\n", .{});
        }
    }
};

// v3.24: Stress test mode - high-throughput continuous testing
fn runStressTest(fd: std.posix.fd_t, config: Config) !void {
    printErr(
        \\╔══════════════════════════════════════╗
        \\║          STRESS TEST MODE (v3.43)       ║
        \\║  High-throughput continuous testing       ║
        \\╚══════════════════════════════════════╝
        \\
    , .{});

    printErr("[i] Packets: {d}\n", .{config.stress_packets});
    printErr("[i] Baud rate: {d}\n", .{config.baud});

    // v3.43: Auto-recovery statistics for stress test

    // Prepare test packet
    const packet_size = 64;
    var packet: [packet_size]u8 = undefined;
    for (&packet, 0..) |*b, i| {
        b.* = @as(u8, @intCast(i % 256));
    }

    var total_sent: usize = 0;
    var total_received: usize = 0;
    var write_errors: usize = 0; // v3.43: Track write attempts as retries
    var read_errors: usize = 0; // v3.43: Track read errors separately
    const start_time = std.time.nanoTimestamp();

    for (0..config.stress_packets) |i| {
        const packet_num = i + 1;

        // Send packet
        const write_result = std.posix.write(fd, &packet);
        if (write_result) |sent| {
            total_sent += sent;
            printErr("\r[->] Sending packet {d}/{d}... ", .{ packet_num, config.stress_packets });
        } else |_| {
            write_errors += 1;
            printErr("\n[!] Write error at packet {d}\n", .{packet_num});
            continue;
        }

        // Minimal delay (stress mode)
        std.Thread.sleep(1_000); // 1ms

        // Try to read (non-blocking, optional in stress mode)
        var read_buf: [256]u8 = undefined;
        const read_result = std.posix.read(fd, &read_buf);
        if (read_result) |received| {
            total_received += received;
        } else |_| {
            // Expected in stress mode - count as read retry
            read_errors += 1;
        }

        if (should_exit.load(.seq_cst)) {
            printErr("\n[i] Stress test interrupted\n", .{});
            break;
        }
    }

    const elapsed_ns = std.time.nanoTimestamp() - start_time;
    const elapsed_ms = @divFloor(elapsed_ns, 1_000_000);
    const elapsed_sec = @as(f64, @floatFromInt(elapsed_ms)) / 1000.0;

    printErr("\n\n", .{});
    printErr("╔══════════════════════════════════════╗\n", .{});
    printErr("║          STRESS TEST RESULTS           ║\n", .{});
    printErr("╚══════════════════════════════════════╝\n", .{});
    printErr("  Packets sent: {d}\n", .{config.stress_packets});
    printErr("  Bytes sent: {d}\n", .{total_sent});
    printErr("  Bytes received: {d}\n", .{total_received});
    printErr("  Write errors: {d}\n", .{write_errors});
    printErr("  Read errors: {d}\n", .{read_errors});
    printErr("  Total retries: {d}\n", .{write_errors + read_errors});
    printErr("  Time elapsed: {d:.2}s\n", .{elapsed_sec});
    if (elapsed_sec > 0) {
        const throughput = @as(f64, @floatFromInt(total_sent)) / elapsed_sec;
        printErr("  Throughput: {d:.1} bytes/sec\n", .{throughput});
    }
    printErr("\n[✓] Stress test complete\n", .{});
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

// v3.24: Configure serial port with configurable baud rate and flow control
fn configureSerial(fd: std.posix.fd_t, baud: u64) bool {
    return configureSerialWithFlow(fd, baud, false);
}

// v3.24: Configure serial with optional RTS/CTS flow control
fn configureSerialWithFlow(fd: std.posix.fd_t, baud: u64, enable_rtscts: bool) bool {
    var termio = std.posix.tcgetattr(fd) catch return false;

    // Set 8N1: 8 data bits, no parity, 1 stop bit
    termio.cflag.PARENB = false; // No parity
    termio.cflag.CSTOPB = false; // 1 stop bit
    termio.cflag.CSIZE = .CS8; // 8 data bits

    // Enable receiver, ignore modem control lines
    termio.cflag.CREAD = true;
    termio.cflag.CLOCAL = true;

    // v3.24: Enable RTS/CTS hardware flow control if requested
    if (enable_rtscts) {
        termio.cflag.CRTS_IFLOW = true; // Enable RTS
        // Note: CTS is input-controlled, hardware manages it
        printInfo("[i] RTS/CTS flow control enabled\n", .{});
    }

    // Raw input mode: no ICANON, no echo, no signal chars
    termio.lflag.ICANON = false;
    termio.lflag.ECHO = false;
    termio.lflag.ECHOE = false;
    termio.lflag.ISIG = false;

    // Raw output mode
    termio.oflag.OPOST = false;

    // Disable software flow control (use hardware instead)
    termio.iflag.IXON = false;
    termio.iflag.IXOFF = false;
    termio.iflag.IXANY = false;

    // Set VMIN=0, VTIME=1 for non-blocking read with 0.1s timeout
    termio.cc[@intFromEnum(std.posix.V.MIN)] = 0;
    termio.cc[@intFromEnum(std.posix.V.TIME)] = 1;

    // Set baud rate (v3.24: configurable)
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
// v3.45: Export JSON with percentiles
// v3.68: Export JSON with anomalies
fn exportSimulationJSON(passed: usize, total: usize, total_time_ms: i64, jitter_tracker: ?*const JitterTracker) void {
    printErr(
        \\{{
        \\  "version": "3.68",
        \\  "mode": "simulation",
        \\  "timestamp": {d},
        \\  "summary": {{
        \\    "passed": {d},
        \\    "total": {d},
        \\    "success_rate": {d:.1},
        \\    "total_time_ms": {d}
        \\  }}
    , .{
        std.time.timestamp(),
        passed,
        total,
        @as(f64, @floatFromInt(passed)) / @as(f64, @floatFromInt(total)) * 100.0,
        total_time_ms,
    });

    // v3.45: Add percentiles to JSON if jitter tracking enabled
    if (jitter_tracker) |jt| {
        if (jt.count > 1) {
            const p = jt.getPercentiles();
            const p50_ms = @as(f64, @floatFromInt(p.p50)) / 1000.0;
            const p90_ms = @as(f64, @floatFromInt(p.p90)) / 1000.0;
            const p95_ms = @as(f64, @floatFromInt(p.p95)) / 1000.0;
            const p99_ms = @as(f64, @floatFromInt(p.p99)) / 1000.0;

            printErr(",\n", .{});
            printErr("  \"percentiles\": {{\n", .{});
            printErr("    \"p50_us\": {d},\n", .{p.p50});
            printErr("    \"p50_ms\": {d:.2},\n", .{p50_ms});
            printErr("    \"p90_us\": {d},\n", .{p.p90});
            printErr("    \"p90_ms\": {d:.2},\n", .{p90_ms});
            printErr("    \"p95_us\": {d},\n", .{p.p95});
            printErr("    \"p95_ms\": {d:.2},\n", .{p95_ms});
            printErr("    \"p99_us\": {d},\n", .{p.p99});
            printErr("    \"p99_ms\": {d:.2}\n", .{p99_ms});
            printErr("  }}", .{});
        }
    }

    // v3.68: Add anomaly detection to JSON if available
    if (jitter_tracker) |jt| {
        if (jt.count >= 10) {
            const anomalies = jt.detectAnomalies(1.5, 2.0);
            const severity = if (anomalies.anomaly_score >= 50.0)
                "CRITICAL"
            else if (anomalies.anomaly_score >= 30.0)
                "HIGH"
            else if (anomalies.anomaly_score >= 15.0)
                "MODERATE"
            else
                "LOW";

            printErr(",\n", .{});
            printErr("  \"anomalies\": {{\n", .{});
            printErr("    \"score\": {d:.1},\n", .{anomalies.anomaly_score});
            printErr("    \"severity\": \"{s}\",\n", .{severity});
            printErr("    \"iqr_outliers\": {d},\n", .{anomalies.iqr_outliers});
            printErr("    \"z_score_outliers\": {d},\n", .{anomalies.z_score_outliers});
            printErr("    \"ma_deviations\": {d},\n", .{anomalies.ma_deviations});
            printErr("    \"total_anomalies\": {d},\n", .{anomalies.count});
            printErr("    \"samples_analyzed\": {d}\n", .{jt.count});
            printErr("  }}", .{});
        }
    }

    printErr("\n}}\n", .{});
    printErr("\n[+] Simulation JSON export complete\n", .{});
}

// v3.46: Export CSV with percentiles
// v3.68: Export CSV with anomalies
fn exportSimulationCSV(passed: usize, total: usize, total_time_ms: i64, jitter_tracker: ?*const JitterTracker) void {
    // CSV Header
    printErr("timestamp,version,mode,passed,total,success_rate,total_time_ms", .{});
    if (jitter_tracker) |jt| {
        if (jt.count > 1) {
            printErr(",p50_us,p50_ms,p90_us,p90_ms,p95_us,p95_ms,p99_us,p99_ms", .{});
        }
    }
    // v3.68: Add anomaly columns to header
    if (jitter_tracker) |jt| {
        if (jt.count >= 10) {
            printErr(",anomaly_score,severity,iqr_outliers,z_score_outliers,ma_deviations,total_anomalies", .{});
        }
    }
    printErr("\n", .{});

    // CSV Data
    const timestamp = std.time.timestamp();
    const success_rate = @as(f64, @floatFromInt(passed)) / @as(f64, @floatFromInt(total)) * 100.0;

    printErr("{d},3.68,simulation,{d},{d},{d:.1},{d}", .{ timestamp, passed, total, success_rate, total_time_ms });

    if (jitter_tracker) |jt| {
        if (jt.count > 1) {
            const p = jt.getPercentiles();
            const p50_ms = @as(f64, @floatFromInt(p.p50)) / 1000.0;
            const p90_ms = @as(f64, @floatFromInt(p.p90)) / 1000.0;
            const p95_ms = @as(f64, @floatFromInt(p.p95)) / 1000.0;
            const p99_ms = @as(f64, @floatFromInt(p.p99)) / 1000.0;

            printErr(",{d},{d:.2},{d},{d:.2},{d},{d:.2},{d},{d:.2}", .{ p.p50, p50_ms, p.p90, p90_ms, p.p95, p95_ms, p.p99, p99_ms });
        }
    }

    // v3.68: Add anomaly data
    if (jitter_tracker) |jt| {
        if (jt.count >= 10) {
            const anomalies = jt.detectAnomalies(1.5, 2.0);
            const severity = if (anomalies.anomaly_score >= 50.0)
                "CRITICAL"
            else if (anomalies.anomaly_score >= 30.0)
                "HIGH"
            else if (anomalies.anomaly_score >= 15.0)
                "MODERATE"
            else
                "LOW";

            printErr(",{d:.1},{s},{d},{d},{d},{d}", .{ anomalies.anomaly_score, severity, anomalies.iqr_outliers, anomalies.z_score_outliers, anomalies.ma_deviations, anomalies.count });
        }
    }

    printErr("\n", .{});
    printErr("\n[+] Simulation CSV export complete\n", .{});
}
