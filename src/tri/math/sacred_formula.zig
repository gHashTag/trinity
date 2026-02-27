// ═══════════════════════════════════════════════════════════════════════════════
// SACRED FORMULA ENGINE v3.6
// V = n × 3^k × π^m × φ^p × e^q
// ═══════════════════════════════════════════════════════════════════════════════
//
// Brute-force fitting: given a target value, find the (n,k,m,p,q) parameters
// that minimize |V - target| / |target|.
// Search space: 9 × 9 × 4 × 9 × 7 = 20,412 combinations — <1ms in Zig.
//
// Mirrors: website/src/services/chatApi.ts:1011-1041
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;

// Sacred constants
pub const PHI: f64 = 1.6180339887498948482;
pub const PI: f64 = 3.14159265358979323846;
pub const E: f64 = 2.71828182845904523536;
pub const TRINITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const SacredFormulaFit = struct {
    n: i8,
    k: i8,
    m: i8,
    p: i8,
    q: i8,
    computed: f64,
    error_pct: f64,
};

// Parameter bounds — matches chatApi.ts PARAM_BOUNDS
const N_MIN: i8 = 1;
const N_MAX: i8 = 9;
const K_MIN: i8 = -4;
const K_MAX: i8 = 4;
const M_MIN: i8 = -3;
const M_MAX: i8 = 0;
const P_MIN: i8 = -4;
const P_MAX: i8 = 4;
const Q_MIN: i8 = -3;
const Q_MAX: i8 = 3;

// ═══════════════════════════════════════════════════════════════════════════════
// CORE FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Helper: integer power of a float
fn ipow(base: f64, exp: i8) f64 {
    if (exp == 0) return 1.0;
    if (exp > 0) {
        var result: f64 = 1.0;
        var i: i8 = 0;
        while (i < exp) : (i += 1) {
            result *= base;
        }
        return result;
    } else {
        var result: f64 = 1.0;
        var i: i8 = 0;
        while (i > exp) : (i -= 1) {
            result /= base;
        }
        return result;
    }
}

/// Compute V = n × 3^k × π^m × φ^p × e^q
pub fn computeSacredFormula(n: i8, k: i8, m: i8, p: i8, q: i8) f64 {
    const nf: f64 = @floatFromInt(n);
    return nf * ipow(3.0, k) * ipow(PI, m) * ipow(PHI, p) * ipow(E, q);
}

/// Brute-force search: find best (n,k,m,p,q) for a target value.
/// Searches 20,412 combinations. Returns best fit with error percentage.
pub fn fitSacredFormula(target: f64) SacredFormulaFit {
    var best = SacredFormulaFit{
        .n = 1,
        .k = 0,
        .m = 0,
        .p = 0,
        .q = 0,
        .computed = 1.0,
        .error_pct = 100.0,
    };
    var best_error: f64 = math.inf(f64);

    const abs_target = @abs(target);
    if (abs_target < 1e-15) return best;

    var n: i8 = N_MIN;
    while (n <= N_MAX) : (n += 1) {
        var k: i8 = K_MIN;
        while (k <= K_MAX) : (k += 1) {
            var m: i8 = M_MIN;
            while (m <= M_MAX) : (m += 1) {
                var p: i8 = P_MIN;
                while (p <= P_MAX) : (p += 1) {
                    var q: i8 = Q_MIN;
                    while (q <= Q_MAX) : (q += 1) {
                        const v = computeSacredFormula(n, k, m, p, q);
                        const err = @abs(v - target) / abs_target;
                        if (err < best_error) {
                            best_error = err;
                            best = .{
                                .n = n,
                                .k = k,
                                .m = m,
                                .p = p,
                                .q = q,
                                .computed = v,
                                .error_pct = err * 100.0,
                            };
                        }
                    }
                }
            }
        }
    }

    return best;
}

// ═══════════════════════════════════════════════════════════════════════════════
// FORMATTING
// ═══════════════════════════════════════════════════════════════════════════════

/// Format the formula string: "n × 3^k × π^m × φ^p × e^q"
pub fn formatFormulaString(buf: []u8, fit: SacredFormulaFit) []const u8 {
    var fbs = std.io.fixedBufferStream(buf);
    const writer = fbs.writer();

    writer.print("{d}", .{fit.n}) catch return buf[0..0];

    if (fit.k != 0) {
        if (fit.k == 1) {
            writer.writeAll("\xc3\x973") catch {}; // ×3
        } else {
            writer.print("\xc3\x973^{d}", .{fit.k}) catch {}; // ×3^k
        }
    }
    if (fit.m != 0) {
        if (fit.m == 1) {
            writer.writeAll("\xc3\x97\xcf\x80") catch {}; // ×π
        } else {
            writer.print("\xc3\x97\xcf\x80^{d}", .{fit.m}) catch {}; // ×π^m
        }
    }
    if (fit.p != 0) {
        if (fit.p == 1) {
            writer.writeAll("\xc3\x97\xcf\x86") catch {}; // ×φ
        } else {
            writer.print("\xc3\x97\xcf\x86^{d}", .{fit.p}) catch {}; // ×φ^p
        }
    }
    if (fit.q != 0) {
        if (fit.q == 1) {
            writer.writeAll("\xc3\x97e") catch {}; // ×e
        } else {
            writer.print("\xc3\x97e^{d}", .{fit.q}) catch {}; // ×e^q
        }
    }

    return fbs.getWritten();
}

/// Print a sacred formula fit result with ANSI colors
pub fn printSacredFormulaFit(fit: SacredFormulaFit, target: f64) void {
    const GOLDEN = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const WHITE = "\x1b[97m";
    const GRAY = "\x1b[90m";
    const GREEN = "\x1b[32m";
    const RED = "\x1b[31m";
    const RESET = "\x1b[0m";

    std.debug.print("\n{s}Sacred Formula Decomposition{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}================================{s}\n\n", .{ GRAY, RESET });

    std.debug.print("  {s}Target:{s}  {s}{d:.6}{s}\n", .{ GRAY, RESET, WHITE, target, RESET });

    var formula_buf: [128]u8 = undefined;
    const formula_str = formatFormulaString(&formula_buf, fit);
    std.debug.print("  {s}Formula:{s} {s}V = {s}{s}\n", .{ GRAY, RESET, GOLDEN, formula_str, RESET });
    std.debug.print("  {s}Value:{s}   {s}{d:.6}{s}\n", .{ GRAY, RESET, WHITE, fit.computed, RESET });

    const err_color = if (fit.error_pct < 1.0) GREEN else if (fit.error_pct < 5.0) CYAN else RED;
    std.debug.print("  {s}Error:{s}   {s}{d:.4}%{s}\n", .{ GRAY, RESET, err_color, fit.error_pct, RESET });

    std.debug.print("\n  {s}Parameters:{s}\n", .{ CYAN, RESET });
    std.debug.print("    n={s}{d}{s}  k={s}{d}{s}  m={s}{d}{s}  p={s}{d}{s}  q={s}{d}{s}\n", .{
        WHITE, fit.n, RESET,
        WHITE, fit.k, RESET,
        WHITE, fit.m, RESET,
        WHITE, fit.p, RESET,
        WHITE, fit.q, RESET,
    });

    std.debug.print("\n{s}\xcf\x86\xc2\xb2 + 1/\xcf\x86\xc2\xb2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "compute trinity" {
    // V = 1 × 3^1 × π^0 × φ^0 × e^0 = 3.0
    const v = computeSacredFormula(1, 1, 0, 0, 0);
    try std.testing.expectApproxEqAbs(3.0, v, 1e-10);
}

test "compute unity" {
    // V = 1 × 3^0 × π^0 × φ^0 × e^0 = 1.0
    const v = computeSacredFormula(1, 0, 0, 0, 0);
    try std.testing.expectApproxEqAbs(1.0, v, 1e-10);
}

test "compute phi" {
    // V = 1 × 3^0 × π^0 × φ^1 × e^0 = φ
    const v = computeSacredFormula(1, 0, 0, 1, 0);
    try std.testing.expectApproxEqAbs(PHI, v, 1e-10);
}

test "compute pi" {
    // V = 1 × 3^0 × π^1 × φ^0 × e^0 = π — but m range is [-3,0], so m=1 is out of search range
    // Test the function directly though:
    const v = computeSacredFormula(1, 0, -1, 0, 0);
    try std.testing.expectApproxEqAbs(1.0 / PI, v, 1e-10);
}

test "fit 3.0 exact" {
    const fit = fitSacredFormula(3.0);
    try std.testing.expectEqual(@as(i8, 1), fit.n);
    try std.testing.expectEqual(@as(i8, 1), fit.k);
    try std.testing.expectEqual(@as(i8, 0), fit.m);
    try std.testing.expectEqual(@as(i8, 0), fit.p);
    try std.testing.expectEqual(@as(i8, 0), fit.q);
    try std.testing.expectApproxEqAbs(0.0, fit.error_pct, 1e-10);
}

test "fit 1.0 exact" {
    const fit = fitSacredFormula(1.0);
    try std.testing.expectEqual(@as(i8, 1), fit.n);
    try std.testing.expectApproxEqAbs(0.0, fit.error_pct, 1e-10);
}

test "fit 137.036 fine structure" {
    const fit = fitSacredFormula(137.036);
    // Should find a reasonable fit with error < 5%
    try std.testing.expect(fit.error_pct < 5.0);
    try std.testing.expect(fit.computed > 0);
}

test "fit 42 answer to everything" {
    const fit = fitSacredFormula(42.0);
    try std.testing.expect(fit.error_pct < 10.0);
    try std.testing.expect(fit.computed > 0);
}

test "ipow correctness" {
    try std.testing.expectApproxEqAbs(1.0, ipow(3.0, 0), 1e-10);
    try std.testing.expectApproxEqAbs(3.0, ipow(3.0, 1), 1e-10);
    try std.testing.expectApproxEqAbs(9.0, ipow(3.0, 2), 1e-10);
    try std.testing.expectApproxEqAbs(1.0 / 3.0, ipow(3.0, -1), 1e-10);
    try std.testing.expectApproxEqAbs(1.0 / 9.0, ipow(3.0, -2), 1e-10);
}

test "format formula string" {
    var buf: [128]u8 = undefined;
    const fit = SacredFormulaFit{
        .n = 1, .k = 1, .m = 0, .p = 0, .q = 0,
        .computed = 3.0, .error_pct = 0.0,
    };
    const s = formatFormulaString(&buf, fit);
    try std.testing.expect(s.len > 0);
}
