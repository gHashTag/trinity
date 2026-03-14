// @origin(spec:science_tools.tri) @regen(manual-impl)
//! Trinity MCP Science Tools — Chemistry, Biology, Quantum, Spiral, Formula
//! Ported from Python mcp/server.py inline implementations
//! V = n × 3^k × π^m × φ^p × e^q | φ² + 1/φ² = 3 = TRINITY
// @origin(manual) @regen(pending)
const std = @import("std");
const math = std.math;

// Sacred constants
const PHI: f64 = 1.618033988749895;
const PI: f64 = 3.141592653589793;
const E_CONST: f64 = 2.718281828459045;
const AVOGADRO: f64 = 6.022e23;

// ═══════════════════════════════════════════════════════════════════════════════
// Chemistry — Elements, Molar Mass, Moles
// ═══════════════════════════════════════════════════════════════════════════════

const Element = struct {
    symbol: []const u8,
    number: u8,
    mass: f64,
    name: []const u8,
    category: []const u8,
};

const ELEMENTS = [_]Element{
    .{ .symbol = "H", .number = 1, .mass = 1.008, .name = "Hydrogen", .category = "nonmetal" },
    .{ .symbol = "He", .number = 2, .mass = 4.003, .name = "Helium", .category = "noble_gas" },
    .{ .symbol = "Li", .number = 3, .mass = 6.941, .name = "Lithium", .category = "alkali_metal" },
    .{ .symbol = "Be", .number = 4, .mass = 9.012, .name = "Beryllium", .category = "alkaline_earth" },
    .{ .symbol = "B", .number = 5, .mass = 10.81, .name = "Boron", .category = "metalloid" },
    .{ .symbol = "C", .number = 6, .mass = 12.011, .name = "Carbon", .category = "nonmetal" },
    .{ .symbol = "N", .number = 7, .mass = 14.007, .name = "Nitrogen", .category = "nonmetal" },
    .{ .symbol = "O", .number = 8, .mass = 15.999, .name = "Oxygen", .category = "nonmetal" },
    .{ .symbol = "F", .number = 9, .mass = 18.998, .name = "Fluorine", .category = "halogen" },
    .{ .symbol = "Ne", .number = 10, .mass = 20.180, .name = "Neon", .category = "noble_gas" },
    .{ .symbol = "Na", .number = 11, .mass = 22.990, .name = "Sodium", .category = "alkali_metal" },
    .{ .symbol = "Mg", .number = 12, .mass = 24.305, .name = "Magnesium", .category = "alkaline_earth" },
    .{ .symbol = "Al", .number = 13, .mass = 26.982, .name = "Aluminum", .category = "post_transition" },
    .{ .symbol = "Si", .number = 14, .mass = 28.086, .name = "Silicon", .category = "metalloid" },
    .{ .symbol = "P", .number = 15, .mass = 30.974, .name = "Phosphorus", .category = "nonmetal" },
    .{ .symbol = "S", .number = 16, .mass = 32.065, .name = "Sulfur", .category = "nonmetal" },
    .{ .symbol = "Cl", .number = 17, .mass = 35.453, .name = "Chlorine", .category = "halogen" },
    .{ .symbol = "Ar", .number = 18, .mass = 39.948, .name = "Argon", .category = "noble_gas" },
    .{ .symbol = "K", .number = 19, .mass = 39.098, .name = "Potassium", .category = "alkali_metal" },
    .{ .symbol = "Ca", .number = 20, .mass = 40.078, .name = "Calcium", .category = "alkaline_earth" },
    .{ .symbol = "Fe", .number = 26, .mass = 55.845, .name = "Iron", .category = "transition_metal" },
    .{ .symbol = "Cu", .number = 29, .mass = 63.546, .name = "Copper", .category = "transition_metal" },
    .{ .symbol = "Zn", .number = 30, .mass = 65.380, .name = "Zinc", .category = "transition_metal" },
    .{ .symbol = "Ag", .number = 47, .mass = 107.868, .name = "Silver", .category = "transition_metal" },
    .{ .symbol = "Au", .number = 79, .mass = 196.967, .name = "Gold", .category = "transition_metal" },
    .{ .symbol = "Hg", .number = 80, .mass = 200.592, .name = "Mercury", .category = "transition_metal" },
    .{ .symbol = "Pb", .number = 82, .mass = 207.200, .name = "Lead", .category = "post_transition" },
    .{ .symbol = "U", .number = 92, .mass = 238.029, .name = "Uranium", .category = "actinide" },
};

fn findElement(symbol: []const u8) ?*const Element {
    for (&ELEMENTS) |*el| {
        if (std.ascii.eqlIgnoreCase(el.symbol, symbol)) return el;
    }
    return null;
}

fn findElementByNumber(num: u8) ?*const Element {
    for (&ELEMENTS) |*el| {
        if (el.number == num) return el;
    }
    return null;
}

/// Parse chemical formula like "H2O" into element/count pairs
/// Returns JSON string with molar_mass and composition
pub fn chemMass(buf: []u8, formula: []const u8) []const u8 {
    var total_mass: f64 = 0;
    var i: usize = 0;

    // Parse and sum
    while (i < formula.len) {
        if (!std.ascii.isUpper(formula[i])) {
            i += 1;
            continue;
        }
        const sym_start = i;
        i += 1;
        // Lowercase continuation
        while (i < formula.len and std.ascii.isLower(formula[i])) i += 1;
        const symbol = formula[sym_start..i];
        // Parse count
        var count: u32 = 0;
        while (i < formula.len and std.ascii.isDigit(formula[i])) {
            count = count * 10 + @as(u32, formula[i] - '0');
            i += 1;
        }
        if (count == 0) count = 1;

        if (findElement(symbol)) |el| {
            total_mass += el.mass * @as(f64, @floatFromInt(count));
        }
    }

    return std.fmt.bufPrint(buf, "{{\"formula\":\"{s}\",\"molar_mass_g_per_mol\":{d:.3}}}", .{ formula, total_mass }) catch "{}";
}

/// Element lookup by symbol or atomic number
pub fn chemElement(buf: []u8, query: []const u8) []const u8 {
    // Try as atomic number
    if (std.fmt.parseInt(u8, query, 10)) |num| {
        if (findElementByNumber(num)) |el| {
            return formatElement(buf, el);
        }
    } else |_| {}

    // Try as symbol
    if (findElement(query)) |el| {
        return formatElement(buf, el);
    }

    return std.fmt.bufPrint(buf, "{{\"error\":\"Element not found: {s}\"}}", .{query}) catch "{}";
}

fn formatElement(buf: []u8, el: *const Element) []const u8 {
    return std.fmt.bufPrint(
        buf,
        "{{\"symbol\":\"{s}\",\"atomic_number\":{d},\"atomic_mass\":{d:.3},\"name\":\"{s}\",\"category\":\"{s}\"}}",
        .{ el.symbol, el.number, el.mass, el.name, el.category },
    ) catch "{}";
}

/// Periodic table listing (all or by category)
pub fn chemPeriodic(buf: []u8, category: []const u8) []const u8 {
    var idx: usize = 0;
    idx += copySlice(buf[idx..], "{\"elements\":[");
    var first = true;
    for (&ELEMENTS) |*el| {
        if (!std.mem.eql(u8, category, "all") and !std.ascii.eqlIgnoreCase(el.category, category)) continue;
        if (!first) {
            if (idx < buf.len) {
                buf[idx] = ',';
                idx += 1;
            }
        }
        first = false;
        const elem_json = std.fmt.bufPrint(
            buf[idx..],
            "{{\"symbol\":\"{s}\",\"number\":{d},\"mass\":{d:.3},\"name\":\"{s}\",\"category\":\"{s}\"}}",
            .{ el.symbol, el.number, el.mass, el.name, el.category },
        ) catch break;
        idx += elem_json.len;
    }
    idx += copySlice(buf[idx..], "]}");
    return buf[0..idx];
}

/// Moles calculation from mass and formula
pub fn chemMoles(buf: []u8, formula: []const u8, mass: f64) []const u8 {
    var molar_mass: f64 = 0;
    var atoms_per_mol: u32 = 0;
    var i: usize = 0;

    while (i < formula.len) {
        if (!std.ascii.isUpper(formula[i])) {
            i += 1;
            continue;
        }
        const sym_start = i;
        i += 1;
        while (i < formula.len and std.ascii.isLower(formula[i])) i += 1;
        const symbol = formula[sym_start..i];
        var count: u32 = 0;
        while (i < formula.len and std.ascii.isDigit(formula[i])) {
            count = count * 10 + @as(u32, formula[i] - '0');
            i += 1;
        }
        if (count == 0) count = 1;
        atoms_per_mol += count;
        if (findElement(symbol)) |el| {
            molar_mass += el.mass * @as(f64, @floatFromInt(count));
        }
    }

    if (molar_mass == 0) {
        return std.fmt.bufPrint(buf, "{{\"error\":\"Cannot compute molar mass for: {s}\"}}", .{formula}) catch "{}";
    }

    const moles = mass / molar_mass;
    const molecules = moles * AVOGADRO;
    const total_atoms = molecules * @as(f64, @floatFromInt(atoms_per_mol));

    return std.fmt.bufPrint(
        buf,
        "{{\"formula\":\"{s}\",\"mass_g\":{d:.4},\"molar_mass\":{d:.3},\"moles\":{d:.6},\"molecules\":{e:.3},\"total_atoms\":{e:.3},\"atoms_per_molecule\":{d}}}",
        .{ formula, mass, molar_mass, moles, molecules, total_atoms, atoms_per_mol },
    ) catch "{}";
}

// ═══════════════════════════════════════════════════════════════════════════════
// Biology — DNA, Codons, Protein
// ═══════════════════════════════════════════════════════════════════════════════

const CodonEntry = struct { codon: []const u8, aa: u8, name: []const u8 };

// Complete RNA codon table (64 codons)
const CODON_TABLE = [_]CodonEntry{
    .{ .codon = "UUU", .aa = 'F', .name = "Phenylalanine" }, .{ .codon = "UUC", .aa = 'F', .name = "Phenylalanine" },
    .{ .codon = "UUA", .aa = 'L', .name = "Leucine" },       .{ .codon = "UUG", .aa = 'L', .name = "Leucine" },
    .{ .codon = "CUU", .aa = 'L', .name = "Leucine" },       .{ .codon = "CUC", .aa = 'L', .name = "Leucine" },
    .{ .codon = "CUA", .aa = 'L', .name = "Leucine" },       .{ .codon = "CUG", .aa = 'L', .name = "Leucine" },
    .{ .codon = "AUU", .aa = 'I', .name = "Isoleucine" },    .{ .codon = "AUC", .aa = 'I', .name = "Isoleucine" },
    .{ .codon = "AUA", .aa = 'I', .name = "Isoleucine" },    .{ .codon = "AUG", .aa = 'M', .name = "Methionine" },
    .{ .codon = "GUU", .aa = 'V', .name = "Valine" },        .{ .codon = "GUC", .aa = 'V', .name = "Valine" },
    .{ .codon = "GUA", .aa = 'V', .name = "Valine" },        .{ .codon = "GUG", .aa = 'V', .name = "Valine" },
    .{ .codon = "UCU", .aa = 'S', .name = "Serine" },        .{ .codon = "UCC", .aa = 'S', .name = "Serine" },
    .{ .codon = "UCA", .aa = 'S', .name = "Serine" },        .{ .codon = "UCG", .aa = 'S', .name = "Serine" },
    .{ .codon = "CCU", .aa = 'P', .name = "Proline" },       .{ .codon = "CCC", .aa = 'P', .name = "Proline" },
    .{ .codon = "CCA", .aa = 'P', .name = "Proline" },       .{ .codon = "CCG", .aa = 'P', .name = "Proline" },
    .{ .codon = "ACU", .aa = 'T', .name = "Threonine" },     .{ .codon = "ACC", .aa = 'T', .name = "Threonine" },
    .{ .codon = "ACA", .aa = 'T', .name = "Threonine" },     .{ .codon = "ACG", .aa = 'T', .name = "Threonine" },
    .{ .codon = "GCU", .aa = 'A', .name = "Alanine" },       .{ .codon = "GCC", .aa = 'A', .name = "Alanine" },
    .{ .codon = "GCA", .aa = 'A', .name = "Alanine" },       .{ .codon = "GCG", .aa = 'A', .name = "Alanine" },
    .{ .codon = "UAU", .aa = 'Y', .name = "Tyrosine" },      .{ .codon = "UAC", .aa = 'Y', .name = "Tyrosine" },
    .{ .codon = "UAA", .aa = '*', .name = "Stop" },          .{ .codon = "UAG", .aa = '*', .name = "Stop" },
    .{ .codon = "CAU", .aa = 'H', .name = "Histidine" },     .{ .codon = "CAC", .aa = 'H', .name = "Histidine" },
    .{ .codon = "CAA", .aa = 'Q', .name = "Glutamine" },     .{ .codon = "CAG", .aa = 'Q', .name = "Glutamine" },
    .{ .codon = "AAU", .aa = 'N', .name = "Asparagine" },    .{ .codon = "AAC", .aa = 'N', .name = "Asparagine" },
    .{ .codon = "AAA", .aa = 'K', .name = "Lysine" },        .{ .codon = "AAG", .aa = 'K', .name = "Lysine" },
    .{ .codon = "GAU", .aa = 'D', .name = "Aspartic acid" }, .{ .codon = "GAC", .aa = 'D', .name = "Aspartic acid" },
    .{ .codon = "GAA", .aa = 'E', .name = "Glutamic acid" }, .{ .codon = "GAG", .aa = 'E', .name = "Glutamic acid" },
    .{ .codon = "UGU", .aa = 'C', .name = "Cysteine" },      .{ .codon = "UGC", .aa = 'C', .name = "Cysteine" },
    .{ .codon = "UGA", .aa = '*', .name = "Stop" },          .{ .codon = "UGG", .aa = 'W', .name = "Tryptophan" },
    .{ .codon = "CGU", .aa = 'R', .name = "Arginine" },      .{ .codon = "CGC", .aa = 'R', .name = "Arginine" },
    .{ .codon = "CGA", .aa = 'R', .name = "Arginine" },      .{ .codon = "CGG", .aa = 'R', .name = "Arginine" },
    .{ .codon = "AGU", .aa = 'S', .name = "Serine" },        .{ .codon = "AGC", .aa = 'S', .name = "Serine" },
    .{ .codon = "AGA", .aa = 'R', .name = "Arginine" },      .{ .codon = "AGG", .aa = 'R', .name = "Arginine" },
    .{ .codon = "GGU", .aa = 'G', .name = "Glycine" },       .{ .codon = "GGC", .aa = 'G', .name = "Glycine" },
    .{ .codon = "GGA", .aa = 'G', .name = "Glycine" },       .{ .codon = "GGG", .aa = 'G', .name = "Glycine" },
};

fn lookupCodon(codon: []const u8) ?*const CodonEntry {
    for (&CODON_TABLE) |*entry| {
        if (std.ascii.eqlIgnoreCase(entry.codon, codon)) return entry;
    }
    return null;
}

/// DNA sequence analysis
pub fn bioDna(buf: []u8, sequence: []const u8) []const u8 {
    var a_count: u32 = 0;
    var t_count: u32 = 0;
    var g_count: u32 = 0;
    var c_count: u32 = 0;
    // Count bases
    for (sequence) |ch| {
        switch (std.ascii.toUpper(ch)) {
            'A' => a_count += 1,
            'T' => t_count += 1,
            'G' => g_count += 1,
            'C' => c_count += 1,
            else => {},
        }
    }
    const total = a_count + t_count + g_count + c_count;
    if (total == 0) {
        return std.fmt.bufPrint(buf, "{{\"error\":\"No valid DNA bases found\"}}", .{}) catch "{}";
    }
    const gc: f64 = @as(f64, @floatFromInt(g_count + c_count)) / @as(f64, @floatFromInt(total)) * 100.0;

    return std.fmt.bufPrint(
        buf,
        "{{\"length\":{d},\"A\":{d},\"T\":{d},\"G\":{d},\"C\":{d},\"gc_content\":{d:.2}}}",
        .{ total, a_count, t_count, g_count, c_count, gc },
    ) catch "{}";
}

/// Codon lookup
pub fn bioCodon(buf: []u8, codon: []const u8) []const u8 {
    if (codon.len == 0) {
        // Return summary
        return std.fmt.bufPrint(buf, "{{\"total_codons\":64,\"stop_codons\":3,\"start_codon\":\"AUG\"}}", .{}) catch "{}";
    }
    if (codon.len != 3) {
        return std.fmt.bufPrint(buf, "{{\"error\":\"Codon must be 3 letters, got {d}\"}}", .{codon.len}) catch "{}";
    }
    if (lookupCodon(codon)) |entry| {
        return std.fmt.bufPrint(
            buf,
            "{{\"codon\":\"{s}\",\"amino_acid\":\"{c}\",\"name\":\"{s}\",\"is_start\":{s},\"is_stop\":{s}}}",
            .{
                entry.codon,
                entry.aa,
                entry.name,
                if (entry.aa == 'M') "true" else "false",
                if (entry.aa == '*') "true" else "false",
            },
        ) catch "{}";
    }
    return std.fmt.bufPrint(buf, "{{\"error\":\"Unknown codon: {s}\"}}", .{codon}) catch "{}";
}

/// Protein sequence analysis
pub fn bioProtein(buf: []u8, sequence: []const u8) []const u8 {
    // Amino acid molecular weights (Da)
    const AA_MASS = [_]struct { aa: u8, mass: f64 }{
        .{ .aa = 'A', .mass = 89.1 },  .{ .aa = 'R', .mass = 174.2 }, .{ .aa = 'N', .mass = 132.1 },
        .{ .aa = 'D', .mass = 133.1 }, .{ .aa = 'C', .mass = 121.2 }, .{ .aa = 'E', .mass = 147.1 },
        .{ .aa = 'Q', .mass = 146.2 }, .{ .aa = 'G', .mass = 75.0 },  .{ .aa = 'H', .mass = 155.2 },
        .{ .aa = 'I', .mass = 131.2 }, .{ .aa = 'L', .mass = 131.2 }, .{ .aa = 'K', .mass = 146.2 },
        .{ .aa = 'M', .mass = 149.2 }, .{ .aa = 'F', .mass = 165.2 }, .{ .aa = 'P', .mass = 115.1 },
        .{ .aa = 'S', .mass = 105.1 }, .{ .aa = 'T', .mass = 119.1 }, .{ .aa = 'W', .mass = 204.2 },
        .{ .aa = 'Y', .mass = 181.2 }, .{ .aa = 'V', .mass = 117.1 },
    };

    var total_mass: f64 = 0;
    var valid_count: u32 = 0;
    for (sequence) |ch| {
        const upper = std.ascii.toUpper(ch);
        for (AA_MASS) |entry| {
            if (entry.aa == upper) {
                total_mass += entry.mass;
                valid_count += 1;
                break;
            }
        }
    }
    return std.fmt.bufPrint(
        buf,
        "{{\"length\":{d},\"molecular_mass_da\":{d:.1},\"valid_residues\":{d}}}",
        .{ sequence.len, total_mass, valid_count },
    ) catch "{}";
}

// ═══════════════════════════════════════════════════════════════════════════════
// Quantum — Constants, States, Bell States
// ═══════════════════════════════════════════════════════════════════════════════

pub fn quantumConstants(buf: []u8) []const u8 {
    const h: f64 = 6.62607015e-34;
    const hbar: f64 = h / (2.0 * PI);
    const alpha: f64 = 1.0 / 137.035999084;
    return std.fmt.bufPrint(
        buf,
        "{{\"phi\":{d:.15},\"h\":{e:.6},\"hbar\":{e:.6},\"alpha\":{e:.9}}}",
        .{ PHI, h, hbar, alpha },
    ) catch "{}";
}

pub fn quantumStates(buf: []u8) []const u8 {
    const inv_sqrt2: f64 = 1.0 / @sqrt(2.0);
    const phi_norm: f64 = @sqrt(1.0 + PHI * PHI);
    return std.fmt.bufPrint(
        buf,
        "{{\"states\":{{" ++
            "\"|0>\":[1,0]," ++
            "\"|1>\":[0,1]," ++
            "\"|+>\":[{d:.6},{d:.6}]," ++
            "\"|->\":[{d:.6},{d:.6}]," ++
            "\"|phi>\":[{d:.6},{d:.6}]" ++
            "}}}}",
        .{ inv_sqrt2, inv_sqrt2, inv_sqrt2, -inv_sqrt2, PHI / phi_norm, 1.0 / phi_norm },
    ) catch "{}";
}

pub fn bellStates(buf: []u8) []const u8 {
    return std.fmt.bufPrint(
        buf,
        "{{\"bell_states\":[\"|Phi+>\",\"|Phi->\",\"|Psi+>\",\"|Psi->\"]}}",
        .{},
    ) catch "{}";
}

// ═══════════════════════════════════════════════════════════════════════════════
// Phi Spiral
// ═══════════════════════════════════════════════════════════════════════════════

pub fn phiSpiral(allocator: std.mem.Allocator, n: u32) ![]const u8 {
    const points = if (n == 0) @as(u32, 100) else n;
    var buf: std.ArrayList(u8) = .{};
    errdefer buf.deinit(allocator);

    try buf.appendSlice(allocator, "{\"points\":[");
    var i: u32 = 0;
    while (i < points) : (i += 1) {
        if (i > 0) try buf.appendSlice(allocator, ",");
        const fi: f64 = @floatFromInt(i);
        const angle = fi * PHI;
        const r = if (i > 0) @sqrt(fi) else 0.0;
        const x = r * @cos(angle);
        const y = r * @sin(angle);
        const w = buf.writer(allocator);
        try w.print("[{d:.4},{d:.4}]", .{ x, y });
    }
    try buf.appendSlice(allocator, "]}");
    return buf.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Sacred Formula: V = n * 3^k * pi^m * phi^p * e^q
// ═══════════════════════════════════════════════════════════════════════════════

pub fn sacredFormula(buf: []u8, n: i32, k: i32, m: i32, p: i32, q: i32) []const u8 {
    const n_f: f64 = @floatFromInt(n);
    var result: f64 = n_f;
    result *= intPow(3.0, k);
    result *= intPow(PI, m);
    result *= intPow(PHI, p);
    result *= intPow(E_CONST, q);

    return std.fmt.bufPrint(
        buf,
        "{{\"formula\":\"V = {d} * 3^{d} * pi^{d} * phi^{d} * e^{d}\",\"result\":{d:.15},\"trinity\":\"phi^2 + 1/phi^2 = 3\"}}",
        .{ n, k, m, p, q, result },
    ) catch "{}";
}

fn intPow(base: f64, exp: i32) f64 {
    if (exp == 0) return 1.0;
    if (exp > 0) {
        var result: f64 = 1.0;
        var i: i32 = 0;
        while (i < exp) : (i += 1) result *= base;
        return result;
    } else {
        var result: f64 = 1.0;
        var i: i32 = 0;
        while (i < -exp) : (i += 1) result *= base;
        return 1.0 / result;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════════

fn copySlice(dst: []u8, src: []const u8) usize {
    const len = @min(dst.len, src.len);
    @memcpy(dst[0..len], src[0..len]);
    return len;
}
