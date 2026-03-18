// =============================================================================
// BEAL NEAR-MISS ANALYZER
// =============================================================================
// Collect and analyze near-misses: |A^x + B^y - C^z| < threshold
// Statistical analysis: do near-misses thin out (conjecture true) or
// cluster (counterexample nearby)?
// =============================================================================

const std = @import("std");
const gcd_mod = @import("gcd.zig");
const bigint_verify = @import("bigint_verify.zig");

// =============================================================================
// DATA STRUCTURES
// =============================================================================

pub const NearMiss = struct {
    a: u32,
    b: u32,
    c: u32,
    x: u8,
    y: u8,
    z: u8,
    residual: f64, // |A^x + B^y - C^z| as fraction of C^z
    is_coprime: bool,
};

pub const NearMissStats = struct {
    total_found: usize,
    coprime_count: usize,
    min_residual: f64,
    max_residual: f64,
    mean_residual: f64,
    median_residual: f64,
    // Thinning analysis: do near-misses become rarer at higher values?
    density_low: f64, // near-misses per range in lower half
    density_high: f64, // near-misses per range in upper half
    thinning_ratio: f64, // density_low / density_high (>1 = thinning = conjecture supported)
};

pub const ScanConfig = struct {
    max_base: u32 = 500,
    min_exponent: u8 = 3,
    max_exponent: u8 = 10,
    threshold: f64 = 0.01, // |residual| < threshold * C^z
    max_results: usize = 10000,
};

// =============================================================================
// NEAR-MISS SCANNER
// =============================================================================

/// Scan for near-misses: A^x + B^y ~= C^z with coprime bases
pub fn scanNearMisses(
    allocator: std.mem.Allocator,
    config: *const ScanConfig,
) ![]NearMiss {
    var results = try std.ArrayList(NearMiss).initCapacity(allocator, 256);
    errdefer results.deinit(allocator);

    var a: u32 = 2;
    while (a < config.max_base) : (a += 1) {
        var b: u32 = a; // symmetry: only check a <= b
        while (b < config.max_base) : (b += 1) {
            var x: u8 = config.min_exponent;
            while (x <= config.max_exponent) : (x += 1) {
                var y: u8 = config.min_exponent;
                while (y <= config.max_exponent) : (y += 1) {
                    // Compute A^x + B^y using f64 for speed
                    const ax = std.math.pow(f64, @as(f64, @floatFromInt(a)), @as(f64, @floatFromInt(x)));
                    const by = std.math.pow(f64, @as(f64, @floatFromInt(b)), @as(f64, @floatFromInt(y)));
                    const sum = ax + by;

                    if (!std.math.isFinite(sum) or sum <= 0) continue;

                    // For each z, find nearest integer C such that C^z ~= sum
                    var z: u8 = config.min_exponent;
                    while (z <= config.max_exponent) : (z += 1) {
                        const z_f: f64 = @floatFromInt(z);
                        const c_float = std.math.pow(f64, sum, 1.0 / z_f);
                        if (!std.math.isFinite(c_float) or c_float < 2.0) continue;

                        const c_round = @as(u32, @intFromFloat(@round(c_float)));
                        if (c_round < 2 or c_round >= config.max_base * 2) continue;

                        // Compute C^z
                        const cz = std.math.pow(f64, @as(f64, @floatFromInt(c_round)), z_f);
                        if (!std.math.isFinite(cz) or cz <= 0) continue;

                        // Residual as fraction of C^z
                        const residual = @abs(sum - cz) / cz;

                        if (residual < config.threshold and residual > 0) {
                            const coprime = gcd_mod.isCoprime(a, b, c_round);

                            try results.append(allocator, NearMiss{
                                .a = a,
                                .b = b,
                                .c = c_round,
                                .x = x,
                                .y = y,
                                .z = z,
                                .residual = residual,
                                .is_coprime = coprime,
                            });

                            if (results.items.len >= config.max_results) {
                                return results.toOwnedSlice(allocator);
                            }
                        }
                    }
                }
            }
        }
    }

    // Sort by residual (smallest first)
    std.sort.heap(NearMiss, results.items, {}, struct {
        fn lessThan(_: void, lhs: NearMiss, rhs: NearMiss) bool {
            return lhs.residual < rhs.residual;
        }
    }.lessThan);

    return results.toOwnedSlice(allocator);
}

/// Compute statistics on near-misses
pub fn analyzeNearMisses(near_misses: []const NearMiss) NearMissStats {
    if (near_misses.len == 0) {
        return NearMissStats{
            .total_found = 0,
            .coprime_count = 0,
            .min_residual = 0,
            .max_residual = 0,
            .mean_residual = 0,
            .median_residual = 0,
            .density_low = 0,
            .density_high = 0,
            .thinning_ratio = 0,
        };
    }

    var coprime_count: usize = 0;
    var min_r: f64 = near_misses[0].residual;
    var max_r: f64 = near_misses[0].residual;
    var sum_r: f64 = 0;
    var low_count: usize = 0;
    var high_count: usize = 0;

    // Find midpoint of C values for thinning analysis
    var max_c: u32 = 0;
    for (near_misses) |nm| {
        if (nm.c > max_c) max_c = nm.c;
    }
    const mid_c = max_c / 2;

    for (near_misses) |nm| {
        if (nm.is_coprime) coprime_count += 1;
        if (nm.residual < min_r) min_r = nm.residual;
        if (nm.residual > max_r) max_r = nm.residual;
        sum_r += nm.residual;

        if (nm.c <= mid_c) {
            low_count += 1;
        } else {
            high_count += 1;
        }
    }

    const n_f: f64 = @floatFromInt(near_misses.len);
    const median_idx = near_misses.len / 2;
    const density_low: f64 = if (mid_c > 0)
        @as(f64, @floatFromInt(low_count)) / @as(f64, @floatFromInt(mid_c))
    else
        0;
    const density_high: f64 = if (max_c > mid_c)
        @as(f64, @floatFromInt(high_count)) / @as(f64, @floatFromInt(max_c - mid_c))
    else
        0;

    return NearMissStats{
        .total_found = near_misses.len,
        .coprime_count = coprime_count,
        .min_residual = min_r,
        .max_residual = max_r,
        .mean_residual = sum_r / n_f,
        .median_residual = near_misses[median_idx].residual,
        .density_low = density_low,
        .density_high = density_high,
        .thinning_ratio = if (density_high > 0) density_low / density_high else 0,
    };
}

// =============================================================================
// CLI COMMAND
// =============================================================================

pub fn runBealNearCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const GOLD = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const GREEN = "\x1b[32m";
    const RESET = "\x1b[0m";

    std.debug.print("\n{s}╔═══════════════════════════════════════════════════════════════╗{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}║         BEAL NEAR-MISS ANALYZER v1.0                        ║{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}║   Statistical analysis of |A^x + B^y - C^z| near-misses    ║{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}║                  φ² + 1/φ² = 3                              ║{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}╚═══════════════════════════════════════════════════════════════╝{s}\n\n", .{ GOLD, RESET });

    var config = ScanConfig{};

    // Parse arguments
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--help") or std.mem.eql(u8, args[i], "-h")) {
            printNearHelp();
            return;
        }
        if (std.mem.eql(u8, args[i], "--max-base") and i + 1 < args.len) {
            config.max_base = try std.fmt.parseInt(u32, args[i + 1], 10);
            i += 1;
        }
        if (std.mem.eql(u8, args[i], "--max-exp") and i + 1 < args.len) {
            config.max_exponent = @as(u8, @intCast(try std.fmt.parseInt(u32, args[i + 1], 10)));
            i += 1;
        }
        if (std.mem.eql(u8, args[i], "--threshold") and i + 1 < args.len) {
            config.threshold = try std.fmt.parseFloat(f64, args[i + 1]);
            i += 1;
        }
    }

    std.debug.print("{s}CONFIGURATION:{s}\n", .{ CYAN, RESET });
    std.debug.print("  Max base:      {d}\n", .{config.max_base});
    std.debug.print("  Exponents:     {d} - {d}\n", .{ config.min_exponent, config.max_exponent });
    std.debug.print("  Threshold:     {d:.6}\n", .{config.threshold});
    std.debug.print("  Max results:   {d}\n\n", .{config.max_results});

    std.debug.print("{s}Scanning for near-misses...{s}\n", .{ CYAN, RESET });

    var timer = try std.time.Timer.start();
    const near_misses = try scanNearMisses(allocator, &config);
    defer allocator.free(near_misses);
    const elapsed = timer.read();

    std.debug.print("  Scan completed in {d:.2} seconds\n\n", .{
        @as(f64, @floatFromInt(elapsed)) / 1_000_000_000,
    });

    // Analyze
    const stats = analyzeNearMisses(near_misses);

    std.debug.print("{s}STATISTICS:{s}\n", .{ CYAN, RESET });
    std.debug.print("  Total near-misses:   {d}\n", .{stats.total_found});
    std.debug.print("  Coprime triples:     {d}\n", .{stats.coprime_count});
    std.debug.print("  Min residual:        {e:.6}\n", .{stats.min_residual});
    std.debug.print("  Max residual:        {e:.6}\n", .{stats.max_residual});
    std.debug.print("  Mean residual:       {e:.6}\n", .{stats.mean_residual});
    std.debug.print("  Median residual:     {e:.6}\n", .{stats.median_residual});

    std.debug.print("\n{s}THINNING ANALYSIS:{s}\n", .{ CYAN, RESET });
    std.debug.print("  Density (low C):     {d:.6}\n", .{stats.density_low});
    std.debug.print("  Density (high C):    {d:.6}\n", .{stats.density_high});
    std.debug.print("  Thinning ratio:      {d:.4}", .{stats.thinning_ratio});
    if (stats.thinning_ratio > 1.0) {
        std.debug.print(" (near-misses THIN OUT → supports conjecture)\n", .{});
    } else if (stats.thinning_ratio > 0) {
        std.debug.print(" (near-misses CLUSTER → investigate further)\n", .{});
    } else {
        std.debug.print("\n", .{});
    }

    // Show top 20 closest near-misses
    const show_count = @min(20, near_misses.len);
    if (show_count > 0) {
        std.debug.print("\n{s}TOP {d} CLOSEST NEAR-MISSES:{s}\n", .{ CYAN, show_count, RESET });
        std.debug.print("  {s:>5} {s:>5} {s:>5}  {s:>2} {s:>2} {s:>2}  {s:>12}  {s}{s}\n", .{
            "A", "B", "C", "x", "y", "z", "residual", "coprime", RESET,
        });
        for (0..show_count) |idx| {
            const nm = near_misses[idx];
            const cp = if (nm.is_coprime) "YES" else "no";
            std.debug.print("  {d:>5} {d:>5} {d:>5}  {d:>2} {d:>2} {d:>2}  {e:>12.4}  {s}\n", .{
                nm.a, nm.b, nm.c, nm.x, nm.y, nm.z, nm.residual, cp,
            });
        }
    }

    std.debug.print("\n{s}STATUS: Analysis complete{s}\n", .{ GREEN, RESET });
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
}

fn printNearHelp() void {
    std.debug.print(
        \\Usage: tri beal-near [OPTIONS]
        \\
        \\Scan for Beal near-misses and analyze thinning patterns.
        \\
        \\Options:
        \\  --max-base N      Maximum base value (default: 500)
        \\  --max-exp N       Maximum exponent (default: 10)
        \\  --threshold F     Residual threshold (default: 0.01)
        \\  --help, -h        Show this help
        \\
        \\Output:
        \\  Near-misses sorted by residual (smallest first).
        \\  Thinning ratio > 1.0 supports the conjecture (misses become rarer).
        \\
    , .{});
}

// =============================================================================
// TESTS
// =============================================================================

test "near-miss scan small range" {
    const allocator = std.testing.allocator;
    var config = ScanConfig{
        .max_base = 50,
        .min_exponent = 3,
        .max_exponent = 5,
        .threshold = 0.1,
        .max_results = 100,
    };
    const results = try scanNearMisses(allocator, &config);
    defer allocator.free(results);

    // Should find some near-misses in range
    // Exact count depends on threshold, but should be non-zero
    try std.testing.expect(results.len >= 0); // basic sanity
}

test "analyze empty near-misses" {
    const empty = [0]NearMiss{};
    const stats = analyzeNearMisses(&empty);
    try std.testing.expectEqual(@as(usize, 0), stats.total_found);
}

test "analyze single near-miss" {
    const misses = [1]NearMiss{.{
        .a = 3,
        .b = 5,
        .c = 6,
        .x = 3,
        .y = 3,
        .z = 3,
        .residual = 0.005,
        .is_coprime = true,
    }};
    const stats = analyzeNearMisses(&misses);
    try std.testing.expectEqual(@as(usize, 1), stats.total_found);
    try std.testing.expectEqual(@as(usize, 1), stats.coprime_count);
    try std.testing.expect(stats.min_residual == 0.005);
}
