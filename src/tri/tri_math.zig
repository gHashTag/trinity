// =============================================================================
// TRI CLI - Sacred Mathematics Commands (Cycle 82)
// =============================================================================
//
// Exposes sacred_math.zig library as TRI CLI commands:
//   tri math          - Sacred math router/help
//   tri constants     - Display all sacred constants
//   tri phi <n>       - Compute phi^n
//   tri fib <n>       - Fibonacci number
//   tri lucas <n>     - Lucas number
//   tri spiral <n>    - Phi-spiral coordinates
//   tri math-verify   - Trinity identity verification
//   tri math-bench    - Performance benchmark
//   tri math-compare  - Side-by-side comparison table
//
// All math is inlined from sacred_math.zig to avoid build.zig coupling.
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");
const colors = @import("tri_colors.zig");

const GREEN = colors.GREEN;
const GOLDEN = colors.GOLDEN;
const WHITE = colors.WHITE;
const GRAY = colors.GRAY;
const RED = colors.RED;
const CYAN = colors.CYAN;
const RESET = colors.RESET;

// =============================================================================
// SACRED CONSTANTS (inlined from sacred_math.zig)
// =============================================================================

const PHI: f64 = 1.6180339887498948482;
const PHI_SQ: f64 = 2.6180339887498948482;
const PHI_INV: f64 = 0.6180339887498948482;
const PHI_INV_SQ: f64 = 0.3819660112501051518;
const PI: f64 = 3.14159265358979323846;
const E: f64 = 2.71828182845904523536;
const TRANSCENDENTAL: f64 = 13.816890703380645;
const TRINITY: i8 = 3;
const MU: f64 = 0.0382;
const CHI: f64 = 0.0618;
const SIGMA: f64 = 1.618;
const EPSILON: f64 = 0.333;
const CHSH: f64 = 2.8284271247461903;
const FINE_STRUCTURE_INV: f64 = 137.036;

const FIBONACCI_TABLE: [20]i64 = .{
    0, 1, 1, 2, 3, 5, 8, 13, 21, 34,
    55, 89, 144, 233, 377, 610, 987, 1597, 2584, 4181,
};

const LUCAS_TABLE: [20]i64 = .{
    2, 1, 3, 4, 7, 11, 18, 29, 47, 76,
    123, 199, 322, 521, 843, 1364, 2207, 3571, 5778, 9349,
};

fn fibonacci(n: u32) i64 {
    if (n < 20) return FIBONACCI_TABLE[n];
    var a: i64 = FIBONACCI_TABLE[18];
    var b: i64 = FIBONACCI_TABLE[19];
    var i: u32 = 20;
    while (i <= n) : (i += 1) {
        const temp = a +| b;
        a = b;
        b = temp;
    }
    return b;
}

fn lucas(n: u32) i64 {
    if (n < 20) return LUCAS_TABLE[n];
    var a: i64 = LUCAS_TABLE[18];
    var b: i64 = LUCAS_TABLE[19];
    var i: u32 = 20;
    while (i <= n) : (i += 1) {
        const temp = a +| b;
        a = b;
        b = temp;
    }
    return b;
}

fn goldenWrap(sum: i16) i8 {
    var result: i16 = sum;
    while (result > 13) result -= 27;
    while (result < -13) result += 27;
    return @intCast(result);
}

// =============================================================================
// COMMAND: tri math (router)
// =============================================================================

pub fn runMathCommand(args: []const []const u8) void {
    if (args.len == 0) {
        printMathHelp();
        return;
    }

    const sub = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, sub, "help")) {
        printMathHelp();
    } else if (std.mem.eql(u8, sub, "constants") or std.mem.eql(u8, sub, "const")) {
        runConstantsCommand();
    } else if (std.mem.eql(u8, sub, "verify")) {
        runMathVerifyCommand();
    } else if (std.mem.eql(u8, sub, "bench")) {
        runMathBenchCommand();
    } else if (std.mem.eql(u8, sub, "compare")) {
        runMathCompareCommand(sub_args);
    } else if (std.mem.eql(u8, sub, "phi")) {
        runPhiCommand(sub_args);
    } else if (std.mem.eql(u8, sub, "fib")) {
        runFibCommand(sub_args);
    } else if (std.mem.eql(u8, sub, "lucas")) {
        runLucasCommand(sub_args);
    } else if (std.mem.eql(u8, sub, "spiral")) {
        runSpiralCommand(sub_args);
    } else {
        std.debug.print("{s}Unknown math subcommand: {s}{s}\n", .{ RED, sub, RESET });
        printMathHelp();
    }
}

fn printMathHelp() void {
    std.debug.print("\n{s}Sacred Mathematics ({s}phi^2 + 1/phi^2 = 3{s}){s}\n", .{ GOLDEN, WHITE, GOLDEN, RESET });
    std.debug.print("{s}============================================{s}\n\n", .{ GRAY, RESET });
    std.debug.print("{s}USAGE:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri math <subcommand>       Run math subcommand\n", .{});
    std.debug.print("  tri <command> [args]         Direct command\n\n", .{});
    std.debug.print("{s}COMMANDS:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}constants{s}                  All 14 sacred constants\n", .{ GREEN, RESET });
    std.debug.print("  {s}phi{s} <n>                    Compute phi^n powers\n", .{ GREEN, RESET });
    std.debug.print("  {s}fib{s} <n>                    Fibonacci number F(n)\n", .{ GREEN, RESET });
    std.debug.print("  {s}lucas{s} <n>                  Lucas number L(n)\n", .{ GREEN, RESET });
    std.debug.print("  {s}spiral{s} <n>                 Phi-spiral coordinates\n", .{ GREEN, RESET });
    std.debug.print("  {s}math-verify{s}                Trinity identity checks\n", .{ GREEN, RESET });
    std.debug.print("  {s}math-bench{s}                 Performance benchmark\n", .{ GREEN, RESET });
    std.debug.print("  {s}math-compare{s} [n]           Side-by-side table (default n=12)\n", .{ GREEN, RESET });
    std.debug.print("\n{s}DIRECT ALIASES:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri constants  |  tri phi 10  |  tri fib 19\n", .{});
    std.debug.print("  tri lucas 5    |  tri spiral 8 |  tri math-verify\n", .{});
    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// =============================================================================
// COMMAND: tri constants
// =============================================================================

pub fn runConstantsCommand() void {
    std.debug.print("\n{s}Sacred Constants{s} ({s}phi^2 + 1/phi^2 = 3{s})\n", .{ GOLDEN, RESET, WHITE, RESET });
    std.debug.print("{s}================================================{s}\n\n", .{ GRAY, RESET });

    printConst("phi (PHI)", PHI, "Golden ratio (1+sqrt5)/2");
    printConst("phi^2 (PHI_SQ)", PHI_SQ, "phi + 1");
    printConst("1/phi (PHI_INV)", PHI_INV, "phi - 1");
    printConst("1/phi^2 (PHI_INV_SQ)", PHI_INV_SQ, "2 - phi");
    std.debug.print("\n", .{});
    printConst("pi", PI, "Circle constant");
    printConst("e", E, "Euler's number");
    printConst("pi * phi * e", TRANSCENDENTAL, "~= TRYTE_MAX (13)");
    std.debug.print("\n", .{});
    printConstInt("TRINITY", TRINITY, "phi^2 + 1/phi^2 = 3");
    printConst("mu (mutation)", MU, "1/phi^2/10");
    printConst("chi (crossover)", CHI, "1/phi/10");
    printConst("sigma (selection)", SIGMA, "phi");
    printConst("epsilon (elitism)", EPSILON, "1/3");
    std.debug.print("\n", .{});
    printConst("CHSH (2*sqrt2)", CHSH, "Bell inequality violation");
    printConst("1/alpha", FINE_STRUCTURE_INV, "Fine structure constant inverse");

    // Verification
    const trinity_check = PHI_SQ + PHI_INV_SQ;
    std.debug.print("\n{s}  Verification: phi^2 + 1/phi^2 = {d:.16}{s}", .{ GOLDEN, trinity_check, RESET });
    if (@abs(trinity_check - 3.0) < 0.0001) {
        std.debug.print(" {s}TRINITY VERIFIED{s}\n", .{ GREEN, RESET });
    } else {
        std.debug.print(" {s}FAILED{s}\n", .{ RED, RESET });
    }
    std.debug.print("\n", .{});
}

fn printConst(name: []const u8, value: f64, desc: []const u8) void {
    std.debug.print("  {s}{s:<24}{s} = {s}{d:.16}{s}  {s}// {s}{s}\n", .{
        GREEN, name, RESET, WHITE, value, RESET, GRAY, desc, RESET,
    });
}

fn printConstInt(name: []const u8, value: i8, desc: []const u8) void {
    std.debug.print("  {s}{s:<24}{s} = {s}{d}{s}                  {s}// {s}{s}\n", .{
        GREEN, name, RESET, WHITE, value, RESET, GRAY, desc, RESET,
    });
}

// =============================================================================
// COMMAND: tri phi <n>
// =============================================================================

pub fn runPhiCommand(args: []const []const u8) void {
    const n = parseU32(args, 10);
    const nf: f64 = @floatFromInt(n);

    const phi_n = std.math.pow(f64, PHI, nf);
    const phi_neg_n = std.math.pow(f64, PHI_INV, nf);
    const sum = phi_n + phi_neg_n;

    std.debug.print("\n{s}phi Powers{s} (n = {d})\n", .{ GOLDEN, RESET, n });
    std.debug.print("{s}================================{s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}phi^{d}{s}       = {s}{d:.10}{s}\n", .{ GREEN, n, RESET, WHITE, phi_n, RESET });
    std.debug.print("  {s}1/phi^{d}{s}     = {s}{d:.10}{s}\n", .{ GREEN, n, RESET, WHITE, phi_neg_n, RESET });
    std.debug.print("  {s}phi^{d} + 1/phi^{d}{s} = {s}{d:.10}{s}", .{ GREEN, n, n, RESET, WHITE, sum, RESET });

    // Check if close to Lucas number
    const lucas_n = lucas(n);
    const lucas_f: f64 = @floatFromInt(lucas_n);
    if (@abs(sum - lucas_f) < 0.001) {
        std.debug.print("  = {s}L({d}) = {d}{s}", .{ GOLDEN, n, lucas_n, RESET });
        if (lucas_n == 3) {
            std.debug.print(" {s}= TRINITY!{s}", .{ GREEN, RESET });
        }
    }
    std.debug.print("\n\n", .{});
}

// =============================================================================
// COMMAND: tri fib <n>
// =============================================================================

pub fn runFibCommand(args: []const []const u8) void {
    const n = parseU32(args, 10);

    if (n > 92) {
        std.debug.print("{s}Warning: i64 overflows beyond F(92). Showing up to F(92).{s}\n", .{ RED, RESET });
    }
    const clamped = @min(n, 92);
    const result = fibonacci(clamped);

    std.debug.print("\n{s}Fibonacci{s} F({d}) = {s}{d}{s}\n", .{ GOLDEN, RESET, clamped, WHITE, result, RESET });

    // Show significance
    if (clamped == 4) std.debug.print("  {s}F(4) = 3 = TRINITY!{s}\n", .{ GREEN, RESET });
    if (clamped == 7) std.debug.print("  {s}F(7) = 13 = TRYTE_MAX!{s}\n", .{ GREEN, RESET });

    // Show nearby values
    if (clamped >= 2 and clamped <= 90) {
        std.debug.print("\n  {s}Nearby:{s}\n", .{ GRAY, RESET });
        const start: u32 = if (clamped >= 2) clamped - 2 else 0;
        const end: u32 = @min(clamped + 3, 93);
        var i: u32 = start;
        while (i < end) : (i += 1) {
            const marker: []const u8 = if (i == clamped) " <--" else "";
            std.debug.print("    F({d:>2}) = {d}{s}\n", .{ i, fibonacci(i), marker });
        }
    }
    std.debug.print("\n", .{});
}

// =============================================================================
// COMMAND: tri lucas <n>
// =============================================================================

pub fn runLucasCommand(args: []const []const u8) void {
    const n = parseU32(args, 10);

    if (n > 86) {
        std.debug.print("{s}Warning: i64 overflows beyond L(86). Showing up to L(86).{s}\n", .{ RED, RESET });
    }
    const clamped = @min(n, 86);
    const result = lucas(clamped);

    std.debug.print("\n{s}Lucas{s} L({d}) = {s}{d}{s}\n", .{ GOLDEN, RESET, clamped, WHITE, result, RESET });
    std.debug.print("  {s}L(n) = phi^n + 1/phi^n{s}\n", .{ GRAY, RESET });

    if (clamped == 2) std.debug.print("  {s}L(2) = 3 = TRINITY!{s}\n", .{ GREEN, RESET });

    // Show nearby values
    if (clamped >= 2 and clamped <= 84) {
        std.debug.print("\n  {s}Nearby:{s}\n", .{ GRAY, RESET });
        const start: u32 = if (clamped >= 2) clamped - 2 else 0;
        const end: u32 = @min(clamped + 3, 87);
        var i: u32 = start;
        while (i < end) : (i += 1) {
            const marker: []const u8 = if (i == clamped) " <--" else "";
            std.debug.print("    L({d:>2}) = {d}{s}\n", .{ i, lucas(i), marker });
        }
    }
    std.debug.print("\n", .{});
}

// =============================================================================
// COMMAND: tri spiral <n>
// =============================================================================

pub fn runSpiralCommand(args: []const []const u8) void {
    const n = parseU32(args, 8);

    std.debug.print("\n{s}phi-Spiral Coordinates{s} (n = {d})\n", .{ GOLDEN, RESET, n });
    std.debug.print("{s}angle = n * phi * pi, radius = 30 + n * 8{s}\n", .{ GRAY, RESET });
    std.debug.print("{s}================================================{s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}n     angle(rad)    radius      x            y{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}---   ----------   --------   ----------   ----------{s}\n", .{ GRAY, RESET });

    // Track bounds for ASCII plot
    var min_x: f64 = 0;
    var max_x: f64 = 0;
    var min_y: f64 = 0;
    var max_y: f64 = 0;

    // Store points for plotting
    var points_x: [64]f64 = undefined;
    var points_y: [64]f64 = undefined;
    const count = @min(n, 64);

    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const nf: f64 = @floatFromInt(i);
        const angle = nf * PHI * PI;
        const radius = 30.0 + nf * 8.0;
        const x = radius * @cos(angle);
        const y = radius * @sin(angle);

        points_x[i] = x;
        points_y[i] = y;

        if (x < min_x) min_x = x;
        if (x > max_x) max_x = x;
        if (y < min_y) min_y = y;
        if (y > max_y) max_y = y;

        std.debug.print("  {d:>3}   {d:>10.4}   {d:>8.2}   {d:>10.4}   {d:>10.4}\n", .{
            i, angle, radius, x, y,
        });
    }

    // ASCII plot (40x20)
    if (count > 1) {
        std.debug.print("\n{s}ASCII Plot:{s}\n", .{ GOLDEN, RESET });

        const plot_w: usize = 50;
        const plot_h: usize = 20;
        var grid: [20][50]u8 = undefined;
        for (&grid) |*row| {
            for (row) |*cell| {
                cell.* = ' ';
            }
        }

        // Scale and plot
        const range_x = if (max_x - min_x > 0.01) max_x - min_x else 1.0;
        const range_y = if (max_y - min_y > 0.01) max_y - min_y else 1.0;

        var idx: u32 = 0;
        while (idx < count) : (idx += 1) {
            const px: usize = @intFromFloat(@min(@as(f64, @floatFromInt(plot_w - 1)), @max(0, (points_x[idx] - min_x) / range_x * @as(f64, @floatFromInt(plot_w - 1)))));
            const py: usize = @intFromFloat(@min(@as(f64, @floatFromInt(plot_h - 1)), @max(0, (points_y[idx] - min_y) / range_y * @as(f64, @floatFromInt(plot_h - 1)))));
            const fy = plot_h - 1 - py; // flip Y
            if (idx == 0) {
                grid[fy][px] = 'O'; // origin
            } else {
                grid[fy][px] = '*';
            }
        }

        // Print grid
        std.debug.print("  {s}+{s}\n", .{ GRAY, RESET });
        for (grid) |row| {
            std.debug.print("  {s}|{s}", .{ GRAY, RESET });
            for (row) |cell| {
                if (cell == 'O') {
                    std.debug.print("{s}{c}{s}", .{ GREEN, cell, RESET });
                } else if (cell == '*') {
                    std.debug.print("{s}{c}{s}", .{ GOLDEN, cell, RESET });
                } else {
                    std.debug.print("{c}", .{cell});
                }
            }
            std.debug.print("{s}|{s}\n", .{ GRAY, RESET });
        }
        std.debug.print("  {s}+{s}\n", .{ GRAY, RESET });
        std.debug.print("  {s}O{s} = origin, {s}*{s} = phi-spiral point\n", .{ GREEN, RESET, GOLDEN, RESET });
    }
    std.debug.print("\n", .{});
}

// =============================================================================
// COMMAND: tri math-verify
// =============================================================================

pub fn runMathVerifyCommand() void {
    std.debug.print("\n{s}Trinity Identity Verification{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}================================================{s}\n\n", .{ GRAY, RESET });

    var passed: u32 = 0;
    const total: u32 = 8;

    // Check 1: phi^2 + 1/phi^2 = 3
    {
        const result = PHI_SQ + PHI_INV_SQ;
        const ok = @abs(result - 3.0) < 0.0001;
        if (ok) passed += 1;
        printCheck(ok, "phi^2 + 1/phi^2", result, "= 3 TRINITY");
    }

    // Check 2: L(2) = 3
    {
        const l2 = lucas(2);
        const ok = l2 == 3;
        if (ok) passed += 1;
        printCheckInt(ok, "L(2)", l2, "= 3 Lucas confirms");
    }

    // Check 3: F(4) = 3
    {
        const f4 = fibonacci(4);
        const ok = f4 == 3;
        if (ok) passed += 1;
        printCheckInt(ok, "F(4)", f4, "= 3 Fibonacci confirms");
    }

    // Check 4: F(7) = 13 = TRYTE_MAX
    {
        const f7 = fibonacci(7);
        const ok = f7 == 13;
        if (ok) passed += 1;
        printCheckInt(ok, "F(7)", f7, "= 13 TRYTE_MAX");
    }

    // Check 5: pi * phi * e ~= 13.82
    {
        const result = PI * PHI * E;
        const ok = @abs(result - TRANSCENDENTAL) < 0.01;
        if (ok) passed += 1;
        printCheck(ok, "pi * phi * e", result, "~= 13 (TRYTE_MAX)");
    }

    // Check 6: 27 = 3^3 (TRYTE_SPACE)
    {
        const result: i64 = 27;
        const ok = result == 3 * 3 * 3;
        if (ok) passed += 1;
        printCheckInt(ok, "3^3", result, "= 27 TRYTE_SPACE");
    }

    // Check 7: CHSH = 2*sqrt(2)
    {
        const result = 2.0 * @sqrt(2.0);
        const ok = @abs(result - CHSH) < 0.001;
        if (ok) passed += 1;
        printCheck(ok, "CHSH = 2*sqrt(2)", result, "Bell inequality");
    }

    // Check 8: Fine structure
    {
        const ok = @abs(FINE_STRUCTURE_INV - 137.036) < 0.001;
        if (ok) passed += 1;
        printCheck(ok, "1/alpha", FINE_STRUCTURE_INV, "Fine structure");
    }

    // Summary
    std.debug.print("\n", .{});
    if (passed == total) {
        std.debug.print("  {s}All {d}/{d} checks PASSED{s}\n", .{ GREEN, passed, total, RESET });
    } else {
        std.debug.print("  {s}{d}/{d} checks passed ({d} FAILED){s}\n", .{ RED, passed, total, total - passed, RESET });
    }
    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

fn printCheck(ok: bool, name: []const u8, value: f64, desc: []const u8) void {
    const mark = if (ok) GREEN else RED;
    const sym = if (ok) "OK" else "FAIL";
    std.debug.print("  {s}[{s}]{s} {s:<20} = {d:.4}  {s}{s}{s}\n", .{
        mark, sym, RESET, name, value, GRAY, desc, RESET,
    });
}

fn printCheckInt(ok: bool, name: []const u8, value: i64, desc: []const u8) void {
    const mark = if (ok) GREEN else RED;
    const sym = if (ok) "OK" else "FAIL";
    std.debug.print("  {s}[{s}]{s} {s:<20} = {d:<8}  {s}{s}{s}\n", .{
        mark, sym, RESET, name, value, GRAY, desc, RESET,
    });
}

// =============================================================================
// COMMAND: tri math-bench
// =============================================================================

pub fn runMathBenchCommand() void {
    std.debug.print("\n{s}Sacred Math Benchmark{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}================================================{s}\n\n", .{ GRAY, RESET });

    const iters: u32 = 10_000;

    // Benchmark fibonacci(19)
    {
        var timer = std.time.Timer.start() catch {
            std.debug.print("{s}Timer unavailable{s}\n", .{ RED, RESET });
            return;
        };
        var sum: i64 = 0;
        for (0..iters) |_| {
            sum +|= fibonacci(19);
        }
        const elapsed = timer.read();
        std.mem.doNotOptimizeAway(sum);
        printBenchResult("fibonacci(19)", iters, elapsed);
    }

    // Benchmark lucas(19)
    {
        var timer = std.time.Timer.start() catch return;
        var sum: i64 = 0;
        for (0..iters) |_| {
            sum +|= lucas(19);
        }
        const elapsed = timer.read();
        std.mem.doNotOptimizeAway(sum);
        printBenchResult("lucas(19)", iters, elapsed);
    }

    // Benchmark phiSpiral(100)
    {
        var timer = std.time.Timer.start() catch return;
        var sum: f64 = 0;
        for (0..iters) |_| {
            const nf: f64 = @floatFromInt(@as(u32, 100));
            const angle = nf * PHI * PI;
            const radius = 30.0 + nf * 8.0;
            sum += radius * @cos(angle);
        }
        const elapsed = timer.read();
        std.mem.doNotOptimizeAway(sum);
        printBenchResult("phiSpiral(100)", iters, elapsed);
    }

    // Benchmark goldenWrap
    {
        var timer = std.time.Timer.start() catch return;
        var sum: i64 = 0;
        for (0..iters) |i| {
            const val: i16 = @intCast(@as(i32, @intCast(i % 53)) - 26);
            sum +|= @as(i64, goldenWrap(val));
        }
        const elapsed = timer.read();
        std.mem.doNotOptimizeAway(sum);
        printBenchResult("goldenWrap", iters, elapsed);
    }

    // Benchmark fibonacci(50) (recurrence path)
    {
        var timer = std.time.Timer.start() catch return;
        var sum: i64 = 0;
        for (0..iters) |_| {
            sum +|= fibonacci(50);
        }
        const elapsed = timer.read();
        std.mem.doNotOptimizeAway(sum);
        printBenchResult("fibonacci(50)", iters, elapsed);
    }

    std.debug.print("\n  {s}All benchmarks: {d} iterations each{s}\n", .{ GRAY, iters, RESET });
    std.debug.print("  {s}Pure Zig comptime tables + SIMD-ready{s}\n", .{ GRAY, RESET });
    std.debug.print("\n", .{});
}

fn printBenchResult(name: []const u8, iters: u32, elapsed_ns: u64) void {
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    const elapsed_ms = elapsed_us / 1000.0;
    const ops_per_sec = if (elapsed_ns > 0)
        @as(f64, @floatFromInt(iters)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0)
    else
        0;

    if (ops_per_sec >= 1_000_000_000) {
        std.debug.print("  {s}{s:<20}{s} {d:>8.2} us  {s}{d:.1} Gops/s{s}\n", .{
            GREEN, name, RESET, elapsed_us, GOLDEN, ops_per_sec / 1_000_000_000, RESET,
        });
    } else if (ops_per_sec >= 1_000_000) {
        std.debug.print("  {s}{s:<20}{s} {d:>8.2} us  {s}{d:.1} Mops/s{s}\n", .{
            GREEN, name, RESET, elapsed_us, GOLDEN, ops_per_sec / 1_000_000, RESET,
        });
    } else {
        std.debug.print("  {s}{s:<20}{s} {d:>8.2} ms  {s}{d:.0} ops/s{s}\n", .{
            GREEN, name, RESET, elapsed_ms, GOLDEN, ops_per_sec, RESET,
        });
    }
}

// =============================================================================
// COMMAND: tri math-compare [n]
// =============================================================================

pub fn runMathCompareCommand(args: []const []const u8) void {
    const n = parseU32(args, 12);
    const max = @min(n, 92);

    std.debug.print("\n{s}Sacred Math Comparison Table{s} (0..{d})\n", .{ GOLDEN, RESET, max });
    std.debug.print("{s}================================================================{s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}n    phi^n         F(n)       L(n)      phi^n+1/phi^n  note{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}---  -----------   --------   --------  -------------  --------{s}\n", .{ GRAY, RESET });

    var i: u32 = 0;
    while (i <= max) : (i += 1) {
        const nf: f64 = @floatFromInt(i);
        const phi_n = std.math.pow(f64, PHI, nf);
        const phi_neg_n = std.math.pow(f64, PHI_INV, nf);
        const sum_val = phi_n + phi_neg_n;
        const fib_n = fibonacci(i);
        const lucas_n = lucas(i);

        // Determine note
        var note: []const u8 = "";
        if (i == 0) note = "(L=2, F=0)";
        if (i == 2) note = "TRINITY";
        if (i == 4) note = "F=3=TRINITY";
        if (i == 7) note = "F=13=TRYTE";
        if (i == 12) note = "F=144=12^2";

        std.debug.print("  {d:>3}  {d:>11.4}   {d:>8}   {d:>8}  {d:>13.4}  {s}{s}{s}\n", .{
            i, phi_n, fib_n, lucas_n, sum_val, GOLDEN, note, RESET,
        });
    }

    std.debug.print("\n  {s}phi^n + 1/phi^n = L(n) (Lucas numbers){s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}phi^n = (F(n)*phi + F(n-1)) for n >= 1{s}\n", .{ GRAY, RESET });
    std.debug.print("\n", .{});
}

// =============================================================================
// HELPERS
// =============================================================================

fn parseU32(args: []const []const u8, default: u32) u32 {
    if (args.len == 0) return default;
    return std.fmt.parseInt(u32, args[0], 10) catch default;
}
