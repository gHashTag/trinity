// ═══════════════════════════════════════════════════════════════════════════════
// sacred_formula.zig — Sacred Formula Engine
// V = n * 3^k * pi^m * phi^p * e^q
// ═══════════════════════════════════════════════════════════════════════════════
//
// Core computation: brute-force integer relation detection (PSLQ-like).
// Reads constants from .tri spec, fits each to the Sacred Formula,
// serializes results to JSON for the HTTP API.
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const tri_spec = @import("tri_spec_parser.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// Constants
// ═══════════════════════════════════════════════════════════════════════════════

const TRINITY: f64 = 3.0;
const PI: f64 = math.pi;
const PHI: f64 = 1.6180339887498948482;
const E: f64 = math.e;

// ═══════════════════════════════════════════════════════════════════════════════
// Types
// ═══════════════════════════════════════════════════════════════════════════════

pub const SacredFit = struct {
    n: i8,
    k: i8,
    m: i8,
    p: i8,
    q: i8,
    value: f64,
    error_pct: f64,
};

pub const FitResult = struct {
    name: []const u8,
    symbol: []const u8,
    target: f64,
    category: []const u8,
    description: []const u8,
    fit: SacredFit,
};

pub const PredictionResult = struct {
    name: []const u8,
    formula: []const u8,
    value: f64,
    unit: []const u8,
    n: i8,
    k: i8,
    m: i8,
    p: i8,
    q: i8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// Core Computation
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute V = n * 3^k * pi^m * phi^p * e^q
pub fn compute(n: i8, k: i8, m: i8, p: i8, q: i8) f64 {
    const fn_f64 = @as(f64, @floatFromInt(n));
    const trinity_pow = math.pow(f64, TRINITY, @as(f64, @floatFromInt(k)));
    const pi_pow = math.pow(f64, PI, @as(f64, @floatFromInt(m)));
    const phi_pow = math.pow(f64, PHI, @as(f64, @floatFromInt(p)));
    const e_pow = math.pow(f64, E, @as(f64, @floatFromInt(q)));
    return fn_f64 * trinity_pow * pi_pow * phi_pow * e_pow;
}

/// Find best integer relation fit for a target value
pub fn findFit(target: f64, bounds: tri_spec.SearchBounds) SacredFit {
    var best = SacredFit{
        .n = 1,
        .k = 0,
        .m = 0,
        .p = 0,
        .q = 0,
        .value = 1.0,
        .error_pct = 100.0,
    };

    var n: i8 = bounds.n_range[0];
    while (n <= bounds.n_range[1]) : (n += 1) {
        var k: i8 = bounds.k_range[0];
        while (k <= bounds.k_range[1]) : (k += 1) {
            var m: i8 = bounds.m_range[0];
            while (m <= bounds.m_range[1]) : (m += 1) {
                var p_exp: i8 = bounds.p_range[0];
                while (p_exp <= bounds.p_range[1]) : (p_exp += 1) {
                    var q_exp: i8 = bounds.q_range[0];
                    while (q_exp <= bounds.q_range[1]) : (q_exp += 1) {
                        const val = compute(n, k, m, p_exp, q_exp);
                        if (val <= 0 or math.isNan(val) or math.isInf(val)) continue;

                        const err = @abs(val - target) / target * 100.0;
                        if (err < best.error_pct) {
                            best = .{
                                .n = n,
                                .k = k,
                                .m = m,
                                .p = p_exp,
                                .q = q_exp,
                                .value = val,
                                .error_pct = err,
                            };
                            if (err < 1e-10) return best;
                        }
                    }
                }
            }
        }
    }

    return best;
}

/// Fit all constants from a spec
pub fn fitAllConstants(allocator: Allocator, spec: *const tri_spec.SacredSpec) Allocator.Error![]FitResult {
    const items = spec.constants.items;
    const results = try allocator.alloc(FitResult, items.len);

    for (items, 0..) |c, i| {
        results[i] = .{
            .name = c.name,
            .symbol = c.symbol,
            .target = c.value,
            .category = c.category,
            .description = c.description,
            .fit = findFit(c.value, spec.search),
        };
    }

    return results;
}

/// Compute all predictions from a spec
pub fn computePredictions(allocator: Allocator, spec: *const tri_spec.SacredSpec) Allocator.Error![]PredictionResult {
    const items = spec.predictions.items;
    const results = try allocator.alloc(PredictionResult, items.len);

    for (items, 0..) |pred, i| {
        results[i] = .{
            .name = pred.name,
            .formula = pred.formula,
            .value = compute(pred.n, pred.k, pred.m, pred.p, pred.q),
            .unit = pred.unit,
            .n = pred.n,
            .k = pred.k,
            .m = pred.m,
            .p = pred.p,
            .q = pred.q,
        };
    }

    return results;
}

// ═══════════════════════════════════════════════════════════════════════════════
// JSON Serialization
// ═══════════════════════════════════════════════════════════════════════════════

/// Serialize a single fit result to JSON (for POST /api/sacred-formula/compute)
pub fn fitToJson(allocator: Allocator, target: f64, fit: SacredFit) Allocator.Error![]u8 {
    return std.fmt.allocPrint(allocator,
        \\{{"target":{d},"fit":{{"n":{d},"k":{d},"m":{d},"p":{d},"q":{d}}},"computed":{d:.10},"error_pct":{d:.6},"formula_string":"{d}*3^{d}*pi^{d}*phi^{d}*e^{d}"}}
    , .{
        target,
        fit.n, fit.k, fit.m, fit.p, fit.q,
        fit.value,
        fit.error_pct,
        fit.n, fit.k, fit.m, fit.p, fit.q,
    });
}

/// Serialize constants list to JSON (for GET /api/sacred-formula/constants)
pub fn constantsToJson(allocator: Allocator, spec: *const tri_spec.SacredSpec) Allocator.Error![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .{};
    const w = buf.writer(allocator);

    w.writeAll("{\"constants\":[") catch return error.OutOfMemory;

    for (spec.constants.items, 0..) |c, i| {
        if (i > 0) w.writeAll(",") catch return error.OutOfMemory;
        std.fmt.format(w,
            \\{{"name":"{s}","symbol":"{s}","value":{d},"category":"{s}","description":"{s}"}}
        , .{ c.name, c.symbol, c.value, c.category, c.description }) catch return error.OutOfMemory;
    }

    w.writeAll("]}") catch return error.OutOfMemory;
    return buf.toOwnedSlice(allocator);
}

/// Serialize full fit results + predictions to JSON (for GET /api/sacred-formula/fit)
pub fn fullResultsToJson(
    allocator: Allocator,
    fits: []const FitResult,
    preds: []const PredictionResult,
    bounds: tri_spec.SearchBounds,
) Allocator.Error![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .{};
    const w = buf.writer(allocator);

    w.writeAll("{\"formula\":\"V = n * 3^k * pi^m * phi^p * e^q\",\"constants\":[") catch return error.OutOfMemory;

    for (fits, 0..) |f, i| {
        if (i > 0) w.writeAll(",") catch return error.OutOfMemory;
        std.fmt.format(w,
            \\{{"name":"{s}","symbol":"{s}","target":{d},"category":"{s}","fit":{{"n":{d},"k":{d},"m":{d},"p":{d},"q":{d}}},"computed":{d:.10},"error_pct":{d:.6}}}
        , .{
            f.name, f.symbol, f.target, f.category,
            f.fit.n, f.fit.k, f.fit.m, f.fit.p, f.fit.q,
            f.fit.value, f.fit.error_pct,
        }) catch return error.OutOfMemory;
    }

    w.writeAll("],\"predictions\":[") catch return error.OutOfMemory;

    for (preds, 0..) |p, i| {
        if (i > 0) w.writeAll(",") catch return error.OutOfMemory;
        std.fmt.format(w,
            \\{{"name":"{s}","formula":"{s}","value":{d:.10},"unit":"{s}","n":{d},"k":{d},"m":{d},"p":{d},"q":{d}}}
        , .{
            p.name, p.formula, p.value, p.unit,
            p.n, p.k, p.m, p.p, p.q,
        }) catch return error.OutOfMemory;
    }

    std.fmt.format(w,
        \\],"search_bounds":{{"n":[{d},{d}],"k":[{d},{d}],"m":[{d},{d}],"p":[{d},{d}],"q":[{d},{d}]}}}}
    , .{
        bounds.n_range[0], bounds.n_range[1],
        bounds.k_range[0], bounds.k_range[1],
        bounds.m_range[0], bounds.m_range[1],
        bounds.p_range[0], bounds.p_range[1],
        bounds.q_range[0], bounds.q_range[1],
    }) catch return error.OutOfMemory;

    return buf.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "compute basic cases" {
    // V = 1 * 3^1 * pi^0 * phi^0 * e^0 = 3
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), compute(1, 1, 0, 0, 0), 1e-10);

    // V = 1 * 3^0 * pi^1 * phi^0 * e^0 = pi
    try std.testing.expectApproxEqAbs(PI, compute(1, 0, 1, 0, 0), 1e-10);

    // V = 1 * 3^0 * pi^0 * phi^1 * e^0 = phi
    try std.testing.expectApproxEqAbs(PHI, compute(1, 0, 0, 1, 0), 1e-10);

    // V = 1 * 3^0 * pi^0 * phi^0 * e^1 = e
    try std.testing.expectApproxEqAbs(E, compute(1, 0, 0, 0, 1), 1e-10);

    // V = 2 * 3^2 = 18
    try std.testing.expectApproxEqAbs(@as(f64, 18.0), compute(2, 2, 0, 0, 0), 1e-10);
}

test "findFit finds exact TRINITY" {
    const bounds = tri_spec.SearchBounds{};
    const fit = findFit(3.0, bounds);
    try std.testing.expectEqual(@as(i8, 1), fit.n);
    try std.testing.expectEqual(@as(i8, 1), fit.k);
    try std.testing.expectEqual(@as(i8, 0), fit.m);
    try std.testing.expectEqual(@as(i8, 0), fit.p);
    try std.testing.expectEqual(@as(i8, 0), fit.q);
    try std.testing.expect(fit.error_pct < 1e-10);
}

test "findFit finds good fit for fine structure" {
    const bounds = tri_spec.SearchBounds{};
    const fit = findFit(137.036, bounds);
    try std.testing.expect(fit.error_pct < 1.0); // Should be well under 1%
    try std.testing.expect(fit.value > 0);
}

test "compute predictions" {
    // Neutrino: 1*3^-1*pi^-1*phi^-4*e^-1
    const val = compute(1, -1, -1, -4, -1);
    try std.testing.expect(val > 0);
    try std.testing.expect(val < 1.0); // Should be a small number
}

test "fitToJson produces valid JSON" {
    const fit = SacredFit{ .n = 5, .k = 3, .m = -1, .p = 0, .q = 1, .value = 137.035, .error_pct = 0.0007 };
    const json = try fitToJson(std.testing.allocator, 137.036, fit);
    defer std.testing.allocator.free(json);

    try std.testing.expect(json.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"target\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"computed\"") != null);
}
