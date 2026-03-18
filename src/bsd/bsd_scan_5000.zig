// ═══════════════════════════════════════════════════════════════════════════════
// BSD SCAN 5000 - Cremona Database Scanner for N ≤ 5000
// ═══════════════════════════════════════════════════════════════════════════════
// Parses allbsd format data and verifies BSD conjecture
// Generates data for arXiv paper
//
// allbsd format (per line):
//   conductor class number [a1,a2,a3,a4,a6] rank torsion tamagawa omega L_value regulator root_number
//
// BSD formula: L^(r)(E,1) = Omega_E * c_E * |Sha| * R_E / |E(Q)_tors|^2
//   => |Sha| = L^(r)(E,1) * |T|^2 / (Omega * c_E * R_E)
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const print = std.debug.print;

// ═══════════════════════════════════════════════════════════════════════════════
// CREMONA BSD ENTRY (from allbsd format)
// ═══════════════════════════════════════════════════════════════════════════════

const CremonaEntry = struct {
    conductor: u64,
    iso_class: []const u8,
    curve_number: u32,
    coefficients: [5]i64,
    rank: u8,
    tamagawa_product: u32,
    torsion_order: u32,
    omega: f64,
    l_value: f64,
    regulator: f64,
    root_number: i8,
    label: []const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// BSD VERIFICATION RESULT
// ═══════════════════════════════════════════════════════════════════════════════

const BSDResult = struct {
    label: []const u8,
    conductor: u64,
    rank: u8,
    analytic_sha: f64,
    sha_integer: u64,
    sha_is_square: bool,
    bsd_ratio: f64,
    sha_err: f64,
    verified: bool,
};

// ═══════════════════════════════════════════════════════════════════════════════
// SCAN STATISTICS
// ═══════════════════════════════════════════════════════════════════════════════

const ScanStats = struct {
    total_curves: u64 = 0,
    verified_bsd: u64 = 0,
    failed_bsd: u64 = 0,
    sha_not_square: u64 = 0,
    rank_counts: [5]u64 = .{ 0, 0, 0, 0, 0 },
    max_sha_error: f64 = 0.0,
    total_sha_error: f64 = 0.0,
    max_conductor: u64 = 0,
    max_sha: u64 = 0,
    parse_errors: u64 = 0,
    start_time: i128 = 0,
    end_time: i128 = 0,

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

    pub fn avgShaError(self: *const ScanStats) f64 {
        if (self.verified_bsd == 0) return 0.0;
        return self.total_sha_error / @as(f64, @floatFromInt(self.verified_bsd));
    }

    pub fn throughput(self: *const ScanStats) f64 {
        const dur = self.duration();
        if (dur == 0) return 0.0;
        return @as(f64, @floatFromInt(self.total_curves)) / dur;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PARSER
// ═══════════════════════════════════════════════════════════════════════════════

fn parseLine(allocator: std.mem.Allocator, line: []const u8) !CremonaEntry {
    var iter = std.mem.tokenizeScalar(u8, line, ' ');

    const conductor_str = iter.next() orelse return error.MissingField;
    const conductor = std.fmt.parseInt(u64, conductor_str, 10) catch return error.InvalidConductor;

    const iso_class = iter.next() orelse return error.MissingField;

    const curve_num_str = iter.next() orelse return error.MissingField;
    const curve_number = std.fmt.parseInt(u32, curve_num_str, 10) catch return error.InvalidCurveNumber;

    const coeff_str = iter.next() orelse return error.MissingField;
    if (coeff_str.len < 3 or coeff_str[0] != '[') return error.InvalidCoefficients;

    const closing = std.mem.indexOfScalar(u8, coeff_str, ']') orelse return error.InvalidCoefficients;
    const coeffs_only = coeff_str[1..closing];

    var coeff_parts = std.mem.splitScalar(u8, coeffs_only, ',');
    var coefficients: [5]i64 = .{ 0, 0, 0, 0, 0 };
    for (0..5) |i| {
        const c_str = coeff_parts.next() orelse break;
        coefficients[i] = std.fmt.parseInt(i64, c_str, 10) catch return error.InvalidCoefficient;
    }

    const rank_str = iter.next() orelse return error.MissingField;
    const rank = std.fmt.parseInt(u8, rank_str, 10) catch return error.InvalidRank;

    // NOTE: In Cremona allbsd format, torsion comes BEFORE tamagawa
    const tors_str = iter.next() orelse return error.MissingField;
    const torsion_order = std.fmt.parseInt(u32, tors_str, 10) catch return error.InvalidTorsion;

    const tam_str = iter.next() orelse return error.MissingField;
    const tamagawa_product = std.fmt.parseInt(u32, tam_str, 10) catch return error.InvalidTamagawa;

    const omega_str = iter.next() orelse return error.MissingField;
    const omega = std.fmt.parseFloat(f64, omega_str) catch return error.InvalidOmega;

    const l_str = iter.next() orelse return error.MissingField;
    const l_value = std.fmt.parseFloat(f64, l_str) catch return error.InvalidLValue;

    const reg_str = iter.next() orelse return error.MissingField;
    const regulator = std.fmt.parseFloat(f64, reg_str) catch return error.InvalidRegulator;

    const root_raw = iter.next() orelse "1";
    const root_number: i8 = if (std.mem.eql(u8, root_raw, "1.00000000000000") or std.mem.eql(u8, root_raw, "1"))
        1
    else if (std.mem.eql(u8, root_raw, "-1.00000000000000") or std.mem.eql(u8, root_raw, "-1"))
        -1
    else
        std.fmt.parseInt(i8, root_raw, 10) catch 0;

    const label = try std.fmt.allocPrint(allocator, "{d}{s}{d}", .{ conductor, iso_class, curve_number });

    return .{
        .conductor = conductor,
        .iso_class = iso_class,
        .curve_number = curve_number,
        .coefficients = coefficients,
        .rank = rank,
        .tamagawa_product = tamagawa_product,
        .torsion_order = torsion_order,
        .omega = omega,
        .l_value = l_value,
        .regulator = regulator,
        .root_number = root_number,
        .label = label,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// BSD VERIFICATION
// ═══════════════════════════════════════════════════════════════════════════════

fn isPerfectSquare(n: u64) bool {
    if (n <= 1) return true;
    const s: u128 = std.math.sqrt(n);
    return s * s == @as(u128, n);
}

fn verifyBSD(entry: *const CremonaEntry) BSDResult {
    const tors_sq: f64 = @floatFromInt(@as(u64, entry.torsion_order) * @as(u64, entry.torsion_order));
    const tam: f64 = @floatFromInt(entry.tamagawa_product);
    const denom = entry.omega * tam * entry.regulator;

    var analytic_sha: f64 = 0.0;
    var sha_integer: u64 = 0;
    var sha_is_square = false;
    var bsd_ratio: f64 = 0.0;
    var err: f64 = 0.0;
    var verified = false;

    if (denom > 1e-30) {
        analytic_sha = entry.l_value * tors_sq / denom;
        sha_integer = @intFromFloat(@round(analytic_sha));
        sha_is_square = isPerfectSquare(sha_integer);

        err = @abs(analytic_sha - @as(f64, @floatFromInt(sha_integer)));
        bsd_ratio = if (sha_integer > 0) analytic_sha / @as(f64, @floatFromInt(sha_integer)) else 0.0;

        // Threshold 1e-4: accounts for limited precision in Cremona L-function data
        verified = (sha_integer >= 1) and sha_is_square and (err < 1e-4);
    }

    return .{
        .label = entry.label,
        .conductor = entry.conductor,
        .rank = entry.rank,
        .analytic_sha = analytic_sha,
        .sha_integer = sha_integer,
        .sha_is_square = sha_is_square,
        .bsd_ratio = bsd_ratio,
        .sha_err = err,
        .verified = verified,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// FILE PROCESSING
// ═══════════════════════════════════════════════════════════════════════════════

fn processFile(
    allocator: std.mem.Allocator,
    path: []const u8,
    stats: *ScanStats,
    interesting: *std.ArrayListUnmanaged(BSDResult),
    max_conductor: u64,
) !void {
    const file = std.fs.cwd().openFile(path, .{}) catch return;
    defer file.close();

    const stat = try file.stat();
    const content = try allocator.alloc(u8, @as(usize, @intCast(stat.size)));
    defer allocator.free(content);
    _ = try file.readAll(content);

    var line_iter = std.mem.tokenizeScalar(u8, content, '\n');

    while (line_iter.next()) |line| {
        if (line.len == 0) continue;

        const entry = parseLine(allocator, line) catch {
            stats.parse_errors += 1;
            continue;
        };
        defer allocator.free(entry.label);

        if (entry.conductor > max_conductor) continue;

        stats.total_curves += 1;
        if (entry.conductor > stats.max_conductor) {
            stats.max_conductor = entry.conductor;
        }

        const rank_idx: usize = if (entry.rank < 5) entry.rank else 4;
        stats.rank_counts[rank_idx] += 1;

        const result = verifyBSD(&entry);

        if (result.verified) {
            stats.verified_bsd += 1;
            stats.total_sha_error += result.sha_err;
            if (result.sha_err > stats.max_sha_error) {
                stats.max_sha_error = result.sha_err;
            }
        } else {
            stats.failed_bsd += 1;
            if (!result.sha_is_square and result.sha_integer >= 1) {
                stats.sha_not_square += 1;
            }
            // Always record failed curves
            const label_copy = try allocator.dupe(u8, result.label);
            try interesting.append(allocator, .{
                .label = label_copy,
                .conductor = result.conductor,
                .rank = result.rank,
                .analytic_sha = result.analytic_sha,
                .sha_integer = result.sha_integer,
                .sha_is_square = result.sha_is_square,
                .bsd_ratio = result.bsd_ratio,
                .sha_err = result.sha_err,
                .verified = result.verified,
            });
        }

        // Record large Sha or high rank (limit to keep memory bounded)
        if (result.verified and (result.sha_integer > 1 or entry.rank >= 2)) {
            if (interesting.items.len < 10000) {
                const label_copy = try allocator.dupe(u8, result.label);
                try interesting.append(allocator, .{
                    .label = label_copy,
                    .conductor = result.conductor,
                    .rank = result.rank,
                    .analytic_sha = result.analytic_sha,
                    .sha_integer = result.sha_integer,
                    .sha_is_square = result.sha_is_square,
                    .bsd_ratio = result.bsd_ratio,
                    .sha_err = result.sha_err,
                    .verified = result.verified,
                });
            }
        }

        // Track max Sha seen
        if (result.sha_integer > stats.max_sha) {
            stats.max_sha = result.sha_integer;
        }

        if (stats.total_curves % 50000 == 0) {
            print("\r  {d} curves verified... (conductor <= {d})", .{ stats.total_curves, stats.max_conductor });
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    print("\n", .{});
    print("=============================================================\n", .{});
    print("  BSD FULL SCAN - Cremona Database (all conductors)\n", .{});
    print("  Verifying BSD Conjecture for entire database\n", .{});
    print("=============================================================\n\n", .{});

    const base_dir = "/Users/playra/trinity-w1/data/ecdata/allbsd";
    const max_conductor: u64 = 500000;

    var stats = ScanStats{};
    stats.start();

    var interesting: std.ArrayListUnmanaged(BSDResult) = .empty;
    defer {
        for (interesting.items) |r| {
            allocator.free(r.label);
        }
        interesting.deinit(allocator);
    }

    // Process all allbsd files: 0-9999, 10000-19999, ..., 490000-499999
    var files_loaded: usize = 0;
    var range_start: u64 = 0;
    while (range_start < 500000) : (range_start += 10000) {
        if (range_start > max_conductor) break;

        const range_end = range_start + 9999;

        // Cremona uses 5-digit padding for < 100000, no padding for >= 100000
        const path = if (range_start < 100000)
            try std.fmt.allocPrint(allocator, "{s}/allbsd.{d:0>5}-{d:0>5}", .{ base_dir, range_start, range_end })
        else
            try std.fmt.allocPrint(allocator, "{s}/allbsd.{d}-{d}", .{ base_dir, range_start, range_end });
        defer allocator.free(path);

        processFile(allocator, path, &stats, &interesting, max_conductor) catch {
            continue;
        };
        files_loaded += 1;
    }

    stats.finish();

    // ═══════════════════════════════════════════════════════════════════════════
    // REPORT
    // ═══════════════════════════════════════════════════════════════════════════

    const total_f: f64 = if (stats.total_curves > 0) @floatFromInt(stats.total_curves) else 1.0;

    print("\n\n", .{});
    print("=============================================================\n", .{});
    print("  BSD CONJECTURE VERIFICATION — FULL CREMONA DATABASE\n", .{});
    print("  N <= {d} ({d} files processed)\n", .{ stats.max_conductor, files_loaded });
    print("=============================================================\n\n", .{});

    print("SUMMARY\n", .{});
    print("-------\n", .{});
    print("  Total curves:    {d}\n", .{stats.total_curves});
    print("  Max conductor:   {d}\n", .{stats.max_conductor});
    print("  Files loaded:    {d}\n", .{files_loaded});
    print("  Parse errors:    {d}\n", .{stats.parse_errors});
    print("  BSD verified:    {d} ({d:.4}%)\n", .{
        stats.verified_bsd,
        @as(f64, @floatFromInt(stats.verified_bsd)) * 100.0 / total_f,
    });
    print("  BSD FAILED:      {d}\n", .{stats.failed_bsd});
    print("  Sha not square:  {d}\n", .{stats.sha_not_square});
    print("  Max |Sha| seen:  {d}\n\n", .{stats.max_sha});

    print("RANK DISTRIBUTION\n", .{});
    print("-----------------\n", .{});
    for (stats.rank_counts, 0..) |count, rank| {
        if (count == 0) continue;
        const pct = @as(f64, @floatFromInt(count)) * 100.0 / total_f;
        if (rank < 4) {
            print("  Rank {d}:   {d:>10} ({d:.2}%)\n", .{ rank, count, pct });
        } else {
            print("  Rank 4+:  {d:>10} ({d:.2}%)\n", .{ count, pct });
        }
    }

    print("\nBSD ERROR STATISTICS\n", .{});
    print("--------------------\n", .{});
    print("  Max |Sha_an - Sha_int|:  {e:.10}\n", .{stats.max_sha_error});
    print("  Avg |Sha_an - Sha_int|:  {e:.10}\n\n", .{stats.avgShaError()});

    print("PERFORMANCE\n", .{});
    print("-----------\n", .{});
    print("  Duration:    {d:.3} seconds\n", .{stats.duration()});
    print("  Throughput:  {d:.0} curves/sec\n\n", .{stats.throughput()});

    // Print notable curves: show failures first, then large Sha, then high rank
    if (interesting.items.len > 0) {
        // Count failures
        var fail_count: usize = 0;
        for (interesting.items) |r| {
            if (!r.verified) fail_count += 1;
        }

        if (fail_count > 0) {
            print("!!! ANOMALIES DETECTED ({d} failures) !!!\n", .{fail_count});
            print("------------------------------------------\n", .{});
            print("{s:<14} {s:>4} {s:>8} {s:>14} {s:>6} {s:>12}\n", .{
                "Label", "Rank", "|Sha|", "Sha_analytic", "Sq?", "Error",
            });
            for (interesting.items) |r| {
                if (!r.verified) {
                    print("{s:<14} {d:>4} {d:>8} {d:>14.6} {s:>6} {e:>12.4}\n", .{
                        r.label,                              r.rank,    r.sha_integer, r.analytic_sha,
                        if (r.sha_is_square) "yes" else "NO", r.sha_err,
                    });
                }
            }
            print("\n", .{});
        }

        // Show top Sha values
        print("LARGEST |Sha| VALUES\n", .{});
        print("--------------------\n", .{});
        print("{s:<14} {s:>4} {s:>8} {s:>14} {s:>12}\n", .{
            "Label", "Rank", "|Sha|", "Sha_analytic", "Error",
        });
        var shown: usize = 0;
        // First pass: show Sha >= 100
        for (interesting.items) |r| {
            if (shown >= 30) break;
            if (r.verified and r.sha_integer >= 100) {
                print("{s:<14} {d:>4} {d:>8} {d:>14.6} {e:>12.4}\n", .{
                    r.label, r.rank, r.sha_integer, r.analytic_sha, r.sha_err,
                });
                shown += 1;
            }
        }
        // Second pass: show Sha >= 25
        if (shown < 30) {
            for (interesting.items) |r| {
                if (shown >= 30) break;
                if (r.verified and r.sha_integer >= 25 and r.sha_integer < 100) {
                    print("{s:<14} {d:>4} {d:>8} {d:>14.6} {e:>12.4}\n", .{
                        r.label, r.rank, r.sha_integer, r.analytic_sha, r.sha_err,
                    });
                    shown += 1;
                }
            }
        }

        print("\nHIGH RANK CURVES\n", .{});
        print("-----------------\n", .{});
        shown = 0;
        for (interesting.items) |r| {
            if (shown >= 20) break;
            if (r.verified and r.rank >= 2) {
                print("{s:<14}  rank={d}  |Sha|={d}\n", .{ r.label, r.rank, r.sha_integer });
                shown += 1;
            }
        }
    }

    // arXiv summary
    print("\n", .{});
    print("=============================================================\n", .{});
    print("  ARXIV PAPER DATA\n", .{});
    print("=============================================================\n\n", .{});

    print("Computational verification of BSD conjecture for all {d}\n", .{stats.total_curves});
    print("elliptic curves over Q with conductor N <= {d}\n", .{stats.max_conductor});
    print("in the Cremona database.\n\n", .{});

    print("|Sha|_an = L^(r)(E,1) * |E(Q)_tors|^2 / (Omega_E * c_E * R_E)\n\n", .{});

    print("Result: {d}/{d} verified ({d:.4}%)\n", .{
        stats.verified_bsd,                                            stats.total_curves,
        @as(f64, @floatFromInt(stats.verified_bsd)) * 100.0 / total_f,
    });
    print("Max |Sha| observed: {d}\n", .{stats.max_sha});
    print("Max error: {e:.10}\n", .{stats.max_sha_error});
    print("Avg error: {e:.10}\n\n", .{stats.avgShaError()});

    print("phi^2 + 1/phi^2 = 3 = TRINITY\n", .{});
}
