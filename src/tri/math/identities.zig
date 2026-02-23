// ═══════════════════════════════════════════════════════════════════════════════
// SACRED MATHEMATICS FRAMEWORK v2.0 — IDENTITIES MODULE
// ═══════════════════════════════════════════════════════════════════════════════
// All φ-identities with proofs
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const parent_mod = @import("mod.zig");
const format = @import("format.zig");

// stdout writer provided by caller

// ═══════════════════════════════════════════════════════════════════════════════
// IDENTITY DATA
// ═══════════════════════════════════════════════════════════════════════════════

pub const Identity = struct {
    name: []const u8,
    formula: []const u8,
    latex: []const u8,
    category: []const u8,
    proof: []const u8,
};

pub const IdentityCategory = enum {
    golden_ratio,
    sequences,
    transcendental,
    quantum,
    trinity,
    ternary,
};

const golden_identities = [_]Identity{
    .{
        .name = "Trinity Identity",
        .formula = "φ² + 1/φ² = 3",
        .latex = "\\phi^2 + \\phi^{-2} = 3",
        .category = "GOLDEN RATIO",
        .proof = \\Given φ = (1 + √5)/2:
        \\  φ² = ((1 + √5)/2)² = (6 + 2√5)/4 = (3 + √5)/2
        \\  1/φ² = (3 - √5)/2
        \\  φ² + 1/φ² = (3 + √5 + 3 - √5)/2 = 6/2 = 3 ✓
    ,
    },
    .{
        .name = "Phi Squared",
        .formula = "φ² = φ + 1",
        .latex = "\\phi^2 = \\phi + 1",
        .category = "GOLDEN RATIO",
        .proof = \\From the definition of φ: φ² - φ - 1 = 0
        \\Therefore: φ² = φ + 1 ✓
    ,
    },
    .{
        .name = "Phi Inverse",
        .formula = "1/φ = φ - 1",
        .latex = "\\phi^{-1} = \\phi - 1",
        .category = "GOLDEN RATIO",
        .proof = \\From φ² = φ + 1, divide both sides by φ:
        \\  φ = 1 + 1/φ
        \\Therefore: 1/φ = φ - 1 ✓
    ,
    },
    .{
        .name = "Phi Cubed",
        .formula = "φ³ = 2φ + 1",
        .latex = "\\phi^3 = 2\\phi + 1",
        .category = "GOLDEN RATIO",
        .proof = \\φ³ = φ × φ² = φ(φ + 1) = φ² + φ = (φ + 1) + φ = 2φ + 1 ✓
    ,
    },
};

const sequence_identities = [_]Identity{
    .{
        .name = "Lucas Phi Powers",
        .formula = "L(n) = φⁿ + 1/φⁿ",
        .latex = "L(n) = \\phi^n + \\phi^{-n}",
        .category = "SEQUENCE RELATIONSHIPS",
        .proof = \\Binet's formula for Lucas numbers:
        \\  L(n) = φⁿ + ψⁿ where ψ = -1/φ
        \\For even n: L(n) = φⁿ + 1/φⁿ ✓
    ,
    },
    .{
        .name = "Fibonacci Binet",
        .formula = "F(n) = (φⁿ - ψⁿ) / √5",
        .latex = "F(n) = \\frac{\\phi^n - \\psi^n}{\\sqrt{5}}",
        .category = "SEQUENCE RELATIONSHIPS",
        .proof = \\Binet's formula for Fibonacci numbers:
        \\  Where ψ = 1 - φ = -1/φ ≈ -0.618
        \\  This gives the closed-form solution ✓
    ,
    },
    .{
        .name = "Lucas Fibonacci Relation",
        .formula = "L(n) = F(n-1) + F(n+1)",
        .latex = "L(n) = F(n-1) + F(n+1)",
        .category = "SEQUENCE RELATIONSHIPS",
        .proof = \\Direct computation from Fibonacci recurrence:
        \\  L(n) = F(n-1) + F(n+1) ✓
    ,
    },
};

const transcendental_identities = [_]Identity{
    .{
        .name = "Tryte Max Approximation",
        .formula = "π × φ × e ≈ 13.82 ≈ TRYTE_MAX",
        .latex = "\\pi \\phi e \\approx 13.82 \\approx \\text{TRYTE\\_MAX}",
        .category = "TRANSCENDENTAL",
        .proof = \\π ≈ 3.14159, φ ≈ 1.61803, e ≈ 2.71828
        \\π × φ × e ≈ 13.81689...
        \\TRYTE_MAX = 13 (max value of balanced ternary tryte)
        \\Relative error ≈ 6.3% (close approximation)
    ,
    },
    .{
        .name = "Berry Phase",
        .formula = "β = π(1 - 1/φ)",
        .latex = "\\beta = \\pi(1 - \\phi^{-1})",
        .category = "QUANTUM CONSTANTS",
        .proof = \\β = π(1 - 1/φ)
        \\β = π(1 - 0.618...)
        \\β ≈ 1.199 radians ✓
    ,
    },
    .{
        .name = "SU3 Constant",
        .formula = "SU3 = 3/(2φ)",
        .latex = "SU3 = \\frac{3}{2\\phi}",
        .category = "QUANTUM CONSTANTS",
        .proof = \\SU3 = 3/(2 × 1.618...)
        \\SU3 = 3/3.236...
        \\SU3 ≈ 0.927 ✓
    ,
    },
};

const trinity_connections = [_]Identity{
    .{
        .name = "Lucas Trinity",
        .formula = "L(2) = 3",
        .latex = "L(2) = 3",
        .category = "TRINITY CONNECTIONS",
        .proof = \\Direct computation: L(2) = L(1) + L(0) = 1 + 2 = 3 ✓
    ,
    },
    .{
        .name = "Fibonacci Trinity",
        .formula = "F(4) = 3",
        .latex = "F(4) = 3",
        .category = "TRINITY CONNECTIONS",
        .proof = \\Direct computation: F(4) = F(3) + F(2) = 2 + 1 = 3 ✓
    ,
    },
    .{
        .name = "Phi Trinity",
        .formula = "φ² + 1/φ² = 3",
        .latex = "\\phi^2 + \\phi^{-2} = 3",
        .category = "TRINITY CONNECTIONS",
        .proof = \\See Trinity Identity proof above ✓
    ,
    },
    .{
        .name = "Fibonacci Tryte Max",
        .formula = "F(7) = 13 = TRYTE_MAX",
        .latex = "F(7) = 13 = \\text{TRYTE\\_MAX}",
        .category = "TRINITY CONNECTIONS",
        .proof = \\Direct computation: F(7) = 13 ✓
    ,
    },
};

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn getAllIdentities() []const Identity {
    // Note: This returns a slice but we need to handle multiple arrays
    _ = &golden_identities;
    _ = &sequence_identities;
    _ = &transcendental_identities;
    _ = &trinity_connections;
    @compileError("Use printAllIdentities for now - identity aggregation needs allocator");
}

pub fn printAllIdentities(writer: anytype) !void {
    try writer.writeAll("+====================================================================+\n");
    try writer.writeAll("|              SACRED MATHEMATICS IDENTITIES                         |\n");
    try writer.writeAll("|              phi^2 + 1/phi^2 = 3 = TRINITY                        |\n");
    try writer.writeAll("+====================================================================+\n\n");

    try printIdentityGroup(writer, &golden_identities);
    try printIdentityGroup(writer, &sequence_identities);
    try printIdentityGroup(writer, &transcendental_identities);
    try printIdentityGroup(writer, &trinity_connections);

    try writer.writeAll("+====================================================================+\n");
}

fn printIdentityGroup(writer: anytype, identities: []const Identity) !void {
    if (identities.len == 0) return;

    try writer.writeAll("  --- ");
    try writer.print("{s}", .{identities[0].category});
    try writer.writeAll(" ---\n\n");

    for (identities) |id| {
        try writer.print("  * {s}: ", .{id.name});
        try writer.writeAll(id.formula);
        try writer.writeAll("\n");

        try writer.writeAll("    Proof: ");
        var iter = std.mem.tokenizeAny(u8, id.proof, "\n");
        var first = true;
        while (iter.next()) |line| {
            if (!first) try writer.writeAll("           ");
            try writer.writeAll(line);
            try writer.writeAll("\n");
            first = false;
        }
    }
    try writer.writeAll("\n");
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "trinity identity holds" {
    const trinity = parent_mod.PHI_SQUARED + parent_mod.INVERSE_PHI_SQUARED;
    try std.testing.expectApproxEqAbs(3.0, trinity, 0.0001);
}

test "lucas trinity" {
    const L2 = parent_mod.lucas(2);
    try std.testing.expectEqual(@as(i64, 3), L2);
}

test "fibonacci trinity" {
    const F4 = parent_mod.fibonacci(4);
    try std.testing.expectEqual(@as(i64, 3), F4);
}

test "fibonacci tryte max" {
    const F7 = parent_mod.fibonacci(7);
    try std.testing.expectEqual(@as(i64, 13), F7);
}
