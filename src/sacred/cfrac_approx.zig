// ═══════════════════════════════════════════════════════════════════════════════
// PALANTIR PIPELINE — Stage 4: APPROX
// Convergents with experimental thresholds (Planck, Euclid, LSST)
// Best rational approximations from continued fraction
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const Convergent = struct {
    n: usize, // Index
    p: u128, // Numerator
    q: u128, // Denominator
    value: f64, // p/q
    error_val: f64, // |x - p/q|
    error_log: f64, // log10(error)

    pub fn format(self: *const Convergent, comptime fmt: []const u8, options: anytype, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("Convergent({d}: {d}/{d} = {d:.12}, err={d:.3e})", .{
            self.n, self.p, self.q, self.value, self.error_val,
        });
    }
};

pub const ExperimentThreshold = struct {
    name: []const u8,
    date: []const u8,
    precision: f64, // Required precision (as log10 error)
    max_denominator: u128,
    status: []const u8,
};

/// Experimental thresholds for Ω_DM measurements
pub const omega_dm_thresholds = [_]ExperimentThreshold{
    .{
        .name = "Planck 2018 (TT,TE,EE+lowE+lensing)",
        .date = "2018",
        .precision = -4.4, // ~10^-4.4 = 4.4×10⁻⁵
        .max_denominator = 100,
        .status = "✓ ACHIEVED",
    },
    .{
        .name = "Euclid DR1",
        .date = "Oct 2026",
        .precision = -5.4, // ~10^-5.4 = 4.1×10⁻⁶
        .max_denominator = 500000,
        .status = "→ TARGET",
    },
    .{
        .name = "Euclid DR2",
        .date = "2029",
        .precision = -6.1, // ~10^-6.1 = 8.6×10⁻⁷
        .max_denominator = 1000000,
        .status = "FUTURE",
    },
    .{
        .name = "Euclid full + LSST",
        .date = "2032",
        .precision = -7.3, // ~10^-7.3 = 5.0×10⁻⁸
        .max_denominator = 10000000,
        .status = "FUTURE",
    },
};

pub const ApproxResult = struct {
    target_value: f64,
    expression: []const u8,
    convergents: []Convergent, // Allocator-managed
    n_convergents: usize,
    best_convergent: ?*Convergent,
    achieved_experiments: []const usize, // Indices of achieved experiments

    pub fn deinit(self: *ApproxResult, allocator: std.mem.Allocator) void {
        if (self.convergents.len > 0) {
            allocator.free(self.convergents);
        }
    }
};

/// Compute convergents from continued fraction partial quotients
/// Uses recurrence: pₙ = aₙpₙ₋₁ + pₙ₋₂, qₙ = aₙqₙ₋₁ + qₙ₋₂
pub fn computeConvergents(
    allocator: std.mem.Allocator,
    target: f64,
    expression: []const u8,
    partials: []const u64,
    max_denominator: u128,
) !ApproxResult {
    // Allocate space for convergents (at most partials.len)
    var convergents = try allocator.alloc(Convergent, partials.len);

    var p_prev2: u128 = 0;
    var p_prev1: u128 = 1;
    var q_prev2: u128 = 1;
    var q_prev1: u128 = 0;

    var n_convergents: usize = 0;
    var best_error: f64 = 1.0;
    var best_idx: ?usize = null;

    for (partials, 0..) |a, i| {
        // Check for overflow before computing
        if (a > 1000000) break; // Safety: don't use huge partials

        const a_u128: u128 = @intCast(a);
        const p_new = a_u128 * p_prev1 + p_prev2;
        const q_new = a_u128 * q_prev1 + q_prev2;

        // Check for overflow
        if (p_new < p_prev1 or q_new < q_prev1) break;

        // Check denominator limit
        if (q_new > max_denominator) break;

        const p_q: f64 = if (q_new > 0)
            @as(f64, @floatFromInt(p_new)) / @as(f64, @floatFromInt(q_new))
        else
            0.0;

        const error_val = if (target > 0)
            @abs(target - p_q) / target
        else
            @abs(target - p_q);

        const error_log = if (error_val > 0)
            std.math.log10(error_val)
        else
            -999.0;

        convergents[n_convergents] = .{
            .n = i,
            .p = p_new,
            .q = q_new,
            .value = p_q,
            .error_val = error_val,
            .error_log = error_log,
        };
        n_convergents += 1;

        // Track best
        if (error_val < best_error) {
            best_error = error_val;
            best_idx = i;
        }

        // Update recurrence
        p_prev2 = p_prev1;
        p_prev1 = p_new;
        q_prev2 = q_prev1;
        q_prev1 = q_new;
    }

    // Shink to actual size
    const actual_convergents = try allocator.realloc(Convergent, convergents, n_convergents);

    // Find which experiments are achieved
    var achieved = try allocator.alloc(usize, omega_dm_thresholds.len);
    var achieved_count: usize = 0;
    for (omega_dm_thresholds, 0..) |threshold, i| {
        if (best_error != 1.0) {
            const best_log = std.math.log10(best_error);
            if (best_log <= threshold.precision) {
                achieved[achieved_count] = i;
                achieved_count += 1;
            }
        }
    }

    return ApproxResult{
        .target_value = target,
        .expression = expression,
        .convergents = actual_convergents,
        .n_convergents = n_convergents,
        .best_convergent = if (best_idx) |idx| &actual_convergents[idx] else null,
        .achieved_experiments = achieved[0..achieved_count],
    };
}

/// Find best convergent for a given precision threshold
pub fn findConvergentForPrecision(convergents: []Convergent, precision: f64) ?*const Convergent {
    var best: ?*const Convergent = null;
    for (convergents) |*conv| {
        if (conv.error_log <= precision) {
            if (best == null or conv.error_log < best.?.error_log) {
                best = conv;
            }
        }
    }
    return best;
}

/// CLI command: tri math cfrac-approx <formula_id> [--max-denom N]
pub fn runApproxCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const GOLD = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const WHITE = "\x1b[97m";
    const GREEN = "\x1b[32m";
    const YELLOW = "\x1b[93m";
    const RED = "\x1b[31m";
    const MAGENTA = "\x1b[35m";
    const RESET = "\x1b[0m";

    if (args.len < 1) {
        std.debug.print("\n{s}USAGE:{s} tri math cfrac-approx <formula_id> [--max-denom N]\n", .{ CYAN, RESET });
        std.debug.print("\n{s}PALANTIR Stage 4 — APPROX: Convergents + Experiment Thresholds{s}\n\n", .{ CYAN, RESET });
        std.debug.print("{s}ARGUMENTS:{s}\n", .{ WHITE, RESET });
        std.debug.print("  formula_id    - One of: phi, pi, omega_dm, etc.\n", .{});
        std.debug.print("  --max-denom N - Maximum denominator (default: 1000000)\n\n", .{});
        std.debug.print("{s}EXPERIMENTAL THRESHOLDS (Ω_DM):{s}\n", .{ YELLOW, RESET });
        for (omega_dm_thresholds) |threshold| {
            std.debug.print("  {s}{s:>20}{s} ({s}): precision 10^{d:.1}, max denom {d:>8} {s}\n", .{
                MAGENTA,             threshold.name,            RESET,            threshold.date,
                threshold.precision, threshold.max_denominator, threshold.status,
            });
        }
        std.debug.print("\n{s}EXAMPLES:{s}\n", .{ CYAN, RESET });
        std.debug.print("  $ tri math cfrac-approx omega_dm\n", .{});
        std.debug.print("  $ tri math cfrac-approx omega_dm --max-denom 10000000\n\n", .{});
        std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
        return;
    }

    // Import expand function
    const expand = @import("cfrac_expand.zig");

    // Parse options
    var max_denominator: u128 = 1000000;
    const formula_id = args[0];

    var arg_idx: usize = 1;
    while (arg_idx < args.len) : (arg_idx += 1) {
        if (std.mem.eql(u8, args[arg_idx], "--max-denom")) {
            if (arg_idx + 1 < args.len) {
                max_denominator = try std.fmt.parseInt(u128, args[arg_idx + 1], 10);
                arg_idx += 1;
            }
        }
    }

    const resolved = try expand.resolveFormula(formula_id);
    const result = try expand.expand(allocator, resolved.value, resolved.expression, .{});
    defer result.deinit(allocator);

    const approx = try computeConvergents(allocator, resolved.value, resolved.expression, result.partials, max_denominator);
    defer approx.deinit(allocator);

    std.debug.print("\n{s}╔════════════════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}║         PALANTIR STAGE 4 — APPROX: CONVERGENTS                   ║{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}╚════════════════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

    std.debug.print("  {s}Target:{s} {s} = {d:.15}\n", .{ WHITE, RESET, approx.expression, approx.target_value });
    std.debug.print("  {s}Convergents computed:{s} {d}\n", .{ WHITE, RESET, approx.n_convergents });
    std.debug.print("  {s}Max denominator:{s} {d}\n\n", .{ WHITE, RESET, max_denominator });

    // Show table of convergents
    std.debug.print("  {s}╔═════╦═══════════════╦═══════════════╦═════════════╦════════════╗{s}\n", .{ MAGENTA, RESET });
    std.debug.print("  {s}║  n  ║   Convergent  ║    Value     ║   Error    ║  log₁₀(err)║{s}\n", .{ MAGENTA, RESET });
    std.debug.print("  {s}╠═════╬═══════════════╬═══════════════╬═════════════╬════════════╣{s}\n", .{ MAGENTA, RESET });

    const show_count = @min(10, approx.n_convergents);
    for (approx.convergents[0..show_count]) |conv| {
        var err_buf: [32]u8 = undefined;
        const exp_notation = if (conv.error_val < 0.0001 or conv.error_val > 1000)
            std.fmt.bufPrint(&err_buf, "{e:.2}", .{conv.error_val}) catch "?"
        else
            std.fmt.bufPrint(&err_buf, "{d:.6}", .{conv.error_val}) catch "?";

        std.debug.print("  {s}║ {d:3} ║ {d:7}/{d:7} ║ {d:11.9} ║ {s:>10} ║ {d:8.2f}  ║{s}\n", .{
            MAGENTA, conv.n, conv.p, conv.q, RESET, conv.value, exp_notation, conv.error_log, MAGENTA,
        });
    }
    std.debug.print("  {s}╚═════╩═══════════════╩═══════════════╩═════════════╩════════════╝{s}\n\n", .{ MAGENTA, RESET });

    // Show best convergent
    if (approx.best_convergent) |best| {
        std.debug.print("  {s}BEST CONVERGENT:{s}\n", .{ WHITE, RESET });
        std.debug.print("    {d}/{d} = {d:.15}\n", .{ best.p, best.q, best.value });
        std.debug.print("    Error: {e:.3} ({d:.2f} decimal places)\n\n", .{ best.error_val, -best.error_log });
    }

    // Show experimental thresholds
    std.debug.print("  {s}EXPERIMENTAL THRESHOLDS:{s}\n", .{ YELLOW, RESET });
    for (omega_dm_thresholds, 0..) |threshold, i| {
        const achieved = if (approx.best_convergent) |best|
            best.error_log <= threshold.precision
        else
            false;

        const status_color = if (achieved) GREEN else YELLOW;
        const status_symbol = if (achieved) "✓" else "→";

        std.debug.print("    {s}{s} {s}{s}{s}\n", .{ status_color, status_symbol, RESET, threshold.name, RESET });
        std.debug.print("      Required: 10^{d:.1} ({d:.1} decimal places)\n", .{
            threshold.precision, -threshold.precision,
        });
        std.debug.print("      Max denom: {d}\n", .{threshold.max_denominator});

        if (approx.best_convergent) |best| {
            if (achieved) {
                std.debug.print("      {s}✓ ACHIEVED{ s}: error = 10^{d:.2} < 10{d:.1}{s}\n", .{
                    GREEN, RESET, best.error_log, threshold.precision, RESET,
                });
            } else {
                const needed = threshold.precision - best.error_log;
                std.debug.print("      {s}→ NEEDS {d:.1} more decimal places{ s}\n", .{
                    YELLOW, needed, RESET,
                });
            }
        }
        std.debug.print("\n", .{});
    }

    // Show notable convergents for specific thresholds
    std.debug.print("  {s}NOTABLE CONVERGENTS FOR EXPERIMENTS:{s}\n", .{ WHITE, RESET });

    for (omega_dm_thresholds) |threshold| {
        if (findConvergentForPrecision(approx.convergents, threshold.precision)) |conv| {
            std.debug.print("    {d}/{d} achieves 10^{d:.1} precision → {s}\n", .{
                conv.p, conv.q, threshold.precision, threshold.name,
            });
        }
    }
    std.debug.print("\n", .{});

    std.debug.print("{s}Next stages: cfrac-detect, cfrac-verdict{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
}

// φ² + 1/φ² = 3 = TRINITY
