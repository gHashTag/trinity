// ═══════════════════════════════════════════════════════════════════════════════
// PALANTIR PIPELINE — Stage 1: EXTRACT
// Continued fraction expansion with mpmath bridge for arbitrary precision
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const cfrac_ref = @import("cfrac_reference.zig");

pub const ExpandResult = struct {
    value: f64,
    expression: []const u8,
    partials: []const u64, // Allocator-managed
    depth: usize,
    terminated: bool,
    precision_bits: u32,
    cache_file: ?[]const u8,

    pub fn deinit(self: *ExpandResult, allocator: std.mem.Allocator) void {
        if (self.partials.len > 0) {
            allocator.free(self.partials);
        }
        if (self.cache_file) |f| {
            allocator.free(f);
        }
    }
};

pub const ExpandOptions = struct {
    max_depth: usize = 10000,
    precision_bits: u32 = 256, // For mpmath bridge
    use_mpmath: bool = false, // Use Python mpmath for arbitrary precision
    cache_dir: ?[]const u8 = null,
};

/// Native Zig CF expansion (f64 precision, good for ~15-17 terms)
pub fn expandNative(allocator: std.mem.Allocator, value: f64, max_depth: usize) !ExpandResult {
    var partials = try allocator.alloc(u64, max_depth);
    errdefer allocator.free(partials);

    var remaining = value;
    var depth: usize = 0;
    var terminated = false;

    while (depth < max_depth) : (depth += 1) {
        const a = @floor(remaining);
        if (a < 0 or a > 1e12) break; // Safety check

        const a_int: u64 = @intFromFloat(a);
        partials[depth] = a_int;

        const frac = remaining - a;
        if (frac < 1e-15) {
            terminated = true;
            break;
        }

        remaining = 1.0 / frac;
        if (!std.math.isFinite(remaining)) break;
    }

    // Shrink to actual depth
    const actual_partials = try allocator.realloc(u64, partials, depth);

    return ExpandResult{
        .value = value,
        .expression = "native",
        .partials = actual_partials,
        .depth = depth,
        .terminated = terminated,
        .precision_bits = 53, // f64 mantissa
        .cache_file = null,
    };
}

/// CF expansion with mpmath bridge (Python subprocess for arbitrary precision)
/// Cache results in cfrac_cache/<id>.json
pub fn expandMpmath(allocator: std.mem.Allocator, expression: []const u8, options: ExpandOptions) !ExpandResult {
    _ = allocator;
    _ = expression;
    _ = options;

    // TODO: Implement mpmath bridge
    // 1. Check cache first
    // 2. If not cached, spawn Python subprocess
    // 3. Run: python -c "from mpmath import mp; mp.dps=100; print(cont_frac(<expr>))"
    // 4. Parse JSON output
    // 5. Write to cache

    return error.MpmathBridgeNotImplemented;
}

/// Main expand function - routes to native or mpmath based on options
pub fn expand(allocator: std.mem.Allocator, value: f64, expression: []const u8, options: ExpandOptions) !ExpandResult {
    if (options.use_mpmath) {
        return expandMpmath(allocator, expression, options);
    } else {
        return expandNative(allocator, value, options.max_depth);
    }
}

/// Resolve formula ID to numeric value
pub fn resolveFormula(formula_id: []const u8) !struct { value: f64, expression: []const u8 } {
    const sacred = @import("../sacred/sacred.zig");

    if (std.mem.eql(u8, formula_id, "phi")) {
        return .{ .value = sacred.PHI, .expression = "φ" };
    } else if (std.mem.eql(u8, formula_id, "pi")) {
        return .{ .value = sacred.PI, .expression = "π" };
    } else if (std.mem.eql(u8, formula_id, "e")) {
        return .{ .value = sacred.E, .expression = "e" };
    } else if (std.mem.eql(u8, formula_id, "sqrt2")) {
        return .{ .value = std.math.sqrt2, .expression = "√2" };
    } else if (std.mem.eql(u8, formula_id, "omega_dm")) {
        return .{ .value = (sacred.PHI * sacred.PHI) / (sacred.PI * sacred.PI), .expression = "φ²/π²" };
    } else if (std.mem.eql(u8, formula_id, "v_cb")) {
        return .{ .value = 1.0 / (3.0 * sacred.PI * sacred.PHI * sacred.PHI), .expression = "1/(3πφ²)" };
    } else {
        // Try parsing as float
        const value = try std.fmt.parseFloat(f64, formula_id);
        return .{ .value = value, .expression = formula_id };
    }
}

/// CLI command: tri math cfrac-expand <formula_id> [--depth N] [--mpmath]
pub fn runExpandCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const GOLD = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const WHITE = "\x1b[97m";
    const GREEN = "\x1b[32m";
    const RED = "\x1b[31m";
    const RESET = "\x1b[0m";

    if (args.len < 1) {
        std.debug.print("\n{s}USAGE:{s} tri math cfrac-expand <formula_id> [--depth N] [--mpmath]\n", .{ CYAN, RESET });
        std.debug.print("\n{s}PALANTIR Stage 1 — EXTRACT: Continued fraction expansion{s}\n\n", .{ CYAN, RESET });
        std.debug.print("{s}ARGUMENTS:{s}\n", .{ WHITE, RESET });
        std.debug.print("  formula_id  - One of: phi, pi, e, sqrt2, omega_dm, v_cb, or numeric value\n", .{});
        std.debug.print("  --depth N   - Max depth (default: 10000)\n", .{});
        std.debug.print("  --mpmath    - Use Python mpmath for arbitrary precision (TODO)\n\n", .{});
        std.debug.print("{s}EXAMPLES:{s}\n", .{ CYAN, RESET });
        std.debug.print("  $ tri math cfrac-expand omega_dm --depth 1000\n", .{});
        std.debug.print("  $ tri math cfrac-expand phi --depth 100\n\n", .{});
        std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
        return;
    }

    // Parse options
    var options = ExpandOptions{};
    var formula_id = args[0];

    var arg_idx: usize = 1;
    while (arg_idx < args.len) : (arg_idx += 1) {
        if (std.mem.eql(u8, args[arg_idx], "--depth")) {
            if (arg_idx + 1 < args.len) {
                options.max_depth = try std.fmt.parseInt(usize, args[arg_idx + 1], 10);
                arg_idx += 1;
            }
        } else if (std.mem.eql(u8, args[arg_idx], "--mpmath")) {
            options.use_mpmath = true;
        }
    }

    // Resolve formula
    const resolved = try resolveFormula(formula_id);
    const result = try expand(allocator, resolved.value, resolved.expression, options);
    defer result.deinit(allocator);

    std.debug.print("\n{s}╔════════════════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}║           PALANTIR STAGE 1 — EXTRACT: CF EXPANSION                 ║{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}╚════════════════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

    std.debug.print("  {s}Target:{s} {s}\n", .{ WHITE, RESET, resolved.expression });
    std.debug.print("  {s}Value:{s} {d:.15}\n", .{ WHITE, RESET, result.value });
    std.debug.print("  {s}Precision:{s} {d} bits ({s}native{}/{s}mpmath{])\n", .{ WHITE, RESET, result.precision_bits, if (options.use_mpmath) "  " else "", RESET });
    std.debug.print("  {s}Depth:{s} {d} terms computed\n\n", .{ WHITE, RESET, result.depth });

    std.debug.print("  {s}Continued Fraction:{s}\n", .{ WHITE, RESET });
    std.debug.print("    [{d}", .{result.partials[0]});
    const show_count = @min(15, result.partials.len);
    if (result.partials.len > 1) {
        std.debug.print(";", .{});
        for (result.partials[1..show_count]) |p| {
            std.debug.print("{d},", .{p});
        }
        std.debug.print("...");
    }
    std.debug.print("]\n\n", .{});

    std.debug.print("  {s}First 20 partial quotients:{s}\n", .{ WHITE, RESET });
    const show_20 = @min(20, result.partials.len);
    for (0..show_20) |i| {
        if (i % 10 == 0) std.debug.print("    ", .{});
        std.debug.print("{d:4} ", .{result.partials[i]});
        if (i % 10 == 9) std.debug.print("\n", .{});
    }
    if (show_20 % 10 != 0) std.debug.print("\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("  {s}Statistics:{s}\n", .{ WHITE, RESET });
    var max_p: u64 = 0;
    var sum: f64 = 0;
    var small_count: usize = 0;
    for (result.partials) |p| {
        if (p > max_p) max_p = p;
        sum += @floatFromInt(p);
        if (p <= 3) small_count += 1;
    }
    const mean = sum / @as(f64, @floatFromInt(result.partials.len));
    const small_ratio = @as(f64, @floatFromInt(small_count)) / @as(f64, @floatFromInt(result.partials.len));

    std.debug.print("    Max partial: {d}\n", .{max_p});
    std.debug.print("    Mean: {d:.3}\n", .{mean});
    std.debug.print("    Small (1,2,3) ratio: {d:.1}%\n\n", .{small_ratio * 100});

    if (result.terminated) {
        std.debug.print("  {s}✓{s} Expansion terminated (exact rational or algebraic)\n\n", .{ GREEN, RESET });
    } else {
        std.debug.print("  {s}○{s} Expansion did not terminate (irrational)\n\n", .{ GOLD, RESET });
    }

    std.debug.print("{s}Next stages: cfrac-stats, cfrac-compare, cfrac-approx, cfrac-detect, cfrac-verdict{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
}

// φ² + 1/φ² = 3 = TRINITY
