// Generated from specs/tri/sacred/sacred_formula.tri — DO NOT EDIT
// Sacred Formula: V = n * 3^k * pi^m * phi^p * e^q

const std = @import("std");
const math = std.math;

pub const TRINITY: f64 = 3.00000000000000000000;
pub const PI: f64 = 3.14159265358979300000;
pub const PHI: f64 = 1.61803398874989500000;
pub const E: f64 = 2.71828182845904500000;

pub const SacredConstant = struct { name: []const u8, symbol: []const u8, value: f64, category: []const u8 };

pub const constants = [_]SacredConstant{
    .{ .name = "1/alpha", .symbol = "FINE_STRUCTURE_INV", .value = 137.036, .category = "particle_physics" },
    .{ .name = "m_p/m_e", .symbol = "PROTON_ELECTRON_RATIO", .value = 1836.15267343, .category = "particle_physics" },
    .{ .name = "CHSH (2*sqrt2)", .symbol = "CHSH", .value = 2.8284271247461903, .category = "quantum" },
    .{ .name = "sin2(theta_W)", .symbol = "WEINBERG_SIN2", .value = 0.23121, .category = "particle_physics" },
    .{ .name = "H_0 (67.4)", .symbol = "HUBBLE", .value = 67.4, .category = "cosmology" },
    .{ .name = "Omega_Lambda", .symbol = "OMEGA_LAMBDA", .value = 0.685, .category = "cosmology" },
    .{ .name = "T_CMB (2.7255)", .symbol = "CMB_TEMP", .value = 2.7255, .category = "cosmology" },
    .{ .name = "gamma_BI (LQG)", .symbol = "BARBERO_IMMIRZI", .value = 0.127384023140948, .category = "quantum_gravity" },
    .{ .name = "S/A = 1/4 (BH)", .symbol = "BEKENSTEIN_HAWKING_RATIO", .value = 0.25, .category = "quantum_gravity" },
    .{ .name = "c_BH = 3/2 (AdS)", .symbol = "BROWN_HENNEAUX", .value = 1.5, .category = "quantum_gravity" },
    .{ .name = "Age (13.787 Gyr)", .symbol = "AGE_UNIVERSE", .value = 13.787, .category = "cosmology" },
    .{ .name = "SU3 golden 3/2phi", .symbol = "SU3_GOLDEN", .value = 0.9270509831248422, .category = "particle_physics" },
    .{ .name = "m_mu/m_e (206.77)", .symbol = "MUON_ELECTRON_RATIO", .value = 206.768283, .category = "particle_physics" },
    .{ .name = "m_tau/m_e (3477.2)", .symbol = "TAU_ELECTRON_RATIO", .value = 3477.1894, .category = "particle_physics" },
    .{ .name = "M_Higgs (125.25)", .symbol = "M_HIGGS", .value = 125.25, .category = "particle_physics" },
    .{ .name = "M_W (80.377)", .symbol = "M_W_BOSON", .value = 80.377, .category = "particle_physics" },
    .{ .name = "M_Z (91.1876)", .symbol = "M_Z_BOSON", .value = 91.1876, .category = "particle_physics" },
    .{ .name = "H_0 SH0ES (73.0)", .symbol = "HUBBLE_SH0ES", .value = 73, .category = "cosmology" },
};

pub const SacredPrediction = struct { name: []const u8, formula: []const u8, n: i8, k: i8, m: i8, p: i8, q: i8, unit: []const u8 };

pub const predictions = [_]SacredPrediction{
    .{ .name = "Neutrino mass hint", .formula = "1*3^-1*pi^-1*phi^-4*e^-1", .n = 1, .k = -1, .m = -1, .p = -4, .q = -1, .unit = "eV" },
    .{ .name = "DM candidate mass", .formula = "3*3^2*phi^3*e^2", .n = 3, .k = 2, .m = 0, .p = 3, .q = 2, .unit = "GeV" },
    .{ .name = "Lambda/rho_P hint", .formula = "1*3^-4*pi^-2*phi^-4*e^-3", .n = 1, .k = -4, .m = -2, .p = -4, .q = -3, .unit = "Planck" },
    .{ .name = "Graviton mass bound", .formula = "1*3^-3*pi^-3*phi^-4*e^-3", .n = 1, .k = -3, .m = -3, .p = -4, .q = -3, .unit = "eV" },
    .{ .name = "Proton lifetime hint", .formula = "3*3^4*pi^3*phi^4*e^4", .n = 3, .k = 4, .m = 3, .p = 4, .q = 4, .unit = "years" },
    .{ .name = "Spatial dimensions", .formula = "1*3^1", .n = 1, .k = 1, .m = 0, .p = 0, .q = 0, .unit = "" },
};
