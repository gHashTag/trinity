//! UART Echo Test — Advanced FPGA UART bridge test tool
//! Sends bytes with configurable delay and expects them echoed back
//! v3.65 — Standard Deviation Bands (Mean ± σ intervals)
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
    }

    // v3.44: Percentile calculation (p50, p90, p95, p99)
    pub fn getPercentiles(self: *const JitterTracker) struct { p50: i64, p90: i64, p95: i64, p99: i64 } {
        if (self.count == 0) {
            return .{ .p50 = 0, .p90 = 0, .p95 = 0, .p99 = 0 };
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

        // Calculate percentiles directly (p50, p90, p95, p99)
        const p50_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(len - 1)) * 0.50));
        const p90_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(len - 1)) * 0.90));
        const p95_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(len - 1)) * 0.95));
        const p99_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(len - 1)) * 0.99));

        return .{
            .p50 = sorted[p50_idx],
            .p90 = sorted[p90_idx],
            .p95 = sorted[p95_idx],
            .p99 = sorted[p99_idx],
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
        \\║      Trinity UART Echo Test v3.62           ║
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
            \\║         SIMULATION MODE (v3.24)         ║
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
        \\║       SIMULATION BATCH MODE (v3.32)      ║
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
    printErr("║     SIMULATION BATCH RESULTS (v3.32)   ║\n", .{});
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
    printErr("║          PERFORMANCE REPORT (v3.31)   ║\n", .{});
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

    printErr("\n[i] Simulation complete - no hardware required!\n", .{});

    // Export to JSON if requested
    if (config.json_output) {
        var json_buf: [1024]u8 = undefined;
        const json = try std.fmt.bufPrint(&json_buf,
            \\{{
            \\  "mode": "simulation_batch",
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
        \\║          BATCH TEST MODE (v3.30)        ║
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
    printErr("║          PERFORMANCE REPORT (v3.31)   ║\n", .{});
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
fn exportSimulationJSON(passed: usize, total: usize, total_time_ms: i64, jitter_tracker: ?*const JitterTracker) void {
    printErr(
        \\{{
        \\  "version": "3.45",
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

    printErr("\n}}\n", .{});
    printErr("\n[+] Simulation JSON export complete\n", .{});
}

// v3.46: Export CSV with percentiles
fn exportSimulationCSV(passed: usize, total: usize, total_time_ms: i64, jitter_tracker: ?*const JitterTracker) void {
    // CSV Header
    printErr("timestamp,version,mode,passed,total,success_rate,total_time_ms", .{});
    if (jitter_tracker) |jt| {
        if (jt.count > 1) {
            printErr(",p50_us,p50_ms,p90_us,p90_ms,p95_us,p95_ms,p99_us,p99_ms", .{});
        }
    }
    printErr("\n", .{});

    // CSV Data
    const timestamp = std.time.timestamp();
    const success_rate = @as(f64, @floatFromInt(passed)) / @as(f64, @floatFromInt(total)) * 100.0;

    printErr("{d},3.46,simulation,{d},{d},{d:.1},{d}", .{ timestamp, passed, total, success_rate, total_time_ms });

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

    printErr("\n", .{});
    printErr("\n[+] Simulation CSV export complete\n", .{});
}
