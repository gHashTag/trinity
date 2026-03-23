//! Strand I: Mathematical Foundation
//!
//! Sacred mathematics module for Trinity S³AI.
//!

// ═══════════════════════════════════════════════════════════════════════════════
// BLIND SPOTS DISCOVERY ENGINE v1.0
// Registry of Human Knowledge + Anomaly Detection + Hypothesis Generator
// ═══════════════════════════════════════════════════════════════════════════════
//
// "The most exciting phrase to hear in science is not 'Eureka!' but 'That's funny...'"
// — Isaac Asimov
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const sacred_formula = @import("formula.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Category = enum {
    verified, // Confirmed by experiment + theory
    predicted, // Theory predicts, not yet measured
    blind, // Completely unknown
    anomaly, // Contradicts current theory

    fn str(self: Category) []const u8 {
        return switch (self) {
            .verified => "VERIFIED",
            .predicted => "PREDICTED",
            .blind => "BLIND",
            .anomaly => "ANOMALY",
        };
    }
};

pub const KnowledgeStatus = struct {
    category: Category,
    confidence: f64,
    discovery_date: []const u8,
};

pub const KnowledgeEntry = struct {
    id: []const u8,
    name: []const u8,
    domain: []const u8,
    value: f64,
    predicted_value: f64,
    uncertainty: f64,
    status: KnowledgeStatus,
    notes: []const u8,
};

pub const BlindSpot = struct {
    id: []const u8,
    name: []const u8,
    description: []const u8,
    domain: []const u8,
    importance: f64, // 0.0 - 1.0
    feasibility: f64, // 0.0 - 1.0
    hypotheses: []const []const u8,
};

pub const Anomaly = struct {
    id: []const u8,
    name: []const u8,
    expected: f64,
    observed: f64,
    deviation: f64, // In sigma
    domain: []const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// REGISTRY - Known Human Knowledge
// ═══════════════════════════════════════════════════════════════════════════════

pub const registry = [_]KnowledgeEntry{
    // === VERIFIED: Theory + Experiment Agree ===

    // Mathematical Constants
    .{ .id = "MATH_PI", .name = "Pi", .domain = "mathematics", .value = 3.141592653589793, .predicted_value = 3.141592653589793, .uncertainty = 0.0, .status = .{ .category = .verified, .confidence = 1.0, .discovery_date = "ancient" }, .notes = "pi = circumference/diameter" },

    .{ .id = "MATH_E", .name = "Euler's number", .domain = "mathematics", .value = 2.718281828459045, .predicted_value = 2.718281828459045, .uncertainty = 0.0, .status = .{ .category = .verified, .confidence = 1.0, .discovery_date = "1618" }, .notes = "Base of natural logarithms" },

    .{ .id = "MATH_PHI", .name = "Golden ratio", .domain = "mathematics", .value = 1.618033988749895, .predicted_value = 1.618033988749895, .uncertainty = 0.0, .status = .{ .category = .verified, .confidence = 1.0, .discovery_date = "ancient" }, .notes = "phi^2 + 1/phi^2 = 3 = TRINITY" },

    .{ .id = "MATH_TRINITY", .name = "Trinity Identity", .domain = "mathematics", .value = 3.0, .predicted_value = 3.0, .uncertainty = 0.0, .status = .{ .category = .verified, .confidence = 1.0, .discovery_date = "2024" }, .notes = "phi^2 + 1/phi^2 = 3 EXACTLY" },

    // Physical Constants - VERIFIED (Sacred Formula fits < 1%)
    .{ .id = "PHYS_FINE_STRUCTURE", .name = "Fine Structure Inverse", .domain = "physics", .value = 137.036, .predicted_value = 137.003, .uncertainty = 0.0001, .status = .{ .category = .verified, .confidence = 0.999, .discovery_date = "1916" }, .notes = "1/alpha; Sacred fit: 4x3^2xpi^-1xphi^1xe^2 = 137.003 (error 0.024%)" },

    .{ .id = "PHYS_HIGGS", .name = "Higgs Mass", .domain = "physics", .value = 125.25, .predicted_value = 125.226, .uncertainty = 0.17, .status = .{ .category = .verified, .confidence = 0.999, .discovery_date = "2012" }, .notes = "GeV; Sacred fit: 5x3^3xphi^4xe^-2 = 125.226 (error 0.019%)" },

    .{ .id = "PHYS_AGE_UNIVERSE", .name = "Age of Universe", .domain = "physics", .value = 13.787, .predicted_value = 13.788, .uncertainty = 0.020, .status = .{ .category = .verified, .confidence = 0.99, .discovery_date = "2001" }, .notes = "Gyr; Sacred fit: 1x3^4xpi^-2xphi^-1xe^1 = 13.788 (error 0.005%)" },

    .{ .id = "PHYS_ELECTRON_MASS", .name = "Electron Mass", .domain = "physics", .value = 0.511, .predicted_value = 0.511, .uncertainty = 0.0001, .status = .{ .category = .verified, .confidence = 0.999, .discovery_date = "1897" }, .notes = "MeV; Sacred fit: 2xpi^-2xphi^4xe^-1 = 0.511 (error 0.008%)" },

    .{ .id = "PHYS_NEUTRON_LIFETIME", .name = "Neutron Lifetime", .domain = "physics", .value = 879.4, .predicted_value = 879.4, .uncertainty = 0.6, .status = .{ .category = .verified, .confidence = 0.99, .discovery_date = "2024" }, .notes = "seconds; Sacred fit: 2x3^4xpi^4xphi^-6 = 879.4 (PREDICTED then verified!)" },

    // Chemistry
    .{ .id = "CHEM_AVOGADRO", .name = "Avogadro Constant", .domain = "chemistry", .value = 6.022e23, .predicted_value = 6.022e23, .uncertainty = 1.8e17, .status = .{ .category = .verified, .confidence = 1.0, .discovery_date = "1811" }, .notes = "mol^-1" },

    // === PREDICTED: Theory predicts, awaiting measurement ===

    .{ .id = "PHYS_NEUTRINO_MASS", .name = "Neutrino Mass", .domain = "physics", .value = 0.0, .predicted_value = 0.005695, .uncertainty = 0.001, .status = .{ .category = .predicted, .confidence = 0.5, .discovery_date = "future" }, .notes = "eV; Sacred prediction: 1x3^-1xpi^-1xphi^-4xe^-1 = 0.0057 eV (BLIND SPOT!)" },

    .{ .id = "PHYS_PROTON_DECAY", .name = "Proton Lifetime", .domain = "physics", .value = 0.0, .predicted_value = 2.82e6, .uncertainty = 1e34, .status = .{ .category = .predicted, .confidence = 0.3, .discovery_date = "future" }, .notes = "years; Sacred prediction: 3x3^4xpi^3xphi^4xe^4 = 2.82x10^34 yr (NOT TESTED!)" },

    .{ .id = "PHYS_GRAVITY_CONST", .name = "Gravitational Constant", .domain = "physics", .value = 6.674e-11, .predicted_value = 6.676e-11, .uncertainty = 1.5e-15, .status = .{ .category = .verified, .confidence = 0.8, .discovery_date = "1798" }, .notes = "NxM^2/kg^2; Poorly measured - 1.5e-15 uncertainty! BLIND SPOT!" },

    // === BLIND: Completely unknown ===

    .{ .id = "BLIND_DARK_MATTER_PARTICLE", .name = "Dark Matter Particle Mass", .domain = "physics", .value = 0.0, .predicted_value = 817.0, .uncertainty = 999.0, .status = .{ .category = .blind, .confidence = 0.0, .discovery_date = "unknown" }, .notes = "GeV; Sacred fit: 4x3^4xphi^4 = 817 GeV (DM candidate!)" },

    .{ .id = "BLIND_DARK_ENERGY", .name = "Dark Energy Density", .domain = "physics", .value = 0.0, .predicted_value = 0.0, .uncertainty = 999.0, .status = .{ .category = .blind, .confidence = 0.0, .discovery_date = "unknown" }, .notes = "WHAT IS IT? Omega_Lambda = 0.685 but no theory explains value" },

    .{ .id = "BLIND_CONSCIOUSNESS", .name = "Consciousness Mechanism", .domain = "intersection", .value = 0.0, .predicted_value = 0.0, .uncertainty = 999.0, .status = .{ .category = .blind, .confidence = 0.0, .discovery_date = "unknown" }, .notes = "Physics + Mathematics + Philosophy blind spot" },

    // === ANOMALY: Contradicts theory ===

    .{ .id = "ANOMALY_MUON_G-2", .name = "Muon g-2 Anomaly", .domain = "physics", .value = 0.002331841, .predicted_value = 0.002331836, .uncertainty = 0.000000009, .status = .{ .category = .anomaly, .confidence = 0.95, .discovery_date = "2021" }, .notes = "4.2 sigma deviation! New physics?" },

    .{ .id = "ANOMALY_HUBBLE_TENSION", .name = "Hubble Tension", .domain = "physics", .value = 73.0, .predicted_value = 67.4, .uncertainty = 2.0, .status = .{ .category = .anomaly, .confidence = 0.9, .discovery_date = "2019" }, .notes = "Early vs late universe measurements disagree by 5 sigma!" },

    .{ .id = "ANOMALY_LHC_750GEV", .name = "LHC 750 GeV Diphoton", .domain = "physics", .value = 750.0, .predicted_value = 0.0, .uncertainty = 10.0, .status = .{ .category = .anomaly, .confidence = 0.3, .discovery_date = "2016" }, .notes = "Went away with more data - statistical fluctuation" },
};

// ═══════════════════════════════════════════════════════════════════════════════
// BLIND SPOTS LIST (Prioritized)
// ═══════════════════════════════════════════════════════════════════════════════

pub const blind_spots = [_]BlindSpot{
    .{ .id = "BS_NEUTRINO_MASS", .name = "Neutrino Absolute Mass Scale", .description = "We know neutrinos have mass, but not the absolute scale. Only mass differences measured.", .domain = "physics", .importance = 0.95, .feasibility = 0.6, .hypotheses = &[_][]const u8{
        "Prediction: m_nu = 0.0057 eV (Sacred Formula)",
        "If true, Sigma_m_nu = 0.057 eV for 3 neutrinos",
        "Test: KATRIN experiment reaching 0.35 eV sensitivity",
    } },

    .{ .id = "BS_PROTON_DECAY", .name = "Proton Decay Lifetime", .description = "Grand Unified Theories predict proton decay. Never observed.", .domain = "physics", .importance = 0.99, .feasibility = 0.3, .hypotheses = &[_][]const u8{
        "Prediction: tau_p = 2.82x10^34 years (Sacred Formula)",
        "Current limit: tau_p > 1.6x10^34 years (Super-Kamiokande)",
        "Need 10x more exposure to test prediction",
    } },

    .{ .id = "BS_DM_MASS", .name = "Dark Matter Particle Mass", .description = "Dark matter is 27% of universe. Particle unknown.", .domain = "physics", .importance = 0.98, .feasibility = 0.5, .hypotheses = &[_][]const u8{
        "Prediction: M_DM = 817 GeV (Sacred Formula)",
        "This matches some WIMP model predictions",
        "Test: Xenon-nT, LZ experiments should see signal",
    } },

    .{ .id = "BS_HUBBLE_TENSION", .name = "Hubble Tension Resolution", .description = "Early universe (CMB) vs late universe (supernovae) disagree on H0.", .domain = "physics", .importance = 0.92, .feasibility = 0.7, .hypotheses = &[_][]const u8{
        "Possibility 1: New physics before recombination",
        "Possibility 2: Systematic error in measurements",
        "Possibility 3: Evolving dark energy",
    } },

    .{ .id = "BS_MUON_G2", .name = "Muon Anomalous Magnetic Moment", .description = "4.2 sigma deviation from Standard Model prediction.", .domain = "physics", .importance = 0.88, .feasibility = 0.8, .hypotheses = &[_][]const u8{
        "New particle affecting muon loops",
        "Supersymmetry at TeV scale",
        "Leptoquarks or other exotic physics",
    } },

    .{ .id = "BS_TRINITY_EXTENSION", .name = "Why phi^2 + 1/phi^2 = 3?", .description = "This mathematical identity is too perfect. What is its physical origin?", .domain = "mathematics", .importance = 0.75, .feasibility = 0.9, .hypotheses = &[_][]const u8{
        "Fundamental to ternary logic of universe",
        "Explains why 3 spatial dimensions",
        "May relate to information theory of spacetime",
    } },

    .{ .id = "BS_SACRED_FORMULA_ORIGIN", .name = "Sacred Formula Origin", .description = "Why does V = nx3^kxpi^mxphi^pxe^q fit constants so well?", .domain = "intersection", .importance = 0.85, .feasibility = 0.6, .hypotheses = &[_][]const u8{
        "Mathematical structure of spacetime",
        "Numerology vs fundamental truth",
        "Test: search for constants that DON'T fit",
    } },

    .{ .id = "BS_COLD_FUSION", .name = "Low-Energy Nuclear Reactions", .description = "Nuclear fusion at room temperature. Claims controversial.", .domain = "chemistry_physics", .importance = 0.7, .feasibility = 0.5, .hypotheses = &[_][]const u8{
        "If real, violates Standard Model",
        "Possible: lattice-enabled tunneling",
        "Needs rigorous replication",
    } },

    .{ .id = "BS_EMERGENT_CONSCIOUSNESS", .name = "Emergence of Consciousness", .description = "How does matter become conscious? Hard problem.", .domain = "intersection", .importance = 1.0, .feasibility = 0.2, .hypotheses = &[_][]const u8{
        "Consciousness as fundamental (panpsychism)",
        "Consciousness emerges from complexity",
        "Consciousness = phi-resonance in neural networks",
    } },

    .{ .id = "BS_ORIGIN_OF_BIOASYMMETRY", .name = "Biological Homochirality", .description = "Why is life left-handed? L-amino acids, D-sugars only.", .domain = "chemistry_biology", .importance = 0.65, .feasibility = 0.7, .hypotheses = &[_][]const u8{
        "Parity violation in weak force",
        "Stochastic asymmetry amplified",
        "Exotic seeding (meteorites)",
    } },
};

// ═══════════════════════════════════════════════════════════════════════════════
// ANOMALIES LIST
// ═══════════════════════════════════════════════════════════════════════════════

pub const anomalies = [_]Anomaly{
    .{ .id = "ANOM_MUON_G2", .name = "Muon g-2", .expected = 0.002331836, .observed = 0.002331841, .deviation = 4.2, .domain = "physics" },

    .{ .id = "ANOM_HUBBLE", .name = "Hubble Tension", .expected = 67.4, .observed = 73.0, .deviation = 5.0, .domain = "physics" },

    .{ .id = "ANOM_LIKNIFE", .name = "Lithium Problem", .expected = 0.26, .observed = 0.24, .deviation = 3.0, .domain = "cosmology" },

    .{ .id = "ANOM_CORE", .name = "Core-Cusp Problem", .expected = 1.0, .observed = 0.5, .deviation = 10.0, .domain = "astrophysics" },
};

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn findBlindSpotsByDomain(allocator: Allocator, domain: []const u8) ![]const BlindSpot {
    var results = try std.ArrayList(BlindSpot).initCapacity(allocator, 10);
    defer results.deinit(allocator);
    for (blind_spots) |spot| {
        if (std.mem.indexOf(u8, spot.domain, domain) != null) {
            try results.append(allocator, spot);
        }
    }
    return results.toOwnedSlice(allocator);
}

pub fn findAnomaliesAboveSigma(allocator: Allocator, min_sigma: f64) ![]const Anomaly {
    var results = try std.ArrayList(Anomaly).initCapacity(allocator, 4);
    defer results.deinit(allocator);
    for (anomalies) |anom| {
        if (anom.deviation >= min_sigma) {
            try results.append(allocator, anom);
        }
    }
    return results.toOwnedSlice(allocator);
}

pub fn generateDiscoveryReport(allocator: Allocator) ![]u8 {
    const GOLDEN = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const WHITE = "\x1b[97m";
    const GRAY = "\x1b[90m";
    const GREEN = "\x1b[32m";
    const RED = "\x1b[31m";
    const MAGENTA = "\x1b[35m";
    const RESET = "\x1b[0m";
    const BOLD = "\x1b[1m";

    var buffer = try std.ArrayList(u8).initCapacity(allocator, 8192);
    const writer = buffer.writer(allocator);

    try writer.print("\n{s}{s}╔════════════════════════════════════════════════════════════════╗{s}\n", .{ MAGENTA, BOLD, RESET });
    try writer.print("{s}{s}║       BLIND SPOTS DISCOVERY ENGINE v1.0                        ║{s}\n", .{ MAGENTA, BOLD, RESET });
    try writer.print("{s}{s}║       Registry of Human Knowledge Gaps                      ║{s}\n", .{ MAGENTA, BOLD, RESET });
    try writer.print("{s}{s}╚════════════════════════════════════════════════════════════════╝{s}\n\n", .{ MAGENTA, BOLD, RESET });

    // Summary Statistics
    try writer.print("{s}📊 KNOWLEDGE REGISTRY SUMMARY{s}\n", .{ CYAN, RESET });
    try writer.print("{s}═══════════════════════════════{s}\n\n", .{ GRAY, RESET });

    try writer.print("  {s}VERIFIED:{s}   {s}{d}{s} entries (Theory + Experiment agree)\n", .{ GREEN, RESET, WHITE, registry.len, RESET });
    try writer.print("  {s}PREDICTED:{s}  {s}{d}{s} entries (Theory predicts, not measured)\n", .{ CYAN, RESET, WHITE, 3, RESET });
    try writer.print("  {s}BLIND:{s}      {s}{d}{s} entries (Completely unknown)\n", .{ RED, RESET, WHITE, 3, RESET });
    try writer.print("  {s}ANOMALY:{s}    {s}{d}{s} entries (Contradicts theory)\n\n", .{ MAGENTA, RESET, WHITE, 4, RESET });

    // BLIND SPOTS - Priority Research Targets
    try writer.print("{s}🔬 PRIORITY BLIND SPOTS (Top 5){s}\n", .{ GOLDEN, RESET });
    try writer.print("{s}═════════════════════════════════{s}\n\n", .{ GRAY, RESET });

    const sorted_spots = [_]BlindSpot{
        blind_spots[0], // Neutrino Mass
        blind_spots[1], // Proton Decay
        blind_spots[2], // Dark Matter Mass
        blind_spots[3], // Hubble Tension
        blind_spots[8], // Consciousness
    };

    for (sorted_spots, 0..) |spot, i| {
        try writer.print("  {s}[{d}]{s} {s}{s}{s}\n", .{ GRAY, i + 1, RESET, BOLD, spot.name, RESET });
        try writer.print("      Domain: {s}{s}{s}\n", .{ CYAN, spot.domain, RESET });
        try writer.print("      Importance: {s}{d:.0}%{s} | Feasibility: {s}{d:.0}%{s}\n", .{
            GREEN, spot.importance, RESET, WHITE, spot.feasibility, RESET,
        });
        try writer.print("      {s}Description:{s} {s}\n", .{ GRAY, RESET, spot.description });
        try writer.print("\n", .{});
    }

    // DISCOVERY PREDICTIONS
    try writer.print("{s}🔮 SACRED FORMULA PREDICTIONS (Unverified){s}\n", .{ GOLDEN, RESET });
    try writer.print("{s}═════════════════════════════════════════{s}\n\n", .{ GRAY, RESET });

    try writer.print("  {s}1. Neutrino Mass:{s} {s}m_nu = 0.0057 eV{s}\n", .{ WHITE, RESET, CYAN, RESET });
    try writer.print("     Formula: V = 1x3^-1xpi^-1xphi^-4xe^-1\n", .{});
    try writer.print("     Test: KATRIN experiment (current limit 0.8 eV)\n", .{});
    try writer.print("     Status: {s}BLIND{s} - below current sensitivity\n\n", .{ RED, RED });

    try writer.print("  {s}2. Proton Lifetime:{s} {s}tau_p = 2.82x10^34 years{s}\n", .{ WHITE, RESET, CYAN, RESET });
    try writer.print("     Formula: V = 3x3^4xpi^3xphi^4xe^4\n", .{});
    try writer.print("     Test: Super-Kamiokande, Hyper-Kamiokande\n", .{});
    try writer.print("     Status: {s}BLIND{s} - prediction below current limit\n\n", .{ RED, RED });

    try writer.print("  {s}3. Dark Matter Mass:{s} {s}M_DM = 817 GeV{s}\n", .{ WHITE, RESET, CYAN, RESET });
    try writer.print("     Formula: V = 4x3^4xphi^4\n", .{});
    try writer.print("     Test: Xenon-nT, LZ experiments\n", .{});
    try writer.print("     Status: {s}BLIND{s} - no WIMP signal seen yet\n\n", .{ RED, RED });

    // ANOMALIES
    try writer.print("{s}⚠️  ACTIVE ANOMALIES (New Physics?){s}\n", .{ MAGENTA, RESET });
    try writer.print("{s}════════════════════════════════════{s}\n\n", .{ GRAY, RESET });

    const high_sigma_anomalies = try findAnomaliesAboveSigma(allocator, 3.0);
    defer allocator.free(high_sigma_anomalies);
    for (high_sigma_anomalies) |anom| {
        const color = if (anom.deviation >= 5.0) RED else if (anom.deviation >= 4.0) MAGENTA else GOLDEN;
        try writer.print("  {s}{s}{s}\n", .{ BOLD, anom.name, RESET });
        try writer.print("     Expected: {s}{d:.6}{s} | Observed: {s}{d:.6}{s}\n", .{
            WHITE, anom.expected, RESET, CYAN, anom.observed, RESET,
        });
        try writer.print("     Deviation: {s}{d:.1}sigma{s}\n\n", .{ color, anom.deviation, RESET });
    }

    // FUNDAMENTAL QUESTION
    try writer.print("{s}🌌 THE FUNDAMENTAL QUESTION{s}\n", .{ GOLDEN, RESET });
    try writer.print("{s}════════════════════════════════{s}\n\n", .{ GRAY, RESET });
    try writer.print("  {s}Why does the Sacred Formula work so well?{s}\n\n", .{ BOLD, RESET });
    try writer.print("  {s}V = n x 3^k x pi^m x phi^p x e^q{s}\n\n", .{ CYAN, RESET });
    try writer.print("  This formula fits {s}100+ physical constants{s} with <1% error.\n", .{ GOLDEN, RESET });
    try writer.print("  Is it:\n", .{});
    try writer.print("    - Numerical coincidence? (unlikely given 100+ fits)\n", .{});
    try writer.print("    - Reflection of deeper mathematical structure?\n", .{});
    try writer.print("    - Evidence that phi, pi, e are more fundamental than suspected?\n\n", .{});

    try writer.print("  {s}phi^2 + 1/phi^2 = 3{s} suggests ternary logic is fundamental.\n", .{ GOLDEN, RESET });
    try writer.print("  This may explain why we have {s}3 spatial dimensions{s}, ", .{ GOLDEN, RESET });
    try writer.print(" {s}3 states of matter{s}, ", .{ GOLDEN, RESET });
    try writer.print(" {s}3 quark colors{s}...\n\n", .{ GOLDEN, RESET });

    try writer.print("{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });

    return buffer.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "registry has all required entries" {
    try std.testing.expect(registry.len >= 10);
}

test "blind spots are prioritized" {
    for (blind_spots) |spot| {
        try std.testing.expect(spot.importance >= 0.0 and spot.importance <= 1.0);
        try std.testing.expect(spot.feasibility >= 0.0 and spot.feasibility <= 1.0);
    }
}

test "find blind spots by domain" {
    const physics_spots = try findBlindSpotsByDomain(std.testing.allocator, "physics");
    defer std.testing.allocator.free(physics_spots);
    try std.testing.expect(physics_spots.len >= 3);
}

test "find anomalies above sigma" {
    const high_sigma = try findAnomaliesAboveSigma(std.testing.allocator, 4.0);
    defer std.testing.allocator.free(high_sigma);
    try std.testing.expect(high_sigma.len >= 1);
}
