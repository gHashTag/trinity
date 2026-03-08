// ============================================================================
// TRANSCENDENTAL NUMBERS CATALOG — Trinity Constants
// ============================================================================
// Systematic catalog of transcendental numbers arising from Trinity's
// four constants (3, phi, pi, e). All proofs follow from classical theorems:
// Hermite (1873), Lindemann (1882), Lindemann-Weierstrass (1885),
// Gelfond-Schneider (1934), Nesterenko (1996).
// ============================================================================

const std = @import("std");
const math = std.math;

const PHI: f64 = 1.6180339887498948482;
const INV_PHI: f64 = 1.0 / PHI;
const PHI_SQ: f64 = PHI * PHI;
const INV_PHI_SQ: f64 = 1.0 / PHI_SQ;
const SQRT5: f64 = math.sqrt(5.0);

pub const Theorem = enum {
    gelfond_schneider,
    lindemann_weierstrass,
    transcendental_arithmetic,
    nesterenko,
};

pub const Category = enum {
    power, // a^b (Gelfond-Schneider)
    exponential, // e^alpha (L-W)
    logarithm, // ln(alpha) (L-W)
    trigonometric, // sin/cos(alpha) (L-W)
    arithmetic, // T +- alpha, T * alpha (Lemma)
    nesterenko, // pi, e^pi algebraically independent
};

pub const TranscendentalEntry = struct {
    name: []const u8,
    value: f64,
    theorem: Theorem,
    category: Category,
    proof: []const u8,
};

// All Trinity transcendentals, computed at comptime
pub const catalog = [_]TranscendentalEntry{
    // === Gelfond-Schneider: a^b (a alg !=0,1; b alg irrational) ===
    .{ .name = "3^phi", .value = 5.91559, .theorem = .gelfond_schneider, .category = .power, .proof = "a=3 alg, b=phi alg irr" },
    .{ .name = "3^(1/phi)", .value = 1.97186, .theorem = .gelfond_schneider, .category = .power, .proof = "a=3, b=1/phi=(sqrt5-1)/2 alg irr" },
    .{ .name = "3^(phi^2)", .value = 17.74678, .theorem = .gelfond_schneider, .category = .power, .proof = "a=3, b=phi^2=(3+sqrt5)/2 alg irr" },
    .{ .name = "3^(1/phi^2)", .value = 1.52140, .theorem = .gelfond_schneider, .category = .power, .proof = "a=3, b=1/phi^2=(3-sqrt5)/2 alg irr" },
    .{ .name = "3^sqrt5", .value = 11.66475, .theorem = .gelfond_schneider, .category = .power, .proof = "a=3, b=sqrt5 alg irr" },
    .{ .name = "phi^phi", .value = 2.17846, .theorem = .gelfond_schneider, .category = .power, .proof = "a=phi alg !=0,1; b=phi alg irr" },
    .{ .name = "phi^(1/phi)", .value = 1.34636, .theorem = .gelfond_schneider, .category = .power, .proof = "a=phi, b=1/phi alg irr" },
    .{ .name = "phi^(phi^2)", .value = 3.52482, .theorem = .gelfond_schneider, .category = .power, .proof = "a=phi, b=phi^2 alg irr" },
    .{ .name = "phi^sqrt3", .value = 2.30132, .theorem = .gelfond_schneider, .category = .power, .proof = "a=phi, b=sqrt3 alg irr" },
    .{ .name = "phi^sqrt5", .value = 2.93299, .theorem = .gelfond_schneider, .category = .power, .proof = "a=phi, b=sqrt5 alg irr" },
    .{ .name = "2^phi", .value = 3.06956, .theorem = .gelfond_schneider, .category = .power, .proof = "a=2, b=phi alg irr" },
    .{ .name = "5^phi", .value = 13.51939, .theorem = .gelfond_schneider, .category = .power, .proof = "a=5, b=phi alg irr" },
    .{ .name = "7^phi", .value = 23.30222, .theorem = .gelfond_schneider, .category = .power, .proof = "a=7, b=phi alg irr" },

    // === Lindemann-Weierstrass: e^alpha (alpha alg != 0) ===
    .{ .name = "e^phi", .value = 5.04317, .theorem = .lindemann_weierstrass, .category = .exponential, .proof = "alpha=phi alg !=0" },
    .{ .name = "e^(1/phi)", .value = 1.85528, .theorem = .lindemann_weierstrass, .category = .exponential, .proof = "alpha=1/phi alg !=0" },
    .{ .name = "e^(phi^2)", .value = 13.70875, .theorem = .lindemann_weierstrass, .category = .exponential, .proof = "alpha=phi^2=phi+1 alg !=0" },
    .{ .name = "e^(3*phi)", .value = 128.26545, .theorem = .lindemann_weierstrass, .category = .exponential, .proof = "alpha=3phi alg !=0" },
    .{ .name = "e^(phi/3)", .value = 1.71488, .theorem = .lindemann_weierstrass, .category = .exponential, .proof = "alpha=phi/3 alg !=0" },
    .{ .name = "e^sqrt5", .value = 9.35647, .theorem = .lindemann_weierstrass, .category = .exponential, .proof = "alpha=sqrt5 alg !=0" },
    .{ .name = "e^(3+phi)", .value = 101.29469, .theorem = .lindemann_weierstrass, .category = .exponential, .proof = "alpha=3+phi alg !=0" },
    .{ .name = "e^(3-phi)", .value = 3.98272, .theorem = .lindemann_weierstrass, .category = .exponential, .proof = "alpha=3-phi alg !=0" },
    .{ .name = "e^(3/phi)", .value = 6.38596, .theorem = .lindemann_weierstrass, .category = .exponential, .proof = "alpha=3/phi alg !=0" },

    // === Lindemann-Weierstrass: ln(alpha) (alpha alg != 0, 1) ===
    .{ .name = "ln(3)", .value = 1.09861, .theorem = .lindemann_weierstrass, .category = .logarithm, .proof = "alpha=3 alg !=0,1" },
    .{ .name = "ln(phi)", .value = 0.48121, .theorem = .lindemann_weierstrass, .category = .logarithm, .proof = "alpha=phi alg !=0,1" },
    .{ .name = "ln(phi^2)", .value = 0.96242, .theorem = .lindemann_weierstrass, .category = .logarithm, .proof = "alpha=phi^2 alg !=0,1" },
    .{ .name = "ln(3*phi)", .value = 1.57982, .theorem = .lindemann_weierstrass, .category = .logarithm, .proof = "alpha=3phi alg !=0,1" },

    // === Lindemann-Weierstrass: sin/cos(alpha) (alpha alg != 0) ===
    .{ .name = "sin(phi)", .value = 0.99888, .theorem = .lindemann_weierstrass, .category = .trigonometric, .proof = "alpha=phi alg !=0" },
    .{ .name = "cos(phi)", .value = -0.04722, .theorem = .lindemann_weierstrass, .category = .trigonometric, .proof = "alpha=phi alg !=0" },
    .{ .name = "sin(3)", .value = 0.14112, .theorem = .lindemann_weierstrass, .category = .trigonometric, .proof = "alpha=3 alg !=0" },
    .{ .name = "cos(3)", .value = -0.98999, .theorem = .lindemann_weierstrass, .category = .trigonometric, .proof = "alpha=3 alg !=0" },
    .{ .name = "sin(1/phi)", .value = 0.57943, .theorem = .lindemann_weierstrass, .category = .trigonometric, .proof = "alpha=1/phi alg !=0" },
    .{ .name = "cos(1/phi)", .value = 0.81502, .theorem = .lindemann_weierstrass, .category = .trigonometric, .proof = "alpha=1/phi alg !=0" },
    .{ .name = "sin(sqrt5)", .value = 0.78675, .theorem = .lindemann_weierstrass, .category = .trigonometric, .proof = "alpha=sqrt5 alg !=0" },

    // === Transcendental Arithmetic: T op alpha ===
    .{ .name = "pi+phi", .value = 4.75963, .theorem = .transcendental_arithmetic, .category = .arithmetic, .proof = "pi transc + phi alg" },
    .{ .name = "pi-phi", .value = 1.52356, .theorem = .transcendental_arithmetic, .category = .arithmetic, .proof = "pi transc - phi alg" },
    .{ .name = "pi*phi", .value = 5.08320, .theorem = .transcendental_arithmetic, .category = .arithmetic, .proof = "pi transc * phi alg !=0" },
    .{ .name = "pi/phi", .value = 1.94161, .theorem = .transcendental_arithmetic, .category = .arithmetic, .proof = "pi transc / phi alg !=0" },
    .{ .name = "pi*phi^2", .value = 8.22480, .theorem = .transcendental_arithmetic, .category = .arithmetic, .proof = "pi transc * phi^2 alg !=0" },
    .{ .name = "e+phi", .value = 4.33632, .theorem = .transcendental_arithmetic, .category = .arithmetic, .proof = "e transc + phi alg" },
    .{ .name = "e+3", .value = 5.71828, .theorem = .transcendental_arithmetic, .category = .arithmetic, .proof = "e transc + 3 alg" },
    .{ .name = "pi+3", .value = 6.14159, .theorem = .transcendental_arithmetic, .category = .arithmetic, .proof = "pi transc + 3 alg" },
    .{ .name = "e*phi", .value = 4.39827, .theorem = .transcendental_arithmetic, .category = .arithmetic, .proof = "e transc * phi alg !=0" },
    .{ .name = "e*3", .value = 8.15485, .theorem = .transcendental_arithmetic, .category = .arithmetic, .proof = "e transc * 3 alg !=0" },
    .{ .name = "e/phi", .value = 1.67999, .theorem = .transcendental_arithmetic, .category = .arithmetic, .proof = "e transc / phi alg !=0" },
    .{ .name = "pi*3phi", .value = 15.24961, .theorem = .transcendental_arithmetic, .category = .arithmetic, .proof = "pi transc * 3phi alg !=0" },

    // === Nesterenko: pi, e^pi algebraically independent ===
    .{ .name = "pi+e^pi", .value = 26.28228, .theorem = .nesterenko, .category = .nesterenko, .proof = "pi,e^pi alg indep (Nesterenko 1996)" },
    .{ .name = "pi*e^pi", .value = 72.69863, .theorem = .nesterenko, .category = .nesterenko, .proof = "pi,e^pi alg indep (Nesterenko 1996)" },
    .{ .name = "pi^2+e^pi", .value = 33.01029, .theorem = .nesterenko, .category = .nesterenko, .proof = "pi,e^pi alg indep (Nesterenko 1996)" },
    .{ .name = "e^pi-pi", .value = 19.99910, .theorem = .nesterenko, .category = .nesterenko, .proof = "pi,e^pi alg indep (Nesterenko 1996)" },
    .{ .name = "e^pi/pi", .value = 7.36591, .theorem = .nesterenko, .category = .nesterenko, .proof = "pi,e^pi alg indep (Nesterenko 1996)" },
};

fn theoremName(t: Theorem) []const u8 {
    return switch (t) {
        .gelfond_schneider => "Gelfond-Schneider (1934)",
        .lindemann_weierstrass => "Lindemann-Weierstrass (1885)",
        .transcendental_arithmetic => "Transc. Arithmetic Lemma",
        .nesterenko => "Nesterenko (1996)",
    };
}

fn categoryName(c: Category) []const u8 {
    return switch (c) {
        .power => "a^b",
        .exponential => "e^alpha",
        .logarithm => "ln(alpha)",
        .trigonometric => "sin/cos",
        .arithmetic => "T op alpha",
        .nesterenko => "Nesterenko",
    };
}

pub fn printCatalog(writer: anytype) !void {
    try writer.print(
        \\+====================================================================+
        \\|           TRANSCENDENTAL NUMBERS — Trinity Catalog                 |
        \\|  Classical theorems applied to constants 3, phi, pi, e            |
        \\+====================================================================+
        \\
        \\
    , .{});

    try writer.print("  {s:<20} {s:>12}  {s:<30}  {s}\n", .{ "NUMBER", "VALUE", "THEOREM", "PROOF" });
    try writer.print("  {s:-<20} {s:->12}  {s:-<30}  {s:-<30}\n", .{ "", "", "", "" });

    for (catalog) |entry| {
        try writer.print("  {s:<20} {d:>12.5}  {s:<30}  {s}\n", .{
            entry.name,
            entry.value,
            theoremName(entry.theorem),
            entry.proof,
        });
    }

    try writer.print("\n  Total: {d} entries ({d} Gelfond-Schneider, {d} Lindemann-Weierstrass, {d} Arithmetic, {d} Nesterenko)\n", .{
        catalog.len,
        countByTheorem(.gelfond_schneider),
        countByTheorem(.lindemann_weierstrass),
        countByTheorem(.transcendental_arithmetic),
        countByTheorem(.nesterenko),
    });

    try writer.print(
        \\
        \\  Note: All results are direct applications of classical theorems.
        \\  n^phi is transcendental for every integer n >= 2 (infinite family).
        \\+====================================================================+
        \\
    , .{});
}

pub fn printByCategory(writer: anytype, cat: Category) !void {
    try writer.print("\n  Category: {s}\n", .{categoryName(cat)});
    try writer.print("  {s:-<60}\n", .{""});

    for (catalog) |entry| {
        if (entry.category == cat) {
            try writer.print("  {s:<20} = {d:.5}  ({s})\n", .{ entry.name, entry.value, entry.proof });
        }
    }
}

pub fn computeNPhi(writer: anytype, n: u32) !void {
    if (n < 2) {
        try writer.print("  Error: n must be >= 2 (n=0,1 give trivial results)\n", .{});
        return;
    }
    const nf: f64 = @floatFromInt(n);
    const result = math.pow(f64, nf, PHI);
    try writer.print(
        \\
        \\  {d}^phi = {d}^{d:.10} = {d:.10}
        \\
        \\  Transcendental by Gelfond-Schneider:
        \\    a = {d} (algebraic, != 0, != 1)
        \\    b = phi = (1+sqrt5)/2 (algebraic, irrational)
        \\    => {d}^phi is transcendental. QED
        \\
    , .{ n, n, PHI, result, n, n });
}

pub fn printOpenProblems(writer: anytype) !void {
    try writer.print(
        \\
        \\+====================================================================+
        \\|              OPEN PROBLEMS (NOT proven transcendental)             |
        \\+====================================================================+
        \\
        \\  NUMBER                VALUE         STATUS
        \\  ──────────────────── ──────────── ──────────────────────────────────
        \\  pi^e                 22.45916      Unknown (G-S/L-W don't apply)
        \\  3^pi                 31.54428      Unknown (pi not algebraic)
        \\  pi + e                5.85987      Unknown (one of pi+e, pi*e is)
        \\  pi * e                8.53973      Unknown
        \\  e^e                  15.15426      Unknown
        \\  gamma (Euler)         0.57722      Not even proven irrational
        \\  Catalan G             0.91597      Not proven
        \\  Feigenbaum delta      4.66920      Not proven
        \\  zeta(3) (Apery)       1.20206      Irrational, transcendence unknown
        \\  zeta(5)               1.03693      Open
        \\
        \\  Proving any of these would be a major mathematical breakthrough.
        \\+====================================================================+
        \\
    , .{});
}

fn countByTheorem(t: Theorem) usize {
    var count: usize = 0;
    for (catalog) |entry| {
        if (entry.theorem == t) count += 1;
    }
    return count;
}

// ============================================================================
// TESTS
// ============================================================================

test "catalog size" {
    try std.testing.expect(catalog.len >= 50);
}

test "3^phi value" {
    try std.testing.expectApproxEqAbs(math.pow(f64, 3.0, PHI), 5.91559, 0.001);
}

test "phi^phi value" {
    try std.testing.expectApproxEqAbs(math.pow(f64, PHI, PHI), 2.17846, 0.001);
}

test "e^phi value" {
    try std.testing.expectApproxEqAbs(@exp(PHI), 5.04317, 0.001);
}

test "ln(phi) value" {
    try std.testing.expectApproxEqAbs(@log(PHI), 0.48121, 0.001);
}

test "sin(phi) value" {
    try std.testing.expectApproxEqAbs(@sin(PHI), 0.99888, 0.001);
}

test "pi+phi value" {
    try std.testing.expectApproxEqAbs(math.pi + PHI, 4.75963, 0.001);
}
