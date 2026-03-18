// ═══════════════════════════════════════════════════════════════════════════════
// PALANTIR PIPELINE — Stage 5: DETECT
// 5 Parallel Pattern Detectors: Period, Quasi-Period, Bounded PQ, Liouville,
//                             Fibonacci Embedding (φ-structure after division)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const DetectorType = enum {
    period_finder,
    quasi_period,
    bounded_pq,
    liouville,
    fibonacci_embedding,
};

pub const DetectionResult = struct {
    detector: DetectorType,
    detected: bool,
    confidence: f64,
    details: []const u8,
    pattern_start: ?usize,
    pattern_length: ?usize,
};

pub const DetectResult = struct {
    target_id: []const u8,
    target_value: f64,
    detections: [5]DetectionResult,
    summary: []const u8,
};

/// Detector 1: Period Finder
/// Detects exact repetition in CF expansion
fn detectPeriod(partials: []const u64) DetectionResult {
    if (partials.len < 6) {
        return .{
            .detector = .period_finder,
            .detected = false,
            .confidence = 0.0,
            .details = "Insufficient data",
            .pattern_start = null,
            .pattern_length = null,
        };
    }

    // Check for period 1 (all 1s)
    var all_ones = true;
    for (partials) |p| {
        if (p != 1) {
            all_ones = false;
            break;
        }
    }
    if (all_ones) {
        return .{
            .detector = .period_finder,
            .detected = true,
            .confidence = 1.0,
            .details = "Pure period 1: [1;1,1,1,...] (φ-type)",
            .pattern_start = 0,
            .pattern_length = 1,
        };
    }

    // Check for period 2
    if (partials.len >= 4) {
        const p1 = partials[0];
        const p2 = partials[1];
        var matches = true;
        var i: usize = 0;
        while (i + 2 < partials.len) : (i += 2) {
            if (partials[i] != p1 or partials[i + 1] != p2) {
                matches = false;
                break;
            }
        }
        if (matches) {
            return .{
                .detector = .period_finder,
                .detected = true,
                .confidence = 0.95,
                .details = "Period 2 detected",
                .pattern_start = 0,
                .pattern_length = 2,
            };
        }
    }

    // General periodicity check (period up to 20)
    const max_period = @min(20, partials.len / 3);
    var period: usize = 3;
    while (period <= max_period) : (period += 1) {
        var matches = true;
        var i: usize = 0;
        while (i + period < partials.len) : (i += 1) {
            if (partials[i] != partials[i + period]) {
                matches = false;
                break;
            }
        }
        if (matches) {
            return .{
                .detector = .period_finder,
                .detected = true,
                .confidence = 0.8,
                .details = "Period detected",
                .pattern_start = 0,
                .pattern_length = period,
            };
        }
    }

    return .{
        .detector = .period_finder,
        .detected = false,
        .confidence = 0.0,
        .details = "No periodicity detected",
        .pattern_start = null,
        .pattern_length = null,
    };
}

/// Detector 2: Quasi-Period (e-like patterns)
/// Detects patterns like [2;1,2,1,1,4,1,1,6,1,...]
fn detectQuasiPeriod(partials: []const u64) DetectionResult {
    if (partials.len < 20) {
        return .{
            .detector = .quasi_period,
            .detected = false,
            .confidence = 0.0,
            .details = "Insufficient data",
            .pattern_start = null,
            .pattern_length = null,
        };
    }

    // Check for pattern: large values separated by ones
    // Characteristic of e = [2;1,2,1,1,4,1,1,6,1,1,8,...]
    var large_count: usize = 0;
    var ones_between: usize = 0;
    var total_ones: usize = 0;

    for (partials) |p| {
        if (p >= 4) {
            large_count += 1;
            ones_between = 0;
        } else if (p == 1) {
            total_ones += 1;
            ones_between += 1;
        }
    }

    // e-like: many ones, some large values in increasing sequence
    const one_ratio = @as(f64, @floatFromInt(total_ones)) / @as(f64, @floatFromInt(partials.len));
    const large_ratio = @as(f64, @floatFromInt(large_count)) / @as(f64, @floatFromInt(partials.len));

    if (one_ratio > 0.5 and large_ratio > 0.05 and large_ratio < 0.2) {
        return .{
            .detector = .quasi_period,
            .detected = true,
            .confidence = 0.7,
            .details = "Quasi-periodic pattern detected (e-like)",
            .pattern_start = 0,
            .pattern_length = null,
        };
    }

    return .{
        .detector = .quasi_period,
        .detected = false,
        .confidence = 0.0,
        .details = "No quasi-periodic pattern",
        .pattern_start = null,
        .pattern_length = null,
    };
}

/// Detector 3: Bounded Partial Quotients
/// Detects bounded CF (characteristic of quadratic irrationals)
fn detectBounded(partials: []const u64) DetectionResult {
    if (partials.len < 10) {
        return .{
            .detector = .bounded_pq,
            .detected = false,
            .confidence = 0.0,
            .details = "Insufficient data",
            .pattern_start = null,
            .pattern_length = null,
        };
    }

    var max_pq: u64 = 0;
    for (partials) |p| {
        if (p > max_pq) max_pq = p;
    }

    // Bounded if max < 10 (typical for quadratic irrationals)
    if (max_pq < 10) {
        return .{
            .detector = .bounded_pq,
            .detected = true,
            .confidence = 0.9,
            .details = "Bounded partial quotients (quadratic irrational)",
            .pattern_start = 0,
            .pattern_length = null,
        };
    }

    // Weakly bounded if max < 100
    if (max_pq < 100) {
        return .{
            .detector = .bounded_pq,
            .detected = true,
            .confidence = 0.5,
            .details = "Weakly bounded (may be higher-degree algebraic)",
            .pattern_start = 0,
            .pattern_length = null,
        };
    }

    return .{
        .detector = .bounded_pq,
        .detected = false,
        .confidence = 0.0,
        .details = "Unbounded (transcendental or high-degree algebraic)",
        .pattern_start = null,
        .pattern_length = null,
    };
}

/// Detector 4: Liouville
/// Detects Liouville numbers (extremely well approximable)
/// Characterized by very large partial quotients
fn detectLiouville(partials: []const u64) DetectionResult {
    if (partials.len < 20) {
        return .{
            .detector = .liouville,
            .detected = false,
            .confidence = 0.0,
            .details = "Insufficient data",
            .pattern_start = null,
            .pattern_length = null,
        };
    }

    // Liouville numbers have extremely large partial quotients
    // that grow faster than any power of n
    var max_pq: u64 = 0;
    var count_very_large: usize = 0;

    for (partials) |p| {
        if (p > max_pq) max_pq = p;
        if (p > 1000) count_very_large += 1;
    }

    if (max_pq > 10000 or count_very_large >= 3) {
        return .{
            .detector = .liouville,
            .detected = true,
            .confidence = if (max_pq > 100000) 0.95 else 0.7,
            .details = "Liouville-type (extremely well approximable)",
            .pattern_start = null,
            .pattern_length = null,
        };
    }

    return .{
        .detector = .liouville,
        .detected = false,
        .confidence = 0.0,
        .details = "Not Liouville-type",
        .pattern_start = null,
        .pattern_length = null,
    };
}

/// Detector 5: Fibonacci Embedding
/// UNIQUE TO TRINITY: Detects hidden φ-structure after division
/// Looks for ratios of consecutive partials close to φ
fn detectFibonacciEmbedding(partials: []const u64) DetectionResult {
    if (partials.len < 10) {
        return .{
            .detector = .fibonacci_embedding,
            .detected = false,
            .confidence = 0.0,
            .details = "Insufficient data",
            .pattern_start = null,
            .pattern_length = null,
        };
    }

    const sacred = @import("../sacred/sacred.zig");
    const phi = sacred.PHI;
    const phi_inv = 1.0 / phi;

    var fib_count: usize = 0;
    var total_ratios: usize = @min(50, partials.len - 1);

    // Check ratios of consecutive partials
    for (0..total_ratios) |i| {
        if (partials[i] > 0 and partials[i + 1] > 0) {
            const ratio = @as(f64, @floatFromInt(partials[i + 1])) /
                @as(f64, @floatFromInt(partials[i]));

            // Check if ratio is close to φ or 1/φ
            const diff_phi = @abs(ratio - phi);
            const diff_inv = @abs(ratio - phi_inv);

            if (diff_phi < 0.1 or diff_inv < 0.1) {
                fib_count += 1;
            }
        }
    }

    const fib_ratio = @as(f64, @floatFromInt(fib_count)) / @as(f64, @floatFromInt(total_ratios));

    if (fib_ratio > 0.3) {
        return .{
            .detector = .fibonacci_embedding,
            .detected = true,
            .confidence = fib_ratio,
            .details = "Fibonacci/φ structure detected in partial ratios",
            .pattern_start = 0,
            .pattern_length = null,
        };
    }

    // Also check for Fibonacci numbers appearing as partials
    var fib_in_cf: usize = 0;
    const fib_sequence = [_]u64{ 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987 };

    for (partials) |p| {
        for (fib_sequence) |f| {
            if (p == f) {
                fib_in_cf += 1;
                break;
            }
        }
    }

    const fib_in_ratio = @as(f64, @floatFromInt(fib_in_cf)) / @as(f64, @floatFromInt(partials.len));
    if (fib_in_ratio > 0.2) {
        return .{
            .detector = .fibonacci_embedding,
            .detected = true,
            .confidence = @min(fib_ratio, fib_in_ratio),
            .details = "Fibonacci numbers detected as partial quotients",
            .pattern_start = 0,
            .pattern_length = null,
        };
    }

    return .{
        .detector = .fibonacci_embedding,
        .detected = false,
        .confidence = 0.0,
        .details = "No Fibonacci/φ structure detected",
        .pattern_start = null,
        .pattern_length = null,
    };
}

/// Run all 5 detectors in parallel
pub fn runAllDetectors(partials: []const u64) [5]DetectionResult {
    return .{
        detectPeriod(partials),
        detectQuasiPeriod(partials),
        detectBounded(partials),
        detectLiouville(partials),
        detectFibonacciEmbedding(partials),
    };
}

/// Generate summary from all detections
pub fn generateSummary(detections: [5]DetectionResult) []const u8 {
    var detected_count: usize = 0;
    for (detections) |d| {
        if (d.detected) detected_count += 1;
    }

    if (detected_count == 0) {
        return "NO PATTERNS DETECTED - Generic transcendental";
    } else if (detected_count == 1) {
        if (detections[0].detected) return "PERIODIC - Quadratic irrational";
        if (detections[4].detected) return "FIBONACCI EMBEDDING - Hidden φ-structure";
    } else if (detected_count >= 3) {
        return "MULTIPLE PATTERNS - Structured number";
    }

    return "MIXED SIGNALS - Some structure detected";
}

/// CLI command: tri math cfrac-detect <formula_id> [--type <detector|all>]
pub fn runDetectCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;

    const GOLD = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const WHITE = "\x1b[97m";
    const GREEN = "\x1b[32m";
    const YELLOW = "\x1b[93m";
    const RED = "\x1b[31m";
    const MAGENTA = "\x1b[35m";
    const RESET = "\x1b[0m";

    if (args.len < 1) {
        std.debug.print("\n{s}USAGE:{s} tri math cfrac-detect <formula_id> [--type <detector|all>]\n", .{ CYAN, RESET });
        std.debug.print("\n{s}PALANTIR Stage 5 — DETECT: 5 Parallel Pattern Engines{s}\n\n", .{ CYAN, RESET });
        std.debug.print("{s}DETECTORS:{s}\n", .{ WHITE, RESET });
        std.debug.print("  1. period_finder       - Exact periodicity\n", .{});
        std.debug.print("  2. quasi_period        - e-like patterns\n", .{});
        std.debug.print("  3. bounded_pq          - Bounded partials (quadratic)\n", .{});
        std.debug.print("  4. liouville           - Extremely well approximable\n", .{});
        std.debug.print("  5. fibonacci_embedding - Hidden φ-structure (TRINITY unique)\n\n", .{});
        std.debug.print("{s}EXAMPLES:{s}\n", .{ CYAN, RESET });
        std.debug.print("  $ tri math cfrac-detect phi\n", .{});
        std.debug.print("  $ tri math cfrac-detect omega_dm\n", .{});
        std.debug.print("  $ tri math cfrac-detect pi --type fibonacci_embedding\n\n", .{});
        std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
        return;
    }

    // Import expand function
    const expand = @import("cfrac_expand.zig");

    const formula_id = args[0];
    const resolved = try expand.resolveFormula(formula_id);

    const result = try expand.expand(allocator, resolved.value, resolved.expression, .{});
    defer result.deinit(allocator);

    const detections = runAllDetectors(result.partials);
    const summary = generateSummary(detections);

    std.debug.print("\n{s}╔════════════════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}║         PALANTIR STAGE 5 — DETECT: 5 PATTERN ENGINES             ║{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}╚════════════════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

    std.debug.print("  {s}Target:{s} {s} = {d:.15}\n\n", .{ WHITE, RESET, resolved.expression, resolved.value });

    std.debug.print("  {s}╔══════════════════════════════════════════════════════════════╗{s}\n", .{ MAGENTA, RESET });
    std.debug.print("  {s}║  DETECTION RESULTS                                          ║{s}\n", .{ MAGENTA, RESET });
    std.debug.print("  {s}╚══════════════════════════════════════════════════════════════╝{s}\n\n", .{ MAGENTA, RESET });

    inline for (0..5) |i| {
        const d = detections[i];
        const detector_name = switch (d.detector) {
            .period_finder => "Period Finder",
            .quasi_period => "Quasi-Period",
            .bounded_pq => "Bounded PQ",
            .liouville => "Liouville",
            .fibonacci_embedding => "Fibonacci Embedding",
        };

        const status_color = if (d.detected) GREEN else YELLOW;
        const status_symbol = if (d.detected) "✓" else "✗";

        std.debug.print("  {s}{s}. {s}:{s} {s}{s} {s}confidence: {d:.0%}{s}\n", .{
            MAGENTA,      i + 1,         detector_name, RESET,
            status_color, status_symbol, d.details,     d.confidence,
            RESET,
        });

        if (d.pattern_length) |pl| {
            std.debug.print("     └─ Pattern length: {d}\n", .{pl});
        }
        std.debug.print("\n", .{});
    }

    std.debug.print("  {s}SUMMARY:{s} {s}\n\n", .{ WHITE, RESET, summary });

    std.debug.print("{s}Next stage: cfrac-verdict{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
}

// φ² + 1/φ² = 3 = TRINITY
