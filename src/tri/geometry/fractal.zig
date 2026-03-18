// ═══════════════════════════════════════════════════════════════════════════════
// SACRED GEOMETRY — FRACTAL GEOMETRY
// ═══════════════════════════════════════════════════════════════════════════════
// Sierpinski triangle (dim = bits/trit!), Koch snowflake, Cantor set,
// Mandelbrot set, Hausdorff dimension calculator.
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const mod = @import("mod.zig");
const fmt = @import("format.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

/// tri geom sierpinski [depth]
pub fn cmdSierpinski(args: []const []const u8) void {
    var depth: u32 = 4;
    if (args.len > 0) {
        depth = std.fmt.parseInt(u32, args[0], 10) catch 4;
    }
    if (depth > 6) {
        std.debug.print("  Capping depth at 6 (2^6 = 64 rows)\n", .{});
        depth = 6;
    }

    fmt.boxHeader("SIERPINSKI TRIANGLE");
    std.debug.print("\n", .{});

    printSierpinskiTriangle(depth);

    const triangles = pow3(depth);
    const scale = @as(u64, 1) << @intCast(depth);

    std.debug.print("\n", .{});
    fmt.sectionHeader("Properties");
    std.debug.print("  {s}Depth:{s}           {d}\n", .{ fmt.GRAY, fmt.RESET, depth });
    std.debug.print("  {s}Triangles:{s}       {d} (3^{d})\n", .{ fmt.GRAY, fmt.RESET, triangles, depth });
    std.debug.print("  {s}Scale:{s}           {d} (2^{d})\n", .{ fmt.GRAY, fmt.RESET, scale, depth });
    std.debug.print("  {s}Area ratio:{s}      (3/4)^{d} = {d:.10}\n", .{
        fmt.GRAY,
        fmt.RESET,
        depth,
        std.math.pow(f64, 0.75, @floatFromInt(depth)),
    });
    std.debug.print("  {s}Perimeter ratio:{s} (3/2)^{d} = {d:.6}\n", .{
        fmt.GRAY,
        fmt.RESET,
        depth,
        std.math.pow(f64, 1.5, @floatFromInt(depth)),
    });

    fmt.separator();
    std.debug.print("  {s}Hausdorff Dimension:{s}  {s}{d:.10}{s}\n", .{
        fmt.GOLD,
        fmt.RESET,
        fmt.CYAN,
        mod.SIERPINSKI_DIM,
        fmt.RESET,
    });
    std.debug.print("\n", .{});
    std.debug.print("  {s}KEY INSIGHT:{s}\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("  {s}log(3)/log(2) = 1.585 = bits per trit = log2(3){s}\n", .{ fmt.CYAN, fmt.RESET });
    std.debug.print("  {s}The Sierpinski triangle IS the geometry of ternary information.{s}\n", .{ fmt.WHITE, fmt.RESET });
    std.debug.print("  {s}3-fold self-similarity = ternary encoding = 1.585 bits/trit.{s}\n", .{ fmt.GRAY, fmt.RESET });

    fmt.boxFooter();
}

/// tri geom koch [depth]
pub fn cmdKoch(args: []const []const u8) void {
    var depth: u32 = 4;
    if (args.len > 0) {
        depth = std.fmt.parseInt(u32, args[0], 10) catch 4;
    }

    fmt.boxHeader("KOCH SNOWFLAKE");
    std.debug.print("\n", .{});

    const segments = 3 * std.math.pow(u64, 4, depth);
    const perimeter_ratio = std.math.pow(f64, 4.0 / 3.0, @floatFromInt(depth));
    // Area converges to 8/5 of original equilateral triangle
    // A_k = A_0 * (1 + sum_{i=0}^{k-1} 3*4^i / 9^{i+1})
    // Limit: A = (2*sqrt(3)/5) * s^2 for unit side
    const area_limit = 2.0 * mod.SQRT3 / 5.0;

    fmt.sectionHeader("Properties");
    std.debug.print("  Segments:          {d} (3 * 4^{d})\n", .{ segments, depth });
    std.debug.print("  Segment length:    (1/3)^{d} = {d:.10}\n", .{
        depth,
        std.math.pow(f64, 1.0 / 3.0, @floatFromInt(depth)),
    });
    std.debug.print("  Perimeter ratio:   (4/3)^{d} = {d:.6}  (-> infinity)\n", .{ depth, perimeter_ratio });
    std.debug.print("  Area limit:        {d:.10}  (finite!)\n", .{area_limit});
    std.debug.print("\n", .{});
    std.debug.print("  {s}Paradox: infinite perimeter enclosing finite area{s}\n", .{ fmt.CYAN, fmt.RESET });

    fmt.separator();
    std.debug.print("  {s}Hausdorff Dimension:{s}  {s}{d:.10}{s}\n", .{
        fmt.GOLD,
        fmt.RESET,
        fmt.CYAN,
        mod.KOCH_DIM,
        fmt.RESET,
    });
    std.debug.print("  {s}D = log(4)/log(3)  —  4 copies at 1/3 scale{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}Each iteration divides segments into 3 parts (ternary subdivision){s}\n", .{ fmt.GRAY, fmt.RESET });

    fmt.boxFooter();
}

/// tri geom cantor [depth]
pub fn cmdCantor(args: []const []const u8) void {
    var depth: u32 = 5;
    if (args.len > 0) {
        depth = std.fmt.parseInt(u32, args[0], 10) catch 5;
    }
    if (depth > 7) depth = 7;

    fmt.boxHeader("CANTOR SET — The Ternary Fractal");
    std.debug.print("\n", .{});

    printCantorSet(depth);

    std.debug.print("\n", .{});
    fmt.sectionHeader("Properties");
    std.debug.print("  Intervals:         {d} (2^{d})\n", .{ @as(u64, 1) << @intCast(depth), depth });
    std.debug.print("  Total length:      (2/3)^{d} = {d:.10}  (-> 0)\n", .{
        depth,
        std.math.pow(f64, 2.0 / 3.0, @floatFromInt(depth)),
    });

    fmt.separator();
    std.debug.print("  {s}Hausdorff Dimension:{s}  {s}{d:.10}{s}\n", .{
        fmt.GOLD,
        fmt.RESET,
        fmt.CYAN,
        mod.CANTOR_DIM,
        fmt.RESET,
    });
    std.debug.print("  {s}D = log(2)/log(3)  —  2 copies at 1/3 scale{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("\n", .{});
    std.debug.print("  {s}KEY:{s} The Cantor set = numbers in [0,1] whose base-3 expansion\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("  uses only digits 0 and 2 (no 1s). It lives natively in ternary!\n", .{});

    fmt.boxFooter();
}

/// tri geom fractal-dim <N> <r>
pub fn cmdFractalDim(args: []const []const u8) void {
    if (args.len < 2) {
        std.debug.print("Usage: tri geom fractal-dim <N> <r>\n", .{});
        std.debug.print("  N = number of self-similar copies\n", .{});
        std.debug.print("  r = scaling factor (magnification ratio)\n", .{});
        std.debug.print("  D = log(N)/log(r) = Hausdorff dimension\n", .{});
        std.debug.print("\n  Examples:\n", .{});
        std.debug.print("    tri geom fractal-dim 3 2    Sierpinski triangle  -> 1.585\n", .{});
        std.debug.print("    tri geom fractal-dim 4 3    Koch curve           -> 1.262\n", .{});
        std.debug.print("    tri geom fractal-dim 2 3    Cantor set           -> 0.631\n", .{});
        std.debug.print("    tri geom fractal-dim 8 3    Sierpinski carpet    -> 1.893\n", .{});
        std.debug.print("    tri geom fractal-dim 20 3   Menger sponge        -> 2.727\n", .{});
        return;
    }

    const n = std.fmt.parseFloat(f64, args[0]) catch {
        std.debug.print("Invalid N: {s}\n", .{args[0]});
        return;
    };
    const r = std.fmt.parseFloat(f64, args[1]) catch {
        std.debug.print("Invalid r: {s}\n", .{args[1]});
        return;
    };

    if (n <= 0 or r <= 1) {
        std.debug.print("N must be > 0 and r must be > 1\n", .{});
        return;
    }

    const dim = mod.hausdorffDimension(n, r);

    fmt.boxHeader("HAUSDORFF DIMENSION CALCULATOR");
    std.debug.print("\n", .{});
    std.debug.print("  N (copies):        {d:.4}\n", .{n});
    std.debug.print("  r (scale factor):  {d:.4}\n", .{r});
    fmt.separator();
    std.debug.print("  {s}D = log(N)/log(r) = {d:.10}{s}\n", .{ fmt.CYAN, dim, fmt.RESET });
    std.debug.print("\n", .{});

    // Compare to known fractals
    fmt.sectionHeader("Known Fractal Dimensions");
    std.debug.print("  {s}{s: <22} {s: >5} {s: >5} {s: >12}{s}\n", .{
        fmt.GOLD, "Fractal", "N", "r", "Dimension", fmt.RESET,
    });
    std.debug.print("  {s}---------------------- ----- ----- ------------{s}\n", .{ fmt.GRAY, fmt.RESET });

    const known = [_]struct { name: []const u8, n: f64, r: f64, dim: f64 }{
        .{ .name = "Cantor set", .n = 2, .r = 3, .dim = mod.CANTOR_DIM },
        .{ .name = "Koch curve", .n = 4, .r = 3, .dim = mod.KOCH_DIM },
        .{ .name = "Sierpinski triangle", .n = 3, .r = 2, .dim = mod.SIERPINSKI_DIM },
        .{ .name = "Sierpinski carpet", .n = 8, .r = 3, .dim = 1.8927892607143728 },
        .{ .name = "Menger sponge", .n = 20, .r = 3, .dim = 2.7268330278608417 },
    };

    for (known) |k| {
        const marker: []const u8 = if (@abs(dim - k.dim) < 0.001) " <--" else "";
        std.debug.print("  {s: <22} {d: >5.0} {d: >5.0} {d: >12.10}{s}{s}\n", .{
            k.name, k.n, k.r, k.dim, marker, fmt.RESET,
        });
    }

    fmt.boxFooter();
}

/// tri geom mandelbrot
pub fn cmdMandelbrot() void {
    fmt.boxHeader("MANDELBROT SET  —  z(n+1) = z(n)^2 + c");
    std.debug.print("\n", .{});

    const width: usize = 70;
    const height: usize = 22;
    const max_iter: u32 = 50;
    const chars = " .:-=+*#%@";

    var y: usize = 0;
    while (y < height) : (y += 1) {
        std.debug.print("  ", .{});
        var x: usize = 0;
        while (x < width) : (x += 1) {
            const cr = -2.0 + 2.5 * @as(f64, @floatFromInt(x)) / @as(f64, @floatFromInt(width));
            const ci = -1.1 + 2.2 * @as(f64, @floatFromInt(y)) / @as(f64, @floatFromInt(height));
            var zr: f64 = 0;
            var zi: f64 = 0;
            var iter: u32 = 0;
            while (iter < max_iter) : (iter += 1) {
                const zr2 = zr * zr - zi * zi + cr;
                const zi2 = 2.0 * zr * zi + ci;
                zr = zr2;
                zi = zi2;
                if (zr * zr + zi * zi > 4.0) break;
            }
            if (iter == max_iter) {
                std.debug.print("{s}*{s}", .{ fmt.GOLD, fmt.RESET });
            } else {
                const idx = iter % chars.len;
                std.debug.print("{c}", .{chars[idx]});
            }
        }
        std.debug.print("\n", .{});
    }

    std.debug.print("\n", .{});
    fmt.sectionHeader("Properties");
    std.debug.print("  Iteration:         z(n+1) = z(n)^2 + c, z(0) = 0\n", .{});
    std.debug.print("  Escape:            |z| > 2 => diverges\n", .{});
    std.debug.print("  Boundary dim:      {s}2.0 (exact){s} — Shishikura 1998\n", .{ fmt.CYAN, fmt.RESET });
    std.debug.print("  Main cardioid:     c = 0\n", .{});
    std.debug.print("  Period-2 bulb:     c = -1\n", .{});
    std.debug.print("  Feigenbaum point:  c = -1.401155...\n", .{});
    std.debug.print("  {s}Legend:{s} {s}*{s}=in set, .:-=+*#%%@=escape time\n", .{
        fmt.GRAY,
        fmt.RESET,
        fmt.GOLD,
        fmt.RESET,
    });

    fmt.boxFooter();
}

// ═══════════════════════════════════════════════════════════════════════════════
// RENDERING
// ═══════════════════════════════════════════════════════════════════════════════

/// Render Sierpinski triangle using Pascal's triangle mod 2
fn printSierpinskiTriangle(depth: u32) void {
    const height: u32 = @as(u32, 1) << @intCast(depth);

    var row: u32 = 0;
    while (row < height) : (row += 1) {
        // Leading spaces for centering
        var s: u32 = 0;
        while (s < height - row - 1) : (s += 1) {
            std.debug.print(" ", .{});
        }

        // Use bit tricks: position (row, col) is filled iff (row & col) == col
        // (equivalent to Pascal's triangle mod 2)
        var col: u32 = 0;
        while (col <= row) : (col += 1) {
            if ((row & col) == col) {
                std.debug.print("{s}*{s} ", .{ fmt.CYAN, fmt.RESET });
            } else {
                std.debug.print("  ", .{});
            }
        }
        std.debug.print("\n", .{});
    }
}

/// Render Cantor set as ASCII bars
fn printCantorSet(depth: u32) void {
    const width: u32 = pow3_u32(depth);
    // Cap display width
    const display_width: u32 = if (width > 81) 81 else width;

    var level: u32 = 0;
    while (level <= depth) : (level += 1) {
        std.debug.print("  ", .{});
        const segment_size = pow3_u32(depth - level);
        var pos: u32 = 0;
        while (pos < display_width) : (pos += 1) {
            // A position is in the Cantor set at this level if
            // none of its base-3 "digits" (at the relevant scales) equal 1
            if (isCantorPoint(pos, level, segment_size)) {
                std.debug.print("{s}={s}", .{ fmt.CYAN, fmt.RESET });
            } else {
                std.debug.print(" ", .{});
            }
        }
        std.debug.print("  level {d}\n", .{level});
    }
}

fn isCantorPoint(pos: u32, level: u32, segment_size: u32) bool {
    if (level == 0) return true;
    // Check each ternary "digit" at the relevant scales
    var remaining: u32 = level;
    var seg = segment_size * 3;
    while (remaining > 0) : (remaining -= 1) {
        const third = seg / 3;
        if (third == 0) return true;
        const digit = (pos % seg) / third;
        if (digit == 1) return false;
        seg = third;
    }
    return true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn pow3(exp: u32) u64 {
    return std.math.pow(u64, 3, exp);
}

fn pow3_u32(exp: u32) u32 {
    var result: u32 = 1;
    var i: u32 = 0;
    while (i < exp) : (i += 1) {
        result *= 3;
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "sierpinski dimension" {
    const dim = mod.hausdorffDimension(3.0, 2.0);
    try std.testing.expectApproxEqAbs(mod.SIERPINSKI_DIM, dim, 1e-10);
}

test "koch dimension" {
    const dim = mod.hausdorffDimension(4.0, 3.0);
    try std.testing.expectApproxEqAbs(mod.KOCH_DIM, dim, 1e-10);
}

test "cantor dimension" {
    const dim = mod.hausdorffDimension(2.0, 3.0);
    try std.testing.expectApproxEqAbs(mod.CANTOR_DIM, dim, 1e-10);
}

test "pow3" {
    try std.testing.expectEqual(@as(u64, 1), pow3(0));
    try std.testing.expectEqual(@as(u64, 3), pow3(1));
    try std.testing.expectEqual(@as(u64, 27), pow3(3));
    try std.testing.expectEqual(@as(u64, 243), pow3(5));
}
