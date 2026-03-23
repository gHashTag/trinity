//! Strand I: Mathematical Foundation
//!
//! Sacred mathematics module for Trinity S³AI.
//!

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED MATHEMATICS FRAMEWORK v2.0 — CONSTANTS MODULE
// ═══════════════════════════════════════════════════════════════════════════════
// All sacred constants with Trinity verification
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const parent_mod = @import("mod.zig");
const format = @import("format.zig");

pub const ColorStyle = format.ColorStyle;
pub const colors = format.colors;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANT ENTRIES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ConstantEntry = struct {
    name: []const u8,
    symbol: []const u8,
    value: []const u8,
    formula: []const u8,
    description: []const u8,
};

pub const ConstantGroup = struct {
    name: []const u8,
    color: []const u8,
    constants: []const ConstantEntry,
};

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANT DATA
// ═══════════════════════════════════════════════════════════════════════════════

const golden_ratio_consts = [_]ConstantEntry{
    .{
        .name = "Golden Ratio",
        .symbol = "φ",
        .value = "1.6180339887498948482",
        .formula = "(1 + √5) / 2",
        .description = "Divine proportion",
    },
    .{
        .name = "Phi Squared",
        .symbol = "φ²",
        .value = "2.6180339887498948482",
        .formula = "φ² = φ + 1",
        .description = "Phi squared",
    },
    .{
        .name = "Inverse Phi Squared",
        .symbol = "1/φ²",
        .value = "0.3819660112501051518",
        .formula = "1/φ² = φ - 1",
        .description = "Inverse phi squared",
    },
    .{
        .name = "Trinity Sum",
        .symbol = "φ² + 1/φ²",
        .value = "3.0",
        .formula = "φ² + 1/φ² = 3",
        .description = "TRINITY IDENTITY — exact equality",
    },
};

const transcendental_consts = [_]ConstantEntry{
    .{
        .name = "Pi",
        .symbol = "π",
        .value = "3.14159265358979323846",
        .formula = "C / d",
        .description = "Circle constant",
    },
    .{
        .name = "Euler's Number",
        .symbol = "e",
        .value = "2.71828182845904523536",
        .formula = "lim(n→∞) (1 + 1/n)ⁿ",
        .description = "Natural log base",
    },
    .{
        .name = "Transcendental Product",
        .symbol = "π × φ × e",
        .value = "13.816890703380645",
        .formula = "π × φ × e",
        .description = "≈ TRYTE_MAX (13)",
    },
};

const genetic_consts = [_]ConstantEntry{
    .{
        .name = "Mu",
        .symbol = "μ",
        .value = "0.0382",
        .formula = "1/φ²/10",
        .description = "Mutation rate",
    },
    .{
        .name = "Chi",
        .symbol = "χ",
        .value = "0.0618",
        .formula = "1/φ/10",
        .description = "Crossover rate",
    },
    .{
        .name = "Sigma",
        .symbol = "σ",
        .value = "1.618",
        .formula = "φ",
        .description = "Selection pressure",
    },
    .{
        .name = "Epsilon",
        .symbol = "ε",
        .value = "0.333",
        .formula = "1/3",
        .description = "Elitism rate",
    },
};

const quantum_consts = [_]ConstantEntry{
    .{
        .name = "CHSH Inequality",
        .symbol = "CHSH",
        .value = "2.8284271247461903",
        .formula = "2√2",
        .description = "Bell inequality violation",
    },
    .{
        .name = "Fine Structure Inverse",
        .symbol = "α⁻¹",
        .value = "137.036",
        .formula = "4π³ + π² + π",
        .description = "Fine structure constant",
    },
    .{
        .name = "Berry Phase",
        .symbol = "β",
        .value = "2.112",
        .formula = "π(1 - 1/φ)",
        .description = "Quantum-inspired phase",
    },
    .{
        .name = "SU3 Constant",
        .symbol = "SU3",
        .value = "0.927",
        .formula = "3/(2φ)",
        .description = "Energy harvesting constant",
    },
};

const groups = [_]ConstantGroup{
    .{ .name = "GOLDEN RATIO", .color = colors.gold, .constants = &golden_ratio_consts },
    .{ .name = "TRANSCENDENTAL", .color = colors.cyan, .constants = &transcendental_consts },
    .{ .name = "GENETIC ALGORITHM", .color = colors.yellow, .constants = &genetic_consts },
    .{ .name = "QUANTUM", .color = colors.purple, .constants = &quantum_consts },
};

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn getAllGroups() []const ConstantGroup {
    return &groups;
}

pub fn printAllConstants(writer: anytype) !void {
    try writer.writeAll("\n");
    try writer.writeAll("+=======================================================================+\n");
    try writer.writeAll("|                    SACRED MATHEMATICS CONSTANTS                       |\n");
    try writer.writeAll("|                    phi^2 + 1/phi^2 = 3 = TRINITY                     |\n");
    try writer.writeAll("+=======================================================================+\n");
    try writer.writeAll("\n");

    for (groups) |group| {
        try writer.writeAll("  --- ");
        try writer.print("{s}", .{group.name});
        try writer.writeAll(" ---\n\n");

        for (group.constants) |const_| {
            try writer.writeAll("    ");
            try writer.print("{s}", .{const_.name});
            try writer.writeAll(" (");
            try writer.print("{s}", .{const_.symbol});
            try writer.writeAll(")\n");
            try writer.writeAll("      Value:   ");
            try writer.print("{s}", .{const_.value});
            try writer.writeAll("\n");
            try writer.writeAll("      Formula: ");
            try writer.print("{s}", .{const_.formula});
            try writer.writeAll("\n");
            try writer.writeAll("      ");
            try writer.print("{s}", .{const_.description});
            try writer.writeAll("\n\n");
        }
    }

    try writer.writeAll("+=======================================================================+\n");
    try writer.writeAll("|  Trit: -1  0  +1  |  Base: 3  |  phi = 1.6180339...                 |\n");
    try writer.writeAll("|  mu = 0.0382  |  chi = 0.0618  |  sigma = phi  |  epsilon = 1/3     |\n");
    try writer.writeAll("|  Lucas: 2, 1, 3, 4, 7, 11, 18, 29, 47, 76, 123                     |\n");
    try writer.writeAll("+=======================================================================+\n");
    try writer.writeAll("\n");
}

pub fn verifyTrinityIdentity() bool {
    const trinity = parent_mod.PHI_SQUARED + parent_mod.INVERSE_PHI_SQUARED;
    return std.math.approxEqAbs(f64, trinity, 3.0, 0.0001);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "trinity identity" {
    try std.testing.expect(verifyTrinityIdentity());
}
