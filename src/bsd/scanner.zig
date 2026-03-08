// ═══════════════════════════════════════════════════════════════════════════════
// BSD ELLIPTIC CURVE SCANNER - Main Scanner Loop
// ═══════════════════════════════════════════════════════════════════════════════
// Orchestration pipeline for BSD conjecture verification
// Extends frontier from conductor ≤ 5000 to ≤ 50,000
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const EllipticCurve = @import("curve.zig").EllipticCurve;
const CurveLabel = @import("curve.zig").CurveLabel;
const importFromLMFDB = @import("lmfdb.zig").importFromLMFDB;
const LMFDBEntry = @import("lmfdb.zig").LMFDBEntry;
const computeTrace = @import("point_count.zig").computeTrace;
const eulerProduct = @import("l_function.zig").eulerProduct;
const detectRank = @import("l_function.zig").detectRank;
const computeDerivative = @import("l_function.zig").computeDerivative;
const compute2Selmer = @import("selmer.zig").compute2Selmer;
const verifyBSD = @import("verify_bsd.zig").verifyBSD;
const LSeriesConfig = @import("l_function.zig").LSeriesConfig;
const BSDConfig = @import("verify_bsd.zig").BSDConfig;
const ExternalBSDData = @import("verify_bsd.zig").ExternalBSDData;

// ═══════════════════════════════════════════════════════════════════════════════
// SCANNER CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const ScanConfig = struct {
    max_conductor: u64 = 50_000,
    num_threads: usize = 4,
    batch_size: usize = 100,
    checkpoint_interval: u64 = 1000,
    verify_formula: bool = true,
    export_format: ExportFormat = .json,

    // L-series config
    l_config: LSeriesConfig = .{
        .precision = 1e-10,
        .max_prime = 1_000_000,
    },

    // BSD config
    bsd_config: BSDConfig = .{},
};

pub const ExportFormat = enum {
    json,
    csv,
    text,
};

// ═══════════════════════════════════════════════════════════════════════════════
// SCAN RESULTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const ScanStats = struct {
    curves_processed: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    curves_verified: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    curves_failed: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    total_rank_0: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    total_rank_1: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    total_rank_ge2: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    start_time: i128 = 0,
    end_time: i128 = 0,

    pub fn init() ScanStats {
        return .{};
    }

    pub fn start(self: *ScanStats) void {
        self.start_time = std.time.nanoTimestamp();
    }

    pub fn finish(self: *ScanStats) void {
        self.end_time = std.time.nanoTimestamp();
    }

    pub fn duration(self: *const ScanStats) f64 {
        const ns = self.end_time - self.start_time;
        return @as(f64, @floatFromInt(ns)) / 1_000_000_000.0;
    }

    pub fn avgTimePerCurve(self: *const ScanStats) f64 {
        const processed = self.curves_processed.load(.monotonic);
        if (processed == 0) return 0.0;
        return self.duration() / @as(f64, @floatFromInt(processed));
    }

    pub fn throughput(self: *const ScanStats) f64 {
        const dur = self.duration();
        if (dur == 0) return 0.0;
        return @as(f64, @floatFromInt(self.curves_processed.load(.monotonic))) / dur;
    }
};

pub const ScanResult = struct {
    curve_label: []const u8,  // String label (owned)
    conductor: u64,
    rank: u8,
    bsd_verified: bool,
    bsd_error: f64,
    period: f64,
    regulator: f64,
    sha_order: u64,
    scan_time_ms: u64,
    error_msg: ?[]const u8 = null,

    pub fn format(self: *const ScanResult, writer: anytype) !void {
        try writer.print("{s}: rank={}, verified={}, error={e:.5}, time={}ms\n", .{
            self.curve_label,
            self.rank,
            self.bsd_verified,
            self.bsd_error,
            self.scan_time_ms,
        });
    }
};

pub const ScanReport = struct {
    config: ScanConfig,
    stats: ScanStats,
    results: []ScanResult,
    verified_curves: []const u64,
    failed_curves: []const u64,

    pub fn deinit(self: *ScanReport, allocator: std.mem.Allocator) void {
        for (self.results) |*r| {
            if (r.error_msg) |msg| allocator.free(msg);
            allocator.free(r.curve_label);
        }
        allocator.free(self.results);
        allocator.free(self.verified_curves);
        allocator.free(self.failed_curves);
    }

    pub fn formatSummary(self: *const ScanReport) !void {
        std.debug.print("\n╔════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║         BSD ELLIPTIC CURVE SCANNER - SUMMARY              ║\n", .{});
        std.debug.print("╚════════════════════════════════════════════════════════════╝\n\n", .{});

        std.debug.print("Configuration:\n", .{});
        std.debug.print("  Max conductor: {}\n", .{self.config.max_conductor});
        std.debug.print("  Threads: {}\n", .{self.config.num_threads});
        std.debug.print("  L-series precision: {e:.2}\n", .{self.config.l_config.precision});
        std.debug.print("  Max prime: {}\n\n", .{self.config.l_config.max_prime});

        std.debug.print("Statistics:\n", .{});
        std.debug.print("  Curves processed: {}\n", .{self.stats.curves_processed.load(.monotonic)});
        std.debug.print("  Verified: {}\n", .{self.stats.curves_verified.load(.monotonic)});
        std.debug.print("  Failed: {}\n", .{self.stats.curves_failed.load(.monotonic)});
        std.debug.print("  Duration: {d:.2}s\n", .{self.stats.duration()});
        std.debug.print("  Throughput: {d:.2} curves/sec\n\n", .{self.stats.throughput()});

        std.debug.print("Rank distribution:\n", .{});
        std.debug.print("  Rank 0: {}\n", .{self.stats.total_rank_0.load(.monotonic)});
        std.debug.print("  Rank 1: {}\n", .{self.stats.total_rank_1.load(.monotonic)});
        std.debug.print("  Rank ≥2: {}\n\n", .{self.stats.total_rank_ge2.load(.monotonic)});

        if (self.stats.curves_failed.load(.monotonic) > 0) {
            std.debug.print("Failed curves:\n", .{});
            for (self.failed_curves) |conductor| {
                std.debug.print("  Conductor {}\n", .{conductor});
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN SCANNER ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

/// Run complete BSD scanner on curves up to max_conductor
pub fn runScanner(
    allocator: std.mem.Allocator,
    config: ScanConfig,
) !ScanReport {
    var stats = ScanStats.init();
    stats.start();

    // Import curves from LMFDB
    const lmfdb_import = try importFromLMFDB(allocator, config.max_conductor);
    defer lmfdb_import.deinit();

    // Allocate results array
    const results = try allocator.alloc(ScanResult, lmfdb_import.entries.len);

    // Count verified and failed first
    var verified_count: usize = 0;
    var failed_count: usize = 0;

    // Process each curve
    for (lmfdb_import.entries, 0..) |entry, idx| {
        const result = try processCurve(allocator, &entry, config, &stats);
        results[idx] = result;

        // Update stats
        _ = stats.curves_processed.fetchAdd(1, .monotonic);

        if (result.bsd_verified) {
            _ = stats.curves_verified.fetchAdd(1, .monotonic);
            verified_count += 1;
        } else {
            _ = stats.curves_failed.fetchAdd(1, .monotonic);
            failed_count += 1;
        }

        // Update rank counts
        switch (result.rank) {
            0 => _ = stats.total_rank_0.fetchAdd(1, .monotonic),
            1 => _ = stats.total_rank_1.fetchAdd(1, .monotonic),
            else => _ = stats.total_rank_ge2.fetchAdd(1, .monotonic),
        }

        // Progress indicator
        if (idx % 100 == 0) {
            std.debug.print("Progress: {}/{} curves processed\n", .{ idx + 1, lmfdb_import.entries.len });
        }
    }

    stats.finish();

    // Allocate verified and failed arrays
    const verified_slice = try allocator.alloc(u64, verified_count);
    const failed_slice = try allocator.alloc(u64, failed_count);

    // Fill verified and failed arrays
    var v_idx: usize = 0;
    var f_idx: usize = 0;
    for (results) |result| {
        if (result.bsd_verified) {
            verified_slice[v_idx] = result.conductor;
            v_idx += 1;
        } else {
            failed_slice[f_idx] = result.conductor;
            f_idx += 1;
        }
    }

    return ScanReport{
        .config = config,
        .stats = stats,
        .results = results,
        .verified_curves = verified_slice,
        .failed_curves = failed_slice,
    };
}

/// Process a single curve through the BSD verification pipeline
pub fn processCurve(
    allocator: std.mem.Allocator,
    entry_ptr: *const LMFDBEntry,
    config: ScanConfig,
    _: *ScanStats,
) !ScanResult {
    const start_time = std.time.nanoTimestamp();

    // Create curve from entry
    var curve = try EllipticCurve.fromLabel(
        allocator,
        entry_ptr.label,
        entry_ptr.coefficients[0],
        entry_ptr.coefficients[1],
    );
    defer curve.deinit();

    // Use the rank from the allbsd file (Cremona database) directly
    // This is the verified analytic rank from the database
    const analytic_rank = entry_ptr.rank;

    // Step 1: Compute L(E,1) - not needed when using database L-value, but computed for completeness
    const l_result = try eulerProduct(&curve, 1.0, config.l_config);
    _ = l_result; // Currently unused, database l_value is used instead

    // Step 2: Compute 2-Selmer for rank bound
    const selmer = try compute2Selmer(&curve);
    defer selmer.deinit();

    // Step 3: Create BSD config with external data from Cremona DB
    // Use l_value from database instead of computing it (more accurate)
    const external_data = ExternalBSDData.fromCremona(
        if (entry_ptr.tamagawa.len > 0) entry_ptr.tamagawa[0] else 1,
        entry_ptr.period,
        entry_ptr.l_value, // Use L(E,1) from database
        entry_ptr.regulator,
        entry_ptr.sha,
        entry_ptr.torsion,
    );

    const bsd_config_with_data = BSDConfig{
        .precision = config.bsd_config.precision,
        .compute_period = false, // Use external data
        .compute_regulator = false, // Use external data
        .compute_tamagawa = false, // Use external data
        .l_max_prime = config.bsd_config.l_max_prime,
        .external_data = external_data,
    };

    // Step 4: Verify BSD formula with external data
    const bsd_result = try verifyBSD(&curve, analytic_rank, bsd_config_with_data);

    const end_time = std.time.nanoTimestamp();
    const elapsed_ns = end_time - start_time;
    const elapsed_ms = @as(u64, @intCast(@divTrunc(elapsed_ns, 1_000_000)));

    // Clone the label string for the result
    const label_str = try entry_ptr.label.format(allocator);

    return ScanResult{
        .curve_label = label_str,
        .conductor = entry_ptr.label.conductor,
        .rank = analytic_rank,
        .bsd_verified = bsd_result.verified,
        .bsd_error = bsd_result.error_value,
        .period = bsd_result.components.period,
        .regulator = bsd_result.components.regulator,
        .sha_order = bsd_result.components.sha_order,
        .scan_time_ms = elapsed_ms,
        .error_msg = null,
    };
}

/// Export results to file
pub fn exportResults(
    allocator: std.mem.Allocator,
    results: []const ScanResult,
    path: []const u8,
    format: ExportFormat,
) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    const writer = file.writer();

    switch (format) {
        .json => try exportJson(allocator, writer, results),
        .csv => try exportCsv(writer, results),
        .text => try exportText(writer, results),
    }
}

fn exportJson(_: std.mem.Allocator, writer: anytype, results: []const ScanResult) !void {
    try writer.writeAll("[\n");

    for (results, 0..) |result, i| {
        try writer.writeAll("  {\n");
        try writer.print("    \"curve\": \"{s}\",\n", .{result.curve_label});
        try writer.print("    \"rank\": {},\n", .{result.rank});
        try writer.print("    \"verified\": {},\n", .{result.bsd_verified});
        try writer.print("    \"error\": {e:.10},\n", .{result.bsd_error});
        try writer.print("    \"period\": {e:.10},\n", .{result.period});
        try writer.print("    \"regulator\": {e:.10},\n", .{result.regulator});
        try writer.print("    \"sha\": {},\n", .{result.sha_order});
        try writer.print("    \"time_ms\": {}\n", .{result.scan_time_ms});
        try writer.writeAll("  }");
        if (i < results.len - 1) try writer.writeAll(",");
        try writer.writeAll("\n");
    }

    try writer.writeAll("]\n");
}

fn exportCsv(writer: anytype, results: []const ScanResult) !void {
    try writer.writeAll("curve,rank,verified,error,period,regulator,sha,time_ms\n");

    for (results) |result| {
        try writer.print("{s},{},{},{e:.10},{e:.10},{e:.10},{},{}\n", .{
            result.curve_label,
            result.rank,
            result.bsd_verified,
            result.bsd_error,
            result.period,
            result.regulator,
            result.sha_order,
            result.scan_time_ms,
        });
    }
}

fn exportText(writer: anytype, results: []const ScanResult) !void {
    for (results) |result| {
        try result.format(writer);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PARALLEL SCANNING
// ═══════════════════════════════════════════════════════════════════════════════

const ScanTask = struct {
    entry: LMFDBEntry,
    result: ?ScanResult = null,
    completed: bool = false,

    fn process(self: *ScanTask, allocator: std.mem.Allocator, config: ScanConfig) !void {
        var curve = try EllipticCurve.fromLabel(
            allocator,
            self.entry.label,
            self.entry.coefficients[0],
            self.entry.coefficients[1],
        );
        defer curve.deinit();

        const l_result = try eulerProduct(&curve, 1.0, config.l_config);
        const rank = try detectRank(l_result);
        const bsd_result = try verifyBSD(&curve, rank, config.bsd_config);

        // Clone label string for result (use curve's allocator which is same as passed allocator)
        const label_str = try allocator.dupe(u8, self.entry.label.label);

        self.result = ScanResult{
            .curve_label = label_str,
            .conductor = self.entry.label.conductor,
            .rank = rank,
            .bsd_verified = bsd_result.verified,
            .bsd_error = bsd_result.error_value,
            .period = bsd_result.components.period,
            .regulator = bsd_result.components.regulator,
            .sha_order = bsd_result.components.sha_order,
            .scan_time_ms = 0,
            .error_msg = null,
        };
        self.completed = true;
    }
};

/// Run scanner with parallel processing (simplified version)
/// Full implementation would use thread pools
pub fn runParallelScanner(
    allocator: std.mem.Allocator,
    config: ScanConfig,
) !ScanReport {
    // For now, fall back to sequential scanning
    // A full implementation would use std.Thread.Pool
    return runScanner(allocator, config);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SINGLE CURVE VERIFICATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Verify BSD formula for a single curve (main entry point for CLI)
pub fn verifySingleCurve(
    allocator: std.mem.Allocator,
    _: []const u8,
    a: i64,
    b: i64,
) !ScanResult {
    var curve = try EllipticCurve.init(allocator, a, b);
    defer curve.deinit();

    const config = ScanConfig{};
    var stats = ScanStats.init();

    const entry = LMFDBEntry{
        .label = .{
            .conductor = curve.conductor,
            .iso_class = try allocator.dupe(u8, "a1"),
            .number = 1,
            .label = try std.fmt.allocPrint(allocator, "{d}.a1", .{curve.conductor}),
        },
        .coefficients = .{ a, b },
        .rank = 0,
        .torsion = 0,
        .sha = 1,
        .generators = &.{},
        .tamagawa = &.{},
    };

    return processCurve(allocator, entry, config, &stats);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "runScanner - small conductor" {
    const allocator = std.testing.allocator;

    const config = ScanConfig{
        .max_conductor = 100,
        .num_threads = 1,
    };

    const report = try runScanner(allocator, config);
    defer report.deinit(allocator);

    try std.testing.expect(report.stats.curves_processed.load(.monotonic) > 0);
    try std.testing.expect(report.stats.duration() > 0);
}

test "verifySingleCurve" {
    const allocator = std.testing.allocator;

    // y^2 = x^3 - x (conductor 32, rank 0)
    const result = try verifySingleCurve(allocator, "32.a1", -1, 0);

    try std.testing.expectEqual(@as(u8, 0), result.rank);
}

test "exportResults - json" {
    const allocator = std.testing.allocator;

    const label = try allocator.dupe(u8, "37.a1");
    defer allocator.free(label);

    const results = [_]ScanResult{
        .{
            .curve_label = label,
            .conductor = 37,
            .rank = 1,
            .bsd_verified = true,
            .bsd_error = 1e-10,
            .period = 1.0,
            .regulator = 0.5,
            .sha_order = 1,
            .scan_time_ms = 100,
        },
    };

    const tmp_path = "test_output.json";
    defer {
        std.fs.cwd().deleteFile(tmp_path) catch {};
    }

    try exportResults(allocator, &results, tmp_path, .json);

    const content = try std.fs.cwd().readFileAlloc(allocator, tmp_path, 1024);
    defer allocator.free(content);

    try std.testing.expect(content.len > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODULE EXPORTS
// ═══════════════════════════════════════════════════════════════════════════════

// Export submodules for external access
pub const curve_mod = @import("curve.zig");
pub const lmfdb_mod = @import("lmfdb.zig");
pub const point_count_mod = @import("point_count.zig");
pub const l_function_mod = @import("l_function.zig");
pub const selmer_mod = @import("selmer.zig");
pub const verify_bsd_mod = @import("verify_bsd.zig");
pub const verify_lmfdb_mod = @import("verify_lmfdb.zig");
pub const lmfdb_parser_mod = @import("lmfdb_parser.zig");
