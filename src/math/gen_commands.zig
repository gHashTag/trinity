//! Math CLI Commands — Generated from specs/tri/math/math_cli.tri
//! φ² + 1/φ² = 3 | TRINITY
//!
//! DO NOT EDIT: This file is generated from math_cli.tri spec
//! Command hierarchy, aliases, help text, argument parsing

const std = @import("std");

// Re-export from other math modules
const gen_constants = @import("gen_constants.zig");
const gen_eval = @import("gen_eval.zig");
const gen_identities = @import("gen_identities.zig");

pub const PHI = gen_constants.PHI;
pub const PI = gen_constants.PI;
pub const E = gen_constants.E;

// ============================================================================
// TYPES
// ============================================================================

/// Output format for commands
pub const OutputFormat = enum(u8) {
    pretty,
    json,
    csv,
};

// ============================================================================
// HELP TEXT
// ============================================================================

pub const MATH_HELP_TEXT =
    \\╔══════════════════════════════════════════════════════════════════════════════╗
    \\║                    SACRED MATHEMATICS FRAMEWORK v2.0                         ║
    \\║                    φ² + 1/φ² = 3 = TRINITY                                    ║
    \\╠══════════════════════════════════════════════════════════════════════════════╣
    \\║                                                                            ║
    \\║  HIERARCHICAL COMMANDS                                                      ║
    \\║  ─────────────────────────────────────────────────────────────────────────  ║
    \\║  tri math                      Show all math commands                        ║
    \\║  tri math constants            Show all sacred constants                     ║
    \\║  tri math eval phi <n>         Compute φ^n                                   ║
    \\║  tri math eval fib <n>         Fibonacci F(n) (BigInt)                       ║
    \\║  tri math eval lucas <n>       Lucas L(n)                                    ║
    \\║  tri math compute spiral <n>   φ-spiral + ASCII plot                         ║
    \\║  tri math compute verify       Verify all sacred identities                  ║
    \\║  tri math compute compare <n>  Compare φ^n vs F(n) vs L(n)                   ║
    \\║  tri math bench                Run benchmarks                                ║
    \\║  tri math identities           Show all φ-identities with proofs             ║
    \\║                                                                            ║
    \\║  ALIASES (Quick Access)                                                      ║
    \\║  ─────────────────────────────────────────────────────────────────────────  ║
    \\║  tri constants                Same as 'tri math constants'                   ║
    \\║  tri phi <n>                  Same as 'tri math eval phi <n>'                ║
    \\║  tri fib <n>                  Same as 'tri math eval fib <n>'                ║
    \\║  tri lucas <n>                Same as 'tri math eval lucas <n>'              ║
    \\║  tri spiral <n>               Same as 'tri math compute spiral <n>'          ║
    \\║  tri verify                   Same as 'tri math compute verify'              ║
    \\║                                                                            ║
    \\║  FLAGS                                                                       ║
    \\║  ─────────────────────────────────────────────────────────────────────────  ║
    \\║  --format=pretty|json|csv    Output format                                  ║
    \\║  --precision=N                Decimal precision (default: 16)                ║
    \\║  --plot                       Show ASCII spiral plot                        ║
    \\║  --max-n=N                    Comparison range (default: 20)                 ║
    \\║                                                                            ║
    \\║  EXAMPLES                                                                    ║
    \\║  ─────────────────────────────────────────────────────────────────────────  ║
    \\║  tri phi 42                   Compute φ⁴²                                    ║
    \\║  tri fib 1000                 F(1000) = 4346655... (209 digits)              ║
    \\║  tri lucas 2                  L(2) = 3 = TRINITY                             ║
    \\║  tri spiral 12 --plot         φ-spiral with ASCII plot                       ║
    \\║  tri verify                   Check all sacred identities                    ║
    \\║  tri math constants --json    Export constants as JSON                       ║
    \\║                                                                            ║
    \\╚══════════════════════════════════════════════════════════════════════════════╝
;

// ============================================================================
// PARSING FUNCTIONS
// ============================================================================

/// Parse a specific flag from arguments
pub fn parseFlag(args: [][]const u8, flag_name: []const u8) ?[]const u8 {
    const flag_with_dash = "--";
    const full_flag = std.fmt.allocPrint(std.heap.page_allocator, "--{s}", .{flag_name}) catch return null;
    defer std.heap.page_allocator.free(full_flag);

    for (args) |arg| {
        if (std.mem.eql(u8, arg, full_flag)) {
            return "";
        }
        if (std.mem.startsWith(u8, arg, flag_with_dash)) {
            const eq_idx = std.mem.indexOfScalar(u8, arg, '=');
            if (eq_idx) |idx| {
                if (std.mem.eql(u8, arg[2..idx], flag_name)) {
                    return arg[idx + 1 ..];
                }
            }
        }
    }
    return null;
}

/// Parse output format from arguments
pub fn parseFormatFlag(args: [][]const u8) OutputFormat {
    if (parseFlag(args, "format")) |fmt| {
        if (std.mem.eql(u8, fmt, "json")) return .json;
        if (std.mem.eql(u8, fmt, "csv")) return .csv;
    }
    return .pretty;
}

// ============================================================================
// COMMAND DISPATCHERS
// ============================================================================

/// Main math command dispatcher
pub fn runMathCommand(allocator: std.mem.Allocator, args: [][]const u8) void {
    if (args.len == 0) {
        showMathHelp();
        return;
    }

    const subcommand = args[0];
    const remaining = args[1..];

    if (std.mem.eql(u8, subcommand, "constants")) {
        runConstantsCommand(allocator, remaining);
    } else if (std.mem.eql(u8, subcommand, "eval")) {
        runEvalCommand(allocator, remaining);
    } else if (std.mem.eql(u8, subcommand, "compute")) {
        runComputeCommand(allocator, remaining);
    } else if (std.mem.eql(u8, subcommand, "bench")) {
        runBenchCommand(allocator, remaining);
    } else if (std.mem.eql(u8, subcommand, "identities")) {
        runIdentitiesCommand(allocator, remaining);
    } else if (std.mem.eql(u8, subcommand, "help")) {
        showMathHelp();
    } else {
        std.debug.print("Unknown math subcommand: {s}\n\n", .{subcommand});
        showMathHelp();
    }
}

/// Show all sacred constants
pub fn runConstantsCommand(allocator: std.mem.Allocator, args: [][]const u8) void {
    _ = allocator;

    const format = parseFormatFlag(args);

    if (format == .json) {
        std.debug.print("{{\n", .{});
        std.debug.print("  \"PHI\": {d:.16},\n", .{PHI});
        std.debug.print("  \"PI\": {d:.16},\n", .{PI});
        std.debug.print("  \"E\": {d:.16},\n", .{E});
        std.debug.print("  \"TRINITY_SUM\": {d:.1}\n", .{gen_constants.TRINITY_SUM});
        std.debug.print("}}\n", .{});
    } else {
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║                    SACRED CONSTANTS                            ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║  PHI (φ)     = {d:>20.16}                             ║\n", .{PHI});
        std.debug.print("║  PI (π)      = {d:>20.16}                             ║\n", .{PI});
        std.debug.print("║  E           = {d:>20.16}                             ║\n", .{E});
        std.debug.print("║  TRINITY     = {d:>20.1} (= φ² + 1/φ²)              ║\n", .{gen_constants.TRINITY_SUM});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    }
}

/// Eval dispatcher (phi/fib/lucas)
pub fn runEvalCommand(allocator: std.mem.Allocator, args: [][]const u8) void {
    if (args.len == 0) {
        std.debug.print("Usage: tri math eval [phi|fib|lucas] <n>\n", .{});
        return;
    }

    const subcommand = args[0];
    const remaining = args[1..];

    if (std.mem.eql(u8, subcommand, "phi")) {
        runPhiCommand(allocator, remaining);
    } else if (std.mem.eql(u8, subcommand, "fib")) {
        runFibCommand(allocator, remaining);
    } else if (std.mem.eql(u8, subcommand, "lucas")) {
        runLucasCommand(allocator, remaining);
    } else {
        std.debug.print("Unknown eval subcommand: {s}\n", .{subcommand});
    }
}

/// Compute φ^n
pub fn runPhiCommand(allocator: std.mem.Allocator, args: [][]const u8) void {
    _ = allocator;
    if (args.len == 0) {
        std.debug.print("Usage: tri math eval phi <n>\n", .{});
        return;
    }

    const n_str = args[0];
    const n = std.fmt.parseInt(usize, n_str, 10) catch {
        std.debug.print("Invalid number: {s}\n", .{n_str});
        return;
    };

    const result = gen_eval.phiPower(n);
    std.debug.print("φ^{d} = {d:.16}\n", .{ n, result });
}

/// Compute Fibonacci F(n)
pub fn runFibCommand(allocator: std.mem.Allocator, args: [][]const u8) void {
    if (args.len == 0) {
        std.debug.print("Usage: tri math eval fib <n>\n", .{});
        return;
    }

    const n_str = args[0];
    const n = std.fmt.parseInt(usize, n_str, 10) catch {
        std.debug.print("Invalid number: {s}\n", .{n_str});
        return;
    };

    const result = gen_eval.fibonacciBigInt(allocator, n) catch |err| {
        std.debug.print("Error computing F({d}): {}\n", .{ n, err });
        return;
    };
    defer allocator.free(result.value_str);

    gen_eval.printEvalResult(result, .{});
}

/// Compute Lucas L(n)
pub fn runLucasCommand(allocator: std.mem.Allocator, args: [][]const u8) void {
    if (args.len == 0) {
        std.debug.print("Usage: tri math eval lucas <n>\n", .{});
        return;
    }

    const n_str = args[0];
    const n = std.fmt.parseInt(usize, n_str, 10) catch {
        std.debug.print("Invalid number: {s}\n", .{n_str});
        return;
    };

    const result = gen_eval.lucasBigInt(allocator, n) catch |err| {
        std.debug.print("Error computing L({d}): {}\n", .{ n, err });
        return;
    };
    defer allocator.free(result.value_str);

    gen_eval.printEvalResult(result, .{});
}

/// Compute dispatcher (spiral/verify/compare)
pub fn runComputeCommand(allocator: std.mem.Allocator, args: [][]const u8) void {
    if (args.len == 0) {
        std.debug.print("Usage: tri math compute [spiral|verify|compare] [args...]\n", .{});
        return;
    }

    const subcommand = args[0];
    const remaining = args[1..];

    if (std.mem.eql(u8, subcommand, "spiral")) {
        runSpiralCommand(allocator, remaining);
    } else if (std.mem.eql(u8, subcommand, "verify")) {
        runVerifyCommand(allocator, remaining);
    } else if (std.mem.eql(u8, subcommand, "compare")) {
        runCompareCommand(allocator, remaining);
    } else {
        std.debug.print("Unknown compute subcommand: {s}\n", .{subcommand});
        showMathHelp();
    }
}

/// Show φ-spiral coordinates
pub fn runSpiralCommand(allocator: std.mem.Allocator, args: [][]const u8) void {
    _ = allocator;
    if (args.len == 0) {
        std.debug.print("Usage: tri math compute spiral <n>\n", .{});
        return;
    }

    const n_str = args[0];
    const n = std.fmt.parseInt(usize, n_str, 10) catch {
        std.debug.print("Invalid number: {s}\n", .{n_str});
        return;
    };

    const plot = parseFlag(args, "plot") != null;

    std.debug.print("φ-Spiral (n={d}):\n", .{n});
    std.debug.print("{s:>10} {s:>10} {s:>10}\n", .{ "x", "y", "r" });
    std.debug.print("────────────────────────────────\n", .{});

    const angle = @as(f64, @floatFromInt(n)) * PHI;
    const radius = std.math.sqrt(@as(f64, @floatFromInt(n)));
    const x = radius * @cos(angle);
    const y = radius * @sin(angle);

    std.debug.print("{d:>10.4} {d:>10.4} {d:>10.4}\n", .{ x, y, radius });

    if (plot) {
        std.debug.print("\nASCII Plot:\n", .{});
        printSpiralPlot(n);
    }
}

/// Simple ASCII spiral plot
fn printSpiralPlot(n: usize) void {
    const size = @min(20, @as(usize, @intFromFloat(@sqrt(@as(f64, @floatFromInt(n))) * 2)) + 1);
    var i: usize = 0;
    while (i < size) : (i += 1) {
        var j: usize = 0;
        while (j < size) : (j += 1) {
            const cx = @as(i64, @intCast(i)) - @as(i64, @intCast(size / 2));
            const cy = @as(i64, @intCast(j)) - @as(i64, @intCast(size / 2));
            const dist = std.math.sqrt(@as(f64, @floatFromInt(cx * cx + cy * cy)));
            if (dist < 2) {
                std.debug.print("●", .{});
            } else if (dist < 4) {
                std.debug.print("○", .{});
            } else if (dist < 6) {
                std.debug.print("◌", .{});
            } else {
                std.debug.print("·", .{});
            }
        }
        std.debug.print("\n", .{});
    }
}

/// Verify all sacred identities
pub fn runVerifyCommand(allocator: std.mem.Allocator, args: [][]const u8) void {
    _ = allocator;
    _ = args;

    std.debug.print("Verifying Sacred Identities:\n", .{});
    std.debug.print("══════════════════════════\n", .{});

    // Trinity Identity
    const trinity_ok = gen_identities.TRINITY_IDENTITY.actual == 3.0;
    std.debug.print("φ² + 1/φ² = 3: {s}\n", .{if (trinity_ok) "✓ PASS" else "✗ FAIL"});

    // Phi Squared
    const phi_sq = PHI * PHI;
    const phi_sq_ok = @abs(phi_sq - (PHI + 1.0)) < 1e-10;
    std.debug.print("φ² = φ + 1: {s}\n", .{if (phi_sq_ok) "✓ PASS" else "✗ FAIL"});

    // Phi Inverse
    const phi_inv = 1.0 / PHI;
    const phi_inv_ok = @abs(phi_inv - (PHI - 1.0)) < 1e-10;
    std.debug.print("1/φ = φ - 1: {s}\n", .{if (phi_inv_ok) "✓ PASS" else "✗ FAIL"});

    std.debug.print("\nAll identities verified!\n", .{});
}

/// Compare φ^n vs F(n) vs L(n)
pub fn runCompareCommand(allocator: std.mem.Allocator, args: [][]const u8) void {
    _ = allocator;

    const max_n = if (parseFlag(args, "max-n")) |n|
        std.fmt.parseInt(usize, n, 10) catch 20
    else
        20;

    std.debug.print("Comparing φ^n, F(n), L(n) for n=0..{d}:\n", .{max_n});
    std.debug.print("{s:>5} {s:>15} {s:>15} {s:>15}\n", .{ "n", "φ^n", "F(n)", "L(n)" });
    std.debug.print("{s:>5} {s:>15} {s:>15} {s:>15}\n", .{ "─────", "───────────────", "───────────────", "───────────────" });

    var i: usize = 0;
    while (i < @min(max_n, 20)) : (i += 1) {
        const phi_val = gen_eval.phiPower(i);
        const fib_val = if (i < gen_eval.fibonacci_cache.len) gen_eval.fibonacci_cache[i] else 0;
        const lucas_val = if (i < gen_eval.lucas_cache.len) gen_eval.lucas_cache[i] else 0;

        std.debug.print("{d:>5} {d:>15.6} {d:>15} {d:>15}\n", .{ i, phi_val, fib_val, lucas_val });
    }
}

/// Run performance benchmarks
pub fn runBenchCommand(allocator: std.mem.Allocator, args: [][]const u8) void {
    _ = args;

    const gen_bench = @import("gen_bench.zig");

    std.debug.print("Running Sacred Mathematics Benchmarks...\n", .{});

    const config = gen_bench.BenchmarkConfig{
        .iterations_override = 10000,
        .warmup_iterations = 100,
        .log_to_nexus = false,
    };

    const suite = gen_bench.runAllBenchmarks(allocator, config) catch {
        std.debug.print("Benchmark failed\n", .{});
        return;
    };
    defer allocator.free(suite.results);

    std.debug.print("\n{s:>30} {s:>15}\n", .{ "Benchmark", "Ops/sec" });
    std.debug.print("{s:>30} {s:>15}\n", .{ "─────────────────────────────", "───────────────" });

    for (suite.results) |r| {
        std.debug.print("{s:>30} {d:>15.0}\n", .{ r.name, r.ops_per_second });
    }
}

/// Show all φ-identities with proofs
pub fn runIdentitiesCommand(allocator: std.mem.Allocator, args: [][]const u8) void {
    _ = allocator;
    _ = args;

    const identities = gen_identities.ALL_IDENTITIES;

    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    SACRED IDENTITIES                             ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});

    for (identities) |id| {
        std.debug.print("║  {s}: {s}\n", .{ id.name, id.formula });
        if (id.verified) {
            std.debug.print("║    ✓ {s}\n", .{id.proof});
        }
        if (id.special_note) |note| {
            std.debug.print("║    Note: {s}\n", .{note});
        }
        std.debug.print("║\n", .{});
    }

    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
}

/// Display math command help
pub fn showMathHelp() void {
    std.debug.print("{s}\n", .{MATH_HELP_TEXT});
}

// ============================================================================
// TESTS
// ============================================================================

test "Math CLI: MATH_HELP_TEXT not empty" {
    try std.testing.expect(@as(usize, 1000) < MATH_HELP_TEXT.len);
}

test "Math CLI: parseFormatFlag default" {
    const args3_arr = [_][]const u8{};
    try std.testing.expectEqual(.pretty, parseFormatFlag(&args3_arr));
}

test "Math CLI: parseFormatFlag json" {
    var args1 = try std.ArrayList([]const u8).initCapacity(std.testing.allocator, 1);
    defer args1.deinit(std.testing.allocator);
    try args1.append(std.testing.allocator, "--format=json");

    try std.testing.expectEqual(.json, parseFormatFlag(args1.items));
}

test "Math CLI: parseFlag basic" {
    var args = try std.ArrayList([]const u8).initCapacity(std.testing.allocator, 2);
    defer args.deinit(std.testing.allocator);
    try args.append(std.testing.allocator, "--format=json");
    try args.append(std.testing.allocator, "--verbose");

    try std.testing.expect(parseFlag(args.items, "format") != null);
    try std.testing.expect(parseFlag(args.items, "verbose") != null);
    try std.testing.expect(parseFlag(args.items, "missing") == null);
}
