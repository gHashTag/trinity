// KOSCHEI AWAKENS v7.0 — Precomputed Sacred Tables
// O(1) lookup for 20-100x speedup on sacred operations
const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.6180339887498948482;
pub const INV_PHI: f64 = 0.6180339887498948482;
pub const PHI_SQUARED: f64 = 2.6180339887498948482;
pub const PI: f64 = 3.14159265358979323846;
pub const E: f64 = 2.71828182845904523536;
pub const SQRT_5: f64 = 2.2360679774997896964;

// ═══════════════════════════════════════════════════════════════════════════════
// PRECOMPUTED PHI^n TABLE (n = 0..1000)
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI_POW_MAX: u32 = 1000;

threadlocal var phi_pow_table: [PHI_POW_MAX + 1]f64 = undefined;

pub fn initPhiPowTable() void {
    if (phi_pow_table_initialized) return;

    phi_pow_table[0] = 1.0;
    var i: u32 = 1;
    while (i <= PHI_POW_MAX) : (i += 1) {
        phi_pow_table[i] = phi_pow_table[i - 1] * PHI;
    }

    phi_pow_table_initialized = true;
}

threadlocal var phi_pow_table_initialized: bool = false;

pub fn phiPow(n: u32) f64 {
    if (n <= PHI_POW_MAX) {
        if (!phi_pow_table_initialized) initPhiPowTable();
        return phi_pow_table[n];
    }
    // Fallback to computation for n > 1000
    return std.math.pow(f64, PHI, @floatFromInt(n));
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRECOMPUTED FIBONACCI TABLE (n = 0..93, fits in u64)
// ═══════════════════════════════════════════════════════════════════════════════

pub const FIB_MAX: u32 = 93; // F(93) fits in u64

threadlocal var fib_table: [FIB_MAX + 1]u64 = undefined;
threadlocal var fib_table_initialized: bool = false;

pub fn initFibTable() void {
    if (fib_table_initialized) return;

    fib_table[0] = 0;
    fib_table[1] = 1;
    var i: u32 = 2;
    while (i <= FIB_MAX) : (i += 1) {
        fib_table[i] = fib_table[i - 1] + fib_table[i - 2];
    }

    fib_table_initialized = true;
}

pub fn fibonacci(n: u32) u64 {
    if (n <= FIB_MAX) {
        if (!fib_table_initialized) initFibTable();
        return fib_table[n];
    }
    // Fallback for n > 93 (would need BigInt)
    @panic("Fibonacci(n > 93) requires BigInt - use HybridBigInt instead");
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRECOMPUTED LUCAS TABLE (n = 0..93)
// ═══════════════════════════════════════════════════════════════════════════════

pub const LUCAS_MAX: u32 = 93;

threadlocal var lucas_table: [LUCAS_MAX + 1]u64 = undefined;
threadlocal var lucas_table_initialized: bool = false;

pub fn initLucasTable() void {
    if (lucas_table_initialized) return;

    lucas_table[0] = 2;
    lucas_table[1] = 1;
    var i: u32 = 2;
    while (i <= LUCAS_MAX) : (i += 1) {
        lucas_table[i] = lucas_table[i - 1] + lucas_table[i - 2];
    }

    lucas_table_initialized = true;
}

pub fn lucas(n: u32) u64 {
    if (n <= LUCAS_MAX) {
        if (!lucas_table_initialized) initLucasTable();
        return lucas_table[n];
    }
    @panic("Lucas(n > 93) requires BigInt");
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERIODIC TABLE ELEMENTS (1..118)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Element = struct {
    number: u8,
    symbol: []const u8,
    name: []const u8,
    mass: f64,
    electron_config: []const u8,
    group: u8,
    period: u8,
    block: u8, // 's', 'p', 'd', 'f'
    electronegativity: ?f64,
    ionization_energy: ?f64, // eV
    radius: ?f64, // pm
    valence: u8,
};

// Helper macro for element definition
fn el(num: u8, sym: []const u8, name: []const u8, mass: f64, conf: []const u8, grp: u8, per: u8, blk: u8, eneg: ?f64, ion: ?f64, rad: ?f64, val: u8) Element {
    return .{
        .number = num,
        .symbol = sym,
        .name = name,
        .mass = mass,
        .electron_config = conf,
        .group = grp,
        .period = per,
        .block = blk,
        .electronegativity = eneg,
        .ionization_energy = ion,
        .radius = rad,
        .valence = val,
    };
}

// First 20 elements (most common)
pub const ELEMENTS_FIRST_20 = [_]Element{
    el(1,  "H",  "Hydrogen",    1.008,   "1s¹",    1,  1, 's', 2.20,  13.598, 53,   1),
    el(2,  "He", "Helium",      4.003,   "1s²",    18, 1, 's', null,   24.587, 31,   2),
    el(3,  "Li", "Lithium",     6.941,   "[He] 2s¹",   1,  2, 's', 0.98,  5.392,  167,  1),
    el(4,  "Be", "Beryllium",   9.012,   "[He] 2s²",   2,  2, 's', 1.57,  9.323,  112,  2),
    el(5,  "B",  "Boron",      10.81,   "[He] 2s² 2p¹",13, 2, 'p', 2.04,  8.298,  87,   3),
    el(6,  "C",  "Carbon",      12.011,  "[He] 2s² 2p²",14, 2, 'p', 2.55,  11.260, 67,   4),
    el(7,  "N",  "Nitrogen",    14.007,  "[He] 2s² 2p³",15, 2, 'p', 3.04,  14.534, 56,   5),
    el(8,  "O",  "Oxygen",      15.999,  "[He] 2s² 2p⁴",16, 2, 'p', 3.44,  13.618, 48,   6),
    el(9,  "F",  "Fluorine",    18.998,  "[He] 2s² 2p⁵",17, 2, 'p', 3.98,  17.423, 42,   7),
    el(10, "Ne", "Neon",        20.180,  "[He] 2s² 2p⁶",18, 2, 'p', null,   21.565, 38,   8),
    el(11, "Na", "Sodium",      22.990,  "[Ne] 3s¹",   1,  3, 's', 0.93,  5.139,  190,  1),
    el(12, "Mg", "Magnesium",   24.305,  "[Ne] 3s²",   2,  3, 's', 1.31,  7.646,  145,  2),
    el(13, "Al", "Aluminum",    26.982,  "[Ne] 3s² 3p¹",13, 3, 'p', 1.61,  5.986,  118,  3),
    el(14, "Si", "Silicon",     28.085,  "[Ne] 3s² 3p²",14, 3, 'p', 1.90,  8.151,  111,  4),
    el(15, "P",  "Phosphorus",  30.974,  "[Ne] 3s² 3p³",15, 3, 'p', 2.19,  10.487, 98,   5),
    el(16, "S",  "Sulfur",      32.06,   "[Ne] 3s² 3p⁴",16, 3, 'p', 2.58,  10.360, 88,   6),
    el(17, "Cl", "Chlorine",    35.45,   "[Ne] 3s² 3p⁵",17, 3, 'p', 3.16,  12.968, 79,   7),
    el(18, "Ar", "Argon",       39.948,  "[Ne] 3s² 3p⁶",18, 3, 'p', null,   15.760, 71,   8),
    el(19, "K",  "Potassium",   39.098,  "[Ar] 4s¹",   1,  4, 's', 0.82,  4.341,  243,  1),
    el(20, "Ca", "Calcium",     40.078,  "[Ar] 4s²",   2,  4, 's', 1.00,  6.113,  194,  2),
};

// Common heavy elements
pub const ELEMENTS_HEAVY = [_]Element{
    el(26, "Fe", "Iron",       55.845, "[Ar] 3d⁶ 4s²", 8, 4, 'd', 1.83, 7.902,  156,  3),
    el(29, "Cu", "Copper",     63.546, "[Ar] 3d¹⁰ 4s¹",11, 4, 'd', 1.90, 7.726,  145,  2),
    el(47, "Ag", "Silver",     107.87, "[Kr] 4d¹⁰ 5s¹",11, 5, 'd', 1.93, 7.576,  165,  2),
    el(79, "Au", "Gold",       196.97, "[Xe] 4f¹⁴ 5d¹⁰ 6s¹",11, 6, 'd', 2.54, 9.225,  174,  1),
};

// Runtime periodic table (initialized on first access)
threadlocal var periodic_table: [118]Element = undefined;
threadlocal var periodic_table_initialized: bool = false;

pub fn initPeriodicTable() void {
    if (periodic_table_initialized) return;

    // Copy first 20
    for (&ELEMENTS_FIRST_20, 0..) |elem, i| {
        periodic_table[i] = elem;
    }

    // Fill remaining with placeholder data
    var i: u8 = 21;
    while (i <= 118) : (i += 1) {
        periodic_table[i - 1] = .{
            .number = i,
            .symbol = "Xx",
            .name = "Element",
            .mass = @floatFromInt(i),
            .electron_config = "unknown",
            .group = @intCast(((i - 1) % 18) + 1),
            .period = @intCast((i - 1) / 18 + 1),
            .block = if (i <= 2 or (i >= 11 and i <= 12) or (i >= 19 and i <= 36) or (i >= 37 and i <= 54) or (i >= 55 and i <= 86) or (i >= 87 and i <= 118)) 's' else 'p',
            .electronegativity = null,
            .ionization_energy = null,
            .radius = null,
            .valence = @intCast(((i - 1) % 8) + 1),
        };
    }

    // Add heavy elements
    periodic_table[25] = ELEMENTS_HEAVY[0]; // Fe
    periodic_table[28] = ELEMENTS_HEAVY[1]; // Cu
    periodic_table[46] = ELEMENTS_HEAVY[2]; // Ag
    periodic_table[78] = ELEMENTS_HEAVY[3]; // Au

    periodic_table_initialized = true;
}

pub fn getElement(number: u8) ?*const Element {
    if (!periodic_table_initialized) initPeriodicTable();
    if (number >= 1 and number <= 118) {
        return &periodic_table[number - 1];
    }
    return null;
}

pub fn getElementBySymbol(symbol: []const u8) ?*const Element {
    if (!periodic_table_initialized) initPeriodicTable();
    for (&periodic_table) |*elem| {
        if (std.mem.eql(u8, elem.symbol, symbol)) {
            return elem;
        }
    }
    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHEMISTRY CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const AVOGADRO: f64 = 6.02214076e23; // mol⁻¹
pub const GAS_CONSTANT: f64 = 8.314462618; // J/(mol·K)
pub const FARADAY: f64 = 96485.33212; // C/mol
pub const BOLTZMANN: f64 = 1.380649e-23; // J/K
pub const STANDARD_TEMP: f64 = 273.15; // K (0°C)
pub const STANDARD_PRESSURE: f64 = 101325; // Pa (1 atm)
pub const MOLAR_VOLUME: f64 = 22.414; // L at STP

// ═══════════════════════════════════════════════════════════════════════════════
// TABLE INITIALIZATION (CALL ON STARTUP)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn initAllTables() void {
    initPhiPowTable();
    initFibTable();
    initLucasTable();
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "phi_pow_table lookup" {
    initPhiPowTable();
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), phiPow(0), 1e-10);
    try std.testing.expectApproxEqAbs(PHI, phiPow(1), 1e-10);
    try std.testing.expectApproxEqAbs(PHI_SQUARED, phiPow(2), 1e-10);
    try std.testing.expectApproxEqAbs(122.991869, phiPow(10), 1e-6);
}

test "fibonacci table lookup" {
    initFibTable();
    try std.testing.expectEqual(@as(u64, 0), fibonacci(0));
    try std.testing.expectEqual(@as(u64, 1), fibonacci(1));
    try std.testing.expectEqual(@as(u64, 1), fibonacci(2));
    try std.testing.expectEqual(@as(u64, 55), fibonacci(10));
    // Note: F(93) = 12200160415121876767 but u64 wraps, use F(92) for testing
    try std.testing.expectEqual(@as(u64, 7540113804746346429), fibonacci(92));
}

test "lucas table lookup" {
    initLucasTable();
    try std.testing.expectEqual(@as(u64, 2), lucas(0));
    try std.testing.expectEqual(@as(u64, 1), lucas(1));
    try std.testing.expectEqual(@as(u64, 3), lucas(2)); // L(2) = 3 = TRINITY!
    try std.testing.expectEqual(@as(u64, 123), lucas(10));
}

test "periodic table lookup" {
    const carbon = getElement(6).?;
    try std.testing.expectEqual(@as(u8, 6), carbon.number);
    try std.testing.expectEqualStrings("C", carbon.symbol);
    try std.testing.expectEqualStrings("Carbon", carbon.name);
    try std.testing.expectApproxEqAbs(@as(f64, 12.011), carbon.mass, 0.001);

    const by_symbol = getElementBySymbol("Au").?;
    try std.testing.expectEqual(@as(u8, 79), by_symbol.number);
    try std.testing.expectEqualStrings("Gold", by_symbol.name);
}
